# core/map/map_controller.gd
extends Node2D

var map_data: Dictionary
var current_node: String = "" # 現在地

func _ready():
	_generate_map()
	_draw_map_ui()

func _generate_map():
	# ノード構成: {id: {type, next_nodes}}
	map_data = {
		"A0": {"type": "battle", "next": ["A00", "A01"]},
		"B0": {"type": "battle", "next": ["B00", "B01"]}
	}
	var types = ["battle", "rest"]
	map_data["A00"] = {"type": types[randi() % types.size()], "next": []}
	map_data["A01"] = {"type": types[randi() % types.size()], "next": []}
	map_data["B00"] = {"type": types[randi() % types.size()], "next": []}
	map_data["B01"] = {"type": types[randi() % types.size()], "next": []}

func _draw_map_ui():
	for child in get_children(): child.queue_free()
	
	var available_nodes = ["A0", "B0"] if current_node == "" else map_data[current_node]["next"]
	
	var y_pos = 100
	for node_id in map_data.keys():
		var btn = Button.new()
		btn.text = node_id + " [" + map_data[node_id]["type"] + "]"
		btn.position = Vector2(100, y_pos); y_pos += 60
		
		# 選択可能ノード以外は押せなくする
		if available_nodes.has(node_id):
			btn.disabled = false
			btn.pressed.connect(_on_node_selected.bind(node_id))
		else:
			btn.disabled = true
			btn.modulate = Color.DARK_GRAY
		add_child(btn)

func _on_node_selected(node_id: String):
	current_node = node_id
	var type = map_data[node_id]["type"]
	if type == "battle": get_tree().change_scene_to_file("res://core/map/battle/battle_controller.tscn")
	elif type == "rest": get_tree().change_scene_to_file("res://core/map/rest/camp_controller.tscn")
