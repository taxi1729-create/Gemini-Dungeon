extends Node2D
class_name BattleFx
## 戦闘の演出をまとめた部品。Cont_Battle.gd はここの関数を呼ぶだけで、見た目の詳細はここに閉じ込める。
## field（戦場の Node2D）の子として置く。カットインなど画面全体に出すものは ui（CanvasLayer）へ出す。
##
## 呼び出し側との約束（関数名・引数・戻り値は変えないこと）
##   setup(battle, field, ui)
##   set_lanes(left_pos, right_pos)              … 味方の左（青）・右（赤）の地面ターゲットの位置
##   set_intents(list)                           … 敵の予告矢印。list = [{"from": Vector2, "lanes": [0] / [0, 1], "move_to": Vector2 or null}]
##   enemy_attack(view, target_pos, hit, move_to) … 敵の攻撃演出。踏み込んだ瞬間に hit を呼ぶ。move_to があれば先にそこへ移動して留まる。戻り値＝演出の秒数
##   ally_attack(view, target_pos, hit)          … 味方の単体攻撃の演出。戻り値＝秒数
##   cast(view, hit)                             … 全体攻撃・スキルの演出（その場で）。戻り値＝秒数
##   hit(view, damage, blocked, kind)            … ダメージを受けた時の演出。kind = "slash" / "burst" / "tick"
##   popup(view, text, color, size)              … 文字を浮かべる（回復・ブロック・状態異常など）
##   knockout(view, from_pos)                    … 撃破演出（from_pos の反対方向へ吹き飛ぶ）
##   cut_in(char_id, special_name)               … 必殺技の溜めが満タンになった時のカットイン
##   shake(amount)                               … 画面揺れ
##
## 描き分け
##   ・この Node 自身（z_index 低）：地面のターゲットと予告矢印。キャラより奥に描く
##   ・top（FxTop、z_index 高）：火花・斬撃・ダメージ数字・画面フラッシュ。1 つの _draw でまとめて描く（ノードを増やさない）

const LANE_COL := [Color("3d8bff"), Color("ff3b3b")]  # 左＝青、右＝赤
const INK := Color("1c2048")  # 黒（ブラッキッシュブルー）
const PAPER := Color("dbe6f3")  # 白（エンジェルホワイト）
const RED := Color("b4485b")  # 差し色（ディープローズ）
const SPARK_GOLD := Color("ffd84d")
const WALL := Rect2(0, 0, 720, 650)  # 吹き飛びの跳ね返り範囲（戦場）
const TARGET_R := Vector2(78, 24)  # 地面ターゲットの楕円半径

var battle: Node
var field: Node2D
var ui: CanvasLayer
var lanes: Array = [Vector2(230, 600), Vector2(490, 600)]
var lane_scale: Array = [1.0, 1.0]  # 地面ターゲットの段の倍率（味方の depth_scale。Cont_Battle._sync_lanes が入れる）
var intents: Array = []
var shake_amt := 0.0
var top: FxTop
var _t := 0.0
var _flyers: Array = []  # 吹き飛び中の敵
var _cut: Node = null
# ヒットストップ（Engine.time_scale を一瞬だけ落とす。終了は実時間で判定）
var _ts_on := false
var _ts_base := 1.0
var _stop_until := 0


func setup(b: Node, f: Node2D, u: CanvasLayer) -> void:
	battle = b
	field = f
	ui = u
	z_index = 1  # 地面のターゲットと矢印はキャラより奥（キャラは y 座標順の z_index）
	top = FxTop.new()
	top.z_index = 900  # 火花・数字はキャラより手前
	add_child(top)


func set_lanes(left_pos: Vector2, right_pos: Vector2) -> void:
	lanes = [left_pos, right_pos]
	queue_redraw()


func set_intents(list: Array) -> void:
	intents = list
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_update_timescale()
	_update_flyers(delta)
	if shake_amt > 0.3:
		field.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt
		shake_amt = lerpf(shake_amt, 0.0, minf(1.0, delta * 15.0))
	else:
		shake_amt = 0.0
		field.position = Vector2.ZERO
	queue_redraw()


func _exit_tree() -> void:
	if _ts_on:
		Engine.time_scale = _ts_base
		_ts_on = false


# ============================================================
# 地面のターゲットと予告矢印
# ============================================================

func _draw() -> void:
	var cnt := [0, 0]
	for it in intents:
		for lane in it.lanes:
			cnt[int(lane)] += 1
	for i in 2:
		_draw_target(lanes[i], LANE_COL[i], int(cnt[i]), float(lane_scale[i]))
	for it in intents:
		if it.get("move_to") != null:
			_draw_move_hint(it)
	# 奥（画面上）の敵の矢印から描き、手前の矢印が上に重なるようにする
	var order: Array = intents.duplicate()
	order.sort_custom(func(a, b): return Vector2(a.from).y < Vector2(b.from).y)
	for it in order:
		for lane in it.lanes:
			_draw_arrow(Vector2(it.from), int(lane))


