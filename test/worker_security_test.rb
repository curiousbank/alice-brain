# frozen_string_literal: true

require "minitest/autorun"
require "tempfile"
require "tmpdir"
load File.expand_path("../bin/autos_cc_worker", __dir__)

class WorkerSecurityTest < Minitest::Test
  def test_env_file_is_loaded_as_data_without_interpolation
    Dir.mktmpdir("alice-env-test") do |directory|
      sentinel = File.join(directory, "should-not-run")
      env_path = File.join(directory, ".env")
      File.write(env_path, "ALICE_TEST_LITERAL=$(touch #{sentinel})\n")
      ENV.delete("ALICE_TEST_LITERAL")

      AliceBrain.load_env_file(env_path)

      assert_equal "$(touch #{sentinel})", ENV.fetch("ALICE_TEST_LITERAL")
      refute File.exist?(sentinel)
    ensure
      ENV.delete("ALICE_TEST_LITERAL")
    end
  end

  def test_explicit_environment_wins_over_file
    Tempfile.create("alice-env") do |file|
      file.write("ALICE_TEST_PRIORITY=file\n")
      file.close
      ENV["ALICE_TEST_PRIORITY"] = "process"

      AliceBrain.load_env_file(file.path)

      assert_equal "process", ENV.fetch("ALICE_TEST_PRIORITY")
    ensure
      ENV.delete("ALICE_TEST_PRIORITY")
    end
  end

  def test_remote_http_controller_is_rejected
    assert_raises(ArgumentError) do
      AliceBrain.validate_base_uri("http://example.com")
    end
  end

  def test_loopback_http_requires_explicit_development_flag
    assert_raises(ArgumentError) do
      AliceBrain.validate_base_uri("http://127.0.0.1:3333")
    end
    uri = AliceBrain.validate_base_uri("http://127.0.0.1:3333", allow_insecure: true)
    assert_equal "127.0.0.1", uri.hostname
  end

  def test_job_paths_cannot_change_controller_origin
    base = AliceBrain.validate_base_uri("https://313.cash")

    assert_raises(ArgumentError) { AliceBrain.controller_uri(base, "https://example.com/steal") }
    assert_raises(ArgumentError) { AliceBrain.controller_uri(base, "//example.com/steal") }
    assert_raises(ArgumentError) { AliceBrain.controller_uri(base, "/jobs/../steal") }
    assert_raises(ArgumentError) { AliceBrain.controller_uri(base, "/jobs/%2e%2e/steal") }
    assert_raises(ArgumentError) { AliceBrain.controller_uri(base, "/jobs/complete?note=%0d%0aInjected") }
    assert_equal "313.cash", AliceBrain.controller_uri(base, "/autos_worker/jobs/1/complete").hostname
  end

  def test_remote_ollama_is_rejected_by_default
    assert_raises(ArgumentError) do
      AliceBrain.validate_base_uri("https://ollama.example", allow_remote: false)
    end
  end

  def test_header_identifiers_are_restricted
    assert_equal "alice-node.1", AliceBrain.validate_identifier("alice-node.1", "node")
    assert_raises(ArgumentError) { AliceBrain.validate_identifier("alice\r\nX-Evil: true", "node") }
  end

  def test_sms_bot_is_a_supported_dedicated_queue
    assert_includes AliceBrain::CONTROLLER_QUEUES, "sms_bot"
    refute_includes AliceBrain::RORE_CAPABILITIES, "embeddings"
  end

  def test_sms_bot_prompt_does_not_include_public_product_context
    worker = AliceBrain::Worker.allocate
    worker.instance_variable_set(:@public_context, "UNIQUE PUBLIC PRODUCT CONTEXT")

    sms_prompt = worker.send(:system_content_for, { "surface" => "sms_bot_compute" })
    regular_prompt = worker.send(:system_content_for, { "surface" => "autos" })

    assert_includes sms_prompt, "customer-facing SMS"
    refute_includes sms_prompt, "UNIQUE PUBLIC PRODUCT CONTEXT"
    assert_includes regular_prompt, "UNIQUE PUBLIC PRODUCT CONTEXT"
  end

  def test_sms_bot_worker_rejects_jobs_from_other_surfaces
    worker = AliceBrain::Worker.allocate
    worker.instance_variable_set(:@worker_queue, "sms_bot")
    worker.instance_variable_set(:@base_uri, AliceBrain.validate_base_uri("https://313.cash"))
    job = {
      "id" => 1,
      "prompt" => "Draft a reply",
      "surface" => "autos",
      "complete_path" => "/autos_worker/messages/1/complete",
      "fail_path" => "/autos_worker/messages/1/fail"
    }

    assert_raises(ArgumentError) { worker.send(:validate_job!, job) }
  end
end
