extends Node
class_name ActionList
## カード・スキル・敵の行動の定義（battle-spec.md「カード」「キャラクター」「敵」）
##
## 共通の項目
##   owner    : カードの持ち主（knight / witch）。報酬・ショップのカードは持ち主のデッキへ自動で入る
##   target   : self / ally_all / enemy_all
##              front_enemy_single = 目の前の敵グループで HP が一番低い敵
##              front_enemy_group  = 目の前の敵グループ全体（自分の側＝画面の左半分／右半分にいる敵）
##              front_row          = 前衛の敵全体
##   power    : ダメージ（対象全員に与える）
##   effects  : 効果の配列。各効果 {"effect": 種類, "eff_val": 値, "status": 状態ID, "turns": ターン数, "to": "target"/"self"/"ally_all"}
##              種類：add_shield / add_status / heal / add_ap / draw / swap / double / turnabout / extra_turn / set_next_action
##   keywords : "exhaust"（廃棄：使うと廃棄札へ）、"power"（パワー：発動不可。手札にある間 power_effect が効く）
## art は ImageController.icon の種類名（画像ファイルは使わない）

const ALLY_CARDS = {
	"common": {
		# --- ナイト ---
		"strike": {"owner": "knight", "name": "ストライク", "type": "attack", "target": "front_enemy_single", "art": "sword", "power": 8, "ap": 1},
		"block": {"owner": "knight", "name": "ブロック", "type": "skill", "target": "self", "art": "shield", "ap": 1,
			"effects": [{"effect": "add_shield", "eff_val": 7}]},
		"sweep": {"owner": "knight", "name": "薙ぎ払い", "type": "attack", "target": "front_enemy_group", "art": "sweep", "power": 5, "ap": 1},
		"spirit": {"owner": "knight", "name": "気合", "type": "skill", "target": "self", "art": "chevrons", "ap": 0,
			"effects": [{"effect": "add_ap", "eff_val": 1}]},
		"big_shield": {"owner": "knight", "name": "ビッグシールド", "type": "skill", "target": "self", "art": "c_big_shield", "ap": 2,
			"effects": [{"effect": "add_shield", "eff_val": 14}]},
		"hone": {"owner": "knight", "name": "研ぎ澄ます", "type": "skill", "target": "self", "art": "c_hone", "ap": 1,
			"effects": [{"effect": "add_shield", "eff_val": 9}, {"effect": "add_status", "status": "spd_buff", "eff_val": 1}]},
		"flash": {"owner": "knight", "name": "一閃", "type": "attack", "target": "front_row", "art": "c_flash", "power": 6, "ap": 1},
		"taunt": {"owner": "knight", "name": "挑発", "type": "skill", "target": "front_enemy_group", "art": "c_taunt", "ap": 0,
			"effects": [{"effect": "add_status", "status": "taunt", "eff_val": 0, "turns": 1}]},
		# --- ウィッチ ---
		"missile": {"owner": "witch", "name": "マジックミサイル", "type": "attack", "target": "front_enemy_single", "art": "star", "power": 7, "ap": 1},
		"firebolt": {"owner": "witch", "name": "ファイアボルト", "type": "attack", "target": "enemy_all", "art": "flame", "power": 6, "ap": 2},
		"sparks": {"owner": "witch", "name": "火の粉", "type": "skill", "target": "enemy_all", "art": "burst", "ap": 1,
			"effects": [{"effect": "add_status", "status": "fire", "eff_val": 3}]},
		"barrier": {"owner": "witch", "name": "マジックバリア", "type": "skill", "target": "self", "art": "shield", "ap": 1,
			"effects": [{"effect": "add_shield", "eff_val": 7}]},
		"chant": {"owner": "witch", "name": "高速詠唱", "type": "skill", "target": "self", "art": "chevrons", "ap": 0,
			"effects": [{"effect": "add_ap", "eff_val": 1}]},
		"swap_card": {"owner": "witch", "name": "スワップ", "type": "skill", "target": "self", "art": "c_swap", "ap": 0,
			"effects": [{"effect": "swap"}]},
		"draw_magic": {"owner": "witch", "name": "ドローマジック", "type": "attack", "target": "front_enemy_single", "art": "c_draw_magic", "power": 5, "ap": 1,
			"effects": [{"effect": "draw", "eff_val": 1, "to": "self"}]},
		"hit_away": {"owner": "witch", "name": "ヒットアンドアウェイ", "type": "attack", "target": "front_enemy_single", "art": "c_hit_away", "power": 8, "ap": 1,
			"effects": [{"effect": "swap", "to": "self"}]},
		"poison_gas": {"owner": "witch", "name": "毒ガス", "type": "skill", "target": "front_enemy_group", "art": "c_poison_gas", "ap": 1,
			"effects": [{"effect": "add_status", "status": "poison", "eff_val": 4, "turns": 4}]},
	},
	"rare": {
		# --- ナイト ---
		"heavy": {"owner": "knight", "name": "重撃", "type": "attack", "target": "front_enemy_single", "art": "sword", "power": 18, "ap": 2},
		"guard_all": {"owner": "knight", "name": "守護の陣", "type": "skill", "target": "ally_all", "art": "shield", "ap": 2,
			"effects": [{"effect": "add_shield", "eff_val": 8}]},
		"fire_guard": {"owner": "knight", "name": "ファイアガード", "type": "skill", "target": "self", "art": "c_fire_guard", "ap": 2,
			"effects": [{"effect": "add_shield", "eff_val": 8}, {"effect": "add_status", "status": "fire_guard", "eff_val": 2, "turns": 1}]},
		"big_swing": {"owner": "knight", "name": "大振り", "type": "attack", "target": "front_enemy_single", "art": "c_big_swing", "power": 20, "ap": 3},
		"store": {"owner": "knight", "name": "貯める", "type": "skill", "target": "self", "art": "c_store", "ap": 3,
			"effects": [{"effect": "add_shield", "eff_val": 10}, {"effect": "add_status", "status": "ap_next", "eff_val": 3, "turns": 1}]},
		"steel": {"owner": "knight", "name": "鋼鉄化", "type": "unselectable", "target": "self", "art": "c_steel",
			"keywords": ["power"], "power_effect": {"status": "def_buff", "eff_val": 2}},
		# --- ウィッチ ---
		"thunder": {"owner": "witch", "name": "雷撃", "type": "attack", "target": "enemy_all", "art": "bolt", "power": 9, "ap": 2},
		"ice_lance": {"owner": "witch", "name": "氷の槍", "type": "attack", "target": "front_enemy_single", "art": "snow", "power": 15, "ap": 2},
		"weaken": {"owner": "witch", "name": "攻撃力低下", "type": "skill", "target": "enemy_all", "art": "c_atk_down", "ap": 2,
			"effects": [{"effect": "add_status", "status": "atk_down", "eff_val": 6, "turns": 1}]},
		"break_armor": {"owner": "witch", "name": "防御力低下", "type": "skill", "target": "front_enemy_group", "art": "c_def_down", "ap": 2,
			"effects": [{"effect": "add_status", "status": "def_down", "eff_val": 3, "turns": 1}]},
		"meditate": {"owner": "witch", "name": "瞑想", "type": "skill", "target": "self", "art": "c_meditate", "ap": 2,
			"effects": [{"effect": "add_status", "status": "ap_plus", "eff_val": 1, "turns": 3}]},
		"force": {"owner": "witch", "name": "フォース", "type": "unselectable", "target": "self", "art": "c_force",
			"keywords": ["power"], "power_effect": {"status": "atk_buff", "eff_val": 2}},
	},
	"super_rare": {
		# --- ナイト ---
		"fighting": {"owner": "knight", "name": "闘志", "type": "skill", "target": "self", "art": "atk_buff", "ap": 1,
			"effects": [{"effect": "add_status", "status": "atk_buff", "eff_val": 2}]},
		"full_strike": {"owner": "knight", "name": "渾身の一撃", "type": "attack", "target": "front_enemy_group", "art": "c_full_strike", "power": 20, "ap": 1,
			"keywords": ["exhaust"]},
		"stand": {"owner": "knight", "name": "仁王立ち", "type": "skill", "target": "enemy_all", "art": "c_stand", "ap": 3, "keywords": ["exhaust"],
			"effects": [{"effect": "add_status", "status": "taunt", "eff_val": 0, "turns": 1}, {"effect": "add_shield", "eff_val": 20, "to": "self"}]},
		# --- ウィッチ ---
		"insight": {"owner": "witch", "name": "ひらめき", "type": "skill", "target": "self", "art": "cards", "ap": 0,
			"effects": [{"effect": "draw", "eff_val": 2}]},
		"magic_wall": {"owner": "witch", "name": "マジックウォール", "type": "skill", "target": "ally_all", "art": "c_magic_wall", "ap": 3, "keywords": ["exhaust"],
			"effects": [{"effect": "add_shield", "eff_val": 30}]},
		"double_cast": {"owner": "witch", "name": "連続魔法", "type": "skill", "target": "self", "art": "c_double", "ap": 1, "keywords": ["exhaust"],
			"effects": [{"effect": "double"}]},
	},
}

