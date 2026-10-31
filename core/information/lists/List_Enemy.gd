extends Node
class_name EnemyList
## 敵の定義。actions の中からランダムに次の行動（予告）を選ぶ。

const DATA = {
	"goblin": {"name": "ゴブリン", "hp": 14, "spd": 4, "def": 0, "art": "goblin", "actions": ["club", "club", "flank", "guard_self"]},
	"gool": {"name": "グール", "hp": 18, "spd": 2, "def": 0, "art": "gool", "actions": ["claw", "burn_one"]},
	"zombie": {"name": "ゾンビ", "hp": 22, "spd": 1, "def": 0, "art": "zombie", "actions": ["bite", "bite", "guard_allies"]},
	"skeleton": {"name": "スケルトン", "hp": 12, "spd": 5, "def": 1, "art": "skeleton", "actions": ["club", "slash"]},
	"harpy": {"name": "ハーピー", "hp": 10, "spd": 7, "def": 0, "art": "harpy", "actions": ["claw", "gust", "flank"]},
	"fire_warriar": {"name": "炎の魔神", "hp": 16, "spd": 3, "def": 0, "art": "fire_warriar", "actions": ["slash", "burn_all"]},
	"dark_knight": {"name": "デュラハン", "hp": 60, "spd": 3, "def": 1, "art": "dark_knight", "art_scale": 1.15,
		"actions": ["dark_slash", "dark_flank", "big_guard", "charge", "war_cry"]},
	"green_dragon": {"name": "緑龍", "hp": 130, "spd": 4, "def": 1, "art": "green_dragon", "art_scale": 1.2,
		"actions": ["breath", "tail", "charge", "burn_all"]},
	"necro": {"name": "ネクロマンサー", "hp": 120, "spd": 5, "def": 0, "art": "necro", "art_scale": 1.25,
		"actions": ["dark_wave", "slash", "dark_heal", "charge"]},
}


static func make_enemy(enemy_id: String, floor_no: int) -> Dictionary:
	var base: Dictionary = DATA[enemy_id]
	var hp := int(round(base.hp * (1.0 + 0.06 * floor_no)))
	return {
		"base_id": enemy_id, "name": base.name, "art": base.art,
		"art_scale": base.get("art_scale", 1.0),
		"hp": hp, "max_hp": hp, "spd": base.spd, "def": base.def,
		"shield": 0, "side": "enemy", "status_effects": {}, "atk": int(floor_no / 2.0),
		"actions": base.actions.duplicate(), "intent": {}, "intent_id": "", "next_action": "", "target_lane": 0,
	}
