Sequel.migration do
  up do
    create_table(:teachings) do
      String :id, primary_key: true
      String :title, null: false
      DateTime :last_modified, null: false
    end
  end

  down do
    drop_table(:teachings)
  end
end
