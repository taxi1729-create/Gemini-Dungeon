extends Control
class_name GuiBackground
## 背景（洞窟・キャンプ・タイトル・マップ）をコードで描く。
## 11回目（軽くする）：動かない部分（壁・窓・床・模様・光のにじみ）は最初に一度だけ SubViewport で絵（テクスチャ）に焼き、
## 毎回はその絵を 1 枚貼るだけにする。動く部分（松明・粒・窓の明るさの揺れ・暖炉の火）だけを
## ImageController.anim_tick の間隔（ANIM_HZ）で描き直す。焼いた絵は画面の拡大率（スマホの高解像度）に合わせた大きさ。
## ライトモード（ImageController.light_mode）の時は動かさず、切り替わった時に焼き直して 1 回だけ描き直す。
## paused = true の間も描き直さない（上を一覧などで覆っている時）。

## 動く部分の描き直しの回数/秒（ゆっくりまたたく粒・松明は少なく、暖炉の火は多め）。
## 回数は ImageController.ANIM_HZ（15）かその半分にそろえる（全部品が同じ時計なので、描き直すフレームが重なって画面の描画回数が増えない）
const ANIM_HZ := {"map": 7.5, "camp": 15.0}
const ANIM_HZ_DEFAULT := 7.5  # 洞窟・タイトル（松明のゆらぎ）
const MAX_BAKE_SCALE := 2.0  # 焼く絵の拡大率の上限（メモリを使いすぎない）

var kind := "cave"
var paused := false
var _t := 0.0
var _was_light := false
var _vp: SubViewport  # 動かない部分を焼く先
var _painter: Control
var _baked := false  # 焼き終わったか（終わるまでは直接描く）


func _init(k: String = "cave", rect: Rect2 = Rect2(0, 0, 720, 1280)) -> void:
	kind = k
	position = rect.position
	size = rect.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_was_light = ImageController.light_mode
	_vp = SubViewport.new()
	_vp.disable_3d = true
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_painter = Control.new()
	_painter.size = size
	_painter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painter.draw.connect(func(): ImageController.background_layer(_painter, kind, Rect2(Vector2.ZERO, size), 0.0, ImageController.BG_STATIC))
	_vp.add_child(_painter)
	add_child(_vp)
	_bake()


## 動かない部分を焼き直す（最初・ライトモードの切り替え時）
func _bake() -> void:
	var s := 1.0
	if is_inside_tree():
		s = clampf(get_tree().root.get_final_transform().get_scale().x, 1.0, MAX_BAKE_SCALE)
	_vp.size = Vector2i(ceili(size.x * s), ceili(size.y * s))
	_vp.canvas_transform = Transform2D().scaled(Vector2(s, s))
	_baked = false
	_painter.queue_redraw()
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	queue_redraw()
	await RenderingServer.frame_post_draw
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_baked = true
	queue_redraw()


func _process(delta: float) -> void:
	var light: bool = ImageController.light_mode
	if light != _was_light:
		_was_light = light
		_bake()
	if light or paused:
		return
	_t += delta
	if ImageController.anim_tick(float(ANIM_HZ.get(kind, ANIM_HZ_DEFAULT))):
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if _baked:
		draw_texture_rect(_vp.get_texture(), r, false)
	else:
		ImageController.background_layer(self, kind, r, _t, ImageController.BG_STATIC)
	ImageController.background_layer(self, kind, r, _t, ImageController.BG_ANIM)
