class CreateMessageAnalysis < ActiveRecord::Migration[8.0]
  def change
    create_table :message_analysis do |t|
      t.references :message, null: false, foreign_key: true, index: { unique: true }
      t.integer :importance_level, null: false
      t.text :message_content_summary, null: false
      t.text :message_type, null: false
      t.text :tags
      t.boolean :is_a_response, null: false, default: false

      t.timestamps
    end
  end
end
