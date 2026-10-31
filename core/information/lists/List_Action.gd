extends Node
class_name ActionList
## カード（味方の行動）と敵の行動の定義。
## art   : カードの絵柄（ImageController.icon の種類名。画像ファイルは使わない）
## target: self / ally_all / enemy_all / front_enemy_single / front_enemy_group
## effect: add_shield / add_ap / add_status / heal / set_next_action
## effect_target: "self" なら効果は使用者に付く（省略時は対象に付く）

const ALLY_CARDS = {
	"common": {
		"block": {"name": "ブロック", "type": "skill", "target": "self", "art": "shield",
				"effect": "add_shield", "eff_val": 6, "ap": 1},
		"companion_block": {"name": "コンパニオンブロック", "type": "skill", "target": "self", "art": "def_buff",
				"effect": "add_status", "status": "def_buff", "eff_val": 2, "ap": 1},
		"firebolt": {"name": "ファイアボルト", "type": "attack", "target": "enemy_all", "art": "flame",
				"effect": "add_status", "status": "fire", "eff_val": 2, "power": 3, "ap": 2},
		"weak_point": {"name": "急所突き", "type": "attack", "target": "front_enemy_single", "art": "dagger",
				"effect": "add_status", "status": "atk_debuff", "eff_val": 2, "power": 4, "ap": 1},
	},
	"rare": {
		"strike": {"name": "ストライク", "type": "attack", "target": "front_enemy_single", "art": "sword",
				"power": 8, "ap": 1},
		"strong_block": {"name": "全体守護", "type": "skill", "target": "ally_all", "art": "shield",
				"effect": "add_shield", "eff_val": 6, "ap": 2},
		"sweep": {"name": "薙ぎ払い", "type": "attack", "target": "front_enemy_group", "art": "sweep",
				"power": 6, "ap": 1},
		"thunderbolt": {"name": "サンダーボルト", "type": "attack", "target": "enemy_all", "art": "bolt",
				"effect": "add_status", "status": "atk_debuff", "eff_val": 1, "power": 4, "ap": 2},
	},
	"super_rare": {
		"action_accel": {"name": "アクション加速", "type": "skill", "target": "self", "art": "chevrons",
				"effect": "add_ap", "eff_val": 1, "ap": 0},
		"shield_attack": {"name": "シールドアタック", "type": "attack", "target": "enemy_all", "art": "shield_sword",
				"effect": "add_status", "status": "def_buff", "effect_target": "self", "eff_val": 1, "power": 4, "ap": 2},
		"attack_up": {"name": "アタックアップ", "type": "skill", "target": "ally_all", "art": "atk_buff",
				"effect": "add_status", "status": "atk_buff", "eff_val": 2, "ap": 1},
		"force": {"name": "フォース", "type": "unselectable", "target": "self", "art": "burst",
				"effect": "add_status", "status": "atk_buff", "timing": "start_turn", "eff_val": 2},
	},
}

## 必殺技（1戦闘に1回ずつ）
const SPECIALS = {
	"knight": {"name": "ブレイブスラッシュ", "type": "attack", "target": "front_enemy_group", "art": "burst",
			"power": 14},
	"witch": {"name": "メテオ", "type": "attack", "target": "enemy_all", "art": "flame",
			"effect": "add_status", "status": "fire", "eff_val": 3, "power": 7},
}

const ENEMY_ACTIONS = {
	"bite": {"name": "噛み付く", "type": "attack", "target": "front_enemy_single", "power": 4},
	"claw": {"name": "引っかく", "type": "attack", "target": "front_enemy_single", "power": 5},
	"club": {"name": "棍棒", "type": "attack", "target": "front_enemy_single", "power": 6},
	"poison_stab": {"name": "毒突き", "type": "attack", "target": "front_enemy_single",
			"effect": "add_status", "status": "poison", "eff_val": 3, "power": 2},
	"block": {"name": "身構える", "type": "skill", "target": "self",
			"effect": "add_status", "status": "def_buff", "eff_val": 2},
	"defend": {"name": "防御陣", "type": "skill", "target": "ally_all", "effect": "add_shield", "eff_val": 5},
	"shield_attack": {"name": "シールドアタック", "type": "attack", "target": "front_enemy_single", "power": 4,
			"effect": "add_shield", "effect_target": "self", "eff_val": 6},
	"charge": {"name": "力を溜める", "type": "skill", "target": "self", "effect": "set_next_action",
			"next": "strong_attack"},
	"strong_attack": {"name": "強攻撃", "type": "attack", "target": "enemy_all", "power": 9},
	"flame_slash": {"name": "炎の剣", "type": "attack", "target": "front_enemy_single", "power": 4,
			"effect": "add_status", "status": "fire", "eff_val": 2},
	"dark_slash": {"name": "闇の斬撃", "type": "attack", "target": "front_enemy_single", "power": 9},
	"war_cry": {"name": "雄叫び", "type": "skill", "target": "ally_all",
			"effect": "add_status", "status": "atk_buff", "eff_val": 2},
	"fire_breath": {"name": "炎の息", "type": "attack", "target": "enemy_all", "power": 5,
			"effect": "add_status", "status": "fire", "eff_val": 2},
	"tail": {"name": "尻尾の一撃", "type": "attack", "target": "front_enemy_group", "power": 8},
	"curse": {"name": "呪い", "type": "skill", "target": "enemy_all",
			"effect": "add_status", "status": "def_debuff", "eff_val": 2},
	"drain": {"name": "生命吸収", "type": "attack", "target": "front_enemy_single", "power": 6,
			"effect": "heal", "effect_target": "self", "eff_val": 6},
	"dark_wave": {"name": "暗黒波", "type": "attack", "target": "enemy_all", "power": 5},
}


## カードIDからカード辞書（rarity・id 付きのコピー）を作る
static func make_card(card_id: String) -> Dictionary:
	for rarity in ["common", "rare", "super_rare"]:
		if ALLY_CARDS[rarity].has(card_id):
			var c: Dictionary = ALLY_CARDS[rarity][card_id].duplicate(true)
			c["id"] = card_id
			c["rarity"] = "normal" if rarity == "common" else rarity
			return c
	return {}


## 報酬用にランダムなカードIDを選ぶ（レアほど出にくい）
static func random_card_id() -> String:
	var roll := randf()
	var tier := "common"
	if roll > 0.9:
		tier = "super_rare"
	elif roll > 0.6:
		tier = "rare"
	var keys: Array = ALLY_CARDS[tier].keys()
	return keys[randi() % keys.size()]
