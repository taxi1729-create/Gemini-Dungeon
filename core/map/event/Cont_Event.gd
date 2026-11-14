extends Node2D
## イベント「？」：ランダムで 1 つ発生し、選択肢を選ぶ
## 9 回目（D）：選択肢をフリック入力（GuiFlickPad）に。選択肢 3 つ＝8・4・6、2 つ＝4・6、1 つ＝8。
## 右の列：デッキ一覧／ステータス。結果が出たら確定＝先へ進む（マップへ）。
## 「1 人の最大HP+5」はナイト／ウィッチを 4・6 で選び直す（確定＝戻る）。
## 10 回目（D）：イベントを 30 個に増やし、今の階（CurrentStatus.stage）のイベントだけ出す（EventList.ids_for_floor）。
##   「戦闘。勝てば〜」は CurrentStatus.event_reward に報酬を入れて戦闘へ（結果画面のその他の報酬に出る）。
##   カードを 2・3 枚から選ぶ選択肢は _ask_pick（4・6 ／ 8・4・6 にカード。確定＝戻る）。
##   ゴールドを払う選択肢は、足りなければ選べない（暗くする）。

const CHOICE_KEYS := {1: [8], 2: [4, 6], 3: [8, 4, 6]}

var ui: CanvasLayer
var pad: GuiFlickPad
var ev_id := ""
var result_label: Label
var icon_w: GuiWidget
var choices: Array = []  # [[id, 文], ...]
var finished := false  # 結果が出た
var _owner_cb := Callable()  # 「どちらの最大HPを上げますか」の選択中
var _pick_cb := Callable()  # カードを選ぶ画面（_ask_pick）の選択中
var _pick_keys: Array = []
var _meta := {}  # 選択肢 id → {"short", "icon"}（EventList の 3・4 番目の要素）


func _ready() -> void:
	CurrentStatus.ensure_started()
	add_child(GuiBackground.new("title"))
	ui = CanvasLayer.new()
	add_child(ui)
	# 再読み込みで同じイベントに戻れるよう、選んだイベントをセーブに残す
	ev_id = str(SaveData.screen.get("event_id", ""))
	if not EventList.DATA.has(ev_id):
		var pool := EventList.ids_for_floor(CurrentStatus.stage)
		if pool.is_empty():
			pool = EventList.DATA.keys()
		ev_id = str(pool.pick_random())
		SaveData.screen["event_id"] = ev_id
		SaveData.save("event")
	var ev: Dictionary = EventList.DATA[ev_id]
	var col: Dictionary = ImageController.COL
	UiSystem.make_banner(ui, "？ EVENT", Rect2(36, 30, 200, 44), 24)
	UiSystem.make_banner(ui, ev.title, Rect2(60, 82, 600, 76), 42, col.ink, col.paper, 28)
	# アイコンの後ろに赤いギザギザ
	var deco := Control.new()
	deco.size = Vector2(720, 420)
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.draw.connect(func():
		var IC = ImageController
		var c := Vector2(360, 270)
		IC.halftone(deco, Rect2(140, 170, 440, 200), Color(col.paper, 0.08), c, 220, 16, 5)
		IC.poly_box(deco, IC.burst_pts(c, 120, 88, 14, 11, 0.2), col.red, 4.0, col.ink, col.ink, Vector2(8, 8))
		# アイコンの台座：バラ窓（ステンドグラスの輪＋紺の中心）
		IC.stained(deco, IC.ell(c, 76, 76, 36), 23, 0.9, [], Color(0, 0, 0, 0), 20.0, 22.0)
		deco.draw_arc(c, 76, 0, TAU, 40, col.ink, 4.0, true)
		deco.draw_circle(c, 58, col.ink.lerp(IC.GLASS.sacred_blue, 0.3))
		deco.draw_arc(c, 58, 0, TAU, 36, IC.GLASS.stone_gray, 3.0, true))
	ui.add_child(deco)
	icon_w = GuiWidget.new("icon", Rect2(290, 200, 140, 140))
	icon_w.icon_kind = ev.icon
	ui.add_child(icon_w)
	# 本文は白いギザギザ吹き出し（しっぽはアイコンへ）
	UiSystem.make_bubble(ui, Rect2(46, 392, 628, 120), Vector2(360, 350), 8)
	var body := UiSystem.make_label(ui, ev.text, Vector2(70, 396), Vector2(580, 112), 23, col.ink, HORIZONTAL_ALIGNMENT_CENTER, 0)
	body.add_theme_font_override("font", ImageController.font_bold)
	result_label = UiSystem.make_label(ui, "", Vector2(40, 520), Vector2(640, 80), 28, col.paper, HORIZONTAL_ALIGNMENT_CENTER, 8)
	result_label.add_theme_font_override("font", ImageController.font_head)
	result_label.add_theme_color_override("font_outline_color", col.red)
	UiSystem.make_banner(ui, "所持：%dゴールド　%s" % [Inventory.gold, Inventory.foods_text()], Rect2(60, 604, 600, 40), 18,
			col.paper, col.ink, 16)
	pad = GuiFlickPad.new()
	pad.header_left = "イベント"
	pad.hint = "選択肢を弾いて（タップで）選ぶ・長押しで説明"
	ui.add_child(pad)
	pad.chosen.connect(_on_chosen)
	choices = []
	for c in ev.choices:
		var label: String = c[1]
		if c[0] == "badge":
			label = label % BadgeList.DATA[_event_badge()].name
		choices.append([str(c[0]), label])
		if c.size() >= 4:
			_meta[str(c[0])] = {"short": str(c[2]), "icon": str(c[3])}
	_show_choices()


