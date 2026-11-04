extends Node

## Personalization settings live in their own file so they survive new games,
## backup restores, and corrupt-save recovery. Progress remains in save.json.

const DEFAULT_PATH := "user://settings.json"
const CORRUPT_DIR := "user://corrupt"
const VERSION := 1
const BASE_WINDOW := Vector2i(1280, 720)
const ZOOM_CHOICES := [0.6, 0.8, 1.0, 1.2]
const WINDOW_SCALES := [1.0, 1.25, 1.5]

var settings_path: String = DEFAULT_PATH
var corrupt_dir: String = CORRUPT_DIR
var data: Dictionary = {}
var was_missing: bool = true


func _ready() -> void:
	load_settings()


func _defaults() -> Dictionary:
	return {
		"version": VERSION,
		"default_zoom": 0.8,
		"window_scale": 1.0,
		"fullscreen": false,
		"station_order": [],
	}


func configure_paths(p_settings_path: String, p_corrupt_dir: String = CORRUPT_DIR) -> void:
	settings_path = p_settings_path
	corrupt_dir = p_corrupt_dir


func load_settings() -> void:
	was_missing = not FileAccess.file_exists(settings_path)
	data = _defaults()
	if not was_missing:
		var loaded := _read_json(settings_path)
		if loaded.is_empty():
			_quarantine()
			# Replace the corrupt source with defaults so the next launch does
			# not quarantine the same broken file again.
			save_settings()
		else:
			for key in _defaults():
				if loaded.has(key):
					data[key] = loaded[key]
	_validate()
	apply_display()


func save_settings() -> bool:
	_validate()
	var temp_path := settings_path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var check := _read_json(temp_path)
	if check.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		return false
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(settings_path))
	if error != OK:
		return false
	was_missing = false
	return true


func migrate_from_legacy(legacy: Dictionary, default_order: Array = []) -> void:
	if not was_missing or legacy.is_empty():
		return
	if legacy.has("station_order") and legacy["station_order"] is Array:
		data["station_order"] = legacy["station_order"].duplicate()
	if legacy.has("default_zoom"):
		data["default_zoom"] = legacy["default_zoom"]
	_validate(default_order)
	save_settings()


func bind_unit_order(default_order: Array) -> void:
	var before: Array = data.get("station_order", []).duplicate()
	var order := station_order(default_order)
	if order != before:
		data["station_order"] = order
		save_settings()


func _validate(default_order: Array = []) -> void:
	var zoom := float(data.get("default_zoom", 0.8))
	var best_zoom: float = ZOOM_CHOICES[0]
	for candidate in ZOOM_CHOICES:
		if absf(float(candidate) - zoom) < absf(best_zoom - zoom):
			best_zoom = float(candidate)
	data["default_zoom"] = best_zoom
	var scale := float(data.get("window_scale", 1.0))
	var best_scale := 1.0
	for candidate in WINDOW_SCALES:
		if absf(float(candidate) - scale) < absf(best_scale - scale):
			best_scale = float(candidate)
	data["window_scale"] = best_scale
	data["fullscreen"] = bool(data.get("fullscreen", false))
	var order: Array = []
	var raw: Variant = data.get("station_order", [])
	if raw is Array:
		for value in raw:
			var def_id := String(value)
			if not order.has(def_id):
				order.append(def_id)
	if not default_order.is_empty():
		var filtered: Array = []
		for def_id in order:
			if default_order.has(def_id):
				filtered.append(def_id)
		for def_id in default_order:
			if not filtered.has(String(def_id)):
				filtered.append(String(def_id))
		order = filtered
	data["station_order"] = order
	data["version"] = VERSION


func station_order(default_order: Array = []) -> Array:
	if not default_order.is_empty():
		_validate(default_order)
	return data.get("station_order", []).duplicate()


func set_station_order(order: Array, default_order: Array = []) -> void:
	data["station_order"] = order.duplicate()
	_validate(default_order)
	save_settings()


func get_default_zoom() -> float:
	return float(data.get("default_zoom", 0.8))


func set_default_zoom(value: float) -> void:
	data["default_zoom"] = value
	_validate()
	save_settings()


func get_window_scale() -> float:
	return float(data.get("window_scale", 1.0))


func set_window_scale(value: float) -> void:
	data["window_scale"] = value
	_validate()
	apply_display()
	save_settings()


func is_fullscreen() -> bool:
	return bool(data.get("fullscreen", false))


func set_fullscreen(value: bool) -> void:
	data["fullscreen"] = value
	_validate()
	apply_display()
	save_settings()


func reset_defaults(default_order: Array = []) -> void:
	data = _defaults()
	data["station_order"] = default_order.duplicate()
	_validate(default_order)
	save_settings()
	apply_display()


func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var scale := get_window_scale()
	if is_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(int(BASE_WINDOW.x * scale), int(BASE_WINDOW.y * scale)))


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


func _quarantine() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(corrupt_dir))
	var stamp := int(Time.get_unix_time_from_system())
	var target := "%s/settings_%d.json" % [corrupt_dir, stamp]
	var suffix := 1
	while FileAccess.file_exists(target):
		target = "%s/settings_%d_%d.json" % [corrupt_dir, stamp, suffix]
		suffix += 1
	var source_path := ProjectSettings.globalize_path(settings_path)
	var target_path := ProjectSettings.globalize_path(target)
	var moved := DirAccess.rename_absolute(source_path, target_path)
	if moved != OK:
		DirAccess.copy_absolute(source_path, target_path)
		DirAccess.remove_absolute(source_path)
