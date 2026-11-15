extends Control
class_name GuiDeckView
## デッキ確認のオーバーレイ（報酬画面・戦闘・イベント・ショップで共通）。
## タブでキャラを切り替え、カードをタップすると下に説明が出る。
## pick_cb を渡すと「選択モード」になり、カードをタップ→「このカードを選ぶ」で pick_cb(char_id, card_id) を呼ぶ。
## sections を渡すと戦闘用表示（山札／捨札／保留などの見出しごとに並べる）。
## open_badge で開くと「バッジを付けるカード選び」：付けられないカードは暗く、選ぶと badge_cb(char_id, デッキの index) を呼ぶ。
## pick_cb に渡す card_id はデッキの ID（バッジ付きなら "カードID@バッジID"。CurrentDeck.remove_card にそのまま渡せる）。
## 10 回目（C）：上のボタンで並べ替え（No.・レア度・種類・AP・名前。選んだ並びは開き直しても残る）。
##   カードをタップ（選ぶ画面では長押し）すると大きく表示（説明つき。どこかをタップで閉じる）。

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
## 並べ替え：[キー, ボタンの文字]。sort_key は static（一覧を開き直しても同じ並び）
const SORTS := [["no", "No."], ["rarity", "レア度"], ["type", "種類"], ["ap", "AP"], ["name", "名前"]]
static var sort_key := "no"
var regroup := true  # true＝並べ替えの種類で見出しを作り直す（タイトルの一覧・デッキ）。false＝見出し（山札・捨札など）の中だけ並べ替える
var _sort_btns := {}
var _zoom_view: Control  # 拡大表示（開いていなければ null）


static func open(parent: Node, title: String = "デッキ", pick: Callable = Callable(), secs: Dictionary = {}, first: String = "knight") -> GuiDeckView:
	var v := GuiDeckView.new()
	v.title_text = title
	v.pick_cb = pick
	v.sections = secs
	v.current = first
	v.regroup = secs.is_empty()  # 戦闘の山札・捨札などの見出しはそのまま
	parent.add_child(v)
	return v


## カード一覧（タイトル）：sections のカードを、並べ替えの種類ごとの見出しに並べ直して出す
static func open_list(parent: Node, title: String, secs: Dictionary, first: String = "knight") -> GuiDeckView:
	var v := GuiDeckView.new()
	v.title_text = title
	v.sections = secs
	v.current = first
	v.regroup = true
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
	bg.color = Color(ImageController.GLASS.ivory_black, 0.78)
	bg.size = size
	add_child(bg)
	UiSystem.make_panel(self, Rect2(20, 60, 680, 1160))
	UiSystem.make_banner(self, title_text, Rect2(40, 34, 420, 66), 32)
	var x := 60.0
	for id in tabs:
		var b := UiSystem.make_button(self, InitAllyStatus.DATA[id].name, Vector2(x, 136), Vector2(290, 64), _switch.bind(id), 26)
		_tab_btns[id] = b
		x += 310
	# 並べ替えのボタン（選んでいるものは赤）
	var bx := 40.0
	for so in SORTS:
		var sb := UiSystem.make_button(self, so[1], Vector2(bx, 208), Vector2(120, 44), _set_sort.bind(so[0]), 20)
		_sort_btns[so[0]] = sb
		bx += 130
	_paint_sort_btns()
	_grid = Control.new()
	_grid.position = Vector2(40, 262)
	_grid.size = Vector2(640, 692)
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
	var from_deck := groups.is_empty()
	if from_deck:
		var cards: Array = []
		var deck: Array = CurrentDeck.decks[id]
		for i in deck.size():
			var c := ActionList.make_card(str(deck[i]))
			if c.is_empty():
				continue
			c["_deck_index"] = i  # バッジを付ける時に使う（表示用の印。デッキには残らない）
			cards.append(c)
		groups = [["%d 枚" % cards.size(), cards]]
	groups = _sorted_groups(groups, from_deck)
	var y := 0.0
	var no_size := 12
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
		if total <= _grid.size.y or sc <= 0.32:  # 見出しが多い並べ替え（AP・種類）でも入るように 0.33 まで
			break
		sc -= 0.03
	no_size = clampi(int(8.0 / sc), 12, 20)  # 小さく並べた時も No. が読めるように
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
			v.animate_shine = false  # 一覧では光の帯を止める（枚数が多いと毎フレームの描き直しが重い）
			v.base_scale = sc
			v.hover_scale = 1.15
			v.scale = Vector2(sc, sc)
			v.no_size = no_size
			# 拡大縮小の中心はカードの中央なので、見た目の左上が揃うようにずらす
			v.position = Vector2((i % cols) * cw, y + int(i / cols) * ch) - GuiCard.SIZE * (1.0 - sc) / 2.0
			if badge_cb.is_valid() and not BadgeList.can_attach(badge_id, c):
				v.playable = false  # 付けられないカードは暗く
			_grid.add_child(v)
			v.tapped.connect(_on_card.bind(c, v))
			v.hold_started.connect(zoom.bind(c))  # 長押しで拡大（選ぶ画面でも）
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
	if not (pick_cb.is_valid() or badge_cb.is_valid()):
		zoom(c)  # 見るだけの一覧はタップで拡大
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


