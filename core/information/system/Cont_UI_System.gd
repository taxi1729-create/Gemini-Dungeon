extends Node
## UiSystem（Autoload）
## ・画面全体のテーマ（ボタン・パネル・文字）をコードで作る（画像は使わない）
## ・シーン切り替え（フェード付き）
## ・ボタン／ラベル／パネル生成のヘルパー

const SCENES = {
	"title": "res://index/core/title/Title.tscn",
	"map": "res://index/core/map/Map.tscn",
	"battle": "res://index/core/map/battle/battle_scene.tscn",
	"result": "res://index/core/map/battle/battle_result.tscn",
	"rest": "res://index/core/map/rest/camp.tscn",
}

var theme: Theme
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _busy := false


func _ready() -> void:
	theme = _build_theme()
	# CanvasLayer の下にある Control にはルートのテーマが届かないため、
	# エンジン既定のテーマ自体に上書きして全画面に効かせる
	ThemeDB.get_default_theme().merge_with(theme)
	ThemeDB.fallback_font = ImageController.font
	get_tree().root.theme = theme
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade_rect)


# ------------------------------------------------------------
# シーン遷移
# ------------------------------------------------------------
func goto(scene_key: String) -> void:
	if _busy:
		return
	_busy = true
	FlickInput.reset()
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_fade_rect, "color:a", 1.0, 0.22)
	await tw.finished
	get_tree().change_scene_to_file(SCENES[scene_key])
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade_rect, "color:a", 0.0, 0.25)
	await tw2.finished
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


# ------------------------------------------------------------
# テーマ
# ------------------------------------------------------------
func _sb(bg: Color, border: Color, bw: int = 3, radius: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.anti_aliasing = true
	return s


func _build_theme() -> Theme:
	var th := Theme.new()
	var col: Dictionary = ImageController.COL
	th.default_font = ImageController.font
	th.default_font_size = 26
	th.set_stylebox("normal", "Button", _sb(col.panel_hi, col.gold_d))
	th.set_stylebox("hover", "Button", _sb(col.panel_hi.lightened(0.08), col.gold))
	th.set_stylebox("pressed", "Button", _sb(col.panel.darkened(0.2), col.gold))
	th.set_stylebox("disabled", "Button", _sb(Color("1a1d28"), Color("3a3f50")))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", col.text)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", col.gold)
	th.set_color("font_disabled_color", "Button", Color("5c6274"))
	th.set_font("font", "Button", ImageController.font_bold)
	th.set_stylebox("panel", "Panel", _sb(Color(col.panel, 0.96), col.gold_d, 3, 16))
	th.set_stylebox("panel", "PanelContainer", _sb(Color(col.panel, 0.96), col.gold_d, 3, 16))
	th.set_color("font_color", "Label", col.text)
	th.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	th.set_constant("outline_size", "Label", 0)
	th.set_color("default_color", "RichTextLabel", col.text)
	th.set_font("normal_font", "RichTextLabel", ImageController.font)
	th.set_font("bold_font", "RichTextLabel", ImageController.font_bold)
	th.set_font_size("normal_font_size", "RichTextLabel", 22)
	th.set_font_size("bold_font_size", "RichTextLabel", 22)
	return th


# ------------------------------------------------------------
# 部品生成ヘルパー
# ------------------------------------------------------------
func make_button(parent: Node, txt: String, pos: Vector2, sz: Vector2, cb: Callable, font_size: int = 28) -> Button:
	var b := Button.new()
	b.text = txt
	b.position = pos
	b.size = sz
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func make_label(parent: Node, txt: String, pos: Vector2, sz: Vector2, font_size: int = 24,
		col: Color = Color(0, 0, 0, 0), align: int = HORIZONTAL_ALIGNMENT_CENTER, outline: int = 6) -> Label:
	var l := Label.new()
	l.text = txt
	l.position = pos
	l.size = sz
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	if col.a > 0:
		l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func make_panel(parent: Node, rect: Rect2) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	parent.add_child(p)
	return p


## 画面中央に一言を出して自動で消す
func toast(parent: Node, txt: String, y: float = 600.0, col: Color = Color(0, 0, 0, 0)) -> void:
	var l := make_label(parent, txt, Vector2(40, y), Vector2(640, 60), 30, col)
	l.z_index = 50
	l.modulate.a = 0.0
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.12)
	tw.tween_interval(0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)
