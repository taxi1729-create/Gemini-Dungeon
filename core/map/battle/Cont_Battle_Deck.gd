extends Node
class_name DeckController
## 戦闘中の1キャラ分の山札・手札（5枠：0=8上 1=4左 2=2下 3=6右 4=1左下）・捨札・廃棄札・保留枠

const HAND_SIZE := 5

var draw_pile: Array = []
var hand: Array = [null, null, null, null, null]
var discard_pile: Array = []
var exhaust_pile: Array = []  # 廃棄札（廃棄カードを使うとここへ。戦闘中は戻らない）
var hold = null  # 保留カード（ターンをまたいで残る）


func setup_battle_deck(master_deck_ids: Array) -> void:
	draw_pile.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	hand = []
	hand.resize(HAND_SIZE)
	hold = null
	for card_id in master_deck_ids:
		var c := ActionList.make_card(card_id)
		if not c.is_empty():
			draw_pile.append(c)
	draw_pile.shuffle()


## 空いている枠をカードで埋める（最大 amount 枚）。引いた枠の番号を返す。only_slots を渡すとその枠だけ埋める
func draw_cards(amount: int, only_slots: Array = []) -> Array:
	var filled: Array = []
	for i in amount:
		var empty_slot := -1
		for s in hand.size():
			if hand[s] == null and (only_slots.is_empty() or only_slots.has(s)):
				empty_slot = s
				break
		if empty_slot == -1:
			break
		if draw_pile.is_empty():
			_shuffle_discard_to_draw()
		if draw_pile.is_empty():
			break
		hand[empty_slot] = draw_pile.pop_back()
		filled.append(empty_slot)
	return filled


## 使ったカードを捨札（廃棄なら廃棄札）へ
func _to_used(c: Dictionary) -> void:
	c.erase("free")
	if ActionList.has_keyword(c, "exhaust"):
		exhaust_pile.append(c)
	else:
		discard_pile.append(c)


func play_and_discard(hand_index: int) -> void:
	if hand[hand_index] != null:
		_to_used(hand[hand_index])
		hand[hand_index] = null


func play_hold() -> void:
	if hold != null:
		_to_used(hold)
		hold = null


## 手札の slot を保留枠へ。保留中のカードがあれば、そのカードは空いた slot へ戻る。
## パワーカードは保留枠に入るとすぐ捨札へ行く（戻り値 true）
func put_on_hold(slot: int) -> bool:
	var c = hand[slot]
	if c == null:
		return false
	hand[slot] = hold
	hold = c
	if ActionList.has_keyword(c, "power"):
		discard_pile.append(c)
		hold = null
		return true
	return false


## ターン終了時：保留枠が空で手札が残っていれば、ランダムに 1 枚を保留枠へ（パワーカードは除く）。保留したカードを返す
func auto_hold():
	if hold != null:
		return null
	var cand: Array = []
	for i in hand.size():
		if hand[i] != null and not ActionList.has_keyword(hand[i], "power"):
			cand.append(i)
	if cand.is_empty():
		return null
	var slot: int = cand.pick_random()
	hold = hand[slot]
	hand[slot] = null
	hold.erase("free")
	return hold


## 消費：except_slot 以外の手札（5 枠。保留枠は含まない）から捨てられるカードがあるか。except_slot = -1 なら手札全部が候補
func has_consume_target(except_slot: int) -> bool:
	for i in hand.size():
		if i != except_slot and hand[i] != null:
			return true
	return false


## 消費：except_slot 以外の手札からランダムに 1 枚を捨札へ。捨てた枠の番号を返す（無ければ -1）
func consume_random(except_slot: int) -> int:
	var cand: Array = []
	for i in hand.size():
		if i != except_slot and hand[i] != null:
			cand.append(i)
	if cand.is_empty():
		return -1
	var slot: int = cand.pick_random()
	var c: Dictionary = hand[slot]
	c.erase("free")
	discard_pile.append(c)
	hand[slot] = null
	return slot


## 倒したらもう一度使える：使ったカードを捨札（廃棄札）から元の枠へ戻す。slot = -1 は保留枠。戻した枠（保留枠は -1）を返す。戻せなければ -2
func return_card(c: Dictionary, slot: int) -> int:
	var removed := false
	for pile in [discard_pile, exhaust_pile]:
		for i in range(pile.size() - 1, -1, -1):
			if is_same(pile[i], c):
				pile.remove_at(i)
				removed = true
				break
		if removed:
			break
	if not removed:
		return -2
	if slot == -1 and hold == null:
		hold = c
		return -1
	if slot >= 0 and hand[slot] == null:
		hand[slot] = c
		return slot
	for i in hand.size():
		if hand[i] == null:
			hand[i] = c
			return i
	_to_used(c)  # 空きが無ければ捨札のまま
	return -2


