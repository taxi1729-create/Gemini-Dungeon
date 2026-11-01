extends Node2D
## マップ画面：下から上へ進むルート選択。次に進めるマスが光る。

const TOP := 190.0
const BOTTOM := 1030.0
const ICONS = {"battle": "battle", "elite": "elite", "rest": "rest", "boss": "boss", "event": "event", "shop": "shop"}
const NAMES = {"battle": "戦闘", "elite": "強敵", "rest": "休憩", "boss": "ボス", "event": "イベント", "shop": "ショップ"}

var view: Control
var _t := 0.0
var _hover := []


func _ready() -> void:
	CurrentStatus.ensure_started()
	SaveData.save("map")  # マップに入った時の自動セーブ
	add_child(GuiBackground.new("map"))
	var ui := CanvasLayer.new()
	add_child(ui)
	view = Control.new()
	view.size = Vector2(720, 1280)
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	view.draw.connect(_draw_map)
	view.gui_input.connect(_on_input)
	ui.add_child(view)
	var col: Dictionary = ImageController.COL
	var area: String = AreaList.DATA[CurrentStatus.current_area_id].name
	UiSystem.make_banner(ui, area, Rect2(28, 22, 400, 72), 42)
	var f := CurrentStatus.current_floor + 1
	UiSystem.make_banner(ui, "進む道を選んでください（%d / %d 階）" % [mini(f + 1, CurrentStatus.FLOORS), CurrentStatus.FLOORS],
			Rect2(250, 92, 450, 40), 21, col.paper, col.ink, 16)
	_build_footer(ui)
	UiSystem.make_red_button(ui, "必殺技", Vector2(566, 1048), Vector2(138, 56), _open_specials.bind(ui), 24)


func _process(delta: float) -> void:
	_t += delta
	view.queue_redraw()


func _node_pos(f: int, i: int) -> Vector2:
	var row: Array = CurrentStatus.map_floors[f]
	var y := BOTTOM - (BOTTOM - TOP) * f / (CurrentStatus.FLOORS - 1)
	return Vector2(80 + 560 * float(row[i].x), y)


func _is_visited(f: int, i: int) -> bool:
	for v in CurrentStatus.visited:
		if v[0] == f and v[1] == i:
			return true
	return false


func _draw_map() -> void:
	var IC = ImageController
	var floors: Array = CurrentStatus.map_floors
	var reach := CurrentStatus.reachable()
	# 線（通った道＝赤の実線、今いるマスから出る道＝白、その他＝薄い破線）
	for f in floors.size() - 1:
		for i in floors[f].size():
			for j in floors[f][i].next:
				var a := _node_pos(f, i)
				var b := _node_pos(f + 1, j)
				var walked := _is_visited(f, i) and _is_visited(f + 1, j)
				var open: bool = f == CurrentStatus.current_floor and i == CurrentStatus.current_index
				if walked:
					view.draw_line(a, b, IC.COL.red, 6, true)
				else:
					_dashed(a, b, Color(1, 1, 1, 0.75) if open else Color(1, 1, 1, 0.16), 4 if open else 3)
	# マス
	for f in floors.size():
		for i in floors[f].size():
			var p := _node_pos(f, i)
			var node: Dictionary = floors[f][i]
			var can := false
			for r in reach:
				if r[0] == f and r[1] == i:
					can = true
			var is_cur: bool = f == CurrentStatus.current_floor and i == CurrentStatus.current_index
			var visited := _is_visited(f, i)
			var rad := 46.0 if node.type == "boss" else 36.0
			if can:
				# 進めるマス：赤いギザギザが脈打つ
				var pulse := 0.5 + 0.5 * sin(_t * 4.0)
				IC.poly_box(view, IC.burst_pts(p, rad + 16 + pulse * 6, rad + 6, 12, f * 7 + i, _t * 0.5), IC.COL.red, 3.0, IC.COL.ink)
			else:
				view.draw_circle(p + Vector2(4, 4), rad, Color(0, 0, 0, 0.6))
			var base: Color = IC.COL.ink
			if can:
				base = IC.COL.red
			elif visited and not is_cur:
				base = Color("1c1c20")
			view.draw_circle(p, rad, base)
			var ring: Color = IC.COL.paper if (can or is_cur) else Color(1, 1, 1, 0.3)
			if node.type == "boss" and not can:
				ring = IC.COL.red
			view.draw_arc(p, rad, 0, TAU, 40, ring, 4 if (can or is_cur) else 2, true)
			var ic_col := Color(0, 0, 0, 0)
			if can:
				ic_col = IC.COL.paper
			elif visited and not is_cur:
				ic_col = Color(0.4, 0.4, 0.42)
			elif not is_cur:
				ic_col = Color(0.8, 0.8, 0.82, 0.6)
			IC.icon(view, ICONS[node.type], p, rad * 1.15, ic_col)
			if can:
				var tag := Rect2(p.x - 44, p.y + rad + 8, 88, 30)
				IC.slant(view, tag, IC.COL.paper, 10, 2.0, IC.COL.ink, IC.COL.ink, Vector2(3, 3))
				IC.head(view, NAMES[node.type], tag.get_center(), 19, IC.COL.ink, 66)
			if is_cur:
				_draw_party_marker(p + Vector2(rad + 26, -8))


