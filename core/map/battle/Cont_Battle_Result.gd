extends Node2D
## 戦闘結果：勝利なら戦利品とカード報酬（3枚から1枚）、敗北・踏破ならタイトルへ

var ui: CanvasLayer
var reward_cards: Array = []
var chosen_card: Dictionary = {}
var owner_box: Control
var card_views: Array = []
var _t := 0.0
var _title := ""
var _title_col := Color.WHITE
var deco: Control


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
	if result == "win" and CurrentStatus.battle_kind == "boss":
		_show_clear()
	elif result == "win":
		_show_win()
	else:
		_show_lose()


func _process(delta: float) -> void:
	_t += delta
	deco.queue_redraw()


func _draw_deco() -> void:
	var IC = ImageController
	var c := Vector2(360, 170)
	if _title_col == IC.COL.gold:
		deco.draw_set_transform(c, _t * 0.3, Vector2.ONE)
		deco.draw_colored_polygon(IC.star_pts(Vector2.ZERO, 170, 70, 12, 0), Color(IC.COL.gold, 0.12))
		deco.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	IC.text(deco, _title, c, 76, _title_col, true, 10, 680)


func _show_win() -> void:
	var col: Dictionary = ImageController.COL
	_title = "VICTORY"
	_title_col = col.gold
	# 倒れた仲間はHP1で起き上がる
	for a in CurrentStatus.allies:
		if a.hp <= 0:
			a["hp"] = 1
	var drops := _process_drops()
	UiSystem.make_label(ui, "戦利品：" + ("、".join(drops) if not drops.is_empty() else "なし"), Vector2(40, 290), Vector2(640, 50), 24, col.text)
	UiSystem.make_label(ui, "報酬カードを1枚選んでください（長押しで説明）", Vector2(20, 360), Vector2(680, 44), 24, col.sub)
	var count := 3
	for i in count:
		var id := ActionList.random_card_id()
		var c := ActionList.make_card(id)
		reward_cards.append(c)
		var v := GuiCard.new()
		v.set_card(c)
		v.position = Vector2(56 + i * 216 + (216 - 128) / 2.0 - 44, 440)
		v.scale = Vector2.ONE
		ui.add_child(v)
		v.tapped.connect(_on_card_selected.bind(i))
		v.hold_started.connect(_show_card_desc.bind(c))
		v.hold_ended.connect(_hide_card_desc)
		card_views.append(v)
	owner_box = Control.new()
	owner_box.position = Vector2(0, 680)
	owner_box.size = Vector2(720, 300)
	owner_box.visible = false
	ui.add_child(owner_box)
	UiSystem.make_label(owner_box, "どちらのデッキに入れますか？", Vector2(0, 0), Vector2(720, 50), 26, col.text)
	UiSystem.make_button(owner_box, "ナイト", Vector2(90, 70), Vector2(250, 84), _give.bind("knight"), 30)
	UiSystem.make_button(owner_box, "ウィッチ", Vector2(380, 70), Vector2(250, 84), _give.bind("witch"), 30)
	UiSystem.make_button(ui, "受け取らずに進む", Vector2(160, 1100), Vector2(400, 80), _leave, 26)


var _desc: Panel


func _show_card_desc(c: Dictionary) -> void:
	_hide_card_desc()
	_desc = UiSystem.make_panel(ui, Rect2(30, 660, 660, 200))
	var l := UiSystem.make_label(_desc, DeckController.card_text({}, c), Vector2(18, 10), Vector2(624, 180), 22,
			ImageController.COL.text, HORIZONTAL_ALIGNMENT_LEFT, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP


func _hide_card_desc() -> void:
	if _desc and is_instance_valid(_desc):
		_desc.queue_free()
	_desc = null


func _on_card_selected(i: int) -> void:
	chosen_card = reward_cards[i]
	for k in card_views.size():
		card_views[k].highlighted = k == i
	owner_box.visible = true


func _give(char_id: String) -> void:
	if chosen_card.is_empty():
		return
	CurrentDeck.add_card(char_id, chosen_card.id)
	var name: String = InitAllyStatus.DATA[char_id].name
	UiSystem.toast(ui, "%sのデッキに %s を追加！" % [name, chosen_card.name], 1000, ImageController.COL.good)
	owner_box.visible = false
	chosen_card = {}
	await get_tree().create_timer(0.9).timeout
	_leave()


func _process_drops() -> Array:
	var got: Array = []
	var food_keys: Array = FoodList.DATA.keys()
	var n := 1 + (1 if randf() < 0.5 else 0)
	if CurrentStatus.battle_kind == "elite":
		n += 1
	for i in n:
		var k: String = food_keys.pick_random()
		Inventory.add_food(k, 1)
		got.append(FoodList.DATA[k].name)
	if randf() < (0.6 if CurrentStatus.battle_kind == "elite" else 0.3):
		var it: String = Item_List.DATA.keys().pick_random()
		Inventory.items.append(it)
		got.append(Item_List.DATA[it].name)
	return got


func _show_lose() -> void:
	var col: Dictionary = ImageController.COL
	_title = "DEFEAT"
	_title_col = col.bad
	var floor_text := "%d 階で力尽きた…" % (CurrentStatus.current_floor + 1)
	UiSystem.make_label(ui, floor_text, Vector2(0, 320), Vector2(720, 60), 30, col.text)
	UiSystem.make_button(ui, "もう一度挑む", Vector2(160, 760), Vector2(400, 90), _restart, 30)
	UiSystem.make_button(ui, "タイトルに戻る", Vector2(160, 870), Vector2(400, 90), _to_title, 30)


func _show_clear() -> void:
	var col: Dictionary = ImageController.COL
	_title = "踏破！"
	_title_col = col.gold
	UiSystem.make_label(ui, "暗がりの洞窟の主を倒した！\nおめでとう！", Vector2(0, 330), Vector2(720, 120), 32, col.text)
	UiSystem.make_button(ui, "もう一度冒険する", Vector2(160, 760), Vector2(400, 90), _restart, 30)
	UiSystem.make_button(ui, "タイトルに戻る", Vector2(160, 870), Vector2(400, 90), _to_title, 30)


func _restart() -> void:
	CurrentStatus.start_new_game()
	UiSystem.goto("map")


func _to_title() -> void:
	CurrentStatus.initialized = false
	UiSystem.goto("title")


func _leave() -> void:
	UiSystem.goto("map")
