extends Control
class_name GuiStatusView
## 戦闘中の全員のステータス一覧（全画面のオーバーレイ）。
## 生きているキャラを味方→敵の順に 2 列のカードで並べる（最大 2 + 6 体が 1 画面に収まる）。
## 各カード：名前、ステータス（HP・攻撃・防御・素早さ・ブロック）、状態異常、
## 味方は AP と立ち位置、敵は次の行動。下の「閉じる」で closed を出して消える。

signal closed

const COLS := 2
const CARD_W := 330.0
const GAP_X := 20.0
const GAP_Y := 18.0
const AREA_TOP := 128.0  # カードを並べる範囲の上端
const AREA_BOTTOM := 1150.0  # 同じく下端（この下に閉じるボタン）
const MAX_CARD_H := 250.0
const STAT_FS := 18
const CHIP_FS := 15
const CHIP_H := 30.0
const LINE_FS := 16
const LANE_NAME := ["左・青", "右・赤"]
const LANE_COL := [Color("2f7cf0"), Color("e8213a")]

var units: Array = []
var _cards: Array = []  # [{unit, rect}]


static func open(parent: Node, list: Array) -> GuiStatusView:
	var v := GuiStatusView.new()
	v.units = list
	parent.add_child(v)
	return v


func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(720, 1280)
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	UiSystem.make_banner(self, "ステータス", Rect2(40, 34, 400, 66), 32)
	UiSystem.make_button(self, "閉じる", Vector2(210, 1170), Vector2(300, 80), _close, 28)
	_layout()


func _close() -> void:
	closed.emit()
	queue_free()


## 味方を先、敵をその次の行から並べる
func _layout() -> void:
	_cards.clear()
	var allies: Array = []
	var enemies: Array = []
	for u in units:
		if int(u.get("hp", 0)) <= 0:
			continue
		if str(u.get("side", "")) == "ally":
			allies.append(u)
		else:
			enemies.append(u)
	var rows := int(ceil(allies.size() / float(COLS))) + int(ceil(enemies.size() / float(COLS)))
	if rows <= 0:
		return
	var h := minf(MAX_CARD_H, (AREA_BOTTOM - AREA_TOP - GAP_Y * (rows - 1)) / rows)
	var x0 := (720.0 - CARD_W * COLS - GAP_X * (COLS - 1)) / 2.0
	var row := 0
	for group in [allies, enemies]:
		var g: Array = group
		for i in g.size():
			var c := i % COLS
			var rr := row + floori(i / float(COLS))
			var r := Rect2(x0 + c * (CARD_W + GAP_X), AREA_TOP + rr * (h + GAP_Y), CARD_W, h)
			_cards.append({"unit": g[i], "rect": r})
		row += int(ceil(g.size() / float(COLS)))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.82))
	var IC = ImageController
	IC.stripes(self, Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.025), 22, 2, 0.6)
	for c in _cards:
		_draw_card(c.unit, c.rect)


