extends Node2D

# --- 外部データへの参照 (Autoload前提) ---
@onready var status = CurrentStatus
@onready var inventory = Inventory

# --- 設定・状態管理 ---
const LONG_PRESS_TIME = 0.5
const GRID_COLS = ["A", "B", "C", "D", "E", "F", "G", "H", "I"]
var grid_map = {}      # 座標データ {"A0": Vector2, ...}
#var deck_sleeves_imgs = func _update_ui_displays():[] # 重ねたスリーブの画像ID保持用 (変数宣言部に追加)

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
var info_label: Label
var item_menu: Panel # アイテム選択用パネル

var hand_ui_elements = [] # 手札の描画IDとLabelを保持する配列
var desc_label: Label     # B6に表示する説明用ラベル
var target_anim_ids = []  # 点滅中のアニメID保持用
var buff_displays = {} # 状態異常アイコン表示用ノード
var char_buttons = {}  # キャラタップ判定用ボタン
func _ready():# ... 既存の初期化 ...

	_init_grid()
	desc_label = _add_label("", "A5", Color.WHITE)
	desc_label.visible = false
	_init_battle_data()
	_create_ui()
	_start_global_turn()

# ---------------------------------------------------
# 1. システム初期化
# ---------------------------------------------------

func _init_grid():
	var win = get_viewport_rect().size
	var sep_x =9
	var sep_y =8
	var cw = win.x / sep_x
	var ch = win.y / sep_y
	for i in range(sep_x):
		for j in range(sep_y):
			grid_map[GRID_COLS[i] + str(j)] = Vector2(cw * i + cw / 2, ch * j + ch / 2)

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
	var e_positions = ["I1", "A1", "F0", "B0"] # 指定された敵配置
	
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

func _create_ui():
	# 味方位置設定
	status.allies[0]["grid_key"] = "D2"
	status.allies[1]["grid_key"] = "F2"
	
	# 全キャラのステータス表示
	for ally in status.allies: _add_status_ui(ally)
	for enemy in status.enemies: _add_status_ui(enemy)
	
	# 手札ボタン (グリッド座標を参考に配置)
	var hand_pos = ["C5", "E4", "G5", "E6"]
	for i in range(4):
		var btn = _add_btn("---", hand_pos[i], "action_a")
		hand_buttons.append(btn)
	
	# 特殊ボタン
	_add_btn("入替", "C4", "action_b")
	_add_btn("必殺", "E5", "action_c")
	_add_btn("終了", "G4", "action_d")
	_add_btn("道具", "C6", "action_f")
	
	info_label = _add_label("Battle Start!", "B7", Color.CYAN)
	_init_item_menu()
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
	# TODO: ここでImageListからHPバーのテクスチャをロードしてください
	# bar.texture_under = load("res://assets/ui/bar_under.png")
	# bar.texture_progress = load("res://assets/ui/bar_progress.png")
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
	info_label.text = user_data.id + " のターン"
	var dc = deck_controllers[user_data.id]
	user_data.ap += 1
	
	# アニメーションを turn に変更
	
	AnimationController.stop_animation(user_data.anim_id)
	var master_data = InitAllyStatus.DATA[user_data.id]
	var anim_name = AnimationList.MOTION_GROUPS[master_data["motion_group"]]["turn"]
	user_data.anim_id = AnimationController.play_animation(anim_name, grid_map[user_data.grid_key], {"is_loop":true})
	#print(user_data)
	_update_ui_displays()

	dc.draw_cards(4)
	_update_hand_ui(dc)

