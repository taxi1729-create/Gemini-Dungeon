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
	"event": "res://index/core/map/event/event.tscn",
	"shop": "res://index/core/map/shop/shop.tscn",
	"treasure": "res://index/core/map/treasure/treasure.tscn",
}

var theme: Theme
var _fade_layer: CanvasLayer
var _fade_rect: ColorRect  # 遷移中の入力ブロック（見た目は _wipe が担当）
var _wipe: Control
var _wipe_k := 0.0:  # 0＝画面が見えている、1＝覆い終わり、2＝抜け終わり
	set(v):
		_wipe_k = v
		if _wipe:
			_wipe.queue_redraw()
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
	_wipe = Control.new()
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wipe.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wipe.draw.connect(_draw_wipe)
	_fade_layer.add_child(_wipe)


# ------------------------------------------------------------
# シーン遷移（赤と黒の斜めのワイプ）
# ------------------------------------------------------------
func goto(scene_key: String) -> void:
	if _busy:
		return
	_busy = true
	FlickInput.reset()
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_wipe_k = 0.0
	var tw := create_tween()
	tw.tween_property(self, "_wipe_k", 1.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw.finished
	get_tree().change_scene_to_file(SCENES[scene_key])
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(self, "_wipe_k", 2.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw2.finished
	_wipe_k = 0.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _draw_wipe() -> void:
	if _wipe_k <= 0.0 or _wipe_k >= 2.0:
		return
	var IC = ImageController
	var sz := _wipe.get_viewport_rect().size
	var lean := 360.0  # 上辺が右へずれる量（斜めの角度）
	var edge := 46.0  # 先頭と末尾の赤い帯の幅
	var span := sz.x + lean + edge * 2
	# 左から右へ：先頭（lead）が画面を覆い、続いて末尾（trail）が抜けていく
	var lead := -lean - edge + span * minf(_wipe_k, 1.0)
	var trail := -lean - edge * 2 - 4000.0 if _wipe_k <= 1.0 else -lean - edge + span * (_wipe_k - 1.0)
	var poly := func(x0: float, x1: float) -> PackedVector2Array:
		return PackedVector2Array([Vector2(x0 + lean, 0), Vector2(x1 + lean, 0), Vector2(x1, sz.y), Vector2(x0, sz.y)])
	_wipe.draw_colored_polygon(poly.call(trail + edge, lead - edge), IC.COL.ink)
	_wipe.draw_colored_polygon(poly.call(lead - edge, lead), IC.COL.red)
	_wipe.draw_colored_polygon(poly.call(lead - edge - 14, lead - edge - 8), IC.COL.paper)
	if _wipe_k > 1.0:
		_wipe.draw_colored_polygon(poly.call(trail, trail + edge), IC.COL.red)


# ------------------------------------------------------------
# テーマ
# ------------------------------------------------------------
## 斜めに傾けたボタン用の箱（ベタ影付き）
func _sb_btn(bg: Color, border: Color, shadow: Color, bw: int = 3) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.skew = Vector2(0.22, 0)
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	if shadow.a > 0:
		s.shadow_color = shadow
		s.shadow_size = 1
		s.shadow_offset = Vector2(6, 6)
	s.anti_aliasing = true
	return s


## 角を斜めに落としたパネル用の箱（左上・右下を面取り）
func _sb_panel(bg: Color, border: Color, bw: int = 3, cut: int = 22) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.corner_radius_top_left = cut
	s.corner_radius_bottom_right = cut
	s.corner_detail = 1  # 角丸ではなく直線の面取りにする
	s.shadow_color = Color(ImageController.COL.red, 0.9)
	s.shadow_size = 1
	s.shadow_offset = Vector2(8, 8)
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
	# ボタン：セイクレッドブルーの地＋白枠＋ブラッキッシュブルーのベタ影。押すとディープローズ。
	# ホバーは枠を赤にするだけ（スマホではタップ後もホバー状態が残るため、文字色が変わらないようにする）
	var G: Dictionary = ImageController.GLASS
	th.set_stylebox("normal", "Button", _sb_btn(G.sacred_blue, col.paper, col.ink))
	th.set_stylebox("hover", "Button", _sb_btn(G.sacred_blue.lerp(col.red, 0.2), col.red, col.ink))
	th.set_stylebox("pressed", "Button", _sb_btn(col.red, col.paper, col.ink))
	th.set_stylebox("disabled", "Button", _sb_btn(col.steel, G.ash_gray, Color(0, 0, 0, 0), 2))
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", col.paper)
	th.set_color("font_hover_color", "Button", col.paper)
	th.set_color("font_hover_pressed_color", "Button", col.paper)
	th.set_color("font_pressed_color", "Button", col.paper)
	th.set_color("font_focus_color", "Button", col.paper)
	th.set_color("font_disabled_color", "Button", ImageController.GLASS.holy_blue.darkened(0.25))
	th.set_font("font", "Button", ImageController.font_head)
	th.set_stylebox("panel", "Panel", _sb_panel(Color(col.panel, 0.98), G.holy_blue))
	th.set_stylebox("panel", "PanelContainer", _sb_panel(Color(col.panel, 0.98), G.holy_blue))
	th.set_color("font_color", "Label", col.text)
	th.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.9))
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
	if cb.is_valid():
		b.pressed.connect(cb)
	parent.add_child(b)
	return b


## 目立たせたいボタン（赤地）。make_button の見た目違い
func make_red_button(parent: Node, txt: String, pos: Vector2, sz: Vector2, cb: Callable, font_size: int = 28) -> Button:
	var b := make_button(parent, txt, pos, sz, cb, font_size)
	set_button_red(b, true)
	return b


