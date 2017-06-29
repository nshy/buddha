def create
  create_table(:digests) do
    String :id
    String :path, unique: true
    String :digest, null: false
    DateTime :last_modified
  end
end
