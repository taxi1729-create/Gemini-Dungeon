extends Node2D
## イベント「？」：ランダムで 1 つ発生し、選択肢を選ぶ

var ui: CanvasLayer
var ev_id := ""
var choice_box: Control
var result_label: Label
var icon_w: GuiWidget


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
	UiSystem.make_banner(ui, "？ EVENT", Rect2(36, 40, 200, 44), 24)
	UiSystem.make_banner(ui, ev.title, Rect2(60, 96, 600, 82), 44, col.ink, col.paper, 28)
	# アイコンの後ろに赤いギザギザ
	var deco := Control.new()
	deco.size = Vector2(720, 420)
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.draw.connect(func():
		var IC = ImageController
		IC.halftone(deco, Rect2(120, 190, 480, 230), Color(col.paper, 0.08), Vector2(360, 300), 240, 16, 5)
		IC.poly_box(deco, IC.burst_pts(Vector2(360, 300), 140, 100, 14, 11, 0.2), col.red, 4.0, col.ink, col.ink, Vector2(8, 8))
		deco.draw_circle(Vector2(360, 300), 86, col.ink))
	ui.add_child(deco)
	icon_w = GuiWidget.new("icon", Rect2(280, 220, 160, 160))
	icon_w.icon_kind = ev.icon
	ui.add_child(icon_w)
	# 本文は白いギザギザ吹き出し（しっぽはアイコンへ）
	UiSystem.make_bubble(ui, Rect2(46, 456, 628, 140), Vector2(360, 400), 8)
	var body := UiSystem.make_label(ui, ev.text, Vector2(70, 462), Vector2(580, 128), 24, col.ink, HORIZONTAL_ALIGNMENT_CENTER, 0)
	body.add_theme_font_override("font", ImageController.font_bold)
	choice_box = Control.new()
	choice_box.size = Vector2(720, 1280)
	choice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(choice_box)
	var y := 650.0
	for c in ev.choices:
		UiSystem.make_button(choice_box, c[1], Vector2(80, y), Vector2(560, 96), _choose.bind(c[0]), 26)
		y += 116
	result_label = UiSystem.make_label(ui, "", Vector2(50, 650), Vector2(620, 160), 30, col.paper, HORIZONTAL_ALIGNMENT_CENTER, 8)
	result_label.add_theme_font_override("font", ImageController.font_head)
	result_label.add_theme_color_override("font_outline_color", col.red)
	UiSystem.make_banner(ui, "所持：%dゴールド　%s" % [Inventory.gold, Inventory.foods_text()], Rect2(60, 1196, 600, 44), 20,
			col.ink, col.paper, 16)


func _choose(id: String) -> void:
	match id:
		"gold40":
			Inventory.gold += 40
			_done("ゴールドを40手に入れた")
		"item":
			var it: String = Item_List.DATA.keys().pick_random()
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
			Inventory.add_food("mush", 3)
			_done("きのこを3つ採った")
		"eat":
			if randf() < 0.5:
				CurrentStatus.heal_all(10)
				_done("おいしい！ 全員HP+10")
			else:
				for a in CurrentStatus.allies:
					a["hp"] = maxi(1, int(a.hp) - 5)
				_done("おなかを壊した… 全員HP-5")
		"remove":
			choice_box.visible = false
			var v := GuiDeckView.open(ui, "削除するカードを選ぶ", func(char_id, card_id):
				CurrentDeck.remove_card(char_id, card_id)
				_done("%s を削除した" % ActionList.make_card(card_id).name))
			v.closed.connect(func():
				if result_label.text == "":
					choice_box.visible = true)
		"heal12":
			CurrentStatus.heal_all(12)
			_done("全員HP+12")
		"maxhp":
			_ask_owner("どちらの最大HPを上げますか？", func(char_id):
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
		"leave":
			_done("その場を後にした")


func _ask_owner(msg: String, cb: Callable) -> void:
	for c in choice_box.get_children():
		c.queue_free()
	UiSystem.make_label(choice_box, msg, Vector2(40, 610), Vector2(640, 70), 26, ImageController.COL.paper, HORIZONTAL_ALIGNMENT_CENTER, 6)
	UiSystem.make_button(choice_box, "ナイト", Vector2(90, 700), Vector2(250, 90), func(): cb.call("knight"), 28)
	UiSystem.make_button(choice_box, "ウィッチ", Vector2(380, 700), Vector2(250, 90), func(): cb.call("witch"), 28)


func _done(msg: String) -> void:
	choice_box.visible = false
	result_label.text = msg
	SaveData.save("map")  # イベントの結果を反映した時点で保存（再読み込みしたらマップへ）
	UiSystem.make_red_button(ui, "先へ進む", Vector2(160, 900), Vector2(400, 90), func(): UiSystem.goto("map"), 30)
