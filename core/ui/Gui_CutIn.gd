extends Control
class_name GuiCutIn
## 必殺技のカットイン。画面を斜めに横切る黒い帯に、キャラを大きく、技名を太字で出す。
## 入力は一切ふさがない（mouse_filter = IGNORE）。実時間で進み、終わると自分で消える。

const DUR := 0.85
const BAND_H := 250.0
const CY := 360.0  # 帯の中心の高さ（戦場の上に出し、操作中の指で隠れないようにする）
const ANG := -0.17  # 帯の傾き

var char_id := "knight"
var special_name := ""
var _start := 0
var _seed: Array = []


func setup(cid: String, sname: String) -> void:
	char_id = cid
	special_name = sname


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 200
	_start = Time.get_ticks_usec()
	for i in 22:
		_seed.append(Vector3(randf(), randf(), randf()))


func _el() -> float:
	return (Time.get_ticks_usec() - _start) / 1000000.0


func _process(_delta: float) -> void:
	if _el() >= DUR:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := _el()
	var IC = ImageController
	var open := 1.0 - pow(1.0 - clampf(t / 0.1, 0.0, 1.0), 3.0)
	var close := clampf((t - 0.66) / 0.19, 0.0, 1.0)
	var h := BAND_H * open * (1.0 - close * close)
	var fade := 1.0 - close
	# 画面を少し暗く
	draw_rect(Rect2(0, 0, 720, 1280), Color(BattleFx.INK, 0.42 * open * fade))
	if h < 2:
		return
	var slide := close * 260.0  # 閉じる時は右へ流れて抜ける

	# --- 帯（傾けて描く） ---
	draw_set_transform(Vector2(360 + slide, CY), ANG, Vector2.ONE)
	draw_rect(Rect2(-700, -h / 2 - 14, 1400, h + 28), Color(BattleFx.PAPER, fade))
	draw_rect(Rect2(-700, -h / 2 - 6, 1400, 4), Color(BattleFx.INK, fade))
	draw_rect(Rect2(-700, -h / 2, 1400, h), Color(BattleFx.INK, fade))
	# 赤い斜めストライプ（流れる）
	for i in 16:
		var x := -700.0 + fmod(i * 92.0 + t * 1100.0, 1472.0)
		var sk := h * 0.45
		var w := 26.0 if i % 3 != 0 else 54.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, -h / 2), Vector2(x + w, -h / 2), Vector2(x + w - sk, h / 2), Vector2(x - sk, h / 2)]),
				Color(BattleFx.RED, 0.38 * fade if i % 3 != 0 else 0.6 * fade))
	# 白い集中線（左へ高速で流れる）
	for i in _seed.size():
		var sd: Vector3 = _seed[i]
		var y := (sd.x - 0.5) * h * 0.92
		var len := 80.0 + sd.y * 220.0
		var x := 700.0 - fmod(sd.z * 1400.0 + t * 2800.0, 1400.0)
		draw_line(Vector2(x, y), Vector2(x + len, y), Color(BattleFx.PAPER, 0.4 * fade), 2.0 + sd.y * 2.0)
	# キャラ色の細い帯と、赤の太い帯
	var ccol: Color = IC.COL.get(char_id, BattleFx.RED)
	draw_rect(Rect2(-700, -h / 2 + 6, 1400, 6), Color(ccol, 0.9 * fade))
	draw_rect(Rect2(-700, h / 2 - 22, 1400, 14), Color(BattleFx.RED, fade))

	# --- 技名（帯と同じ傾き） ---
	var tin := 1.0 - pow(1.0 - clampf((t - 0.04) / 0.13, 0.0, 1.0), 3.0)
	var tx := 120.0 + (1.0 - tin) * 520.0 + t * 24.0
	if h > BAND_H * 0.5:
		var tag := Rect2(tx - 150, -h / 2 + 26, 120, 34)
		draw_colored_polygon(PackedVector2Array([tag.position + Vector2(10, 0), tag.position + Vector2(tag.size.x + 10, 0),
				tag.end - Vector2(10, 0), tag.position + Vector2(-10, tag.size.y)]), Color(BattleFx.RED, fade))
		IC.text(self, "必殺技", tag.get_center(), 22, Color(BattleFx.PAPER, fade), true)
		BattleFx.comic_text(self, special_name, Vector2(tx, 10), 104, Color(BattleFx.PAPER, fade), Color(BattleFx.INK, fade),
				false, Color(BattleFx.RED, fade), 440.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# --- キャラ（帯からはみ出して大きく） ---
	var cin := 1.0 - pow(1.0 - clampf(t / 0.14, 0.0, 1.0), 3.0)
	var cx := -140.0 + cin * 300.0 + t * 30.0 + slide * 1.4
	# 足元は帯の下端より少し下（帯の傾きに合わせる）
	var foot := Vector2(cx, CY + h * 0.5 + 26.0 + (360.0 - cx) * tan(-ANG))
	var sc := 2.5 * (0.85 + 0.15 * cin)
	# 背後の赤い爆発形
	var burst: PackedVector2Array = IC.star_pts(foot + Vector2(0, -150 * sc / 2.5), 190 * open, 110 * open, 12, t * 1.5)
	draw_colored_polygon(burst, Color(BattleFx.RED, 0.85 * fade))
	draw_colored_polygon(IC.star_pts(foot + Vector2(0, -150 * sc / 2.5), 130 * open, 80 * open, 12, -t * 1.2), Color(BattleFx.PAPER, 0.9 * fade))
	if fade > 0.05:
		IC.character(self, char_id, foot, sc, 1.0, t * 3.0)
	# 出だしの白い閃光
	if t < 0.07:
		draw_rect(Rect2(0, 0, 720, 1280), Color(1, 1, 1, 0.55 * (1.0 - t / 0.07)))
