extends Node2D
## 戦闘シーン：進行・UI・入力
##
## 画面構成（720×1280）
##   上半分 : 行動順バー／戦場（味方2体が中央、敵が左右から挟む）／ログ
##   下半分 : 手札4枚を十字に配置（↑←↓→）、四隅に 入替・必殺・道具・終了
## 操作 : カードをタップ／下半分のどこからでもフリック（方向＝テンキー番号）で使用、長押しで説明

signal turn_done

# 戦場の立ち位置（キーは行動の対象判定に使うグリッド座標）
const POS = {
	"A2": Vector2(90, 455), "B1": Vector2(182, 330),
	"D2": Vector2(292, 440), "F2": Vector2(428, 440),
	"G1": Vector2(540, 330), "H2": Vector2(600, 455), "I2": Vector2(630, 455),
}
const ENEMY_KEYS = ["I2", "A2", "G1", "B1"]
const LOWER_RECT := Rect2(0, 660, 720, 620)
const HAND_POS = [Vector2(360, 790), Vector2(212, 965), Vector2(360, 1140), Vector2(508, 965)]
const HAND_KEYS = [8, 4, 2, 6]
const ARROW = {8: "↑", 4: "←", 2: "↓", 6: "→", 7: "↖", 9: "↗", 1: "↙", 3: "↘"}
const SYS_DEF = [
	["swap", "入替", "swap", Color("8fc0ea"), "ナイトとウィッチの位置を入れ替える（AP不要）。\n一番近い敵が変わるので、狙う相手を選べる。", 7, Vector2(110, 790)],
	["special", "必殺", "burst", Color("ffb03a"), "", 9, Vector2(610, 790)],
	["item", "道具", "potion", Color("6fd08a"), "所持している道具を使う（AP不要）。", 1, Vector2(110, 1140)],
	["end", "終了", "hourglass", Color("e8c26a"), "このキャラの手番を終える。\n残ったAPは次の手番に持ち越す。", 3, Vector2(610, 1140)],
]

var field: Node2D
var ui: CanvasLayer
var lower: Control
var views := {}  # uid -> GuiUnit
var _uid := 0

var round_no := 0
var action_order: Array = []
var current: Dictionary = {}
var phase := "busy"  # busy / player / over
var deck_controllers := {}
var special_used := {}

var hand_cards: Array = []
var sys_buttons := {}
var keypad := {}
var flick_target = null

var order_bar: GuiWidget
var hub: GuiWidget
var draw_pile_w: GuiWidget
var discard_w: GuiWidget
var log_label: Label
var turn_label: Label
var desc_panel: Panel
var desc_label: Label
var item_panel: Panel
var _desc_token := 0

## 自動テスト用：true なら味方の手番を自動で進める
var autoplay := false


func _ready() -> void:
	CurrentStatus.ensure_started()
	autoplay = OS.has_feature("autoplay") or OS.get_cmdline_user_args().has("--autoplay")
	add_child(GuiBackground.new("cave", Rect2(0, 0, 720, 660)))
	field = Node2D.new()
	add_child(field)
	ui = CanvasLayer.new()
	add_child(ui)
	_setup_units()
	_build_ui()
	FlickInput.reset()
	FlickInput.is_enabled = true
	FlickInput.active_rect = LOWER_RECT
	FlickInput.flick_changed.connect(_on_flick_changed)
	FlickInput.flick_executed.connect(_on_flick_executed)
	FlickInput.flick_canceled.connect(_on_flick_canceled)
	_battle_loop()


func _exit_tree() -> void:
	FlickInput.reset()


# ============================================================
# 1. 初期化
# ============================================================

func _new_uid() -> int:
	_uid += 1
	return _uid


