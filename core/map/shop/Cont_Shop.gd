extends Node2D
## ショップ「店」：戦闘と同じフリックの操作エリア（GuiFlickPad）で買う（battle-spec.md「ショップ」）
## 品ぞろえ 9 個（テンキー 1〜9）：7・8・9＝カード 3（うち 1 枚は 3 割でバッジ付き）、5＝レリック、4＝バッジ、6＝道具、
## 1・2＝食材（グレード 1〜3）、3＝カード削除。行商人の鈴を持っていれば左の列にも 3 つ（カード・レリックかバッジ・食材）。
## 右の列：デッキ一覧／ステータス／確定＝店を出る。長押しで説明、弾く（またはタップ）と購入確認 → 購入。
## 品ぞろえと売れた物は SaveData.screen["shop"] に残す（再読み込みしても同じ店のまま）。

const PRICE := {"normal": 50, "rare": 80, "super_rare": 120}
const BADGE_CARD_EXTRA := 40  # バッジ付きカードの値上げ
const BADGE_CARD_RATE := 0.3  # 3 枚のうち 1 枚がバッジ付きになる確率
const ITEM_PRICE := 30
const FOOD_PRICE := {1: 10, 2: 20, 3: 35}
const REMOVE_PRICE := 75
const MAIN_KEYS := [7, 8, 9, 5, 4, 6, 1, 2, 3]  # 品の並び（カード 3・レリック・バッジ・道具・食材 2・削除）
const BELL_KEYS := ["left0", "left1", "left2"]  # 行商人の鈴（カード・レリックかバッジ・食材）

var ui: CanvasLayer
var pad: GuiFlickPad
var board: Control  # 所持品の表示（ゴールド・レリック・食材・道具）
var stock: Array = []  # [{key, type, id, grade, price, sold}]
var confirm_box: Control  # 購入確認


func _ready() -> void:
	CurrentStatus.ensure_started()
	add_child(GuiBackground.new("map"))
	ui = CanvasLayer.new()
	add_child(ui)
	var col: Dictionary = ImageController.COL
	UiSystem.make_banner(ui, "洞窟の行商人", Rect2(140, 28, 420, 70), 40)
	var badge := Control.new()  # 店のアイコンの下地（黒い菱形＋赤い影）
	badge.position = Vector2(26, 18)
	badge.size = Vector2(90, 90)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.draw.connect(func():
		var d := PackedVector2Array([Vector2(45, 0), Vector2(90, 45), Vector2(45, 90), Vector2(0, 45)])
		ImageController.poly_box(badge, d, col.ink, 3.0, col.paper, col.red, Vector2(6, 6))
		ImageController.icon(badge, "shop", Vector2(45, 45), 62))
	ui.add_child(badge)
	board = Control.new()
	board.position = Vector2(20, 124)
	board.size = Vector2(680, 236)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.draw.connect(_draw_board)
	ui.add_child(board)
	# 行商人のひとこと（飾り）
	var talk := Control.new()
	talk.position = Vector2(0, 380)
	talk.size = Vector2(720, 260)
	talk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	talk.draw.connect(func():
		var IC = ImageController
		IC.halftone(talk, Rect2(0, 0, 720, 260), Color(col.red, 0.1), Vector2(130, 150), 260, 18, 5)
		IC.poly_box(talk, IC.burst_pts(Vector2(130, 140), 96, 70, 14, 3), col.red, 3.0, col.ink)
		IC.icon(talk, "shop", Vector2(130, 136), 110, col.paper)
		IC.bubble(talk, Rect2(250, 50, 440, 150), Vector2(200, 140), 4)
		IC.rich_text(talk, "いらっしゃい！\n品を弾けば買える。長押しで説明だ。", Vector2(278, 86), 24, col.ink, 390, 0, 36))
	ui.add_child(talk)

	pad = GuiFlickPad.new()
	pad.header_left = "行商人"
	pad.hint = "弾いて（タップで）買う・長押しで説明"
	ui.add_child(pad)
	pad.chosen.connect(_on_chosen)

	if not _load_stock():
		stock = _gen_stock()
	_save_shop()
	_refresh()


# ============================================================
# 品ぞろえ
# ============================================================

