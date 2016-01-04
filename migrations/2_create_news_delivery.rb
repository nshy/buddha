Sequel.migration do
  up do
    create_table :delivery do
      primary_key :id
      Fixnum :type
      String :rid
      unique [:type, :rid]
    end
  end

  down do
    drop_table :delivery
  end
end
