extends Control
class_name GuiAcquire
## 「手に入れる」流れの共通部品（宝箱・ショップ・イベント・戦闘報酬で使う）
##   GuiAcquire.relic(parent, relic_id, done)  … レリックの獲得演出。5 つの時は交換画面。done.call(got: bool)
##   GuiAcquire.badge(parent, badge_id, done)  … デッキ一覧で付けるカードを選ぶ。done.call(attached: bool)
##   GuiAcquire.card(parent, deck_id, done)    … カードを持ち主のデッキへ加える演出。done.call(true)
## どれも parent の上に全画面のオーバーレイを重ね、終わったら自分を消してから done を呼ぶ。

var mode := ""  # relic / swap / card
var item_id := ""  # レリックID か デッキの ID
var done_cb := Callable()
var _t := 0.0
var _deco: Control
var _rows: Array = []  # 交換画面の行（Button）
var _row_ids: Array = []
var _picked := ""  # 交換画面で選んだ「捨てる」レリック（新しい方なら諦める）
var _ok_btn: Button
var _finished := false
var _card_view: GuiCard


# ------------------------------------------------------------
# 入口
# ------------------------------------------------------------
## レリックを手に入れる。空きがあれば加えて演出、5 つなら交換画面。持っているレリックなら何もせず done(false)
static func relic(parent: Node, relic_id: String, done: Callable) -> void:
	if not RelicList.DATA.has(relic_id) or Inventory.has_relic(relic_id):
		if done.is_valid():
			done.call(false)
		return
	var v := GuiAcquire.new()
	v.item_id = relic_id
	v.done_cb = done
	if Inventory.relics_full():
		v.mode = "swap"
	else:
		Inventory.add_relic(relic_id)
		v.mode = "relic"
	parent.add_child(v)


## バッジを付ける。デッキ一覧（両キャラのタブ）で付けるカードを選ぶ。やめれば done(false)
static func badge(parent: Node, badge_id: String, done: Callable) -> void:
	if not BadgeList.DATA.has(badge_id):
		if done.is_valid():
			done.call(false)
		return
	var state := {"attached": false}
	var v := GuiDeckView.open_badge(parent, badge_id, func(char_id: String, index: int):
		var before: String = str(CurrentDeck.decks[char_id][index])
		CurrentDeck.attach_badge(char_id, index, badge_id)
		state.attached = true
		var c := ActionList.make_card(before)
		UiSystem.toast(parent, "%sに%sを付けた！" % [c.get("name", ""), BadgeList.DATA[badge_id].name], 600, ImageController.COL.good))
	v.closed.connect(func():
		if done.is_valid():
			done.call(bool(state.attached)))


## カード（バッジ付きも）を持ち主のデッキへ加える演出
static func card(parent: Node, deck_id: String, done: Callable) -> void:
	var c := ActionList.make_card(deck_id)
	if c.is_empty():
		if done.is_valid():
			done.call(false)
		return
	CurrentDeck.add_card(str(c.owner), deck_id)
	var v := GuiAcquire.new()
	v.mode = "card"
	v.item_id = deck_id
	v.done_cb = done
	parent.add_child(v)


# ------------------------------------------------------------
# 画面
# ------------------------------------------------------------
func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(720, 1280)
	z_index = 300
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.82)
	bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_deco = Control.new()
	_deco.size = size
	_deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deco.draw.connect(_draw_deco)
	add_child(_deco)
	match mode:
		"relic": _build_relic()
		"swap": _build_swap()
		"card": _build_card()


func _process(delta: float) -> void:
	_t += delta
	_deco.queue_redraw()


