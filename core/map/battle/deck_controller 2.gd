# core/map/battle/deck_controller.gd
extends Node
class_name DeckController

var draw_pile = []
var hand = [null,null,null,null]
var discard_pile = []

# バトル開始時に、CurrentDeckのデータを受け取って山札を作る
func setup_battle_deck(master_deck_ids: Array):
	draw_pile.clear()
	hand = [null,null,null,null]
	discard_pile.clear()
	
	# IDの文字列リストを、実際のカードデータ（辞書）に変換して山札へ入れる
	for card_id in master_deck_ids:
		if ActionList.ALLY_CARDS.has(card_id):
			draw_pile.append(ActionList.ALLY_CARDS[card_id].duplicate(true))
			
	# 初期シャッフル
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
