extends Control

## Debug-only two-lane map editor for M6. It edits the same JSON that BattleSim
## consumes. It is not a player-facing graph editor; M7 will replace this view.

const VIEW_W := 640.0
const VIEW_H := 360.0
const TOP_H := 28.0
const WORLD_ORIGIN := Vector2(0.0, 42.0)
const ZOOM := 0.4
const PANEL_Y := 196.0
const MIN_SEGMENT_LENGTH := 24.0

var font: Font
var map_paths: Array = []
var map_index: int = 0
var map: MapData
var levels: Array = []
var selected_kind: String = ""
var selected_lane: int = 0
var selected_segment: int = 0
var dragging: bool = false
var dirty: bool = false
var status: String = ""
var status_color: Color = Color("#8A8498")
var validation_errors: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "SimHei"])
	font = system_font
	_scan_maps()
	if map_paths.is_empty():
		status = "未找到 res://data/maps/*.json"
		status_color = Color("#E06666")
	else:
		_load_map(0)
	queue_redraw()


func _scan_maps() -> void:
	map_paths.clear()
	var dir := DirAccess.open("res://data/maps")
	if dir != null:
		var names: Array = dir.get_files()
		names.sort()
		for file_name in names:
			if String(file_name).ends_with(".json"):
				map_paths.append("res://data/maps/" + String(file_name))
	if map_paths.is_empty():
		for fallback in ["res://data/maps/greyhaven_road.json", "res://data/maps/mistmarsh_road.json"]:
			if FileAccess.file_exists(fallback):
				map_paths.append(fallback)


func _load_map(index: int) -> void:
	if map_paths.is_empty():
		return
	map_index = posmod(index, map_paths.size())
	map = MapData.load_file(String(map_paths[map_index]))
	selected_kind = ""
	selected_lane = 0
	selected_segment = 0
	dragging = false
	dirty = false
	validation_errors = map.errors.duplicate()
	status = "已载入 %s" % String(map_paths[map_index]).get_file()
	status_color = Color("#6FA8DC") if validation_errors.is_empty() else Color("#E06666")
	_load_levels_for_map()
	queue_redraw()


func _load_levels_for_map() -> void:
	levels.clear()
	var level_paths: Array = []
	for contract in GameState.get_contracts():
		level_paths.append({"contract": int(contract), "path": GameState.get_level_path(int(contract)), "endless": false})
	level_paths.append({"contract": 0, "path": GameState.get_endless_path(), "endless": true})
	for entry in level_paths:
		var path := String(entry["path"])
		if path == "":
			continue
		var text := FileAccess.get_file_as_string(path)
		if text.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(text)
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var level: Dictionary = parsed
		if String(level.get("map", "")) != map.source_path:
			continue
		levels.append({
			"contract": int(entry["contract"]),
			"endless": bool(entry["endless"]),
			"name": String(level.get("name_cn", level.get("name", ""))),
			"waves": level.get("waves", []),
		})


