extends Node
class_name DeckController
## 戦闘中の1キャラ分の山札・手札（4枠：0=8上 1=4左 2=2下 3=6右）・捨札・廃棄札・保留枠

const HAND_SIZE := 4  # 手札の枠（テンキー 8・4・2・6）

var draw_pile: Array = []
var hand: Array = [null, null, null, null]
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
	# 先のバッジ：戦闘開始時に優先して最初の手札へ（山札は後ろから引くので末尾へ寄せる）
	var first: Array = draw_pile.filter(func(x): return str(x.get("badge", "")) == "first")
	if not first.is_empty():
		draw_pile = draw_pile.filter(func(x): return str(x.get("badge", "")) != "first") + first


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
	if burns(c, "exhaust"):
		exhaust_pile.append(c)
	else:
		discard_pile.append(c)


## 廃棄（exhaust）・消費（consume）が実際に効くか。残のバッジが付いていれば無効
static func burns(c: Dictionary, kw: String) -> bool:
	return ActionList.has_keyword(c, kw) and str(c.get("badge", "")) != "keep"


## 軽のバッジを反映した消費 AP（0 未満にしない）。APX はそのまま
static func card_ap(c: Dictionary) -> int:
	var ap := int(c.get("ap", 0))
	if str(c.get("badge", "")) == "light" and not c.get("ap_x", false):
		ap = maxi(0, ap - 1)
	return ap


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


# ------------------------------------------------------------
# 戦闘の途中のセーブ（SaveData.save_battle）：山札・手札・捨札・廃棄札・保留を辞書にする／戻す
# ------------------------------------------------------------
## 今の山札などを辞書にする。山札の順（末尾から引く）・手札の枠の位置もそのまま残す
func to_save() -> Dictionary:
	return {
		"draw": draw_pile.map(func(c): return card_to_save(c)),
		"hand": hand.map(func(c): return card_to_save(c)),
		"discard": discard_pile.map(func(c): return card_to_save(c)),
		"exhaust": exhaust_pile.map(func(c): return card_to_save(c)),
		"hold": card_to_save(hold),
	}


## to_save() の辞書から戻す。形がおかしければ何も変えずに false。今は無いカード（削除されたカード）は捨てる
func from_save(d: Dictionary) -> bool:
	if not save_ok(d):
		return false
	var piles := {}
	for k in ["draw", "discard", "exhaust"]:
		var list: Array = []
		for o in d[k]:
			var c = card_from_save(o)
			if c != null:
				list.append(c)
		piles[k] = list
	var h: Array = []
	for o in d.hand:
		h.append(card_from_save(o))
	draw_pile = piles.draw
	discard_pile = piles.discard
	exhaust_pile = piles.exhaust
	hand = h
	hold = card_from_save(d.get("hold"))
	return true


## to_save() の形になっているか（from_save の前に全員分を確かめる用）
static func save_ok(d) -> bool:
	if not d is Dictionary:
		return false
	for k in ["draw", "hand", "discard", "exhaust"]:
		if not (d as Dictionary).get(k) is Array:
			return false
	return (d.hand as Array).size() == HAND_SIZE


## カード 1 枚 → {"id": デッキの ID（"カードID@バッジID"）, "x": 元のカードと違う項目, "del": 消えた項目}。null は null
## 元のカード（ActionList.make_card）との差分だけ残すので、カードの定義が変わっても新しい定義で戻る
static func card_to_save(c) -> Variant:
	if not c is Dictionary:
		return null
	var cd: Dictionary = c
	var deck_id := str(cd.get("deck_id", cd.get("id", "")))
	var base := ActionList.make_card(deck_id)
	var extra := {}
	for k in cd:
		if not base.has(k) or base[k] != cd[k]:
			extra[k] = cd[k]
	var gone: Array = []
	for k in base:
		if not cd.has(k):
			gone.append(k)
	return {"id": deck_id, "x": extra, "del": gone}


