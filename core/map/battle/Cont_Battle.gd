extends Node2D
## 戦闘シーン：進行・UI・入力（battle-spec.md）
##
## 画面（720×1280）
##   上   : 行動順バー／ログ／敵（前列 3・後列 3）
##   中   : 味方 2 人（前・後）
##   下   : 説明帯／3×3 のフリック操作エリア（左）＋右列キー（デッキ・ステータス・終了）
## 3×3（テンキー）: 7 入替 8 カード 9 保留 / 4 カード 5 必殺(長押し) 6 カード / 1 アイテム 2 カード 3 固有スキル

signal turn_done

const ENEMY_X := [[180.0, 400.0, 620.0], [80.0, 300.0, 520.0]]  # [row][col]。前後の列を左右にずらし、予告と HP バーが重ならないようにする
const ENEMY_ROW_Y := [440.0, 280.0]  # row 0 = 前列, row 1 = 後列
const ENEMY_SCALE := 0.78
const ENEMY_SLOTS := [[0, 1], [0, 0], [0, 2], [1, 1], [1, 0], [1, 2]]  # [row, col] を埋める順
const ALLY_POS := [Vector2(255, 588), Vector2(470, 612)]  # row 0 = 前, row 1 = 後
const VIEW_SCALE := 0.85

const PAD_RECT := Rect2(0, 706, 540, 574)
const CELL := {7: Vector2(90, 801), 8: Vector2(270, 801), 9: Vector2(450, 801),
		4: Vector2(90, 991), 5: Vector2(270, 991), 6: Vector2(450, 991),
		1: Vector2(90, 1181), 2: Vector2(270, 1181), 3: Vector2(450, 1181)}
const SLOT_NUM := [8, 4, 2, 6]  # 手札の枠 → テンキー
const DIR := {8: Vector2(0, -1), 2: Vector2(0, 1), 4: Vector2(-1, 0), 6: Vector2(1, 0),
		7: Vector2(-1, -1), 9: Vector2(1, -1), 1: Vector2(-1, 1), 3: Vector2(1, 1)}
const KEYS := {"deck": Rect2(548, 710, 164, 170), "status": Rect2(548, 890, 164, 170), "end": Rect2(548, 1070, 164, 200)}
const DEADZONE := 52.0
const CHARGE_DELAY := 0.12
const CHARGE_TIME := 0.9

var field: Node2D
var ui: CanvasLayer
var pad: Control
var strip: Control
var views := {}  # uid -> GuiUnit
var _uid := 0

var round_no := 0
var action_order: Array = []
var current: Dictionary = {}
var phase := "busy"  # setup / busy / player / over
var deck_controllers := {}
var specials := {}  # char_id -> 必殺技の辞書
var extra_turn := false
var first_turn := {}  # char_id -> まだ最初のターン前か

var hand_cards: Array = []  # GuiCard ×4
var hold_card: GuiCard
var btn := {}  # "swap" "hold" "item" "unique" "special" "deck" "status" "end" -> GuiSysButton
var order_bar: GuiWidget
var log_label: Label
var item_panel: Panel
var overlay: Control

# 説明帯
var strip_title := ""
var strip_text := ""
var strip_col := Color.WHITE

# ジェスチャー
var g_active := false
var g_start := Vector2.ZERO
var g_time := 0.0
var g_first := 5
var g_last_card := 5  # 押してから最初に弾いたカード方向（保留の対象。中央を通っても変わらない）
var g_cur := 5
var g_moved := false
var g_key := ""
var g_charge_preview := false

# 演出
var shake_amt := 0.0
var _hitstop_on := false
var _base_ts := 1.0

## 自動テスト用：true なら味方の手番を自動で進める
var autoplay := false


func _ready() -> void:
	CurrentStatus.ensure_started()
	autoplay = OS.get_cmdline_user_args().has("--autoplay") or get_tree().root.has_meta("autoplay")
	_base_ts = Engine.time_scale
	add_child(GuiBackground.new("cave", Rect2(0, 0, 720, 662)))
	field = Node2D.new()
	add_child(field)
	ui = CanvasLayer.new()
	add_child(ui)
	FlickInput.reset()
	_setup_units()
	_build_ui()
	_battle_loop()


func _exit_tree() -> void:
	Engine.time_scale = _base_ts


func _process(delta: float) -> void:
	if shake_amt > 0.1:
		field.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt
		shake_amt = lerpf(shake_amt, 0.0, minf(1.0, delta * 14.0))
	else:
		field.position = Vector2.ZERO
	if g_active and not g_moved and g_key == "" and _input_ok():
		g_time += delta / maxf(Engine.time_scale, 0.01)
		var c := clampf((g_time - CHARGE_DELAY) / CHARGE_TIME, 0.0, 1.0)
		btn.special.charge = c
		if c > 0 and not g_charge_preview:
			g_charge_preview = true
			_preview_action(5)


# ============================================================
# 1. 初期化
# ============================================================

func _new_uid() -> int:
	_uid += 1
	return _uid


