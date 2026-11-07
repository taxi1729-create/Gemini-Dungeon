extends Node2D
## 戦闘結果：勝利なら戦利品と報酬（フリック入力 GuiFlickPad）、敗北・踏破ならタイトルへ
## 9 回目（D）：報酬画面をフリック入力に作り直した。
##   8・4・6 ＝ カード報酬 3 枚（1 枚だけ選べる。選ばずに閉じてもよい）
##   2・3・1 ＝ その他の報酬（レリック・バッジ・アイテム・ボスレリック・超レア報酬を、この順に並べる）
##   右の列   ＝ デッキ一覧／ステータス／確定（結果画面を閉じてマップへ）
##   ゴールド・食材は画面を開いた時に自動で手に入る（表示だけ）。強敵を倒した時は必殺技を 1 つ解放して表示する。
## 食材は戦闘の集計（CurrentStatus.battle_stats の overkill・rounds・hp_lost。無ければ 0）で決まる。
## 普通の戦闘は 25% でバッジ、強敵はレリック 1 つ。報酬カードは各 25% でバッジ付き。
## 1・2 階のボス：CurrentStatus.boss_rewards()（C）の超レア確定のカード 3 枚から 1 枚・ボスレリック 3 つから 1 つ。
## ラスボスに勝った時（CurrentStatus.is_final_clear()）だけ「踏破！」。3 階のボスの後は結果画面に来ない（C がラスボスへ直行）。
## 状態（カード・その他の報酬・受け取ったか）は SaveData.screen に残す（再読み込みで取り直しにならない）。

const CARD_KEYS := [8, 4, 6]
const OTHER_KEYS := [2, 3, 1]
const OTHER_ORDER := ["relic", "badge", "item", "boss_relic", "sr_cards"]  # その他の報酬を並べる順

var ui: CanvasLayer
var pad: GuiFlickPad
var reward_cards: Array = []  # カードの辞書 ×3
var card_taken := -1  # 受け取ったカードの番号（-1＝まだ）
var others: Array = []  # [{"kind", "id", "ids", "done"}]
var unlocked := ""  # この戦闘で解放した必殺技の ID
var sub_mode := ""  # "" ＝通常 / "boss_relic"・"sr_cards" ＝ 3 択の画面（others の番号は sub_index）
var sub_index := -1
var _t := 0.0
var _title := ""
var _title_col := Color.WHITE
var deco: Control
var _busy := false  # 受け取りの演出中


func _ready() -> void:
	CurrentStatus.ensure_started()
	add_child(GuiBackground.new("title"))
	ui = CanvasLayer.new()
	add_child(ui)
	deco = Control.new()
	deco.size = Vector2(720, 400)
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.draw.connect(_draw_deco)
	ui.add_child(deco)
	var result := CurrentStatus.last_result
	if result == "win" and _is_clear():
		_show_clear()
	elif result == "win":
		_show_win()
	else:
		_show_lose()


## 踏破（ラスボスを倒した）か
func _is_clear() -> bool:
	return CurrentStatus.is_final_clear()


func _process(delta: float) -> void:
	_t += delta
	if not ImageController.get("light_mode"):
		deco.queue_redraw()


func _draw_deco() -> void:
	var IC = ImageController
	var col: Dictionary = IC.COL
	var c := Vector2(360, 150)
	var lose: bool = _title_col == col.bad
	# 勝利：赤いギザギザが回る。敗北：赤い斜線
	if not lose:
		deco.draw_colored_polygon(IC.burst_pts(c, 230, 150, 16, 4, _t * 0.25), Color(col.red, 0.85))
		deco.draw_colored_polygon(IC.burst_pts(c, 170, 120, 16, 8, -_t * 0.2), Color(col.ink, 0.9))
	else:
		IC.stripes(deco, Rect2(0, 60, 720, 180), Color(col.red, 0.25), 26, 10, 0.5)
	deco.draw_set_transform(c, -0.06, Vector2.ONE)
	var band := Rect2(-330, -62, 660, 124)
	IC.slant(deco, band, col.red if lose else col.ink, 40, 4.0, col.paper, col.ink if lose else col.red, Vector2(12, 12))
	IC.head(deco, _title, Vector2(0, -2), 92, col.paper, 560, col.ink if lose else col.red, Vector2(6, 6))
	deco.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


