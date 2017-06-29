def create
  create_table(:book_categories) do
    String :id
    String :path, unique: true
    String :name, null: false
    DateTime :last_modified
  end

  create_table(:category_books) do
    String :book_id, null: false
    foreign_key :category_path, :book_categories,
      key: :path, type: String, on_delete: :cascade
    String :category_id, null: false
    String :group, null: false
  end

  create_table(:category_subcategories) do
    foreign_key :category_path, :book_categories,
      key: :path, type: String, on_delete: :cascade
    String :category_id, null: false
    String :subcategory_id, null: false
  end
end
