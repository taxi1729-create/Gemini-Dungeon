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


## 階ごとの敵の数（battle-spec.md「敵」）。floor_no は 0 始まり
static func enemy_count(floor_no: int, kind: String) -> int:
	match kind:
		"elite": return 1 + randi_range(2, 3)
		"boss": return 1 + randi_range(3, 5)
	if floor_no <= 1:
		return randi_range(2, 3)
	if floor_no <= 4:
		return randi_range(3, 4)
	return randi_range(4, 6)
