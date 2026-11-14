extends Control
class_name GuiBaked
## 11回目（軽くする）：動かない絵を一度だけ SubViewport で絵（テクスチャ）に焼き、毎回はその 1 枚を貼るだけにする部品。
## 網点・水玉・斜線など図形の多い下地に使う（スマホは画面を描くたびに全部の図形を描き直すので、1 枚にまとめると軽い）。
## painter：func(ci: CanvasItem, size: Vector2) で ci に描く関数。範囲全体を塗りつぶす（不透明な）絵だけに使う。
## 焼いた絵は画面の拡大率（スマホの高解像度）に合わせた大きさ。焼き終わるまでの最初のフレームは直接描く。

const MAX_BAKE_SCALE := 2.0  # 焼く絵の拡大率の上限（メモリを使いすぎない）

var painter: Callable
var _vp: SubViewport
var _inner: Control
var _baked := false


func _init(rect: Rect2 = Rect2(), p: Callable = Callable()) -> void:
	position = rect.position
	size = rect.size
	painter = p
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.disable_3d = true
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_inner = Control.new()
	_inner.size = size
	_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.draw.connect(func(): if painter.is_valid(): painter.call(_inner, size))
	_vp.add_child(_inner)
	add_child(_vp)
	rebake()


## 焼き直す（描く中身が変わった時）
func rebake() -> void:
	if _vp == null:
		return
	var s := clampf(get_tree().root.get_final_transform().get_scale().x, 1.0, MAX_BAKE_SCALE)
	_vp.size = Vector2i(ceili(size.x * s), ceili(size.y * s))
	_vp.canvas_transform = Transform2D().scaled(Vector2(s, s))
	_baked = false
	_inner.queue_redraw()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	queue_redraw()
	await RenderingServer.frame_post_draw
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_baked = true
	queue_redraw()


func _draw() -> void:
	if _baked:
		draw_texture_rect(_vp.get_texture(), Rect2(Vector2.ZERO, size), false)
	elif painter.is_valid():
		painter.call(self, size)
