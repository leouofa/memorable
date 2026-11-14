# frozen_string_literal: true

require "test_helper"

class GenerateEmbeddingJobTest < ActiveJob::TestCase
  test "performs embedding generation on memory" do
    memory = Memory.create!(title: "Test Memory", body: "Job test content")
    fake_vector = Array.new(1024) { 0.05 }

    singleton = Llm::EmbeddingGenerator.singleton_class
    original = Llm::EmbeddingGenerator.method(:call)
    singleton.define_method(:call) do |_text, **_kwargs|
      { vector: fake_vector, model: "qwen3-embedding:0.6b" }
    end

    begin
      GenerateEmbeddingJob.perform_now(memory.id)
      memory.reload
      assert memory.embedded?
      assert_equal "qwen3-embedding:0.6b", memory.embedding_model
      assert_not_nil memory.embedded_at
    ensure
      singleton.define_method(:call, original)
    end
  end

  test "gracefully handles deleted memory" do
    assert_nothing_raised do
      GenerateEmbeddingJob.perform_now(-9999)
    end
  end
end