## 選択肢のマス（数に応じて 8・4・6 ／ 4・6 ／ 8）
func _show_choices() -> void:
	for k in [8, 4, 6]:
		pad.clear_cell(k)
	pad.clear_cell("ok")
	var keys: Array = CHOICE_KEYS.get(clampi(choices.size(), 1, 3), [8])
	for i in mini(choices.size(), keys.size()):
		var id: String = choices[i][0]
		var info := {"title": _short_title(id, choices[i][1]), "icon": _choice_icon(id), "accent": _choice_col(id),
				"desc": str(choices[i][1])}
		var why := choice_block(id)
		if why != "":
			info["enabled"] = false
			info["block_msg"] = why
		pad.set_cell(keys[i], info)
	pad.queue_redraw()


## 選択肢 → マスの番号（テスト用。無ければ null）
func key_of(choice_id: String):
	var keys: Array = CHOICE_KEYS.get(clampi(choices.size(), 1, 3), [8])
	for i in mini(choices.size(), keys.size()):
		if choices[i][0] == choice_id:
			return keys[i]
	return null


## 選択肢を今選べないわけ（"" ＝選べる）。ゴールドが足りない・レリックが残っていない
func choice_block(id: String) -> String:
	var cost := int(GOLD_COST.get(id, 0))
	if cost > 0 and Inventory.gold < cost:
		return "ゴールドが足りない（%dゴールド必要）" % cost
	return ""


const GOLD_COST := {"shield_polish": 30, "star_map": 80}


## 丸いボタンに入る短い名前
func _short_title(id: String, label: String) -> String:
	if _meta.has(id):
		return str(_meta[id].short)
	match id:
		"gold40": return "ゴールド40"
		"item": return "道具"
		"altar": return "捧げる"
		"mush3": return "きのこ×3"
		"eat": return "食べる"
		"remove": return "カード削除"
		"heal12": return "HP+12"
		"maxhp": return "最大HP+5"
		"fight": return "戦う"
		"badge": return "バッジ"
		"leave": return "立ち去る"
	return label.substr(0, 6)


func _choice_icon(id: String) -> String:
	if _meta.has(id):
		return str(_meta[id].icon)
	match id:
		"gold40": return "coin"
		"item": return "potion"
		"altar": return "star"
		"mush3", "eat": return "mushroom"
		"remove": return "skull"
		"heal12", "maxhp": return "heart"
		"fight": return "sword"
		"badge": return "badge"
		"leave": return "enter"
	return "question"


