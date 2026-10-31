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
	if highlighted:
		IC.round_rect(self, r.grow(6), Color(IC.COL.gold, 0.55), 16)
	# 外枠（レア度で縁の色が変わる）
	var border := Color(1, 1, 1, 0.3)
	if rarity == "rare":
		border = IC.COL.gold
	elif rarity == "super_rare":
		border = Color.from_hsv(fmod(_t * 0.35, 1.0), 0.55, 1.0)
	IC.round_rect(self, r, fc, 12, 4, border)
	# 絵柄の窓
	var art := Rect2(8, 30, size.x - 16, 84)
	IC.round_rect(self, art, fc.darkened(0.55), 6)
	IC.glow(self, art.get_center(), 46, Color(fc.lightened(0.4), 0.7), 5)
	IC.icon(self, card.get("art", "star"), art.get_center(), 62)
	_draw_shine(art, rarity)
	# 名前
	IC.round_rect(self, Rect2(6, size.y - 52, size.x - 12, 24), Color(0, 0, 0, 0.45), 5)
	IC.text(self, card.get("name", ""), Vector2(size.x / 2, size.y - 40), 17, IC.COL.text, true, 0, size.x - 18)
	# 効果の要約
	IC.text(self, summary(card), Vector2(size.x / 2, size.y - 15), 14, Color(IC.COL.text, 0.85), false, 0, size.x - 12)
	# 威力（左上）
	var power: int = int(card.get("power", 0))
	if power > 0:
		draw_circle(Vector2(18, 17), 16, Color("2a1418"))
		draw_arc(Vector2(18, 17), 16, 0, TAU, 24, IC.COL.bad, 2.5, true)
		IC.text(self, str(power), Vector2(18, 17), 20, Color.WHITE, true)
	# 消費AP（右上）
	if card.has("ap"):
		var apc: Color = IC.COL.ap if playable else Color("7a3a3a")
		IC.icon(self, "ap", Vector2(size.x - 18, 17), 36, apc)
		IC.text(self, str(card.ap), Vector2(size.x - 18, 18), 19, Color.WHITE, true, 4)
	elif card.get("type") == "unselectable":
		IC.text(self, "常時", Vector2(size.x - 22, 16), 14, IC.COL.good, true, 4)
	if not playable:
		IC.round_rect(self, r, Color(0, 0, 0, 0.45), 12)
	if label_hint != "":
		draw_circle(Vector2(size.x - 14, size.y - 66), 11, Color(0, 0, 0, 0.55))
		IC.text(self, label_hint, Vector2(size.x - 14, size.y - 66), 14, Color(1, 1, 1, 0.8), true)


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
		"front_enemy_single": parts.append("正面1体")
		"front_enemy_group": parts.append("正面の列")
		"ally_all": parts.append("味方全体")
		"self": parts.append("自分")
	match c.get("effect", ""):
		"add_shield": parts.append("盾%d" % c.eff_val)
		"add_ap": parts.append("AP+%d" % c.eff_val)
		"heal": parts.append("回復%d" % c.eff_val)
		"add_status":
			var st: Dictionary = StatusEffectList.DATA.get(c.status, {})
			parts.append("%s%d" % [st.get("short", "?"), c.eff_val])
	return " ".join(parts)