func _setup_units() -> void:
	var allies: Array = CurrentStatus.allies
	allies[0]["grid_key"] = "D2"
	allies[1]["grid_key"] = "F2"
	for a in allies:
		a["uid"] = _new_uid()
		a["shield"] = 0
		a["status_effects"] = {}
		a["ap"] = 3
		a["facing"] = -1.0 if a.grid_key == "D2" else 1.0
		var dc := DeckController.new()
		add_child(dc)
		dc.setup_battle_deck(CurrentDeck.decks[a.id])
		deck_controllers[a.id] = dc
	special_used = {}

	var floor_no := maxi(0, CurrentStatus.current_floor)
	var area := CurrentStatus.current_area_id
	var ids: Array = []
	var keys: Array = []
	var normal: Array = AreaList.get_enemy_pool(area, "enemies")
	match CurrentStatus.battle_kind:
		"boss":
			ids = [AreaList.get_enemy_pool(area, "bosses").pick_random(), normal.pick_random()]
			keys = ["H2", "A2"]
		"elite":
			ids = [AreaList.get_enemy_pool(area, "elites").pick_random(), normal.pick_random()]
			keys = ["I2", "A2"]
		_:
			var count := 2
			if floor_no >= 2 and randf() < 0.6:
				count = 3
			for i in count:
				ids.append(normal.pick_random())
				keys.append(ENEMY_KEYS[i])
	var enemies: Array = []
	for i in ids.size():
		var e := EnemyList.make_enemy(ids[i], floor_no)
		e["grid_key"] = keys[i]
		e["uid"] = _new_uid()
		e["facing"] = 1.0 if ActionController.is_left(e) else -1.0
		_choose_intent(e)
		enemies.append(e)
	CurrentStatus.enemies = enemies

	for u in allies + enemies:
		var v := GuiUnit.new()
		v.position = POS[u.grid_key]
		field.add_child(v)
		v.setup(u, u.facing)
		views[u.uid] = v
		if u.hp <= 0:
			v.dead = true
			v.modulate.a = 0.35


func _choose_intent(e: Dictionary) -> void:
	var id: String = e.get("next_action", "")
	e["next_action"] = ""
	if id == "":
		id = e.actions.pick_random()
	e["intent_id"] = id
	e["intent"] = ActionList.ENEMY_ACTIONS[id]


func _build_ui() -> void:
	var col: Dictionary = ImageController.COL
	var low_bg := ColorRect.new()
	low_bg.color = Color("0e1222")
	low_bg.position = Vector2(0, 660)
	low_bg.size = Vector2(720, 620)
	low_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(low_bg)
	var line := ColorRect.new()
	line.color = Color(col.gold, 0.5)
	line.position = Vector2(0, 658)
	line.size = Vector2(720, 3)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(line)

	order_bar = GuiWidget.new("order", Rect2(10, 10, 700, 78))
	ui.add_child(order_bar)
	log_label = UiSystem.make_label(ui, "", Vector2(20, 598), Vector2(680, 54), 26, col.text)
	turn_label = UiSystem.make_label(ui, "", Vector2(24, 664), Vector2(672, 40), 24, col.gold, HORIZONTAL_ALIGNMENT_LEFT)

	lower = Control.new()
	lower.position = Vector2.ZERO
	lower.size = Vector2(720, 1280)
	lower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(lower)

	hub = GuiWidget.new("hub", Rect2(290, 895, 140, 140))
	lower.add_child(hub)
	draw_pile_w = GuiWidget.new("pile", Rect2(16, 902, 104, 132))
	draw_pile_w.caption = "山札"
	lower.add_child(draw_pile_w)
	discard_w = GuiWidget.new("pile", Rect2(600, 902, 104, 132))
	discard_w.caption = "捨札"
	lower.add_child(discard_w)

	for i in 4:
		var c := GuiCard.new()
		c.position = HAND_POS[i] - GuiCard.SIZE / 2
		c.label_hint = ARROW[HAND_KEYS[i]]
		c.visible = false
		lower.add_child(c)
		c.tapped.connect(_on_card_tapped.bind(i))
		c.hold_started.connect(_show_pad_desc.bind(c))
		c.hold_ended.connect(_hide_desc)
		hand_cards.append(c)
		keypad[HAND_KEYS[i]] = c

	for d in SYS_DEF:
		var b := GuiSysButton.new()
		b.setup(d[1], d[2], d[3], d[4], ARROW[d[5]])
		b.position = d[6] - b.size / 2
		b.set_meta("id", d[0])
		lower.add_child(b)
		b.tapped.connect(_on_sys.bind(d[0]))
		b.hold_started.connect(_show_pad_desc.bind(b))
		b.hold_ended.connect(_hide_desc)
		sys_buttons[d[0]] = b
		keypad[d[5]] = b

	desc_panel = UiSystem.make_panel(ui, Rect2(20, 452, 680, 196))
	desc_panel.visible = false
	desc_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_label = UiSystem.make_label(desc_panel, "", Vector2(18, 10), Vector2(644, 176), 22, col.text, HORIZONTAL_ALIGNMENT_LEFT, 0)
	desc_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	item_panel = UiSystem.make_panel(ui, Rect2(50, 300, 620, 600))
	item_panel.visible = false
	_refresh_all()