func _execute_card_action(hand_idx: int, action_data: Dictionary):
	var user = action_order[active_idx].data
	if user.ap < action_data.ap:
		info_label.text = "AP不足！"
		return
	
	# AP消費
	user.ap -= action_data.ap
	#print(user)
	# アクション実行
	ActionController.execute_action(user, action_data, status.allies, status.enemies)
	#アニメ更新、ターンのアニメ消去
	AnimationController.stop_animation(user.anim_id)
	#攻撃のアニメ
	var master_data = InitAllyStatus.DATA[user.id]
	var anim_name = AnimationList.MOTION_GROUPS[master_data["motion_group"]]["attack"]
	user.anim_id = AnimationController.play_animation(anim_name, grid_map[user.grid_key], {})
	if action_data.target == "front_enemy_single":
		var target_data =ActionController._resolve_targets(user, action_data.target, status.allies, status.enemies)
		for target_key in target_data:
			var move_vector = (grid_map[target_key.grid_key] + grid_map[user.grid_key])/2
			AnimationController.move_animation_arc(user.anim_id, move_vector, {"arc_height":-200,"duration":10})
	#await AnimationController.wait_for_animation(user.anim_id, true)
	get_tree().create_timer(0.7).timeout.connect(func():
		AnimationController.stop_animation(user.anim_id)
		anim_name = AnimationList.MOTION_GROUPS[master_data["motion_group"]]["turn"]
		user.anim_id = AnimationController.play_animation(anim_name, grid_map[user.grid_key], {"is_loop":true}))
	# デッキ処理：使用したカードを捨札へ、新しいカードを1枚引く
	var start_pos = hand_buttons[hand_idx].global_position + Vector2(60, 30) # ボタンの中心付近
	var end_pos = grid_map["G6"]
	
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
	_check_battle_end()

# --- アクションB: 位置交代 ---
func _execute_swap():
	if status.allies.size() < 2: return
	var user = action_order[active_idx].data
	var partner = status.allies[0] if status.allies[1] == user else status.allies[1]
	
	var temp_key = user.grid_key
	user.grid_key = partner.grid_key
	partner.grid_key = temp_key
	
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
			btn.set_meta("action_data", card)
			btn.set_meta("hand_idx", i)
			btn.visible = true
			btn.self_modulate.a = 0.0 # ボタン自体は透明にして当たり判定だけ残す
			
			var pos = btn.global_position + (btn.size / 2.0)
			
			# 1. フレームとイラスト描画 (ImageController想定)
			var art_id = ImageController.show_image(card.image, pos, {"scale":card_default_size,"duration":5})
			var frame_id = ImageController.show_image(card.card_frame, pos, {"scale":card_default_size,"duration":5})

			hand_ui_elements.append_array([frame_id, art_id])
			print(hand_ui_elements)
			# 2. 消費AP (右上)
			var ap_icon = ImageController.show_image("ActionPoint", pos + Vector2(50, -50), {})
			var ap_lbl = _create_ui_label(str(card.ap), pos + Vector2(65, -45), Color.WHITE)
			hand_ui_elements.append_array([ap_icon, ap_lbl])
			
			# 3. 攻撃力 (左上、パワー0以外)
			var power = card.get("power", 0)
			if power > 0:
				var atk_icon = ImageController.show_image("sword_icon", pos + Vector2(-50, -50), {})
				var atk_lbl = _create_ui_label(str(power), pos + Vector2(-35, -40), Color.WHITE)
				hand_ui_elements.append_array([atk_icon, atk_lbl])
				
			# 4. 対象・効果アイコン (中央下)
			var eff_text = card.get("target","")
			if card.has("status_effect"):
				var status_icon = ImageController.show_image(card.status_effect.icon, pos + Vector2(-90, -60), {})
				eff_text += "\n" + card.status_effect.name + " " + str(card.status_effect.duration) + "T"
			var eff_lbl = _create_ui_label(eff_text, pos + Vector2(-30, 20), Color.WHITE)
			hand_ui_elements.append(eff_lbl)
			#print(btn.button_down.is_connected)
			# ボタンのシグナル接続 (長押し・拡大用)
			#if not btn.button_down.is_connected(_on_hand_down):
			btn.button_down.connect(_on_hand_down.bind(btn, frame_id, art_id, card))
			btn.button_up.connect(_on_hand_up.bind(btn, frame_id, art_id))
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
	
# --- 長押しと拡大・縮小処理 ---
func _on_hand_down(btn: Button, frame_id: String, art_id: String, card: Dictionary):
	is_pressing = true
	press_time = 0.0
	current_press_data = card
	_process(300)
	# 画像の拡大
	ImageController.manipulate_image(frame_id,  {"pos":ImageController.get_image_position(frame_id),"scale":2*card_default_size,"duration":10})
	ImageController.manipulate_image(art_id, {"pos":ImageController.get_image_position(art_id),"scale":2*card_default_size,"duration":10})