func _choice_col(id: String) -> Color:
	match id:
		"leave": return ImageController.GLASS.stone_gray
		"fight", "altar", "ascetic_fight", "mirror_fight", "prisoner_help", "bell_check", "door_force": return ImageController.COL.red
	return ImageController.COL.gold


func _on_chosen(key) -> void:
	match key:
		"deck":
			_lock(GuiDeckView.open(ui, "デッキ"))
			return
		"status":
			_lock(GuiStatusView.open(ui, CurrentStatus.allies))
			return
		"ok":
			if finished:
				UiSystem.goto("map")
			elif _pick_cb.is_valid():
				_pick_cb = Callable()
				_show_choices()  # 戻る
			elif _owner_cb.is_valid():
				_owner_cb = Callable()
				_show_choices()  # 戻る
			return
	if finished:
		return
	if _pick_cb.is_valid():
		var pi := _pick_keys.find(key)
		if pi >= 0:
			var pcb := _pick_cb
			_pick_cb = Callable()
			pcb.call(pi)
		return
	if _owner_cb.is_valid():
		if key == 4 or key == 6:
			var cb := _owner_cb
			_owner_cb = Callable()
			cb.call("knight" if key == 4 else "witch")
		return
	var keys: Array = CHOICE_KEYS.get(clampi(choices.size(), 1, 3), [8])
	var i := keys.find(key)
	if i >= 0 and i < choices.size() and choice_block(str(choices[i][0])) == "":
		_choose(str(choices[i][0]))


func _lock(v: Node) -> void:
	pad.locked = true
	if v != null and v.has_signal("closed"):
		v.closed.connect(func(): pad.locked = false)


func _choose(id: String) -> void:
	if finished:
		return
	match id:
		"gold40":
			Inventory.gold += 40
			_done("ゴールドを40手に入れた")
		"item":
			var it: String = Item_List.random_id()
			if Inventory.add_item(it):
				_done("%sを手に入れた" % Item_List.DATA[it].name)
			else:
				_done("%sを見つけたが、アイテムがいっぱい（3つまで）" % Item_List.DATA[it].name)
		"altar":
			for a in CurrentStatus.allies:
				a["hp"] = maxi(1, int(a.hp) - 6)
			var c := ActionList.make_card(ActionList.random_card_id("rare"))
			CurrentDeck.add_card(c.owner, c.id)
			_done("%s を授かった（%sのデッキに追加）" % [c.name, InitAllyStatus.DATA[c.owner].name])
		"mush3":
			for i in 3:
				Inventory.add_food("mush", 1)
			_done("きのこ（G1）を3つ採った")
		"eat":
			if randf() < 0.5:
				CurrentStatus.heal_all(10)
				_done("おいしい！ 全員HP+10")
			else:
				for a in CurrentStatus.allies:
					a["hp"] = maxi(1, int(a.hp) - 5)
				_done("おなかを壊した… 全員HP-5")
		"remove":
			pad.locked = true
			var v := GuiDeckView.open(ui, "削除するカードを選ぶ", func(char_id, card_id):
				CurrentDeck.remove_card(char_id, card_id)
				_done("%s を削除した" % ActionList.make_card(card_id).name))
			v.closed.connect(func(): pad.locked = false)
		"heal12":
			CurrentStatus.heal_all(12)
			_done("全員HP+12")
		"maxhp":
			_ask_owner(func(char_id):
				var a := CurrentStatus.ally(char_id)
				a["max_hp"] = int(a.max_hp) + 5
				a["hp"] = int(a.hp) + 5
				_done("%sの最大HP+5" % a.name))
		"fight":
			CurrentStatus.battle_kind = "battle"
			CurrentStatus.gold_multiplier = 2
			SaveData.screen = {}
			SaveData.save("battle")  # 再読み込みしたらこの戦闘から
			UiSystem.goto("battle")
		"badge":
			var bid := _event_badge()
			pad.locked = true
			GuiAcquire.badge(ui, bid, func(ok: bool):
				pad.locked = false
				if ok:
					_done("%sを付けてもらった" % BadgeList.DATA[bid].name)
				else:
					_done("バッジを受け取らずに立ち去った"))
		"leave":
			_done("その場を後にした")
		_:
			_choose_new(id)


