extends Node2D
## マップ画面：下から上へ進むルート選択。次に進めるマスが光る。

const TOP := 190.0
const BOTTOM := 1030.0
const ICONS = {"battle": "battle", "elite": "elite", "rest": "rest", "boss": "boss", "event": "event", "shop": "shop", "treasure": "treasure"}
const NAMES = {"battle": "戦闘", "elite": "強敵", "rest": "休憩", "boss": "ボス", "event": "イベント", "shop": "ショップ", "treasure": "宝箱"}

var view: Control
var _t := 0.0
var _hover := []


func _ready() -> void:
	CurrentStatus.ensure_started()
	# 1 階・2 階のボスを倒した後なら次の階のマップを作る（3 階構成）
	var new_stage := CurrentStatus.advance_stage_if_cleared()
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
	UiSystem.make_banner(ui, "%d階　%s" % [CurrentStatus.stage, area], Rect2(28, 22, 440, 72), 40)
	var f := CurrentStatus.current_floor + 1
	UiSystem.make_banner(ui, "進む道を選んでください（%d / %d）" % [mini(f + 1, CurrentStatus.FLOORS), CurrentStatus.FLOORS],
			Rect2(270, 92, 430, 40), 21, col.paper, col.ink, 16)
	_build_footer(ui)
	UiSystem.make_red_button(ui, "必殺技", Vector2(566, 1048), Vector2(138, 56), _open_specials.bind(ui), 24)
	if new_stage:
		_show_stage_intro(ui)


## 階が変わった時の演出：ステンドグラスの帯に「2階 沈黙の回廊」。タップかしばらくで消える（ライトモードは動きなし）
func _show_stage_intro(ui: CanvasLayer) -> void:
	var light: bool = ImageController.get("light_mode") == true
	var box := Control.new()
	box.size = Vector2(720, 1280)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.z_index = 120
	ui.add_child(box)
	var st := CurrentStatus.stage
	var nm := CurrentStatus.stage_name()
	var t0 := [0.0]
	box.draw.connect(func():
		var IC = ImageController
		var k := clampf(t0[0] / 0.35, 0.0, 1.0) if not light else 1.0
		box.draw_rect(Rect2(0, 0, 720, 1280), Color(IC.GLASS.ivory_black, 0.72 * k))
		var band := Rect2(-20, 480, 760, 260)
		IC.stained(box, IC.pts([[band.position.x, band.position.y + 30], [band.end.x, band.position.y], [band.end.x, band.end.y - 30], [band.position.x, band.end.y]]),
				17 + st, 0.6 * k, [], Color(0, 0, 0, 0), 26.0, 30.0)
		IC.slant(box, Rect2(70, 540, 580, 140), Color(IC.COL.ink, 0.92 * k), 30, 4.0, Color(IC.COL.paper, k), Color(IC.COL.red, k), Vector2(10, 10))
		IC.head(box, "%d階" % st, Vector2(360, 580), 40, Color(IC.COL.gold, k), 300)
		IC.head(box, nm, Vector2(360, 638), 56, Color(IC.COL.paper, k), 540, Color(IC.COL.red, k), Vector2(5, 5)))
	var close := func():
		if is_instance_valid(box):
			box.queue_free()
	box.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			close.call())
	if not light:
		var tw := box.create_tween()
		tw.tween_method(func(v: float):
			t0[0] = v
			box.queue_redraw(), 0.0, 0.35, 0.35)
	# 時間で消す（box に付いた tween なので、先に画面が変わって box が消えても呼ばれない）
	var tw_close := box.create_tween()
	tw_close.tween_interval(2.2)
	tw_close.tween_callback(box.queue_free)


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
				view.draw_circle(p + Vector2(4, 4), rad, Color(IC.GLASS.ivory_black, 0.6))
			# マスの面：ブラッキッシュブルー×セイクレッドブルー（通ったマスはアイボリーブラック寄り）
			var base: Color = IC.COL.ink.lerp(IC.GLASS.sacred_blue, 0.5)
			if can:
				base = IC.COL.red
			elif visited and not is_cur:
				base = IC.GLASS.ivory_black.lerp(IC.GLASS.ash_gray, 0.3)
			view.draw_circle(p, rad, base)
			if node.type == "boss" and not can:
				# ボスのマス：バラ窓のステンドグラス
				IC.stained(view, IC.ell(p, rad - 3, rad - 3, 28), 41, 0.75, [], Color(0, 0, 0, 0), 16.0, 18.0)
				view.draw_circle(p, rad * 0.62, Color(IC.COL.ink, 0.85))
			var ring: Color = IC.COL.paper if (can or is_cur) else Color(IC.GLASS.holy_blue, 0.6)
			if node.type == "boss" and not can:
				ring = IC.COL.red
			view.draw_arc(p, rad, 0, TAU, 40, ring, 4 if (can or is_cur) else 2, true)
			var ic_col := Color(0, 0, 0, 0)
			if can:
				ic_col = IC.COL.paper
			elif visited and not is_cur:
				ic_col = IC.GLASS.ash_gray.lightened(0.15)
			elif not is_cur:
				ic_col = Color(IC.GLASS.angel_white, 0.75)
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
	SaveData.save(t if t in ["rest", "event", "shop", "treasure"] else "battle")
	match t:
		"rest": UiSystem.goto("rest")
		"event": UiSystem.goto("event")
		"shop": UiSystem.goto("shop")
		"treasure": UiSystem.goto("treasure")
		_: UiSystem.goto("battle")


