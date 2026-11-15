extends Node
## SaveData（Autoload）：冒険の自動セーブ
## ・CurrentStatus／Inventory／CurrentDeck を user://save.json に JSON で保存する。
## ・Web 版の user:// は IndexedDB に置かれる。Godot は書き込み用に開いたファイルを close すると
##   次のフレームで IndexedDB へ同期するので、保存は「一時ファイルに書いて close → 名前を変える」を同じフレームで行う。
## ・削除だけでは同期されないため、clear() は「消した印」のファイルを書いて上書きする。
## ・戦闘中は味方のキャラのターン開始時に保存する（save_battle）。再読み込みしたらそのターン開始から再開する。
##   戦闘の状態は screen["battle_state"] に var_to_str の文字列で入れる（Vector2 や整数をそのまま戻すため）。

const VERSION := 1
const PATH := "user://save.json"
const TMP_PATH := "user://save.tmp"
const RESUMES := ["map", "battle", "event", "shop", "rest", "result", "treasure"]
# 味方で戦闘の外へ持ち越す項目（uid・pos・lane・status_effects・shield・ap などの戦闘用の項目は保存しない）
const ALLY_KEYS := ["id", "name", "hp", "max_hp", "pow", "def", "sld", "atk", "max_ap", "side", "art"]  # 素早さ（spd）は 10 回目に撤去。POW・SLD は 11 回目
const ALLY_INT_KEYS := ["hp", "max_hp", "pow", "def", "sld", "atk", "max_ap"]
const REMOVED_CARDS := ["thunder"]  # 削除したカード（読み込み時にデッキから外す。9 回目：雷撃）

## 画面ごとの途中の状態（イベントの id、戦利品、ショップの品ぞろえなど）。
## マップに戻った時（save("map")）とマスを選んだ時に空にする。
var screen: Dictionary = {}
const BATTLE_KEY := "battle_state"  # screen の中の戦闘の途中の状態
const BATTLE_VERSION := 1  # 戦闘の途中の状態の形の版（変えたら古い途中セーブは捨てて戦闘をはじめからやり直す）
var _cache := -1  # has_save() の結果のキャッシュ（-1＝未確認、0＝無し、1＝有り）


## 今の状態を保存する。resume は再開する画面
func save(resume: String) -> void:
	if not resume in RESUMES:
		push_warning("SaveData: 不明な再開先 %s" % resume)
		return
	if resume == "map":
		screen = {}
	if resume != "battle":
		screen.erase(BATTLE_KEY)  # 戦闘が終わったら途中の状態は要らない
	var data := _collect(resume)
	if _write(JSON.stringify(data, "", true, true)):
		_cache = 1


## 戦闘の途中の状態を保存する（Cont_Battle.battle_snapshot() の辞書）。再開先は戦闘
func save_battle(state: Dictionary) -> void:
	var d := state.duplicate(true)
	d["v"] = BATTLE_VERSION
	screen[BATTLE_KEY] = var_to_str(d)
	save("battle")


## 保存してある戦闘の途中の状態（無い・壊れている・形が違うなら空）。Cont_Battle が戦闘の開始時に読む
func battle_state() -> Dictionary:
	var s = screen.get(BATTLE_KEY)
	if not s is String or str(s) == "":
		return {}
	var d = str_to_var(str(s))
	if not d is Dictionary or int((d as Dictionary).get("v", 0)) != BATTLE_VERSION or _has_object(d):
		return {}
	return d


## 戻した値に Object が混ざっていないか（セーブの文字列から作られた Object は使わない）
func _has_object(v) -> bool:
	if v is Object:
		return true
	if v is Dictionary:
		for k in v:
			if _has_object(k) or _has_object(v[k]):
				return true
	elif v is Array:
		for x in v:
			if _has_object(x):
				return true
	return false


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
			"stage": CS.stage,
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
			"special_unlocked": CS.special_unlocked.duplicate(),  # D：解放済みの必殺技
			"floor_fx": CS.floor_fx.duplicate(true),  # D（10 回目）：この階の間のイベントの効果
			"event_reward": CS.event_reward.duplicate(true),  # D（10 回目）：イベントの戦闘の追加報酬
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
		if not o.has("pow"):
			# 11 回目より前のセーブ：古い値（最大 HP 60 等）を今のステータスに直す
			a.erase("pow")
			InitAllyStatus.upgrade_old(a)
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
				# 削除したカード（9 回目：雷撃）は古いセーブのデッキから外す
				if REMOVED_CARDS.has(ActionList.base_id(cid)):
					continue
				if not ActionList.make_card(cid).is_empty():
					ids.append(cid)
		decks[a.id] = ids

	var CS = CurrentStatus
	CS.current_area_id = str(st.get("area", "cave"))
	if not AreaList.DATA.has(CS.current_area_id):
		CS.current_area_id = "cave"
	# 階（9 回目・C）。古いセーブは 1 階。エリアは階に合わせる
	CS.stage = clampi(int(st.get("stage", 1)) if (st.get("stage") is float or st.get("stage") is int) else 1, 1, CS.STAGE_MAX)
	CS.current_area_id = CS.STAGES[CS.stage - 1]
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
	# D：解放済みの必殺技（古いセーブには無いので最初の 4 つ）。未解放・旧 ID のセットは初期に戻す
	CS.special_unlocked = (st.special_unlocked as Array).map(func(x): return str(x)) if st.get("special_unlocked") is Array else ActionList.SPECIAL_START.duplicate()
	CS.fix_specials()
	# D（10 回目）：この階の間の効果（数値だけ）・イベントの戦闘の追加報酬（古いセーブには無い）
	CS.floor_fx = {}
	if st.get("floor_fx") is Dictionary:
		for k in st.floor_fx:
			CS.floor_fx[str(k)] = int(st.floor_fx[k])
	CS.event_reward = {}
	if st.get("event_reward") is Dictionary:
		for k in st.event_reward:
			CS.event_reward[str(k)] = str(st.event_reward[k])
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


