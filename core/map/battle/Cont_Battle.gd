extends Node2D
## 戦闘シーン：進行・UI・入力（battle-spec.md）
##
## 画面（720×1280）
##   上   : 行動順バー／ログ／敵（最大 6 体。2 段に並ぶが前後の概念はない）
##   中   : 味方 2 人（左＝青ターゲット／右＝赤ターゲット）
##   下   : 説明帯／操作エリア 3 行×4 列（左 3 列がテンキー、右列がデッキ・ステータス・終了）
## 操作 : 指を置いたマスを起点に 8 方向へ弾くと、隣のマスの操作を実行する（5 を起点にすればテンキーどおり）
##        例）3（固有スキル）を起点に 上＝6（カード）、左＝2（カード）、右＝ターン終了

signal turn_done

const ENEMY_X := [[180.0, 400.0, 620.0], [80.0, 300.0, 520.0]]  # [段][列]。上下の段を左右にずらし、予告と HP バーが重ならないようにする
const ENEMY_ROW_Y := [440.0, 280.0]
const ENEMY_SCALE := 0.78
const ENEMY_SLOTS := [[0, 1], [0, 0], [0, 2], [1, 1], [1, 0], [1, 2]]  # [段, 列] を埋める順
const ALLY_POS := [Vector2(230, 604), Vector2(490, 604)]  # lane 0 = 左（青）, lane 1 = 右（赤）
const VIEW_SCALE := 0.85

## 操作エリアのマス（3 行×4 列）。番号はテンキー、右列は "deck" / "status" / "end"
const GRID := [[7, 8, 9, "deck"], [4, 5, 6, "status"], [1, 2, 3, "end"]]
const GRID_ORIGIN := Vector2(0, 706)
const GRID_CELL := Vector2(180, 190)
const SLOT_NUM := [8, 4, 2, 6]  # 手札の枠 → テンキー
const DIR8 := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
const DEADZONE := 48.0
const CHARGE_DELAY := 0.12
const CHARGE_TIME := 0.9

var field: Node2D
var ui: CanvasLayer
var fx: BattleFx
var pad: Control
var strip: Control
var views := {}  # uid -> GuiUnit
var _uid := 0

var round_no := 0
var action_order: Array = []
var current: Dictionary = {}
var phase := "busy"  # busy / player / over
var deck_controllers := {}
var specials := {}  # char_id -> 必殺技の辞書
var extra_turn := false
var first_turn := {}

var hand_cards: Array = []  # GuiCard ×4
var hold_card: GuiCard
var btn := {}  # swap hold item unique special deck status end -> GuiSysButton
var order_bar: GuiWidget
var log_label: Label
var item_panel: Panel
var overlay: Control
var info_panel: Control  # キャラをタップした時の情報

# 説明帯
var strip_title := ""
var strip_text := ""
var strip_col := Color.WHITE

# ジェスチャー
var g_active := false
var g_start := Vector2.ZERO
var g_origin := Vector2i(1, 1)  # 指を置いたマス（列, 行）
var g_time := 0.0
var g_cur = null  # 今の指先が指すマスの中身（番号 / キー名 / null）
var g_first_card := 0  # 最初に弾いたカードの番号（保留の対象）。0 = まだ
var g_moved := false
var g_cut_in := false

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
	fx = BattleFx.new()
	field.add_child(fx)
	fx.setup(self, field, ui)
	fx.set_lanes(ALLY_POS[0], ALLY_POS[1])
	FlickInput.reset()
	_setup_units()
	_build_ui()
	_battle_loop()


var _base_ts := 1.0


func _exit_tree() -> void:
	Engine.time_scale = _base_ts  # ヒットストップ中に画面を離れても時間の流れを戻す


func _process(delta: float) -> void:
	if g_active and not g_moved and _cell_value(g_origin) is int and _cell_value(g_origin) == 5 and _input_ok():
		g_time += delta / maxf(Engine.time_scale, 0.01)
		var c := clampf((g_time - CHARGE_DELAY) / CHARGE_TIME, 0.0, 1.0)
		btn.special.charge = c
		if c > 0 and g_cur == null:
			g_cur = 5
			_preview_action(5)
		if c >= 1.0 and not g_cut_in:
			g_cut_in = true
			fx.cut_in(current.id, specials[current.id].name)


# ============================================================
# 1. 初期化
# ============================================================

func _new_uid() -> int:
	_uid += 1
	return _uid


