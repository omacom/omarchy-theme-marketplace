class CreateEngagement < ActiveRecord::Migration[8.1]
  def change
    create_table :likes do |t|
      t.references :user, null: false, foreign_key: true
      t.string :slug, null: false
      t.timestamps
    end
    add_index :likes, [ :user_id, :slug ], unique: true
    add_index :likes, :slug

    # How often the install command was copied on the site, per theme per day. Anonymous.
    # (Real install counts arrive with the Omarchy client and its ping.)
    create_table :command_copies do |t|
      t.string :slug, null: false
      t.date :day, null: false
      t.integer :count, null: false, default: 0
      t.timestamps
    end
    add_index :command_copies, [ :slug, :day ], unique: true
  end
end
