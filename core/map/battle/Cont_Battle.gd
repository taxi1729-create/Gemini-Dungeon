extends Node2D

# --- 外部データへの参照 (Autoload前提) ---
@onready var status = CurrentStatus
@onready var inventory = Inventory

# --- 設定・状態管理 ---
const LONG_PRESS_TIME = 0.5
var grid_map = {}      # 座標データ {"A0": Vector2, ...}
var bottom_grid_map = {}      # 座標データ {"A0": Vector2, ...}
#var deck_sleeves_imgs = func _update_ui_displays():[] # 重ねたスリーブの画像ID保持用 (変数宣言部に追加)
var Battle_Text =""
var turn_count = 1
var action_order = []  # 行動順リスト
var active_idx = 0     # 現在の行動者インデックス
var deck_controllers = {} # { "char_id": DeckController }
var is_special_used = false # 今ターンの必殺技使用フラグ
var card_default_size=Vector2(0.8,0.8)
# 入力検知
var is_pressing = false
var press_time = 0.0
var current_press_data = null

# UI保持
var hand_buttons = []
var hp_bars = {}
var hp_labels = {}
var ap_displays = {} # ← 名前を変更！ (AP画像を束ねる箱を管理します)
var icon_displays = {} # ← 名前を変更！ (AP画像を束ねる箱を管理します)
var info_label: Label
var item_menu: Panel # アイテム選択用パネル
var image_atk_pos = Vector2(0,0)
var image_ap_pos = Vector2(0,0)
var hand_ui_elements = [] # 手札の描画IDとLabelを保持する配列
var desc_label: Label     # B6に表示する説明用ラベル
var target_anim_ids = []  # 点滅中のアニメID保持用
var buff_displays = {} # 状態異常アイコン表示用ノード
var char_buttons = {}  # キャラタップ判定用ボタン
var keypad_map = {} # テンキー番号とボタンの対応表
var last_flick_btn = null # 現在フリックで選択中のボタン保持用

func _ready():# ... 既存の初期化 ...

	UiSystem.init_grid()
	grid_map =UiSystem.grid_map
	bottom_grid_map =UiSystem.bottom_grid_map
	desc_label = _add_label("", "A5", Color.WHITE)
	var win = get_viewport_rect().size
	var background_img = ImageController.show_image("bg_forest", Vector2(win.x/2,win.y/4), {})
	desc_label.visible = false
	_init_battle_data()
	_create_ui()
	info_label = _add_label("Battle Start!", "B7", Color.CYAN)
	keypad_map = {
		8:hand_buttons[0], # 上：手札1
		2: hand_buttons[2], # 下：手札3
		4: hand_buttons[1],   # 左：手札2
		6: hand_buttons[3], # 右：手札4
		7: system_buttons[0],   # 左上：入替 (Action B)
		9: system_buttons[1],   # 右上：必殺 (Action C)
		3: system_buttons[2], # 左下：道具 (Action F)
		1: system_buttons[3]    # 右下：終了 (Action D)
	}
	FlickInput.flick_changed.connect(_on_flick_changed)
	FlickInput.flick_executed.connect(_on_flick_executed)
	FlickInput.flick_canceled.connect(_on_flick_canceled)
# テンキーとボタンの紐付け（前回の回答のロジック）

	_start_global_turn()

# ---------------------------------------------------
# 1. システム初期化
# ---------------------------------------------------

func _init_battle_data():
	# もしCurrentStatusが空なら、ここで初期化を強制する
	if status.allies.is_empty():
		status.sync_from_init() # CurrentStatus内の初期化関数を呼ぶ
		CurrentDeck.sync_from_init()	# --- 追加箇所：デッキの初期化 --
	# 味方のデッキコントローラーを初期化
	for ally in status.allies:
		var dc = DeckController.new()
		add_child(dc)
# --- 修正箇所：CurrentDeckからマスターデッキを取得して渡す ---
		var master_deck = CurrentDeck.decks[ally.id]
		#print((master_deck))
		dc.setup_battle_deck(master_deck)
		#print(dc.setup_battle_deck(master_deck))
		deck_controllers[ally.id] = dc
	
	# 敵をランダムに1〜4体生成
	status.enemies.clear()
	var enemy_count = (randi() % 3) + 2
	var e_positions = ["I2", "A2", "G1", "B1"] # 指定された敵配置
	
	# エリアリストから出現モンスターを抽選
	var pool = AreaList.get_enemy_pool("cave") # cave固定。実際はMapから渡す
	for i in range(enemy_count):
		var e_id = pool[randi() % pool.size()]
		var e_data = EnemyList.DATA[e_id].duplicate(true)
		e_data["base_id"] = e_id # ←これを追加！(マスターデータ参照用)
		e_data["id"] = e_id + "_" + str(i)
		#e_data["id"] = e_id
		e_data["grid_key"] = e_positions[i]
		e_data["side"] = "enemy"            # ←これも追加！(敵味方判定用)
		e_data["is_defeat"] = false
		e_data["status_effects"] = {}
		e_data["flip_h"] = false
		#print(e_data)
		if i == 0 or i==2:
			e_data["flip_h"] = true
		status.enemies.append(e_data)
	_update_action_order()
	_update_action_order_ui()

