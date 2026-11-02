class_name MapData
extends RefCounted

## Two-lane straight-road map data for M6.
## This is intentionally not a graph map yet: routes are one-dimensional and
## every unit still moves on a single lane index plus an X coordinate.

const DEFAULT_WORLD_WIDTH := 1600.0
const DEFAULT_WORLD_HEIGHT := 360.0
const DEFAULT_PLAYER_BASE_X := 80.0
const DEFAULT_ENEMY_BASE_X := 1520.0
const DEFAULT_LANE_Y := [110.0, 250.0]
const MIN_ROAD_WIDTH := 24.0
const MAX_ROAD_WIDTH := 160.0
const MIN_BASE_GAP := 240.0

var id: String = "default_two_lanes"
var name: String = "Two Lanes"
var name_cn: String = "双路战场"
var world_width: float = DEFAULT_WORLD_WIDTH
var world_height: float = DEFAULT_WORLD_HEIGHT
var bases: Array = []
var routes: Array = []
var errors: Array = []
var source_path: String = ""


func _init() -> void:
	reset_defaults()


func reset_defaults() -> void:
	world_width = DEFAULT_WORLD_WIDTH
	world_height = DEFAULT_WORLD_HEIGHT
	bases = [
		{"id": "player", "team": 0, "name": "Player Camp", "name_cn": "冒险者营地", "x": DEFAULT_PLAYER_BASE_X},
		{"id": "enemy", "team": 1, "name": "Enemy Camp", "name_cn": "敌方营地", "x": DEFAULT_ENEMY_BASE_X},
	]
	routes = []
	for lane in range(2):
		var y := float(DEFAULT_LANE_Y[lane])
		routes.append({
			"id": lane,
			"name": "Lane %d" % (lane + 1),
			"name_cn": "第%d路" % (lane + 1),
			"y": y,
			"player_spawn_x": DEFAULT_PLAYER_BASE_X + 12.0,
			"enemy_spawn_x": DEFAULT_ENEMY_BASE_X - 12.0,
			"segments": [
				{
					"from": DEFAULT_PLAYER_BASE_X,
					"to": DEFAULT_ENEMY_BASE_X,
					"width": 80.0,
				},
			],
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
	reset_defaults()
	id = String(source.get("id", id))
	name = String(source.get("name", name))
	name_cn = String(source.get("name_cn", name_cn))
	var world: Dictionary = source.get("world", {})
	world_width = clampf(float(world.get("width", world_width)), 480.0, 8000.0)
	world_height = clampf(float(world.get("height", world_height)), 240.0, 1080.0)

	_apply_bases(source.get("bases", []))
	_apply_routes(source.get("routes", []))
	_validate()


func _apply_bases(raw_bases: Variant) -> void:
	if raw_bases is Array and not raw_bases.is_empty():
		var by_team := {}
		for raw in raw_bases:
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var d: Dictionary = raw
			var team := int(d.get("team", -1))
			if team != 0 and team != 1:
				errors.append("基地 team 必须是 0 或 1")
				continue
			by_team[team] = {
				"id": String(d.get("id", "player" if team == 0 else "enemy")),
				"team": team,
				"name": String(d.get("name", "Player Camp" if team == 0 else "Enemy Camp")),
				"name_cn": String(d.get("name_cn", "冒险者营地" if team == 0 else "敌方营地")),
				"x": clampf(float(d.get("x", bases[team]["x"])), 20.0, world_width - 20.0),
			}
		for team in [0, 1]:
			if not by_team.has(team):
				errors.append("缺少 team=%d 的基地" % team)
			else:
				bases[team] = by_team[team]
	if float(bases[0]["x"]) > float(bases[1]["x"]):
		errors.append("玩家基地必须在敌方基地左侧")
	if float(bases[1]["x"]) - float(bases[0]["x"]) < MIN_BASE_GAP:
		errors.append("两个基地相距太近（至少 %.0f）" % MIN_BASE_GAP)


func _apply_routes(raw_routes: Variant) -> void:
	if not (raw_routes is Array) or raw_routes.is_empty():
		errors.append("地图至少需要一条路线")
		return
	var parsed_routes: Array = []
	for index in range(mini(2, raw_routes.size())):
		var raw: Variant = raw_routes[index]
		if typeof(raw) != TYPE_DICTIONARY:
			errors.append("路线 %d 不是对象" % index)
			continue
		var d: Dictionary = raw
		var fallback_y := float(DEFAULT_LANE_Y[index])
		var route := {
			"id": int(d.get("id", index)),
			"name": String(d.get("name", "Lane %d" % (index + 1))),
			"name_cn": String(d.get("name_cn", "第%d路" % (index + 1))),
			"y": clampf(float(d.get("y", fallback_y)), 50.0, world_height - 50.0),
			"width": clampf(float(d.get("width", 80.0)), MIN_ROAD_WIDTH, MAX_ROAD_WIDTH),
			"player_spawn_x": clampf(float(d.get("player_spawn_x", float(bases[0]["x"]) + 12.0)), float(bases[0]["x"]) + 8.0, float(bases[1]["x"]) - 8.0),
			"enemy_spawn_x": clampf(float(d.get("enemy_spawn_x", float(bases[1]["x"]) - 12.0)), float(bases[0]["x"]) + 8.0, float(bases[1]["x"]) - 8.0),
			"segments": [],
		}
		_apply_segments(route, d.get("segments", []), index)
		parsed_routes.append(route)
	if raw_routes.size() > 2:
		errors.append("M6 只支持两条路线，多余路线已忽略")
	routes = parsed_routes
	if routes.size() < 2:
		errors.append("M6 需要两条路线")


func _apply_segments(route: Dictionary, raw_segments: Variant, route_index: int) -> void:
	var base_left := float(bases[0]["x"])
	var base_right := float(bases[1]["x"])
	var raw_width := clampf(float(route.get("width", 80.0)), MIN_ROAD_WIDTH, MAX_ROAD_WIDTH)
	var segments: Array = []
	if raw_segments is Array:
		for raw in raw_segments:
			if typeof(raw) != TYPE_DICTIONARY:
				continue
			var d: Dictionary = raw
			var from_x := clampf(float(d.get("from", base_left)), base_left, base_right)
			var to_x := clampf(float(d.get("to", base_right)), base_left, base_right)
			if to_x < from_x:
				var swap := from_x
				from_x = to_x
				to_x = swap
			if to_x - from_x < 1.0:
				errors.append("路线 %d 存在长度过短的宽度段" % route_index)
				continue
			segments.append({
				"from": from_x,
				"to": to_x,
				"width": clampf(float(d.get("width", raw_width)), MIN_ROAD_WIDTH, MAX_ROAD_WIDTH),
			})
	segments.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["from"]) < float(b["from"]))
	if segments.is_empty():
		segments = [{"from": base_left, "to": base_right, "width": raw_width}]
	if not segments.is_empty():
		if float(segments[0]["from"]) > base_left + 0.5:
			errors.append("路线 %d 未覆盖玩家基地" % route_index)
		if float(segments[segments.size() - 1]["to"]) < base_right - 0.5:
			errors.append("路线 %d 未覆盖敌方基地" % route_index)
		for i in range(1, segments.size()):
			var prev_to := float(segments[i - 1]["to"])
			var next_from := float(segments[i]["from"])
			if next_from > prev_to + 0.5:
				errors.append("路线 %d 宽度段之间有缺口" % route_index)
			elif next_from < prev_to - 0.5:
				errors.append("路线 %d 宽度段重叠" % route_index)
	route["segments"] = segments


