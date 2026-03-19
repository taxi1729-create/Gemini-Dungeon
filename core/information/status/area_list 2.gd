# core/information/status/area_list.gd
extends Node
class_name AreaList

const DATA = {
	#"forest": {
	#	"name": "静寂の森",
	#	"enemies": ["slime", "goblin", "bat"]
	#},
	"cave": {
		"name": "暗がりの洞窟",
		"enemies": ["nagool", "spider", "skeleton"]
	}
}

static func get_enemy_pool(area_id: String) -> Array:
	if DATA.has(area_id):
		return DATA[area_id]["enemies"]
	return ["nagool"] # デフォルト