func _update_action_order():
	action_order.clear()
	
	# 味方と敵をすべてリストにまとめる
	for ally in status.allies:
		action_order.append({"data": ally, "side": "ally"})
	for enemy in status.enemies:
		action_order.append({"data": enemy, "side": "enemy"})
		
	# 素早さ(spd)が高い順にソート（並び替え）する
	action_order.sort_custom(func(a, b): 
		return a.data.get("spd", 0) > b.data.get("spd", 0)
	)
# ---------------------------------------------------
# 2. UI構築
# ---------------------------------------------------
var system_buttons=[]
var system_action_data = {
	"action_b": {"name": "入替", "image": "icon_swap", "description": "前衛と後衛の位置を入れ替えます。"},
	"action_c": {"name": "必殺", "image": "icon_special", "description": "強力な必殺技を放ちます。"},
	"action_d": {"name": "終了", "image": "icon_end", "description": "行動を終了し、次のキャラクターへ番を回します。"},
	"action_f": {"name": "道具", "image": "icon_item", "description": "所持しているアイテムを表示します。"}
}
var system_ui_elements = [] # システムボタンの画像ID管理用
func _create_ui():
	# 味方位置設定
	status.allies[0]["grid_key"] = "D2"
	status.allies[1]["grid_key"] = "F2"
	
	# 全キャラのステータス表示
	for ally in status.allies: _add_status_ui(ally)
	for enemy in status.enemies: _add_status_ui(enemy)
	
	# 手札ボタン (グリッド座標を参考に配置)
	var hand_pos = ["C0_B", "B1_B", "C2_B", "D1_B"]
	for i in range(4):
		var btn = _add_btn("---", hand_pos[i], "action_a")
		hand_buttons.append(btn)
	
# 特殊ボタンの生成とデータ紐付け
	var sys_configs = [
		["B0_B", "action_b"],
		["D0_B", "action_c"],
		["E2_B", "action_d"],
		["B2_B", "action_f"]
	]

	for config in sys_configs:
		var grid_key = config[0]
		var type = config[1]
		var data = system_action_data[type]
		var btn = _add_btn(data.name, grid_key, type)
		btn.set_meta("action_data", data) # 説明表示用にデータを保持
		system_buttons.append(btn)
	
	# システムボタンの見た目（画像）を更新
	_update_system_ui()
func _add_status_ui(data):
	var id = data.id
	var pos = grid_map[data.grid_key]
	var is_ally = data.get("side", "ally") == "ally"
	
	# マスターデータの取得
	var master_data = InitAllyStatus.DATA[id] if is_ally else EnemyList.DATA[data.base_id]
	
	# --- A. キャラクターアニメーションの初期表示 (Idle) ---
	var motion_group = master_data.get("motion_group", "knight_motions")
	var idle_anim = AnimationList.MOTION_GROUPS[motion_group]["idle"]
	var flip = data.flip_h
	data["anim_id"] = AnimationController.play_animation(idle_anim, pos,  {"is_loop":true,"flip_h":flip})
	
	# --- B. HPバーの生成 ---
	var bar = TextureProgressBar.new()
	bar.nine_patch_stretch = true
	# TODO: ここでImageListからHPバーのテクスチャをロードしてください
	bar.texture_under = load("res://index/design/image/system/pipo-WindowBaseSet2a_01.png")
	bar.texture_progress = load("res://index/design/image/system/pipo-WindowBaseSet2b_07.png")
	bar.max_value = data.max_hp
	bar.value = data.hp
	bar.size = Vector2(100, 10) # 適宜サイズ調整
	$UI.add_child(bar)
	hp_bars[id] = bar
	
	# --- C. 名前とHP数値ラベルの生成 ---
	var name_label = _add_label(master_data.get("name", id), "A5", Color.WHITE) # grid_keyを空にして手動配置
	$UI.add_child(name_label)
	# ラベルをhp_labelsに登録（_update_ui_displaysで更新するため）
	hp_labels[id] = name_label
	
	# --- D. chara表示用のコンテナ生成 ---
	var icon_node = Node2D.new()
	$UI.add_child(icon_node)
	icon_displays[id] = icon_node
	
	# --- D. AP表示用のコンテナ生成 ---
	var ap_node = Node2D.new()
	$UI.add_child(ap_node)
	ap_displays[id] = ap_node
	
	# --- E. 状態異常(バフ/デバフ)を表示する箱 ---
	var buff_node = Node2D.new()
	buff_node.position = pos + Vector2(-50, 60)
	$Characters.add_child(buff_node)
	buff_displays[id] = buff_node
	
	# --- F. キャラクタータップ判定用の透明ボタン ---
	var tap_btn = Button.new()
	tap_btn.size = Vector2(100, 150)
	tap_btn.position = pos + Vector2(-50, -100)
	tap_btn.self_modulate.a = 0.0
	tap_btn.pressed.connect(_on_character_tapped.bind(data))
	$Characters.add_child(tap_btn)
	char_buttons[id] = tap_btn
