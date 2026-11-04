extends Control

const VIEW_W := 640.0
const VIEW_H := 360.0
const CARD_Y := 82.0
const CARD_W := 184.0
const CARD_H := 148.0
const CARD_GAP := 12.0
const ENDLESS_RECT := Rect2(30.0, 242.0, 580.0, 66.0)
const SAVE_RECT := Rect2(56.0, 68.0, 528.0, 242.0)
const SETTINGS_BUTTON := Rect2(548.0, 12.0, 72.0, 24.0)

@onready var settings_panel: SettingsPanel = $SettingsPanel

var font: Font
var levels: Array = []
var contract_ids: Array = []
var message: String = ""
var save_panel_open: bool = false
var backups: Array = []
var selected_backup: int = 0
var save_confirm: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "SimHei"])
	font = system_font
	for contract in GameState.get_contracts():
		contract_ids.append(int(contract))
		levels.append(_load_json(GameState.get_level_path(int(contract))))
	if GameState.load_status == "recovered":
		message = "主存档损坏，已从最近备份恢复"
	elif GameState.load_status == "corrupt":
		message = "主存档损坏且无可用备份，已使用默认进度"
	settings_panel.closed.connect(queue_redraw)
	queue_redraw()
	if _has_map_editor_arg() and not GameState.map_editor_auto_opened:
		GameState.map_editor_auto_opened = true
		call_deferred("_open_map_editor", true)


