extends GuiPad
class_name GuiCard
## 手札・報酬のカード。枠・絵柄・AP・威力を全てコードで描く。

const SIZE := Vector2(128, 168)

var card: Dictionary = {}
var playable := true  # AP不足なら false（暗く表示）
var label_hint := ""  # 右下に出す操作ヒント（例: "8"）


func _init() -> void:
	size = SIZE
	custom_minimum_size = SIZE
	hover_scale = 1.5  # フリックで選んだカードは大きく見せる


func set_card(c: Dictionary) -> void:
	card = c
	queue_redraw()


func _process(delta: float) -> void:
	super(delta)
	if not card.is_empty() and card.get("rarity", "normal") != "normal":
		queue_redraw()


func _frame_color() -> Color:
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
	# 絵柄の窓：種類の色の斜線の上にアイコン
	var art := Rect2(9, 27, size.x - 18, 82)
	draw_rect(art, fc.darkened(0.62))
	IC.stripes(self, art, Color(fc, 0.35), 14, 5, 0.7)
	IC.glow(self, art.get_center(), 42, Color(fc.lightened(0.4), 0.6), 5)
	IC.icon(self, card.get("art", "star"), art.get_center() + Vector2(0, 2), 60)
	_draw_shine(art, rarity)
	draw_rect(art, Color(1, 1, 1, 0.18), false, 1.0)
	# 名前：白い斜めの帯に黒い太字
	IC.slant(self, Rect2(4, size.y - 56, size.x - 8, 27), IC.COL.paper, 8)
	IC.text(self, card.get("name", ""), Vector2(size.x / 2, size.y - 42), 17, IC.COL.ink, true, 0, size.x - 22)
	# 効果の要約
	IC.text(self, summary(card), Vector2(size.x / 2, size.y - 15), 14, IC.COL.text, true, 0, size.x - 14)
	# 威力（左上）：赤いギザギザの星に白い数字
	var power: int = int(card.get("power", 0))
	if power > 0:
		var pc := Vector2(17, 17)
		IC.poly_box(self, IC.burst_pts(pc, 21, 14, 8, 3), IC.COL.red, 2.0, IC.COL.ink)
		IC.head(self, str(power), pc + Vector2(-1, 0), 21, IC.COL.paper, 26, Color(0, 0, 0, 0), Vector2.ZERO, 4, IC.COL.ink)
	# 消費AP（右上）
	if card.has("ap"):
		var apc: Color = IC.COL.ap if playable else Color("5a2a30")
		IC.icon(self, "ap", Vector2(size.x - 18, 17), 36, apc)
		IC.text(self, str(card.ap), Vector2(size.x - 18, 18), 19, Color.WHITE, true, 4, -1.0, IC.COL.ink)
	elif card.get("type") == "unselectable":
		IC.text(self, "常時", Vector2(size.x - 22, 16), 14, IC.COL.good, true, 4)
	# 持ち主のタグ（ナイト／ウィッチ）：持ち主の色の斜めタグ
	var owner: String = card.get("owner", "")
	if owner != "":
		var tag := Rect2(size.x / 2 - 30, 4, 60, 20)
		IC.slant(self, tag, IC.COL.get(owner, Color.GRAY), 6, 2.0, IC.COL.ink)
		IC.text(self, "ナイト" if owner == "knight" else "ウィッチ", tag.get_center(), 12, Color.WHITE, true)
	if not playable:
		draw_colored_polygon(IC.cut_pts(r, 14), Color(0, 0, 0, 0.55))
	if label_hint != "":
		var hr := Rect2(size.x - 30, size.y - 78, 22, 20)
		IC.slant(self, hr, Color(IC.COL.ink, 0.8), 4)
		IC.text(self, label_hint, hr.get_center(), 14, Color(1, 1, 1, 0.85), true)


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


static func summary(c: Dictionary) -> String:
	var parts: Array = []
	match c.get("target", ""):
		"enemy_all": parts.append("敵全体")
		"front_enemy_single": parts.append("近い敵")
		"front_enemy_group": parts.append("同じ側")
		"ally_all": parts.append("味方全体")
		"self": parts.append("自分")
	match c.get("effect", ""):
		"add_shield": parts.append("盾%d" % c.eff_val)
		"add_ap": parts.append("AP+%d" % c.eff_val)
		"heal": parts.append("回復%d" % c.eff_val)
		"draw": parts.append("%d枚引く" % c.eff_val)
		"add_status":
			var st: Dictionary = StatusEffectList.DATA.get(c.status, {})
			parts.append("%s%d" % [st.get("short", "?"), c.eff_val])
	return " ".join(parts)
