# frozen_string_literal: true

class GenerateEmbeddingJob < ApplicationJob
  queue_as :default

  def perform(memory_id)
    memory = Memory.find_by(id: memory_id)
    return unless memory

    memory.generate_embedding!
  rescue StandardError => e
    Rails.logger.error("[GenerateEmbeddingJob] Memory##{memory_id} #{e.class}: #{e.message}")
    raise e if Rails.env.test? && !called_via_perform_later?
  end

  private

  def called_via_perform_later?
    job_id.present?
  end
end