## イベント「旅の細工師」のバッジ（再読み込みで変わらないようセーブに残す）
func _event_badge() -> String:
	var bid := str(SaveData.screen.get("event_badge", ""))
	if not BadgeList.DATA.has(bid):
		bid = BadgeList.random_id()
		SaveData.screen["event_badge"] = bid
		SaveData.save("event")
	return bid


## どちらのキャラかを 4（ナイト）・6（ウィッチ）で選ぶ。確定＝戻る
func _ask_owner(cb: Callable) -> void:
	_owner_cb = cb
	for k in [8, 4, 6]:
		pad.clear_cell(k)
	pad.set_cell(4, {"title": "ナイト", "icon": "sword", "accent": ImageController.COL.get("knight", ImageController.COL.paper), "desc": "ナイトの最大HP+5"})
	pad.set_cell(6, {"title": "ウィッチ", "icon": "flame", "accent": ImageController.COL.get("witch", ImageController.COL.paper), "desc": "ウィッチの最大HP+5"})
	pad.set_cell("ok", {"title": "戻る", "icon": "enter", "accent": ImageController.GLASS.stone_gray, "desc": "選択肢に戻る"})
	pad.flash("最大HP+5", "どちらの最大HPを上げますか？（4＝ナイト・6＝ウィッチ）")
	pad.queue_redraw()


func _done(msg: String) -> void:
	finished = true
	result_label.text = msg
	SaveData.save("map")  # イベントの結果を反映した時点で保存（再読み込みしたらマップへ）
	for k in [8, 4, 6]:
		pad.clear_cell(k)
	pad.set_cell("ok", {"title": "先へ進む", "icon": "enter", "accent": ImageController.COL.red, "desc": "マップに戻って先へ進む"})
	pad.hint = "確定で先へ進む"
	pad.queue_redraw()


