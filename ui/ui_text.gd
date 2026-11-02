class_name UIText
extends RefCounted

## Shared Chinese labels for UI. Data display names live in CSV/JSON; these are
## for enum values and short explanations that are not worth another data file.

const ROLE := {
	"vanguard": "先锋",
	"anti_armor": "破甲",
	"shock": "突击",
	"ranged": "远程",
	"flanker": "游击",
	"siege": "攻城",
	"aoe": "范围",
	"support": "辅助",
}

const ATTACK := {
	"melee": "近战",
	"ranged": "远程",
	"siege": "攻城",
}

const ATTACK_SHORT := {
	"melee": "近",
	"ranged": "远",
	"siege": "攻",
}

const ARMOR := {
	"light": "轻甲",
	"heavy": "重甲",
}

const ARMOR_SHORT := {
	"light": "轻",
	"heavy": "重",
}

const PASSIVE_NAME := {
	"shield_wall": "盾墙",
	"armor_pierce": "破甲",
	"volley": "齐射",
	"charge": "冲锋",
	"splash": "溅射",
	"siege_master": "攻城精通",
	"backstab": "背刺",
	"heal": "治疗",
}

const PASSIVE_DESC := {
	"shield_wall": "受到远程伤害 -30%",
	"armor_pierce": "对重甲伤害 1.25×",
	"volley": "站定后攻速 +25%",
	"charge": "首次攻击 2×",
	"splash": "命中后对附近 50% 溅射",
	"siege_master": "对重甲伤害 1.25×",
	"backstab": "对远程伤害 1.5×",
	"heal": "治疗最残血的友军",
}

const STATE := {
	"advance": "推进",
	"engage": "接敌",
	"attack": "攻击",
	"hold": "驻守",
}


static func role_label(role: String) -> String:
	return String(ROLE.get(role, role))


static func attack_label(attack_type: String) -> String:
	return String(ATTACK.get(attack_type, attack_type))


static func attack_short(attack_type: String) -> String:
	return String(ATTACK_SHORT.get(attack_type, attack_type.substr(0, 1)))


static func armor_label(armor_type: String) -> String:
	return String(ARMOR.get(armor_type, armor_type))


static func armor_short(armor_type: String) -> String:
	return String(ARMOR_SHORT.get(armor_type, armor_type.substr(0, 1)))


static func passive_name(passive: String) -> String:
	if passive == "":
		return "无"
	return String(PASSIVE_NAME.get(passive, passive))


static func passive_desc(passive: String) -> String:
	if passive == "":
		return "无"
	return String(PASSIVE_DESC.get(passive, passive))


static func state_label(state: String) -> String:
	return String(STATE.get(state, state))


static func join_armor(values: Array) -> String:
	if values.is_empty():
		return "无"
	var parts: Array = []
	for value in values:
		parts.append(armor_label(String(value)))
	return "、".join(PackedStringArray(parts))


static func join_names(values: Array) -> String:
	if values.is_empty():
		return "无"
	var parts: Array = []
	for value in values:
		parts.append(String(value))
	return "、".join(PackedStringArray(parts))
