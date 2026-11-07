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

## 戦場の配置（7 列 × 4 段。battle-spec.md「配置」）。左右の端から 0〜6 列
##   段0（敵の後衛・一番奥）：A-1（2列）、C（3列）、B-1（4列）
##   段1（敵の前衛）　　　　：A-2（1列）、A-3（2列）、B-3（4列）、B-2（5列）
##   段2（味方の前衛）　　　：青前（1列）、赤前（5列）
##   段3（味方の後衛・手前）：青後（0列）、赤後（6列）
## 画面の位置は遠近法で奥の段ほど小さく上に置く。敵の前衛と後衛は互い違い（後衛は前衛の間から見える）にして、
## 吹き出し・HP バーが重ならないようにしてある
const ENEMY_SLOTS := {
	"A-1": {"col": 2, "row": 1, "pos": Vector2(180, 188)},
	"C": {"col": 3, "row": 1, "pos": Vector2(360, 194)},
	"B-1": {"col": 4, "row": 1, "pos": Vector2(540, 188)},
	"A-2": {"col": 1, "row": 0, "pos": Vector2(88, 376)},
	"A-3": {"col": 2, "row": 0, "pos": Vector2(268, 376)},
	"B-3": {"col": 4, "row": 0, "pos": Vector2(452, 376)},
	"B-2": {"col": 5, "row": 0, "pos": Vector2(632, 376)},
}
const FILL_ORDER := ["A-3", "B-3", "A-2", "B-2", "A-1", "B-1", "C"]  # 普通の敵を埋める順（C は 7 体目だけ）
const BOSS_SLOT := "C"  # 強敵・ボスの位置
const ENEMY_MAX := 7
## 遠近法：段ごとの倍率（遠い＝上の段ほど小さい）。ユニットの data.depth_scale に入れ、
## 絵・影・HP バー・吹き出しの位置は GuiUnit がこの値（× data.art_scale × GuiUnit.VIEW_BASE）から決める。
## ボス・強敵は C（後衛）に立つが本体が大きいので別の倍率（"boss"）。PNG に差し替える時もこの値はそのまま使う
const DEPTH_SCALE := {"enemy_back": 0.62, "enemy_front": 0.82, "ally_front": 0.92, "ally_back": 1.0, "boss": 0.7}
const BOSS_POS := Vector2(360, 206)  # 強敵・ボスが C に立つ時の足元（体が大きいので少し手前に。吹き出しが上の帯に隠れないように）。体が大きいほど下げる
const BOSS_MAX_SCALE := 0.95  # C に立つボスの絵の倍率（art_scale × depth_scale × VIEW_BASE）の上限
const BOSS_HEAD_ROOM := 106.0  # 頭の上に要る高さ（手番の帯の下 56 ＋ 吹き出し）。足元 ≥ これ ＋ 体の高さ
const BOSS_MAX_Y := 240.0  # ボスの足元の下限（これより下げると前衛の敵の吹き出しと重なる）
## 味方の位置 [lane][rank]。lane 0 = 左（青）/ 1 = 右（赤）、rank 0 = 前衛 / 1 = 後衛（手前）
## 後衛は足元の状態の列が下の行動順の帯（y 652〜）に隠れないよう、少し上に置く
const ALLY_POS := [[Vector2(214, 540), Vector2(92, 582)], [Vector2(506, 540), Vector2(628, 582)]]
## 陣形変更（1）の行動。ActionList に無いのでここで定義する
const FORMATION := {"id": "formation", "name": "陣形変更", "type": "skill", "target": "self", "art": "formation", "ap": 1, "effects": []}

## 操作エリアのマス（3 行×5 列）。数字はテンキー、"itemN" はアイテム欄、右列は "deck" / "status" / "end"
const GRID := [["item0", 7, 8, 9, "deck"], ["item1", 4, 5, 6, "status"], ["item2", 1, 2, 3, "end"]]
const GRID_COLS := 5
const COL_X := [0.0, 104.0, 272.0, 440.0, 608.0, 720.0]  # 列の左端（最後は右端）
const GRID_TOP := 764.0
const ROW_H := 172.0
const SLOT_NUM := [8, 4, 2, 6]  # 手札の枠 → テンキー（手札は 4 枚。1 は陣形変更、7 は入替）
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
var boots_used := {}  # char_id -> このターン「軽い靴」の AP0 を使ったか（ターン終了で空にする）
var last_swap_round := -1  # 最後に左右の入替（7・スワップ等）をしたラウンド（即応の判定用）

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
var _cur_action: Dictionary = {}  # 今 _perform している行動（撃破の repeat 用）
var _cur_x := 1
var whet_used := {}  # char_id -> このターン「砥石」を使ったか（各ターン最初のアタックカードだけ）
var rosary_left := 10  # 十連の数珠：あと何回カードを使えば発動するか（味方 2 人の合計）
var rosary_ready := false  # 十連の数珠：次のカードに効く
var stats := {"overkill": 0, "rounds": 0, "hp_lost": 0}  # 戦闘の集計（終了時に CurrentStatus.battle_stats へ）
var boss_extra := {"knight": false, "witch": false}  # ボスレリック：このラウンドの追加ターン（ラウンド開始時の抽選の結果。戦闘中セーブに残す）

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

## 戦闘の途中のセーブ（battle_snapshot / _restore_battle）でそのまま保存・復元するメンバー変数の名前。
## 値は int・bool・String・Dictionary・Array など（ユニットの辞書やノードを入れない）。戦闘に状態を足したらここに名前を足す
const SAVE_VARS := ["round_no", "first_turn", "boots_used", "last_swap_round", "whet_used", "rosary_left", "rosary_ready", "stats", "boss_extra"]
var _resume_at := -1  # 再開する行動順の位置（-1＝再開ではない。_restore_battle が入れる）
var _turn_idx := 0  # 今ターン中のキャラの行動順の位置（action_order の添字。同じキャラが 2 回入っていても区別する）


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
	fx.set_lanes(ALLY_POS[0][0], ALLY_POS[1][1])
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
		if int(current.ap) >= _special_cost(sp) and _special_block(sp) == "":
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
		1: return btn.formation
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
		# 初期位置：ナイト＝青前（lane0, rank0）、ウィッチ＝赤後（lane1, rank1）。戦闘開始時の位置は転身用に残す
		var ln := i
		if a.id == "knight":
			ln = 0
		elif a.id == "witch":
			ln = 1
		a["lane"] = ln
		a["rank"] = ln
		a["start_lane"] = ln
		a["start_rank"] = ln
		a["pos"] = ally_pos(a)
		a["uid"] = _new_uid()
		a["shield"] = int(nb.get("block", 0)) if a.hp > 0 else 0
		a["status_effects"] = {}
		if int(nb.get("atk", 0)) > 0:
			a.status_effects["atk_buff"] = int(nb.atk)
		a["ap"] = 0
		a["max_ap"] = InitAllyStatus.AP_MAX
		a["depth_scale"] = ally_depth(a)
		var dc := DeckController.new()
		add_child(dc)
		dc.setup_battle_deck(CurrentDeck.decks[a.id])
		deck_controllers[a.id] = dc
		first_turn[a.id] = true
		specials[a.id] = ActionList.special(a.id, CurrentStatus.special_choice.get(a.id, ""))

	var floor_no := maxi(0, CurrentStatus.current_floor)
	var area := CurrentStatus.current_area_id
	var kind := CurrentStatus.battle_kind
	var count := AreaList.enemy_count(floor_no, kind, CurrentStatus.stage)
	var normal: Array = AreaList.get_enemy_pool(area, "enemies")
	var ids: Array = []
	var boss_id := ""
	if kind == "lastboss":
		boss_id = AreaList.get_enemy_pool(area, "lastboss").pick_random()  # 3 階のボスの後の連戦（1 体だけ）
	elif kind == "boss":
		boss_id = AreaList.get_enemy_pool(area, "bosses").pick_random()
	elif kind == "elite":
		boss_id = AreaList.get_enemy_pool(area, "elites").pick_random()
	# 並び：強敵・ボスは C。普通の敵は前衛（A-3, B-3, A-2, B-2）→ 後衛（A-1, B-1）→ 7 体目だけ C
	var slots: Array = fill_slots(count, boss_id != "")  # ids と同じ順の位置名
	for i in slots.size():
		ids.append(boss_id if (i == 0 and boss_id != "") else normal.pick_random())
	# 再読み込みしても同じ敵で再開できるよう、編成をセーブに残す（保存済みならそれを使う）
	# 形：[{"id", "slot"}]。古い形（x, y, row）のセーブは捨てて作り直す
	var saved = SaveData.screen.get("formation")
	if saved is Array and not saved.is_empty() and saved.all(func(f): return f is Dictionary and EnemyList.DATA.has(str(f.get("id", ""))) and ENEMY_SLOTS.has(str(f.get("slot", "")))):
		ids = []
		slots = []
		for f in saved:
			ids.append(str(f.id))
			slots.append(str(f.slot))
	else:
		var form: Array = []
		for i in ids.size():
			form.append({"id": ids[i], "slot": slots[i]})
		SaveData.screen["formation"] = form
		SaveData.save("battle")
	var enemies: Array = []
	for i in ids.size():
		var e := EnemyList.make_enemy(ids[i], floor_no)
		_place_enemy(e, str(slots[i]))
		e["uid"] = _new_uid()
		enemies.append(e)
	CurrentStatus.enemies = enemies
	for e in enemies:
		_choose_intent(e)
	# 戦闘の途中のセーブがあれば、味方・敵・山札などをその時の状態に戻す（enemies の中身も入れ替わる）
	_restore_battle(SaveData.battle_state(), enemies)

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
	_sync_lanes()
	_update_targets()


