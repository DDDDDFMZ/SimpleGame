extends SceneTree


func _initialize() -> void:
	var select_scene: Node = load("res://main/level_select.tscn").instantiate()
	root.add_child(select_scene)
	await process_frame
	var gs := root.get_node_or_null("GameState")
	if gs == null:
		printerr("GameState autoload missing")
		quit(1)
		return
	if not gs.select_contract(1):
		printerr("contract 1 should be unlocked")
		quit(1)
		return
	select_scene._start_contract(1)
	await process_frame
	await process_frame
	var current := current_scene
	if current == null:
		printerr("no current scene after start")
		quit(1)
		return
	print("FLOW PASS scene=", current.name)
	quit(0)