func _setup_units() -> void:
	var allies: Array = CurrentStatus.allies
	var nb: Dictionary = CurrentStatus.next_battle
	for i in allies.size():
		var a: Dictionary = allies[i]
		a["lane"] = i
		a["pos"] = ALLY_POS[i]
		a["uid"] = _new_uid()
		a["shield"] = int(nb.get("block", 0)) if a.hp > 0 else 0
		a["status_effects"] = {}
		if int(nb.get("atk", 0)) > 0:
			a.status_effects["atk_buff"] = int(nb.atk)
		a["ap"] = 0
		a["max_ap"] = InitAllyStatus.AP_MAX
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
		e["pos"] = Vector2(ENEMY_X[slots[i][0]][slots[i][1]], ENEMY_ROW_Y[slots[i][0]])
		e["uid"] = _new_uid()
		e["view_scale"] = ENEMY_SCALE
		enemies.append(e)
	CurrentStatus.enemies = enemies
	for e in enemies:
		_choose_intent(e)

	for u in allies + enemies:
		var v := GuiUnit.new()
		v.position = u.pos
		v.z_index = 10 + int(v.position.y)
		field.add_child(v)
		v.setup(u, _facing(u))
		views[u.uid] = v
		if u.hp <= 0:
			v.dead = true
			v.modulate.a = 0.35
	_update_targets()


func _facing(u: Dictionary) -> float:
	if u.side == "ally":
		return 1.0 if int(u.lane) == 0 else -1.0
	return 1.0 if Vector2(u.pos).x < 360 else -1.0


## 敵の次の行動を決める。単体攻撃なら狙う側（左／右）も決める
func _choose_intent(e: Dictionary) -> void:
	var id: String = e.get("next_action", "")
	e["next_action"] = ""
	if id == "":
		id = e.actions.pick_random()
	var act: Dictionary = ActionList.ENEMY_ACTIONS[id]
	e["intent_id"] = id
	e["intent"] = act
	e["move_to"] = null
	if act.get("move", false):
		var dest = _flank_dest(e)
		if dest != null:
			e["move_to"] = dest
			e["target_lane"] = 0 if dest.x < 360 else 1
			return
		# 移動先が空いていなければ、その場で攻撃する
	e["target_lane"] = randi() % 2


## 回り込み先：左右反対側の同じ段の位置（他の敵がいなければ）
func _flank_dest(e: Dictionary):
	var p: Vector2 = e.pos
	var row := 0 if p.y > 360 else 1
	var best = null
	for x in ENEMY_X[row]:
		var cand := Vector2(x, ENEMY_ROW_Y[row])
		if (cand.x < 360) == (p.x < 360):
			continue
		var taken := false
		for o in CurrentStatus.enemies:
			if o != e and o.hp > 0 and Vector2(o.pos).distance_to(cand) < 10:
				taken = true
		if not taken and (best == null or absf(cand.x - (720 - p.x)) < absf(best.x - (720 - p.x))):
			best = cand
	return best


## 予告の矢印と、狙われている味方の印を更新する
func _update_targets() -> void:
	var list: Array = []
	for a in CurrentStatus.allies:
		views[a.uid].targeted = 0
	for e in CurrentStatus.enemies:
		if e.hp <= 0 or e.intent.is_empty():
			continue
		var t: String = e.intent.get("target", "")
		var lanes: Array = []
		if t == "front_enemy_single":
			lanes = [int(e.target_lane)]
		elif t == "enemy_all":
			lanes = [0, 1]
		if lanes.is_empty():
			continue
		var from: Vector2 = e.pos if e.move_to == null else e.move_to
		list.append({"from": from, "lanes": lanes, "move_to": e.move_to})
		for a in ActionController.resolve_targets(e, t, CurrentStatus.allies, CurrentStatus.enemies):
			views[a.uid].targeted += 1
	fx.set_intents(list)


func _cell_center(c: Vector2i) -> Vector2:
	return GRID_ORIGIN + Vector2(c.x + 0.5, c.y + 0.5) * GRID_CELL


func _cell_value(c: Vector2i):
	if c.y < 0 or c.y >= GRID.size() or c.x < 0 or c.x >= 4:
		return null
	return GRID[c.y][c.x]


func _cell_of(value) -> Vector2i:
	for r in GRID.size():
		for col in 4:
			if typeof(GRID[r][col]) == typeof(value) and GRID[r][col] == value:
				return Vector2i(col, r)
	return Vector2i(-1, -1)