func _draw_party_marker(p: Vector2) -> void:
	var bob := sin(_t * 3.0) * 3
	ImageController.character(view, "knight", p + Vector2(-10, 30 + bob), 0.3, 1.0, _t)
	ImageController.character(view, "witch", p + Vector2(12, 30 + bob), 0.3, 1.0, _t)


func _dashed(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var d := a.distance_to(b)
	var n := int(d / 16)
	for k in n:
		if k % 2 == 0:
			view.draw_line(a.lerp(b, float(k) / n), a.lerp(b, float(k + 1) / n), col, w, true)


func _on_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	for r in CurrentStatus.reachable():
		if event.position.distance_to(_node_pos(r[0], r[1])) < 56:
			_select(r[0], r[1])
			return


func _select(f: int, i: int) -> void:
	var t := CurrentStatus.enter_node(f, i)
	# マスを選んだ時の自動セーブ（再読み込みしたらそのマスの画面から。戦闘ははじめから）
	SaveData.screen = {}
	SaveData.save(t if t in ["rest", "event", "shop"] else "battle")
	match t:
		"rest": UiSystem.goto("rest")
		"event": UiSystem.goto("event")
		"shop": UiSystem.goto("shop")
		_: UiSystem.goto("battle")


func _build_footer(ui: CanvasLayer) -> void:
	var p := UiSystem.make_panel(ui, Rect2(16, 1120, 688, 144))
	var x := 22.0
	for a in CurrentStatus.allies:
		var col: Color = ImageController.COL.text if a.hp > 0 else ImageController.COL.bad
		UiSystem.make_banner(p, a.name, Rect2(x - 4, 12, 150, 34), 20, ImageController.COL.get(a.id, ImageController.COL.ink), ImageController.COL.paper, 10)
		var hp := UiSystem.make_label(p, "HP %d/%d" % [a.hp, a.max_hp], Vector2(x, 50), Vector2(200, 40), 26, col, HORIZONTAL_ALIGNMENT_LEFT, 4)
		hp.add_theme_font_override("font", ImageController.font_head)
		UiSystem.make_label(p, "デッキ %d枚" % CurrentDeck.decks[a.id].size(), Vector2(x, 92), Vector2(200, 36), 18, ImageController.COL.sub, HORIZONTAL_ALIGNMENT_LEFT, 0)
		x += 220
	var txt := "%dゴールド\n%s\n道具 %d個" % [Inventory.gold, Inventory.foods_text(), Inventory.items.size()]
	UiSystem.make_label(p, txt, Vector2(450, 12), Vector2(230, 120), 18, ImageController.COL.text, HORIZONTAL_ALIGNMENT_LEFT, 0)


## 必殺技のセット（キャラごとに 2 つから 1 つ）。戦闘中は中央の長押しで発動する
func _open_specials(ui: CanvasLayer) -> void:
	var col: Dictionary = ImageController.COL
	var box := Control.new()
	box.size = Vector2(720, 1280)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.z_index = 100
	ui.add_child(box)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.size = box.size
	box.add_child(dim)
	UiSystem.make_panel(box, Rect2(30, 280, 660, 680))
	UiSystem.make_banner(box, "必殺技をセット", Rect2(50, 252, 380, 64), 32)
	UiSystem.make_label(box, "戦闘中は中央を長押しして発動（AP消費）", Vector2(30, 334), Vector2(660, 50), 20, col.sub)
	var y := 404.0
	for a in CurrentStatus.allies:
		UiSystem.make_banner(box, a.name, Rect2(54, y - 2, 170, 38), 22, col.get(a.id, col.ink), col.paper, 12)
		var btns: Array = []
		var x := 60.0
		for sp in ActionList.SPECIALS[a.id]:
			var eff: String = ("%dダメージ" % sp.power) if sp.has("power") else DeckController.plain(DeckController.effect_text({}, sp))
			var b := UiSystem.make_button(box, "%s（AP%d）\n%s" % [sp.name, sp.ap, eff], Vector2(x, y + 40), Vector2(290, 110), Callable(), 19)
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.set_meta("sp", sp.id)
			btns.append(b)
			x += 310
		for b in btns:
			b.pressed.connect(func():
				CurrentStatus.special_choice[a.id] = b.get_meta("sp")
				for o in btns:
					o.modulate = Color.WHITE if o == b else Color(1, 1, 1, 0.4))
			b.modulate = Color.WHITE if b.get_meta("sp") == CurrentStatus.special_choice.get(a.id, "") else Color(1, 1, 1, 0.4)
		y += 175
	UiSystem.make_red_button(box, "決定", Vector2(210, 860), Vector2(300, 80), box.queue_free, 30)
