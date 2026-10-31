extends Node
## AnimationController（Autoload）
## スプライトシートの代わりに、Tween で動き（踏み込み・揺れ・点滅・数字ポップ）を付ける。


## 対象に向かって踏み込み、元の位置に戻る。踏み込み切った時点で hit コールバックを呼ぶ。
func lunge(node: Node2D, toward: Vector2, dist: float = 70.0, hit: Callable = Callable()) -> Tween:
	var home := node.position
	var dir := (toward - home)
	dir.y *= 0.3
	var to := home + dir.normalized() * dist
	var tw := node.create_tween()
	tw.tween_property(node, "position", home - dir.normalized() * 10, 0.08)
	tw.tween_property(node, "position", to, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if hit.is_valid():
		tw.tween_callback(hit)
	tw.tween_interval(0.06)
	tw.tween_property(node, "position", home, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tw


## その場で跳ねる（全体攻撃・魔法の詠唱など）
func hop(node: Node2D, height: float = 26.0, hit: Callable = Callable()) -> Tween:
	var home := node.position
	var tw := node.create_tween()
	tw.tween_property(node, "position", home + Vector2(0, -height), 0.14).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	if hit.is_valid():
		tw.tween_callback(hit)
	tw.tween_property(node, "position", home, 0.18).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)
	return tw


func shake(node: CanvasItem, amount: float = 8.0, times: int = 4) -> Tween:
	var prop := "position"
	var home = node.get(prop)
	var tw := node.create_tween()
	for i in times:
		var off := Vector2(amount if i % 2 == 0 else -amount, 0)
		tw.tween_property(node, prop, home + off, 0.04)
	tw.tween_property(node, prop, home, 0.04)
	return tw


## 色を一瞬乗せる（被ダメージ＝赤、強化＝水色など）
func flash(node: CanvasItem, col: Color, times: int = 2) -> Tween:
	var tw := node.create_tween()
	for i in times:
		tw.tween_property(node, "modulate", col, 0.07)
		tw.tween_property(node, "modulate", Color.WHITE, 0.09)
	return tw


## 数字や文字を浮かび上がらせて消す
func popup_text(parent: Node, pos: Vector2, txt: String, col: Color, size: int = 34) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", ImageController.font_bold)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(200, 50)
	l.position = pos - Vector2(100, 25)
	l.pivot_offset = Vector2(100, 25)
	l.z_index = 60
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.scale = Vector2(0.4, 0.4)
	parent.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2(1.15, 1.15), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.08)
	tw.parallel().tween_property(l, "position:y", l.position.y - 46, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.25)
	tw.tween_callback(l.queue_free)