func _setup_units() -> void:
	var allies: Array = CurrentStatus.allies
	allies[0]["row"] = 0
	allies[1]["row"] = 1
	var nb: Dictionary = CurrentStatus.next_battle
	for a in allies:
		a["col"] = 1
		a["uid"] = _new_uid()
		a["shield"] = int(nb.get("block", 0)) if a.hp > 0 else 0
		a["status_effects"] = {}
		if int(nb.get("atk", 0)) > 0:
			a.status_effects["atk_buff"] = int(nb.atk)
		a["ap"] = 0
		a["view_scale"] = VIEW_SCALE
		var dc := DeckController.new()
		add_child(dc)
		dc.setup_battle_deck(CurrentDeck.decks[a.id])
		deck_controllers[a.id] = dc
		first_turn[a.id] = true
		specials[a.id] = ActionList.special(a.id, CurrentStatus.special_choice.get(a.id, ""))

	var floor_no := maxi(0, CurrentStatus.current_floor)
	var area := CurrentStatus.current_area_id
	var kind := CurrentStatus.battle_kind
	var count := AreaList.enemy_count(floor_no, kind)
	var normal: Array = AreaList.get_enemy_pool(area, "enemies")
	var ids: Array = []
	var slots: Array = []
	var boss_id := ""
	if kind == "boss":
		boss_id = AreaList.get_enemy_pool(area, "bosses").pick_random()
	elif kind == "elite":
		boss_id = AreaList.get_enemy_pool(area, "elites").pick_random()
	var free: Array = ENEMY_SLOTS.duplicate()
	if boss_id != "":
		ids.append(boss_id)
		slots.append([1, 1])
		free.erase([1, 1])
	while ids.size() < count:
		ids.append(normal.pick_random())
		slots.append(free.pop_front())
	var enemies: Array = []
	for i in ids.size():
		var e := EnemyList.make_enemy(ids[i], floor_no)
		e["row"] = slots[i][0]
		e["col"] = slots[i][1]
		e["uid"] = _new_uid()
		e["view_scale"] = ENEMY_SCALE
		_choose_intent(e)
		enemies.append(e)
	CurrentStatus.enemies = enemies

	for u in allies + enemies:
		var v := GuiUnit.new()
		v.position = _unit_pos(u)
		v.z_index = int(v.position.y)
		field.add_child(v)
		v.setup(u, 1.0 if u.side == "ally" else (1.0 if v.position.x < 300 else -1.0))
		views[u.uid] = v
		if u.hp <= 0:
			v.dead = true
			v.modulate.a = 0.35
	_update_targets()


func _unit_pos(u: Dictionary) -> Vector2:
	if u.side == "ally":
		return ALLY_POS[int(u.row)]
	return Vector2(ENEMY_X[int(u.row)][int(u.col)], ENEMY_ROW_Y[int(u.row)])


func _choose_intent(e: Dictionary) -> void:
	var id: String = e.get("next_action", "")
	e["next_action"] = ""
	if id == "":
		id = e.actions.pick_random()
	e["intent_id"] = id
	e["intent"] = ActionList.ENEMY_ACTIONS[id]


## 敵の予告から、狙われている味方に印を付ける
func _update_targets() -> void:
	for a in CurrentStatus.allies:
		views[a.uid].targeted = 0
	for e in CurrentStatus.enemies:
		if e.hp <= 0 or e.intent.is_empty():
			continue
		var t: String = e.intent.get("target", "")
		if t in ["front_enemy_single", "enemy_all"]:
			for a in ActionController.resolve_targets(e, t, CurrentStatus.allies, CurrentStatus.enemies):
				views[a.uid].targeted += 1


func _build_ui() -> void:
	var col: Dictionary = ImageController.COL
	var low_bg := ColorRect.new()
	low_bg.color = Color("0e1222")
	low_bg.position = Vector2(0, 662)
	low_bg.size = Vector2(720, 618)
	low_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(low_bg)
	var line := ColorRect.new()
	line.color = Color(col.gold, 0.5)
	line.position = Vector2(0, 660)
	line.size = Vector2(720, 3)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(line)

	order_bar = GuiWidget.new("order", Rect2(8, 6, 704, 62))
	ui.add_child(order_bar)
	log_label = UiSystem.make_label(ui, "", Vector2(110, 70), Vector2(500, 38), 22, col.text)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.set_corner_radius_all(12)
	log_label.add_theme_stylebox_override("normal", sb)
	log_label.z_index = 5

	strip = Control.new()
	strip.position = Vector2(0, 664)
	strip.size = Vector2(720, 42)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.draw.connect(_draw_strip)
	ui.add_child(strip)

	pad = Control.new()
	pad.size = Vector2(720, 1280)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(pad)
	# 3×3 の区切り（薄い格子）
	var grid := Control.new()
	grid.size = Vector2(720, 1280)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.draw.connect(func():
		for k in CELL:
			var r := Rect2(CELL[k] - Vector2(86, 91), Vector2(172, 182))
			ImageController.round_rect(grid, r, Color(1, 1, 1, 0.03), 14))
	pad.add_child(grid)

	for i in 4:
		var c := GuiCard.new()
		c.interactive = false
		c.position = CELL[SLOT_NUM[i]] - GuiCard.SIZE / 2
		c.label_hint = str(SLOT_NUM[i])
		c.visible = false
		pad.add_child(c)
		hand_cards.append(c)

	_add_btn("swap", "入替", "swap", Color("8fc0ea"), 7, CELL[7])
	_add_btn("hold", "保留", "pin", Color("e8c26a"), 9, CELL[9])
	_add_btn("item", "アイテム", "potion", Color("6fd08a"), 1, CELL[1])
	_add_btn("unique", "固有", "star", Color("b88cff"), 3, CELL[3])
	_add_btn("special", "必殺", "burst", Color("ffb03a"), 5, CELL[5], Vector2(132, 132))
	btn.swap.ap_cost = 1
	btn.hold.subtitle = "AP 0"
	btn.item.subtitle = "AP 0"
	hold_card = GuiCard.new()
	hold_card.interactive = false
	hold_card.scale = Vector2(0.86, 0.86)
	hold_card.position = CELL[9] - GuiCard.SIZE * 0.43
	hold_card.pivot_offset = Vector2.ZERO
	hold_card.label_hint = "9"
	hold_card.visible = false
	pad.add_child(hold_card)

	var kb := [["deck", "デッキ・捨札", "cards", Color("5c8ad8")], ["status", "ステータス", "info", Color("8fc0ea")], ["end", "ターン終了", "enter", Color("e8c26a")]]
	for k in kb:
		var b := GuiSysButton.new()
		var r: Rect2 = KEYS[k[0]]
		b.setup(k[1], k[2], k[3], "", "", r.size, "key")
		b.position = r.position
		pad.add_child(b)
		btn[k[0]] = b

	item_panel = UiSystem.make_panel(ui, Rect2(50, 300, 620, 600))
	item_panel.visible = false
	_refresh_all()