# ============================================================
# 勝利
# ============================================================

func _show_win() -> void:
	var col: Dictionary = ImageController.COL
	_title = "VICTORY"
	_title_col = col.gold
	for a in CurrentStatus.allies:
		if a.hp <= 0:
			a["hp"] = 1  # 倒れた仲間は HP1 で起き上がる
	var drops: Array = []
	if not _load_state():
		drops = _process_drops()
		_new_rewards()
	else:
		drops = SaveData.screen.drops
	UiSystem.make_banner(ui, "戦利品　" + "、".join(drops), Rect2(30, 262, 660, 54), 22, col.paper, col.ink, 18)
	_build_foods(SaveData.screen.get("foods_got", []))
	if unlocked != "":
		var sp := ActionList.special(ActionList.special_owner(unlocked), unlocked)
		var who: String = InitAllyStatus.DATA[ActionList.special_owner(unlocked)].name
		UiSystem.make_banner(ui, "必殺技「%s」（%s）を解放！" % [sp.name, who], Rect2(40, 456, 640, 48), 22,
				ImageController.GLASS.deep_rose, col.paper, 16)
	UiSystem.make_banner(ui, "8・4・6＝カードを1枚　2・3・1＝その他の報酬　確定で閉じる", Rect2(30, 590, 660, 36), 18,
			ImageController.GLASS.sacred_blue, col.paper, 14)
	pad = GuiFlickPad.new()
	pad.header_left = "戦利品"
	pad.hint = "弾いて（タップで）受け取る・長押しで説明"
	ui.add_child(pad)
	pad.chosen.connect(_on_chosen)
	_save_state()
	SaveData.save("result")
	_refresh()


## 保存した報酬を読む（無ければ false）
func _load_state() -> bool:
	var sc: Dictionary = SaveData.screen
	if not (sc.get("drops") is Array and sc.get("foods_got") is Array and sc.get("reward") is Array):
		return false
	var saved: Array = sc.reward
	if saved.size() != 3 or saved.any(func(k): return ActionList.make_card(str(k)).is_empty()):
		return false
	reward_cards = saved.map(func(k): return ActionList.make_card(str(k)))
	card_taken = int(sc.get("card_taken", -1))
	unlocked = str(sc.get("unlocked", ""))
	others = []
	if sc.get("others") is Array:
		for o in sc.others:
			if o is Dictionary and _valid_other(o):
				others.append((o as Dictionary).duplicate(true))
	elif sc.get("pending") is Dictionary:
		# 古いセーブ（受け取りの途中のレリック・バッジ）
		var pend: Dictionary = sc.pending
		if pend.has("relic"):
			others.append({"kind": "relic", "id": str(pend.relic), "ids": [], "done": false})
		if pend.has("badge"):
			others.append({"kind": "badge", "id": str(pend.badge), "ids": [], "done": false})
	return true


func _valid_other(o: Dictionary) -> bool:
	var id := str(o.get("id", ""))
	match str(o.get("kind", "")):
		"relic", "boss_relic_one": return RelicList.DATA.has(id)
		"badge": return BadgeList.DATA.has(id)
		"item": return Item_List.DATA.has(id)
		"boss_relic":
			return o.get("ids") is Array and (o.ids as Array).all(func(r): return RelicList.DATA.has(str(r)))
		"sr_cards":
			return o.get("ids") is Array and (o.ids as Array).all(func(c): return not ActionList.make_card(str(c)).is_empty())
	return false


func _save_state() -> void:
	SaveData.screen["reward"] = reward_cards.map(func(c): return c.deck_id)
	SaveData.screen["card_taken"] = card_taken
	SaveData.screen["others"] = others.duplicate(true)
	SaveData.screen["unlocked"] = unlocked
	SaveData.screen.erase("pending")


