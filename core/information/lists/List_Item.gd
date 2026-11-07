extends Node
class_name Item_List
## 道具（AP 0）。行動と同じ形式なので ActionController でそのまま処理できる。
## 9 回目の追加（D）：効果の "to" に left_ally / right_ally（左＝lane 0・右＝lane 1 の味方）、front_ally / back_ally（前衛・後衛の味方）。
## item_only の効果は Cont_Battle が処理する：
##   prophecy  … 山札のランダムなカードを保留枠へ（保留枠が空で山札が 1 枚以上の時だけ使える。"need": "prophecy"）
##   fate_dice … FATE の中からランダムに 1 つを味方全体に

const DATA = {
	"herb": {"name": "薬草", "art": "item_herb", "icon": "item_herb", "art_col": Color("6fd08a"), "type": "skill",
		"target": "ally_all", "effects": [{"effect": "heal", "eff_val": 12}], "desc": "味方全員のHPを12回復"},
	"fire_potion": {"name": "火炎ポーション", "art": "item_fire", "icon": "item_fire", "art_col": Color("ff7a2a"), "type": "attack",
		"target": "enemy_all", "power": 10, "fixed": true, "desc": "敵全体に10ダメージ"},
	"power_water": {"name": "力の水", "art": "item_power", "icon": "item_power", "art_col": Color("5aa8ff"), "type": "skill",
		"target": "self", "effects": [{"effect": "add_status", "status": "atk_buff", "eff_val": 2}], "desc": "攻撃力+2（戦闘中）"},
	# 料理「三種の極み膳」で手に入る。heal_pct = 最大 HP の % 回復
	"ultimate_soup": {"name": "極みスープ", "art": "item_soup", "icon": "item_soup", "art_col": Color("f2c14e"), "type": "skill",
		"target": "ally_all", "effects": [{"effect": "heal_pct", "eff_val": 50}], "desc": "味方全体のHPを50%回復", "no_shop": true},
	# --- 9 回目の追加（10 種） ---
	"iron_charm": {"name": "鉄の護符", "art": "def_buff", "icon": "def_buff", "art_col": Color("9bb0e1"), "type": "skill",
		"target": "ally_all", "effects": [{"effect": "add_status", "status": "def_buff", "eff_val": 2}], "desc": "味方全体の防御力+2（戦闘中）"},
	"holy_water": {"name": "守りの聖水", "art": "drop", "icon": "drop", "art_col": Color("7fc8ff"), "type": "skill",
		"target": "ally_all", "effects": [{"effect": "add_shield", "eff_val": 15}], "desc": "味方全体にブロック+15"},
	"twin_incense": {"name": "双色の香", "art": "swap", "icon": "swap", "art_col": Color("e07aa0"), "type": "skill",
		"target": "ally_all", "effects": [{"effect": "add_shield", "eff_val": 20, "to": "left_ally"}, {"effect": "add_ap", "eff_val": 1, "to": "right_ally"}],
		"desc": "左のキャラにブロック+20、右のキャラにAP+1"},
	"war_wine": {"name": "陣中の酒", "art": "potion", "icon": "potion", "art_col": Color("d0546a"), "type": "skill",
		"target": "ally_all", "effects": [{"effect": "add_status", "status": "atk_buff", "eff_val": 3, "to": "front_ally"},
			{"effect": "add_status", "status": "def_buff", "eff_val": 3, "to": "back_ally"}],
		"desc": "前衛のキャラに攻撃力+3、後衛のキャラに防御力+3（戦闘中）"},
	"prophecy": {"name": "予言の栞", "art": "cards", "icon": "cards", "art_col": Color("f2c14e"), "type": "skill",
		"target": "self", "item_only": "prophecy", "need": "prophecy", "effects": [],
		"desc": "山札のランダムなカードを保留枠へ（保留枠が空で山札が1枚以上の時だけ）"},
	"wasp_jar": {"name": "毒蜂の瓶", "art": "st_poison", "icon": "st_poison", "art_col": Color("9ad04a"), "type": "attack",
		"target": "random_enemy", "power": 10, "fixed": true, "hits": 3, "reroll": true,
		"hit_effects": [{"effect": "add_status", "status": "poison", "eff_val": 2}],
		"desc": "ランダムな敵に10ダメージ×3（1回ごとに選び直す）。当たった敵に毒2"},
	"flash_ball": {"name": "閃光玉", "art": "star", "icon": "star", "art_col": Color("fff1a8"), "type": "skill",
		"target": "random_enemy", "effects": [{"effect": "add_status", "status": "stun", "eff_val": 1}], "desc": "ランダムな敵1体にスタン1"},
	"shrink_dust": {"name": "萎縮の粉", "art": "atk_debuff", "icon": "atk_debuff", "art_col": Color("c49ad8"), "type": "skill",
		"target": "enemy_all", "effects": [{"effect": "add_status", "status": "atk_down", "eff_val": 5, "turns": 1}], "desc": "敵全体に1ターン攻撃力-5"},
	"rust_mist": {"name": "腐蝕の霧", "art": "def_debuff", "icon": "def_debuff", "art_col": Color("b08a5a"), "type": "skill",
		"target": "enemy_all", "effects": [{"effect": "add_status", "status": "def_down", "eff_val": 2, "turns": 1}], "desc": "敵全体に1ターン防御力-2"},
	"fate_dice": {"name": "運命のダイス", "art": "question", "icon": "question", "art_col": Color("ffb03a"), "type": "skill",
		"target": "ally_all", "item_only": "fate_dice", "effects": [],
		"desc": "次からランダムに1つを味方全体に：3ダメージ／ブロック+19／AP+1／火傷2／攻撃力-3（1ターン）／防御力-3（1ターン）／HP全回復／手札の空きを補充／攻撃力+4（戦闘中）／防御力+4（戦闘中）"},
}

## 運命のダイスの出目（味方全体に。"text" は出た時の表示。power は固定ダメージ）
const FATE := [
	{"text": "3ダメージ", "power": 3},
	{"text": "ブロック+19", "effects": [{"effect": "add_shield", "eff_val": 19}]},
	{"text": "AP+1", "effects": [{"effect": "add_ap", "eff_val": 1}]},
	{"text": "火傷2", "effects": [{"effect": "add_status", "status": "fire", "eff_val": 2}]},
	{"text": "攻撃力-3（1ターン）", "effects": [{"effect": "add_status", "status": "atk_down", "eff_val": 3, "turns": 1}]},
	{"text": "防御力-3（1ターン）", "effects": [{"effect": "add_status", "status": "def_down", "eff_val": 3, "turns": 1}]},
	{"text": "HP全回復", "effects": [{"effect": "heal_pct", "eff_val": 100}]},
	{"text": "手札の空きを補充", "fill": true},  # 手札があるのは使ったキャラだけ（もう 1 人の手札はターン開始まで空）
	{"text": "攻撃力+4（戦闘中）", "effects": [{"effect": "add_status", "status": "atk_buff", "eff_val": 4}]},
	{"text": "防御力+4（戦闘中）", "effects": [{"effect": "add_status", "status": "def_buff", "eff_val": 4}]},
]


## 抽選用：ショップ・宝箱・イベント・戦闘報酬に出る道具（no_shop は出ない）
static func random_id() -> String:
	var ids: Array = DATA.keys().filter(func(k): return not DATA[k].get("no_shop", false))
	return str(ids.pick_random())
