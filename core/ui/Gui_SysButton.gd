extends GuiPad
class_name GuiSysButton
## 操作エリアのボタン（入替・保留・アイテム・固有スキル・中央の必殺・右列キー）。
## shape = "circle"（3×3 の中）/ "key"（右列のキー）

var title := ""
var icon_kind := "star"
var accent := Color("e8c26a")
var description := ""
var label_hint := ""
var shape := "circle"
var ap_cost := -1
var subtitle := ""
var charge := 0.0:  # 中央長押しの溜め（0〜1）
	set(v):
		charge = v
		queue_redraw()
## 左上の効果量（必殺技）：{"kind": "power", "val": 実際のダメージ, "base": 基本の威力} / {"kind": "shield", "val": n} / {}（出さない）
var badge := {}:
	set(v):
		badge = v
		queue_redraw()
var dimmed := false:
	set(v):
		dimmed = v
		queue_redraw()


func setup(t: String, ik: String, acc: Color, desc: String, hint: String, sz: Vector2 = Vector2(116, 116), shp: String = "circle") -> void:
	title = t
	icon_kind = ik
	accent = acc
	description = desc
	label_hint = hint
	shape = shp
	size = sz
	interactive = false  # 入力は戦闘シーンのジェスチャー処理でまとめて扱う
	queue_redraw()


func _process(delta: float) -> void:
	super(delta)
	if (icon_kind == "burst" and not dimmed) or charge > 0:
		queue_redraw()


func _draw() -> void:
	var IC = ImageController
	var fg: Color = IC.COL.text if not dimmed else IC.GLASS.ash_gray.lightened(0.2)
	var ac: Color = accent if not dimmed else IC.GLASS.ash_gray
	if shape == "key":
		_draw_key(fg, ac)
		return
	var c := size / 2.0
	var rad := size.x / 2.0 - 6
	# 選択中：赤いギザギザの爆発形を背負わせ、円も赤で塗る
	if highlighted:
		IC.poly_box(self, IC.burst_pts(c, rad + 16, rad + 4, 14, 5, _t * 0.6), IC.COL.red, 3.0, IC.COL.ink)
	else:
		draw_circle(c + Vector2(5, 5), rad, Color(IC.GLASS.ivory_black, 0.7))
	# 丸の面：ブラッキッシュブルーにセイクレッドブルーを混ぜた明るめの紺。無効はアッシュ寄りの暗い色
	var face: Color = IC.COL.ink.lerp(IC.GLASS.sacred_blue, 0.45)
	if dimmed:
		face = IC.GLASS.ivory_black.lerp(IC.GLASS.ash_gray, 0.3)
	elif highlighted:
		face = IC.COL.red
	draw_circle(c, rad, face)
	var ring: Color = IC.COL.paper if not dimmed else IC.GLASS.ash_gray.darkened(0.2)
	if icon_kind == "burst" and not dimmed and not highlighted:
		ring = IC.COL.red.lerp(IC.COL.paper, 0.5 + 0.5 * sin(_t * 4.0))
	draw_arc(c, rad, 0, TAU, 48, ring, 4, true)
	if not highlighted:
		draw_arc(c, rad - 8, 0, TAU, 40, Color(ac, 0.6), 2, true)
	if charge > 0:
		var full := charge >= 1.0
		var col: Color = IC.COL.paper if full and int(_t * 12) % 2 == 0 else IC.COL.red
		draw_arc(c, rad + 8, -PI / 2, -PI / 2 + TAU * minf(charge, 1.0), 48, IC.COL.ink, 14, true)
		draw_arc(c, rad + 8, -PI / 2, -PI / 2 + TAU * minf(charge, 1.0), 48, col, 9, true)
	var sub_on := subtitle != ""
	IC.icon(self, icon_kind, c + Vector2(0, -18 if sub_on else -14), 44, ac if not highlighted else IC.COL.paper)
	IC.head(self, title, c + Vector2(0, 16 if sub_on else 22), 19, fg, size.x - 24, Color(0, 0, 0, 0), Vector2.ZERO, 5, IC.COL.ink)
	if sub_on:
		IC.text(self, subtitle, c + Vector2(0, 39), 14, Color(fg, 0.85), true, 4, size.x - 30, IC.COL.ink)
	_draw_badge()
	if ap_cost >= 0:
		var p := Vector2(size.x - 18, 18)
		IC.icon(self, "ap", p, 34, IC.COL.ap if not dimmed else IC.GLASS.deep_rose.darkened(0.55))
		IC.text(self, str(ap_cost), p + Vector2(0, 1), 17, Color.WHITE, true, 4, -1.0, IC.COL.ink)


