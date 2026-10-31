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
	ev_id = EventList.DATA.keys().pick_random()
	var ev: Dictionary = EventList.DATA[ev_id]
	var col: Dictionary = ImageController.COL
	UiSystem.make_label(ui, "？ イベント", Vector2(0, 50), Vector2(720, 40), 24, col.sub)
	UiSystem.make_label(ui, ev.title, Vector2(0, 92), Vector2(720, 70), 46, col.gold)
	icon_w = GuiWidget.new("icon", Rect2(260, 200, 200, 200))
	icon_w.icon_kind = ev.icon
	ui.add_child(icon_w)
	UiSystem.make_label(ui, ev.text, Vector2(50, 430), Vector2(620, 120), 26, col.text)
	choice_box = Control.new()
	choice_box.size = Vector2(720, 1280)
	choice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(choice_box)
	var y := 640.0
	for c in ev.choices:
		UiSystem.make_button(choice_box, c[1], Vector2(80, y), Vector2(560, 96), _choose.bind(c[0]), 26)
		y += 116
	result_label = UiSystem.make_label(ui, "", Vector2(50, 640), Vector2(620, 160), 28, col.good)
	UiSystem.make_label(ui, "所持：%dゴールド　%s" % [Inventory.gold, Inventory.foods_text()], Vector2(0, 1200), Vector2(720, 40), 20, col.sub)


func _choose(id: String) -> void:
	match id:
		"gold40":
			Inventory.gold += 40
			_done("ゴールドを40手に入れた")
		"item":
			var it: String = Item_List.DATA.keys().pick_random()
			Inventory.items.append(it)
			_done("%sを手に入れた" % Item_List.DATA[it].name)
		"altar":
			for a in CurrentStatus.allies:
				a["hp"] = maxi(1, int(a.hp) - 6)
			var c := ActionList.make_card(ActionList.random_card_id("rare"))
			_ask_owner("%s を授かった。どちらのデッキに入れますか？" % c.name, func(char_id):
				CurrentDeck.add_card(char_id, c.id)
				_done("%sのデッキに %s を追加した" % [InitAllyStatus.DATA[char_id].name, c.name]))
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
			UiSystem.goto("battle")
		"leave":
			_done("その場を後にした")


func _ask_owner(msg: String, cb: Callable) -> void:
	for c in choice_box.get_children():
		c.queue_free()
	UiSystem.make_label(choice_box, msg, Vector2(40, 600), Vector2(640, 80), 24, ImageController.COL.text)
	UiSystem.make_button(choice_box, "ナイト", Vector2(90, 700), Vector2(250, 90), func(): cb.call("knight"), 28)
	UiSystem.make_button(choice_box, "ウィッチ", Vector2(380, 700), Vector2(250, 90), func(): cb.call("witch"), 28)


func _done(msg: String) -> void:
	choice_box.visible = false
	result_label.text = msg
	UiSystem.make_button(ui, "先へ進む", Vector2(160, 900), Vector2(400, 90), func(): UiSystem.goto("map"), 28)
