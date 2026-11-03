extends Control
class_name GuiFlickPad
## 戦闘と同じ 3×5 の操作エリア（左の列 3 つ・中央 3×3・右の列＝デッキ一覧／ステータス／確定）。
## ショップ・休憩所・宝箱で使う。操作は戦闘（Cont_Battle の操作エリア）と同じ：
##   ・指を置いたマスを起点に、弾いた方向の隣のマスを選ぶ（相対フリック）。弾いている間は説明の吹き出しを出す
##   ・長押し（0.9 秒で満タン）で説明の吹き出し。満タンで離すとそのマスを選ぶ（満タン前に離すとキャンセル）
##   ・軽いタップでそのマスを選ぶ（tap_chooses = false なら説明帯に説明を出すだけ）。右の列はタップで選ぶ
## マスの中身は set_cell(key, info) で外から入れる。key は 1〜9 の int、"left0"〜"left2"、"deck"・"status"・"ok"。
## info：
##   title（名前）・icon（アイコン名）・accent（差し色）・desc（吹き出しの本文。[i:..] 可）・short（説明帯の文。省略時は desc）
##   sub（丸いボタンの下の小さい文字）・price（値札の文字。例 "80G"）・card（カードの辞書。あればカードとして描く）
##   enabled（false なら暗く、選ぶと blocked を出す）・sold（売り切れ。暗くして札を出す）・block_msg（使えない理由）
## 画面上の位置は戦闘と同じ（y = 652 から下。マスは y = 764 から 172 ずつ）。親は原点に置いた CanvasLayer を想定。

signal chosen(key)  ## マスが選ばれた（使えるマスだけ）
signal blocked(key)  ## 使えないマス（enabled = false・売り切れ）を選ぼうとした
signal focused(key)  ## プレビュー中のマスが変わった（null＝なし）

const KEYS := [["left0", 7, 8, 9, "deck"], ["left1", 4, 5, 6, "status"], ["left2", 1, 2, 3, "ok"]]
const COLS := 5
const COL_X := [0.0, 104.0, 272.0, 440.0, 608.0, 720.0]  # 列の左端（最後は右端）。戦闘と同じ
const TOP_Y := 652.0  # 画面上の上端（赤い線）
const GRID_TOP := 112.0  # 自分の中でのマスの上端（画面上 764）
const ROW_H := 172.0
const STRIP_Y := 70.0  # 説明帯（画面上 722〜764）
const HEADER_Y := 16.0  # 見出しの帯（画面上 668〜720。戦闘の行動順バーの位置）
const DIR8 := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
const DEADZONE := 48.0
const CHARGE_DELAY := 0.12
const CHARGE_TIME := 0.9
const TAP_TIME := 0.35
## 右の列の既定（set_cell で上書きできる）
const RIGHT_KEYS := {
	"deck": {"title": "デッキ一覧", "icon": "cards", "accent": Color("8fb4ff"), "desc": "ナイトとウィッチのデッキを確認する"},
	"status": {"title": "ステータス", "icon": "info", "accent": Color("8fc0ea"), "desc": "味方のステータスを確認する"},
}

var cells := {}  # key -> info
var widgets := {}  # key -> 表示している部品
var bubble: GuiDescBubble
var tap_chooses := true  # 軽いタップで選ぶ（false なら説明帯に説明を出すだけ）
var locked := false  # true の間は入力を受けない（確認の画面などを出している時）
var hint := "弾いて選ぶ・長押しで説明"  # 何もしていない時の説明帯
var header_left := ""  # 見出しの左（赤い斜めタグ）
var header_right := ""  # 見出しの右（白い斜めタグ）

var _strip_title := ""
var _strip_text := ""
var _strip_col := Color.WHITE
var _tags: Control  # 値札・売り切れの札
var _flash_id := 0