func _draw_deco() -> void:
	var IC = ImageController
	var col: Dictionary = IC.COL
	if mode == "relic":
		# 回る赤いギザギザ＋黒い芯の上に大きなアイコン
		var c := Vector2(360, 470)
		var pop := minf(1.0, _t / 0.25)
		IC.halftone(_deco, Rect2(60, 230, 600, 480), Color(col.paper, 0.08), c, 300, 18, 6)
		_deco.draw_colored_polygon(IC.burst_pts(c, 230 * pop, 160 * pop, 16, 4, _t * 0.3), Color(col.red, 0.9))
		_deco.draw_colored_polygon(IC.burst_pts(c, 170 * pop, 130 * pop, 16, 9, -_t * 0.22), col.ink)
		_deco.draw_circle(c, 118 * pop, col.ink)
		_deco.draw_arc(c, 118 * pop, 0, TAU, 48, col.paper, 4.0, true)
		IC.icon(_deco, RelicList.DATA[item_id].icon, c, 170 * pop * (1.0 + 0.03 * sin(_t * 4.0)))
	elif mode == "card":
		var c := Vector2(360, 560)
		var pop := minf(1.0, _t / 0.2)
		_deco.draw_colored_polygon(IC.burst_pts(c, 260 * pop, 190 * pop, 18, 6, _t * 0.3), Color(col.red, 0.85))
		_deco.draw_colored_polygon(IC.burst_pts(c, 200 * pop, 160 * pop, 18, 2, -_t * 0.2), col.ink)


## 普通の獲得（空きがあった）
func _build_relic() -> void:
	var col: Dictionary = ImageController.COL
	var d: Dictionary = RelicList.DATA[item_id]
	UiSystem.make_banner(self, "レリック獲得！", Rect2(110, 120, 500, 92), 46)
	UiSystem.make_banner(self, d.name, Rect2(90, 740, 540, 78), 38, col.paper, col.ink, 22)
	UiSystem.make_bubble(self, Rect2(60, 850, 600, 140), Vector2(360, 820), 3)
	var l := UiSystem.make_label(self, d.desc, Vector2(84, 856), Vector2(552, 128), 24, col.ink, HORIZONTAL_ALIGNMENT_CENTER, 0)
	l.add_theme_font_override("font", ImageController.font_bold)
	UiSystem.make_label(self, "所持レリック %d / %d" % [Inventory.relics.size(), RelicList.MAX], Vector2(60, 1010), Vector2(600, 40), 22, col.sub, HORIZONTAL_ALIGNMENT_CENTER, 4)
	_ok_btn = UiSystem.make_red_button(self, "OK", Vector2(200, 1080), Vector2(320, 90), func(): finish(true), 32)


## 交換画面：今の 5 つ＋新しい 1 つから「捨てる 1 つ」を選ぶ（新しい方を選べば諦める）
func _build_swap() -> void:
	var col: Dictionary = ImageController.COL
	UiSystem.make_banner(self, "レリックがいっぱい！", Rect2(80, 40, 560, 80), 40)
	UiSystem.make_label(self, "持てるのは%dつまで。捨てるレリックを1つ選んでください\n（新しいレリックを選ぶと、それを諦めます）" % RelicList.MAX,
			Vector2(30, 128), Vector2(660, 76), 20, col.paper, HORIZONTAL_ALIGNMENT_CENTER, 4)
	_row_ids = Inventory.relics.duplicate()
	_row_ids.append(item_id)
	var y := 214.0
	for i in _row_ids.size():
		var rid: String = _row_ids[i]
		var is_new := i == _row_ids.size() - 1
		if is_new:
			y += 22  # 新しいものは少し離して置く
		var b := UiSystem.make_button(self, "", Vector2(40, y), Vector2(640, 116), _pick_row.bind(rid), 20)
		var face := Control.new()
		face.size = b.size
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.draw.connect(_draw_row.bind(face, rid, is_new))
		b.add_child(face)
		_rows.append(b)
		y += 128
	_ok_btn = UiSystem.make_red_button(self, "捨てるレリックを選ぶ", Vector2(60, 1124), Vector2(380, 92), confirm, 26)
	_ok_btn.disabled = true
	UiSystem.make_button(self, "諦める", Vector2(460, 1124), Vector2(200, 92), func(): finish(false), 26)


