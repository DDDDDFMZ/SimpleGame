class_name MapData
extends RefCounted

## M7 top-down graph map. A map has exactly one player base and one enemy base;
## routes are spawn entries into an undirected node/edge graph. A unit's path is
## computed by MapGraph, not stored here (MapData is immutable/cached).

const DEFAULT_WORLD_WIDTH := 1600.0
const DEFAULT_WORLD_HEIGHT := 900.0
const DEFAULT_PLAYER_BASE := Vector2(140.0, 450.0)
const DEFAULT_ENEMY_BASE := Vector2(1460.0, 450.0)
const MIN_ROAD_WIDTH := 24.0
const MAX_ROAD_WIDTH := 200.0
const MIN_NODE_GAP := 20.0

var version: int = 2
var id: String = "default_crossroads"
var name: String = "Crossroads"
var name_cn: String = "双路十字口"
var world_width: float = DEFAULT_WORLD_WIDTH
var world_height: float = DEFAULT_WORLD_HEIGHT
var nodes: Array = []
var edges: Array = []
var spawns: Array = []
var bases: Array = []
var errors: Array = []
var source_path: String = ""

var node_by_id: Dictionary = {}
var edge_by_id: Dictionary = {}
var spawn_by_id: Dictionary = {}
var base_node_by_team: Dictionary = {}


func _init() -> void:
	reset_defaults()


func reset_defaults() -> void:
	version = 2
	id = "default_crossroads"
	name = "Crossroads"
	name_cn = "双路十字口"
	world_width = DEFAULT_WORLD_WIDTH
	world_height = DEFAULT_WORLD_HEIGHT
	_clear_graph()
	_add_node("p_base", "base", 0, DEFAULT_PLAYER_BASE, "冒险者营地")
	_add_node("e_base", "base", 1, DEFAULT_ENEMY_BASE, "敌方营地")
	_add_node("j_north", "junction", -1, Vector2(800.0, 300.0), "北交汇")
	_add_node("j_south", "junction", -1, Vector2(800.0, 600.0), "南交汇")
	_add_edge("p_jn", "p_base", "j_north", 80.0, "北线")
	_add_edge("jn_e", "j_north", "e_base", 80.0, "北线")
	_add_edge("p_js", "p_base", "j_south", 80.0, "南线")
	_add_edge("js_e", "j_south", "e_base", 80.0, "南线")
	_add_spawn("north", 0, "p_base", "p_jn", "北线")
	_add_spawn("south", 0, "p_base", "p_js", "南线")
	_add_spawn("enemy_north", 1, "e_base", "jn_e", "敌方北线")
	_add_spawn("enemy_south", 1, "e_base", "js_e", "敌方南线")
	_rebuild_indexes()
	_refresh_bases()


func _clear_graph() -> void:
	nodes = []
	edges = []
	spawns = []
	bases = []
	errors = []
	node_by_id.clear()
	edge_by_id.clear()
	spawn_by_id.clear()
	base_node_by_team.clear()


func _add_node(node_id: String, type: String, team: int, pos: Vector2, display_name: String) -> void:
	nodes.append({
		"id": node_id,
		"type": type,
		"team": team,
		"pos": pos,
		"name_cn": display_name,
	})


func _add_edge(edge_id: String, from_node: String, to_node: String, width: float, display_name: String, points: Array = []) -> void:
	var points_out: Array = []
	if points.is_empty():
		var from_pos := _node_pos_raw(from_node)
		var to_pos := _node_pos_raw(to_node)
		points_out = [from_pos, to_pos]
	else:
		points_out = points.duplicate()
	edges.append({
		"id": edge_id,
		"from": from_node,
		"to": to_node,
		"width": clampf(width, MIN_ROAD_WIDTH, MAX_ROAD_WIDTH),
		"name_cn": display_name,
		"points": points_out,
		"length": _polyline_length(points_out),
	})


func _add_spawn(spawn_id: String, team: int, base_node: String, entry_edge: String, display_name: String) -> void:
	spawns.append({
		"id": spawn_id,
		"team": team,
		"base": base_node,
		"entry": entry_edge,
		"name_cn": display_name,
	})


