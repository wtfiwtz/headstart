json.extract! <%= singular %>, :id, :name, :email, :password, :created_at, :updated_at
json.url <%= singular %>_url(<%= singular %>, format: :json)
