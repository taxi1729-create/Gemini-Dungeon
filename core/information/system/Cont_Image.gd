extends Node
## ImageController（Autoload）
## 画像ファイルを一切使わず、アイコン・キャラクター・背景・カード裏をコードで描く共通ライブラリ。
## どの関数も「描画先の CanvasItem」を受け取り、その CanvasItem の _draw() の中から呼ぶ。

const COL = {
	# 基調：黒・白・赤（スタイリッシュなメニュー風の高コントラスト配色）
	"bg": Color("0a0a0c"),
	"panel": Color("141417"),
	"panel_hi": Color("222228"),
	"line": Color("46464e"),
	"gold": Color("f2c94c"),
	"accent": Color("e8213a"),  # 差し色（赤）
	"knight": Color("2f7cf0"),
	"witch": Color("9b4dea"),
	"gold_d": Color("5a5a62"),
	"text": Color("f5f3ee"),
	"sub": Color("a8a8b0"),
	"attack": Color("c8303c"),
	"skill": Color("2f68c8"),
	"passive": Color("2f9258"),
	"hp": Color("e8213a"),
	"hp_back": Color("2a0c12"),
	"shield": Color("8fc0ea"),
	"ap": Color("b88cff"),
	"good": Color("7be09a"),
	"bad": Color("ff5a5a"),
	# 追加：スタイル用の基本色
	"ink": Color("0a0a0c"),  # 墨（いちばん濃い黒）
	"paper": Color("f7f5f0"),  # 紙（吹き出し・白帯）
	"red": Color("e8213a"),  # 赤（強調・選択中）
	"red_d": Color("7a0c1a"),  # 暗い赤（影・地色）
	"steel": Color("2c2c33"),  # 無効・控えめな面
}

var font: Font
var font_bold: Font
var font_head: Font  # 見出し用（極太＋斜体）


func _ready() -> void:
	var base: Font = load("res://index/design/NotoSansJP-VariableFont_wght.ttf")
	font = _weight(base, 500)
	font_bold = _weight(base, 800)
	var fh := _weight(base, 900) as FontVariation
	fh.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.2, 1), Vector2.ZERO)  # 右に傾けた斜体
	font_head = fh


func _weight(base: Font, w: int) -> Font:
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): w}
	return fv


# ============================================================
# 文字
# ============================================================

## center を中心に1行の文字を描く。max_w を超える場合は文字サイズを自動で縮める。
func text(ci: CanvasItem, s: String, center: Vector2, size: int, col: Color = COL.text,
		bold: bool = false, outline: int = 0, max_w: float = -1.0,
		out_col: Color = Color(0, 0, 0, 0.85)) -> void:
	_text_f(ci, font_bold if bold else font, s, center, size, col, outline, max_w, out_col)


## 見出し文字（極太の斜体）。shadow_col を指定すると右下にずらした影（ベタ影）を付ける
func head(ci: CanvasItem, s: String, center: Vector2, size: int, col: Color = COL.paper,
		max_w: float = -1.0, shadow_col: Color = Color(0, 0, 0, 0), shadow_off: Vector2 = Vector2(4, 4),
		outline: int = 0, out_col: Color = COL.ink) -> void:
	if shadow_col.a > 0:
		_text_f(ci, font_head, s, center + shadow_off, size, shadow_col, outline, max_w, shadow_col)
	_text_f(ci, font_head, s, center, size, col, outline, max_w, out_col)


## max_w に収まる文字サイズを返す
func fit_size(f: Font, s: String, size: int, max_w: float) -> int:
	var fs := size
	if max_w > 0:
		while fs > 9 and f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
			fs -= 1
	return fs


func _text_f(ci: CanvasItem, f: Font, s: String, center: Vector2, size: int, col: Color,
		outline: int, max_w: float, out_col: Color) -> void:
	var fs := fit_size(f, s, size, max_w)
	var w := 1200.0
	var pos := Vector2(center.x - w / 2.0, center.y + (f.get_ascent(fs) - f.get_descent(fs)) / 2.0)
	if outline > 0:
		ci.draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_CENTER, w, fs, outline, out_col)
	ci.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_CENTER, w, fs, col)


# ============================================================
# 図形ヘルパー
# ============================================================

func ell(c: Vector2, rx: float, ry: float, n: int = 20) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		p.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return p


func pts(arr: Array) -> PackedVector2Array:
	var p := PackedVector2Array()
	for v in arr:
		p.append(Vector2(v[0], v[1]))
	return p


func star_pts(c: Vector2, r_out: float, r_in: float, n: int = 5, rot: float = -PI / 2) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n * 2:
		var r := r_out if i % 2 == 0 else r_in
		var a := rot + PI * i / n
		p.append(c + Vector2(cos(a), sin(a)) * r)
	return p


func round_rect(ci: CanvasItem, r: Rect2, col: Color, radius: float = 10.0,
		border: float = 0.0, border_col: Color = Color.TRANSPARENT) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	if border > 0:
		sb.set_border_width_all(int(border))
		sb.border_color = border_col
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)


func glow(ci: CanvasItem, c: Vector2, r: float, col: Color, steps: int = 6) -> void:
	for i in steps:
		var k := 1.0 - float(i) / steps
		ci.draw_circle(c, r * k, Color(col.r, col.g, col.b, col.a * (1.0 - k) * 0.5 + 0.03))


# ============================================================
# スタイル図形（斜めの帯・面取りパネル・ギザギザ吹き出し・斜線・網点）
# ============================================================

## 平行四辺形の頂点（上辺を右へ skew ずらす＝右に傾いた形）
func slant_pts(r: Rect2, skew: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(r.position.x + skew, r.position.y), Vector2(r.end.x, r.position.y),
			Vector2(r.end.x - skew, r.end.y), Vector2(r.position.x, r.end.y)])


## 左上と右下の角を斜めに落とした四角の頂点
func cut_pts(r: Rect2, cut: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(r.position.x + cut, r.position.y), Vector2(r.end.x, r.position.y),
			Vector2(r.end.x, r.end.y - cut), Vector2(r.end.x - cut, r.end.y), Vector2(r.position.x, r.end.y),
			Vector2(r.position.x, r.position.y + cut)])


## 多角形を「影 → 縁 → 面」の順に描く（影は右下へずらしたベタ影、縁は外側へ太らせた多角形）
func poly_box(ci: CanvasItem, poly: PackedVector2Array, fill: Color, border: float = 0.0,
		border_col: Color = Color.TRANSPARENT, shadow_col: Color = Color.TRANSPARENT,
		shadow_off: Vector2 = Vector2(6, 6)) -> void:
	var outer := poly
	if border > 0:
		var grown := Geometry2D.offset_polygon(poly, border, Geometry2D.JOIN_MITER)
		if not grown.is_empty():
			outer = grown[0]
	if shadow_col.a > 0:
		var sh := PackedVector2Array()
		for v in outer:
			sh.append(v + shadow_off)
		ci.draw_colored_polygon(sh, shadow_col)
	if border > 0:
		ci.draw_colored_polygon(outer, border_col)
	ci.draw_colored_polygon(poly, fill)


## 斜めの帯（平行四辺形）
func slant(ci: CanvasItem, r: Rect2, col: Color, skew: float = 14.0, border: float = 0.0,
		border_col: Color = Color.TRANSPARENT, shadow_col: Color = Color.TRANSPARENT,
		shadow_off: Vector2 = Vector2(6, 6)) -> void:
	poly_box(ci, slant_pts(r, skew), col, border, border_col, shadow_col, shadow_off)


## 角を落としたパネル
func cut_rect(ci: CanvasItem, r: Rect2, col: Color, cut: float = 14.0, border: float = 0.0,
		border_col: Color = Color.TRANSPARENT, shadow_col: Color = Color.TRANSPARENT,
		shadow_off: Vector2 = Vector2(6, 6)) -> void:
	poly_box(ci, cut_pts(r, cut), col, border, border_col, shadow_col, shadow_off)


## 0〜1 の決まった乱数（同じ seed なら毎フレーム同じ形になる）
func _hash(i: float) -> float:
	return fposmod(sin(i * 12.9898) * 43758.5453, 1.0)