func _node_pos_raw(node_id: String) -> Vector2:
	for node in nodes:
		if String(node.get("id", "")) == node_id:
			return node.get("pos", Vector2.ZERO)
	return Vector2.ZERO


func _polyline_length(points: Array) -> float:
	var length := 0.0
	for i in range(1, points.size()):
		length += Vector2(points[i - 1]).distance_to(Vector2(points[i]))
	return maxf(0.001, length)


func _rebuild_indexes() -> void:
	node_by_id.clear()
	edge_by_id.clear()
	spawn_by_id.clear()
	base_node_by_team.clear()
	for node in nodes:
		node_by_id[String(node.get("id", ""))] = node
		if String(node.get("type", "")) == "base":
			base_node_by_team[int(node.get("team", -1))] = node
	for edge in edges:
		edge_by_id[String(edge.get("id", ""))] = edge
		edge["length"] = _polyline_length(edge.get("points", []))
	for spawn in spawns:
		spawn_by_id[String(spawn.get("id", ""))] = spawn


func _refresh_bases() -> void:
	bases = []
	for team in [0, 1]:
		var node: Dictionary = base_node_by_team.get(team, {})
		if node.is_empty():
			continue
		bases.append({
			"id": String(node.get("id", "")),
			"node": String(node.get("id", "")),
			"team": team,
			"name": String(node.get("name", "")),
			"name_cn": String(node.get("name_cn", "")),
			"x": float(node.get("pos", Vector2.ZERO).x),
			"y": float(node.get("pos", Vector2.ZERO).y),
		})


static func load_file(path: String) -> MapData:
	var map := MapData.new()
	map.source_path = path
	if path.is_empty():
		map.errors.append("地图路径为空")
		return map
	if not FileAccess.file_exists(path):
		map.errors.append("地图文件不存在：%s" % path)
		return map
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		map.errors.append("地图文件为空：%s" % path)
		return map
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		map.errors.append("地图 JSON 格式错误：%s" % path)
		return map
	map.apply_dict(parsed)
	return map


func apply_dict(source: Dictionary) -> void:
	errors.clear()
	version = int(source.get("version", 1))
	id = String(source.get("id", "untitled"))
	name = String(source.get("name", id))
	name_cn = String(source.get("name_cn", name))
	var world: Dictionary = source.get("world", {})
	world_width = clampf(float(world.get("width", DEFAULT_WORLD_WIDTH)), 480.0, 12000.0)
	world_height = clampf(float(world.get("height", DEFAULT_WORLD_HEIGHT)), 360.0, 12000.0)
	_clear_graph()
	if source.has("nodes") or source.has("edges") or version >= 2:
		_parse_graph(source)
	else:
		_compile_legacy(source)
	_rebuild_indexes()
	_refresh_bases()
	_validate()


