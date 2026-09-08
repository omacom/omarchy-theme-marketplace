# Self-Referential Associations

A model that references itself — trees, hierarchies, and social graphs.

---

## Tree Structure (Parent-Child)

```ruby
class Category < ApplicationRecord
  belongs_to :parent, class_name: "Category", optional: true
  has_many :children, class_name: "Category", foreign_key: "parent_id",
           dependent: :destroy, inverse_of: :parent
end
```

Migration:
```ruby
create_table :categories do |t|
  t.string :name
  t.references :parent, foreign_key: { to_table: :categories }
  t.timestamps
end
```

**Note:** `foreign_key: { to_table: :categories }` — critical for self-joins. Without `to_table`, Rails looks for a `parents` table.

## Manager-Employee

```ruby
class Employee < ApplicationRecord
  belongs_to :manager, class_name: "Employee", optional: true
  has_many :subordinates, class_name: "Employee", foreign_key: "manager_id",
           dependent: :nullify, inverse_of: :manager
end
```

## Social Follow/Friend

```ruby
class User < ApplicationRecord
  # Users I follow
  has_many :active_follows, class_name: "Follow", foreign_key: "follower_id",
           dependent: :destroy
  has_many :following, through: :active_follows, source: :followed

  # Users following me
  has_many :passive_follows, class_name: "Follow", foreign_key: "followed_id",
           dependent: :destroy
  has_many :followers, through: :passive_follows, source: :follower
end

class Follow < ApplicationRecord
  belongs_to :follower, class_name: "User"
  belongs_to :followed, class_name: "User"

  validates :follower_id, uniqueness: { scope: :followed_id }
end
```

Migration:
```ruby
create_table :follows do |t|
  t.references :follower, null: false, foreign_key: { to_table: :users }
  t.references :followed, null: false, foreign_key: { to_table: :users }
  t.timestamps
end
add_index :follows, [:follower_id, :followed_id], unique: true
```