func _build_ui() -> void:
	var col: Dictionary = ImageController.COL
	# 下半分の操作エリア：黒地に薄い斜線、上端に赤と白の線
	var low_bg := Control.new()
	low_bg.position = Vector2(0, 662)
	low_bg.size = Vector2(720, 618)
	low_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	low_bg.draw.connect(func():
		var IC = ImageController
		low_bg.draw_rect(Rect2(Vector2.ZERO, low_bg.size), col.ink)
		IC.stripes(low_bg, Rect2(Vector2.ZERO, low_bg.size), Color(1, 1, 1, 0.022), 24, 2, 0.6)
		IC.halftone(low_bg, Rect2(Vector2(420, 380), Vector2(300, 238)), Color(col.red, 0.08), low_bg.size, 320, 18, 5))
	ui.add_child(low_bg)
	var line := Control.new()
	line.position = Vector2(0, 652)
	line.size = Vector2(720, 14)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.draw.connect(func():
		line.draw_rect(Rect2(0, 7, 720, 4), col.red)
		line.draw_rect(Rect2(0, 12, 720, 1), Color(1, 1, 1, 0.5))
		line.draw_colored_polygon(ImageController.slant_pts(Rect2(470, 0, 260, 11), 10), col.red))
	ui.add_child(line)

	order_bar = GuiWidget.new("order", Rect2(8, 6, 704, 62))
	ui.add_child(order_bar)
	log_label = UiSystem.make_label(ui, "", Vector2(110, 72), Vector2(500, 38), 22, col.text, HORIZONTAL_ALIGNMENT_CENTER, 4)
	log_label.add_theme_font_override("font", ImageController.font_bold)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col.ink, 0.88)
	sb.skew = Vector2(0.4, 0)
	sb.border_color = col.red
	sb.border_width_left = 8
	sb.border_width_right = 2
	sb.anti_aliasing = true
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
	var grid := Control.new()
	grid.size = Vector2(720, 1280)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.draw.connect(func():
		# 3×3 のマス：うっすら面を敷き、四隅に L 字の印（照準のような枠）
		for r in 3:
			for c in 3:
				var rr := Rect2(_cell_center(Vector2i(c, r)) - Vector2(86, 91), Vector2(172, 182))
				grid.draw_rect(rr, Color(1, 1, 1, 0.025))
				var k := 16.0
				var lc := Color(1, 1, 1, 0.22)
				for corner in [[rr.position, Vector2(1, 1)], [Vector2(rr.end.x, rr.position.y), Vector2(-1, 1)],
						[rr.end, Vector2(-1, -1)], [Vector2(rr.position.x, rr.end.y), Vector2(1, -1)]]:
					var p0: Vector2 = corner[0]
					var d: Vector2 = corner[1]
					grid.draw_line(p0, p0 + Vector2(d.x * k, 0), lc, 2)
					grid.draw_line(p0, p0 + Vector2(0, d.y * k), lc, 2))
	pad.add_child(grid)

	for i in 4:
		var c := GuiCard.new()
		c.interactive = false
		c.position = _cell_center(_cell_of(SLOT_NUM[i])) - GuiCard.SIZE / 2
		c.label_hint = str(SLOT_NUM[i])
		c.visible = false
		pad.add_child(c)
		hand_cards.append(c)

	_add_btn("swap", "入替", "swap", Color("8fc0ea"), 7)
	_add_btn("hold", "保留", "pin", Color("e8c26a"), 9)
	_add_btn("item", "アイテム", "potion", Color("6fd08a"), 1)
	_add_btn("unique", "固有", "star", Color("b88cff"), 3)
	_add_btn("special", "必殺", "burst", Color("ffb03a"), 5, Vector2(132, 132))
	btn.swap.ap_cost = 1
	btn.hold.subtitle = "AP 0"
	btn.item.subtitle = "AP 0"
	hold_card = GuiCard.new()
	hold_card.interactive = false
	hold_card.base_scale = 0.86
	hold_card.scale = Vector2(0.86, 0.86)
	hold_card.position = _cell_center(_cell_of(9)) - GuiCard.SIZE / 2
	hold_card.label_hint = "9"
	hold_card.visible = false
	pad.add_child(hold_card)

	var kb := [["deck", "デッキ・捨札", "cards", Color("8fb4ff")], ["status", "ステータス", "info", Color("8fc0ea")], ["end", "ターン終了", "enter", col.red]]
	for k in kb:
		var b := GuiSysButton.new()
		var c := _cell_center(_cell_of(k[0]))
		var sz := Vector2(164, 176)
		b.setup(k[1], k[2], k[3], "", "", sz, "key")
		b.position = c - sz / 2
		pad.add_child(b)
		btn[k[0]] = b

	item_panel = UiSystem.make_panel(ui, Rect2(50, 300, 620, 600))
	item_panel.visible = false
	_refresh_all()


func _add_btn(id: String, title: String, ik: String, acc: Color, num: int, sz: Vector2 = Vector2(116, 116)) -> void:
	var b := GuiSysButton.new()
	b.setup(title, ik, acc, "", str(num), sz)
	b.position = _cell_center(_cell_of(num)) - sz / 2
	pad.add_child(b)
	btn[id] = b