## ターン終了：「このターンの間 AP 0」を外す
func clear_free() -> void:
	for c in hand + [hold] + draw_pile + discard_pile + exhaust_pile:
		if c is Dictionary:
			c.erase("free")


func discard_hand(slots: Array = []) -> void:
	for i in hand.size():
		if hand[i] != null and (slots.is_empty() or slots.has(i)):
			discard_pile.append(hand[i])
			hand[i] = null


func turn_end_and_discard() -> void:
	clear_free()
	discard_hand()


## 手札にあるパワーカードの効果の合計 {"atk": n, "def": n}
func power_mods() -> Dictionary:
	var m := {"atk": 0, "def": 0}
	for c in hand:
		if c != null and ActionList.has_keyword(c, "power"):
			var pe: Dictionary = c.get("power_effect", {})
			match pe.get("status", ""):
				"atk_buff": m.atk += int(pe.eff_val)
				"def_buff": m.def += int(pe.eff_val)
	return m


func _shuffle_discard_to_draw() -> void:
	draw_pile = discard_pile.duplicate()
	draw_pile.shuffle()
	discard_pile.clear()


## 説明文（アイコン入り。"[i:アイコン名]" は ImageController.rich_text で描く。文字だけの場所は plain() を通す）
static func card_text(user: Dictionary, action: Dictionary) -> String:
	var lines: Array = []
	var head: String = action.get("name", "")
	match action.get("rarity", ""):
		"rare": head += "　★レア"
		"super_rare": head += "　★★超レア"
	var kw: Array = action.get("keywords", [])
	if kw.has("power"):
		head += "　[i:kw_power]パワー"
	if kw.has("exhaust"):
		head += "　[i:kw_exhaust]廃棄"
	if kw.has("consume"):
		head += "　[i:kw_consume]消費"
	if action.get("ap_x", false):
		head += "　[i:kw_apx]APX"
	lines.append(head)
	var row := target_text(action.get("target", ""))
	if action.get("ap_x", false):
		row += "　[i:ap]AP X（1以上）"
	elif action.get("free", false):
		row += "　[i:ap]AP 0（このターン）"
	elif action.has("ap"):
		row += "　[i:ap]AP %d" % action.ap
	lines.append(row)
	lines.append(effect_text(user, action))
	return "\n".join(lines)


## "[i:..]" を取り除いた文字だけの説明（ログなど）
static func plain(s: String) -> String:
	var re := RegEx.new()
	re.compile("\\[i:[^\\]]*\\]")
	return re.sub(s, "", true)


## 対象 → 対象のアイコン名
static func target_icon(t: String) -> String:
	match t:
		"enemy_all": return "tgt_enemy_all"
		"front_enemy_single": return "tgt_enemy_one"
		"front_enemy_group": return "tgt_enemy_group"
		"front_row": return "tgt_front_row"
		"self": return "tgt_self"
		"ally_all": return "tgt_ally_all"
		"other_ally": return "tgt_ally_other"
	return ""


static func target_text(t: String) -> String:
	var ic := target_icon(t)
	var s := ""
	match t:
		"enemy_all": s = "敵全体"
		"front_enemy_single": s = "目の前の敵（HP最低）"
		"front_enemy_group": s = "目の前の敵グループ"
		"front_row": s = "前衛の敵全体"
		"self": s = "自分"
		"ally_all": s = "味方全体"
		"other_ally": s = "ナイト（もう一人の味方）"  # 今は APパサー（ウィッチのカード）だけが使う
	return "" if s == "" else "[i:%s]%s" % [ic, s]