func _on_hand_up(btn: Button, frame_id: String, art_id: String):
	is_pressing = false
	desc_label.visible = false
	
	# 点滅の解除
	for anim_id in target_anim_ids:
		AnimationController.set_blink(anim_id, false)
	target_anim_ids.clear()
	
	# 画像を元のサイズに戻す
	ImageController.manipulate_image(frame_id, {"scale":card_default_size,"duration":15})
	ImageController.manipulate_image(art_id, {"scale":card_default_size,"duration":15})
	
	# 長押し未満ならアクション実行 (クリック判定)
	if press_time < LONG_PRESS_TIME:
		var idx = btn.get_meta("hand_idx")
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
func _process(delta):
	if is_pressing:
		press_time += delta
		if press_time >= LONG_PRESS_TIME and not desc_label.visible:
			# 長押し成立時：説明表示
			desc_label.text = current_press_data.get("description", "説明がありません。")
			desc_label.visible = true
			
			# 対象の点滅処理
			target_anim_ids.clear()
			var target_type = current_press_data.get("target", "")
			var targets = []
			#ここの処理が違う。
			print("_process光る判定がおかしい")
			if "enemy" in target_type: targets = status.enemies
			elif "ally" in target_type: targets = status.allies
			
			for t in targets:
				AnimationController.set_blink(t.anim_id, true)
				target_anim_ids.append(t.anim_id)
func _update_ui_displays():
	for char in status.allies + status.enemies:
		var id = char.id
		if not grid_map.has(char.grid_key): continue
		var current_pos = grid_map[char.grid_key]
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
				hp_bars[id].position = current_pos + Vector2(-50, 40)
			
			if hp_labels.has(id):
				hp_labels[id].text = str(char.hp) + "/" + str(char.max_hp)
				hp_labels[id].position = current_pos + Vector2(-50, 55)
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
			for i in effects.keys():
				var effect_value = effects[i]
				var effect_icon = StatusEffectList.DATA[i]
				var offset_pos = icon_pos + Vector2(0,effect_num *3) # 横に並べる
				var status_id =ImageController.show_image(effect_icon.icon, offset_pos, {"scale": Vector2(0.8, 0.8) })
				#print(i,effect_icon.icon,status_id)
		# 蓄積ターン effect["turns"] を表示する処理をここに追加
		# APアイコンの描画（ここが重要！）
		if ap_displays.has(id):
			var ap_node = ap_displays[id]
			ap_node.position = current_pos + Vector2(-50, 100)
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
	#print(enemies_alive,"残りHP")
	if enemies_alive.size() == 0:
		get_tree().change_scene_to_file("res://core/map/battle/battle_result.tscn")
		print(enemies_alive,"全ての敵を倒した！")
		
	var allies_alive = status.allies.filter(func(a): return a.hp > 0)
	if allies_alive.size() == 0:
		# 敗北処理
		get_tree().change_scene_to_file("res://core/map/battle/battle_result.tscn")

# ---------------------------------------------------
# 補助関数
# ---------------------------------------------------

func _add_btn(txt, grid_key, type):
	var b = Button.new()
	b.text = txt
	b.position = grid_map[grid_key]
	b.size = grid_map["B1"]-grid_map["A0"]
	b.pressed.connect(_on_btn_pressed.bind(type, b))
	add_child(b)
	return b
# 汎用ラベル生成ヘルパー (画面上部のインフォメーションなど)
func _add_label(txt: String, grid_key: String, color: Color) -> Label:
	var l = Label.new()
	l.text = txt
	if grid_key != "" and grid_map.has(grid_key):
		l.position = grid_map[grid_key]
	l.modulate = color
	
	# --- 文字の縁取りを追加 ---
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6) # 少し太めの縁
	l.add_theme_font_size_override("font_size", 20)  # ついでに文字サイズも調整可能
	# ------------------------
	
	add_child(l)
	return l
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