## キャラ固有スキル（テンキー 3）
const UNIQUE_SKILLS = {
	"witch": {"id": "first_step", "name": "ファーストステップ", "type": "skill", "target": "ally_all", "art": "chevrons", "ap": 1,
			"effects": [{"effect": "add_status", "status": "spd_buff", "eff_val": 10}, {"effect": "add_shield", "eff_val": 3}]},
	"knight": {"id": "turnabout", "name": "一転攻勢", "type": "skill", "target": "self", "art": "atk_buff", "ap": 1,
			"effects": [{"effect": "turnabout", "eff_val": 1}]},
}

## 必殺技（中央長押し。マップ画面でキャラごとに 1 つセット）
const SPECIALS = {
	"witch": [
		{"id": "explosion", "name": "爆発", "type": "attack", "target": "enemy_all", "art": "burst", "power": 14, "ap": 3},
		{"id": "turn_skip", "name": "ターンスキップ", "type": "skill", "target": "self", "art": "hourglass", "ap": 5,
			"effects": [{"effect": "extra_turn"}]},
	],
	"knight": [
		{"id": "sky_slash", "name": "空烈斬", "type": "attack", "target": "front_enemy_group", "art": "sweep", "power": 17, "ap": 2},
		{"id": "great_guard", "name": "大防御", "type": "skill", "target": "self", "art": "shield", "ap": 1,
			"effects": [{"effect": "add_shield", "eff_val": 13}]},
	],
}