## ボタンを赤地（選択中・決定）にする／通常の黒地に戻す
func set_button_red(b: Button, on: bool) -> void:
	var col: Dictionary = ImageController.COL
	if on:
		b.add_theme_stylebox_override("normal", _sb_btn(col.red, col.paper, col.ink, 4))
		b.add_theme_stylebox_override("hover", _sb_btn(col.red.lightened(0.08), col.paper, col.ink, 4))
		b.add_theme_stylebox_override("pressed", _sb_btn(col.ink, col.red, col.red, 4))
	else:
		for k in ["normal", "hover", "pressed"]:
			b.remove_theme_stylebox_override(k)


func make_label(parent: Node, txt: String, pos: Vector2, sz: Vector2, font_size: int = 24,
		col: Color = Color(0, 0, 0, 0), align: int = HORIZONTAL_ALIGNMENT_CENTER, outline: int = 6) -> Label:
	var l := Label.new()
	# 折り返しと文字サイズを先に決めてから大きさを入れる（先に size を入れると、
	# 折り返し無しの 1 行幅に引っぱられてラベルが横に広がったままになる）
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_size)
	l.text = txt
	l.position = pos
	l.size = sz
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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


## パネルを明るい「文字の箱」（エンジェルホワイトの面・ブラッキッシュブルーの縁・ローズの影）にする。中の文字は COL.ink で書く
func set_panel_light(p: Panel) -> void:
	var col: Dictionary = ImageController.COL
	var sb := _sb_panel(ImageController.GLASS.angel_white, col.ink)
	p.add_theme_stylebox_override("panel", sb)


## 見出しの帯（斜めの平行四辺形＋極太斜体の文字）。fill＝帯の色、txt_col＝文字の色
func make_banner(parent: Node, txt: String, rect: Rect2, font_size: int = 36,
		fill: Color = Color(0, 0, 0, 0), txt_col: Color = Color(0, 0, 0, 0), skew: float = 22.0) -> Control:
	var col: Dictionary = ImageController.COL
	var f: Color = fill if fill.a > 0 else col.red
	var tc: Color = txt_col if txt_col.a > 0 else col.paper
	var c := Control.new()
	c.position = rect.position
	c.size = rect.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_meta("text", txt)
	c.draw.connect(func():
		var IC = ImageController
		var r := Rect2(Vector2.ZERO, c.size)
		# 黒い帯は白縁＋赤影、それ以外は黒縁＋黒影にして背景から浮かせる
		var dark := f.get_luminance() < 0.2
		IC.slant(c, r, f, skew, 3.0, col.paper if dark else col.ink, col.red if dark else Color(col.ink, 0.9), Vector2(7, 7))
		# 帯の右端にストライプ（ローズの帯は墨、紺の帯はスカイ。白い帯には入れない）
		if f.get_luminance() < 0.6 and c.size.x > 150:
			var sw := Rect2(c.size.x * 0.74, 2, c.size.x * 0.26 - skew - 4, c.size.y - 4)
			IC.stripes(c, sw, Color(col.ink, 0.22) if not dark else Color(IC.GLASS.sacred_sky, 0.14), 12, 4, 0.5)
		# 帯の左端に白い細線を添えてシャープに見せる
		c.draw_colored_polygon(IC.slant_pts(Rect2(-14, 0, 8, c.size.y), skew), col.paper)
		# 文字の影：白文字なら黒（黒帯なら赤）、黒文字なら影なし
		var sh := Color(0, 0, 0, 0)
		if tc.get_luminance() > 0.5 and font_size >= 26:
			sh = col.ink if f != col.ink else col.red
		IC.head(c, str(c.get_meta("text")), r.get_center() + Vector2(0, -1), font_size, tc, c.size.x - skew * 2 - 16, sh, Vector2(3, 3)))
	parent.add_child(c)
	return c


## 白いギザギザ吹き出し（黒縁・赤のベタ影）。tail_to（親の座標）を渡すとしっぽがそちらを向く
func make_bubble(parent: Node, rect: Rect2, tail_to: Vector2 = Vector2(-9999, -9999), seed: int = 0) -> Control:
	var c := Control.new()
	c.position = rect.position
	c.size = rect.size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var local_tail := tail_to - rect.position if tail_to.x > -9000 else tail_to
	c.draw.connect(func():
		ImageController.bubble(c, Rect2(Vector2.ZERO, c.size), local_tail, seed))
	parent.add_child(c)
	return c


## 画面中央に一言を出して自動で消す（黒い斜めの帯が左から滑り込む）
func toast(parent: Node, txt: String, y: float = 600.0, col: Color = Color(0, 0, 0, 0)) -> void:
	var IC = ImageController
	var tc: Color = col if col.a > 0 else IC.COL.paper
	var box := Control.new()
	box.position = Vector2(0, y - 6)
	box.size = Vector2(720, 72)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.z_index = 50
	box.draw.connect(func():
		var r := Rect2(30, 4, 660, 64)
		IC.slant(box, r, Color(IC.COL.ink, 0.95), 26, 3.0, IC.COL.paper, IC.COL.red, Vector2(8, 8))
		box.draw_colored_polygon(IC.slant_pts(Rect2(r.position.x + 18, r.position.y, 12, r.size.y), 26), IC.COL.red))
	parent.add_child(box)
	var l := make_label(box, txt, Vector2(70, 6), Vector2(600, 60), 28, tc, HORIZONTAL_ALIGNMENT_CENTER, 4)
	l.add_theme_font_override("font", IC.font_head)
	box.modulate.a = 0.0
	box.position.x = -80
	var tw := box.create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(box, "position:x", 0.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.9)
	tw.tween_property(box, "modulate:a", 0.0, 0.25)
	tw.parallel().tween_property(box, "position:x", 80.0, 0.25)
	tw.tween_callback(box.queue_free)