func _add_btn(id: String, title: String, ik: String, acc: Color, num: int, center: Vector2, sz: Vector2 = Vector2(116, 116)) -> void:
	var b := GuiSysButton.new()
	b.setup(title, ik, acc, "", str(num), sz)
	b.position = center - sz / 2
	pad.add_child(b)
	btn[id] = b


func _draw_strip() -> void:
	var IC = ImageController
	IC.round_rect(strip, Rect2(8, 2, 704, 38), Color(1, 1, 1, 0.04), 10)
	var ap := int(current.get("ap", 0)) if current.get("side", "") == "ally" else 0
	if strip_text != "":
		IC.text(strip, strip_title + "　" + strip_text, Vector2(360, 21), 20, strip_col, true, 0, 690)
		return
	if current.get("side", "") == "ally":
		IC.text(strip, "%sの手番" % current.name, Vector2(110, 21), 22, IC.COL.gold, true)
		var n := maxi(ap, InitAllyStatus.AP_PER_TURN)
		for i in n:
			IC.icon(strip, "ap", Vector2(250 + i * 30, 21), 26, IC.COL.ap if i < ap else Color(0.3, 0.3, 0.4, 0.8))
		IC.text(strip, "AP %d" % ap, Vector2(250 + n * 30 + 26, 21), 18, IC.COL.text, true)
	elif not current.is_empty():
		IC.text(strip, "%sの行動" % current.name, Vector2(360, 21), 20, IC.COL.sub, true)


# ============================================================
# 2. 戦闘の進行
# ============================================================

func _battle_loop() -> void:
	await _choose_specials()
	var names: Array = []
	for e in CurrentStatus.enemies:
		names.append(e.name)
	_log("%s が現れた！" % "、".join(names) if names.size() <= 3 else "敵が %d 体現れた！" % names.size())
	await _wait(0.5)
	while true:
		round_no += 1
		action_order = (CurrentStatus.allies + CurrentStatus.enemies).filter(func(u): return u.hp > 0)
		action_order.sort_custom(func(a, b):
			var sa := ActionController.get_spd(a)
			var sb := ActionController.get_spd(b)
			if sa == sb:
				return a.side == "ally" and b.side != "ally"
			return sa > sb)
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


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _run_turn(u: Dictionary) -> void:
	var v: GuiUnit = views[u.uid]
	v.active = true
	var again := true
	while again and u.hp > 0:
		again = false
		if u.side == "enemy" or not first_turn.get(u.id, false):
			u["shield"] = 0
		var ticks := StatusController.trigger_start_of_turn(u)
		if not ticks.is_empty():
			_show_events(ticks, {}, Vector2.ZERO)
			await _wait(0.45)
			_update_deaths()
		if u.hp <= 0 or _all_dead(CurrentStatus.enemies) or _all_dead(CurrentStatus.allies):
			break
		if u.side == "ally":
			extra_turn = false
			await _ally_turn(u)
			if extra_turn and u.hp > 0 and not _all_dead(CurrentStatus.enemies):
				again = true
				_log("%sはもう一度行動する！" % u.name)
				await _wait(0.4)
		else:
			await _enemy_turn(u)
	v.active = false
	_refresh_all()


func _ally_turn(u: Dictionary) -> void:
	current = u
	u["ap"] = InitAllyStatus.AP_PER_TURN
	if first_turn.get(u.id, false):
		u["ap"] += int(CurrentStatus.next_battle.get("ap", 0))
		first_turn[u.id] = false
	var dc: DeckController = deck_controllers[u.id]
	dc.draw_cards(4)
	_log("%sの手番" % u.name)
	phase = "player"
	_refresh_all()
	for i in 4:
		if dc.hand[i] != null:
			_pop_in(hand_cards[i], i * 0.04)
	if autoplay:
		_autoplay_turn.call_deferred()
	await turn_done
	phase = "busy"
	_end_gesture()
	_close_item_panel()
	dc.turn_end_and_discard()
	_refresh_all()
	await _wait(0.25)


