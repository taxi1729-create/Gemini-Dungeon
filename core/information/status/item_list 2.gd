# core/information/status/item_list.gd
extends Node
class_name Item_List

const DATA = {
	"herb": {"name": "薬草", "effect": "heal_all", "val": 15},
	"fire_potion": {"name": "火炎ポーション", "effect": "damage_front", "val": 20},
	"poison_potion": {"name": "毒ポーション", "effect": "apply_status", "status": "poison", "val": 3} # 3ターン毒
}
