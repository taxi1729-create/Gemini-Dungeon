extends Node2D
## 戦闘シーン：進行・UI・入力（battle-spec.md）
##
## 画面（720×1280）
##   上   : ログ／敵（前衛 4 体・後衛 2 体。後衛は小さく描いて遠近感を出す）
##   中   : 味方 2 人（左＝青ターゲット／右＝赤ターゲット）
##   下   : 行動順バー／説明帯／操作エリア 3 行×5 列（左からアイテム欄・テンキー 3 列・デッキ等のキー）
## 操作 : 指を置いたマスを起点に 8 方向へ弾くと、隣のマスの操作を実行する（5 を起点にすればテンキーどおり）
##        どのマスも長押しで溜め、満タンで離すと発動する。フリックで 5（必殺）に合わせて止めても溜まる

signal turn_done

const ENEMY_FRONT := [Vector2(270, 468), Vector2(450, 468), Vector2(105, 468), Vector2(615, 468)]  # 前衛（最大 4 体）を埋める順
const ENEMY_BACK := [Vector2(190, 278), Vector2(530, 278)]  # 後衛（最大 2 体）
const BOSS_POS := Vector2(360, 278)  # 強敵・ボスは後衛の中央
const BOSS_BACK_EXTRA := Vector2(612, 278)  # ボス戦で後衛に入るもう 1 体
const ENEMY_SCALE := 0.8  # 前衛
const ENEMY_BACK_SCALE := 0.62  # 後衛（遠くにいるので小さく）
const ALLY_POS := [Vector2(230, 604), Vector2(490, 604)]  # lane 0 = 左（青）, lane 1 = 右（赤）
const VIEW_SCALE := 0.85

## 操作エリアのマス（3 行×5 列）。数字はテンキー、"itemN" はアイテム欄、右列は "deck" / "status" / "end"
const GRID := [["item0", 7, 8, 9, "deck"], ["item1", 4, 5, 6, "status"], ["item2", 1, 2, 3, "end"]]
const GRID_COLS := 5
const COL_X := [0.0, 104.0, 272.0, 440.0, 608.0, 720.0]  # 列の左端（最後は右端）
const GRID_TOP := 764.0
const ROW_H := 172.0
const SLOT_NUM := [8, 4, 2, 6, 1]  # 手札の枠 → テンキー（1 は 5 枚目のカード）
const DIR8 := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
const DEADZONE := 48.0
const CHARGE_DELAY := 0.12
const CHARGE_TIME := 0.9
const HIT_GAP := 0.14  # 多段攻撃のヒットの間隔（秒）

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

var hand_cards: Array = []  # GuiCard ×5
var hold_card: GuiCard
var item_slots: Array = []  # GuiItemSlot ×3
var btn := {}  # swap hold unique special deck status end -> GuiSysButton
var order_bar: GuiWidget
var log_label: Label
var overlay: Control
var info_panel: Control  # キャラをタップした時の情報
var desc_bubble: GuiDescBubble  # 長押し・フリック中の説明（アイコン入り）
var _desc_key = null  # 今吹き出しに出している操作
var power_seen := {}  # char_id -> このターン手札に入ったパワーカード（効果は次の自分のターンまで）

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
var g_charge_target = null  # 溜めている操作（マスの中身）。変わったら溜め直し

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
	if not (g_active and _input_ok()):
		return
	# 溜める対象：指を動かしていなければ押したマス、フリック中なら 5（必殺）に合わせている時だけ
	var target = null
	if not g_moved:
		target = _cell_value(g_origin)
	elif g_cur is int and g_cur == 5:
		target = 5
	if typeof(target) != typeof(g_charge_target) or target != g_charge_target:
		_set_charge(g_charge_target, 0.0)
		g_charge_target = target
		g_time = 0.0
		g_cut_in = false
	if target == null:
		return
	g_time += delta / maxf(Engine.time_scale, 0.01)
	var c := clampf((g_time - CHARGE_DELAY) / CHARGE_TIME, 0.0, 1.0)
	_set_charge(target, c)
	if c > 0:
		_show_desc_for(target)
	if c > 0 and target is int and target == 5 and not g_moved and g_cur == null:
		g_cur = 5
		_preview_action(5)
	# カットインは必殺技だけ。AP が足りない時は出さない
	if c >= 1.0 and target is int and target == 5 and not g_cut_in:
		g_cut_in = true
		var sp: Dictionary = specials[current.id]
		if int(current.ap) >= _special_cost(sp):
			fx.cut_in(current.id, sp.name)


## マスの部品に溜めゲージを表示する
func _set_charge(target, c: float) -> void:
	var w = _widget_of(target)
	if w != null and "charge" in w:
		w.charge = c


