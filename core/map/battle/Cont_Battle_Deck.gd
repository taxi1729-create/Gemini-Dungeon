extends Node
class_name DeckController
## 戦闘中の1キャラ分の山札・手札（4枠）・捨て札

var draw_pile: Array = []
var hand: Array = [null, null, null, null]
var discard_pile: Array = []


func setup_battle_deck(master_deck_ids: Array) -> void:
	draw_pile.clear()
	discard_pile.clear()
	hand = [null, null, null, null]
	for card_id in master_deck_ids:
		var c := ActionList.make_card(card_id)
		if not c.is_empty():
			draw_pile.append(c)
	draw_pile.shuffle()


## 空いている枠をカードで埋める（最大 amount 枚）
func draw_cards(amount: int) -> void:
	for i in amount:
		var empty_slot := hand.find(null)
		if empty_slot == -1:
			break
		if draw_pile.is_empty():
			_shuffle_discard_to_draw()
		if draw_pile.is_empty():
			break
		hand[empty_slot] = draw_pile.pop_back()


func play_and_discard(hand_index: int) -> void:
	if hand[hand_index] != null:
		discard_pile.append(hand[hand_index])
		hand[hand_index] = null


func turn_end_and_discard() -> void:
	for i in hand.size():
		if hand[i] != null:
			discard_pile.append(hand[i])
	hand = [null, null, null, null]


func _shuffle_discard_to_draw() -> void:
	draw_pile = discard_pile.duplicate()
	draw_pile.shuffle()
	discard_pile.clear()


## 長押し時の説明文
static func card_text(user: Dictionary, action: Dictionary) -> String:
	var lines: Array = []
	var head: String = action.get("name", "")
	match action.get("type", ""):
		"attack": head += "　［攻撃］"
		"skill": head += "　［スキル］"
		"unselectable": head += "　［常時・使用不可］"
	lines.append(head)
	var target_text := ""
	match action.get("target", ""):
		"enemy_all": target_text = "敵全体"
		"front_enemy_single": target_text = "一番近い敵1体"
		"front_enemy_group": target_text = "一番近い敵と同じ側の敵全員"
		"self": target_text = "自分"
		"ally_all": target_text = "味方全体"
	var row := "対象: " + target_text
	if action.has("ap"):
		row += "　消費AP: %d" % action.ap
	lines.append(row)
	if action.has("power"):
		var atk := ActionController.get_atk(user) if not user.is_empty() else 0
		if atk != 0:
			lines.append("威力: %d（%+d）" % [action.power, atk])
		else:
			lines.append("威力: %d" % action.power)
	match action.get("effect", ""):
		"add_shield": lines.append("効果: シールド +%d（次の自分の手番まで）" % action.eff_val)
		"add_ap": lines.append("効果: AP +%d" % action.eff_val)
		"heal": lines.append("効果: HP %d 回復" % action.eff_val)
		"add_status":
			var st: Dictionary = StatusEffectList.DATA[action.status]
			var who := "自分に" if action.get("effect_target") == "self" else ""
			lines.append("効果: %s%s %d（%s）" % [who, st.name, action.eff_val, st.desc])
	if action.get("timing") == "start_turn":
		lines.append("手札にあると、手番の開始時に自動で発動")
	return "\n".join(lines)