## card_to_save() の形 → カード（今は無いカードなら null）
static func card_from_save(o) -> Variant:
	if not o is Dictionary or not o.has("id"):
		return null
	var c := ActionList.make_card(str(o.id))
	if c.is_empty():
		return null
	if o.get("x") is Dictionary:
		c.merge(o.x, true)
	if o.get("del") is Array:
		for k in o.del:
			c.erase(k)
	return c


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
	for k in KW_NAME:
		if kw.has(k):
			head += "　[i:kw_%s]%s" % [k, KW_NAME[k]]
	if action.get("ap_x", false):
		head += "　[i:kw_apx]APX"
	lines.append(head)
	var row := target_text(action.get("target", ""))
	if action.get("ap_x", false):
		row += "　[i:ap]AP X（1以上）"
	elif action.get("free", false):
		row += "　[i:ap]AP 0（このターン）"
	elif action.has("ap"):
		var ap := card_ap(action)
		row += "　[i:ap]AP %d" % ap + ("（軽のバッジで-1）" if ap != int(action.ap) or str(action.get("badge", "")) == "light" else "")
	lines.append(row)
	lines.append(effect_text(user, action))
	var bt := badge_text(action)
	if bt != "":
		lines.append(bt)
	return "\n".join(lines)


## キーワード（即応・最後・陣形・転身）の名前
const KW_NAME := {"sokuou": "即応", "saigo": "最後", "jinkei": "陣形", "tenshin": "転身", "gekiha": "撃破", "hangeki": "反撃", "yoyaku": "予約"}
## キーワードの条件の説明
const KW_COND := {
	"sokuou": "このラウンドに味方の誰かが入替していれば",
	"saigo": "手札にも保留枠にも他のカードが無ければ",
	"tenshin": "戦闘開始時と違う位置にいれば",
	"gekiha": "この攻撃で敵を倒したら",
	"hangeki": "次の自分のターン開始まで、攻撃してきた敵に",
	"yoyaku": "次の自分のターン開始時に",
}


## バッジの説明の行（"[i:b_xxx]○○のバッジ：…"）。バッジが無ければ ""
static func badge_text(c: Dictionary) -> String:
	var b := str(c.get("badge", ""))
	if not BadgeList.DATA.has(b):
		return ""
	var d: Dictionary = BadgeList.DATA[b]
	return "[i:%s]%s：%s" % [d.icon, d.name, d.desc]


## 追加効果（bonus）の文。例「ダメージ+4　自分にブロック+3」
static func bonus_text(user: Dictionary, b: Dictionary) -> String:
	if b.has("text"):
		return str(b.text)  # 説明文を差し替える（星降り）
	var parts: Array = []
	if int(b.get("power", 0)) != 0:
		parts.append("ダメージ%+d" % int(b.power))
	var effs: Array = b.get("effects", [])
	if not effs.is_empty():
		parts.append(effect_text(user, {"effects": effs}))
	return "　".join(parts) if not parts.is_empty() else "—"


## キーワードの説明の行（カードの説明文に入れる）
static func keyword_lines(user: Dictionary, action: Dictionary) -> Array:
	var out: Array = []
	for kw in action.get("keywords", []):
		var k := str(kw)
		if k == "jinkei":
			out.append("[i:kw_jinkei]陣形：左（青）なら %s／右（赤）なら %s" % [
					bonus_text(user, action.get("bonus_left", {})), bonus_text(user, action.get("bonus_right", {}))])
		elif ActionController.KW_TIMED.has(k):
			# 撃破・反撃・予約：追加効果が書いてあるカードだけ説明する（倒したらもう一度・ファイアガード等は本文で説明済み）
			var tb := ActionController.timed_bonus(action, k)
			if not (tb.get("effects", []) as Array).is_empty():
				out.append("[i:kw_%s]%s：%s %s" % [k, KW_NAME[k], KW_COND[k], bonus_text(user, {"effects": tb.effects})])
		elif KW_COND.has(k):
			# 札ごとの追加効果（bonus_sokuou など。無ければ bonus）
			out.append("[i:kw_%s]%s：%s %s" % [k, KW_NAME[k], KW_COND[k], bonus_text(user, action.get("bonus_" + k, action.get("bonus", {})))])
	return out


## "[i:..]" を取り除いた文字だけの説明（ログなど）
static func plain(s: String) -> String:
	var re := RegEx.new()
	re.compile("\\[i:[^\\]]*\\]")
	return re.sub(s, "", true)


## 対象 → 対象のアイコン名
static func target_icon(t: String) -> String:
	match t:
		"enemy_all": return "tgt_enemy_all"
		"front_pair", "front_enemy_single": return "tgt_front_pair"
		"front_enemy_group": return "tgt_enemy_group"
		"front_row": return "tgt_front_row"
		"self": return "tgt_self"
		"ally_all": return "tgt_ally_all"
		"other_ally": return "tgt_ally_other"
		"back_row": return "tgt_back_row"
		"random_enemy": return "tgt_random"
	return ""


