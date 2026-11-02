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
# アイコン入りの文字（"[i:アイコン名]" の位置にアイコンを文字の高さで描く）
# ============================================================

const RICH_CLOSE := "。、，．）」』】〕・ー！？!?)]%,.：:"  # 行頭に来させない文字
const RICH_OPEN := "（「『【〔(["  # 行末に残さない文字

## アイコン 1 つ分の送り幅（文字サイズ size に対して）
func _rich_icon_w(size: int) -> float:
	return size * 1.3


## 文字列を部品に分ける：[{"t": 文字 or "", "i": アイコン名 or "", "w": 幅}]。"\n" は {"nl": true}
func _rich_atoms(s: String, size: int) -> Array:
	var f: Font = font_bold
	var out: Array = []
	var i := 0
	var n := s.length()
	while i < n:
		var ch := s[i]
		if ch == "[" and s.substr(i, 3) == "[i:":
			var e := s.find("]", i)
			if e > i:
				out.append({"t": "", "i": s.substr(i + 3, e - i - 3), "w": _rich_icon_w(size)})
				i = e + 1
				continue
		if ch == "\n":
			out.append({"nl": true})
		else:
			out.append({"t": ch, "i": "", "w": f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x})
		i += 1
	return out


## 半角の英数字（続けて並んだ数字は途中で折り返さない）
func _rich_ascii(a: Dictionary) -> bool:
	var t: String = a.get("t", "")
	if t == "" or t == " ":
		return false
	var c := t.unicode_at(0)
	return c < 128 and c != 32


## a と b の間で折り返してよいか
func _rich_can_break(a: Dictionary, b: Dictionary) -> bool:
	if a.get("i", "") != "":
		return false  # アイコンは次の文字とくっつける
	if _rich_ascii(a) and _rich_ascii(b):
		return false
	if b.get("t", "") != "" and RICH_CLOSE.contains(b.t):
		return false
	if a.get("t", "") != "" and RICH_OPEN.contains(a.t):
		return false
	return true


## 部品を幅 max_w の行に分ける。戻り値：行の配列（各行は部品の配列）
func _rich_lines(s: String, size: int, max_w: float) -> Array:
	var atoms := _rich_atoms(s, size)
	# 全角空白の直後から次の全角空白（か改行）までを「句」とし、句が次の行に丸ごと入るなら句の頭で折り返す
	var phrase_w := {}
	for k in atoms.size():
		if k > 0 and atoms[k - 1].get("t", "") == "　" and atoms[k].get("t", "") != "　":
			var pw := 0.0
			var j := k
			while j < atoms.size() and not atoms[j].has("nl") and atoms[j].get("t", "") != "　":
				pw += float(atoms[j].w)
				j += 1
			phrase_w[k] = pw
	var lines: Array = []
	var cur: Array = []
	var cur_w := 0.0
	# 折り返せない部品のまとまり（語）を作りながら行へ詰める
	var word: Array = []
	var word_w := 0.0
	var phrase_break := false  # 次の語の前で改行する
	for k in atoms.size() + 1:
		var a: Dictionary = atoms[k] if k < atoms.size() else {"nl": true, "end": true}
		var flush := a.has("nl")
		if not flush and not word.is_empty() and _rich_can_break(word[word.size() - 1], a):
			flush = true
		if flush and not word.is_empty():
			if phrase_break and not cur.is_empty():
				lines.append(cur)
				cur = []
				cur_w = 0.0
			phrase_break = false
			if max_w > 0 and not cur.is_empty() and cur_w + word_w > max_w:
				lines.append(cur)
				cur = []
				cur_w = 0.0
				# 折り返した行の頭の空白は捨てる
				while not word.is_empty() and (word[0].get("t", "") == "　" or word[0].get("t", "") == " "):
					word_w -= float(word[0].w)
					word.pop_front()
			# 1 語が 1 行より長い時は部品ごとに折り返す
			for w in word:
				if max_w > 0 and not cur.is_empty() and cur_w + float(w.w) > max_w:
					lines.append(cur)
					cur = []
					cur_w = 0.0
				cur.append(w)
				cur_w += float(w.w)
			word = []
			word_w = 0.0
		if a.has("nl"):
			if not a.has("end") or not cur.is_empty() or lines.is_empty():
				lines.append(cur)
			cur = []
			cur_w = 0.0
			continue
		if max_w > 0 and phrase_w.has(k):
			# 句の頭：今の行に入りきらず、次の行なら丸ごと入る時は句の前で改行（行末に全角空白が残っても見えない）
			var rest := cur_w + word_w
			if rest + float(phrase_w[k]) > max_w and float(phrase_w[k]) <= max_w:
				# 直前の語（全角空白）を今の行に入れてから改行させる
				for w in word:
					cur.append(w)
					cur_w += float(w.w)
				word = []
				word_w = 0.0
				phrase_break = true
		word.append(a)
		word_w += float(a.w)
	return lines


func _rich_line_w(line: Array) -> float:
	var w := 0.0
	for a in line:
		w += float(a.w)
	return w