func _draw_strip() -> void:
	var IC = ImageController
	strip.draw_rect(Rect2(0, 0, 720, 42), Color(IC.COL.ink, 0.0))
	var ap := int(current.get("ap", 0)) if current.get("side", "") == "ally" else 0
	if strip_text != "":
		IC.slant(strip, Rect2(8, 4, 704, 36), Color(1, 1, 1, 0.06), 14)
		IC.text(strip, strip_title + "　" + strip_text, Vector2(360, 22), 20, strip_col, true, 0, 680)
		return
	if current.get("side", "") == "ally":
		# 左に赤い斜めタグで「〇〇の手番」、右に AP の菱形
		var tag := Rect2(4, 3, 196, 38)
		IC.slant(strip, tag, IC.COL.red, 14, 2.0, IC.COL.ink, IC.COL.ink, Vector2(4, 4))
		IC.head(strip, "%sの手番" % current.name, tag.get_center(), 22, IC.COL.paper, 168)
		for i in InitAllyStatus.AP_MAX:
			IC.icon(strip, "ap", Vector2(228 + i * 30, 22), 24, IC.COL.ap if i < ap else Color(1, 1, 1, 0.14))
		var apr := Rect2(548, 5, 116, 34)
		IC.slant(strip, apr, IC.COL.paper, 12)
		IC.head(strip, "AP %d" % ap, apr.get_center(), 22, IC.COL.ink, 96)
	elif not current.is_empty():
		IC.slant(strip, Rect2(160, 4, 400, 36), Color(1, 1, 1, 0.06), 14)
		IC.head(strip, "%sの行動" % current.name, Vector2(360, 22), 21, IC.COL.sub, 380)


# ============================================================
# 2. 戦闘の進行
# ============================================================

func _battle_loop() -> void:
	var names: Array = []
	for e in CurrentStatus.enemies:
		names.append(e.name)
	_log("%s が現れた！" % "、".join(names) if names.size() <= 3 else "敵が %d 体現れた！" % names.size())
	await _wait(0.6)
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
			for t in ticks:
				fx.hit(views[t.target.uid], int(t.damage), 0, "tick")
			await _wait(0.45)
			_update_deaths({})
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
	var gain := InitAllyStatus.AP_PER_TURN
	if first_turn.get(u.id, false):
		gain += int(CurrentStatus.next_battle.get("ap", 0))
		first_turn[u.id] = false
	u["ap"] = mini(InitAllyStatus.AP_MAX, int(u.ap) + gain)
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
	_close_panels()
	dc.turn_end_and_discard()
	_refresh_all()
	await _wait(0.25)


func _enemy_turn(e: Dictionary) -> void:
	current = e
	_refresh_all()
	var act: Dictionary = ActionList.ENEMY_ACTIONS[e.intent_id]
	_log("%sの %s！" % [e.name, act.name])
	await _wait(0.3)
	var v: GuiUnit = views[e.uid]
	var move_to = e.get("move_to")
	if move_to != null:
		e["pos"] = move_to
		v.facing = _facing(e)
		v.z_index = 10 + int(Vector2(move_to).y)
	var dur := 0.4
	var hit_cb := func(): _apply(e, act)
	if act.has("power") or act.get("target", "") in ["front_enemy_single", "enemy_all"]:
		var targets := ActionController.resolve_targets(e, act.target, CurrentStatus.allies, CurrentStatus.enemies)
		var tp: Vector2 = ALLY_POS[int(e.target_lane)] if act.target == "front_enemy_single" else (ALLY_POS[0] + ALLY_POS[1]) / 2
		if act.target == "front_enemy_single" and not targets.is_empty():
			tp = targets[0].pos
		dur = fx.enemy_attack(v, tp, hit_cb, move_to)
	else:
		dur = fx.cast(v, hit_cb)
	await _wait(dur + 0.25)
	if e.hp > 0:
		_choose_intent(e)
	_update_targets()
	current = {}


## 行動の効果をその場で確定し、演出を流す
func _apply(user: Dictionary, action: Dictionary) -> void:
	var events := ActionController.execute_action(user, action, CurrentStatus.allies, CurrentStatus.enemies)
	_show_events(events, action)
	_update_deaths(user)
	_update_targets()
	_refresh_all()