# ジェスチャーの状態（Cont_Battle と同じ考え方）
var g_active := false
var g_start := Vector2.ZERO
var g_origin := Vector2i(1, 1)
var g_time := 0.0
var g_cur = null  # 今の指先が指すマス（null＝なし）
var g_moved := false
var g_charge_target = null
var _desc_key = null


func _init() -> void:
	position = Vector2(0, TOP_Y)
	size = Vector2(720, 1280 - TOP_Y)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 0


func _ready() -> void:
	_tags = Control.new()
	_tags.size = size
	_tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tags.z_index = 31  # 拡大したカード（z 30）よりは上。拡大中のマスの札は描かない
	_tags.draw.connect(_draw_tags)
	add_child(_tags)
	bubble = GuiDescBubble.new()
	bubble.top_level = true  # 画面の座標で置く（吹き出しは操作エリアの上に出る）
	add_child(bubble)
	for k in RIGHT_KEYS:
		if not cells.has(k):
			set_cell(k, RIGHT_KEYS[k])


## マスに指を置ける範囲（説明帯より上は通す）
func _has_point(p: Vector2) -> bool:
	return p.y >= GRID_TOP and p.y <= size.y and p.x >= 0 and p.x <= size.x


# ============================================================
# マスの中身
# ============================================================

func set_cell(key, info: Dictionary) -> void:
	var c := cell_of(key)
	if c.x < 0:
		push_warning("GuiFlickPad: 不明なマス %s" % str(key))
		return
	cells[key] = info
	var w = widgets.get(key)
	var want := _kind_for(c, info)
	if w != null and str(w.get_meta("kind", "")) != want:
		w.queue_free()
		widgets.erase(key)
		w = null
	if w == null:
		w = _make_widget(c, want, key)
		widgets[key] = w
		add_child(w)
		if _tags != null and _tags.get_parent() == self:
			move_child(_tags, -1)
		if bubble != null and bubble.get_parent() == self:
			move_child(bubble, -1)
	_apply(w, c, want, info)
	if _tags:
		_tags.queue_redraw()


func clear_cell(key) -> void:
	cells.erase(key)
	if widgets.has(key):
		widgets[key].queue_free()
		widgets.erase(key)
	if _tags:
		_tags.queue_redraw()


func clear_all() -> void:
	for k in widgets.keys():
		clear_cell(k)
	cells = {}


func get_cell(key) -> Dictionary:
	return cells.get(key, {})


func widget_of(key):
	return widgets.get(key)


## マスの中心（画面の座標）。テスト・吹き出し用
func cell_center_global(key) -> Vector2:
	return global_position + _cell_center(cell_of(key))


func is_usable(key) -> bool:
	var info: Dictionary = cells.get(key, {})
	return not info.is_empty() and bool(info.get("enabled", true)) and not bool(info.get("sold", false))


## 説明帯に一言を出す（col を省略すると白）
func flash(title: String, text: String, col: Color = Color(0, 0, 0, 0)) -> void:
	_strip_title = title
	_strip_text = text
	_strip_col = col if col.a > 0 else ImageController.COL.text
	queue_redraw()
	# 指を離した後の一言（使えない理由など）は少しして消す
	_flash_id += 1
	var my := _flash_id
	if is_inside_tree() and not g_active:
		get_tree().create_timer(1.8).timeout.connect(func():
			if my == _flash_id and not g_active:
				clear_flash())


func clear_flash() -> void:
	_strip_text = ""
	queue_redraw()


func _kind_for(c: Vector2i, info: Dictionary) -> String:
	if info.get("card") is Dictionary and not (info.card as Dictionary).is_empty():
		return "card"
	if c.x == 0:
		return "tile"
	if c.x == COLS - 1:
		return "key"
	return "circle"


func _make_widget(c: Vector2i, kind: String, key) -> Control:
	var w: Control
	match kind:
		"card":
			var gc := GuiCard.new()
			gc.interactive = false
			var sc := 1.0 if (c.x > 0 and c.x < COLS - 1) else 0.72
			gc.base_scale = sc
			gc.scale = Vector2(sc, sc)
			w = gc
		"tile":
			w = SideTile.new()
		_:
			var b := GuiSysButton.new()
			b.interactive = false
			w = b
	w.set_meta("kind", kind)
	w.set_meta("key", key)
	return w