## 敵 count 体の位置名（最大 7）。boss なら先頭が C（強敵・ボス）、残りは FILL_ORDER の順
static func fill_slots(count: int, boss: bool) -> Array:
	var out: Array = []
	if boss:
		out.append(BOSS_SLOT)
	for s in FILL_ORDER:
		if out.size() >= mini(count, ENEMY_MAX):
			break
		if not out.has(s):
			out.append(s)
	return out


## 味方の画面上の位置（lane と rank から）
func ally_pos(a: Dictionary) -> Vector2:
	return ALLY_POS[clampi(int(a.get("lane", 0)), 0, 1)][clampi(int(a.get("rank", 0)), 0, 1)]


## 味方の段の倍率（前衛 / 後衛）
static func ally_depth(a: Dictionary) -> float:
	return float(DEPTH_SCALE.ally_front if int(a.get("rank", 0)) == 0 else DEPTH_SCALE.ally_back)


## 敵を位置名（A-1 など）に置く。slot・col・row（0＝前衛／1＝後衛）・pos・depth_scale を書く
## C に立つ強敵・ボス（普通の戦闘以外の C、または data.boss）は体が大きいので専用の倍率と位置
func _place_enemy(e: Dictionary, slot: String) -> void:
	var d: Dictionary = ENEMY_SLOTS[slot]
	e["slot"] = slot
	e["col"] = int(d.col)
	e["row"] = int(d.row)
	var big := slot == BOSS_SLOT and (str(CurrentStatus.battle_kind) != "battle" or bool(e.get("boss", false)))
	e["pos"] = BOSS_POS if big else d.pos
	if big:
		# 体がとても大きいボス（ラスボスなど art_scale が大きい敵）は、絵の倍率を BOSS_MAX_SCALE までに抑え、
		# 体の高さに合わせて足元を下げる（頭が上の予告の吹き出し・手番の帯に隠れないように）
		var art := maxf(0.1, float(e.get("art_scale", 1.0)))
		var dep := minf(float(DEPTH_SCALE.boss), BOSS_MAX_SCALE / (art * GuiUnit.VIEW_BASE))
		e["depth_scale"] = dep
		var body_h := 140.0 * art * dep * GuiUnit.VIEW_BASE
		e["pos"] = Vector2(BOSS_POS.x, clampf(BOSS_HEAD_ROOM + body_h, BOSS_POS.y, BOSS_MAX_Y))
	else:
		e["depth_scale"] = float(DEPTH_SCALE.enemy_front if int(d.row) == 0 else DEPTH_SCALE.enemy_back)


## 地面の青・赤ターゲットを、今その lane に立つ味方の足元へ動かす
func _sync_lanes() -> void:
	var p := [ALLY_POS[0][0], ALLY_POS[1][1]]
	var k: Array = [float(DEPTH_SCALE.ally_front), float(DEPTH_SCALE.ally_back)]
	for a in CurrentStatus.allies:
		p[clampi(int(a.lane), 0, 1)] = ally_pos(a)
		k[clampi(int(a.lane), 0, 1)] = ally_depth(a)
	fx.lane_scale = k  # 地面のターゲットの大きさも段に合わせる
	fx.set_lanes(p[0], p[1])


## lane / rank が変わった味方を新しい位置へ跳ばす（大きさも段に合わせる）
func _move_ally(a: Dictionary) -> void:
	a["pos"] = ally_pos(a)
	a["depth_scale"] = ally_depth(a)
	var v: GuiUnit = views[a.uid]
	v.facing = _facing(a)
	v.z_index = 10 + int(Vector2(a.pos).y)
	var to_scale := GuiUnit.scale_of(a)
	var tw := v.create_tween()
	tw.tween_property(v, "position", (v.position + Vector2(a.pos)) / 2 + Vector2(0, -40), 0.1)
	tw.parallel().tween_property(v, "art_scale", (v.art_scale + to_scale) / 2, 0.1)
	tw.tween_property(v, "position", Vector2(a.pos), 0.1)
	tw.parallel().tween_property(v, "art_scale", to_scale, 0.1)


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
	e["move_slot"] = ""
	if act.get("move", false):
		var dest := _flank_dest(e)
		if dest != "":
			e["move_slot"] = dest
			e["move_to"] = ENEMY_SLOTS[dest].pos
			e["target_lane"] = 0 if dest.begins_with("A") else 1
			return
		# 移動先が空いていなければ、その場で攻撃する
	e["target_lane"] = randi() % 2


## 回り込み先（位置名。"" = 無し）：同じ段で、左右反対側の空いている位置（向かい合う位置を優先）。
## C（中央）にいる敵は後衛の左右どちらか空いている方へ
func _flank_dest(e: Dictionary) -> String:
	var cur: String = str(e.get("slot", ""))
	var cands: Array = []
	match cur:
		"A-2": cands = ["B-2", "B-3"]
		"A-3": cands = ["B-3", "B-2"]
		"B-3": cands = ["A-3", "A-2"]
		"B-2": cands = ["A-2", "A-3"]
		"A-1": cands = ["B-1"]
		"B-1": cands = ["A-1"]
		"C":
			cands = ["A-1", "B-1"]
			cands.shuffle()
	for s in cands:
		var taken := false
		for o in CurrentStatus.enemies:
			if o != e and o.hp > 0 and (str(o.get("slot", "")) == s or str(o.get("move_slot", "")) == s):
				taken = true
		if not taken:
			return s
	return ""


## 予告の矢印と、狙われている味方の印を更新する
func _update_targets() -> void:
	var list: Array = []
	for a in CurrentStatus.allies:
		views[a.uid].targeted = 0
		# ランダムな敵 1 体（random_enemy）の選び直し：行動のたびに引き直し、次の行動まではプレビューと実行で同じ敵になる
		a["rand_seq"] = randi()
	for e in CurrentStatus.enemies:
		if e.hp <= 0 or e.intent.is_empty():
			continue
		if StatusController.has(e, "stun"):
			e["aim_lanes"] = []  # スタン中は行動しないので矢印を出さない（吹き出しは「スタン」）
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
	_update_intent_values()


## 敵の予告の数字（実際に受けるダメージ）を data.intent_dmg = [{"lane", "dmg"}] に入れる（左＝lane 0 から順）。
## 味方の防御力・防御力アップ/ダウン・パワーの防御力を反映し、ブロックは引かない。
## 単体攻撃は狙われる味方 1 人分（挑発・回り込みの移動先も resolve_targets が反映）、全体攻撃は立っている味方ごと
func _update_intent_values() -> void:
	for e in CurrentStatus.enemies:
		var act: Dictionary = e.get("intent", {})
		var out: Array = []
		if e.hp > 0 and act.has("power") and not StatusController.has(e, "stun"):
			var tg := ActionController.resolve_targets(e, act.get("target", ""), CurrentStatus.allies, CurrentStatus.enemies)
			tg = tg.filter(func(a): return a.get("side", "") == "ally")
			tg.sort_custom(func(a, b): return int(a.get("lane", 0)) < int(b.get("lane", 0)))
			for a in tg:
				out.append({"lane": int(a.get("lane", 0)), "dmg": ActionController.calc_damage(e, act, a)})
		e["intent_dmg"] = out


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
		IC.pad_bg(low_bg, Rect2(Vector2.ZERO, low_bg.size)))
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
	_add_btn("formation", "陣形変更", "formation", Color("8fe0b0"), 1)
	btn.formation.ap_cost = 1
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
	turn_done.connect(func(): boots_used.clear())  # 軽い靴の AP0 はターンごと
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
		# 説明帯：エンジェルホワイトの帯に濃い文字（明るい色の指定は墨に、濃い色は少し暗くして読みやすく）
		IC.slant(strip, Rect2(8, 4, 704, 36), IC.COL.paper, 14, 2.0, IC.COL.ink, Color(IC.COL.red, 0.9), Vector2(4, 4))
		var sc: Color = IC.COL.ink if strip_col.get_luminance() > 0.5 else strip_col.darkened(0.25)
		IC.text(strip, strip_title + "　" + DeckController.plain(strip_text), Vector2(360, 22), 20, sc, true, 0, 680)
		return
	if current.get("side", "") == "ally":
		# 左に赤い斜めタグで「〇〇の手番」、右に AP の菱形
		var tag := Rect2(4, 3, 196, 38)
		IC.slant(strip, tag, IC.COL.red, 14, 2.0, IC.COL.ink, IC.COL.ink, Vector2(4, 4))
		IC.head(strip, "%sの手番" % current.name, tag.get_center(), 22, IC.COL.paper, 168)
		var amax := int(current.get("max_ap", InitAllyStatus.AP_MAX))  # 大きな砂時計で 12
		var step := 300.0 / maxf(10.0, float(amax))
		for i in amax:
			IC.icon(strip, "ap", Vector2(228 + i * step, 22), 24.0 * minf(1.0, step / 30.0), IC.COL.ap if i < ap else Color(1, 1, 1, 0.14))
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
	var resume_at := _resume_at  # 途中のセーブから再開する時は、行動順のこの位置のキャラのターン開始から
	_resume_at = -1
	if resume_at >= 0:
		_log("戦闘を再開した")
		_refresh_all()
		await _wait(0.6)
	else:
		_battle_start_effects()
		var names: Array = []
		for e in CurrentStatus.enemies:
			names.append(e.name)
		_log("%s が現れた！" % "、".join(names) if names.size() <= 3 else "敵が %d 体現れた！" % names.size())
		await _wait(0.6)
	while true:
		var start := 0
		if resume_at >= 0:
			# 再開：ラウンド・行動順は保存したもの。ラウンド開始の処理はしない（抽選の結果なども保存から戻っている）
			start = resume_at
			resume_at = -1
		else:
			round_no += 1
			action_order = (CurrentStatus.allies + CurrentStatus.enemies).filter(func(u): return u.hp > 0)
			action_order.sort_custom(func(a, b):
				var sa := ActionController.get_spd(a)
				var sb := ActionController.get_spd(b)
				if sa == sb:
					return a.side == "ally" and b.side != "ally"
				return sa > sb)
			_boss_round_start()  # ボスレリック（星詠みの砂時計・騎士王の角笛）：追加ターンを行動順の末尾へ
		order_bar.units = action_order
		for idx in range(start, action_order.size()):
			var u: Dictionary = action_order[idx]
			if u.hp <= 0:
				continue
			order_bar.index = idx
			_turn_idx = idx
			await _run_turn(u)
			if _check_end():
				return
		StatusController.decrease_all_durations(CurrentStatus.allies + CurrentStatus.enemies)
		_refresh_all()