## マスの中身 → 表示している部品
func _widget_of(target):
	if target == null:
		return null
	if target is String:
		if target.begins_with("item"):
			return item_slots[int(target.substr(4))]
		return btn.get(target)
	match target:
		5: return btn.special
		7: return btn.swap
		3: return btn.unique
		9: return hold_card if hold_card.visible else btn.hold
	var slot := SLOT_NUM.find(target)
	return hand_cards[slot] if slot >= 0 else null


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
	var boss_id := ""
	if kind == "boss":
		boss_id = AreaList.get_enemy_pool(area, "bosses").pick_random()
	elif kind == "elite":
		boss_id = AreaList.get_enemy_pool(area, "elites").pick_random()
	# 並び：前衛 4 体まで → 後衛 2 体まで。強敵・ボスは後衛の中央
	var places: Array = []  # [位置, 段]
	if boss_id != "":
		ids.append(boss_id)
		places.append([BOSS_POS, 1])
	var front_free: Array = ENEMY_FRONT.duplicate()
	var back_free: Array = ENEMY_BACK.duplicate() if boss_id == "" else [BOSS_BACK_EXTRA]
	while ids.size() < count and (not front_free.is_empty() or not back_free.is_empty()):
		ids.append(normal.pick_random())
		if not front_free.is_empty():
			places.append([front_free.pop_front(), 0])
		else:
			places.append([back_free.pop_front(), 1])
	# 再読み込みしても同じ敵で再開できるよう、編成をセーブに残す（保存済みならそれを使う）
	var saved = SaveData.screen.get("formation")
	if saved is Array and not saved.is_empty() and saved.all(func(f): return f is Dictionary and EnemyList.DATA.has(str(f.get("id", "")))):
		ids = []
		places = []
		for f in saved:
			ids.append(str(f.id))
			places.append([Vector2(float(f.x), float(f.y)), int(f.row)])
	else:
		var form: Array = []
		for i in ids.size():
			form.append({"id": ids[i], "x": places[i][0].x, "y": places[i][0].y, "row": places[i][1]})
		SaveData.screen["formation"] = form
		SaveData.save("battle")
	var enemies: Array = []
	for i in ids.size():
		var e := EnemyList.make_enemy(ids[i], floor_no)
		e["pos"] = places[i][0]
		e["row"] = places[i][1]
		e["uid"] = _new_uid()
		e["view_scale"] = ENEMY_SCALE if e.row == 0 else ENEMY_BACK_SCALE
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


## 回り込み先：同じ段で、左右反対側の空いている位置
func _flank_dest(e: Dictionary):
	var p: Vector2 = e.pos
	var row_pos: Array = ENEMY_FRONT if int(e.row) == 0 else ENEMY_BACK + [BOSS_BACK_EXTRA]
	var best = null
	for cand in row_pos:
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
			var tg := ActionController.resolve_targets(e, t, CurrentStatus.allies, CurrentStatus.enemies)
			lanes = [int(tg[0].lane)] if not tg.is_empty() else [int(e.target_lane)]
		elif t == "enemy_all":
			lanes = [0, 1]
		e["aim_lanes"] = lanes
		if lanes.is_empty():
			continue
		var from: Vector2 = e.pos if e.move_to == null else e.move_to
		list.append({"from": from, "lanes": lanes, "move_to": e.move_to})
		for a in ActionController.resolve_targets(e, t, CurrentStatus.allies, CurrentStatus.enemies):
			views[a.uid].targeted += 1
	fx.set_intents(list)


func _cell_rect(c: Vector2i) -> Rect2:
	return Rect2(COL_X[c.x], GRID_TOP + c.y * ROW_H, COL_X[c.x + 1] - COL_X[c.x], ROW_H)


func _cell_center(c: Vector2i) -> Vector2:
	return _cell_rect(c).get_center()


func _cell_at(p: Vector2) -> Vector2i:
	var col := 0
	for i in GRID_COLS:
		if p.x >= COL_X[i]:
			col = i
	return Vector2i(col, clampi(int((p.y - GRID_TOP) / ROW_H), 0, 2))


func _cell_value(c: Vector2i):
	if c.y < 0 or c.y >= GRID.size() or c.x < 0 or c.x >= GRID_COLS:
		return null
	return GRID[c.y][c.x]


func _cell_of(value) -> Vector2i:
	for r in GRID.size():
		for col in GRID_COLS:
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

	# 行動順は操作エリアのすぐ上
	order_bar = GuiWidget.new("order", Rect2(8, 668, 704, 52))
	ui.add_child(order_bar)
	log_label = UiSystem.make_label(ui, "", Vector2(110, 10), Vector2(500, 38), 22, col.text, HORIZONTAL_ALIGNMENT_CENTER, 4)
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
	strip.position = Vector2(0, 722)
	strip.size = Vector2(720, 42)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.draw.connect(_draw_strip)
	ui.add_child(strip)

	pad = Control.new()
	pad.size = Vector2(720, 1280)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(pad)

	for i in SLOT_NUM.size():
		var c := GuiCard.new()
		c.interactive = false
		c.position = _cell_center(_cell_of(SLOT_NUM[i])) - GuiCard.SIZE / 2
		c.label_hint = str(SLOT_NUM[i])
		c.visible = false
		pad.add_child(c)
		hand_cards.append(c)

	_add_btn("swap", "入替", "swap", Color("8fc0ea"), 7)
	_add_btn("hold", "保留", "pin", Color("e8c26a"), 9)
	_add_btn("unique", "固有", "star", Color("b88cff"), 3)
	_add_btn("special", "必殺", "burst", Color("ffb03a"), 5, Vector2(132, 132))
	btn.swap.ap_cost = 1
	btn.hold.subtitle = "AP 0"
	hold_card = GuiCard.new()
	hold_card.interactive = false
	hold_card.base_scale = 0.86
	hold_card.scale = Vector2(0.86, 0.86)
	hold_card.position = _cell_center(_cell_of(9)) - GuiCard.SIZE / 2
	hold_card.label_hint = "9"
	hold_card.visible = false
	pad.add_child(hold_card)

	# アイテム欄（テンキー 7・4・1 の左。上から 1 つ目・2 つ目・3 つ目）
	for i in Inventory.ITEM_MAX:
		var s := GuiItemSlot.new()
		s.slot_index = i
		s.size = Vector2(96, 160)
		s.position = _cell_center(Vector2i(0, i)) - s.size / 2
		pad.add_child(s)
		item_slots.append(s)

	var kb := [["deck", "デッキ・捨札", "cards", Color("8fb4ff")], ["status", "ステータス", "info", Color("8fc0ea")], ["end", "ターン終了", "enter", col.red]]
	for k in kb:
		var b := GuiSysButton.new()
		var c := _cell_center(_cell_of(k[0]))
		var sz := Vector2(108, 164)
		b.setup(k[1], k[2], k[3], "", "", sz, "key")
		b.position = c - sz / 2
		pad.add_child(b)
		btn[k[0]] = b

	desc_bubble = GuiDescBubble.new()
	ui.add_child(desc_bubble)
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
		IC.text(strip, strip_title + "　" + DeckController.plain(strip_text), Vector2(360, 22), 20, strip_col, true, 0, 680)
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
		# ブロックはターン開始時に 0 に戻る（バリケード中は戻さない）
		if (u.side == "enemy" or not first_turn.get(u.id, false)) and not StatusController.has(u, "barricade"):
			u["shield"] = 0
		var ticks := StatusController.trigger_start_of_turn(u)
		var hurt := false
		for t in ticks:
			if t.has("declare"):
				if t.declare:
					fx.popup(views[u.uid], "APプラス！", ImageController.COL.good, 30)
				else:
					fx.popup(views[u.uid], "宣言失敗", ImageController.COL.bad, 28)
			elif t.has("damage"):
				fx.hit(views[t.target.uid], int(t.damage), 0, "tick")
				hurt = true
			elif t.has("ap_gain"):
				u["pending_ap"] = int(u.get("pending_ap", 0)) + int(t.ap_gain)
				fx.popup(views[u.uid], "AP+%d" % t.ap_gain, ImageController.COL.ap, 28)
			elif t.has("reblock"):
				fx.popup(views[u.uid], "盾+%d" % int(t.shield), ImageController.COL.shield, 28)
			elif t.has("focus"):
				fx.popup(views[u.uid], "必殺AP-%d" % int(t.focus), ImageController.COL.accent, 26)
		if hurt:
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
		StatusController.end_of_turn(u)  # 持ち主のターンが終わったら残りターンを減らす
	v.active = false
	_refresh_all()


