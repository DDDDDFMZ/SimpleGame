class_name UnitView
extends Node2D

var data: Dictionary = {}
var selected: bool = false


func update_data(p_data: Dictionary, lane_y: float) -> void:
	data = p_data
	var slot := int(data.get("slot", 0))
	position = Vector2(float(data["x"]), lane_y + (slot - 1) * 6.0)
	queue_redraw()


func set_selected(value: bool) -> void:
	if selected == value:
		return
	selected = value
	queue_redraw()


func _draw() -> void:
	if data.is_empty():
		return

	var team := int(data.get("team", 0))
	var color := Color("#3B6EA5") if team == 0 else Color("#A53B3B")
	var bar_color := Color("#6FA8DC") if team == 0 else Color("#E06666")

	# Placeholder body: 14x20 rectangle, not final art.
	draw_rect(Rect2(-7.0, -10.0, 14.0, 20.0), color)
	draw_rect(Rect2(-7.0, -10.0, 14.0, 20.0), Color(0.0, 0.0, 0.0, 0.45), false, 1.0)
	if bool(data.get("is_elite", false)):
		draw_rect(Rect2(-8.0, -11.0, 16.0, 22.0), Color("#D9A441"), false, 1.5)
	if selected:
		draw_arc(Vector2(0.0, 0.0), 12.0, 0.0, TAU, 16, Color("#D9A441"), 1.5)

	# Simple attack-type glyph for debugging.
	var attack_type := String(data.get("attack_type", "melee"))
	var glyph_color := Color(1.0, 1.0, 1.0, 0.8)
	match attack_type:
		"melee":
			draw_line(Vector2(-5.0, 0.0), Vector2(5.0, 0.0), glyph_color, 1.5)
		"ranged":
			draw_circle(Vector2(0.0, 0.0), 2.5, glyph_color)
		"siege":
			draw_rect(Rect2(-3.0, -3.0, 6.0, 6.0), glyph_color)

	var max_hp := maxf(1.0, float(data.get("max_hp", 1.0)))
	var ratio := clampf(float(data.get("hp", 0.0)) / max_hp, 0.0, 1.0)
	draw_rect(Rect2(-8.0, -14.0, 16.0, 3.0), Color(0.0, 0.0, 0.0, 0.7))
	if ratio > 0.0:
		draw_rect(Rect2(-8.0, -14.0, 16.0 * ratio, 3.0), bar_color)