func _enemy_turn(e: Dictionary) -> void:
	current = e
	_refresh_all()
	var act: Dictionary = ActionList.ENEMY_ACTIONS[e.intent_id]
	_log("%sの %s！" % [e.name, act.name])
	await _wait(0.35)
	_perform(e, act, Vector2.ZERO)
	await _wait(0.5)
	if e.hp > 0:
		_choose_intent(e)
	_update_targets()
	current = {}


## 行動の実行（その場で結果を確定し、演出は流しっぱなし）
func _perform(user: Dictionary, action: Dictionary, fly_dir: Vector2) -> Array:
	var v: GuiUnit = views[user.uid]
	var events := ActionController.execute_action(user, action, CurrentStatus.allies, CurrentStatus.enemies)
	var single: bool = action.get("target", "") == "front_enemy_single"
	if action.has("power") and single and not events.is_empty():
		AnimationController.lunge(v, views[events[0].target.uid].position, 60)
	else:
		AnimationController.hop(v, 22 if action.has("power") else 12)
	_show_events(events, action, fly_dir)
	_update_deaths()
	_update_targets()
	_refresh_all()
	return events


func _show_events(events: Array, action: Dictionary, fly_dir: Vector2) -> void:
	var col: Dictionary = ImageController.COL
	var total := 0
	for ev in events:
		var t: Dictionary = ev.target
		if not views.has(t.uid):
			continue
		var tv: GuiUnit = views[t.uid]
		var head := tv.position + Vector2(0, -tv.body_height() * 0.6)
		var y_off := 0.0
		if ev.has("damage"):
			if ev.has("tick"):
				AnimationController.popup_text(field, head, "火傷 -%d" % ev.damage, Color("ffa060"))
				AnimationController.flash(tv, Color(1.6, 0.6, 0.3))
			else:
				var fx := "slash" if action.get("target", "") in ["front_enemy_single", "front_enemy_group"] else "burst"
				GuiFx.spawn(field, fx, head, Color("ffd0a0") if fx == "slash" else Color("ff9a3a"))
				if ev.damage > 0:
					AnimationController.popup_text(field, head, str(ev.damage), col.bad, 34 + mini(ev.damage, 30))
					AnimationController.flash(tv, Color(2, 0.5, 0.5))
					total += int(ev.damage)
				elif ev.get("blocked", 0) > 0:
					AnimationController.popup_text(field, head, "ブロック", col.shield, 28)
				else:
					AnimationController.popup_text(field, head, "0", Color.WHITE, 30)
			y_off -= 40
		if ev.has("heal"):
			AnimationController.popup_text(field, head + Vector2(0, y_off), "+%d" % ev.heal, col.good, 34)
			GuiFx.spawn(field, "rise", tv.position, col.good, 0.6)
		if ev.has("shield"):
			AnimationController.popup_text(field, head + Vector2(0, y_off), "盾+%d" % ev.shield, col.shield, 28)
			AnimationController.flash(tv, Color(0.7, 1.2, 1.8))
		if ev.has("status"):
			var st: Dictionary = StatusEffectList.DATA.get(ev.status, {})
			var good: bool = st.get("good", false)
			AnimationController.popup_text(field, head + Vector2(0, y_off), "%s %d" % [st.get("short", ""), ev.status_val],
					col.good if good else Color("ffa060"), 26)
			GuiFx.spawn(field, "rise", tv.position, Color("8fe0ff") if good else Color("ff8a3a"), 0.6)
		if ev.has("ap"):
			AnimationController.popup_text(field, head + Vector2(0, y_off), "AP+%d" % ev.ap, col.ap, 30)
		if ev.has("charge"):
			AnimationController.popup_text(field, head, "力を溜めている…", col.gold, 24)
	if total > 0:
		shake_amt = clampf(4.0 + total * 0.5, 4.0, 24.0)
		_hitstop(0.05 + minf(total, 40) * 0.0015)


## ヒットストップ：一瞬だけ時間を止める
func _hitstop(sec: float) -> void:
	if _hitstop_on:
		return
	_hitstop_on = true
	Engine.time_scale = _base_ts * 0.06
	await get_tree().create_timer(sec, true, false, true).timeout
	Engine.time_scale = _base_ts
	_hitstop_on = false


func _update_deaths() -> void:
	for u in CurrentStatus.allies + CurrentStatus.enemies:
		var v: GuiUnit = views[u.uid]
		if u.hp <= 0 and not v.dead:
			v.dead = true
			v.active = false
			v.preview = {}
			var tw := v.create_tween()
			tw.tween_property(v, "scale", Vector2(1.25, 0.7), 0.08)
			tw.tween_property(v, "modulate", Color(1, 1, 1, 0.0 if u.side == "enemy" else 0.35), 0.35)
			GuiFx.spawn(field, "burst", v.position + Vector2(0, -50), Color("c070ff"), 0.45)


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
	_end_gesture()
	_close_item_panel()
	for c in hand_cards:
		c.visible = false
	pad.modulate.a = 0.3
	current = {}
	strip_text = ""
	_log("勝利！" if result == "win" else "全滅してしまった…")
	if result == "win":
		for a in CurrentStatus.allies:
			if a.hp > 0:
				AnimationController.hop(views[a.uid], 40)
	await _wait(1.3)
	CurrentStatus.last_result = result
	CurrentStatus.next_battle = {}
	for a in CurrentStatus.allies:
		a["shield"] = 0
		a["status_effects"] = {}
	UiSystem.goto("result")


