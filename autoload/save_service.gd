extends Node

const SAVE_PATH := "user://save.json"
const BACKUP_DIR := "user://backups"
const CORRUPT_DIR := "user://corrupt"
const MAX_BACKUPS := 8
const SAVE_VERSION := 4

var save_path: String = SAVE_PATH
var backup_dir: String = BACKUP_DIR
var last_status: String = "missing"


func configure_paths(p_save_path: String, p_backup_dir: String) -> void:
	save_path = p_save_path
	backup_dir = p_backup_dir


func load_game() -> Dictionary:
	last_status = "missing"
	if not FileAccess.file_exists(save_path):
		return {}
	var data := _read_json(save_path)
	if not data.is_empty():
		last_status = "ok"
		return data
	_quarantine_corrupt()
	var backups := list_backups()
	if not backups.is_empty():
		var recovered := _read_json(String(backups[0].get("path", "")))
		if not recovered.is_empty():
			last_status = "recovered"
			_write_primary(recovered)
			return recovered
	last_status = "corrupt"
	return {}


func save_game(data: Dictionary, make_backup: bool = true) -> bool:
	var payload := data.duplicate(true)
	payload["version"] = SAVE_VERSION
	payload["saved_at"] = int(Time.get_unix_time_from_system())
	var temp_path := save_path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write save file")
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	var readback := _read_json(temp_path)
	if readback.is_empty():
		push_error("Save readback failed")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		return false
	if make_backup and FileAccess.file_exists(save_path):
		backup_current("auto")
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(save_path))
	if error != OK:
		push_error("Cannot replace save file: %s" % error_string(error))
		return false
	last_status = "ok"
	return true


func backup_current(label: String = "manual") -> String:
	if not FileAccess.file_exists(save_path):
		return ""
	var text := FileAccess.get_file_as_string(save_path)
	if text.is_empty():
		return ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(backup_dir))
	var stamp := int(Time.get_unix_time_from_system())
	var safe_label := label.strip_edges().replace(" ", "_")
	if safe_label == "":
		safe_label = "manual"
	var path := "%s/save_%d_%s.json" % [backup_dir, stamp, safe_label]
	var counter := 1
	while FileAccess.file_exists(path):
		path = "%s/save_%d_%s_%d.json" % [backup_dir, stamp, safe_label, counter]
		counter += 1
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(text)
	file.close()
	prune_backups()
	return path


func list_backups() -> Array:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(backup_dir))
	var dir := DirAccess.open(backup_dir)
	if dir == null:
		return []
	var result: Array = []
	for file_name in dir.get_files():
		if not String(file_name).ends_with(".json"):
			continue
		var path := backup_dir + "/" + String(file_name)
		var data := _read_json(path)
		var modified := 0
		if not data.is_empty():
			modified = int(data.get("saved_at", 0))
		if modified == 0:
			modified = FileAccess.get_modified_time(path)
		var stars := 0
		var stars_data: Dictionary = data.get("stars", {})
		for value in stars_data.values():
			stars += int(value)
		result.append({
			"path": path,
			"name": String(file_name),
			"modified": modified,
			"version": int(data.get("version", 0)),
			"contracts": data.get("unlocked_contracts", []),
			"stars": stars,
			"favor": data.get("guild_favor", {}),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["modified"]) > int(b["modified"]))
	return result


func restore_backup(path: String) -> Dictionary:
	var data := _read_json(path)
	if data.is_empty():
		return {}
	backup_current("before_restore")
	if not _write_primary(data):
		return {}
	last_status = "restored"
	return data


func new_game_data(defaults: Dictionary) -> Dictionary:
	backup_current("before_new")
	var data: Dictionary = defaults.duplicate(true)
	data["version"] = SAVE_VERSION
	data["saved_at"] = int(Time.get_unix_time_from_system())
	if not _write_primary(data):
		return {}
	last_status = "new"
	return data


func prune_backups() -> void:
	var backups := list_all_backup_files()
	if backups.size() <= MAX_BACKUPS:
		return
	for i in range(MAX_BACKUPS, backups.size()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(String(backups[i])))


func list_all_backup_files() -> Array:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(backup_dir))
	var dir := DirAccess.open(backup_dir)
	if dir == null:
		return []
	var files: Array = []
	for file_name in dir.get_files():
		if String(file_name).ends_with(".json"):
			files.append(backup_dir + "/" + String(file_name))
	files.sort_custom(func(a: String, b: String) -> bool:
		return FileAccess.get_modified_time(a) > FileAccess.get_modified_time(b)
	)
	return files


func _read_json(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data


func _write_primary(data: Dictionary) -> bool:
	var temp_path := save_path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(save_path))
	return error == OK


func _quarantine_corrupt() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CORRUPT_DIR))
	var stamp := int(Time.get_unix_time_from_system())
	var target := "%s/save_%d.json" % [CORRUPT_DIR, stamp]
	DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(target))
