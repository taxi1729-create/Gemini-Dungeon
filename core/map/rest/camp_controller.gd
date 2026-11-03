extends Node2D
## 休憩所：戦闘と同じフリックの操作エリア（GuiFlickPad）で料理か仮眠を 1 回（battle-spec.md「食材と料理」）
## 8＝肉、4＝きのこ、6＝魚：押すたびにグレードの高い物から 1 つずつ鍋へ（最大 3 つ）。鍋の食材をタップすると 1 つ戻す。
## 5・確定＝料理する（合計グレード＋料理人の鍋で FoodList.dish_for）。2＝仮眠（全員 HP 20%）。
## 空白＝ステータス、削除＝デッキ一覧。料理・仮眠はどちらか 1 回。

const NAP_PCT := 20
const FOOD_KEYS := {8: "meat", 4: "mush", 6: "fish"}
const POT_POS := Vector2(360, 330)  # 鍋の中心
const POT_SLOT := [Vector2(250, 470), Vector2(360, 470), Vector2(470, 470)]  # 鍋の食材の札（タップで戻す）

var ui: CanvasLayer
var pad: GuiFlickPad
var view: Control  # 体力・鍋・できる料理
var pot: Array = []  # 鍋に入れた食材の Inventory.foods の index（入れた順）
var done := false
var _t := 0.0


func _ready() -> void:
	CurrentStatus.ensure_started()
	add_child(GuiBackground.new("camp"))
	ui = CanvasLayer.new()
	add_child(ui)
	UiSystem.make_banner(ui, "休憩所", Rect2(40, 26, 300, 76), 48)
	UiSystem.make_banner(ui, "料理を1品作るか、仮眠をとろう", Rect2(260, 100, 420, 42), 21, ImageController.COL.paper, ImageController.COL.ink, 14)
	view = Control.new()
	view.size = Vector2(720, 652)
	view.mouse_filter = Control.MOUSE_FILTER_PASS
	view.draw.connect(_draw_view)
	view.gui_input.connect(_on_view_input)
	ui.add_child(view)
	pad = GuiFlickPad.new()
	pad.header_left = "休憩所"
	pad.hint = "食材を弾いて鍋へ・5か確定で料理・鍋の食材をタップで戻す"
	ui.add_child(pad)
	pad.chosen.connect(_on_chosen)
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	view.queue_redraw()


# ============================================================
# 鍋
# ============================================================

## 鍋の中身（[{id, grade}, ...]）
func picked() -> Array:
	return pot.map(func(i): return Inventory.foods[i])


func bonus() -> int:
	return 1 if Inventory.has_relic("chef_pot") else 0


## 今の鍋でできる料理の ID（空なら ""）
func dish_id() -> String:
	return FoodList.dish_for(picked(), bonus())


## 鍋にまだ入れていない、その食材の index（グレードの高い順）
func remaining(food_id: String) -> Array:
	return Inventory.food_indices(food_id).filter(func(i): return not pot.has(i))


## 食材を 1 つ鍋へ（高いグレードから）。入れられなければ false
func add_to_pot(food_id: String) -> bool:
	if done or pot.size() >= FoodList.PICK_MAX:
		return false
	var rest := remaining(food_id)
	if rest.is_empty():
		return false
	pot.append(rest[0])
	_refresh()
	return true


## 鍋の i 番目の食材を戻す
func take_out(i: int) -> void:
	if done or i < 0 or i >= pot.size():
		return
	pot.remove_at(i)
	_refresh()


func _on_view_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	for i in pot.size():
		if event.position.distance_to(POT_SLOT[i]) < 50:
			take_out(i)
			return


# ============================================================
# 料理・仮眠
# ============================================================

## 料理する。作れなければ ""、作れたら料理の ID
func cook() -> String:
	if done or pot.is_empty():
		return ""
	var id := dish_id()
	var d: Dictionary = FoodList.DISHES[id]
	# 食材を使う（index がずれないよう大きい方から消す）
	var idx := pot.duplicate()
	idx.sort()
	idx.reverse()
	for i in idx:
		Inventory.remove_food_at(int(i))
	pot = []
	if d.has("max_hp"):
		for a in CurrentStatus.allies:
			a["max_hp"] = int(a.max_hp) + int(d.max_hp)
			a["hp"] = int(a.hp) + int(d.max_hp)
	heal_pct(int(d.get("heal_pct", 0)))
	var nx: Dictionary = d.get("next", {})
	for k in nx:
		CurrentStatus.next_battle[k] = int(CurrentStatus.next_battle.get(k, 0)) + int(nx[k])
	var msg := "%sを食べた！ %s" % [d.name, d.desc]
	if d.has("item"):
		if Inventory.add_item(str(d.item)):
			msg = "%sを食べた！ %sを手に入れた" % [d.name, Item_List.DATA[d.item].name]
		else:
			msg = "%sを食べた！（%sは持ちきれない）" % [d.name, Item_List.DATA[d.item].name]
	_finish(msg)
	return id


