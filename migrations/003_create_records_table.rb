Sequel.migration do
  up do
    create_table(:records) do
      primary_key :id
      Date :record_date, null: false
      String :description
      String :audio_url
      Integer :audio_size
      String :youtube_id
      foreign_key :theme_id, :themes, on_delete: :cascade
    end
  end

  down do
    drop_table(:records)
  end
end
