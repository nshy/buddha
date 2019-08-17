def create
  create_table(:bookshop) do
    primary_key :id
    String :title, null: false
    String :authors, null: false
    String :rel_href, null: true
    String :image, null: true
  end
end