## 全員の HP を最大 HP の pct% 回復（上限は最大 HP）
func heal_pct(pct: int) -> void:
	if pct <= 0:
		return
	for a in CurrentStatus.allies:
		var v := maxi(1, int(int(a.max_hp) * pct / 100.0))
		a["hp"] = mini(int(a.max_hp), maxi(1, int(a.hp)) + v)


func nap() -> void:
	if done:
		return
	pot = []
	heal_pct(NAP_PCT)
	_finish("ぐっすり眠った（全員HP%d%%回復）" % NAP_PCT)


func _finish(msg: String) -> void:
	done = true
	SaveData.save("map")  # 食べた・眠った時点で保存（再読み込みしたらマップへ）
	_refresh()
	pad.locked = true
	UiSystem.toast(ui, msg, 560, ImageController.COL.good)
	await get_tree().create_timer(1.6).timeout
	if is_inside_tree():
		UiSystem.goto("map")


func _on_chosen(key) -> void:
	if key is int and FOOD_KEYS.has(key):
		add_to_pot(FOOD_KEYS[key])
		return
	match key:
		5, "ok": cook()
		2: nap()
		"deck":
			pad.locked = true
			GuiDeckView.open(ui, "デッキ").closed.connect(func(): pad.locked = done)
		"status":
			pad.locked = true
			GuiStatusView.open(ui, CurrentStatus.allies).closed.connect(func(): pad.locked = done)


# ============================================================
# 表示
# ============================================================

func _refresh() -> void:
	var col: Dictionary = ImageController.COL
	var full := pot.size() >= FoodList.PICK_MAX
	for k in FOOD_KEYS:
		var fid: String = FOOD_KEYS[k]
		var f: Dictionary = FoodList.DATA[fid]
		var rest := remaining(fid)
		var gs: Array = rest.map(func(i): return "G%d" % int(Inventory.foods[i].grade))
		var msg := ""
		if done:
			msg = "もう休憩した"
		elif rest.is_empty():
			msg = "%sが無い" % f.name
		elif full:
			msg = "鍋がいっぱい（%dつまで）" % FoodList.PICK_MAX
		pad.set_cell(k, {"title": f.name, "icon": f.icon, "accent": f.col, "sub": "残り%d" % rest.size(),
				"desc": "[i:%s]%s を 1 つ鍋へ入れる（グレードの高い物から）\n持っている：%s\n手に入れ方：%s" % [f.icon, f.name, "・".join(gs) if not gs.is_empty() else "なし", f.how],
				"short": "%sを鍋へ（残り %s）" % [f.name, "・".join(gs) if not gs.is_empty() else "なし"],
				"enabled": msg == "", "block_msg": msg})
	var did := dish_id()
	var cook_msg := "もう休憩した" if done else ("鍋に食材を入れてください" if pot.is_empty() else "")
	var cook_desc := "鍋の食材で料理して食べる"
	if did != "":
		var d: Dictionary = FoodList.DISHES[did]
		cook_desc = "%s（合計グレード %d）\n%s" % [d.name, FoodList.grade_sum(picked(), bonus()), d.desc]
	var cook_info := {"title": "料理する", "icon": "camp", "accent": col.red, "sub": FoodList.DISHES[did].name if did != "" else "",
			"desc": cook_desc, "enabled": cook_msg == "", "block_msg": cook_msg}
	pad.set_cell(5, cook_info)
	var ok_info := cook_info.duplicate()
	ok_info["icon"] = "enter"
	pad.set_cell("ok", ok_info)
	pad.set_cell(2, {"title": "仮眠", "icon": "rest", "accent": ImageController.GLASS.sacred_sky, "sub": "HP%d%%" % NAP_PCT,
			"desc": "料理をせずに眠る。全員のHPを最大HPの%d%%回復" % NAP_PCT,
			"enabled": not done, "block_msg": "もう休憩した"})
	pad.header_right = "鍋 %d/%d　合計G%d" % [pot.size(), FoodList.PICK_MAX, FoodList.grade_sum(picked(), bonus())] if not pot.is_empty() else "鍋は空"
	pad.queue_redraw()
	view.queue_redraw()


