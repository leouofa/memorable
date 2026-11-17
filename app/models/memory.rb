# frozen_string_literal: true

class Memory < ApplicationRecord
  include Embeddable

  attr_accessor :skip_versioning

  has_many_attached :files
  has_many :versions, -> { order(version_number: :desc) },
           class_name: "MemoryVersion",
           dependent: :destroy,
           inverse_of: :memory

  validates :title, presence: true

  after_create :record_version_snapshot!
  after_update :record_version_snapshot!, unless: :skip_versioning
  after_commit :enqueue_generate_embedding, on: %i[create update], if: :saved_change_to_embedding_content?

  scope :recent, -> { order(updated_at: :desc) }
  scope :pinned, -> { where(pinned: true).order(Arel.sql("pinned_position ASC NULLS LAST, updated_at DESC")) }
  scope :search, ->(query) {
    return all if query.blank?
    where("title ILIKE :q OR body ILIKE :q", q: "%#{sanitize_sql_like(query.to_s.strip)}%")
  }

  def embedding_input
    [ "Title: #{title}", body.presence ].compact.join("\n\n")
  end

  def toggle_pin!
    if pinned?
      update!(pinned: false, pinned_position: nil)
    else
      max_pos = Memory.where(pinned: true).maximum(:pinned_position) || 0
      update!(pinned: true, pinned_position: max_pos + 1)
    end
  end

  def latest_version
    versions.reorder(version_number: :desc).first
  end

  def current_version_number
    versions.maximum(:version_number) || 1
  end

  def unversioned_changes?
    latest = latest_version
    return true if latest.nil?

    latest.title != title || latest.body != body
  end

  def record_version_snapshot!
    return unless unversioned_changes?

    next_number = (versions.maximum(:version_number) || 0) + 1
    versions.create!(
      version_number: next_number,
      title: title,
      body: body
    )
  end

  def restore_version!(version)
    transaction do
      record_version_snapshot! if unversioned_changes?
      self.skip_versioning = false
      update!(title: version.title, body: version.body)
      record_version_snapshot!
    end
  end

  private

  def saved_change_to_embedding_content?
    saved_change_to_title? || saved_change_to_body?
  end

  def enqueue_generate_embedding
    GenerateEmbeddingJob.perform_later(id)
  end
end