func _ally_turn(u: Dictionary) -> void:
	current = u
	var gain := InitAllyStatus.AP_PER_TURN + int(u.get("pending_ap", 0))
	u["pending_ap"] = 0
	if first_turn.get(u.id, false):
		gain += int(CurrentStatus.next_battle.get("ap", 0))
		first_turn[u.id] = false
	u["ap"] = mini(InitAllyStatus.AP_MAX, int(u.ap) + gain)
	var dc: DeckController = deck_controllers[u.id]
	# パワーカードの効果は前の自分のターンから今まで。ここで切り替える
	u["power_atk"] = 0
	u["power_def"] = 0
	power_seen[u.id] = []
	dc.draw_cards(DeckController.HAND_SIZE)
	_log("%sの手番" % u.name)
	phase = "player"
	_refresh_all()
	for i in hand_cards.size():
		if dc.hand[i] != null:
			_pop_in(hand_cards[i], i * 0.04)
	if autoplay:
		_autoplay_turn.call_deferred()
	await turn_done
	phase = "busy"
	_end_gesture()
	_close_panels()
	# 保留枠が空で手札が残っていれば、ランダムに 1 枚を自動で保留（演出つき）
	if u.hp > 0:
		var slot := -1
		var before: Array = dc.hand.duplicate()
		var held = dc.auto_hold()
		if held != null:
			for i in before.size():
				if before[i] != null and is_same(before[i], held):
					slot = i
			_log("%sを自動で保留した" % held.name)
			await _anim_hold(held, hand_cards[slot] if slot >= 0 else hold_card, true)
	dc.turn_end_and_discard()
	_refresh_all()
	await _wait(0.3)


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


## カード・スキルの実行：結果はその場で確定し（入力の先行受付のため）、演出は後追い。x は APX の X。イベントを返す
func _perform(user: Dictionary, action: Dictionary, x: int = 1) -> Array:
	var v: GuiUnit = views[user.uid]
	var single_target := ActionController.resolve_targets(user, action.get("target", "self"), CurrentStatus.allies, CurrentStatus.enemies)
	var events := ActionController.execute_action(user, action, CurrentStatus.allies, CurrentStatus.enemies, x)
	_handle_specials(user, events)
	var last_hit := 0
	for ev in events:
		last_hit = maxi(last_hit, int(ev.get("hit_no", 0)))
	var show := func():
		_show_events(events, action)
		# 多段攻撃は最後のヒットの数字が出てから倒れる
		if last_hit > 0:
			get_tree().create_timer(HIT_GAP * last_hit).timeout.connect(func(): _update_deaths(user))
		else:
			_update_deaths(user)
	if action.has("power") and action.get("target", "") == "front_enemy_single" and not single_target.is_empty():
		fx.ally_attack(v, single_target[0].pos, show)
	else:
		fx.cast(v, show)
	_update_targets()
	_refresh_all()
	return events


## 表示側で処理する効果（ドロー・入替・連続魔法・一転攻勢・ターンスキップ）
func _handle_specials(user: Dictionary, events: Array) -> void:
	if user.get("side", "") != "ally":
		return
	var dc: DeckController = deck_controllers[user.id]
	for ev in events:
		if not ev.has("special"):
			continue
		match ev.special:
			"draw":
				_draw_more(dc, int(ev.val))
			"swap":
				_do_swap()
			"double":
				StatusController.apply_status(user, "double", 1, -1)
				fx.popup(views[user.uid], "連続魔法", ImageController.COL.accent, 28)
			"turnabout":
				# 空いている手札の枠を補充する。攻撃力 +1
				_draw_more(dc, DeckController.HAND_SIZE)
				StatusController.apply_status(user, "atk_buff", maxi(1, int(ev.val)))
				fx.popup(views[user.uid], "攻↑ 1", ImageController.COL.good, 28)
			"extra_turn":
				extra_turn = true
				fx.popup(views[user.uid], "もう一度！", ImageController.COL.accent, 32)


