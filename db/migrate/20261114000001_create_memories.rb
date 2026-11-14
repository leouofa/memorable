class CreateMemories < ActiveRecord::Migration[8.1]
  def change
    create_table :memories do |t|
      t.string :title, null: false
      t.text :body, null: false, default: ""
      t.boolean :pinned, null: false, default: false
      t.integer :pinned_position

      t.timestamps
    end

    add_index :memories, :updated_at
    add_index :memories, [ :pinned, :pinned_position ]
  end
end
