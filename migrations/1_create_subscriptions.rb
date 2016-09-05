Sequel.migration do
  up do
    create_table :subscriptions do
      primary_key :id
      String :email, unique: true
      String :key, unique: true
    end
  end

  down do
    drop_table :subscriptions
  end
end
