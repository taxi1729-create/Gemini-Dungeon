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
	var sep_x =8
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
	var e_positions = ["G1", "A1", "F0", "B0"] # 指定された敵配置
	
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
		e_data["status_effects"] = {}
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
	print(data)
	var id = data.id
	var pos = grid_map[data.grid_key]
	var is_ally = data.get("side", "ally") == "ally"
	# 1. マスターデータの取得 (アイコンやモーションの参照用)
	var master_data = InitAllyStatus.DATA[id] if is_ally else EnemyList.DATA[data.base_id]
	
	# 2. アニメーションの再生 (待機モーションをループ再生)
	var motion_group = master_data["motion_group"]
	var idle_anim = AnimationList.MOTION_GROUPS[motion_group]["idle"]
	var flip = not is_ally # 敵は左向き(フリップ)にする
	
	# アニメーションコントローラー呼び出し (60フレーム周期でループ)
	var anim_id = AnimationController.play_animation(idle_anim, pos, Vector2(0.5, 0.5), Color.WHITE, 0.0, flip, true)
	data["anim_id"] = anim_id # 後で操作できるようにIDを保存
	
	# 3. 名前ラベルの追加
	var l = Label.new()
	#print(master_data["id"])
	l.text = data.id + str(master_data["hp"]) + "/" + str(master_data["max_hp"])
	l.position = pos + Vector2(-50, -85)
	$Characters.add_child(l)
		# HP数値ラベル
	hp_labels[id] = l
	
	# HPバー
	var bar = ProgressBar.new()
	bar.size = Vector2(100, 20)
	bar.position = pos + Vector2(-50, 40)
	bar.max_value = data.max_hp
	bar.value = data.hp
	add_child(bar)
	hp_bars[id] = bar
	

	
