extends Node2D
## 戦闘結果：勝利なら戦利品とカード報酬（3枚から1枚）＋デッキ確認、敗北・踏破ならタイトルへ
## 食材は戦闘の集計（CurrentStatus.battle_stats の overkill・rounds・hp_lost。無ければ 0）で決まる。
## 普通の戦闘は 25% でバッジ、強敵はレリック 1 つ（GuiAcquire で受け取る）。報酬カードは各 25% でバッジ付き。

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
	if SaveData.screen.get("drops") is Array and SaveData.screen.get("foods_got") is Array and not saved_cards.is_empty():
		drops = SaveData.screen.drops
	else:
		drops = _process_drops()
		saved_cards = []
	UiSystem.make_banner(ui, "戦利品　" + "、".join(drops), Rect2(30, 262, 660, 54), 24, col.paper, col.ink, 18)
	_build_foods(SaveData.screen.get("foods_got", []))
	# 案内：セイクレッドブルーの帯（背景の窓の上でも読めるように）
	UiSystem.make_banner(ui, "報酬カードを1枚選んでください（持ち主のデッキに入ります）", Rect2(30, 452, 660, 36), 20, ImageController.GLASS.sacred_blue, col.paper, 14)
	var owners := ["knight", "witch", ["knight", "witch"].pick_random()]
	owners.shuffle()
	for i in 3:
		var cid: String = str(saved_cards[i]) if not saved_cards.is_empty() else _reward_id(owners[i])
		var c := ActionList.make_card(cid)
		reward_cards.append(c)
		var v := GuiCard.new()
		v.set_card(c)
		v.position = Vector2(84 + i * 200, 494)
		ui.add_child(v)
		v.tapped.connect(_on_card_selected.bind(i))
		card_views.append(v)
	# 説明はカードを選ぶと出る白いギザギザ吹き出し（しっぽが選んだカードを指す）
	_bubble = Control.new()
	_bubble.position = Vector2(36, 682)
	_bubble.size = Vector2(648, 142)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.visible = false
	_bubble.draw.connect(func(): ImageController.bubble(_bubble, Rect2(Vector2.ZERO, _bubble.size), _tail - _bubble.position, 2))
	ui.add_child(_bubble)
	_desc = UiSystem.make_label(ui, "", Vector2(58, 686), Vector2(604, 134), 20, col.ink, HORIZONTAL_ALIGNMENT_LEFT, 0)
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_desc.add_theme_font_override("font", ImageController.font_bold)
	_desc.add_theme_constant_override("line_spacing", -3)
	owner_box = Control.new()
	owner_box.position = Vector2(0, 842)
	owner_box.size = Vector2(720, 120)
	owner_box.visible = false
	ui.add_child(owner_box)
	UiSystem.make_red_button(owner_box, "このカードをもらう", Vector2(160, 0), Vector2(400, 84), _take, 28)
	UiSystem.make_button(ui, "デッキを見る", Vector2(160, 960), Vector2(400, 80), _open_deck, 26)
	UiSystem.make_button(ui, "受け取らずに進む", Vector2(160, 1060), Vector2(400, 80), _leave, 26)
	SaveData.screen["drops"] = drops
	SaveData.screen["reward"] = reward_cards.map(func(c): return c.deck_id)
	SaveData.save("result")
	_run_pending.call_deferred()


## 報酬カードの ID（25% でバッジ付き）
func _reward_id(owner: String) -> String:
	if randf() < 0.25:
		return ActionList.random_badged_id("", owner)
	return ActionList.random_card_id("", owner)


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


## 受け取りの途中のレリック・バッジを順に出す（セーブの screen.pending に残し、終わったら消す）
func _run_pending() -> void:
	var pend: Dictionary = SaveData.screen.get("pending") if SaveData.screen.get("pending") is Dictionary else {}
	if pend.has("relic"):
		GuiAcquire.relic(ui, str(pend.relic), func(_got: bool):
			pend.erase("relic")
			SaveData.screen["pending"] = pend
			SaveData.save("result")
			_run_pending())
	elif pend.has("badge"):
		GuiAcquire.badge(ui, str(pend.badge), func(_ok: bool):
			pend.erase("badge")
			SaveData.screen["pending"] = pend
			SaveData.save("result")
			_run_pending())


func _open_deck() -> void:
	GuiDeckView.open(ui, "デッキ")


func _on_card_selected(i: int) -> void:
	chosen_card = reward_cards[i]
	for k in card_views.size():
		card_views[k].modulate = Color.WHITE if k == i else Color(1, 1, 1, 0.45)
	var owner_name: String = InitAllyStatus.DATA[chosen_card.owner].name
	var txt := DeckController.plain(DeckController.card_text({}, chosen_card))
	var b := str(chosen_card.get("badge", ""))
	if b != "" and not txt.contains(BadgeList.DATA[b].name):
		txt += "\n%s：%s" % [BadgeList.DATA[b].name, BadgeList.DATA[b].desc]
	_desc.text = txt + "\n→ %sのデッキに入ります" % owner_name
	_tail = card_views[i].position + Vector2(GuiCard.SIZE.x / 2, GuiCard.SIZE.y)
	_bubble.visible = true
	_bubble.queue_redraw()
	owner_box.visible = true


func _take() -> void:
	if chosen_card.is_empty():
		return
	var did: String = chosen_card.deck_id
	owner_box.visible = false
	chosen_card = {}
	GuiAcquire.card(ui, did, func(_ok: bool):
		SaveData.save("map")  # 報酬を受け取った時の自動セーブ
		_leave())


func _process_drops() -> Array:
	var got: Array = []
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
	SaveData.screen["foods_got"] = foods_got
	# レリック（強敵）・バッジ（普通の戦闘で 25%）は画面を作った後に受け取る
	var pend := {}
	if elite:
		var rid := RelicList.random_id(Inventory.relics)
		if rid != "":
			pend["relic"] = rid
			got.append(RelicList.DATA[rid].name)
	elif CurrentStatus.battle_kind == "battle" and randf() < 0.25:
		var bid := BadgeList.random_id()
		pend["badge"] = bid
		got.append(BadgeList.DATA[bid].name)
	SaveData.screen["pending"] = pend
	if randf() < (0.6 if elite else 0.25):
		var it: String = Item_List.DATA.keys().pick_random()
		if not Inventory.add_item(it):
			got.append("（%sは持ちきれない）" % Item_List.DATA[it].name)
			return got
		got.append(Item_List.DATA[it].name)
	return got


## 食材のグレード（FoodList の境目で判定）
static func food_grade(food_id: String, v: int) -> int:
	match food_id:
		"meat": return FoodList.meat_grade(v)
		"mush": return FoodList.mush_grade(v)
		"fish": return FoodList.fish_grade(v)
	return 0


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
