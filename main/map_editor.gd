extends Control

## Debug-only graph map editor for M7. It edits the same v2 JSON consumed by
## MapData. Player-facing map workshop/import/undo is intentionally out of scope.

const VIEW_W := 640.0
const VIEW_H := 360.0
const TOP_H := 28.0
const WORLD_RECT := Rect2(0.0, 32.0, 440.0, 320.0)
const PANEL_RECT := Rect2(448.0, 32.0, 192.0, 320.0)

var font: Font
var map_paths: Array = []
var map_index: int = 0
var map: MapData
var levels: Array = []
var selected_node: String = ""
var selected_edge: String = ""
var connect_from: String = ""
var dragging: bool = false
var status: String = ""
var status_color: Color = Color("#8A8498")
var validation_errors: Array = []
var map_scale: float = 0.25
var map_origin: Vector2 = Vector2.ZERO


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
	selected_node = ""
	selected_edge = ""
	connect_from = ""
	dragging = false
	validation_errors = map.errors.duplicate()
	status = "已载入 %s" % String(map_paths[map_index]).get_file()
	status_color = Color("#6FA8DC") if validation_errors.is_empty() else Color("#E06666")
	_load_levels_for_map()
	_fit_world()
	queue_redraw()


func _load_levels_for_map() -> void:
	levels.clear()
	var paths: Array = []
	for contract in GameState.get_contracts():
		paths.append({"contract": int(contract), "path": GameState.get_level_path(int(contract)), "endless": false})
	paths.append({"contract": 0, "path": GameState.get_endless_path(), "endless": true})
	for entry in paths:
		var path := String(entry["path"])
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


func _fit_world() -> void:
	if map == null:
		return
	map_scale = minf(WORLD_RECT.size.x / maxf(1.0, map.world_width), WORLD_RECT.size.y / maxf(1.0, map.world_height))
	var used := Vector2(map.world_width, map.world_height) * map_scale
	map_origin = WORLD_RECT.position + (WORLD_RECT.size - used) * 0.5


