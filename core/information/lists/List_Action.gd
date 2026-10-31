extends Node
class_name ActionList
## カード・スキル・敵の行動の定義（battle-spec.md「カード」「キャラクター」「敵」）
## 1 枚のカード／1 つの敵行動の効果は 1 つだけ。
##   power   : ダメージ（威力）
##   effect  : add_shield / add_ap / add_status / heal / draw / set_next_action
## art は ImageController.icon の種類名（画像ファイルは使わない）
## target  : self / ally_all / enemy_all / front_enemy_single / front_enemy_group

const ALLY_CARDS = {
	"common": {
		"strike": {"name": "ストライク", "type": "attack", "target": "front_enemy_single", "art": "sword", "power": 8, "ap": 1},
		"block": {"name": "ブロック", "type": "skill", "target": "self", "art": "shield", "effect": "add_shield", "eff_val": 7, "ap": 1},
		"sweep": {"name": "薙ぎ払い", "type": "attack", "target": "front_enemy_group", "art": "sweep", "power": 5, "ap": 1},
		"accel": {"name": "加速", "type": "skill", "target": "self", "art": "chevrons", "effect": "add_ap", "eff_val": 1, "ap": 0},
		"missile": {"name": "マジックミサイル", "type": "attack", "target": "front_enemy_single", "art": "star", "power": 7, "ap": 1},
		"firebolt": {"name": "ファイアボルト", "type": "attack", "target": "enemy_all", "art": "flame", "power": 6, "ap": 2},
		"sparks": {"name": "火の粉", "type": "skill", "target": "enemy_all", "art": "burst", "effect": "add_status", "status": "fire", "eff_val": 3, "ap": 1},
	},
	"rare": {
		"heavy": {"name": "重撃", "type": "attack", "target": "front_enemy_single", "art": "sword", "power": 18, "ap": 2},
		"guard_all": {"name": "守護の陣", "type": "skill", "target": "ally_all", "art": "shield", "effect": "add_shield", "eff_val": 8, "ap": 2},
		"thunder": {"name": "雷撃", "type": "attack", "target": "enemy_all", "art": "bolt", "power": 9, "ap": 2},
	},
	"super_rare": {
		"fighting": {"name": "闘志", "type": "skill", "target": "self", "art": "atk_buff", "effect": "add_status", "status": "atk_buff", "eff_val": 2, "ap": 1},
		"insight": {"name": "ひらめき", "type": "skill", "target": "self", "art": "cards", "effect": "draw", "eff_val": 2, "ap": 0},
	},
}

## キャラ固有スキル（テンキー 3）
const UNIQUE_SKILLS = {
	"witch": {"id": "first_step", "name": "ファーストステップ", "type": "skill", "target": "ally_all", "art": "chevrons",
			"effect": "add_status", "status": "spd_buff", "eff_val": 10, "ap": 1},
	"knight": {"id": "turnabout", "name": "一転攻勢", "type": "skill", "target": "self", "art": "atk_buff",
			"effect": "turnabout", "eff_val": 1, "ap": 1},
}

## 必殺技（中央長押し。戦闘開始時にキャラごとに 1 つセット）
const SPECIALS = {
	"witch": [
		{"id": "explosion", "name": "爆発", "type": "attack", "target": "enemy_all", "art": "burst", "power": 24, "ap": 3},
		{"id": "turn_skip", "name": "ターンスキップ", "type": "skill", "target": "self", "art": "hourglass", "effect": "extra_turn", "ap": 5},
	],
	"knight": [
		{"id": "sky_slash", "name": "空烈斬", "type": "attack", "target": "front_enemy_group", "art": "sweep", "power": 17, "ap": 2},
		{"id": "great_guard", "name": "大防御", "type": "skill", "target": "self", "art": "shield", "effect": "add_shield", "eff_val": 13, "ap": 1},
	],
}

## 入替（テンキー 7）
const SWAP = {"id": "swap", "name": "入替", "type": "skill", "target": "self", "art": "swap", "effect": "swap", "ap": 1}

## 敵の行動。target は敵から見た向き：
##   front_enemy_single = 前にいる味方 / enemy_all = 味方 2 人 / ally_all = 敵の仲間全員 / self
const ENEMY_ACTIONS = {
	"club": {"name": "棍棒", "type": "attack", "target": "front_enemy_single", "power": 5},
	"claw": {"name": "引っかく", "type": "attack", "target": "front_enemy_single", "power": 6},
	"bite": {"name": "噛み付く", "type": "attack", "target": "front_enemy_single", "power": 5},
	"slash": {"name": "斬りつけ", "type": "attack", "target": "front_enemy_single", "power": 7},
	"gust": {"name": "突風", "type": "attack", "target": "enemy_all", "power": 3},
	"guard_self": {"name": "身構える", "type": "skill", "target": "self", "effect": "add_shield", "eff_val": 6},
	"guard_allies": {"name": "防御陣", "type": "skill", "target": "ally_all", "effect": "add_shield", "eff_val": 4},
	"burn_one": {"name": "火炎の爪", "type": "skill", "target": "front_enemy_single", "effect": "add_status", "status": "fire", "eff_val": 3},
	"burn_all": {"name": "炎の渦", "type": "skill", "target": "enemy_all", "effect": "add_status", "status": "fire", "eff_val": 2},
	"war_cry": {"name": "雄叫び", "type": "skill", "target": "ally_all", "effect": "add_status", "status": "atk_buff", "eff_val": 2},
	"dark_slash": {"name": "闇の斬撃", "type": "attack", "target": "front_enemy_single", "power": 11},
	"big_guard": {"name": "鉄壁", "type": "skill", "target": "self", "effect": "add_shield", "eff_val": 12},
	"charge": {"name": "力を溜める", "type": "skill", "target": "self", "effect": "set_next_action", "next": "strong_attack"},
	"strong_attack": {"name": "強攻撃", "type": "attack", "target": "enemy_all", "power": 10},
	"breath": {"name": "炎の息", "type": "attack", "target": "enemy_all", "power": 7},
	"tail": {"name": "尻尾の一撃", "type": "attack", "target": "front_enemy_single", "power": 13},
	"dark_wave": {"name": "暗黒波", "type": "attack", "target": "enemy_all", "power": 6},
	"dark_heal": {"name": "闇の再生", "type": "skill", "target": "self", "effect": "heal", "eff_val": 15},
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


static func rarity_of(card_id: String) -> String:
	return make_card(card_id).get("rarity", "normal")


## 報酬用にランダムなカードIDを選ぶ（レアほど出にくい）。min_tier="rare" ならレア以上
static func random_card_id(min_tier: String = "") -> String:
	var roll := randf()
	var tier := "common"
	if roll > 0.88:
		tier = "super_rare"
	elif roll > 0.58:
		tier = "rare"
	if min_tier == "rare" and tier == "common":
		tier = "rare"
	var keys: Array = ALLY_CARDS[tier].keys()
	return keys[randi() % keys.size()]


static func special(char_id: String, special_id: String) -> Dictionary:
	for s in SPECIALS[char_id]:
		if s.id == special_id:
			return s
	return SPECIALS[char_id][0]
