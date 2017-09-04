def create
  create_table(:digest_uuids) do
    String :id
    String :path, unique: true
    String :uuid
    DateTime :mtime
  end
end
