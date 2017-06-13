def create
  create_table(:news) do
    String :id, primary_key: true
    String :path, unique: true
    DateTime :date, null: false
    String :title, null: false
    String :cut
    String :body, null: false
    Boolean :is_dir, null: false
    String :buddha_node
    DateTime :last_modified
  end
end