## 新しい品ぞろえを作る
func _gen_stock() -> Array:
	var out: Array = []
	var badged := randi() % 3 if randf() < BADGE_CARD_RATE else -1
	for i in 3:
		var cid := ActionList.random_badged_id() if i == badged else ActionList.random_card_id()
		out.append(_entry(MAIN_KEYS[i], "card", cid))
	var rid := RelicList.random_id(Inventory.relics)
	if rid != "":
		out.append(_entry(5, "relic", rid))
	else:
		out.append(_entry(5, "badge", BadgeList.random_id()))  # レリックを全部持っていればバッジ
	out.append(_entry(4, "badge", BadgeList.random_id()))
	out.append(_entry(6, "item", _random_item()))
	for k in [1, 2]:
		out.append(_entry(k, "food", FoodList.DATA.keys().pick_random(), randi_range(1, 3)))
	out.append(_entry(3, "remove", "remove"))
	if Inventory.has_relic("merchant_bell"):
		out.append(_entry("left0", "card", ActionList.random_card_id()))
		var rid2 := RelicList.random_id(Inventory.relics + ([rid] if rid != "" else []))
		if rid2 != "" and randf() < 0.5:
			out.append(_entry("left1", "relic", rid2))
		else:
			out.append(_entry("left1", "badge", BadgeList.random_id()))
		out.append(_entry("left2", "food", FoodList.DATA.keys().pick_random(), randi_range(1, 3)))
	return out


func _random_item() -> String:
	var ids: Array = Item_List.DATA.keys().filter(func(k): return not Item_List.DATA[k].get("no_shop", false))
	return ids.pick_random()


func _entry(key, type: String, id: String, grade: int = 0) -> Dictionary:
	return {"key": key, "type": type, "id": id, "grade": grade, "price": _price(type, id, grade), "sold": false}


static func _price(type: String, id: String, grade: int) -> int:
	match type:
		"card":
			var c := ActionList.make_card(id)
			return int(PRICE.get(c.get("rarity", "normal"), 50)) + (BADGE_CARD_EXTRA if c.has("badge") else 0)
		"relic": return int(RelicList.DATA[id].price)
		"badge": return int(BadgeList.DATA[id].price)
		"item": return ITEM_PRICE
		"food": return int(FOOD_PRICE.get(grade, 10))
		"remove": return REMOVE_PRICE
	return 0


## 保存した品ぞろえを読む。おかしければ false（作り直す）
func _load_stock() -> bool:
	var saved = SaveData.screen.get("shop")
	if not saved is Dictionary or not saved.get("stock") is Array:
		return false
	var out: Array = []
	for e in saved.stock:
		if not e is Dictionary:
			return false
		var key = _key_from(str(e.get("key", "")))
		var type := str(e.get("type", ""))
		var id := str(e.get("id", ""))
		var grade := int(e.get("grade", 0))
		var valid := false
		match type:
			"card": valid = not ActionList.make_card(id).is_empty()
			"relic": valid = RelicList.DATA.has(id)
			"badge": valid = BadgeList.DATA.has(id)
			"item": valid = Item_List.DATA.has(id)
			"food": valid = FoodList.DATA.has(id) and grade >= 1 and grade <= 3
			"remove": valid = true
		if not valid or GuiFlickPad.cell_of(key).x < 0:
			return false
		out.append({"key": key, "type": type, "id": id, "grade": grade, "price": _price(type, id, grade), "sold": bool(e.get("sold", false))})
	if out.size() != 9 and out.size() != 12:
		return false
	stock = out
	return true


## セーブ用の文字列 → マスの key（"7" → 7、"left0" はそのまま）
static func _key_from(s: String):
	return int(s) if s.is_valid_int() else s


## 品ぞろえと売れた物を保存する（再開先はショップ）
func _save_shop() -> void:
	SaveData.screen["shop"] = {"stock": stock.map(func(e): return {"key": str(e.key), "type": e.type, "id": e.id, "grade": e.grade, "sold": e.sold})}
	SaveData.save("shop")


func entry_at(key) -> Dictionary:
	for e in stock:
		if typeof(e.key) == typeof(key) and e.key == key:
			return e
	return {}


