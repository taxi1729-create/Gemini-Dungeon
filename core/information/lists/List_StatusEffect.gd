extends Node
class_name StatusEffectList
## 状態異常。数値は「強さ」と「残りラウンド」を兼ねる（ラウンド終了ごとに1減る）。
## timing: start_turn = 手番の開始時に発動 / end_turn = 手番の終了時 / all = 常時

const DATA = {
	"fire": {"name": "火傷", "short": "火傷", "timing": "start_turn", "icon": "flame", "good": false,
		"desc": "手番の開始時に数値分のダメージ"},
	"poison": {"name": "毒", "short": "毒", "timing": "start_turn", "icon": "drop", "good": false,
		"desc": "手番の開始時に数値分のダメージ"},
	"atk_buff": {"name": "攻撃力上昇", "short": "攻↑", "timing": "all", "icon": "atk_buff", "good": true,
		"desc": "与えるダメージ +数値"},
	"atk_debuff": {"name": "攻撃力低下", "short": "攻↓", "timing": "all", "icon": "atk_debuff", "good": false,
		"desc": "与えるダメージ -数値"},
	"def_buff": {"name": "防御力上昇", "short": "防↑", "timing": "all", "icon": "def_buff", "good": true,
		"desc": "受けるダメージ -数値"},
	"def_debuff": {"name": "防御力低下", "short": "防↓", "timing": "all", "icon": "def_debuff", "good": false,
		"desc": "受けるダメージ +数値"},
	"regen": {"name": "再生", "short": "再生", "timing": "end_turn", "icon": "regen", "good": true,
		"desc": "手番の終了時に数値分回復"},
}
