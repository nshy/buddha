def create
  create_table(:errors) do
    String :path, primary_key: true
    String :message, null: false
  end
end