# ------------------------------------------------------------
# 戦闘の途中のセーブ（味方のキャラのターン開始時に SaveData.save_battle で保存）
#   状態を集めるのは battle_snapshot()、戻すのは _restore_battle() の 1 か所だけ。
#   戦闘に状態を足す時：
#     ・メンバー変数なら SAVE_VARS に名前を足すだけ（値はユニットの辞書・ノードを含まないこと）
#     ・味方・敵の辞書の項目（a["xxx"]・e["xxx"]）は何もしなくても丸ごと保存される
#     ・それ以外（ユニットを指す値など）は battle_snapshot() の d["ext"] に足し、_restore_battle() の最後で戻す
# ------------------------------------------------------------
## 今の戦闘の状態（味方・敵の辞書、山札など、行動順、SAVE_VARS の変数）
func battle_snapshot() -> Dictionary:
	var decks := {}
	for id in deck_controllers:
		decks[id] = (deck_controllers[id] as DeckController).to_save()
	var vars := {}
	for k in SAVE_VARS:
		var v = get(k)
		vars[k] = v.duplicate(true) if (v is Dictionary or v is Array) else v
	var d := {
		"allies": CurrentStatus.allies.map(func(a): return (a as Dictionary).duplicate(true)),
		"enemies": CurrentStatus.enemies.map(func(e): return (e as Dictionary).duplicate(true)),
		"decks": decks,
		"order": action_order.map(func(u): return int(u.uid)),  # 行動順はユニットの uid で
		"turn": _turn_idx,
		"kind": CurrentStatus.battle_kind,  # 別の戦闘（ボスの後のラスボスなど）に古い途中の状態を戻さないため
		"vars": vars,
		"ext": {},
	}
	return d


## battle_snapshot() の状態に戻す（_setup_units の中、ユニットの絵を作る前に呼ぶ）。enemies は CurrentStatus.enemies と同じ配列で、中身を入れ替える。
## 形がおかしければ何も変えない（その戦闘をはじめからやり直す）
## 途中の状態が今の戦闘に戻せる形か。戻せなければ理由（戻せれば ""）
func _battle_state_error(st: Dictionary) -> String:
	var allies: Array = CurrentStatus.allies
	var sa = st.get("allies")
	var se = st.get("enemies")
	var sd = st.get("decks")
	var so = st.get("order")
	if not (sa is Array and se is Array and sd is Dictionary and so is Array and st.get("vars") is Dictionary) or se.is_empty():
		return "形が違う"
	if str(st.get("kind", "")) != CurrentStatus.battle_kind:
		return "戦闘の種類が違う"
	if (sa as Array).size() != allies.size():
		return "味方の数が違う"
	var by_uid := {}
	for i in allies.size():
		var o = sa[i]
		if not (o is Dictionary and str(o.get("id", "")) == str(allies[i].id) and o.has("uid") and o.has("hp")):
			return "味方が違う"
		if not DeckController.save_ok(sd.get(str(allies[i].id))):
			return "山札の形が違う"
		by_uid[int(o.uid)] = true
	for o in se:
		if not (o is Dictionary and EnemyList.DATA.has(str(o.get("base_id", ""))) and o.has("uid") and o.has("hp")):
			return "知らない敵"
		by_uid[int(o.uid)] = true
	if by_uid.size() != (sa as Array).size() + (se as Array).size():
		return "uid が重なっている"
	for x in so:
		if not by_uid.has(int(x)):
			return "行動順に知らないユニット"
	var turn := int(st.get("turn", -1))
	if turn < 0 or turn >= (so as Array).size():
		return "手番の位置が違う"
	return ""


func _restore_battle(st: Dictionary, enemies: Array) -> void:
	if st.is_empty():
		return
	var bad := _battle_state_error(st)
	if bad != "":
		push_warning("Battle: 途中のセーブを使わず、戦闘をはじめからやり直す（%s）" % bad)
		return
	var allies: Array = CurrentStatus.allies
	var sa: Array = st.allies
	var sd: Dictionary = st.decks
	var se: Array = st.enemies
	var so: Array = st.order
	var turn := int(st.turn)
	# ここから反映
	var units := {}
	for i in allies.size():
		var a: Dictionary = allies[i]
		a.clear()
		a.merge((sa[i] as Dictionary).duplicate(true))
		units[int(a.uid)] = a
		(deck_controllers[a.id] as DeckController).from_save(sd[a.id])
	enemies.clear()
	for o in se:
		var e: Dictionary = (o as Dictionary).duplicate(true)
		units[int(e.uid)] = e
		enemies.append(e)
	CurrentStatus.enemies = enemies
	_uid = 0
	for k in units:
		_uid = maxi(_uid, int(k))
	action_order = []
	for x in so:
		action_order.append(units[int(x)])
	var vars: Dictionary = st.vars
	for k in SAVE_VARS:
		if vars.has(k) and typeof(vars[k]) == typeof(get(k)):
			set(k, vars[k])
	_turn_idx = turn
	_resume_at = turn
	# st.ext の項目はここで戻す（battle_snapshot() の d["ext"] と対に）


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


## 戦闘開始時の効果：料理の効果（CurrentStatus.next_battle の atk/def/regen/block。ap は最初のターンに足す）とレリック
func _battle_start_effects() -> void:
	var nb: Dictionary = CurrentStatus.next_battle
	stats = {"overkill": 0, "rounds": 0, "hp_lost": 0}
	CurrentStatus.battle_stats = stats.duplicate()
	rosary_left = 10
	rosary_ready = false
	for a in CurrentStatus.allies:
		# 大きな砂時計：AP の上限 +5
		a["max_ap"] = InitAllyStatus.AP_MAX + (5 if Inventory.has_relic("hourglass") else 0)
		# _setup_units が入れた料理の値はここで正しい形に入れ直す
		a.status_effects.erase("atk_buff")
		a["shield"] = 0
		a.erase("rosary")
		if int(a.hp) <= 0:
			continue
		if int(nb.get("atk", 0)) > 0:
			StatusController.apply_status(a, "atk_buff", int(nb.atk), -1)
		if int(nb.get("def", 0)) > 0:
			StatusController.apply_status(a, "def_buff", int(nb.def), -1)
		if int(nb.get("regen", 0)) > 0:
			StatusController.apply_status(a, "regen", int(nb.regen), int(nb.regen))
		a["shield"] = int(nb.get("block", 0))
		if Inventory.has_relic("rosary"):
			a["rosary"] = rosary_left
	_refresh_all()


## 戦闘の集計：倒した時の余り（overkill）と、味方が減らされた HP（lost。回復で相殺しない）
func _tally(events: Array) -> void:
	for ev in events:
		var t: Dictionary = ev.get("target", {})
		if t.is_empty():
			continue
		if str(t.get("side", "")) == "ally":
			stats["hp_lost"] = int(stats.hp_lost) + int(ev.get("lost", 0))
		else:
			stats["overkill"] = int(stats.overkill) + int(ev.get("overkill", 0))


