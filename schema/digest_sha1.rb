def create
  create_table(:digest_sha1s) do
    String :id
    String :path, unique: true
    String :sha1, null: false
    DateTime :mtime
  end
end
