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

# 3 階構成（9 回目・C）：1 階＝暗がりの洞窟、2 階＝沈黙の回廊、3 階＝星の大聖堂。3 階のボスの後はラスボスと連戦
const STAGES := ["cave", "corridor", "cathedral"]
const STAGE_MAX := 3
const LAST_BOSS_HEAL := 0.3  # 3 階のボスを倒した後、ラスボスの前に最大 HP の 30% 回復
var stage := 1  # 今の階（1〜3）
var allies: Array = []
var enemies: Array = []

# マップ
var map_floors: Array = []  # [floor][i] = {"type":..., "x":..., "next":[i,...]}
var current_floor := -1
var current_index := -1
var visited: Array = []  # [[floor, index], ...]

# 戦闘の受け渡し
var battle_kind := "battle"  # battle / elite / boss / lastboss（3 階のボスの後の連戦）
var last_result := ""  # win / lose
var gold_multiplier := 1  # イベント「迷子の魔物」で 2
var next_battle := {}  # 料理の効果 {"ap": n, "atk": n, "def": n, "regen": ターン数, "block": n}（次の戦闘の開始時に反映）
var battle_stats := {}  # 直前の戦闘の集計 {"overkill": 倒した時の余りの合計, "rounds": ラウンド数, "hp_lost": 味方が減らされた HP の合計}
var special_choice := {"knight": "k_sp_formation", "witch": "w_sp_explosion"}  # 前回セットした必殺技
var special_unlocked: Array = ActionList.SPECIAL_START.duplicate()  # 解放済みの必殺技 ID（強敵を倒すと 1 つ増える）


func start_new_game() -> void:
	allies = [InitAllyStatus.get_status("knight"), InitAllyStatus.get_status("witch")]
	enemies = []
	Inventory.reset()
	CurrentDeck.sync_from_init()
	stage = 1
	current_area_id = STAGES[0]
	_generate_map()
	current_floor = -1
	current_index = -1
	visited = []
	last_result = ""
	gold_multiplier = 1
	next_battle = {}
	reset_specials()
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


# ------------------------------------------------------------
# 必殺技の解放（9 回目）
# ------------------------------------------------------------
## 新しい冒険：最初の 4 つだけ解放し、セットも初期の 2 つに戻す
func reset_specials() -> void:
	special_unlocked = ActionList.SPECIAL_START.duplicate()
	special_choice = {"knight": "k_sp_formation", "witch": "w_sp_explosion"}


func is_special_unlocked(special_id: String) -> bool:
	return special_unlocked.has(special_id)


## まだ解放されていない必殺技（両キャラから）
func locked_specials() -> Array:
	return ActionList.special_ids().filter(func(id): return not special_unlocked.has(id))


## 強敵を倒した時：まだ解放されていない必殺技をランダムに 1 つ解放する。解放した ID（全部解放済みなら ""）
func unlock_random_special() -> String:
	var cand := locked_specials()
	if cand.is_empty():
		return ""
	var id: String = cand.pick_random()
	special_unlocked.append(id)
	return id


## セーブの読み込み後など：知らない ID・未解放の必殺技がセットされていたら初期のものに戻す
func fix_specials() -> void:
	var ok: Array = []
	for id in special_unlocked:
		if ActionList.special_owner(str(id)) != "" and not ok.has(str(id)):
			ok.append(str(id))
	for id in ActionList.SPECIAL_START:
		if not ok.has(id):
			ok.append(id)
	special_unlocked = ok
	var defaults := {"knight": "k_sp_formation", "witch": "w_sp_explosion"}
	for ch in defaults:
		var cur := str(special_choice.get(ch, ""))
		if ActionList.special_owner(cur) != ch or not special_unlocked.has(cur):
			special_choice[ch] = defaults[ch]


# ============================================================
# 3 階構成・ボスの報酬・ラスボス（9 回目・C）
# ============================================================