# ---------------------------------------------------
# 3. 戦闘進行ロジック
# ---------------------------------------------------

func _start_global_turn():
	active_idx = 0
	_next_character_turn()

func _next_character_turn():
	#print(action_order)
	if active_idx >= action_order.size():
		# ターン終了時処理
		StatusController.decrease_all_durations(status.allies, status.enemies)
		turn_count += 1
		_start_global_turn()
		return
	#print(active_idx,action_order.size())
	var chara = action_order[active_idx]
	if chara.data.hp <= 0:
		_finish_character_turn()
		return
	
	# 行動開始前：状態異常トリガー
	StatusController.trigger_start_of_turn(chara.data)
	_update_ui_displays()
	_update_action_order_ui()
	if chara.data.hp <= 0:
		_finish_character_turn()
		return

	if chara.side == "ally":
		is_special_used = false
		_setup_ally_turn(chara.data)
	else:
		_execute_enemy_ai(chara.data)

func _setup_ally_turn(user_data):
	#info_label.text = user_data.id + " のターン"
	var dc = deck_controllers[user_data.id]
	user_data.ap += 1
	
	# アニメーションを turn に変更
	var flip_h = user_data.flip_h
	AnimationController.stop_animation(user_data.anim_id)
	var master_data = InitAllyStatus.DATA[user_data.id]
	var anim_name = AnimationList.MOTION_GROUPS[master_data["motion_group"]]["turn"]
	user_data.anim_id = AnimationController.play_animation(anim_name, grid_map[user_data.grid_key], {"is_loop":true,"flip_h":flip_h})
	#print(user_data)
	_update_ui_displays()

	dc.draw_cards(4)
	_update_hand_ui(dc)

func _execute_card_action(hand_idx: int, action_data: Dictionary):
	var user = action_order[active_idx].data
	if action_data.has("ap"):
		if user.ap < action_data.ap:
			#info_label.text = "AP不足！"
			return
	if action_data.type == "unselectable":
		#info_label.text = "使用不可！"
		return
	# AP消費
	user.ap -= action_data.ap
	#print(user)
	# アクション実行
	var target_data =ActionController._resolve_targets(user, action_data.target, status.allies, status.enemies)
	ActionController.execute_action(user, action_data, status.allies, status.enemies)
	_check_battle_end()
	#アニメ更新、ターンのアニメ消去
	var flip_h = action_order[active_idx].data.flip_h
	#print("muki",flip_h)
	AnimationController.stop_animation(user.anim_id)
	#攻撃のアニメ
	var master_data = InitAllyStatus.DATA[user.id]
	var anim_name = AnimationList.MOTION_GROUPS[master_data["motion_group"]]["attack"]
	for target_key in target_data:
		var flip_s =flip_h
		#print("aaa",action_data.target)
		if action_data.target == "front_enemy_single" or action_data.target == "enemy_all":
			_play_damage_effect(target_key)
			if action_data.target == "front_enemy_single" :
				if target_key.flip_h == flip_h:		
					flip_s = !flip_h
			user.anim_id = AnimationController.play_animation(anim_name, grid_map[user.grid_key], {"flip_h":flip_s})
			if action_data.target == "front_enemy_single" :
				var move_vector = (grid_map[target_key.grid_key] + grid_map[user.grid_key])/2
				AnimationController.move_animation_arc(user.anim_id, move_vector, {"arc_height":-200,"duration":10})
		elif action_data.target == "ally_all" or action_data.target == "self":
			anim_name = AnimationList.MOTION_GROUPS[master_data["motion_group"]]["skill"]	
			user.anim_id = AnimationController.play_animation(anim_name, grid_map[user.grid_key], {"flip_h":flip_h})
			_play_buff_effect(user)
	#await AnimationController.wait_for_animation(user.anim_id, true)
	
	get_tree().create_timer(0.7).timeout.connect(func():
		AnimationController.stop_animation(user.anim_id)
		anim_name = AnimationList.MOTION_GROUPS[master_data["motion_group"]]["turn"]
		user.anim_id = AnimationController.play_animation(anim_name, grid_map[user.grid_key], {"is_loop":true,"flip_h":flip_h}))
	# デッキ処理：使用したカードを捨札へ、新しいカードを1枚引く
	var start_pos = hand_buttons[hand_idx].global_position + Vector2(60, 30) # ボタンの中心付近
	var end_pos = bottom_grid_map["E0_B"]
	
	# 0フレーム(一瞬)でフレーム画像を表示
	var throw_img = ImageController.show_image(action_data.image, start_pos, {"angle": -15.0,"scale":card_default_size})
	var throw_frm = ImageController.show_image(action_data.card_frame, start_pos, {"angle": -15.0,"scale":card_default_size})
	var sleeve_id = ImageController.show_image(action_data.card_sleeve, grid_map["A5"], {"scale":card_default_size*0.8,"z_index":100})

	# 30フレーム(0.5秒)かけてG6へ移動させながら回転
	var time =36
	ImageController.move_image_arc(sleeve_id, start_pos + Vector2(-10, 90), {"height": -200.0, "duration": time/2})
	ImageController.manipulate_image(sleeve_id, {"scale":card_default_size,"duration":time/2})
	ImageController.move_image_arc(throw_img, grid_map["I6"], {"height": -200.0, "duration": time})
	ImageController.manipulate_image(throw_img,  {"rotation": 120.0, "scale":Vector2(0,0),"duration": time})
	ImageController.move_image_arc(throw_frm, grid_map["I6"], {"height": -200.0, "duration": time})
	ImageController.manipulate_image(throw_frm,  {"rotation": 120.0, "scale":Vector2(0,0),"duration": time})
	# 画像を消去するタイマーをセット
	get_tree().create_timer(0.5).timeout.connect(func():
		ImageController.manipulate_image(sleeve_id, {"scale":Vector2(0,0.8),"duration":time/8})
		ImageController.erase_image(throw_img, 45)
		ImageController.erase_image(throw_frm, 45)
		ImageController.erase_image(sleeve_id, 45)
	)
	# ----------------------------------------------
	
	var dc = deck_controllers[user.id]
	dc.play_and_discard(hand_idx)
	dc.draw_cards(1)
	
	_update_hand_ui(dc)
	_update_ui_displays()

