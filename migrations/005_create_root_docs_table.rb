Sequel.migration do
  up do
    create_table(:root_docs) do
      String :url, primary_key: true
      DateTime :last_modified, null: false
    end
  end

  down do
    drop_table(:root_docs)
  end
end
