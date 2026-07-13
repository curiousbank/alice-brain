# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require "net/http"
require "time"
require "uri"

class AliceContextCache
  attr_reader :embed_model
  DEFAULT_AUTOS_PATTERNS = [
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

  DEFAULT_DOPE_PATTERNS = [
    "README.md",
    "config/routes.rb",
    "config/autos/**/*.{md,txt,rb}",
    "app/controllers/asks_controller.rb",
    "app/controllers/autos_worker_controller.rb",
    "app/controllers/dope_worker_controller.rb",
    "app/controllers/deal_queues_controller.rb",
    "app/controllers/data_maps_controller.rb",
    "app/models/autos*.rb",
    "app/models/crm_record.rb",
    "app/models/report_artifact.rb",
    "app/services/autos/**/*.rb",
    "app/services/deal_reports/**/*.rb",
    "app/services/hubspot/**/*.rb",
    "app/services/data_maps/**/*.rb",
    "app/services/canva/**/*.rb",
    "app/views/asks/**/*.{erb,html}",
    "app/views/deal_queues/**/*.{erb,html}",
    "app/views/data_maps/**/*.{erb,html}",
    "docs/**/*.{md,txt}"
  ].freeze

  def initialize(ollama_url: nil, logger: nil)
    @ollama_url = (ollama_url || env("OLLAMA_URL", "http://127.0.0.1:11434")).sub(%r{/+\z}, "")
    @embed_model = env("AUTOS_CC_EMBED_MODEL", "qwen3-embedding:8b-q4_K_M")
    @enabled = truthy?(env("AUTOS_CC_EMBED_ENABLED", "1"))
    @max_chunks = env("AUTOS_CC_MAX_CHUNKS", "5").to_i.clamp(1, 12)
    @min_score = env("AUTOS_CC_MIN_SCORE", "0.18").to_f
    @chunk_chars = env("AUTOS_CC_CHUNK_CHARS", "1200").to_i.clamp(400, 3000)
    @index_max_chunks = env("AUTOS_CC_INDEX_MAX_CHUNKS", "420").to_i.clamp(20, 1200)
    @batch_size = env("AUTOS_CC_EMBED_BATCH", "12").to_i.clamp(1, 32)
    @rebuild_seconds = env("AUTOS_CC_REBUILD_SECONDS", "3600").to_i.clamp(60, 86_400)
    @skip_stale_check = truthy?(env("AUTOS_CC_SKIP_STALE_CHECK", "1"))
    @logger = logger
    @profiles = build_profiles
  end

  def enabled?
    @enabled
  end

  def search(query, scope: "autos")
    return [] unless enabled?

    query = query.to_s.strip
    return [] if query.empty?

    scope_name = profile_key(scope)
    index = load_or_rebuild(scope_name)
    query_embedding = embed_many([query]).first

    Array(index["chunks"])
      .select { |chunk| ["common", scope_name].include?(chunk["scope"].to_s) }
      .map { |chunk| chunk.merge("score" => cosine(query_embedding, chunk["embedding"])) }
      .select { |chunk| chunk["score"].finite? && chunk["score"] >= @min_score }
      .sort_by { |chunk| -chunk["score"] }
      .first(@max_chunks)
  rescue StandardError => e
    log "semantic context failed scope=#{scope} #{e.class}: #{e.message}"
    []
  end

  def embed_query(text)
    embed_many([text.to_s]).first || []
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

  def rebuild!(scope: "autos")
    raise "semantic context disabled" unless enabled?

    if scope.to_s == "all"
      return @profiles.keys.each_with_object({}) { |key, built| built[key] = rebuild_profile!(key) }
    end

    rebuild_profile!(profile_key(scope))
  end

  private

  def build_profiles
    legacy_root = env("AUTOS_CC_ROOT", default_autos_root)
    legacy_context_dir = env("AUTOS_CC_CONTEXT_DIR", File.expand_path("context", __dir__))
    index_dir = File.expand_path(env("AUTOS_CC_INDEX_DIR", File.expand_path("log", __dir__)))

    autos_root = File.expand_path(env("AUTOS_CC_AUTOS_ROOT", legacy_root))
    dope_root = File.expand_path(env("AUTOS_CC_DOPE_ROOT", default_dope_root))

    {
      "autos" => {
        scope: "autos",
        label: "pb",
        root: autos_root,
        context_dirs: context_dirs("AUTOS_CC_AUTOS_CONTEXT_DIRS", [
          File.expand_path("context/autos", __dir__),
          File.expand_path(legacy_context_dir)
        ]),
        index_path: File.expand_path(env("AUTOS_CC_AUTOS_INDEX_PATH", File.join(index_dir, "alice_context_autos.json"))),
        patterns: DEFAULT_AUTOS_PATTERNS
      },
      "dope" => {
        scope: "dope",
        label: "dope",
        root: dope_root,
        context_dirs: context_dirs("AUTOS_CC_DOPE_CONTEXT_DIRS", [
          File.expand_path("context/dope", __dir__),
          File.expand_path("~/Desktop/alice-brain/report_refs"),
          File.expand_path("~/.config/autos/context/dope")
        ]),
        index_path: File.expand_path(env("AUTOS_CC_DOPE_INDEX_PATH", File.join(index_dir, "alice_context_dope.json"))),
        patterns: DEFAULT_DOPE_PATTERNS
      }
    }
  end

  def profile_key(scope)
    value = scope.to_s.downcase
    return "dope" if value.include?("dope") || value.include?("8182")

    "autos"
  end

  def context_dirs(env_name, defaults)
    configured = ENV[env_name].to_s.split(":").map(&:strip).reject(&:empty?)
    dirs = configured.empty? ? defaults : configured
    dirs.map { |dir| File.expand_path(dir) }.uniq
  end

  def load_or_rebuild(scope_name)
    profile = @profiles.fetch(scope_name)
    unless sync_rebuild_on_search?
      if File.file?(profile[:index_path])
        return JSON.parse(File.read(profile[:index_path]))
      end

      log "semantic context index missing scope=#{scope_name}; skipping synchronous rebuild"
      return empty_index(scope_name)
    end

    return rebuild_profile!(scope_name) if index_stale?(profile)

    JSON.parse(File.read(profile[:index_path]))
  rescue JSON::ParserError
    unless sync_rebuild_on_search?
      log "semantic context index unreadable scope=#{scope_name}; skipping synchronous rebuild"
      return empty_index(scope_name)
    end

    rebuild_profile!(scope_name)
  end

  def sync_rebuild_on_search?
    truthy?(env("AUTOS_CC_SYNC_REBUILD_ON_SEARCH", "0"))
  end

  def empty_index(scope_name)
    {
      "version" => 2,
      "scope" => scope_name,
      "model" => @embed_model,
      "chunk_count" => 0,
      "chunks" => []
    }
  end

  def rebuild_profile!(scope_name)
    profile = @profiles.fetch(scope_name)
    sources = source_files(profile)
    chunks = sources.flat_map { |source| chunks_for(source) }.first(@index_max_chunks)
    raise "no #{scope_name} context chunks found under #{profile[:root]} / #{profile[:context_dirs].join(', ')}" if chunks.empty?

    embedded = []
    chunks.each_slice(@batch_size) do |batch|
      embeddings = embed_many(batch.map { |chunk| chunk[:text] })
      batch.zip(embeddings).each do |chunk, embedding|
        embedded << chunk.merge(embedding: embedding)
      end
    end

    payload = {
      version: 2,
      scope: scope_name,
      generated_at: Time.now.iso8601,
      root_label: profile[:label],
      context_dirs: profile[:context_dirs].select { |dir| Dir.exist?(dir) }.map { |dir| safe_context_label(dir) },
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

    FileUtils.mkdir_p(File.dirname(profile[:index_path]))
    tmp_path = "#{profile[:index_path]}.tmp-#{$$}"
    File.write(tmp_path, JSON.generate(payload))
    File.rename(tmp_path, profile[:index_path])
    log "semantic context indexed scope=#{scope_name} chunks=#{embedded.length} files=#{sources.length} model=#{@embed_model}"
    payload
  ensure
    FileUtils.rm_f(tmp_path) if defined?(tmp_path) && tmp_path && File.exist?(tmp_path)
  end

  def index_stale?(profile)
    return true unless File.file?(profile[:index_path])

    index = JSON.parse(File.read(profile[:index_path]))
    return true unless index["version"].to_i >= 2
    return true unless index["scope"] == profile[:scope]
    return true unless index["model"] == @embed_model
    return true unless index["root_label"] == profile[:label]
    return false if @skip_stale_check
    return true if Time.now - File.mtime(profile[:index_path]) > @rebuild_seconds

    index_mtime = File.mtime(profile[:index_path])
    source_files(profile).any? { |source| File.mtime(source[:absolute]) > index_mtime }
  rescue StandardError
    true
  end

  def source_files(profile)
    paths = []
    if Dir.exist?(profile[:root])
      paths.concat(profile[:patterns].flat_map { |pattern| Dir.glob(File.join(profile[:root], pattern), File::FNM_EXTGLOB) })
    end

    profile[:context_dirs].each do |context_dir|
      paths.concat(Dir.glob(File.join(context_dir, "**/*.{md,txt}"), File::FNM_EXTGLOB)) if Dir.exist?(context_dir)
    end

    paths.uniq.select do |path|
      File.file?(path) && File.size(path) <= 250_000 && !sensitive_path?(path)
    end.sort.map do |path|
      { absolute: path, relative: relative_path(path, profile), scope: scope_for(path, profile) }
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

  def relative_path(path, profile)
    expanded = File.expand_path(path)
    if expanded.start_with?("#{profile[:root]}/")
      "#{profile[:label]}:#{expanded.delete_prefix("#{profile[:root]}/")}" 
    else
      context_dir = profile[:context_dirs].find { |dir| expanded.start_with?("#{dir}/") }
      return "#{profile[:label]}_context:#{expanded.delete_prefix("#{context_dir}/")}" if context_dir

      File.basename(expanded)
    end
  end

  def scope_for(path, profile)
    rel = relative_path(path, profile).downcase
    return "common" if rel.include?("common/") || rel.include?("shared/")

    profile[:scope]
  end

  def safe_context_label(dir)
    File.basename(File.expand_path(dir))
  end

  def sensitive_path?(path)
    path.downcase.match?(%r{(credentials|master\.key|secret|database\.yml|application\.yml|\.env|token|storage\.yml)})
  end

  def default_autos_root
    candidate = File.expand_path("~/Desktop/PB")
    Dir.exist?(candidate) ? candidate : Dir.pwd
  end

  def default_dope_root
    candidate = File.expand_path("~/Desktop/DOPE")
    Dir.exist?(candidate) ? candidate : default_autos_root
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
