def create
  create_table(:digests) do
    String :id, primary_key: true
    String :path, unique: true
    String :digest, null: false
    DateTime :last_modified
  end
end
