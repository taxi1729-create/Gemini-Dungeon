extends Control
class_name GuiDeckView
## デッキ確認のオーバーレイ（報酬画面・戦闘・イベント・ショップで共通）。
## タブでキャラを切り替え、カードをタップすると下に説明が出る。
## pick_cb を渡すと「選択モード」になり、カードをタップ→「このカードを選ぶ」で pick_cb(char_id, card_id) を呼ぶ。
## sections を渡すと戦闘用表示（山札／捨札／保留などの見出しごとに並べる）。
## open_badge で開くと「バッジを付けるカード選び」：付けられないカードは暗く、選ぶと badge_cb(char_id, デッキの index) を呼ぶ。
## pick_cb に渡す card_id はデッキの ID（バッジ付きなら "カードID@バッジID"。CurrentDeck.remove_card にそのまま渡せる）。

signal closed

var tabs: Array = ["knight", "witch"]
var current := "knight"
var pick_cb := Callable()
var sections := {}  # char_id -> [[見出し, [card辞書...]], ...]
var title_text := "デッキ"
var _grid: Control
var _desc: Control  # 説明（アイコン入りの文字を rich_text で描く）
var _desc_text := "カードをタップすると説明を表示"
var _pick_btn: Button
var _picked := {}
var _tab_btns := {}
var badge_id := ""  # バッジを付けるカード選びの時のバッジ
var badge_cb := Callable()  # badge_cb(char_id, index)
var _picked_index := -1


static func open(parent: Node, title: String = "デッキ", pick: Callable = Callable(), secs: Dictionary = {}, first: String = "knight") -> GuiDeckView:
	var v := GuiDeckView.new()
	v.title_text = title
	v.pick_cb = pick
	v.sections = secs
	v.current = first
	parent.add_child(v)
	return v


## バッジを付けるカードを選ぶ一覧。cb(char_id: String, index: int) を選んだ時に呼ぶ（閉じた後 closed も出る）
static func open_badge(parent: Node, badge: String, cb: Callable, first: String = "knight") -> GuiDeckView:
	var v := GuiDeckView.new()
	v.title_text = "%sを付ける" % BadgeList.DATA[badge].name
	v.badge_id = badge
	v.badge_cb = cb
	v.current = first
	v._desc_text = _badge_intro(badge)
	parent.add_child(v)
	return v


static func _badge_intro(badge: String) -> String:
	var d: Dictionary = BadgeList.DATA[badge]
	return "[i:%s]%s：%s\n付けるカードを選んでください（暗いカードには付けられません）" % [d.icon, d.name, d.desc]


func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(720, 1280)
	z_index = 200
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.size = size
	add_child(bg)
	UiSystem.make_panel(self, Rect2(20, 60, 680, 1160))
	UiSystem.make_banner(self, title_text, Rect2(40, 34, 420, 66), 32)
	var x := 60.0
	for id in tabs:
		var b := UiSystem.make_button(self, InitAllyStatus.DATA[id].name, Vector2(x, 136), Vector2(290, 64), _switch.bind(id), 26)
		_tab_btns[id] = b
		x += 310
	_grid = Control.new()
	_grid.position = Vector2(40, 214)
	_grid.size = Vector2(640, 740)
	_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_grid)
	# 説明は白いギザギザ吹き出しに黒文字で
	UiSystem.make_bubble(self, Rect2(44, 960, 632, 124), Vector2(-9999, -9999), 6)
	_desc = Control.new()
	_desc.position = Vector2(64, 970)
	_desc.size = Vector2(596, 106)
	_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desc.draw.connect(_draw_desc)
	add_child(_desc)
	if pick_cb.is_valid() or badge_cb.is_valid():
		_pick_btn = UiSystem.make_red_button(self, "バッジを付ける" if badge_cb.is_valid() else "このカードを選ぶ", Vector2(60, 1110), Vector2(290, 80), _do_pick, 24)
		_pick_btn.disabled = true
		UiSystem.make_button(self, "やめる", Vector2(370, 1110), Vector2(290, 80), _close, 24)
	else:
		UiSystem.make_button(self, "閉じる", Vector2(210, 1110), Vector2(300, 80), _close, 26)
	_switch(current)