func _parse_graph(source: Dictionary) -> void:
	var raw_nodes: Variant = source.get("nodes", [])
	if raw_nodes is Array:
		for raw in raw_nodes:
			if typeof(raw) != TYPE_DICTIONARY:
				errors.append("节点不是对象")
				continue
			var d: Dictionary = raw
			var node_id := String(d.get("id", "")).strip_edges()
			if node_id == "":
				errors.append("节点缺少 id")
				continue
			if node_by_id.has(node_id):
				errors.append("重复节点 id：%s" % node_id)
				continue
			var node_type := String(d.get("type", "waypoint"))
			if node_type != "base" and node_type != "junction" and node_type != "waypoint":
				errors.append("节点 %s 类型无效：%s" % [node_id, node_type])
				node_type = "waypoint"
			var pos := _read_pos(d)
			var node := {
				"id": node_id,
				"type": node_type,
				"team": int(d.get("team", -1)) if node_type == "base" else -1,
				"pos": pos,
				"name": String(d.get("name", node_id)),
				"name_cn": String(d.get("name_cn", d.get("name", node_id))),
			}
			nodes.append(node)
			node_by_id[node_id] = node

	var raw_edges: Variant = source.get("edges", [])
	if raw_edges is Array:
		for raw in raw_edges:
			if typeof(raw) != TYPE_DICTIONARY:
				errors.append("边不是对象")
				continue
			var d: Dictionary = raw
			var edge_id := String(d.get("id", "")).strip_edges()
			if edge_id == "":
				errors.append("边缺少 id")
				continue
			if edge_by_id.has(edge_id):
				errors.append("重复边 id：%s" % edge_id)
				continue
			var from_node := String(d.get("from", ""))
			var to_node := String(d.get("to", ""))
			if not node_by_id.has(from_node) or not node_by_id.has(to_node):
				errors.append("边 %s 端点不存在" % edge_id)
				continue
			if from_node == to_node:
				errors.append("边 %s 两端相同" % edge_id)
				continue
			var width := clampf(float(d.get("width", 80.0)), MIN_ROAD_WIDTH, MAX_ROAD_WIDTH)
			var points: Array = []
			var raw_points: Variant = d.get("polyline", [])
			if raw_points is Array and raw_points.size() >= 2:
				for point_value in raw_points:
					points.append(_read_pos_value(point_value))
			else:
				points = [
					node_by_id[from_node].get("pos", Vector2.ZERO),
					node_by_id[to_node].get("pos", Vector2.ZERO),
				]
			if points.size() < 2:
				errors.append("边 %s 缺少路径点" % edge_id)
				continue
			var edge := {
				"id": edge_id,
				"from": from_node,
				"to": to_node,
				"width": width,
				"capacity_override": int(d.get("capacity", 0)),
				"name": String(d.get("name", edge_id)),
				"name_cn": String(d.get("name_cn", d.get("name", edge_id))),
				"points": points,
				"length": _polyline_length(points),
			}
			edges.append(edge)
			edge_by_id[edge_id] = edge
	_rebuild_indexes()

	var raw_spawns: Variant = source.get("spawns", [])
	if raw_spawns is Array:
		for raw in raw_spawns:
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var d: Dictionary = raw
			var spawn_id := String(d.get("id", "")).strip_edges()
			if spawn_id == "":
				errors.append("出生口缺少 id")
				continue
			if spawn_by_id.has(spawn_id):
				errors.append("重复出生口 id：%s" % spawn_id)
				continue
			var spawn := {
				"id": spawn_id,
				"team": int(d.get("team", 0)),
				"base": String(d.get("base", "")),
				"entry": String(d.get("entry", "")),
				"name": String(d.get("name", spawn_id)),
				"name_cn": String(d.get("name_cn", d.get("name", spawn_id))),
			}
			spawns.append(spawn)
			spawn_by_id[spawn_id] = spawn
	_auto_spawn_if_needed()


func _auto_spawn_if_needed() -> void:
	if not spawns.is_empty():
		return
	for team in [0, 1]:
		var base_node: Dictionary = base_node_by_team.get(team, {})
		if base_node.is_empty():
			continue
		var base_id := String(base_node.get("id", ""))
		for edge in edges:
			if String(edge.get("from", "")) != base_id and String(edge.get("to", "")) != base_id:
				continue
			var spawn_id := "%s_%s" % ["player" if team == 0 else "enemy", String(edge.get("id", ""))]
			spawns.append({
				"id": spawn_id,
				"team": team,
				"base": base_id,
				"entry": String(edge.get("id", "")),
				"name": String(edge.get("name", spawn_id)),
				"name_cn": String(edge.get("name_cn", edge.get("name", spawn_id))),
			})
			spawn_by_id[spawn_id] = spawns[spawns.size() - 1]