## 四角の周りをギザギザに尖らせた頂点（漫画の吹き出し風）。amp = 尖りの高さ、step = 尖りの間隔
func jag_pts(r: Rect2, seed: int = 0, amp: float = 10.0, step: float = 21.0) -> PackedVector2Array:
	var p := PackedVector2Array()
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var outs := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
	var k := float(seed) * 7.31
	for e in 4:
		var a: Vector2 = corners[e]
		var b: Vector2 = corners[(e + 1) % 4]
		var o: Vector2 = outs[e]
		# 角は斜め外へ少し張り出させる
		var diag: Vector2 = (o + outs[(e + 3) % 4]) * amp * 0.9
		p.append(a + diag)
		var n := maxi(1, int(a.distance_to(b) / step))
		for i in range(1, n):
			var t := (float(i) + (_hash(k + i) - 0.5) * 0.5) / n
			var h := amp * (0.55 + _hash(k + i * 3.3) * 0.9) if i % 2 == 1 else -amp * 0.25
			p.append(a.lerp(b, t) + o * h)
		k += 17.0
	return p


## 吹き出しの頂点（ギザギザの本体＋ tail_to へ向かう尖ったしっぽ）。tail_to.x < -9000 ならしっぽ無し
func bubble_pts(r: Rect2, tail_to: Vector2 = Vector2(-9999, -9999), seed: int = 0,
		amp: float = 9.0) -> PackedVector2Array:
	var body := jag_pts(r, seed, amp)
	if tail_to.x < -9000 or r.has_point(tail_to):
		return body
	# しっぽの根元：tail_to に一番近い辺の上に置く
	var c := r.get_center()
	var base := Vector2(clampf(tail_to.x, r.position.x + 30, r.end.x - 30), clampf(tail_to.y, r.position.y + 24, r.end.y - 24))
	var horiz := absf(tail_to.y - c.y) / maxf(r.size.y, 1.0) >= absf(tail_to.x - c.x) / maxf(r.size.x, 1.0)
	var w := 22.0
	var b1: Vector2
	var b2: Vector2
	if horiz:
		base.y = r.end.y - 4 if tail_to.y > c.y else r.position.y + 4
		b1 = base + Vector2(-w, 0)
		b2 = base + Vector2(w, 0)
	else:
		base.x = r.end.x - 4 if tail_to.x > c.x else r.position.x + 4
		b1 = base + Vector2(0, -w)
		b2 = base + Vector2(0, w)
	var tip := tail_to
	var lim := 70.0
	if base.distance_to(tip) > lim:
		tip = base + (tip - base).normalized() * lim
	# 少しねじった三角形にして勢いを出す
	var mid := (b1 + b2) / 2.0
	var back := (tip - mid).normalized() * 12.0  # 根元を本体の内側へ少し食い込ませて確実につなぐ
	var tail := PackedVector2Array([b1 - back, b2 - back, tip])
	var merged := Geometry2D.merge_polygons(body, tail)
	for m in merged:
		if Geometry2D.is_polygon_clockwise(m) != Geometry2D.is_polygon_clockwise(body):  # 穴は飛ばす
			continue
		return m
	return body


## 白い吹き出し（黒い縁＋赤いベタ影）
func bubble(ci: CanvasItem, r: Rect2, tail_to: Vector2 = Vector2(-9999, -9999), seed: int = 0,
		fill: Color = COL.paper, line: Color = COL.ink, shadow: Color = COL.red, amp: float = 9.0) -> void:
	poly_box(ci, bubble_pts(r, tail_to, seed, amp), fill, 4.0, line, shadow, Vector2(8, 8))


## ギザギザの爆発形（漫画の効果線の星）
func burst_pts(c: Vector2, r_out: float, r_in: float, n: int = 14, seed: int = 0, rot: float = 0.0) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n * 2:
		var a := rot + PI * i / n
		var r := r_out * (0.78 + 0.22 * _hash(seed + i * 1.7)) if i % 2 == 0 else r_in * (0.9 + 0.1 * _hash(seed + i))
		p.append(c + Vector2(cos(a), sin(a)) * r)
	return p


## 斜線の模様を rect の中に描く（slope = 横へずれる割合、gap = 間隔、w = 線の太さ）
func stripes(ci: CanvasItem, r: Rect2, col: Color, gap: float = 18.0, w: float = 6.0, slope: float = 0.6) -> void:
	var rect_poly := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var dx := r.size.y * slope
	var x := r.position.x - dx
	while x < r.end.x:
		var band := PackedVector2Array([Vector2(x, r.end.y), Vector2(x + w, r.end.y),
				Vector2(x + w + dx, r.position.y), Vector2(x + dx, r.position.y)])
		if x >= r.position.x and x + w + dx <= r.end.x:
			ci.draw_colored_polygon(band, col)
		else:
			for poly in Geometry2D.intersect_polygons(band, rect_poly):
				ci.draw_colored_polygon(poly, col)
		x += gap


## 網点（ハーフトーン）。from に近いほど点が大きく、reach 離れると消える
func halftone(ci: CanvasItem, r: Rect2, col: Color, from: Vector2, reach: float, spacing: float = 16.0,
		max_r: float = 5.0) -> void:
	var y := r.position.y
	var row := 0
	while y < r.end.y:
		var x := r.position.x + (spacing / 2.0 if row % 2 == 1 else 0.0)
		while x < r.end.x:
			var k := 1.0 - Vector2(x, y).distance_to(from) / reach
			if k > 0.06:
				ci.draw_circle(Vector2(x, y), max_r * k, col)
			x += spacing
		y += spacing * 0.866
		row += 1


# ============================================================
# アイコン（単位座標 -0.5〜0.5 で定義し、s 倍して描く）
# ============================================================

const ICON_DEFAULT = {
	"sword": Color("dfe6ee"), "shield": Color("4f86c6"), "flame": Color("ff8a2a"),
	"bolt": Color("ffd84a"), "heart": Color("e8484a"), "ap": Color("b88cff"),
	"star": Color("f2c84b"), "skull": Color("e9e3d0"), "drop": Color("9b59d0"),
	"snow": Color("8fe0ff"), "potion": Color("e0484a"), "swap": Color("e6edf5"),
	"burst": Color("ffb03a"), "hourglass": Color("e8c26a"), "cards": Color("5c8ad8"),
	"target_one": Color("ff6a5a"), "target_all": Color("ff6a5a"), "chevrons": Color("6fe3ff"),
	"sweep": Color("dfe6ee"), "dagger": Color("dfe6ee"), "meat": Color("c9773d"),
	"camp": Color("ff9a3a"), "crown": Color("f2c84b"), "horns": Color("d0506a"),
	"plus": Color("6fd08a"), "atk_buff": Color("dfe6ee"), "atk_debuff": Color("dfe6ee"),
	"def_buff": Color("4f86c6"), "def_debuff": Color("4f86c6"), "regen": Color("e8484a"),
	"shield_sword": Color("4f86c6"), "battle": Color("dfe6ee"), "rest": Color("ff9a3a"),
	"elite": Color("d0506a"), "boss": Color("f2c84b"), "question": Color("e6edf5"),
	"leaf": Color("6fbf4a"), "mushroom": Color("d9a46a"), "coin": Color("f2c84b"), "shop": Color("c9a26a"),
	"event": Color("b88cff"), "info": Color("8fc0ea"), "enter": Color("e8c26a"), "pin": Color("e8c26a"),
}