# ============================================================
# 2. 戦闘の進行
# ============================================================

func _battle_loop() -> void:
	await get_tree().create_timer(0.5).timeout
	var names: Array = []
	for e in CurrentStatus.enemies:
		names.append(e.name)
	_log("、".join(names) + " が現れた！")
	await get_tree().create_timer(0.6).timeout
	while true:
		round_no += 1
		action_order = (CurrentStatus.allies + CurrentStatus.enemies).filter(func(u): return u.hp > 0)
		action_order.sort_custom(func(a, b):
			if a.spd == b.spd:
				return a.side == "ally" and b.side != "ally"
			return a.spd > b.spd)
		order_bar.units = action_order
		for idx in action_order.size():
			var u: Dictionary = action_order[idx]
			if u.hp <= 0:
				continue
			order_bar.index = idx
			await _run_turn(u)
			if _check_end():
				return
		StatusController.decrease_all_durations(CurrentStatus.allies + CurrentStatus.enemies)
		_refresh_all()


func _run_turn(u: Dictionary) -> void:
	var v: GuiUnit = views[u.uid]
	u["shield"] = 0
	v.active = true
	var ticks := StatusController.trigger_start_of_turn(u)
	if not ticks.is_empty():
		_show_events(ticks)
		await get_tree().create_timer(0.55).timeout
		_update_deaths()
	if u.hp > 0 and not _all_dead(CurrentStatus.enemies) and not _all_dead(CurrentStatus.allies):
		if u.side == "ally":
			await _ally_turn(u)
		else:
			await _enemy_turn(u)
		var regen := StatusController.trigger_end_of_turn(u)
		if not regen.is_empty():
			_show_events(regen)
	v.active = false
	_refresh_all()


func _ally_turn(u: Dictionary) -> void:
	current = u
	u["ap"] = mini(int(u.max_ap), int(u.ap) + 1)
	var dc: DeckController = deck_controllers[u.id]
	dc.draw_cards(4)
	_log("%sの手番" % u.name)
	# 手札にある「常時」カード（フォースなど）を発動
	for card in dc.hand:
		if card != null and card.get("timing") == "start_turn":
			_show_events(ActionController.execute_action(u, card, CurrentStatus.allies, CurrentStatus.enemies))
			_log("%s の効果が発動！" % card.name)
	phase = "player"
	_refresh_all()
	if autoplay:
		_autoplay_turn.call_deferred()
	await turn_done
	if phase == "player":
		phase = "busy"
	_hide_desc()
	_clear_flick()
	dc.turn_end_and_discard()
	current = {}
	_refresh_all()


func _enemy_turn(e: Dictionary) -> void:
	current = e
	_refresh_all()
	var act: Dictionary = ActionList.ENEMY_ACTIONS[e.intent_id]
	_log("%sの %s！" % [e.name, act.name])
	await get_tree().create_timer(0.45).timeout
	await _perform(e, act)
	if e.hp > 0:
		_choose_intent(e)
	current = {}
	await get_tree().create_timer(0.2).timeout


