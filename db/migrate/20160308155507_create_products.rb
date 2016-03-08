class CreateProducts < ActiveRecord::Migration
  def change
    create_table :products do |t|
        t.string :name
        t.text :description
        t.string :url, limit:100
        t.string :meta_title
        t.text :meta_description
        t.text :meta_keywords
      	t.integer :company_id
      	t.float :price # Price we are offering to user
      	t.float :mrp
      	t.float :weight
        t.integer :rank, limit:2 
        t.integer :status, limit:1 , default:0, index: true, comment: "0=>disabled,1=>enabled,2=>Discontinued, 3=>Comming soon"
        t.timestamps null: false
    end
    add_index :products, [:url], unique: true
  end
end