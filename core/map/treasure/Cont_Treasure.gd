extends Node2D
## 宝箱：開けると中身が 1 つ。戦闘と同じフリックの操作エリア（GuiFlickPad）で取るか決める
## 中身の確率：レリック 25%（全部持っていればゴールド）・バッジ 20%・ゴールド 20%（40〜80）・レア以上のカード 20%・バッジ付きカード 15%
## 8＝中身（弾くと取得。GuiAcquire を使う）、2＝取得しない、空白＝ステータス、削除＝デッキ一覧。
## 中身は SaveData.screen["treasure"] に残す（再読み込みしても同じ中身）。

const RATE := [["relic", 0.25], ["badge", 0.20], ["gold", 0.20], ["card", 0.20], ["badged_card", 0.15]]
const GOLD_MIN := 40
const GOLD_MAX := 80
const CHEST_POS := Vector2(360, 330)

var ui: CanvasLayer
var pad: GuiFlickPad
var view: Control
var content := {}  # {"kind": relic/badge/gold/card, "id": ..., "gold": n}
var done := false
var _t := 0.0
var _open := 0.0  # 開く演出（0→1）


func _ready() -> void:
	CurrentStatus.ensure_started()
	add_child(GuiBackground.new("cave"))
	ui = CanvasLayer.new()
	add_child(ui)
	UiSystem.make_banner(ui, "宝箱", Rect2(40, 26, 260, 76), 48)
	UiSystem.make_banner(ui, "中身を持っていくか決めよう", Rect2(280, 100, 400, 42), 21, ImageController.COL.paper, ImageController.COL.ink, 14)
	view = Control.new()
	view.size = Vector2(720, 652)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.draw.connect(_draw_view)
	ui.add_child(view)
	pad = GuiFlickPad.new()
	pad.header_left = "宝箱"
	pad.hint = "8 の中身を弾いて取得・2 で取得しない・長押しで説明"
	ui.add_child(pad)
	pad.chosen.connect(_on_chosen)
	if not _load_content():
		content = roll()
	SaveData.screen["treasure"] = content.duplicate()
	SaveData.save("treasure")
	_refresh()
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(self, "_open", 1.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	view.queue_redraw()


## 中身を決める（確率は RATE）
static func roll() -> Dictionary:
	var r := randf()
	var kind := "badged_card"
	var acc := 0.0
	for k in RATE:
		acc += float(k[1])
		if r < acc:
			kind = str(k[0])
			break
	match kind:
		"relic":
			var rid := RelicList.random_id(Inventory.relics)
			if rid != "":
				return {"kind": "relic", "id": rid, "gold": 0}
			return {"kind": "gold", "id": "", "gold": randi_range(GOLD_MIN, GOLD_MAX)}  # 全部持っていればゴールド
		"badge": return {"kind": "badge", "id": BadgeList.random_id(), "gold": 0}
		"gold": return {"kind": "gold", "id": "", "gold": randi_range(GOLD_MIN, GOLD_MAX)}
		"card": return {"kind": "card", "id": ActionList.random_rare_id(), "gold": 0}
	return {"kind": "card", "id": ActionList.random_badged_id(), "gold": 0}


func _load_content() -> bool:
	var s = SaveData.screen.get("treasure")
	if not s is Dictionary:
		return false
	var kind := str(s.get("kind", ""))
	var id := str(s.get("id", ""))
	var ok := false
	match kind:
		"relic": ok = RelicList.DATA.has(id)
		"badge": ok = BadgeList.DATA.has(id)
		"gold": ok = int(s.get("gold", 0)) > 0
		"card": ok = not ActionList.make_card(id).is_empty()
	if not ok:
		return false
	content = {"kind": kind, "id": id, "gold": int(s.get("gold", 0))}
	return true


## 中身の表示用 {"title", "icon", "desc", "card"?}
func content_info() -> Dictionary:
	match content.kind:
		"relic":
			var r: Dictionary = RelicList.DATA[content.id]
			var d := "[i:%s]%s：%s" % [r.icon, r.name, r.desc]
			if Inventory.has_relic(content.id):
				d += "\n（もう持っている）"
			elif Inventory.relics_full():
				d += "\n（レリックは%dつまで。取ると今の 1 つと交換）" % RelicList.MAX
			return {"title": r.name, "icon": r.icon, "accent": ImageController.COL.gold, "sub": "レリック", "desc": d}
		"badge":
			var b: Dictionary = BadgeList.DATA[content.id]
			return {"title": b.name, "icon": b.icon, "accent": Color("e8c26a"), "sub": "バッジ",
					"desc": "[i:%s]%s：%s\n（取るとデッキのカード 1 枚に付ける）" % [b.icon, b.name, b.desc]}
		"gold":
			return {"title": "%d ゴールド" % content.gold, "icon": "coin", "accent": ImageController.COL.gold, "sub": "ゴールド",
					"desc": "[i:coin]%d ゴールド（所持 %d → %d）" % [content.gold, Inventory.gold, Inventory.gold + int(content.gold)]}
	var c := ActionList.make_card(content.id)
	var owner := str(c.get("owner", "knight"))
	return {"title": c.get("name", ""), "card": c,
			"desc": "%sのカード\n%s" % [InitAllyStatus.DATA[owner].name, DeckController.card_text(CurrentStatus.ally(owner), c)]}


func _refresh() -> void:
	var info := content_info()
	info["short"] = "弾くと取得：" + DeckController.plain(str(info.desc)).replace("\n", " ")
	info["enabled"] = not done and not (content.kind == "relic" and Inventory.has_relic(content.id))
	info["block_msg"] = "もう持っている" if not done else "もう決めた"
	pad.set_cell(8, info)
	pad.set_cell(2, {"title": "取得しない", "icon": "skull", "accent": ImageController.GLASS.stone_gray, "desc": "中身を置いて先へ進む", "enabled": not done, "block_msg": "もう決めた"})
	pad.queue_redraw()


func _on_chosen(key) -> void:
	match key:
		8: take()
		2: leave()
		"deck":
			pad.locked = true
			GuiDeckView.open(ui, "デッキ").closed.connect(func(): pad.locked = done)
		"status":
			pad.locked = true
			GuiStatusView.open(ui, CurrentStatus.allies).closed.connect(func(): pad.locked = done)


## 取得する（GuiAcquire の流れ）。バッジを付けずにやめた時は宝箱の画面に戻る
func take() -> void:
	if done:
		return
	pad.locked = true
	match content.kind:
		"relic":
			GuiAcquire.relic(ui, content.id, func(got: bool):
				_finish("%sを手に入れた" % RelicList.DATA[content.id].name if got else "レリックを諦めた"))
		"badge":
			GuiAcquire.badge(ui, content.id, func(attached: bool):
				if attached:
					_finish("")
				else:
					pad.locked = false)
		"gold":
			Inventory.gold += int(content.gold)
			_finish("%d ゴールドを手に入れた" % content.gold)
		_:
			GuiAcquire.card(ui, content.id, func(_ok: bool): _finish(""))


## 取得しない
func leave() -> void:
	if done:
		return
	_finish("宝箱を後にした")


func _finish(msg: String) -> void:
	done = true
	pad.locked = true
	SaveData.save("map")  # 取った・置いた時点で保存（再読み込みしたらマップへ）
	_refresh()
	if msg != "":
		UiSystem.toast(ui, msg, 560, ImageController.COL.good)
	await get_tree().create_timer(1.2).timeout
	if is_inside_tree():
		UiSystem.goto("map")


## 上の表示：開いた宝箱と中身
func _draw_view() -> void:
	var IC = ImageController
	var col: Dictionary = IC.COL
	var c := CHEST_POS
	var k := clampf(_open, 0.0, 1.2)
	# 後ろの光（開くと大きくなる）
	IC.halftone(view, Rect2(0, 150, 720, 480), Color(col.red, 0.12), c, 340, 18, 5)
	IC.poly_box(view, IC.burst_pts(c, 120 + 70 * k, 80 + 40 * k, 16, 7, _t * 0.25), col.red, 3.0, col.ink)
	IC.glow(view, c, 110 * k + 10, Color(col.gold, 0.35 * k), 6)
	# 中身（宝箱から浮き上がる）
	var info := content_info()
	var p := c + Vector2(0, -30 - 70 * k + 6 * sin(_t * 2.5))
	if not info.has("card"):
		IC.icon(view, str(info.get("icon", "star")), p, 96 * maxf(k, 0.2))
	# 宝箱（D の chest アイコン。無ければ代わりの丸）
	IC.icon(view, "chest", c + Vector2(0, 70), 150)
	# 中身の名前と効果
	var r := Rect2(40, 500, 640, 132)
	# 中身の説明：エンジェルホワイトの文字の箱（見出しはディープローズ、本文は墨）
	IC.slant(view, r, IC.GLASS.angel_white, 16, 3.0, col.ink, col.red, Vector2(6, 6))
	IC.head(view, str(info.get("title", "")), Vector2(360, r.position.y + 32), 30, col.red, 560)
	var body := str(info.desc).replace("\n", "　")
	var fs := 19
	while fs > 13 and IC.rich_height(body, fs, r.size.x - 60, fs * 1.35) > r.size.y - 66:
		fs -= 1
	IC.rich_text(view, body, Vector2(r.position.x + 30, r.position.y + 60), fs, col.ink, r.size.x - 60, 0, fs * 1.35)
	if info.has("card"):
		# カードの中身はマス 8 にカードで出るので、上にはアイコンの代わりに「カード」の札
		IC.icon(view, "cards", p, 90 * maxf(k, 0.2))
