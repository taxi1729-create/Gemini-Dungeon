extends Node
class_name StatusEffectList
## 状態異常（battle-spec.md「状態異常」）
## データ形：unit.status_effects[id] = {"val": 強さ, "turns": 残りターン（-1 = 戦闘中ずっと）}
## timing: start_turn = 持ち主のターン開始時に発動 / all = 常時
## 残りターンは「持ち主の自分のターンが終わった時」に 1 減る（火傷・毒は val も同時に 1 減る）
## label: 表示の仕方（"val" = 強さ、"neg" = −強さ、"turns" = 残りターン）

const DATA = {
	"fire": {"name": "火傷", "short": "火傷", "timing": "start_turn", "icon": "flame", "good": false, "label": "val",
		"desc": "ターン開始時に数値分のダメージ。毎ターン1減る"},
	"poison": {"name": "毒", "short": "毒", "timing": "start_turn", "icon": "st_poison", "good": false, "label": "val",
		"desc": "ターン開始時に残りターン分のダメージ。毎ターン1減る"},
	"atk_buff": {"name": "攻撃力アップ", "short": "攻↑", "timing": "all", "icon": "atk_buff", "good": true, "label": "val",
		"desc": "与えるダメージ +数値"},
	"atk_down": {"name": "攻撃力低下", "short": "攻↓", "timing": "all", "icon": "st_atk_down", "good": false, "label": "neg",
		"desc": "与えるダメージ −数値"},
	"def_buff": {"name": "防御力アップ", "short": "防↑", "timing": "all", "icon": "st_def_up", "good": true, "label": "val",
		"desc": "受けるダメージ −数値"},
	"def_down": {"name": "防御力低下", "short": "防↓", "timing": "all", "icon": "st_def_down", "good": false, "label": "neg",
		"desc": "受けるダメージ +数値"},
	"spd_buff": {"name": "素早さアップ", "short": "速↑", "timing": "all", "icon": "chevrons", "good": true, "label": "val",
		"desc": "素早さ +数値（次のラウンドの行動順から）"},
	"ap_plus": {"name": "APプラス", "short": "AP+", "timing": "start_turn", "icon": "st_ap_plus", "good": true, "label": "turns",
		"desc": "自分のターン開始時に AP +数値"},
	"ap_next": {"name": "次ターンAP", "short": "次AP", "timing": "start_turn", "icon": "st_ap_next", "good": true, "label": "val",
		"desc": "次の自分のターン開始時に AP +数値"},
	"taunt": {"name": "挑発", "short": "挑発", "timing": "all", "icon": "st_taunt", "good": false, "label": "turns",
		"desc": "単体攻撃の対象が、挑発してきたキャラになる"},
	"fire_guard": {"name": "ファイアガード", "short": "炎盾", "timing": "all", "icon": "st_fire_guard", "good": true, "label": "val",
		"desc": "攻撃してきた相手に火傷を与える"},
	"double": {"name": "連続魔法", "short": "連続", "timing": "all", "icon": "st_double", "good": true, "label": "none",
		"desc": "次に使うカード・保留カードが2回発動する"},
	"regen": {"name": "リジェネ", "short": "再生", "timing": "start_turn", "icon": "st_regen", "good": true, "label": "val",
		"desc": "ターン開始時に残りターン分 HP 回復（最大HPを超えられる）。毎ターン1減る"},
	"barricade": {"name": "バリケード", "short": "柵", "timing": "all", "icon": "st_barricade", "good": true, "label": "none",
		"desc": "ブロックがターン開始時に取り除かれない（戦闘中ずっと）"},
	"focus": {"name": "精神統一", "short": "統一", "timing": "start_turn", "icon": "st_focus", "good": true, "label": "val",
		"desc": "次の自分のターン、必殺技の AP −数値"},
	"declare": {"name": "宣言", "short": "宣言", "timing": "start_turn", "icon": "st_declare", "good": true, "label": "none",
		"desc": "次の自分のターン開始時までに HP が減らなければ、3 ターン APプラス"},
	"reblock": {"name": "リブロック", "short": "再盾", "timing": "start_turn", "icon": "st_reblock", "good": true, "label": "val",
		"desc": "次の自分のターン開始時にブロック +数値"},
}