# ============================================================
# 12 回目（C）：周回をまたぐ記録（カード・必殺技の解放）
# ・user://unlock.json に置く。冒険のセーブ（save.json）とは別のファイルなので、clear()（全滅・踏破・新しい冒険）でも消えない。
# ・解放したカード（"pool": "unlock"）は ActionList.unlocked_cards、必殺技は unlocked_specials に入れる。
# ・1 階・2 階のボスを倒すと 3 枚、ラスボスを倒すと 5 枚＋必殺技 1 つ、ゲームオーバーで 1 枚（ナイト・ウィッチ合わせた数）。
# ============================================================
const META_PATH := "user://unlock.json"
const META_VERSION := 1
const UNLOCK_COUNT := {"boss": 3, "lastboss": 5, "gameover": 1}

var unlocked_specials: Array = []  # 解放した "pool": "unlock" の必殺技 ID


func _ready() -> void:
	load_meta()


## 周回をまたぐ記録を読む（無い・壊れている時は何も解放していない状態）
func load_meta() -> void:
	ActionList.unlocked_cards = {}
	unlocked_specials = []
	if not FileAccess.file_exists(META_PATH):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(META_PATH)) != OK or not json.data is Dictionary:
		return
	var d: Dictionary = json.data
	if d.get("cards") is Array:
		for c in d.cards:
			if not ActionList.card_raw(str(c)).is_empty():  # 知らないカードは捨てる
				ActionList.unlocked_cards[str(c)] = true
	if d.get("specials") is Array:
		for s in d.specials:
			if ActionList.special_owner(str(s)) != "" and not unlocked_specials.has(str(s)):
				unlocked_specials.append(str(s))


func save_meta() -> void:
	var f := FileAccess.open(META_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("SaveData: 解放の記録を保存できません (%s)" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify({"version": META_VERSION, "cards": ActionList.unlocked_cards.keys(), "specials": unlocked_specials}))
	f.close()  # Web 版は close した時に IndexedDB へ書き出される


## 解放の記録を消す（テスト・デバッグ用）
func reset_meta() -> void:
	ActionList.unlocked_cards = {}
	unlocked_specials = []
	save_meta()


## カードを n 枚解放する。未解放カードが残っているグループを 1 つランダムに選んでその中から解放し、
## 足りなければ残りを別のグループから。解放したカード ID の配列（全部解放済みなら空）
func unlock_cards(n: int) -> Array:
	var got: Array = []
	while got.size() < n:
		var by := {}  # グループ名 → 未解放のカード ID
		for id in ActionList.locked_card_ids():
			var g := ActionList.group_of(str(id))
			if not by.has(g):
				by[g] = []
			(by[g] as Array).append(str(id))
		if by.is_empty():
			break
		var ids: Array = by[by.keys().pick_random()]
		ids.shuffle()
		for id in ids.slice(0, n - got.size()):
			ActionList.unlocked_cards[str(id)] = true
			got.append(str(id))
	if not got.is_empty():
		save_meta()
	return got


## 必殺技が選べるか（最初から選べる、または解放済み）
func is_special_open(special_id: String) -> bool:
	return ActionList.special_pool(special_id) == "init" or unlocked_specials.has(special_id)


## 選べる必殺技の ID（両キャラ）
func open_specials() -> Array:
	return ActionList.special_ids().filter(func(id): return is_special_open(str(id)))


## 未解放の必殺技をランダムに 1 つ解放する（ラスボスを倒した時）。解放した ID（全部解放済みなら ""）
func unlock_special() -> String:
	var cand: Array = ActionList.special_ids().filter(func(id): return not is_special_open(str(id)))
	if cand.is_empty():
		return ""
	var id := str(cand.pick_random())
	unlocked_specials.append(id)
	save_meta()
	return id


## 解放をまとめて行う。kind＝"boss"（1・2 階のボス）／"lastboss"／"gameover"。
## 戻り値 {"cards": [カード ID…], "special": 必殺技 ID か ""}（結果画面が表示する）
func unlock_for(kind: String) -> Dictionary:
	var out := {"cards": unlock_cards(int(UNLOCK_COUNT.get(kind, 0))), "special": ""}
	if kind == "lastboss":
		out["special"] = unlock_special()
	return out
