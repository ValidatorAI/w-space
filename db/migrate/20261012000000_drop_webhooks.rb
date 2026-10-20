class DropWebhooks < ActiveRecord::Migration[7.2]
  def change
    drop_table :webhooks, if_exists: true
  end
end
