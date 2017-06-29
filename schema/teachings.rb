def create
  create_table(:teachings) do
    String :id
    String :path, unique: true
    String :title, null: false
    DateTime :last_modified
  end

  create_table(:themes) do
    primary_key :id
    String :title, null: false
    String :buddha_node
    Date :begin_date, null: false
    foreign_key :teaching_path, :teachings,
      key: :path, type: String, on_delete: :cascade
    String :teaching_id, null: false
  end

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
