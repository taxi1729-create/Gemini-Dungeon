extends Node
class_name StatusEffectList
## 状態異常（battle-spec.md「状態異常」）
## データ形：unit.status_effects[id] = {"val": 強さ, "turns": 残りターン（-1 = 戦闘中ずっと）}
## timing: start_turn = 持ち主のターン開始時に発動 / all = 常時
## 残りターンは「持ち主の自分のターンが終わった時」に 1 減る（火傷・毒は val も同時に 1 減る）
## label: 表示の仕方（"val" = 強さ、"neg" = −強さ、"turns" = 残りターン）

## 12 回目：旧 ID → 新しい ID（攻撃力→POW、防御力→DEF）。StatusController.canon が使う
const ALIAS = {"atk_buff": "pow_up", "atk_down": "pow_down", "def_buff": "def_up"}

const DATA = {
	"fire": {"name": "火傷", "short": "火傷", "timing": "start_turn", "icon": "flame", "good": false, "label": "val",
		"desc": "ターン開始時に数値分のダメージ。毎ターン1減る"},
	"poison": {"name": "毒", "short": "毒", "timing": "start_turn", "icon": "st_poison", "good": false, "label": "val",
		"desc": "ターン開始時に残りターン分のダメージ。毎ターン1減る"},
	# 12 回目：ステータス増減（ターン限定）。味方は POW・SLD・DEF そのものが変わる（% のカードすべてに効く）。
	#   敵には POW・SLD が無いので、pow_up / pow_down は今まで通り敵のダメージの増減（表示は POW↑／POW↓）
	#   戦闘終了までの増減は状態ではなく効果 add_stat（ActionController.add_stat。u.stat_add）
	"pow_up": {"name": "POWアップ", "short": "POW↑", "timing": "all", "icon": "atk_buff", "good": true, "label": "val",
		"desc": "POW +数値（敵に付いた時は与えるダメージ +数値）"},
	"pow_down": {"name": "POWダウン", "short": "POW↓", "timing": "all", "icon": "st_atk_down", "good": false, "label": "neg",
		"desc": "POW −数値（敵に付いた時は与えるダメージ −数値）"},
	"sld_up": {"name": "SLDアップ", "short": "SLD↑", "timing": "all", "icon": "c_big_shield", "good": true, "label": "val",
		"desc": "SLD +数値（ブロックのカードの量が増える）"},
	"sld_down": {"name": "SLDダウン", "short": "SLD↓", "timing": "all", "icon": "c_big_shield", "good": false, "label": "neg",
		"desc": "SLD −数値（ブロックのカードの量が減る）"},
	"def_up": {"name": "DEFアップ", "short": "DEF↑", "timing": "all", "icon": "st_def_up", "good": true, "label": "val",
		"desc": "DEF +数値（受けるダメージ −数値）"},
	"def_down": {"name": "DEFダウン", "short": "DEF↓", "timing": "all", "icon": "st_def_down", "good": false, "label": "neg",
		"desc": "DEF −数値（受けるダメージ +数値）"},
	# 旧 ID（11 回目まで）。付ける時に StatusController.apply_status が新しい ID に読み替えるので、ユニットには残らない。
	# データ（敵の行動など）に古い ID が残っていても表示が引けるように、同じ中身を置いておく（ALIAS と対）
	"atk_buff": {"name": "POWアップ", "short": "POW↑", "timing": "all", "icon": "atk_buff", "good": true, "label": "val",
		"desc": "POW +数値（敵に付いた時は与えるダメージ +数値）"},
	"atk_down": {"name": "POWダウン", "short": "POW↓", "timing": "all", "icon": "st_atk_down", "good": false, "label": "neg",
		"desc": "POW −数値（敵に付いた時は与えるダメージ −数値）"},
	"def_buff": {"name": "DEFアップ", "short": "DEF↑", "timing": "all", "icon": "st_def_up", "good": true, "label": "val",
		"desc": "DEF +数値（受けるダメージ −数値）"},
	# 12 回目：庇う（城壁・聖域）。残りは「ラウンド」で数える（1＝付けたラウンドの敵の攻撃が終わるまで）
	"cover": {"name": "庇う", "short": "庇う", "timing": "all", "icon": "shield", "good": true, "label": "turns",
		"desc": "もう1人の味方への敵の攻撃（単体・全体の分）を代わりに受ける"},
	"ap_plus": {"name": "APプラス", "short": "AP+", "timing": "start_turn", "icon": "st_ap_plus", "good": true, "label": "turns",
		"desc": "自分のターン開始時に AP +数値"},
	"ap_next": {"name": "次ターンAP", "short": "次AP", "timing": "start_turn", "icon": "st_ap_next", "good": true, "label": "val",
		"desc": "次の自分のターン開始時に AP +数値"},
	"taunt": {"name": "挑発", "short": "挑発", "timing": "all", "icon": "st_taunt", "good": false, "label": "turns",
		"desc": "単体攻撃の対象が、挑発してきたキャラになる"},
	"fire_guard": {"name": "ファイアガード", "short": "炎盾", "timing": "all", "icon": "st_fire_guard", "good": true, "label": "val",
		"desc": "攻撃してきた相手に火傷を与える"},
	"double": {"name": "連続魔法", "short": "連続", "timing": "all", "icon": "st_double", "good": true, "label": "none",
		"desc": "次に使うカードが2回発動する"},
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
	# 8 回目の追加
	"stun": {"name": "スタン", "short": "スタン", "timing": "start_turn", "icon": "st_stun", "good": false, "label": "none",
		"desc": "次の自分のターンを休む（ターン開始時の火傷・毒などは起きる）。休んだら消える"},
	"no_heal": {"name": "回復不可", "short": "回復不可", "timing": "all", "icon": "st_no_heal", "good": false, "label": "turns",
		"desc": "HPを回復できない（回復・リジェネも効かない）"},
	# 反撃・予約の札が付ける状態（中身の効果は status_effects[id].effects / .list）
	"hangeki": {"name": "反撃", "short": "反撃", "timing": "all", "icon": "kw_hangeki", "good": true, "label": "none",
		"desc": "次の自分のターン開始まで、攻撃してきた敵に追加効果"},
	"yoyaku": {"name": "予約", "short": "予約", "timing": "start_turn", "icon": "kw_yoyaku", "good": true, "label": "none",
		"desc": "次の自分のターン開始時に効果が発動する"},
	# 10 回目（D）：詠唱の構え
	"chant": {"name": "詠唱", "short": "詠唱", "timing": "all", "icon": "star", "good": true, "label": "val",
		"desc": "次に使うアタックカードのダメージ +数値（使うと消える）"},
}
