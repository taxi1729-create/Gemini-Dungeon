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
		if ActionList.ALLY_CARDS.has(card_id):
			# --- 1. 元データをコピーして、このカード専用の辞書を作る ---
			var card_data = ActionList.ALLY_CARDS[card_id].duplicate(true)
			# ここに ID も持たせておくと、後で便利です
			card_data["id"] = card_id
			
			# --- 2. レアリティのデフォルト値設定 (コピーに対して行うのでOK) ---
			if not card_data.has("rarity"):
				card_data["rarity"] = "normal"
			if not card_data.has("card_sleeve"):
				card_data["card_sleeve"] = "sleeve_magic"			
			# --- 3. タイプのルールに基づいたフレーム設定 ---
			if not card_data.has("card_frame"):
				match card_data.get("type", ""):
					"attack":
						card_data["card_frame"] = "frame_red"
					"skill":
						card_data["card_frame"] = "frame_blu"
					_:
						card_data["card_frame"] = "frame_green"
			
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
