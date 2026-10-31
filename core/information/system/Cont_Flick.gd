extends Node
## FlickInput（Autoload）
## 指（マウス）の移動方向をテンキー番号（1〜9、5は中央）に変換して通知する。
##   7 8 9
##   4 5 6
##   1 2 3
## タッチはブラウザ上でマウスとしても届くため、マウスイベントだけを見る（二重通知を防ぐ）。

signal flick_started(start_pos: Vector2)
signal flick_changed(num: int)
signal flick_executed(num: int)
signal flick_canceled

@export var DEADZONE: float = 60.0  # この距離以内は「5（中央）」

var start_pos := Vector2.ZERO
var is_active := false
var current_num := 5
var is_enabled := false  # 戦闘シーンが有効にする
## この範囲内で押し始めた時だけ判定する（空なら画面全体）
var active_rect := Rect2()


func reset() -> void:
	is_enabled = false
	is_active = false
	current_num = 5
	active_rect = Rect2()


func _input(event: InputEvent) -> void:
	if not is_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if active_rect.size != Vector2.ZERO and not active_rect.has_point(event.position):
				return
			start_pos = event.position
			is_active = true
			current_num = 5
			flick_started.emit(start_pos)
		elif is_active:
			is_active = false
			if current_num != 5:
				var n := current_num
				current_num = 5
				flick_executed.emit(n)
			else:
				flick_canceled.emit()
	elif event is InputEventMouseMotion and is_active:
		var diff: Vector2 = event.position - start_pos
		var n := 5
		if diff.length() > DEADZONE:
			n = _get_num_from_angle(rad_to_deg(diff.angle()))
		if n != current_num:
			current_num = n
			if n == 5:
				flick_canceled.emit()
			else:
				flick_changed.emit(n)


func _get_num_from_angle(angle: float) -> int:
	if angle >= -112.5 and angle < -67.5: return 8
	if angle >= 67.5 and angle < 112.5: return 2
	if angle >= -22.5 and angle < 22.5: return 6
	if angle >= 157.5 or angle < -157.5: return 4
	if angle >= -67.5 and angle < -22.5: return 9
	if angle >= -157.5 and angle < -112.5: return 7
	if angle >= 22.5 and angle < 67.5: return 3
	if angle >= 112.5 and angle < 157.5: return 1
	return 5
