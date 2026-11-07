extends Node
class_name InitAllyStatus
## 味方の初期ステータス（battle-spec.md「キャラクター」。9 回目に HP 1.5 倍：ナイト 60・ウィッチ 33）。art はコードで描くキャラの種類名。

const AP_PER_TURN := 3  # 毎ターン開始時に AP 3（＋APプラス・予約などの加算）。ターン終了時に残りは捨てる（9 回目）
const AP_MAX := 7  # 大きな砂時計で +5（12）

const DATA = {
	"knight": {"id": "knight", "name": "ナイト",
		"hp": 60, "max_hp": 60, "spd": 3, "def": 2, "atk": 0, "shield": 0,
		"ap": 0, "max_ap": AP_MAX, "side": "ally", "art": "knight", "status_effects": {}},
	"witch": {"id": "witch", "name": "ウィッチ",
		"hp": 33, "max_hp": 33, "spd": 8, "def": 0, "atk": 0, "shield": 0,
		"ap": 0, "max_ap": AP_MAX, "side": "ally", "art": "witch", "status_effects": {}},
}


static func get_status(character_id: String) -> Dictionary:
	return DATA[character_id].duplicate(true)
