# core/map/battle/battle_result.gd
extends Node2D

var result_type = "win" # バトルコントローラーから "win" か "lose" を渡される想定
var reward_cards = []

func _ready():
	if result_type == "win": _show_win_ui()
	else: _show_lose_ui()

func _show_win_ui():
	_process_drops()
	var l = Label.new(); l.text = "VICTORY! 報酬を選択"; add_child(l)
	
	# エリア報酬からランダムに3枚抽出 (仮データ)
	reward_cards = ["strike", "defend", "poison_stab"]
	
	for i in range(3):
		var c_id = reward_cards[i]
		var btn = Button.new(); btn.text = ActionList.ALLY_CARDS[c_id]["name"] + " をデッキへ"
		btn.position = Vector2(50, 50 + i * 50)
		btn.pressed.connect(_on_card_selected.bind(c_id))
		add_child(btn)
		
	var skip_btn = Button.new(); skip_btn.text = "スキップ"; skip_btn.position = Vector2(50, 200)
	skip_btn.pressed.connect(_leave)
	add_child(skip_btn)

func _process_drops():
	# 敵のドロップデータを参照して確率で付与
	if randf() < 0.5:
		Inventory.add_food("meat", 1)
		print("肉をドロップ！")
	if randf() < 0.3:
		Inventory.items.append("herb")
		print("薬草をドロップ！")

func _on_card_selected(card_id: String):
	print("カード取得: ", card_id)
	# デッキにカードを追加する処理
	_leave()

func _show_lose_ui():
	var l = Label.new(); l.text = "DEFEAT..."; add_child(l)
	
	var title_btn = Button.new(); title_btn.text = "タイトルに戻る"; title_btn.position = Vector2(50, 100)
	add_child(title_btn)
	
	var retry_btn = Button.new(); retry_btn.text = "クイックリスタート"; retry_btn.position = Vector2(50, 160)
	add_child(retry_btn)

func _leave():
	get_tree().change_scene_to_file("res://core/map/map_controller.tscn")