# ============================================================
# 3. 戦闘開始時の必殺技セット
# ============================================================

func _choose_specials() -> void:
	if autoplay:
		return
	phase = "setup"
	var col: Dictionary = ImageController.COL
	overlay = Control.new()
	overlay.size = Vector2(720, 1280)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 100
	ui.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.size = overlay.size
	overlay.add_child(dim)
	UiSystem.make_panel(overlay, Rect2(30, 300, 660, 640))
	UiSystem.make_label(overlay, "必殺技をセット", Vector2(30, 318), Vector2(660, 50), 32, col.gold)
	UiSystem.make_label(overlay, "中央を長押しして発動（AP 消費）", Vector2(30, 366), Vector2(660, 36), 20, col.sub)
	var y := 420.0
	var group_btns := {}
	for a in CurrentStatus.allies:
		UiSystem.make_label(overlay, a.name, Vector2(60, y), Vector2(600, 36), 24, col.text, HORIZONTAL_ALIGNMENT_LEFT)
		var x := 60.0
		group_btns[a.id] = []
		for sp in ActionList.SPECIALS[a.id]:
			var b := UiSystem.make_button(overlay, "%s（AP%d）\n%s" % [sp.name, sp.ap, _effect_label(sp) if not sp.has("power") else "%dダメージ" % sp.power],
					Vector2(x, y + 40), Vector2(290, 110), Callable(), 20)
			b.set_meta("sp", sp)
			group_btns[a.id].append(b)
			x += 310
		for b in group_btns[a.id]:
			b.pressed.connect(func():
				specials[a.id] = b.get_meta("sp")
				CurrentStatus.special_choice[a.id] = specials[a.id].id
				for o in group_btns[a.id]:
					o.modulate = Color.WHITE if o == b else Color(1, 1, 1, 0.4))
			b.modulate = Color.WHITE if b.get_meta("sp").id == specials[a.id].id else Color(1, 1, 1, 0.4)
		y += 170
	var go := UiSystem.make_button(overlay, "戦闘開始", Vector2(210, 820), Vector2(300, 84), Callable(), 30)
	await go.pressed
	overlay.queue_free()
	overlay = null
	phase = "busy"


# ============================================================
# 4. プレイヤーの操作（ジェスチャー）
# ============================================================

func _input_ok() -> bool:
	return phase == "player" and not item_panel.visible and overlay == null


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_press(event.position)
		else:
			_on_release(event.position)
	elif event is InputEventMouseMotion and g_active:
		_on_drag(event.position)


func _on_press(p: Vector2) -> void:
	if not _input_ok():
		return
	for k in KEYS:
		if KEYS[k].has_point(p):
			g_key = k
			btn[k].highlighted = true
			g_active = true
			return
	if not PAD_RECT.has_point(p):
		return
	g_active = true
	g_start = p
	g_time = 0.0
	g_first = 5
	g_last_card = 5
	g_cur = 5
	g_moved = false
	g_key = ""


func _on_drag(p: Vector2) -> void:
	if g_key != "" or not _input_ok():
		return
	var diff := p - g_start
	var n := 5
	if diff.length() > DEADZONE:
		n = FlickInput._get_num_from_angle(rad_to_deg(diff.angle()))
		if not g_moved:
			g_moved = true
			btn.special.charge = 0.0
			g_charge_preview = false
	if n == g_cur:
		return
	g_cur = n
	if n == 5:
		_clear_preview()
		return
	if g_first == 5:
		g_first = n
	if n in SLOT_NUM and g_last_card == 5:
		g_last_card = n
	_preview_action(_intent())


## 今のジェスチャーが指す操作：テンキー番号、または "hold:<枠>"
func _intent():
	if g_cur == 9 and g_last_card in SLOT_NUM:
		return "hold:%d" % SLOT_NUM.find(g_last_card)
	return g_cur


func _on_release(p: Vector2) -> void:
	if not g_active:
		return
	var key := g_key
	var moved := g_moved
	var intent = _intent()
	var charge: float = btn.special.charge
	var press_pos := g_start
	_end_gesture()
	if not _input_ok():
		return
	if key != "":
		if KEYS[key].has_point(p):
			_on_key(key)
		return
	if moved:
		if intent is int and intent == 5:
			return
		_execute(intent)
	elif charge >= 1.0:
		_execute(5)
	elif g_time < 0.35 or charge <= 0.0:
		_tap_info(press_pos)


func _end_gesture() -> void:
	g_active = false
	g_moved = false
	g_cur = 5
	g_first = 5
	g_last_card = 5
	g_charge_preview = false
	if g_key != "" and btn.has(g_key):
		btn[g_key].highlighted = false
	g_key = ""
	if btn.has("special"):
		btn.special.charge = 0.0
	_clear_preview()


## 軽くタップしたマスの説明を出す
func _tap_info(p: Vector2) -> void:
	var best := 5
	var bd := INF
	for k in CELL:
		var d: float = p.distance_to(CELL[k])
		if d < bd:
			bd = d
			best = k
	var info := _action_for(best)
	if info.is_empty():
		return
	strip_title = info.title
	strip_text = info.desc
	strip_col = ImageController.COL.text
	strip.queue_redraw()


