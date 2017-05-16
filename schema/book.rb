def create
  create_table(:books) do
    String :id, primary_key: true
    String :path, unique: true
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
    DateTime :last_modified
    Date :added
  end
end
