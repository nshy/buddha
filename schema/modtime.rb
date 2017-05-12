def create
  create_table(:root_docs) do
    String :id, primary_key: true
    DateTime :last_modified, null: false
  end
end
