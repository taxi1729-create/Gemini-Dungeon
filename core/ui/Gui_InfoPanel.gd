extends Control
class_name GuiInfoPanel
## 戦場のキャラをタップした時に出る情報の吹き出し。画面のどこかをタップすると閉じる（Cont_Battle 側で処理）
## 白いギザギザの漫画風吹き出し（黒縁・赤のベタ影）で、しっぽがキャラの方を向く。

const FS := 18  # 本文の文字サイズ
const LINE_H := 27.0  # 本文の行の高さ
const PAD_X := 22.0  # 左右の余白
const TOP := 46.0  # 本文の開始位置（見出しタグの下）

var title := ""
var lines: Array = []
var is_enemy := false
var tail_to := Vector2(-9999, -9999)  # しっぽの向く先（親の座標）。未設定ならしっぽ無し
var _wrapped: Array = []


func setup(t: String, l: Array, rect: Rect2, enemy: bool) -> void:
	title = t
	lines = l
	is_enemy = enemy
	position = rect.position
	size = rect.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wrapped = wrap_lines(lines, size.x - PAD_X * 2)


## 幅 w に収まるように 1 文字ずつ折り返した行の配列を返す（日本語は空白が無いので文字単位）
static func wrap_lines(src: Array, w: float) -> Array:
	var f: Font = ImageController.font_bold
	var out: Array = []
	for s in src:
		var cur := ""
		for ch in str(s):
			if cur != "" and f.get_string_size(cur + ch, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x > w:
				out.append(cur)
				cur = "　" + ch  # 折り返した行は字下げして続きだと分かるようにする
			else:
				cur += ch
		out.append(cur)
	return out


## 本文 src を幅 w の吹き出しに入れた時の高さ
static func measure(src: Array, w: float) -> float:
	return TOP + wrap_lines(src, w - PAD_X * 2).size() * LINE_H + 18.0


func _draw() -> void:
	var IC = ImageController
	var r := Rect2(Vector2.ZERO, size)
	var local_tail := tail_to - position if tail_to.x > -9000 else tail_to
	IC.bubble(self, r, local_tail, 3)
	# 見出し：吹き出しの上辺にかぶせた斜めのタグ（敵＝赤、味方＝黒）
	var tf: Font = IC.font_head
	var tw := minf(tf.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 56, size.x - 30)
	var tag := Rect2(14, -16, tw, 42)
	IC.slant(self, tag, IC.COL.red if is_enemy else IC.COL.ink, 14, 3.0, IC.COL.ink if is_enemy else IC.COL.paper,
			IC.COL.ink if is_enemy else IC.COL.red, Vector2(4, 4))
	IC.head(self, title, tag.get_center(), 24, IC.COL.paper, tw - 34)
	var f: Font = IC.font_bold
	for i in _wrapped.size():
		var y := TOP + i * LINE_H + LINE_H * 0.5
		draw_string(f, Vector2(PAD_X, y + FS * 0.36), _wrapped[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FS, IC.COL.ink)
		if i < _wrapped.size() - 1 and not str(_wrapped[i + 1]).begins_with("　"):
			draw_line(Vector2(PAD_X, y + LINE_H * 0.5), Vector2(size.x - PAD_X, y + LINE_H * 0.5), Color(0, 0, 0, 0.12), 1)


## 互換用：左寄せの 1 行
func ci_text_left(s: String, p: Vector2, fs: int) -> void:
	draw_string(ImageController.font_bold, p + Vector2(0, fs * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, size.x - 30, fs, ImageController.COL.ink)