static func effect_text(user: Dictionary, action: Dictionary) -> String:
	var parts: Array = []
	if ActionList.has_keyword(action, "power"):
		var pe: Dictionary = action.get("power_effect", {})
		var st: Dictionary = StatusEffectList.DATA.get(pe.get("status", ""), {})
		parts.append("[i:kw_power]使えない。手札にある間、次の自分のターンまで [i:%s]%s+%d（保留枠に入ると捨札へ）" % [
				st.get("icon", "star"), str(st.get("name", "")).replace("アップ", ""), int(pe.get("eff_val", 0))])
	if ActionList.has_keyword(action, "consume"):
		parts.append("[i:kw_consume]消費：他の手札1枚をランダムに捨てる　無いと使えない")
	if action.get("ap_x", false):
		parts.append("[i:kw_apx]APを全部使い、その量をXとする")
	if action.has("power"):
		var atk := ActionController.get_atk(user) if not user.is_empty() else 0
		var times := ""  # 多段攻撃の回数
		if action.get("hits_x", false):
			times = "×X回"
		elif int(action.get("hits", 1)) > 1:
			times = "×%d回" % int(action.hits)
		if atk != 0 and not action.get("fixed", false):
			parts.append("[i:stat_atk]%dダメージ%s（攻撃力%+d）" % [action.power, times, atk])
		else:
			parts.append("[i:stat_atk]%dダメージ%s" % [action.power, times])
	match String(action.get("on_kill", "")):
		"reuse": parts.append("[i:skull]倒したら、もう一度使える")
		"reuse_free": parts.append("[i:skull]倒したら、このターンはAP0でもう一度使える")
	if int(action.get("kill_ap", 0)) > 0:
		parts.append("[i:ap]倒すたびAP+%d" % int(action.kill_ap))
	for e in ActionList.effects_of(action):
		var who := ""
		match e.get("to", "target"):
			"self": who = "自分に"
			"ally_all": who = "味方全体に"
		var turns := int(e.get("turns", -1))
		var dur := ("%dターン " % turns) if turns > 0 else ""
		match e.get("effect", ""):
			"add_shield": parts.append("[i:shield]%sブロック+%d%s" % [who, e.eff_val, "×X" if e.get("x", false) else ""])
			"absorb_block": parts.append("[i:shield]対象の敵のブロックの合計を、自分のブロックに足す")
			"add_ap": parts.append("[i:ap]AP+%d" % e.eff_val)
			"heal": parts.append("[i:heart]HP%d回復" % e.eff_val)
			"draw": parts.append("[i:cards]カードを%d枚引く" % e.eff_val)
			"swap": parts.append("[i:swap]味方の位置を入れ替える")
			"double": parts.append("[i:st_double]次に使うカード・保留カードが2回発動")
			"turnabout": parts.append("[i:cards]空いている手札の枠を補充する　[i:atk_buff]攻撃力+1")
			"extra_turn": parts.append("[i:hourglass]ターン終了時、もう一度ターンを得る")
			"set_next_action": parts.append("[i:hourglass]次に強攻撃")
			"add_status":
				var st: Dictionary = StatusEffectList.DATA.get(e.status, {})
				var ic := "[i:%s]" % str(st.get("icon", "star"))
				match e.status:
					"taunt": parts.append("%s%s挑発（単体攻撃をこちらへ向けさせる）" % [ic, dur])
					"poison": parts.append("%s毒%dターン" % [ic, int(e.eff_val)])
					"fire": parts.append("%s火傷%d" % [ic, int(e.eff_val)])
					"atk_down": parts.append("%s%s攻撃力-%d" % [ic, dur, int(e.eff_val)])
					"def_down": parts.append("%s%s防御力-%d" % [ic, dur, int(e.eff_val)])
					"ap_plus": parts.append("%s%sAPプラス（ターン開始時AP+%d）" % [ic, dur, int(e.eff_val)])
					"ap_next": parts.append("%s次の自分のターンAP+%d" % [ic, int(e.eff_val)])
					"fire_guard": parts.append("%s%s攻撃してきた相手に火傷%d" % [ic, dur, int(e.eff_val)])
					"barricade": parts.append("%s戦闘中ずっと、ターン開始時にブロックが消えない" % ic)
					"focus": parts.append("%s次の自分のターン、必殺技のAP-%d" % [ic, int(e.eff_val)])
					"declare": parts.append("%s宣言：次の自分のターン開始時までにHPが減らなければ、%dターン APプラス（ターン開始時AP+1）" % [ic, int(e.eff_val)])
					"reblock": parts.append("%s次の自分のターン開始時にブロック+%d" % [ic, int(e.eff_val)])
					_: parts.append("%s%s%s+%d" % [ic, who, str(st.get("name", "")).replace("アップ", ""), int(e.eff_val)])
	if ActionList.has_keyword(action, "exhaust"):
		parts.append("[i:kw_exhaust]使うと廃棄")
	return "　".join(parts)
