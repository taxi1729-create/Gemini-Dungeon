extends Node2D
class_name GuiUnit
## 戦場のキャラ1体分の表示（体・HPバー・ブロック・状態異常・敵の行動予告・プレビュー）。
## data は戦闘ロジックと共有する辞書（hp などが書き換わると次の描画で反映される）。
## 見た目は白・黒・赤の漫画調（斜めの HP バー、ギザギザの吹き出し、赤い斜めの札）。

const INK := Color("111114")
const PAPER := Color("f7f4ee")
const RED := Color("e8213a")
const LANE_COL := [Color("3d8bff"), Color("ff3b3b")]  # 左＝青、右＝赤（BattleFx と同じ）

var data: Dictionary
var art_scale := 1.0
var facing := 1.0
var active := false  # 手番中の目印
var dead := false
var targeted := 0  # 敵の予告で狙われている数（味方用）
## プレビュー：{"on": bool, "damage": n, "kill": bool, "label": 文字}
var preview := {}
var kick := Vector2.ZERO  # 被弾で体だけ押し返されるずれ（演出用）
var flying := false  # 撃破で吹き飛んでいる最中（影や地面の印を描かない）
var _t := 0.0
var _phase := randf() * TAU
var _bubble := PackedVector2Array()  # 吹き出しの形（ギザギザ。最初に一度だけ作る）


func setup(d: Dictionary, f: float) -> void:
	data = d
	facing = f
	art_scale = float(d.get("art_scale", 1.0)) * float(d.get("view_scale", 1.0))


func body_height() -> float:
	return 140.0 * art_scale


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if data.is_empty():
		return
	var IC = ImageController
	var bob := sin(_t * 2.4 + _phase) * 2.5
	var on: bool = preview.get("on", false)
	if not flying:
		if on:
			var a := 0.55 + 0.3 * sin(_t * 10.0)
			draw_colored_polygon(IC.ell(Vector2(0, 2), 62 * art_scale, 17 * art_scale), Color(RED, a * 0.6))
			_ring(Vector2(0, 2), 62 * art_scale, 17 * art_scale, Color(PAPER, a), 3.0)
		elif active:
			var a := 0.5 + 0.3 * sin(_t * 5.0)
			_ring(Vector2(0, 2), 56 * art_scale, 15 * art_scale, Color(PAPER, a), 3.0)
		IC.shadow(self, Vector2.ZERO, 38 * art_scale)
	draw_set_transform(kick, 0, Vector2(1.0, 1.0 + bob * 0.006))
	IC.character(self, data.get("art", "knight"), kick, art_scale, facing, _t + _phase)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if dead:
		return
	_draw_hp(IC)
	_draw_status(IC)
	if data.get("side") == "enemy":
		_draw_intent(IC)
	else:
		_draw_ally_badges(IC)
	if on:
		_draw_preview(IC)
	elif active:
		var y := -body_height() - 16 + sin(_t * 6.0) * 5
		var tri := PackedVector2Array([Vector2(-14, y - 16), Vector2(14, y - 16), Vector2(0, y)])
		draw_colored_polygon(PackedVector2Array([Vector2(-19, y - 19), Vector2(19, y - 19), Vector2(0, y + 5)]), INK)
		draw_colored_polygon(tri, RED)


func _ring(c: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	var p := ImageController.ell(c, rx, ry, 28)
	p.append(p[0])
	draw_polyline(p, col, w, true)


## 傾いた平行四辺形（x, y は左上、sk は上辺のずれ）
func _para(x: float, y: float, w: float, h: float, sk: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x + sk, y), Vector2(x + w + sk, y), Vector2(x + w, y + h), Vector2(x, y + h)])


func _draw_hp(IC) -> void:
	var w := 98.0
	var h := 13.0
	var sk := 6.0
	var x0 := -w / 2 - sk / 2
	var y0 := 11.0
	draw_colored_polygon(_para(x0 - 5, y0 - 4, w + 10, h + 8, sk), INK)
	draw_colored_polygon(_para(x0 - 2.5, y0 - 2, w + 5, h + 4, sk), PAPER)
	draw_colored_polygon(_para(x0, y0, w, h, sk), Color("2a0d12"))
	var ratio := clampf(float(data.hp) / float(data.max_hp), 0.0, 1.0)
	if ratio > 0:
		draw_colored_polygon(_para(x0, y0, w * ratio, h, sk), RED)
		draw_colored_polygon(_para(x0 + 1, y0 + 1, maxf(0.0, w * ratio - 2), 3, sk * 0.25), Color(1, 1, 1, 0.35))
	# プレビューの予想ダメージ部分を白く点滅
	var dmg := int(preview.get("damage", 0))
	if preview.get("on", false) and dmg > 0 and ratio > 0:
		var after := clampf(float(int(data.hp) - dmg) / float(data.max_hp), 0.0, 1.0)
		var a := 0.55 + 0.4 * sin(_t * 12.0)
		draw_colored_polygon(_para(x0 + w * after, y0, w * (ratio - after), h, sk), Color(1, 1, 1, a))
	IC.text(self, "%d/%d" % [data.hp, data.max_hp], Vector2(2, y0 + h / 2 + 0.5), 13, PAPER, true, 4, -1.0, INK)
	var sh := int(data.get("shield", 0))
	if sh > 0:
		var p := Vector2(-w / 2 - 18, y0 + h / 2)
		IC.icon(self, "shield", p, 32)
		IC.text(self, str(sh), p + Vector2(0, 1), 15, PAPER, true, 4, -1.0, INK)