# ------------------------------------------------------------
# 並べ替え
# ------------------------------------------------------------
func _set_sort(key: String) -> void:
	if sort_key == key:
		return
	sort_key = key
	_paint_sort_btns()
	_switch(current)


func _paint_sort_btns() -> void:
	for k in _sort_btns:
		UiSystem.set_button_red(_sort_btns[k], k == sort_key)


## 12 回目（C）：レア度は 4 段階（ActionList.RARITIES。古い値は norm_rarity で読み替える）
const RARITY_ORDER := ["common", "rare", "epic", "legend"]
const RARITY_NAME := {"common": "コモン", "rare": "レア", "epic": "エピック", "legend": "レジェンド"}
const TYPE_NAME := ["アタック", "スキル", "パワー", "その他"]


## 種類の順（アタック 0・スキル 1・パワー 2・その他 3）
static func type_rank(c: Dictionary) -> int:
	if ActionList.has_keyword(c, "power") or str(c.get("type", "")) in ["power", "unselectable"]:
		return 2
	match str(c.get("type", "")):
		"attack": return 0
		"skill": return 1
	return 3


## AP の順（X は最後）
static func ap_rank(c: Dictionary) -> int:
	if c.get("ap_x", false):
		return 99
	if not c.has("ap"):
		return 98
	return DeckController.card_ap(c)


## 並べ替えの主キー（数）。名前・No. は 0（後ろの比べで決まる）
static func sort_rank(c: Dictionary, key: String) -> int:
	match key:
		"rarity": return RARITY_ORDER.find(ActionList.norm_rarity(c.get("rarity", "common")))
		"type": return type_rank(c)
		"ap": return ap_rank(c)
	return 0


## 見出しの名前（regroup の時）
static func group_name(c: Dictionary, key: String) -> String:
	match key:
		"rarity": return str(RARITY_NAME[ActionList.norm_rarity(c.get("rarity", "common"))])
		"type": return TYPE_NAME[type_rank(c)]
		"ap":
			var r := ap_rank(c)
			# AP3 以上はまとめる（見出しが増えすぎると一覧に入らない）
			return "AP X" if r == 99 else ("AP なし" if r == 98 else ("AP 3 以上" if r >= 3 else "AP %d" % r))
	return ""


## カードの並べ替え（主キー → No. → 名前 → デッキの ID）。比べる値は先に作っておく（枚数が多くても軽く）
static func sort_cards(cards: Array, key: String) -> Array:
	var rows: Array = []
	for c in cards:
		var nm := str(c.get("name", ""))
		var no := str(c.get("no", ""))
		rows.append([sort_rank(c, key), nm if key == "name" else no, no if key == "name" else nm, str(c.get("deck_id", c.get("id", ""))), c])
	rows.sort_custom(func(a, b):
		for i in 4:
			if a[i] != b[i]:
				return a[i] < b[i]
		return false)
	return rows.map(func(r): return r[4])


