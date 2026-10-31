extends Control
class_name GuiBackground
## 背景（洞窟・キャンプ・タイトル・マップ）をコードで描く。

var kind := "cave"
var _t := 0.0


func _init(k: String = "cave", rect: Rect2 = Rect2(0, 0, 720, 1280)) -> void:
	kind = k
	position = rect.position
	size = rect.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	ImageController.background(self, kind, Rect2(Vector2.ZERO, size), _t)
