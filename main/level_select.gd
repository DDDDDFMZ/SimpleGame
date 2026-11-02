extends Control

const VIEW_W := 640.0
const VIEW_H := 360.0
const CARD_Y := 82.0
const CARD_W := 184.0
const CARD_H := 148.0
const CARD_GAP := 12.0
const ENDLESS_RECT := Rect2(30.0, 242.0, 580.0, 66.0)
const GUILD_CN := {"iron": "铁誓会", "verdant": "绿荫游侠团", "arcane": "星环秘法会"}

var font: Font
var levels: Array = []
var contract_ids: Array = []
var message: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "SimHei"])
	font = system_font
	for contract in GameState.get_contracts():
		contract_ids.append(int(contract))
		levels.append(_load_json(GameState.get_level_path(int(contract))))
	queue_redraw()


func _load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, VIEW_W, VIEW_H), Color("#15121E"))
	draw_rect(Rect2(0.0, 0.0, VIEW_W, 62.0), Color("#0C0A12"))
	draw_string(font, Vector2(30.0, 30.0), "灰港委托", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 22, Color("#E8D5A9"))
	draw_string(font, Vector2(150.0, 30.0), "GREYHAVEN CONTRACTS", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#8A8498"))
	draw_string(font, Vector2(30.0, 50.0), "灰鸦小队 · 选择一份委托", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#B8B0C8"))

	for i in range(levels.size()):
		_draw_contract(i)

	_draw_endless()
	_draw_favor()
	draw_string(font, Vector2(30.0, 344.0), "1-3 选择委托 · E 无尽 · Esc 退出", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#6B6B6B"))
	if message != "":
		draw_string(font, Vector2(330.0, 344.0), message, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#E06666"))


func _draw_contract(index: int) -> void:
	var level: Dictionary = levels[index]
	var contract_id := int(level.get("contract", index + 1))
	var unlocked: bool = GameState.is_contract_unlocked(contract_id)
	var stars: int = GameState.star_for(contract_id)
	var rect := _card_rect(index)
	var hover := rect.has_point(get_local_mouse_position())

	draw_rect(rect, Color("#1A1724") if unlocked else Color("#121019"))
	draw_rect(rect, Color("#D9A441") if unlocked and hover else (Color("#4A4658") if unlocked else Color("#2A2635")), false, 1.5 if unlocked and hover else 1.0)

	var title := String(level.get("name_cn", level.get("name", "Contract %d" % contract_id)))
	draw_string(font, rect.position + Vector2(10.0, 22.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color("#E8D5A9") if unlocked else Color("#6B6B6B"))

	var star_text := ""
	for i in range(3):
		star_text += "★" if i < stars else "☆"
	draw_string(font, rect.position + Vector2(10.0, 40.0), star_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 11, Color("#D9A441"))

	if unlocked:
		var brief := String(level.get("brief_cn", level.get("brief", "")))
		_draw_wrapped(rect.position + Vector2(10.0, 60.0), brief, 8, 20, Color("#B8B0C8"))
		var guilds: Array = level.get("available_guilds", [])
		var guild_names: Array = []
		for guild_id in guilds:
			guild_names.append(GUILD_CN.get(String(guild_id), String(guild_id)))
		var guild_text := "协会: " + ", ".join(PackedStringArray(guild_names))
		draw_string(font, rect.position + Vector2(10.0, 132.0), guild_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#6FA8DC"))
	else:
		draw_string(font, rect.position + Vector2(10.0, 70.0), "LOCKED", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color("#4A4658"))
		draw_string(font, rect.position + Vector2(10.0, 92.0), "完成上一份委托后解锁", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#4A4658"))


func _draw_endless() -> void:
	var rect := ENDLESS_RECT
	var unlocked := GameState.endless_unlocked
	draw_rect(rect, Color("#1A1724") if unlocked else Color("#121019"))
	draw_rect(rect, Color("#6FA8DC") if unlocked else Color("#2A2635"), false, 1.0)
	draw_string(font, rect.position + Vector2(12.0, 22.0), "无尽悬赏  ENDLESS BOUNTIES", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color("#E8D5A9") if unlocked else Color("#6B6B6B"))
	var best := GameState.best_endless
	draw_string(font, rect.position + Vector2(12.0, 42.0), "最佳: %d 分 / %d 波" % [int(best.get("score", 0)), int(best.get("waves", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#B8B0C8"))
	if not unlocked:
		draw_string(font, rect.position + Vector2(420.0, 42.0), "通关委托 3 解锁", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#8A8498"))


func _draw_favor() -> void:
	var y := 318.0
	draw_string(font, Vector2(30.0, y), "协会人情:", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#8A8498"))
	var x := 90.0
	for guild_id in ["iron", "verdant", "arcane"]:
		var text := "%s %s" % [GUILD_CN.get(guild_id, guild_id), GameState.guild_bonus_text(guild_id)]
		draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#6FA8DC"))
		x += 170.0


func _draw_wrapped(pos: Vector2, text: String, size: int, max_chars: int, color: Color) -> void:
	var line := ""
	var y := pos.y
	for ch in text:
		line += ch
		if line.length() >= max_chars or ch == "\n":
			draw_string(font, Vector2(pos.x, y), line.strip_edges(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
			line = ""
			y += size + 4.0
	if line != "":
		draw_string(font, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _card_rect(index: int) -> Rect2:
	return Rect2(30.0 + index * (CARD_W + CARD_GAP), CARD_Y, CARD_W, CARD_H)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var pos: Vector2 = event.position
	for i in range(levels.size()):
		if _card_rect(i).has_point(pos):
			_start_contract(int(contract_ids[i]))
			accept_event()
			return
	if ENDLESS_RECT.has_point(pos):
		_start_endless()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1, KEY_2, KEY_3:
			var index: int = event.keycode - KEY_1
			if index >= 0 and index < contract_ids.size():
				_start_contract(int(contract_ids[index]))
		KEY_E:
			_start_endless()
		KEY_ESCAPE:
			get_tree().quit()


func _start_contract(contract_id: int) -> void:
	if not GameState.select_contract(contract_id):
		message = "该委托尚未解锁"
		queue_redraw()
		return
	get_tree().change_scene_to_file("res://scenes/battle.tscn")


func _start_endless() -> void:
	if not GameState.select_endless():
		message = "通关委托 3 后解锁无尽"
		queue_redraw()
		return
	get_tree().change_scene_to_file("res://scenes/battle.tscn")