func _draw() -> void:
	if font == null:
		return
	draw_rect(Rect2(0.0, 0.0, VIEW_W, VIEW_H), Color("#15121E"))
	draw_rect(Rect2(0.0, 0.0, VIEW_W, TOP_H), Color("#0C0A12"))
	draw_string(font, Vector2(8.0, 18.0), "地图编辑器（调试）", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color("#E8D5A9"))
	draw_string(font, Vector2(168.0, 18.0), "M6：两条直线路 · 路宽段 · 基地 · 出生点", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#8A8498"))
	if map != null:
		draw_string(font, Vector2(470.0, 18.0), "%s  [Tab 切换]" % map.name_cn, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#6FA8DC"))

	_draw_world()
	_draw_panel()


func _draw_world() -> void:
	if map == null:
		return
	var world_rect := Rect2(WORLD_ORIGIN.x, WORLD_ORIGIN.y, map.world_width * ZOOM, map.world_height * ZOOM)
	draw_rect(world_rect, Color("#1E1A2B"))
	draw_rect(world_rect, Color("#3E3A4A"), false, 1.0)

	var player_base := map.base_x(0)
	var enemy_base := map.base_x(1)
	for lane in range(map.route_count()):
		var route := map.route(lane)
		var y := float(route.get("y", 180.0))
		for segment_index in range(route.get("segments", []).size()):
			var segment: Dictionary = route["segments"][segment_index]
			var from_x := float(segment.get("from", player_base))
			var to_x := float(segment.get("to", enemy_base))
			var width := float(segment.get("width", 80.0))
			var road := Rect2(
				WORLD_ORIGIN.x + from_x * ZOOM,
				WORLD_ORIGIN.y + (y - width * 0.5) * ZOOM,
				(to_x - from_x) * ZOOM,
				width * ZOOM
			)
			var fill := Color("#302C3D")
			if selected_kind == "segment" and lane == selected_lane and segment_index == selected_segment:
				fill = Color("#4A3A28")
			draw_rect(road, fill)
			draw_rect(road, Color("#D9A441") if selected_kind == "segment" and lane == selected_lane and segment_index == selected_segment else Color("#4A4658"), false, 1.0)
			draw_string(font, road.position + Vector2(3.0, 9.0), "%d" % int(width), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#8A8498"))
		draw_line(_world_point(player_base, y), _world_point(enemy_base, y), Color(0.85, 0.65, 0.25, 0.65), 1.0)
		var first_width := 80.0
		var route_segments: Array = route.get("segments", [])
		if not route_segments.is_empty():
			first_width = float(route_segments[0].get("width", 80.0))
		var route_label_pos := Vector2(
			WORLD_ORIGIN.x + (player_base + 8.0) * ZOOM,
			WORLD_ORIGIN.y + (y - first_width * 0.5) * ZOOM - 5.0
		)
		draw_string(font, route_label_pos, "%s  y=%d" % [map.route_name(lane), int(y)], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#B8B0C8"))
		draw_colored_polygon(PackedVector2Array([
			_world_point(float(route.get("player_spawn_x", player_base + 12.0)), y) + Vector2(0.0, -4.0),
			_world_point(float(route.get("player_spawn_x", player_base + 12.0)), y) + Vector2(5.0, 4.0),
			_world_point(float(route.get("player_spawn_x", player_base + 12.0)), y) + Vector2(-5.0, 4.0),
		]), Color("#6FA8DC"))
		draw_colored_polygon(PackedVector2Array([
			_world_point(float(route.get("enemy_spawn_x", enemy_base - 12.0)), y) + Vector2(0.0, -4.0),
			_world_point(float(route.get("enemy_spawn_x", enemy_base - 12.0)), y) + Vector2(5.0, 4.0),
			_world_point(float(route.get("enemy_spawn_x", enemy_base - 12.0)), y) + Vector2(-5.0, 4.0),
		]), Color("#E06666"))

	for team in [0, 1]:
		var base_x := map.base_x(team)
		var x := WORLD_ORIGIN.x + base_x * ZOOM
		var color := Color("#6FA8DC") if team == 0 else Color("#E06666")
		draw_rect(Rect2(x - 4.0, WORLD_ORIGIN.y + 2.0, 8.0, map.world_height * ZOOM - 4.0), color)
		draw_rect(Rect2(x - 6.0, WORLD_ORIGIN.y + 2.0, 12.0, map.world_height * ZOOM - 4.0), Color("#D9A441") if selected_kind == "base" and selected_lane == team else color, false, 1.5)
		draw_string(font, Vector2(x - 14.0, WORLD_ORIGIN.y - 4.0), map.base_name(team), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, color)


func _draw_panel() -> void:
	draw_rect(Rect2(0.0, PANEL_Y, VIEW_W, VIEW_H - PANEL_Y), Color("#0C0A12"))
	draw_line(Vector2(0.0, PANEL_Y), Vector2(VIEW_W, PANEL_Y), Color("#3E3A4A"), 1.0)
	var x := 10.0
	var y := PANEL_Y + 14.0
	if map != null:
		draw_string(font, Vector2(x, y), "地图：%s   基地 %d→%d   路线 %d 条" % [map.name_cn, int(map.base_x(0)), int(map.base_x(1)), map.route_count()], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#E8D5A9"))
		y += 14.0
		draw_string(font, Vector2(x, y), _selection_text(), HORIZONTAL_ALIGNMENT_LEFT, 326.0, 8, Color("#D9A441"))
		y += 14.0
	draw_string(font, Vector2(x, y), "拖动基地改 X · 拖动道路改宽度 · Shift+拖动改路线 Y", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#8A8498"))
	y += 12.0
	draw_string(font, Vector2(x, y), "N 切分宽度段 · Delete 删除段 · [ / ] 调宽", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#8A8498"))
	y += 12.0
	draw_string(font, Vector2(x, y), "F5 保存 · F8 校验 · F9 重载 · Tab 切图 · Esc 返回", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#8A8498"))
	y += 13.0
	draw_string(font, Vector2(x, y), "蓝三角=我方出生点  红三角=敌方出生点  数字=该段宽度", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#6B6B6B"))
	y += 13.0
	var status_text := status
	if dirty:
		status_text += "（未保存）"
	draw_string(font, Vector2(x, y), status_text, HORIZONTAL_ALIGNMENT_LEFT, 326.0, 8, status_color)
	if not validation_errors.is_empty():
		draw_string(font, Vector2(x, y + 13.0), "校验错误：%s" % String(validation_errors[0]), HORIZONTAL_ALIGNMENT_LEFT, 326.0, 7, Color("#E06666"))

	# Reference wave timeline for every level that references this map.
	draw_line(Vector2(344.0, PANEL_Y + 8.0), Vector2(344.0, VIEW_H - 8.0), Color("#3E3A4A"), 1.0)
	draw_string(font, Vector2(354.0, PANEL_Y + 16.0), "参考波次（只读）", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#6FA8DC"))
	var wy := PANEL_Y + 31.0
	for entry in levels:
		if wy > VIEW_H - 16.0:
			break
		var title := String(entry["name"])
		if bool(entry["endless"]):
			title = "无尽悬赏"
		else:
			title = "委托%d %s" % [int(entry["contract"]), String(entry["name"])]
		var waves: Array = entry["waves"]
		if waves.is_empty():
			draw_string(font, Vector2(354.0, wy), "%s：动态波次" % title, HORIZONTAL_ALIGNMENT_LEFT, 276.0, 7, Color("#B8B0C8"))
			wy += 12.0
			continue
		var times: Array = []
		var unit_count := 0
		for wave in waves:
			times.append("%d" % int(float(wave.get("time", 0.0))))
			for spawn in wave.get("spawns", []):
				unit_count += int(spawn.get("count", 1))
		draw_string(font, Vector2(354.0, wy), "%s：%d波 / %d单位" % [title, waves.size(), unit_count], HORIZONTAL_ALIGNMENT_LEFT, 276.0, 7, Color("#B8B0C8"))
		wy += 11.0
		draw_string(font, Vector2(354.0, wy), "  时间：%s 秒" % "/".join(PackedStringArray(times)), HORIZONTAL_ALIGNMENT_LEFT, 276.0, 7, Color("#8A8498"))
		wy += 13.0
	if levels.is_empty():
		draw_string(font, Vector2(354.0, wy), "当前没有委托引用这张地图。", HORIZONTAL_ALIGNMENT_LEFT, 276.0, 7, Color("#8A8498"))


func _selection_text() -> String:
	if selected_kind == "base":
		return "已选：%s 基地，x=%d" % [map.base_name(selected_lane), int(map.base_x(selected_lane))]
	if selected_kind == "lane":
		return "已选：%s，y=%d" % [map.route_name(selected_lane), int(map.route_y(selected_lane))]
	if selected_kind == "segment":
		var segments: Array = map.route(selected_lane).get("segments", [])
		if selected_segment >= 0 and selected_segment < segments.size():
			var segment: Dictionary = segments[selected_segment]
			return "已选：%s 第%d段 [%d–%d] 宽%d" % [map.route_name(selected_lane), selected_segment + 1, int(segment["from"]), int(segment["to"]), int(segment["width"])]
	return "点击基地或道路选择；拖动修改。"


func _world_point(world_x: float, world_y: float) -> Vector2:
	return Vector2(WORLD_ORIGIN.x + world_x * ZOOM, WORLD_ORIGIN.y + world_y * ZOOM)


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return Vector2(
		clampf(screen_pos.x / ZOOM, 0.0, map.world_width),
		clampf((screen_pos.y - WORLD_ORIGIN.y) / ZOOM, 0.0, map.world_height)
	)


func _gui_input(event: InputEvent) -> void:
	if map == null:
		return
	if not (event is InputEventMouseButton):
		return
	var pos: Vector2 = event.position
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if pos.y >= PANEL_Y or pos.y <= TOP_H:
				return
			_select_at(pos)
			dragging = selected_kind != ""
			accept_event()
		else:
			dragging = false
			accept_event()


func _select_at(screen_pos: Vector2) -> void:
	var world := _screen_to_world(screen_pos)
	var best_kind := ""
	var best_lane := 0
	var best_segment := 0
	var best_dist := INF
	for team in [0, 1]:
		var base_screen_x := WORLD_ORIGIN.x + map.base_x(team) * ZOOM
		if absf(screen_pos.x - base_screen_x) <= 8.0:
			var dist := absf(screen_pos.x - base_screen_x)
			if dist < best_dist:
				best_dist = dist
				best_kind = "base"
				best_lane = team
	if best_kind != "":
		selected_kind = best_kind
		selected_lane = best_lane
		selected_segment = 0
		queue_redraw()
		return

	for lane in range(map.route_count()):
		var route := map.route(lane)
		var y := float(route.get("y", 180.0))
		var segments: Array = route.get("segments", [])
		for segment_index in range(segments.size()):
			var segment: Dictionary = segments[segment_index]
			if world.x < float(segment["from"]) - 2.0 or world.x > float(segment["to"]) + 2.0:
				continue
			if absf(world.y - y) > float(segment["width"]) * 0.5 + 6.0:
				continue
			var dist := absf(world.y - y)
			if dist < best_dist:
				best_dist = dist
				best_kind = "segment"
				best_lane = lane
				best_segment = segment_index
	if best_kind == "":
		# Clicking just outside a road still selects the nearest route.
		for lane in range(map.route_count()):
			var route_y := map.route_y(lane)
			var dist := absf(world.y - route_y)
			if dist < best_dist:
				best_dist = dist
				best_kind = "lane"
				best_lane = lane
	if best_kind == "":
		return
	selected_kind = best_kind
	selected_lane = best_lane
	selected_segment = best_segment
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseMotion) or not dragging or map == null:
		return
	var world := _screen_to_world(event.position)
	if selected_kind == "base":
		_move_base(selected_lane, world.x)
	elif selected_kind == "lane":
		var route := map.route(selected_lane)
		route["y"] = clampf(world.y, 50.0, map.world_height - 50.0)
		dirty = true
		queue_redraw()
	elif selected_kind == "segment":
		var route := map.route(selected_lane)
		var segments: Array = route.get("segments", [])
		if selected_segment < segments.size():
			if event.shift_pressed:
				route["y"] = clampf(world.y, 50.0, map.world_height - 50.0)
			else:
				var width := clampf(absf(world.y - float(route["y"])) * 2.0, MapData.MIN_ROAD_WIDTH, MapData.MAX_ROAD_WIDTH)
				segments[selected_segment]["width"] = width
			dirty = true
			queue_redraw()


func _move_base(team: int, world_x: float) -> void:
	if map == null:
		return
	var other_x := map.base_x(1 - team)
	var low := 20.0
	var high := map.world_width - 20.0
	if team == 0:
		high = other_x - MapData.MIN_BASE_GAP
	else:
		low = other_x + MapData.MIN_BASE_GAP
	var new_x := clampf(world_x, low, high)
	map.bases[team]["x"] = new_x
	for lane in range(map.route_count()):
		var route: Dictionary = map.route(lane)
		var segments: Array = route.get("segments", [])
		if segments.is_empty():
			continue
		if team == 0:
			segments[0]["from"] = new_x
			route["player_spawn_x"] = clampf(new_x + 12.0, new_x + 8.0, map.base_x(1) - 8.0)
		else:
			segments[segments.size() - 1]["to"] = new_x
			route["enemy_spawn_x"] = clampf(new_x - 12.0, map.base_x(0) + 8.0, new_x - 8.0)
	dirty = true
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE:
			get_tree().change_scene_to_file("res://main/level_select.tscn")
		KEY_TAB:
			if map != null:
				_load_map(map_index + 1)
		KEY_F5:
			_save_map()
		KEY_F8:
			_validate_map()
		KEY_F9:
			_reload_map()
		KEY_N:
			_split_segment()
		KEY_DELETE, KEY_BACKSPACE:
			_delete_segment()
		KEY_BRACKETLEFT:
			_adjust_width(-4.0)
		KEY_BRACKETRIGHT:
			_adjust_width(4.0)


func _split_segment() -> void:
	if map == null or selected_kind != "segment":
		_set_status("先选中一个宽度段再切分", Color("#E06666"))
		return
	var route: Dictionary = map.route(selected_lane)
	var segments: Array = route.get("segments", [])
	if selected_segment >= segments.size():
		return
	var segment: Dictionary = segments[selected_segment]
	var mouse_x := _screen_to_world(get_local_mouse_position()).x
	var from_x := float(segment["from"])
	var to_x := float(segment["to"])
	if mouse_x < from_x + MIN_SEGMENT_LENGTH or mouse_x > to_x - MIN_SEGMENT_LENGTH:
		_set_status("鼠标位置太靠近段边界", Color("#E06666"))
		return
	var left := {"from": from_x, "to": mouse_x, "width": float(segment["width"])}
	var right := {"from": mouse_x, "to": to_x, "width": float(segment["width"])}
	segments[selected_segment] = left
	segments.insert(selected_segment + 1, right)
	selected_segment += 1
	dirty = true
	_set_status("已切分宽度段", Color("#6FA8DC"))


func _delete_segment() -> void:
	if map == null or selected_kind != "segment":
		return
	var route: Dictionary = map.route(selected_lane)
	var segments: Array = route.get("segments", [])
	if segments.size() <= 1:
		_set_status("每条路线至少保留一个宽度段", Color("#E06666"))
		return
	var index := clampi(selected_segment, 0, segments.size() - 1)
	if index == 0:
		segments[1]["from"] = segments[0]["from"]
	else:
		segments[index - 1]["to"] = segments[index]["to"]
	segments.remove_at(index)
	selected_segment = clampi(index - 1, 0, segments.size() - 1)
	dirty = true
	_set_status("已删除宽度段", Color("#6FA8DC"))


func _adjust_width(delta: float) -> void:
	if map == null or selected_kind != "segment":
		return
	var segments: Array = map.route(selected_lane).get("segments", [])
	if selected_segment >= segments.size():
		return
	segments[selected_segment]["width"] = clampf(float(segments[selected_segment]["width"]) + delta, MapData.MIN_ROAD_WIDTH, MapData.MAX_ROAD_WIDTH)
	dirty = true
	_set_status("宽度：%d" % int(segments[selected_segment]["width"]), Color("#6FA8DC"))


func _save_map() -> void:
	if map == null:
		return
	var text := JSON.stringify(map.to_dict(), "\t") + "\n"
	var path := map.source_path
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var fallback := "user://maps/%s" % path.get_file()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://maps"))
		file = FileAccess.open(fallback, FileAccess.WRITE)
		if file == null:
			_set_status("保存失败：无法写入 %s" % path, Color("#E06666"))
			return
		path = fallback
	file.store_string(text)
	file.close()
	dirty = false
	_set_status("已保存：%s" % path, Color("#6FA8DC"))


func _reload_map() -> void:
	if map == null:
		return
	_load_map(map_index)
	_set_status("已重载 %s" % map.source_path, Color("#6FA8DC"))


func _validate_map() -> void:
	if map == null:
		return
	var check := MapData.new()
	check.apply_dict(map.to_dict())
	validation_errors = check.errors.duplicate()
	if validation_errors.is_empty():
		_set_status("校验通过", Color("#6FA8DC"))
	else:
		_set_status("校验失败：%d 个问题" % validation_errors.size(), Color("#E06666"))


func _set_status(text: String, color: Color) -> void:
	status = text
	status_color = color
	queue_redraw()
