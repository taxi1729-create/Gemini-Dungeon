extends Node
## SaveData（Autoload）：冒険の自動セーブ
## ・CurrentStatus／Inventory／CurrentDeck を user://save.json に JSON で保存する。
## ・Web 版の user:// は IndexedDB に置かれる。Godot は書き込み用に開いたファイルを close すると
##   次のフレームで IndexedDB へ同期するので、保存は「一時ファイルに書いて close → 名前を変える」を同じフレームで行う。
## ・削除だけでは同期されないため、clear() は「消した印」のファイルを書いて上書きする。
## ・戦闘中は保存しない（再読み込みしたらその戦闘をはじめからやり直す）。

const VERSION := 1
const PATH := "user://save.json"
const TMP_PATH := "user://save.tmp"
const RESUMES := ["map", "battle", "event", "shop", "rest", "result", "treasure"]
# 味方で戦闘の外へ持ち越す項目（uid・pos・lane・status_effects・shield・ap などの戦闘用の項目は保存しない）
const ALLY_KEYS := ["id", "name", "hp", "max_hp", "spd", "def", "atk", "max_ap", "side", "art"]
const ALLY_INT_KEYS := ["hp", "max_hp", "spd", "def", "atk", "max_ap"]

## 画面ごとの途中の状態（イベントの id、戦利品、ショップの品ぞろえなど）。
## マップに戻った時（save("map")）とマスを選んだ時に空にする。
var screen: Dictionary = {}
var _cache := -1  # has_save() の結果のキャッシュ（-1＝未確認、0＝無し、1＝有り）


## 今の状態を保存する。resume は再開する画面
func save(resume: String) -> void:
	if not resume in RESUMES:
		push_warning("SaveData: 不明な再開先 %s" % resume)
		return
	if resume == "map":
		screen = {}
	var data := _collect(resume)
	if _write(JSON.stringify(data, "", true, true)):
		_cache = 1


## 続きから再開できるセーブがあるか
func has_save() -> bool:
	if _cache < 0:
		_cache = 1 if not _read_valid().is_empty() else 0
	return _cache == 1


## セーブを読み込んで、保存した画面から再開する。読めなければ新しい冒険をはじめる
func load_and_resume() -> void:
	var data := _read_valid()
	var resume := "map"
	if data.is_empty() or not _apply(data):
		screen = {}
		CurrentStatus.start_new_game()
	else:
		resume = str(data.resume)
	UiSystem.goto(resume)


## セーブを消す（全滅・踏破・新しい冒険）。Web で確実に同期させるため、消した印を書いて上書きする
func clear() -> void:
	screen = {}
	_cache = 0
	if FileAccess.file_exists(PATH) or FileAccess.file_exists(TMP_PATH):
		_write(JSON.stringify({"version": VERSION, "cleared": true}))
		if FileAccess.file_exists(TMP_PATH):
			DirAccess.remove_absolute(TMP_PATH)


# ------------------------------------------------------------
# 保存する中身
# ------------------------------------------------------------
func _collect(resume: String) -> Dictionary:
	var CS = CurrentStatus
	var allies: Array = []
	for a in CS.allies:
		var o := {}
		for k in ALLY_KEYS:
			if a.has(k):
				o[k] = a[k]
		allies.append(o)
	var floors: Array = []
	for row in CS.map_floors:
		var r: Array = []
		for node in row:
			r.append({"type": node.type, "x": float(node.x), "next": node.next.duplicate()})
		floors.append(r)
	return {
		"version": VERSION,
		"resume": resume,
		"time": int(Time.get_unix_time_from_system()),
		"status": {
			"area": CS.current_area_id,
			"allies": allies,
			"map_floors": floors,
			"current_floor": CS.current_floor,
			"current_index": CS.current_index,
			"visited": CS.visited.duplicate(true),
			"battle_kind": CS.battle_kind,
			"last_result": CS.last_result,
			"gold_multiplier": CS.gold_multiplier,
			"next_battle": CS.next_battle.duplicate(true),
			"special_choice": CS.special_choice.duplicate(true),
		},
		"inventory": {
			"items": Inventory.items.duplicate(),
			"foods": Inventory.foods.duplicate(true),
			"relics": Inventory.relics.duplicate(),
			"gold": Inventory.gold,
		},
		"decks": CurrentDeck.decks.duplicate(true),
		"screen": screen.duplicate(true),
	}