## 報酬カード 3 枚と、ボスの報酬を決める（その他の報酬は _process_drops が先に入れる）
func _new_rewards() -> void:
	var owners := ["knight", "witch", ["knight", "witch"].pick_random()]
	owners.shuffle()
	reward_cards = []
	for i in 3:
		reward_cards.append(ActionList.make_card(_reward_id(owners[i])))
	card_taken = -1
	# 1・2 階のボス（C の CurrentStatus.boss_rewards()。それ以外は []）
	for br in CurrentStatus.boss_rewards():
		if not br is Dictionary:
			continue
		var rel: Array = br.get("relics", []) if br.get("relics") is Array else []
		var crd: Array = br.get("cards", []) if br.get("cards") is Array else []
		if str(br.get("kind", "")) == "boss_relic" and not rel.is_empty():
			others.append({"kind": "boss_relic", "id": "", "ids": rel.map(func(x): return str(x)), "done": false})
		elif str(br.get("kind", "")) == "super_rare_card" and not crd.is_empty():
			others.append({"kind": "sr_cards", "id": "", "ids": crd.map(func(x): return str(x)), "done": false})
	# 並べる順（レリック・バッジ・アイテム・ボスレリック・超レア報酬）。マスは 3 つまで
	others.sort_custom(func(a, b): return OTHER_ORDER.find(str(a.kind)) < OTHER_ORDER.find(str(b.kind)))
	others = others.slice(0, OTHER_KEYS.size())


## 報酬カードの ID（25% でバッジ付き）
func _reward_id(owner: String) -> String:
	if randf() < 0.25:
		return ActionList.random_badged_id("", owner)
	return ActionList.random_card_id("", owner)


# ------------------------------------------------------------
# 操作エリア
# ------------------------------------------------------------
func _refresh() -> void:
	if pad == null:
		return
	pad.header_right = "所持 %d G" % Inventory.gold
	for k in CARD_KEYS + OTHER_KEYS:
		pad.clear_cell(k)
	if sub_mode != "":
		_refresh_sub()
		return
	pad.header_left = "戦利品"
	for i in reward_cards.size():
		var c: Dictionary = reward_cards[i]
		var owner := str(c.get("owner", "knight"))
		var info := {"card": c, "title": str(c.get("name", "")),
				"desc": "%sのカード（%sのデッキに入る）\n%s" % [InitAllyStatus.DATA[owner].name, InitAllyStatus.DATA[owner].name,
						DeckController.card_text(CurrentStatus.ally(owner), c)],
				"enabled": card_taken < 0, "block_msg": "カードはもう選んだ（1枚だけ）"}
		if card_taken == i:
			info["price"] = "獲得"
		pad.set_cell(CARD_KEYS[i], info)
	for i in others.size():
		pad.set_cell(OTHER_KEYS[i], _other_info(others[i]))
	pad.set_cell("ok", {"title": "閉じる", "icon": "enter", "accent": ImageController.COL.red, "desc": "結果画面を閉じてマップへ進む（受け取っていない報酬は無くなる）"})
	pad.queue_redraw()


func _other_info(o: Dictionary) -> Dictionary:
	var info := {}
	var gold: Color = ImageController.COL.gold
	match str(o.kind):
		"relic":
			var r: Dictionary = RelicList.DATA[o.id]
			info = {"title": r.name, "icon": r.icon, "accent": gold, "sub": "レリック",
					"desc": "[i:%s]%s：%s\n（レリックは%dつまで。いっぱいなら交換）" % [r.icon, r.name, r.desc, RelicList.MAX]}
			if Inventory.has_relic(str(o.id)) and not o.done:
				info["enabled"] = false
				info["block_msg"] = "もう持っている"
		"badge":
			var b: Dictionary = BadgeList.DATA[o.id]
			info = {"title": b.name, "icon": b.icon, "accent": Color("e8c26a"), "sub": "バッジ",
					"desc": "[i:%s]%s：%s\n（受け取るとデッキのカード 1 枚に付ける）" % [b.icon, b.name, b.desc]}
		"item":
			var it: Dictionary = Item_List.DATA[o.id]
			info = {"title": it.name, "icon": str(it.get("icon", "potion")), "accent": it.get("art_col", ImageController.COL.paper), "sub": "道具",
					"desc": "[i:%s]%s：%s（戦闘中に AP0 で使う。%dつまで）" % [str(it.get("icon", "potion")), it.name, it.desc, Inventory.ITEM_MAX]}
			if Inventory.items_full() and not o.done:
				info["enabled"] = false
				info["block_msg"] = "アイテムは%dつまでしか持てない" % Inventory.ITEM_MAX
		"boss_relic":
			var names: Array = (o.ids as Array).map(func(r): return str(RelicList.DATA[str(r)].name))
			info = {"title": "ボスレリック", "icon": "crown", "accent": gold, "sub": "3つから1つ",
					"desc": "[i:crown]ボスレリックを 3 つから 1 つ選ぶ：%s" % "／".join(names)}
		"sr_cards":
			var names2: Array = (o.ids as Array).map(func(c): return str(ActionList.make_card(str(c)).get("name", "")))
			info = {"title": "超レア報酬", "icon": "cards", "accent": Color("ffb03a"), "sub": "3枚から1枚",
					"desc": "[i:cards]超レア確定のカードを 3 枚から 1 枚選ぶ：%s" % "／".join(names2)}
	if o.done:
		info["enabled"] = false
		info["price"] = "獲得"
		info["block_msg"] = "もう受け取った"
	return info