# ============================================================
# 表示
# ============================================================

func _refresh() -> void:
	pad.header_right = "所持 %d G" % Inventory.gold
	for e in stock:
		pad.set_cell(e.key, _cell_info(e))
	pad.set_cell("ok", {"title": "店を出る", "icon": "enter", "accent": ImageController.COL.red, "desc": "店を出てマップに戻る"})
	pad.queue_redraw()
	board.queue_redraw()


## 品 → マスの中身
func _cell_info(e: Dictionary) -> Dictionary:
	var info := {"price": "%dG" % e.price, "sold": e.sold}
	var lack := Inventory.gold < int(e.price)
	var msg := "ゴールドが足りない" if lack else ""
	match e.type:
		"card":
			var c := ActionList.make_card(e.id)
			var owner := str(c.get("owner", "knight"))
			info["card"] = c
			info["title"] = c.name
			info["desc"] = "%sのカード\n%s" % [InitAllyStatus.DATA[owner].name, DeckController.card_text(CurrentStatus.ally(owner), c)]
		"relic":
			var r: Dictionary = RelicList.DATA[e.id]
			info.merge({"title": r.name, "icon": r.icon, "accent": ImageController.COL.gold, "sub": "レリック",
					"desc": "[i:%s]%s：%s\n（レリックは%dつまで。いっぱいなら交換）" % [r.icon, r.name, r.desc, RelicList.MAX]})
			if Inventory.has_relic(e.id):
				msg = "もう持っている"
		"badge":
			var b: Dictionary = BadgeList.DATA[e.id]
			info.merge({"title": b.name, "icon": b.icon, "accent": Color("e8c26a"), "sub": "バッジ",
					"desc": "[i:%s]%s：%s\n（買うとデッキのカード 1 枚に付ける。%s）" % [b.icon, b.name, b.desc, _badge_for_text(b)]})
		"item":
			var it: Dictionary = Item_List.DATA[e.id]
			info.merge({"title": it.name, "icon": str(it.get("icon", "potion")), "accent": it.get("art_col", ImageController.COL.paper), "sub": "道具",
					"desc": "[i:%s]%s：%s（戦闘中に AP0 で使う。%dつまで）" % [str(it.get("icon", "potion")), it.name, it.desc, Inventory.ITEM_MAX]})
			if not lack and Inventory.items_full():
				msg = "アイテムは%dつまでしか持てない" % Inventory.ITEM_MAX
		"food":
			var f: Dictionary = FoodList.DATA[e.id]
			info.merge({"title": "%s G%d" % [f.name, e.grade], "icon": f.icon, "accent": f.col, "sub": "食材",
					"desc": "[i:%s]%s（グレード%d）：休憩所の料理に使う。グレードの合計で料理が決まる" % [f.icon, f.name, e.grade]})
		"remove":
			info.merge({"title": "カード削除", "icon": "skull", "accent": ImageController.COL.red, "sub": "1回だけ",
					"desc": "デッキのカードを1枚選んで削除する（この店で1回だけ）"})
	info["enabled"] = msg == ""
	info["block_msg"] = msg
	return info


static func _badge_for_text(b: Dictionary) -> String:
	match b.for:
		"attack": return "付けられるのはダメージのあるカード"
		"ap": return "付けられるのは AP1 以上のカード"
		"burn": return "付けられるのは廃棄・消費のカード"
	return "どのカードにも付けられる"


