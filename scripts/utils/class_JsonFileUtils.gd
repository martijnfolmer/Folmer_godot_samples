# res://scripts/utils/class_JsonFileUtils.gd
class_name JsonFileUtils

'''
	Usage : 
	func write_and_read_json() -> void:
		#var path := "user://save_data.json"	# the example says this, but I could not tell you where this ended up
		var path := "res://json/save_data.json"

		var save_data := {
			"player_name": "Martijn",
			"level": 3,
			"hp": 87,
			"items": ["key", "potion"]
		}

		var ok := JsonFileUtils.write_json_file(path, save_data)
		if ok:
			print("Saved JSON to ", path)

		var loaded = JsonFileUtils.read_json_file(path)
		if loaded != null:
			print("Loaded JSON: ", loaded)

'''


static func read_json_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("JSON file does not exist: %s" % path)
		return null

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open file for reading: %s" % path)
		return null

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error(
			"Failed to parse JSON in %s at line %d: %s" %
			[path, json.get_error_line(), json.get_error_message()]
		)
		return null

	return json.data


static func write_json_file(path: String, data: Variant, indent: String = "\t") -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open file for writing: %s" % path)
		return false

	var json_text := JSON.stringify(data, indent)
	file.store_string(json_text)
	file.close()
	return true
