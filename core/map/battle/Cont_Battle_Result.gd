extends Node2D
## 戦闘結果：勝利なら戦利品とカード報酬（3枚から1枚）＋デッキ確認、敗北・踏破ならタイトルへ

var ui: CanvasLayer
var reward_cards: Array = []
var chosen_card: Dictionary = {}
var owner_box: Control
var card_views: Array = []
var _t := 0.0
var _title := ""
var _title_col := Color.WHITE
var deco: Control
var _desc: Label
var _bubble: Control  # 説明の吹き出し
var _tail := Vector2(-9999, -9999)  # 吹き出しのしっぽの向く先（選んだカード）


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


func _show_win() -> void:
	var col: Dictionary = ImageController.COL
	_title = "VICTORY"
	_title_col = col.gold
	for a in CurrentStatus.allies:
		if a.hp <= 0:
			a["hp"] = 1  # 倒れた仲間は HP1 で起き上がる
	# 戦利品と報酬カードはセーブに残す（再読み込みで取り直しにならないように）
	var saved_cards: Array = SaveData.screen.get("reward") if SaveData.screen.get("reward") is Array else []
	if saved_cards.size() != 3 or saved_cards.any(func(k): return ActionList.make_card(str(k)).is_empty()):
		saved_cards = []
	var drops: Array = []
	if SaveData.screen.get("drops") is Array and not saved_cards.is_empty():
		drops = SaveData.screen.drops
	else:
		drops = _process_drops()
		saved_cards = []
	UiSystem.make_banner(ui, "戦利品　" + "、".join(drops), Rect2(30, 262, 660, 54), 24, col.paper, col.ink, 18)
	UiSystem.make_label(ui, "報酬カードを1枚選んでください（持ち主のデッキに入ります）", Vector2(20, 330), Vector2(680, 40), 21, col.text, HORIZONTAL_ALIGNMENT_CENTER, 4)
	var owners := ["knight", "witch", ["knight", "witch"].pick_random()]
	owners.shuffle()
	for i in 3:
		var cid: String = str(saved_cards[i]) if not saved_cards.is_empty() else ActionList.random_card_id("", owners[i])
		var c := ActionList.make_card(cid)
		reward_cards.append(c)
		var v := GuiCard.new()
		v.set_card(c)
		v.position = Vector2(84 + i * 200, 390)
		ui.add_child(v)
		v.tapped.connect(_on_card_selected.bind(i))
		card_views.append(v)
	# 説明はカードを選ぶと出る白いギザギザ吹き出し（しっぽが選んだカードを指す）
	_bubble = Control.new()
	_bubble.position = Vector2(36, 588)
	_bubble.size = Vector2(648, 142)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.visible = false
	_bubble.draw.connect(func(): ImageController.bubble(_bubble, Rect2(Vector2.ZERO, _bubble.size), _tail - _bubble.position, 2))
	ui.add_child(_bubble)
	_desc = UiSystem.make_label(ui, "", Vector2(58, 592), Vector2(604, 134), 20, col.ink, HORIZONTAL_ALIGNMENT_LEFT, 0)
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_desc.add_theme_font_override("font", ImageController.font_bold)
	_desc.add_theme_constant_override("line_spacing", -3)
	owner_box = Control.new()
	owner_box.position = Vector2(0, 752)
	owner_box.size = Vector2(720, 120)
	owner_box.visible = false
	ui.add_child(owner_box)
	UiSystem.make_red_button(owner_box, "このカードをもらう", Vector2(160, 0), Vector2(400, 84), _take, 28)
	UiSystem.make_button(ui, "デッキを見る", Vector2(160, 960), Vector2(400, 80), _open_deck, 26)
	UiSystem.make_button(ui, "受け取らずに進む", Vector2(160, 1060), Vector2(400, 80), _leave, 26)
	SaveData.screen["drops"] = drops
	SaveData.screen["reward"] = reward_cards.map(func(c): return c.id)
	SaveData.save("result")


func _open_deck() -> void:
	GuiDeckView.open(ui, "デッキ")


func _on_card_selected(i: int) -> void:
	chosen_card = reward_cards[i]
	for k in card_views.size():
		card_views[k].modulate = Color.WHITE if k == i else Color(1, 1, 1, 0.45)
	var owner_name: String = InitAllyStatus.DATA[chosen_card.owner].name
	_desc.text = DeckController.plain(DeckController.card_text({}, chosen_card)) + "\n→ %sのデッキに入ります" % owner_name
	_tail = card_views[i].position + Vector2(GuiCard.SIZE.x / 2, GuiCard.SIZE.y)
	_bubble.visible = true
	_bubble.queue_redraw()
	owner_box.visible = true


func _take() -> void:
	if chosen_card.is_empty():
		return
	var owner: String = chosen_card.owner
	CurrentDeck.add_card(owner, chosen_card.id)
	SaveData.save("map")  # 報酬を受け取った時の自動セーブ
	UiSystem.toast(ui, "%sのデッキに %s を追加！" % [InitAllyStatus.DATA[owner].name, chosen_card.name], 860, ImageController.COL.good)
	owner_box.visible = false
	chosen_card = {}
	await get_tree().create_timer(0.9).timeout
	_leave()


func _process_drops() -> Array:
	var got: Array = []
	var elite := CurrentStatus.battle_kind == "elite"
	var g := (40 if elite else randi_range(15, 25)) * CurrentStatus.gold_multiplier
	Inventory.gold += g
	got.append("%dゴールド" % g)
	CurrentStatus.gold_multiplier = 1
	var n := 3 if elite else randi_range(1, 2)
	var keys: Array = FoodList.DATA.keys()
	for i in n:
		var k: String = keys.pick_random()
		Inventory.add_food(k, 1)
		got.append(FoodList.DATA[k].name)
	if randf() < (0.6 if elite else 0.25):
		var it: String = Item_List.DATA.keys().pick_random()
		if not Inventory.add_item(it):
			got.append("（%sは持ちきれない）" % Item_List.DATA[it].name)
			return got
		got.append(Item_List.DATA[it].name)
	return got


func _show_lose() -> void:
	var col: Dictionary = ImageController.COL
	_title = "DEFEAT"
	SaveData.clear()  # 全滅したらセーブを消す
	_title_col = col.bad
	UiSystem.make_bubble(ui, Rect2(150, 330, 420, 90), Vector2(-9999, -9999), 1)
	var l := UiSystem.make_label(ui, "%d 階で力尽きた…" % (CurrentStatus.current_floor + 1), Vector2(150, 330), Vector2(420, 90), 30, col.ink, HORIZONTAL_ALIGNMENT_CENTER, 0)
	l.add_theme_font_override("font", ImageController.font_head)
	UiSystem.make_red_button(ui, "もう一度挑む", Vector2(160, 760), Vector2(400, 90), _restart, 30)
	UiSystem.make_button(ui, "タイトルに戻る", Vector2(160, 870), Vector2(400, 90), _to_title, 30)


func _show_clear() -> void:
	var col: Dictionary = ImageController.COL
	_title = "踏破！"
	SaveData.clear()  # 踏破したらセーブを消す
	_title_col = col.gold
	UiSystem.make_bubble(ui, Rect2(90, 320, 540, 140), Vector2(-9999, -9999), 1)
	var l := UiSystem.make_label(ui, "暗がりの洞窟の主を倒した！\nおめでとう！", Vector2(90, 320), Vector2(540, 140), 32, col.ink, HORIZONTAL_ALIGNMENT_CENTER, 0)
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
	SaveData.save("map")  # 報酬を受け取らずに進んだ時の自動セーブ
	UiSystem.goto("map")