func _switch(id: String) -> void:
	current = id
	_picked = {}
	_picked_index = -1
	if badge_cb.is_valid():
		_desc_text = _badge_intro(badge_id)
		if _desc:
			_desc.queue_redraw()
	if _pick_btn:
		_pick_btn.disabled = true
	for k in _tab_btns:
		_tab_btns[k].modulate = Color.WHITE if k == id else Color(1, 1, 1, 0.55)
		UiSystem.set_button_red(_tab_btns[k], k == id)  # 選んでいるタブは赤
	for c in _grid.get_children():
		c.queue_free()
	var groups: Array = sections.get(id, [])
	if groups.is_empty():
		var cards: Array = []
		var deck: Array = CurrentDeck.decks[id]
		for i in deck.size():
			var c := ActionList.make_card(str(deck[i]))
			if c.is_empty():
				continue
			c["_deck_index"] = i  # バッジを付ける時に使う（表示用の印。デッキには残らない）
			cards.append(c)
		cards.sort_custom(func(a, b): return a.name < b.name if a.name != b.name else str(a.deck_id) < str(b.deck_id))
		groups = [["%d 枚" % cards.size(), cards]]
	var y := 0.0
	# 入りきらない時はカードを小さくする（1 行の枚数を増やす）
	var sc := 0.66
	var cols := 7
	var cw := 0.0
	var ch := 0.0
	while true:
		cw = GuiCard.SIZE.x * sc + 10
		ch = GuiCard.SIZE.y * sc + 10
		cols = maxi(1, int((_grid.size.x + 10) / cw))
		var total := 0.0
		for g in groups:
			total += 34 + ceili(g[1].size() / float(cols)) * ch + 6
		if total <= _grid.size.y or sc <= 0.36:
			break
		sc -= 0.03
	for g in groups:
		var gl := UiSystem.make_label(_grid, "%s（%d）" % [g[0], g[1].size()], Vector2(12, y), Vector2(628, 32), 20, ImageController.COL.paper, HORIZONTAL_ALIGNMENT_LEFT, 0)
		gl.add_theme_font_override("font", ImageController.font_head)
		var tick := ColorRect.new()  # 見出しの左の赤い印
		tick.color = ImageController.COL.red
		tick.position = Vector2(0, y + 6)
		tick.size = Vector2(5, 22)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grid.add_child(tick)
		y += 34
		var i := 0
		for c in g[1]:
			var v := GuiCard.new()
			v.set_card(c)
			v.base_scale = sc
			v.hover_scale = 1.15
			v.scale = Vector2(sc, sc)
			# 拡大縮小の中心はカードの中央なので、見た目の左上が揃うようにずらす
			v.position = Vector2((i % cols) * cw, y + int(i / cols) * ch) - GuiCard.SIZE * (1.0 - sc) / 2.0
			if badge_cb.is_valid() and not BadgeList.can_attach(badge_id, c):
				v.playable = false  # 付けられないカードは暗く
			_grid.add_child(v)
			v.tapped.connect(_on_card.bind(c, v))
			i += 1
		y += ceili(g[1].size() / float(cols)) * ch + 6


func _on_card(c: Dictionary, v: GuiCard) -> void:
	_desc_text = DeckController.card_text(CurrentStatus.ally(current), c)
	if badge_cb.is_valid():
		var bd: Dictionary = BadgeList.DATA[badge_id]
		if not BadgeList.can_attach(badge_id, c):
			_desc_text += "\n※%sはこのカードには付けられません" % bd.name
			_desc.queue_redraw()
			_picked = {}
			_picked_index = -1
			_pick_btn.disabled = true
			for o in _grid.get_children():
				if o is GuiCard:
					o.highlighted = false
			return
		var old := str(c.get("badge", ""))
		if old != "":
			_desc_text += "\n→ [i:%s]%sを[i:%s]%sに上書き" % [BadgeList.DATA[old].icon, BadgeList.DATA[old].name, bd.icon, bd.name]
		else:
			_desc_text += "\n→ [i:%s]%s（%s）を付ける" % [bd.icon, bd.name, bd.desc]
		_picked_index = int(c.get("_deck_index", -1))
	_desc.queue_redraw()
	if pick_cb.is_valid() or badge_cb.is_valid():
		for o in _grid.get_children():
			if o is GuiCard:
				o.highlighted = false
		v.highlighted = true
		_picked = c
		_pick_btn.disabled = false


## 説明欄：入りきらない時は文字を小さくする
func _draw_desc() -> void:
	var IC = ImageController
	var fs := 20
	while fs > 13 and IC.rich_height(_desc_text, fs, _desc.size.x, fs * 1.32) > _desc.size.y:
		fs -= 1
	IC.rich_text(_desc, _desc_text, Vector2.ZERO, fs, IC.COL.ink, _desc.size.x, 0, fs * 1.32)


func _do_pick() -> void:
	if _picked.is_empty():
		return
	var id := current
	if badge_cb.is_valid():
		if _picked_index < 0:
			return
		var bcb := badge_cb
		var idx := _picked_index
		badge_cb = Callable()
		bcb.call(id, idx)  # 付けてから閉じる（closed を受けた側が結果を見られるように）
		_close()
		return
	var cb := pick_cb
	var cid: String = str(_picked.get("deck_id", _picked.id))
	_close()
	cb.call(id, cid)


## テスト用：今のタブの index 番目（デッキの順）のカードを選んだことにする
func pick_index(char_id: String, index: int) -> bool:
	if char_id != current:
		_switch(char_id)
	for o in _grid.get_children():
		if o is GuiCard and int(o.card.get("_deck_index", -1)) == index:
			_on_card(o.card, o)
			return _pick_btn != null and not _pick_btn.disabled
	return false


func _close() -> void:
	closed.emit()
	queue_free()