## 上の表示：体力（2 人）・鍋（中身 3 枠）・合計グレード・できる料理と効果
func _draw_view() -> void:
	var IC = ImageController
	var col: Dictionary = IC.COL
	# 体力
	var hp_r := Rect2(30, 156, 660, 70)
	IC.slant(view, hp_r, IC.GLASS.angel_white, 16, 3.0, col.ink, col.red, Vector2(6, 6))  # 文字の箱はエンジェルホワイト
	var x := 70.0
	for a in CurrentStatus.allies:
		IC.slant(view, Rect2(x - 20, 172, 110, 36), col.get(a.id, col.ink), 10, 2.0, col.ink)
		IC.head(view, a.name, Vector2(x + 35, 190), 20, col.paper, 96)
		var hpc: Color = col.ink if int(a.hp) > 0 else col.red
		IC.head(view, "HP %d/%d" % [a.hp, a.max_hp], Vector2(x + 190, 190), 26, hpc, 180)
		x += 320
	# 鍋（たき火の上の黒い鍋）
	var pc := POT_POS
	IC.glow(view, pc + Vector2(0, 90), 90, Color(1.0, 0.45, 0.1, 0.35 + 0.1 * sin(_t * 5.0)), 6)
	view.draw_colored_polygon(IC.ell(pc + Vector2(0, 30), 150, 72, 32), Color(0, 0, 0, 0.6))
	IC.poly_box(view, IC.ell(pc + Vector2(0, 20), 140, 64, 32), col.steel, 4.0, col.paper, col.red, Vector2(6, 6))
	view.draw_colored_polygon(IC.ell(pc + Vector2(0, -6), 124, 34, 28), IC.GLASS.ivory_black)
	if not pot.is_empty():
		var g := FoodList.grade_sum(picked(), bonus())
		var steam := Color(1, 1, 1, 0.25)
		for i in 3:
			var sx := pc.x - 50 + i * 50
			var ph := _t * 2.0 + i
			view.draw_polyline(PackedVector2Array([Vector2(sx, pc.y - 20), Vector2(sx + 8 * sin(ph), pc.y - 50), Vector2(sx - 6 * sin(ph), pc.y - 80)]), steam, 5, true)
		view.draw_colored_polygon(IC.ell(pc + Vector2(0, -6), 110, 26, 24), Color(1.0, 0.6, 0.2, 0.25 + 0.05 * g))
	# 合計グレード
	var gs := Rect2(pc.x - 110, pc.y + 2, 220, 36)
	IC.slant(view, gs, col.paper, 10, 2.0, col.ink, col.red, Vector2(4, 4))
	var gtxt := "合計グレード %d" % FoodList.grade_sum(picked(), bonus())
	if bonus() > 0:
		gtxt += "（鍋+1）"
	IC.head(view, gtxt, gs.get_center(), 20, col.ink, 200)
	# 鍋の食材 3 枠（タップで戻す）
	for i in FoodList.PICK_MAX:
		var p: Vector2 = POT_SLOT[i]
		if i < pot.size():
			var f: Dictionary = Inventory.foods[pot[i]]
			IC.poly_box(view, IC.burst_pts(p, 46, 36, 12, i), col.red, 3.0, col.ink)
			IC.icon(view, FoodList.DATA[f.id].icon, p + Vector2(0, -4), 52)
			IC.text(view, "G%d" % int(f.grade), p + Vector2(22, 26), 18, col.paper, true, 4, -1.0, col.ink)
		else:
			var poly := IC.ell(p, 38, 38, 20)
			for j in poly.size():
				view.draw_dashed_line(poly[j], poly[(j + 1) % poly.size()], Color(1, 1, 1, 0.35), 2.0, 6.0)
			IC.text(view, "空き", p, 16, Color(1, 1, 1, 0.5), true)
	if not pot.is_empty():
		IC.text(view, "タップで戻す", Vector2(600, 470), 16, col.sub, true)
	# できる料理と効果
	var dr := Rect2(30, 528, 660, 104)
	IC.slant(view, dr, IC.GLASS.angel_white, 16, 3.0, col.ink, col.red, Vector2(6, 6))
	var did := dish_id()
	if did == "":
		IC.text(view, "食材を鍋に入れると、できる料理が出る", dr.get_center(), 22, IC.GLASS.sacred_blue, true, 0, 620)
	else:
		var d: Dictionary = FoodList.DISHES[did]
		IC.head(view, d.name, Vector2(dr.get_center().x, dr.position.y + 30), 28, col.red, 600)
		IC.text(view, d.desc, Vector2(dr.get_center().x, dr.position.y + 74), 19, col.ink, true, 0, 620)
