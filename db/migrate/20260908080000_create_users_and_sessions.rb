class CreateUsersAndSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.bigint :github_id, null: false
      t.string :login, null: false
      t.string :name
      t.string :avatar_url
      t.timestamps
    end
    add_index :users, :github_id, unique: true
    add_index :users, :login

    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end
  end
end
