extends Control
class_name GuiDescBubble
## 説明用の吹き出し（アイコン入りの文字）。白いギザギザ吹き出しに黒文字・赤のベタ影。
## しっぽは anchor（ui 座標）を指す。幅は最大 660、高さは中身に合わせる。画面からはみ出さないよう位置を調整する。
## 戦闘では操作エリアの上（下端 y < 760）に出す。親は ui の原点に置いた Control を想定。

const MAX_W := 660.0
const MIN_W := 300.0
const FS := 22  # 本文の文字サイズ
const LINE_H := 33.0  # 本文の行の高さ
const PAD_X := 24.0  # 左右の余白
const PAD_TOP := 36.0  # 本文の開始位置（見出しタグの下）
const PAD_BOTTOM := 18.0
const SCREEN := Vector2(720, 1280)
const BOTTOM_LIMIT := 750.0  # 吹き出しの下端の上限（操作エリアにかぶせない）
const GAP := 70.0  # anchor と吹き出しの間（しっぽの長さ）

var title := ""
var body := ""
var anchor := Vector2(-9999, -9999)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 60
	visible = false


## 見出し title・本文 body（"[i:..]" 入り可）を出し、しっぽを anchor へ向ける
func show_text(t: String, b: String, a: Vector2) -> void:
	title = t
	body = b
	anchor = a
	var IC = ImageController
	# 幅：本文の一番長い行と見出しに合わせる（最大 MAX_W）
	var tw: float = IC.font_head.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 80.0
	var bw: float = IC.rich_width(body, FS) + PAD_X * 2 + 4.0
	var w := clampf(maxf(tw, bw), MIN_W, MAX_W)
	var h: float = (PAD_TOP if title != "" else 14.0) + IC.rich_height(body, FS, w - PAD_X * 2, LINE_H) + PAD_BOTTOM
	# 横：anchor を中心に、画面内に収める
	var x := clampf(a.x - w / 2.0, 14.0, SCREEN.x - 14.0 - w - 8.0)
	# 縦：anchor の上（下端は BOTTOM_LIMIT まで）。上に入らない時は anchor の下
	var bottom := minf(a.y - GAP, BOTTOM_LIMIT)
	var y := bottom - h
	if y < 24.0:
		y = a.y + GAP
		if y + h > SCREEN.y - 14.0:
			y = maxf(24.0, SCREEN.y - 14.0 - h)
	position = Vector2(x, y)
	size = Vector2(w, h)
	visible = true
	queue_redraw()


func hide_bubble() -> void:
	visible = false


func _draw() -> void:
	var IC = ImageController
	var r := Rect2(Vector2.ZERO, size)
	var local_tail := anchor - position if anchor.x > -9000 else anchor
	IC.bubble(self, r, local_tail, 5)
	var top := 14.0
	if title != "":
		# 見出し：上辺にかぶせた黒い斜めタグ
		var tf: Font = IC.font_head
		var tw := minf(tf.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 56, size.x - 30)
		var tag := Rect2(14, -16, tw, 42)
		IC.slant(self, tag, IC.COL.ink, 14, 3.0, IC.COL.paper, IC.COL.red, Vector2(4, 4))
		IC.head(self, title, tag.get_center(), 24, IC.COL.paper, tw - 34)
		top = PAD_TOP
	IC.rich_text(self, body, Vector2(PAD_X, top), FS, IC.COL.ink, size.x - PAD_X * 2, 0, LINE_H)