## 入替（テンキー 7）
const SWAP = {"id": "swap", "name": "入替", "type": "skill", "target": "self", "art": "swap", "ap": 1, "effects": [{"effect": "swap"}]}

## 敵の行動。target は敵から見た向き：
##   front_enemy_single = 予告した側（左＝青／右＝赤）の味方（挑発されていれば挑発してきた味方）
##   enemy_all = 味方 2 人 / ally_all = 敵の仲間全員 / self
##   move = true なら、反対側へ移動してから攻撃する（狙う側も移動先の側になる）
const ENEMY_ACTIONS = {
	"club": {"name": "棍棒", "type": "attack", "target": "front_enemy_single", "power": 10},
	"claw": {"name": "引っかく", "type": "attack", "target": "front_enemy_single", "power": 11},
	"bite": {"name": "噛み付く", "type": "attack", "target": "front_enemy_single", "power": 10},
	"slash": {"name": "斬りつけ", "type": "attack", "target": "front_enemy_single", "power": 13},
	"gust": {"name": "突風", "type": "attack", "target": "enemy_all", "power": 7},
	"flank": {"name": "回り込み", "type": "attack", "target": "front_enemy_single", "power": 12, "move": true},
	"guard_self": {"name": "身構える", "type": "skill", "target": "self", "effects": [{"effect": "add_shield", "eff_val": 10}]},
	"guard_allies": {"name": "防御陣", "type": "skill", "target": "ally_all", "effects": [{"effect": "add_shield", "eff_val": 8}]},
	"burn_one": {"name": "火炎の爪", "type": "skill", "target": "front_enemy_single", "effects": [{"effect": "add_status", "status": "fire", "eff_val": 5}]},
	"burn_all": {"name": "炎の渦", "type": "skill", "target": "enemy_all", "effects": [{"effect": "add_status", "status": "fire", "eff_val": 4}]},
	"poison_spit": {"name": "毒液", "type": "skill", "target": "front_enemy_single", "effects": [{"effect": "add_status", "status": "poison", "eff_val": 4, "turns": 4}]},
	"war_cry": {"name": "雄叫び", "type": "skill", "target": "ally_all", "effects": [{"effect": "add_status", "status": "atk_buff", "eff_val": 3}]},
	"dark_slash": {"name": "闇の斬撃", "type": "attack", "target": "front_enemy_single", "power": 20},
	"dark_flank": {"name": "影走り", "type": "attack", "target": "front_enemy_single", "power": 18, "move": true},
	"big_guard": {"name": "鉄壁", "type": "skill", "target": "self", "effects": [{"effect": "add_shield", "eff_val": 18}]},
	"charge": {"name": "力を溜める", "type": "skill", "target": "self", "effects": [{"effect": "set_next_action", "next": "strong_attack"}]},
	"strong_attack": {"name": "強攻撃", "type": "attack", "target": "enemy_all", "power": 19},
	"breath": {"name": "炎の息", "type": "attack", "target": "enemy_all", "power": 13},
	"tail": {"name": "尻尾の一撃", "type": "attack", "target": "front_enemy_single", "power": 24},
	"dark_wave": {"name": "暗黒波", "type": "attack", "target": "enemy_all", "power": 12},
	"dark_heal": {"name": "闇の再生", "type": "skill", "target": "self", "effects": [{"effect": "heal", "eff_val": 24}]},
}


