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
	UiSystem.make_banner(ui, "洞窟の行商人", Rect2(120, 26, 420, 70), 40)
	var badge := Control.new()  # 店のアイコンの下地（黒い菱形＋赤い影）
	badge.position = Vector2(26, 18)
	badge.size = Vector2(90, 90)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.draw.connect(func():
		var d := PackedVector2Array([Vector2(45, 0), Vector2(90, 45), Vector2(45, 90), Vector2(0, 45)])
		ImageController.poly_box(badge, d, col.ink, 3.0, col.paper, col.red, Vector2(6, 6)))
	ui.add_child(badge)
	var ic := GuiWidget.new("icon", Rect2(38, 30, 66, 66))
	ic.icon_kind = "shop"
	ui.add_child(ic)
	gold_label = UiSystem.make_label(ui, "", Vector2(0, 100), Vector2(720, 40), 24, col.paper)
	gold_label.add_theme_font_override("font", ImageController.font_head)
	msg_label = UiSystem.make_label(ui, "", Vector2(20, 140), Vector2(680, 36), 20, col.good)

	_section("カード（タップで買う）", 182)
	for i in 3:
		var c := ActionList.make_card(ActionList.random_card_id())
		var v := GuiCard.new()
		v.set_card(c)
		v.position = Vector2(84 + i * 200, 224)
		ui.add_child(v)
		var price: int = PRICE[c.rarity]
		var pl := UiSystem.make_label(ui, "%dG" % price, Vector2(84 + i * 200 + 4, 398), Vector2(120, 32), 22, col.ink, HORIZONTAL_ALIGNMENT_CENTER, 0)
		pl.add_theme_font_override("font", ImageController.font_head)
		var psb := StyleBoxFlat.new()  # 値札：白い斜めのタグ
		psb.bg_color = col.paper
		psb.skew = Vector2(0.3, 0)
		psb.shadow_color = col.red
		psb.shadow_size = 1
		psb.shadow_offset = Vector2(4, 4)
		pl.add_theme_stylebox_override("normal", psb)
		var entry := {"card": c, "sold": false, "view": v, "price": price, "label": pl}
		v.tapped.connect(_buy_card.bind(entry))
		stock_cards.append(entry)

	_section("道具（各%dG）" % ITEM_PRICE, 444)
	var ids: Array = Item_List.DATA.keys()
	ids.shuffle()
	for i in 2:
		var it: Dictionary = Item_List.DATA[ids[i]]
		var entry := {"id": ids[i], "sold": false}
		var b := UiSystem.make_button(ui, "%s\n%s" % [it.name, it.desc], Vector2(34 + i * 336, 486), Vector2(316, 100), Callable(), 18)
		b.pressed.connect(_buy_item.bind(entry))
		entry["btn"] = b
		stock_items.append(entry)

	_section("食材（各%dG）" % FOOD_PRICE, 604)
	var x := 30.0
	for k in FoodList.DATA:
		var b := UiSystem.make_button(ui, "     " + FoodList.DATA[k].name, Vector2(x + 4, 646), Vector2(204, 84), _buy_food.bind(k), 24)
		var fic := GuiWidget.new("icon", Rect2(20, 14, 56, 56))
		fic.icon_kind = FoodList.DATA[k].icon
		b.add_child(fic)
		food_btns[k] = b
		x += 225

	remove_btn = UiSystem.make_button(ui, "カード削除（%dG・1回だけ）" % REMOVE_PRICE, Vector2(80, 770), Vector2(560, 84), _remove, 24)
	UiSystem.make_button(ui, "デッキを見る", Vector2(80, 880), Vector2(560, 80), func(): GuiDeckView.open(ui, "デッキ"), 24)
	UiSystem.make_red_button(ui, "店を出る", Vector2(160, 1100), Vector2(400, 90), func(): UiSystem.goto("map"), 30)
	_refresh()


## 区切りの見出し（赤い斜めのタグ）
func _section(txt: String, y: float) -> void:
	UiSystem.make_banner(ui, txt, Rect2(36, y, 300, 38), 20, ImageController.COL.red, ImageController.COL.paper, 12)


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
	Inventory.gold -= e.price
	e.sold = true
	e.view.visible = false
	var owner: String = e.card.owner
	CurrentDeck.add_card(owner, e.card.id)
	msg_label.text = "%sのデッキに %s を追加した" % [InitAllyStatus.DATA[owner].name, e.card.name]
	_refresh()


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