func _show_events(events: Array, action: Dictionary) -> void:
	var col: Dictionary = ImageController.COL
	for ev in events:
		var t: Dictionary = ev.target
		if not views.has(t.uid):
			continue
		var tv: GuiUnit = views[t.uid]
		if ev.has("damage"):
			var kind := "slash" if action.get("target", "") in ["front_enemy_single", "front_enemy_group"] else "burst"
			var hn := int(ev.get("hit_no", 0))
			if hn > 0:
				# 多段攻撃：ヒットごとに少しずらして数字を出す
				var dmg := int(ev.damage)
				var blk := int(ev.get("blocked", 0))
				get_tree().create_timer(HIT_GAP * hn).timeout.connect(func(): fx.hit(tv, dmg, blk, kind))
			else:
				fx.hit(tv, int(ev.damage), int(ev.get("blocked", 0)), kind)
		if ev.has("heal"):
			fx.popup(tv, "+%d" % ev.heal, col.good, 34)
		if ev.has("shield"):
			fx.popup(tv, "盾+%d" % ev.shield, col.shield, 28)
		if ev.has("status"):
			var st: Dictionary = StatusEffectList.DATA.get(ev.status, {})
			var txt: String = st.get("short", "") if (ev.status in ["taunt", "double"] or st.get("label", "") == "none") else "%s %d" % [st.get("short", ""), ev.status_val]
			if ev.get("reflect", false):
				txt = "反撃 " + txt
			fx.popup(tv, txt, col.good if st.get("good", false) else Color("ffa060"), 26)
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
		a["power_atk"] = 0
		a["power_def"] = 0
	if result == "win" and CurrentStatus.battle_kind != "boss":
		SaveData.save("result")  # 戦闘クリア時の自動セーブ
	else:
		SaveData.clear()  # 全滅・踏破でセーブを消す
	UiSystem.goto("result")


# ============================================================
# 3. プレイヤーの操作（ジェスチャー）
# ============================================================

func _input_ok() -> bool:
	return phase == "player" and overlay == null


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
	if p.y < GRID_TOP:
		return
	g_active = true
	g_start = p
	g_origin = _cell_at(p)
	g_time = 0.0
	g_cur = null
	g_first_card = 0
	g_moved = false
	g_cut_in = false
	g_charge_target = null
	var k = _cell_value(g_origin)
	if k is String and btn.has(k):
		btn[k].highlighted = true


func _on_drag(p: Vector2) -> void:
	if not _input_ok():
		return
	var diff := p - g_start
	var target = null
	if diff.length() > DEADZONE:
		if not g_moved:
			g_moved = true
			var k = _cell_value(g_origin)
			if k is String and btn.has(k):
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
	var origin_val = _cell_value(g_origin)
	var charged := g_charge_target != null and (g_time - CHARGE_DELAY) >= CHARGE_TIME
	var charge_target = g_charge_target
	var short := g_time < 0.35 or g_charge_target == null
	_end_gesture()
	if not _input_ok():
		return
	if moved:
		if intent == null:
			return
		if intent is int and intent == 5:
			# フリックで必殺に合わせた時は、止めて溜めきった時だけ発動
			if charged and charge_target is int and charge_target == 5:
				_execute(5)
			return
		_execute(intent)
	elif charged:
		_execute(origin_val)  # 長押しで溜めきったマスを発動
	elif origin_val is String and btn.has(origin_val):
		_execute(origin_val)  # 右列のキーはタップでも使える
	elif short:
		_tap_info(origin_val)


func _end_gesture() -> void:
	_set_charge(g_charge_target, 0.0)
	g_active = false
	g_moved = false
	g_cur = null
	g_first_card = 0
	g_cut_in = false
	g_charge_target = null
	for k in ["deck", "status", "end"]:
		if btn.has(k):
			btn[k].highlighted = false
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
			"deck": return {"title": "デッキ・捨札", "desc": "山札・捨札・廃棄札・保留を確認する", "kind": "deck"}
			"status": return {"title": "ステータス", "desc": "全員のステータスを確認する", "kind": "status"}
			"end": return {"title": "ターン終了", "desc": "手番を終える（残りAPは持ち越し。保留が空なら手札から1枚自動で保留）", "kind": "end"}
		if num.begins_with("item"):
			var i := int(num.substr(4))
			if i >= Inventory.items.size():
				return {"title": "アイテム", "desc": "空き（アイテムは3つまで）", "kind": "none"}
			var it: Dictionary = Item_List.DATA[Inventory.items[i]]
			return {"title": it.name, "desc": it.desc + "（AP0）", "action": it, "kind": "item", "index": i, "ap": 0}
		if num.begins_with("hold:"):
			var slot := int(num.substr(5))
			var c = dc.hand[slot]
			if c == null:
				return {}
			var t := "%s を保留" % c.name
			if ActionList.has_keyword(c, "power"):
				t += "（パワーカードは捨札へ行く）"
			elif dc.hold != null:
				t += "（%s と入れ替え）" % dc.hold.name
			return {"title": "保留", "desc": t, "kind": "hold", "slot": slot, "ap": 0}
		return {}
	match num:
		8, 4, 2, 6, 1:
			var slot := SLOT_NUM.find(num)
			var c = dc.hand[slot]
			if c == null:
				return {}
			if c.get("type", "") == "unselectable":
				return {"title": c.name, "desc": DeckController.effect_text(current, c), "kind": "none"}
			return _card_info(c, slot, "card", _short(c))
		9:
			if dc.hold == null:
				return {"title": "保留", "desc": "カードへ弾き、離さず9へ滑らせると保留（AP0）", "kind": "none"}
			return _card_info(dc.hold, -1, "hold_play", "保留カードを使う　" + _short(dc.hold))
		7:
			return {"title": "入替", "desc": "左右の位置を入れ替える（AP1）。敵の矢印の色で狙われる側がわかる", "action": ActionList.SWAP, "kind": "swap", "ap": 1}
		3:
			var s: Dictionary = ActionList.UNIQUE_SKILLS[current.id]
			return {"title": s.name, "desc": _short(s), "action": s, "kind": "unique", "ap": int(s.ap), "block_msg": _unique_block(s)}
		5:
			var s: Dictionary = specials[current.id]
			return {"title": "必殺", "desc": "%s　%s（長押し）" % [s.name, _short(s)], "action": s, "kind": "special", "ap": _special_cost(s)}
	return {}