## 今の階の名前（暗がりの洞窟など）
func stage_name(s: int = -1) -> String:
	var st := stage if s < 0 else s
	return str(AreaList.DATA[STAGES[clampi(st, 1, STAGE_MAX) - 1]].name)


## 今いるマスがその階のボスか
func at_boss_node() -> bool:
	return current_floor == FLOORS - 1 and current_floor < map_floors.size() and current_index >= 0 \
			and current_index < map_floors[current_floor].size() and str(map_floors[current_floor][current_index].type) == "boss"


## 1 階・2 階のボスを倒した後なら次の階へ進む（マップを作り直す）。進んだら true。マップの画面に入った時に呼ぶ
func advance_stage_if_cleared() -> bool:
	if stage >= STAGE_MAX or last_result != "win" or battle_kind != "boss" or not at_boss_node():
		return false
	stage += 1
	current_area_id = STAGES[stage - 1]
	_generate_map()
	current_floor = -1
	current_index = -1
	visited = []
	last_result = ""
	battle_kind = "battle"
	return true


## 3 階のボスを倒した直後か（結果画面を出さずにラスボスへ続く）
func is_last_boss_next() -> bool:
	return stage >= STAGE_MAX and battle_kind == "boss" and last_result == "win"


## ラスボス戦の準備：HP を最大 HP の 30% 回復（倒れた仲間も起き上がる）。状態異常・ブロック・AP は戦闘の開始で作り直される
func start_last_boss() -> void:
	for a in allies:
		var add := int(round(int(a.max_hp) * LAST_BOSS_HEAL))
		a["hp"] = mini(int(a.max_hp), maxi(0, int(a.hp)) + add)
		a["shield"] = 0
		a["ap"] = 0
		a["status_effects"] = {}
	battle_kind = "lastboss"
	last_result = ""
	next_battle = {}  # 料理の効果は 3 階のボス戦で使い切り


## ラスボスを倒した（クリア）か。結果画面はこの時にクリアの表示をする
func is_final_clear() -> bool:
	return battle_kind == "lastboss" and last_result == "win"


## ボスの報酬（結果画面 D に渡す）。1 階・2 階のボスに勝った時だけ、それ以外は空
## [{"kind": "super_rare_card", "cards": [カードID×3]}, {"kind": "boss_relic", "relics": [レリックID×最大3]}]
## 一度決めたら SaveData.screen["boss_rewards"] に残し、再読み込みしても同じものを返す（マップに戻ると消える）
func boss_rewards() -> Array:
	if not (battle_kind == "boss" and last_result == "win" and stage < STAGE_MAX):
		return []
	var saved = SaveData.screen.get("boss_rewards")
	if saved is Array and saved.size() == 2:
		return saved
	var out: Array = [{"kind": "super_rare_card", "cards": boss_card_ids()}, {"kind": "boss_relic", "relics": boss_relic_choices()}]
	SaveData.screen["boss_rewards"] = out
	return out


## 超レア確定のカード 3 枚（持ち主はナイト・ウィッチ・どちらか。同じカードは出さない）
func boss_card_ids() -> Array:
	var owners := ["knight", "witch", ["knight", "witch"].pick_random()]
	owners.shuffle()
	var out: Array = []
	var sr: Dictionary = ActionList.ALLY_CARDS["super_rare"]
	for o in owners:
		var keys: Array = sr.keys().filter(func(k): return str(sr[k].get("owner", "")) == o and not out.has(k))
		if keys.is_empty():
			keys = sr.keys().filter(func(k): return not out.has(k))
		if keys.is_empty():
			keys = sr.keys()
		out.append(str(keys.pick_random()))
	return out


## ボスレリック 3 つ（持っていないものから。足りなければ少なくなる）
func boss_relic_choices() -> Array:
	var keys: Array = RelicList.boss_ids().filter(func(k): return not Inventory.relics.has(k))
	keys.shuffle()
	return keys.slice(0, 3)
