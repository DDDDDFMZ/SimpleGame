extends SceneTree


func _initialize() -> void:
	var data := GameData.new()
	var ok := data.load_all()
	if ok and data.errors.is_empty():
		print("DATA VALID: units=%d guilds=%d" % [data.unit_defs.size(), data.guild_defs.size()])
		quit(0)
	else:
		for err in data.errors:
			printerr(err)
		quit(1)
