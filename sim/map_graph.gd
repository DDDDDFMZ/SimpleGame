class_name MapGraph
extends RefCounted

## Runtime pathfinding over a MapData graph. Immutable: per-battle occupancy and
## queues live in BattleSim. Graphs are small, so Dijkstra with a scan is enough.

var map_data: MapData
var nodes: Dictionary = {}
var edges: Dictionary = {}
var adjacency: Dictionary = {}
var path_cache: Dictionary = {}


func _init(p_map: MapData) -> void:
	map_data = p_map
	nodes = p_map.node_by_id
	edges = p_map.edge_by_id
	for node_id in nodes:
		adjacency[node_id] = []
	for edge_id in edges:
		var edge: Dictionary = edges[edge_id]
		var from_node := String(edge.get("from", ""))
		var to_node := String(edge.get("to", ""))
		if adjacency.has(from_node):
			adjacency[from_node].append(edge_id)
		if adjacency.has(to_node):
			adjacency[to_node].append(edge_id)


func node_pos(node_id: String) -> Vector2:
	var node: Dictionary = nodes.get(node_id, {})
	return node.get("pos", Vector2.ZERO)


func edge(edge_id: String) -> Dictionary:
	return edges.get(edge_id, {})


func edge_length(edge_id: String) -> float:
	return float(edge(edge_id).get("length", 0.0))


func edge_other(edge_id: String, node_id: String) -> String:
	var e := edge(edge_id)
	if String(e.get("from", "")) == node_id:
		return String(e.get("to", ""))
	if String(e.get("to", "")) == node_id:
		return String(e.get("from", ""))
	return ""


func edge_start(edge_id: String, from_node: String) -> bool:
	return String(edge(edge_id).get("from", "")) == from_node


func shortest_path(from_node: String, to_node: String) -> Array:
	if from_node == to_node:
		return []
	var cache_key := from_node + ">" + to_node
	if path_cache.has(cache_key):
		return path_cache[cache_key].duplicate()
	var dist: Dictionary = {}
	var previous_edge: Dictionary = {}
	var unvisited: Dictionary = {}
	for node_id in nodes:
		dist[node_id] = INF
		previous_edge[node_id] = ""
		unvisited[node_id] = true
	dist[from_node] = 0.0
	while not unvisited.is_empty():
		var current := ""
		var current_dist := INF
		for node_id in unvisited:
			if float(dist[node_id]) < current_dist:
				current = node_id
				current_dist = float(dist[node_id])
		if current == "" or current_dist == INF:
			break
		unvisited.erase(current)
		if current == to_node:
			break
		for edge_id in adjacency.get(current, []):
			var next_node := edge_other(String(edge_id), current)
			if next_node == "" or not unvisited.has(next_node):
				continue
			var next_dist := current_dist + edge_length(String(edge_id))
			if next_dist < float(dist[next_node]):
				dist[next_node] = next_dist
				previous_edge[next_node] = String(edge_id)
	var result: Array = []
	if not previous_edge.has(to_node) or String(previous_edge[to_node]) == "":
		path_cache[cache_key] = []
		return []
	var walk := to_node
	var guard := 0
	while walk != from_node and guard < 128:
		var prev := String(previous_edge.get(walk, ""))
		if prev == "":
			result.clear()
			break
		result.push_front(prev)
		walk = edge_other(prev, walk)
		guard += 1
	path_cache[cache_key] = result
	return result.duplicate()


func path_from_spawn(spawn_id: String, target_node: String) -> Array:
	var spawn_data := map_data.spawn(spawn_id)
	if spawn_data.is_empty():
		return []
	var base_node := String(spawn_data.get("base", ""))
	var entry := String(spawn_data.get("entry", ""))
	if not edges.has(entry):
		return []
	var far_node := edge_other(entry, base_node)
	if far_node == "":
		return []
	var result: Array = [entry]
	for edge_id in shortest_path(far_node, target_node):
		result.append(edge_id)
	return result


func path_to_edge(from_node: String, edge_id: String) -> Array:
	if not edges.has(edge_id):
		return []
	var e := edge(edge_id)
	var from_a := shortest_path(from_node, String(e.get("from", "")))
	var from_b := shortest_path(from_node, String(e.get("to", "")))
	if from_a.size() <= from_b.size():
		return from_a
	return from_b