func _validate() -> void:
	if routes.size() < 2:
		return
	var y0 := float(routes[0]["y"])
	var y1 := float(routes[1]["y"])
	if absf(y0 - y1) < 40.0:
		errors.append("两条路线距离太近")
	for lane in range(routes.size()):
		var route: Dictionary = routes[lane]
		for segment in route.get("segments", []):
			var half := float(segment["width"]) * 0.5
			if float(route["y"]) - half < 0.0 or float(route["y"]) + half > world_height:
				errors.append("路线 %d 的宽度超出地图边界" % lane)
				break


func base_for_team(team: int) -> Dictionary:
	for base in bases:
		if int(base.get("team", -1)) == team:
			return base
	return {}


func base_x(team: int) -> float:
	var base := base_for_team(team)
	if base.is_empty():
		return DEFAULT_PLAYER_BASE_X if team == 0 else DEFAULT_ENEMY_BASE_X
	return float(base.get("x", 0.0))


func base_name(team: int) -> String:
	var base := base_for_team(team)
	return String(base.get("name_cn", base.get("name", "营地")))


func route_count() -> int:
	return routes.size()


func route(lane: int) -> Dictionary:
	if lane < 0 or lane >= routes.size():
		return {}
	return routes[lane]


func route_y(lane: int) -> float:
	var r := route(lane)
	return float(r.get("y", DEFAULT_LANE_Y[clampi(lane, 0, 1)]))


func route_name(lane: int) -> String:
	var r := route(lane)
	if r.is_empty():
		return "第%d路" % (lane + 1)
	return String(r.get("name_cn", r.get("name", "第%d路" % (lane + 1))))


func width_at(lane: int, x: float) -> float:
	var r := route(lane)
	if r.is_empty():
		return 80.0
	for segment in r.get("segments", []):
		if x >= float(segment["from"]) - 0.5 and x <= float(segment["to"]) + 0.5:
			return float(segment["width"])
	return float(r.get("segments", [{"width": 80.0}])[0].get("width", 80.0))


func spawn_x(lane: int, team: int) -> float:
	var r := route(lane)
	if r.is_empty():
		return base_x(team) + (12.0 if team == 0 else -12.0)
	var key := "player_spawn_x" if team == 0 else "enemy_spawn_x"
	return float(r.get(key, base_x(team) + (12.0 if team == 0 else -12.0)))


func lane_ys() -> Array:
	var result: Array = []
	for lane in range(routes.size()):
		result.append(route_y(lane))
	return result


func to_dict() -> Dictionary:
	return {
		"version": 1,
		"id": id,
		"name": name,
		"name_cn": name_cn,
		"world": {
			"width": world_width,
			"height": world_height,
		},
		"bases": bases.duplicate(true),
		"routes": routes.duplicate(true),
	}


func to_snapshot() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"name_cn": name_cn,
		"world_width": world_width,
		"world_height": world_height,
		"bases": bases.duplicate(true),
		"routes": routes.duplicate(true),
	}
