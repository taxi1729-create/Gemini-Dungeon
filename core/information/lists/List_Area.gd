extends Node
class_name AreaList
## 階（エリア）の定義。CurrentStatus.STAGES の順に 1 階・2 階・3 階
## lastboss：3 階のボスを倒した後に連戦するラスボス（3 階だけ）

const DATA = {
	"cave": {
		"name": "暗がりの洞窟",
		"stage": 1,
		"enemies": ["goblin", "gool", "zombie", "skeleton", "harpy", "fire_warriar"],
		"elites": ["dark_knight"],
		"bosses": ["green_dragon", "necro"],
	},
	"corridor": {
		"name": "沈黙の回廊",
		"stage": 2,
		"enemies": ["mute_imp", "corridor_ghoul", "silent_monk", "bone_choir", "gargoyle", "candle_wraith"],
		"elites": ["silent_knight"],
		"bosses": ["abbess", "bell_dragon"],
	},
	"cathedral": {
		"name": "星の大聖堂",
		"stage": 3,
		"enemies": ["choir_imp", "censer_ghoul", "fallen_pilgrim", "star_sentinel", "glass_angel", "astral_flame"],
		"elites": ["star_paladin"],
		"bosses": ["star_dragon", "archbishop"],
		"lastboss": ["fallen_twins"],
	},
}


static func get_enemy_pool(area_id: String, kind: String = "enemies") -> Array:
	if DATA.has(area_id) and DATA[area_id].has(kind):
		return DATA[area_id][kind]
	if kind == "lastboss":
		return DATA["cathedral"].lastboss
	return DATA["cave"][kind]


## 階ごとの敵の数（battle-spec.md「敵」）。floor_no は階の中の段（0 始まり）、stage は 1〜3
static func enemy_count(floor_no: int, kind: String, stage: int = 1) -> int:
	# 最大 7 体（配置の 7 マス）。強敵・ボスは本体 1 体＋取り巻き 2〜4 体。ラスボスは 1 体だけ
	match kind:
		"elite": return 1 + (randi_range(2, 4) if stage <= 1 else randi_range(2, 3))
		"boss": return 1 + (randi_range(2, 4) if stage <= 1 else randi_range(2, 3))
		"lastboss": return 1
	if stage >= 2:
		# 2 階以降は 1 体が固いので少なめ
		if floor_no <= 1:
			return randi_range(2, 3)
		if floor_no <= 4:
			return randi_range(3, 4)
		return randi_range(4, 5)
	if floor_no <= 1:
		return randi_range(2, 3)
	if floor_no <= 4:
		return randi_range(3, 5)
	return randi_range(5, 7)