## アイコン入りの文字を描く。pos = 1行目の左上（align=0）／上中央（align=1）。max_w を超えたら折り返す。戻り値＝描いた高さ
## 文字の色が暗い時（白い紙の上）は、アイコンの後ろに黒い丸を敷いて明るいアイコンも見えるようにする
func rich_text(ci: CanvasItem, s: String, pos: Vector2, size: int, col: Color, max_w: float = -1.0,
		align: int = 0, line_h: float = 0.0) -> float:
	var lh := line_h if line_h > 0 else size * 1.5
	var f: Font = font_bold
	var on_paper := col.get_luminance() < 0.5
	var lines := _rich_lines(s, size, max_w)
	var y := pos.y
	for line in lines:
		var x := pos.x
		if align == 1:
			x = pos.x - _rich_line_w(line) / 2.0
		var mid := y + lh / 2.0
		var base := mid + (f.get_ascent(size) - f.get_descent(size)) / 2.0
		for a in line:
			var w := float(a.w)
			if a.i != "":
				var c := Vector2(x + w / 2.0, mid)
				if on_paper:
					ci.draw_circle(c, size * 0.66, COL.ink)
					icon(ci, a.i, c, size * 1.04)
				else:
					icon(ci, a.i, c, size * 1.12)
			else:
				ci.draw_string(f, Vector2(x, base), a.t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
			x += w
		y += lh
	return lines.size() * lh


## rich_text で描いた時の高さ（描かない）
func rich_height(s: String, size: int, max_w: float, line_h: float = 0.0) -> float:
	var lh := line_h if line_h > 0 else size * 1.5
	return _rich_lines(s, size, max_w).size() * lh


## rich_text の一番長い行の幅（折り返さない時。max_w を渡すと折り返した後の幅）
func rich_width(s: String, size: int, max_w: float = -1.0) -> float:
	var w := 0.0
	for line in _rich_lines(s, size, max_w):
		w = maxf(w, _rich_line_w(line))
	return w


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
	# ステータス
	"stat_hp": Color("e8213a"), "stat_atk": Color("e6eef6"), "stat_def": Color("b9c2cc"), "stat_spd": Color("6fe3ff"),
	# アイテム
	"item_herb": Color("6fbf4a"), "item_fire": Color("ff6a2a"), "item_power": Color("4f9cff"),
	# 状態異常
	"st_poison": Color("8be04a"), "st_atk_down": Color("e6eef6"), "st_def_up": Color("b9c2cc"),
	"st_def_down": Color("b9c2cc"), "st_ap_plus": Color("b88cff"), "st_ap_next": Color("b88cff"),
	"st_taunt": Color("ff3048"), "st_fire_guard": Color("ff8a2a"), "st_double": Color("c79bff"),
	# カードの絵柄（ウィッチ）
	"c_swap": Color("e6edf5"), "c_force": Color("b88cff"), "c_draw_magic": Color("5c8ad8"),
	"c_hit_away": Color("e6eef6"), "c_atk_down": Color("e6eef6"), "c_def_down": Color("b9c2cc"),
	"c_poison_gas": Color("8be04a"), "c_meditate": Color("c79bff"), "c_magic_wall": Color("8fe0ff"),
	"c_double": Color("c79bff"),
	# カードの絵柄（ナイト）
	"c_big_shield": Color("4f86c6"), "c_fire_guard": Color("ff8a2a"), "c_hone": Color("e6eef6"),
	"c_flash": Color("f7f5f0"), "c_taunt": Color("ff3048"), "c_big_swing": Color("e6eef6"),
	"c_steel": Color("b9c2cc"), "c_store": Color("ffd84a"), "c_full_strike": Color("ff5a2a"),
	"c_stand": Color("b9c2cc"),
	# 対象（敵＝赤い人影、味方＝白い人影）
	"tgt_enemy_one": Color("ff4a4a"), "tgt_enemy_group": Color("ff4a4a"), "tgt_front_row": Color("ff4a4a"),
	"tgt_enemy_all": Color("ff4a4a"), "tgt_self": Color("f7f5f0"), "tgt_ally_all": Color("f7f5f0"),
	# キーワード（パワー／廃棄）
	"kw_power": Color("b88cff"), "kw_exhaust": Color("e8213a"),
	# 5回目の追加：カードの絵柄（ナイト）
	"c_chop": Color("e6eef6"), "c_flurry": Color("ffb03a"), "c_rampart": Color("b9c2cc"), "c_parry": Color("4f86c6"),
	"c_focus": Color("6fe3ff"), "c_barricade": Color("c9773d"), "c_dance": Color("e6eef6"), "c_declare": Color("e8213a"),
	"c_holy": Color("ffd84a"), "c_mushin": Color("ff3048"),
	# 5回目の追加：カードの絵柄（ウィッチ）
	"c_ap_pass": Color("b88cff"), "c_golem": Color("a8957e"), "c_reblock": Color("4f86c6"), "c_drain": Color("e8484a"),
	"c_absorb": Color("c79bff"), "c_quake": Color("c9935a"), "c_absorb_block": Color("4f86c6"), "c_energy": Color("ffd84a"),
	"c_inferno": Color("ff5a2a"), "c_overload": Color("c79bff"),
	# 5回目の追加：状態・キーワード・対象
	"st_barricade": Color("c9773d"), "st_focus": Color("6fe3ff"), "st_declare": Color("e8213a"), "st_reblock": Color("4f86c6"),
	"kw_consume": Color("ff8a2a"), "kw_apx": Color("b88cff"), "tgt_ally_other": Color("f7f5f0"),
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
			if not _icon_ext(ci, kind, k, Transform2D(rot, Vector2(s, s), 0.0, c)):
				ci.draw_circle(Vector2.ZERO, 0.35, k)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 追加のアイコン（ステータス・アイテム・状態異常・カードの絵柄）。描いたら true、知らない名前なら false
## m = icon() が設定した変形（部品を小さく重ねる時に使う）
func _icon_ext(ci: CanvasItem, kind: String, k: Color, m: Transform2D) -> bool:
	match kind:
		# ステータス
		"stat_hp": _i_stat_hp(ci, k)
		"stat_atk": _i_stat_atk(ci, k)
		"stat_def": _i_helmet(ci, k)
		"stat_spd": _i_stat_spd(ci, k)
		# アイテム
		"item_herb": _i_item_herb(ci, k)
		"item_fire": _i_item_fire(ci, k)
		"item_power": _i_item_power(ci, k)
		# 状態異常（小さく出るので太い形だけ）
		"st_poison": _i_st_poison(ci, k)
		"st_atk_down":
			_i_sword(ci, k)
			_arrow(ci, Vector2(0.24, 0.22), 0.62, false)
		"st_def_up":
			_i_helmet(ci, k)
			_arrow(ci, Vector2(0.26, 0.24), 0.58, true)
		"st_def_down":
			_i_helmet(ci, k)
			_arrow(ci, Vector2(0.26, 0.24), 0.58, false)
		"st_ap_plus":
			_sub(ci, m, Vector2(-0.06, -0.04), 0.86)
			_i_ap(ci, k)
			_sub(ci, m, Vector2.ZERO, 1.0)
			ci.draw_circle(Vector2(0.24, 0.24), 0.21, COL.ink)
			_i_plus(ci, COL.good, Vector2(0.24, 0.24), 0.16)
		"st_ap_next":
			_sub(ci, m, Vector2(-0.06, -0.04), 0.86)
			_i_ap(ci, k)
			_sub(ci, m, Vector2.ZERO, 1.0)
			_clock_badge(ci, Vector2(0.24, 0.24), 0.21)
		"st_taunt": _i_anger(ci, k, Vector2.ZERO, 1.0)
		"st_fire_guard": _i_fire_guard(ci, k)
		"st_double": _i_st_double(ci, k)
		# カードの絵柄（ウィッチ）
		"c_swap": _i_c_swap(ci, k)
		"c_force": _i_c_force(ci, k)
		"c_draw_magic":
			_sub(ci, m, Vector2(-0.06, 0.06), 0.9)
			_i_cards(ci, k)
			_sub(ci, m, Vector2.ZERO, 1.0)
			_sparkle(ci, Vector2(0.28, -0.3), 0.2, Color("bff4ff"))
			_sparkle(ci, Vector2(0.4, -0.04), 0.1, Color("bff4ff"))
		"c_hit_away": _i_c_hit_away(ci, k)
		"c_atk_down":
			_i_broken_sword(ci, k)
			_arrow(ci, Vector2(0.26, 0.26), 0.7, false)
		"c_def_down":
			_i_helmet(ci, k)
			_crack(ci, Vector2(0.02, -0.4), COL.ink)
			_arrow(ci, Vector2(0.28, 0.26), 0.7, false)
		"c_poison_gas": _i_c_poison_gas(ci, k)
		"c_meditate": _i_c_meditate(ci, k)
		"c_magic_wall": _i_c_magic_wall(ci, k)
		"c_double": _i_c_double(ci, k)
		# カードの絵柄（ナイト）
		"c_big_shield": _i_c_big_shield(ci, k)
		"c_fire_guard":
			_i_c_fire_ring(ci, k)
			_sub(ci, m, Vector2(0, 0.04), 0.62)
			_i_shield(ci, ICON_DEFAULT.shield)
			_sub(ci, m, Vector2.ZERO, 1.0)
		"c_hone": _i_c_hone(ci, k)
		"c_flash": _i_c_flash(ci, k)
		"c_taunt":
			ci.draw_colored_polygon(burst_pts(Vector2.ZERO, 0.52, 0.32, 12, 3), COL.paper)
			ci.draw_colored_polygon(burst_pts(Vector2.ZERO, 0.42, 0.26, 12, 5, 0.2), COL.ink)
			_i_anger(ci, k, Vector2(0, 0), 0.62)
		"c_big_swing": _i_c_big_swing(ci, k)
		"c_steel": _i_c_steel(ci, k)
		"c_store": _i_c_store(ci, k)
		"c_full_strike": _i_c_full_strike(ci, k, m)
		"c_stand": _i_c_stand(ci, k)
		# 対象（20〜28px でも見分けられるよう、人影の数と並び方で区別する）
		"tgt_enemy_one": _i_tgt_enemy_one(ci, k)
		"tgt_enemy_group": _i_tgt_enemy_group(ci, k)
		"tgt_front_row": _i_tgt_front_row(ci, k)
		"tgt_enemy_all": _i_tgt_enemy_all(ci, k)
		"tgt_self": _i_tgt_self(ci, k)
		"tgt_ally_all": _i_tgt_ally_all(ci, k)
		# キーワード
		"kw_power": _i_kw_power(ci, k)
		"kw_exhaust": _i_kw_exhaust(ci, k)
		_:
			return _icon_ext5(ci, kind, k, m)
	return true


## 5回目に追加したアイコン（新カード 20 枚の絵柄・状態 4 種・キーワード 2 種・対象 1 種）
func _icon_ext5(ci: CanvasItem, kind: String, k: Color, m: Transform2D) -> bool:
	match kind:
		# カードの絵柄（ナイト）
		"c_chop": _i_c_chop(ci, k, m)
		"c_flurry": _i_c_flurry(ci, k)
		"c_rampart": _i_c_rampart(ci, k)
		"c_parry": _i_c_parry(ci, k, m)
		"c_focus": _i_c_focus(ci, k)
		"c_barricade": _i_c_barricade(ci, k, m)
		"c_dance": _i_c_dance(ci, k)
		"c_declare": _i_c_declare(ci, k)
		"c_holy": _i_c_holy(ci, k, m)
		"c_mushin": _i_c_mushin(ci, k)
		# カードの絵柄（ウィッチ）
		"c_ap_pass": _i_c_ap_pass(ci, k, m)
		"c_golem": _i_c_golem(ci, k)
		"c_reblock": _i_c_reblock(ci, k, m)
		"c_drain": _i_c_drain(ci, k, m)
		"c_absorb": _i_c_absorb(ci, k, m)
		"c_quake": _i_c_quake(ci, k)
		"c_absorb_block": _i_c_absorb_block(ci, k, m)
		"c_energy": _i_c_energy(ci, k, m)
		"c_inferno": _i_c_inferno(ci, k, m)
		"c_overload": _i_c_overload(ci, k)
		# 状態（小さく出るので太い形だけ）
		"st_barricade": _i_st_barricade(ci, k)
		"st_focus": _i_st_focus(ci, k)
		"st_declare": _i_st_declare(ci, k)
		"st_reblock": _i_st_reblock(ci, k, m)
		# キーワード
		"kw_consume": _i_kw_consume(ci, k)
		"kw_apx": _i_kw_apx(ci, k, m)
		# 対象
		"tgt_ally_other": _i_tgt_ally_other(ci, k)
		_:
			return false
	return true


# ------------------------------------------------------------
# 5回目の追加アイコンの部品
# ------------------------------------------------------------

## 黒い縁付きの多角形（縁 → 面）
func _ink_poly(ci: CanvasItem, poly: PackedVector2Array, k: Color, o: float = 0.05) -> void:
	var g: Array = Geometry2D.offset_polygon(poly, o, Geometry2D.JOIN_MITER)
	if not g.is_empty():
		ci.draw_colored_polygon(g[0], COL.ink)
	ci.draw_colored_polygon(poly, k)


## 斬撃の筋（a→b の細長い三日月形）。下に赤、上に k の 2 層で描く
func _slash_streak(ci: CanvasItem, a: Vector2, b: Vector2, w: float, k: Color, under: Color = COL.red) -> void:
	var n := (b - a).normalized().orthogonal()
	var mid := (a + b) / 2.0
	_ink_poly(ci, PackedVector2Array([a, mid + n * w * 1.5, b, mid - n * w * 0.2]), under, 0.035)
	ci.draw_colored_polygon(PackedVector2Array([a, mid + n * w, b, mid]), k)


## 黒い縁付きの矢印（from → to）
func _ink_arrow(ci: CanvasItem, from: Vector2, to: Vector2, k: Color, w: float) -> void:
	var d := (to - from).normalized()
	var n := d.orthogonal()
	ci.draw_line(from, to - d * 0.12, COL.ink, w + 0.08, true)
	_ink_poly(ci, PackedVector2Array([to + d * 0.03, to - d * 0.22 + n * 0.16, to - d * 0.22 - n * 0.16]), k, 0.04)
	ci.draw_line(from, to - d * 0.14, k, w, true)


## 円弧の矢印（中心 c、半径 r、a0 → a1 へ回る。先に矢じり）
func _arc_arrow(ci: CanvasItem, c: Vector2, r: float, a0: float, a1: float, k: Color, w: float) -> void:
	ci.draw_arc(c, r, a0, a1, 24, COL.ink, w + 0.07, true)
	ci.draw_arc(c, r, a0, a1, 24, k, w, true)
	var e := c + Vector2(cos(a1), sin(a1)) * r
	var sgn := 1.0 if a1 > a0 else -1.0
	var d := Vector2(-sin(a1), cos(a1)) * sgn  # 弧の進む向き
	var n := d.orthogonal()
	_ink_poly(ci, PackedVector2Array([e + d * 0.2, e + n * (w + 0.09), e - n * (w + 0.09)]), k, 0.04)


## 刃（根元 base から ang の向きへ長さ len の剣身）
func _blade(ci: CanvasItem, base: Vector2, ang: float, ln: float, wd: float, k: Color) -> void:
	var p := _rot([[0, -ln], [wd, -ln + wd * 1.4], [wd, 0], [-wd, 0], [-wd, -ln + wd * 1.4]], ang, base)
	_ink_poly(ci, p, k, 0.04)
	ci.draw_colored_polygon(_rot([[0, -ln + 0.03], [wd * 0.35, -ln + wd * 1.4], [wd * 0.35, -0.02], [0, -0.02]], ang, base), COL.paper)


## 切り刻み：剣と、獣の爪跡のような 3 本の斬撃
func _i_c_chop(ci: CanvasItem, k: Color, m: Transform2D) -> void:
	_sub(ci, m, Vector2(-0.14, 0.06), 0.82)
	_i_sword(ci, k)
	_sub(ci, m, Vector2.ZERO, 1.0)
	for i in 3:
		var o := Vector2(-0.12 + i * 0.17, 0.0)
		_slash_streak(ci, o + Vector2(0.02, -0.44), o + Vector2(0.24, 0.42), 0.06, COL.paper)


## 乱撃：続けて当たる 2 つの衝撃（大小の爆発に斬撃）
func _i_c_flurry(ci: CanvasItem, k: Color) -> void:
	for v in [[-0.16, -0.14, 0.3], [0.2, 0.18, 0.24]]:
		var c := Vector2(v[0], v[1])
		var r: float = v[2]
		_ink_poly(ci, burst_pts(c, r, r * 0.5, 9, int(r * 10.0)), k, 0.04)
		ci.draw_colored_polygon(burst_pts(c, r * 0.55, r * 0.28, 9, 3), Color("ffe08a"))
		_slash_streak(ci, c + Vector2(-r * 1.15, r * 0.7), c + Vector2(r * 1.15, -r * 0.7), 0.05, COL.paper)


## 城壁：凸凹の付いた石の壁と門
func _i_c_rampart(ci: CanvasItem, k: Color) -> void:
	var wall := pts([[-0.46, -0.22], [-0.3, -0.22], [-0.3, -0.06], [-0.16, -0.06], [-0.16, -0.22], [0.08, -0.22], [0.08, -0.06],
			[0.22, -0.06], [0.22, -0.22], [0.46, -0.22], [0.46, 0.44], [-0.46, 0.44]])
	# 塔（左右の高い所）
	_ink_poly(ci, pts([[-0.46, -0.44], [-0.24, -0.44], [-0.24, 0.44], [-0.46, 0.44]]), k.darkened(0.1), 0.05)
	_ink_poly(ci, pts([[0.24, -0.44], [0.46, -0.44], [0.46, 0.44], [0.24, 0.44]]), k.darkened(0.1), 0.05)
	_ink_poly(ci, wall, k, 0.05)
	# 石積みの目地
	for row in 3:
		var y := 0.02 + row * 0.14
		ci.draw_line(Vector2(-0.46, y), Vector2(0.46, y), k.darkened(0.45), 0.03)
		var off := 0.0 if row % 2 == 0 else 0.1
		for i in 5:
			var x := -0.38 + off + i * 0.2
			ci.draw_line(Vector2(x, y), Vector2(x, y + 0.14), k.darkened(0.45), 0.03)
	# 塔の上の凸凹
	for x in [-0.46, -0.31, 0.24, 0.39]:
		ci.draw_rect(Rect2(x, -0.5, 0.07, 0.08), k.darkened(0.1))
	# 門（黒いアーチ）
	var gate := PackedVector2Array()
	for i in 9:
		var a := PI + PI * i / 8.0
		gate.append(Vector2(cos(a) * 0.12, -0.0 + sin(a) * 0.12 + 0.2))
	gate.append(Vector2(0.12, 0.44))
	gate.append(Vector2(-0.12, 0.44))
	ci.draw_colored_polygon(gate, COL.ink)
	ci.draw_colored_polygon(ell(Vector2(-0.37, -0.3), 0.04, 0.07), Color(1, 1, 1, 0.5))


## 受け流し：盾に当たった攻撃が、矢印になって逸れていく
func _i_c_parry(ci: CanvasItem, k: Color, m: Transform2D) -> void:
	_sub(ci, m, Vector2(-0.16, 0.06), 0.78)
	_i_shield(ci, k)
	_sub(ci, m, Vector2.ZERO, 1.0)
	# 飛んでくる攻撃（白）→ 盾で跳ね返って右下へ
	_ink_arrow(ci, Vector2(0.48, -0.46), Vector2(0.1, -0.06), COL.paper, 0.07)
	_ink_arrow(ci, Vector2(0.12, -0.02), Vector2(0.44, 0.42), COL.red, 0.08)
	_sparkle(ci, Vector2(0.08, -0.06), 0.2, Color("ffe08a"))


## 精神統一：閉じた目と、額に光る点。周りに集中の輪
func _i_c_focus(ci: CanvasItem, k: Color) -> void:
	for i in 3:
		ci.draw_arc(Vector2.ZERO, 0.24 + i * 0.1, 0, TAU, 32, Color(k, 0.85 - i * 0.25), 0.04, true)
	glow(ci, Vector2(0, -0.12), 0.24, Color(k, 0.9), 5)
	ci.draw_circle(Vector2(0, -0.12), 0.07, COL.paper)
	# 閉じた目（下向きの弧＋まつ毛）
	ci.draw_arc(Vector2(0, 0.02), 0.2, PI * 0.12, PI * 0.88, 14, COL.ink, 0.12, true)
	ci.draw_arc(Vector2(0, 0.02), 0.2, PI * 0.12, PI * 0.88, 14, COL.paper, 0.06, true)
	for a in [0.32, 0.5, 0.68]:
		var p := Vector2(cos(PI * a), sin(PI * a)) * 0.2 + Vector2(0, 0.02)
		ci.draw_line(p, p + Vector2(cos(PI * a), sin(PI * a)) * 0.1, COL.paper, 0.04, true)


## 木の柵（横板＋交差した尖った杭）。バリケードのカードと状態で共通
func _barricade_shape(ci: CanvasItem, k: Color, sc: float) -> void:
	var dk := k.darkened(0.35)
	_ink_poly(ci, pts([[-0.48 * sc, -0.06 * sc], [0.48 * sc, -0.06 * sc], [0.48 * sc, 0.1 * sc], [-0.48 * sc, 0.1 * sc]]), dk, 0.05)
	for a in [PI / 4, -PI / 4]:
		var stake := _rot([[0, -0.6 * sc], [0.09 * sc, -0.46 * sc], [0.09 * sc, 0.52 * sc], [-0.09 * sc, 0.52 * sc], [-0.09 * sc, -0.46 * sc]], a)
		_ink_poly(ci, stake, k, 0.05)
		ci.draw_colored_polygon(_rot([[0, -0.6 * sc], [0.09 * sc, -0.46 * sc], [-0.09 * sc, -0.46 * sc]], a), COL.paper)
	ci.draw_circle(Vector2.ZERO, 0.06 * sc, COL.ink)


## バリケード：消えずに残る盾（後ろ）と木の柵
func _i_c_barricade(ci: CanvasItem, k: Color, m: Transform2D) -> void:
	_sub(ci, m, Vector2(0, -0.06), 0.9)
	_i_shield(ci, ICON_DEFAULT.shield)
	_sub(ci, m, Vector2(0, 0.08), 0.86)
	_barricade_shape(ci, k, 1.0)
	_sub(ci, m, Vector2.ZERO, 1.0)


## 演舞：円を描いて舞う 3 本の剣と赤い軌跡
func _i_c_dance(ci: CanvasItem, k: Color) -> void:
	ci.draw_arc(Vector2.ZERO, 0.42, 0, TAU, 40, Color(COL.red, 0.55), 0.1, true)
	for i in 3:
		var a := TAU * i / 3.0 - PI / 2
		var a0 := a + 0.5
		ci.draw_arc(Vector2.ZERO, 0.42, a0, a0 + 1.2, 14, COL.red, 0.07, true)
		# 剣（柄は中心寄り、切っ先は外向き。刃は少し傾けて回転の勢いを出す）
		var d := Vector2(cos(a + 0.35), sin(a + 0.35))
		var base := d * 0.16
		_blade(ci, base, a + 0.35 + PI / 2, 0.34, 0.06, k.darkened(0.08))
		var n := d.orthogonal()
		ci.draw_line(base - n * 0.11, base + n * 0.11, COL.ink, 0.09)
		ci.draw_line(base - n * 0.1, base + n * 0.1, ICON_DEFAULT.star, 0.05)
		ci.draw_line(base, base - d * 0.12, Color("7a4a2a"), 0.05)
	ci.draw_circle(Vector2.ZERO, 0.06, COL.red)


## 旗（竿＋赤い旗に白い星）。宣言のカードと状態で共通
func _flag_shape(ci: CanvasItem, k: Color, bold: bool) -> void:
	var pw := 0.1 if bold else 0.07
	ci.draw_line(Vector2(-0.3, -0.46), Vector2(-0.3, 0.5), COL.ink, pw + 0.08)
	ci.draw_line(Vector2(-0.3, -0.44), Vector2(-0.3, 0.5), Color("dfe6ee"), pw)
	var flag := pts([[-0.26, -0.42], [0.04, -0.48], [0.24, -0.38], [0.46, -0.42], [0.44, 0.02], [0.22, 0.06], [0.02, -0.04], [-0.26, 0.02]])
	_ink_poly(ci, flag, k, 0.05)
	ci.draw_colored_polygon(star_pts(Vector2(0.1, -0.2), 0.15 if bold else 0.13, 0.06), COL.paper)
	ci.draw_circle(Vector2(-0.3, -0.48), 0.06, ICON_DEFAULT.star)


## 宣言：旗を立てて、後ろに放射の光
func _i_c_declare(ci: CanvasItem, k: Color) -> void:
	for i in 10:
		var a := -PI * 0.95 + PI * 0.9 * i / 9.0
		var d := Vector2(cos(a), sin(a))
		ci.draw_line(Vector2(0.08, -0.2) + d * 0.36, Vector2(0.08, -0.2) + d * 0.54, Color(ICON_DEFAULT.star, 0.8), 0.04)
	_flag_shape(ci, k, false)
	# 足元の台
	_ink_poly(ci, pts([[-0.46, 0.38], [-0.14, 0.38], [-0.1, 0.5], [-0.5, 0.5]]), COL.steel.lightened(0.3), 0.04)


## 聖なる加護：金色の光の輪の下に白い盾、後ろに光の筋
func _i_c_holy(ci: CanvasItem, k: Color, m: Transform2D) -> void:
	glow(ci, Vector2(0, 0.04), 0.5, Color(k, 0.8), 6)
	for i in 12:
		var a := TAU * i / 12.0
		var d := Vector2(cos(a), sin(a))
		ci.draw_line(Vector2(0, 0.06) + d * 0.3, Vector2(0, 0.06) + d * 0.5, Color(k, 0.75), 0.04)
	_sub(ci, m, Vector2(0, 0.1), 0.78)
	_i_shield(ci, Color("e9edf2"))
	_sub(ci, m, Vector2.ZERO, 1.0)
	ci.draw_colored_polygon(pts([[-0.035, -0.12], [0.035, -0.12], [0.035, 0.0], [0.12, 0.0], [0.12, 0.07], [0.035, 0.07], [0.035, 0.3],
			[-0.035, 0.3], [-0.035, 0.07], [-0.12, 0.07], [-0.12, 0.0], [-0.035, 0.0]]), k.darkened(0.15))
	# 光の輪
	var halo := ell(Vector2(0, -0.42), 0.24, 0.07, 24)
	halo.append(halo[0])
	ci.draw_polyline(halo, COL.ink, 0.11, true)
	ci.draw_polyline(halo, k, 0.06, true)


## 無心乱舞：赤い爆発の上を、あちこちから走る白い斬撃
func _i_c_mushin(ci: CanvasItem, k: Color) -> void:
	_ink_poly(ci, burst_pts(Vector2.ZERO, 0.5, 0.3, 14, 11), k.darkened(0.25), 0.04)
	ci.draw_colored_polygon(burst_pts(Vector2.ZERO, 0.32, 0.18, 14, 13), k.lightened(0.2))
	for v in [[-0.46, -0.2, 0.42, 0.06], [-0.3, 0.42, 0.22, -0.46], [-0.14, -0.46, 0.4, 0.36], [0.46, -0.22, -0.4, 0.26], [-0.46, 0.14, 0.46, -0.4]]:
		_slash_streak(ci, Vector2(v[0], v[1]), Vector2(v[2], v[3]), 0.04, COL.paper, COL.ink)


## APパサー：左の味方から右の味方へ、AP の結晶を投げ渡す
func _i_c_ap_pass(ci: CanvasItem, k: Color, m: Transform2D) -> void:
	_pawn(ci, Vector2(-0.3, 0.06), 0.44, COL.paper.darkened(0.3), false)
	_pawn(ci, Vector2(0.3, 0.06), 0.44, COL.paper, false)
	ci.draw_arc(Vector2(0, 0.0), 0.32, -PI * 0.92, -PI * 0.08, 20, COL.ink, 0.1, true)
	ci.draw_arc(Vector2(0, 0.0), 0.32, -PI * 0.92, -PI * 0.08, 20, Color(k, 0.9), 0.05, true)
	_sub(ci, m, Vector2(0.0, -0.32), 0.44)
	ci.draw_colored_polygon(pts([[0, -0.58], [0.46, -0.1], [0, 0.58], [-0.46, -0.1]]), COL.ink)
	_i_ap(ci, k)
	_sub(ci, m, Vector2.ZERO, 1.0)
	_ink_poly(ci, PackedVector2Array([Vector2(0.36, -0.02), Vector2(0.2, -0.12), Vector2(0.38, -0.2)]), k, 0.03)


## ゴーレム：角ばった石の頭に光る目
func _i_c_golem(ci: CanvasItem, k: Color) -> void:
	# 肩
	_ink_poly(ci, pts([[-0.48, 0.2], [-0.3, 0.08], [0.3, 0.08], [0.48, 0.2], [0.5, 0.48], [-0.5, 0.48]]), k.darkened(0.3), 0.05)
	var head := pts([[-0.26, -0.44], [0.26, -0.44], [0.34, -0.3], [0.32, 0.18], [0.2, 0.3], [-0.2, 0.3], [-0.32, 0.18], [-0.34, -0.3]])
	_ink_poly(ci, head, k, 0.05)
	# 光の当たる面
	ci.draw_colored_polygon(pts([[-0.26, -0.44], [0.0, -0.44], [-0.06, -0.3], [-0.34, -0.3]]), k.lightened(0.25))
	# 眉（岩のでっぱり）と目
	ci.draw_rect(Rect2(-0.3, -0.16, 0.6, 0.08), k.darkened(0.45))
	for sx in [-1.0, 1.0]:
		ci.draw_rect(Rect2(sx * 0.15 - 0.07, -0.07, 0.14, 0.08), COL.ink)
		ci.draw_rect(Rect2(sx * 0.15 - 0.05, -0.06, 0.1, 0.05), Color("6fe3ff"))
	# 口とひび
	ci.draw_rect(Rect2(-0.12, 0.12, 0.24, 0.05), COL.ink)
	ci.draw_polyline(pts([[0.18, -0.44], [0.12, -0.32], [0.2, -0.24]]), k.darkened(0.5), 0.03, true)
	ci.draw_polyline(pts([[-0.36, 0.3], [-0.26, 0.36], [-0.3, 0.46]]), k.darkened(0.6), 0.03, true)


## 盾を回り込む矢印（もう一度張る）。リブロックのカードと状態で共通
func _reblock_shape(ci: CanvasItem, k: Color, m: Transform2D, bold: bool) -> void:
	_sub(ci, m, Vector2(0, 0.02), 0.72 if not bold else 0.66)
	_i_shield(ci, k)
	_sub(ci, m, Vector2.ZERO, 1.0)
	_arc_arrow(ci, Vector2(0, 0.02), 0.44, PI * 0.72, PI * 2.32, COL.paper if not bold else Color("7be09a"), 0.07 if not bold else 0.09)


## リブロック：盾と、ぐるりと回る白い矢印。右下に「次のターン」の時計
func _i_c_reblock(ci: CanvasItem, k: Color, m: Transform2D) -> void:
	_reblock_shape(ci, k, m, false)
	_clock_badge(ci, Vector2(0.32, 0.32), 0.16)


## ドレイン：赤いしずくを吸い込む紫の渦と AP の結晶
func _i_c_drain(ci: CanvasItem, k: Color, m: Transform2D) -> void:
	for i in 3:
		ci.draw_arc(Vector2.ZERO, 0.26 + i * 0.09, i * 1.4, i * 1.4 + PI * 1.1, 18, Color(ICON_DEFAULT.ap, 0.75 - i * 0.18), 0.045, true)
	_sub(ci, m, Vector2.ZERO, 0.42)
	ci.draw_colored_polygon(pts([[0, -0.6], [0.48, -0.1], [0, 0.6], [-0.48, -0.1]]), COL.ink)
	_i_ap(ci, ICON_DEFAULT.ap)
	_sub(ci, m, Vector2.ZERO, 1.0)
	for i in 3:
		var a := TAU * i / 3.0 - PI * 0.75
		var d := Vector2(cos(a), sin(a))
		var p := d * 0.38
		ci.draw_line(p - d * 0.08, d * 0.22, Color(k, 0.7), 0.05, true)
		# しずく（中心へ飛んでいく向き：丸い方が前、尖った方が外）
		var drop := PackedVector2Array()
		for v in [[0, -0.17], [0.1, -0.01], [0.08, 0.07], [0, 0.11], [-0.08, 0.07], [-0.1, -0.01]]:
			drop.append(Vector2(v[0], v[1]).rotated(a + PI / 2) + p)
		_ink_poly(ci, drop, k, 0.035)
		ci.draw_circle(p + d * 0.03 + d.orthogonal() * 0.03, 0.025, Color(1, 1, 1, 0.6))


## アブソーブ：紫の渦に吸い込まれる剣（相手の力を奪う）＋自分の攻撃力アップの矢印
func _i_c_absorb(ci: CanvasItem, k: Color, m: Transform2D) -> void:
	var sp := PackedVector2Array()
	for i in 40:
		var t := float(i) / 39.0
		var a := t * TAU * 1.8
		sp.append(Vector2(cos(a), sin(a)) * (0.06 + t * 0.4))
	ci.draw_polyline(sp, COL.ink, 0.11, true)
	ci.draw_polyline(sp, k, 0.06, true)
	_sub(ci, m, Vector2(-0.06, -0.04), 0.5, -0.5)
	_i_sword(ci, ICON_DEFAULT.sword)
	_sub(ci, m, Vector2.ZERO, 1.0)
	_arrow(ci, Vector2(0.3, 0.3), 0.66, true)


## アースクエイク：割れた地面と飛び散る岩、横揺れの線
func _i_c_quake(ci: CanvasItem, k: Color) -> void:
	for sx in [-1.0, 1.0]:
		for i in 2:
			var x: float = sx * (0.4 + i * 0.07)
			ci.draw_line(Vector2(x, -0.3 + i * 0.06), Vector2(x, -0.06 + i * 0.06), Color(COL.paper, 0.7 - i * 0.25), 0.035)
	# 左右に割れた地面
	_ink_poly(ci, pts([[-0.5, 0.12], [-0.06, 0.08], [0.02, 0.22], [-0.08, 0.32], [0.0, 0.48], [-0.5, 0.48]]), k, 0.04)
	_ink_poly(ci, pts([[0.06, 0.14], [0.5, 0.18], [0.5, 0.48], [0.1, 0.48], [0.16, 0.32], [0.08, 0.24]]), k.darkened(0.15), 0.04)
	ci.draw_line(Vector2(-0.5, 0.2), Vector2(-0.1, 0.17), k.lightened(0.3), 0.03)
	ci.draw_line(Vector2(0.12, 0.25), Vector2(0.5, 0.27), k.lightened(0.2), 0.03)
	# 飛び散る岩
	for v in [[-0.2, -0.2, 0.12, 0.3], [0.16, -0.34, 0.1, -0.5], [0.02, -0.04, 0.08, 1.0], [-0.3, -0.42, 0.07, 0.6], [0.3, -0.08, 0.08, 2.0]]:
		var c := Vector2(v[0], v[1])
		var r: float = v[2]
		var rock := PackedVector2Array()
		for j in 5:
			var a: float = TAU * j / 5.0 + float(v[3])
			rock.append(c + Vector2(cos(a), sin(a)) * r * (0.8 + _hash(j + float(v[3])) * 0.4))
		_ink_poly(ci, rock, k.lightened(0.15), 0.03)


## ブロック吸収：左の赤い（敵の）盾から、右の青い盾へ流れ込む矢印
func _i_c_absorb_block(ci: CanvasItem, k: Color, m: Transform2D) -> void:
	_sub(ci, m, Vector2(-0.27, -0.14), 0.5)
	_i_shield(ci, Color("d0404a"))
	_sub(ci, m, Vector2(0.18, 0.14), 0.74)
	_i_shield(ci, k)
	_sub(ci, m, Vector2.ZERO, 1.0)
	_arc_arrow(ci, Vector2(-0.12, 0.26), 0.3, PI * 1.1, PI * 1.62, COL.paper, 0.06)
	for v in [[-0.1, -0.4], [0.06, -0.3], [-0.04, -0.2]]:
		ci.draw_circle(Vector2(v[0], v[1]), 0.035, Color("8fc0ea"))


## エナジーチャージ：AP の結晶に走る稲妻と、集まる光
func _i_c_energy(ci: CanvasItem, k: Color, m: Transform2D) -> void:
	glow(ci, Vector2.ZERO, 0.46, Color(k, 0.8), 6)
	_sub(ci, m, Vector2(0, 0.02), 0.82)
	ci.draw_colored_polygon(pts([[0, -0.56], [0.44, -0.1], [0, 0.56], [-0.44, -0.1]]), COL.ink)
	_i_ap(ci, ICON_DEFAULT.ap)
	_sub(ci, m, Vector2(0.02, 0.02), 0.62)
	ci.draw_colored_polygon(pts([[0.08, -0.56], [-0.36, 0.1], [-0.04, 0.1], [-0.16, 0.56], [0.36, -0.12], [0.04, -0.12]]), COL.ink)
	_i_bolt(ci, k)
	_sub(ci, m, Vector2.ZERO, 1.0)
	_sparkle(ci, Vector2(0.36, -0.36), 0.14, COL.paper)
	_sparkle(ci, Vector2(-0.38, 0.3), 0.1, COL.paper)


## 豪炎：並んで燃え上がる 3 つの大きな炎と火の粉
func _i_c_inferno(ci: CanvasItem, k: Color, m: Transform2D) -> void:
	ci.draw_colored_polygon(ell(Vector2(0, 0.42), 0.5, 0.09, 24), Color(COL.red, 0.7))
	for v in [[-0.26, 0.12, 0.62], [0.26, 0.12, 0.62], [0.0, 0.0, 0.9]]:
		_sub(ci, m, Vector2(v[0], v[1]), float(v[2]))
		ci.draw_colored_polygon(_teardrop(Vector2(0, 0.18), 0.35, 0.76), COL.ink)
		_i_flame(ci, k)
	_sub(ci, m, Vector2.ZERO, 1.0)
	for v in [[-0.4, -0.3], [0.38, -0.36], [0.14, -0.48]]:
		ci.draw_circle(Vector2(v[0], v[1]), 0.035, Color("ffe08a"))


## 魔力暴走：ひびの入った魔力の玉から四方へ走る稲妻
func _i_c_overload(ci: CanvasItem, k: Color) -> void:
	ci.draw_colored_polygon(burst_pts(Vector2.ZERO, 0.52, 0.34, 12, 5), Color(COL.red, 0.85))
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4
		var d := Vector2(cos(a), sin(a))
		var n := d.orthogonal()
		var bolt := PackedVector2Array([d * 0.22, d * 0.34 + n * 0.08, d * 0.36 - n * 0.02, d * 0.52 + n * 0.04])
		ci.draw_polyline(bolt, COL.ink, 0.1, true)
		ci.draw_polyline(bolt, Color("ffe08a"), 0.05, true)
	ci.draw_circle(Vector2.ZERO, 0.3, COL.ink)
	ci.draw_circle(Vector2.ZERO, 0.26, k)
	ci.draw_circle(Vector2(-0.06, -0.06), 0.15, k.lightened(0.5))
	ci.draw_circle(Vector2(-0.1, -0.1), 0.05, COL.paper)
	# ひび（赤）
	ci.draw_polyline(pts([[0.04, -0.26], [0.0, -0.12], [0.08, -0.02], [0.02, 0.1], [0.12, 0.24]]), COL.red_d, 0.05, true)
	ci.draw_polyline(pts([[0.08, -0.02], [0.22, 0.0]]), COL.red_d, 0.04, true)


## 状態：バリケード（木の柵）
func _i_st_barricade(ci: CanvasItem, k: Color) -> void:
	_barricade_shape(ci, k, 0.9)


## 状態：精神統一（水色の丸に閉じた目）
func _i_st_focus(ci: CanvasItem, k: Color) -> void:
	ci.draw_circle(Vector2.ZERO, 0.42, k)
	ci.draw_arc(Vector2(0, -0.04), 0.24, PI * 0.1, PI * 0.9, 14, COL.ink, 0.11, true)
	for a in [0.3, 0.5, 0.7]:
		var d := Vector2(cos(PI * a), sin(PI * a))
		ci.draw_line(d * 0.24 + Vector2(0, -0.04), d * 0.36 + Vector2(0, -0.04), COL.ink, 0.07, true)
	ci.draw_circle(Vector2(0, -0.26), 0.07, COL.paper)


## 状態：宣言（赤い旗）
func _i_st_declare(ci: CanvasItem, k: Color) -> void:
	_flag_shape(ci, k, true)


## 状態：リブロック（盾と緑の回る矢印）
func _i_st_reblock(ci: CanvasItem, k: Color, m: Transform2D) -> void:
	_reblock_shape(ci, k, m, true)


## キーワード：消費（橙の丸に、下へ落ちる白いカード）
func _i_kw_consume(ci: CanvasItem, k: Color) -> void:
	ci.draw_circle(Vector2.ZERO, 0.46, COL.ink)
	ci.draw_circle(Vector2.ZERO, 0.4, k)
	var card := _rot([[-0.15, -0.21], [0.15, -0.21], [0.15, 0.21], [-0.15, 0.21]], -0.3, Vector2(-0.02, -0.06))
	_ink_poly(ci, card, COL.paper, 0.04)
	# 下向きの矢印
	ci.draw_line(Vector2(0.18, -0.1), Vector2(0.18, 0.16), COL.ink, 0.09)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(0.04, 0.12), Vector2(0.32, 0.12), Vector2(0.18, 0.32)]), COL.ink)


