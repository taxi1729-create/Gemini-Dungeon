extends Node

# --- シグナル ---
signal flick_started(start_pos: Vector2)
signal flick_changed(num: int) # 1~9 (5は中央/デッドゾーン)
signal flick_executed(num: int)
signal flick_canceled

# --- 設定値 ---
@export var DEADZONE: float = 60.0       # この距離以内は「5（中央）」と判定
@export var ACTIVATION_DIST: float = 20.0 # 指がこれ以上動いたらフリック開始とみなす

# --- 内部状態 ---
var start_pos: Vector2 = Vector2.ZERO
var is_active: bool = false
var current_num: int = 5
var is_enabled: bool = true # 入力を受け付けるかどうか（演出中などはfalseに）

func _input(event: InputEvent):
	if not is_enabled: return
	
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		if event.pressed:
			_on_press_start(event.position)
		else:
			_on_press_end()

	elif (event is InputEventMouseMotion or event is InputEventScreenDrag) and is_active:
		_on_drag(event.position)

func _on_press_start(pos: Vector2):
	start_pos = pos
	is_active = true
	current_num = 5
	flick_started.emit(start_pos)

func _on_drag(current_pos: Vector2):
	var diff = current_pos - start_pos
	var dist = diff.length()
	
	var new_num = 5
	if dist > DEADZONE:
		# 角度からテンキー番号を算出 (-180 ~ 180度)
		var angle = rad_to_deg(diff.angle())
		new_num = _get_num_from_angle(angle)
	
	if new_num != current_num:
		current_num = new_num
		flick_changed.emit(current_num)

func _on_press_end():
	if not is_active: return
	
	if current_num != 5:
		flick_executed.emit(current_num)
	else:
		flick_canceled.emit()
		
	is_active = false
	current_num = 5

# 角度をテンキーに対応させる (8方向)
func _get_num_from_angle(angle: float) -> int:
	if angle >= -112.5 and angle < -67.5: return 8 # 上
	if angle >= 67.5 and angle < 112.5: return 2   # 下
	if angle >= -22.5 and angle < 22.5: return 6    # 右
	if angle >= 157.5 or angle < -157.5: return 4   # 左
	if angle >= -67.5 and angle < -22.5: return 9   # 右上
	if angle >= -157.5 and angle < -112.5: return 7 # 左上
	if angle >= 22.5 and angle < 67.5: return 3     # 右下
	if angle >= 112.5 and angle < 157.5: return 1   # 左下
	return 5