## 見出しごとの並べ替え。regroup なら全部を並べ直して、レア度・種類・AP は見出しを作り直す
func _sorted_groups(groups: Array, from_deck: bool) -> Array:
	if not regroup:
		return groups.map(func(g): return [g[0], sort_cards(g[1], sort_key)])
	var all: Array = []
	for g in groups:
		all.append_array(g[1])
	var sorted := sort_cards(all, sort_key)
	if sort_key in ["no", "name"]:
		return [["%d 枚" % sorted.size() if from_deck else "全 %d 枚" % sorted.size(), sorted]]
	var out: Array = []
	for c in sorted:
		var gn := group_name(c, sort_key)
		if out.is_empty() or out.back()[0] != gn:
			out.append([gn, []])
		out.back()[1].append(c)
	return out


# ------------------------------------------------------------
# 拡大表示
# ------------------------------------------------------------
const ZOOM_SCALE := 2.3
const ZOOM_CENTER := Vector2(360, 432)


## カードを大きく表示（説明つき）。どこをタップしても閉じる
func zoom(c: Dictionary) -> void:
	close_zoom()
	var IC = ImageController
	var z := Control.new()
	z.size = size
	z.mouse_filter = Control.MOUSE_FILTER_STOP
	z.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			z.accept_event()
			close_zoom())
	var shade := ColorRect.new()
	shade.color = Color(IC.GLASS.ivory_black, 0.86)
	shade.size = size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	z.add_child(shade)
	var gc := GuiCard.new()
	gc.interactive = false
	gc.set_card(c)
	gc.base_scale = ZOOM_SCALE
	gc.position = ZOOM_CENTER - GuiCard.SIZE / 2
	gc.pivot_offset = GuiCard.SIZE / 2
	gc.scale = Vector2(ZOOM_SCALE, ZOOM_SCALE)
	if badge_cb.is_valid() and not BadgeList.can_attach(badge_id, c):
		gc.playable = false
	z.add_child(gc)
	# 説明（白いギザギザ吹き出し）
	var owner := str(c.get("owner", current))
	var text := DeckController.card_text(CurrentStatus.ally(owner if InitAllyStatus.DATA.has(owner) else current), c)
	UiSystem.make_bubble(z, Rect2(40, 680, 640, 330), Vector2(360, 640), 3)
	var d := Control.new()
	d.position = Vector2(66, 700)
	d.size = Vector2(588, 290)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.draw.connect(func():
		var fs := 26
		while fs > 15 and IC.rich_height(text, fs, d.size.x, fs * 1.34) > d.size.y:
			fs -= 1
		IC.rich_text(d, text, Vector2.ZERO, fs, IC.COL.ink, d.size.x, 0, fs * 1.34))
	z.add_child(d)
	var hint := UiSystem.make_label(z, "タップで閉じる", Vector2(160, 1040), Vector2(400, 50), 24, IC.COL.paper, HORIZONTAL_ALIGNMENT_CENTER, 4)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(z)
	_zoom_view = z
	if not IC.light_mode:
		# 開く時だけ少し弾ませる（ライトモードでは省く）
		gc.scale = Vector2.ONE * ZOOM_SCALE * 0.7
		z.modulate.a = 0.0
		var tw := z.create_tween()
		tw.tween_property(z, "modulate:a", 1.0, 0.1)
		tw.parallel().tween_property(gc, "scale", Vector2.ONE * ZOOM_SCALE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close_zoom() -> void:
	if _zoom_view != null and is_instance_valid(_zoom_view):
		_zoom_view.queue_free()
	_zoom_view = null


func is_zoomed() -> bool:
	return _zoom_view != null and is_instance_valid(_zoom_view)


func _close() -> void:
	closed.emit()
	queue_free()
