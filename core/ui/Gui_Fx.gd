extends Node2D
class_name GuiFx
## 一瞬だけ出る演出（斬撃・爆発・光）。描き終わると自動で消える。

var kind := "slash"
var col := Color.WHITE
var dur := 0.35
var _t := 0.0
var _flip := 1.0


static func spawn(parent: Node, k: String, pos: Vector2, c: Color = Color.WHITE, d: float = 0.35) -> GuiFx:
	var fx := GuiFx.new()
	fx.kind = k
	fx.col = c
	fx.dur = d
	fx.position = pos
	fx.z_index = 900
	fx._flip = 1.0 if randf() < 0.5 else -1.0
	parent.add_child(fx)
	return fx


func _process(delta: float) -> void:
	_t += delta
	if _t >= dur:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / dur
	var a := 1.0 - k
	match kind:
		"slash":
			var start := -2.4
			var sweep := 2.2 * minf(1.0, k * 2.5)
			draw_set_transform(Vector2.ZERO, 0, Vector2(_flip, 1))
			draw_arc(Vector2.ZERO, 54, start, start + sweep, 20, Color(col, a), 9, true)
			draw_arc(Vector2.ZERO, 46, start, start + sweep, 20, Color(1, 1, 1, a), 3, true)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		"burst":
			var r := 20 + 60 * k
			draw_colored_polygon(ImageController.star_pts(Vector2.ZERO, r, r * 0.45, 8, k * 2), Color(col, a * 0.8))
			draw_circle(Vector2.ZERO, r * 0.4, Color(1, 1, 1, a * 0.7))
		"glow":
			ImageController.glow(self, Vector2.ZERO, 50 + 30 * k, Color(col, a), 6)
		"rise":
			for i in 6:
				var x := -40 + i * 16
				var y := -k * 90 - (i % 3) * 14
				draw_circle(Vector2(x, y), 4, Color(col, a))