## 3 択の画面（ボスレリック・超レア報酬）：8・4・6 に候補、確定＝戻る
func _refresh_sub() -> void:
	var o: Dictionary = others[sub_index]
	var ids: Array = o.ids
	pad.header_left = "ボスレリック" if sub_mode == "boss_relic" else "超レア報酬"
	for i in mini(ids.size(), CARD_KEYS.size()):
		var id := str(ids[i])
		if sub_mode == "boss_relic":
			var r: Dictionary = RelicList.DATA[id]
			var info := {"title": r.name, "icon": r.icon, "accent": ImageController.COL.gold, "sub": "ボスレリック",
					"desc": "[i:%s]%s：%s\n（レリックは%dつまで。いっぱいなら交換）" % [r.icon, r.name, r.desc, RelicList.MAX]}
			if Inventory.has_relic(id):
				info["enabled"] = false
				info["block_msg"] = "もう持っている"
			pad.set_cell(CARD_KEYS[i], info)
		else:
			var c := ActionList.make_card(id)
			var owner := str(c.get("owner", "knight"))
			pad.set_cell(CARD_KEYS[i], {"card": c, "title": str(c.get("name", "")),
					"desc": "%sのカード（%sのデッキに入る）\n%s" % [InitAllyStatus.DATA[owner].name, InitAllyStatus.DATA[owner].name,
							DeckController.card_text(CurrentStatus.ally(owner), c)]})
	pad.set_cell("ok", {"title": "戻る", "icon": "enter", "accent": ImageController.GLASS.stone_gray, "desc": "選ばずに報酬の一覧へ戻る"})
	pad.queue_redraw()


## マスが選ばれた（テストからも呼ぶ）
func choose(key) -> void:
	_on_chosen(key)


func _on_chosen(key) -> void:
	if _busy:
		return
	match key:
		"deck":
			_lock(GuiDeckView.open(ui, "デッキ"))
			return
		"status":
			_lock(GuiStatusView.open(ui, CurrentStatus.allies))
			return
		"ok":
			if sub_mode != "":
				sub_mode = ""
				sub_index = -1
				_refresh()
			else:
				_leave()
			return
	if sub_mode != "":
		var i := CARD_KEYS.find(key)
		if i >= 0:
			_take_sub(i)
		return
	var ci := CARD_KEYS.find(key)
	if ci >= 0:
		_on_card_selected(ci)
		return
	var oi := OTHER_KEYS.find(key)
	if oi >= 0 and oi < others.size():
		_take_other(oi)


func _lock(v: Node) -> void:
	pad.locked = true
	if v != null and v.has_signal("closed"):
		v.closed.connect(func(): pad.locked = false)


## 報酬カード i を受け取る（1 枚だけ）
func _on_card_selected(i: int) -> void:
	if card_taken >= 0 or i < 0 or i >= reward_cards.size():
		return
	card_taken = i
	_save_state()
	_busy = true
	pad.locked = true
	GuiAcquire.card(ui, str(reward_cards[i].deck_id), func(_ok: bool): _after_take())
	SaveData.save("result")  # 受け取った時の自動セーブ（デッキに入れた後）


