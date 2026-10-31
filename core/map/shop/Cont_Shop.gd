extends Node2D
## ショップ「店」：カード 3 枚・道具 2 個・食材 3 種・カード削除（battle-spec.md「ショップ」）

const PRICE := {"normal": 50, "rare": 80, "super_rare": 120}
const ITEM_PRICE := 30
const FOOD_PRICE := 12
const REMOVE_PRICE := 75

var ui: CanvasLayer
var gold_label: Label
var msg_label: Label
var stock_cards: Array = []  # [{card, sold, view, price}]
var stock_items: Array = []  # [{id, sold, btn}]
var food_btns := {}
var remove_btn: Button
var removed := false


func _ready() -> void:
	CurrentStatus.ensure_started()
	add_child(GuiBackground.new("map"))
	ui = CanvasLayer.new()
	add_child(ui)
	var col: Dictionary = ImageController.COL
	var ic := GuiWidget.new("icon", Rect2(60, 26, 80, 80))
	ic.icon_kind = "shop"
	ui.add_child(ic)
	UiSystem.make_label(ui, "洞窟の行商人", Vector2(0, 36), Vector2(720, 60), 40, col.gold)
	gold_label = UiSystem.make_label(ui, "", Vector2(0, 100), Vector2(720, 40), 26, col.text)
	msg_label = UiSystem.make_label(ui, "", Vector2(20, 140), Vector2(680, 36), 20, col.good)

	UiSystem.make_label(ui, "カード（タップで買う）", Vector2(30, 180), Vector2(660, 36), 22, col.sub, HORIZONTAL_ALIGNMENT_LEFT)
	for i in 3:
		var c := ActionList.make_card(ActionList.random_card_id())
		var v := GuiCard.new()
		v.set_card(c)
		v.position = Vector2(84 + i * 200, 222)
		ui.add_child(v)
		var price: int = PRICE[c.rarity]
		var pl := UiSystem.make_label(ui, "%dG" % price, Vector2(84 + i * 200, 394), Vector2(128, 34), 22, col.gold)
		var entry := {"card": c, "sold": false, "view": v, "price": price, "label": pl}
		v.tapped.connect(_buy_card.bind(entry))
		stock_cards.append(entry)

	UiSystem.make_label(ui, "道具（各%dG）" % ITEM_PRICE, Vector2(30, 440), Vector2(660, 36), 22, col.sub, HORIZONTAL_ALIGNMENT_LEFT)
	var ids: Array = Item_List.DATA.keys()
	ids.shuffle()
	for i in 2:
		var it: Dictionary = Item_List.DATA[ids[i]]
		var entry := {"id": ids[i], "sold": false}
		var b := UiSystem.make_button(ui, "%s\n%s" % [it.name, it.desc], Vector2(30 + i * 335, 480), Vector2(325, 100), Callable(), 18)
		b.pressed.connect(_buy_item.bind(entry))
		entry["btn"] = b
		stock_items.append(entry)

	UiSystem.make_label(ui, "食材（各%dG）" % FOOD_PRICE, Vector2(30, 600), Vector2(660, 36), 22, col.sub, HORIZONTAL_ALIGNMENT_LEFT)
	var x := 30.0
	for k in FoodList.DATA:
		var b := UiSystem.make_button(ui, "     " + FoodList.DATA[k].name, Vector2(x, 640), Vector2(210, 84), _buy_food.bind(k), 24)
		var fic := GuiWidget.new("icon", Rect2(14, 14, 56, 56))
		fic.icon_kind = FoodList.DATA[k].icon
		b.add_child(fic)
		food_btns[k] = b
		x += 225

	remove_btn = UiSystem.make_button(ui, "カード削除（%dG・1回だけ）" % REMOVE_PRICE, Vector2(80, 770), Vector2(560, 84), _remove, 24)
	UiSystem.make_button(ui, "デッキを見る", Vector2(80, 880), Vector2(560, 80), func(): GuiDeckView.open(ui, "デッキ"), 24)
	UiSystem.make_button(ui, "店を出る", Vector2(160, 1100), Vector2(400, 90), func(): UiSystem.goto("map"), 28)
	_refresh()


func _refresh() -> void:
	gold_label.text = "所持 %d ゴールド　%s" % [Inventory.gold, Inventory.foods_text()]
	for e in stock_cards:
		e.view.playable = not e.sold and Inventory.gold >= e.price
		e.view.queue_redraw()
		if e.sold:
			e.label.text = "売り切れ"
	for e in stock_items:
		e.btn.disabled = e.sold or Inventory.gold < ITEM_PRICE
	for k in food_btns:
		food_btns[k].disabled = Inventory.gold < FOOD_PRICE
	remove_btn.disabled = removed or Inventory.gold < REMOVE_PRICE


func _buy_card(e: Dictionary) -> void:
	if e.sold or Inventory.gold < e.price:
		return
	var box := Control.new()
	box.size = Vector2(720, 1280)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.z_index = 100
	ui.add_child(box)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = box.size
	box.add_child(dim)
	UiSystem.make_panel(box, Rect2(40, 420, 640, 400))
	UiSystem.make_label(box, "%s（%dG）\nどちらのデッキに入れますか？" % [e.card.name, e.price], Vector2(40, 440), Vector2(640, 100), 24, ImageController.COL.text)
	for pair in [["knight", 70], ["witch", 370]]:
		UiSystem.make_button(box, InitAllyStatus.DATA[pair[0]].name, Vector2(pair[1], 570), Vector2(280, 90), func():
			Inventory.gold -= e.price
			e.sold = true
			e.view.visible = false
			CurrentDeck.add_card(pair[0], e.card.id)
			msg_label.text = "%sのデッキに %s を追加した" % [InitAllyStatus.DATA[pair[0]].name, e.card.name]
			box.queue_free()
			_refresh(), 28)
	UiSystem.make_button(box, "やめる", Vector2(220, 700), Vector2(280, 80), box.queue_free, 24)


func _buy_item(e: Dictionary) -> void:
	if e.sold or Inventory.gold < ITEM_PRICE:
		return
	Inventory.gold -= ITEM_PRICE
	Inventory.items.append(e.id)
	e.sold = true
	e.btn.text = "売り切れ"
	msg_label.text = "%sを買った" % Item_List.DATA[e.id].name
	_refresh()


func _buy_food(k: String) -> void:
	if Inventory.gold < FOOD_PRICE:
		return
	Inventory.gold -= FOOD_PRICE
	Inventory.add_food(k, 1)
	msg_label.text = "%sを買った" % FoodList.DATA[k].name
	_refresh()


func _remove() -> void:
	if removed or Inventory.gold < REMOVE_PRICE:
		return
	GuiDeckView.open(ui, "削除するカードを選ぶ", func(char_id, card_id):
		Inventory.gold -= REMOVE_PRICE
		removed = true
		CurrentDeck.remove_card(char_id, card_id)
		msg_label.text = "%s を削除した" % ActionList.make_card(card_id).name
		remove_btn.text = "カード削除（済）"
		_refresh())