## カード・スキルの実行：演出（踏み込み等）の当たりの瞬間に効果を確定する。結果はその場で入力へ戻る
func _perform(user: Dictionary, action: Dictionary) -> void:
	var v: GuiUnit = views[user.uid]
	if action.has("power") and action.get("target", "") == "front_enemy_single":
		var t := ActionController.resolve_targets(user, action.target, CurrentStatus.allies, CurrentStatus.enemies)
		if not t.is_empty():
			# 結果は先に確定（入力の先行受付のため）、演出は後追い
			var events := ActionController.execute_action(user, action, CurrentStatus.allies, CurrentStatus.enemies)
			fx.ally_attack(v, t[0].pos, func():
				_show_events(events, action)
				_update_deaths(user))
			_update_targets()
			_refresh_all()
			return
	var events2 := ActionController.execute_action(user, action, CurrentStatus.allies, CurrentStatus.enemies)
	fx.cast(v, func():
		_show_events(events2, action)
		_update_deaths(user))
	_update_targets()
	_refresh_all()


func _show_events(events: Array, action: Dictionary) -> void:
	var col: Dictionary = ImageController.COL
	for ev in events:
		var t: Dictionary = ev.target
		if not views.has(t.uid):
			continue
		var tv: GuiUnit = views[t.uid]
		if ev.has("damage"):
			var kind := "slash" if action.get("target", "") in ["front_enemy_single", "front_enemy_group"] else "burst"
			fx.hit(tv, int(ev.damage), int(ev.get("blocked", 0)), kind)
		if ev.has("heal"):
			fx.popup(tv, "+%d" % ev.heal, col.good, 34)
		if ev.has("shield"):
			fx.popup(tv, "盾+%d" % ev.shield, col.shield, 28)
		if ev.has("status"):
			var st: Dictionary = StatusEffectList.DATA.get(ev.status, {})
			fx.popup(tv, "%s %d" % [st.get("short", ""), ev.status_val], col.good if st.get("good", false) else Color("ffa060"), 26)
		if ev.has("ap"):
			fx.popup(tv, "AP+%d" % ev.ap, col.ap, 30)
		if ev.has("charge"):
			fx.popup(tv, "力を溜めている…", col.accent, 24)


func _update_deaths(attacker: Dictionary) -> void:
	for u in CurrentStatus.allies + CurrentStatus.enemies:
		var v: GuiUnit = views[u.uid]
		if u.hp <= 0 and not v.dead:
			v.dead = true
			v.active = false
			v.preview = {}
			if u.side == "enemy":
				var from: Vector2 = attacker.get("pos", Vector2(360, 700)) if not attacker.is_empty() else Vector2(360, 700)
				fx.knockout(v, from)
			else:
				v.create_tween().tween_property(v, "modulate", Color(1, 1, 1, 0.35), 0.4)
	_update_targets()


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
	_close_panels()
	for c in hand_cards:
		c.visible = false
	pad.modulate.a = 0.3
	current = {}
	strip_text = ""
	_log("勝利！" if result == "win" else "全滅してしまった…")
	await _wait(1.4)
	CurrentStatus.last_result = result
	CurrentStatus.next_battle = {}
	for a in CurrentStatus.allies:
		a["shield"] = 0
		a["status_effects"] = {}
	UiSystem.goto("result")


# ============================================================
# 3. プレイヤーの操作（ジェスチャー）
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
	if info_panel != null:
		_close_info()
		return
	if not _input_ok():
		return
	if p.y < 650:
		_tap_field(p)
		return
	if p.y < GRID_ORIGIN.y:
		return
	g_active = true
	g_start = p
	g_origin = Vector2i(clampi(int(p.x / GRID_CELL.x), 0, 3), clampi(int((p.y - GRID_ORIGIN.y) / GRID_CELL.y), 0, 2))
	g_time = 0.0
	g_cur = null
	g_first_card = 0
	g_moved = false
	g_cut_in = false
	var k = _cell_value(g_origin)
	if k is String:
		btn[k].highlighted = true


func _on_drag(p: Vector2) -> void:
	if not _input_ok():
		return
	var diff := p - g_start
	var target = null
	if diff.length() > DEADZONE:
		if not g_moved:
			g_moved = true
			btn.special.charge = 0.0
			var k = _cell_value(g_origin)
			if k is String:
				btn[k].highlighted = false
		var idx := int(round(diff.angle() / (PI / 4))) % 8
		if idx < 0:
			idx += 8
		target = _cell_value(g_origin + DIR8[idx])
	elif not g_moved:
		return
	if typeof(target) == typeof(g_cur) and target == g_cur:
		return
	g_cur = target
	if target == null:
		_clear_preview()
		return
	if target is int and target in SLOT_NUM and g_first_card == 0:
		g_first_card = target
	_preview_action(_intent())


## 今のジェスチャーが指す操作：テンキー番号・キー名、または "hold:<枠>"
func _intent():
	if g_cur is int and g_cur == 9 and g_first_card != 0:
		return "hold:%d" % SLOT_NUM.find(g_first_card)
	return g_cur


