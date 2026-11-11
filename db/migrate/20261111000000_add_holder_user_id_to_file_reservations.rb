class AddHolderUserIdToFileReservations < ActiveRecord::Migration[8.0]
  def change
    add_column :file_reservations, :holder_user_id, :integer
    add_index :file_reservations, :holder_user_id
  end
end