func _has_map_editor_arg() -> bool:
	return "--map-editor" in OS.get_cmdline_args() or "--map-editor" in OS.get_cmdline_user_args()


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
	draw_string(font, Vector2(150.0, 30.0), "灰鸦小队 · 冒险者协会委托板", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#8A8498"))
	draw_string(font, Vector2(30.0, 50.0), "选择一份委托，带上你的冒险者守住灰港。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#B8B0C8"))
	draw_rect(SETTINGS_BUTTON, Color("#252232"))
	draw_rect(SETTINGS_BUTTON, Color("#4A4658"), false, 1.0)
	_center_text_in("设置 [O]", SETTINGS_BUTTON, 8, Color("#E8D5A9"))

	for i in range(levels.size()):
		_draw_contract(i)

	_draw_endless()
	_draw_favor()
	var footer := "1-3 选择委托 · E 无尽 · S 存档/备份 · O 设置 · Esc 退出"
	if OS.is_debug_build():
		footer += " · F3 地图编辑器（调试）"
	draw_string(font, Vector2(30.0, 344.0), footer, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#6B6B6B"))
	if message != "":
		draw_string(font, Vector2(330.0, 344.0), message, HORIZONTAL_ALIGNMENT_LEFT, 300.0, 9, Color("#E06666"))
	if save_panel_open:
		_draw_save_panel()


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
			guild_names.append(_guild_name(String(guild_id)))
		var guild_text := "协会：" + "、".join(PackedStringArray(guild_names))
		draw_string(font, rect.position + Vector2(10.0, 132.0), guild_text, HORIZONTAL_ALIGNMENT_LEFT, 164.0, 8, Color("#6FA8DC"))
	else:
		draw_string(font, rect.position + Vector2(10.0, 70.0), "尚未解锁", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color("#4A4658"))
		draw_string(font, rect.position + Vector2(10.0, 92.0), "完成上一份委托后解锁", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#4A4658"))


func _draw_endless() -> void:
	var rect := ENDLESS_RECT
	var unlocked := GameState.endless_unlocked
	draw_rect(rect, Color("#1A1724") if unlocked else Color("#121019"))
	draw_rect(rect, Color("#6FA8DC") if unlocked else Color("#2A2635"), false, 1.0)
	draw_string(font, rect.position + Vector2(12.0, 22.0), "无尽悬赏", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color("#E8D5A9") if unlocked else Color("#6B6B6B"))
	var best := GameState.best_endless
	draw_string(font, rect.position + Vector2(12.0, 42.0), "最佳：%d 分 / %d 波" % [int(best.get("score", 0)), int(best.get("waves", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#B8B0C8"))
	if not unlocked:
		draw_string(font, rect.position + Vector2(420.0, 42.0), "通关委托 3 解锁", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, Color("#8A8498"))


func _draw_favor() -> void:
	var y := 318.0
	draw_string(font, Vector2(30.0, y), "协会人情：", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#8A8498"))
	var x := 92.0
	var guild_ids: Array = GameState.game_data.guild_order if GameState.game_data != null else ["iron", "verdant", "arcane"]
	for guild_id in guild_ids:
		var text := "%s %s" % [_guild_name(String(guild_id)), GameState.guild_bonus_text(String(guild_id))]
		draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, 168.0, 8, Color("#6FA8DC"))
		x += 170.0


func _guild_name(guild_id: String) -> String:
	if GameState.game_data != null and GameState.game_data.guild_defs.has(guild_id):
		var guild: Dictionary = GameState.game_data.guild_defs[guild_id]
		return String(guild.get("name_cn", guild.get("name", guild_id)))
	return guild_id


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


func _draw_save_panel() -> void:
	draw_rect(Rect2(0.0, 0.0, VIEW_W, VIEW_H), Color(0.0, 0.0, 0.0, 0.55))
	draw_rect(SAVE_RECT, Color(0.06, 0.05, 0.09, 0.99))
	draw_rect(SAVE_RECT, Color("#D9A441"), false, 1.5)
	draw_string(font, SAVE_RECT.position + Vector2(14.0, 20.0), "存档与备份", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color("#E8D5A9"))
	draw_string(font, SAVE_RECT.position + Vector2(150.0, 20.0), "当前主档：user://save.json", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 7, Color("#8A8498"))
	if save_confirm != "":
		var confirm := Rect2(140.0, 130.0, 360.0, 80.0)
		draw_rect(confirm, Color("#1A1724"))
		draw_rect(confirm, Color("#E06666"), false, 1.0)
		_center_text_in("确认%s？此操作会先备份当前进度。" % ("新存档" if save_confirm == "new" else "恢复所选备份"), Rect2(150.0, 142.0, 340.0, 26.0), 9, Color("#E8D5A9"))
		draw_rect(Rect2(210.0, 178.0, 90.0, 22.0), Color("#3A2020"))
		draw_rect(Rect2(340.0, 178.0, 90.0, 22.0), Color("#252232"))
		_center_text_in("确认", Rect2(210.0, 178.0, 90.0, 22.0), 8, Color("#E06666"))
		_center_text_in("取消", Rect2(340.0, 178.0, 90.0, 22.0), 8, Color("#B8B0C8"))
		return
	if backups.is_empty():
		draw_string(font, SAVE_RECT.position + Vector2(14.0, 62.0), "暂无备份。每次保存会轮换保留最近 8 个备份。", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("#8A8498"))
	for i in range(mini(backups.size(), 4)):
		var row := Rect2(SAVE_RECT.position.x + 12.0, SAVE_RECT.position.y + 48.0 + i * 30.0, SAVE_RECT.size.x - 24.0, 26.0)
		var backup: Dictionary = backups[i]
		draw_rect(row, Color("#252232") if i != selected_backup else Color("#3B3348"))
		draw_rect(row, Color("#D9A441") if i == selected_backup else Color("#4A4658"), false, 1.0)
		var contracts: Array = backup.get("contracts", [])
		draw_string(font, row.position + Vector2(8.0, 17.0), "%s   委托 %d   ★%d" % [_format_backup_time(int(backup.get("modified", 0))), contracts.size(), int(backup.get("stars", 0))], HORIZONTAL_ALIGNMENT_LEFT, 450.0, 7, Color("#B8B0C8"))
	var button_y := SAVE_RECT.position.y + SAVE_RECT.size.y - 36.0
	var buttons := [
		["手动备份", Rect2(SAVE_RECT.position.x + 14.0, button_y, 108.0, 24.0)],
		["恢复选中", Rect2(SAVE_RECT.position.x + 132.0, button_y, 108.0, 24.0)],
		["新存档", Rect2(SAVE_RECT.position.x + 250.0, button_y, 88.0, 24.0)],
		["关闭", Rect2(SAVE_RECT.position.x + 348.0, button_y, 88.0, 24.0)],
	]
	for entry in buttons:
		var rect: Rect2 = entry[1]
		draw_rect(rect, Color("#252232"))
		draw_rect(rect, Color("#4A4658"), false, 1.0)
		_center_text_in(String(entry[0]), rect, 8, Color("#E8D5A9"))


func _format_backup_time(timestamp: int) -> String:
	if timestamp <= 0:
		return "未知时间"
	var dt: Dictionary = Time.get_datetime_dict_from_unix_time(timestamp)
	return "%02d-%02d %02d:%02d" % [int(dt.get("month", 1)), int(dt.get("day", 1)), int(dt.get("hour", 0)), int(dt.get("minute", 0))]


func _handle_save_click(pos: Vector2) -> void:
	if not SAVE_RECT.has_point(pos):
		return
	if save_confirm != "":
		if Rect2(210.0, 178.0, 90.0, 22.0).has_point(pos):
			_apply_save_confirm()
		elif Rect2(340.0, 178.0, 90.0, 22.0).has_point(pos):
			save_confirm = ""
		queue_redraw()
		return
	for i in range(mini(backups.size(), 4)):
		if Rect2(SAVE_RECT.position.x + 12.0, SAVE_RECT.position.y + 48.0 + i * 30.0, SAVE_RECT.size.x - 24.0, 26.0).has_point(pos):
			selected_backup = i
			queue_redraw()
			return
	var button_y := SAVE_RECT.position.y + SAVE_RECT.size.y - 36.0
	if Rect2(SAVE_RECT.position.x + 14.0, button_y, 108.0, 24.0).has_point(pos):
		GameState.backup_progress("manual")
		_refresh_backups()
		message = "已创建手动备份"
		return
	if Rect2(SAVE_RECT.position.x + 132.0, button_y, 108.0, 24.0).has_point(pos):
		if not backups.is_empty():
			save_confirm = "restore"
		return
	if Rect2(SAVE_RECT.position.x + 250.0, button_y, 88.0, 24.0).has_point(pos):
		save_confirm = "new"
		return
	if Rect2(SAVE_RECT.position.x + 348.0, button_y, 88.0, 24.0).has_point(pos):
		save_panel_open = false
		queue_redraw()


func _apply_save_confirm() -> void:
	var action := save_confirm
	save_confirm = ""
	if action == "restore":
		if selected_backup < 0 or selected_backup >= backups.size():
			return
		var path := String(backups[selected_backup].get("path", ""))
		if GameState.restore_backup(path):
			message = "已恢复备份"
		else:
			message = "恢复失败：备份文件无效"
	elif action == "new":
		if GameState.new_game():
			message = "已开始新存档（旧进度已备份）"
		else:
			message = "新存档失败"
	_refresh_backups()
	queue_redraw()


func _refresh_backups() -> void:
	backups = GameState.list_backups()
	selected_backup = clampi(selected_backup, 0, maxi(0, backups.size() - 1))


func _open_save_panel() -> void:
	save_panel_open = true
	save_confirm = ""
	selected_backup = 0
	_refresh_backups()
	queue_redraw()


func _open_settings() -> void:
	save_panel_open = false
	save_confirm = ""
	settings_panel.open(0)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if settings_panel.visible:
		return
	var pos: Vector2 = event.position
	if SETTINGS_BUTTON.has_point(pos):
		_open_settings()
		accept_event()
		return
	if save_panel_open:
		_handle_save_click(pos)
		accept_event()
		return
	for i in range(levels.size()):
		if _card_rect(i).has_point(pos):
			_start_contract(int(contract_ids[i]))
			accept_event()
			return
	if ENDLESS_RECT.has_point(pos):
		_start_endless()
		accept_event()


func _center_text_in(text: String, rect: Rect2, size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	draw_string(font, Vector2(rect.position.x + (rect.size.x - width) * 0.5, rect.position.y + rect.size.y * 0.5 + 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if settings_panel.visible:
		return
	if save_panel_open:
		if event.keycode == KEY_ESCAPE:
			save_panel_open = false
			save_confirm = ""
			queue_redraw()
		return
	match event.keycode:
		KEY_1, KEY_2, KEY_3:
			var index: int = event.keycode - KEY_1
			if index >= 0 and index < contract_ids.size():
				_start_contract(int(contract_ids[index]))
		KEY_E:
			_start_endless()
		KEY_S:
			_open_save_panel()
		KEY_O:
			_open_settings()
		KEY_F3:
			_open_map_editor()
		KEY_ESCAPE:
			get_tree().quit()


func _open_map_editor(force := false) -> void:
	if not force and not OS.is_debug_build():
		message = "按 F3 只在调试版开放；发行版用 --map-editor 启动"
		queue_redraw()
		return
	get_tree().change_scene_to_file("res://main/map_editor.tscn")


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
