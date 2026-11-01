extends Node2D
## タイトル画面

var deco: Control
var _t := 0.0


func _ready() -> void:
	add_child(GuiBackground.new("title"))
	var ui := CanvasLayer.new()
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
	# 操作のヒントは白いギザギザ吹き出しで
	UiSystem.make_bubble(ui, Rect2(70, 1092, 580, 104), Vector2(110, 1250), 4)
	var hint := UiSystem.make_label(ui, "カードをタップ、または下半分でフリックして使う\n長押しで説明・敵をタップで詳細",
			Vector2(80, 1096), Vector2(560, 96), 20, col.ink, HORIZONTAL_ALIGNMENT_CENTER, 0)
	hint.add_theme_font_override("font", ImageController.font_bold)


func _process(delta: float) -> void:
	_t += delta
	deco.queue_redraw()


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


## セーブした画面から再開
func _continue() -> void:
	SaveData.load_and_resume()
