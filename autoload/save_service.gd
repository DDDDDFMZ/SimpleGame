extends Node

const SAVE_PATH := "user://save.json"


func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Save file is not a dictionary")
		return {}
	return parsed


func save_game(data: Dictionary) -> bool:
	var temp_path := SAVE_PATH + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write save file")
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	var absolute_temp := ProjectSettings.globalize_path(temp_path)
	var absolute_save := ProjectSettings.globalize_path(SAVE_PATH)
	var error := DirAccess.rename_absolute(absolute_temp, absolute_save)
	if error != OK:
		push_error("Cannot replace save file: %s" % error_string(error))
		return false
	return true