func _ring_pts(c: Vector2, rx: float, ry: float, n: int = 32) -> PackedVector2Array:
	var p := ImageController.ell(c, rx, ry, n)
	p.append(p[0])
	return p


func _draw_target(p: Vector2, col: Color, n: int, depth: float = 1.0) -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	var rx := TARGET_R.x * depth
	var ry := TARGET_R.y * depth
	draw_colored_polygon(ImageController.ell(p, rx + 6, ry + 3, 32), Color(0, 0, 0, 0.35))
	draw_colored_polygon(ImageController.ell(p, rx, ry, 32), Color(col, 0.18 + (0.12 * pulse if n > 0 else 0.0)))
	draw_polyline(_ring_pts(p, rx, ry), Color(col, 0.95), 4.0, true)
	draw_polyline(_ring_pts(p, rx * 0.62, ry * 0.62), Color(col, 0.6), 2.0, true)
	draw_colored_polygon(ImageController.ell(p, 13, 4.5, 12), Color(col, 0.9))
	# 回る目盛り（白）
	for k in 4:
		var a := _t * 0.9 + k * PI / 2.0
		var d := Vector2(cos(a) * rx, sin(a) * ry)
		draw_line(p + d * 0.84, p + d * 1.16, Color(PAPER, 0.9), 3.0, true)
	# 狙われている時は外へ広がる波紋
	if n > 0:
		var k2 := fmod(_t * 1.3, 1.0)
		draw_polyline(_ring_pts(p, rx * (1.0 + 0.45 * k2), ry * (1.0 + 0.45 * k2)), Color(col, 0.7 * (1.0 - k2)), 3.0, true)


## 地面の上を曲線で進む矢印（敵の足元 → 狙う側のターゲット）
func _draw_arrow(from: Vector2, lane: int) -> void:
	var to: Vector2 = lanes[lane]
	var col: Color = LANE_COL[lane]
	var d := to - from
	if d.length() < 10:
		return
	var nrm := Vector2(-d.y, d.x).normalized()
	if nrm.y > 0:
		nrm = -nrm  # 上側へふくらませて、奥行きのある地面を進むように見せる
	var ctrl := (from + to) * 0.5 + nrm * d.length() * 0.14
	var raw := PackedVector2Array()
	var steps := 28
	for i in steps + 1:
		var s := float(i) / steps
		raw.append(from.lerp(ctrl, s).lerp(ctrl.lerp(to, s), s))
	# 足元の楕円とターゲットの楕円の内側は削る
	var path := PackedVector2Array()
	for q in raw:
		var a := (q - from) / Vector2(26, 9)
		var b := (q - to) / (TARGET_R + Vector2(4, 2))
		if a.length() > 1.0 and b.length() > 1.0:
			path.append(q)
	if path.size() < 3:
		return
	var n := path.size()
	var pulse := 0.8 + 0.2 * sin(_t * 6.0)
	var cols := PackedColorArray()
	var outs := PackedColorArray()
	for i in n:
		var k := float(i) / (n - 1)
		cols.append(Color(col, (0.25 + 0.6 * k) * pulse))
		outs.append(Color(0, 0, 0, 0.15 + 0.35 * k))
	draw_polyline_colors(path, outs, 11.0, true)
	draw_polyline_colors(path, cols, 6.0, true)
	# 先へ流れる白い山形（進む向きを示す）
	var lens := PackedFloat32Array([0.0])
	for i in range(1, n):
		lens.append(lens[i - 1] + path[i].distance_to(path[i - 1]))
	var total := lens[n - 1]
	var gap := 34.0
	var s0 := fmod(_t * 70.0, gap)
	var j := 1
	var sd := s0
	while sd < total - 30.0:
		while j < n - 1 and lens[j] < sd:
			j += 1
		var seg := maxf(lens[j] - lens[j - 1], 0.001)
		var u := clampf((sd - lens[j - 1]) / seg, 0.0, 1.0)
		var pt := path[j - 1].lerp(path[j], u)
		var tg := (path[j] - path[j - 1]).normalized()
		var nn := Vector2(-tg.y, tg.x)
		var fade := clampf(sd / 50.0, 0.0, 1.0) * clampf((total - 30.0 - sd) / 30.0, 0.0, 1.0)
		var w := 5.0
		draw_polyline(PackedVector2Array([pt - tg * 4 + nn * w, pt + tg * 3, pt - tg * 4 - nn * w]), Color(PAPER, 0.85 * fade), 2.5, true)
		sd += gap
	# 矢じり（ターゲットの縁に刺さる）
	var tip := path[n - 1]
	var tg2 := (path[n - 1] - path[n - 3]).normalized()
	var nn2 := Vector2(-tg2.y, tg2.x)
	var head := PackedVector2Array([tip + tg2 * 6, tip - tg2 * 22 + nn2 * 14, tip - tg2 * 15, tip - tg2 * 22 - nn2 * 14])
	var outline := PackedVector2Array([tip + tg2 * 10, tip - tg2 * 25 + nn2 * 18, tip - tg2 * 17, tip - tg2 * 25 - nn2 * 18])
	draw_colored_polygon(outline, Color(0, 0, 0, 0.55))
	draw_colored_polygon(head, Color(col, 0.95))
	draw_polyline(PackedVector2Array([tip + tg2 * 6, tip - tg2 * 22 + nn2 * 14]), Color(PAPER, 0.9), 2.0, true)
	# 足元の印
	draw_polyline(_ring_pts(from, 26, 9, 20), Color(col, 0.75), 2.5, true)


