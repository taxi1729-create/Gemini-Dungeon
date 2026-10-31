extends Node
class_name InitAllyStatus
## 味方の初期ステータス。art はコードで描くキャラの種類名。

const DATA = {
	"knight": {"id": "knight", "name": "ナイト",
		"hp": 32, "max_hp": 32, "spd": 3, "def": 1, "atk": 0, "shield": 0,
		"ap": 3, "max_ap": 5, "side": "ally", "art": "knight", "status_effects": {}},
	"witch": {"id": "witch", "name": "ウィッチ",
		"hp": 24, "max_hp": 24, "spd": 6, "def": 0, "atk": 0, "shield": 0,
		"ap": 3, "max_ap": 5, "side": "ally", "art": "witch", "status_effects": {}},
}


static func get_status(character_id: String) -> Dictionary:
	return DATA[character_id].duplicate(true)