func path_length(path: Array) -> float:
	var total := 0.0
	for edge_id in path:
		total += edge_length(String(edge_id))
	return total


func edge_point(edge_id: String, s: float) -> Vector2:
	var points: Array = edge(edge_id).get("points", [])
	if points.size() < 2:
		return Vector2.ZERO
	var length := edge_length(edge_id)
	var remaining := clampf(s, 0.0, length)
	for i in range(1, points.size()):
		var a: Vector2 = points[i - 1]
		var b: Vector2 = points[i]
		var segment := a.distance_to(b)
		if remaining <= segment or i == points.size() - 1:
			var ratio := remaining / maxf(0.001, segment)
			return a.lerp(b, clampf(ratio, 0.0, 1.0))
		remaining -= segment
	return Vector2(points[points.size() - 1])


func edge_progress(edge_id: String, world_pos: Vector2) -> float:
	var points: Array = edge(edge_id).get("points", [])
	if points.size() < 2:
		return 0.0
	var best_s := 0.0
	var best_dist := INF
	var walked := 0.0
	for i in range(1, points.size()):
		var a: Vector2 = points[i - 1]
		var b: Vector2 = points[i]
		var ab := b - a
		var segment := ab.length()
		if segment <= 0.001:
			continue
		var t := clampf((world_pos - a).dot(ab) / (segment * segment), 0.0, 1.0)
		var point := a + ab * t
		var dist := point.distance_squared_to(world_pos)
		if dist < best_dist:
			best_dist = dist
			best_s = walked + segment * t
		walked += segment
	return best_s


func edge_heading(edge_id: String, s: float) -> Vector2:
	var points: Array = edge(edge_id).get("points", [])
	if points.size() < 2:
		return Vector2.RIGHT
	var length := edge_length(edge_id)
	var remaining := clampf(s, 0.0, length)
	for i in range(1, points.size()):
		var a: Vector2 = points[i - 1]
		var b: Vector2 = points[i]
		var segment := a.distance_to(b)
		if remaining <= segment or i == points.size() - 1:
			return (b - a).normalized()
		remaining -= segment
	return Vector2.RIGHT


func nearest_point(world_pos: Vector2) -> Dictionary:
	var best := {
		"edge_id": "",
		"s": 0.0,
		"pos": world_pos,
		"distance": INF,
	}
	for edge_id in edges:
		var points: Array = edges[edge_id].get("points", [])
		if points.size() < 2:
			continue
		var walked := 0.0
		for i in range(1, points.size()):
			var a: Vector2 = points[i - 1]
			var b: Vector2 = points[i]
			var ab := b - a
			var segment := ab.length()
			if segment <= 0.001:
				continue
			var t := clampf((world_pos - a).dot(ab) / (segment * segment), 0.0, 1.0)
			var point := a + ab * t
			var dist := point.distance_to(world_pos)
			if dist < float(best["distance"]):
				best = {
					"edge_id": String(edge_id),
					"s": walked + segment * t,
					"pos": point,
					"distance": dist,
				}
			walked += segment
	return best


func nearest_point_on_route(spawn_id: String, target_node: String, world_pos: Vector2) -> Dictionary:
	var path := path_from_spawn(spawn_id, target_node)
	var best := {
		"edge_id": "",
		"s": 0.0,
		"pos": world_pos,
		"distance": INF,
		"path_index": -1,
	}
	for i in range(path.size()):
		var edge_id := String(path[i])
		var points: Array = edge(edge_id).get("points", [])
		if points.size() < 2:
			continue
		var walked := 0.0
		for j in range(1, points.size()):
			var a: Vector2 = points[j - 1]
			var b: Vector2 = points[j]
			var ab := b - a
			var segment := ab.length()
			if segment <= 0.001:
				continue
			var t := clampf((world_pos - a).dot(ab) / (segment * segment), 0.0, 1.0)
			var point := a + ab * t
			var dist := point.distance_to(world_pos)
			if dist < float(best["distance"]):
				best = {
					"edge_id": edge_id,
					"s": walked + segment * t,
					"pos": point,
					"distance": dist,
					"path_index": i,
				}
			walked += segment
	return best


func all_nodes() -> Array:
	var result: Array = []
	for node_id in nodes:
		result.append(nodes[node_id])
	return result


func all_edges() -> Array:
	var result: Array = []
	for edge_id in edges:
		result.append(edges[edge_id])
	return result