# ============================================================
# 10 回目（D）：新しいイベントの選択肢（数値は仮）
# ============================================================
func _choose_new(id: String) -> void:
	var CS = CurrentStatus
	var kn: Dictionary = CS.ally("knight")
	var wt: Dictionary = CS.ally("witch")
	match id:
		# ----- 1 階 -----
		"cart_item":
			_give_items(1, "荷車から")
		"cart_carry", "lr_hurry":
			Inventory.gold += 50
			_done("ゴールドを50手に入れた")
		"water_drink":
			CS.heal_pct_all(20)
			_done("冷たい水で元気が出た（全員HP20%回復）")
		"water_draw":
			if Inventory.add_item("herb"):
				_done("薬草を手に入れた")
			else:
				_done("薬草を作ったが、アイテムがいっぱい（%dつまで）" % Inventory.ITEM_MAX)
		"shield_pick":
			_give_card(_card_of("common", "knight", "skill"), "")
		"shield_polish":
			Inventory.gold -= 30
			_give_badge("guard")
		"book_read":
			CS.change_max_hp(wt, -3)
			_give_card(_card_of("rare", "witch"), "ウィッチの最大HP-3。")
		"book_burn":
			Inventory.gold += 30
			_done("燃え残りの金具を売って30ゴールド")
		"ascetic_fight":
			_fight("battle", {"kind": "ev_card", "id": _card_of("rare", "")})
		"ascetic_learn", "choir_listen", "ghost_listen", "font_dip":
			_give_badge(_event_badge())
		"trap_run":
			CS.damage_all(6)
			Inventory.gold += 40
			_done("罠をかわしきれず全員HP-6。40ゴールドを拾った")
		"trap_disarm", "lib_copy":
			_remove_cards(1)
		"fire_rest":
			CS.heal_pct_all(10)
			_done("少し休んだ（全員HP10%回復）")
		"fire_ash":
			var f1: String = ["meat", "mush", "fish"].pick_random()
			Inventory.add_food(f1, 2)
			_done("%s（G2）を見つけた" % FoodList.DATA[f1].name)
		# ----- 2 階 -----
		"choir_sing":
			for a in CS.allies:
				CS.change_max_hp(a, 4)
			_done("声の無い歌に心が満ちた（全員の最大HP+4）")
		"mirror_fight":
			_fight("battle", {"kind": "dup", "id": ""})
		"mirror_break":
			CS.damage_all(8)
			_give_relic("鏡の破片で全員HP-8。")
		"prisoner_help":
			_fight("battle", {"kind": "relic", "id": RelicList.random_id(Inventory.relics)})
		"prisoner_key":
			Inventory.gold += 50
			_give_items(2, "50ゴールドと、")
		"lib_search":
			var a1 := _card_of("rare", "")
			var a2 := _card_of("rare", "", "", [a1])
			_ask_pick([a1, a2], func(i: int):
				var cid: String = [a1, a2][i]
				_give_card(cid, ""))
		"statue_sword":
			CS.add_floor_fx("knight_atk", 1)
			_done("剣に力が宿った（この階の間、ナイトの攻撃力+1）")
		"statue_staff":
			CS.add_floor_fx("witch_ap", 1)
			_done("杖に魔力が宿った（この階の間、ウィッチの毎ターンAP+1）")
		"ghost_pray":
			CS.heal_all(15)
			_done("亡霊は安らかに消えた（全員HP+15）")
		"font_drink":
			for a in CS.allies:
				CS.change_max_hp(a, -5)
				a["hp"] = int(a.max_hp)
			_done("聖水で傷が消えた（全員HP全回復・最大HP-5）")
		"gamble_bet":
			if randf() < 0.5:
				Inventory.gold *= 2
				_done("当たり！ 所持金が2倍（%dゴールド）" % Inventory.gold)
			else:
				Inventory.gold = int(Inventory.gold / 2.0)
				_done("外れ… 所持金が半分（%dゴールド）" % Inventory.gold)
		"gamble_watch":
			Inventory.gold += 10
			_done("見物料のおこぼれで10ゴールド")
		"col_jump":
			kn["hp"] = maxi(1, int(kn.hp) - 10)
			_give_treasure("ナイトHP-10。")
		"col_around":
			_done("遠回りして先へ進んだ")
		"col_dig":
			var got: Array = []
			for i in 2:
				var f2: String = ["meat", "mush", "fish"].pick_random()
				Inventory.add_food(f2, 2)
				got.append("%s（G2）" % FoodList.DATA[f2].name)
			_done("%sを見つけた" % "・".join(got))
		"portrait_blue":
			CS.add_floor_fx("left_block", 2)
			_done("青い光に包まれた（この階の間、左のキャラはターン開始時ブロック+2）")
		"portrait_red":
			CS.add_floor_fx("right_atk", 1)
			_done("赤い光に包まれた（この階の間、右のキャラの攻撃力+1）")
		# ----- 3 階 -----
		"glass_blue":
			for a in CS.allies:
				CS.change_max_hp(a, 5)
			_done("青の光を浴びた（全員の最大HP+5）")
		"glass_red":
			for a in CS.allies:
				a["atk"] = int(a.get("atk", 0)) + 1
			CS.damage_all(10)
			_done("赤の光を浴びた（全員の攻撃力+1・全員HP-10）")
		"conf_tell":
			_remove_cards(2)
		"conf_pray":
			CS.heal_pct_all(30)
			_done("静かに祈った（全員HP30%回復）")
		"bell_ring":
			CS.next_battle["ap"] = int(CS.next_battle.get("ap", 0)) + 3
			_done("鐘の音が響いた（次の戦闘で最初のAP+3）")
		"bell_check":
			_fight("elite", {"kind": "relic", "id": RelicList.random_id(Inventory.relics)})
		"rel_open":
			_give_relic("")
		"rel_bless":
			_give_card(_card_of("super_rare", ""), "")
		"feather_pick":
			var ids: Array = []
			for i in 3:
				ids.append(_card_of("super_rare", "", "", ids))
			_ask_pick(ids, func(i: int):
				for a in CS.allies:
					CS.change_max_hp(a, -8)
				_give_card(str(ids[i]), "全員の最大HP-8。"))
		"feather_burn":
			for a in CS.allies:
				a["hp"] = int(a.max_hp)
			_done("羽の炎が傷を癒やした（全員HP全回復）")
		"star_read":
			CS.next_battle["block"] = int(CS.next_battle.get("block", 0)) + 15
			_done("星が守りを告げた（次の戦闘の最初のラウンドに全員ブロック+15）")
		"star_map":
			Inventory.gold -= 80
			_give_relic("80ゴールドで星図を買った。")
		"door_force":
			_fight("battle", {"kind": "ev_card", "id": _card_of("super_rare", "")})
		"door_key":
			Inventory.gold += 100
			_done("鍵は見つからなかったが、100ゴールドを見つけた")
		"hymn_sing":
			CS.next_battle["sokuou_all"] = 1
			_done("聖歌が満ちた（次の戦闘の間、即応が常に成立）")
		"hymn_take":
			if Inventory.add_item("holy_water"):
				_done("%sを手に入れた" % Item_List.DATA["holy_water"].name)
			else:
				_done("%sを見つけたが、アイテムがいっぱい（%dつまで）" % [Item_List.DATA["holy_water"].name, Inventory.ITEM_MAX])
		"twin_knight":
			kn["hp"] = maxi(1, int(kn.hp) - 20)
			_give_relic("ナイトHP-20。")
		"twin_witch":
			wt["hp"] = maxi(1, int(wt.hp) - 15)
			_give_relic("ウィッチHP-15。")
		"lr_cook":
			finished = true
			SaveData.save("rest")  # 再読み込みしたら休憩所から
			UiSystem.goto("rest")
		"lr_sleep":
			CS.heal_pct_all(40)
			_done("ぐっすり眠った（全員HP40%回復）")