## キーワード：APX（AP の結晶に白い X）
func _i_kw_apx(ci: CanvasItem, k: Color, m: Transform2D) -> void:
	ci.draw_colored_polygon(pts([[0, -0.56], [0.44, -0.1], [0, 0.56], [-0.44, -0.1]]), COL.ink)
	_i_ap(ci, k)
	for v in [[-0.17, -0.2, 0.17, 0.2], [0.17, -0.2, -0.17, 0.2]]:
		ci.draw_line(Vector2(v[0], v[1]), Vector2(v[2], v[3]), COL.ink, 0.17)
	for v in [[-0.15, -0.18, 0.15, 0.18], [0.15, -0.18, -0.15, 0.18]]:
		ci.draw_line(Vector2(v[0], v[1]), Vector2(v[2], v[3]), COL.paper, 0.09)


## 対象：自分以外の味方（暗い自分の人影から、赤い矢印が明るい味方の人影を指す）
func _i_tgt_ally_other(ci: CanvasItem, k: Color) -> void:
	ci.draw_colored_polygon(ell(Vector2(0.2, 0.42), 0.3, 0.1, 18), COL.red)
	_pawn(ci, Vector2(-0.28, 0.08), 0.38, k.darkened(0.5), false)
	_pawn(ci, Vector2(0.2, -0.02), 0.52, k, false)
	_ink_arrow(ci, Vector2(-0.44, -0.3), Vector2(-0.04, -0.3), COL.red, 0.08)


