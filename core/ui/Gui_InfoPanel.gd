extends Control
class_name GuiInfoPanel
## 戦場のキャラをタップした時に出る情報の吹き出し。画面のどこかをタップすると閉じる（Cont_Battle 側で処理）

var title := ""
var lines: Array = []
var is_enemy := false


func setup(t: String, l: Array, rect: Rect2, enemy: bool) -> void:
	title = t
	lines = l
	is_enemy = enemy
	position = rect.position
	size = rect.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var IC = ImageController
	var r := Rect2(Vector2.ZERO, size)
	IC.round_rect(self, r, Color(0.05, 0.05, 0.07, 0.94), 6, 3, IC.COL.accent if is_enemy else IC.COL.knight)
	IC.text(self, title, Vector2(size.x / 2, 26), 24, IC.COL.text, true, 0, size.x - 20)
	for i in lines.size():
		var y := 58.0 + i * 30.0
		ci_text_left(lines[i], Vector2(18, y), 18)


func ci_text_left(s: String, p: Vector2, fs: int) -> void:
	var f: Font = ImageController.font
	draw_string(f, p + Vector2(0, fs * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, size.x - 30, fs, ImageController.COL.text)