func _apply(w: Control, c: Vector2i, kind: String, info: Dictionary) -> void:
	var usable: bool = bool(info.get("enabled", true)) and not bool(info.get("sold", false))
	var ctr := _cell_center(c)
	var acc: Color = info.get("accent", ImageController.COL.paper) if info.get("accent") is Color else ImageController.COL.paper
	match kind:
		"card":
			var gc: GuiCard = w
			gc.set_card(info.card)
			gc.playable = usable
			gc.position = ctr - GuiCard.SIZE / 2
			gc.queue_redraw()
		"tile":
			var t: SideTile = w
			t.title = str(info.get("title", ""))
			t.icon_kind = str(info.get("icon", "star"))
			t.accent = acc
			t.sub = str(info.get("sub", ""))
			t.dimmed = not usable
			t.position = ctr - t.size / 2
			t.queue_redraw()
		"key":
			var b: GuiSysButton = w
			b.setup(str(info.get("title", "")), str(info.get("icon", "star")), acc, "", "", Vector2(108, 164), "key")
			b.dimmed = not usable
			b.position = ctr - b.size / 2
		_:
			var b: GuiSysButton = w
			var sz := Vector2(132, 132) if c == Vector2i(2, 1) else Vector2(116, 116)  # 5（中央）は大きい
			b.setup(str(info.get("title", "")), str(info.get("icon", "star")), acc, "", "", sz, "circle")
			b.subtitle = str(info.get("sub", ""))
			b.dimmed = not usable
			b.position = ctr - sz / 2


# ============================================================
# マスの位置
# ============================================================

func _cell_rect(c: Vector2i) -> Rect2:
	return Rect2(COL_X[c.x], GRID_TOP + c.y * ROW_H, COL_X[c.x + 1] - COL_X[c.x], ROW_H)


func _cell_center(c: Vector2i) -> Vector2:
	return _cell_rect(c).get_center()


func _cell_at(p: Vector2) -> Vector2i:
	var col := 0
	for i in COLS:
		if p.x >= COL_X[i]:
			col = i
	return Vector2i(col, clampi(int((p.y - GRID_TOP) / ROW_H), 0, 2))


func _cell_value(c: Vector2i):
	if c.y < 0 or c.y >= KEYS.size() or c.x < 0 or c.x >= COLS:
		return null
	return KEYS[c.y][c.x]


static func cell_of(value) -> Vector2i:
	for r in KEYS.size():
		for col in COLS:
			if typeof(KEYS[r][col]) == typeof(value) and KEYS[r][col] == value:
				return Vector2i(col, r)
	return Vector2i(-1, -1)


# ============================================================
# ジェスチャー（戦闘と同じ）
# ============================================================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if event.pressed:
			_on_press(event.position)
		else:
			_on_release(event.position)
	elif event is InputEventMouseMotion and g_active:
		accept_event()
		_on_drag(event.position)


func _on_press(p: Vector2) -> void:
	if locked or not is_visible_in_tree() or p.y < GRID_TOP:
		return
	g_active = true
	g_start = p
	g_origin = _cell_at(p)
	g_time = 0.0
	g_cur = null
	g_moved = false
	g_charge_target = null
	var k = _cell_value(g_origin)
	if widgets.has(k) and g_origin.x == COLS - 1:
		widgets[k].highlighted = true  # 右の列は押した時点で光らせる（戦闘と同じ）