func _run_turn(u: Dictionary) -> void:
	var v: GuiUnit = views[u.uid]
	v.active = true
	var again := true
	while again and u.hp > 0:
		again = false
		# 自動セーブ：味方のキャラのターン開始の処理（ブロックのリセット・予約・火傷・AP・手札の補充）の前
		if u.side == "ally" and phase != "over":
			SaveData.save_battle(battle_snapshot())
		# ブロックはターン開始時に 0 に戻る（バリケード中は戻さない）
		if (u.side == "enemy" or not first_turn.get(u.id, false)) and not StatusController.has(u, "barricade"):
			u["shield"] = 0
		# 蒼の盾章：左（青）に立つ味方はターン開始時にブロック+4
		if u.side == "ally" and int(u.get("lane", 0)) == 0 and Inventory.has_relic("blue_crest"):
			u["shield"] = int(u.get("shield", 0)) + 4
			fx.popup(views[u.uid], "蒼の盾章 盾+4", ImageController.COL.shield, 26)
		var ticks := StatusController.trigger_start_of_turn(u)
		_tally(ticks)
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
			elif t.has("no_heal"):
				fx.popup(views[u.uid], "回復不可", ImageController.COL.bad, 26)
			elif t.has("heal"):
				fx.popup(views[u.uid], "再生 +%d" % int(t.heal), ImageController.COL.good, 30)
			elif t.has("yoyaku"):
				# 予約の札：積んだ効果を今発動する（対象はこの時に決め直す）
				fx.popup(views[u.uid], "予約！", ImageController.COL.accent, 28)
				for entry in t.yoyaku:
					var ed: Dictionary = entry
					var yev := ActionController.execute_action(u, {"target": str(ed.get("target", "self")), "effects": ed.get("effects", [])},
							CurrentStatus.allies, CurrentStatus.enemies)
					_tally(yev)
					_handle_specials(u, yev)
					_show_events(yev, {})
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
		if StatusController.has(u, "stun"):
			# スタン：このターンは行動しない（ターン開始時の効果は上で起きている）。休んだら消える
			StatusController.remove(u, "stun")
			_log("%sはスタンで動けない！" % u.name)
			fx.popup(views[u.uid], "スタン", ImageController.COL.bad, 32)
			_refresh_all()
			await _wait(0.6)
			if u.side == "enemy" and u.hp > 0:
				_choose_intent(u)
			_update_targets()
		elif u.side == "ally":
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
	gain += _boss_ap_bonus()  # ボスレリック「暁の聖杯」：ターン開始時 AP+1
	# 毎ターン AP 3 ＋ 加算（前のターンの終わりで 0 にしてあるので、u.ap は予約・他の味方から入った分だけ）。上限は大きな砂時計で +5
	u["ap"] = mini(int(u.get("max_ap", InitAllyStatus.AP_MAX)), int(u.ap) + gain)
	whet_used[u.id] = false
	var dc: DeckController = deck_controllers[u.id]
	# パワーカードの効果は前の自分のターンから今まで。ここで切り替える
	u["power_atk"] = 0
	u["power_def"] = 0
	power_seen[u.id] = []
	_power_reset(u)
	dc.draw_cards(DeckController.HAND_SIZE)
	_log("%sの手番" % u.name)
	phase = "player"
	_refresh_all()
	for i in hand_cards.size():
		if dc.hand[i] != null:
			_pop_in(hand_cards[i], i * 0.04)
	_boss_hold_auto(u, dc)  # ボスレリック「封印の聖櫃」：保留カードを AP0 で自動発動
	if autoplay and phase == "player":
		_autoplay_turn.call_deferred()
	await turn_done
	phase = "busy"
	_end_gesture()
	_close_panels()
	# 残った AP は捨てる（持ち越さない。9 回目）。この後に入る AP（魔力の転換・他の味方からの AP+）は次の自分のターンに足される
	u["ap"] = 0
	# パワーの「ターン終了時」（薬師の加護・魔力の転換）：手札にあれば発動（自動保留より先）
	if u.hp > 0 and not _all_dead(CurrentStatus.enemies):
		await _power_turn_end(u, dc)
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
		if str(e.get("move_slot", "")) != "":
			_place_enemy(e, str(e.move_slot))  # 回り込み：位置名も移動先に変える
			e["move_slot"] = ""
		e["pos"] = move_to
		v.facing = _facing(e)
		v.z_index = 10 + int(Vector2(move_to).y)
	var dur := 0.4
	var hit_cb := func(): _apply(e, act)
	if act.has("power") or act.get("target", "") in ["front_enemy_single", "enemy_all"]:
		var targets := ActionController.resolve_targets(e, act.target, CurrentStatus.allies, CurrentStatus.enemies)
		var tp: Vector2 = fx.lanes[clampi(int(e.target_lane), 0, 1)] if act.target == "front_enemy_single" else (Vector2(fx.lanes[0]) + Vector2(fx.lanes[1])) / 2
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
	_tally(events)
	_show_events(events, action)
	_power_marks(events)  # 断罪の連鎖：反撃が発動するたび（敵の攻撃）
	_update_deaths(user)
	_update_targets()
	_refresh_all()


## カード・スキルの実行：結果はその場で確定し（入力の先行受付のため）、演出は後追い。x は APX の X。イベントを返す
func _perform(user: Dictionary, action: Dictionary, x: int = 1) -> Array:
	var v: GuiUnit = views[user.uid]
	var single_target := ActionController.resolve_targets(user, action.get("target", "self"), CurrentStatus.allies, CurrentStatus.enemies)
	var events := ActionController.execute_action(user, action, CurrentStatus.allies, CurrentStatus.enemies, x)
	_tally(events)
	_cur_action = action  # 撃破の「もう一度この攻撃」（repeat）で使う
	_cur_x = x
	_handle_specials(user, events)
	_power_marks(events)  # 断罪の連鎖：撃破・反撃が発動するたび
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
	if action.has("power") and action.get("target", "") in ["front_pair", "front_enemy_single"] and not single_target.is_empty():
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
			"rank_swap":
				# 踏み込み：自分だけ前衛・後衛を入れ替える（左右はそのまま）
				user["rank"] = 1 - int(user.get("rank", 0))
				_move_ally(user)
				_sync_lanes()
				_update_targets()
				_log("%sは%sへ移った！" % [user.name, "前衛" if int(user.rank) == 0 else "後衛"])
			"rank_to":
				# 魔法準備・魔弾：段は ActionController が変え済み。絵を動かす
				_move_ally(user)
				_sync_lanes()
				_update_targets()
			"repeat":
				# 追尾弾（撃破）：同じ攻撃をもう一度（もう一度の分では撃破の追加効果は出さない）
				if _cur_action.is_empty() or phase != "player" or _all_dead(CurrentStatus.enemies):
					continue
				var again: Dictionary = _cur_action.duplicate(true)
				again.erase("gekiha_effects")
				again["keywords"] = (again.get("keywords", []) as Array).filter(func(k): return str(k) != "gekiha")
				user["rand_seq"] = randi()
				fx.popup(views[user.uid], "もう一度！", ImageController.COL.accent, 30)
				var rx := _cur_x
				_perform(user, again, rx)


func _show_events(events: Array, action: Dictionary) -> void:
	var col: Dictionary = ImageController.COL
	for ev in events:
		var t: Dictionary = ev.target
		if not views.has(t.uid):
			continue
		var tv: GuiUnit = views[t.uid]
		if ev.has("damage"):
			var kind := "slash" if action.get("target", "") in ["front_pair", "front_enemy_single", "front_enemy_group"] else "burst"
			var hn := int(ev.get("hit_no", 0))
			if hn > 0:
				# 多段攻撃：ヒットごとに少しずらして数字を出す
				var dmg := int(ev.damage)
				var blk := int(ev.get("blocked", 0))
				get_tree().create_timer(HIT_GAP * hn).timeout.connect(func(): fx.hit(tv, dmg, blk, kind))
			else:
				fx.hit(tv, int(ev.damage), int(ev.get("blocked", 0)), kind)
		if ev.get("no_heal", false):
			fx.popup(tv, "回復不可", col.bad, 26)
		elif ev.has("heal"):
			fx.popup(tv, "+%d" % ev.heal, col.good, 34)
		if ev.has("gekiha"):
			fx.popup(tv, "撃破！", col.accent, 30)
		if ev.has("shield"):
			fx.popup(tv, "盾+%d" % ev.shield, col.shield, 28)
		if ev.has("status"):
			var st: Dictionary = StatusEffectList.DATA.get(ev.status, {})
			var txt: String = st.get("short", "") if (ev.status in ["taunt", "double"] or st.get("label", "") == "none") else "%s %d" % [st.get("short", ""), ev.status_val]
			if ev.get("reflect", false) or ev.get("hangeki", false):
				txt = "反撃 " + txt
			fx.popup(tv, txt, col.good if st.get("good", false) else Color("ffa060"), 26)
		if ev.has("ap"):
			fx.popup(tv, "AP+%d" % ev.ap, col.ap, 30)
		if ev.has("charge"):
			fx.popup(tv, "力を溜めている…", col.accent, 24)
		if ev.has("cleanse"):
			fx.popup(tv, "デバフ解除" if not (ev.cleanse as Array).is_empty() else "解除なし", col.good, 26)  # 闘志


func _update_deaths(attacker: Dictionary) -> void:
	_lastboss_check()  # ラスボスの HP が 50% 以下なら第 2 段階へ
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
	# 戦闘の集計（結果画面の食材の判定に使う）
	stats["rounds"] = round_no
	CurrentStatus.battle_stats = stats.duplicate()
	for a in CurrentStatus.allies:
		a.erase("rosary")
		a["shield"] = 0
		a["status_effects"] = {}
		a["power_atk"] = 0
		a["power_def"] = 0
		a.erase("powers")  # 8 回目のパワー（効いているもの・鼓舞・使った枚数）
		a.erase("aid_atk")
		a.erase("aid_def")  # 鋼鉄化（味方全体）
		a.erase("cards_used")
	if result == "win" and CurrentStatus.is_last_boss_next():
		# 3 階のボスを倒した：結果画面を出さず、HP30% 回復してラスボスと連戦
		CurrentStatus.start_last_boss()
		SaveData.screen = {}
		SaveData.save("battle")
		UiSystem.goto("battle")
		return
	if result == "win" and CurrentStatus.battle_kind != "lastboss":
		SaveData.save("result")  # 戦闘クリア時の自動セーブ（1 階・2 階のボスもボスの報酬があるので保存する）
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
			"end": return {"title": "ターン終了", "desc": "手番を終える（残りAPは捨てる。保留が空なら手札から1枚自動で保留）", "kind": "end"}
		if num.begins_with("item"):
			var i := int(num.substr(4))
			if i >= Inventory.items.size():
				return {"title": "アイテム", "desc": "空き（アイテムは3つまで）", "kind": "none"}
			var it: Dictionary = Item_List.DATA[Inventory.items[i]]
			return {"title": it.name, "desc": it.desc + "（AP0）", "action": it, "kind": "item", "index": i, "ap": 0, "block_msg": _item_block(it)}
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
		8, 4, 2, 6:
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
			var c7 := _move_cost()
			return {"title": "入替", "desc": "左右の位置を入れ替える（前衛・後衛はそのまま）（AP%d）。敵の矢印の色で狙われる側がわかる" % c7, "action": ActionList.SWAP, "kind": "swap", "ap": c7}
		1:
			var c1 := _move_cost()
			return {"title": "陣形変更", "desc": "味方全員の前衛・後衛を入れ替える（AP%d）。前衛は攻撃力+2、後衛は防御力+2" % c1, "action": FORMATION, "kind": "formation", "ap": c1}
		3:
			var s: Dictionary = ActionList.UNIQUE_SKILLS[current.id]
			return {"title": s.name, "desc": _short(s), "action": s, "kind": "unique", "ap": int(s.ap), "block_msg": _unique_block(s)}
		5:
			var s: Dictionary = specials[current.id]
			var sd := str(s.get("desc", "")) + "（AP%d）" % _special_cost(s) if s.has("desc") else _short(s)
			return {"title": "必殺", "desc": "%s　%s（長押し）" % [s.name, sd], "action": _boss_mod(current, _special_play(s), true), "kind": "special", "ap": _special_cost(s),
					"block_msg": _special_block(s)}
	return {}


