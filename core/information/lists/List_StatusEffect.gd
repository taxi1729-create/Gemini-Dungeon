extends Node
class_name StatusEffectList

const DATA = {
	"fire": {"name": "火傷","type": "stat_change_minus", "status": "hp","timing":"start_turn","val":-1,"duration":-1,"icon": "fire"}, # 行動開始時に蓄積ターン分のダメージ(valは固定ダメージ等の拡張用)
	"atk_debuff": {"name": "攻撃力低下", "type": "stat_change_minus", "status": "atk","timing":"all","val":-1,"duration":1,"icon": "attack_debuff"},
	"atk_buff": {"name": "攻撃力上昇", "type": "stat_change_plus", "status": "atk","timing":"all","val":-1,"duration":1,"icon": "attack_buff"},
	"def_debuff": {"name": "防御力低下", "type": "stat_change_minus", "status": "def","timing":"all","val":-1,"duration":1,"icon": "def_debuff"},
	"def_buff": {"name": "防御力上昇", "type": "stat_change_plus", "status": "def","timing":"all","val":-1,"duration":1,"icon": "def_buff"},
	"speed_debuff": {"name": "素早さ低下", "type": "stat_change_minus", "status": "speed","timing":"all","val":-1,"duration":1,"icon": "speed_debuff"},
	"speed_buff": {"name": "素早さ上昇", "type": "stat_change_plus", "status": "speed","timing":"all","val":-1,"duration":1,"icon": "speed_buff"},
	"regen": {"name": "HP回復", "type": "stat_change_plus", "status": "hp","timing":"end_turn","val":-1,"duration":1,"icon": "regen"}
}
#	"regen": {"name": "HP回復", "type": "stat_change", "timing":"end_turn","val":-1,"duration":1,"icon": "regen"}はターン終了時、蓄積数値ぶんHPを回復、ターン終了時効果を取り除く
#
