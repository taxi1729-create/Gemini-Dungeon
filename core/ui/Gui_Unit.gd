extends Node2D
class_name GuiUnit
## 戦場のキャラ1体分の表示（体・HPバー・シールド・状態異常・敵の行動予告）。
## data は戦闘ロジックと共有する辞書（hp などが書き換わると次の描画で反映される）。

var data: Dictionary
var art_scale := 1.0
var facing := 1.0
var active := false  # 手番中の目印
var dead := false
var _t := 0.0
var _phase := randf() * TAU


func setup(d: Dictionary, f: float) -> void:
	data = d
	facing = f
	art_scale = float(d.get("art_scale", 1.0))
	z_index = int(position.y)


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
	if active:
		var a := 0.5 + 0.3 * sin(_t * 5.0)
		draw_colored_polygon(IC.ell(Vector2(0, 2), 54 * art_scale, 14 * art_scale), Color(IC.COL.gold, a * 0.5))
	IC.shadow(self, Vector2.ZERO, 38 * art_scale)
	var squash := Vector2(1.0, 1.0 + bob * 0.006)
	draw_set_transform(Vector2.ZERO, 0, squash)
	IC.character(self, data.get("art", "knight"), Vector2(0, 0), art_scale, facing, _t + _phase)
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	if dead:
		return
	_draw_hp(IC)
	_draw_status(IC)
	if data.get("side") == "enemy":
		_draw_intent(IC)
	if active:
		var y := -body_height() - 30 + sin(_t * 6.0) * 5
		draw_colored_polygon(PackedVector2Array([Vector2(-12, y - 14), Vector2(12, y - 14), Vector2(0, y)]), IC.COL.gold)


func _draw_hp(IC) -> void:
	var w := 104.0
	var r := Rect2(-w / 2, 14, w, 14)
	IC.round_rect(self, r.grow(2), Color(0, 0, 0, 0.7), 6)
	IC.round_rect(self, r, IC.COL.hp_back, 5)
	var ratio := clampf(float(data.hp) / float(data.max_hp), 0.0, 1.0)
	if ratio > 0:
		IC.round_rect(self, Rect2(r.position, Vector2(w * ratio, r.size.y)), IC.COL.hp, 5)
		draw_rect(Rect2(r.position + Vector2(3, 2), Vector2(maxf(0, w * ratio - 6), 3)), Color(1, 1, 1, 0.25))
	IC.text(self, "%d/%d" % [data.hp, data.max_hp], Vector2(0, 21), 15, Color.WHITE, true, 4)
	var sh := int(data.get("shield", 0))
	if sh > 0:
		IC.icon(self, "shield", Vector2(-w / 2 - 14, 21), 30)
		IC.text(self, str(sh), Vector2(-w / 2 - 14, 22), 15, Color.WHITE, true, 4)
	if data.get("side") == "ally":
		var ap := int(data.get("ap", 0))
		var mx := int(data.get("max_ap", 5))
		for i in mx:
			var p := Vector2(-((mx - 1) * 9) + i * 18, 40)
			IC.icon(self, "ap", p, 16, IC.COL.ap if i < ap else Color(0.3, 0.3, 0.4, 0.8))


func _draw_status(IC) -> void:
	var effects: Dictionary = data.get("status_effects", {})
	var i := 0
	var y := 58.0 if data.get("side") == "ally" else 42.0
	var n := effects.size()
	for k in effects.keys():
		var st: Dictionary = StatusEffectList.DATA.get(k, {})
		var p := Vector2(-((n - 1) * 15) + i * 30, y)
		draw_circle(p, 13, Color(0, 0, 0, 0.6))
		IC.icon(self, st.get("icon", "star"), p, 22)
		IC.text(self, str(effects[k]), p + Vector2(9, 8), 13, Color.WHITE, true, 4)
		i += 1


func _draw_intent(IC) -> void:
	var act: Dictionary = data.get("intent", {})
	if act.is_empty():
		return
	var y := -body_height() - 24
	var bob := sin(_t * 3.0) * 3
	var c := Vector2(0, y + bob)
	IC.round_rect(self, Rect2(c - Vector2(38, 18), Vector2(76, 36)), Color(0, 0, 0, 0.6), 10, 2, Color(1, 1, 1, 0.25))
	if act.has("power"):
		var dmg := int(act.power) + ActionController.get_atk(data)
		var kind := "target_all" if act.get("target") == "enemy_all" else "sword"
		IC.icon(self, kind, c + Vector2(-16, 0), 26, IC.COL.bad if kind == "target_all" else Color(0, 0, 0, 0))
		IC.text(self, str(maxi(0, dmg)), c + Vector2(14, 1), 20, Color.WHITE, true, 4)
	else:
		var kind := "def_buff"
		match act.get("effect", ""):
			"add_shield": kind = "shield"
			"set_next_action": kind = "hourglass"
			"add_status":
				var st: Dictionary = StatusEffectList.DATA.get(act.status, {})
				kind = st.get("icon", "star")
		IC.icon(self, kind, c, 28)