## カード（手札・保留）の操作情報。ap = 払う AP、need = 使うのに必要な AP、no_consume = 消費するカードが無い
func _card_info(c: Dictionary, slot: int, kind: String, desc: String) -> Dictionary:
	var dc: DeckController = deck_controllers[current.id]
	var cost := _card_cost(c)
	var need := cost
	if c.get("ap_x", false) and not c.get("free", false):
		need = maxi(1, int(c.get("ap", 1)))
	var no_consume: bool = DeckController.burns(c, "consume") and not dc.has_consume_target(slot)
	# 自分以外の味方が対象（APパサー）：その味方が倒れていれば使えない
	var msg := ""
	if c.get("target", "") == "other_ally" and ActionController.resolve_targets(current, "other_ally", CurrentStatus.allies, CurrentStatus.enemies).is_empty():
		msg = "渡す相手が倒れている"
	# 「最後」の効果しか無いカード（saigo_only）は、最後の条件を満たした時だけ使える
	if c.get("saigo_only", false) and not bool(_play_ctx(c, slot).get("alone", false)):
		msg = "最後の時だけ使える（他の手札・保留が無い時）"
	# play = 実際に発動する行動（キーワード・バッジ・レリックの強化込み。プレビューに使う）
	return {"title": c.name, "desc": desc, "action": c, "play": ActionController.play_action(current, c, _play_ctx(c, slot)),
			"kind": kind, "slot": slot, "ap": cost, "need": need, "no_consume": no_consume, "block_msg": msg}


## カードを使う時の条件（ActionController.play_action の ctx）。slot = -1 は保留枠
## use = true なら実際に使う時：砥石・十連の数珠の回数を進める
func _play_ctx(c: Dictionary, slot: int, use: bool = false) -> Dictionary:
	var dc: DeckController = deck_controllers[current.id]
	# 最後：このカード以外に手札・保留枠のカードが無い
	var alone: bool = slot == -1 or dc.hold == null
	for i in dc.hand.size():
		if i != slot and dc.hand[i] != null:
			alone = false
	var is_atk: bool = c.has("power")
	var whet: bool = Inventory.has_relic("whetstone") and is_atk and not whet_used.get(current.id, false)
	var ros: bool = Inventory.has_relic("rosary") and rosary_ready
	if use:
		if whet:
			whet_used[current.id] = true
		if Inventory.has_relic("rosary"):
			if ros:
				rosary_ready = false
				fx.popup(views[current.uid], "十連の数珠！", ImageController.COL.accent, 30)
			rosary_left -= 1
			if rosary_left <= 0:
				rosary_left = 10
				rosary_ready = true
			for a in CurrentStatus.allies:
				a["rosary"] = 0 if rosary_ready else rosary_left
	return {"swapped": last_swap_round == round_no, "alone": alone, "whet": whet, "rosary": ros}


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
	return DeckController.card_ap(c)  # 軽のバッジは -1


## 必殺技の AP（精神統一中は減る。0 未満にしない）
func _special_cost(sp: Dictionary) -> int:
	return maxi(0, int(sp.get("ap", 0)) - StatusController.focus_cut(current))


# ------------------------------------------------------------
# 必殺技（9 回目・D）
# ------------------------------------------------------------
## 必殺技の実際に使う行動：陣形の左右・虚空連斬の空き数・毒蛇の舞の回数を反映したコピー。
## consumed = true なら消費が発動した後（空き数をそのまま数える）。false なら「これから消費する 1 枚」も空きに数える（プレビュー）
## ※ C のボスレリック（双星の宝冠・双翼の紋章）の効果量・対象の差し替えは、この関数の最後で a を変えて足す
func _special_play(sp: Dictionary, consumed: bool = false) -> Dictionary:
	var a: Dictionary = sp.duplicate(true)
	# 陣形の札：左（lane 0）／右（lane 1）の行動に差し替える
	if sp.get("left") is Dictionary and sp.get("right") is Dictionary:
		var side: Dictionary = (sp.left if int(current.get("lane", 0)) == 0 else sp.right)
		a.erase("power")
		a.erase("effects")
		a.merge(side.duplicate(true), true)
	# 虚空連斬：カードアクション（手札 4 枠＋保留枠）の空き数 × n
	if sp.get("void_hits") is Dictionary:
		var vh: Dictionary = sp.void_hits
		var n := _card_empties()
		if not consumed and deck_controllers.has(current.get("id", "")) and (deck_controllers[current.id] as DeckController).has_consume_target(-1):
			n += 1
		a["power"] = n * int(vh.get("power_per", 0))
		a["effects"] = [{"effect": "add_shield", "eff_val": n * int(vh.get("shield_per", 0)), "to": "self"}]
		a["void_n"] = n
	# 毒蛇の舞：毒が付いた敵が 1 体でもいれば poison_hits 回攻撃
	if int(sp.get("poison_hits", 0)) > 0:
		if CurrentStatus.enemies.any(func(e): return int(e.hp) > 0 and StatusController.val(e, "poison") > 0):
			a["hits"] = int(sp.poison_hits)
	return a


## カードアクションの空き数（手札 4 枠の空き＋保留枠が空なら 1）
func _card_empties() -> int:
	var dc: DeckController = deck_controllers.get(current.get("id", ""), null)
	if dc == null:
		return 0
	var n := 0
	for c in dc.hand:
		if c == null:
			n += 1
	if dc.hold == null:
		n += 1
	return n


## 必殺技を今使えないわけ（"" = 使える）。即応の条件・消費する手札
func _special_block(sp: Dictionary) -> String:
	if sp.get("sokuou_only", false) and not ActionController.keyword_on(current, "sokuou", {"swapped": last_swap_round == round_no}):
		return "即応の時だけ使える（このラウンドに入替をした時）"
	if DeckController.burns(sp, "consume"):
		var dc: DeckController = deck_controllers.get(current.get("id", ""), null)
		if dc == null or not dc.has_consume_target(-1):
			return "消費する手札がない"
	return ""


## 必殺技を使う（AP は払った後）。消費の札は先に手札から 1 枚捨ててから、空き数を数え直して発動
func _use_special(dc: DeckController) -> void:
	var sp: Dictionary = specials[current.id]
	var consumed := false
	if DeckController.burns(sp, "consume"):
		var cs := dc.consume_random(-1)
		if cs >= 0:
			var gone: GuiCard = hand_cards[cs]
			_fly_card(gone, Vector2(0, 1))
			gone.visible = false
			var gone_card: Dictionary = dc.discard_pile.back()
			_log("消費：%sを捨てた" % gone_card.get("name", ""))
			_ash_altar()
		consumed = true
	var act := _boss_mod(current, _special_play(sp, consumed), true)  # ボスレリック（双翼の紋章・双星の宝冠）
	var evs := _play(act)
	for ev in evs:
		if ev.has("purge"):
			var t: Dictionary = ev.target
			fx.popup(views[t.uid], "浄化！" if int(ev.get("purge_bonus", 0)) <= 0 else "浄化！ 攻防+%d" % int(ev.purge_bonus), ImageController.COL.good, 30)
	if act.has("void_n"):
		fx.popup(views[current.uid], "空き%d" % int(act.void_n), ImageController.COL.accent, 28)


# ------------------------------------------------------------
# アイテム（9 回目・D）
# ------------------------------------------------------------
var last_fate := {}  # 運命のダイスの直前の出目（Item_List.FATE の要素。テスト用）


## アイテムを今使えないわけ（"" = 使える）
func _item_block(it: Dictionary) -> String:
	if str(it.get("need", "")) == "prophecy":
		var dc: DeckController = deck_controllers.get(current.get("id", ""), null)
		if dc == null or dc.hold != null:
			return "保留枠が空の時だけ使える"
		if dc.draw_pile.is_empty():
			return "山札が無い"
	return ""