## 読み込んだ中身を検証してから一度に反映する。おかしければ何も変えずに false
func _apply(data: Dictionary) -> bool:
	var st = data.get("status")
	var inv = data.get("inventory")
	var dk = data.get("decks")
	if not (st is Dictionary and inv is Dictionary and dk is Dictionary):
		return false
	# 味方：初期値をもとに、持ち越す項目だけ上書きして作り直す
	var allies: Array = []
	var src_allies = st.get("allies")
	if not src_allies is Array or src_allies.is_empty():
		return false
	for o in src_allies:
		if not o is Dictionary or not InitAllyStatus.DATA.has(str(o.get("id", ""))):
			return false
		var a := InitAllyStatus.get_status(str(o.id))
		for k in ALLY_KEYS:
			if o.has(k):
				a[k] = int(o[k]) if k in ALLY_INT_KEYS else str(o[k])
		a["max_hp"] = maxi(1, int(a.max_hp))
		a["hp"] = clampi(int(a.hp), 0, int(a.max_hp))
		allies.append(a)
	# マップ（JSON では数が小数になるので整数に戻す）
	var floors: Array = []
	var src_floors = st.get("map_floors")
	if not src_floors is Array or src_floors.size() != CurrentStatus.FLOORS:
		return false
	for row in src_floors:
		if not row is Array or row.is_empty():
			return false
		var r: Array = []
		for node in row:
			if not node is Dictionary or not node.get("next") is Array:
				return false
			var nx: Array = []
			for j in node.next:
				nx.append(int(j))
			r.append({"type": str(node.get("type", "battle")), "x": float(node.get("x", 0.5)), "next": nx})
		floors.append(r)
	for f in floors.size() - 1:
		for node in floors[f]:
			for j in node.next:
				if j < 0 or j >= floors[f + 1].size():
					return false
	var cf := int(st.get("current_floor", -1))
	var ci := int(st.get("current_index", -1))
	if cf >= floors.size() or (cf >= 0 and (ci < 0 or ci >= floors[cf].size())):
		return false
	var visited: Array = []
	if st.get("visited") is Array:
		for v in st.visited:
			if v is Array and v.size() == 2:
				visited.append([int(v[0]), int(v[1])])
	var next_battle := {}
	if st.get("next_battle") is Dictionary:
		for k in st.next_battle:
			next_battle[str(k)] = int(st.next_battle[k])
	var specials: Dictionary = CurrentStatus.special_choice.duplicate()
	if st.get("special_choice") is Dictionary:
		for k in st.special_choice:
			specials[str(k)] = str(st.special_choice[k])
	# 道具・食材・ゴールド（知らない ID は捨てる）
	var items: Array = []
	if inv.get("items") is Array:
		for it in inv.items:
			if Item_List.DATA.has(str(it)) and items.size() < Inventory.ITEM_MAX:
				items.append(str(it))
	# 食材は [{"id", "grade"}] の配列。古いセーブの辞書（{"meat": 2, ...}）は捨てる
	var foods: Array = []
	if inv.get("foods") is Array:
		for f in inv.foods:
			if f is Dictionary and FoodList.DATA.has(str(f.get("id", ""))):
				var g := int(f.get("grade", 1)) if (f.get("grade") is float or f.get("grade") is int) else 1
				if g >= 1:
					foods.append({"id": str(f.id), "grade": clampi(g, 1, 3)})
	# レリック（知らない ID・重複は捨てる。MAX まで）
	var relics: Array = []
	if inv.get("relics") is Array:
		for r in inv.relics:
			if RelicList.DATA.has(str(r)) and not relics.has(str(r)) and relics.size() < RelicList.MAX:
				relics.append(str(r))
	# デッキ（知らないカードは捨てる。"カードID@バッジID" の知らないバッジは外す）
	var decks := {}
	for a in allies:
		var ids: Array = []
		if dk.get(a.id) is Array:
			for c in dk[a.id]:
				var cid := str(c)
				var b := ActionList.badge_of(cid)
				if b != "" and not BadgeList.DATA.has(b):
					cid = ActionList.base_id(cid)
				if not ActionList.make_card(cid).is_empty():
					ids.append(cid)
		decks[a.id] = ids

	var CS = CurrentStatus
	CS.current_area_id = str(st.get("area", "cave"))
	if not AreaList.DATA.has(CS.current_area_id):
		CS.current_area_id = "cave"
	CS.allies = allies
	CS.enemies = []
	CS.map_floors = floors
	CS.current_floor = cf
	CS.current_index = ci
	CS.visited = visited
	CS.battle_kind = str(st.get("battle_kind", "battle"))
	CS.last_result = str(st.get("last_result", ""))
	CS.gold_multiplier = maxi(1, int(st.get("gold_multiplier", 1)))
	CS.next_battle = next_battle
	CS.special_choice = specials
	CS.initialized = true
	Inventory.items = items
	Inventory.foods = foods
	Inventory.relics = relics
	Inventory.gold = maxi(0, int(inv.get("gold", 0)))
	CurrentDeck.decks = decks
	screen = data.get("screen") if data.get("screen") is Dictionary else {}
	return true


# ------------------------------------------------------------
# ファイルの読み書き（失敗しても止めない）
# ------------------------------------------------------------
## 一時ファイルに書いて close し、本番の名前に置き換える。置き換えに失敗したら直接書く
func _write(text: String) -> bool:
	var f := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if f == null:
		return _write_direct(text)
	f.store_string(text)
	var ok := f.get_error() == OK
	f.close()  # close した時点で Web は IndexedDB への同期を予約する
	if not ok:
		return _write_direct(text)
	if DirAccess.rename_absolute(TMP_PATH, PATH) != OK:
		return _write_direct(text)
	return true


func _write_direct(text: String) -> bool:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("SaveData: 保存できません (%s)" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(text)
	var ok := f.get_error() == OK
	f.close()
	return ok


## 読める正しいセーブ（消した印でない）を返す。無ければ空。本番が壊れていたら一時ファイルも試す
func _read_valid() -> Dictionary:
	for p in [PATH, TMP_PATH]:
		var d := _read(p)
		if d.is_empty():
			continue
		if d.get("cleared", false):
			return {}  # 消した印（一時ファイルは古いので見ない）
		return d
	return {}


func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		return {}
	var json := JSON.new()  # parse_string は壊れた時にエラーを出すので、こちらで静かに読む
	if json.parse(text) != OK or not json.data is Dictionary:
		return {}
	var d: Dictionary = json.data
	var ver := int(d.get("version", 0)) if (d.get("version") is float or d.get("version") is int) else 0
	if ver < 1 or ver > VERSION:
		return {}
	if d.get("cleared", false):
		return d
	if not str(d.get("resume", "")) in RESUMES or not d.get("status") is Dictionary:
		return {}
	return d