func _build_footer(ui: CanvasLayer) -> void:
	var p := UiSystem.make_panel(ui, Rect2(16, 1112, 688, 156))
	UiSystem.set_panel_light(p)  # 文字の箱はエンジェルホワイト＋濃い文字
	var x := 22.0
	for a in CurrentStatus.allies:
		var col: Color = ImageController.COL.ink if a.hp > 0 else ImageController.COL.red
		UiSystem.make_banner(p, a.name, Rect2(x - 4, 10, 118, 32), 20, ImageController.COL.get(a.id, ImageController.COL.ink), ImageController.COL.paper, 10)
		var hp := UiSystem.make_label(p, "HP %d/%d" % [a.hp, a.max_hp], Vector2(x, 44), Vector2(200, 34), 26, col, HORIZONTAL_ALIGNMENT_LEFT, 0)
		hp.add_theme_font_override("font", ImageController.font_head)
		UiSystem.make_label(p, "デッキ%d枚" % CurrentDeck.decks[a.id].size(), Vector2(x + 124, 12), Vector2(86, 30), 15, ImageController.GLASS.ash_gray, HORIZONTAL_ALIGNMENT_LEFT, 0)
		x += 220
	var txt := "%dゴールド\n道具 %d個" % [Inventory.gold, Inventory.items.size()]
	UiSystem.make_label(p, txt, Vector2(462, 10), Vector2(220, 70), 20, ImageController.COL.ink, HORIZONTAL_ALIGNMENT_LEFT, 0)
	# 食材（アイコン＋グレード）とレリック（タップで説明）
	var belong := Control.new()
	belong.position = Vector2(0, 84)
	belong.size = Vector2(688, 66)
	belong.mouse_filter = Control.MOUSE_FILTER_STOP
	belong.draw.connect(_draw_belongings.bind(belong))
	p.add_child(belong)
	var bub := GuiDescBubble.new()
	ui.add_child(bub)
	belong.gui_input.connect(func(ev: InputEvent):
		if not (ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT):
			return
		if not ev.pressed:
			bub.hide_bubble()
			return
		for i in Inventory.relics.size():
			var c := RELIC_X0 + Vector2(i * RELIC_GAP, 0)
			if ev.position.distance_to(c) < 28:
				var r: Dictionary = RelicList.DATA[Inventory.relics[i]]
				bub.show_text(r.name, "[i:%s]%s" % [r.icon, r.desc], belong.global_position + c)
				return)


const RELIC_X0 := Vector2(400, 33)  # フッターのレリックの 1 つ目の中心（belong の座標）
const RELIC_GAP := 60.0