func icon(ci: CanvasItem, kind: String, c: Vector2, s: float, col: Color = Color(0, 0, 0, 0), rot: float = 0.0) -> void:
	var k: Color = col if col.a > 0 else ICON_DEFAULT.get(kind, Color.WHITE)
	ci.draw_set_transform(c, rot, Vector2(s, s))
	match kind:
		"sword", "battle": _i_sword(ci, k)
		"shield": _i_shield(ci, k)
		"flame": _i_flame(ci, k)
		"bolt": _i_bolt(ci, k)
		"heart": _i_heart(ci, k)
		"ap": _i_ap(ci, k)
		"star": ci.draw_colored_polygon(star_pts(Vector2.ZERO, 0.48, 0.2), k)
		"skull": _i_skull(ci, k)
		"drop": _i_drop(ci, k)
		"snow": _i_snow(ci, k)
		"potion": _i_potion(ci, k)
		"swap": _i_swap(ci, k)
		"burst": _i_burst(ci, k)
		"hourglass": _i_hourglass(ci, k)
		"cards": _i_cards(ci, k)
		"target_one": _i_target(ci, k, Vector2.ZERO, 0.42)
		"target_all":
			_i_target(ci, k, Vector2(-0.24, 0.12), 0.22)
			_i_target(ci, k, Vector2(0.24, 0.12), 0.22)
			_i_target(ci, k, Vector2(0, -0.22), 0.22)
		"chevrons": _i_chevrons(ci, k)
		"sweep": _i_sweep(ci, k)
		"dagger": _i_dagger(ci, k)
		"meat": _i_meat(ci, k)
		"camp", "rest": _i_camp(ci, k)
		"crown", "boss": _i_crown(ci, k)
		"horns", "elite": _i_horns(ci, k)
		"plus": _i_plus(ci, k, Vector2.ZERO, 0.42)
		"atk_buff":
			_i_sword(ci, k)
			_arrow(ci, Vector2(0.26, 0.24), 0.5, true)
		"atk_debuff":
			_i_sword(ci, k)
			_arrow(ci, Vector2(0.26, 0.24), 0.5, false)
		"def_buff":
			_i_shield(ci, k)
			_arrow(ci, Vector2(0.26, 0.24), 0.5, true)
		"def_debuff":
			_i_shield(ci, k)
			_arrow(ci, Vector2(0.26, 0.24), 0.5, false)
		"regen":
			_i_heart(ci, k)
			_i_plus(ci, Color.WHITE, Vector2(0.0, -0.04), 0.2)
		"shield_sword":
			_i_shield(ci, k)
			ci.draw_set_transform(c + Vector2(0.12, 0.08) * s, rot, Vector2(s, s) * 0.62)
			_i_sword(ci, ICON_DEFAULT.sword)
		"leaf": _i_leaf(ci, k)
		"mushroom": _i_mushroom(ci, k)
		"coin": _i_coin(ci, k)
		"shop": _i_shop(ci, k)
		"info": _i_info(ci, k)
		"enter": _i_enter(ci, k)
		"pin": _i_pin(ci, k)
		"question", "event":
			text_in_icon(ci, "?", k)
		_:
			ci.draw_circle(Vector2.ZERO, 0.35, k)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func text_in_icon(ci: CanvasItem, s: String, k: Color) -> void:
	ci.draw_circle(Vector2.ZERO, 0.45, Color(k, 0.25))
	ci.draw_arc(Vector2.ZERO, 0.45, 0, TAU, 24, k, 0.06, true)
	ci.draw_line(Vector2(-0.12, -0.16), Vector2(0.0, -0.26), k, 0.09, true)
	ci.draw_line(Vector2(0.0, -0.26), Vector2(0.14, -0.14), k, 0.09, true)
	ci.draw_line(Vector2(0.14, -0.14), Vector2(0.0, 0.04), k, 0.09, true)
	ci.draw_line(Vector2(0.0, 0.04), Vector2(0.0, 0.12), k, 0.09, true)
	ci.draw_circle(Vector2(0, 0.26), 0.06, k)