# --- アクションB: 位置交代 ---
func _execute_swap():
	if status.allies.size() < 2: return
	var user = action_order[active_idx].data
	var partner = status.allies[0] if status.allies[1] == user else status.allies[1]
	
	var temp_key = user.grid_key
	user.grid_key = partner.grid_key
	partner.grid_key = temp_key
	user.flip_h = !user.flip_h
	partner.flip_h = !partner.flip_h
	var idx_a = status.allies.find(user)
	var idx_b = status.allies.find(partner)
	status.allies[idx_a] = partner
	status.allies[idx_b] = user
	
	# 【追加】画像(アニメーション)の位置も入れ替える
	AnimationController.set_position(user.anim_id, grid_map[user.grid_key])
	AnimationController.set_position(partner.anim_id, grid_map[partner.grid_key])
	
	info_label.text = "位置を交代した！"
	_update_ui_displays()
func _finish_character_turn():
	var user = action_order[active_idx].data

	if user.id == "knight" or user.id == "witch":
		AnimationController.stop_animation(user.anim_id)
		var anim_name = AnimationList.MOTION_GROUPS[InitAllyStatus.DATA[user.id]["motion_group"]]["idle"]
		user.anim_id = AnimationController.play_animation(anim_name, grid_map[user.grid_key], {"is_loop":true})

		var dc = deck_controllers[user.id]
		dc.turn_end_and_discard()
	active_idx += 1
	
	_next_character_turn()

# ---------------------------------------------------
# 4. 入力・イベントハンドリング
# ---------------------------------------------------

func _on_btn_pressed(type, btn):
	match type:
		"action_a":
			var data = btn.get_meta("action_data")
			var idx = btn.get_meta("hand_idx")
			_execute_card_action(idx, data)
		"action_b":
			_execute_swap()
		"action_c":
			if not is_special_used:
				info_label.text = "必殺技発動！"
				is_special_used = true
				# ここに必殺技の具体的なActionController呼び出しを書く
		"action_d":
			_finish_character_turn()
		"action_f":
			item_menu.visible = true

func _handle_item_use(item_id):
	# アイテム効果の発動 (ActionControllerで処理可能)
	var user = action_order[active_idx].data
	var item_data = Item_List.DATA[item_id]
	ActionController.execute_action(user, item_data, status.allies, status.enemies)
	item_menu.visible = false
	_update_ui_displays()

# ---------------------------------------------------
# 5. UI更新補助
# ---------------------------------------------------
var order_icons = [] # 保持用の配列 (ファイルの先頭の変数宣言部に追加してください)

func _update_action_order_ui():
	# 古いアイコンを消去
	for icon in order_icons:
		icon.queue_free()
	order_icons.clear()
	
	# 画面上部 (例: X=100, Y=30) に並べる
	var start_pos = Vector2(100, 30)
	for i in range(action_order.size()):
		var char_data = action_order[i].data
		var is_ally = char_data.get("side", "ally") == "ally"
		var master_data = InitAllyStatus.DATA[char_data.id] if is_ally else EnemyList.DATA[char_data.base_id]
		
		# アイコン画像を表示
		var icon_path = ImageList.DATA["icon"][master_data["icon"]]
		var sprite = Sprite2D.new()
		sprite.texture = load(icon_path)
		sprite.position = start_pos + Vector2(i * 50, 20) # 50pxずつずらす
		sprite.scale = Vector2(0.8, 0.8)
		
		# 現在のターンのキャラは少し大きくする
		if i == active_idx:
			sprite.scale = Vector2(1.5, 1.5)
			
		$UI.add_child(sprite)
		order_icons.append(sprite)