func _on_release(p: Vector2) -> void:
	if not g_active:
		return
	var moved := g_moved
	var intent = _intent()
	var charge: float = btn.special.charge
	var origin_val = _cell_value(g_origin)
	var short := g_time < 0.35
	_end_gesture()
	if not _input_ok():
		return
	if moved:
		if intent == null or (intent is int and intent == 5):
			return
		_execute(intent)
	elif origin_val is int and origin_val == 5 and charge >= 1.0:
		_execute(5)
	elif origin_val is String:
		_execute(origin_val)  # 右列のキーはタップで使える
	elif short or charge <= 0.0:
		_tap_info(origin_val)


func _end_gesture() -> void:
	g_active = false
	g_moved = false
	g_cur = null
	g_first_card = 0
	g_cut_in = false
	for k in ["deck", "status", "end"]:
		if btn.has(k):
			btn[k].highlighted = false
	if btn.has("special"):
		btn.special.charge = 0.0
	_clear_preview()


## 軽くタップしたマスの説明を出す
func _tap_info(num) -> void:
	var info := _action_for(num)
	if info.is_empty():
		return
	strip_title = info.title
	strip_text = info.desc
	strip_col = ImageController.COL.text
	strip.queue_redraw()


## 操作の中身 → {"title", "desc", "action", "ap", "kind"}
func _action_for(num) -> Dictionary:
	if current.get("side", "") != "ally" or num == null:
		return {}
	var dc: DeckController = deck_controllers[current.id]
	if num is String:
		match num:
			"deck": return {"title": "デッキ・捨札", "desc": "山札・捨札・保留を確認する", "kind": "deck"}
			"status": return {"title": "ステータス", "desc": "全員のステータスを確認する", "kind": "status"}
			"end": return {"title": "ターン終了", "desc": "手番を終える（残りAPは持ち越し）", "kind": "end"}
		if num.begins_with("hold:"):
			var slot := int(num.substr(5))
			var c = dc.hand[slot]
			if c == null:
				return {}
			var t := "%s を保留" % c.name
			if dc.hold != null:
				t += "（%s と入れ替え）" % dc.hold.name
			return {"title": "保留", "desc": t, "kind": "hold", "slot": slot, "ap": 0}
		return {}
	match num:
		8, 4, 2, 6:
			var slot := SLOT_NUM.find(num)
			var c = dc.hand[slot]
			if c == null:
				return {}
			return {"title": c.name, "desc": _short(c), "action": c, "kind": "card", "slot": slot, "ap": int(c.get("ap", 0))}
		9:
			if dc.hold == null:
				return {"title": "保留", "desc": "カードへ弾き、離さず9へ滑らせると保留（AP0）", "kind": "none"}
			return {"title": dc.hold.name, "desc": "保留カードを使う　" + _short(dc.hold), "action": dc.hold, "kind": "hold_play", "ap": int(dc.hold.get("ap", 0))}
		7:
			return {"title": "入替", "desc": "左右の位置を入れ替える（AP1）。敵の矢印の色で狙われる側がわかる", "action": ActionList.SWAP, "kind": "swap", "ap": 1}
		1:
			return {"title": "アイテム", "desc": "道具を使う（AP0）　所持 %d 個" % Inventory.items.size(), "kind": "item", "ap": 0}
		3:
			var s: Dictionary = ActionList.UNIQUE_SKILLS[current.id]
			return {"title": s.name, "desc": _short(s), "action": s, "kind": "unique", "ap": int(s.ap)}
		5:
			var s: Dictionary = specials[current.id]
			return {"title": "必殺", "desc": "%s　%s（中央を長押し）" % [s.name, _short(s)], "action": s, "kind": "special", "ap": int(s.ap)}
	return {}


