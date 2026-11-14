# frozen_string_literal: true

class EnablePgvectorAndAddMemoryEmbeddings < ActiveRecord::Migration[8.1]
  def change
    enable_extension "vector"

    change_table :memories, bulk: true do |t|
      t.column :embedding, :vector, limit: 1024
      t.string :embedding_model
      t.datetime :embedded_at
    end

    add_index :memories, :embedding, using: :hnsw, opclass: :vector_cosine_ops
  end
end