func _update_system_ui():
	# 古い画像を消去
	for elem in system_ui_elements:
		if typeof(elem) == TYPE_STRING: ImageController.erase_image(elem, 0)
		elif is_instance_valid(elem): elem.queue_free()
	system_ui_elements.clear()

	for btn in system_buttons:
		var data = btn.get_meta("action_data")
		btn.self_modulate.a = 0.0 # ボタン自体は透明に
		var pos = btn.global_position + (btn.size / 2.0)
		
		# アイコンとフレームの表示
		var art_id = ImageController.show_image(data.image, pos, {"scale": Vector2(0.6, 0.6)})
		var frame_id = ImageController.show_image("card_frame_system", pos, {"scale": Vector2(0.6, 0.6)})
		
		var btn_info = {"art_id": art_id, "frame_id": frame_id}
		system_ui_elements.append_array([art_id, frame_id])

		# シグナル接続（アクションAと共通の関数を利用）
		if btn.button_down.is_connected(_on_hand_down):
			btn.button_down.disconnect(_on_hand_down)
			btn.button_up.disconnect(_on_hand_up)
		
		btn.button_down.connect(_on_hand_down.bind(btn, btn_info, data))
		btn.button_up.connect(_on_hand_up.bind(btn, btn_info))
var atk_icon_scale=Vector2(4,4)
var ap_icon_scale=Vector2(4,4)
func _update_hand_ui(dc):
	_update_deck_ui(dc)
	
	# 古いUIを全消去
	for elem in hand_ui_elements:
		if typeof(elem) == TYPE_STRING: ImageController.erase_image(elem, 0)
		elif is_instance_valid(elem): elem.queue_free()
	hand_ui_elements.clear()
	
	for i in range(4):
		var btn = hand_buttons[i]
		var card = dc.hand[i]
		if card != null:
			var btn_information = {}
			btn.set_meta("action_data", card)
			btn.set_meta("hand_idx", i)
			btn.visible = true
			btn.self_modulate.a = 0.0 # ボタン自体は透明にして当たり判定だけ残す
			#print("hand_idx",i,"",card.name)
			var pos = btn.global_position + (btn.size / 2.0)
			
			# 1. フレームとイラスト描画 (ImageController想定)
			var art_id = ImageController.show_image(card.image, pos, {"scale":card_default_size,"duration":5})
			var frame_id = ImageController.show_image(card.card_frame, pos, {"scale":card_default_size,"duration":5})
			if card.rarity == "rare":
				ImageController.shine_image(art_id,{"hologram": false,           # 単色モード
				"color": Color(1.0, 0.8, 0.2), "duration_frames":80,"intensity":0.5,"width":0.3,"wait":1,"loop":true})
				ImageController.shine_image(frame_id,{"hologram": false,           # 単色モード
				 "duration_frames":80,"intensity":0.5,"width":0.3,"wait":1,"loop":true})
			if card.rarity == "super_rare":
				ImageController.shine_image(art_id,{"hologram": true,           # 単色モード
				"duration_frames":120,"intensity":0.5,"width":0.5,"wait":1,"loop":true})
				ImageController.shine_image(frame_id,{"hologram": true,           # 単色モード
				"duration_frames":120,"intensity":0.5,"width":0.5,"wait":1,"loop":true})
			btn_information["frame_id"]= frame_id
			btn_information["art_id"]  = art_id
			hand_ui_elements.append_array([frame_id, art_id])
			#print(hand_ui_elements)
			# 2. 消費AP (右上)
			if card.has("ap"):
				var ap_icon = ImageController.show_image("ActionPoint", pos + Vector2(80, -80), {"scale":ap_icon_scale})
				var ap_lbl = _create_ui_label(str(card.ap), pos + Vector2(60, -125), Color.PURPLE)
				ap_lbl.scale=Vector2(3,3)
				hand_ui_elements.append_array([ap_icon, ap_lbl])
				btn_information["ap_icon"]  = ap_icon
				btn_information["ap_lbl"]  = ap_lbl
			# 3. 攻撃力 (左上、パワー0以外)
			var power = card.get("power", 0)
			if power > 0:
				var target_icon = "enemy_1"
				if card.target =="enemy_all":
					target_icon = "enemy_all"
				var atk_icon = ImageController.show_image(target_icon, pos + Vector2(-80, -80), {"scale":atk_icon_scale})
				var atk_lbl = _create_ui_label(str(power), pos + Vector2(-65, -125), Color.GREEN)
				atk_lbl.scale=Vector2(3,3)
				hand_ui_elements.append_array([atk_icon, atk_lbl])
				btn_information["atk_icon"]  = atk_icon
				btn_information["atk_lbl"]  = atk_lbl
			# 4. 対象・効果アイコン (中央下)
			var eff_text = card.get("target","")
			if card.has("status_effect"):
				var eff_icon = ImageController.show_image(card.status_effect.icon, pos + Vector2(-90, -60), {})
				eff_text += "\n" + card.status_effect.name + " " + str(card.status_effect.duration) + "T"
				eff_text.scale=Vector2(2,2)
				var eff_lbl = _create_ui_label(eff_text, pos + Vector2(-30, 20), Color.WHITE)
				hand_ui_elements.append(eff_lbl)
				btn_information["eff_icon"]  = eff_icon
				btn_information["eff_lbl"]  = eff_lbl
			btn_information["eff_text"]  = eff_text
			#print(btn.button_down.is_connected)
			# ボタンのシグナル接続 (長押し・拡大用)
			#print("KOKO",btn_information)
			if btn.button_down.is_connected(_on_hand_down):
				#print("wakatta")
				btn.button_down.disconnect(_on_hand_down)
				btn.button_up.disconnect(_on_hand_up)
			btn.button_down.connect(_on_hand_down.bind(btn, btn_information, card))
			btn.button_up.connect(_on_hand_up.bind(btn, btn_information))
			btn.set_meta("btn_info", btn_information) # これが重要！
		else:
			btn.visible = false
		

