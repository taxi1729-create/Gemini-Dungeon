extends Node2D
## タイトル画面

const VERSION := "0.04"  # 公開するたびに上げる（右下に表示）

var deco: Control
var _t := 0.0
var ui: CanvasLayer
var bg: GuiBackground
var _deco_light := false  # ライトモードで最後に描いた時の値（切り替わった時だけ描き直す）


func _ready() -> void:
	bg = GuiBackground.new("title")
	add_child(bg)
	ui = CanvasLayer.new()
	add_child(ui)
	deco = Control.new()
	deco.size = Vector2(720, 1280)
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.draw.connect(_draw_deco)
	ui.add_child(deco)
	var col: Dictionary = ImageController.COL
	if SaveData.has_save():
		# セーブがある時は「続きから」を大きく、「冒険をはじめる」（セーブを消して新規）をその下に
		UiSystem.make_red_button(ui, "続きから", Vector2(150, 900), Vector2(420, 96), _continue, 36)
		UiSystem.make_button(ui, "冒険をはじめる", Vector2(180, 1010), Vector2(360, 70), _start, 28)
	else:
		UiSystem.make_red_button(ui, "冒険をはじめる", Vector2(150, 940), Vector2(420, 100), _start, 36)
	# 一覧（カード・レリック・バッジ）
	UiSystem.make_button(ui, "カード一覧", Vector2(30, 1094), Vector2(208, 60), open_card_list, 22)
	UiSystem.make_button(ui, "レリック一覧", Vector2(256, 1094), Vector2(208, 60), open_relic_list, 22)
	UiSystem.make_button(ui, "バッジ一覧", Vector2(482, 1094), Vector2(208, 60), open_badge_list, 22)
	# 設定（右上）
	UiSystem.make_button(ui, "設定", Vector2(566, 24), Vector2(130, 56), open_settings, 22)
	# 操作のヒントは白いギザギザ吹き出しで
	UiSystem.make_bubble(ui, Rect2(70, 1166, 520, 64), Vector2(100, 1250), 4)
	var hint := UiSystem.make_label(ui, "カードをタップ、または下半分でフリックして使う\n長押しで説明・敵をタップで詳細",
			Vector2(80, 1168), Vector2(500, 60), 16, col.ink, HORIZONTAL_ALIGNMENT_CENTER, 0)
	hint.add_theme_font_override("font", ImageController.font_bold)
	# バージョン（右下）
	var ver := UiSystem.make_label(ui, "ver %s" % VERSION, Vector2(500, 1236), Vector2(200, 34), 20, col.paper, HORIZONTAL_ALIGNMENT_RIGHT, 4)
	ver.add_theme_font_override("font", ImageController.font_head)


func _process(delta: float) -> void:
	# 一覧・設定で覆っている間は後ろの背景と飾りを描き直さない（カード一覧を開いた時の重さ対策）
	var covered := _covered()
	bg.paused = covered
	var light: bool = ImageController.light_mode
	if light != _deco_light:
		_deco_light = light
		deco.queue_redraw()
	if covered or light:
		return  # ライトモードでは後光を回さない（止まった 1 枚の絵）
	_t += delta
	deco.queue_redraw()


## 一覧・設定のオーバーレイが開いているか
func _covered() -> bool:
	for c in ui.get_children():
		if c is GuiDeckView or c.has_meta("overlay"):
			return true
	return false


