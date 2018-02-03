def create
  create_table(:gesheru) do
    primary_key :id
    String :title, null: false
    DateTime :date, null: false
    String :href, null: true
  end
end
