extends GuiPad
class_name GuiCard
## 手札・報酬のカード。枠・絵柄・AP・威力を全てコードで描く。

const SIZE := Vector2(128, 168)
const POWER_COL := Color("23a85a")  # パワーカードの枠の色

var card: Dictionary = {}
var playable := true  # AP不足なら false（暗く表示）
var label_hint := ""  # 互換用（操作ヒントの数字はもう描かない）
var charge := 0.0:  # 長押しの溜め（0〜1）。0 より大きい時は縁に溜めゲージを描く
	set(v):
		charge = v
		queue_redraw()


func _init() -> void:
	size = SIZE
	custom_minimum_size = SIZE
	hover_scale = 1.5  # フリックで選んだカードは大きく見せる


func set_card(c: Dictionary) -> void:
	card = c
	queue_redraw()


func _process(delta: float) -> void:
	super(delta)
	if not card.is_empty() and (card.get("rarity", "normal") != "normal" or charge >= 1.0):
		queue_redraw()


func _frame_color() -> Color:
	if ActionList.has_keyword(card, "power"):
		return POWER_COL  # パワーカードは緑の枠（札は出さない）
	match card.get("type", ""):
		"attack": return ImageController.COL.attack
		"skill": return ImageController.COL.skill
		_: return ImageController.COL.passive


