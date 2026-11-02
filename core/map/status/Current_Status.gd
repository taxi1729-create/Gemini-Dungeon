extends Node
## CurrentStatus（Autoload）
## 冒険中の状態：パーティ、マップ、次の戦闘の種類、料理の効果、直前の戦闘結果。

const FLOORS := 8  # 0〜6 が通常階、7 がボス
const SHOP_FLOORS := [2, 4]  # 3 階と 5 階
const TREASURE_RATE := 0.1  # 宝箱マス：2 階以降（休憩の階・ボスの階は除く）のマスの 1 割程度
const TREASURE_MIN := 1  # 1 回の冒険で必ず 1〜2 個
const TREASURE_MAX := 2

var initialized := false
var current_area_id := "cave"
var allies: Array = []
var enemies: Array = []

# マップ
var map_floors: Array = []  # [floor][i] = {"type":..., "x":..., "next":[i,...]}
var current_floor := -1
var current_index := -1
var visited: Array = []  # [[floor, index], ...]

# 戦闘の受け渡し
var battle_kind := "battle"  # battle / elite / boss
var last_result := ""  # win / lose
var gold_multiplier := 1  # イベント「迷子の魔物」で 2
var next_battle := {}  # 料理の効果 {"ap": n, "atk": n, "def": n, "regen": ターン数, "block": n}（次の戦闘の開始時に反映）
var battle_stats := {}  # 直前の戦闘の集計 {"overkill": 倒した時の余りの合計, "rounds": ラウンド数, "hp_lost": 味方が減らされた HP の合計}
var special_choice := {"knight": "sky_slash", "witch": "explosion"}  # 前回セットした必殺技


func start_new_game() -> void:
	allies = [InitAllyStatus.get_status("knight"), InitAllyStatus.get_status("witch")]
	enemies = []
	Inventory.reset()
	CurrentDeck.sync_from_init()
	_generate_map()
	current_floor = -1
	current_index = -1
	visited = []
	last_result = ""
	gold_multiplier = 1
	next_battle = {}
	initialized = true


func sync_from_init() -> void:
	start_new_game()


func ensure_started() -> void:
	if not initialized:
		start_new_game()


func ally(id: String) -> Dictionary:
	for a in allies:
		if a.id == id:
			return a
	return {}


func heal_all(v: int) -> void:
	for a in allies:
		a["hp"] = mini(int(a.max_hp), maxi(1, int(a.hp)) + v)


## 次に進めるマスの [floor, index] 一覧
func reachable() -> Array:
	var out: Array = []
	if current_floor < 0:
		for i in map_floors[0].size():
			out.append([0, i])
	elif current_floor < map_floors.size() - 1:
		for j in map_floors[current_floor][current_index].next:
			out.append([current_floor + 1, j])
	return out


func enter_node(f: int, i: int) -> String:
	current_floor = f
	current_index = i
	visited.append([f, i])
	var t: String = map_floors[f][i].type
	if t in ["battle", "elite", "boss"]:
		battle_kind = t
		gold_multiplier = 1
	return t


func _generate_map() -> void:
	map_floors = []
	for f in FLOORS:
		var n := 3 if f in [1, 3, 5] else 2 + (randi() % 2)
		if f == FLOORS - 1:
			n = 1
		var row: Array = []
		for i in n:
			var t := "battle"
			if f == FLOORS - 1:
				t = "boss"
			elif f == FLOORS - 2:
				t = "rest"
			elif f >= 2:
				var r := randf()
				if r < 0.3:
					t = "event"
				elif r < 0.45:
					t = "rest"
				elif r < 0.62 and f >= 3:
					t = "elite"
			var x := (i + 1.0) / (n + 1.0)
			if n > 1:
				x += randf_range(-0.05, 0.05)
			row.append({"type": t, "x": x, "next": []})
		if f in SHOP_FLOORS:
			row[randi() % row.size()].type = "shop"
		map_floors.append(row)
	_place_treasures()
	# 隣の階との接続（左右の位置関係が近いものを結ぶ）
	for f in FLOORS - 1:
		var a: Array = map_floors[f]
		var b: Array = map_floors[f + 1]
		var incoming := {}
		for i in a.size():
			var ratio := 0.0 if a.size() == 1 else float(i) / (a.size() - 1)
			var j := int(round(ratio * (b.size() - 1)))
			a[i].next.append(j)
			incoming[j] = true
			if b.size() > 1 and randf() < 0.5:
				var j2 := clampi(j + (1 if randf() < 0.5 else -1), 0, b.size() - 1)
				if not a[i].next.has(j2):
					a[i].next.append(j2)
					incoming[j2] = true
		for j in b.size():
			if not incoming.has(j):
				var ratio := 0.0 if b.size() == 1 else float(j) / (b.size() - 1)
				var i := int(round(ratio * (a.size() - 1)))
				a[i].next.append(j)
		for i in a.size():
			a[i].next.sort()


## 宝箱マスを置く：2 階以降（f = 1〜5）のショップ以外のマスを 1 割程度で宝箱にし、全体で TREASURE_MIN〜TREASURE_MAX 個にそろえる
func _place_treasures() -> void:
	var cand: Array = []  # [floor, index]
	for f in range(1, FLOORS - 2):
		for i in map_floors[f].size():
			if map_floors[f][i].type != "shop":
				cand.append([f, i])
	cand.shuffle()
	var picked: Array = cand.filter(func(_c): return randf() < TREASURE_RATE)
	if picked.size() < TREASURE_MIN:
		for c in cand:
			if picked.size() >= TREASURE_MIN:
				break
			if not picked.has(c):
				picked.append(c)
	picked = picked.slice(0, TREASURE_MAX)
	for c in picked:
		map_floors[c[0]][c[1]].type = "treasure"