## 所持品の表示：ゴールド・レリック（5 枠）・食材・道具
func _draw_board() -> void:
	var IC = ImageController
	var col: Dictionary = IC.COL
	var r := Rect2(Vector2.ZERO, board.size)
	# 所持品の棚：エンジェルホワイトの箱（墨の縁・ローズの影）に、下端だけ市松（ローズ×ストーングレイ）の飾り
	var G: Dictionary = IC.GLASS
	IC.slant(board, r, G.angel_white, 18, 3.0, col.ink, col.red, Vector2(7, 7))
	IC.checker(board, Rect2(40, r.end.y - 14, r.size.x - 80, 10), 10.0, Color(G.deep_rose, 0.75), Color(G.stone_gray, 0.9))
	# ゴールド
	IC.icon(board, "coin", Vector2(60, 46), 50)
	IC.head(board, "%d G" % Inventory.gold, Vector2(170, 46), 38, col.ink, 170)
	# 道具
	IC.text(board, "道具", Vector2(330, 46), 20, G.sacred_blue, true)
	for i in Inventory.ITEM_MAX:
		var p := Vector2(390 + i * 56, 46)
		if i < Inventory.items.size():
			var it: Dictionary = Item_List.DATA.get(Inventory.items[i], {})
			IC.icon(board, str(it.get("icon", "potion")), p, 40, it.get("art_col", col.paper))
		else:
			board.draw_arc(p, 18, 0, TAU, 20, G.holy_blue, 2, true)
	# レリック 5 枠
	IC.text(board, "レリック", Vector2(70, 112), 20, G.sacred_blue, true)
	for i in RelicList.MAX:
		var p := Vector2(160 + i * 64, 112)
		board.draw_circle(p, 26, Color(G.holy_blue, 0.35))
		board.draw_arc(p, 26, 0, TAU, 28, G.holy_blue if i >= Inventory.relics.size() else G.sacred_blue, 2, true)
		if i < Inventory.relics.size():
			IC.icon(board, str(RelicList.DATA[Inventory.relics[i]].icon), p, 40)
	# 食材（アイコン＋グレード）
	IC.text(board, "食材", Vector2(70, 180), 20, G.sacred_blue, true)
	var x := 130.0
	for k in FoodList.DATA:
		for i in Inventory.food_indices(k):
			if x > 650:
				break
			IC.icon(board, FoodList.DATA[k].icon, Vector2(x, 180), 36)
			IC.text(board, "G%d" % int(Inventory.foods[i].grade), Vector2(x + 14, 196), 14, col.paper, true, 3, -1.0, col.ink)
			x += 44
	if Inventory.foods.is_empty():
		IC.text(board, "なし", Vector2(150, 180), 20, G.ash_gray, true)


# ============================================================
# 操作
# ============================================================

func _on_chosen(key) -> void:
	match key:
		"ok":
			_leave()
			return
		"deck":
			_lock(GuiDeckView.open(ui, "デッキ"))
			return
		"status":
			_lock(GuiStatusView.open(ui, CurrentStatus.allies))
			return
	var e := entry_at(key)
	if e.is_empty() or e.sold:
		return
	_confirm(e)


## オーバーレイを出している間は操作エリアを止める
func _lock(v: Node) -> void:
	pad.locked = true
	if v != null and v.has_signal("closed"):
		v.closed.connect(func(): pad.locked = false)


func _leave() -> void:
	SaveData.save("map")  # 店を出た時の自動セーブ
	UiSystem.goto("map")


## 購入確認：品の名前・効果・値段と「買う」「やめる」
func _confirm(e: Dictionary) -> void:
	var IC = ImageController
	var col: Dictionary = IC.COL
	var info := _cell_info(e)
	pad.locked = true
	var box := Control.new()
	box.size = Vector2(720, 1280)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.z_index = 150
	ui.add_child(box)
	confirm_box = box
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.size = box.size
	box.add_child(dim)
	UiSystem.make_panel(box, Rect2(40, 330, 640, 560))
	UiSystem.make_banner(box, "購入の確認", Rect2(60, 302, 320, 60), 30)
	if info.has("card"):
		var gc := GuiCard.new()
		gc.interactive = false
		gc.set_card(info.card)
		gc.position = Vector2(84, 400)
		box.add_child(gc)
	else:
		var ic := Control.new()
		ic.position = Vector2(84, 400)
		ic.size = Vector2(128, 168)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.draw.connect(func():
			IC.poly_box(ic, IC.burst_pts(Vector2(64, 80), 66, 50, 12, 2), col.red, 3.0, col.ink)
			IC.icon(ic, str(info.get("icon", "star")), Vector2(64, 78), 80))
		box.add_child(ic)
	var nm := UiSystem.make_label(box, str(info.get("title", "")), Vector2(240, 396), Vector2(420, 50), 30, col.paper, HORIZONTAL_ALIGNMENT_LEFT, 4)
	nm.add_theme_font_override("font", IC.font_head)
	var pr := UiSystem.make_label(box, "%d G（所持 %d G → %d G）" % [e.price, Inventory.gold, Inventory.gold - int(e.price)], Vector2(240, 446), Vector2(420, 40), 22, col.gold, HORIZONTAL_ALIGNMENT_LEFT, 4)
	pr.add_theme_font_override("font", IC.font_bold)
	var desc := Control.new()
	desc.position = Vector2(64, 590)
	desc.size = Vector2(592, 170)
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body := str(info.get("desc", ""))
	desc.draw.connect(func():
		IC.bubble(desc, Rect2(Vector2.ZERO, desc.size), Vector2(-9999, -9999), 2)
		var fs := 22
		while fs > 14 and IC.rich_height(body, fs, desc.size.x - 40, fs * 1.4) > desc.size.y - 30:
			fs -= 1
		IC.rich_text(desc, body, Vector2(20, 16), fs, col.ink, desc.size.x - 40, 0, fs * 1.4))
	box.add_child(desc)
	var close := func():
		box.queue_free()
		confirm_box = null
		pad.locked = false
	UiSystem.make_red_button(box, "買う（%dG）" % e.price, Vector2(70, 790), Vector2(300, 80), func():
		close.call()
		buy(e), 28)
	UiSystem.make_button(box, "やめる", Vector2(390, 790), Vector2(260, 80), close, 28)


