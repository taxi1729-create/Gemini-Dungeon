extends Node
class_name InitAllyStatus
## 味方の初期ステータス（battle-spec.md「キャラクター」）。art はコードで描くキャラの種類名。

const AP_PER_TURN := 3  # 毎ターン +3、余りは持ち越し
const AP_MAX := 10

const DATA = {
	"knight": {"id": "knight", "name": "ナイト",
		"hp": 40, "max_hp": 40, "spd": 3, "def": 2, "atk": 0, "shield": 0,
		"ap": 0, "max_ap": AP_MAX, "side": "ally", "art": "knight", "status_effects": {}},
	"witch": {"id": "witch", "name": "ウィッチ",
		"hp": 22, "max_hp": 22, "spd": 8, "def": 0, "atk": 0, "shield": 0,
		"ap": 0, "max_ap": AP_MAX, "side": "ally", "art": "witch", "status_effects": {}},
}


static func get_status(character_id: String) -> Dictionary:
	return DATA[character_id].duplicate(true)
