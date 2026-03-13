extends Node
class_name InitAllyStatus

# 味方の初期ステータス定義
# hp: 体力, max_hp: 最大体力, spd: 素早さ, def: 防御力, ap: アクションポイント
const DATA = {
	"knight": { "id": "knight",
		"name_jp": "ナイト",
		"hp": 20, "max_hp": 20,
		"spd": 3, "def": 1,
		"ap": 3, "max_ap": 5,"color":Color.GREEN,"side":"ally"
		,"icon": "sword_icon", "motion_group": "knight_motions"
	},
	"witch": { "id": "witch",
		"name_jp": "ウィッチ",
		"hp": 15, "max_hp": 15,
		"spd": 6, "def": 0,
		"ap": 3, "max_ap": 5,"color":Color.PURPLE,"side":"ally",
		"icon": "potion_icon", "motion_group": "witch_motions"
	}
}

static func get_status(character_id: String) -> Dictionary:
	return DATA[character_id].duplicate(true)