## ランダムなカード ID（tier＝common/rare/super_rare。owner・type を指定するとそれだけ。except は出さない）
func _card_of(tier: String, owner: String, type: String = "", except: Array = []) -> String:
	var src: Dictionary = ActionList.ALLY_CARDS[tier]
	var keys: Array = src.keys().filter(func(k): return (owner == "" or str(src[k].owner) == owner) \
			and (type == "" or str(src[k].type) == type) and not except.has(k))
	if keys.is_empty():
		keys = src.keys().filter(func(k): return owner == "" or str(src[k].owner) == owner)
	return str(keys.pick_random())


func _give_card(card_id: String, pre: String) -> void:
	pad.locked = true
	var c := ActionList.make_card(card_id)
	GuiAcquire.card(ui, card_id, func(_ok: bool):
		pad.locked = false
		_done("%s%s を手に入れた（%sのデッキに追加）" % [pre, c.get("name", ""), InitAllyStatus.DATA[str(c.owner)].name]))


func _give_badge(bid: String) -> void:
	pad.locked = true
	GuiAcquire.badge(ui, bid, func(ok: bool):
		pad.locked = false
		if ok:
			_done("%sを付けた" % BadgeList.DATA[bid].name)
		else:
			_done("バッジを付けずに立ち去った"))


## レリック（持っていないものから。全部持っていれば 50 ゴールド）
func _give_relic(pre: String) -> void:
	var rid := RelicList.random_id(Inventory.relics)
	if rid == "":
		Inventory.gold += 50
		_done("%sレリックは見つからず、50ゴールドを手に入れた" % pre)
		return
	pad.locked = true
	GuiAcquire.relic(ui, rid, func(got: bool):
		pad.locked = false
		_done("%s%s" % [pre, ("%sを手に入れた" % RelicList.DATA[rid].name) if got else "レリックを諦めた"]))


