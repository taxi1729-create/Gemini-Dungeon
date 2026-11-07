extends Node2D
## イベント「？」：ランダムで 1 つ発生し、選択肢を選ぶ
## 9 回目（D）：選択肢をフリック入力（GuiFlickPad）に。選択肢 3 つ＝8・4・6、2 つ＝4・6、1 つ＝8。
## 右の列：デッキ一覧／ステータス。結果が出たら確定＝先へ進む（マップへ）。
## 「1 人の最大HP+5」はナイト／ウィッチを 4・6 で選び直す（確定＝戻る）。

const CHOICE_KEYS := {1: [8], 2: [4, 6], 3: [8, 4, 6]}

var ui: CanvasLayer
var pad: GuiFlickPad
var ev_id := ""
var result_label: Label
var icon_w: GuiWidget
var choices: Array = []  # [[id, 文], ...]
var finished := false  # 結果が出た
var _owner_cb := Callable()  # 「どちらの最大HPを上げますか」の選択中


func _ready() -> void:
	CurrentStatus.ensure_started()
	add_child(GuiBackground.new("title"))
	ui = CanvasLayer.new()
	add_child(ui)
	# 再読み込みで同じイベントに戻れるよう、選んだイベントをセーブに残す
	ev_id = str(SaveData.screen.get("event_id", ""))
	if not EventList.DATA.has(ev_id):
		ev_id = EventList.DATA.keys().pick_random()
		SaveData.screen["event_id"] = ev_id
		SaveData.save("event")
	var ev: Dictionary = EventList.DATA[ev_id]
	var col: Dictionary = ImageController.COL
	UiSystem.make_banner(ui, "？ EVENT", Rect2(36, 30, 200, 44), 24)
	UiSystem.make_banner(ui, ev.title, Rect2(60, 82, 600, 76), 42, col.ink, col.paper, 28)
	# アイコンの後ろに赤いギザギザ
	var deco := Control.new()
	deco.size = Vector2(720, 420)
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.draw.connect(func():
		var IC = ImageController
		var c := Vector2(360, 270)
		IC.halftone(deco, Rect2(140, 170, 440, 200), Color(col.paper, 0.08), c, 220, 16, 5)
		IC.poly_box(deco, IC.burst_pts(c, 120, 88, 14, 11, 0.2), col.red, 4.0, col.ink, col.ink, Vector2(8, 8))
		# アイコンの台座：バラ窓（ステンドグラスの輪＋紺の中心）
		IC.stained(deco, IC.ell(c, 76, 76, 36), 23, 0.9, [], Color(0, 0, 0, 0), 20.0, 22.0)
		deco.draw_arc(c, 76, 0, TAU, 40, col.ink, 4.0, true)
		deco.draw_circle(c, 58, col.ink.lerp(IC.GLASS.sacred_blue, 0.3))
		deco.draw_arc(c, 58, 0, TAU, 36, IC.GLASS.stone_gray, 3.0, true))
	ui.add_child(deco)
	icon_w = GuiWidget.new("icon", Rect2(290, 200, 140, 140))
	icon_w.icon_kind = ev.icon
	ui.add_child(icon_w)
	# 本文は白いギザギザ吹き出し（しっぽはアイコンへ）
	UiSystem.make_bubble(ui, Rect2(46, 392, 628, 120), Vector2(360, 350), 8)
	var body := UiSystem.make_label(ui, ev.text, Vector2(70, 396), Vector2(580, 112), 23, col.ink, HORIZONTAL_ALIGNMENT_CENTER, 0)
	body.add_theme_font_override("font", ImageController.font_bold)
	result_label = UiSystem.make_label(ui, "", Vector2(40, 520), Vector2(640, 80), 28, col.paper, HORIZONTAL_ALIGNMENT_CENTER, 8)
	result_label.add_theme_font_override("font", ImageController.font_head)
	result_label.add_theme_color_override("font_outline_color", col.red)
	UiSystem.make_banner(ui, "所持：%dゴールド　%s" % [Inventory.gold, Inventory.foods_text()], Rect2(60, 604, 600, 40), 18,
			col.paper, col.ink, 16)
	pad = GuiFlickPad.new()
	pad.header_left = "イベント"
	pad.hint = "選択肢を弾いて（タップで）選ぶ・長押しで説明"
	ui.add_child(pad)
	pad.chosen.connect(_on_chosen)
	choices = []
	for c in ev.choices:
		var label: String = c[1]
		if c[0] == "badge":
			label = label % BadgeList.DATA[_event_badge()].name
		choices.append([str(c[0]), label])
	_show_choices()