func _on_drag(p: Vector2) -> void:
	if locked:
		return
	var diff := p - g_start
	var target = null
	if diff.length() > DEADZONE:
		if not g_moved:
			g_moved = true
			var k = _cell_value(g_origin)
			if widgets.has(k):
				widgets[k].highlighted = false
		var idx := int(round(diff.angle() / (PI / 4))) % 8
		if idx < 0:
			idx += 8
		target = _cell_value(g_origin + DIR8[idx])
		if target != null and not cells.has(target):
			target = null  # 中身の無いマスは選ばない
	elif not g_moved:
		return
	if typeof(target) == typeof(g_cur) and target == g_cur:
		return
	g_cur = target
	_preview(target)


func _process(delta: float) -> void:
	if not g_active or locked:
		return
	# 溜める対象：指を動かしていなければ押したマス
	var target = null
	if not g_moved:
		target = _cell_value(g_origin)
		if not cells.has(target):
			target = null
	if typeof(target) != typeof(g_charge_target) or target != g_charge_target:
		_set_charge(g_charge_target, 0.0)
		g_charge_target = target
		g_time = 0.0
	if target == null:
		return
	g_time += delta / maxf(Engine.time_scale, 0.01)
	var c := clampf((g_time - CHARGE_DELAY) / CHARGE_TIME, 0.0, 1.0)
	_set_charge(target, c)
	if c > 0:
		_show_desc(target)
		_strip_for(target)


func _on_release(_p: Vector2) -> void:
	if not g_active:
		return
	var moved := g_moved
	var target = g_cur
	var origin_val = _cell_value(g_origin)
	var charged := g_charge_target != null and (g_time - CHARGE_DELAY) >= CHARGE_TIME
	var short := g_time < TAP_TIME or g_charge_target == null
	_end_gesture()
	if locked:
		return
	if moved:
		if target != null:
			_choose(target)
	elif charged:
		_choose(origin_val)  # 長押しで溜めきったマスを選ぶ
	elif not cells.has(origin_val):
		return
	elif g_origin.x == COLS - 1 or tap_chooses:
		if short:
			_choose(origin_val)
	elif short:
		_strip_for(origin_val)  # タップは説明だけ


func _end_gesture() -> void:
	_set_charge(g_charge_target, 0.0)
	g_active = false
	g_moved = false
	g_cur = null
	g_charge_target = null
	for k in widgets:
		widgets[k].highlighted = false
	_desc_key = null
	if bubble:
		bubble.hide_bubble()
	_strip_text = ""
	queue_redraw()
	if _tags:
		_tags.queue_redraw()
	focused.emit(null)


## 選ぶ（使えないマスなら blocked）
func _choose(key) -> void:
	if not cells.has(key):
		return
	var info: Dictionary = cells[key]
	if not is_usable(key):
		var msg := str(info.get("block_msg", "売り切れ" if info.get("sold", false) else "今は選べない"))
		flash(str(info.get("title", "")), msg, ImageController.COL.bad)
		blocked.emit(key)
		return
	chosen.emit(key)


## フリックで合わせたマスのプレビュー：光らせて説明の吹き出しと説明帯を出す
func _preview(key) -> void:
	for k in widgets:
		widgets[k].highlighted = false
	_tags.queue_redraw()
	focused.emit(key)
	if key == null:
		_desc_key = null
		bubble.hide_bubble()
		_strip_text = ""
		queue_redraw()
		return
	if widgets.has(key):
		widgets[key].highlighted = true
	_show_desc(key)
	_strip_for(key)


func _strip_for(key) -> void:
	var info: Dictionary = cells.get(key, {})
	if info.is_empty():
		return
	var t := str(info.get("short", DeckController.plain(str(info.get("desc", "")))))
	if not is_usable(key):
		flash(str(info.get("title", "")), t + "　" + str(info.get("block_msg", "売り切れ" if info.get("sold", false) else "")), ImageController.COL.bad)
	else:
		flash(str(info.get("title", "")), t, ImageController.COL.accent)