## 行動の演出と実行（カード・敵の技・道具・必殺技すべてここを通る）
func _perform(user: Dictionary, action: Dictionary) -> void:
	var targets := ActionController.resolve_targets(user, action.get("target", "self"), CurrentStatus.allies, CurrentStatus.enemies)
	var v: GuiUnit = views[user.uid]
	var events: Array = []
	var do_hit := func():
		events.append_array(ActionController.execute_action(user, action, CurrentStatus.allies, CurrentStatus.enemies))
		_show_events(events, action)
	var single: bool = action.get("target", "") in ["front_enemy_single", "front_enemy_group"]
	if action.has("power") and single and not targets.is_empty():
		var tv: GuiUnit = views[targets[0].uid]
		v.facing = 1.0 if tv.position.x > v.position.x else -1.0
		AnimationController.lunge(v, tv.position, 80, do_hit)
		await get_tree().create_timer(0.55).timeout
		v.facing = user.facing
	elif action.has("power"):
		GuiFx.spawn(field, "glow", v.position + Vector2(0, -60), Color("ffb060"), 0.4)
		AnimationController.hop(v, 30, do_hit)
		await get_tree().create_timer(0.5).timeout
	else:
		AnimationController.hop(v, 14, do_hit)
		await get_tree().create_timer(0.42).timeout
	await get_tree().create_timer(0.12).timeout
	_update_deaths()
	_refresh_all()


func _show_events(events: Array, action: Dictionary = {}) -> void:
	var col: Dictionary = ImageController.COL
	for ev in events:
		var t: Dictionary = ev.target
		if not views.has(t.uid):
			continue
		var tv: GuiUnit = views[t.uid]
		var head := tv.position + Vector2(0, -tv.body_height() * 0.6)
		var y_off := 0.0
		if ev.has("damage"):
			if ev.has("tick"):
				var st: Dictionary = StatusEffectList.DATA.get(ev.tick, {})
				AnimationController.popup_text(field, head, "%s -%d" % [st.get("short", ""), ev.damage], Color("ffa060"))
				AnimationController.flash(tv, Color(1.6, 0.6, 0.3))
			else:
				var fx := "slash" if action.get("target", "") in ["front_enemy_single", "front_enemy_group"] else "burst"
				GuiFx.spawn(field, fx, head, Color("ffd0a0") if fx == "slash" else Color("ff9a3a"))
				if ev.damage > 0:
					AnimationController.popup_text(field, head, str(ev.damage), col.bad, 40)
					AnimationController.flash(tv, Color(2, 0.5, 0.5))
					AnimationController.shake(tv, 7)
				elif ev.get("blocked", 0) > 0:
					AnimationController.popup_text(field, head, "ブロック", col.shield, 28)
				else:
					AnimationController.popup_text(field, head, "0", Color.WHITE, 32)
			y_off -= 40
		if ev.has("heal"):
			AnimationController.popup_text(field, head + Vector2(0, y_off), "+%d" % ev.heal, col.good, 36)
			GuiFx.spawn(field, "rise", tv.position, col.good, 0.6)
			y_off -= 40
		if ev.has("shield"):
			AnimationController.popup_text(field, head + Vector2(0, y_off), "盾+%d" % ev.shield, col.shield, 28)
			AnimationController.flash(tv, Color(0.7, 1.2, 1.8))
			y_off -= 36
		if ev.has("status"):
			var st: Dictionary = StatusEffectList.DATA.get(ev.status, {})
			var good: bool = st.get("good", false)
			AnimationController.popup_text(field, head + Vector2(0, y_off), "%s %d" % [st.get("short", ""), ev.status_val],
					col.good if good else Color("d39bff"), 26)
			if good:
				GuiFx.spawn(field, "rise", tv.position, Color("8fe0ff"), 0.6)
			y_off -= 34
		if ev.has("ap"):
			AnimationController.popup_text(field, head + Vector2(0, y_off), "AP+%d" % ev.ap, col.ap, 30)
		if ev.has("charge"):
			AnimationController.popup_text(field, head, "力を溜めている…", col.gold, 24)