## 選択肢のマス（数に応じて 8・4・6 ／ 4・6 ／ 8）
func _show_choices() -> void:
	for k in [8, 4, 6]:
		pad.clear_cell(k)
	pad.clear_cell("ok")
	var keys: Array = CHOICE_KEYS.get(clampi(choices.size(), 1, 3), [8])
	for i in mini(choices.size(), keys.size()):
		var id: String = choices[i][0]
		pad.set_cell(keys[i], {"title": _short_title(id, choices[i][1]), "icon": _choice_icon(id), "accent": _choice_col(id),
				"desc": str(choices[i][1])})
	pad.queue_redraw()


## 選択肢 → マスの番号（テスト用。無ければ null）
func key_of(choice_id: String):
	var keys: Array = CHOICE_KEYS.get(clampi(choices.size(), 1, 3), [8])
	for i in mini(choices.size(), keys.size()):
		if choices[i][0] == choice_id:
			return keys[i]
	return null


## 丸いボタンに入る短い名前
func _short_title(id: String, label: String) -> String:
	match id:
		"gold40": return "ゴールド40"
		"item": return "道具"
		"altar": return "捧げる"
		"mush3": return "きのこ×3"
		"eat": return "食べる"
		"remove": return "カード削除"
		"heal12": return "HP+12"
		"maxhp": return "最大HP+5"
		"fight": return "戦う"
		"badge": return "バッジ"
		"leave": return "立ち去る"
	return label.substr(0, 6)


func _choice_icon(id: String) -> String:
	match id:
		"gold40": return "coin"
		"item": return "potion"
		"altar": return "star"
		"mush3", "eat": return "mushroom"
		"remove": return "skull"
		"heal12", "maxhp": return "heart"
		"fight": return "sword"
		"badge": return "badge"
		"leave": return "enter"
	return "question"


func _choice_col(id: String) -> Color:
	match id:
		"leave": return ImageController.GLASS.stone_gray
		"fight", "altar": return ImageController.COL.red
	return ImageController.COL.gold


func _on_chosen(key) -> void:
	match key:
		"deck":
			_lock(GuiDeckView.open(ui, "デッキ"))
			return
		"status":
			_lock(GuiStatusView.open(ui, CurrentStatus.allies))
			return
		"ok":
			if finished:
				UiSystem.goto("map")
			elif _owner_cb.is_valid():
				_owner_cb = Callable()
				_show_choices()  # 戻る
			return
	if finished:
		return
	if _owner_cb.is_valid():
		if key == 4 or key == 6:
			var cb := _owner_cb
			_owner_cb = Callable()
			cb.call("knight" if key == 4 else "witch")
		return
	var keys: Array = CHOICE_KEYS.get(clampi(choices.size(), 1, 3), [8])
	var i := keys.find(key)
	if i >= 0 and i < choices.size():
		_choose(str(choices[i][0]))


func _lock(v: Node) -> void:
	pad.locked = true
	if v != null and v.has_signal("closed"):
		v.closed.connect(func(): pad.locked = false)