static func target_text(t: String) -> String:
	var ic := target_icon(t)
	var s := ""
	match t:
		"enemy_all": s = "敵全体"
		"front_pair", "front_enemy_single": s = "目の前の敵前衛"
		"front_enemy_group": s = "目の前の敵グループ"
		"front_row": s = "前衛全体"
		"back_row": s = "後衛全体"
		"random_enemy": s = "ランダムな敵"
		"self": s = "自分"
		"ally_all": s = "味方全体"
		"other_ally": s = "もう1人の味方"
	return "" if s == "" else "[i:%s]%s" % [ic, s]


static func effect_text(user: Dictionary, action: Dictionary) -> String:
	var parts: Array = []
	var is_power := ActionList.has_keyword(action, "power")
	if is_power:
		parts.append(power_text(user, action))
	if burns(action, "consume") and not is_power:
		parts.append("[i:kw_consume]消費：他の手札1枚をランダムに捨てる　無いと使えない")
	if action.get("ap_x", false):
		parts.append("[i:kw_apx]APを全部使い、その量をXとする")
	if action.has("power"):
		var atk := ActionController.get_atk(user) + ActionController.relic_atk(user) if not user.is_empty() else 0
		var times := ""  # 多段攻撃の回数
		if action.get("hits_x", false):
			times = "×X回"
		elif action.get("hits_used", false):
			times = "×X回"  # 怒涛の締め（X＝このターンに使ったカードの枚数）
		elif int(action.get("hits", 1)) > 1:
			times = "×%d回" % int(action.hits)
		if action.get("reroll", false):
			times += "（1回ごとに敵を選び直す）"
		if action.has("pre_rank"):
			parts.append("[i:formation]自分が%sに移動してから" % ("前衛" if int(action.pre_rank) == 0 else "後衛"))  # 魔弾
		if str(action.get("power_from", "")) == "poison":
			parts.append("[i:st_poison]それぞれの毒の残り分の固定ダメージ（毒は減らない）")
		elif action.get("hits_used", false):
			parts.append("[i:stat_atk]%dダメージ×X回（X＝このターンにこのキャラが使ったカードの枚数%s）" % [action.power, ("。攻撃力%+d" % atk) if atk != 0 else ""])
		elif action.get("power_used", false):
			parts.append("[i:stat_atk]Xダメージ%s（X＝このターンにこのキャラが使ったカードの枚数%s）" % [times, ("。攻撃力%+d" % atk) if atk != 0 else ""])
		elif atk != 0 and not action.get("fixed", false):
			parts.append("[i:stat_atk]%dダメージ%s（攻撃力%+d）" % [action.power, times, atk])
		else:
			parts.append("[i:stat_atk]%dダメージ%s" % [action.power, times])
	var aph = action.get("ap_hits")
	if aph is Dictionary:
		parts.append("[i:ap]使う前のAPが%d以上なら、さらに%d回" % [int(aph.get("min", 0)), int(aph.get("hits", 1)) - maxi(1, int(action.get("hits", 1)))])
	# 1 ヒットごとの効果（毒の雨・毒針の嵐・星の審判）
	var he_txt: Array = []
	for he in action.get("hit_effects", []):
		var hs := effect_text(user, {"effects": [(he as Dictionary).duplicate()]})
		if (he as Dictionary).get("if_damaged", false):
			hs = "ダメージを受けた敵に" + hs
		he_txt.append(hs)
	if not he_txt.is_empty():
		var n_txt := "X" if action.get("hits_x", false) else str(maxi(1, int(action.get("hits", 1))))
		if action.has("power"):
			parts.append("1回ごとに " + "　".join(he_txt))
		else:
			parts.append("%s を%s回%s" % ["　".join(he_txt), n_txt, "（1回ごとに敵を選び直す）" if action.get("reroll", false) else ""])
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
			"other_ally": who = "もう1人の味方に"
		var turns := int(e.get("turns", -1))
		var dur := ("%dターン " % turns) if turns > 0 else ""
		match e.get("effect", ""):
			"add_shield": parts.append("[i:shield]%sブロック+%d%s" % [who, e.eff_val, "×X" if e.get("x", false) else ""])
			"absorb_block": parts.append("[i:shield]対象の敵のブロックの合計を、自分のブロックに足す")
			"add_ap": parts.append("[i:ap]AP+%d" % e.eff_val)
			"heal": parts.append("[i:heart]HP%d回復" % e.eff_val)
			"heal_pct": parts.append("[i:heart]HPを最大HPの%d%%回復" % int(e.eff_val))
			"draw": parts.append("[i:cards]カードを%d枚引く" % e.eff_val)
			"swap": parts.append("[i:swap]味方の位置を入れ替える")
			"double": parts.append("[i:st_double]次に使うカード・保留カードが2回発動")
			"turnabout": parts.append("[i:cards]空いている手札の枠を補充する　[i:atk_buff]攻撃力+1")
			"extra_turn": parts.append("[i:hourglass]ターン終了時、もう一度ターンを得る")
			"set_next_action": parts.append("[i:hourglass]次に強攻撃")
			"rank_swap": parts.append("[i:formation]自分の前衛・後衛を入れ替える")
			"rank_to": parts.append("[i:formation]自分を%sに移動" % ("前衛" if int(e.get("eff_val", 1)) == 0 else "後衛"))
			"cleanse": parts.append("[i:heart]%sデバフ（火傷・毒・攻撃力低下・防御力低下・回復不可・スタン）を解除" % who)
			"repeat": parts.append("[i:skull]もう一度この攻撃が発動")
			"add_status":
				var st: Dictionary = StatusEffectList.DATA.get(e.status, {})
				var ic := "[i:%s]" % str(st.get("icon", "star"))
				match e.status:
					"taunt": parts.append("%s%s挑発（単体攻撃をこちらへ向けさせる）" % [ic, dur])
					"poison": parts.append("%s毒%dターン" % [ic, int(e.eff_val)])
					"fire": parts.append("%s%s火傷%d" % [ic, who, int(e.eff_val)])
					"stun": parts.append("%sスタン（次のターンを休む）" % ic)
					"no_heal": parts.append("%s%s回復不可" % [ic, dur])
					"atk_down": parts.append("%s%s攻撃力-%d%s" % [ic, dur, int(e.eff_val), "（戦闘中）" if turns < 0 else ""])
					"def_down": parts.append("%s%s防御力-%d%s" % [ic, dur, int(e.eff_val), "（戦闘中）" if turns < 0 else ""])
					"ap_plus": parts.append("%s%sAPプラス（ターン開始時AP+%d）" % [ic, dur, int(e.eff_val)])
					"ap_next": parts.append("%s次の自分のターンAP+%d" % [ic, int(e.eff_val)])
					"fire_guard": parts.append("%s%s攻撃してきた相手に火傷%d" % [ic, dur, int(e.eff_val)])
					"barricade": parts.append("%s戦闘中ずっと、ターン開始時にブロックが消えない" % ic)
					"focus": parts.append("%s次の自分のターン、必殺技のAP-%d" % [ic, int(e.eff_val)])
					"declare": parts.append("%s宣言：次の自分のターン開始時までにHPが減らなければ、%dターン APプラス（ターン開始時AP+1）" % [ic, int(e.eff_val)])
					"reblock": parts.append("%s次の自分のターン開始時にブロック+%d" % [ic, int(e.eff_val)])
					_: parts.append("%s%s%s+%d" % [ic, who, str(st.get("name", "")).replace("アップ", ""), int(e.eff_val)])
	if burns(action, "exhaust") and not is_power:
		parts.append("[i:kw_exhaust]使うと廃棄")
	if str(action.get("badge", "")) == "keep" and (ActionList.has_keyword(action, "exhaust") or ActionList.has_keyword(action, "consume")):
		parts.append("[i:b_keep]廃棄・消費しない")
	var kl := keyword_lines(user, action)
	if action.get("saigo_only", false):
		# 「最後」の効果しか無いカード：条件を満たした時だけ使える
		kl = kl.filter(func(s): return not str(s).begins_with("[i:kw_saigo]"))
		kl.append("[i:kw_saigo]最後：手札にも保留枠にも他のカードが無い時だけ使える")
	if is_power:
		kl = kl.filter(func(s): return not str(s).begins_with("[i:kw_jinkei]") and not str(s).begins_with("[i:kw_sokuou]"))  # power_text で説明済み
	parts.append_array(kl)
	return "　".join(parts)