func _rot(arr: Array, a: float, off: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var p := PackedVector2Array()
	for v in arr:
		p.append(Vector2(v[0], v[1]).rotated(a) + off)
	return p


func _i_sword(ci: CanvasItem, k: Color) -> void:
	var a := PI / 4
	ci.draw_colored_polygon(_rot([[0, -0.5], [0.075, -0.4], [0.075, 0.16], [-0.075, 0.16], [-0.075, -0.4]], a), k)
	ci.draw_colored_polygon(_rot([[0, -0.46], [0.025, -0.4], [0.025, 0.14], [0, 0.14]], a), k.lightened(0.5))
	ci.draw_colored_polygon(_rot([[-0.22, 0.15], [0.22, 0.15], [0.22, 0.23], [-0.22, 0.23]], a), ICON_DEFAULT.star)
	ci.draw_colored_polygon(_rot([[-0.045, 0.23], [0.045, 0.23], [0.045, 0.4], [-0.045, 0.4]], a), Color("7a4a2a"))
	ci.draw_circle(Vector2(0, 0.45).rotated(a), 0.06, ICON_DEFAULT.star)


func _i_shield(ci: CanvasItem, k: Color) -> void:
	var outer := pts([[-0.4, -0.42], [0.4, -0.42], [0.4, -0.02], [0.3, 0.22], [0, 0.48], [-0.3, 0.22], [-0.4, -0.02]])
	ci.draw_colored_polygon(outer, k.lightened(0.45))
	var inner := pts([[-0.32, -0.34], [0.32, -0.34], [0.32, -0.04], [0.24, 0.17], [0, 0.38], [-0.24, 0.17], [-0.32, -0.04]])
	ci.draw_colored_polygon(inner, k)
	ci.draw_line(Vector2(0, -0.28), Vector2(0, 0.28), k.lightened(0.55), 0.08)
	ci.draw_line(Vector2(-0.22, -0.08), Vector2(0.22, -0.08), k.lightened(0.55), 0.08)


func _teardrop(c: Vector2, w: float, h: float, sway: float = 0.0) -> PackedVector2Array:
	var p := PackedVector2Array()
	var n := 14
	for i in n + 1:
		var a := PI * i / n
		p.append(c + Vector2(cos(a) * w, sin(a) * w * 0.9))
	p.append(c + Vector2(-w * 0.7 + sway * 0.4, -h * 0.45))
	p.append(c + Vector2(sway, -h))
	p.append(c + Vector2(w * 0.7 + sway * 0.4, -h * 0.45))
	# 先端を上に向けた形にするため、底辺の半円を後半に並べ替え
	var out := PackedVector2Array()
	for i in range(p.size() - 1, -1, -1):
		out.append(p[i])
	return out


func _i_flame(ci: CanvasItem, k: Color) -> void:
	ci.draw_colored_polygon(_teardrop(Vector2(0, 0.18), 0.3, 0.68), k.darkened(0.15))
	ci.draw_colored_polygon(_teardrop(Vector2(0, 0.24), 0.2, 0.46), k.lightened(0.25))
	ci.draw_colored_polygon(_teardrop(Vector2(0, 0.3), 0.1, 0.24), Color("fff3b0"))


func _i_bolt(ci: CanvasItem, k: Color) -> void:
	ci.draw_colored_polygon(pts([[0.08, -0.5], [-0.3, 0.06], [-0.02, 0.06], [-0.12, 0.5], [0.3, -0.08], [0.02, -0.08]]), k)


func _i_heart(ci: CanvasItem, k: Color) -> void:
	ci.draw_circle(Vector2(-0.2, -0.12), 0.23, k)
	ci.draw_circle(Vector2(0.2, -0.12), 0.23, k)
	ci.draw_colored_polygon(pts([[-0.42, -0.04], [0.42, -0.04], [0, 0.44]]), k)
	ci.draw_circle(Vector2(-0.24, -0.18), 0.07, Color(1, 1, 1, 0.45))


func _i_ap(ci: CanvasItem, k: Color) -> void:
	ci.draw_colored_polygon(pts([[0, -0.48], [0.36, -0.1], [0, 0.48], [-0.36, -0.1]]), k.darkened(0.2))
	ci.draw_colored_polygon(pts([[0, -0.48], [0.36, -0.1], [0, -0.02], [-0.36, -0.1]]), k.lightened(0.35))
	ci.draw_colored_polygon(pts([[0, -0.02], [0.36, -0.1], [0, 0.48]]), k)


func _i_skull(ci: CanvasItem, k: Color) -> void:
	ci.draw_circle(Vector2(0, -0.08), 0.36, k)
	ci.draw_colored_polygon(pts([[-0.2, 0.14], [0.2, 0.14], [0.18, 0.42], [-0.18, 0.42]]), k)
	ci.draw_circle(Vector2(-0.14, -0.06), 0.1, Color("1a1420"))
	ci.draw_circle(Vector2(0.14, -0.06), 0.1, Color("1a1420"))
	ci.draw_colored_polygon(pts([[0, 0.06], [0.05, 0.16], [-0.05, 0.16]]), Color("1a1420"))
	for x in [-0.1, 0.0, 0.1]:
		ci.draw_line(Vector2(x, 0.3), Vector2(x, 0.42), Color("1a1420"), 0.03)


func _i_drop(ci: CanvasItem, k: Color) -> void:
	ci.draw_circle(Vector2(0, 0.14), 0.3, k)
	ci.draw_colored_polygon(pts([[0, -0.5], [0.27, 0.02], [-0.27, 0.02]]), k)
	ci.draw_circle(Vector2(-0.1, 0.1), 0.07, Color(1, 1, 1, 0.5))


func _i_snow(ci: CanvasItem, k: Color) -> void:
	for i in 3:
		var a := PI / 3 * i
		var d := Vector2(cos(a), sin(a)) * 0.46
		ci.draw_line(-d, d, k, 0.08, true)
		for sgn in [-1, 1]:
			var e: Vector2 = d * sgn
			ci.draw_line(e * 0.6, e * 0.6 + e.rotated(0.8) * 0.3, k, 0.06, true)
			ci.draw_line(e * 0.6, e * 0.6 + e.rotated(-0.8) * 0.3, k, 0.06, true)


func _i_potion(ci: CanvasItem, k: Color) -> void:
	ci.draw_colored_polygon(pts([[-0.1, -0.42], [0.1, -0.42], [0.1, -0.16], [-0.1, -0.16]]), Color("cfe3f2", 0.85))
	ci.draw_colored_polygon(pts([[-0.13, -0.5], [0.13, -0.5], [0.13, -0.4], [-0.13, -0.4]]), Color("8a5a32"))
	ci.draw_circle(Vector2(0, 0.14), 0.34, Color("cfe3f2", 0.85))
	ci.draw_circle(Vector2(0, 0.18), 0.28, k)
	ci.draw_circle(Vector2(-0.12, 0.06), 0.07, Color(1, 1, 1, 0.6))


func _arrow_shape(ci: CanvasItem, from: Vector2, to: Vector2, k: Color, w: float) -> void:
	var d := (to - from).normalized()
	var n := d.orthogonal()
	ci.draw_line(from, to - d * 0.12, k, w, true)
	ci.draw_colored_polygon(PackedVector2Array([to, to - d * 0.2 + n * 0.14, to - d * 0.2 - n * 0.14]), k)


func _i_swap(ci: CanvasItem, k: Color) -> void:
	_arrow_shape(ci, Vector2(-0.4, -0.16), Vector2(0.42, -0.16), k, 0.1)
	_arrow_shape(ci, Vector2(0.4, 0.18), Vector2(-0.42, 0.18), k, 0.1)


func _i_burst(ci: CanvasItem, k: Color) -> void:
	ci.draw_colored_polygon(star_pts(Vector2.ZERO, 0.5, 0.24, 8, 0.0), k)
	ci.draw_colored_polygon(star_pts(Vector2.ZERO, 0.32, 0.16, 8, PI / 8), k.lightened(0.4))
	ci.draw_circle(Vector2.ZERO, 0.12, Color("fff6d0"))


func _i_hourglass(ci: CanvasItem, k: Color) -> void:
	ci.draw_colored_polygon(pts([[-0.28, -0.4], [0.28, -0.4], [0.04, 0.0], [-0.04, 0.0]]), Color(k, 0.35))
	ci.draw_colored_polygon(pts([[-0.04, 0.0], [0.04, 0.0], [0.28, 0.4], [-0.28, 0.4]]), Color(k, 0.35))
	ci.draw_colored_polygon(pts([[-0.16, 0.24], [0.16, 0.24], [0.26, 0.38], [-0.26, 0.38]]), k)
	ci.draw_colored_polygon(pts([[-0.14, -0.2], [0.14, -0.2], [0.02, -0.04], [-0.02, -0.04]]), k)
	ci.draw_line(Vector2(-0.36, -0.44), Vector2(0.36, -0.44), Color("8a5a32"), 0.08)
	ci.draw_line(Vector2(-0.36, 0.44), Vector2(0.36, 0.44), Color("8a5a32"), 0.08)


func _i_cards(ci: CanvasItem, k: Color) -> void:
	for i in 3:
		var o := Vector2(-0.14 + i * 0.1, 0.08 - i * 0.08)
		var r := Rect2(o + Vector2(-0.22, -0.32), Vector2(0.44, 0.6))
		ci.draw_rect(r, k.darkened(0.3 - i * 0.12))
		ci.draw_rect(r, ICON_DEFAULT.star, false, 0.04)


func _i_target(ci: CanvasItem, k: Color, c: Vector2, r: float) -> void:
	ci.draw_arc(c, r, 0, TAU, 24, k, r * 0.22, true)
	ci.draw_circle(c, r * 0.28, k)
	ci.draw_line(c + Vector2(-r * 1.2, 0), c + Vector2(-r * 0.6, 0), k, r * 0.18)
	ci.draw_line(c + Vector2(r * 0.6, 0), c + Vector2(r * 1.2, 0), k, r * 0.18)
	ci.draw_line(c + Vector2(0, -r * 1.2), c + Vector2(0, -r * 0.6), k, r * 0.18)
	ci.draw_line(c + Vector2(0, r * 0.6), c + Vector2(0, r * 1.2), k, r * 0.18)


func _i_chevrons(ci: CanvasItem, k: Color) -> void:
	for x in [-0.22, 0.12]:
		ci.draw_colored_polygon(pts([[x - 0.12, -0.4], [x + 0.06, -0.4], [x + 0.3, 0], [x + 0.06, 0.4], [x - 0.12, 0.4], [x + 0.12, 0]]), k)


func _i_sweep(ci: CanvasItem, k: Color) -> void:
	ci.draw_arc(Vector2(0, 0.25), 0.5, -PI * 0.95, -PI * 0.05, 24, k, 0.12, true)
	ci.draw_arc(Vector2(0, 0.25), 0.36, -PI * 0.9, -PI * 0.1, 20, Color(k, 0.5), 0.06, true)
	ci.draw_colored_polygon(pts([[0.5, 0.28], [0.36, 0.06], [0.62, 0.08]]), k)


func _i_dagger(ci: CanvasItem, k: Color) -> void:
	_i_target(ci, Color(ICON_DEFAULT.target_one, 0.75), Vector2(0.12, -0.12), 0.24)
	var a := PI / 4
	ci.draw_colored_polygon(_rot([[0, -0.3], [0.06, -0.22], [0.06, 0.12], [-0.06, 0.12], [-0.06, -0.22]], a, Vector2(-0.06, 0.06)), k)
	ci.draw_colored_polygon(_rot([[-0.16, 0.12], [0.16, 0.12], [0.16, 0.18], [-0.16, 0.18]], a, Vector2(-0.06, 0.06)), ICON_DEFAULT.star)
	ci.draw_colored_polygon(_rot([[-0.04, 0.18], [0.04, 0.18], [0.04, 0.34], [-0.04, 0.34]], a, Vector2(-0.06, 0.06)), Color("7a4a2a"))


func _i_meat(ci: CanvasItem, k: Color) -> void:
	ci.draw_line(Vector2(0.06, 0.06), Vector2(0.36, 0.36), Color("efe6d2"), 0.1)
	ci.draw_circle(Vector2(0.38, 0.32), 0.07, Color("efe6d2"))
	ci.draw_circle(Vector2(0.32, 0.4), 0.07, Color("efe6d2"))
	ci.draw_colored_polygon(ell(Vector2(-0.1, -0.1), 0.32, 0.26), k)
	ci.draw_colored_polygon(ell(Vector2(-0.16, -0.16), 0.14, 0.09), k.lightened(0.3))


func _i_camp(ci: CanvasItem, k: Color) -> void:
	ci.draw_line(Vector2(-0.4, 0.4), Vector2(0.36, 0.2), Color("8a5a32"), 0.12)
	ci.draw_line(Vector2(0.4, 0.4), Vector2(-0.36, 0.2), Color("6e4526"), 0.12)
	ci.draw_colored_polygon(_teardrop(Vector2(0, 0.16), 0.24, 0.62), k)
	ci.draw_colored_polygon(_teardrop(Vector2(0, 0.2), 0.12, 0.34), Color("ffe08a"))


func _i_crown(ci: CanvasItem, k: Color) -> void:
	ci.draw_colored_polygon(pts([[-0.42, 0.3], [-0.46, -0.24], [-0.2, 0.0], [0, -0.36], [0.2, 0.0], [0.46, -0.24], [0.42, 0.3]]), k)
	ci.draw_rect(Rect2(-0.42, 0.24, 0.84, 0.12), k.darkened(0.2))
	ci.draw_circle(Vector2(0, 0.06), 0.07, Color("e0484a"))
	for v in [Vector2(-0.46, -0.28), Vector2(0, -0.4), Vector2(0.46, -0.28)]:
		ci.draw_circle(v, 0.06, k.lightened(0.3))


func _i_horns(ci: CanvasItem, k: Color) -> void:
	ci.draw_colored_polygon(pts([[-0.22, -0.16], [-0.46, -0.48], [-0.36, -0.06]]), Color("e9e3d0"))
	ci.draw_colored_polygon(pts([[0.22, -0.16], [0.46, -0.48], [0.36, -0.06]]), Color("e9e3d0"))
	ci.draw_circle(Vector2(0, 0.02), 0.34, k)
	ci.draw_colored_polygon(pts([[-0.22, -0.06], [-0.04, 0.04], [-0.2, 0.08]]), Color("ffe24a"))
	ci.draw_colored_polygon(pts([[0.22, -0.06], [0.04, 0.04], [0.2, 0.08]]), Color("ffe24a"))
	ci.draw_colored_polygon(pts([[-0.16, 0.2], [0.16, 0.2], [0, 0.3]]), Color("1a1420"))


func _i_leaf(ci: CanvasItem, k: Color) -> void:
	ci.draw_colored_polygon(pts([[-0.36, 0.36], [-0.3, -0.1], [0.0, -0.4], [0.42, -0.44], [0.36, -0.02], [0.06, 0.3]]), k)
	ci.draw_line(Vector2(-0.4, 0.42), Vector2(0.3, -0.34), k.darkened(0.4), 0.05, true)
	ci.draw_colored_polygon(pts([[-0.1, 0.44], [-0.02, 0.18], [0.12, 0.44]]), Color("e07a3a"))


func _i_mushroom(ci: CanvasItem, k: Color) -> void:
	ci.draw_colored_polygon(pts([[-0.12, 0.0], [0.12, 0.0], [0.15, 0.44], [-0.15, 0.44]]), Color("efe6d2"))
	var cap := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		cap.append(Vector2(cos(a) * 0.46, sin(a) * 0.4 + 0.04))
	ci.draw_colored_polygon(cap, k)
	ci.draw_circle(Vector2(-0.18, -0.16), 0.07, Color(1, 1, 1, 0.7))
	ci.draw_circle(Vector2(0.14, -0.22), 0.06, Color(1, 1, 1, 0.7))


func _i_coin(ci: CanvasItem, k: Color) -> void:
	ci.draw_circle(Vector2.ZERO, 0.44, k.darkened(0.25))
	ci.draw_circle(Vector2(-0.03, -0.03), 0.4, k)
	ci.draw_arc(Vector2(-0.03, -0.03), 0.28, 0, TAU, 20, k.darkened(0.3), 0.05, true)
	ci.draw_colored_polygon(star_pts(Vector2(-0.03, -0.03), 0.18, 0.08), k.darkened(0.3))


func _i_shop(ci: CanvasItem, k: Color) -> void:
	ci.draw_colored_polygon(pts([[-0.36, -0.12], [0.36, -0.12], [0.42, 0.44], [-0.42, 0.44]]), k)
	ci.draw_arc(Vector2(0, -0.12), 0.2, PI, TAU, 14, k.darkened(0.35), 0.08, true)
	_i_coin_small(ci, Vector2(0, 0.16))


func _i_coin_small(ci: CanvasItem, c: Vector2) -> void:
	ci.draw_circle(c, 0.16, ICON_DEFAULT.coin)
	ci.draw_circle(c, 0.09, ICON_DEFAULT.coin.darkened(0.3))


func _i_info(ci: CanvasItem, k: Color) -> void:
	ci.draw_circle(Vector2.ZERO, 0.44, Color(k, 0.25))
	ci.draw_arc(Vector2.ZERO, 0.44, 0, TAU, 28, k, 0.07, true)
	ci.draw_circle(Vector2(0, -0.2), 0.07, k)
	ci.draw_rect(Rect2(-0.06, -0.06, 0.12, 0.34), k)


func _i_enter(ci: CanvasItem, k: Color) -> void:
	ci.draw_line(Vector2(0.32, -0.36), Vector2(0.32, 0.1), k, 0.1)
	_arrow_shape(ci, Vector2(0.36, 0.1), Vector2(-0.4, 0.1), k, 0.1)


func _i_pin(ci: CanvasItem, k: Color) -> void:
	ci.draw_rect(Rect2(-0.3, -0.42, 0.6, 0.12), k)
	ci.draw_colored_polygon(pts([[-0.18, -0.3], [0.18, -0.3], [0.26, 0.08], [-0.26, 0.08]]), k.darkened(0.15))
	ci.draw_line(Vector2(0, 0.08), Vector2(0, 0.46), Color("dfe6ee"), 0.07)


func _i_plus(ci: CanvasItem, k: Color, c: Vector2, r: float) -> void:
	ci.draw_rect(Rect2(c + Vector2(-r * 0.3, -r), Vector2(r * 0.6, r * 2)), k)
	ci.draw_rect(Rect2(c + Vector2(-r, -r * 0.3), Vector2(r * 2, r * 0.6)), k)


func _arrow(ci: CanvasItem, c: Vector2, sc: float, up: bool) -> void:
	var k: Color = COL.good if up else COL.bad
	var d := -1.0 if up else 1.0
	var p := pts([[0, 0.3 * d], [0.26, 0], [0.1, 0], [0.1, -0.3 * d], [-0.1, -0.3 * d], [-0.1, 0], [-0.26, 0]])
	var p2 := PackedVector2Array()
	for v in p:
		p2.append(c + v * sc)
	ci.draw_circle(c, 0.24 * sc * 1.6, Color(0, 0, 0, 0.55))
	ci.draw_colored_polygon(p2, k)


# ============================================================
# カード裏（双子座の紋章）
# ============================================================

func card_back(ci: CanvasItem, r: Rect2) -> void:
	# 黒地に赤の斜線、中央に白い双子の星
	cut_rect(ci, r, COL.ink, 10, 2.0, COL.paper)
	var inner := r.grow(-7)
	stripes(ci, inner, Color(COL.red, 0.55), 12, 4, 0.7)
	var c := r.get_center()
	var s: float = min(r.size.x, r.size.y)
	ci.draw_colored_polygon(slant_pts(Rect2(c - Vector2(s * 0.42, s * 0.2), Vector2(s * 0.84, s * 0.4)), s * 0.12), COL.ink)
	ci.draw_colored_polygon(star_pts(c + Vector2(-s * 0.13, -s * 0.03), s * 0.12, s * 0.05), COL.paper)
	ci.draw_colored_polygon(star_pts(c + Vector2(s * 0.13, s * 0.03), s * 0.12, s * 0.05), COL.paper)


# ============================================================
# キャラクター（足元が origin、右向きで定義。facing=-1 で左右反転）
# ============================================================

func character(ci: CanvasItem, kind: String, origin: Vector2, sc: float, facing: float, t: float) -> void:
	ci.draw_set_transform(origin, 0.0, Vector2(sc * facing, sc))
	match kind:
		"knight": _c_armored(ci, t, false, {"steel": Color("8fa3b8"), "dark": Color("566a80"), "light": Color("cfdae6"),
				"cape": Color("2f55a8"), "plume": Color("d8423a"), "blade": Color("e6eef6")})
		"witch": _c_witch(ci, t)
		"goblin": _c_goblin(ci, t)
		"gool": _c_gool(ci, t)
		"zombie": _c_zombie(ci, t)
		"skeleton": _c_skeleton(ci, t)
		"harpy": _c_harpy(ci, t)
		"fire_warriar": _c_fire(ci, t)
		"dark_knight": _c_armored(ci, t, true, {"steel": Color("4a4060"), "dark": Color("2c2640"), "light": Color("6e6290"),
				"cape": Color("6a1f3a"), "plume": Color("6a1f3a"), "blade": Color("b7a8e0")})
		"green_dragon": _c_dragon(ci, t)
		"necro": _c_necro(ci, t)
		_: ci.draw_circle(Vector2(0, -50), 40, Color.MAGENTA)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func shadow(ci: CanvasItem, origin: Vector2, w: float) -> void:
	ci.draw_colored_polygon(ell(origin + Vector2(0, 2), w, w * 0.22), Color(0, 0, 0, 0.35))


func _c_armored(ci: CanvasItem, t: float, headless: bool, p: Dictionary) -> void:
	# マント
	ci.draw_colored_polygon(pts([[-12, -82], [8, -82], [-2, -24], [-34, -14], [-28, -50]]), p.cape)
	# 脚
	ci.draw_rect(Rect2(-15, -36, 11, 30), p.dark)
	ci.draw_rect(Rect2(4, -36, 11, 30), p.dark)
	ci.draw_rect(Rect2(-18, -9, 15, 9), Color("2a2230"))
	ci.draw_rect(Rect2(3, -9, 17, 9), Color("2a2230"))
	# 背中側の盾
	var sh := pts([[-40, -74], [-12, -74], [-12, -54], [-18, -40], [-26, -32], [-34, -40], [-40, -54]])
	ci.draw_colored_polygon(sh, ICON_DEFAULT.star.darkened(0.2))
	var sh2 := pts([[-37, -71], [-15, -71], [-15, -55], [-20, -43], [-26, -36], [-32, -43], [-37, -55]])
	ci.draw_colored_polygon(sh2, p.cape.lightened(0.15))
	# 胴
	ci.draw_colored_polygon(pts([[-20, -84], [20, -84], [16, -34], [-16, -34]]), p.steel)
	ci.draw_colored_polygon(pts([[-10, -80], [6, -80], [2, -52], [-8, -52]]), Color(p.light, 0.6))
	ci.draw_rect(Rect2(-17, -42, 34, 7), Color("5a3a24"))
	ci.draw_rect(Rect2(-4, -42, 8, 7), ICON_DEFAULT.star)
	ci.draw_circle(Vector2(-18, -80), 9, p.light)
	ci.draw_circle(Vector2(18, -80), 9, p.light)
	# 剣
	var sw := sin(t * 2.0) * 2.0
	ci.draw_line(Vector2(24, -56), Vector2(48 + sw, -122), p.blade, 7, true)
	ci.draw_line(Vector2(26, -62), Vector2(46 + sw, -118), p.blade.lightened(0.6), 2, true)
	ci.draw_line(Vector2(13, -60), Vector2(35, -50), ICON_DEFAULT.star, 5, true)
	ci.draw_line(Vector2(24, -56), Vector2(20, -44), Color("5a3a24"), 5, true)
	if headless:
		# 首元の青い鬼火
		var sway := sin(t * 6.0) * 3.0
		ci.draw_colored_polygon(_teardrop(Vector2(0, -88), 14, 44, sway), Color("5fd0ff", 0.85))
		ci.draw_colored_polygon(_teardrop(Vector2(0, -88), 7, 26, sway * 0.6), Color("d8f6ff"))
	else:
		ci.draw_circle(Vector2(0, -100), 17, p.steel)
		ci.draw_colored_polygon(ell(Vector2(-2, -104), 14, 9), p.light)
		ci.draw_rect(Rect2(3, -103, 15, 5), Color("15121c"))
		ci.draw_colored_polygon(pts([[-2, -115], [-8, -122], [-32, -114], [-28, -101], [-12, -108]]), p.plume)


func _c_witch(ci: CanvasItem, t: float) -> void:
	var purple := Color("6a3fa0")
	ci.draw_colored_polygon(pts([[-30, 0], [30, 0], [14, -72], [-14, -72]]), purple)
	ci.draw_colored_polygon(pts([[-8, 0], [8, 0], [4, -66], [-4, -66]]), purple.darkened(0.25))
	ci.draw_rect(Rect2(-30, -7, 60, 7), ICON_DEFAULT.star.darkened(0.1))
	ci.draw_colored_polygon(pts([[-17, -98], [13, -98], [16, -68], [-20, -62]]), Color("e8a33d"))
	ci.draw_circle(Vector2(2, -86), 12, Color("f3d1b5"))
	ci.draw_circle(Vector2(8, -87), 2.2, Color("2a1a30"))
	ci.draw_colored_polygon(pts([[10, -64], [30, -52], [26, -44], [8, -54]]), purple.darkened(0.15))
	ci.draw_colored_polygon(ell(Vector2(0, -99), 31, 7), Color("3b2163"))
	ci.draw_colored_polygon(pts([[-15, -101], [15, -101], [3, -128], [-20, -144], [-7, -124]]), Color("3b2163"))
	ci.draw_rect(Rect2(-15, -108, 30, 5), ICON_DEFAULT.star)
	# 杖
	ci.draw_line(Vector2(30, -4), Vector2(30, -112), Color("8a5a32"), 4, true)
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	glow(ci, Vector2(30, -119), 18 + pulse * 4, Color("6fe3ff", 0.8))
	ci.draw_circle(Vector2(30, -119), 7, Color("bff4ff"))


func _c_goblin(ci: CanvasItem, t: float) -> void:
	var g := Color("5fa04a")
	ci.draw_rect(Rect2(-12, -24, 9, 24), g.darkened(0.3))
	ci.draw_rect(Rect2(3, -24, 9, 24), g.darkened(0.3))
	ci.draw_colored_polygon(ell(Vector2(0, -40), 20, 20), g)
	ci.draw_colored_polygon(pts([[-18, -32], [18, -32], [14, -18], [-14, -18]]), Color("7a5232"))
	ci.draw_colored_polygon(pts([[-14, -78], [-36, -90], [-12, -66]]), g.darkened(0.1))
	ci.draw_colored_polygon(pts([[16, -78], [36, -92], [18, -64]]), g.darkened(0.1))
	ci.draw_circle(Vector2(2, -72), 18, g.lightened(0.08))
	ci.draw_circle(Vector2(9, -75), 4.5, Color("ffe24a"))
	ci.draw_circle(Vector2(10, -75), 2.2, Color("c0201a"))
	ci.draw_line(Vector2(4, -62), Vector2(16, -64), Color("2a1a10"), 2)
	ci.draw_colored_polygon(pts([[8, -63], [11, -63], [9.5, -59]]), Color.WHITE)
	var sw := sin(t * 3.0) * 4.0
	ci.draw_line(Vector2(18, -42), Vector2(36 + sw, -80), Color("7a5232"), 6, true)
	ci.draw_circle(Vector2(38 + sw, -84), 10, Color("5a3a24"))


func _c_gool(ci: CanvasItem, t: float) -> void:
	var g := Color("7d8f6a")
	ci.draw_line(Vector2(-10, 0), Vector2(-6, -24), g.darkened(0.3), 7)
	ci.draw_line(Vector2(10, 0), Vector2(8, -24), g.darkened(0.3), 7)
	ci.draw_colored_polygon(pts([[-20, -20], [12, -20], [26, -70], [-4, -86], [-24, -60]]), g)
	for i in 3:
		ci.draw_line(Vector2(-14 + i * 3, -36 - i * 12), Vector2(6 + i * 4, -40 - i * 12), g.darkened(0.25), 2)
	ci.draw_circle(Vector2(24, -84), 15, g.lightened(0.1))
	glow(ci, Vector2(30, -86), 8, Color("ff3a2a", 0.9), 4)
	ci.draw_circle(Vector2(30, -86), 3, Color("ffd0c0"))
	var sw := sin(t * 2.5) * 5.0
	ci.draw_line(Vector2(14, -66), Vector2(42, -38 + sw), g.darkened(0.1), 6, true)
	for i in 3:
		ci.draw_line(Vector2(42, -38 + sw), Vector2(50, -34 + sw + i * 4), Color("e9e3d0"), 2)


func _c_zombie(ci: CanvasItem, t: float) -> void:
	var skin := Color("8db07a")
	ci.draw_rect(Rect2(-14, -36, 11, 36), Color("4a3a30"))
	ci.draw_rect(Rect2(3, -36, 11, 36), Color("4a3a30"))
	ci.draw_colored_polygon(pts([[-16, -82], [16, -82], [16, -40], [8, -32], [0, -40], [-8, -32], [-16, -40]]), Color("4b6a8f"))
	var sw := sin(t * 2.0) * 3.0
	ci.draw_line(Vector2(6, -76), Vector2(44, -70 + sw), skin, 9, true)
	ci.draw_line(Vector2(0, -70), Vector2(40, -62 - sw), skin.darkened(0.15), 9, true)
	ci.draw_circle(Vector2(2, -96), 15, skin)
	ci.draw_colored_polygon(pts([[-14, -104], [12, -110], [16, -100], [-15, -94]]), Color("2a2a2a"))
	ci.draw_circle(Vector2(9, -96), 3.2, Color("f4f4d0"))
	ci.draw_line(Vector2(-6, -90), Vector2(-2, -86), Color("3a2a2a"), 2)


func _c_skeleton(ci: CanvasItem, t: float) -> void:
	var b := Color("e8e2cf")
	ci.draw_line(Vector2(-8, 0), Vector2(-7, -34), b, 4)
	ci.draw_line(Vector2(8, 0), Vector2(7, -34), b, 4)
	ci.draw_colored_polygon(ell(Vector2(0, -36), 13, 6), b)
	ci.draw_line(Vector2(0, -36), Vector2(0, -82), b, 4)
	for i in 4:
		var y := -48.0 - i * 9.0
		ci.draw_arc(Vector2(0, y + 6), 15 - i, -PI * 0.95, -PI * 0.05, 10, b, 3)
	var sw := sin(t * 3.0) * 4.0
	ci.draw_line(Vector2(-4, -78), Vector2(-20, -50), b, 3)
	ci.draw_line(Vector2(4, -78), Vector2(22, -54), b, 3)
	ci.draw_line(Vector2(22, -54), Vector2(40 + sw, -108), Color("a07a5a"), 5, true)
	ci.draw_line(Vector2(14, -60), Vector2(30, -50), Color("7a6a5a"), 4)
	ci.draw_circle(Vector2(2, -96), 15, b)
	ci.draw_rect(Rect2(-6, -86, 15, 8), b)
	ci.draw_circle(Vector2(-3, -97), 4.5, Color("1a1420"))
	ci.draw_circle(Vector2(9, -97), 4.5, Color("1a1420"))


func _c_harpy(ci: CanvasItem, t: float) -> void:
	var lift := -18.0 + sin(t * 3.0) * 5.0
	var flap := sin(t * 7.0) * 18.0
	var feather := Color("8a5aa0")
	ci.draw_colored_polygon(pts([[0, -70 + lift], [-56, -104 + lift + flap], [-46, -72 + lift + flap * 0.5], [-34, -56 + lift], [-6, -50 + lift]]), feather.darkened(0.2))
	ci.draw_line(Vector2(-6, -36 + lift), Vector2(-8, -20 + lift), Color("e8c24a"), 3)
	ci.draw_line(Vector2(6, -36 + lift), Vector2(8, -20 + lift), Color("e8c24a"), 3)
	ci.draw_colored_polygon(ell(Vector2(0, -58 + lift), 14, 22), Color("b07a6a"))
	ci.draw_colored_polygon(pts([[-12, -96 + lift], [12, -98 + lift], [10, -76 + lift], [-16, -70 + lift]]), Color("c0507a"))
	ci.draw_circle(Vector2(3, -90 + lift), 11, Color("f0c8b0"))
	ci.draw_circle(Vector2(8, -91 + lift), 2.2, Color("4a1a2a"))
	ci.draw_colored_polygon(pts([[4, -68 + lift], [52, -98 + lift + flap], [44, -66 + lift + flap * 0.5], [30, -52 + lift], [6, -48 + lift]]), feather)


func _c_fire(ci: CanvasItem, t: float) -> void:
	var sway := sin(t * 5.0) * 7.0
	ci.draw_colored_polygon(_teardrop(Vector2(0, -26), 30, 104, sway), Color("c8321e"))
	ci.draw_colored_polygon(_teardrop(Vector2(0, -24), 22, 82, sway * 0.8), Color("ff7a1e"))
	ci.draw_colored_polygon(_teardrop(Vector2(0, -22), 12, 50, sway * 0.5), Color("ffd34a"))
	ci.draw_circle(Vector2(8, -64), 4, Color.WHITE)
	ci.draw_circle(Vector2(-4, -64), 4, Color.WHITE)
	ci.draw_circle(Vector2(9, -64), 2, Color("401008"))
	ci.draw_circle(Vector2(-3, -64), 2, Color("401008"))
	ci.draw_line(Vector2(22, -40), Vector2(46, -104), Color("ffb03a"), 6, true)
	ci.draw_line(Vector2(14, -46), Vector2(30, -36), Color("6a3a1a"), 4)


func _c_dragon(ci: CanvasItem, t: float) -> void:
	var g := Color("3f8f4f")
	var flap := sin(t * 3.0) * 14.0
	ci.draw_colored_polygon(pts([[-30, -22], [-74, -10], [-92, -30], [-66, -26], [-30, -42]]), g.darkened(0.15))
	ci.draw_colored_polygon(pts([[-8, -78], [-62, -150 + flap], [-34, -118 + flap * 0.5], [-14, -132 + flap], [12, -88]]), g.darkened(0.35))
	ci.draw_rect(Rect2(-30, -28, 16, 28), g.darkened(0.2))
	ci.draw_rect(Rect2(12, -28, 16, 28), g.darkened(0.2))
	ci.draw_colored_polygon(ell(Vector2(0, -52), 46, 34), g)
	ci.draw_colored_polygon(ell(Vector2(12, -44), 26, 22), Color("c8d98a"))
	ci.draw_colored_polygon(pts([[18, -72], [38, -112], [56, -106], [36, -62]]), g)
	ci.draw_colored_polygon(ell(Vector2(56, -114), 24, 15), g.lightened(0.05))
	ci.draw_colored_polygon(pts([[66, -118], [86, -110], [70, -104]]), g.lightened(0.05))
	ci.draw_colored_polygon(pts([[44, -124], [36, -146], [52, -126]]), Color("e9e3d0"))
	ci.draw_colored_polygon(pts([[54, -126], [52, -150], [62, -126]]), Color("e9e3d0"))
	ci.draw_circle(Vector2(62, -118), 3.5, Color("ffe24a"))
	ci.draw_line(Vector2(74, -106), Vector2(82, -106), Color("1a1420"), 2)
	ci.draw_colored_polygon(pts([[2, -82], [48, -152 + flap], [36, -112 + flap * 0.5], [56, -118 + flap], [26, -84]]), g.lightened(0.12))


func _c_necro(ci: CanvasItem, t: float) -> void:
	var lift := -10.0 + sin(t * 2.0) * 4.0
	var robe := Color("2b2338")
	var p := PackedVector2Array()
	p.append(Vector2(16, -82 + lift))
	p.append(Vector2(-16, -82 + lift))
	for i in 7:
		var x := -28.0 + i * 9.333
		p.append(Vector2(x, lift + (0.0 if i % 2 == 0 else -10.0)))
	ci.draw_colored_polygon(p, robe)
	ci.draw_colored_polygon(pts([[-19, -80 + lift], [19, -80 + lift], [15, -112 + lift], [0, -124 + lift], [-15, -112 + lift]]), robe.darkened(0.35))
	ci.draw_circle(Vector2(3, -98 + lift), 10, Color("e9e3d0"))
	glow(ci, Vector2(7, -100 + lift), 6, Color("c070ff"), 3)
	ci.draw_circle(Vector2(7, -100 + lift), 2.4, Color("f0d0ff"))
	ci.draw_line(Vector2(28, lift - 2), Vector2(28, -122 + lift), Color("5a4a3a"), 4, true)
	var pulse := 0.5 + 0.5 * sin(t * 4.0)
	glow(ci, Vector2(28, -128 + lift), 18 + pulse * 5, Color("b060ff", 0.9))
	ci.draw_circle(Vector2(28, -128 + lift), 7, Color("e6c8ff"))
	for i in 3:
		var a := t * 1.5 + TAU * i / 3
		ci.draw_circle(Vector2(cos(a) * 34, -60 + lift + sin(a) * 12), 3, Color("b060ff", 0.7))


# ============================================================
# 背景
# ============================================================

func background(ci: CanvasItem, kind: String, r: Rect2, t: float) -> void:
	match kind:
		"camp": _bg_camp(ci, r, t)
		"title": _bg_cave(ci, r, t, true)
		"map": _bg_map(ci, r, t)
		_: _bg_cave(ci, r, t, false)


func _vgrad(ci: CanvasItem, r: Rect2, top: Color, bottom: Color, steps: int = 24) -> void:
	var h := r.size.y / steps
	for i in steps:
		ci.draw_rect(Rect2(r.position.x, r.position.y + h * i, r.size.x, h + 1), top.lerp(bottom, float(i) / (steps - 1)))


## 画面を斜めに横切る光の帯（赤と白の細い筋）
func _slash(ci: CanvasItem, r: Rect2, y0: float, y1: float, w: float, col: Color) -> void:
	var p := PackedVector2Array([Vector2(r.position.x, y0), Vector2(r.position.x, y0 + w),
			Vector2(r.end.x, y1 + w), Vector2(r.end.x, y1)])
	ci.draw_colored_polygon(p, col)


func _bg_cave(ci: CanvasItem, r: Rect2, t: float, title: bool) -> void:
	var ground_y := r.position.y + r.size.y * (0.62 if not title else 0.72)
	_vgrad(ci, Rect2(r.position, Vector2(r.size.x, ground_y - r.position.y)), Color("060608"), Color("1c1b21"))
	_vgrad(ci, Rect2(r.position.x, ground_y, r.size.x, r.end.y - ground_y), Color("17161b"), Color("070709"), 12)
	# 斜めに差す赤い光と白い筋
	_slash(ci, r, r.position.y + r.size.y * 0.30, r.position.y - r.size.y * 0.05, r.size.y * 0.16, Color(COL.red, 0.10))
	_slash(ci, r, r.position.y + r.size.y * 0.47, r.position.y + r.size.y * 0.10, 5, Color(COL.red, 0.35))
	_slash(ci, r, r.position.y + r.size.y * 0.50, r.position.y + r.size.y * 0.13, 2, Color(1, 1, 1, 0.10))
	# 網点（左上は白、右下は赤）
	halftone(ci, Rect2(r.position, Vector2(300, 300)), Color(1, 1, 1, 0.05), r.position, 320, 18, 5)
	halftone(ci, Rect2(r.end - Vector2(300, 260), Vector2(300, 260)), Color(COL.red, 0.12), r.end, 320, 18, 5)
	# 奥の岩壁（尖ったシルエット）
	var wall := PackedVector2Array()
	wall.append(Vector2(r.position.x, ground_y))
	var n := 14
	for i in n + 1:
		var x := r.position.x + r.size.x * i / n
		var y := ground_y - 50 - (34 if i % 2 == 0 else 6) - 18 * sin(i * 1.7)
		wall.append(Vector2(x, y))
	wall.append(Vector2(r.end.x, ground_y))
	ci.draw_colored_polygon(wall, Color("0e0e11"))
	ci.draw_line(Vector2(r.position.x, ground_y), Vector2(r.end.x, ground_y), Color(1, 1, 1, 0.12), 2)
	# つらら
	for i in 9:
		var x := r.position.x + (i + 0.5) * r.size.x / 9.0
		var l := 40.0 + 34.0 * absf(sin(i * 2.3))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 22, r.position.y), Vector2(x + 22, r.position.y), Vector2(x + 3, r.position.y + l)]), Color("040405"))
	# 地面の遠近線
	var cx := r.get_center().x
	for i in 7:
		var x := r.position.x + r.size.x * i / 6.0
		ci.draw_line(Vector2(cx + (x - cx) * 0.3, ground_y), Vector2(x, r.end.y), Color(1, 1, 1, 0.05), 2)
	for i in 4:
		var y := ground_y + (r.end.y - ground_y) * pow((i + 1) / 5.0, 1.6)
		ci.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(1, 1, 1, 0.04), 2)
	# 松明（赤い炎と白い芯）
	for side in [-1, 1]:
		var tx: float = cx + side * r.size.x * 0.46
		var ty := ground_y - (90.0 if title else 190.0)
		var fl := 0.85 + 0.15 * sin(t * 9.0 + side) + 0.08 * sin(t * 23.0)
		glow(ci, Vector2(tx, ty), 110 * fl, Color(COL.red, 0.30), 8)
		ci.draw_line(Vector2(tx, ty + 6), Vector2(tx, ty + 46), Color("2a2a30"), 6)
		ci.draw_colored_polygon(_teardrop(Vector2(tx, ty + 4), 9, 30 * fl, sin(t * 7.0 + side) * 3), COL.red)
		ci.draw_colored_polygon(_teardrop(Vector2(tx, ty + 6), 4, 16 * fl, 0), COL.paper)
	# 漂う光の粒（白と赤）
	for i in 14:
		var px := r.position.x + fmod(i * 97.0 + t * (8 + i % 5), r.size.x)
		var py := r.position.y + fmod(i * 61.0 - t * (5 + i % 3) * 3.0 + 2000.0, ground_y - r.position.y)
		var pc := COL.red if i % 3 == 0 else Color.WHITE
		ci.draw_rect(Rect2(Vector2(px, py), Vector2(3, 3)), Color(pc, 0.22 + 0.15 * sin(t * 2 + i)))


