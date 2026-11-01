extends Control
class_name GuiInfoPanel
## 戦場のキャラをタップした時に出る情報の吹き出し。画面のどこかをタップすると閉じる（Cont_Battle 側で処理）
## 白いギザギザの漫画風吹き出し（黒縁・赤のベタ影）で、しっぽがキャラの方を向く。
## unit を入れておくと、本文の上にステータス（アイコン＋数字）と状態異常のアイコンを並べる。

const FS := 18  # 本文の文字サイズ
const LINE_H := 27.0  # 本文の行の高さ
const PAD_X := 22.0  # 左右の余白
const TOP := 46.0  # 本文の開始位置（見出しタグの下）
const STAT_FS := 20  # ステータスの数字の文字サイズ
const STAT_H := 40.0  # ステータスの行の高さ
const CHIP_FS := 16  # 状態異常の文字サイズ
const CHIP_H := 34.0  # 状態異常の行の高さ

var title := ""
var lines: Array = []
var is_enemy := false
var unit: Dictionary = {}  # 表示するキャラ（setup より前に入れる）。空ならアイコンの行は出さない
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


## 本文 lines を幅 w の吹き出しに入れた時の高さ。unit を渡すとステータスと状態異常のアイコンの行の分も足す
static func measure(lines: Array, w: float, unit: Dictionary = {}) -> float:
	return TOP + icon_rows_height(unit, w - PAD_X * 2) + wrap_lines(lines, w - PAD_X * 2).size() * LINE_H + 18.0


## アイコンの行（ステータス＋状態異常）の高さ。u が空なら 0
static func icon_rows_height(u: Dictionary, w: float) -> float:
	if u.is_empty():
		return 0.0
	var rows := status_layout(u, w, CHIP_FS, CHIP_H)
	var n := 0
	for c in rows:
		n = maxi(n, int(c.row) + 1)
	return STAT_H + n * CHIP_H + 8.0


# ============================================================
# ステータス・状態異常の描画（GuiStatusView からも使う）
# ============================================================

## ステータスの並び：[[アイコン名, 数字の文字列], ...]。ブロックは 1 以上の時だけ
static func stat_items(u: Dictionary) -> Array:
	var out: Array = [
		["stat_hp", "%d/%d" % [int(u.get("hp", 0)), int(u.get("max_hp", 0))]],
		["stat_atk", str(ActionController.get_atk(u))],
		["stat_def", str(ActionController.get_def(u))],
		["stat_spd", str(ActionController.get_spd(u))],
	]
	var sh := int(u.get("shield", 0))
	if sh > 0:
		out.append(["shield", str(sh)])
	return out


