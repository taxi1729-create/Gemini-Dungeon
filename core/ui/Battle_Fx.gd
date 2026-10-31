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

const LANE_COL := [Color("3d8bff"), Color("ff3b3b")]  # 左＝青、右＝赤

var battle: Node
var field: Node2D
var ui: CanvasLayer
var lanes: Array = [Vector2(230, 600), Vector2(490, 600)]
var intents: Array = []
var shake_amt := 0.0
var _hitstop_on := false
var _t := 0.0


func setup(b: Node, f: Node2D, u: CanvasLayer) -> void:
	battle = b
	field = f
	ui = u
	z_index = 1  # 地面のターゲットと矢印はキャラより奥（キャラは y 座標順の z_index）


func set_lanes(left_pos: Vector2, right_pos: Vector2) -> void:
	lanes = [left_pos, right_pos]
	queue_redraw()


func set_intents(list: Array) -> void:
	intents = list
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if shake_amt > 0.1:
		field.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt
		shake_amt = lerpf(shake_amt, 0.0, minf(1.0, delta * 14.0))
	else:
		field.position = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	for i in 2:
		var p: Vector2 = lanes[i]
		draw_colored_polygon(ImageController.ell(p, 70, 20), Color(LANE_COL[i], 0.25))
		draw_arc(p, 1, 0, TAU, 4, Color.TRANSPARENT)
	for it in intents:
		for lane in it.lanes:
			var a: Vector2 = it.from
			var b: Vector2 = lanes[lane]
			draw_line(a, b, Color(LANE_COL[lane], 0.7), 6, true)


func enemy_attack(view: Node2D, target_pos: Vector2, hit: Callable, move_to = null) -> float:
	if move_to != null:
		view.position = move_to
	AnimationController.lunge(view, target_pos, 60, hit)
	return 0.5


func ally_attack(view: Node2D, target_pos: Vector2, hit: Callable) -> float:
	AnimationController.lunge(view, target_pos, 60, hit)
	return 0.45


func cast(view: Node2D, hit: Callable) -> float:
	AnimationController.hop(view, 20, hit)
	return 0.4


func hit(view: Node2D, damage: int, blocked: int, kind: String) -> void:
	var head: Vector2 = view.position + Vector2(0, -view.body_height() * 0.6)
	if kind == "tick":
		AnimationController.popup_text(field, head, "火傷 -%d" % damage, Color("ffa060"))
		return
	GuiFx.spawn(field, "slash" if kind == "slash" else "burst", head, Color("ffd0a0"))
	if damage > 0:
		AnimationController.popup_text(field, head, str(damage), Color("ff4040"), 34 + mini(damage, 30))
		AnimationController.flash(view, Color(2, 0.5, 0.5))
		shake(clampf(4.0 + damage * 0.5, 4.0, 24.0))
		hitstop(0.05 + minf(damage, 40) * 0.0015)
	elif blocked > 0:
		AnimationController.popup_text(field, head, "ブロック", Color("8fc0ea"), 28)


func popup(view: Node2D, text: String, color: Color, size: int = 28) -> void:
	AnimationController.popup_text(field, view.position + Vector2(0, -view.body_height() * 0.6), text, color, size)


func knockout(view: Node2D, from_pos: Vector2) -> void:
	var tw := view.create_tween()
	tw.tween_property(view, "modulate:a", 0.0, 0.4)


func cut_in(char_id: String, special_name: String) -> void:
	UiSystem.toast(ui, special_name, 500)


func shake(amount: float) -> void:
	shake_amt = maxf(shake_amt, amount)


func hitstop(sec: float) -> void:
	if _hitstop_on:
		return
	_hitstop_on = true
	var base := Engine.time_scale
	Engine.time_scale = base * 0.06
	await get_tree().create_timer(sec, true, false, true).timeout
	Engine.time_scale = base
	_hitstop_on = false
