extends Node

# グリッド座標を保持する辞書
var grid_map = {}
var bottom_grid_map = {}
const TOP_GRID_COLS = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]
const BOTTOM_GRID_COLS = ["A", "B", "C", "D", "E"]

func _ready():
	# ゲーム開始時に自動でグリッドを初期化
	init_grid()

# グリッドの初期化
func init_grid():
	var win = get_viewport().get_visible_rect().size
	var sep_x = 10
	var sep_y = 10
	var cw = win.x / sep_x
	var ch = win.y / sep_y
	
	grid_map.clear()
	for i in range(sep_x):
		if i >= TOP_GRID_COLS.size(): break
		for j in range(sep_y):
			var key = TOP_GRID_COLS[i] + str(j) 
			grid_map[key] = Vector2(cw * i + cw / 2, ch * j + ch / 2)
	sep_x = 5
	sep_y = 5
	cw = win.x / (sep_x)
	ch = win.y/2 / (sep_y)
	
	bottom_grid_map.clear()
	for i in range(sep_x):
		if i >= BOTTOM_GRID_COLS.size(): break
		for j in range(sep_y):
			var key = BOTTOM_GRID_COLS[i] + str(j) +str("_B")
			bottom_grid_map[key] = Vector2(cw * i + cw / 2, win.y/2+ (ch*j) + (ch/2))

# ボタンの追加 (parent引数を追加して、どのシーンにも追加できるように改良)
func add_btn(parent: Node, txt: String, grid_key: String, callback: Callable) -> Button:
	if not grid_map.has(grid_key): return null
	
	var b = Button.new()
	b.text = txt
	b.position = grid_map[grid_key]
	
	# サイズ計算 (B1-A0の範囲)
	if grid_map.has("B1") and grid_map.has("A0"):
		b.custom_minimum_size = grid_map["B1"] - grid_map["A0"]
	
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

# 汎用ラベル (グリッド指定)
func add_label(parent: Node, txt: String, grid_key: String, color: Color = Color.WHITE) -> Label:
	var l = Label.new()
	l.text = txt
	if grid_key != "" and grid_map.has(grid_key):
		l.position = grid_map[grid_key]
	
	l.modulate = color
	_apply_label_style(l, 6, 20)
	
	parent.add_child(l)
	return l

# UI用ラベル (座標指定)
func create_ui_label(parent: Node, txt: String, pos: Vector2, color: Color = Color.WHITE) -> Label:
	var l = Label.new()
	l.text = txt
	l.position = pos
	l.modulate = color
	l.z_index = 3
	
	_apply_label_style(l, 4, 16)
	
	parent.add_child(l)
	return l

# スタイル適用（共通処理）
func _apply_label_style(label: Label, outline_size: int, font_size: int):
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_font_size_override("font_size", font_size)


var active_windows = {}
var window_counter = 0


# ==========================================
# ダイアログウィンドウ（完全版）
# pages: テキストの配列 ["ページ1", "ページ2"...]
# options: { 
#   "type": "normal"|"popup"|"fade"|"rough", 
#   "speed": 0.05, 
#   "choices": {"はい": "callback1", "いいえ": "callback2"} 
# }
# ==========================================
#func start_event():
#	var pages = [
#		"お疲れ様！(res://icon_win.png) 見事な勝利だね。",
#		"さて、報酬はどうする？(res://icon_gold.png)"]	
#	var choices = {
#		"ゴールドをもらう": _on_get_gold,
#		"カードを引く": _on_draw_card}	
#	UIController.show_dialog(self, pages, Vector2(300, 400), {
#		"type": "popup",
#		"speed": 0.05,
#		"choices": choices})
#func _on_get_gold():
#	print("ゴールドを獲得しました！")
#func _on_draw_card():
#	print("カード抽選を開始します。")

func show_dialog(parent: Node, pages: Array, pos: Vector2, options: Dictionary = {}) -> String:
	var win_id = "win_" + str(window_counter)
	window_counter += 1
	
	# --- ノード構築 ---
	var panel = PanelContainer.new()
	var vbox = VBoxContainer.new() # テキストと選択肢を縦に並べる
	var rtl = RichTextLabel.new()
	var choice_container = HBoxContainer.new() # 選択肢を横に並べる
	
	panel.add_child(vbox)
	vbox.add_child(rtl)
	vbox.add_child(choice_container)
	parent.add_child(panel)
	
	# --- 初期設定 ---
	panel.position = pos
	panel.custom_minimum_size = Vector2(400, 120)
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE # パネル側でクリックを拾うため
	_apply_rtl_style(rtl)
	
	# 状態管理データを保持
	var state = {
		"panel": panel,
		"rtl": rtl,
		"choice_container": choice_container,
		"pages": pages,
		"current_page": 0,
		"options": options,
		"is_typing": false,
		"tween": null
	}
	active_windows[win_id] = state
	
	# --- クリックイベント登録 ---
	# パネルをクリックしたら次のページへ
	panel.gui_input.connect(_on_window_gui_input.bind(win_id))
	
	# 出現演出
	_apply_window_animation(panel, options.get("type", "normal"), pos)
	
	# 最初のページを表示
	_display_page(win_id)
	
	return win_id

