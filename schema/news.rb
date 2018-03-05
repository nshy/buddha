def create
  create_table(:news) do
    String :id
    String :path, unique: true
    DateTime :date, null: false
    String :title, null: false
    String :cut
    String :body, null: false
    Boolean :is_dir, null: false
    String :scripts
    String :buddha_node
    TrueClass :hidden, default: false
    TrueClass :pin, default: false
    DateTime :mtime
  end
end