## テンキー番号 → {"title", "desc", "action"(実行する行動), "ap", "kind"}
func _action_for(num) -> Dictionary:
	if current.get("side", "") != "ally":
		return {}
	var dc: DeckController = deck_controllers[current.id]
	if num is String and num.begins_with("hold:"):
		var slot := int(num.substr(5))
		var c = dc.hand[slot]
		if c == null:
			return {}
		var t := "%s を保留" % c.name
		if dc.hold != null:
			t += "（%s と入れ替え）" % dc.hold.name
		return {"title": "保留", "desc": t, "kind": "hold", "slot": slot, "ap": 0}
	match num:
		8, 4, 2, 6:
			var slot := SLOT_NUM.find(num)
			var c = dc.hand[slot]
			if c == null:
				return {}
			return {"title": c.name, "desc": _short(c), "action": c, "kind": "card", "slot": slot, "ap": int(c.get("ap", 0))}
		9:
			if dc.hold == null:
				return {"title": "保留", "desc": "カード方向へ弾き、離さず9へ滑らせると保留（AP0）", "kind": "none"}
			return {"title": dc.hold.name, "desc": "保留カードを使う　" + _short(dc.hold), "action": dc.hold, "kind": "hold_play", "ap": int(dc.hold.get("ap", 0))}
		7:
			return {"title": "入替", "desc": "前後の位置を入れ替える（AP1）。前にいる方が敵の単体攻撃を受ける", "action": ActionList.SWAP, "kind": "swap", "ap": 1}
		1:
			return {"title": "アイテム", "desc": "道具を使う（AP0）　所持 %d 個" % Inventory.items.size(), "kind": "item", "ap": 0}
		3:
			var s: Dictionary = ActionList.UNIQUE_SKILLS[current.id]
			return {"title": s.name, "desc": _short(s), "action": s, "kind": "unique", "ap": int(s.ap)}
		5:
			var s: Dictionary = specials[current.id]
			return {"title": "必殺", "desc": "%s　%s（長押しで発動）" % [s.name, _short(s)], "action": s, "kind": "special", "ap": int(s.ap)}
	return {}


func _short(a: Dictionary) -> String:
	var tgt := ""
	match a.get("target", ""):
		"enemy_all": tgt = "敵全体に"
		"front_enemy_single": tgt = "正面の敵に"
		"front_enemy_group": tgt = "目の前の敵全体に"
		"ally_all": tgt = "味方全体："
		"self": tgt = "自分："
	var s := "%s%s" % [tgt, DeckController.effect_text(current, a)]
	if a.has("ap"):
		s += "（AP%d）" % a.ap
	return s


func _preview_action(num) -> void:
	_clear_preview()
	var info := _action_for(num)
	if info.is_empty():
		return
	var lack := int(info.get("ap", 0)) > int(current.ap)
	log_label.visible = false  # プレビュー中はログを隠し、敵の上の予想表示を見やすくする
	strip_title = info.title
	strip_text = info.desc + ("　AP不足" if lack else "")
	strip_col = ImageController.COL.bad if lack else ImageController.COL.gold
	strip.queue_redraw()
	# 操作エリアのハイライト
	match info.kind:
		"card": hand_cards[info.slot].highlighted = true
		"hold":
			btn.hold.highlighted = true
			hand_cards[info.slot].highlighted = true
		"hold_play": hold_card.highlighted = true
		"swap": btn.swap.highlighted = true
		"item": btn.item.highlighted = true
		"unique": btn.unique.highlighted = true
	# 戦場のハイライトと予想ダメージ
	if info.has("action") and not lack:
		var act: Dictionary = info.action
		if info.kind == "swap":
			for a in CurrentStatus.allies:
				views[a.uid].preview = {"on": true, "label": "→後" if a.row == 0 else "→前"}
			return
		for ev in ActionController.preview(current, act, CurrentStatus.allies, CurrentStatus.enemies):
			var p := {"on": true}
			if ev.has("damage"):
				p["damage"] = ev.damage
				p["kill"] = ev.kill
			else:
				p["label"] = _effect_label(act)
			views[ev.target.uid].preview = p


func _effect_label(a: Dictionary) -> String:
	match a.get("effect", ""):
		"add_shield": return "盾+%d" % a.eff_val
		"add_ap": return "AP+%d" % a.eff_val
		"heal": return "回復%d" % a.eff_val
		"draw": return "%d枚引く" % a.eff_val
		"add_status":
			return "%s%d" % [StatusEffectList.DATA[a.status].short, a.eff_val]
		"turnabout": return "引き直し"
		"extra_turn": return "再行動"
	return ""


func _clear_preview() -> void:
	for v in views.values():
		v.preview = {}
	for c in hand_cards:
		c.highlighted = false
	if hold_card:
		hold_card.highlighted = false
	for k in ["swap", "hold", "item", "unique"]:
		if btn.has(k):
			btn[k].highlighted = false
	strip_text = ""
	if log_label:
		log_label.visible = true
	if strip:
		strip.queue_redraw()