func _draw() -> void:
	if font == null:
		return
	draw_rect(Rect2(0.0, 0.0, VIEW_W, VIEW_H), Color("#15121E"))
	draw_rect(Rect2(0.0, 0.0, VIEW_W, TOP_H), Color("#0C0A12"))
	draw_string(font, Vector2(8.0, 18.0), "地图编辑器（调试）", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color("#E8D5A9"))
	draw_string(font, Vector2(168.0, 18.0), "节点图 · 基地 · 道路宽度/容量 · 出生口", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#8A8498"))
	if map != null:
		draw_string(font, Vector2(454.0, 18.0), "%s [Tab]" % map.name_cn, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#6FA8DC"))
	_draw_world()
	_draw_panel()


func _draw_world() -> void:
	if map == null:
		return
	draw_rect(WORLD_RECT, Color("#1E1A2B"))
	draw_rect(WORLD_RECT, Color("#3E3A4A"), false, 1.0)
	var world_rect := Rect2(map_origin, Vector2(map.world_width, map.world_height) * map_scale)
	draw_rect(world_rect, Color("#1A2024"))
	draw_rect(world_rect, Color("#3E4A4E"), false, 1.0)
	for x in range(0, int(map.world_width) + 1, 100):
		draw_line(_world_point(Vector2(x, 0)), _world_point(Vector2(x, map.world_height)), Color(0.2, 0.24, 0.25, 0.35), 1.0)
	for y in range(0, int(map.world_height) + 1, 100):
		draw_line(_world_point(Vector2(0, y)), _world_point(Vector2(map.world_width, y)), Color(0.2, 0.24, 0.25, 0.35), 1.0)

	for edge in map.edges:
		var edge_id := String(edge.get("id", ""))
		var points: Array = edge.get("points", [])
		if points.size() < 2:
			continue
		var selected := edge_id == selected_edge
		var width := maxf(2.0, float(edge.get("width", 80.0)) * map_scale)
		var color := Color("#D9A441") if selected else Color("#59665A")
		for i in range(1, points.size()):
			draw_line(_world_point(points[i - 1]), _world_point(points[i]), color, width)
			draw_line(_world_point(points[i - 1]), _world_point(points[i]), Color("#1A2024"), 1.0)
		var middle := _world_point(points[int(points.size() / 2)])
		draw_string(font, middle + Vector2(2.0, -3.0), "%d" % int(edge.get("width", 80.0)), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#B8B0C8"))

	for node in map.nodes:
		var node_id := String(node.get("id", ""))
		var pos := _world_point(node.get("pos", Vector2.ZERO))
		var team := int(node.get("team", -1))
		var color := Color("#8A8498")
		if String(node.get("type", "")) == "base":
			color = Color("#6FA8DC") if team == 0 else Color("#E06666")
			draw_circle(pos, 9.0, color)
			draw_string(font, pos + Vector2(-18.0, -12.0), String(node.get("name_cn", "")), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, color)
		else:
			draw_circle(pos, 5.0, color)
		if node_id == selected_node or node_id == connect_from:
			draw_arc(pos, 11.0, 0.0, TAU, 18, Color("#D9A441"), 2.0)

	for spawn in map.spawns:
		var entry := String(spawn.get("entry", ""))
		var edge := map.edge(entry)
		if edge.is_empty():
			continue
		var points: Array = edge.get("points", [])
		if points.size() < 2:
			continue
		var point := _world_point(points[0] if String(edge.get("from", "")) == String(spawn.get("base", "")) else points[points.size() - 1])
		var color := Color("#6FA8DC") if int(spawn.get("team", 0)) == 0 else Color("#E06666")
		draw_colored_polygon(PackedVector2Array([point + Vector2(0, -4), point + Vector2(5, 4), point + Vector2(-5, 4)]), color)


func _draw_panel() -> void:
	draw_rect(PANEL_RECT, Color("#0C0A12"))
	draw_line(Vector2(PANEL_RECT.position.x, PANEL_RECT.position.y), Vector2(PANEL_RECT.position.x, PANEL_RECT.position.y + PANEL_RECT.size.y), Color("#3E3A4A"), 1.0)
	if map == null:
		return
	var x := PANEL_RECT.position.x + 10.0
	var y := PANEL_RECT.position.y + 16.0
	draw_string(font, Vector2(x, y), "地图：%s" % map.name_cn, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#E8D5A9"))
	y += 14.0
	draw_string(font, Vector2(x, y), "节点 %d  边 %d  玩家路线 %d" % [map.nodes.size(), map.edges.size(), map.spawns_for_team(0).size()], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#8A8498"))
	y += 14.0
	draw_string(font, Vector2(x, y), _selection_text(), HORIZONTAL_ALIGNMENT_LEFT, 172.0, 7, Color("#D9A441"))
	y += 16.0
	var lines: Array = [
		"拖动节点改位置",
		"N 新增交汇点",
		"C 从选中节点连到下一个点击节点",
		"B 切换节点：普通→我方基地→敌方基地",
		"[ / ] 调选中边宽度",
		"Delete 删除选中节点/边",
		"F5 保存  F8 校验  F9 重载",
		"Tab 切图  Esc 返回",
	]
	for line in lines:
		draw_string(font, Vector2(x, y), String(line), HORIZONTAL_ALIGNMENT_LEFT, 174.0, 7, Color("#8A8498"))
		y += 12.0
	y += 3.0
	draw_string(font, Vector2(x, y), status, HORIZONTAL_ALIGNMENT_LEFT, 174.0, 7, status_color)
	if not validation_errors.is_empty():
		draw_string(font, Vector2(x, y + 12.0), "错误：%s" % String(validation_errors[0]), HORIZONTAL_ALIGNMENT_LEFT, 174.0, 6, Color("#E06666"))
	y += 28.0
	draw_string(font, Vector2(x, y), "出生口（只读，保存时保留 id）", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#6FA8DC"))
	y += 12.0
	for spawn in map.spawns:
		if y > VIEW_H - 46.0:
			break
		var team_label := "玩家" if int(spawn.get("team", -1)) == 0 else "敌方"
		draw_string(font, Vector2(x, y), "%s → %s (%s)" % [String(spawn.get("id", "")), String(spawn.get("name_cn", spawn.get("name", ""))), team_label], HORIZONTAL_ALIGNMENT_LEFT, 174.0, 6, Color("#8A8498"))
		y += 10.0
	y += 4.0
	draw_string(font, Vector2(x, y), "参考波次（只读）", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#6FA8DC"))
	y += 12.0
	for entry in levels:
		if y > VIEW_H - 14.0:
			break
		var title := "无尽" if bool(entry["endless"]) else "委托%d" % int(entry["contract"])
		var waves: Array = entry["waves"]
		var route_labels := _wave_route_labels(waves)
		var route_suffix := ""
		if not route_labels.is_empty():
			route_suffix = " [%s]" % "/".join(route_labels)
		draw_string(font, Vector2(x, y), "%s %s：%d波%s" % [title, String(entry["name"]), waves.size(), route_suffix], HORIZONTAL_ALIGNMENT_LEFT, 174.0, 6, Color("#B8B0C8"))
		y += 11.0
	if levels.is_empty():
		draw_string(font, Vector2(x, y), "没有委托引用此地图。", HORIZONTAL_ALIGNMENT_LEFT, 174.0, 6, Color("#8A8498"))


func _wave_route_labels(waves: Array) -> Array:
	var seen := {}
	for wave in waves:
		var default_route: Variant = wave.get("route", wave.get("lane", -1))
		_collect_route_label(default_route, seen)
		for spawn in wave.get("spawns", []):
			_collect_route_label(spawn.get("route", spawn.get("lane", default_route)), seen)
	return seen.keys()


func _collect_route_label(route_value: Variant, seen: Dictionary) -> void:
	var route_id := ""
	if route_value is String and String(route_value) != "":
		route_id = String(route_value)
	elif route_value is float or route_value is int:
		var enemy_routes: Array = map.spawns_for_team(1)
		var index := int(route_value)
		if index >= 0 and index < enemy_routes.size():
			route_id = String(enemy_routes[index].get("id", ""))
	if route_id == "":
		return
	var spawn_data := map.spawn(route_id)
	var label := String(spawn_data.get("name_cn", spawn_data.get("name", route_id))) if not spawn_data.is_empty() else route_id
	if not seen.has(label):
		seen[label] = true


func _selection_text() -> String:
	if selected_node != "":
		var node := map.node(selected_node)
		var node_label := "节点 %s  %s" % [selected_node, "基地" if String(node.get("type", "")) == "base" else "交汇"]
		var spawn_ids: Array = []
		for spawn in map.spawns:
			if String(spawn.get("base", "")) == selected_node:
				spawn_ids.append(String(spawn.get("id", "")))
		if not spawn_ids.is_empty():
			node_label += "  出生口 " + "/".join(spawn_ids)
		return node_label
	if selected_edge != "":
		var edge := map.edge(selected_edge)
		var slot_width := 14.0
		var padding := 1.0
		if GameState.game_data != null:
			slot_width = float(GameState.game_data.get_balance("road_slot_width", 14.0))
			padding = float(GameState.game_data.get_balance("road_slot_padding", 1.0))
		var capacity := map.edge_slot_count(selected_edge, slot_width, padding)
		var spawn_ids: Array = []
		for spawn in map.spawns:
			if String(spawn.get("entry", "")) == selected_edge:
				spawn_ids.append(String(spawn.get("id", "")))
		var spawn_suffix := "" if spawn_ids.is_empty() else "  出生口 " + "/".join(spawn_ids)
		return "边 %s  宽%d  并行%d%s" % [selected_edge, int(edge.get("width", 80.0)), capacity, spawn_suffix]
	return "点击节点/边选择；拖动节点移动。"


func _world_point(world_pos: Vector2) -> Vector2:
	return map_origin + world_pos * map_scale


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return Vector2(
		clampf((screen_pos.x - map_origin.x) / map_scale, 0.0, map.world_width),
		clampf((screen_pos.y - map_origin.y) / map_scale, 0.0, map.world_height)
	)


func _gui_input(event: InputEvent) -> void:
	if map == null or not (event is InputEventMouseButton):
		return
	var pos: Vector2 = event.position
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if event.pressed:
		if not WORLD_RECT.has_point(pos):
			return
		if connect_from != "":
			var target := _node_at(pos)
			if target != "" and target != connect_from:
				_add_edge(connect_from, target)
				connect_from = ""
			accept_event()
			return
		_select_at(pos)
		dragging = selected_node != ""
		accept_event()
	else:
		dragging = false


func _select_at(screen_pos: Vector2) -> void:
	var node_id := _node_at(screen_pos)
	if node_id != "":
		selected_node = node_id
		selected_edge = ""
		queue_redraw()
		return
	var edge_id := _edge_at(screen_pos)
	selected_edge = edge_id
	selected_node = ""
	queue_redraw()


func _node_at(screen_pos: Vector2) -> String:
	for node in map.nodes:
		if _world_point(node.get("pos", Vector2.ZERO)).distance_to(screen_pos) <= 11.0:
			return String(node.get("id", ""))
	return ""


func _edge_at(screen_pos: Vector2) -> String:
	var best := ""
	var best_dist := 7.0
	for edge in map.edges:
		var points: Array = edge.get("points", [])
		for i in range(1, points.size()):
			var a := _world_point(points[i - 1])
			var b := _world_point(points[i])
			var dist := _distance_to_segment(screen_pos, a, b)
			if dist < best_dist:
				best_dist = dist
				best = String(edge.get("id", ""))
	return best


func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	if ab.length_squared() <= 0.001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return point.distance_to(a + ab * t)


func _input(event: InputEvent) -> void:
	if map == null or not dragging or selected_node == "" or not (event is InputEventMouseMotion):
		return
	var world := _screen_to_world(event.position)
	var node := map.node(selected_node)
	node["pos"] = world
	for edge in map.edges:
		if String(edge.get("from", "")) == selected_node or String(edge.get("to", "")) == selected_node:
			var from_pos := map.node_pos(String(edge.get("from", "")))
			var to_pos := map.node_pos(String(edge.get("to", "")))
			edge["points"] = [from_pos, to_pos]
			edge["length"] = maxf(0.001, from_pos.distance_to(to_pos))
	queue_redraw()


func _add_edge(from_node: String, to_node: String) -> void:
	var edge_id := "e_%d" % (map.edges.size() + 1)
	while map.edge_by_id.has(edge_id):
		edge_id += "_x"
	map._add_edge(edge_id, from_node, to_node, 72.0, "新道路")
	map._rebuild_indexes()
	selected_edge = edge_id
	selected_node = ""
	status = "已连接 %s → %s" % [from_node, to_node]
	status_color = Color("#6FA8DC")
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo or map == null:
		return
	match event.keycode:
		KEY_ESCAPE:
			get_tree().change_scene_to_file("res://main/level_select.tscn")
		KEY_TAB:
			_load_map(map_index + 1)
		KEY_N:
			_add_junction()
		KEY_C:
			if selected_node != "":
				connect_from = selected_node
				status = "点击另一个节点完成连接"
				status_color = Color("#D9A441")
				queue_redraw()
		KEY_B:
			_cycle_base()
		KEY_BRACKETLEFT:
			_adjust_width(-4.0)
		KEY_BRACKETRIGHT:
			_adjust_width(4.0)
		KEY_DELETE, KEY_BACKSPACE:
			_delete_selected()
		KEY_F5:
			_save_map()
		KEY_F8:
			_validate_map()
		KEY_F9:
			_load_map(map_index)


func _add_junction() -> void:
	var pos := _screen_to_world(get_local_mouse_position())
	var node_id := "n_%d" % (map.nodes.size() + 1)
	while map.node_by_id.has(node_id):
		node_id += "_x"
	map._add_node(node_id, "junction", -1, pos, "交汇")
	map._rebuild_indexes()
	map._refresh_bases()
	selected_node = node_id
	selected_edge = ""
	status = "已新增节点 %s" % node_id
	status_color = Color("#6FA8DC")
	queue_redraw()


func _cycle_base() -> void:
	if selected_node == "":
		return
	var node := map.node(selected_node)
	var current := String(node.get("type", "")) + ":" + str(int(node.get("team", -1)))
	var next_team := -1
	if String(node.get("type", "")) != "base":
		next_team = 0
	elif int(node.get("team", -1)) == 0:
		next_team = 1
	else:
		next_team = -1
	if next_team >= 0:
		for other in map.nodes:
			if String(other.get("id", "")) == selected_node:
				continue
			if String(other.get("type", "")) == "base" and int(other.get("team", -1)) == next_team:
				other["type"] = "junction"
				other["team"] = -1
		node["type"] = "base"
		node["team"] = next_team
		if String(node.get("name_cn", "")) == "交汇":
			node["name_cn"] = "我方营地" if next_team == 0 else "敌方营地"
	else:
		node["type"] = "junction"
		node["team"] = -1
	map._rebuild_indexes()
	map._refresh_bases()
	status = "节点 %s 类型已切换" % selected_node
	status_color = Color("#6FA8DC")
	queue_redraw()


func _adjust_width(delta: float) -> void:
	if selected_edge == "":
		return
	var edge := map.edge(selected_edge)
	edge["width"] = clampf(float(edge.get("width", 80.0)) + delta, MapData.MIN_ROAD_WIDTH, MapData.MAX_ROAD_WIDTH)
	status = "边宽：%d" % int(edge["width"])
	status_color = Color("#6FA8DC")
	queue_redraw()


func _delete_selected() -> void:
	if selected_edge != "":
		map.edges.erase(map.edge(selected_edge))
		map._rebuild_indexes()
		selected_edge = ""
		status = "已删除边"
	elif selected_node != "":
		var edges_to_remove: Array = []
		for edge in map.edges:
			if String(edge.get("from", "")) == selected_node or String(edge.get("to", "")) == selected_node:
				edges_to_remove.append(edge)
		for edge in edges_to_remove:
			map.edges.erase(edge)
		map.nodes.erase(map.node(selected_node))
		map._rebuild_indexes()
		map._refresh_bases()
		selected_node = ""
		status = "已删除节点及相连边"
	status_color = Color("#E06666")
	queue_redraw()


func _ensure_base_spawns() -> void:
	# Append-only: preserve curated spawn ids/names/order. Never rebuild or
	# rename existing spawns just because an edge was added.
	for team in [0, 1]:
		var base_node: Dictionary = map.base_node_by_team.get(team, {})
		if base_node.is_empty():
			continue
		var base_id := String(base_node.get("id", ""))
		for edge in map.edges:
			if String(edge.get("from", "")) != base_id and String(edge.get("to", "")) != base_id:
				continue
			var edge_id := String(edge.get("id", ""))
			var exists := false
			for spawn in map.spawns:
				if int(spawn.get("team", -1)) == team and String(spawn.get("entry", "")) == edge_id:
					exists = true
					break
			if exists:
				continue
			var spawn_id := "%s_%s" % ["p" if team == 0 else "e", edge_id]
			var suffix := 1
			while map.spawn_by_id.has(spawn_id):
				spawn_id = "%s_%s_%d" % ["p" if team == 0 else "e", edge_id, suffix]
				suffix += 1
			var name := String(edge.get("name_cn", edge.get("name", edge_id)))
			map._add_spawn(spawn_id, team, base_id, edge_id, name)
	map._rebuild_indexes()


func _validate_map() -> void:
	if map == null:
		return
	# Validate a deep copy; validation must not mutate spawn ids/order.
	var check := MapData.new()
	check.apply_dict(map.to_dict().duplicate(true))
	validation_errors = check.errors.duplicate()
	if validation_errors.is_empty():
		status = "校验通过"
		status_color = Color("#6FA8DC")
	else:
		status = "校验失败：%d 个问题" % validation_errors.size()
		status_color = Color("#E06666")
	queue_redraw()


func _save_map() -> void:
	if map == null:
		return
	_ensure_base_spawns()
	var check := MapData.new()
	check.apply_dict(map.to_dict().duplicate(true))
	validation_errors = check.errors.duplicate()
	if not validation_errors.is_empty():
		status = "未保存：请先修复 %d 个校验错误" % validation_errors.size()
		status_color = Color("#E06666")
		queue_redraw()
		return
	var path := map.source_path
	var text := JSON.stringify(map.to_dict(), "\t") + "\n"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		var fallback := "user://maps/%s" % path.get_file()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://maps"))
		file = FileAccess.open(fallback, FileAccess.WRITE)
		path = fallback
	if file == null:
		status = "保存失败"
		status_color = Color("#E06666")
		return
	file.store_string(text)
	file.close()
	status = "已保存：%s" % path
	status_color = Color("#6FA8DC")
	queue_redraw()
