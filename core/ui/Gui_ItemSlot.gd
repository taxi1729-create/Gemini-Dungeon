extends GuiPad
class_name GuiItemSlot
## 戦闘のアイテム欄の 1 枠（縦に 3 つ並ぶ）。アイテムがあればアイコンと名前、空なら点線の空き枠。
## 入力は戦闘シーンがまとめて処理する（interactive = false）。長押しの溜めは charge（0〜1）で描く。

const SIZE := Vector2(96, 160)
const SLOT_MARK := ["①", "②", "③"]  # 互換用（もう描かない）

var item_id := ""  # 空なら空き枠
var slot_index := 0  # 0=上, 1=中, 2=下
var charge := 0.0:  # 長押しの溜め（0〜1）
	set(v):
		charge = v
		queue_redraw()


func _init() -> void:
	size = SIZE
	custom_minimum_size = SIZE
	interactive = false


func set_item(id: String) -> void:
	item_id = id
	queue_redraw()


func _process(delta: float) -> void:
	super(delta)
	if charge >= 1.0 or highlighted:
		queue_redraw()


func _draw() -> void:
	var IC = ImageController
	var r := Rect2(6, 6, size.x - 16, size.y - 16)
	var skew := 10.0
	var it: Dictionary = Item_List.DATA.get(item_id, {}) if item_id != "" else {}
	if it.is_empty():
		_draw_empty(r, skew)
		return
	var acc: Color = it.get("art_col", IC.COL.paper)
	# 斜めの黒いパネル。選択中は赤く塗り、白縁＋黒のベタ影
	var face: Color = IC.COL.red if highlighted else IC.COL.ink.lerp(acc, 0.12)
	var shadow: Color = IC.COL.ink if highlighted else Color(0, 0, 0, 0.75)
	IC.slant(self, r, face, skew, 4.0 if highlighted else 3.0, IC.COL.paper, shadow, Vector2(6, 6))
	if not highlighted:
		IC.stripes(self, Rect2(r.position.x + r.size.x * 0.4, r.end.y - 30, r.size.x * 0.5, 26), Color(acc, 0.3), 9, 3, 0.6)
	# アイコン：後ろに差し色の光
	var ic := Vector2(size.x / 2 - 1, r.position.y + 54)
	if not highlighted:
		IC.glow(self, ic, 30, Color(acc, 0.45), 4)
	IC.icon(self, String(it.get("icon", it.get("art", "potion"))), ic, 52, acc if not highlighted else Color(0, 0, 0, 0))
	# 名前（白い斜めの帯に黒い太字）
	var nb := Rect2(r.position.x - 2, r.position.y + 92, r.size.x + 4, 24)
	IC.slant(self, nb, IC.COL.paper, 6, 2.0, IC.COL.ink)
	IC.text(self, String(it.get("name", "")), nb.get_center(), 15, IC.COL.ink, true, 0, nb.size.x - 14)
	# AP0 の目印（下）
	IC.text(self, "AP0", Vector2(size.x / 2 - 3, r.end.y - 14), 13, IC.COL.ap if not highlighted else IC.COL.paper, true, 3, -1.0, IC.COL.ink)
	if charge > 0:
		_draw_charge(r, skew)


## 空き枠：点線の斜め枠と「空き」だけ（枠番号は描かない）
func _draw_empty(r: Rect2, skew: float) -> void:
	var IC = ImageController
	var poly := IC.slant_pts(r, skew)
	draw_colored_polygon(poly, Color(0, 0, 0, 0.35))
	var col: Color = Color(1, 1, 1, 0.3) if not highlighted else IC.COL.red
	for i in poly.size():
		draw_dashed_line(poly[i], poly[(i + 1) % poly.size()], col, 2.0, 7.0)
	IC.text(self, "空き", r.get_center(), 15, Color(1, 1, 1, 0.28), true)


## 長押しの溜め：パネルの縁に沿って上辺から時計回りに赤いゲージ。満タンは白と赤で点滅
func _draw_charge(r: Rect2, skew: float) -> void:
	var IC = ImageController
	var poly := IC.slant_pts(r.grow(5), skew)
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