func _draw_row(face: Control, rid: String, is_new: bool) -> void:
	var IC = ImageController
	var col: Dictionary = IC.COL
	var d: Dictionary = RelicList.DATA[rid]
	var sel := _picked == rid
	face.draw_circle(Vector2(62, 58), 44, col.red if is_new else col.steel)
	face.draw_arc(Vector2(62, 58), 44, 0, TAU, 32, col.paper, 3.0, true)
	IC.icon(face, d.icon, Vector2(62, 58), 66)
	face.draw_string(IC.font_bold, Vector2(120, 42), d.name, HORIZONTAL_ALIGNMENT_LEFT, 380, 26, col.paper)
	if is_new:
		IC.slant(face, Rect2(520, 12, 96, 34), col.red, 8, 2.0, col.paper)
		IC.head(face, "NEW", Vector2(568, 29), 22, col.paper, 80)
	if sel:
		IC.slant(face, Rect2(420, 12, 196 if not is_new else 92, 34), col.paper, 8, 2.0, col.ink)
		IC.head(face, "諦める" if is_new else "捨てる", Vector2(518 if not is_new else 466, 29), 20, col.red, 84)
	IC.rich_text(face, d.desc, Vector2(120, 56), 19, col.text, 500, 0, 25)


func _pick_row(rid: String) -> void:
	_picked = rid
	for i in _rows.size():
		UiSystem.set_button_red(_rows[i], _row_ids[i] == rid)
		_rows[i].get_child(0).queue_redraw()
	_ok_btn.disabled = false
	_ok_btn.text = "新しい方を諦める" if rid == item_id else "捨てて入れ替える"


## 交換画面の決定（テストからも呼ぶ）。新しい方を選んでいれば諦める
func confirm() -> void:
	if _picked == "":
		return
	if _picked == item_id:
		finish(false)
		return
	var old: String = _picked
	Inventory.swap_relic(old, item_id)
	UiSystem.toast(get_parent(), "%s → %s" % [RelicList.DATA[old].name, RelicList.DATA[item_id].name], 600, ImageController.COL.good)
	finish(true)


## 交換画面で捨てるものを選ぶ（テスト用の入口。行のボタンと同じ）
func choose(rid: String) -> void:
	if _row_ids.has(rid):
		_pick_row(rid)


## カードの獲得演出：中央で大きく見せてから下へ飛ばす。タップで飛ばせる
func _build_card() -> void:
	var col: Dictionary = ImageController.COL
	var c := ActionList.make_card(item_id)
	var owner_name: String = InitAllyStatus.DATA[c.owner].name
	UiSystem.make_banner(self, "%sのデッキに追加！" % owner_name, Rect2(70, 210, 580, 86), 38)
	_card_view = GuiCard.new()
	_card_view.set_card(c)
	_card_view.interactive = false
	_card_view.base_scale = 2.0
	_card_view.position = Vector2(360, 560) - GuiCard.SIZE / 2.0
	_card_view.scale = Vector2(0.4, 0.4)
	add_child(_card_view)
	_card_view.pivot_offset = GuiCard.SIZE / 2.0
	var tw := create_tween()
	tw.tween_property(_card_view, "scale", Vector2(2.0, 2.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var line := DeckController.plain(DeckController.card_text({}, c))
	UiSystem.make_bubble(self, Rect2(60, 780, 600, 150), Vector2(360, 720), 5)
	var l := UiSystem.make_label(self, line, Vector2(82, 786), Vector2(556, 138), 19, col.ink, HORIZONTAL_ALIGNMENT_LEFT, 0)
	l.add_theme_font_override("font", ImageController.font_bold)
	_ok_btn = UiSystem.make_red_button(self, "OK", Vector2(200, 1000), Vector2(320, 90), _fly_card, 32)
	get_tree().create_timer(1.6, true, false, true).timeout.connect(_fly_card)


func _fly_card() -> void:
	if _finished or _card_view == null:
		return
	_finished = true
	var tw := create_tween()
	tw.tween_property(_card_view, "position", Vector2(560, 1180) - GuiCard.SIZE / 2.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_card_view, "scale", Vector2(0.3, 0.3), 0.28)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.28)
	tw.tween_callback(func():
		var cb := done_cb
		queue_free()
		if cb.is_valid():
			cb.call(true))


## 閉じて done を呼ぶ（got = 手に入れたか）
func finish(got: bool) -> void:
	if mode == "card":
		_fly_card()
		return
	if _finished:
		return
	_finished = true
	var cb := done_cb
	queue_free()
	if cb.is_valid():
		cb.call(got)