## 効果の配列（"effects" が無い古い形の行動にも対応）
static func effects_of(a: Dictionary) -> Array:
	if a.has("effects"):
		return a.effects
	if a.has("effect"):
		return [{"effect": a.effect, "eff_val": a.get("eff_val", 0), "status": a.get("status", ""), "turns": a.get("turns", -1),
				"next": a.get("next", ""), "to": a.get("effect_target", "target")}]
	return []


static func has_keyword(a: Dictionary, k: String) -> bool:
	return a.get("keywords", []).has(k)


## カードIDからカード辞書（rarity・id 付きのコピー）を作る
static func make_card(card_id: String) -> Dictionary:
	for rarity in ["common", "rare", "super_rare"]:
		if ALLY_CARDS[rarity].has(card_id):
			var c: Dictionary = ALLY_CARDS[rarity][card_id].duplicate(true)
			c["id"] = card_id
			c["rarity"] = "normal" if rarity == "common" else rarity
			if not c.has("keywords"):
				c["keywords"] = []
			return c
	return {}


static func owner_of(card_id: String) -> String:
	return make_card(card_id).get("owner", "knight")


## 報酬用にランダムなカードIDを選ぶ（レアほど出にくい）。owner を指定するとそのキャラのカードだけ
static func random_card_id(min_tier: String = "", owner: String = "") -> String:
	var roll := randf()
	var tier := "common"
	if roll > 0.88:
		tier = "super_rare"
	elif roll > 0.58:
		tier = "rare"
	if min_tier == "rare" and tier == "common":
		tier = "rare"
	var keys: Array = ALLY_CARDS[tier].keys().filter(func(k): return owner == "" or ALLY_CARDS[tier][k].owner == owner)
	if keys.is_empty():
		keys = ALLY_CARDS[tier].keys()
	return keys[randi() % keys.size()]


static func special(char_id: String, special_id: String) -> Dictionary:
	for s in SPECIALS[char_id]:
		if s.id == special_id:
			return s
	return SPECIALS[char_id][0]