func _compile_legacy(source: Dictionary) -> void:
	# Legacy M6 two-lane map: one base per team, one straight lane per route.
	var raw_bases: Variant = source.get("bases", [])
	var base0 := Vector2(80.0, world_height * 0.5)
	var base1 := Vector2(1520.0, world_height * 0.5)
	if raw_bases is Array:
		for raw in raw_bases:
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var d: Dictionary = raw
			var team := int(d.get("team", -1))
			if team == 0:
				base0 = Vector2(float(d.get("x", base0.x)), world_height * 0.5)
			elif team == 1:
				base1 = Vector2(float(d.get("x", base1.x)), world_height * 0.5)
	_add_node("p_base", "base", 0, base0, "冒险者营地")
	_add_node("e_base", "base", 1, base1, "敌方营地")
	var raw_routes: Variant = source.get("routes", [])
	if not (raw_routes is Array) or raw_routes.is_empty():
		_parse_legacy_route(0, 110.0, 80.0)
	else:
		for i in range(mini(4, raw_routes.size())):
			var route: Dictionary = raw_routes[i]
			var y := float(route.get("y", 110.0 + i * 100.0))
			var width := 80.0
			var segments: Array = route.get("segments", [])
			if not segments.is_empty():
				width = float(segments[0].get("width", 80.0))
				for segment in segments:
					width = minf(width, float(segment.get("width", width)))
			_parse_legacy_route(i, y, width)


func _parse_legacy_route(index: int, lane_y: float, width: float) -> void:
	var base0: Vector2 = node_by_id["p_base"]["pos"]
	var base1: Vector2 = node_by_id["e_base"]["pos"]
	var p_lane := "p_lane%d" % index
	var e_lane := "e_lane%d" % index
	var lane_name := "第%d路" % (index + 1)
	_add_node(p_lane, "waypoint", -1, Vector2(base0.x + 12.0, lane_y), "我方%d路" % (index + 1))
	_add_node(e_lane, "waypoint", -1, Vector2(base1.x - 12.0, lane_y), "敌方%d路" % (index + 1))
	_add_edge("lane_in_%d" % index, "p_base", p_lane, width, lane_name)
	_add_edge("lane_%d" % index, p_lane, e_lane, width, lane_name)
	_add_edge("lane_out_%d" % index, e_lane, "e_base", width, lane_name)
	_add_spawn("north" if index == 0 else "lane_%d" % index, 0, "p_base", "lane_in_%d" % index, lane_name)
	_add_spawn("enemy_north" if index == 0 else "enemy_lane_%d" % index, 1, "e_base", "lane_out_%d" % index, "敌方" + lane_name)


func _read_pos(d: Dictionary) -> Vector2:
	if d.has("pos"):
		return _read_pos_value(d["pos"])
	return Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))


func _read_pos_value(value: Variant) -> Vector2:
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Vector2:
		return value
	return Vector2.ZERO


func _validate() -> void:
	if node_by_id.size() < 3:
		errors.append("地图至少需要基地与一个节点")
	for team in [0, 1]:
		if not base_node_by_team.has(team):
			errors.append("缺少 team=%d 的基地节点" % team)
	if base_node_by_team.size() != 2:
		errors.append("必须恰好有一个玩家基地和一个敌方基地")
	var seen_base_teams := {}
	for node in nodes:
		if String(node.get("type", "")) != "base":
			continue
		var base_team := int(node.get("team", -1))
		if seen_base_teams.has(base_team):
			errors.append("同一阵营只能有一个基地节点")
		seen_base_teams[base_team] = true
	for node in nodes:
		var pos: Vector2 = node.get("pos", Vector2.ZERO)
		if pos.x < 0.0 or pos.y < 0.0 or pos.x > world_width or pos.y > world_height:
			errors.append("节点 %s 超出世界边界" % String(node.get("id", "")))
		if String(node.get("type", "")) == "base" and int(node.get("team", -1)) not in [0, 1]:
			errors.append("基地节点 %s team 无效" % String(node.get("id", "")))
	for edge in edges:
		if String(edge.get("from", "")) not in node_by_id or String(edge.get("to", "")) not in node_by_id:
			errors.append("边 %s 端点不存在" % String(edge.get("id", "")))
		if float(edge.get("length", 0.0)) < MIN_NODE_GAP:
			errors.append("边 %s 太短" % String(edge.get("id", "")))
		if edge.get("points", []).size() < 2:
			errors.append("边 %s 缺少路径点" % String(edge.get("id", "")))
	for spawn in spawns:
		var team := int(spawn.get("team", -1))
		var base_id := String(spawn.get("base", ""))
		var entry := String(spawn.get("entry", ""))
		if team != 0 and team != 1:
			errors.append("出生口 %s team 无效" % String(spawn.get("id", "")))
			continue
		if not edge_by_id.has(entry):
			errors.append("出生口 %s 的 entry 边不存在" % String(spawn.get("id", "")))
			continue
		if not base_node_by_team.has(team) or base_id != String(base_node_by_team[team].get("id", "")):
			errors.append("出生口 %s 的 base 与基地不匹配" % String(spawn.get("id", "")))
		elif String(edge_by_id[entry].get("from", "")) != base_id and String(edge_by_id[entry].get("to", "")) != base_id:
			errors.append("出生口 %s 的 entry 不连接基地" % String(spawn.get("id", "")))
	_validate_connectivity()