## 左上の効果量。攻撃はカードと同じ赤いギザギザの星（基本より高ければ緑＋▲、低ければ白地に赤字＋▼）、
## ブロックは盾のアイコンに数字。暗い時（dimmed）は AP 表示と同様に暗くする
func _draw_badge() -> void:
	if badge.is_empty():
		return
	var IC = ImageController
	var pc := Vector2(18, 18)  # 丸の外側の左上の角（右上の AP と左右対称）
	var dark := 0.6 if dimmed else 0.0  # 暗くする量
	var val := int(badge.get("val", 0))
	if badge.get("kind", "") == "shield":
		IC.icon(self, "shield", pc, 36, Color("4f86c6").darkened(dark))  # 盾の既定色（ImageController.ICON_DEFAULT と同じ）
		IC.text(self, str(val), pc + Vector2(0, 1), 17, Color.WHITE.darkened(dark), true, 4, -1.0, IC.COL.ink)
		return
	var base := int(badge.get("base", val))
	var face: Color = IC.COL.red
	var num_col: Color = IC.COL.paper
	if val > base:
		face = Color("1c9a48")
	elif val < base:
		face = IC.COL.paper
		num_col = IC.COL.red
	IC.poly_box(self, IC.burst_pts(pc, 21, 14, 8, 3), face.darkened(dark), 2.0, IC.COL.ink)
	IC.head(self, str(val), pc + Vector2(-1, 0), 21, num_col.darkened(dark), 26, Color(0, 0, 0, 0), Vector2.ZERO, 4, IC.COL.ink)
	if val != base:
		var up := val > base
		var ac := Vector2(pc.x + 16, pc.y + 13)
		var tri := PackedVector2Array([ac + Vector2(-5, 3), ac + Vector2(5, 3), ac + Vector2(0, -5)]) if up \
				else PackedVector2Array([ac + Vector2(-5, -3), ac + Vector2(5, -3), ac + Vector2(0, 5)])
		var tc: Color = IC.COL.good if up else IC.COL.red
		IC.poly_box(self, tri, tc.darkened(dark), 2.0, IC.COL.ink)


## 右列のキー：斜めの黒いパネル。選択中は赤く塗りつぶす
func _draw_key(fg: Color, ac: Color) -> void:
	var IC = ImageController
	var r := Rect2(8, 6, size.x - 18, size.y - 16)
	var skew := 16.0
	var face: Color = IC.COL.ink.lerp(IC.GLASS.sacred_blue, 0.4).lerp(accent, 0.12)  # 紺に差し色をほんのり混ぜる
	if dimmed:
		face = IC.GLASS.ivory_black.lerp(IC.GLASS.ash_gray, 0.3)
	elif highlighted:
		face = IC.COL.red
	var shadow: Color = IC.COL.ink if highlighted else Color(IC.GLASS.ivory_black, 0.75)
	IC.slant(self, r, face, skew, 3.0 if not highlighted else 4.0, IC.COL.paper if not dimmed else IC.GLASS.ash_gray.darkened(0.2),
			shadow, Vector2(7, 7))
	if not highlighted and not dimmed:
		# 右下に差し色の斜線、左に差し色の細い帯
		IC.stripes(self, Rect2(r.position.x + r.size.x * 0.45, r.end.y - 34, r.size.x * 0.5, 30), Color(ac, 0.35), 10, 3, 0.6)
		draw_colored_polygon(IC.slant_pts(Rect2(r.position.x + 6, r.position.y + 10, 7, r.size.y - 20), skew * (r.size.y - 20) / r.size.y), ac)
	IC.icon(self, icon_kind, Vector2(size.x / 2 + 2, size.y / 2 - 18), 50, ac if not highlighted else IC.COL.paper)
	IC.head(self, title, Vector2(size.x / 2, size.y / 2 + 32), 22, fg, size.x - 46, Color(0, 0, 0, 0), Vector2.ZERO, 5, IC.COL.ink)