## カード（手札・保留）の操作情報。ap = 払う AP、need = 使うのに必要な AP、no_consume = 消費するカードが無い
func _card_info(c: Dictionary, slot: int, kind: String, desc: String) -> Dictionary:
	var dc: DeckController = deck_controllers[current.id]
	var cost := _card_cost(c)
	var need := cost
	if c.get("ap_x", false) and not c.get("free", false):
		need = maxi(1, int(c.get("ap", 1)))
	var no_consume: bool = ActionList.has_keyword(c, "consume") and not dc.has_consume_target(slot)
	# 自分以外の味方が対象（APパサー）：その味方が倒れていれば使えない
	var msg := ""
	if c.get("target", "") == "other_ally" and ActionController.resolve_targets(current, "other_ally", CurrentStatus.allies, CurrentStatus.enemies).is_empty():
		msg = "渡す相手が倒れている"
	return {"title": c.name, "desc": desc, "action": c, "kind": kind, "slot": slot, "ap": cost, "need": need, "no_consume": no_consume, "block_msg": msg}


## 固有スキルを今使えないわけ（"" = 使える）。一転攻勢は手札に空きが無いと使えない
func _unique_block(s: Dictionary) -> String:
	if ActionList.effects_of(s).any(func(e): return e.get("effect", "") == "turnabout"):
		var dc: DeckController = deck_controllers[current.id]
		if not dc.hand.any(func(x): return x == null):
			return "手札に空きがない"
	return ""


## カードを使う時に払う AP（free は 0、APX は今の AP 全部）
func _card_cost(c: Dictionary) -> int:
	if c.get("free", false):
		return 0
	if c.get("ap_x", false):
		return int(current.get("ap", 0))
	return int(c.get("ap", 0))


## 必殺技の AP（精神統一中は減る。0 未満にしない）
func _special_cost(sp: Dictionary) -> int:
	return maxi(0, int(sp.get("ap", 0)) - StatusController.focus_cut(current))


## カードを今使えないわけ（"" = 使える / "ap" = AP不足 / "consume" = 消費するカードがない）。slot = -1 は保留枠
func _card_block(c: Dictionary, slot: int) -> String:
	if c.get("type", "") == "unselectable":
		return "unselectable"
	var info := _card_info(c, slot, "", "")
	if int(info.need) > int(current.get("ap", 0)):
		return "ap"
	if info.no_consume:
		return "consume"
	if info.block_msg != "":
		return "target"
	return ""


## AP の表示（APX は "X"、free は "0"）
func _ap_label(a: Dictionary) -> String:
	if a.get("free", false):
		return "0"
	if a.get("ap_x", false):
		return "X"
	return str(a.get("ap", 0))


func _short(a: Dictionary) -> String:
	var tgt := DeckController.target_text(a.get("target", ""))
	var s := "%s：%s" % [tgt, DeckController.effect_text(current, a)] if tgt != "" else DeckController.effect_text(current, a)
	if a.has("ap"):
		var is_sp: bool = current.get("side", "") == "ally" and specials.get(current.get("id", ""), {}).get("id", "-") == a.get("id", "")
		s += "（AP%s）" % (str(_special_cost(a)) if is_sp else _ap_label(a))
	return s


func _preview_action(num) -> void:
	_clear_preview()
	var info := _action_for(num)
	if info.is_empty():
		return
	var lack_ap := int(info.get("need", info.get("ap", 0))) > int(current.ap)
	var lack_cons: bool = info.get("no_consume", false)
	var lack_msg := str(info.get("block_msg", ""))
	var lack := lack_ap or lack_cons or lack_msg != ""
	_show_desc_for(num)
	log_label.visible = false
	strip_title = info.title
	strip_text = info.desc + ("　AP不足" if lack_ap else ("　消費するカードがない" if lack_cons else ("　" + lack_msg if lack_msg != "" else "")))
	strip_col = ImageController.COL.bad if lack else ImageController.COL.accent
	strip.queue_redraw()
	var w = _widget_of(num if not (num is String and num.begins_with("hold:")) else 9)
	if w != null:
		w.highlighted = true
	if info.kind == "hold":
		hand_cards[info.slot].highlighted = true
	if info.has("action") and not lack:
		var act: Dictionary = info.action
		if info.kind == "swap":
			for a in CurrentStatus.allies:
				views[a.uid].preview = {"on": true, "label": "→右" if int(a.lane) == 0 else "→左"}
			return
		var x := int(current.ap) if (act.get("ap_x", false) and not act.get("free", false)) else 1
		for ev in ActionController.preview(current, act, CurrentStatus.allies, CurrentStatus.enemies, x):
			var p := {"on": true}
			if ev.has("damage"):
				p["damage"] = ev.damage
				p["kill"] = ev.kill
			else:
				p["label"] = _effect_label(act, x)
			views[ev.target.uid].preview = p