# UI用ラベル生成ヘルパー
# UI用ラベル生成ヘルパー (手札のAPや効果テキストなど)
func _create_ui_label(txt: String, pos: Vector2, color: Color) -> Label:
	var l = Label.new()
	l.text = txt
	l.position = pos
	l.modulate = color
	l.z_index = 3
	# --- 文字の縁取りを追加 ---
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4) # 縁の太さ (ピクセル)
	# ------------------------
	
	add_child(l)
	return l
	

func _on_hand_down(btn: Button, btn_information: Dictionary, card: Dictionary):
	is_pressing = true
	current_press_data = card
	
	# 長押しタイマー開始（既存ロジック）
	get_tree().create_timer(0.1).timeout.connect(func():
		if is_pressing:
			press_time += 0.5
			if press_time >= LONG_PRESS_TIME and not desc_label.visible:
				# 説明テキストの生成（システムボタンの場合は DeckController を通さず直接表示）
				var display_text = []
				if card.has("description"):
					display_text = [card.description]
				else:
					var user = action_order[active_idx].data
					display_text = DeckController.new().card_text(user, card)
				
				Battle_Text = UiSystem.show_dialog(self, display_text, grid_map["C3"], {"type": "popup","speed": 0.0})
	)

	# 画像の拡大処理（安全な取得に変更）
	var scale_target = 1.2 * card_default_size
	
	# 存在するキーだけ処理する
	var keys_to_scale = ["art_id", "frame_id", "ap_icon", "atk_icon", "eff_icon"]
	for key in keys_to_scale:
		var img_id = btn_information.get(key, "")
		if img_id != "":
			var z = ImageController.get_z_index(img_id) + 100
			# システムボタンはもともと小さいのでスケールを調整
			var s = scale_target if "icon" not in key else Vector2(4.5, 4.5)
			ImageController.manipulate_image(img_id, {"scale": s, "duration": 5, "z_index": z})
			
func _on_hand_up(btn: Button, btn_information:Dictionary):
	is_pressing = false
	press_time = 0.0
	desc_label.visible = false
	
	# 点滅の解除
	for anim_id in target_anim_ids:
		AnimationController.set_blink(anim_id, false)
	target_anim_ids.clear()
	var image_data =btn_information.get("frame_id","")
	var label_data =btn_information.get("ap_lbl","")
	#var image_pos = ImageController.get_image_position(image_data)
	var image_scale = card_default_size
	var image_z_index = ImageController.get_z_index(image_data)-100

	for i in 5:
		var pos_ofs =Vector2(0,0)
		match i:
			0 : 
				image_data =btn_information.get("art_id","")
			1 : 
				image_data =btn_information.get("frame_id","")
			2 :#app_icon
				image_data =btn_information.get("ap_icon","")
				image_scale = ap_icon_scale 
			3 :#attack_icon
				image_data =btn_information.get("atk_icon","")
				image_scale = atk_icon_scale
			4 : image_data =btn_information.get("eff_icon" ,"")
		image_z_index = ImageController.get_z_index(image_data)
		ImageController.manipulate_image(image_data,  {"scale":image_scale,"duration":15,"z_index":image_z_index})
	# 画像を元のサイズに戻す
	# 長押し未満ならアクション実行 (クリック判定)
	UiSystem.hide_window(Battle_Text)
		#_execute_card_action(idx, btn.get_meta("action_data"))
# 被ダメージ演出 (赤く3回点滅)
func _play_damage_effect(target_data):
	var id = target_data.id
	var tween = create_tween()
	for i in range(3):
		tween.tween_callback(func():
			AnimationController.set_blink(target_data.anim_id, true, Color.RED)
			if hp_bars.has(id): hp_bars[id].modulate = Color.RED
			if hp_labels.has(id): hp_labels[id].modulate = Color.RED
		)
		tween.tween_interval(0.1)
		tween.tween_callback(func():
			AnimationController.set_blink(target_data.anim_id, false)
			if hp_bars.has(id): hp_bars[id].modulate = Color.WHITE
			if hp_labels.has(id): hp_labels[id].modulate = Color.WHITE
		)
		tween.tween_interval(0.1)

# 回復・バフ演出 (青く光って15フレームで戻る)
func _play_buff_effect(target_data):
	AnimationController.flash_color(target_data.anim_id, Color.CYAN, 15)