func _draw_deco() -> void:
	var IC = ImageController
	var col: Dictionary = IC.COL
	# キャラの後ろ：ゆっくり回る赤いギザギザの後光と黒い芯、網点
	var g := Vector2(360, 760)
	IC.halftone(deco, Rect2(0, 480, 720, 460), Color(col.paper, 0.10), g + Vector2(0, -40), 380, 20, 6)
	deco.draw_colored_polygon(IC.burst_pts(g, 300, 205, 16, 2, _t * 0.08), Color(col.red, 0.9))
	deco.draw_colored_polygon(IC.burst_pts(g, 222, 172, 16, 9, -_t * 0.06), col.ink)
	# 主人公の二人
	var ground := Vector2(360, 862)
	deco.draw_colored_polygon(IC.slant_pts(Rect2(150, ground.y - 8, 420, 16), 10), col.ink)
	deco.draw_colored_polygon(IC.slant_pts(Rect2(160, ground.y - 10, 400, 3), 2), col.paper)
	IC.character(deco, "knight", ground + Vector2(-80, 0), 1.6, 1.0, _t)
	IC.character(deco, "witch", ground + Vector2(80, 0), 1.6, -1.0, _t)
	# タイトル：少し傾けた赤い帯に白抜きの「GEMINI」、白い帯に黒の「DUNGEON」
	var c := Vector2(360, 250)
	deco.draw_set_transform(c, -0.07, Vector2.ONE)
	IC.slant(deco, Rect2(-430, -92, 860, 158), col.red, 44, 4.0, col.ink, col.ink, Vector2(12, 12))
	IC.stripes(deco, Rect2(150, -88, 270, 150), Color(col.ink, 0.25), 16, 5, 0.3)
	IC.head(deco, "GEMINI", Vector2(-8, -12), 134, col.paper, 660, col.ink, Vector2(7, 7))
	IC.slant(deco, Rect2(-250, 82, 540, 92), col.paper, 30, 4.0, col.ink, col.red, Vector2(9, 9))
	IC.head(deco, "DUNGEON", Vector2(22, 126), 78, col.ink, 480, Color(col.red, 0.85), Vector2(4, 3))
	# 双子座の二つ星（白い十字星を赤い線で結ぶ）
	var s1 := Vector2(-330, -124)
	var s2 := Vector2(-250, -150 + sin(_t * 2.0) * 3)
	deco.draw_line(s1, s2, col.paper, 3, true)
	deco.draw_colored_polygon(IC.star_pts(s1, 26, 7, 4, 0), col.paper)
	deco.draw_colored_polygon(IC.star_pts(s2, 20, 6, 4, 0), col.paper)
	deco.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# カナ表記のタグ
	var tag := Rect2(206, 444, 308, 50)
	IC.slant(deco, tag, col.ink, 16, 3.0, col.paper, col.red, Vector2(6, 6))
	IC.head(deco, "ジェミニ・ダンジョン", tag.get_center(), 26, col.paper, 270)


func _start() -> void:
	SaveData.clear()
	CurrentStatus.start_new_game()
	UiSystem.goto("map")


# ------------------------------------------------------------
# 一覧
# ------------------------------------------------------------
## カード一覧：持ち主のタブ、レア度ごとの見出しで全カード。タップで説明
func open_card_list() -> GuiDeckView:
	var secs := {}
	for owner in ["knight", "witch"]:
		var groups: Array = []
		for tier in [["common", "通常"], ["rare", "レア"], ["super_rare", "超レア"]]:
			var cards: Array = []
			for cid in ActionList.ALLY_CARDS[tier[0]]:
				if ActionList.ALLY_CARDS[tier[0]][cid].get("owner", "") == owner:
					cards.append(ActionList.make_card(cid))
			if not cards.is_empty():
				groups.append([tier[1], cards])
		secs[owner] = groups
	return GuiDeckView.open(ui, "カード一覧", Callable(), secs)


func open_relic_list() -> Control:
	var rows: Array = []
	for id in RelicList.DATA:
		var d: Dictionary = RelicList.DATA[id]
		rows.append([d.icon, d.name, d.desc])
	return _open_list("レリック一覧", "5つまで持てる（6つ目は交換）。宝箱・ショップ・強敵で手に入る", rows)


func open_badge_list() -> Control:
	var rows: Array = []
	var fors := {"all": "全部のカード", "attack": "攻撃のカード", "ap": "AP1以上のカード", "burn": "廃棄・消費のカード"}
	for id in BadgeList.DATA:
		var d: Dictionary = BadgeList.DATA[id]
		rows.append([d.icon, d.name, "%s（付けられる：%s）" % [d.desc, fors.get(d["for"], "")]])
	return _open_list("バッジ一覧", "カード1枚に1つ。付け直すと上書き。戦闘・ショップ・イベント・宝箱で手に入る", rows)