func _choose(id: String) -> void:
	if finished:
		return
	match id:
		"gold40":
			Inventory.gold += 40
			_done("ゴールドを40手に入れた")
		"item":
			var it: String = Item_List.random_id()
			if Inventory.add_item(it):
				_done("%sを手に入れた" % Item_List.DATA[it].name)
			else:
				_done("%sを見つけたが、アイテムがいっぱい（3つまで）" % Item_List.DATA[it].name)
		"altar":
			for a in CurrentStatus.allies:
				a["hp"] = maxi(1, int(a.hp) - 6)
			var c := ActionList.make_card(ActionList.random_card_id("rare"))
			CurrentDeck.add_card(c.owner, c.id)
			_done("%s を授かった（%sのデッキに追加）" % [c.name, InitAllyStatus.DATA[c.owner].name])
		"mush3":
			for i in 3:
				Inventory.add_food("mush", 1)
			_done("きのこ（G1）を3つ採った")
		"eat":
			if randf() < 0.5:
				CurrentStatus.heal_all(10)
				_done("おいしい！ 全員HP+10")
			else:
				for a in CurrentStatus.allies:
					a["hp"] = maxi(1, int(a.hp) - 5)
				_done("おなかを壊した… 全員HP-5")
		"remove":
			pad.locked = true
			var v := GuiDeckView.open(ui, "削除するカードを選ぶ", func(char_id, card_id):
				CurrentDeck.remove_card(char_id, card_id)
				_done("%s を削除した" % ActionList.make_card(card_id).name))
			v.closed.connect(func(): pad.locked = false)
		"heal12":
			CurrentStatus.heal_all(12)
			_done("全員HP+12")
		"maxhp":
			_ask_owner(func(char_id):
				var a := CurrentStatus.ally(char_id)
				a["max_hp"] = int(a.max_hp) + 5
				a["hp"] = int(a.hp) + 5
				_done("%sの最大HP+5" % a.name))
		"fight":
			CurrentStatus.battle_kind = "battle"
			CurrentStatus.gold_multiplier = 2
			SaveData.screen = {}
			SaveData.save("battle")  # 再読み込みしたらこの戦闘から
			UiSystem.goto("battle")
		"badge":
			var bid := _event_badge()
			pad.locked = true
			GuiAcquire.badge(ui, bid, func(ok: bool):
				pad.locked = false
				if ok:
					_done("%sを付けてもらった" % BadgeList.DATA[bid].name)
				else:
					_done("バッジを受け取らずに立ち去った"))
		"leave":
			_done("その場を後にした")


## イベント「旅の細工師」のバッジ（再読み込みで変わらないようセーブに残す）
func _event_badge() -> String:
	var bid := str(SaveData.screen.get("event_badge", ""))
	if not BadgeList.DATA.has(bid):
		bid = BadgeList.random_id()
		SaveData.screen["event_badge"] = bid
		SaveData.save("event")
	return bid


## どちらのキャラかを 4（ナイト）・6（ウィッチ）で選ぶ。確定＝戻る
func _ask_owner(cb: Callable) -> void:
	_owner_cb = cb
	for k in [8, 4, 6]:
		pad.clear_cell(k)
	pad.set_cell(4, {"title": "ナイト", "icon": "sword", "accent": ImageController.COL.get("knight", ImageController.COL.paper), "desc": "ナイトの最大HP+5"})
	pad.set_cell(6, {"title": "ウィッチ", "icon": "flame", "accent": ImageController.COL.get("witch", ImageController.COL.paper), "desc": "ウィッチの最大HP+5"})
	pad.set_cell("ok", {"title": "戻る", "icon": "enter", "accent": ImageController.GLASS.stone_gray, "desc": "選択肢に戻る"})
	pad.flash("最大HP+5", "どちらの最大HPを上げますか？（4＝ナイト・6＝ウィッチ）")
	pad.queue_redraw()


func _done(msg: String) -> void:
	finished = true
	result_label.text = msg
	SaveData.save("map")  # イベントの結果を反映した時点で保存（再読み込みしたらマップへ）
	for k in [8, 4, 6]:
		pad.clear_cell(k)
	pad.set_cell("ok", {"title": "先へ進む", "icon": "enter", "accent": ImageController.COL.red, "desc": "マップに戻って先へ進む"})
	pad.hint = "確定で先へ進む"
	pad.queue_redraw()
