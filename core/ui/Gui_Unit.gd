extends Node2D
class_name GuiUnit
## 戦場のキャラ1体分の表示（体・HPバー・ブロック・状態異常・敵の行動予告・プレビュー）。
## data は戦闘ロジックと共有する辞書（hp などが書き換わると次の描画で反映される）。

var data: Dictionary
var art_scale := 1.0
var facing := 1.0
var active := false  # 手番中の目印
var dead := false
var targeted := 0  # 敵の予告で狙われている数（味方用）
## プレビュー：{"on": bool, "damage": n, "kill": bool, "label": 文字}
var preview := {}
var _t := 0.0
var _phase := randf() * TAU


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
	if on:
		var a := 0.45 + 0.25 * sin(_t * 10.0)
		draw_colored_polygon(IC.ell(Vector2(0, 2), 60 * art_scale, 16 * art_scale), Color(IC.COL.gold, a))
	elif active:
		var a := 0.5 + 0.3 * sin(_t * 5.0)
		draw_colored_polygon(IC.ell(Vector2(0, 2), 54 * art_scale, 14 * art_scale), Color(IC.COL.gold, a * 0.5))
	IC.shadow(self, Vector2.ZERO, 38 * art_scale)
	draw_set_transform(Vector2.ZERO, 0, Vector2(1.0, 1.0 + bob * 0.006))
	IC.character(self, data.get("art", "knight"), Vector2.ZERO, art_scale, facing, _t + _phase)
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
		draw_colored_polygon(PackedVector2Array([Vector2(-12, y - 14), Vector2(12, y - 14), Vector2(0, y)]), IC.COL.gold)


func _draw_hp(IC) -> void:
	var w := 96.0
	var r := Rect2(-w / 2, 10, w, 14)
	IC.round_rect(self, r.grow(2), Color(0, 0, 0, 0.7), 6)
	IC.round_rect(self, r, IC.COL.hp_back, 5)
	var ratio := clampf(float(data.hp) / float(data.max_hp), 0.0, 1.0)
	if ratio > 0:
		IC.round_rect(self, Rect2(r.position, Vector2(w * ratio, r.size.y)), IC.COL.hp, 5)
	# プレビューの予想ダメージ部分を白く点滅
	var dmg := int(preview.get("damage", 0))
	if preview.get("on", false) and dmg > 0 and ratio > 0:
		var after := clampf(float(int(data.hp) - dmg) / float(data.max_hp), 0.0, 1.0)
		var a := 0.5 + 0.4 * sin(_t * 12.0)
		draw_rect(Rect2(r.position.x + w * after, r.position.y, w * (ratio - after), r.size.y), Color(1, 1, 1, a))
	IC.text(self, "%d/%d" % [data.hp, data.max_hp], Vector2(0, 17), 14, Color.WHITE, true, 4)
	var sh := int(data.get("shield", 0))
	if sh > 0:
		IC.icon(self, "shield", Vector2(-w / 2 - 14, 17), 30)
		IC.text(self, str(sh), Vector2(-w / 2 - 14, 18), 15, Color.WHITE, true, 4)


func _draw_status(IC) -> void:
	var effects: Dictionary = data.get("status_effects", {})
	var i := 0
	var n := effects.size()
	for k in effects.keys():
		var st: Dictionary = StatusEffectList.DATA.get(k, {})
		var p := Vector2(-((n - 1) * 15) + i * 30, 40)
		draw_circle(p, 13, Color(0, 0, 0, 0.6))
		IC.icon(self, st.get("icon", "star"), p, 22)
		IC.text(self, str(effects[k]), p + Vector2(9, 8), 13, Color.WHITE, true, 4)
		i += 1


func _draw_ally_badges(IC) -> void:
	if targeted > 0:
		var p := Vector2(0, -body_height() * 0.55)
		var r := 30 + 4 * sin(_t * 8.0)
		draw_arc(p, r, 0, TAU, 28, Color(IC.COL.bad, 0.85), 3, true)
		for k in 4:
			var d := Vector2.RIGHT.rotated(PI / 2 * k)
			draw_line(p + d * (r - 8), p + d * (r + 8), Color(IC.COL.bad, 0.85), 3)


func _draw_intent(IC) -> void:
	var act: Dictionary = data.get("intent", {})
	if act.is_empty():
		return
	var y := -body_height() - 18
	var c := Vector2(0, y + sin(_t * 3.0) * 3)
	IC.round_rect(self, Rect2(c - Vector2(46, 17), Vector2(92, 34)), Color(0, 0, 0, 0.65), 10, 2, Color(1, 1, 1, 0.25))
	# 左：効果、右：対象
	if act.has("power"):
		IC.icon(self, "sword", c + Vector2(-30, 0), 24)
		IC.text(self, str(maxi(0, int(act.power) + ActionController.get_atk(data))), c + Vector2(-6, 1), 18, Color.WHITE, true, 4)
	else:
		var kind := "star"
		var label := ""
		match act.get("effect", ""):
			"add_shield":
				kind = "shield"
				label = str(act.eff_val)
			"heal":
				kind = "heart"
				label = str(act.eff_val)
			"set_next_action": kind = "hourglass"
			"add_status":
				kind = StatusEffectList.DATA[act.status].icon
				label = str(act.eff_val)
		IC.icon(self, kind, c + Vector2(-30, 0), 24)
		if label != "":
			IC.text(self, label, c + Vector2(-6, 1), 18, Color.WHITE, true, 4)
	var tk := "target_one"
	var tcol: Color = IC.COL.bad
	match act.get("target", ""):
		"enemy_all": tk = "target_all"
		"ally_all":
			tk = "horns"
			tcol = Color(0, 0, 0, 0)
		"self":
			tk = "horns"
			tcol = Color(0, 0, 0, 0)
	IC.icon(self, tk, c + Vector2(26, 0), 24, tcol)


func _draw_preview(IC) -> void:
	var top := -body_height() - (52.0 if data.get("side") == "enemy" else 22.0)
	var label: String = preview.get("label", "")
	if preview.get("kill", false):
		var p := Vector2(0, top - 4)
		draw_circle(p, 26, Color(0, 0, 0, 0.6))
		IC.icon(self, "skull", p, 44)
	elif int(preview.get("damage", -1)) >= 0 and preview.has("damage"):
		IC.round_rect(self, Rect2(Vector2(-34, top - 22), Vector2(68, 38)), Color(IC.COL.bad, 0.9), 10)
		IC.text(self, "-%d" % preview.damage, Vector2(0, top - 3), 22, Color.WHITE, true, 4)
	elif label != "":
		IC.round_rect(self, Rect2(Vector2(-60, top - 22), Vector2(120, 38)), Color(IC.COL.skill, 0.9), 10)
		IC.text(self, label, Vector2(0, top - 3), 18, Color.WHITE, true, 4, 112)
