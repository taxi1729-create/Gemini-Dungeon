extends Node
class_name DeckController
## 戦闘中の1キャラ分の山札・手札（6 欄：0=8上 1=4左 2=2下 3=6右、空き欄 4=9 5=3）・捨札・廃棄札
## 10 回目：保留枠を撤去。9・3 は「空き欄」＝「カードを引く」効果で 4 枠が埋まっている時に 9→3 の順で入る手札の欄

const HAND_SIZE := 4  # ターン開始時に補充する手札の枠（テンキー 8・4・2・6 ＝ hand の 0〜3）
const HAND_SLOTS := 6  # 手札の欄の数（4 枠＋空き欄 2。手札は最大 6 枚）
const BASE_SLOTS := [0, 1, 2, 3]  # ターン開始の補充で埋める欄
const FREE_SLOTS := [4, 5]  # 空き欄（9・3）

var draw_pile: Array = []
var hand: Array = [null, null, null, null, null, null]
var discard_pile: Array = []
var exhaust_pile: Array = []  # 廃棄札（廃棄カードを使うとここへ。戦闘中は戻らない）
var last_consumed: Dictionary = {}  # 消費で最後に手札から捨てたカード（揮発なら廃棄札にある）


func setup_battle_deck(master_deck_ids: Array) -> void:
	draw_pile.clear()
	discard_pile.clear()
	exhaust_pile.clear()
	hand = []
	hand.resize(HAND_SLOTS)
	for card_id in master_deck_ids:
		var c := ActionList.make_card(card_id)
		if not c.is_empty():
			draw_pile.append(c)
	draw_pile.shuffle()
	# 先のバッジ：戦闘開始時に優先して最初の手札へ（山札は後ろから引くので末尾へ寄せる）
	var first: Array = draw_pile.filter(func(x): return str(x.get("badge", "")) == "first")
	if not first.is_empty():
		draw_pile = draw_pile.filter(func(x): return str(x.get("badge", "")) != "first") + first


## 空いている欄をカードで埋める（最大 amount 枚。4 枠 → 空き欄 9 → 3 の順）。引いた欄の番号を返す。only_slots を渡すとその欄だけ埋める
## ターン開始の補充は only_slots = BASE_SLOTS（空き欄は埋めない）
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


## 使ったカードを捨札（廃棄・揮発なら廃棄札）へ
func _to_used(c: Dictionary) -> void:
	c.erase("free")
	if burns(c, "exhaust") or burns(c, "kihatsu"):
		exhaust_pile.append(c)
	else:
		discard_pile.append(c)


## 廃棄（exhaust）・消費（consume）が実際に効くか。残のバッジが付いていれば無効
static func burns(c: Dictionary, kw: String) -> bool:
	return ActionList.has_keyword(c, kw) and str(c.get("badge", "")) != "keep"


## 軽のバッジ・ハイコストを反映した消費 AP（0 未満にしない）。APX はそのまま
## ハイコスト（11 回目）：使うたびにカードの辞書の ap_up が +1（戦闘中の山札のカードだけ。戦闘中セーブにも差分で残る）
static func card_ap(c: Dictionary) -> int:
	var ap := int(c.get("ap", 0))
	if c.get("ap_x", false):
		return ap
	if str(c.get("badge", "")) == "light":
		ap = maxi(0, ap - 1)
	return maxi(0, ap + int(c.get("ap_up", 0)) - int(c.get("ap_down", 0)))


## D（12 回目・流星の煌めき）：カードの AP を n 下げる（その戦闘中。カードの辞書の ap_down。実際の AP が 0 より下がる分は足さない）
static func lower_ap(c: Dictionary, n: int) -> void:
	if c.get("ap_x", false) or n <= 0:
		return
	var room := card_ap(c)  # 今の AP（0 まで下げられる）
	if room > 0:
		c["ap_down"] = int(c.get("ap_down", 0)) + mini(n, room)


## ハイコスト：使ったカードの AP を 1 上げる（その戦闘中。カードごと）
static func raise_highcost(c: Dictionary) -> void:
	if ActionList.has_keyword(c, "highcost") and not c.get("ap_x", false):
		c["ap_up"] = int(c.get("ap_up", 0)) + 1


