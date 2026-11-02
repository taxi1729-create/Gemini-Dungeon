extends Node
class_name Item_List
## 道具（AP 0）。行動と同じ形式なので ActionController でそのまま処理できる。

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
}
