extends Node2D
## 休憩所：料理を 1 品作って食べる、または仮眠（battle-spec.md「食材と料理」）

var ui: CanvasLayer
var status_label: Label
var buttons: Array = []
var done := false


func _ready() -> void:
	CurrentStatus.ensure_started()
	add_child(GuiBackground.new("camp"))
	ui = CanvasLayer.new()
	add_child(ui)
	var col: Dictionary = ImageController.COL
	UiSystem.make_label(ui, "休憩所", Vector2(0, 40), Vector2(720, 70), 48, col.gold)
	UiSystem.make_label(ui, "料理を1品作るか、仮眠をとろう", Vector2(0, 108), Vector2(720, 40), 22, col.sub)
	status_label = UiSystem.make_label(ui, "", Vector2(40, 150), Vector2(640, 110), 24, col.text)
	var panel := UiSystem.make_panel(ui, Rect2(20, 640, 680, 620))
	var y := 14.0
	for r in FoodList.RECIPES:
		var b := UiSystem.make_button(panel, "", Vector2(14, y), Vector2(652, 80), _cook.bind(r), 22)
		b.set_meta("recipe", r)
		var lbl := UiSystem.make_label(b, "%s　%s" % [r.name, r.desc], Vector2(150, 0), Vector2(490, 80), 21, col.text, HORIZONTAL_ALIGNMENT_LEFT, 0)
		lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		for i in 2:
			var ic := GuiWidget.new("icon", Rect2(14 + i * 62, 12, 56, 56))
			ic.icon_kind = FoodList.DATA[r.use[i]].icon
			b.add_child(ic)
		buttons.append(b)
		y += 88
	var nap := UiSystem.make_button(panel, "仮眠をとる（全員HP+6）", Vector2(14, y + 4), Vector2(652, 72), _nap, 24)
	buttons.append(nap)
	_refresh()


func _refresh() -> void:
	var lines: Array = []
	for a in CurrentStatus.allies:
		lines.append("%s　HP %d / %d" % [a.name, a.hp, a.max_hp])
	lines.append("食材　" + Inventory.foods_text())
	status_label.text = "\n".join(lines)
	for b in buttons:
		if b.has_meta("recipe"):
			b.disabled = done or not Inventory.can_cook(b.get_meta("recipe"))
		else:
			b.disabled = done


func _cook(r: Dictionary) -> void:
	if done or not Inventory.can_cook(r):
		return
	Inventory.consume(r)
	match r.kind:
		"heal": CurrentStatus.heal_all(int(r.val))
		"max_hp":
			for a in CurrentStatus.allies:
				a["max_hp"] = int(a.max_hp) + int(r.val)
				a["hp"] = mini(int(a.max_hp), maxi(1, int(a.hp)) + int(r.val))
		_:
			CurrentStatus.next_battle[r.kind] = int(CurrentStatus.next_battle.get(r.kind, 0)) + int(r.val)
	_finish("%sを食べた！ %s" % [r.name, r.desc])


func _nap() -> void:
	if done:
		return
	CurrentStatus.heal_all(6)
	_finish("ぐっすり眠った（全員HP+6）")


func _finish(msg: String) -> void:
	done = true
	_refresh()
	UiSystem.toast(ui, msg, 520, ImageController.COL.good)
	await get_tree().create_timer(1.4).timeout
	UiSystem.goto("map")