## その他の報酬 i を受け取る
func _take_other(i: int) -> void:
	var o: Dictionary = others[i]
	if o.done:
		return
	match str(o.kind):
		"relic":
			if Inventory.has_relic(str(o.id)):
				return
			_busy = true
			pad.locked = true
			GuiAcquire.relic(ui, str(o.id), func(got: bool):
				if got:
					o["done"] = true
				_after_take())
		"badge":
			_busy = true
			pad.locked = true
			GuiAcquire.badge(ui, str(o.id), func(attached: bool):
				if attached:
					o["done"] = true
				_after_take())
		"item":
			if Inventory.add_item(str(o.id)):
				o["done"] = true
				UiSystem.toast(ui, "%sを手に入れた" % Item_List.DATA[o.id].name, 560, ImageController.COL.good)
			_after_take()
		"boss_relic", "sr_cards":
			sub_mode = str(o.kind)
			sub_index = i
			_refresh()


## 3 択の画面で i 番目を受け取る
func _take_sub(i: int) -> void:
	var o: Dictionary = others[sub_index]
	if i >= (o.ids as Array).size():
		return
	var id := str(o.ids[i])
	_busy = true
	pad.locked = true
	if sub_mode == "boss_relic":
		if Inventory.has_relic(id):
			_busy = false
			pad.locked = false
			return
		GuiAcquire.relic(ui, id, func(got: bool):
			if got:
				o["done"] = true
				o["id"] = id
				sub_mode = ""
			_after_take())
	else:
		o["done"] = true
		o["id"] = id
		sub_mode = ""
		GuiAcquire.card(ui, id, func(_ok: bool): _after_take())


func _after_take() -> void:
	_busy = false
	if pad:
		pad.locked = false
	if sub_mode == "":
		sub_index = -1
	_save_state()
	SaveData.save("result")
	_refresh()


## 食材の欄：3 種の条件の値とグレード（得られなかったものは暗く「なし」）
func _build_foods(got: Array) -> void:
	var col: Dictionary = ImageController.COL
	var box := Control.new()
	box.position = Vector2(30, 326)
	box.size = Vector2(660, 118)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.draw.connect(func():
		var IC = ImageController
		var labels := {"meat": "超過ダメージ", "mush": "ラウンド数", "fish": "減ったHP"}
		var i := 0
		for f in got:
			var r := Rect2(i * 222, 0, 214, 118)
			var g := int(f.grade)
			# 食材の箱：手に入れたらエンジェルホワイト、なしはストーングレイ（どちらも墨の縁・濃い文字）
			IC.cut_rect(box, r, IC.GLASS.angel_white if g > 0 else IC.GLASS.stone_gray.darkened(0.15), 12, 3.0, col.ink,
					Color(col.red, 0.9) if g > 0 else Color(IC.GLASS.ivory_black, 0.5), Vector2(5, 5))
			var fd: Dictionary = FoodList.DATA[f.id]
			IC.icon(box, fd.icon, r.position + Vector2(44, 46), 58, Color(0, 0, 0, 0) if g > 0 else IC.GLASS.ash_gray)
			IC.head(box, ("%s G%d" % [fd.name, g]) if g > 0 else "%s なし" % fd.name, r.position + Vector2(146, 44), 26,
					col.ink if g > 0 else IC.GLASS.ash_gray.darkened(0.2), 128, Color(0, 0, 0, 0), Vector2(3, 3))
			IC.text(box, "%s %d" % [labels.get(f.id, ""), int(f.val)], r.position + Vector2(107, 96), 18, IC.GLASS.ash_gray.darkened(0.2) if g <= 0 else IC.GLASS.sacred_blue, true, 0, 200)
			if g > 0:
				for s in g:  # グレードの星
					box.draw_colored_polygon(IC.star_pts(r.position + Vector2(110 + s * 22, 74), 9, 4), col.red)
			i += 1)
	ui.add_child(box)


func _open_deck() -> void:
	GuiDeckView.open(ui, "デッキ")


## 自動プレイ（autorunner）との互換：結果画面を閉じる
func _take() -> void:
	_leave()


