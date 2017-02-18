Sequel.migration do
  up do
    create_table(:digests) do
      String :id, primary_key: true
      String :digest, null: false
      DateTime :last_modified, null: false
    end
  end

  down do
    drop_table(:digests)
  end
end
