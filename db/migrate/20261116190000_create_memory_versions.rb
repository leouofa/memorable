# frozen_string_literal: true

class CreateMemoryVersions < ActiveRecord::Migration[8.1]
  def up
    create_table :memory_versions do |t|
      t.references :memory, null: false, foreign_key: { on_delete: :cascade }
      t.integer :version_number, null: false
      t.string :title, null: false
      t.text :body, default: "", null: false
      t.datetime :created_at, null: false
    end

    add_index :memory_versions, %i[memory_id version_number], unique: true
    add_index :memory_versions, %i[memory_id created_at]

    execute <<~SQL.squish
      INSERT INTO memory_versions (memory_id, version_number, title, body, created_at)
      SELECT id, 1, title, body, created_at
      FROM memories
    SQL
  end

  def down
    drop_table :memory_versions
  end
end
