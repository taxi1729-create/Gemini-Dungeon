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
	UiSystem.make_banner(ui, "休憩所", Rect2(40, 30, 300, 76), 48)
	UiSystem.make_banner(ui, "料理を1品作るか、仮眠をとろう", Rect2(260, 108, 420, 42), 21, col.paper, col.ink, 14)
	# 体力と食材は黒い斜めパネルに
	var back := Control.new()
	back.position = Vector2(40, 170)
	back.size = Vector2(640, 116)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.draw.connect(func(): ImageController.slant(back, Rect2(Vector2.ZERO, back.size), Color(col.ink, 0.88), 18, 3.0, col.paper, col.red, Vector2(7, 7)))
	ui.add_child(back)
	status_label = UiSystem.make_label(ui, "", Vector2(60, 172), Vector2(600, 112), 23, col.text, HORIZONTAL_ALIGNMENT_CENTER, 0)
	status_label.add_theme_font_override("font", ImageController.font_bold)
	var panel := UiSystem.make_panel(ui, Rect2(20, 640, 680, 620))
	UiSystem.make_banner(ui, "料理", Rect2(36, 614, 160, 44), 26)
	var y := 14.0
	for r in FoodList.RECIPES:
		var b := UiSystem.make_button(panel, "", Vector2(24, y + 22), Vector2(632, 76), _cook.bind(r), 22)
		b.set_meta("recipe", r)
		var lbl := UiSystem.make_label(b, "%s\n%s" % [r.name, r.desc], Vector2(148, 0), Vector2(468, 76), 20, col.text, HORIZONTAL_ALIGNMENT_LEFT, 0)
		lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lbl.add_theme_font_override("font", ImageController.font_bold)
		for i in 2:
			var ic := GuiWidget.new("icon", Rect2(22 + i * 60, 10, 56, 56))
			ic.icon_kind = FoodList.DATA[r.use[i]].icon
			b.add_child(ic)
		buttons.append(b)
		y += 84
	var nap := UiSystem.make_red_button(panel, "仮眠をとる（全員HP+6）", Vector2(24, y + 28), Vector2(632, 70), _nap, 24)
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
			b.modulate.a = 0.45 if b.disabled else 1.0  # 作れない料理は薄く
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
	SaveData.save("map")  # 食べた・眠った時点で保存（再読み込みしたらマップへ）
	_refresh()
	UiSystem.toast(ui, msg, 520, ImageController.COL.good)
	await get_tree().create_timer(1.4).timeout
	UiSystem.goto("map")
