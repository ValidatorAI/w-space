class AddDescriptionToSkills < ActiveRecord::Migration[8.0]
  def change
    add_column :skills, :description, :text
  end
end