## ゴールド・食材を自動で受け取り、その他の報酬（others）を決める。戦利品の表示の文字列を返す
func _process_drops() -> Array:
	var got: Array = []
	others = []
	unlocked = ""
	var elite := CurrentStatus.battle_kind == "elite"
	var g := (40 if elite else randi_range(15, 25)) * CurrentStatus.gold_multiplier
	Inventory.gold += g
	got.append("%dゴールド" % g)
	CurrentStatus.gold_multiplier = 1
	# 食材：戦闘の集計で 3 種それぞれのグレードを決める（0 なら得られない）
	var bs = CurrentStatus.get("battle_stats")
	var st: Dictionary = bs if bs is Dictionary else {}
	var vals := {"meat": int(st.get("overkill", 0)), "mush": int(st.get("rounds", 0)), "fish": int(st.get("hp_lost", 0))}
	var foods_got: Array = []
	for k in ["meat", "mush", "fish"]:
		var fg := food_grade(k, int(vals[k]))
		foods_got.append({"id": k, "grade": fg, "val": int(vals[k])})
		if fg > 0:
			Inventory.add_food(k, fg)
			got.append("%s G%d" % [FoodList.DATA[k].name, fg])
	SaveData.screen["foods_got"] = foods_got
	# レリック（強敵）・バッジ（普通の戦闘で 25%）・道具はマスに並べて、選んだら受け取る
	if elite:
		var rid := RelicList.random_id(Inventory.relics)
		if rid != "":
			others.append({"kind": "relic", "id": rid, "ids": [], "done": false})
		# 強敵を倒すと、まだ解放されていない必殺技（両キャラから）をランダムに 1 つ解放
		unlocked = CurrentStatus.unlock_random_special()
	elif CurrentStatus.battle_kind == "battle" and randf() < 0.25:
		others.append({"kind": "badge", "id": BadgeList.random_id(), "ids": [], "done": false})
	if randf() < (0.6 if elite else 0.25):
		others.append({"kind": "item", "id": Item_List.random_id(), "ids": [], "done": false})
	SaveData.screen["drops"] = got
	return got


## 食材のグレード（FoodList の境目で判定）
static func food_grade(food_id: String, v: int) -> int:
	match food_id:
		"meat": return FoodList.meat_grade(v)
		"mush": return FoodList.mush_grade(v)
		"fish": return FoodList.fish_grade(v)
	return 0


# ============================================================
# 敗北・踏破
# ============================================================

func _show_lose() -> void:
	var col: Dictionary = ImageController.COL
	_title = "DEFEAT"
	SaveData.clear()  # 全滅したらセーブを消す
	_title_col = col.bad
	UiSystem.make_bubble(ui, Rect2(70, 330, 580, 90), Vector2(-9999, -9999), 1)
	var l := UiSystem.make_label(ui, "%d階「%s」で力尽きた…" % [CurrentStatus.stage, CurrentStatus.stage_name()], Vector2(70, 330), Vector2(580, 90), 28, col.ink, HORIZONTAL_ALIGNMENT_CENTER, 0)
	l.add_theme_font_override("font", ImageController.font_head)
	UiSystem.make_red_button(ui, "もう一度挑む", Vector2(160, 760), Vector2(400, 90), _restart, 30)
	UiSystem.make_button(ui, "タイトルに戻る", Vector2(160, 870), Vector2(400, 90), _to_title, 30)


func _show_clear() -> void:
	var col: Dictionary = ImageController.COL
	_title = "踏破！"
	SaveData.clear()  # 踏破したらセーブを消す
	_title_col = col.gold
	UiSystem.make_bubble(ui, Rect2(90, 320, 540, 140), Vector2(-9999, -9999), 1)
	var l := UiSystem.make_label(ui, "堕ちた双星を倒し、\nダンジョンを踏破した！", Vector2(90, 320), Vector2(540, 140), 32, col.ink, HORIZONTAL_ALIGNMENT_CENTER, 0)
	l.add_theme_font_override("font", ImageController.font_head)
	UiSystem.make_button(ui, "デッキを見る", Vector2(160, 650), Vector2(400, 80), _open_deck, 26)
	UiSystem.make_red_button(ui, "もう一度冒険する", Vector2(160, 760), Vector2(400, 90), _restart, 30)
	UiSystem.make_button(ui, "タイトルに戻る", Vector2(160, 870), Vector2(400, 90), _to_title, 30)


func _restart() -> void:
	CurrentStatus.start_new_game()
	UiSystem.goto("map")


func _to_title() -> void:
	CurrentStatus.initialized = false
	UiSystem.goto("title")


func _leave() -> void:
	SaveData.screen = {}
	SaveData.save("map")  # 結果画面を閉じた時の自動セーブ
	UiSystem.goto("map")