# 今後タップした時に呼ばれる関数 (今回はログ出力のみ)
func _on_character_tapped(char_data):
	print(char_data.id + " の詳細ステータスを開きます！ (後日実装)")
func _update_ui_displays():
	for char in status.allies + status.enemies:
		var id = char.id
		var current_pos = Vector2(0,0)
		if grid_map.has(char.grid_key): 
			current_pos = grid_map[char.grid_key]
		if bottom_grid_map.has(char.grid_key): 
			current_pos = bottom_grid_map[char.grid_key]
		if char.hp <1 and char.is_defeat ==false: #敵撃破
			char.is_defeat=true
			AnimationController.stop_animation(char.anim_id)
			var anim_name = AnimationList.MOTION_GROUPS[char["motion_group"]]["defeat"]
			char.anim_id = AnimationController.play_animation(anim_name, grid_map[char.grid_key], {"auto_delete": true})
			hp_bars[id].visible =false
			hp_labels[id].visible =false
		if char.hp>0:
			# HPバーの位置と数値更新
			if hp_bars.has(id):
				hp_bars[id].value = char.hp
				hp_bars[id].position = current_pos + Vector2(-50, 70)
			
			if hp_labels.has(id):
				hp_labels[id].text = str(char.hp) + "/" + str(char.max_hp)
				hp_labels[id].position = current_pos + Vector2(-50, 40)
			# 個別ユニットのステータスUI（シールド・状態異常）を更新
			var base_pos = grid_map[char.grid_key]
			# アイコンを表示する基準点（ユニットの少し右上など）
			var icon_pos = base_pos + Vector2(40, -60) 
	
			# 一旦古いステータスアイコンを消去する仕組みが必要な場合
			# (簡単のため、今回は既存のIDを再利用するか、特定の命名ルールで管理します)
			# 1. シールドの表示（常時チェック）
			var shield_id =char.id + "_shield"
			if char.status_effects.get("shield", 0) > 0:
				ImageController.show_image("icon_shield", icon_pos, {"id": shield_id})
			# 数値の表示（Labelノードを生成して管理するか、デバッグプリント等で対応）
			# 蓄積値 unit_data["shield"] を表示
			else:
				ImageController.erase_image(shield_id,0) # 0なら消す
			# 2. 状態異常の表示
			var effects = char.get("status_effects", {}) # [{"name":"burn", "turns":2}, ...]
			var effect_num =0
			var status_id ={}

			for i in effects.keys():
				print(effects)
				var effect_value = effects[i]
				var effect_icon = StatusEffectList.DATA[i]
				var offset_pos = icon_pos + Vector2(0,effect_num *30) # 横に並べる
				status_id =ImageController.show_image(effect_icon.icon, offset_pos, {"scale": Vector2(1.5, 1.5) ,"z_index":1000+effect_num})
				#print(i,effect_icon.icon,status_id)
		# 蓄積ターン effect["turns"] を表示する処理をここに追加
		# APアイコンの描画（ここが重要！）
		if ap_displays.has(id):
			var ap_node = ap_displays[id]
			ap_node.position = current_pos + Vector2(-40, 90)
			# 一旦古いアイコンを消去
			for child in ap_node.get_children():
				child.queue_free()
			
			# 現在のAP分だけアイコンを並べる
			for i in range(char.get("ap", 0)):
				var ap_icon = Sprite2D.new()
				ap_icon.texture = load(ImageList.DATA["icon"]["ActionPoint"])
				ap_icon.scale = Vector2(0.8, 0.8)
				ap_icon.position = Vector2(i * 15, 0) # 横に並べる
				ap_node.add_child(ap_icon)
				
		if icon_displays.has(id):
			var icon_node = icon_displays[id]
			icon_node.position = current_pos + Vector2(-50, 55)
			# 一旦古いアイコンを消去
			for child in icon_node.get_children():
				child.queue_free()
			var char_icon = Sprite2D.new()
			char_icon.texture = load(ImageList.DATA["icon"][char.icon])
			char_icon.scale = Vector2(1.2, 1.2)
			icon_node.add_child(char_icon)
var deck_sleeves_imgs: Array = []
func _update_deck_ui(dc):
	# 古いスリーブ画像を消去
	for img_id in deck_sleeves_imgs:
		ImageController.erase_image(img_id, 0)
	deck_sleeves_imgs.clear()
	
	var draw_count = dc.draw_pile.size()
	if draw_count == 0: return
	
	var pos = grid_map["A5"]
	# 最大3枚までスリーブを重ねて表示
	var display_count = min(draw_count, 3)
	for i in range(display_count):
		var card = dc.draw_pile[i]
		var offset = Vector2(i * 5, i * -5) # 少しずつ左上にずらす
		var img_id = ImageController.show_image(card.card_sleeve, pos + offset, {"scale":Vector2(card_default_size*0.8),"duration_sec":5})
		deck_sleeves_imgs.append(img_id)


