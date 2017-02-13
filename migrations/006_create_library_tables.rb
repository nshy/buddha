Sequel.migration do
  up do
    create_table(:books) do
      String :url, primary_key: true
      String :title, null: false
      String :authors
      String :translators
      Integer :year
      String :isbn
      String :publisher
      Integer :amount
      String :annotation
      String :contents
      String :outer_id
      DateTime :last_modified, null: false
      Date :added
    end

    create_table(:book_categories) do
      String :url, primary_key: true
      String :name, null: false
      DateTime :last_modified, null: false
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

    create_table(:top_categories) do
      primary_key :id
      String :section, null: false
      String :category_id, null: false
    end

  end

  down do
    drop_table(:book_categories)
    drop_table(:books)
    drop_table(:category_books)
    drop_table(:category_subcategories)
    drop_table(:top_categories)
  end
end