## 人影（頭＋肩）。c = 胴の上端の中心、h = 全体の高さ。enemy なら頭に小さな角。黒い縁で重なっても分かれて見える
func _pawn(ci: CanvasItem, c: Vector2, h: float, k: Color, enemy: bool = true) -> void:
	var o := 0.05  # 縁の太さ
	var head := c + Vector2(0, -h * 0.27)
	var hr := h * 0.22
	var body := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		body.append(c + Vector2(cos(a) * h * 0.4, h * 0.5 + sin(a) * h * 0.5))
	var grown := Geometry2D.offset_polygon(body, o, Geometry2D.JOIN_MITER)
	if not grown.is_empty():
		ci.draw_colored_polygon(grown[0], COL.ink)
	ci.draw_circle(head, hr + o, COL.ink)
	if enemy:
		for sx in [-1.0, 1.0]:
			var horn := PackedVector2Array([head + Vector2(sx * hr * 0.35, -hr * 0.6), head + Vector2(sx * hr * 1.05, -hr * 1.3),
					head + Vector2(sx * hr * 0.95, -hr * 0.2)])
			var hg := Geometry2D.offset_polygon(horn, o * 0.8, Geometry2D.JOIN_MITER)
			if not hg.is_empty():
				ci.draw_colored_polygon(hg[0], COL.ink)
			ci.draw_colored_polygon(horn, k.lightened(0.5))
	ci.draw_colored_polygon(body, k)
	ci.draw_circle(head, hr, k)


