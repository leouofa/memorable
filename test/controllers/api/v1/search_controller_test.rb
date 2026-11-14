# frozen_string_literal: true

require "test_helper"

class Api::V1::SearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    Memory.destroy_all
    @v_close = Array.new(1024, 0.0)
    @v_close[0] = 0.95
    @v_close[1] = 0.05

    @v_far = Array.new(1024, 0.0)
    @v_far[900] = 1.0

    @mem1 = Memory.create!(
      title: "Active Record Performance",
      body: "Optimizing database queries and eager loading in Rails",
      embedding: @v_close,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )

    @mem2 = Memory.create!(
      title: "Cooking Pasta",
      body: "Boil water with salt for delicious spaghetti",
      embedding: @v_far,
      embedding_model: "qwen3-embedding:0.6b",
      embedded_at: Time.current
    )
  end

  test "returns 400 when query parameter q is missing or blank" do
    get api_v1_search_url, as: :json
    assert_response :bad_request
    json = response.parsed_body
    assert_includes json["error"], "must not be blank"

    get api_v1_search_url, params: { q: "   " }, as: :json
    assert_response :bad_request
  end

  test "returns keyword search results when mode is keyword" do
    get api_v1_search_url, params: { q: "spaghetti", mode: "keyword" }, as: :json
    assert_response :success
    json = response.parsed_body
    assert_equal "ok", json["status"]
    assert_equal "keyword", json["meta"]["mode"]
    assert_equal 1, json["results"].size
    assert_equal @mem2.id, json["results"].first["data"]["id"]
    assert_nil json["results"].first["score"]
  end

  test "returns semantic vector search results with scores when mode is semantic" do
    query_vector = Array.new(1024, 0.0)
    query_vector[0] = 1.0

    singleton = Llm::EmbeddingGenerator.singleton_class
    original = Llm::EmbeddingGenerator.method(:call)
    singleton.define_method(:call) do |_text, **_kwargs|
      { vector: query_vector, model: "qwen3-embedding:0.6b" }
    end

    begin
      get api_v1_search_url, params: { q: "database tuning", mode: "semantic" }, as: :json
      assert_response :success
      json = response.parsed_body
      assert_equal "ok", json["status"]
      assert_equal "semantic", json["meta"]["mode"]
      assert_equal 2, json["results"].size

      first_result = json["results"].first
      assert_equal @mem1.id, first_result["data"]["id"]
      assert_not_nil first_result["score"]
      assert first_result["score"] > 0.8
    ensure
      singleton.define_method(:call, original)
    end
  end

  test "auto mode uses semantic search when embeddings exist" do
    query_vector = Array.new(1024, 0.0)
    query_vector[0] = 1.0

    singleton = Llm::EmbeddingGenerator.singleton_class
    original = Llm::EmbeddingGenerator.method(:call)
    singleton.define_method(:call) do |_text, **_kwargs|
      { vector: query_vector, model: "qwen3-embedding:0.6b" }
    end

    begin
      get api_v1_search_url, params: { q: "database tuning" }, as: :json
      assert_response :success
      json = response.parsed_body
      assert_equal "semantic", json["meta"]["mode"]
      assert_equal @mem1.id, json["results"].first["data"]["id"]
    ensure
      singleton.define_method(:call, original)
    end
  end

  test "auto mode falls back to keyword matching when embedding generation fails" do
    singleton = Llm::EmbeddingGenerator.singleton_class
    original = Llm::EmbeddingGenerator.method(:call)
    singleton.define_method(:call) do |_text, **_kwargs|
      raise StandardError, "Embedding service offline"
    end

    begin
      get api_v1_search_url, params: { q: "spaghetti" }, as: :json
      assert_response :success
      json = response.parsed_body
      assert_equal "keyword", json["meta"]["mode"]
      assert_equal 1, json["results"].size
      assert_equal @mem2.id, json["results"].first["data"]["id"]
    ensure
      singleton.define_method(:call, original)
    end
  end

  test "respects limit parameter" do
    get api_v1_search_url, params: { q: "e", mode: "keyword", limit: 1 }, as: :json
    assert_response :success
    json = response.parsed_body
    assert_equal 1, json["results"].size
  end
end
