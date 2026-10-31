extends Node
class_name Item_List
## 道具。行動と同じ形式なので ActionController でそのまま処理できる。

const DATA = {
	"herb": {"name": "薬草", "art": "potion", "art_col": Color("6fd08a"), "type": "skill",
		"target": "ally_all", "effect": "heal", "eff_val": 12, "desc": "味方全員のHPを12回復"},
	"fire_potion": {"name": "火炎ポーション", "art": "potion", "art_col": Color("ff7a2a"), "type": "attack",
		"target": "enemy_all", "power": 8, "desc": "敵全体に8ダメージ"},
	"poison_potion": {"name": "毒ポーション", "art": "potion", "art_col": Color("9b59d0"), "type": "attack",
		"target": "enemy_all", "effect": "add_status", "status": "poison", "eff_val": 4, "desc": "敵全体に毒4"},
}