func _effect_label(a: Dictionary, x: int = 1) -> String:
	var effs := ActionList.effects_of(a)
	if effs.is_empty():
		return ""
	var e: Dictionary = effs[0]
	var v := int(e.get("eff_val", 0)) * (x if e.get("x", false) else 1)
	match e.get("effect", ""):
		"add_shield": return "盾+%d" % v
		"absorb_block":
			var total := 0
			for t in ActionController.resolve_targets(current, a.get("target", "self"), CurrentStatus.allies, CurrentStatus.enemies):
				total += int(t.get("shield", 0))
			return "盾吸収+%d" % total
		"add_ap": return "AP+%d" % e.eff_val
		"heal": return "回復%d" % e.eff_val
		"draw": return "%d枚引く" % e.eff_val
		"swap": return "入替"
		"double": return "連続魔法"
		"add_status":
			var st: Dictionary = StatusEffectList.DATA[e.status]
			return st.short if (e.status in ["taunt"] or st.get("label", "") == "none") else "%s%d" % [st.short, v]
		"turnabout": return "補充"
		"extra_turn": return "再行動"
	return ""


func _clear_preview() -> void:
	for v in views.values():
		v.preview = {}
	for c in hand_cards:
		c.highlighted = false
	if hold_card:
		hold_card.highlighted = false
	for s2 in item_slots:
		s2.highlighted = false
	for k in ["swap", "hold", "unique", "special", "deck", "status", "end"]:
		if btn.has(k) and not (g_active and not g_moved and _cell_value(g_origin) is String and _cell_value(g_origin) == k):
			btn[k].highlighted = false
	strip_text = ""
	_desc_key = null
	if desc_bubble:
		desc_bubble.hide_bubble()
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
	if int(info.get("need", ap)) > int(current.ap):
		_log("APが足りない！")
		AnimationController.shake(pad, 6)
		return
	if info.get("no_consume", false):
		_log("消費するカードがない")
		AnimationController.shake(pad, 6)
		return
	if str(info.get("block_msg", "")) != "":
		_log(str(info.block_msg))
		AnimationController.shake(pad, 6)
		return
	var dc: DeckController = deck_controllers[current.id]
	var dir := _flick_dir(num)
	match info.kind:
		"card", "hold_play":
			_use_card(info, dc, dir)
		"hold":
			var src: GuiCard = hand_cards[info.slot]
			var moving: Dictionary = dc.hand[info.slot]
			var to_discard := dc.put_on_hold(info.slot)
			if to_discard:
				_log("パワーカードは保留できず、捨札へ")
				_fly_card(src, Vector2(1, -1))
			else:
				_log("%sを保留した" % dc.hold.name)
				_anim_hold(moving, src, false)  # 入れ替えで戻ったカードは、保留したカードが着いてから出す
		"swap":
			current["ap"] = int(current.ap) - ap
			_do_swap()
		"item":
			Inventory.remove_item_at(int(info.index))
			_log("%sを使った！" % info.action.name)
			_play(info.action)
		"unique":
			current["ap"] = int(current.ap) - ap
			_log("%s！" % info.action.name)
			_play(info.action)
		"special":
			current["ap"] = maxi(0, int(current.ap) - ap)
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


## 手札・保留のカードを使う：AP（APX は全部）を払い、消費、発動、倒したらもう一度使える
func _use_card(info: Dictionary, dc: DeckController, dir: Vector2) -> void:
	var c: Dictionary = info.action
	var slot := int(info.slot)  # -1 = 保留枠
	var x := 1
	if c.get("ap_x", false) and not c.get("free", false):
		x = int(current.ap)
	current["ap"] = maxi(0, int(current.ap) - int(info.ap))
	# 消費：ほかの手札からランダムに 1 枚を捨札へ
	if ActionList.has_keyword(c, "consume"):
		var cs := dc.consume_random(slot)
		if cs >= 0:
			var gone: GuiCard = hand_cards[cs]
			_fly_card(gone, Vector2(0, 1))
			gone.visible = false
			var gone_card: Dictionary = dc.discard_pile.back()
			_log("消費：%sを捨てた" % gone_card.get("name", ""))
	if slot >= 0:
		_fly_card(hand_cards[slot], dir)
		dc.play_and_discard(slot)
	else:
		_fly_card(hold_card, dir)
		dc.play_hold()
	var kills := _play_card(c, x)
	# 倒したら捨札へ行かず元の枠に戻る（reuse_free はこのターンの間 AP 0）
	var ok_kind: String = c.get("on_kill", "")
	if kills > 0 and ok_kind in ["reuse", "reuse_free"]:
		var back := dc.return_card(c, slot)
		if back != -2:
			if ok_kind == "reuse_free":
				c["free"] = true
			fx.popup(views[current.uid], "もう一度！" if ok_kind == "reuse" else "もう一度！ AP0", ImageController.COL.accent, 30)
			_refresh_all()
			_pop_in(hand_cards[back] if back >= 0 else hold_card, 0.25)


## カード（手札・保留）を使う。連続魔法がかかっていれば 2 回発動する（X は 2 回とも同じ）。倒した敵の数を返す
func _play_card(card: Dictionary, x: int = 1) -> int:
	var times := 1
	if StatusController.has(current, "double") and not ActionList.effects_of(card).any(func(e): return e.get("effect", "") == "double"):
		StatusController.remove(current, "double")
		times = 2
		fx.popup(views[current.uid], "2回発動！", ImageController.COL.accent, 30)
	var kills := 0
	for i in times:
		if phase != "player":
			break
		for ev in _play(card, x):
			if ev.get("kill", false):
				kills += 1
	return kills


