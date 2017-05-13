def create
  create_table(:book_categories) do
    String :id, primary_key: true
    String :name, null: false
    DateTime :last_modified
  end

  create_table(:category_books) do
    String :book_id, null: false
    foreign_key :category_id, :book_categories, type: String, on_delete: :cascade
    String :group, null:false
  end

  create_table(:category_subcategories) do
    foreign_key :category_id, :book_categories, type: String, on_delete: :cascade
    String :subcategory_id, null: false
  end
end