## パワーカードの説明（power_effect の形は ActionList の説明を参照）
static func power_text(user: Dictionary, action: Dictionary) -> String:
	var pe: Dictionary = action.get("power_effect", {})
	var head := "[i:kw_power]使えない。手札にある間、次の自分のターンまで"
	if pe.has("left") or pe.has("right"):
		return "%s [i:kw_jinkei]陣形：左（青）なら %s／右（赤）なら %s（手札に入った時の位置）" % [
				head, _power_body(user, pe.get("left", {})), _power_body(user, pe.get("right", {}))]
	var kind := str(pe.get("kind", ""))
	if kind in ["end_herb", "end_convert"]:
		return "[i:kw_power]使えない。" + _power_body(user, pe)
	if pe.get("exhaust_now", false):
		return "[i:kw_power]使えない。手札に入った時に %s（その後すぐ廃棄）" % _power_body(user, pe)
	return "%s %s（保留枠に入ると捨札へ）" % [head, _power_body(user, pe)]


static func _power_body(user: Dictionary, pe: Dictionary) -> String:
	var parts: Array = []
	if pe.has("status"):
		var st: Dictionary = StatusEffectList.DATA.get(pe.get("status", ""), {})
		parts.append(("味方全体の" if pe.get("all", false) else "") + "[i:%s]%s+%d" % [st.get("icon", "star"), str(st.get("name", "")).replace("アップ", ""), int(pe.get("eff_val", 0))])
	if pe.has("once"):
		var t := effect_text(user, {"effects": pe.once})
		parts.append(t if pe.get("exhaust_now", false) else "手札に入った時 " + t)
	if int(pe.get("aid_atk", 0)) > 0:
		parts.append("[i:atk_buff]もう1人の味方の攻撃力+%d" % int(pe.aid_atk))
	match str(pe.get("kind", "")):
		"burn_atk": parts.append("[i:flame]自分の火傷の残りターン分、攻撃力+")
		"last_stand": parts.append("[i:stat_atk]HPの残りX%で 攻撃力+Y・素早さ+Y（Y＝(100−X)÷10 切り捨て）")
		"on_plain_card": parts.append("[i:tgt_enemy_all]札の無いカードが発動するたび、敵全体に%dダメージ　[i:kw_sokuou]即応：さらに+%d" % [int(pe.get("dmg", 0)), int(pe.get("sokuou_add", 0))])
		"on_burn": parts.append("[i:tgt_enemy_all]消費・廃棄が発動するたび、敵全体に%dダメージ" % int(pe.get("dmg", 0)))
		"on_attack_poison": parts.append("[i:st_poison]アタックカードを使うたび、当たった敵に毒%d" % int(pe.get("eff_val", 1)))
		"on_debuff_card": parts.append("[i:shield]状態異常を付けるカードを使うたび、自分にブロック+%d" % int(pe.get("shield", 1)))
		"on_own_card": parts.append("[i:flame]このキャラがカードを使うたび、もう1人の味方に火傷%d・ブロック+%d" % [int(pe.get("fire", 1)), int(pe.get("shield", 0))])
		"on_gekiha_card": parts.append("[i:atk_buff]%sのカードを使うたび、自分の攻撃力+%d（戦闘中）" % [_kws_text(pe.get("kws", ["gekiha"])), int(pe.get("atk", 1))])
		"on_kw_card": parts.append("[i:tgt_enemy_all]%sのカードが発動するたび、敵全体に%dダメージ　[i:kw_sokuou]即応：さらに+%d" % [_kws_text(pe.get("kws", [])), int(pe.get("dmg", 0)), int(pe.get("sokuou_add", 0))])
		"on_gekiha_hangeki": parts.append("[i:tgt_random]撃破・反撃が発動するたび、ランダムな敵に%d×%d（固定）" % [int(pe.get("power", 2)), int(pe.get("hits", 5))])
		"end_herb": parts.append("[i:item_herb]自分のターン終了時に手札にあれば、薬草を得る（アイテムがいっぱいなら得られない）。その後廃棄")
		"end_convert": parts.append("[i:kw_consume]自分のターン終了時に手札にあれば、他の手札1枚をランダムに捨て（消費）、そのカードのAP分 AP+")
	return "　".join(parts) if not parts.is_empty() else "—"


## 札の名前を「・」でつなぐ（例：即応・転身）
static func _kws_text(kws: Array) -> String:
	var names: Array = []
	for k in kws:
		names.append(str(KW_NAME.get(str(k), str(k))))
	return "・".join(names)