## 対象：目の前の敵 1 体（照準の中に人影 1 つ）
func _i_tgt_enemy_one(ci: CanvasItem, k: Color) -> void:
	ci.draw_arc(Vector2.ZERO, 0.42, 0, TAU, 28, COL.ink, 0.17, true)
	ci.draw_arc(Vector2.ZERO, 0.42, 0, TAU, 28, k, 0.1, true)
	for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		ci.draw_line(d * 0.34, d * 0.56, k, 0.1)
	_pawn(ci, Vector2(0, 0.0), 0.54, k)


## 対象：目の前の敵グループ（寄り集まった人影 3 つ＋足元の丸い光）
func _i_tgt_enemy_group(ci: CanvasItem, k: Color) -> void:
	ci.draw_colored_polygon(ell(Vector2(0, 0.38), 0.52, 0.14, 24), Color(k, 0.5))
	_pawn(ci, Vector2(-0.24, -0.1), 0.56, k.darkened(0.2))
	_pawn(ci, Vector2(0.24, -0.1), 0.56, k.darkened(0.2))
	_pawn(ci, Vector2(0, 0.0), 0.6, k)


## 対象：前衛の敵全体（横一列の人影 3 つ＋その下に太い赤線）
func _i_tgt_front_row(ci: CanvasItem, k: Color) -> void:
	for x in [-0.33, 0.33, 0.0]:
		_pawn(ci, Vector2(x, -0.1), 0.5, k)
	ci.draw_rect(Rect2(-0.54, 0.34, 1.08, 0.16), COL.ink)
	ci.draw_rect(Rect2(-0.5, 0.37, 1.0, 0.1), k)


## 対象：敵全体（2 列の人影＋四隅のかぎ括弧で囲む）
func _i_tgt_enemy_all(ci: CanvasItem, k: Color) -> void:
	for x in [-0.16, 0.16]:
		_pawn(ci, Vector2(x, -0.2), 0.38, k.darkened(0.2))
	for x in [-0.16, 0.16]:
		_pawn(ci, Vector2(x, 0.06), 0.4, k)
	var a := 0.48
	var l := 0.22
	var t := 0.11
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var cc := Vector2(sx * a, sy * a)
			ci.draw_line(cc + Vector2(sx * t / 2, 0), cc + Vector2(-sx * l, 0), k, t)
			ci.draw_line(cc + Vector2(0, sy * t / 2), cc + Vector2(0, -sy * l), k, t)


