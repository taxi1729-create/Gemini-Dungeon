extends GuiPad
class_name GuiSysButton
## 戦闘画面の四隅のボタン（入替・必殺・道具・終了）。

var title := ""
var icon_kind := "star"
var accent := Color("e8c26a")
var description := ""
var label_hint := ""
var dimmed := false:
	set(v):
		dimmed = v
		queue_redraw()


func setup(t: String, ik: String, acc: Color, desc: String, hint: String) -> void:
	title = t
	icon_kind = ik
	accent = acc
	description = desc
	label_hint = hint
	size = Vector2(112, 112)
	queue_redraw()


func _process(delta: float) -> void:
	super(delta)
	if icon_kind == "burst" and not dimmed:
		queue_redraw()


func _draw() -> void:
	var IC = ImageController
	var c := size / 2.0
	var rad := size.x / 2.0 - 4
	if highlighted:
		draw_circle(c, rad + 8, Color(IC.COL.gold, 0.5))
	var base: Color = IC.COL.panel_hi if not dimmed else Color("1a1d28")
	draw_circle(c, rad, base)
	var ring := accent if not dimmed else Color("3a3f50")
	if icon_kind == "burst" and not dimmed:
		ring = accent.lerp(Color.WHITE, 0.3 + 0.3 * sin(_t * 4.0))
	draw_arc(c, rad, 0, TAU, 40, ring, 4, true)
	IC.icon(self, icon_kind, c + Vector2(0, -10), 50, accent if not dimmed else Color("4a4f60"))
	IC.text(self, title, c + Vector2(0, 30), 20, IC.COL.text if not dimmed else Color("5c6274"), true, 4)
	if label_hint != "":
		IC.text(self, label_hint, Vector2(size.x - 14, 14), 14, Color(1, 1, 1, 0.55), true)