## アイテムを使う（インベントリから外した後）
func _use_item(it: Dictionary, dc: DeckController) -> void:
	match str(it.get("item_only", "")):
		"prophecy":
			# 予言の栞：山札のランダムなカードを保留枠へ
			if dc.hold == null and not dc.draw_pile.is_empty():
				var i := randi() % dc.draw_pile.size()
				dc.hold = dc.draw_pile[i]
				dc.draw_pile.remove_at(i)
				_log("予言：%sを保留枠へ" % str(dc.hold.get("name", "")))
				_refresh_all()
				if hold_card:
					_pop_in(hold_card, 0.0)
		"fate_dice":
			# 運命のダイス：出目を 1 つ引いて味方全体に
			var f: Dictionary = Item_List.FATE.pick_random()
			last_fate = f
			fx.popup(views[current.uid], "ダイス：%s" % str(f.text), ImageController.COL.accent, 30)
			_log("運命のダイス…%s！" % str(f.text))
			if f.get("fill", false):
				_draw_more(dc, DeckController.HAND_SIZE)
			elif f.has("power"):
				_play({"name": it.name, "type": "attack", "target": "ally_all", "power": int(f.power), "fixed": true})
			else:
				_play({"name": it.name, "type": "skill", "target": "ally_all", "effects": (f.get("effects", []) as Array).duplicate(true)})
		_:
			_play(it)


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
	return str(DeckController.card_ap(a))


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
		var act: Dictionary = info.get("play", info.action)  # カードは強化込みの行動で予想する
		if info.kind in ["card", "hold_play", "unique", "special"]:
			act = _boss_mod(current, act, info.kind == "special")  # ボスレリックの対象の差し替え・必殺技の倍率
		if info.kind == "swap":
			for a in CurrentStatus.allies:
				views[a.uid].preview = {"on": true, "label": "→右" if int(a.lane) == 0 else "→左"}
			return
		if info.kind == "formation":
			for a in CurrentStatus.allies:
				views[a.uid].preview = {"on": true, "label": "→後衛 防+2" if int(a.rank) == 0 else "→前衛 攻+2"}
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
		"heal_pct": return "回復%d%%" % int(e.eff_val)
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
	for k in ["swap", "formation", "hold", "unique", "special", "deck", "status", "end"]:
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
		"swap", "formation":
			current["ap"] = int(current.ap) - ap
			if ap == 0 and Inventory.has_relic("light_boots"):
				boots_used[current.id] = true  # 軽い靴：このターンの AP0 を使った
			if info.kind == "swap":
				_do_swap()
			else:
				_do_formation()
		"item":
			Inventory.remove_item_at(int(info.index))
			_log("%sを使った！" % info.action.name)
			_use_item(info.action, dc)
		"unique":
			current["ap"] = int(current.ap) - ap
			_log("%s！" % info.action.name)
			_play(_boss_mod(current, info.action))
			# 誓いの紋章：キャラ固有スキルを使うと、味方全体にブロック+4
			if Inventory.has_relic("oath"):
				for a in CurrentStatus.allies:
					if int(a.hp) > 0:
						a["shield"] = int(a.get("shield", 0)) + 4
						fx.popup(views[a.uid], "誓い 盾+4", ImageController.COL.shield, 26)
		"special":
			current["ap"] = maxi(0, int(current.ap) - ap)
			_log("必殺！ %s！" % info.action.name)
			fx.shake(10.0)
			_use_special(dc)
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
	var ap_before := int(current.ap)  # 二連詠唱：使う前の AP
	current["ap"] = maxi(0, int(current.ap) - int(info.ap))
	# 実際に発動する行動：キーワード（条件は使う前の手札で判定）・バッジ・砥石・十連の数珠の強化込み
	var ctx0 := _play_ctx(c, slot)
	var on_kw: Array = (c.get("keywords", []) as Array).filter(func(k): return str(k) in ["sokuou", "saigo", "tenshin"] and ActionController.keyword_on(current, str(k), ctx0))
	var pctx := _play_ctx(c, slot, true)
	pctx["ap_before"] = ap_before
	var act := ActionController.play_action(current, c, pctx)
	act = _boss_mod(current, act)  # ボスレリック「双翼の紋章」：対象の差し替え
	if not on_kw.is_empty():
		fx.popup(views[current.uid], "%s！" % DeckController.KW_NAME[on_kw[0]], ImageController.COL.accent, 30)
	# 消費：ほかの手札からランダムに 1 枚を捨札へ（残のバッジなら無効）
	if DeckController.burns(c, "consume"):
		var cs := dc.consume_random(slot)
		if cs >= 0:
			var gone: GuiCard = hand_cards[cs]
			_fly_card(gone, Vector2(0, 1))
			gone.visible = false
			var gone_card: Dictionary = dc.discard_pile.back()
			_log("消費：%sを捨てた" % gone_card.get("name", ""))
			_ash_altar()
	if slot >= 0:
		_fly_card(hand_cards[slot], dir)
		dc.play_and_discard(slot)
	else:
		_fly_card(hold_card, dir)
		dc.play_hold()
	if DeckController.burns(c, "exhaust"):
		_ash_altar()
	var kills := _play_card(act, x)
	current["cards_used"] = int(current.get("cards_used", 0)) + 1  # 怒涛の締めの X（このターンに使ったカードの枚数）
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


## 灰の祭壇：消費・廃棄が発動した時、その味方にブロック+3
func _ash_altar() -> void:
	_power_burn_trigger()  # 焦土の誓い：消費・廃棄が発動するたび（灰の祭壇と同じ所で数える）
	if not Inventory.has_relic("ash_altar"):
		return
	current["shield"] = int(current.get("shield", 0)) + 3
	fx.popup(views[current.uid], "灰の祭壇 盾+3", ImageController.COL.shield, 26)


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
		var evs := _play(card, x)
		for ev in evs:
			if ev.get("kill", false):
				kills += 1
		_power_card_triggers(card, evs)  # パワーの「カードが発動するたび」
		_end_if_won()
	return kills


## カード・スキル・必殺技・アイテムの効果。イベントを返す
func _play(act: Dictionary, x: int = 1) -> Array:
	var events := _perform(current, act, x)
	if _all_dead(CurrentStatus.enemies) or current.hp <= 0:
		phase = "busy"
		turn_done.emit.call_deferred()
	return events


# ------------------------------------------------------------
# パワー（8 回目の新カード）。power_effect の形は ActionList の説明を参照
#   手札に入った時に _power_enter が効果を出し、トリガー型・計算型は持ち主の powers に入れる（次の自分のターン開始で空にする）
#   「〜するたび」は味方のどちらで起きても、効いている全員のパワーが発動する（炎の守りだけは持ち主のカード）
# ------------------------------------------------------------

## 自分のターン開始：前のターンのパワーを外す（鼓舞でもう 1 人に渡した攻撃力も）。使ったカードの枚数を 0 に
func _power_reset(u: Dictionary) -> void:
	u["powers"] = []
	u["cards_used"] = 0
	for a in CurrentStatus.allies:
		var aid: Dictionary = a.get("aid_atk", {})
		aid.erase(u.id)
		var aid_d: Dictionary = a.get("aid_def", {})
		aid_d.erase(u.id)  # 鋼鉄化（味方全体）でもう 1 人に渡した防御力


## パワーカードが手札に入った時（そのターンに 1 回）
func _power_enter(u: Dictionary, dc: DeckController, c: Dictionary) -> void:
	var pe: Dictionary = (c.get("power_effect", {}) as Dictionary).duplicate(true)
	if ActionList.has_keyword(c, "jinkei"):
		pe = (pe.get("left" if int(u.get("lane", 0)) == 0 else "right", {}) as Dictionary).duplicate(true)
	var col: Color = ImageController.COL.good
	match str(pe.get("status", "")):
		"atk_buff":
			u["power_atk"] = int(u.get("power_atk", 0)) + int(pe.eff_val)
			fx.popup(views[u.uid], "攻 +%d" % int(pe.eff_val), col, 26)
		"def_buff":
			u["power_def"] = int(u.get("power_def", 0)) + int(pe.eff_val)
			fx.popup(views[u.uid], "防 +%d" % int(pe.eff_val), col, 26)
	# 鋼鉄化・フォース（9 回目）："all" なら、もう 1 人の味方にも同じ分（次の持ち主のターンまで）
	if pe.get("all", false) and str(pe.get("status", "")) in ["atk_buff", "def_buff"]:
		var key := "aid_atk" if str(pe.status) == "atk_buff" else "aid_def"
		for a in CurrentStatus.allies:
			if a != u and int(a.hp) > 0:
				var ad: Dictionary = a.get(key, {})
				ad[u.id] = int(ad.get(u.id, 0)) + int(pe.eff_val)
				a[key] = ad
				fx.popup(views[a.uid], "%s +%d" % ["攻" if key == "aid_atk" else "防", int(pe.eff_val)], col, 26)
	# 鼓舞（右）：もう 1 人の攻撃力 +n（次の自分のターンまで）
	if int(pe.get("aid_atk", 0)) > 0:
		for a in CurrentStatus.allies:
			if a != u and int(a.hp) > 0:
				var aid: Dictionary = a.get("aid_atk", {})
				aid[u.id] = int(aid.get(u.id, 0)) + int(pe.aid_atk)
				a["aid_atk"] = aid
				fx.popup(views[a.uid], "攻 +%d" % int(pe.aid_atk), col, 26)
	# 手札に入った時に 1 回だけの効果
	var once: Array = pe.get("once", [])
	if not once.is_empty():
		var evs := ActionController.execute_action(u, {"target": "self", "effects": once}, CurrentStatus.allies, CurrentStatus.enemies)
		_tally(evs)
		_show_events(evs, {})
	if pe.has("kind"):
		var list: Array = u.get("powers", [])
		list.append(pe)
		u["powers"] = list
		fx.popup(views[u.uid], c.get("name", ""), col, 24)
	# 天啓：効果の後すぐ廃棄札へ（残のバッジなら手札に残る）
	if pe.get("exhaust_now", false) and DeckController.burns(c, "exhaust"):
		for i in dc.hand.size():
			if dc.hand[i] != null and is_same(dc.hand[i], c):
				dc.hand[i] = null
				dc.exhaust_pile.append(c)
				_fly_card(hand_cards[i], Vector2.UP)
				_log("%sを発動して廃棄した" % c.get("name", ""))
				_ash_altar()
				break


## 今効いているパワー（倒れた持ち主のものは除く）：[[持ち主, power_effect], ...]
func _powers_of(kind: String) -> Array:
	var out: Array = []
	for a in CurrentStatus.allies:
		if int(a.hp) <= 0:
			continue
		for pe in a.get("powers", []):
			if str((pe as Dictionary).get("kind", "")) == kind:
				out.append([a, pe])
	return out


