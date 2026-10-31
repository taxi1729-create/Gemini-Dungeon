extends Node
class_name AreaList

const DATA = {
	"cave": {
		"name": "暗がりの洞窟",
		"enemies": ["goblin", "gool", "zombie", "skeleton", "harpy", "fire_warriar"],
		"elites": ["dark_knight"],
		"bosses": ["green_dragon", "necro"],
	}
}


static func get_enemy_pool(area_id: String, kind: String = "enemies") -> Array:
	if DATA.has(area_id):
		return DATA[area_id][kind]
	return DATA["cave"][kind]