func _draw_card(u: Dictionary, r: Rect2) -> void:
	var IC = ImageController
	var col: Dictionary = IC.COL
	var enemy := str(u.get("side", "")) != "ally"
	# 白い面（黒縁・赤のベタ影）。上辺に名前の斜めタグ
	IC.cut_rect(self, r, col.paper, 12, 3.0, col.ink, col.red if enemy else Color(col.ink, 0.9), Vector2(6, 6))
	var nm := str(u.get("name", ""))
	var tf: Font = IC.font_head
	var tw := minf(tf.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 46, r.size.x - 70)
	var tag := Rect2(r.position + Vector2(10, -10), Vector2(tw, 36))
	IC.slant(self, tag, col.red if enemy else col.ink, 12, 2.0, col.ink if enemy else col.paper)
	IC.head(self, nm, tag.get_center(), 22, col.paper, tw - 28)
	# 右上：敵は前衛／後衛、味方は立ち位置の色
	var f: Font = IC.font_bold
	if enemy:
		if u.has("row"):
			var rt := "後衛" if int(u.row) == 1 else "前衛"
			draw_string(f, Vector2(r.end.x - 52, r.position.y + 22), rt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col.red_d)
	else:
		var lane := clampi(int(u.get("lane", 0)), 0, 1)
		draw_circle(Vector2(r.end.x - 24, r.position.y + 16), 9, LANE_COL[lane])
		draw_arc(Vector2(r.end.x - 24, r.position.y + 16), 9, 0, TAU, 16, col.ink, 2.0, true)
	var pad := 14.0
	var w := r.size.x - pad * 2
	var y := r.position.y + 34.0
	# ステータス
	GuiInfoPanel.draw_stats(self, u, Vector2(r.position.x + pad, y + 16), w, STAT_FS, col.ink, col.paper)
	y += 36.0
	# 下の行（味方：AP と立ち位置、敵：次の行動）を先に決め、残りの高さに状態異常を入れる
	var foot := _foot_lines(u, w)
	var foot_h := foot.size() * 21.0 + 6.0
	var lay := GuiInfoPanel.status_layout(u, w, CHIP_FS, CHIP_H)
	var max_rows := maxi(1, int((r.end.y - foot_h - 8.0 - y) / CHIP_H))
	var shown: Array = []
	for c in lay:
		if int(c.row) < max_rows:
			shown.append(c)
	GuiInfoPanel.draw_status(self, shown, Vector2(r.position.x + pad, y), CHIP_FS, CHIP_H, col.ink, col.paper)
	if shown.size() < lay.size():
		draw_string(f, Vector2(r.end.x - pad - 30, y + max_rows * CHIP_H - 4), "…", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col.ink)
	# 下の行
	var fy := r.end.y - foot_h + 4.0
	draw_line(Vector2(r.position.x + pad, fy - 2), Vector2(r.end.x - pad, fy - 2), Color(0, 0, 0, 0.2), 2)
	for i in foot.size():
		var p := Vector2(r.position.x + pad, fy + 10.0 + i * 21.0)
		if i == 0 and not enemy:
			_draw_ap(u, p)
		else:
			draw_string(f, p + Vector2(0, LINE_FS * 0.36), str(foot[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_FS, col.ink)


## 下に出す文の行（幅 w で折り返す。最大 2 行）
func _foot_lines(u: Dictionary, w: float) -> Array:
	if str(u.get("side", "")) == "ally":
		var lane := clampi(int(u.get("lane", 0)), 0, 1)
		return ["AP", "位置：" + LANE_NAME[lane]]
	var it: Dictionary = u.get("intent", {})
	var s := "次：—"
	if not it.is_empty():
		s = "次：%s　%s" % [str(it.get("name", "")), DeckController.effect_text(u, it)]
	var out := _wrap(s, w, LINE_FS)
	if out.size() > 2:
		out = [out[0], str(out[1]).substr(0, maxi(0, str(out[1]).length() - 1)) + "…"]
	return out


## 1 文字ずつ折り返す（日本語は空白が無いので文字単位）
func _wrap(s: String, w: float, fs: int) -> Array:
	var f: Font = ImageController.font_bold
	var out: Array = []
	var cur := ""
	for ch in s:
		if cur != "" and f.get_string_size(cur + ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
			out.append(cur)
			cur = ch
		else:
			cur += ch
	out.append(cur)
	return out


## AP：小さな菱形 10 個＋数字
func _draw_ap(u: Dictionary, p: Vector2) -> void:
	var IC = ImageController
	var col: Dictionary = IC.COL
	var ap := int(u.get("ap", 0))
	var mx := int(u.get("max_ap", 10))
	draw_string(IC.font_bold, p + Vector2(0, LINE_FS * 0.36), "AP", HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_FS, col.ink)
	for i in mx:
		var c := p + Vector2(36 + i * 19, 0)
		var dia := PackedVector2Array([c + Vector2(0, -8), c + Vector2(7, 0), c + Vector2(0, 8), c + Vector2(-7, 0)])
		draw_colored_polygon(dia, col.red if i < ap else Color(col.ink, 0.15))
	draw_string(IC.font_bold, p + Vector2(36 + mx * 19, LINE_FS * 0.36), "%d/%d" % [ap, mx], HORIZONTAL_ALIGNMENT_LEFT, -1, LINE_FS, col.ink)
