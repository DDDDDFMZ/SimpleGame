class_name BattleView
extends Node2D

const LANE_Y := [110.0, 250.0]
const VIEW_W := 640.0
const VIEW_H := 360.0

var runner: SimRunner
var unit_views: Dictionary = {}
var last_snapshot: Dictionary = {}


func setup(p_runner: SimRunner) -> void:
	runner = p_runner
	if not runner.ticked.is_connected(_on_ticked):
		runner.ticked.connect(_on_ticked)


func reset_view() -> void:
	for view in unit_views.values():
		view.queue_free()
	unit_views.clear()
	last_snapshot = {}
	queue_redraw()


func _on_ticked(snapshot: Dictionary) -> void:
	last_snapshot = snapshot
	_sync_units(snapshot.get("units", []))
	queue_redraw()


func _sync_units(units_data: Array) -> void:
	var seen := {}
	for data in units_data:
		var id := int(data.get("id", -1))
		if id < 0:
			continue
		seen[id] = true
		var view: UnitView = unit_views.get(id)
		if view == null:
			view = UnitView.new()
			add_child(view)
			unit_views[id] = view
		var lane := clampi(int(data.get("lane", 0)), 0, LANE_Y.size() - 1)
		view.update_data(data, LANE_Y[lane])

	for id in unit_views.keys():
		if not seen.has(id):
			unit_views[id].queue_free()
			unit_views.erase(id)


func _draw() -> void:
	# Background and two lanes.
	draw_rect(Rect2(0.0, 0.0, VIEW_W, VIEW_H), Color("#1E1A2B"))
	for i in range(LANE_Y.size()):
		var y := float(LANE_Y[i])
		draw_rect(Rect2(50.0, y - 40.0, 540.0, 80.0), Color("#2E2A3A"))
		draw_line(Vector2(50.0, y), Vector2(590.0, y), Color("#3E3A4A"), 1.0)

	# Base gates.
	draw_rect(Rect2(20.0, 40.0, 30.0, 280.0), Color("#2B4A6F"))
	draw_rect(Rect2(590.0, 40.0, 30.0, 280.0), Color("#6F2B2B"))

	var font := ThemeDB.fallback_font
	if font != null:
		draw_string(font, Vector2(56.0, 66.0), "LANE 1", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#B8B0C8"))
		draw_string(font, Vector2(56.0, 206.0), "LANE 2", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#B8B0C8"))
		draw_string(font, Vector2(24.0, 34.0), "P", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#6FA8DC"))
		draw_string(font, Vector2(596.0, 34.0), "E", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#E06666"))

	# Projectiles are cheap to draw directly; no per-projectile node needed yet.
	for p in last_snapshot.get("projectiles", []):
		var lane := clampi(int(p.get("lane", 0)), 0, LANE_Y.size() - 1)
		var color := Color("#D9A441") if int(p.get("team", 0)) == 0 else Color("#E06666")
		draw_circle(Vector2(float(p.get("x", 0.0)), LANE_Y[lane]), 2.0, color)