func _short(a: Dictionary) -> String:
	var tgt := ""
	match a.get("target", ""):
		"enemy_all": tgt = "敵全体に"
		"front_enemy_single": tgt = "一番近い敵に"
		"front_enemy_group": tgt = "自分の側の敵全員に"
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
	log_label.visible = false
	strip_title = info.title
	strip_text = info.desc + ("　AP不足" if lack else "")
	strip_col = ImageController.COL.bad if lack else ImageController.COL.accent
	strip.queue_redraw()
	match info.kind:
		"card": hand_cards[info.slot].highlighted = true
		"hold":
			btn.hold.highlighted = true
			hand_cards[info.slot].highlighted = true
		"hold_play": hold_card.highlighted = true
		"swap": btn.swap.highlighted = true
		"item": btn.item.highlighted = true
		"unique": btn.unique.highlighted = true
		"deck", "status", "end": btn[info.kind].highlighted = true
	if info.has("action") and not lack:
		var act: Dictionary = info.action
		if info.kind == "swap":
			for a in CurrentStatus.allies:
				views[a.uid].preview = {"on": true, "label": "→右" if int(a.lane) == 0 else "→左"}
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
	for k in ["swap", "hold", "item", "unique", "deck", "status", "end"]:
		if btn.has(k) and not (g_active and not g_moved and _cell_value(g_origin) is String and _cell_value(g_origin) == k):
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
	var dir := _flick_dir(num)
	match info.kind:
		"card":
			current["ap"] = int(current.ap) - ap
			_fly_card(hand_cards[info.slot], dir)
			dc.play_and_discard(info.slot)
			_play(info.action)
		"hold_play":
			current["ap"] = int(current.ap) - ap
			_fly_card(hold_card, dir)
			dc.play_hold()
			_play(info.action)
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
			_play(info.action)
		"special":
			current["ap"] = int(current.ap) - ap
			_log("必殺！ %s！" % info.action.name)
			fx.shake(10.0)
			_play(info.action)
		"end":
			phase = "busy"
			turn_done.emit()
			return
		"deck": _open_deck()
		"status": _open_status()
	_refresh_all()


## カードが飛んでいく向き（押した位置から操作したマスへの向き）
func _flick_dir(num) -> Vector2:
	var c := _cell_of(num) if not (num is String and num.begins_with("hold:")) else _cell_of(9)
	if c.x < 0:
		return Vector2.UP
	var d := _cell_center(c) - _cell_center(g_origin)
	return d.normalized() if d.length() > 1 else Vector2.UP


## カード・スキル・必殺技の効果。表示側で扱う特殊効果もここで処理する
func _play(act: Dictionary) -> void:
	var dc: DeckController = deck_controllers[current.id]
	match act.get("effect", ""):
		"draw":
			_draw_more(dc, int(act.eff_val))
			fx.cast(views[current.uid], Callable())
		"turnabout":
			dc.discard_hand()
			_draw_more(dc, 4)
			StatusController.apply_status(current, "atk_buff", int(act.eff_val))
			fx.cast(views[current.uid], Callable())
			fx.popup(views[current.uid], "攻↑ %d" % int(act.eff_val), ImageController.COL.good, 28)
		"extra_turn":
			extra_turn = true
			fx.cast(views[current.uid], Callable())
			fx.popup(views[current.uid], "もう一度！", ImageController.COL.accent, 32)
		_:
			_perform(current, act)
	if _all_dead(CurrentStatus.enemies) or current.hp <= 0:
		phase = "busy"
		turn_done.emit.call_deferred()


func _draw_more(dc: DeckController, n: int) -> void:
	for i in dc.draw_cards(n):
		_pop_in(hand_cards[i], i * 0.05)


func _do_swap() -> void:
	for a in CurrentStatus.allies:
		a["lane"] = 1 - int(a.lane)
		a["pos"] = ALLY_POS[int(a.lane)]
		var v: GuiUnit = views[a.uid]
		v.facing = _facing(a)
		var tw := v.create_tween()
		tw.tween_property(v, "position", (v.position + a.pos) / 2 + Vector2(0, -40), 0.1)
		tw.tween_property(v, "position", a.pos, 0.1)
	_update_targets()
	_log("左右を入れ替えた！")


# ============================================================
# 4. 情報表示（キャラのタップ・デッキ・ステータス・アイテム）
# ============================================================

## 戦場のキャラをタップすると、そのキャラの情報を出す
func _tap_field(p: Vector2) -> void:
	for u in CurrentStatus.enemies + CurrentStatus.allies:
		var v: GuiUnit = views[u.uid]
		if v.dead:
			continue
		var d: Vector2 = p - v.position
		if absf(d.x) < 60 * v.art_scale and d.y < 30 and d.y > -v.body_height() - 10:
			_show_unit_info(u)
			return


func _unit_lines(u: Dictionary) -> Array:
	var lines: Array = []
	lines.append("HP %d / %d" % [u.hp, u.max_hp] + ("　ブロック %d" % u.shield if int(u.get("shield", 0)) > 0 else ""))
	lines.append("攻撃 %+d　防御 %d　素早さ %d" % [ActionController.get_atk(u), ActionController.get_def(u), ActionController.get_spd(u)])
	if u.side == "ally":
		lines.append("AP %d / %d　位置：%s" % [u.ap, InitAllyStatus.AP_MAX, "左（青）" if int(u.lane) == 0 else "右（赤）"])
	for k in u.status_effects:
		var st: Dictionary = StatusEffectList.DATA[k]
		lines.append("%s %d：%s" % [st.name, u.status_effects[k], st.desc])
	if u.side == "enemy" and not u.intent.is_empty():
		var it: Dictionary = u.intent
		var who := ""
		match it.get("target", ""):
			"front_enemy_single": who = "（%s を狙う）" % ("左・青" if int(u.target_lane) == 0 else "右・赤")
			"enemy_all": who = "（味方全員）"
		lines.append("次の行動：%s　%s%s" % [it.name, DeckController.effect_text(u, it), who])
	return lines