## カードを使った：ハイコストなら AP+1 して、捨札（廃棄・揮発なら廃棄札）へ
func play_and_discard(hand_index: int) -> void:
	if hand[hand_index] != null:
		raise_highcost(hand[hand_index])
		_to_used(hand[hand_index])
		hand[hand_index] = null


## 消費：except_slot 以外の手札（空き欄を含む 6 欄）から捨てられるカードがあるか。except_slot = -1 なら手札全部が候補
func has_consume_target(except_slot: int) -> bool:
	for i in hand.size():
		if i != except_slot and hand[i] != null:
			return true
	return false


## 消費：except_slot 以外の手札からランダムに 1 枚を捨札（揮発なら廃棄札）へ。捨てた枠の番号を返す（無ければ -1）
## 捨てたカードは last_consumed に入る
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
	_to_unused(c)
	last_consumed = c
	hand[slot] = null
	return slot


## 使わずに手札から捨てる（ターン終了・消費）：捨札へ。揮発は廃棄札へ
func _to_unused(c: Dictionary) -> void:
	if burns(c, "kihatsu"):
		exhaust_pile.append(c)
	else:
		discard_pile.append(c)


## 倒したらもう一度使える：使ったカードを捨札（廃棄札）から元の欄へ戻す。戻した欄を返す。戻せなければ -2
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
	for c in hand + draw_pile + discard_pile + exhaust_pile:
		if c is Dictionary:
			c.erase("free")


func discard_hand(slots: Array = []) -> void:
	for i in hand.size():
		if hand[i] != null and (slots.is_empty() or slots.has(i)):
			_to_unused(hand[i])
			hand[i] = null


## ターン終了：保留のカードは空き欄（9→3）へ移して手札に残し、残りは捨札（揮発は廃棄札）へ
func turn_end_and_discard() -> void:
	clear_free()
	keep_horyu()  # 保留以外を捨て、保留を空き欄へ（入らない保留も捨てる）


## 保留（11 回目）：ターン終了時、保留でない手札を先に捨て（揮発は廃棄札）、保留のカードを空き欄へ移して残す。
## もう空き欄にある保留のカードはそのまま。4 枠の保留のカードは空いている空き欄へ 9→3 の順（4 枠の 8・4・2・6 の順）に移し、
## 空き欄が保留のカードで埋まっていれば捨札へ。空き欄に残したカードの欄の番号を返す
func keep_horyu() -> Array:
	var others: Array = []
	for i in hand.size():
		if hand[i] != null and not ActionList.has_keyword(hand[i], "horyu"):
			others.append(i)
	if not others.is_empty():
		discard_hand(others)  # 空の配列だと手札全部を捨てるので
	var kept: Array = []
	for f in FREE_SLOTS:
		if hand[f] != null:
			kept.append(f)
	for i in BASE_SLOTS:
		if hand[i] == null:
			continue
		for f in FREE_SLOTS:
			if hand[f] == null:
				hand[f] = hand[i]
				hand[i] = null
				kept.append(f)
				break
	discard_hand(BASE_SLOTS)  # 空き欄に入らなかった保留のカード
	return kept


func _shuffle_discard_to_draw() -> void:
	draw_pile = discard_pile.duplicate()
	draw_pile.shuffle()
	discard_pile.clear()


