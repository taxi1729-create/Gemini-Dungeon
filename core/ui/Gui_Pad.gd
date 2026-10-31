extends Control
class_name GuiPad
## タップ／長押しを判定する土台。カードや戦闘ボタンはこれを継承して見た目を _draw で描く。

signal tapped
signal hold_started
signal hold_ended

const HOLD_TIME := 0.45
const MOVE_CANCEL := 36.0

var enabled := true
var base_scale := 1.0  # 通常時の大きさ
var hover_scale := 1.12  # フリックで選ばれている時の倍率
var interactive := true  # false なら入力を受けない（戦闘の操作エリアはジェスチャーでまとめて処理）
var highlighted := false:
	set(v):
		highlighted = v
		_update_scale()
		queue_redraw()

var _down := false
var _held := false
var _moved := false
var _hold_t := 0.0
var _press_pos := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	pivot_offset = size / 2.0


func _process(delta: float) -> void:
	_t += delta
	if _down and not _held and not _moved:
		_hold_t += delta
		if _hold_t >= HOLD_TIME:
			_held = true
			_update_scale()
			hold_started.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
			_held = false
			_moved = false
			_hold_t = 0.0
			_press_pos = event.position
			_update_scale()
		elif _down:
			_down = false
			var was_held := _held
			_held = false
			_update_scale()
			if was_held:
				hold_ended.emit()
			elif not _moved and Rect2(Vector2.ZERO, size).has_point(event.position):
				tapped.emit()
	elif event is InputEventMouseMotion and _down and not _moved:
		if (event.position - _press_pos).length() > MOVE_CANCEL:
			_moved = true
			if _held:
				_held = false
				hold_ended.emit()
			_update_scale()


func _update_scale() -> void:
	pivot_offset = size / 2.0
	var s := base_scale
	if highlighted or _held:
		s = base_scale * hover_scale
	elif _down and not _moved:
		s = base_scale * 0.95
	z_index = 30 if (highlighted or _held) else 0
	if not is_inside_tree():
		scale = Vector2(s, s)
		return
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(s, s), 0.08)