func _draw() -> void:
	if card.is_empty():
		return
	var IC = ImageController
	var r := Rect2(Vector2.ZERO, size)
	var rarity: String = card.get("rarity", "normal")
	var fc := _frame_color()
	# 外枠（種類の色の太い枠）。縁の色はレア度で変わる。選択中は白縁＋赤のベタ影
	var border: Color = IC.COL.ink
	var bw := 2.0
	if rarity == "rare":
		border = IC.COL.gold
		bw = 3.0
	elif rarity == "super_rare":
		border = Color.from_hsv(fmod(_t * 0.35, 1.0), 0.55, 1.0)
		bw = 3.0
	if highlighted:
		IC.cut_rect(self, r, fc, 14, 4.0, IC.COL.paper, IC.COL.red, Vector2(7, 7))
	else:
		IC.cut_rect(self, r, fc, 14, bw, border, Color(0, 0, 0, 0.6), Vector2(4, 4))
	# 本体は黒
	IC.cut_rect(self, r.grow(-5), IC.COL.ink, 10)
	var unsel: bool = card.get("type", "") == "unselectable"
	# 絵柄の窓：種類の色の斜線の上にアイコン
	var art := Rect2(9, 27, size.x - 18, 82)
	draw_rect(art, fc.darkened(0.62))
	IC.stripes(self, art, Color(fc, 0.35), 14, 5, 0.7)
	IC.glow(self, art.get_center(), 42, Color(fc.lightened(0.4), 0.6), 5)
	IC.icon(self, card.get("art", "star"), art.get_center() + Vector2(0, 2), 60)
	_draw_shine(art, rarity)
	if unsel:
		# パワーカード（使えない）：絵柄の窓に黒い斜線をかけて「出せない」感じに（文字は暗くしない）
		draw_rect(art, Color(0, 0, 0, 0.35))
		IC.stripes(self, art, Color(IC.COL.ink, 0.75), 10, 3, 1.3)
	draw_rect(art, Color(1, 1, 1, 0.18), false, 1.0)
	# 名前：白い斜めの帯に黒い太字
	IC.slant(self, Rect2(4, size.y - 56, size.x - 8, 27), IC.COL.paper, 8)
	IC.text(self, card.get("name", ""), Vector2(size.x / 2, size.y - 42), 17, IC.COL.ink, true, 0, size.x - 22)
	# 効果の要約：先頭に対象のアイコン（文字より大きめ）。入りきらない時は文字を小さくする
	var ti := DeckController.target_icon(card.get("target", ""))
	var sm := DeckController.plain(summary(card))
	var isz := 22.0 if ti != "" else 0.0
	var gap := 3.0 if ti != "" and sm != "" else 0.0
	var fs := 14
	var f: Font = IC.font_bold
	while fs > 9 and isz + gap + f.get_string_size(sm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 14:
		fs -= 1
	var tw := isz + gap + f.get_string_size(sm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var sy := size.y - 15
	var sx := size.x / 2 - tw / 2
	if ti != "":
		IC.icon(self, ti, Vector2(sx + isz / 2, sy), isz)
	if sm != "":
		draw_string(f, Vector2(sx + isz + gap, sy + (f.get_ascent(fs) - f.get_descent(fs)) / 2.0), sm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, IC.COL.text)
	# 威力（左上）：ギザギザの星に数字。実際のダメージ（power_eff）を出し、
	# 基本より高ければ緑の星＋▲、低ければ白い星に赤い数字＋▼、同じなら赤い星に白い数字
	var power: int = int(card.get("power", 0))
	if power > 0:
		var eff: int = int(card.get("power_eff", power))
		var pc := Vector2(17, 17)
		var badge: Color = IC.COL.red
		var num_col: Color = IC.COL.paper
		if eff > power:
			badge = Color("1c9a48")
		elif eff < power:
			badge = IC.COL.paper
			num_col = IC.COL.red
		IC.poly_box(self, IC.burst_pts(pc, 21, 14, 8, 3), badge, 2.0, IC.COL.ink)
		IC.head(self, str(eff), pc + Vector2(-1, 0), 21, num_col, 26, Color(0, 0, 0, 0), Vector2.ZERO, 4, IC.COL.ink)
		if eff != power:
			var up := eff > power
			var ac := Vector2(33, 30)
			var tri := PackedVector2Array([ac + Vector2(-5, 3), ac + Vector2(5, 3), ac + Vector2(0, -5)]) if up \
					else PackedVector2Array([ac + Vector2(-5, -3), ac + Vector2(5, -3), ac + Vector2(0, 5)])
			IC.poly_box(self, tri, IC.COL.good if up else IC.COL.red, 2.0, IC.COL.ink)
	# 多段攻撃：威力の星の下に「×2」「×X」の小さな札
	var hits := hits_label(card)
	if power > 0 and hits != "":
		var hr := Rect2(2, 37, 30, 15)
		IC.slant(self, hr, IC.COL.ink, 4, 1.5, IC.COL.paper)
		IC.text(self, hits, hr.get_center() + Vector2(0, -0.5), 13, IC.COL.paper, true, 0, 26)
	# 消費AP（右上）。戦闘中は ap_show（APX は "X"、free は "0"）を描く
	if card.has("ap"):
		var apc: Color = IC.COL.ap if playable else Color("5a2a30")
		var aps: String = str(card.get("ap_show", "X" if card.get("ap_x", false) else str(DeckController.card_ap(card))))
		IC.icon(self, "ap", Vector2(size.x - 18, 17), 36, apc)
		IC.text(self, aps, Vector2(size.x - 18, 18), 19, Color.WHITE, true, 4, -1.0, IC.COL.ink)
	elif card.get("type") == "unselectable":
		IC.text(self, "常時", Vector2(size.x - 22, 16), 14, IC.COL.good, true, 4)
	# 持ち主のタグ（ナイト／ウィッチ）：持ち主の色の斜めタグ
	var owner: String = card.get("owner", "")
	if owner != "":
		var tag := Rect2(size.x / 2 - 30, 4, 60, 20)
		IC.slant(self, tag, IC.COL.get(owner, Color.GRAY), 6, 2.0, IC.COL.ink)
		IC.text(self, "ナイト" if owner == "knight" else "ウィッチ", tag.get_center(), 12, Color.WHITE, true)
	_draw_keywords(art)
	_draw_badge(art)
	if not playable and not unsel:
		draw_colored_polygon(IC.cut_pts(r, 14), Color(0, 0, 0, 0.55))
	if charge > 0:
		_draw_charge(r)


## 多段攻撃の回数の表示（"×2" / "×X"。多段でなければ ""）
static func hits_label(c: Dictionary) -> String:
	if c.get("hits_x", false):
		return "×X"
	var n := int(c.get("hits", 1))
	return "×%d" % n if n > 1 else ""


## バッジの紋章：絵柄の窓の右下に、赤い菱形の盾に白い 1 文字（BadgeList.DATA[b].short）
func _draw_badge(art: Rect2) -> void:
	var b := str(card.get("badge", ""))
	if not BadgeList.DATA.has(b):
		return
	var IC = ImageController
	var c := Vector2(art.end.x - 13, art.end.y - 13)
	var pts := PackedVector2Array([c + Vector2(0, -17), c + Vector2(15, -8), c + Vector2(13, 9), c + Vector2(0, 17), c + Vector2(-13, 9), c + Vector2(-15, -8)])
	IC.poly_box(self, pts, IC.COL.red, 2.5, IC.COL.ink)
	draw_polyline(PackedVector2Array([c + Vector2(0, -12), c + Vector2(10, -6), c + Vector2(9, 6), c + Vector2(0, 12), c + Vector2(-9, 6), c + Vector2(-10, -6), c + Vector2(0, -12)]),
			Color(IC.COL.paper, 0.7), 1.2, true)
	IC.text(self, str(BadgeList.DATA[b].short), c + Vector2(0, 0.5), 16, IC.COL.paper, true, 3, 26, IC.COL.ink)


## キーワードの札（廃棄／消費／即応／最後／陣形／転身）：絵柄の窓の左下に小さな斜めタグを縦に積む
## パワーは札を出さない（枠の緑で示す）。即応などは条件を満たしている時（card.kw_on に入っている）だけ赤く光らせる
func _draw_keywords(art: Rect2) -> void:
	var kws: Array = card.get("keywords", [])
	if kws.is_empty():
		return
	var IC = ImageController
	var x := art.position.x - 2
	var y := art.end.y - 19
	for kw in kws:
		var lb := ""
		var face: Color = IC.COL.ink
		var fg: Color = IC.COL.paper
		var line: Color = IC.COL.paper
		match String(kw):
			"sokuou", "saigo", "jinkei", "tenshin":
				lb = str(DeckController.KW_NAME[kw])
				if kw == "jinkei" and card.has("kw_side"):
					lb += str(card.kw_side)
				var on: bool = (card.get("kw_on", []) as Array).has(kw)
				face = IC.COL.red if on else IC.COL.paper
				fg = IC.COL.paper if on else IC.COL.ink
				line = IC.COL.ink
			"exhaust":
				lb = "廃棄"
				face = IC.COL.ink
				fg = IC.COL.red
				line = IC.COL.red
			"consume":
				lb = "消費"
				face = Color("ff8a2a").darkened(0.1)
				fg = Color.WHITE
				line = IC.COL.ink
			_:
				continue
		var w := 18.0 + 12.0 * lb.length()
		var tr := Rect2(x, y, w, 17)
		IC.slant(self, tr, face, 5, 1.5, line)
		IC.text(self, lb, tr.get_center() + Vector2(0, -0.5), 11, fg, true, 3, w - 8, IC.COL.ink)
		y -= 19


## 長押しの溜め：カードの縁に沿って上の中央から時計回りに赤いゲージ。満タンは白と赤で点滅
func _draw_charge(r: Rect2) -> void:
	var IC = ImageController
	var poly := IC.cut_pts(r.grow(3), 16)
	# 上辺の中央から始まる閉じた経路にする
	var path := PackedVector2Array([Vector2(r.get_center().x, poly[0].y)])
	for i in range(1, poly.size()):
		path.append(poly[i])
	path.append(poly[0])
	path.append(path[0])
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
	var full := charge >= 1.0
	var col: Color = IC.COL.red
	if full and int(_t * 12) % 2 == 0:
		col = IC.COL.paper
	draw_polyline(out, IC.COL.ink, 10.0, true)
	draw_polyline(out, col, 6.0, true)
	if full:
		draw_polyline(out, Color(1, 1, 1, 0.25 + 0.25 * sin(_t * 20.0)), 2.0, true)


## 絵柄の窓に斜めの光を走らせる（レア＝金、スーパーレア＝虹）
func _draw_shine(art: Rect2, rarity: String) -> void:
	if rarity == "normal":
		return
	var period := 2.6 if rarity == "rare" else 2.0
	var k := fmod(_t, period) / period
	var x := lerpf(art.position.x - 60, art.end.x + 60, k)
	var band := PackedVector2Array([Vector2(x - 14, art.end.y), Vector2(x + 14, art.end.y),
			Vector2(x + 54, art.position.y), Vector2(x + 26, art.position.y)])
	var rect_poly := PackedVector2Array([art.position, Vector2(art.end.x, art.position.y), art.end, Vector2(art.position.x, art.end.y)])
	var col := Color(1.0, 0.9, 0.5, 0.45)
	if rarity == "super_rare":
		col = Color.from_hsv(fmod(_t * 0.5, 1.0), 0.5, 1.0, 0.5)
	for poly in Geometry2D.intersect_polygons(band, rect_poly):
		draw_colored_polygon(poly, col)


## 効果の要約（"[i:対象のアイコン]" 入り。ImageController.rich_text で描く）
static func summary(c: Dictionary) -> String:
	var parts: Array = []
	var ti := DeckController.target_icon(c.get("target", ""))
	if ActionList.has_keyword(c, "power"):
		var pe: Dictionary = c.get("power_effect", {})
		parts.append("%s+%d" % ["攻" if pe.get("status", "") == "atk_buff" else "防", int(pe.get("eff_val", 0))])
	# 多段攻撃は「5×2」「8×X」（数字は実際のダメージ）
	var hl := hits_label(c)
	if hl != "" and int(c.get("power", 0)) > 0:
		parts.append("%d%s" % [int(c.get("power_eff", c.power)), hl])
	if c.get("kill_ap", 0) > 0:
		parts.append("撃破AP+%d" % int(c.kill_ap))
	match String(c.get("on_kill", "")):
		"reuse": parts.append("撃破で再使用")
		"reuse_free": parts.append("撃破でAP0再使用")
	for e in ActionList.effects_of(c):
		var xs := "×X" if e.get("x", false) else ""
		match e.get("effect", ""):
			"add_shield": parts.append("盾%d%s" % [e.eff_val, xs])
			"absorb_block": parts.append("盾吸収")
			"add_ap": parts.append("AP+%d" % e.eff_val)
			"heal": parts.append("回復%d" % e.eff_val)
			"heal_pct": parts.append("回復%d%%" % int(e.eff_val))
			"draw": parts.append("%d枚引く" % e.eff_val)
			"swap": parts.append("入替")
			"double": parts.append("2回発動")
			"turnabout": parts.append("補充")
			"extra_turn": parts.append("再行動")
			"add_status":
				var st: Dictionary = StatusEffectList.DATA.get(e.status, {})
				var only_name: bool = e.status in ["taunt", "fire_guard"] or st.get("label", "") == "none"
				parts.append(st.get("short", "?") if only_name else "%s%d" % [st.get("short", "?"), e.eff_val])
	var s := " ".join(parts)
	return s if ti == "" else "[i:%s]%s" % [ti, s]
