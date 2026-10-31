extends Control
class_name GuiWidget
## 小物の表示部品をまとめたもの。mode で描く内容を切り替える。
##   "order" : 行動順バー（data = ユニット辞書の配列、index = 手番の位置）
##   "pile"  : 山札／捨て札（count = 枚数、caption = 見出し）
##   "hub"   : フリック方向の案内（num = 現在の方向）
##   "icon"  : アイコン1つ（icon_kind）

var mode := "icon"
var units: Array = []
var index := 0
var count := 0
var caption := ""
var num := 5
var icon_kind := "star"
var icon_col := Color(0, 0, 0, 0)
var _t := 0.0


func _init(m: String = "icon", rect: Rect2 = Rect2()) -> void:
	mode = m
	position = rect.position
	size = rect.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	if mode == "order" or mode == "hub":
		queue_redraw()


func _draw() -> void:
	match mode:
		"order": _draw_order()
		"pile": _draw_pile()
		"hub": _draw_hub()
		"icon": ImageController.icon(self, icon_kind, size / 2, minf(size.x, size.y), icon_col)


func _draw_order() -> void:
	var IC = ImageController
	IC.round_rect(self, Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45), 14)
	IC.text(self, "行動順", Vector2(44, size.y / 2), 18, IC.COL.sub, true)
	var x := 96.0
	for i in units.size():
		var u: Dictionary = units[i]
		var is_cur := i == index
		var w := 64.0 if is_cur else 52.0
		var r := Rect2(x, (size.y - w) / 2, w, w)
		var side_col: Color = Color("2f55a8") if u.get("side") == "ally" else Color("8a2f3a")
		var alive: bool = u.hp > 0
		IC.round_rect(self, r, side_col.darkened(0.3) if alive else Color("222"), 10, 3 if is_cur else 2,
				IC.COL.gold if is_cur else side_col)
		var sc: float = 0.36 * w / 64.0 / float(u.get("art_scale", 1.0))
		var face := 1.0 if u.get("side") == "ally" else -1.0
		IC.character(self, u.get("art", "knight"), r.position + Vector2(w / 2, w - 6), sc * float(u.get("art_scale", 1.0)), face, _t)
		if not alive:
			draw_line(r.position + Vector2(8, 8), r.end - Vector2(8, 8), IC.COL.bad, 4)
		x += w + 8


func _draw_pile() -> void:
	var IC = ImageController
	var card := Rect2(10, 10, size.x - 20, size.y - 44)
	if count > 0:
		for i in mini(count, 3):
			IC.card_back(self, Rect2(card.position + Vector2(i * 3, -i * 3), card.size))
	else:
		IC.round_rect(self, card, Color(0, 0, 0, 0.3), 10, 2, Color(1, 1, 1, 0.2))
	IC.text(self, "%s %d" % [caption, count], Vector2(size.x / 2, size.y - 16), 16, IC.COL.text, true, 4)


func _draw_hub() -> void:
	var IC = ImageController
	var c := size / 2
	draw_circle(c, 62, Color(0, 0, 0, 0.35))
	draw_arc(c, 62, 0, TAU, 40, Color(1, 1, 1, 0.15), 2, true)
	var dirs := {8: Vector2(0, -1), 2: Vector2(0, 1), 4: Vector2(-1, 0), 6: Vector2(1, 0),
			7: Vector2(-1, -1).normalized(), 9: Vector2(1, -1).normalized(), 1: Vector2(-1, 1).normalized(), 3: Vector2(1, 1).normalized()}
	for k in dirs:
		var d: Vector2 = dirs[k]
		var on: bool = k == num
		var p: Vector2 = c + d * 44
		var col: Color = IC.COL.gold if on else Color(1, 1, 1, 0.25)
		var n := d.orthogonal()
		draw_colored_polygon(PackedVector2Array([p + d * 10, p - d * 4 + n * 8, p - d * 4 - n * 8]), col)
	draw_circle(c, 14, Color(1, 1, 1, 0.15 + 0.1 * sin(_t * 3.0)))
	IC.text(self, "フリック", c + Vector2(0, 0), 13, Color(1, 1, 1, 0.55), true)