# --- 内部処理：ページ表示 ---
func _display_page(win_id: String):
	var state = active_windows[win_id]
	var text = state["pages"][state["current_page"]]
	var speed = state["options"].get("speed", 0.05)
	
	state["rtl"].text = _parse_custom_icons(text)
	state["choice_container"].hide() # 選択肢は隠しておく
	
	if speed <= 0:
		state["rtl"].visible_ratio = 1.0
		state["is_typing"] = false
		_check_for_choices(win_id)
	else:
		state["is_typing"] = true
		state["rtl"].visible_ratio = 0.0
		if state["tween"]: state["tween"].kill()
		state["tween"] = create_tween()
		var duration = text.length() * speed
		state["tween"].tween_property(state["rtl"], "visible_ratio", 1.0, duration)
		state["tween"].finished.connect(func(): 
			state["is_typing"] = false
			_check_for_choices(win_id)
		)

# --- 内部処理：クリック判定 ---
func _on_window_gui_input(event: InputEvent, win_id: String):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var state = active_windows[win_id]
		
		# 文字送り中ならスキップして全表示
		if state["is_typing"]:
			if state["tween"]: state["tween"].kill()
			state["rtl"].visible_ratio = 1.0
			state["is_typing"] = false
			_check_for_choices(win_id)
			return

		# 選択肢が表示されている場合はクリックでの次ページ遷移を無効化
		if state["choice_container"].visible:
			return

		# 次のページへ
		state["current_page"] += 1
		if state["current_page"] < state["pages"].size():
			_display_page(win_id)
		else:
			# 全ページ終了、選択肢がない場合は閉じる
			if not state["options"].has("choices"):
				hide_window(win_id)

# --- 内部処理：選択肢の生成 ---
func _check_for_choices(win_id: String):
	var state = active_windows[win_id]
	# 最終ページかつ選択肢データがある場合のみ
	if state["current_page"] == state["pages"].size() - 1 and state["options"].has("choices"):
		var choices = state["options"]["choices"]
		
		# 既存のボタンをクリア
		for child in state["choice_container"].get_children():
			child.queue_free()
		
		for choice_text in choices.keys():
			var btn = Button.new()
			btn.text = choice_text
			var callback = choices[choice_text]
			btn.pressed.connect(_on_choice_selected.bind(win_id, callback))
			state["choice_container"].add_child(btn)
		
		state["choice_container"].show()

func _on_choice_selected(win_id: String, callback: Callable):
	callback.call() # 渡された関数を実行
	hide_window(win_id)

# --- ユーティリティ ---
func _parse_custom_icons(input_text: String) -> String:
	var regex = RegEx.new()
	regex.compile("\\((res://.*?\\.(?:png|jpg|tres|atex))\\)")
	return regex.sub(input_text, "[img=32x32]$1[/img]", true)

func _apply_rtl_style(rtl: RichTextLabel):
	rtl.add_theme_color_override("default_color", Color.WHITE)
	rtl.add_theme_color_override("font_outline_color", Color.BLACK)
	rtl.add_theme_constant_override("outline_size", 6)
	rtl.add_theme_font_size_override("normal_font_size", 20)

func _apply_window_animation(panel, type, pos):
	match type:
		"popup":
			panel.scale = Vector2.ZERO
			panel.pivot_offset = Vector2(200, 60)
			create_tween().tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC)
		"fade":
			panel.modulate.a = 0
			create_tween().tween_property(panel, "modulate:a", 1.0, 0.4)
		"rough":
			var t = create_tween().set_loops(10)
			t.tween_callback(func(): panel.position = pos + Vector2(randf_range(-4, 4), randf_range(-4, 4))).set_delay(0.05)

func hide_window(win_id: String):
	if active_windows.has(win_id):
		var panel = active_windows[win_id]["panel"]
		var tween = create_tween()
		tween.tween_property(panel, "modulate:a", 0, 0.2)
		tween.tween_callback(panel.queue_free)
		active_windows.erase(win_id)
		
		