func _check_battle_end():
	var enemies_alive = status.enemies.filter(func(e): return e.hp > 0)
	var allies_alive = status.allies.filter(func(a): return a.hp > 0)
	print(allies_alive,"残りHP")
	if enemies_alive.size() == 0:	
		
		await get_tree().create_timer(5.0).timeout
		var flip_h = action_order[active_idx].data.flip_h
		#AnimationController.stop_animation(user.anim_id)
		#攻撃のアニメ
		for i in allies_alive.size():
			var anim_id =allies_alive[i].anim_id
			print(anim_id)
			AnimationController.stop_animation(anim_id)
			var master_data = InitAllyStatus.DATA[allies_alive[i].id]
			var anim_name = AnimationList.MOTION_GROUPS[master_data["motion_group"]]["victory"]
			var victory = AnimationController.play_animation(anim_name, grid_map[allies_alive[i].grid_key], {"flip_h":allies_alive[i].flip_h})
			
		#await get_tree().create_timer(0.0).timeout
		print(enemies_alive,"全ての敵を倒した！")
		get_tree().change_scene_to_file("res://index/core/map/battle/battle_result.tscn")

		

	if allies_alive.size() == 0:
		# 敗北処理
		get_tree().change_scene_to_file("res://index/core/map/battle/battle_result.tscn")

# ---------------------------------------------------
# 補助関数
# ---------------------------------------------------
func _add_btn(txt, grid_key, type):
	
	var b = Button.new()
	b.text = txt
	if bottom_grid_map.has(grid_key):
		b.position = bottom_grid_map[grid_key]
		b.size = bottom_grid_map["B1_B"]-bottom_grid_map["A0_B"]
	else:
		b.position = grid_map[grid_key]
		b.size = grid_map["B1"]-grid_map["A0"]
	b.pressed.connect(_on_btn_pressed.bind(type, b))
	add_child(b)
	return b
func _add_label(txt: String, grid_key: String, color: Color) -> Label:
	var l = Label.new()
	l.text = txt
	if grid_key != "" and grid_map.has(grid_key):
		l.position = grid_map[grid_key]
		l.modulate = color# --- 字の縁取りを追加 ---
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 6) # 少し太めの縁
		l.add_theme_font_size_override("font_size", 20)  # ついでに文字サイズも調整可能
	add_child(l)
	return l
# UI用ラベル生成ヘルパー
func _on_flick_changed(num: int):
	# まず前のプレビューを解除
	_on_flick_canceled()

	if num == 5 or not keypad_map.has(num): return

	var btn = keypad_map[num]
	if btn.visible:
		# ボタンから情報を抜き取って長押し演出を開始
		var info = btn.get_meta("btn_info") if btn.has_meta("btn_info") else {}
		var data = btn.get_meta("action_data")
		
		_on_hand_down(btn, info, data)
		last_flick_btn = btn
func _on_flick_executed(num: int):
	if keypad_map.has(num):
		var btn = keypad_map[num]
		if btn.visible:
			# ボタンの種類（action_a〜f）を特定して実行
			var type = _get_type_from_btn(btn)
			_on_btn_pressed(type, btn)
	
	_on_flick_canceled() # 演出を元に戻す

# ヘルパー関数：ボタンオブジェクトから種別を判定
func _get_type_from_btn(btn):
	if btn in hand_buttons: return "action_a"
	if btn == system_buttons[0]: return "action_b"
	if btn == system_buttons[1]: return "action_c"
	if btn == system_buttons[2]: return "action_d"
	if btn == system_buttons[3]: return "action_f"
	return ""
func _on_flick_canceled():
	if last_flick_btn:
		var info = last_flick_btn.get_meta("btn_info") if last_flick_btn.has_meta("btn_info") else {}
		_on_hand_up(last_flick_btn, info)
		last_flick_btn = null
# UI用ラベル生成ヘルパー (手札のAPや効果テキストなど)

func _init_item_menu():
	item_menu = Panel.new()
	item_menu.size = Vector2(300, 200)
	item_menu.position = Vector2(100, 100)
	item_menu.visible = false
	add_child(item_menu)
	
	var close_btn = Button.new()
	close_btn.text = "閉じる"
	close_btn.pressed.connect(func(): item_menu.visible = false)
	item_menu.add_child(close_btn)
	
	# インベントリ内のアイテムを表示するボタンを並べる (簡易実装)
	var y = 40
	for item_id in inventory.items:
		var ib = Button.new()
		ib.text = Item_List.DATA[item_id].name
		ib.position = Vector2(10, y)
		ib.pressed.connect(_handle_item_use.bind(item_id))
		item_menu.add_child(ib)
		y += 40
func _execute_enemy_ai(user_data):
	var action_key = ActionList.ENEMY_ACTIONS.keys().pick_random()
	var action = ActionList.ENEMY_ACTIONS[action_key]
	info_label.text = user_data.id + " の " + action.name
	print(info_label.text)
	# 横揺れ演出を実行
	AnimationController.shake_animation(user_data.anim_id)
	
	await get_tree().create_timer(1.0).timeout
	# ... (以下既存の処理)
	ActionController.execute_action(user_data, action, status.allies, status.enemies)
	_update_ui_displays()
	_finish_character_turn()
