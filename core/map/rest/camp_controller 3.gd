# core/map/rest/camp_controller.gd
extends Node2D

func _ready():
	_create_ui()

func _create_ui():
	var btn_s = Button.new(); btn_s.text = "小回復 (HP+10, 食材-2)"; btn_s.position = Vector2(50,50)
	btn_s.pressed.connect(_heal.bind(10, 2))
	
	var btn_l = Button.new(); btn_l.text = "大回復 (全回復, 食材-5)"; btn_l.position = Vector2(50,110)
	btn_l.pressed.connect(_heal.bind(999, 5))
	
	var btn_skip = Button.new(); btn_skip.text = "空白 (何もしない)"; btn_skip.position = Vector2(50,170)
	btn_skip.pressed.connect(_leave)
	
	add_child(btn_s); add_child(btn_l); add_child(btn_skip)

func _heal(amount: int, cost: int):
	if Inventory.consume_random_food(cost):
		for ally in CurrentStatus.allies:
			ally.hp = min(ally.max_hp, ally.hp + amount)
		print("回復しました！")
		_leave()
	else:
		print("食材が足りません")

func _leave():
	get_tree().change_scene_to_file("res://core/map/map_controller.tscn") # マップへ戻る