## カード・スキル・必殺技・アイテムの効果。イベントを返す
func _play(act: Dictionary, x: int = 1) -> Array:
	var events := _perform(current, act, x)
	if _all_dead(CurrentStatus.enemies) or current.hp <= 0:
		phase = "busy"
		turn_done.emit.call_deferred()
	return events


func _draw_more(dc: DeckController, n: int, only_slots: Array = []) -> void:
	for i in dc.draw_cards(n, only_slots):
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


## 吹き出し用の文章（HP・攻撃・防御・素早さはアイコンの行で別に表示される）
func _unit_lines(u: Dictionary) -> Array:
	var lines: Array = []
	if u.side == "ally":
		lines.append("AP %d / %d　位置：%s" % [u.ap, InitAllyStatus.AP_MAX, "左（青）" if int(u.lane) == 0 else "右（赤）"])
	else:
		lines.append("位置：%s" % ("前衛" if int(u.get("row", 0)) == 0 else "後衛"))
	for k in u.status_effects:
		var st: Dictionary = StatusEffectList.DATA.get(k, {})
		lines.append("%s %s：%s" % [st.get("name", k), StatusController.label(u, k), st.get("desc", "")])
	if u.side == "enemy" and not u.intent.is_empty():
		var it: Dictionary = u.intent
		var who := ""
		match it.get("target", ""):
			"front_enemy_single":
				var tg := ActionController.resolve_targets(u, "front_enemy_single", CurrentStatus.allies, CurrentStatus.enemies)
				if not tg.is_empty():
					who = "（%s を狙う）" % tg[0].name
			"enemy_all": who = "（味方全員）"
		lines.append("次の行動：%s　%s%s" % [it.name, DeckController.effect_text(u, it), who])
	return lines


func _show_unit_info(u: Dictionary) -> void:
	_close_info()
	var v: GuiUnit = views[u.uid]
	var lines := _unit_lines(u)
	var w := 470.0
	var panel := GuiInfoPanel.new()
	panel.unit = u
	var h: float = GuiInfoPanel.measure(lines, w, u)
	var head := v.position - Vector2(0, v.body_height())  # キャラの頭のあたり
	var x := clampf(v.position.x - w / 2, 16, 720 - w - 24)
	var y := clampf(head.y - h - 40, 56, 640 - h)
	info_panel = panel
	panel.setup(u.name, lines, Rect2(x, y, w, h), u.side == "enemy")
	panel.tail_to = head + Vector2(0, -4) if head.y > y + h else v.position + Vector2(0, -v.body_height() * 0.5)
	panel.z_index = 50
	ui.add_child(panel)


func _close_info() -> void:
	if info_panel != null and is_instance_valid(info_panel):
		info_panel.queue_free()
	info_panel = null


func _close_panels() -> void:
	_close_info()


func _open_deck() -> void:
	var secs := {}
	for a in CurrentStatus.allies:
		var dc: DeckController = deck_controllers[a.id]
		var hand: Array = dc.hand.filter(func(c): return c != null)
		secs[a.id] = [["手札", hand], ["保留", [dc.hold] if dc.hold != null else []],
				["山札（順不同）", _sorted(dc.draw_pile)], ["捨札", dc.discard_pile.duplicate()], ["廃棄札", dc.exhaust_pile.duplicate()]]
	overlay = GuiDeckView.open(ui, "デッキ・捨札・廃棄札", Callable(), secs, current.get("id", "knight"))
	overlay.closed.connect(func(): overlay = null)


func _sorted(arr: Array) -> Array:
	var a := arr.duplicate()
	a.sort_custom(func(x, y): return x.name < y.name)
	return a


func _open_status() -> void:
	var units: Array = (CurrentStatus.allies + CurrentStatus.enemies).filter(func(u): return u.hp > 0)
	overlay = GuiStatusView.open(ui, units)
	overlay.closed.connect(func(): overlay = null)


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


