Sequel.migration do
  up do
    create_table(:themes) do
      primary_key :id
      String :title, null: false
      String :buddha_node
      Date :begin_date, null: false
      foreign_key :teaching_id, :teachings, type: String, on_delete: :cascade
    end
  end

  down do
    drop_table(:themes)
  end
end
