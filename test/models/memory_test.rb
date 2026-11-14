# frozen_string_literal: true

require "test_helper"

class MemoryTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "validates presence of title" do
    memory = Memory.new(title: "")
    assert_not memory.valid?
    assert_includes memory.errors[:title], "can't be blank"

    memory.title = "Valid Title"
    assert memory.valid?
  end

  test "search scope filters by title and body" do
    m1 = Memory.create!(title: "Rails Optimization", body: "Use bullet for N+1 queries")
    m2 = Memory.create!(title: "Python Tips", body: "List comprehensions are fast")

    assert_includes Memory.search("Optimization"), m1
    assert_not_includes Memory.search("Optimization"), m2

    assert_includes Memory.search("bullet"), m1
    assert_not_includes Memory.search("bullet"), m2
  end

  test "toggle_pin! toggles pinned state and manages pinned_position" do
    m1 = Memory.create!(title: "Memory 1")
    m2 = Memory.create!(title: "Memory 2")

    assert_not m1.pinned?
    m1.toggle_pin!
    assert m1.pinned?
    assert_equal 1, m1.pinned_position

    m2.toggle_pin!
    assert m2.pinned?
    assert_equal 2, m2.pinned_position

    assert_equal [ m1, m2 ], Memory.pinned.to_a

    m1.toggle_pin!
    assert_not m1.pinned?
    assert_nil m1.pinned_position
    assert_equal [ m2 ], Memory.pinned.to_a
  end

  test "formats embedding_input with title and body" do
    memory = Memory.new(title: "Architecture Decision", body: "Use pgvector for embeddings.")
    assert_equal "Title: Architecture Decision\n\nUse pgvector for embeddings.", memory.embedding_input

    memory_empty_body = Memory.new(title: "Title Only", body: "")
    assert_equal "Title: Title Only", memory_empty_body.embedding_input
  end

  test "enqueues GenerateEmbeddingJob when title or body changes" do
    assert_enqueued_with(job: GenerateEmbeddingJob) do
      Memory.create!(title: "New Memory", body: "Fresh context")
    end

    memory = Memory.create!(title: "Stable Memory", body: "Unchanged")
    clear_enqueued_jobs

    assert_enqueued_with(job: GenerateEmbeddingJob, args: [ memory.id ]) do
      memory.update!(body: "Updated context")
    end

    clear_enqueued_jobs
    assert_no_enqueued_jobs do
      memory.update!(pinned: true)
    end
  end

  test "generate_embedding! updates vector, model, and timestamp" do
    memory = Memory.create!(title: "Vector Embed Test", body: "Pgvector test")
    fake_vector = Array.new(1024) { |i| (i + 1) * 0.001 }

    singleton = Llm::EmbeddingGenerator.singleton_class
    original = Llm::EmbeddingGenerator.method(:call)
    singleton.define_method(:call) do |_text, **_kwargs|
      { vector: fake_vector, model: "qwen3-embedding:0.6b" }
    end

    begin
      memory.generate_embedding!
      memory.reload
      assert memory.embedded?
      assert_equal 1024, memory.embedding.to_a.size
      assert_equal "qwen3-embedding:0.6b", memory.embedding_model
      assert_not_nil memory.embedded_at
    ensure
      singleton.define_method(:call, original)
    end
  end

  test "nearest_neighbors finds semantically closest memories via cosine distance" do
    v1 = Array.new(1024, 0.0)
    v1[0] = 1.0

    v2 = Array.new(1024, 0.0)
    v2[0] = 0.9
    v2[1] = 0.1

    v3 = Array.new(1024, 0.0)
    v3[500] = 1.0

    m1 = Memory.create!(title: "Memory 1", embedding: v1, embedding_model: "test", embedded_at: Time.current)
    m2 = Memory.create!(title: "Memory 2 (Close)", embedding: v2, embedding_model: "test", embedded_at: Time.current)
    m3 = Memory.create!(title: "Memory 3 (Distant)", embedding: v3, embedding_model: "test", embedded_at: Time.current)

    results = Memory.where.not(id: m1.id).embedded.nearest_neighbors(:embedding, v1, distance: "cosine").to_a
    assert_equal m2.id, results.first.id
    assert results.first.neighbor_distance < results.last.neighbor_distance
  end
end