## ステータスを 1 行に並べて描く。p = 行の左端・縦の中心、w = 使える幅。入りきらない時は文字を縮める
static func draw_stats(ci: CanvasItem, u: Dictionary, p: Vector2, w: float, fs: int, ink: Color, paper: Color) -> void:
	var f: Font = ImageController.font_bold
	var items := stat_items(u)
	var fsz := fs
	var d := 0.0
	var gap := 0.0
	var total := 0.0
	while true:
		d = fsz * 1.45
		gap = fsz * 0.55
		total = 0.0
		for it in items:
			total += d + 4.0 + f.get_string_size(str(it[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x + gap
		total -= gap
		if total <= w or fsz <= 11:
			break
		fsz -= 1
	# 余った幅は項目の間に配る
	if items.size() > 1:
		gap += (w - total) / float(items.size() - 1) * 0.5
	var x := p.x
	for it in items:
		var c := Vector2(x + d / 2.0, p.y)
		ci.draw_circle(c, d / 2.0, ink)
		ci.draw_arc(c, d / 2.0 - 1.0, 0, TAU, 20, paper, 1.5, true)
		ImageController.icon(ci, str(it[0]), c, d * 0.7)
		var s := str(it[1])
		ci.draw_string(f, Vector2(x + d + 4.0, p.y + fsz * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, ink)
		x += d + 4.0 + f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x + gap


## 状態異常 1 つ分の表示文字（短い名前＋ StatusController.label の数字）
static func status_text(u: Dictionary, id: String) -> String:
	var st: Dictionary = StatusEffectList.DATA.get(id, {})
	var lb := str(StatusController.label(u, id))
	var nm := str(st.get("short", id))
	return nm if lb == "" else nm + " " + lb


## 状態異常の並べ方：[{id, icon, text, good, row, x}]。幅 w で折り返す（x は行の左端からの位置）
static func status_layout(u: Dictionary, w: float, fs: int, row_h: float) -> Array:
	var f: Font = ImageController.font_bold
	var out: Array = []
	var effects: Dictionary = u.get("status_effects", {})
	var d := row_h - 6.0
	var x := 0.0
	var row := 0
	for k in effects.keys():
		var id := str(k)
		var st: Dictionary = StatusEffectList.DATA.get(id, {})
		var t := status_text(u, id)
		var cw := d + 4.0 + f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 8.0
		if x > 0.0 and x + cw > w:
			row += 1
			x = 0.0
		out.append({"id": id, "icon": str(st.get("icon", "star")), "text": t, "good": bool(st.get("good", true)), "row": row, "x": x})
		x += cw + 6.0
	return out


## status_layout の結果を描く。p = 1 行目の左上
static func draw_status(ci: CanvasItem, layout: Array, p: Vector2, fs: int, row_h: float, ink: Color, paper: Color) -> void:
	var f: Font = ImageController.font_bold
	var d := row_h - 6.0
	for c in layout:
		var cx := p.x + float(c.x)
		var cy := p.y + int(c.row) * row_h + row_h / 2.0
		var cc := Vector2(cx + d / 2.0, cy)
		# 良い効果は白い縁、悪い効果は赤い縁
		ci.draw_circle(cc, d / 2.0, ink)
		ci.draw_arc(cc, d / 2.0 - 1.0, 0, TAU, 20, paper if c.good else ImageController.COL.red, 2.0, true)
		ImageController.icon(ci, str(c.icon), cc, d * 0.72)
		ci.draw_string(f, Vector2(cx + d + 4.0, cy + fs * 0.36), str(c.text), HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				ink if c.good else ImageController.COL.red_d)


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
	var body_w := size.x - PAD_X * 2
	var top := TOP
	if not unit.is_empty():
		# ステータスの行（アイコン＋数字）
		draw_stats(self, unit, Vector2(PAD_X, top + STAT_H * 0.5), body_w, STAT_FS, IC.COL.ink, IC.COL.paper)
		top += STAT_H
		# 状態異常のアイコン
		var lay := status_layout(unit, body_w, CHIP_FS, CHIP_H)
		draw_status(self, lay, Vector2(PAD_X, top), CHIP_FS, CHIP_H, IC.COL.ink, IC.COL.paper)
		top = TOP + icon_rows_height(unit, body_w)
		draw_line(Vector2(PAD_X, top - 4), Vector2(size.x - PAD_X, top - 4), Color(0, 0, 0, 0.25), 2)
	var f: Font = IC.font_bold
	for i in _wrapped.size():
		var y := top + i * LINE_H + LINE_H * 0.5
		draw_string(f, Vector2(PAD_X, y + FS * 0.36), _wrapped[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FS, IC.COL.ink)
		if i < _wrapped.size() - 1 and not str(_wrapped[i + 1]).begins_with("　"):
			draw_line(Vector2(PAD_X, y + LINE_H * 0.5), Vector2(size.x - PAD_X, y + LINE_H * 0.5), Color(0, 0, 0, 0.12), 1)


## 互換用：左寄せの 1 行
func ci_text_left(s: String, p: Vector2, fs: int) -> void:
	draw_string(ImageController.font_bold, p + Vector2(0, fs * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, size.x - 30, fs, ImageController.COL.ink)
