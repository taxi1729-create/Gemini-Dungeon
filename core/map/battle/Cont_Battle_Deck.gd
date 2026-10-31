extends Node
class_name DeckController
## 戦闘中の1キャラ分の山札・手札（4枠：0=8上 1=4左 2=2下 3=6右）・捨て札・保留枠

var draw_pile: Array = []
var hand: Array = [null, null, null, null]
var discard_pile: Array = []
var hold = null  # 保留カード（ターンをまたいで残る）


func setup_battle_deck(master_deck_ids: Array) -> void:
	draw_pile.clear()
	discard_pile.clear()
	hand = [null, null, null, null]
	hold = null
	for card_id in master_deck_ids:
		var c := ActionList.make_card(card_id)
		if not c.is_empty():
			draw_pile.append(c)
	draw_pile.shuffle()


## 空いている枠をカードで埋める（最大 amount 枚）。引いた枠の番号を返す
func draw_cards(amount: int) -> Array:
	var filled: Array = []
	for i in amount:
		var empty_slot := hand.find(null)
		if empty_slot == -1:
			break
		if draw_pile.is_empty():
			_shuffle_discard_to_draw()
		if draw_pile.is_empty():
			break
		hand[empty_slot] = draw_pile.pop_back()
		filled.append(empty_slot)
	return filled


func play_and_discard(hand_index: int) -> void:
	if hand[hand_index] != null:
		discard_pile.append(hand[hand_index])
		hand[hand_index] = null


func play_hold() -> void:
	if hold != null:
		discard_pile.append(hold)
		hold = null


## 手札の slot を保留枠へ。保留中のカードがあれば、そのカードは空いた slot へ戻る
func put_on_hold(slot: int) -> void:
	var c = hand[slot]
	if c == null:
		return
	hand[slot] = hold
	hold = c


func discard_hand() -> void:
	for i in hand.size():
		if hand[i] != null:
			discard_pile.append(hand[i])
	hand = [null, null, null, null]


func turn_end_and_discard() -> void:
	discard_hand()


func _shuffle_discard_to_draw() -> void:
	draw_pile = discard_pile.duplicate()
	draw_pile.shuffle()
	discard_pile.clear()


## 説明文
static func card_text(user: Dictionary, action: Dictionary) -> String:
	var lines: Array = []
	var head: String = action.get("name", "")
	match action.get("rarity", ""):
		"rare": head += "　★レア"
		"super_rare": head += "　★★超レア"
	lines.append(head)
	var target_text := ""
	match action.get("target", ""):
		"enemy_all": target_text = "敵全体"
		"front_enemy_single": target_text = "一番近い敵1体"
		"front_enemy_group": target_text = "自分の側（左右）の敵全員"
		"self": target_text = "自分"
		"ally_all": target_text = "味方全体"
	var row := "対象: " + target_text
	if action.has("ap"):
		row += "　AP %d" % action.ap
	lines.append(row)
	lines.append("効果: " + effect_text(user, action))
	return "\n".join(lines)


static func effect_text(user: Dictionary, action: Dictionary) -> String:
	if action.has("power"):
		var atk := ActionController.get_atk(user) if not user.is_empty() else 0
		if atk != 0 and not action.get("fixed", false):
			return "%d ダメージ（攻撃力 %+d）" % [action.power, atk]
		return "%d ダメージ" % action.power
	match action.get("effect", ""):
		"add_shield": return "%d ブロック" % action.eff_val
		"add_ap": return "AP +%d" % action.eff_val
		"heal": return "HP %d 回復" % action.eff_val
		"draw": return "%d 枚引く（空き枠まで）" % action.eff_val
		"add_status":
			var st: Dictionary = StatusEffectList.DATA[action.status]
			return "%s %d（%s）" % [st.name, action.eff_val, st.desc]
		"turnabout": return "上下左右の手札をすべて捨てて4枚引く。攻撃力 +1"
		"extra_turn": return "ターン終了時、もう一度ターンを得る"
		"swap": return "前後の位置を入れ替える"
	return ""