func _bg_camp(ci: CanvasItem, r: Rect2, t: float) -> void:
	_bg_cave(ci, r, t, true)
	var c := Vector2(r.get_center().x, r.position.y + r.size.y * 0.44)  # 休憩所の画面で見える高さに置く
	var fl := 0.9 + 0.1 * sin(t * 8.0) + 0.06 * sin(t * 21.0)
	glow(ci, c + Vector2(0, -40), 260 * fl, Color(COL.red, 0.35), 10)
	ci.draw_colored_polygon(slant_pts(Rect2(c.x - 150, c.y + 14, 300, 14), 10), COL.ink)
	ci.draw_line(c + Vector2(-70, 14), c + Vector2(64, -10), Color("2a2a30"), 16)
	ci.draw_line(c + Vector2(70, 14), c + Vector2(-64, -10), Color("3a3a42"), 16)
	var sway := sin(t * 5.0) * 6.0
	ci.draw_colored_polygon(_teardrop(c + Vector2(0, -6), 46 * fl, 140 * fl, sway), COL.red_d)
	ci.draw_colored_polygon(_teardrop(c + Vector2(0, -4), 32 * fl, 100 * fl, sway * 0.7), COL.red)
	ci.draw_colored_polygon(_teardrop(c + Vector2(0, -2), 16 * fl, 56 * fl, sway * 0.4), COL.paper)
	for i in 8:
		var k := fmod(t * 0.6 + i * 0.137, 1.0)
		ci.draw_rect(Rect2(c + Vector2(sin(i * 3.1 + t) * 30, -60 - k * 220), Vector2(3, 3)), Color(COL.red.lightened(0.3), 1.0 - k))