func _validate_connectivity() -> void:
	if not base_node_by_team.has(0) or not base_node_by_team.has(1):
		return
	var adjacency := _build_adjacency()
	var start := String(base_node_by_team[0].get("id", ""))
	var goal := String(base_node_by_team[1].get("id", ""))
	var visited := {start: true}
	var queue: Array = [start]
	while not queue.is_empty():
		var current: String = queue.pop_front()
		for edge_id in adjacency.get(current, []):
			var edge: Dictionary = edge_by_id.get(edge_id, {})
			var next_node := String(edge.get("to", "")) if String(edge.get("from", "")) == current else String(edge.get("from", ""))
			if not visited.has(next_node):
				visited[next_node] = true
				queue.append(next_node)
	if not visited.has(goal):
		errors.append("玩家基地与敌方基地不连通")
	for spawn in spawns:
		if not visited.has(String(spawn.get("base", ""))):
			errors.append("出生口 %s 的基地不可达" % String(spawn.get("id", "")))


func _build_adjacency() -> Dictionary:
	var adjacency := {}
	for node in nodes:
		adjacency[String(node.get("id", ""))] = []
	for edge in edges:
		var from_node := String(edge.get("from", ""))
		var to_node := String(edge.get("to", ""))
		if adjacency.has(from_node):
			adjacency[from_node].append(String(edge.get("id", "")))
		if adjacency.has(to_node):
			adjacency[to_node].append(String(edge.get("id", "")))
	return adjacency


# --- runtime accessors -------------------------------------------------------

func node(node_id: String) -> Dictionary:
	return node_by_id.get(node_id, {})


func edge(edge_id: String) -> Dictionary:
	return edge_by_id.get(edge_id, {})


func spawn(spawn_id: String) -> Dictionary:
	return spawn_by_id.get(spawn_id, {})


func node_pos(node_id: String) -> Vector2:
	var n := node(node_id)
	return n.get("pos", Vector2.ZERO)


func edge_points(edge_id: String) -> Array:
	var e := edge(edge_id)
	return e.get("points", [])


func edge_length(edge_id: String) -> float:
	return float(edge(edge_id).get("length", 0.0))


func edge_width(edge_id: String) -> float:
	return float(edge(edge_id).get("width", 80.0))


func edge_capacity(edge_id: String, px_per_unit: float = 12.0, maximum: int = 12) -> int:
	var e := edge(edge_id)
	var override := int(e.get("capacity_override", 0))
	if override > 0:
		return override
	return clampi(int(floor(float(e.get("width", 80.0)) / maxf(1.0, px_per_unit))), 1, maximum)


func edge_other(edge_id: String, node_id: String) -> String:
	var e := edge(edge_id)
	if String(e.get("from", "")) == node_id:
		return String(e.get("to", ""))
	if String(e.get("to", "")) == node_id:
		return String(e.get("from", ""))
	return ""


func base_node_id(team: int) -> String:
	var node_data: Dictionary = base_node_by_team.get(team, {})
	return String(node_data.get("id", ""))


