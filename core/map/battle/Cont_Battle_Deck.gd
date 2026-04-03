# core/map/battle/deck_controller.gd
extends Node
class_name DeckController

var draw_pile = []
var hand = [null,null,null,null]
var discard_pile = []

# バトル開始時に、CurrentDeckのデータを受け取って山札を作る
func setup_battle_deck(master_deck_ids: Array):
	draw_pile.clear()
	hand = [null, null, null, null]
	discard_pile.clear()
	
	for card_id in master_deck_ids:
		var card_exist =0
		var card_data ={}
		if ActionList.ALLY_CARDS["common"].has(card_id):
			# --- 1. 元データをコピーして、このカード専用の辞書を作る ---
			card_data = ActionList.ALLY_CARDS["common"][card_id].duplicate(true)
			# ここに ID も持たせておくと、後で便利です
			card_data["id"] = card_id
			card_data["rarity"] = "normal"
			card_exist =1
		if ActionList.ALLY_CARDS["rare"].has(card_id):
			# --- 1. 元データをコピーして、このカード専用の辞書を作る ---
			card_data = ActionList.ALLY_CARDS["rare"][card_id].duplicate(true)
			# ここに ID も持たせておくと、後で便利です
			card_data["id"] = card_id
			card_data["rarity"] = "rare"
			card_exist =1
		if ActionList.ALLY_CARDS["super_rare"].has(card_id):
			# --- 1. 元データをコピーして、このカード専用の辞書を作る ---
			card_data = ActionList.ALLY_CARDS["super_rare"][card_id].duplicate(true)
			# ここに ID も持たせておくと、後で便利です
			card_data["id"] = card_id
			card_data["rarity"] = "super_rare"
			card_exist =1
		if card_exist==1:
			# --- 2. レアリティのデフォルト値設定 (コピーに対して行うのでOK) ---
			if not card_data.has("card_sleeve"):
				card_data["card_sleeve"] = "sleeve_magic"			
			# --- 3. タイプのルールに基づいたフレーム設定 ---
			if not card_data.has("card_frame"):
				match card_data.get("type", ""):
					"attack":
						card_data["card_frame"] = "frame_red"
					"skill":
						card_data["card_frame"] = "frame_blu"
					"unselectable":
						card_data["card_frame"] = "frame_gre"
			
			# --- 4. 整形が終わったデータを山札に追加 ---
			draw_pile.append(card_data)
	
	# 必要ならここでシャッフル
	draw_pile.shuffle()

func draw_cards(amount: int):
	for i in range(amount):
		# 空いている（nullの）スロットを探す
		var empty_slot = hand.find(null)
		
		# 空きスロットがない、または山札が空なら終了
		if empty_slot == -1: break
		
		if draw_pile.is_empty():
			_shuffle_discard_to_draw()
		
		if not draw_pile.is_empty():
			# 見つかった空きスロットにカードを入れる
			hand[empty_slot] = draw_pile.pop_back()

func play_and_discard(hand_index: int):
	# index指定で直接アクセスし、存在すれば捨てる
	if hand[hand_index] != null:
		var card = hand[hand_index]
		discard_pile.append(card)
		# 配列から削除(remove_at)せず、nullを代入して「空き」にする
		hand[hand_index] = null
	print("discard_pile=",discard_pile.size(),"draw_pile=",draw_pile.size())
		
func turn_end_and_discard():
	print("turn_end")
	for i in range(4):
		if i < hand.size():
			var card = hand[i]
			discard_pile.append(card)
	hand = [null,null,null,null]
		
func _shuffle_discard_to_draw():
	# 捨札を山札に戻してシャッフル
	draw_pile = discard_pile.duplicate(true)
	draw_pile.shuffle()
	discard_pile.clear()

func card_text(user: Dictionary, action: Dictionary)-> Array:
	var name_text =action.name
	var ap =action.get("ap", -1)
	var ap_icon = ImageList.DATA.icon.ActionPoint
	var ap_text =""
	if ap >0 or ap ==0:
		ap_text="消費AP(%s) %d" %[ap_icon,ap]	
	print(action)

	var power = action.get("power",0)
	var user_atk = user.atk
	var power_text=""
	if (user_atk + power)>0:
		if user_atk >0:
			power_text="攻撃力 %d + %d" %[power,user_atk]
		power_text="攻撃力 %d" %[power]		
	var type_icon =""

	match action.type:
		"attack":
			type_icon = ImageList.DATA.icon.sword_icon
		"skill":
			type_icon = ImageList.DATA.icon.star
		"unselectable":
			type_icon = ImageList.DATA.icon.No_Use
	var eff_icon =""
	var eff_name=""
	var eff_text =""
	match action.get("effect",""):
		"add_ap":
			eff_name="AP"
			eff_icon = ap_icon
		"add_shield":
			eff_name ="シールド"
			eff_icon = ImageList.DATA.icon.Shield_Icon
		"add_status":
			var eff_data = StatusEffectList.DATA[action.status]
			eff_name =eff_data.name
			var eff_label =eff_data.icon
			eff_icon =ImageList.DATA.icon[eff_label]
	if eff_icon != "":
		var eff_val = action.eff_val
		eff_text ="\n効果: %s (%s) を%d与える" % [eff_name,eff_icon,eff_val]
	var target_icon =""
	var target_text =""
	match action.target:
		"enemy_all":
			target_icon = ImageList.DATA.icon.enemy_all
			target_text = "敵全体"
		"front_enemy_single":
			target_icon = ImageList.DATA.icon.enemy_1
			target_text= "目の前の敵１体"
		"self":
			var user_icon =user.icon
			target_icon=ImageList.DATA.icon[user_icon]
			target_text= "自身"
		"ally_all":
			target_icon=""
			target_text= "味方全体"
	var text =["%s (%s) \n 効果対象(%s)%s　%s  %s %s"  %[name_text,type_icon,target_icon,target_text,power_text,ap_text,eff_text]]
	return text
