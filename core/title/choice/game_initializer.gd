# core/information/choice/game_initializer.gd
extends Node

func start_new_game():
	CurrentStatus.sync_from_init() # パラメータ初期化
	Inventory.reset()              # 所持品初期化
	CurrentDeck.sync_from_init()	# --- 追加箇所：デッキの初期化 ---
	# -----------------------------
	# デッキ初期化ロジック (CurrentDeck側で ActionList.get_initial_deck を呼ぶ)
	get_tree().change_scene_to_file("res://core/map/map_controller.tscn")