# ------------------------------------------------------------
# 戦闘の途中のセーブ（SaveData.save_battle）：山札・手札・捨札・廃棄札を辞書にする／戻す
# ------------------------------------------------------------
## 今の山札などを辞書にする。山札の順（末尾から引く）・手札の枠の位置もそのまま残す
func to_save() -> Dictionary:
	return {
		"draw": draw_pile.map(func(c): return card_to_save(c)),
		"hand": hand.map(func(c): return card_to_save(c)),
		"discard": discard_pile.map(func(c): return card_to_save(c)),
		"exhaust": exhaust_pile.map(func(c): return card_to_save(c)),
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
	h.resize(HAND_SLOTS)  # 古いセーブ（4 枠）は空き欄を足す
	# 古いセーブの保留カード：手札の空き欄（9→3）へ。入らなければ捨札へ
	var old_hold = card_from_save(d.get("hold"))
	if old_hold != null:
		var put := false
		for i in FREE_SLOTS:
			if h[i] == null:
				h[i] = old_hold
				put = true
				break
		if not put:
			piles.discard.append(old_hold)
	draw_pile = piles.draw
	discard_pile = piles.discard
	exhaust_pile = piles.exhaust
	hand = h
	return true


## to_save() の形になっているか（from_save の前に全員分を確かめる用）
static func save_ok(d) -> bool:
	if not d is Dictionary:
		return false
	for k in ["draw", "hand", "discard", "exhaust"]:
		if not (d as Dictionary).get(k) is Array:
			return false
	return (d.hand as Array).size() in [HAND_SIZE, HAND_SLOTS]  # 4 は古いセーブ（保留枠があった頃）


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
	if SaveData.REMOVED_CARDS.has(ActionList.base_id(str(o.id))):
		return null  # 削除したカード（雷撃など）は戻さない
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
	if user.is_empty():
		user = ActionController.owner_unit(action)  # 11 回目：POW%・SLD% の（）の値は持ち主のステータスで
	var lines: Array = []
	var head: String = action.get("name", "")
	if str(action.get("no", "")) != "":
		head = "No.%s　%s" % [str(action.no), head]  # カードの No. を見出しの頭に
	if str(action.get("rarity", "")) != "":
		# 12 回目（C）：レア度 4 段階（コモンは出さない。古い値も読み替える）
		match ActionList.norm_rarity(action.get("rarity")):
			"rare": head += "　★レア"
			"epic": head += "　★★エピック"
			"legend": head += "　★★★レジェンド"
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
		var why: Array = []  # AP が元と違う理由（軽のバッジ -1・ハイコスト +N）
		if str(action.get("badge", "")) == "light":
			why.append("軽のバッジで-1")
		if int(action.get("ap_up", 0)) > 0:
			why.append("ハイコストで+%d" % int(action.ap_up))
		if int(action.get("ap_down", 0)) > 0:
			why.append("手札に残って-%d" % int(action.ap_down))
		row += "　[i:ap]AP %d" % ap + ("（%s）" % "・".join(why) if not why.is_empty() else "")
	lines.append(row)
	lines.append(effect_text(user, action))
	var bt := badge_text(action)
	if bt != "":
		lines.append(bt)
	return "\n".join(lines)


## キーワード（即応・最後・陣形・転身）の名前
const KW_NAME := {"sokuou": "即応", "saigo": "最後", "jinkei": "陣形", "tenshin": "転身", "gekiha": "撃破", "hangeki": "反撃", "yoyaku": "予約",
		"horyu": "保留", "kihatsu": "揮発", "highcost": "ハイコスト"}
## 11 回目（C）：条件の無い札（保留・揮発・ハイコスト）の説明
const KW_RULE := {
	"horyu": "ターン終了時に手札に残っていれば、空き欄（9→3）へ移って次のターンも手札に残る（空き欄が埋まっていれば捨札へ）",
	"kihatsu": "捨札に行かず廃棄札へ（使っても、使わずにターン終了しても）",
	"highcost": "使うたびに、このカードのAPが1上がる（この戦闘中）",
}
## キーワードの条件の説明
const KW_COND := {
	"sokuou": "このラウンドに味方の誰かが入替していれば",
	"saigo": "手札（空き欄を含む）に他のカードが無ければ",
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


## 11 回目：「POW40%（8）」の形（% と、使う人の POW で計算した値）。user が空なら % だけ
static func pow_txt(user: Dictionary, pct: int) -> String:
	if user.is_empty():
		return "POW%d%%" % pct
	return "POW%d%%（%d）" % [pct, maxi(1, ActionController.get_pow(user) * pct / 100) if pct > 0 else 0]


## 11 回目：「SLD140%（11）」の形（使う人の SLD で計算した値）。user が空なら % だけ
static func sld_txt(user: Dictionary, pct: int) -> String:
	if user.is_empty():
		return "SLD%d%%" % pct
	return "SLD%d%%（%d）" % [pct, ActionController.get_sld(user) * pct / 100]


## ダメージの数の文：pow_pct があれば「POW40%（8）」（固定の上乗せ power があれば「+n」も）、無ければ power の数（敵の行動・アイテムなど）
static func _dmg_txt(user: Dictionary, d: Dictionary) -> String:
	var pct := int(d.get("pow_pct", 0))
	var flat := int(d.get("power", 0))
	if pct <= 0:
		return str(flat)
	return pow_txt(user, pct) + ("%+d" % flat if flat != 0 else "")


## ブロックの数の文：sld_pct があれば「SLD140%（11）」（固定の eff_val があれば「+n」も）、無ければ eff_val の数
static func _shield_txt(user: Dictionary, e: Dictionary) -> String:
	var pct := int(e.get("sld_pct", 0))
	var flat := int(e.get("eff_val", 0))
	if pct <= 0:
		return str(flat)
	return sld_txt(user, pct) + ("%+d" % flat if flat != 0 else "")


## 11 回目：文の中の「POW70%」「SLD400%」に、使う人の値を（）で足す（必殺技の desc・陣形の差し替えの文など）
static func pct_fill(user: Dictionary, s: String) -> String:
	if user.is_empty() or s.find("%") < 0:
		return s
	var re := RegEx.new()
	re.compile("(POW|SLD)(\\d+)%(?!（)")
	var out := ""
	var at := 0
	for m in re.search_all(s):
		out += s.substr(at, m.get_start() - at)
		var pct := int(m.get_string(2))
		out += pow_txt(user, pct) if m.get_string(1) == "POW" else sld_txt(user, pct)
		at = m.get_end()
	return out + s.substr(at)


## 追加効果（bonus）の文。例「ダメージ+POW25%（5）　自分にブロック+SLD60%（4）」
static func bonus_text(user: Dictionary, b: Dictionary) -> String:
	if b.has("text"):
		return pct_fill(user, str(b.text))  # 説明文を差し替える（星降り）
	var parts: Array = []
	if int(b.get("pow_pct", 0)) != 0:
		parts.append("ダメージ+" + pow_txt(user, int(b.pow_pct)))
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
			elif k == "yoyaku" and int(tb.get("pow_pct", 0)) > 0:
				# D（12 回目・豪炎）：予約の攻撃だけのカード（同じ対象へ。text があればそれ）
				out.append("[i:kw_%s]%s：%s %s" % [k, KW_NAME[k], KW_COND[k], bonus_text(user, tb)])
		elif KW_COND.has(k):
			# 札ごとの追加効果（bonus_sokuou など。無ければ bonus）
			out.append("[i:kw_%s]%s：%s %s" % [k, KW_NAME[k], KW_COND[k], bonus_text(user, action.get("bonus_" + k, action.get("bonus", {})))])
		elif KW_RULE.has(k):
			# 保留・揮発・ハイコスト（残のバッジがあれば揮発は効かない）
			if k == "kihatsu" and not burns(action, k):
				continue
			out.append("[i:kw_%s]%s：%s" % [k, KW_NAME[k], KW_RULE[k]])
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
		# 12 回目：味方の攻撃力の加算（レリックなど）は POW に入った（_dmg_txt の値に含まれる）。atk は敵のダメージの加算だけ
		var atk := ActionController.get_atk(user) if not user.is_empty() else 0
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
			parts.append("[i:stat_atk]%sダメージ×X回（X＝このターンにこのキャラが使ったカードの枚数%s）" % [_dmg_txt(user, action), ("。POW%+d" % atk) if atk != 0 else ""])
		elif action.get("power_used", false):
			parts.append("[i:stat_atk]Xダメージ%s（X＝このターンにこのキャラが使ったカードの枚数%s）" % [times, ("。POW%+d" % atk) if atk != 0 else ""])
		elif atk != 0 and not action.get("fixed", false):
			parts.append("[i:stat_atk]%sダメージ%s（POW%+d）" % [_dmg_txt(user, action), times, atk])
		else:
			parts.append("[i:stat_atk]%sダメージ%s" % [_dmg_txt(user, action), times])
	# D（10 回目の新カード）：盾打ち・炎刃・侵食の針・灰燼斬
	if action.get("power_half_block", false) and action.has("power"):
		var hb := int(floor(int(user.get("shield", 0)) / 2.0)) if not user.is_empty() else 0
		parts[parts.size() - 1] = "[i:shield]自分のブロックの半分のダメージ（今のブロックなら%d）" % hb
	# A（12 回目のナイトのカード）：盾打ち・審判の大盾・不死鳥の剣・剛腕・覇王の一撃・苦痛の糧
	if action.get("power_block", false) and action.has("power"):
		parts[parts.size() - 1] = "[i:shield]自分のブロックと同じダメージ（今のブロックなら%d。ブロックは減らない）" % (int(user.get("shield", 0)) if not user.is_empty() else 0)
	if int(action.get("burn_all_pct", 0)) > 0 and action.has("power"):
		parts[parts.size() - 1] = "[i:stat_atk]POW0%%ダメージ　[i:flame]自分の火傷を全部消し、消した数値1につきさらに+%s" % pow_txt(user, int(action.burn_all_pct))
	var ipw = action.get("if_pow")
	if ipw is Dictionary:
		parts.append("[i:atk_buff]自分のPOWが%d以上ならさらに+%s" % [int(ipw.get("min", 0)), pow_txt(user, int(ipw.get("pow_pct", 0)))])
	if int(action.get("per_pow_up_pct", 0)) > 0:
		parts.append("[i:atk_buff]自分のPOWの増えた分1につきさらに+POW%d%%" % int(action.per_pow_up_pct))
	var pss = action.get("per_self_status_pct")
	if pss is Dictionary:
		var snames: Array = []
		for sid0 in pss.get("statuses", []):
			snames.append(str(StatusEffectList.DATA.get(str(sid0), {}).get("name", "")))
		parts.append("[i:flame]自分の%sの数値の合計1につきさらに+POW%d%%" % ["・".join(snames), int(pss.get("pow_pct", 0))])
	var iss = action.get("if_self_status")
	if iss is Dictionary:
		parts.append("[i:flame]自分に%sがあればさらに+%s" % [str(StatusEffectList.DATA.get(str(iss.get("status", "")), {}).get("name", "")), _dmg_txt(user, iss)])
	var vss = action.get("vs_status")
	if vss is Dictionary:
		parts.append("[i:st_poison]%sが付いた敵にはさらに+%s" % [str(StatusEffectList.DATA.get(str(vss.get("status", "")), {}).get("name", "")), _dmg_txt(user, vss)])
	if int(action.get("per_exhaust", 0)) > 0:
		parts.append("[i:kw_exhaust]自分の廃棄札1枚につきさらに+%d" % int(action.per_exhaust))
	if int(action.get("per_exhaust_pct", 0)) > 0:
		parts.append("[i:kw_exhaust]自分の廃棄札1枚につきさらに+%s" % pow_txt(user, int(action.per_exhaust_pct)))
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
	if int(action.get("turn_discount", 0)) > 0:
		parts.append("[i:ap]自分のターン開始時に手札にあれば、このカードのAP-%d（戦闘中。0まで）" % int(action.turn_discount))  # D（12 回目）：流星の煌めき
	for e in ActionList.effects_of(action):
		var who := ""
		match e.get("to", "target"):
			"self": who = "自分に"
			"ally_all": who = "味方全体に"
			"other_ally": who = "もう1人の味方に"
		var turns := int(e.get("turns", -1))
		var dur := ("%dターン " % turns) if turns > 0 else ""
		match e.get("effect", ""):
			"add_shield": parts.append("[i:shield]%sブロック+%s%s" % [who, _shield_txt(user, e), "×X" if e.get("x", false) else ""])
			"absorb_block": parts.append("[i:shield]対象の敵のブロックの合計を、自分のブロックに足す")
			"add_ap": parts.append("[i:ap]AP+%d" % e.eff_val)
			"heal": parts.append("[i:heart]HP%d回復" % e.eff_val)
			"heal_pct": parts.append("[i:heart]HPを最大HPの%d%%回復" % int(e.eff_val))
			"draw": parts.append("[i:cards]カードを%d枚引く" % e.eff_val)
			"swap": parts.append("[i:swap]味方の位置を入れ替える")
			"double": parts.append("[i:st_double]次に使うカードが2回発動")
			"add_gauge": parts.append("[i:burst]%s必殺技ゲージ+%d" % [who, int(e.eff_val)])
			"extra_turn": parts.append("[i:hourglass]ターン終了時、もう一度ターンを得る")
			"set_next_action": parts.append("[i:hourglass]次に強攻撃")
			"rank_swap": parts.append("[i:formation]自分の前衛・後衛を入れ替える")
			"rank_to": parts.append("[i:formation]自分を%sに移動" % ("前衛" if int(e.get("eff_val", 1)) == 0 else "後衛"))
			"cleanse": parts.append("[i:heart]%sデバフ（火傷・毒・POWダウン・SLDダウン・DEFダウン・回復不可・スタン）を解除" % who)
			"repeat": parts.append("[i:skull]もう一度この攻撃が発動")
			"shield_per_status": parts.append("[i:shield]自分の%s1につきブロック+%s（%sは減らない）" % [
					str(StatusEffectList.DATA.get(str(e.get("status", "fire")), {}).get("name", "")), _shield_txt(user, e),
					str(StatusEffectList.DATA.get(str(e.get("status", "fire")), {}).get("name", ""))])
			"dmg_half_block": parts.append("[i:shield]自分のブロックの半分のダメージ")
			# A（12 回目）：気炎・引きつけ・肩を貸す、ステータス増減（戦闘終了まで）
			"shield_pow": parts.append("[i:shield]%sブロック+%s" % [who, pow_txt(user, int(e.get("pow_pct", 0)))])
			"double_block": parts.append("[i:shield]自分のブロックを2倍にする")
			"cleanse_one": parts.append("[i:heart]%sデバフを1つ解除" % who)
			"add_stat":
				var sn := str(ActionController.STAT_NAME.get(str(e.get("stat", "pow")), ""))
				parts.append("[i:%s]%s%s%+d%s（戦闘中）" % ["atk_buff" if str(e.get("stat", "pow")) == "pow" else "st_def_up", who, sn, int(e.get("eff_val", 0)), "×X" if e.get("x", false) else ""])
			"add_status":
				var st: Dictionary = StatusEffectList.DATA.get(e.status, {})
				var ic := "[i:%s]" % str(st.get("icon", "star"))
				match e.status:
					"taunt": parts.append("%s%s挑発（単体攻撃をこちらへ向けさせる）" % [ic, dur])
					"poison": parts.append("%s毒%dターン" % [ic, int(e.eff_val)])
					"fire": parts.append("%s%s火傷%d" % [ic, who, int(e.eff_val)])
					"stun": parts.append("%sスタン（次のターンを休む）" % ic)
					"no_heal": parts.append("%s%s回復不可" % [ic, dur])
					"atk_down": parts.append("%s%sPOW-%d%s" % [ic, dur, int(e.eff_val), "（戦闘中）" if turns < 0 else ""])  # 12 回目：旧 ID（pow_down と同じ）
					"def_down": parts.append("%s%sDEF-%d%s" % [ic, dur, int(e.eff_val), "（戦闘中）" if turns < 0 else ""])
					"ap_plus": parts.append("%s%sAPプラス（ターン開始時AP+%d）" % [ic, dur, int(e.eff_val)])
					"ap_next": parts.append("%s次の自分のターンAP+%d" % [ic, int(e.eff_val)])
					"fire_guard": parts.append("%s%s攻撃してきた相手に火傷%d" % [ic, dur, int(e.eff_val)])
					"barricade": parts.append("%s戦闘中ずっと、ターン開始時にブロックが消えない" % ic)
					"focus": parts.append("%s次の自分のターン、必殺技のAP-%d" % [ic, int(e.eff_val)])
					"declare": parts.append("%s宣言：次の自分のターン開始時までにHPが減らなければ、%dターン APプラス（ターン開始時AP+1）" % [ic, int(e.eff_val)])
					"reblock": parts.append("%s次の自分のターン開始時にブロック+%d" % [ic, int(e.eff_val)])
					"chant": parts.append("%s次に使うアタックカードのダメージ+%d" % [ic, int(e.eff_val)])  # D：詠唱の構え
					# A（12 回目）：庇う（城壁・身代わり）、敵に付ける POW ダウン（鉄壁の反撃）
					"cover": parts.append("%s%s%s庇う（もう1人の味方への敵の攻撃を代わりに受ける）" % [ic, who, dur])
					"pow_down": parts.append("%s%sPOW-%d%s" % [ic, dur, int(e.eff_val), "（戦闘中）" if turns < 0 else ""])
					_: parts.append("%s%s%s%s+%d" % [ic, who, dur, str(st.get("name", "")).replace("アップ", ""), int(e.eff_val)])
	if burns(action, "exhaust") and not is_power:
		parts.append("[i:kw_exhaust]使うと廃棄")
	if str(action.get("badge", "")) == "keep" and (ActionList.has_keyword(action, "exhaust") or ActionList.has_keyword(action, "consume") or ActionList.has_keyword(action, "kihatsu")):
		parts.append("[i:b_keep]廃棄・消費しない")
	var kl := keyword_lines(user, action)
	if action.get("saigo_only", false):
		# 「最後」の効果しか無いカード：条件を満たした時だけ使える
		kl = kl.filter(func(s): return not str(s).begins_with("[i:kw_saigo]"))
		kl.append("[i:kw_saigo]最後：手札（空き欄を含む）に他のカードが無い時だけ使える")
	if is_power:
		kl = kl.filter(func(s): return not str(s).begins_with("[i:kw_jinkei]") and not str(s).begins_with("[i:kw_sokuou]"))  # power_text で説明済み
	parts.append_array(kl)
	return "　".join(parts)


## パワーカードの説明（power_effect の形は ActionList の説明を参照）。戦闘終了まで効く。12 回目：AP はカードごと（データの "ap"）
static func power_text(user: Dictionary, action: Dictionary) -> String:
	var pe: Dictionary = action.get("power_effect", {})
	var head := "[i:kw_power]パワー：使うと戦闘終了まで"
	if pe.has("left") or pe.has("right"):
		return "%s [i:kw_jinkei]陣形：左（青）にいる間 %s／右（赤）にいる間 %s（入替・陣形変更で切り替わる。重ねて使える）" % [
				head, _power_body(user, pe.get("left", {})), _power_body(user, pe.get("right", {}))]
	if pe.get("exhaust_now", false):
		return "[i:kw_power]パワー：使うと %s（その後廃棄）" % _power_body(user, pe)
	var tail := "（重ねて使える）"
	if burns(action, "exhaust"):
		tail = "（使うと廃棄）"
	return "%s %s%s" % [head, _power_body(user, pe), tail]


static func _power_body(user: Dictionary, pe: Dictionary) -> String:
	var parts: Array = []
	if pe.has("status"):
		var st: Dictionary = StatusEffectList.DATA.get(pe.get("status", ""), {})
		parts.append(("味方全体の" if pe.get("all", false) else "") + "[i:%s]%s+%d" % [st.get("icon", "star"), str(st.get("name", "")).replace("アップ", ""), int(pe.get("eff_val", 0))])
	if pe.has("once") and str(pe.get("kind", "")) != "barricade":
		var t := effect_text(user, {"effects": pe.once})
		parts.append(t if pe.get("exhaust_now", false) else "使った時 " + t)
	if int(pe.get("aid_atk", 0)) > 0:
		parts.append("[i:atk_buff]もう1人の味方のPOW+%d" % int(pe.aid_atk))
	match str(pe.get("kind", "")):
		"burn_atk": parts.append("[i:flame]自分の火傷の残りターン分、POW+")
		"last_stand": parts.append("[i:stat_atk]HPの残りX%で POW+Y・DEF+Y（Y＝(100−X)÷10 切り捨て）")
		# A（12 回目）：バリケード・闘気の昂り・業火の構え・双剣の誓い
		"barricade": parts.append("[i:st_barricade]ターン開始時にブロックが消えない")
		"turn_stat": parts.append("[i:atk_buff]自分のターン開始時に%s+%d（積み重なる）" % [str(ActionController.STAT_NAME.get(str(pe.get("stat", "pow")), "")), int(pe.get("eff_val", 1))])
		"on_tick_dmg": parts.append("[i:flame]自分が状態異常のダメージを受けるたび、ランダムな敵に同じダメージ×%d回（固定。1回ごとに敵を選び直す）" % int(pe.get("hits", 2)))
		"on_ally_attack": parts.append("[i:shield]もう1人の味方がアタックカードを使うたび、味方全体にブロック+%d（固定）" % int(pe.get("shield", 0)))
		"on_plain_card": parts.append("[i:tgt_enemy_all]札の無いカードが発動するたび、敵全体に%dダメージ　[i:kw_sokuou]即応：さらに+%d" % [int(pe.get("dmg", 0)), int(pe.get("sokuou_add", 0))])
		"on_burn": parts.append("[i:tgt_enemy_all]消費・廃棄が発動するたび、敵全体に%dダメージ" % int(pe.get("dmg", 0)))
		"on_attack_poison": parts.append("[i:st_poison]%sを使うたび、当たった敵に毒%d" % ["カード" if pe.get("any_card", false) else "アタックカード", int(pe.get("eff_val", 1))])
		# D（12 回目）：フォース・双星の魔法陣
		"turn_start_stat": parts.append("[i:st_def_up]自分のターン開始時、味方全体の%s+%d（戦闘中。積み重なる）" % [str(ActionController.STAT_NAME.get(str(pe.get("stat", "sld")), "")), int(pe.get("eff_val", 1))])
		"on_skill_card": parts.append("[i:shield]スキルカードが発動するたび、発動したキャラにSLD%d%%ブロック（そのキャラのSLDで計算）" % int(pe.get("sld_pct", 0)))
		"on_debuff_card": parts.append("[i:shield]状態異常を付けるカードを使うたび、自分にブロック+%d（固定）" % int(pe.get("shield", 1)))
		"on_own_card": parts.append("[i:flame]このキャラがカードを使うたび、もう1人の味方に火傷%d・ブロック+%d（固定）" %[int(pe.get("fire", 1)), int(pe.get("shield", 0))])
		"on_gekiha_card": parts.append("[i:atk_buff]%sのカードを使うたび、自分のPOW+%d（戦闘中）" % [_kws_text(pe.get("kws", ["gekiha"])), int(pe.get("atk", 1))])
		"on_kw_card": parts.append("[i:tgt_enemy_all]%sのカードが発動するたび、敵全体に%dダメージ　[i:kw_sokuou]即応：さらに+%d" % [_kws_text(pe.get("kws", [])), int(pe.get("dmg", 0)), int(pe.get("sokuou_add", 0))])
		"on_gekiha_hangeki": parts.append("[i:tgt_random]撃破・反撃が発動するたび、ランダムな敵に%d×%d（固定）" % [int(pe.get("power", 2)), int(pe.get("hits", 5))])
		"end_herb": parts.append("[i:item_herb]自分のターン終了時に薬草を得る（アイテムがいっぱいなら得られない）")
		"end_convert": parts.append("[i:kw_consume]自分のターン終了時に、手札1枚をランダムに捨て（消費）、そのカードのAP分 AP+")
	return "　".join(parts) if not parts.is_empty() else "—"


## 札の名前を「・」でつなぐ（例：即応・転身）
static func _kws_text(kws: Array) -> String:
	var names: Array = []
	for k in kws:
		names.append(str(KW_NAME.get(str(k), str(k))))
	return "・".join(names)