## パワーのダメージ（固定ダメージ。攻撃力・防御力は見ず、ブロックは削る）
func _power_hit(owner: Dictionary, act: Dictionary) -> void:
	if _all_dead(CurrentStatus.enemies):
		return
	owner["rand_seq"] = randi()
	var evs := ActionController.execute_action(owner, act, CurrentStatus.allies, CurrentStatus.enemies)
	_tally(evs)
	_show_events(evs, act)
	_update_deaths(owner)


## 自分の手番中に敵を全滅させたら手番を終える（_play と同じ。二重に終えない）
func _end_if_won() -> void:
	if phase == "player" and (_all_dead(CurrentStatus.enemies) or int(current.get("hp", 1)) <= 0):
		phase = "busy"
		turn_done.emit.call_deferred()


## カードが 1 回発動するたび（連続魔法の 2 回目も数える）。card = 発動した行動、evs = そのイベント
func _power_card_triggers(card: Dictionary, evs: Array) -> void:
	if current.get("side", "") != "ally":
		return
	var kws: Array = card.get("keywords", [])
	var plain: bool = kws.is_empty() and not card.get("ap_x", false)  # 札の無いカード
	var is_attack: bool = str(card.get("type", "")) == "attack"
	var debuff := false  # 状態異常を敵に付けた
	var hit: Array = []  # 当たった敵
	for ev in evs:
		var t: Dictionary = ev.get("target", {})
		if t.is_empty() or str(t.get("side", "")) != "enemy":
			continue
		if ev.has("damage") and not hit.has(t):
			hit.append(t)
		if ev.has("status") and not ev.get("reflect", false) and not StatusEffectList.DATA.get(str(ev.status), {}).get("good", false):
			debuff = true
	# 連撃の気迫（9 回目）：即応・転身の札が付いたカードが発動するたび。即応：さらに +sokuou_add
	for p in _powers_of("on_kw_card"):
		if (p[1].get("kws", []) as Array).any(func(k): return kws.has(k)):
			var dmg2 := int(p[1].get("dmg", 0)) + (int(p[1].get("sokuou_add", 0)) if last_swap_round == round_no else 0)
			_power_hit(p[0], {"name": "連撃の気迫", "power": dmg2, "fixed": true, "target": "enemy_all"})
	if plain:
		for p in _powers_of("on_plain_card"):
			var dmg := int(p[1].get("dmg", 0)) + (int(p[1].get("sokuou_add", 0)) if last_swap_round == round_no else 0)
			_power_hit(p[0], {"name": "連撃の気迫", "power": dmg, "fixed": true, "target": "enemy_all"})
	if is_attack:
		for p in _powers_of("on_attack_poison"):
			var pevs: Array = []
			for t in hit:
				if int(t.hp) > 0:
					var ev2 := {"target": t}
					ActionController._apply_effect(p[0], t, {"effect": "add_status", "status": "poison", "eff_val": int(p[1].get("eff_val", 1))}, ev2)
					pevs.append(ev2)
			_show_events(pevs, {})
	if debuff:
		for p in _powers_of("on_debuff_card"):
			var o: Dictionary = p[0]
			o["shield"] = int(o.get("shield", 0)) + int(p[1].get("shield", 0))
			fx.popup(views[o.uid], "呪術の加護 盾+%d" % int(p[1].get("shield", 0)), ImageController.COL.shield, 24)
	for p in _powers_of("on_own_card"):
		if p[0] != current:
			continue
		var fevs: Array = []
		for a in CurrentStatus.allies:
			if a != current and int(a.hp) > 0:
				var ev3 := {"target": a}
				ActionController._apply_effect(current, a, {"effect": "add_status", "status": "fire", "eff_val": int(p[1].get("fire", 1))}, ev3)
				fevs.append(ev3)
				a["shield"] = int(a.get("shield", 0)) + int(p[1].get("shield", 0))
				fevs.append({"target": a, "shield": int(p[1].get("shield", 0))})
		_show_events(fevs, {})
	# 狩人の本能：kws（9 回目は陣形・予約。無ければ撃破）の札が付いたカードを使うたび
	for p in _powers_of("on_gekiha_card"):
		if (p[1].get("kws", ["gekiha"]) as Array).any(func(k): return kws.has(k)):
			StatusController.apply_status(p[0], "atk_buff", int(p[1].get("atk", 1)), -1)
			fx.popup(views[p[0].uid], "狩人の本能 攻+%d" % int(p[1].get("atk", 1)), ImageController.COL.good, 24)


## 焦土の誓い：消費・廃棄が 1 回発動するたび
func _power_burn_trigger() -> void:
	for p in _powers_of("on_burn"):
		_power_hit(p[0], {"name": "焦土の誓い", "power": int(p[1].get("dmg", 0)), "fixed": true, "target": "enemy_all"})


## 断罪の連鎖：イベントの中の撃破（{"gekiha": n}）・反撃（{"hangeki": true}。攻撃してきた敵ごとに 1 回）を数えて発動
func _power_marks(evs: Array) -> void:
	var list := _powers_of("on_gekiha_hangeki")
	if list.is_empty():
		return
	var n := 0
	var counter_from: Array = []
	for ev in evs:
		if ev.has("gekiha"):
			n += 1
		elif ev.get("hangeki", false):
			var t: Dictionary = ev.get("target", {})
			if not counter_from.has(t):
				counter_from.append(t)
				n += 1
	for i in n:
		for p in list:
			_power_hit(p[0], {"name": "断罪の連鎖", "power": int(p[1].get("power", 2)), "hits": int(p[1].get("hits", 5)), "fixed": true,
					"target": "random_enemy", "reroll": true})
	_end_if_won()


## ターン終了時に手札にあるパワー：薬師の加護（薬草を得て廃棄）・魔力の転換（他の手札 1 枚を消費し、その AP 分 AP+）
func _power_turn_end(u: Dictionary, dc: DeckController) -> void:
	for i in dc.hand.size():
		var c = dc.hand[i]
		if c == null or not ActionList.has_keyword(c, "power"):
			continue
		match str((c.get("power_effect", {}) as Dictionary).get("kind", "")):
			"end_herb":
				var got: bool = Inventory.add_item("herb")
				fx.popup(views[u.uid], "薬草を得た" if got else "アイテムがいっぱい", ImageController.COL.good if got else ImageController.COL.bad, 26)
				_log("薬師の加護：%s" % ("薬草を得た" if got else "アイテムがいっぱいで得られない"))
				if DeckController.burns(c, "exhaust"):
					dc.hand[i] = null
					dc.exhaust_pile.append(c)
					_fly_card(hand_cards[i], Vector2.UP)
					_ash_altar()
				_refresh_all()
				await _wait(0.3)
			"end_convert":
				if not DeckController.burns(c, "consume"):
					continue
				var cs := dc.consume_random(i)
				if cs < 0:
					continue
				var gone: Dictionary = dc.discard_pile.back()
				var gain := DeckController.card_ap(gone) if gone.has("ap") else 0
				u["ap"] = mini(int(u.get("max_ap", InitAllyStatus.AP_MAX)), int(u.ap) + gain)
				_fly_card(hand_cards[cs], Vector2(0, 1))
				fx.popup(views[u.uid], "魔力の転換 AP+%d" % gain, ImageController.COL.ap, 28)
				_log("魔力の転換：%sを捨ててAP+%d" % [gone.get("name", ""), gain])
				_ash_altar()
				_refresh_all()
				await _wait(0.3)


func _draw_more(dc: DeckController, n: int, only_slots: Array = []) -> void:
	for i in dc.draw_cards(n, only_slots):
		_pop_in(hand_cards[i], i * 0.05)


## 入替（7・スワップ等）：左右（lane）だけ入れ替え、前衛・後衛（rank）はそのまま
func _do_swap() -> void:
	for a in CurrentStatus.allies:
		a["lane"] = 1 - int(a.lane)
		_move_ally(a)
	last_swap_round = round_no
	_sync_lanes()
	_update_targets()
	_log("左右を入れ替えた！")


## 陣形変更（1）：味方全員の前衛・後衛（rank）を入れ替える。左右はそのまま
func _do_formation() -> void:
	for a in CurrentStatus.allies:
		a["rank"] = 1 - int(a.get("rank", 0))
		_move_ally(a)
	_sync_lanes()
	_update_targets()
	_log("陣形を変えた！")


