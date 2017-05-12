def create
  create_table(:top_categories) do
    primary_key :id
    String :section, null: false
    String :category_id, null: false
  end
end
