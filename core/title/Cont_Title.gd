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
	UiSystem.make_button(ui, "冒険をはじめる", Vector2(160, 960), Vector2(400, 96), _start, 34)
	UiSystem.make_label(ui, "カードをタップ、または下半分でフリックして使う\n長押しで説明・敵をタップで詳細",
			Vector2(40, 1090), Vector2(640, 90), 20, col.sub)


func _process(delta: float) -> void:
	_t += delta
	deco.queue_redraw()


func _draw_deco() -> void:
	var IC = ImageController
	var c := Vector2(360, 300)
	deco.draw_set_transform(c, _t * 0.15, Vector2.ONE)
	deco.draw_colored_polygon(IC.star_pts(Vector2.ZERO, 260, 110, 12, 0), Color(IC.COL.gold, 0.06))
	deco.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	# 双子の星
	var tw := 0.8 + 0.2 * sin(_t * 2.0)
	for s in [-1, 1]:
		var p: Vector2 = c + Vector2(s * 70, -150 + s * 10)
		IC.glow(deco, p, 60 * tw, Color(IC.COL.gold, 0.6), 6)
		deco.draw_colored_polygon(IC.star_pts(p, 30, 12), IC.COL.gold)
	deco.draw_line(c + Vector2(-70, -160), c + Vector2(70, -140), Color(IC.COL.gold, 0.5), 2, true)
	IC.text(deco, "GEMINI", c + Vector2(0, -30), 92, IC.COL.gold, true, 12, 680)
	IC.text(deco, "DUNGEON", c + Vector2(0, 70), 76, IC.COL.text, true, 10, 680)
	IC.text(deco, "ジェミニ・ダンジョン", c + Vector2(0, 150), 28, IC.COL.sub, true, 6)
	# 主人公の二人
	var ground := Vector2(360, 820)
	IC.shadow(deco, ground + Vector2(-80, 0), 60)
	IC.shadow(deco, ground + Vector2(80, 0), 60)
	IC.character(deco, "knight", ground + Vector2(-80, 0), 1.6, 1.0, _t)
	IC.character(deco, "witch", ground + Vector2(80, 0), 1.6, -1.0, _t)



func _start() -> void:
	CurrentStatus.start_new_game()
	UiSystem.goto("map")