## 対象：自分（白い人影を回り込む矢印）
func _i_tgt_self(ci: CanvasItem, k: Color) -> void:
	_pawn(ci, Vector2(0, 0.02), 0.56, k, false)
	var arc_col: Color = COL.red
	ci.draw_arc(Vector2(0, 0.02), 0.44, PI * 0.95, PI * 2.25, 24, COL.ink, 0.16, true)
	ci.draw_arc(Vector2(0, 0.02), 0.44, PI * 0.95, PI * 2.25, 24, arc_col, 0.09, true)
	var e := Vector2(cos(PI * 2.25), sin(PI * 2.25)) * 0.44 + Vector2(0, 0.02)
	var d := Vector2(-sin(PI * 2.25), cos(PI * 2.25))  # 弧の進む向き
	var n := d.orthogonal()
	var tri := PackedVector2Array([e + d * 0.2, e + n * 0.14, e - n * 0.14])
	var tg := Geometry2D.offset_polygon(tri, 0.04, Geometry2D.JOIN_MITER)
	if not tg.is_empty():
		ci.draw_colored_polygon(tg[0], COL.ink)
	ci.draw_colored_polygon(tri, arc_col)


## 対象：味方全体（白い人影 2 つ。足元に左＝青・右＝赤の光）
func _i_tgt_ally_all(ci: CanvasItem, k: Color) -> void:
	ci.draw_colored_polygon(ell(Vector2(-0.23, 0.4), 0.27, 0.1, 18), COL.knight)
	ci.draw_colored_polygon(ell(Vector2(0.23, 0.4), 0.27, 0.1, 18), COL.red)
	_pawn(ci, Vector2(-0.23, -0.02), 0.48, k, false)
	_pawn(ci, Vector2(0.23, -0.02), 0.48, k, false)


## キーワード：パワー（紫の丸に白い稲妻）
func _i_kw_power(ci: CanvasItem, k: Color) -> void:
	ci.draw_circle(Vector2.ZERO, 0.46, COL.ink)
	ci.draw_circle(Vector2.ZERO, 0.4, k)
	ci.draw_colored_polygon(pts([[0.06, -0.34], [-0.2, 0.05], [-0.02, 0.05], [-0.08, 0.34], [0.2, -0.06], [0.02, -0.06]]), COL.paper)


## キーワード：廃棄（白いカードに赤い×）
func _i_kw_exhaust(ci: CanvasItem, k: Color) -> void:
	var card := _rot([[-0.26, -0.38], [0.26, -0.38], [0.26, 0.38], [-0.26, 0.38]], 0.18)
	var g := Geometry2D.offset_polygon(card, 0.05, Geometry2D.JOIN_MITER)
	if not g.is_empty():
		ci.draw_colored_polygon(g[0], COL.ink)
	ci.draw_colored_polygon(card, COL.paper)
	ci.draw_line(Vector2(-0.3, -0.3), Vector2(0.3, 0.3), COL.ink, 0.2)
	ci.draw_line(Vector2(0.3, -0.3), Vector2(-0.3, 0.3), COL.ink, 0.2)
	ci.draw_line(Vector2(-0.28, -0.28), Vector2(0.28, 0.28), k, 0.12)
	ci.draw_line(Vector2(0.28, -0.28), Vector2(-0.28, 0.28), k, 0.12)


## 部品用の変形：icon() の変形 m の中で、off へ動かして sc 倍にする
func _sub(ci: CanvasItem, m: Transform2D, off: Vector2, sc: float, ang: float = 0.0) -> void:
	ci.draw_set_transform_matrix(m * Transform2D(ang, Vector2(sc, sc), 0.0, off))


## 4方向に尖ったきらめき
func _sparkle(ci: CanvasItem, c: Vector2, r: float, k: Color) -> void:
	ci.draw_colored_polygon(star_pts(c, r, r * 0.28, 4, -PI / 2), k)


## 小さな時計（次のターン）の印
func _clock_badge(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r, COL.ink)
	ci.draw_circle(c, r * 0.78, COL.paper)
	ci.draw_line(c, c + Vector2(0, -r * 0.6), COL.ink, r * 0.22)
	ci.draw_line(c, c + Vector2(r * 0.48, 0), COL.ink, r * 0.22)


## ひび割れ（上から下へのジグザグ）
func _crack(ci: CanvasItem, top: Vector2, k: Color) -> void:
	var p := PackedVector2Array([top, top + Vector2(0.08, 0.14), top + Vector2(-0.04, 0.24), top + Vector2(0.06, 0.36), top + Vector2(-0.02, 0.46)])
	ci.draw_polyline(p, k, 0.07, true)


## 防御（兜）：丸い鉢＋T字ののぞき穴。ブロックの盾とは形を分ける
func _i_helmet(ci: CanvasItem, k: Color) -> void:
	var p := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		p.append(Vector2(cos(a) * 0.38, sin(a) * 0.42 - 0.02))
	p.append(Vector2(0.38, 0.3))
	p.append(Vector2(0.2, 0.46))
	p.append(Vector2(-0.2, 0.46))
	p.append(Vector2(-0.38, 0.3))
	ci.draw_colored_polygon(p, k)
	# 鉢の上のとさか（赤）
	ci.draw_colored_polygon(pts([[-0.06, -0.5], [0.06, -0.5], [0.05, -0.1], [-0.05, -0.1]]), COL.red)
	# 光沢
	ci.draw_colored_polygon(ell(Vector2(-0.18, -0.2), 0.08, 0.13), Color(1, 1, 1, 0.45))
	# T 字ののぞき穴
	ci.draw_rect(Rect2(-0.3, 0.02, 0.6, 0.11), COL.ink)
	ci.draw_rect(Rect2(-0.055, 0.02, 0.11, 0.38), COL.ink)
	ci.draw_line(Vector2(-0.38, -0.04), Vector2(0.38, -0.04), k.darkened(0.35), 0.04)


## HP：赤いハートに白い心電図の線
func _i_stat_hp(ci: CanvasItem, k: Color) -> void:
	ci.draw_circle(Vector2(-0.2, -0.12), 0.25, k)
	ci.draw_circle(Vector2(0.2, -0.12), 0.25, k)
	ci.draw_colored_polygon(pts([[-0.44, -0.02], [0.44, -0.02], [0, 0.46]]), k)
	var line := pts([[-0.46, 0.0], [-0.18, 0.0], [-0.08, -0.22], [0.04, 0.2], [0.13, -0.06], [0.2, 0.0], [0.46, 0.0]])
	ci.draw_polyline(line, COL.paper, 0.08, true)


## 攻撃：交差した2本の剣
func _i_stat_atk(ci: CanvasItem, k: Color) -> void:
	for a in [PI / 4, -PI / 4]:
		ci.draw_colored_polygon(_rot([[0, -0.52], [0.08, -0.42], [0.08, 0.16], [-0.08, 0.16], [-0.08, -0.42]], a), k)
		ci.draw_colored_polygon(_rot([[0, -0.48], [0.03, -0.42], [0.03, 0.14], [0, 0.14]], a), k.lightened(0.6))
		ci.draw_colored_polygon(_rot([[-0.2, 0.15], [0.2, 0.15], [0.2, 0.24], [-0.2, 0.24]], a), COL.red)
		ci.draw_colored_polygon(_rot([[-0.05, 0.24], [0.05, 0.24], [0.05, 0.42], [-0.05, 0.42]], a), Color("3a2a22"))


## 素早さ：羽の付いた靴と速度の線
func _i_stat_spd(ci: CanvasItem, k: Color) -> void:
	for y in [-0.12, 0.06, 0.24]:
		ci.draw_line(Vector2(-0.5, y), Vector2(-0.3, y), Color(k, 0.6), 0.06)
	ci.draw_colored_polygon(pts([[-0.16, -0.36], [0.12, -0.36], [0.12, 0.08], [0.42, 0.18], [0.46, 0.4], [-0.2, 0.4]]), k)
	ci.draw_rect(Rect2(-0.2, 0.32, 0.66, 0.08), k.darkened(0.45))
	ci.draw_rect(Rect2(-0.18, -0.4, 0.34, 0.1), COL.paper)
	# 羽（白）
	for i in 3:
		var y0 := -0.34 + i * 0.13
		ci.draw_colored_polygon(pts([[-0.14, y0], [-0.46 + i * 0.05, y0 - 0.16], [-0.38 + i * 0.04, y0 + 0.02], [-0.14, y0 + 0.12]]), COL.paper)


## 薬草：茎を赤い紐で束ねた3枚の葉
func _i_item_herb(ci: CanvasItem, k: Color) -> void:
	var leaf := [[0, 0.06], [0.13, -0.12], [0.1, -0.34], [0, -0.48], [-0.1, -0.34], [-0.13, -0.12]]
	for a in [-0.62, 0.62, 0.0]:
		var base := Vector2(0, 0.18)
		ci.draw_line(base, base + Vector2(0, -0.26).rotated(a), k.darkened(0.45), 0.06, true)
		var col: Color = k if a == 0.0 else k.darkened(0.18)
		ci.draw_colored_polygon(_rot(leaf, a, base + Vector2(0, -0.18).rotated(a)), col)
		ci.draw_line(base + Vector2(0, -0.2).rotated(a), base + Vector2(0, -0.58).rotated(a), k.lightened(0.45), 0.035, true)
	ci.draw_line(Vector2(-0.04, 0.18), Vector2(-0.1, 0.48), k.darkened(0.45), 0.07, true)
	ci.draw_line(Vector2(0.04, 0.18), Vector2(0.1, 0.48), k.darkened(0.45), 0.07, true)
	ci.draw_rect(Rect2(-0.13, 0.2, 0.26, 0.09), COL.red)
	ci.draw_colored_polygon(pts([[0.1, 0.24], [0.3, 0.16], [0.26, 0.34]]), COL.red)


## 火炎ポーション：丸いフラスコに燃える液体と炎の印
func _i_item_fire(ci: CanvasItem, k: Color) -> void:
	var glass := Color("e6f0f8", 0.9)
	ci.draw_colored_polygon(pts([[-0.1, -0.34], [0.1, -0.34], [0.1, -0.08], [-0.1, -0.08]]), glass)
	ci.draw_colored_polygon(pts([[-0.13, -0.46], [0.13, -0.46], [0.13, -0.34], [-0.13, -0.34]]), Color("8a5a32"))
	ci.draw_circle(Vector2(0, 0.18), 0.32, glass)
	ci.draw_circle(Vector2(0, 0.2), 0.27, k)
	ci.draw_colored_polygon(_teardrop(Vector2(0, 0.3), 0.13, 0.32), Color("ffe08a"))
	ci.draw_colored_polygon(_teardrop(Vector2(0, 0.33), 0.06, 0.16), COL.paper)
	ci.draw_circle(Vector2(-0.14, 0.06), 0.05, Color(1, 1, 1, 0.7))
	# 口から立つ火の粉
	ci.draw_colored_polygon(_teardrop(Vector2(0.02, -0.48), 0.06, 0.12, 0.03), k)