## 入替・陣形変更の AP。「軽い靴」があれば、各ターン最初の 1 回は 0
func _move_cost() -> int:
	if Inventory.has_relic("light_boots") and not boots_used.get(current.get("id", ""), false):
		return 0
	return 1


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
		lines.append("AP %d / %d　位置：%s・%s" % [u.ap, int(u.get("max_ap", InitAllyStatus.AP_MAX)), "左（青）" if int(u.lane) == 0 else "右（赤）",
				"前衛（攻撃力+2）" if int(u.get("rank", 0)) == 0 else "後衛（防御力+2）"])
	else:
		lines.append("位置：%s（%s）" % ["前衛" if int(u.get("row", 0)) == 0 else "後衛", str(u.get("slot", ""))])
	for k in u.status_effects:
		if StatusController.RESERVE.has(k):
			continue  # 次のターンに効く状態は「予約」にまとめる
		var st: Dictionary = StatusEffectList.DATA.get(k, {})
		var desc := str(st.get("desc", ""))
		if k == "hangeki":
			# 反撃：攻撃してきた敵に付く効果の中身
			desc = "次の自分のターン開始まで、攻撃してきた敵に %s" % DeckController.effect_text({}, {"effects": u.status_effects.hangeki.get("effects", [])})
		lines.append("[i:%s]%s %s：%s" % [st.get("icon", "star"), st.get("name", k), StatusController.label(u, k), desc])
	var rs := StatusController.reserve_lines(u)
	if not rs.is_empty():
		lines.append("[i:st_reserve]予約：" + "／".join(rs))
	if u.has("rosary"):
		lines.append("[i:r_rosary]十連の数珠：%s" % ("次のカードで発動（アタック＋10ダメージ／スキル＝自分にブロック+10）" if int(u.rosary) <= 0 else "あと%d回カードを使うと発動（2人の合計）" % int(u.rosary)))
	if u.side == "enemy" and StatusController.has(u, "stun"):
		lines.append("[i:st_stun]次の行動：スタン（次のターンは休む）")
	elif u.side == "enemy" and not u.intent.is_empty():
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
				_power_enter(current, dc, c)
		power_seen[current.id] = seen
	_update_intent_values()  # パワー・状態の変化を敵の予告の数字に反映
	for i in hand_cards.size():
		var cv: GuiCard = hand_cards[i]
		var c = dc.hand[i] if dc != null else null
		cv.visible = c != null
		if c != null:
			_set_eff(c, i)
			cv.set_card(c)
			cv.playable = _card_block(c, i) == ""
			cv.queue_redraw()
	hold_card.visible = dc != null and dc.hold != null
	if hold_card.visible:
		_set_eff(dc.hold, -1)
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
		btn.special.dimmed = int(current.ap) < _special_cost(sp) or _special_block(sp) != ""
		btn.special.badge = _special_badge(_boss_mod(current, _special_play(sp), true))
		var mc := _move_cost()
		btn.swap.ap_cost = mc
		btn.swap.dimmed = int(current.ap) < mc
		btn.formation.ap_cost = mc
		btn.formation.dimmed = int(current.ap) < mc
		pad.modulate.a = 1.0
	elif phase != "over":
		pad.modulate.a = 0.5
	for b in btn.values():
		b.queue_redraw()
	order_bar.queue_redraw()
	strip.queue_redraw()


## カードに「実際のダメージ」を書き込む（自分の攻撃力と、主な対象の防御力を反映）
## キーワード（即応・最後・陣形・転身）の条件を満たしていれば kw_on に入れ、札を光らせる。slot = -1 は保留枠
func _set_eff(c: Dictionary, slot: int = -1) -> void:
	# 右上の AP の表示（通常は数字、APX は "X"、このターン AP 0 なら "0"）
	if c.has("ap") or c.get("free", false):
		c["ap_show"] = _ap_label(c)
	var ctx := _play_ctx(c, slot)
	var on: Array = []
	for kw in c.get("keywords", []):
		if str(kw) in ["sokuou", "saigo", "jinkei", "tenshin"] and ActionController.keyword_on(current, str(kw), ctx):
			on.append(str(kw))
	c["kw_on"] = on
	if (c.get("keywords", []) as Array).has("jinkei"):
		c["kw_side"] = "左" if int(current.get("lane", 0)) == 0 else "右"
	if c.has("power"):
		c["power_eff"] = ActionController.effective_power(current, ActionController.play_action(current, c, ctx), CurrentStatus.allies, CurrentStatus.enemies)
	else:
		c.erase("power_eff")


## 必殺技ボタンの左上の効果量：攻撃は主な対象への実際のダメージ（カードの power_eff と同じ計算）、
## ブロックは盾の量。数値の無い必殺技は {}（出さない）
func _special_badge(sp: Dictionary) -> Dictionary:
	if sp.has("power"):
		return {"kind": "power", "val": ActionController.effective_power(current, sp, CurrentStatus.allies, CurrentStatus.enemies),
				"base": int(sp.power)}
	for eff in ActionList.effects_of(sp):
		if eff.get("effect", "") == "add_shield":
			return {"kind": "shield", "val": int(eff.get("eff_val", 0))}
	return {}


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
		if int(current.ap) >= _special_cost(sp) and _special_block(sp) == "" and sp.id != "w_sp_turnskip" and guard == 1 and randf() < 0.5:
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


# ============================================================
# ボスレリック・ラスボス（9 回目・C）
# ============================================================
const BOSS_EXTRA_RATE := 0.25  # 星詠みの砂時計・騎士王の角笛の確率
const ENEMY_TARGETS := ["front_pair", "front_enemy_single", "front_enemy_group", "random_enemy", "back_row", "front_row"]
const ALLY_TARGETS := ["self", "other_ally"]
const SELF_ONLY_EFFECTS := ["draw", "swap", "double", "turnabout", "extra_turn", "rank_swap", "rank_to", "repeat", "add_ap"]  # 味方全体にしても持ち主だけに効く効果


## 暁の聖杯：ターン開始時 AP+1
func _boss_ap_bonus() -> int:
	return 1 if Inventory.has_relic("boss_ap") else 0


## ラウンド開始：星詠みの砂時計（ウィッチ）・騎士王の角笛（ナイト）が 25% で当たれば、行動順の末尾にそのキャラの追加ターン
func _boss_round_start() -> void:
	boss_extra = {"knight": false, "witch": false}
	for pair in [["boss_knight_turn", "knight"], ["boss_witch_turn", "witch"]]:
		if not Inventory.has_relic(pair[0]) or randf() >= BOSS_EXTRA_RATE:
			continue
		var a := CurrentStatus.ally(pair[1])
		if a.is_empty() or int(a.hp) <= 0:
			continue
		boss_extra[pair[1]] = true
		action_order.append(a)
		_log("%s：%sの追加ターン！" % [RelicList.DATA[pair[0]].name, a.name])


## 封印の聖櫃：ターン開始時、保留カードがあれば AP を使わずに自動で発動する（使えない条件のカードはそのまま）
func _boss_hold_auto(u: Dictionary, dc: DeckController) -> void:
	if not Inventory.has_relic("boss_hold") or dc.hold == null or phase != "player":
		return
	var c: Dictionary = dc.hold
	if c.get("type", "") == "unselectable" or ActionList.has_keyword(c, "power"):
		return
	var info := _card_info(c, -1, "hold_play", "")
	if info.no_consume or str(info.block_msg) != "":
		return
	info["ap"] = 0
	fx.popup(views[u.uid], "封印の聖櫃！", ImageController.COL.accent, 28)
	_log("封印の聖櫃：%sが自動で発動" % c.get("name", ""))
	_use_card(info, dc, Vector2.UP)
	_refresh_all()


## 必殺技の倍率（双星の宝冠）。kind = "dmg"（左＝青のキャラ）/ "block"（右＝赤のキャラ）。D の必殺技で計算するダメージ・ブロックにも掛ける
func boss_special_mult(user: Dictionary, kind: String) -> int:
	if not Inventory.has_relic("boss_special") or user.get("side", "") != "ally":
		return 1
	var left := int(user.get("lane", 0)) == 0
	if kind == "dmg":
		return 2 if left else 1
	return 1 if left else 2


## ボスレリックで行動を書き換えたコピーを返す（持っていなければそのまま）
## 双翼の紋章：前衛（rank 0）のキャラは敵が対象→敵全体、後衛（rank 1）は味方が対象→味方全体
## 双星の宝冠（is_special のとき）：左のキャラはダメージ 2 倍、右のキャラはブロック 2 倍
func _boss_mod(user: Dictionary, act: Dictionary, is_special: bool = false) -> Dictionary:
	if act.get("_boss_mod", false) or user.get("side", "") != "ally":
		return act
	var form := Inventory.has_relic("boss_formation")
	var crown := is_special and Inventory.has_relic("boss_special")
	if not form and not crown:
		return act
	var a: Dictionary = act.duplicate(true)
	a["_boss_mod"] = true
	if form:
		var tgt := str(a.get("target", "self"))
		var front := int(user.get("rank", 0)) == 0
		if front and tgt in ENEMY_TARGETS:
			a["target"] = "enemy_all"
		elif not front:
			var to_all := tgt in ALLY_TARGETS
			if to_all:
				a["target"] = "ally_all"
			if a.has("effects"):
				var effs: Array = []
				for e in a.effects:
					var ed: Dictionary = (e as Dictionary).duplicate(true)
					var k := str(ed.get("effect", ""))
					var to := str(ed.get("to", "target"))
					if k in SELF_ONLY_EFFECTS:
						if to_all and to == "target":
							ed["to"] = "self"  # 引く・入替などは持ち主だけ
					elif to in ALLY_TARGETS:
						ed["to"] = "ally_all"
					effs.append(ed)
				a["effects"] = effs
	if crown:
		if boss_special_mult(user, "dmg") > 1 and a.has("power"):
			a["power"] = int(a.power) * 2
		if boss_special_mult(user, "block") > 1 and a.has("effects"):
			for e in a.effects:
				if str(e.get("effect", "")) == "add_shield":
					e["eff_val"] = int(e.get("eff_val", 0)) * 2
	return a


## ラスボス：HP が phase2_at（50%）以下になったら第 2 段階（行動が全体攻撃＋スタン入りに変わる。デバフを払う）
func _lastboss_check() -> void:
	for e in CurrentStatus.enemies:
		if int(e.get("phase", 0)) != 1 or int(e.hp) <= 0:
			continue
		var base: Dictionary = EnemyList.DATA.get(str(e.get("base_id", "")), {})
		if not base.has("phase2_actions") or float(e.hp) > float(e.max_hp) * float(base.get("phase2_at", 0.5)):
			continue
		e["phase"] = 2
		e["actions"] = (base.phase2_actions as Array).duplicate()
		for sid in ["fire", "poison", "atk_down", "def_down", "no_heal", "stun"]:
			StatusController.remove(e, sid)
		e["next_action"] = "twin_charge"
		_choose_intent(e)
		_log("%sが第2段階へ！" % e.name)
		if views.has(e.uid):
			fx.popup(views[e.uid], "第2段階！", ImageController.COL.red, 38)
		if ImageController.get("light_mode") != true:
			fx.shake(14.0)
