extends Node2D
## マップ画面：下から上へ進むルート選択。次に進めるマスが光る。

const TOP := 190.0
const BOTTOM := 1030.0
const ICONS = {"battle": "battle", "elite": "elite", "rest": "rest", "boss": "boss"}
const NAMES = {"battle": "戦闘", "elite": "強敵", "rest": "休憩", "boss": "ボス"}

var view: Control
var _t := 0.0
var _hover := []


func _ready() -> void:
	CurrentStatus.ensure_started()
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
	UiSystem.make_label(ui, area, Vector2(0, 24), Vector2(720, 56), 40, col.gold)
	var f := CurrentStatus.current_floor + 1
	UiSystem.make_label(ui, "進む道を選んでください（%d / %d 階）" % [mini(f + 1, CurrentStatus.FLOORS), CurrentStatus.FLOORS],
			Vector2(0, 84), Vector2(720, 40), 22, col.sub)
	_build_footer(ui)


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
	# 線
	for f in floors.size() - 1:
		for i in floors[f].size():
			for j in floors[f][i].next:
				var a := _node_pos(f, i)
				var b := _node_pos(f + 1, j)
				var walked := _is_visited(f, i) and _is_visited(f + 1, j)
				var open: bool = f == CurrentStatus.current_floor and i == CurrentStatus.current_index
				var col := Color(IC.COL.gold, 0.9) if walked else (Color(1, 1, 1, 0.45) if open else Color(1, 1, 1, 0.12))
				_dashed(a, b, col, 4 if walked or open else 3)
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
				var pulse := 0.5 + 0.5 * sin(_t * 4.0)
				view.draw_circle(p, rad + 10 + pulse * 6, Color(IC.COL.gold, 0.25 + 0.2 * pulse))
			var base: Color = IC.COL.panel_hi if (can or is_cur) else Color("161b2c")
			if visited and not is_cur:
				base = Color("2a2a20")
			view.draw_circle(p, rad, base)
			var ring: Color = IC.COL.gold if (can or is_cur) else Color(1, 1, 1, 0.25)
			view.draw_arc(p, rad, 0, TAU, 40, ring, 4 if can else 2, true)
			var ic_col := Color(0, 0, 0, 0) if (can or is_cur or not visited) else Color(0.5, 0.5, 0.5)
			if not can and not is_cur and not visited:
				ic_col = Color(0.75, 0.75, 0.8, 0.55)
			IC.icon(view, ICONS[node.type], p, rad * 1.15, ic_col)
			if can:
				IC.text(view, NAMES[node.type], p + Vector2(0, rad + 20), 20, IC.COL.text, true, 5)
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
	match t:
		"rest": UiSystem.goto("rest")
		_: UiSystem.goto("battle")


func _build_footer(ui: CanvasLayer) -> void:
	var p := UiSystem.make_panel(ui, Rect2(16, 1120, 688, 144))
	var x := 20.0
	for a in CurrentStatus.allies:
		var col: Color = ImageController.COL.text if a.hp > 0 else ImageController.COL.bad
		UiSystem.make_label(p, "%s\nHP %d/%d" % [a.name, a.hp, a.max_hp], Vector2(x, 12), Vector2(200, 70), 22, col, HORIZONTAL_ALIGNMENT_LEFT, 4)
		UiSystem.make_label(p, "デッキ %d枚" % CurrentDeck.decks[a.id].size(), Vector2(x, 84), Vector2(200, 40), 18, ImageController.COL.sub, HORIZONTAL_ALIGNMENT_LEFT, 0)
		x += 220
	var items: Array = []
	for it in Inventory.items:
		items.append(Item_List.DATA[it].name)
	var txt := "食材 %d\n道具 %s" % [Inventory.food_total(), "、".join(items) if not items.is_empty() else "なし"]
	UiSystem.make_label(p, txt, Vector2(450, 12), Vector2(230, 120), 18, ImageController.COL.text, HORIZONTAL_ALIGNMENT_LEFT, 0)