## 力の水：角ばった細長い瓶に青い液体と黄色い稲妻のラベル
func _i_item_power(ci: CanvasItem, k: Color) -> void:
	var glass := Color("e6f0f8", 0.9)
	ci.draw_colored_polygon(pts([[-0.08, -0.4], [0.08, -0.4], [0.08, -0.26], [0.24, -0.14], [0.24, 0.46], [-0.24, 0.46], [-0.24, -0.14], [-0.08, -0.26]]), glass)
	ci.draw_colored_polygon(pts([[0.19, -0.04], [0.19, 0.41], [-0.19, 0.41], [-0.19, -0.04]]), k)
	ci.draw_colored_polygon(pts([[-0.11, -0.5], [0.11, -0.5], [0.11, -0.38], [-0.11, -0.38]]), Color("8a5a32"))
	ci.draw_rect(Rect2(-0.24, 0.04, 0.48, 0.28), COL.paper)
	ci.draw_colored_polygon(pts([[0.03, 0.06], [-0.1, 0.2], [-0.01, 0.2], [-0.05, 0.31], [0.1, 0.15], [0.01, 0.15]]), Color("f2c22a"))
	ci.draw_line(Vector2(-0.15, -0.1), Vector2(-0.15, 0.0), Color(1, 1, 1, 0.7), 0.04)


## 毒：緑のどくろ（小さくても分かる太い形）
func _i_st_poison(ci: CanvasItem, k: Color) -> void:
	ci.draw_circle(Vector2(0, -0.08), 0.4, k)
	ci.draw_colored_polygon(pts([[-0.24, 0.12], [0.24, 0.12], [0.2, 0.44], [-0.2, 0.44]]), k)
	ci.draw_circle(Vector2(-0.15, -0.06), 0.12, COL.ink)
	ci.draw_circle(Vector2(0.15, -0.06), 0.12, COL.ink)
	ci.draw_colored_polygon(pts([[0, 0.08], [0.06, 0.2], [-0.06, 0.2]]), COL.ink)
	ci.draw_line(Vector2(-0.07, 0.3), Vector2(-0.07, 0.44), COL.ink, 0.05)
	ci.draw_line(Vector2(0.07, 0.3), Vector2(0.07, 0.44), COL.ink, 0.05)


## 怒りマーク（漫画の「💢」）。4つの角から中心へ反った太い弧
func _i_anger(ci: CanvasItem, k: Color, c: Vector2, sc: float) -> void:
	for q in 4:
		var d := Vector2(1, 1).rotated(PI / 2 * q)
		var cc := c + d * 0.42 * sc
		var a0 := d.angle() + PI - PI * 0.27
		ci.draw_arc(cc, 0.3 * sc, a0, a0 + PI * 0.54, 12, k, 0.15 * sc, true)


## ファイアガード（状態）：炎を抱いた盾
func _i_fire_guard(ci: CanvasItem, k: Color) -> void:
	var outer := pts([[-0.42, -0.42], [0.42, -0.42], [0.42, -0.02], [0.32, 0.22], [0, 0.5], [-0.32, 0.22], [-0.42, -0.02]])
	ci.draw_colored_polygon(outer, k)
	var inner := pts([[-0.3, -0.31], [0.3, -0.31], [0.3, -0.04], [0.23, 0.15], [0, 0.36], [-0.23, 0.15], [-0.3, -0.04]])
	ci.draw_colored_polygon(inner, COL.ink)
	ci.draw_colored_polygon(_teardrop(Vector2(0, 0.16), 0.16, 0.44), k)
	ci.draw_colored_polygon(_teardrop(Vector2(0, 0.2), 0.08, 0.22), Color("ffe08a"))


## 連続魔法（状態）：重なった2つの星
func _i_st_double(ci: CanvasItem, k: Color) -> void:
	ci.draw_colored_polygon(star_pts(Vector2(-0.14, -0.12), 0.34, 0.15), k.darkened(0.25))
	ci.draw_colored_polygon(star_pts(Vector2(0.16, 0.14), 0.36, 0.16), COL.ink)
	ci.draw_colored_polygon(star_pts(Vector2(0.16, 0.14), 0.3, 0.13), k.lightened(0.45))


## スワップ：青（左）と赤（右）の玉を回る2本の矢印
func _i_c_swap(ci: CanvasItem, k: Color) -> void:
	ci.draw_circle(Vector2(-0.26, 0), 0.15, Color("2f7cf0"))
	ci.draw_circle(Vector2(0.26, 0), 0.15, COL.red)
	ci.draw_arc(Vector2.ZERO, 0.4, -PI * 0.92, -PI * 0.18, 16, k, 0.08, true)
	ci.draw_arc(Vector2.ZERO, 0.4, PI * 0.08, PI * 0.82, 16, k, 0.08, true)
	var t1 := Vector2(cos(-PI * 0.14), sin(-PI * 0.14)) * 0.4
	ci.draw_colored_polygon(PackedVector2Array([t1 + Vector2(0.1, 0.1), t1 + Vector2(-0.14, -0.04), t1 + Vector2(0.08, -0.16)]), k)
	var t2 := Vector2(cos(PI * 0.86), sin(PI * 0.86)) * 0.4
	ci.draw_colored_polygon(PackedVector2Array([t2 + Vector2(-0.1, -0.1), t2 + Vector2(0.14, 0.04), t2 + Vector2(-0.08, 0.16)]), k)


## フォース：魔力の玉から右へ広がる衝撃波
func _i_c_force(ci: CanvasItem, k: Color) -> void:
	glow(ci, Vector2(-0.26, 0), 0.3, Color(k, 0.9), 5)
	ci.draw_circle(Vector2(-0.26, 0), 0.14, COL.paper)
	for i in 3:
		var r := 0.22 + i * 0.13
		ci.draw_arc(Vector2(-0.26, 0), r, -PI * 0.32, PI * 0.32, 12, Color(k, 1.0 - i * 0.22), 0.07 - i * 0.012, true)
	ci.draw_colored_polygon(pts([[0.2, -0.06], [0.48, 0], [0.2, 0.06]]), COL.paper)


## ヒットアンドアウェイ：右で一撃（爆発）、左へ戻る曲がった矢印
func _i_c_hit_away(ci: CanvasItem, k: Color) -> void:
	ci.draw_colored_polygon(burst_pts(Vector2(0.24, -0.12), 0.28, 0.13, 9, 2), Color("ffb03a"))
	ci.draw_colored_polygon(burst_pts(Vector2(0.24, -0.12), 0.15, 0.07, 9, 4), COL.paper)
	ci.draw_arc(Vector2(0.0, -0.02), 0.34, PI * 0.12, PI * 0.88, 16, k, 0.09, true)
	var tip := Vector2(cos(PI * 0.92), sin(PI * 0.92)) * 0.34 + Vector2(0.0, -0.02)
	ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-0.04, -0.18), tip + Vector2(-0.1, 0.1), tip + Vector2(0.16, 0.02)]), k)
	for y in [0.3, 0.42]:
		ci.draw_line(Vector2(0.06, y), Vector2(0.34, y), Color(k, 0.5), 0.04)


## 折れた剣
func _i_broken_sword(ci: CanvasItem, k: Color) -> void:
	var a := PI / 4
	ci.draw_colored_polygon(_rot([[0.075, -0.12], [0.075, 0.16], [-0.075, 0.16], [-0.075, -0.06]], a), k)
	ci.draw_colored_polygon(_rot([[-0.22, 0.15], [0.22, 0.15], [0.22, 0.23], [-0.22, 0.23]], a), ICON_DEFAULT.star)
	ci.draw_colored_polygon(_rot([[-0.045, 0.23], [0.045, 0.23], [0.045, 0.4], [-0.045, 0.4]], a), Color("7a4a2a"))
	# 折れて飛んだ切っ先
	ci.draw_colored_polygon(_rot([[0, -0.5], [0.075, -0.4], [0.075, -0.2], [-0.075, -0.26], [-0.075, -0.4]], a + 0.4, Vector2(0.02, -0.08)), k.darkened(0.15))


## 毒ガス：緑の雲と小さなどくろ
func _i_c_poison_gas(ci: CanvasItem, k: Color) -> void:
	var dk := k.darkened(0.35)
	for v in [[-0.26, 0.12, 0.2], [0.0, 0.0, 0.26], [0.26, 0.12, 0.2], [-0.1, 0.24, 0.18], [0.14, 0.24, 0.18]]:
		ci.draw_circle(Vector2(v[0], v[1]), v[2] + 0.04, dk)
	for v in [[-0.26, 0.12, 0.2], [0.0, 0.0, 0.26], [0.26, 0.12, 0.2], [-0.1, 0.24, 0.18], [0.14, 0.24, 0.18]]:
		ci.draw_circle(Vector2(v[0], v[1]), v[2], k)
	ci.draw_circle(Vector2(0, 0.06), 0.14, COL.ink)
	ci.draw_rect(Rect2(-0.08, 0.14, 0.16, 0.1), COL.ink)
	ci.draw_circle(Vector2(-0.05, 0.05), 0.04, k)
	ci.draw_circle(Vector2(0.05, 0.05), 0.04, k)
	for v in [[-0.3, -0.3, 0.07], [0.22, -0.36, 0.06], [0.36, -0.2, 0.05]]:
		ci.draw_arc(Vector2(v[0], v[1]), v[2], 0, TAU, 12, k, 0.03, true)


## 瞑想：蓮の花の上に光る玉
func _i_c_meditate(ci: CanvasItem, k: Color) -> void:
	glow(ci, Vector2(0, -0.26), 0.34, Color(k, 0.8), 5)
	ci.draw_circle(Vector2(0, -0.26), 0.14, COL.paper)
	var petal := [[0, 0.0], [0.14, -0.18], [0, -0.46], [-0.14, -0.18]]
	for a in [-1.2, -0.6, 0.6, 1.2, 0.0]:
		var col: Color = k if a == 0.0 else k.darkened(0.2 + absf(a) * 0.1)
		ci.draw_colored_polygon(_rot(petal, a, Vector2(0, 0.38)), col)
	ci.draw_line(Vector2(-0.4, 0.4), Vector2(0.4, 0.4), Color(k, 0.6), 0.04)


