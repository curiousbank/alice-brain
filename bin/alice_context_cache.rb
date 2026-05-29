# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "net/http"
require "time"
require "uri"

class AliceContextCache
  DEFAULT_PATTERNS = [
    "README.md",
    "config/routes.rb",
    "config/autos/**/*.{md,txt,rb}",
    "config/thumper/**/*.{md,txt,rb}",
    "docs/cc_context_cache.md",
    "docs/runtime_identity_contract.md",
    "app/views/application/faq.html.erb",
    "app/views/application/_guide_sections.html.erb",
    "app/views/application/autos.html.erb",
    "app/views/shop/index.html.erb",
    "app/controllers/autos_controller.rb",
    "app/controllers/autos_worker_controller.rb",
    "app/controllers/shop_controller.rb",
    "app/controllers/pow_wow*.rb",
    "app/controllers/pow_wow_inventory_base_controller.rb",
    "app/models/autos*.rb",
    "app/models/user.rb",
    "app/models/address.rb",
    "app/models/pow_wow*.rb",
    "app/services/autos/**/*.rb",
    "app/services/shop/**/*.rb",
    "app/channels/pow_wow*.rb"
  ].freeze

  def initialize(ollama_url: nil, logger: nil)
    @ollama_url = (ollama_url || env("OLLAMA_URL", "http://127.0.0.1:11434")).sub(%r{/+\z}, "")
    @embed_model = env("AUTOS_CC_EMBED_MODEL", "nomic-embed-text")
    @enabled = truthy?(env("AUTOS_CC_EMBED_ENABLED", "1"))
    @root = File.expand_path(env("AUTOS_CC_ROOT", default_root))
    @context_dir = File.expand_path(env("AUTOS_CC_CONTEXT_DIR", File.expand_path("context", __dir__)))
    @index_path = File.expand_path(env("AUTOS_CC_INDEX_PATH", File.expand_path("log/alice_context_index.json", __dir__)))
    @max_chunks = env("AUTOS_CC_MAX_CHUNKS", "5").to_i.clamp(1, 12)
    @min_score = env("AUTOS_CC_MIN_SCORE", "0.18").to_f
    @chunk_chars = env("AUTOS_CC_CHUNK_CHARS", "1200").to_i.clamp(400, 3000)
    @index_max_chunks = env("AUTOS_CC_INDEX_MAX_CHUNKS", "360").to_i.clamp(20, 1000)
    @batch_size = env("AUTOS_CC_EMBED_BATCH", "12").to_i.clamp(1, 32)
    @rebuild_seconds = env("AUTOS_CC_REBUILD_SECONDS", "3600").to_i.clamp(60, 86_400)
    @skip_stale_check = truthy?(env("AUTOS_CC_SKIP_STALE_CHECK", "1"))
    @logger = logger
  end

  def enabled?
    @enabled
  end

  def search(query, scope: "autos")
    return [] unless enabled?

    query = query.to_s.strip
    return [] if query.empty?

    index = load_or_rebuild
    query_embedding = embed_many([query]).first
    wanted_scope = scope.to_s

    Array(index["chunks"])
      .select { |chunk| ["common", wanted_scope].include?(chunk["scope"].to_s) }
      .map { |chunk| chunk.merge("score" => cosine(query_embedding, chunk["embedding"])) }
      .select { |chunk| chunk["score"].finite? && chunk["score"] >= @min_score }
      .sort_by { |chunk| -chunk["score"] }
      .first(@max_chunks)
  rescue StandardError => e
    log "semantic context failed #{e.class}: #{e.message}"
    []
  end

  def format_results(chunks)
    return "No extra Alice semantic context matched." if chunks.empty?

    chunks.each_with_index.map do |chunk, index|
      score = format("%.3f", chunk.fetch("score", 0.0))
      <<~TEXT.strip
        [#{index + 1}] #{chunk["path"]} score=#{score}
        #{chunk["text"]}
      TEXT
    end.join("\n\n")
  end

  def rebuild!
    raise "semantic context disabled" unless enabled?

    sources = source_files
    chunks = sources.flat_map { |source| chunks_for(source) }.first(@index_max_chunks)
    raise "no context chunks found under #{@root} / #{@context_dir}" if chunks.empty?

    embedded = []
    chunks.each_slice(@batch_size) do |batch|
      embeddings = embed_many(batch.map { |chunk| chunk[:text] })
      batch.zip(embeddings).each do |chunk, embedding|
        embedded << chunk.merge(embedding: embedding)
      end
    end

    payload = {
      version: 1,
      generated_at: Time.now.iso8601,
      root: @root,
      context_dir: @context_dir,
      model: @embed_model,
      chunk_count: embedded.length,
      chunks: embedded.map do |chunk|
        {
          path: chunk[:path],
          scope: chunk[:scope],
          digest: chunk[:digest],
          text: chunk[:text],
          embedding: chunk[:embedding]
        }
      end
    }

    FileUtils.mkdir_p(File.dirname(@index_path))
    tmp_path = "#{@index_path}.tmp-#{$$}"
    File.write(tmp_path, JSON.generate(payload))
    File.rename(tmp_path, @index_path)
    log "semantic context indexed #{embedded.length} chunks from #{sources.length} files using #{@embed_model}"
    payload
  ensure
    FileUtils.rm_f(tmp_path) if defined?(tmp_path) && tmp_path && File.exist?(tmp_path)
  end

  private

  def load_or_rebuild
    return rebuild! if index_stale?

    JSON.parse(File.read(@index_path))
  rescue JSON::ParserError
    rebuild!
  end

  def index_stale?
    return true unless File.file?(@index_path)

    index = JSON.parse(File.read(@index_path))
    return true unless index["model"] == @embed_model
    return true unless index["root"] == @root
    return false if @skip_stale_check
    return true if Time.now - File.mtime(@index_path) > @rebuild_seconds

    index_mtime = File.mtime(@index_path)
    source_files.any? { |source| File.mtime(source[:absolute]) > index_mtime }
  rescue StandardError
    true
  end

  def source_files
    paths = DEFAULT_PATTERNS.flat_map { |pattern| Dir.glob(File.join(@root, pattern), File::FNM_EXTGLOB) }
    paths.concat(Dir.glob(File.join(@context_dir, "**/*.{md,txt}"), File::FNM_EXTGLOB)) if Dir.exist?(@context_dir)

    paths.uniq.select do |path|
      File.file?(path) && File.size(path) <= 250_000 && !sensitive_path?(path)
    end.sort.map do |path|
      { absolute: path, relative: relative_path(path), scope: scope_for(path) }
    end
  end

  def chunks_for(source)
    text = File.read(source[:absolute], encoding: "UTF-8", invalid: :replace, undef: :replace, replace: "")
    text = clean_text(text)
    return [] if text.empty?

    chunk_text(text).map.with_index do |chunk, index|
      digest = Digest::SHA256.hexdigest("#{source[:relative]}:#{index}:#{chunk}")
      {
        path: source[:relative],
        scope: source[:scope],
        digest: digest,
        text: chunk
      }
    end
  rescue StandardError => e
    log "skipping context source #{source[:relative]} #{e.class}: #{e.message}"
    []
  end

  def clean_text(text)
    text.gsub(/\r\n?/, "\n")
      .gsub(/<script.*?<\/script>/m, " ")
      .gsub(/<style.*?<\/style>/m, " ")
      .gsub(/[ \t]+/, " ")
      .gsub(/\n{4,}/, "\n\n\n")
      .strip
  end

  def chunk_text(text)
    chunks = []
    current = +""

    text.split(/\n{2,}/).each do |paragraph|
      paragraph = paragraph.strip
      next if paragraph.empty?

      if paragraph.length > @chunk_chars
        chunks << current unless current.empty?
        current = +""
        paragraph.scan(/.{1,#{@chunk_chars}}/m) { |part| chunks << part.strip unless part.strip.empty? }
      elsif current.empty?
        current = paragraph
      elsif current.length + paragraph.length + 2 <= @chunk_chars
        current << "\n\n" << paragraph
      else
        chunks << current
        current = paragraph
      end
    end

    chunks << current unless current.empty?
    chunks
  end

  def embed_many(texts)
    uri = URI("#{@ollama_url}/api/embed")
    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req.body = { model: @embed_model, input: texts }.to_json

    res = http(uri, read_timeout: 300).request(req)
    raise "ollama embed HTTP #{res.code}: #{res.body}" unless res.is_a?(Net::HTTPSuccess)

    parsed = JSON.parse(res.body)
    embeddings = parsed["embeddings"]
    raise "ollama embed returned no embeddings" unless embeddings.is_a?(Array) && embeddings.length == texts.length

    embeddings
  end

  def cosine(left, right)
    return -1.0 unless left.is_a?(Array) && right.is_a?(Array) && left.length == right.length

    dot = 0.0
    left_norm = 0.0
    right_norm = 0.0
    left.each_with_index do |value, index|
      l = value.to_f
      r = right[index].to_f
      dot += l * r
      left_norm += l * l
      right_norm += r * r
    end
    return -1.0 if left_norm.zero? || right_norm.zero?

    dot / Math.sqrt(left_norm * right_norm)
  end

  def http(uri, read_timeout: 30)
    Net::HTTP.new(uri.host, uri.port).tap do |client|
      client.use_ssl = uri.scheme == "https"
      client.open_timeout = 5
      client.read_timeout = read_timeout
    end
  end

  def relative_path(path)
    expanded = File.expand_path(path)
    if expanded.start_with?("#{@root}/")
      expanded.delete_prefix("#{@root}/")
    elsif expanded.start_with?("#{@context_dir}/")
      "alice_context/#{expanded.delete_prefix("#{@context_dir}/")}" 
    else
      expanded
    end
  end

  def scope_for(path)
    rel = relative_path(path).downcase
    return "dope" if rel.include?("dope") || rel.include?("pow_wow") || rel.include?("shop")
    return "autos" if rel.include?("autos") || rel.include?("pinball") || rel.include?("thumper") || rel.include?("cc_context")

    "common"
  end

  def sensitive_path?(path)
    path.downcase.match?(%r{(credentials|master\.key|secret|database\.yml|application\.yml|\.env|token|storage\.yml)})
  end

  def default_root
    candidate = File.expand_path("~/Desktop/PB")
    Dir.exist?(candidate) ? candidate : Dir.pwd
  end

  def env(name, fallback)
    value = ENV[name].to_s.strip
    value.empty? ? fallback : value
  end

  def truthy?(value)
    %w[1 true yes on].include?(value.to_s.downcase)
  end

  def log(message)
    if @logger
      @logger.call(message)
    else
      warn "[alice_context_cache] #{Time.now.iso8601} #{message}"
    end
  end
end
