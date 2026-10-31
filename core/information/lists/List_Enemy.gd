extends Node
class_name EnemyList
## 敵の定義。actions の中からランダムに次の行動（予告）を選ぶ。

const DATA = {
	"goblin": {"name": "ゴブリン", "hp": 16, "spd": 4, "def": 0, "art": "goblin",
		"actions": ["club", "bite", "block"]},
	"gool": {"name": "グール", "hp": 20, "spd": 2, "def": 0, "art": "gool",
		"actions": ["claw", "poison_stab"]},
	"zombie": {"name": "ゾンビ", "hp": 24, "spd": 1, "def": 0, "art": "zombie",
		"actions": ["bite", "poison_stab", "block"]},
	"skeleton": {"name": "スケルトン", "hp": 15, "spd": 5, "def": 1, "art": "skeleton",
		"actions": ["club", "shield_attack"]},
	"harpy": {"name": "ハーピー", "hp": 13, "spd": 7, "def": 0, "art": "harpy",
		"actions": ["claw", "claw", "curse"]},
	"fire_warriar": {"name": "炎の魔神", "hp": 19, "spd": 3, "def": 0, "art": "fire_warriar",
		"actions": ["flame_slash", "war_cry"]},
	"dark_knight": {"name": "デュラハン", "hp": 48, "spd": 3, "def": 1, "art": "dark_knight", "art_scale": 1.2,
		"actions": ["dark_slash", "shield_attack", "charge", "defend"]},
	"green_dragon": {"name": "緑龍", "hp": 90, "spd": 4, "def": 1, "art": "green_dragon", "art_scale": 1.3,
		"actions": ["fire_breath", "tail", "charge", "bite"]},
	"necro": {"name": "ネクロマンサー", "hp": 75, "spd": 5, "def": 0, "art": "necro", "art_scale": 1.35,
		"actions": ["dark_wave", "drain", "curse", "charge"]},
}


static func make_enemy(enemy_id: String, floor_no: int) -> Dictionary:
	var base: Dictionary = DATA[enemy_id]
	var hp := int(round(base.hp * (1.0 + 0.08 * floor_no)))
	return {
		"base_id": enemy_id, "name": base.name, "art": base.art,
		"art_scale": base.get("art_scale", 1.0),
		"hp": hp, "max_hp": hp, "spd": base.spd, "def": base.def, "atk": 0,
		"shield": 0, "side": "enemy", "status_effects": {},
		"actions": base.actions.duplicate(), "intent": {}, "next_action": "",
	}