## 操作の実行。結果はその場で確定し、続けて次の操作を受け付ける
func _execute(num) -> void:
	var info := _action_for(num)
	if info.is_empty() or info.kind == "none":
		return
	var ap := int(info.get("ap", 0))
	if ap > int(current.ap):
		_log("APが足りない！")
		AnimationController.shake(pad, 6)
		return
	var dc: DeckController = deck_controllers[current.id]
	var dir: Vector2 = DIR.get(num, Vector2.UP) if num is int else Vector2(1, -1)
	match info.kind:
		"card":
			current["ap"] = int(current.ap) - ap
			_fly_card(hand_cards[info.slot], dir)
			dc.play_and_discard(info.slot)
			_play(info.action, dir)
		"hold_play":
			current["ap"] = int(current.ap) - ap
			_fly_card(hold_card, dir)
			dc.play_hold()
			_play(info.action, dir)
		"hold":
			dc.put_on_hold(info.slot)
			_log("%sを保留した" % dc.hold.name)
			_pop_in(hold_card, 0.0)
			if dc.hand[info.slot] != null:
				_pop_in(hand_cards[info.slot], 0.05)
		"swap":
			current["ap"] = int(current.ap) - ap
			_do_swap()
		"item":
			_open_items()
		"unique":
			current["ap"] = int(current.ap) - ap
			_log("%s！" % info.action.name)
			_play(info.action, dir)
		"special":
			current["ap"] = int(current.ap) - ap
			_log("必殺！ %s！" % info.action.name)
			GuiFx.spawn(field, "burst", views[current.uid].position + Vector2(0, -70), Color("ffd060"), 0.6)
			shake_amt = 10.0
			_play(info.action, dir)
	_refresh_all()


## カード・スキル・必殺技の効果。表示側で扱う特殊効果もここで処理する
func _play(act: Dictionary, dir: Vector2) -> void:
	var dc: DeckController = deck_controllers[current.id]
	match act.get("effect", ""):
		"draw":
			_draw_more(dc, int(act.eff_val))
			AnimationController.hop(views[current.uid], 12)
		"turnabout":
			dc.discard_hand()
			_draw_more(dc, 4)
			StatusController.apply_status(current, "atk_buff", int(act.eff_val))
			_show_events([{"target": current, "status": "atk_buff", "status_val": int(act.eff_val)}], act, dir)
			AnimationController.hop(views[current.uid], 20)
		"extra_turn":
			extra_turn = true
			AnimationController.popup_text(field, views[current.uid].position + Vector2(0, -130), "もう一度！", ImageController.COL.gold, 32)
			GuiFx.spawn(field, "glow", views[current.uid].position + Vector2(0, -60), Color("ffd060"), 0.6)
		_:
			_perform(current, act, dir)
	if _all_dead(CurrentStatus.enemies) or current.hp <= 0:
		phase = "busy"
		turn_done.emit.call_deferred()


func _draw_more(dc: DeckController, n: int) -> void:
	for i in dc.draw_cards(n):
		_pop_in(hand_cards[i], i * 0.05)


func _do_swap() -> void:
	for a in CurrentStatus.allies:
		a["row"] = 1 - int(a.row)
		var v: GuiUnit = views[a.uid]
		var to := _unit_pos(a)
		var tw := v.create_tween()
		tw.tween_property(v, "position", (v.position + to) / 2 + Vector2(0, -36), 0.1)
		tw.tween_property(v, "position", to, 0.1)
		v.z_index = int(to.y)
	_update_targets()
	_log("位置を入れ替えた！")


func _on_key(k: String) -> void:
	match k:
		"end":
			phase = "busy"
			turn_done.emit()
		"deck":
			var secs := {}
			for a in CurrentStatus.allies:
				var dc: DeckController = deck_controllers[a.id]
				var hand: Array = dc.hand.filter(func(c): return c != null)
				secs[a.id] = [["手札", hand], ["保留", [dc.hold] if dc.hold != null else []],
						["山札（順不同）", _sorted(dc.draw_pile)], ["捨札", dc.discard_pile.duplicate()]]
			overlay = GuiDeckView.open(ui, "デッキ・捨札", Callable(), secs, current.get("id", "knight"))
			overlay.closed.connect(func(): overlay = null)
		"status":
			_open_status()


func _sorted(arr: Array) -> Array:
	var a := arr.duplicate()
	a.sort_custom(func(x, y): return x.name < y.name)
	return a