func _draw_belongings(c: Control) -> void:
	var IC = ImageController
	var col: Dictionary = IC.COL
	c.draw_line(Vector2(16, 2), Vector2(672, 2), Color(col.ink, 0.25), 2)
	var x := 30.0
	if Inventory.foods.is_empty():
		IC.text(c, "食材なし", Vector2(80, 33), 18, IC.GLASS.ash_gray, true)
	for k in FoodList.DATA:
		for i in Inventory.food_indices(k):
			if x > 340:
				break
			IC.icon(c, FoodList.DATA[k].icon, Vector2(x, 33), 34)
			IC.text(c, "G%d" % int(Inventory.foods[i].grade), Vector2(x + 13, 48), 13, col.paper, true, 3, -1.0, col.ink)
			x += 38
	for i in RelicList.MAX:
		var p := RELIC_X0 + Vector2(i * RELIC_GAP, 0)
		c.draw_circle(p, 25, Color(IC.GLASS.holy_blue, 0.35))
		c.draw_arc(p, 25, 0, TAU, 28, IC.GLASS.sacred_blue if i < Inventory.relics.size() else IC.GLASS.holy_blue, 2, true)
		if i < Inventory.relics.size():
			IC.icon(c, str(RelicList.DATA[Inventory.relics[i]].icon), p, 38)


## 必殺技のセット（キャラごとに 4 つから 1 つ。未解放は「？？？」で選べない）。戦闘中は中央の長押しで発動する
func _open_specials(ui: CanvasLayer) -> void:
	var col: Dictionary = ImageController.COL
	CurrentStatus.fix_specials()
	var box := Control.new()
	box.name = "Specials"
	box.size = Vector2(720, 1280)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.z_index = 100
	ui.add_child(box)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.size = box.size
	box.add_child(dim)
	UiSystem.make_panel(box, Rect2(20, 150, 680, 1000))
	UiSystem.make_banner(box, "必殺技をセット", Rect2(40, 122, 380, 64), 32)
	UiSystem.make_label(box, "戦闘中は中央を長押しして発動（AP消費）。強敵を倒すと新しい必殺技が解放される", Vector2(40, 196), Vector2(640, 60), 18, col.sub)
	var y := 262.0
	for a in CurrentStatus.allies:
		UiSystem.make_banner(box, a.name, Rect2(44, y, 170, 38), 22, col.get(a.id, col.ink), col.paper, 12)
		var btns: Array = []
		var n := 0
		for sp in ActionList.SPECIALS[a.id]:
			var open: bool = CurrentStatus.is_special_unlocked(str(sp.id))
			var txt := "？？？\n（強敵を倒すと解放）"
			if open:
				txt = "%s（AP%d）\n%s" % [sp.name, int(sp.ap), str(sp.get("desc", ""))]
			var pos := Vector2(40 + (n % 2) * 324, y + 44 + (n >> 1) * 172)
			# 文字はボタンの上のラベルで折り返す（ボタンの文字だと横に伸びてしまう）
			var b := UiSystem.make_button(box, "", pos, Vector2(316, 164), Callable(), 17)
			var lb := UiSystem.make_label(b, txt, Vector2(18, 8), Vector2(280, 148), 18, col.paper if open else col.sub, HORIZONTAL_ALIGNMENT_CENTER, 4)
			lb.set_meta("text", txt)
			b.tooltip_text = txt
			b.set_meta("sp", str(sp.id))
			b.disabled = not open
			btns.append(b)
			n += 1
		for b in btns:
			b.pressed.connect(func():
				if not CurrentStatus.is_special_unlocked(str(b.get_meta("sp"))):
					return
				CurrentStatus.special_choice[a.id] = b.get_meta("sp")
				for o in btns:
					o.modulate = Color.WHITE if o == b else Color(1, 1, 1, 0.4))
			var picked: bool = b.get_meta("sp") == CurrentStatus.special_choice.get(a.id, "")
			b.modulate = Color.WHITE if picked else Color(1, 1, 1, 0.4)
		y += 404
	UiSystem.make_red_button(box, "決定", Vector2(210, 1070), Vector2(300, 74), func():
		SaveData.save("map")
		box.queue_free(), 30)