func _give_items(n: int, pre: String) -> void:
	var names: Array = []
	var lost: Array = []
	for i in n:
		var it: String = Item_List.random_id()
		if Inventory.add_item(it):
			names.append(str(Item_List.DATA[it].name))
		else:
			lost.append(str(Item_List.DATA[it].name))
	var msg := pre
	if not names.is_empty():
		msg += "%sを手に入れた" % "・".join(names)
	if not lost.is_empty():
		msg += ("　" if not names.is_empty() else "") + "%sはアイテムがいっぱいで持てない" % "・".join(lost)
	_done(msg)


## 宝箱の中身 1 つ（宝箱のマスと同じ確率）
func _give_treasure(pre: String) -> void:
	var ct: Dictionary = TREASURE.roll()
	match str(ct.kind):
		"relic":
			pad.locked = true
			GuiAcquire.relic(ui, str(ct.id), func(got: bool):
				pad.locked = false
				_done("%s%s" % [pre, ("%sを手に入れた" % RelicList.DATA[ct.id].name) if got else "レリックを諦めた"]))
		"badge":
			_give_badge(str(ct.id))
		"gold":
			Inventory.gold += int(ct.gold)
			_done("%s%dゴールドを手に入れた" % [pre, int(ct.gold)])
		_:
			_give_card(str(ct.id), pre)


const TREASURE = preload("res://index/core/map/treasure/Cont_Treasure.gd")


## カードを n 枚削除する（1 枚ずつデッキ一覧で選ぶ。やめたらそこまで）
func _remove_cards(n: int, removed: Array = []) -> void:
	pad.locked = true
	var v := GuiDeckView.open(ui, "削除するカードを選ぶ（あと%d枚）" % (n - removed.size()), func(char_id, card_id):
		CurrentDeck.remove_card(char_id, card_id)
		removed.append(ActionList.make_card(card_id).name))
	# 選んだ時は closed の後に選んだ処理が呼ばれるので、判定は次のフレームで
	v.closed.connect(func(): _after_remove.call_deferred(n, removed))


func _after_remove(n: int, removed: Array) -> void:
	if not is_inside_tree():
		return
	pad.locked = false
	if removed.size() < n and removed.size() > 0:
		_remove_cards(n, removed)
	elif removed.is_empty():
		_done("カードを削除せずに立ち去った")
	else:
		_done("%s を削除した" % "・".join(removed))


## 戦闘へ。勝ったら reward（{"kind": "ev_card"/"relic"/"dup", "id"}）が結果画面のその他の報酬に出る
func _fight(kind: String, reward: Dictionary) -> void:
	finished = true
	CurrentStatus.battle_kind = kind
	CurrentStatus.gold_multiplier = 1
	CurrentStatus.event_reward = reward if not (str(reward.kind) == "relic" and str(reward.id) == "") else {}
	SaveData.screen = {}
	SaveData.save("battle")  # 再読み込みしたらこの戦闘から
	UiSystem.goto("battle")


## カードを 2〜3 枚から 1 枚選ぶ画面（2 枚＝4・6、3 枚＝8・4・6）。確定＝戻る。cb(i)
func _ask_pick(ids: Array, cb: Callable) -> void:
	_pick_cb = cb
	_pick_keys = CHOICE_KEYS.get(clampi(ids.size(), 1, 3), [8])
	for k in [8, 4, 6]:
		pad.clear_cell(k)
	for i in mini(ids.size(), _pick_keys.size()):
		var c := ActionList.make_card(str(ids[i]))
		pad.set_cell(_pick_keys[i], {"card": c, "title": str(c.get("name", "")),
				"desc": DeckController.card_text(CurrentStatus.ally(str(c.owner)), c)})
	pad.set_cell("ok", {"title": "戻る", "icon": "enter", "accent": ImageController.GLASS.stone_gray, "desc": "選択肢に戻る"})
	pad.flash("カードを選ぶ", "%d枚から1枚を選ぶ" % ids.size())
	pad.queue_redraw()