func _bg_map(ci: CanvasItem, r: Rect2, t: float) -> void:
	_vgrad(ci, r, Color("0d0d10"), Color("050506"))
	# 細かい斜線の地模様
	stripes(ci, r, Color(1, 1, 1, 0.025), 22, 2, 0.6)
	# 左上から伸びる赤い大きな斜めの帯
	var band := PackedVector2Array([Vector2(r.position.x, r.position.y + 40), Vector2(r.position.x + 520, r.position.y),
			Vector2(r.position.x + 720, r.position.y), Vector2(r.position.x, r.position.y + 420)])
	ci.draw_colored_polygon(band, Color(COL.red, 0.10))
	_slash(ci, r, r.position.y + 470, r.position.y - 60, 4, Color(COL.red, 0.35))
	halftone(ci, Rect2(r.end - Vector2(320, 320), Vector2(320, 320)), Color(COL.red, 0.10), r.end, 360, 18, 5)
	halftone(ci, Rect2(r.position + Vector2(0, r.size.y * 0.45), Vector2(240, 300)), Color(1, 1, 1, 0.04),
			r.position + Vector2(0, r.size.y * 0.6), 220, 18, 4)
	for i in 30:
		var p := Vector2(fmod(i * 173.0, r.size.x), fmod(i * 291.0, r.size.y)) + r.position
		ci.draw_rect(Rect2(p, Vector2(2, 2)), Color(1, 1, 1, 0.08 + 0.06 * sin(t + i)))