func base_x(team: int) -> float:
	var node_data: Dictionary = base_node_by_team.get(team, {})
	return float(node_data.get("pos", Vector2.ZERO).x)


func base_y(team: int) -> float:
	var node_data: Dictionary = base_node_by_team.get(team, {})
	return float(node_data.get("pos", Vector2.ZERO).y)


func base_name(team: int) -> String:
	var node_data: Dictionary = base_node_by_team.get(team, {})
	return String(node_data.get("name_cn", node_data.get("name", "营地")))


func spawns_for_team(team: int) -> Array:
	var result: Array = []
	for spawn_data in spawns:
		if int(spawn_data.get("team", -1)) == team:
			result.append(spawn_data)
	return result


func route_count(team: int = 0) -> int:
	return spawns_for_team(team).size()


func route(index: int, team: int = 0) -> Dictionary:
	var list := spawns_for_team(team)
	if index < 0 or index >= list.size():
		return {}
	return list[index]


func route_name(index: int, team: int = 0) -> String:
	var spawn_data := route(index, team)
	if spawn_data.is_empty():
		return "路线 %d" % (index + 1)
	return String(spawn_data.get("name_cn", spawn_data.get("name", "路线 %d" % (index + 1))))


func spawn_entry(spawn_id: String) -> String:
	return String(spawn(spawn_id).get("entry", ""))


func spawn_base(spawn_id: String) -> String:
	return String(spawn(spawn_id).get("base", ""))


func to_dict() -> Dictionary:
	var nodes_out: Array = []
	for node_data in nodes:
		var pos: Vector2 = node_data.get("pos", Vector2.ZERO)
		nodes_out.append({
			"id": String(node_data.get("id", "")),
			"type": String(node_data.get("type", "waypoint")),
			"team": int(node_data.get("team", -1)),
			"name": String(node_data.get("name", "")),
			"name_cn": String(node_data.get("name_cn", "")),
			"pos": [pos.x, pos.y],
		})
	var edges_out: Array = []
	for edge_data in edges:
		var points: Array = []
		for point in edge_data.get("points", []):
			points.append([point.x, point.y])
		edges_out.append({
			"id": String(edge_data.get("id", "")),
			"from": String(edge_data.get("from", "")),
			"to": String(edge_data.get("to", "")),
			"width": float(edge_data.get("width", 80.0)),
			"capacity": int(edge_data.get("capacity_override", 0)),
			"name": String(edge_data.get("name", "")),
			"name_cn": String(edge_data.get("name_cn", "")),
			"polyline": points,
		})
	return {
		"version": 2,
		"id": id,
		"name": name,
		"name_cn": name_cn,
		"world": {"width": world_width, "height": world_height},
		"nodes": nodes_out,
		"edges": edges_out,
		"spawns": spawns.duplicate(true),
	}


func to_snapshot() -> Dictionary:
	var nodes_out: Array = []
	for node_data in nodes:
		var pos: Vector2 = node_data.get("pos", Vector2.ZERO)
		nodes_out.append({
			"id": String(node_data.get("id", "")),
			"type": String(node_data.get("type", "")),
			"team": int(node_data.get("team", -1)),
			"name_cn": String(node_data.get("name_cn", "")),
			"pos": [pos.x, pos.y],
		})
	var edges_out: Array = []
	for edge_data in edges:
		var points: Array = []
		for point in edge_data.get("points", []):
			points.append([point.x, point.y])
		edges_out.append({
			"id": String(edge_data.get("id", "")),
			"from": String(edge_data.get("from", "")),
			"to": String(edge_data.get("to", "")),
			"width": float(edge_data.get("width", 80.0)),
			"name_cn": String(edge_data.get("name_cn", "")),
			"points": points,
		})
	return {
		"id": id,
		"name": name,
		"name_cn": name_cn,
		"world_width": world_width,
		"world_height": world_height,
		"nodes": nodes_out,
		"edges": edges_out,
		"spawns": spawns.duplicate(true),
		"bases": bases.duplicate(true),
	}