func _open_status() -> void:
	var col: Dictionary = ImageController.COL
	overlay = Control.new()
	overlay.size = Vector2(720, 1280)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 100
	ui.add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.size = overlay.size
	overlay.add_child(dim)
	UiSystem.make_panel(overlay, Rect2(20, 80, 680, 1100))
	UiSystem.make_label(overlay, "ステータス", Vector2(20, 96), Vector2(680, 50), 32, col.gold)
	var lines: Array = []
	for u in CurrentStatus.allies + CurrentStatus.enemies:
		if u.hp <= 0:
			continue
		var s := "%s%s　HP %d/%d　攻%+d　防%d　速%d" % [u.name, "（前）" if u.side == "ally" and u.row == 0 else ("（後）" if u.side == "ally" else ""),
				u.hp, u.max_hp, ActionController.get_atk(u), ActionController.get_def(u), ActionController.get_spd(u)]
		if int(u.get("shield", 0)) > 0:
			s += "　盾%d" % u.shield
		for k in u.status_effects:
			s += "　%s%d" % [StatusEffectList.DATA[k].short, u.status_effects[k]]
		if u.side == "enemy" and not u.intent.is_empty():
			s += "\n　　次：%s（%s）" % [u.intent.name, DeckController.effect_text(u, u.intent)]
		lines.append(s)
	var l := UiSystem.make_label(overlay, "\n".join(lines), Vector2(44, 156), Vector2(632, 900), 20, col.text, HORIZONTAL_ALIGNMENT_LEFT, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	UiSystem.make_button(overlay, "閉じる", Vector2(210, 1080), Vector2(300, 80), func():
		overlay.queue_free()
		overlay = null, 26)


func _open_items() -> void:
	for c in item_panel.get_children():
		c.queue_free()
	UiSystem.make_label(item_panel, "アイテム（AP 0）", Vector2(0, 14), Vector2(620, 50), 30, ImageController.COL.gold)
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
		y += 106
		if y > 440:
			break
	UiSystem.make_button(item_panel, "閉じる", Vector2(210, 510), Vector2(200, 70), _close_item_panel)
	item_panel.visible = true


func _close_item_panel() -> void:
	if item_panel:
		item_panel.visible = false


func _use_item(item_id: String) -> void:
	item_panel.visible = false
	if phase != "player":
		return
	var it: Dictionary = Item_List.DATA[item_id]
	Inventory.remove_item(item_id)
	_log("%sを使った！" % it.name)
	_play(it, Vector2.UP)
	_refresh_all()


func _fly_card(src: GuiCard, dir: Vector2) -> void:
	var c := GuiCard.new()
	c.interactive = false
	c.set_card(src.card)
	c.position = src.position
	c.scale = src.scale
	pad.add_child(c)
	c.pivot_offset = c.size / 2
	var d := dir.normalized()
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "position", src.position + d * 520 + Vector2(0, -240), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(c, "rotation", d.x * 1.4 + 0.3, 0.32)
	tw.tween_property(c, "modulate:a", 0.0, 0.32)
	tw.chain().tween_callback(c.queue_free)


func _pop_in(c: Control, delay: float) -> void:
	var base: Vector2 = c.scale if c != hold_card else Vector2(0.86, 0.86)
	c.scale = base * 0.5
	var tw := c.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(c, "scale", base, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ============================================================
# 5. 表示の更新
# ============================================================

func _refresh_all() -> void:
	var is_player: bool = phase == "player" and current.get("side", "") == "ally"
	var dc: DeckController = deck_controllers.get(current.get("id", ""), null) if is_player else null
	for i in 4:
		var cv: GuiCard = hand_cards[i]
		var c = dc.hand[i] if dc != null else null
		cv.visible = c != null
		if c != null:
			cv.set_card(c)
			cv.playable = int(current.ap) >= int(c.get("ap", 0))
			cv.queue_redraw()
	hold_card.visible = dc != null and dc.hold != null
	if hold_card.visible:
		hold_card.set_card(dc.hold)
		hold_card.playable = int(current.ap) >= int(dc.hold.get("ap", 0))
	if is_player:
		var u: Dictionary = ActionList.UNIQUE_SKILLS[current.id]
		btn.unique.title = u.name
		btn.unique.icon_kind = u.art
		btn.unique.ap_cost = int(u.ap)
		btn.unique.dimmed = int(current.ap) < int(u.ap)
		var sp: Dictionary = specials[current.id]
		btn.special.title = sp.name
		btn.special.icon_kind = sp.art
		btn.special.ap_cost = int(sp.ap)
		btn.special.subtitle = "長押し"
		btn.special.dimmed = int(current.ap) < int(sp.ap)
		btn.swap.dimmed = int(current.ap) < 1
		btn.item.dimmed = Inventory.items.is_empty()
		btn.hold.dimmed = false
		pad.modulate.a = 1.0
	elif phase != "over":
		pad.modulate.a = 0.5
	for b in btn.values():
		b.queue_redraw()
	order_bar.queue_redraw()
	strip.queue_redraw()


func _log(txt: String) -> void:
	log_label.text = txt
	log_label.modulate.a = 0.3
	log_label.create_tween().tween_property(log_label, "modulate:a", 1.0, 0.15)


# ============================================================
# 6. 自動テスト用（--autoplay 指定時のみ）
# ============================================================

func _autoplay_turn() -> void:
	var guard := 0
	while phase == "player" and guard < 14:
		guard += 1
		await _wait(0.08)
		if phase != "player":
			return
		var dc: DeckController = deck_controllers[current.id]
		var done := false
		var sp: Dictionary = specials[current.id]
		if int(current.ap) >= int(sp.ap) and sp.get("effect", "") != "extra_turn" and guard == 1:
			_execute(5)
			continue
		if guard == 2 and dc.hand[0] != null and randf() < 0.5:
			_execute("hold:0")
			continue
		if guard == 3 and int(current.ap) >= 1 and randf() < 0.3:
			_execute(3)
			continue
		for i in 4:
			var c = dc.hand[i]
			if c != null and int(current.ap) >= int(c.get("ap", 0)):
				_execute(SLOT_NUM[i])
				done = true
				break
		if not done and dc.hold != null and int(current.ap) >= int(dc.hold.get("ap", 0)):
			_execute(9)
			done = true
		if not done:
			break
	if phase == "player":
		_on_key("end")
