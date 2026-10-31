extends Control
class_name GuiDeckView
## デッキ確認のオーバーレイ（報酬画面・戦闘・イベント・ショップで共通）。
## タブでキャラを切り替え、カードをタップすると下に説明が出る。
## pick_cb を渡すと「選択モード」になり、カードをタップ→「このカードを選ぶ」で pick_cb(char_id, card_id) を呼ぶ。
## sections を渡すと戦闘用表示（山札／捨札／保留などの見出しごとに並べる）。

signal closed

var tabs: Array = ["knight", "witch"]
var current := "knight"
var pick_cb := Callable()
var sections := {}  # char_id -> [[見出し, [card辞書...]], ...]
var title_text := "デッキ"
var _grid: Control
var _desc: Label
var _pick_btn: Button
var _picked := {}
var _tab_btns := {}


static func open(parent: Node, title: String = "デッキ", pick: Callable = Callable(), secs: Dictionary = {}, first: String = "knight") -> GuiDeckView:
	var v := GuiDeckView.new()
	v.title_text = title
	v.pick_cb = pick
	v.sections = secs
	v.current = first
	parent.add_child(v)
	return v


func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(720, 1280)
	z_index = 200
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.75)
	bg.size = size
	add_child(bg)
	var col: Dictionary = ImageController.COL
	UiSystem.make_panel(self, Rect2(20, 60, 680, 1160))
	UiSystem.make_label(self, title_text, Vector2(20, 76), Vector2(680, 50), 32, col.gold)
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
	_desc = UiSystem.make_label(self, "カードをタップすると説明を表示", Vector2(44, 960), Vector2(632, 120), 20, col.text, HORIZONTAL_ALIGNMENT_LEFT, 0)
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	if pick_cb.is_valid():
		_pick_btn = UiSystem.make_button(self, "このカードを選ぶ", Vector2(60, 1110), Vector2(290, 80), _do_pick, 24)
		_pick_btn.disabled = true
		UiSystem.make_button(self, "やめる", Vector2(370, 1110), Vector2(290, 80), _close, 24)
	else:
		UiSystem.make_button(self, "閉じる", Vector2(210, 1110), Vector2(300, 80), _close, 26)
	_switch(current)


func _switch(id: String) -> void:
	current = id
	_picked = {}
	if _pick_btn:
		_pick_btn.disabled = true
	for k in _tab_btns:
		_tab_btns[k].modulate = Color.WHITE if k == id else Color(1, 1, 1, 0.45)
	for c in _grid.get_children():
		c.queue_free()
	var groups: Array = sections.get(id, [])
	if groups.is_empty():
		var cards: Array = []
		for cid in CurrentDeck.decks[id]:
			cards.append(ActionList.make_card(cid))
		cards.sort_custom(func(a, b): return a.name < b.name)
		groups = [["%d 枚" % cards.size(), cards]]
	var y := 0.0
	var sc := 0.66
	var cw := GuiCard.SIZE.x * sc + 10
	var ch := GuiCard.SIZE.y * sc + 10
	for g in groups:
		UiSystem.make_label(_grid, "%s（%d）" % [g[0], g[1].size()], Vector2(0, y), Vector2(640, 32), 20, ImageController.COL.sub, HORIZONTAL_ALIGNMENT_LEFT, 0)
		y += 34
		var i := 0
		for c in g[1]:
			var v := GuiCard.new()
			v.set_card(c)
			v.base_scale = sc
			v.hover_scale = 1.15
			v.scale = Vector2(sc, sc)
			# 拡大縮小の中心はカードの中央なので、見た目の左上が揃うようにずらす
			v.position = Vector2((i % 7) * cw, y + int(i / 7) * ch) - GuiCard.SIZE * (1.0 - sc) / 2.0
			_grid.add_child(v)
			v.tapped.connect(_on_card.bind(c, v))
			i += 1
		y += ceili(g[1].size() / 7.0) * ch + 6


func _on_card(c: Dictionary, v: GuiCard) -> void:
	_desc.text = DeckController.card_text(CurrentStatus.ally(current), c)
	if pick_cb.is_valid():
		for o in _grid.get_children():
			if o is GuiCard:
				o.highlighted = false
		v.highlighted = true
		_picked = c
		_pick_btn.disabled = false


func _do_pick() -> void:
	if _picked.is_empty():
		return
	var cb := pick_cb
	var id := current
	var cid: String = _picked.id
	_close()
	cb.call(id, cid)


func _close() -> void:
	closed.emit()
	queue_free()
