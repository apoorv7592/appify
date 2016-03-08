class CreateCategories < ActiveRecord::Migration
  def change
    create_table :categories do |t|
      t.string :name, null:false
      t.string :title
      t.text :description
      t.integer :parent_id, index: true
      t.integer :status, default:1, limit:1, index: true, comment: "0=>disable,1=>enable,2=>permanently discontinued"
      t.string :url
      t.string :meta_title
      t.text :meta_description
      t.text :meta_keywords
      t.timestamps null: false
    end
    add_index :categories, [:url], unique: true
  end
end