func _show_desc(key) -> void:
	if typeof(key) == typeof(_desc_key) and key == _desc_key:
		return
	_desc_key = key
	var info: Dictionary = cells.get(key, {})
	var body := str(info.get("desc", ""))
	if info.get("card") is Dictionary and body == "":
		body = DeckController.card_text(CurrentStatus.ally(str(info.card.get("owner", "knight"))), info.card)
	if body == "":
		bubble.hide_bubble()
		return
	var head := str(info.get("title", ""))
	if str(info.get("price", "")) != "":
		head += "　" + str(info.price)
	bubble.show_text(head, body, cell_center_global(key))


func _set_charge(key, c: float) -> void:
	var w = widgets.get(key) if key != null else null
	if w != null and "charge" in w:
		w.charge = c


# ============================================================
# 描画（背景は戦闘の操作エリアと同じ：黒地に薄い斜線、上端に赤と白の線）
# ============================================================

func _draw() -> void:
	var IC = ImageController
	var col: Dictionary = IC.COL
	var bg := Rect2(0, 10, size.x, size.y - 10)
	IC.pad_bg(self, bg)
	draw_rect(Rect2(0, 7, 720, 4), col.red)
	draw_rect(Rect2(0, 12, 720, 1), Color(1, 1, 1, 0.5))
	draw_colored_polygon(IC.slant_pts(Rect2(470, 0, 260, 11), 10), col.red)
	# 見出しの帯（戦闘の「〇〇の手番」と AP の位置）
	if header_left != "":
		var tag := Rect2(4, HEADER_Y + 4, 220, 42)
		IC.slant(self, tag, col.red, 14, 2.0, col.ink, col.ink, Vector2(4, 4))
		IC.head(self, header_left, tag.get_center(), 22, col.paper, 190)
	if header_right != "":
		var f: Font = IC.font_head
		var w := clampf(f.get_string_size(header_right, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 50, 120, 470)
		var r := Rect2(712 - w, HEADER_Y + 6, w, 38)
		IC.slant(self, r, col.paper, 12)
		IC.head(self, header_right, r.get_center(), 22, col.ink, w - 30)
	# 説明帯
	if _strip_text != "":
		# 説明帯：エンジェルホワイトの帯に濃い文字
		IC.slant(self, Rect2(8, STRIP_Y + 4, 704, 36), col.paper, 14, 2.0, col.ink, Color(col.red, 0.9), Vector2(4, 4))
		var sc: Color = col.ink if _strip_col.get_luminance() > 0.5 else _strip_col.darkened(0.25)
		IC.text(self, _strip_title + "　" + DeckController.plain(_strip_text), Vector2(360, STRIP_Y + 22), 20, sc, true, 0, 680)
	elif hint != "":
		# 操作のヒント：ホーリーブルーの薄い帯にエンジェルホワイトの文字
		IC.slant(self, Rect2(60, STRIP_Y + 6, 600, 32), Color(IC.GLASS.holy_blue, 0.16), 12)
		IC.text(self, hint, Vector2(360, STRIP_Y + 22), 18, col.paper, true, 0, 680)


## 値札（白い斜めタグ）と売り切れ（黒地に赤字）。拡大中のマスには描かない
func _draw_tags() -> void:
	var IC = ImageController
	var col: Dictionary = IC.COL
	for k in cells:
		var info: Dictionary = cells[k]
		var sold: bool = bool(info.get("sold", false))
		var price := str(info.get("price", ""))
		if not sold and price == "":
			continue
		var w = widgets.get(k)
		if w != null and w.highlighted:
			continue
		var c := cell_of(k)
		var r := _cell_rect(c)
		var txt := "売り切れ" if sold else price
		var tw := clampf(IC.font_head.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 30, 64, r.size.x - 4)
		var tag := Rect2(r.get_center().x - tw / 2, r.end.y - 30, tw, 26)
		if sold:
			IC.slant(_tags, tag, col.ink, 8, 2.0, col.red, Color(0, 0, 0, 0.6), Vector2(3, 3))
			IC.head(_tags, txt, tag.get_center(), 18, col.red, tw - 16)
		else:
			var afford: bool = bool(info.get("enabled", true))
			IC.slant(_tags, tag, col.paper if afford else Color("5c5c66"), 8, 2.0, col.ink, col.red, Vector2(3, 3))
			IC.head(_tags, txt, tag.get_center(), 18, col.ink, tw - 16)


# ============================================================
# 左の列のマス（戦闘のアイテム欄と同じ見た目：斜めの黒いパネル＋アイコン＋名前の白帯）
# ============================================================
class SideTile extends GuiPad:
	var title := ""
	var icon_kind := "star"
	var accent := Color.WHITE
	var sub := ""
	var dimmed := false
	var charge := 0.0:
		set(v):
			charge = v
			queue_redraw()

	func _init() -> void:
		size = Vector2(96, 160)
		custom_minimum_size = size
		interactive = false

	func _process(delta: float) -> void:
		super(delta)
		if charge >= 1.0 or highlighted:
			queue_redraw()

	func _draw() -> void:
		var IC = ImageController
		var r := Rect2(6, 6, size.x - 16, size.y - 16)
		var skew := 10.0
		var acc: Color = accent if not dimmed else Color("4a4a54")
		var face: Color = IC.COL.red if highlighted else (Color("17171b") if dimmed else IC.COL.ink.lerp(acc, 0.12))
		var shadow: Color = IC.COL.ink if highlighted else Color(0, 0, 0, 0.75)
		IC.slant(self, r, face, skew, 4.0 if highlighted else 3.0, IC.COL.paper if not dimmed else Color("3a3a42"), shadow, Vector2(6, 6))
		if not highlighted and not dimmed:
			IC.stripes(self, Rect2(r.position.x + r.size.x * 0.4, r.end.y - 30, r.size.x * 0.5, 26), Color(acc, 0.3), 9, 3, 0.6)
		var ic := Vector2(size.x / 2 - 1, r.position.y + 50)
		if not highlighted and not dimmed:
			IC.glow(self, ic, 30, Color(acc, 0.45), 4)
		IC.icon(self, icon_kind, ic, 50, acc if not highlighted else IC.COL.paper)
		var nb := Rect2(r.position.x - 2, r.position.y + 88, r.size.x + 4, 24)
		IC.slant(self, nb, IC.COL.paper if not dimmed else Color("5c5c66"), 6, 2.0, IC.COL.ink)
		IC.text(self, title, nb.get_center(), 15, IC.COL.ink, true, 0, nb.size.x - 14)
		if sub != "":
			IC.text(self, sub, Vector2(size.x / 2 - 3, r.end.y - 26), 13, IC.COL.text if not dimmed else Color("5c5c66"), true, 3, r.size.x - 6, IC.COL.ink)
		if charge > 0:
			_draw_charge(r, skew)

	## 長押しの溜め：パネルの縁に沿って赤いゲージ（GuiItemSlot と同じ）
	func _draw_charge(r: Rect2, skew: float) -> void:
		var IC = ImageController
		var poly: PackedVector2Array = IC.slant_pts(r.grow(5), skew)
		var path := PackedVector2Array([(poly[0] + poly[1]) / 2.0, poly[1], poly[2], poly[3], poly[0], (poly[0] + poly[1]) / 2.0])
		var total := 0.0
		for i in path.size() - 1:
			total += path[i].distance_to(path[i + 1])
		var want := total * clampf(charge, 0.0, 1.0)
		var out := PackedVector2Array([path[0]])
		var acc := 0.0
		for i in path.size() - 1:
			var seg := path[i].distance_to(path[i + 1])
			if acc + seg >= want:
				out.append(path[i].lerp(path[i + 1], (want - acc) / maxf(seg, 0.001)))
				break
			acc += seg
			out.append(path[i + 1])
		if out.size() < 2:
			return
		var col: Color = IC.COL.red
		if charge >= 1.0 and int(_t * 12) % 2 == 0:
			col = IC.COL.paper
		draw_polyline(out, IC.COL.ink, 9.0, true)
		draw_polyline(out, col, 5.0, true)