## 保留の演出：カードを大きく見せてから保留枠へ飛ばし、「保留」の札を出す
func _anim_hold(card: Dictionary, src: Control, auto: bool) -> void:
	var c := GuiCard.new()
	c.interactive = false
	c.set_card(card)
	c.position = src.position
	c.scale = src.scale
	c.z_index = 40
	pad.add_child(c)
	c.pivot_offset = c.size / 2
	hold_card.modulate.a = 0.0
	# 元の枠のカードは隠し、飛んでいくカード 1 枚だけを見せる（入れ替えで戻るカードは着いてから出す）
	var hide_src: bool = src != hold_card and src is GuiCard
	if hide_src:
		src.modulate.a = 0.0
	var dest: Vector2 = _cell_center(_cell_of(9)) - GuiCard.SIZE / 2
	var center := Vector2(360, 960) - GuiCard.SIZE / 2
	var tw := c.create_tween()
	if auto:
		# 自動保留：中央で大きく見せてから飛ばす
		tw.tween_property(c, "position", center, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(c, "scale", Vector2(1.6, 1.6), 0.18)
		tw.tween_interval(0.35)
	else:
		tw.tween_property(c, "scale", Vector2(1.3, 1.3), 0.08)
	tw.tween_property(c, "position", dest, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(c, "scale", Vector2(0.86, 0.86), 0.22)
	tw.parallel().tween_property(c, "rotation", 0.25, 0.11)
	tw.tween_property(c, "rotation", 0.0, 0.08)
	tw.tween_callback(func():
		c.queue_free()
		hold_card.modulate.a = 1.0
		_pop_in(hold_card, 0.0)
		if hide_src:
			src.modulate.a = 1.0
			if auto:
				src.visible = false  # 自動保留：元の枠は空になる
			elif src.visible:
				_pop_in(src, 0.0)
		if not auto:  # 自動保留は吹き出しで知らせるので、札は出さない
			AnimationController.popup_text(ui, _cell_center(_cell_of(9)) + Vector2(0, -96), "保留！", ImageController.COL.accent, 30))
	if auto:
		desc_bubble.show_text(("自動保留：" + card.name), DeckController.card_text(current, card), _cell_center(_cell_of(9)))
		await tw.finished
		await _wait(0.35)
		desc_bubble.hide_bubble()


## 長押し・フリック中に説明の吹き出しを出す
func _show_desc_for(key) -> void:
	if typeof(key) == typeof(_desc_key) and key == _desc_key:
		return
	_desc_key = key
	var info := _action_for(key)
	if info.is_empty():
		desc_bubble.hide_bubble()
		return
	var body: String = info.desc
	if info.has("action") and info.kind in ["card", "hold_play"]:
		body = DeckController.card_text(current, info.action)
	var cell := _cell_of(9) if (key is String and key.begins_with("hold:")) else _cell_of(key)
	desc_bubble.show_text(info.title, body, _cell_center(cell) if cell.x >= 0 else Vector2(360, 960))


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
	if dc != null:
		# パワーカード：手札にある間だけ効果
		var seen: Array = power_seen.get(current.id, [])
		for c in dc.hand:
			if c != null and ActionList.has_keyword(c, "power") and not seen.any(func(x): return is_same(x, c)):
				seen.append(c)
				var pe: Dictionary = c.get("power_effect", {})
				match pe.get("status", ""):
					"atk_buff": current["power_atk"] = int(current.get("power_atk", 0)) + int(pe.eff_val)
					"def_buff": current["power_def"] = int(current.get("power_def", 0)) + int(pe.eff_val)
				fx.popup(views[current.uid], "%s +%d" % ["攻" if pe.get("status", "") == "atk_buff" else "防", int(pe.eff_val)], ImageController.COL.good, 26)
		power_seen[current.id] = seen
	for i in hand_cards.size():
		var cv: GuiCard = hand_cards[i]
		var c = dc.hand[i] if dc != null else null
		cv.visible = c != null
		if c != null:
			_set_eff(c)
			cv.set_card(c)
			cv.playable = _card_block(c, i) == ""
			cv.queue_redraw()
	hold_card.visible = dc != null and dc.hold != null
	if hold_card.visible:
		_set_eff(dc.hold)
		hold_card.set_card(dc.hold)
		hold_card.playable = _card_block(dc.hold, -1) == ""
	for i in item_slots.size():
		item_slots[i].set_item(Inventory.items[i] if i < Inventory.items.size() else "")
	if is_player:
		var u: Dictionary = ActionList.UNIQUE_SKILLS[current.id]
		btn.unique.title = u.name
		btn.unique.icon_kind = u.art
		btn.unique.ap_cost = int(u.ap)
		btn.unique.dimmed = int(current.ap) < int(u.ap) or _unique_block(u) != ""
		var sp: Dictionary = specials[current.id]
		btn.special.title = sp.name
		btn.special.icon_kind = sp.art
		btn.special.ap_cost = _special_cost(sp)  # 精神統一中は減った値
		btn.special.subtitle = "長押し"
		btn.special.dimmed = int(current.ap) < _special_cost(sp)
		btn.swap.dimmed = int(current.ap) < 1
		pad.modulate.a = 1.0
	elif phase != "over":
		pad.modulate.a = 0.5
	for b in btn.values():
		b.queue_redraw()
	order_bar.queue_redraw()
	strip.queue_redraw()


## カードに「実際のダメージ」を書き込む（自分の攻撃力と、主な対象の防御力を反映）
func _set_eff(c: Dictionary) -> void:
	# 右上の AP の表示（通常は数字、APX は "X"、このターン AP 0 なら "0"）
	if c.has("ap") or c.get("free", false):
		c["ap_show"] = _ap_label(c)
	if c.has("power"):
		c["power_eff"] = ActionController.effective_power(current, c, CurrentStatus.allies, CurrentStatus.enemies)
	else:
		c.erase("power_eff")


func _log(txt: String) -> void:
	log_label.text = txt
	log_label.modulate.a = 0.3
	log_label.create_tween().tween_property(log_label, "modulate:a", 1.0, 0.15)


# ============================================================
# 6. 自動テスト用（--autoplay 指定時のみ）
# ============================================================

func _autoplay_turn() -> void:
	var guard := 0
	while phase == "player" and guard < 16:
		guard += 1
		await _wait(0.08)
		if phase != "player":
			return
		var dc: DeckController = deck_controllers[current.id]
		var done := false
		var sp: Dictionary = specials[current.id]
		if int(current.ap) >= _special_cost(sp) and sp.id != "turn_skip" and guard == 1 and randf() < 0.5:
			_execute(5)
			continue
		if guard == 2 and dc.hand[0] != null and randf() < 0.3:
			_execute("hold:0")
			continue
		if guard == 3 and int(current.ap) >= 2 and randf() < 0.25:
			_execute(3 if randf() < 0.5 else 7)
			continue
		if guard == 4 and not Inventory.items.is_empty() and randf() < 0.3:
			_execute("item0")
			continue
		for i in hand_cards.size():
			var c = dc.hand[i]
			if c != null and _card_block(c, i) == "":
				_execute(SLOT_NUM[i])
				done = true
				break
		if not done and dc.hold != null and _card_block(dc.hold, -1) == "":
			_execute(9)
			done = true
		if not done:
			break
	if phase == "player":
		_execute("end")