## アイコン・名前・説明の行を並べた一覧のオーバーレイ
func _open_list(title: String, note: String, rows: Array) -> Control:
	var col: Dictionary = ImageController.COL
	var v := Control.new()
	v.size = Vector2(720, 1280)
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	v.z_index = 200
	var bg := ColorRect.new()
	bg.color = Color(ImageController.GLASS.ivory_black, 0.8)
	bg.size = v.size
	v.add_child(bg)
	UiSystem.make_panel(v, Rect2(20, 60, 680, 1160))
	UiSystem.make_banner(v, title, Rect2(40, 34, 420, 66), 32)
	UiSystem.make_label(v, note, Vector2(40, 108), Vector2(640, 56), 18, col.sub, HORIZONTAL_ALIGNMENT_LEFT, 0)
	var list := Control.new()
	list.position = Vector2(36, 170)
	list.size = Vector2(648, 920)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rh := minf(92.0, 920.0 / maxf(1.0, rows.size()))
	list.draw.connect(func():
		var IC = ImageController
		for i in rows.size():
			var y := i * rh
			var r := Rect2(0, y, 648, rh - 6)
			# 一覧の行：エンジェルホワイトの箱（セイクレッドブルーの縁）、アイコンの下地はホーリーブルー
			IC.cut_rect(list, r, IC.GLASS.angel_white, 10, 2.0, IC.GLASS.sacred_blue)
			list.draw_circle(Vector2(44, y + (rh - 6) / 2), 34, IC.GLASS.holy_blue)
			IC.icon(list, rows[i][0], Vector2(44, y + (rh - 6) / 2), 54)
			list.draw_string(IC.font_bold, Vector2(92, y + 32), rows[i][1], HORIZONTAL_ALIGNMENT_LEFT, 540, 23, col.ink)
			IC.rich_text(list, rows[i][2], Vector2(92, y + 40), 17, IC.GLASS.ash_gray.darkened(0.35), 548, 0, 22))
	v.add_child(list)
	UiSystem.make_button(v, "閉じる", Vector2(210, 1110), Vector2(300, 80), v.queue_free, 26)
	v.set_meta("overlay", true)
	ui.add_child(v)
	return v


# ------------------------------------------------------------
# 設定
# ------------------------------------------------------------
## 設定画面：演出ライトモードの ON／OFF。user://settings.json に保存（セーブを消しても残る）
func open_settings() -> Control:
	var col: Dictionary = ImageController.COL
	var v := Control.new()
	v.size = Vector2(720, 1280)
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	v.z_index = 200
	v.set_meta("overlay", true)
	var shade := ColorRect.new()
	shade.color = Color(ImageController.GLASS.ivory_black, 0.8)
	shade.size = v.size
	v.add_child(shade)
	UiSystem.make_panel(v, Rect2(20, 300, 680, 600))
	UiSystem.make_banner(v, "設定", Rect2(40, 274, 300, 66), 32)
	var head := UiSystem.make_label(v, "演出ライトモード", Vector2(56, 372), Vector2(608, 48), 28, col.paper, HORIZONTAL_ALIGNMENT_LEFT, 4)
	head.add_theme_font_override("font", ImageController.font_head)
	UiSystem.make_label(v, "ONにすると、背景の動き・光の帯・粒・カードの光る演出・必殺技のカットイン・画面の揺れ・画面切り替えのワイプを省いて軽くします。動きが重い時に使ってください。",
			Vector2(56, 428), Vector2(608, 150), 20, col.sub, HORIZONTAL_ALIGNMENT_LEFT, 0)
	var off := UiSystem.make_button(v, "OFF", Vector2(80, 600), Vector2(260, 90), Callable(), 30)
	var on := UiSystem.make_button(v, "ON", Vector2(380, 600), Vector2(260, 90), Callable(), 30)
	var refresh := func():
		UiSystem.set_button_red(on, ImageController.light_mode)
		UiSystem.set_button_red(off, not ImageController.light_mode)
	off.pressed.connect(func():
		Settings.set_light_mode(false)
		refresh.call())
	on.pressed.connect(func():
		Settings.set_light_mode(true)
		refresh.call())
	refresh.call()
	UiSystem.make_label(v, "設定はセーブを消しても残ります", Vector2(56, 708), Vector2(608, 40), 18, col.sub, HORIZONTAL_ALIGNMENT_LEFT, 0)
	UiSystem.make_button(v, "閉じる", Vector2(210, 780), Vector2(300, 80), v.queue_free, 26)
	ui.add_child(v)
	return v


## セーブした画面から再開
func _continue() -> void:
	SaveData.load_and_resume()
