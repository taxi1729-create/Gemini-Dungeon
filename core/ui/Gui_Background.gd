extends Control
class_name GuiBackground
## 背景（洞窟・キャンプ・タイトル・マップ）をコードで描く。
## ライトモード（ImageController.light_mode）の時は動かさず、切り替わった時に 1 回だけ描き直す。
## paused = true の間も描き直さない（上を一覧などで覆っている時）。

var kind := "cave"
var paused := false
var _t := 0.0
var _was_light := false


func _init(k: String = "cave", rect: Rect2 = Rect2(0, 0, 720, 1280)) -> void:
	kind = k
	position = rect.position
	size = rect.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var light: bool = ImageController.light_mode
	if light != _was_light:
		_was_light = light
		queue_redraw()
	if light or paused:
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	ImageController.background(self, kind, Rect2(Vector2.ZERO, size), _t)
