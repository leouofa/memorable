require "test_helper"

module Api
  module V1
    class MemoriesControllerTest < ActionDispatch::IntegrationTest
      setup do
        @memory = Memory.create!(title: "API Memory", body: "# API Markdown Test")
      end

      test "index lists memories with pagination" do
        get api_v1_memories_url
        assert_response :success
        json = response.parsed_body
        assert json.key?("memories")
        assert json.key?("meta")
        assert_equal 1, json["memories"].size
        assert_equal @memory.title, json["memories"].first["title"]
      end

      test "index filters by search query" do
        Memory.create!(title: "Other Item", body: "irrelevant")
        get api_v1_memories_url(q: "API")
        assert_response :success
        json = response.parsed_body
        assert_equal 1, json["memories"].size
        assert_equal "API Memory", json["memories"].first["title"]
      end

      test "index filters by pinned status" do
        @memory.toggle_pin!
        Memory.create!(title: "Unpinned Memory", body: "none")

        get api_v1_memories_url(pinned: "true")
        assert_response :success
        json = response.parsed_body
        assert_equal 1, json["memories"].size
        assert_equal @memory.id, json["memories"].first["id"]
      end

      test "show returns memory details" do
        get api_v1_memory_url(@memory)
        assert_response :success
        json = response.parsed_body
        assert_equal @memory.id, json["id"]
        assert_equal @memory.title, json["title"]
        assert_equal @memory.body, json["body"]
      end

      test "show renders markdown when requested" do
        get api_v1_memory_url(@memory, render_markdown: "true")
        assert_response :success
        json = response.parsed_body
        assert json.key?("rendered_html")
        assert_includes json["rendered_html"], "API Markdown Test"
      end

      test "create creates memory" do
        assert_difference("Memory.count") do
          post api_v1_memories_url, params: {
            memory: { title: "New JSON Memory", body: "# Content" }
          }, as: :json
        end
        assert_response :created
        json = response.parsed_body
        assert_equal "New JSON Memory", json["title"]
      end

      test "update updates memory" do
        patch api_v1_memory_url(@memory), params: {
          memory: { title: "Updated JSON Memory" }
        }, as: :json
        assert_response :success
        assert_equal "Updated JSON Memory", @memory.reload.title
      end

      test "destroy deletes memory" do
        assert_difference("Memory.count", -1) do
          delete api_v1_memory_url(@memory)
        end
        assert_response :success
      end

      test "toggle_pin toggles pin status" do
        patch toggle_pin_api_v1_memory_url(@memory)
        assert_response :success
        json = response.parsed_body
        assert_equal true, json["pinned"]
        assert @memory.reload.pinned?
      end

      test "reorder_pinned reorders pinned memories" do
        m1 = Memory.create!(title: "M1", pinned: true, pinned_position: 1)
        m2 = Memory.create!(title: "M2", pinned: true, pinned_position: 2)

        patch reorder_pinned_api_v1_memories_url, params: {
          memory_ids: [ m2.id, m1.id ]
        }, as: :json
        assert_response :success

        assert_equal 1, m2.reload.pinned_position
        assert_equal 2, m1.reload.pinned_position
      end

      test "memory json includes embedding metadata" do
        get api_v1_memory_url(@memory)
        assert_response :success
        json = response.parsed_body
        assert json.key?("embedded")
        assert json.key?("embedding_model")
        assert json.key?("embedded_at")
        assert_equal false, json["embedded"]
      end

      test "neighbors returns 422 if memory has no embedding" do
        get neighbors_api_v1_memory_url(@memory)
        assert_response :unprocessable_entity
        json = response.parsed_body
        assert_includes json["error"], "not been embedded yet"
      end

      test "neighbors returns nearest memories when embedded" do
        v1 = Array.new(1024, 0.0)
        v1[0] = 1.0

        v2 = Array.new(1024, 0.0)
        v2[0] = 0.95

        @memory.update!(embedding: v1, embedding_model: "qwen3-embedding:0.6b", embedded_at: Time.current)
        neighbor = Memory.create!(title: "Neighbor Memory", embedding: v2, embedding_model: "qwen3-embedding:0.6b", embedded_at: Time.current)

        get neighbors_api_v1_memory_url(@memory)
        assert_response :success
        json = response.parsed_body
        assert_equal "ok", json["status"]
        assert_equal 1, json["neighbors"].size
        assert_equal neighbor.id, json["neighbors"].first["memory"]["id"]
        assert json["neighbors"].first["score"] > 0.9
      end

      test "generate_embedding generates embedding synchronously by default" do
        fake_vector = Array.new(1024) { 0.1 }
        singleton = Llm::EmbeddingGenerator.singleton_class
        original = Llm::EmbeddingGenerator.method(:call)
        singleton.define_method(:call) do |_text, **_kwargs|
          { vector: fake_vector, model: "qwen3-embedding:0.6b" }
        end

        begin
          post generate_embedding_api_v1_memory_url(@memory)
          assert_response :success
          json = response.parsed_body
          assert_equal "ok", json["status"]
          assert_equal true, json["memory"]["embedded"]
          assert_equal "qwen3-embedding:0.6b", json["memory"]["embedding_model"]
        ensure
          singleton.define_method(:call, original)
        end
      end

      test "generate_embedding with async enqueues job" do
        assert_enqueued_with(job: GenerateEmbeddingJob, args: [ @memory.id ]) do
          post generate_embedding_api_v1_memory_url(@memory, async: true)
          assert_response :success
          json = response.parsed_body
          assert_equal "ok", json["status"]
          assert_includes json["message"], "enqueued"
        end
      end

      test "index supports semantic mode" do
        v = Array.new(1024, 0.0)
        v[0] = 1.0
        @memory.update!(embedding: v, embedding_model: "qwen3-embedding:0.6b", embedded_at: Time.current)

        singleton = Llm::EmbeddingGenerator.singleton_class
        original = Llm::EmbeddingGenerator.method(:call)
        singleton.define_method(:call) do |_text, **_kwargs|
          { vector: v, model: "qwen3-embedding:0.6b" }
        end

        begin
          get api_v1_memories_url(q: "something", mode: "semantic")
          assert_response :success
          json = response.parsed_body
          assert_equal 1, json["memories"].size
          assert_equal @memory.id, json["memories"].first["id"]
        ensure
          singleton.define_method(:call, original)
        end
      end
    end
  end
end