## 回り込む敵：今の位置から移動先への点線
func _draw_move_hint(it: Dictionary) -> void:
	var dest: Vector2 = it.move_to
	var cur := dest
	for e in CurrentStatus.enemies:
		if int(e.hp) > 0 and e.get("move_to") != null and Vector2(e.move_to).distance_to(dest) < 1.0:
			cur = e.pos
	if cur.distance_to(dest) < 8:
		return
	var dir := (dest - cur).normalized()
	var len := cur.distance_to(dest)
	var off := fmod(_t * 60.0, 24.0)
	var s := off
	while s < len - 26.0:
		var a := cur + dir * maxf(s, 18.0)
		var b := cur + dir * minf(s + 12.0, len - 26.0)
		draw_line(a, b, Color(PAPER, 0.7), 3.0, true)
		s += 24.0
	var tip := dest - dir * 26.0
	var nn := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([tip, tip - dir * 14 + nn * 9, tip - dir * 14 - nn * 9]), Color(PAPER, 0.8))
	# 移動先のゴースト（点線の輪）
	for k in 12:
		var a0 := TAU * k / 12.0 + _t
		var p0 := dest + Vector2(cos(a0) * 30, sin(a0) * 10)
		var p1 := dest + Vector2(cos(a0 + 0.3) * 30, sin(a0 + 0.3) * 10)
		draw_line(p0, p1, Color(PAPER, 0.7), 2.0, true)


# ============================================================
# 動き
# ============================================================

func _kill(node: Node, key: String) -> void:
	if node.has_meta(key):
		var tw: Tween = node.get_meta(key)
		if tw != null and tw.is_valid():
			tw.kill()
		node.remove_meta(key)


func _home(view: Node2D) -> Vector2:
	var gv := view as GuiUnit
	if gv != null and gv.data.has("pos"):
		return gv.data.pos
	return view.position