func _show_unit_info(u: Dictionary) -> void:
	_close_info()
	var v: GuiUnit = views[u.uid]
	var lines := _unit_lines(u)
	var w := 470.0
	var h := GuiInfoPanel.measure(lines, w)
	var head := v.position - Vector2(0, v.body_height())  # キャラの頭のあたり
	var x := clampf(v.position.x - w / 2, 16, 720 - w - 24)
	var y := clampf(head.y - h - 40, 92, 630 - h)
	info_panel = GuiInfoPanel.new()
	info_panel.setup(u.name, lines, Rect2(x, y, w, h), u.side == "enemy")
	info_panel.tail_to = head + Vector2(0, -4) if head.y > y + h else v.position + Vector2(0, -v.body_height() * 0.5)
	info_panel.z_index = 50
	ui.add_child(info_panel)


func _close_info() -> void:
	if info_panel != null and is_instance_valid(info_panel):
		info_panel.queue_free()
	info_panel = null


func _close_panels() -> void:
	_close_info()
	if item_panel:
		item_panel.visible = false


func _open_deck() -> void:
	var secs := {}
	for a in CurrentStatus.allies:
		var dc: DeckController = deck_controllers[a.id]
		var hand: Array = dc.hand.filter(func(c): return c != null)
		secs[a.id] = [["手札", hand], ["保留", [dc.hold] if dc.hold != null else []],
				["山札（順不同）", _sorted(dc.draw_pile)], ["捨札", dc.discard_pile.duplicate()]]
	overlay = GuiDeckView.open(ui, "デッキ・捨札", Callable(), secs, current.get("id", "knight"))
	overlay.closed.connect(func(): overlay = null)


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
	dim.color = Color(0, 0, 0, 0.75)
	dim.size = overlay.size
	overlay.add_child(dim)
	UiSystem.make_panel(overlay, Rect2(20, 80, 680, 1100))
	UiSystem.make_banner(overlay, "ステータス", Rect2(40, 56, 330, 60), 32)
	var lines: Array = []
	for u in CurrentStatus.allies + CurrentStatus.enemies:
		if u.hp <= 0:
			continue
		lines.append("■ " + u.name)
		for l in _unit_lines(u):
			lines.append("　" + l)
	var l := UiSystem.make_label(overlay, "\n".join(lines), Vector2(44, 140), Vector2(632, 920), 18, col.text, HORIZONTAL_ALIGNMENT_LEFT, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	UiSystem.make_button(overlay, "閉じる", Vector2(210, 1080), Vector2(300, 80), func():
		overlay.queue_free()
		overlay = null, 26)


func _open_items() -> void:
	for c in item_panel.get_children():
		c.queue_free()
	UiSystem.make_banner(item_panel, "アイテム（AP 0）", Rect2(20, -22, 340, 58), 28)
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
	UiSystem.make_button(item_panel, "閉じる", Vector2(210, 510), Vector2(200, 70), func(): item_panel.visible = false)
	item_panel.visible = true


func _use_item(item_id: String) -> void:
	item_panel.visible = false
	if phase != "player":
		return
	var it: Dictionary = Item_List.DATA[item_id]
	Inventory.remove_item(item_id)
	_log("%sを使った！" % it.name)
	_play(it)
	_refresh_all()


func _fly_card(src: GuiCard, dir: Vector2) -> void:
	var c := GuiCard.new()
	c.interactive = false
	c.set_card(src.card)
	c.position = src.position
	c.scale = src.scale
	c.z_index = 20
	pad.add_child(c)
	c.pivot_offset = c.size / 2
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "position", src.position + dir * 520 + Vector2(0, -240), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(c, "rotation", dir.x * 1.4 + 0.3, 0.32)
	tw.tween_property(c, "modulate:a", 0.0, 0.32)
	tw.chain().tween_callback(c.queue_free)


func _pop_in(c: GuiCard, delay: float) -> void:
	var base := Vector2.ONE * c.base_scale
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
		if int(current.ap) >= int(sp.ap) and sp.get("effect", "") != "extra_turn" and guard == 1 and randf() < 0.5:
			_execute(5)
			continue
		if guard == 2 and dc.hand[0] != null and randf() < 0.4:
			_execute("hold:0")
			continue
		if guard == 3 and int(current.ap) >= 2 and randf() < 0.25:
			_execute(3 if randf() < 0.5 else 7)
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
		_execute("end")
