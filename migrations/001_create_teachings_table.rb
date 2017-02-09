Sequel.migration do
  up do
    create_table(:teachings) do
      primary_key :id
      String :url, unique: true, null: false
      String :title, null: false
      DateTime :last_modified, null: false
    end
  end

  down do
    drop_table(:teachings)
  end
end
