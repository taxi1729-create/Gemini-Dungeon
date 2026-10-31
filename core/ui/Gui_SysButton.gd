extends GuiPad
class_name GuiSysButton
## 操作エリアのボタン（入替・保留・アイテム・固有スキル・中央の必殺・右列キー）。
## shape = "circle"（3×3 の中）/ "key"（右列のキー）

var title := ""
var icon_kind := "star"
var accent := Color("e8c26a")
var description := ""
var label_hint := ""
var shape := "circle"
var ap_cost := -1
var subtitle := ""
var charge := 0.0:  # 中央長押しの溜め（0〜1）
	set(v):
		charge = v
		queue_redraw()
var dimmed := false:
	set(v):
		dimmed = v
		queue_redraw()


func setup(t: String, ik: String, acc: Color, desc: String, hint: String, sz: Vector2 = Vector2(116, 116), shp: String = "circle") -> void:
	title = t
	icon_kind = ik
	accent = acc
	description = desc
	label_hint = hint
	shape = shp
	size = sz
	interactive = false  # 入力は戦闘シーンのジェスチャー処理でまとめて扱う
	queue_redraw()


func _process(delta: float) -> void:
	super(delta)
	if (icon_kind == "burst" and not dimmed) or charge > 0:
		queue_redraw()


func _draw() -> void:
	var IC = ImageController
	var fg: Color = IC.COL.text if not dimmed else Color("5c6274")
	var ac: Color = accent if not dimmed else Color("4a4f60")
	if shape == "key":
		var r := Rect2(Vector2.ZERO, size)
		if highlighted:
			IC.round_rect(self, r.grow(5), Color(IC.COL.gold, 0.5), 18)
		IC.round_rect(self, r, IC.COL.panel_hi if not dimmed else Color("1a1d28"), 16, 3, ac)
		IC.icon(self, icon_kind, Vector2(size.x / 2, size.y / 2 - 16), 48, ac)
		IC.text(self, title, Vector2(size.x / 2, size.y / 2 + 30), 20, fg, true, 4, size.x - 10)
		return
	var c := size / 2.0
	var rad := size.x / 2.0 - 4
	if highlighted:
		draw_circle(c, rad + 8, Color(IC.COL.gold, 0.5))
	draw_circle(c, rad, IC.COL.panel_hi if not dimmed else Color("1a1d28"))
	var ring := ac
	if icon_kind == "burst" and not dimmed:
		ring = accent.lerp(Color.WHITE, 0.3 + 0.3 * sin(_t * 4.0))
	draw_arc(c, rad, 0, TAU, 40, ring, 4, true)
	if charge > 0:
		var full := charge >= 1.0
		var col: Color = Color.WHITE if full and int(_t * 12) % 2 == 0 else IC.COL.gold
		draw_arc(c, rad + 7, -PI / 2, -PI / 2 + TAU * minf(charge, 1.0), 48, col, 9, true)
	IC.icon(self, icon_kind, c + Vector2(0, -14), 46, ac)
	IC.text(self, title, c + Vector2(0, 24), 18, fg, true, 4, size.x - 14)
	if subtitle != "":
		IC.text(self, subtitle, c + Vector2(0, 44), 13, Color(fg, 0.75), false, 3, size.x - 10)
	if ap_cost >= 0:
		var p := Vector2(size.x - 18, 18)
		IC.icon(self, "ap", p, 34, IC.COL.ap if not dimmed else Color("7a3a3a"))
		IC.text(self, str(ap_cost), p + Vector2(0, 1), 17, Color.WHITE, true, 4)
	if label_hint != "":
		IC.text(self, label_hint, Vector2(16, 16), 14, Color(1, 1, 1, 0.5), true)