## マジックウォール：光るレンガの壁
func _i_c_magic_wall(ci: CanvasItem, k: Color) -> void:
	ci.draw_rect(Rect2(-0.44, -0.38, 0.88, 0.8), Color(k, 0.25))
	for row in 4:
		var y := -0.38 + row * 0.2
		ci.draw_line(Vector2(-0.44, y), Vector2(0.44, y), k, 0.04)
		var off := 0.0 if row % 2 == 0 else 0.15
		for i in 3:
			var x := -0.29 + off + i * 0.3
			if x < 0.44:
				ci.draw_line(Vector2(x, y), Vector2(x, y + 0.2), k, 0.04)
	ci.draw_rect(Rect2(-0.44, -0.38, 0.88, 0.8), k, false, 0.06)
	_sparkle(ci, Vector2(0.3, -0.36), 0.16, COL.paper)
	_sparkle(ci, Vector2(-0.32, 0.3), 0.11, COL.paper)


## 連続魔法：並んで飛ぶ2つの星と尾
func _i_c_double(ci: CanvasItem, k: Color) -> void:
	for v in [Vector2(0.18, -0.2), Vector2(0.02, 0.2)]:
		var tail := PackedVector2Array([v + Vector2(-0.06, -0.08), v + Vector2(-0.5, 0.0), v + Vector2(-0.06, 0.08)])
		ci.draw_colored_polygon(tail, Color(k, 0.55))
		ci.draw_colored_polygon(star_pts(v, 0.2, 0.09), k.lightened(0.5))
	ci.draw_line(Vector2(0.32, 0.12), Vector2(0.46, 0.26), COL.paper, 0.06)
	ci.draw_line(Vector2(0.46, 0.12), Vector2(0.32, 0.26), COL.paper, 0.06)


## ビッグシールド：鋲を打った大きな縦長の盾
func _i_c_big_shield(ci: CanvasItem, k: Color) -> void:
	var outer := pts([[-0.34, -0.5], [0.34, -0.5], [0.38, -0.44], [0.38, 0.36], [0, 0.52], [-0.38, 0.36], [-0.38, -0.44]])
	ci.draw_colored_polygon(outer, k.lightened(0.45))
	var inner := pts([[-0.29, -0.42], [0.29, -0.42], [0.3, 0.31], [0, 0.43], [-0.3, 0.31]])
	ci.draw_colored_polygon(inner, k)
	ci.draw_colored_polygon(pts([[-0.29, -0.42], [-0.12, -0.42], [-0.12, 0.38], [-0.3, 0.31]]), k.lightened(0.15))
	ci.draw_rect(Rect2(-0.3, -0.06, 0.6, 0.1), k.lightened(0.5))
	for v in [Vector2(-0.24, -0.34), Vector2(0.24, -0.34), Vector2(-0.24, 0.22), Vector2(0.24, 0.22)]:
		ci.draw_circle(v, 0.04, COL.paper)


## ファイアガード（カード）：炎の輪
func _i_c_fire_ring(ci: CanvasItem, k: Color) -> void:
	for i in 10:
		var a := TAU * i / 10.0
		var p := Vector2(cos(a), sin(a)) * 0.3
		var td := _teardrop(Vector2.ZERO, 0.1, 0.22)
		var out := PackedVector2Array()
		for v in td:
			out.append(v.rotated(a + PI / 2) + p)
		ci.draw_colored_polygon(out, k if i % 2 == 0 else k.lightened(0.3))


## 研ぎ澄ます：立てた剣と火花
func _i_c_hone(ci: CanvasItem, k: Color) -> void:
	ci.draw_colored_polygon(pts([[0, -0.5], [0.08, -0.4], [0.08, 0.16], [-0.08, 0.16], [-0.08, -0.4]]), k)
	ci.draw_colored_polygon(pts([[0, -0.46], [0.03, -0.4], [0.03, 0.14], [0, 0.14]]), COL.paper)
	ci.draw_rect(Rect2(-0.22, 0.15, 0.44, 0.08), ICON_DEFAULT.star)
	ci.draw_rect(Rect2(-0.045, 0.23, 0.09, 0.2), Color("7a4a2a"))
	# 刃に走る光
	ci.draw_line(Vector2(-0.2, -0.1), Vector2(0.2, -0.3), Color(1, 1, 1, 0.7), 0.04, true)
	for v in [[-0.18, -0.3, 0.12], [-0.3, -0.12, 0.09], [0.3, -0.38, 0.1], [-0.2, 0.02, 0.07]]:
		_sparkle(ci, Vector2(v[0], v[1]), v[2], Color("ffe08a"))


## 一閃：画面を横切る細い光の筋
func _i_c_flash(ci: CanvasItem, k: Color) -> void:
	var a := Vector2(-0.5, 0.36)
	var b := Vector2(0.5, -0.36)
	var n := (b - a).normalized().orthogonal()
	ci.draw_colored_polygon(PackedVector2Array([a, (a + b) / 2 + n * 0.1, b, (a + b) / 2 - n * 0.03]), Color(COL.red, 0.9))
	ci.draw_colored_polygon(PackedVector2Array([a, (a + b) / 2 + n * 0.05, b, (a + b) / 2 - n * 0.01]), k)
	_sparkle(ci, (a + b) / 2, 0.22, k)
	for t in [0.22, 0.78]:
		var p: Vector2 = a.lerp(b, t)
		ci.draw_line(p - n * 0.14, p - n * 0.3, Color(k, 0.6), 0.03)


## 大振り：大剣と大きな振りの軌跡
func _i_c_big_swing(ci: CanvasItem, k: Color) -> void:
	ci.draw_arc(Vector2(-0.06, 0.26), 0.46, -PI * 0.92, -PI * 0.2, 20, Color(k, 0.35), 0.14, true)
	ci.draw_arc(Vector2(-0.06, 0.26), 0.46, -PI * 0.7, -PI * 0.2, 16, Color(k, 0.6), 0.05, true)
	var a := PI * 0.3
	var o := Vector2(-0.14, 0.26)
	ci.draw_colored_polygon(_rot([[0, -0.64], [0.12, -0.52], [0.12, 0.0], [-0.12, 0.0], [-0.12, -0.52]], a, o), k)
	ci.draw_colored_polygon(_rot([[0, -0.6], [0.04, -0.52], [0.04, -0.02], [0, -0.02]], a, o), COL.paper)
	ci.draw_colored_polygon(_rot([[-0.24, 0.0], [0.24, 0.0], [0.24, 0.09], [-0.24, 0.09]], a, o), COL.red)
	ci.draw_colored_polygon(_rot([[-0.05, 0.09], [0.05, 0.09], [0.05, 0.24], [-0.05, 0.24]], a, o), Color("3a2a22"))


## 鋼鉄化：光る鋼の胸当て
func _i_c_steel(ci: CanvasItem, k: Color) -> void:
	var body := pts([[-0.42, -0.36], [-0.16, -0.42], [0, -0.3], [0.16, -0.42], [0.42, -0.36], [0.34, 0.0], [0.28, 0.44], [-0.28, 0.44], [-0.34, 0.0]])
	ci.draw_colored_polygon(body, k.darkened(0.35))
	var face := pts([[-0.34, -0.3], [-0.16, -0.34], [0, -0.22], [0.16, -0.34], [0.34, -0.3], [0.27, 0.0], [0.22, 0.37], [-0.22, 0.37], [-0.27, 0.0]])
	ci.draw_colored_polygon(face, k)
	ci.draw_line(Vector2(0, -0.22), Vector2(0, 0.37), k.darkened(0.3), 0.05)
	ci.draw_line(Vector2(-0.26, 0.08), Vector2(0.26, 0.08), k.darkened(0.3), 0.04)
	ci.draw_colored_polygon(pts([[-0.24, -0.22], [-0.12, -0.24], [-0.16, 0.0], [-0.24, 0.0]]), Color(1, 1, 1, 0.6))
	_sparkle(ci, Vector2(0.3, -0.38), 0.18, COL.paper)
	_sparkle(ci, Vector2(-0.36, 0.3), 0.1, COL.paper)


## 貯める：4方向から中心の光へ集まる矢印
func _i_c_store(ci: CanvasItem, k: Color) -> void:
	glow(ci, Vector2.ZERO, 0.34, Color(k, 0.9), 6)
	ci.draw_circle(Vector2.ZERO, 0.13, COL.paper)
	for i in 4:
		var d := Vector2(1, 1).normalized().rotated(PI / 2 * i)
		_arrow_shape(ci, d * 0.52, d * 0.22, k, 0.07)


## 渾身の一撃：赤い爆発を突き抜ける剣
func _i_c_full_strike(ci: CanvasItem, k: Color, m: Transform2D) -> void:
	ci.draw_colored_polygon(burst_pts(Vector2(0.08, -0.08), 0.54, 0.28, 12, 7), k)
	ci.draw_colored_polygon(burst_pts(Vector2(0.08, -0.08), 0.32, 0.17, 12, 9), Color("ffe08a"))
	ci.draw_circle(Vector2(0.08, -0.08), 0.1, COL.paper)
	_sub(ci, m, Vector2(-0.04, 0.04), 0.92)
	_i_sword(ci, ICON_DEFAULT.sword)
	_sub(ci, m, Vector2.ZERO, 1.0)


## 仁王立ち：足を開いて腰に手を当てた立ち姿と後ろの光
func _i_c_stand(ci: CanvasItem, k: Color) -> void:
	for i in 12:
		var a := TAU * i / 12.0
		ci.draw_line(Vector2(cos(a), sin(a)) * 0.34 + Vector2(0, -0.04), Vector2(cos(a), sin(a)) * 0.52 + Vector2(0, -0.04), Color(COL.red, 0.8), 0.05)
	var dk := k.darkened(0.3)
	# 脚
	ci.draw_colored_polygon(pts([[-0.1, 0.06], [0.0, 0.06], [-0.2, 0.46], [-0.32, 0.46]]), dk)
	ci.draw_colored_polygon(pts([[0.0, 0.06], [0.1, 0.06], [0.32, 0.46], [0.2, 0.46]]), dk)
	# 腕（腰に手）
	ci.draw_polyline(pts([[-0.14, -0.2], [-0.3, -0.04], [-0.12, 0.06]]), k, 0.08, true)
	ci.draw_polyline(pts([[0.14, -0.2], [0.3, -0.04], [0.12, 0.06]]), k, 0.08, true)
	# 胴と頭
	ci.draw_colored_polygon(pts([[-0.16, -0.26], [0.16, -0.26], [0.11, 0.08], [-0.11, 0.08]]), k)
	ci.draw_circle(Vector2(0, -0.36), 0.11, k)
	ci.draw_rect(Rect2(-0.08, -0.38, 0.16, 0.04), COL.ink)


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
