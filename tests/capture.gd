extends SceneTree


func _initialize() -> void:
	var dir := ProjectSettings.globalize_path("res://build")
	DirAccess.make_dir_recursive_absolute(dir)

	var scene: Node = load("res://scenes/battle.tscn").instantiate()
	root.add_child(scene)

	await create_timer(16.0).timeout
	await RenderingServer.frame_post_draw

	var image := root.get_texture().get_image()
	var path := dir.path_join("m1_screenshot.png")
	var err := image.save_png(path)
	print("screenshot: %s (%s)" % [path, error_string(err)])
	quit(0 if err == OK else 1)
