extends Node
class_name StatusEffectList

const DATA = {
	"poison": {"name": "毒", "type": "damage", "val": 2, "duration":1,"icon": "sword_icon"}, # 行動開始時に蓄積ターン分のダメージ(valは固定ダメージ等の拡張用)
	"atk_down": {"name": "攻撃力低下", "type": "stat_change", "duration":1,"icon": "sword_icon"},
	"regen": {"name": "HP回復", "type": "heal", "duration":1,"icon": "sword_icon"}
}