func _draw_status(IC) -> void:
	var effects: Dictionary = data.get("status_effects", {})
	var i := 0
	var n := effects.size()
	for k in effects.keys():
		var st: Dictionary = StatusEffectList.DATA.get(k, {})
		var p := Vector2(-((n - 1) * 15) + i * 30, 42)
		draw_circle(p, 14, INK)
		draw_arc(p, 13, 0, TAU, 20, PAPER, 2.0, true)
		IC.icon(self, st.get("icon", "star"), p, 21)
		IC.text(self, str(effects[k]), p + Vector2(10, 9), 13, PAPER, true, 4, -1.0, INK)
		i += 1


func _draw_ally_badges(IC) -> void:
	if targeted <= 0:
		return
	# 狙われている印：立っている側（青／赤）の色の照準を頭の横に小さく
	var col: Color = LANE_COL[clampi(int(data.get("lane", 0)), 0, 1)]
	var p := Vector2(44 * (1.0 if int(data.get("lane", 0)) == 0 else -1.0), -body_height() * 0.8)
	var r := 15.0 + 2.0 * sin(_t * 8.0)
	draw_circle(p, r + 5, Color(INK, 0.8))
	draw_arc(p, r, 0, TAU, 24, col, 3.0, true)
	for k in 4:
		var d := Vector2.RIGHT.rotated(PI / 2 * k)
		draw_line(p + d * (r - 6), p + d * (r + 6), col, 3.0)
	draw_circle(p, 3, PAPER)
	if targeted > 1:
		IC.text(self, "×%d" % targeted, p + Vector2(0, r + 14), 16, PAPER, true, 4, -1.0, INK)


func _bubble_shape() -> PackedVector2Array:
	if _bubble.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = int(_phase * 1000.0)
		var n := 22
		for i in n:
			var a := TAU * i / n
			var r := 1.0 if i % 2 == 0 else rng.randf_range(1.1, 1.2)
			_bubble.append(Vector2(cos(a) * 54.0 * r, sin(a) * 23.0 * r))
	return _bubble


func _draw_intent(IC) -> void:
	var act: Dictionary = data.get("intent", {})
	if act.is_empty():
		return
	var y := -body_height() - 20
	var c := Vector2(0, y + sin(_t * 3.0) * 3)
	# ギザギザの白い吹き出し（黒縁）としっぽ
	var shape := _bubble_shape()
	var tail := PackedVector2Array([c + Vector2(-10, 18), c + Vector2(8, 18), c + Vector2(-2, 36)])
	draw_set_transform(c, 0.0, Vector2(1.09, 1.16))
	draw_colored_polygon(shape, INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([tail[0] + Vector2(-4, -2), tail[1] + Vector2(4, -2), tail[2] + Vector2(0, 5)]), INK)
	draw_set_transform(c, 0.0, Vector2.ONE)
	draw_colored_polygon(shape, PAPER)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_colored_polygon(tail, PAPER)
	# 左：効果、右：対象
	if act.has("power"):
		IC.icon(self, "sword", c + Vector2(-28, 0), 24, INK)
		IC.text(self, str(maxi(0, int(act.power) + ActionController.get_atk(data))), c + Vector2(-3, 1), 21, INK, true)
	else:
		var kind := "star"
		var label := ""
		var kcol := Color(0, 0, 0, 0)
		match act.get("effect", ""):
			"add_shield":
				kind = "shield"
				label = str(act.eff_val)
			"heal":
				kind = "heart"
				label = str(act.eff_val)
			"set_next_action":
				kind = "hourglass"
				kcol = INK
			"add_status":
				kind = StatusEffectList.DATA[act.status].icon
				label = str(act.eff_val)
		IC.icon(self, kind, c + Vector2(-28, 0), 24, kcol)
		if label != "":
			IC.text(self, label, c + Vector2(-3, 1), 21, INK, true)
	var tk := "target_one"
	var tcol: Color = RED
	match act.get("target", ""):
		"enemy_all": tk = "target_all"
		"ally_all", "self":
			tk = "horns"
			tcol = INK
	# 対象アイコンの下に赤い斜めの下地
	draw_colored_polygon(_para(c.x + 12, c.y - 13, 30, 26, 6), Color(RED, 0.18) if tcol == RED else Color(INK, 0.08))
	IC.icon(self, tk, c + Vector2(28, 0), 24, tcol)


func _draw_preview(IC) -> void:
	var top := -body_height() - (56.0 if data.get("side") == "enemy" else 22.0)
	var label: String = preview.get("label", "")
	if preview.get("kill", false):
		var p := Vector2(0, top - 6)
		var s := 1.0 + 0.08 * sin(_t * 10.0)
		draw_colored_polygon(IC.star_pts(p, 36 * s, 26 * s, 12, _t), INK)
		draw_colored_polygon(IC.star_pts(p, 31 * s, 22 * s, 12, _t), RED)
		IC.icon(self, "skull", p, 42 * s, PAPER)
	elif int(preview.get("damage", -1)) >= 0 and preview.has("damage"):
		# 赤い斜めの札
		draw_set_transform(Vector2(0, top - 4), -0.08, Vector2.ONE)
		draw_colored_polygon(_para(-42, -22, 80, 42, 10), INK)
		draw_colored_polygon(_para(-38, -18, 72, 34, 8), RED)
		BattleFx.comic_text(self, "-%d" % preview.damage, Vector2(1, 0), 26, PAPER, INK)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif label != "":
		draw_set_transform(Vector2(0, top - 4), -0.05, Vector2.ONE)
		draw_colored_polygon(_para(-66, -21, 126, 40, 8), INK)
		draw_colored_polygon(_para(-62, 14, 118, 4, 1), RED)
		IC.text(self, label, Vector2(0, -2), 18, PAPER, true, 0, 112)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
