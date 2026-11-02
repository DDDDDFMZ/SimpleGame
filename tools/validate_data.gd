extends SceneTree


func _initialize() -> void:
	var data := GameData.new()
	var ok := data.load_all()
	if ok and data.errors.is_empty():
		print("DATA VALID: units=%d guilds=%d maps=%d levels=%d" % [data.unit_defs.size(), data.guild_defs.size(), data.get_map_count(), data.level_paths.size()])
		quit(0)
	else:
		for err in data.errors:
			printerr(err)
		quit(1)