func enemy_attack(view: Node2D, target_pos: Vector2, hit: Callable, move_to = null) -> float:
	_kill(view, "fx_tw")
	var home := _home(view)
	if move_to != null:
		home = move_to
	var start := view.position
	var tw := view.create_tween()
	view.set_meta("fx_tw", tw)
	var total := 0.0
	if move_to != null and start.distance_to(home) > 4:
		# 横へダッシュして回り込む（移動先に留まる）
		var dash_dir := (home - start).normalized()
		top.dust(start, -dash_dir)
		tw.tween_property(view, "scale", Vector2(1.15, 0.88), 0.05)
		tw.tween_property(view, "position", home, 0.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(view, "scale", Vector2(0.92, 1.08), 0.1)
		tw.tween_callback(func(): top.dust(home, dash_dir))
		tw.tween_property(view, "scale", Vector2.ONE, 0.07)
		total += 0.32
		var segs := 5
		for i in segs:
			var a := start.lerp(home, float(i) / segs)
			var b := start.lerp(home, float(i + 1) / segs)
			top.streak(a + Vector2(0, -40), b + Vector2(0, -40), Color(PAPER, 0.5), 10.0, 0.18 + i * 0.03, 0.05)
	# 狙う側へ横に踏み込んで打つ
	var d := target_pos - home
	var side := 0.0
	if absf(d.x) > 24:
		side = signf(d.x)
	var step := Vector2(side * 78.0, clampf(d.y * 0.32, 20.0, 110.0))
	var to := home + step
	var back := home - step.normalized() * 16.0
	tw.tween_property(view, "position", back, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(view, "scale", Vector2(1.12, 0.9), 0.12)
	tw.tween_property(view, "position", to, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(view, "scale", Vector2(0.9, 1.1), 0.08)
	tw.tween_callback(func():
		top.streak(back + Vector2(0, -50), to + Vector2(0, -50), Color(PAPER, 0.7), 16.0, 0.14)
		if hit.is_valid():
			hit.call())
	tw.tween_interval(0.08)
	tw.tween_property(view, "position", home, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(view, "scale", Vector2.ONE, 0.18)
	total += 0.12 + 0.08 + 0.08 + 0.18
	return total


func ally_attack(view: Node2D, target_pos: Vector2, hit: Callable) -> float:
	_kill(view, "fx_tw")
	var home := _home(view)
	view.position = home
	view.scale = Vector2.ONE
	var dir := (target_pos - home)
	var dist := maxf(0.0, dir.length() - 120.0)
	var to := home + dir.normalized() * minf(dist, 260.0)
	var back := home - dir.normalized() * 14.0
	var tw := view.create_tween()
	view.set_meta("fx_tw", tw)
	tw.tween_property(view, "position", back, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(view, "scale", Vector2(1.12, 0.9), 0.07)
	tw.tween_property(view, "position", to, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(view, "scale", Vector2(0.88, 1.12), 0.08)
	tw.tween_callback(func():
		top.streak(back + Vector2(0, -60), to + Vector2(0, -60), Color(PAPER, 0.75), 18.0, 0.12)
		if hit.is_valid():
			hit.call())
	tw.tween_interval(0.05)
	tw.tween_property(view, "position", home, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(view, "scale", Vector2.ONE, 0.16)
	return 0.36


func cast(view: Node2D, hit: Callable) -> float:
	_kill(view, "fx_tw")
	var home := _home(view)
	view.position = home
	var tw := view.create_tween()
	view.set_meta("fx_tw", tw)
	top.ring(home, 20.0, 110.0, 0.3, Color(PAPER, 0.9), 5.0, 0.3)
	top.ring(home, 10.0, 80.0, 0.26, Color(RED, 0.9), 4.0, 0.3)
	top.sparks(home + Vector2(0, -20), 10, 260.0, [PAPER, RED], Vector2.UP, 0.7)
	tw.tween_property(view, "scale", Vector2(1.14, 0.86), 0.05)
	tw.tween_property(view, "position", home + Vector2(0, -24), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(view, "scale", Vector2(0.9, 1.12), 0.09)
	if hit.is_valid():
		tw.tween_callback(hit)
	tw.tween_property(view, "position", home, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(view, "scale", Vector2.ONE, 0.14)
	return 0.3


# ============================================================
# 当たり
# ============================================================

func hit(view: Node2D, damage: int, blocked: int, kind: String) -> void:
	if not is_instance_valid(view):
		return
	var gv := view as GuiUnit
	var bh := 120.0
	var is_enemy := true
	if gv != null:
		bh = gv.body_height()
		is_enemy = gv.data.get("side", "") == "enemy"
	var c := view.position + Vector2(0, -bh * 0.5)
	var away := Vector2(randf_range(-0.3, 0.3), -1.0 if is_enemy else 1.0).normalized()
	var num_at := view.position + Vector2(randf_range(-22, 22), -bh * 0.6)
	if kind == "tick":
		top.sparks(c, 8, 240.0, [Color("ffa060"), SPARK_GOLD], Vector2.UP, 1.4)
		top.boom(c, 26.0, 0.1, Color("ffa060"))
		top.text(num_at, "火傷 -%d" % damage, 30, Color("ffb070"), INK, false, 0.55)
		_impact(view, Color(1.8, 0.9, 0.5), away, 5.0)
		shake(3.0)
		return
	if damage <= 0:
		if blocked > 0:
			top.ring(c, 18.0, 90.0, 0.2, Color(ImageController.COL.shield, 0.9), 6.0)
			top.sparks(c, 8, 300.0, [ImageController.COL.shield, PAPER], Vector2.ZERO, PI)
			top.text(num_at, "ブロック", 30, ImageController.COL.shield, INK, false, 0.55)
			_impact(view, Color(1.2, 1.4, 1.8), away, 4.0)
			shake(3.0)
		return
	var power := clampf(damage / 30.0, 0.0, 1.0)
	var big := damage >= 15
	hitstop(0.05 + 0.06 * power)
	shake(minf(5.0 + damage * 0.75, 26.0))
	_impact(view, Color(1.9, 0.45, 0.45), away, 10.0 + 14.0 * power)
	var col_sp: Array = [PAPER, SPARK_GOLD, RED, PAPER]
	if kind == "slash":
		var ang := randf_range(-0.9, -0.5) + (PI if randf() < 0.5 else 0.0)
		top.slash(c, ang, 200.0 + 90.0 * power, 18.0 + 10.0 * power, 0.17)
		top.boom(c, 38.0 + 34.0 * power, 0.13, RED)
		top.sparks(c, 14 + int(12 * power), 560.0 + 300.0 * power, col_sp, Vector2.from_angle(ang), 0.5)
		top.sparks(c, 6, 380.0, col_sp, Vector2.ZERO, PI)
	else:
		top.boom(c, 52.0 + 40.0 * power, 0.16, RED)
		top.ring(c, 26.0, 170.0 + 90.0 * power, 0.24, Color(RED, 0.9), 7.0)
		top.sparks(c, 16 + int(12 * power), 520.0 + 260.0 * power, col_sp, Vector2.ZERO, PI)
	top.ring(c, 16.0, 120.0 + 80.0 * power, 0.18, Color(PAPER, 0.95), 5.0)
	var size := int(54 + minf(damage, 40) * 1.4)
	top.text(num_at, str(damage), size, RED if big else PAPER, INK, true, 0.62, big)
	if blocked > 0:
		top.text(num_at + Vector2(0, 40), "ブロック %d" % blocked, 22, ImageController.COL.shield, INK, false, 0.5)
	if big:
		top.flash(Color(1, 1, 1, 0.38), 0.06, 0.0)
		top.flash(Color(RED, 0.22), 0.16, 0.05)


## 被弾した体の白→赤の点滅・押し返し・つぶれ
func _impact(view: Node2D, col: Color, away: Vector2, amt: float) -> void:
	_kill(view, "fx_hit_tw")
	var tw := view.create_tween().set_parallel(true)
	view.set_meta("fx_hit_tw", tw)
	tw.tween_property(view, "modulate", Color(6, 6, 6, view.modulate.a), 0.03)
	tw.tween_property(view, "modulate", Color(col.r, col.g, col.b, view.modulate.a), 0.07).set_delay(0.03)
	tw.tween_property(view, "modulate", Color(1, 1, 1, view.modulate.a), 0.12).set_delay(0.1)
	if "kick" in view:
		tw.tween_property(view, "kick", away * amt, 0.04).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(view, "kick", Vector2.ZERO, 0.24).set_delay(0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not view.has_meta("fx_tw") or not (view.get_meta("fx_tw") as Tween).is_valid():
		tw.tween_property(view, "scale", Vector2(1.16, 0.84), 0.04)
		tw.tween_property(view, "scale", Vector2(0.94, 1.07), 0.08).set_delay(0.04)
		tw.tween_property(view, "scale", Vector2.ONE, 0.1).set_delay(0.12)


func popup(view: Node2D, text: String, color: Color, size: int = 28) -> void:
	if not is_instance_valid(view):
		return
	var bh := 120.0
	if view is GuiUnit:
		bh = (view as GuiUnit).body_height()
	top.text(view.position + Vector2(randf_range(-10, 10), -bh * 0.7), text, size, color, INK, false, 0.8)


# ============================================================
# 撃破：ピンボールのように壁で跳ね返ってから消える
# ============================================================

func knockout(view: Node2D, from_pos: Vector2) -> void:
	if not is_instance_valid(view):
		return
	_kill(view, "fx_tw")
	_kill(view, "fx_hit_tw")
	for f in _flyers:
		if f.view == view:
			return
	var bh := 120.0
	if view is GuiUnit:
		var gv := view as GuiUnit
		bh = gv.body_height()
		gv.flying = true
		gv.kick = Vector2.ZERO
	view.scale = Vector2.ONE
	view.modulate = Color(4, 4, 4, 1)
	var h := bh * 0.5
	var c := view.position + Vector2(0, -h)
	var dir := c - from_pos
	if dir.length() < 1:
		dir = Vector2.UP
	dir = dir.normalized().rotated(randf_range(-0.35, 0.35))
	if absf(dir.x) < 0.45:
		dir.x = 0.45 * (signf(dir.x) if dir.x != 0 else (1.0 if randf() < 0.5 else -1.0))
		dir = dir.normalized()
	view.z_index = 800
	_flyers.append({
		"view": view, "c": c, "v": dir * randf_range(1700.0, 1950.0), "rot": 0.0,
		"w": randf_range(16.0, 22.0) * signf(dir.x), "h": h, "r": clampf(bh * 0.32, 26.0, 64.0),
		"n": 0, "t": 0.0, "home": view.position,
	})
	top.boom(c, 70.0, 0.16, RED)
	top.ring(c, 20.0, 200.0, 0.25, Color(PAPER, 0.95), 8.0)
	top.sparks(c, 20, 700.0, [PAPER, SPARK_GOLD, RED], dir, 0.8)
	shake(12.0)


func _update_flyers(delta: float) -> void:
	for i in range(_flyers.size() - 1, -1, -1):
		var f: Dictionary = _flyers[i]
		var view: Node2D = f.view
		if not is_instance_valid(view):
			_flyers.remove_at(i)
			continue
		f.t = float(f.t) + delta
		var t: float = f.t
		if t < 0.05:  # 吹き飛ぶ直前の一瞬の溜め
			continue
		var c: Vector2 = f.c
		var vel: Vector2 = f.v
		var r: float = f.r
		var prev := c
		c += vel * delta
		var hit_p := Vector2.INF
		var nrm := Vector2.ZERO
		if c.x < WALL.position.x + r:
			c.x = WALL.position.x + r
			vel.x = absf(vel.x)
			hit_p = Vector2(WALL.position.x, c.y)
			nrm = Vector2.RIGHT
		elif c.x > WALL.end.x - r:
			c.x = WALL.end.x - r
			vel.x = -absf(vel.x)
			hit_p = Vector2(WALL.end.x, c.y)
			nrm = Vector2.LEFT
		if c.y < WALL.position.y + r:
			c.y = WALL.position.y + r
			vel.y = absf(vel.y)
			hit_p = Vector2(c.x, WALL.position.y)
			nrm = Vector2.DOWN
		elif c.y > WALL.end.y - r:
			c.y = WALL.end.y - r
			vel.y = -absf(vel.y)
			hit_p = Vector2(c.x, WALL.end.y)
			nrm = Vector2.UP
		if hit_p != Vector2.INF:
			f.n = int(f.n) + 1
			vel = vel.rotated(randf_range(-0.15, 0.15)) * 0.93
			f.w = -float(f.w) * randf_range(0.9, 1.2)
			top.wall_hit(hit_p, nrm)
			shake(7.0)
			view.modulate = Color(4, 4, 4, 1)
		f.c = c
		f.v = vel
		f.rot = float(f.rot) + float(f.w) * delta
		top.streak(prev, c, Color(PAPER, 0.55), r * 0.9, 0.14)
		var rot: float = f.rot
		view.rotation = rot
		view.position = c + Vector2(0, float(f.h)).rotated(rot)
		view.modulate = view.modulate.lerp(Color(1.3, 1.3, 1.3, 1), minf(1.0, delta * 12.0))
		if int(f.n) >= 4 or t > 1.25:
			top.boom(c, 90.0, 0.2, RED)
			top.ring(c, 30.0, 220.0, 0.3, Color(PAPER, 0.95), 9.0)
			top.ring(c, 20.0, 160.0, 0.26, Color(RED, 0.9), 6.0)
			top.sparks(c, 26, 820.0, [PAPER, SPARK_GOLD, RED, INK], Vector2.ZERO, PI)
			shake(10.0)
			view.visible = false
			view.rotation = 0.0
			view.position = f.home
			view.modulate = Color(1, 1, 1, 0)
			_flyers.remove_at(i)


# ============================================================
# カットイン・揺れ・ヒットストップ
# ============================================================

func cut_in(char_id: String, special_name: String) -> void:
	if ui == null or ImageController.light_mode:
		return  # ライトモードではカットインを出さない
	if is_instance_valid(_cut):
		_cut.queue_free()
	var c := GuiCutIn.new()
	c.setup(char_id, special_name)
	ui.add_child(c)
	_cut = c


func shake(amount: float) -> void:
	if ImageController.light_mode:
		return  # ライトモードでは画面を揺らさない
	shake_amt = clampf(maxf(shake_amt, amount), 0.0, 30.0)


## 時間をほぼ止める（実時間 sec 秒）。重なった時は長い方に合わせ、終わったら元の速さに戻す
func hitstop(sec: float) -> void:
	if not _ts_on:
		_ts_base = Engine.time_scale
		_ts_on = true
	_stop_until = maxi(_stop_until, Time.get_ticks_msec() + int(clampf(sec, 0.0, 0.15) * 1000.0))
	Engine.time_scale = _ts_base * 0.05


func _update_timescale() -> void:
	if _ts_on and Time.get_ticks_msec() >= _stop_until:
		Engine.time_scale = _ts_base
		_ts_on = false


## 漫画風の文字（赤い影・黒い太縁・白の内縁）。center を中心に描く
static func comic_text(ci: CanvasItem, s: String, center: Vector2, size: int, fill: Color, outer: Color,
		inner: bool = false, shadow: Color = Color.TRANSPARENT, max_w: float = -1.0) -> void:
	var f: Font = ImageController.font_bold
	var fs := size
	if max_w > 0:
		while fs > 10 and f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
			fs -= 2
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := center + Vector2(-w / 2.0, (f.get_ascent(fs) - f.get_descent(fs)) / 2.0)
	var ow := maxi(4, int(fs * 0.26))
	if shadow.a > 0:
		var sh := Vector2(1, 1) * maxf(3.0, fs * 0.09)
		ci.draw_string_outline(f, pos + sh, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ow, shadow)
		ci.draw_string(f, pos + sh, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, shadow)
	ci.draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ow, outer)
	if inner:
		ci.draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, int(fs * 0.1)), PAPER)
	ci.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fill)


# ============================================================
# 手前に描く一瞬の演出（火花・斬撃・爆発・数字・フラッシュ）をまとめて描くノード
# ============================================================

class FxTop extends Node2D:
	const MAX_PARTS := 280
	var parts: Array = []  # 火花 {p, v, life, max, col, w}
	var rings: Array = []  # 衝撃波 {p, r0, r1, life, max, col, w, sy}
	var booms: Array = []  # 漫画風の爆発 {p, r, life, max, shape, col}
	var slashes: Array = []  # 斬撃 {p, ang, len, w, life, max}
	var streaks: Array = []  # 残像の線 {a, b, col, w, life, max}
	var texts: Array = []  # 文字 {p, s, size, fill, outer, dmg, big, rot, life, max}
	var flashes: Array = []  # 画面フラッシュ {col, life, max}（life が負の間は待ち）

	func sparks(p: Vector2, n: int, speed: float, cols: Array, dir: Vector2, spread: float) -> void:
		if ImageController.light_mode:
			n = mini(n, 4)  # ライトモード：火花は少しだけ
		for i in n:
			if parts.size() >= MAX_PARTS:
				return
			var a := randf() * TAU if dir == Vector2.ZERO else dir.angle() + randf_range(-spread, spread)
			var sp := speed * randf_range(0.45, 1.15)
			var mx := randf_range(0.18, 0.34)
			parts.append({"p": p, "v": Vector2.from_angle(a) * sp, "life": 0.0, "max": mx,
				"col": cols[i % cols.size()], "w": randf_range(2.5, 5.5)})

	func ring(p: Vector2, r0: float, r1: float, mx: float, col: Color, w: float, sy: float = 1.0) -> void:
		rings.append({"p": p, "r0": r0, "r1": r1, "life": 0.0, "max": mx, "col": col, "w": w, "sy": sy})

	func boom(p: Vector2, r: float, mx: float, col: Color) -> void:
		var shape := PackedVector2Array()
		var n := 14
		var rot := randf() * TAU
		for i in n * 2:
			var rr := 1.0 if i % 2 == 0 else randf_range(0.42, 0.6)
			if i % 2 == 0:
				rr *= randf_range(0.8, 1.15)
			shape.append(Vector2.from_angle(rot + PI * i / n) * rr)
		booms.append({"p": p, "r": r, "life": 0.0, "max": mx, "shape": shape, "col": col})

	func slash(p: Vector2, ang: float, len: float, w: float, mx: float) -> void:
		slashes.append({"p": p, "ang": ang, "len": len, "w": w, "life": 0.0, "max": mx})

	func streak(a: Vector2, b: Vector2, col: Color, w: float, mx: float, delay: float = 0.0) -> void:
		if streaks.size() > 80:
			return
		streaks.append({"a": a, "b": b, "col": col, "w": w, "life": -delay, "max": mx})

	func text(p: Vector2, s: String, size: int, fill: Color, outer: Color, dmg: bool, mx: float, big: bool = false) -> void:
		texts.append({"p": p, "s": s, "size": size, "fill": fill, "outer": outer, "dmg": dmg, "big": big,
			"rot": randf_range(-0.16, 0.16) if dmg else randf_range(-0.05, 0.05), "life": 0.0, "max": mx})

	func flash(col: Color, mx: float, delay: float) -> void:
		if flashes.size() >= 4 or ImageController.light_mode:
			return
		flashes.append({"col": col, "life": -delay, "max": mx})

	## 壁にぶつかった時の火花
	func wall_hit(p: Vector2, nrm: Vector2) -> void:
		sparks(p, 14, 620.0, [BattleFx.PAPER, BattleFx.SPARK_GOLD, BattleFx.RED], nrm, 1.1)
		boom(p, 40.0, 0.12, BattleFx.RED)
		ring(p, 10.0, 90.0, 0.18, Color(BattleFx.PAPER, 0.9), 5.0)

	## 足元の土煙
	func dust(p: Vector2, dir: Vector2) -> void:
		for i in 7:
			if parts.size() >= MAX_PARTS:
				return
			var a := dir.angle() + randf_range(-0.6, 0.6)
			parts.append({"p": p + Vector2(randf_range(-20, 20), -4), "v": Vector2.from_angle(a) * randf_range(80, 220) + Vector2(0, -40),
				"life": 0.0, "max": randf_range(0.2, 0.32), "col": Color(0.85, 0.82, 0.78, 0.7), "w": randf_range(5.0, 9.0)})

	func _age(arr: Array, delta: float) -> void:
		for i in range(arr.size() - 1, -1, -1):
			var d: Dictionary = arr[i]
			d.life = float(d.life) + delta
			if float(d.life) >= float(d.max):
				arr.remove_at(i)

	var _last_us := 0

	## ヒットストップ中も火花・数字は実時間で動かす（止まるのはキャラだけ）。重いフレームでも演出を飛ばさない
	func _process(_delta: float) -> void:
		var now := Time.get_ticks_usec()
		var delta := 0.016 if _last_us == 0 else clampf((now - _last_us) / 1000000.0, 0.0, 0.05)
		_last_us = now
		for d in parts:
			var v: Vector2 = d.v
			d.p = Vector2(d.p) + v * delta
			d.v = v * maxf(0.0, 1.0 - delta * 5.0) + Vector2(0, 900.0 * delta)
		_age(parts, delta)
		_age(rings, delta)
		_age(booms, delta)
		_age(slashes, delta)
		_age(streaks, delta)
		_age(texts, delta)
		_age(flashes, delta)
		queue_redraw()

	func _draw() -> void:
		for d in streaks:
			var life: float = d.life
			if life < 0:
				continue
			var k: float = life / float(d.max)
			var col: Color = d.col
			var w: float = d.w
			draw_line(d.a, d.b, Color(col, col.a * 0.35 * (1.0 - k)), maxf(1.0, w * (1.0 - k)), true)
			draw_line(d.a, d.b, Color(col, col.a * (1.0 - k)), maxf(1.0, w * 0.3 * (1.0 - k)), true)
		for d in rings:
			var k: float = float(d.life) / float(d.max)
			var e := 1.0 - pow(1.0 - k, 3.0)
			var r := lerpf(float(d.r0), float(d.r1), e)
			var col: Color = d.col
			var sy: float = d.sy
			draw_set_transform(d.p, 0.0, Vector2(1, sy))
			draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(col, col.a * (1.0 - k)), maxf(1.0, float(d.w) * (1.0 - k)), true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for d in slashes:
			var k: float = float(d.life) / float(d.max)
			var grow := minf(1.0, k / 0.25)
			var len: float = float(d.len) * grow
			var w: float = float(d.w) * (1.0 - k * 0.85)
			var dirv := Vector2.from_angle(float(d.ang))
			var nn := Vector2(-dirv.y, dirv.x)
			var p: Vector2 = d.p
			var a := p - dirv * float(d.len) * 0.5
			var b := a + dirv * len
			var mid := a.lerp(b, 0.55)
			draw_colored_polygon(PackedVector2Array([a - dirv * 6, mid + nn * (w + 6), b + dirv * 10, mid - nn * (w + 6)]), Color(BattleFx.INK, 0.85 * (1.0 - k)))
			draw_colored_polygon(PackedVector2Array([a, mid + nn * (w + 2), b + dirv * 6, mid - nn * (w + 2)]), Color(BattleFx.RED, 1.0 - k))
			draw_colored_polygon(PackedVector2Array([a, mid + nn * w * 0.55, b, mid - nn * w * 0.55]), Color(BattleFx.PAPER, 1.0 - k * 0.6))
		for d in booms:
			var k: float = float(d.life) / float(d.max)
			var sc: float = float(d.r) * (0.5 + 0.7 * minf(1.0, k / 0.3)) * (1.0 - 0.25 * k)
			var shape: PackedVector2Array = d.shape
			var a := 1.0 - maxf(0.0, (k - 0.5) / 0.5)
			draw_set_transform(d.p, 0.0, Vector2(sc, sc) * 1.16)
			draw_colored_polygon(shape, Color(BattleFx.INK, a))
			draw_set_transform(d.p, 0.0, Vector2(sc, sc))
			draw_colored_polygon(shape, Color(BattleFx.PAPER, a))
			draw_set_transform(d.p, 0.3, Vector2(sc, sc) * 0.55)
			draw_colored_polygon(shape, Color(d.col, a))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for d in parts:
			var k: float = float(d.life) / float(d.max)
			var v: Vector2 = d.v
			var p: Vector2 = d.p
			var col: Color = d.col
			var tail := v * 0.025
			draw_line(p, p - tail, Color(col, col.a * (1.0 - k)), float(d.w) * (1.0 - k * 0.6), true)
		for d in texts:
			_draw_text(d)
		for d in flashes:
			var life: float = d.life
			if life < 0:
				continue
			var k: float = life / float(d.max)
			var col: Color = d.col
			draw_rect(Rect2(-40, -40, 800, 702), Color(col, col.a * (1.0 - k)))

	func _draw_text(d: Dictionary) -> void:
		var life: float = d.life
		var k: float = life / float(d.max)
		var dmg: bool = d.dmg
		var s := 1.0
		var off := Vector2.ZERO
		if dmg:
			# 大きく出て → 縮み → 少し跳ねて落ち着く
			if life < 0.05:
				s = lerpf(2.3, 0.82, life / 0.05)
			elif life < 0.12:
				s = lerpf(0.82, 1.1, (life - 0.05) / 0.07)
			elif life < 0.2:
				s = lerpf(1.1, 1.0, (life - 0.12) / 0.08)
			off.y = -34.0 * sin(minf(1.0, life / 0.22) * PI * 0.5) + 10.0 * maxf(0.0, life - 0.22)
		else:
			if life < 0.08:
				s = lerpf(0.4, 1.12, life / 0.08)
			elif life < 0.14:
				s = lerpf(1.12, 1.0, (life - 0.08) / 0.06)
			off.y = -50.0 * (1.0 - pow(1.0 - k, 2.0))
		var a := 1.0 if k < 0.72 else (1.0 - k) / 0.28
		var p: Vector2 = d.p
		draw_set_transform(p + off, float(d.rot), Vector2(s, s))
		var fill: Color = d.fill
		var outer: Color = d.outer
		var big: bool = d.big
		var shadow := Color(BattleFx.INK, a) if big else Color(BattleFx.RED, a)
		if not dmg:
			shadow = Color.TRANSPARENT
		BattleFx.comic_text(self, d.s, Vector2.ZERO, int(d.size), Color(fill, a), Color(outer, a), big, shadow)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