## 購入（確認の後）。レリック・バッジは手に入れる流れ（GuiAcquire）で手に入った時だけ払う
func buy(e: Dictionary) -> void:
	if e.sold or Inventory.gold < int(e.price):
		return
	var price := int(e.price)
	match e.type:
		"card":
			Inventory.gold -= price
			e.sold = true
			_after_buy()
			pad.locked = true
			GuiAcquire.card(ui, e.id, func(_ok: bool): _unlock_refresh())
		"relic":
			if Inventory.has_relic(e.id):
				return
			pad.locked = true
			GuiAcquire.relic(ui, e.id, func(got: bool):
				if got:
					Inventory.gold -= price
					e.sold = true
					_after_buy()
				_unlock_refresh())
		"badge":
			pad.locked = true
			GuiAcquire.badge(ui, e.id, func(attached: bool):
				if attached:
					Inventory.gold -= price
					e.sold = true
					_after_buy()
				_unlock_refresh())
		"item":
			if not Inventory.add_item(e.id):
				UiSystem.toast(ui, "アイテムは%dつまでしか持てない" % Inventory.ITEM_MAX, 560, ImageController.COL.bad)
				return
			Inventory.gold -= price
			e.sold = true
			_after_buy()
			UiSystem.toast(ui, "%sを買った" % Item_List.DATA[e.id].name, 560, ImageController.COL.good)
		"food":
			Inventory.add_food(e.id, int(e.grade))
			Inventory.gold -= price
			e.sold = true
			_after_buy()
			UiSystem.toast(ui, "%s（G%d）を買った" % [FoodList.DATA[e.id].name, e.grade], 560, ImageController.COL.good)
		"remove":
			pad.locked = true
			var v := GuiDeckView.open(ui, "削除するカードを選ぶ", func(char_id: String, card_id: String):
				_remove_from_deck(char_id, card_id)
				Inventory.gold -= price
				e.sold = true
				_after_buy()
				UiSystem.toast(ui, "%s を削除した" % ActionList.make_card(card_id).get("name", ""), 560, ImageController.COL.good))
			v.closed.connect(_unlock_refresh)


## デッキから 1 枚消す。card_id はデッキの ID（バッジ付きは "カードID@バッジID"）。
## 一覧がカードID だけを返した時は、同じカードの最初の 1 枚を消す
func _remove_from_deck(char_id: String, card_id: String) -> void:
	var deck: Array = CurrentDeck.decks.get(char_id, [])
	if deck.has(card_id):
		CurrentDeck.remove_card(char_id, card_id)
		return
	for d in deck:
		if ActionList.base_id(str(d)) == ActionList.base_id(card_id):
			CurrentDeck.remove_card(char_id, str(d))
			return


func _after_buy() -> void:
	_save_shop()
	_refresh()


func _unlock_refresh() -> void:
	pad.locked = false
	_refresh()