func _update_deaths() -> void:
	for u in CurrentStatus.allies + CurrentStatus.enemies:
		var v: GuiUnit = views[u.uid]
		if u.hp <= 0 and not v.dead:
			v.dead = true
			v.active = false
			_log("%sは倒れた！" % u.name)
			var tw := v.create_tween()
			tw.tween_property(v, "modulate", Color(1, 0.3, 0.3, 1), 0.1)
			tw.tween_property(v, "modulate", Color(1, 1, 1, 0.0 if u.side == "enemy" else 0.35), 0.5)
			GuiFx.spawn(field, "burst", v.position + Vector2(0, -50), Color("c070ff"), 0.5)


func _all_dead(arr: Array) -> bool:
	return arr.all(func(u): return u.hp <= 0)


func _check_end() -> bool:
	if phase == "over":
		return true
	if _all_dead(CurrentStatus.enemies):
		_finish("win")
		return true
	if _all_dead(CurrentStatus.allies):
		_finish("lose")
		return true
	return false


func _finish(result: String) -> void:
	phase = "over"
	FlickInput.is_enabled = false
	_clear_flick()
	_hide_desc()
	item_panel.visible = false
	for c in hand_cards:
		c.visible = false
	lower.modulate.a = 0.3
	if result == "win":
		_log("勝利！")
		for a in CurrentStatus.allies:
			if a.hp > 0:
				AnimationController.hop(views[a.uid], 40)
	else:
		_log("全滅してしまった…")
	await get_tree().create_timer(1.4).timeout
	CurrentStatus.last_result = result
	for a in CurrentStatus.allies:
		a["shield"] = 0
		a["status_effects"] = {}
	UiSystem.goto("result")


# ============================================================
# 3. プレイヤーの操作
# ============================================================

func _input_ok() -> bool:
	return phase == "player" and not item_panel.visible