# 【追加】5. キャラクターアイコンの表示 (HPバーの左側に配置)
	var icon_path = ImageList.DATA["icon"][master_data["icon"]]
	var icon_sprite = Sprite2D.new()
	icon_sprite.texture = load(icon_path)
	icon_sprite.position = pos + Vector2(-70, 45) # HPバーの少し左
	icon_sprite.scale = Vector2(1, 1)         # アイコンのサイズ調整
	$Characters.add_child(icon_sprite)
	
	if not is_ally:
		# 敵の場合は、識別用の数字("スライム_0"の"0"の部分)を取り出して表示
		var num_str = data.id.split("_")[-1]
		var num_label = Label.new()
		num_label.text = num_str
		num_label.position = Vector2(10, -20) # アイコンの右上に配置
		num_label.add_theme_color_override("font_color", Color.RED)
		icon_sprite.add_child(num_label)

	# 【修正】6. AP表示用のコンテナ(箱)を準備
	if data.has("ap"):
		var ap_node = Node2D.new()
		ap_node.position = pos + Vector2(-50, 75) # HPバーの下あたり
		$Characters.add_child(ap_node)
		ap_displays[data.id] = ap_node # ap_labels の代わりに ap_displays を使う

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
	user_data.anim_id = AnimationController.play_animation(anim_name, grid_map[user_data.grid_key], Vector2(1,1), Color.WHITE, 0.0, false, true)
	
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
	
	# アクション実行
	ActionController.execute_action(user, action_data, status.allies, status.enemies)
	
	# デッキ処理：使用したカードを捨札へ、新しいカードを1枚引く
	var start_pos = hand_buttons[hand_idx].global_position + Vector2(60, 30) # ボタンの中心付近
	var end_pos = grid_map["G6"]
	
	# 0フレーム(一瞬)でフレーム画像を表示
	var throw_img = ImageController.show_image(action_data.frame, start_pos, Vector2(0.4,0.4), Color.WHITE, 0.0, false, 0)
	# 30フレーム(0.5秒)かけてG6へ移動させながら回転
	ImageController.manipulate_image(throw_img, end_pos, Vector2(0, 0), Color.WHITE, 120.0, false, 30)
	
	# 0.5秒後に画像を消去するタイマーをセット
	get_tree().create_timer(0.5).timeout.connect(func():
		ImageController.erase_image(throw_img, 15)
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
			var frame_id = ImageController.show_image(card.frame, pos, Vector2(0.5,0.5), Color.WHITE, 0.0, false, 1)
			var art_id = ImageController.show_image(card.image, pos, Vector2(0.5,0.5), Color.WHITE, 0.0, false, 0)
			hand_ui_elements.append_array([frame_id, art_id])
			
			# 2. 消費AP (右上)
			var ap_icon = ImageController.show_image("ActionPoint", pos + Vector2(30, -30), Vector2(0.4, 0.4), Color.WHITE, 0.0, false, 2)
			var ap_lbl = _create_ui_label(str(card.ap), pos + Vector2(25, -40), Color.WHITE)
			hand_ui_elements.append_array([ap_icon, ap_lbl])
			
			# 3. 攻撃力 (左上、パワー0以外)
			var power = card.get("power", 0)
			if power > 0:
				var atk_icon = ImageController.show_image("ActionPoint", pos + Vector2(-30, -30), Vector2(0.4, 0.4), Color.RED, 0.0, false, 2)
				var atk_lbl = _create_ui_label(str(power), pos + Vector2(-35, -40), Color.WHITE)
				hand_ui_elements.append_array([atk_icon, atk_lbl])
				
			# 4. 対象・効果アイコン (中央下)
			var eff_text = card.get("target", "単体")
			if card.has("status_effect"):
				eff_text += "\n" + card.status_effect.type + " " + str(card.status_effect.duration) + "T"
			var eff_lbl = _create_ui_label(eff_text, pos + Vector2(-30, 20), Color.WHITE)
			hand_ui_elements.append(eff_lbl)
			
			# ボタンのシグナル接続 (長押し・拡大用)
			if not btn.button_down.is_connected(_on_hand_down):
				btn.button_down.connect(_on_hand_down.bind(btn, frame_id, art_id, card))
				btn.button_up.connect(_on_hand_up.bind(btn, frame_id, art_id))
		else:
			btn.visible = false

# UI用ラベル生成ヘルパー
func _create_ui_label(txt: String, pos: Vector2, color: Color) -> Label:
	var l = Label.new()
	l.text = txt
	l.position = pos
	l.modulate = color
	l.z_index = 3
	add_child(l)
	return l

# --- 長押しと拡大・縮小処理 ---
func _on_hand_down(btn: Button, frame_id: String, art_id: String, card: Dictionary):
	is_pressing = true
	press_time = 0.0
	current_press_data = card
	
	# 画像の拡大
	ImageController.manipulate_image(frame_id, ImageController.get_image_position(frame_id), Vector2(1.1, 1.1), Color.WHITE, 0.0, false, 5)
	ImageController.manipulate_image(art_id, ImageController.get_image_position(art_id), Vector2(1.1, 1.1), Color.WHITE, 0.0, false, 5)

func _on_hand_up(btn: Button, frame_id: String, art_id: String):
	is_pressing = false
	desc_label.visible = false
	
	# 点滅の解除
	for anim_id in target_anim_ids:
		AnimationController.set_blink(anim_id, false)
	target_anim_ids.clear()
	
	# 画像を元のサイズに戻す
	ImageController.manipulate_image(frame_id, ImageController.get_image_position(frame_id), Vector2(0.5, 0.5), Color.WHITE, 0.0, false, 5)
	ImageController.manipulate_image(art_id, ImageController.get_image_position(art_id), Vector2(0.5, 0.5), Color.WHITE, 0.0, false, 5)
	
	# 長押し未満ならアクション実行 (クリック判定)
	if press_time < LONG_PRESS_TIME:
		var idx = btn.get_meta("hand_idx")
		_execute_card_action(idx, btn.get_meta("action_data"))

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
			if "enemy" in target_type: targets = status.enemies
			elif "ally" in target_type: targets = status.allies
			
			for t in targets:
				AnimationController.set_blink(t.anim_id, true)
				target_anim_ids.append(t.anim_id)
func _update_ui_displays():
	for char in status.allies + status.enemies:
		var id = char.id
		if hp_bars.has(id):
			hp_bars[id].value = char.hp
			hp_bars[id].position = grid_map[char.grid_key] + Vector2(-50, 40)
			hp_labels[id].text = str(char.hp) + "/" + str(char.max_hp)
			hp_labels[id].position = grid_map[char.grid_key] + Vector2(-50, 60)
			
			# 【追加・修正】AP画像の更新処理
			if ap_displays.has(id):
				var ap_node = ap_displays[id]
				var ap_val = char.get("ap", 0)
				
				# まず古いAP表示(画像やラベル)をすべて消去する
				for child in ap_node.get_children():
					child.queue_free()
				
				if ap_val > 0:
					var ap_img_path = ImageList.DATA["icon"]["ActionPoint"]
					
					if ap_val < 6:
						# 5個以下：所持数ぶん並べて表示
						for i in range(ap_val):
							var sprite = Sprite2D.new()
							sprite.texture = load(ap_img_path)
							sprite.position = Vector2(i * 15, 20) # 20ピクセルずつ右にずらす
							sprite.scale = Vector2(0.5, 0.5)
							ap_node.add_child(sprite)
					else:
						# 6個以上：画像1つと、その上に所持数を表示
						var sprite = Sprite2D.new()
						sprite.texture = load(ap_img_path)
						sprite.position = Vector2(0, 0)
						sprite.scale = Vector2(0.5, 0.5)
						ap_node.add_child(sprite)
						
						var l = Label.new()
						l.text = "x" + str(ap_val)
						l.position = Vector2(10, -10) # 画像の右上に被せる
						ap_node.add_child(l)
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
		var offset = Vector2(i * -3, i * -3) # 少しずつ左上にずらす
		var img_id = ImageController.show_image(card.sleeve, pos + offset, Vector2(0.4,0.4), Color.WHITE, 0.0, false, 10)
		deck_sleeves_imgs.append(img_id)


func _check_battle_end():
	var enemies_alive = status.enemies.filter(func(e): return e.hp > 0)
	if enemies_alive.size() == 0:
		get_tree().change_scene_to_file("res://core/map/battle/battle_result.tscn")
	
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
	b.size = Vector2(80, 40)
	b.pressed.connect(_on_btn_pressed.bind(type, b))
	add_child(b)
	return b

func _add_label(txt, grid_key, color):
	var l = Label.new()
	l.text = txt
	l.position = grid_map[grid_key]
	l.modulate = color
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
	# 簡易AI：ActionListからランダムに攻撃
	var action_key = ActionList.ENEMY_ACTIONS.keys().pick_random()
	var action = ActionList.ENEMY_ACTIONS[action_key]
	info_label.text = user_data.id + " の " + action.name
	await get_tree().create_timer(1.0).timeout
	ActionController.execute_action(user_data, action, status.allies, status.enemies)
	_update_ui_displays()
	_finish_character_turn()
