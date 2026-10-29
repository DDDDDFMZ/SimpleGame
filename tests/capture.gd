extends SceneTree


func _initialize() -> void:
	var dir := ProjectSettings.globalize_path("res://build")
	DirAccess.make_dir_recursive_absolute(dir)

	var scene: Node = load("res://scenes/battle.tscn").instantiate()
	root.add_child(scene)

	await create_timer(22.0).timeout
	await RenderingServer.frame_post_draw

	var image := root.get_texture().get_image()
	var path := dir.path_join("m2_screenshot.png")
	var err := image.save_png(path)
	print("screenshot: %s (%s)" % [path, error_string(err)])

	var hud: Control = scene.get_node("HUD/Root")
	hud.panel_open = true
	hud.queue_redraw()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var panel_image := root.get_texture().get_image()
	var panel_path := dir.path_join("m2_buildings.png")
	var panel_err := panel_image.save_png(panel_path)
	print("screenshot: %s (%s)" % [panel_path, error_string(panel_err)])
	quit(0 if err == OK and panel_err == OK else 1)