func _on_card_tapped(i: int) -> void:
	if not _input_ok():
		return
	var dc: DeckController = deck_controllers[current.id]
	var card = dc.hand[i]
	if card == null:
		return
	if card.type == "unselectable":
		_log("このカードは使えない（手札にあると自動で発動）")
		AnimationController.shake(hand_cards[i])
		return
	if int(current.ap) < int(card.get("ap", 0)):
		_log("APが足りない！")
		AnimationController.shake(hand_cards[i])
		return
	phase = "busy"
	_hide_desc()
	_clear_flick()
	current["ap"] = int(current.ap) - int(card.get("ap", 0))
	_fly_card(hand_cards[i])
	hand_cards[i].visible = false
	_log("%sの %s！" % [current.name, card.name])
	await _perform(current, card)
	dc.play_and_discard(i)
	dc.draw_cards(1)
	_refresh_all()
	if dc.hand[i] != null and hand_cards[i].visible:
		hand_cards[i].scale = Vector2(0.6, 0.6)
		hand_cards[i].create_tween().tween_property(hand_cards[i], "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _all_dead(CurrentStatus.enemies) or current.hp <= 0:
		turn_done.emit()
		return
	phase = "player"
	_refresh_all()


func _on_sys(id: String) -> void:
	if not _input_ok():
		return
	_hide_desc()
	_clear_flick()
	match id:
		"swap": _do_swap()
		"special": _do_special()
		"item": _open_items()
		"end":
			phase = "busy"
			turn_done.emit()


func _do_swap() -> void:
	var a: Dictionary = CurrentStatus.allies[0]
	var b: Dictionary = CurrentStatus.allies[1]
	var tmp: String = a.grid_key
	a["grid_key"] = b.grid_key
	b["grid_key"] = tmp
	for u in [a, b]:
		u["facing"] = -float(u.facing)
		var v: GuiUnit = views[u.uid]
		v.facing = u.facing
		var tw := v.create_tween()
		tw.tween_property(v, "position", POS[u.grid_key] + Vector2(0, -30), 0.12)
		tw.tween_property(v, "position", POS[u.grid_key], 0.12)
	_log("位置を入れ替えた！")


func _do_special() -> void:
	if special_used.get(current.id, false):
		_log("必殺技はこの戦闘ではもう使った")
		AnimationController.shake(sys_buttons.special)
		return
	var sp: Dictionary = ActionList.SPECIALS[current.id]
	special_used[current.id] = true
	phase = "busy"
	_log("必殺！ %s！" % sp.name)
	GuiFx.spawn(field, "burst", views[current.uid].position + Vector2(0, -70), Color("ffd060"), 0.6)
	await get_tree().create_timer(0.3).timeout
	await _perform(current, sp)
	_after_free_action()


func _open_items() -> void:
	for c in item_panel.get_children():
		c.queue_free()
	UiSystem.make_label(item_panel, "道具", Vector2(0, 14), Vector2(620, 50), 32, ImageController.COL.gold)
	var y := 80.0
	if Inventory.items.is_empty():
		UiSystem.make_label(item_panel, "道具を持っていない", Vector2(0, 200), Vector2(620, 60), 26)
	for item_id in Inventory.items:
		var it: Dictionary = Item_List.DATA[item_id]
		var b := UiSystem.make_button(item_panel, "%s\n%s" % [it.name, it.desc], Vector2(30, y), Vector2(560, 96),
				_use_item.bind(item_id), 22)
		var ic := GuiWidget.new("icon", Rect2(14, 18, 60, 60))
		ic.icon_kind = it.art
		ic.icon_col = it.art_col
		b.add_child(ic)
		y += 108
		if y > 440:
			break
	UiSystem.make_button(item_panel, "閉じる", Vector2(210, 510), Vector2(200, 70), func(): item_panel.visible = false)
	item_panel.visible = true


func _use_item(item_id: String) -> void:
	item_panel.visible = false
	if phase != "player":
		return
	var it: Dictionary = Item_List.DATA[item_id]
	Inventory.remove_item(item_id)
	phase = "busy"
	_log("%sを使った！" % it.name)
	await _perform(current, it)
	_after_free_action()


func _after_free_action() -> void:
	_refresh_all()
	if _all_dead(CurrentStatus.enemies) or current.hp <= 0:
		turn_done.emit()
		return
	phase = "player"
	_refresh_all()


func _fly_card(src: GuiCard) -> void:
	var c := GuiCard.new()
	c.set_card(src.card)
	c.position = src.position
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lower.add_child(c)
	c.pivot_offset = c.size / 2
	var to := discard_w.position + discard_w.size / 2 - c.size / 2
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "position", src.position + Vector2(0, -60), 0.12)
	tw.chain().tween_property(c, "position", to, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(c, "rotation", 0.8, 0.3)
	tw.tween_property(c, "scale", Vector2(0.35, 0.35), 0.3)
	tw.chain().tween_callback(c.queue_free)


# --- フリック ---
func _on_flick_changed(num: int) -> void:
	_clear_flick()
	if not _input_ok():
		return
	var pad = keypad.get(num)
	if pad == null or not pad.visible:
		return
	pad.highlighted = true
	flick_target = pad
	hub.num = num
	_show_pad_desc(pad)


func _on_flick_executed(num: int) -> void:
	var pad = keypad.get(num)
	_clear_flick()
	if not _input_ok() or pad == null or not pad.visible:
		return
	if pad is GuiCard:
		_on_card_tapped(hand_cards.find(pad))
	else:
		_on_sys(pad.get_meta("id"))


func _on_flick_canceled() -> void:
	_clear_flick()


func _clear_flick() -> void:
	if flick_target != null and is_instance_valid(flick_target):
		flick_target.highlighted = false
		_hide_desc()
	flick_target = null
	if hub:
		hub.num = 5


# --- 説明パネル ---
func _show_pad_desc(pad) -> void:
	var txt := ""
	if pad is GuiCard:
		txt = DeckController.card_text(current, pad.card)
	else:
		var id: String = pad.get_meta("id")
		if id == "special" and not current.is_empty() and current.side == "ally":
			var sp: Dictionary = ActionList.SPECIALS[current.id]
			txt = "必殺技（1戦闘に1回・AP不要）\n" + DeckController.card_text(current, sp)
			if special_used.get(current.id, false):
				txt += "\n※この戦闘では使用済み"
		else:
			txt = pad.title + "\n" + pad.description
	_show_desc(txt)


func _show_desc(txt: String, auto_hide: float = 0.0) -> void:
	desc_label.text = txt
	desc_panel.visible = true
	_desc_token += 1
	if auto_hide > 0:
		var tok := _desc_token
		await get_tree().create_timer(auto_hide).timeout
		if tok == _desc_token:
			desc_panel.visible = false


func _hide_desc() -> void:
	if desc_panel:
		desc_panel.visible = false


## 戦場のキャラをタップすると詳細を表示
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.position.y > 600:
		return
	for u in CurrentStatus.allies + CurrentStatus.enemies:
		var v: GuiUnit = views[u.uid]
		if v.dead:
			continue
		var p: Vector2 = event.position - v.position
		if absf(p.x) < 55 * v.art_scale and p.y < 40 and p.y > -v.body_height():
			_show_desc(_unit_text(u), 2.5)
			return


func _unit_text(u: Dictionary) -> String:
	var lines: Array = []
	lines.append("%s　HP %d/%d　攻撃%+d　防御%d　素早さ%d" % [u.name, u.hp, u.max_hp, ActionController.get_atk(u), ActionController.get_def(u), u.spd])
	for k in u.status_effects.keys():
		var st: Dictionary = StatusEffectList.DATA.get(k, {})
		lines.append("・%s %d：%s" % [st.get("name", k), u.status_effects[k], st.get("desc", "")])
	if u.side == "enemy" and not u.intent.is_empty():
		lines.append("次の行動：" + u.intent.name)
	return "\n".join(lines)


# ============================================================
# 4. 表示の更新
# ============================================================

func _refresh_all() -> void:
	var is_player: bool = phase == "player" and not current.is_empty() and current.side == "ally"
	var dc: DeckController = deck_controllers.get(current.get("id", ""), null) if is_player else null
	for i in 4:
		var cv: GuiCard = hand_cards[i]
		var c = dc.hand[i] if dc != null else null
		if c == null:
			cv.visible = false
			continue
		cv.visible = true
		cv.set_card(c)
		cv.playable = c.type != "unselectable" and int(current.ap) >= int(c.get("ap", 0))
		cv.queue_redraw()
	if dc != null:
		draw_pile_w.count = dc.draw_pile.size()
		discard_w.count = dc.discard_pile.size()
	draw_pile_w.queue_redraw()
	discard_w.queue_redraw()
	if is_player:
		sys_buttons.special.dimmed = special_used.get(current.id, false)
		sys_buttons.item.dimmed = Inventory.items.is_empty()
		turn_label.text = "%sの手番　AP %d/%d" % [current.name, current.ap, current.max_ap]
		lower.modulate.a = 1.0
	elif phase != "over":
		turn_label.text = ("%sの行動" % current.name) if not current.is_empty() else ""
		lower.modulate.a = 0.55
	order_bar.queue_redraw()


func _log(txt: String) -> void:
	log_label.text = txt
	log_label.modulate.a = 0.3
	log_label.create_tween().tween_property(log_label, "modulate:a", 1.0, 0.15)


# ============================================================
# 5. 自動テスト用（--autoplay 指定時のみ）
# ============================================================

func _autoplay_turn() -> void:
	var guard := 0
	while phase != "over" and not current.is_empty() and current.side == "ally" and guard < 12:
		guard += 1
		await get_tree().create_timer(0.05).timeout
		if phase != "player":
			continue
		var dc: DeckController = deck_controllers[current.id]
		var played := false
		for i in 4:
			var c = dc.hand[i]
			if c != null and c.type != "unselectable" and int(current.ap) >= int(c.get("ap", 0)):
				await _on_card_tapped(i)
				played = true
				break
		if not played:
			break
	if phase == "player":
		_on_sys("end")
