extends Node
# プロジェクト設定で "ImageController" としてAutoloadに登録推奨

# 表示中の画像を管理するための辞書 (ID: Sprite2D)
var active_images = {}
var image_counter = 0

func show_image(image_key: String, pos: Vector2, options: Dictionary = {}) -> String:
	# (パス取得ロジックは以前のまま)
	var path = ""
	for category in ImageList.DATA.values():
		if category.has(image_key):
			path = category[image_key]
			break

	if path == "":
		push_error("ImageController: キー '" + image_key + "' が見つかりません！")
		return ""
	#if image_key == "sword_icon":
		#print(path)
	var sprite = Sprite2D.new()
	sprite.texture = load(path)
	sprite.position = pos
	
	# --- 【修正】初期値の設定 ---
	sprite.scale = options.get("scale", Vector2.ONE)
	sprite.modulate = options.get("color", Color.WHITE)
	# "angle"（角度）オプションを追加 (デフォルト0.0)
	sprite.rotation_degrees = options.get("angle", 0.0) 
	# "flip_h"（左右反転）オプションを追加 (デフォルトfalse)
	sprite.flip_h = options.get("flip_h", false)
	
	sprite.z_index = options.get("z_index", 0) 
	
	add_child(sprite)
	
	var id = "img_" + str(image_counter)
	image_counter += 1
	active_images[id] = sprite
	return id

func manipulate_image(image_id: String, options: Dictionary = {}):
	if not active_images.has(image_id): return
	var img = active_images[image_id]
	if not is_instance_valid(img): return
	
	var duration_sec = float(options.get("duration", 0)) / 60.0
	var tween = create_tween().set_parallel(true)
	
	# 指定された項目だけを操作する
	if options.has("pos"): tween.tween_property(img, "position", options["pos"], duration_sec)
	if options.has("scale"): tween.tween_property(img, "scale", options["scale"], duration_sec)
	if options.has("color"): tween.tween_property(img, "modulate", options["color"], duration_sec)
	if options.has("rotation"): tween.tween_property(img, "rotation_degrees", options["rotation"], duration_sec)
	if options.has("flip_h"): img.flip_h = options["flip_h"]
	if options.has("z_index"): img.z_index = options["z_index"]

func get_image_position(image_id: String) -> Vector2:
	if active_images.has(image_id) and is_instance_valid(active_images[image_id]):
		return active_images[image_id].position
	return Vector2.ZERO
func get_z_index(image_id: String) -> float:
	if active_images.has(image_id) and is_instance_valid(active_images[image_id]):
		return active_images[image_id].z_index
	return float(0)
# 3. 画像を消去する関数
func erase_image(image_id: String, duration_frames: int):
	if not active_images.has(image_id):
		return
		
	var sprite = active_images[image_id]
	var duration_sec = duration_frames / 60.0
	
	var tween = create_tween()
	# 指定フレームかけて透明度を0にする
	tween.tween_property(sprite, "modulate:a", 0.0, duration_sec)
	# 透明になり終わったらノードを削除し、辞書からも消す
	tween.tween_callback(func():
		sprite.queue_free()
		active_images.erase(image_id)
	)

# ==========================================
# 【新機能】放物線を描いて移動する (Arc Move)
# ==========================================
func move_image_arc(image_id: String, end_pos: Vector2, options: Dictionary = {}):
	if not active_images.has(image_id): return
	var img = active_images[image_id]
	if not is_instance_valid(img): return
	
	# --- パラメータの取得と計算 ---
	var start_pos = img.position
	var start_angle = img.rotation_degrees
	# options から取得 (なければ今の値、またはデフォルト値)
	var end_angle = options.get("end_angle", start_angle)
	var duration_sec = float(options.get("duration", 30)) / 60.0
	
	# 放物線の高さ (始点と終点の中心からの上方向へのズレ)
	# デフォルトは画面高さの1/4程度にするなど、適宜調整
	var arc_height = options.get("height", -100.0) # マイナス値が上方向

	# Tweenの作成 (並列処理はオフにする)
	var tween = create_tween()
	
	# 角度のアニメーションは通常通り Tween する
	if start_angle != end_angle:
		tween.set_parallel(true) # 角度と移動を同時に動かすために一時的にオン
		tween.tween_property(img, "rotation_degrees", end_angle, duration_sec)
		tween.set_parallel(false) # 移動計算用にオフに戻す
	
	# --- 放物線移動の計算ロジック ---
	# Tweenの `tween_method` を使い、0.0〜1.0 の「進行度(t)」を計算関数に渡す
	tween.tween_method(
		_calculate_arc_position.bind(img, start_pos, end_pos, arc_height),
		0.0, # 開始値 (0%)
		1.0, # 終了値 (100%)
		duration_sec
	)

# 【内部用】放物線の座標計算関数
# t: 進行度 (0.0 ～ 1.0)
func _calculate_arc_position(t: float, img: Sprite2D, start: Vector2, end: Vector2, height: float):
	if not is_instance_valid(img): return
	
	# 1. 直線的なXY座標 (線形補間)
	var current_x = lerp(start.x, end.x, t)
	var current_y = lerp(start.y, end.y, t)
	
	# 2. 放物線の「高さ」を計算 (二次関数: y = a * x * (x - 1))
	# tが0.0または1.0の時に0になり、tが0.5の時に最大(height)になる
	var arc_y = 4 * height * t * (1.0 - t)
	
	# 3. 直線y座標に高さを足す
	img.position = Vector2(current_x, current_y + arc_y)
# ==========================================
# 【最終版】光沢エフェクト (単色/虹色 切り替え対応)
# ==========================================
func shine_image(image_id: String, options: Dictionary = {}):
	if not active_images.has(image_id): return
	var img = active_images[image_id]
	if not is_instance_valid(img): return

	# --- パラメータの取得 ---
	var duration_sec = float(options.get("duration_frames", 180)) / 60.0
	var intensity = float(options.get("intensity", 1.0))
	var width = float(options.get("width", 0.2))
	var is_loop = options.get("loop", false)
	var is_hologram = options.get("hologram", false) # trueで虹色、falseで単色
	var base_color = options.get("color", Color.WHITE) # 単色時の色
	var wait_time = options.get("wait", 2.0)
	
	# --- シェーダーの動的作成 ---
	var shader = Shader.new()
	shader.code = """
	shader_type canvas_item;
	uniform float progress : hint_range(0.0, 1.0);
	uniform float width : hint_range(0.0, 1.0);
	uniform float intensity : hint_range(0.0, 5.0);
	uniform bool is_hologram;
	uniform vec4 single_color : source_color;

	vec3 get_hologram_color(float p) {
		return vec3(0.5 + 0.5 * cos(6.28 * (p + vec3(0.0, 0.33, 0.67))));
	}

	void fragment() {
		vec4 tex_color = texture(TEXTURE, UV);
		float slope = UV.x + UV.y; 
		float current_pos = progress * 2.0;
		
		float shine = smoothstep(current_pos - width, current_pos, slope) - 
					 smoothstep(current_pos, current_pos + width, slope);
		
		vec3 shine_rgb;
		if (is_hologram) {
			// 虹色：進行度と位置で色を変化させる
			shine_rgb = get_hologram_color(progress + slope * 0.5);
		} else {
			// 単色：指定された色を使用
			shine_rgb = single_color.rgb;
		}

		vec3 final_color = mix(tex_color.rgb, shine_rgb, shine * intensity * tex_color.a);
		COLOR = vec4(final_color, tex_color.a);
	}
	"""
	
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("width", width)
	mat.set_shader_parameter("intensity", intensity)
	mat.set_shader_parameter("is_hologram", is_hologram)
	mat.set_shader_parameter("single_color", base_color)
	mat.set_shader_parameter("progress", 0.0)
	
	img.material = mat

	# --- アニメーションの制御 ---
	var tween = create_tween()
	if is_loop:
		# 待機時間
		if wait_time > 0:
			tween.tween_interval(wait_time)

		tween.set_loops()
		tween.tween_property(mat, "shader_parameter/progress", 1.0, duration_sec).from(0.0)
	else:
		tween.tween_property(mat, "shader_parameter/progress", 1.0, duration_sec).from(0.0)
		tween.tween_callback(func(): 
			if is_instance_valid(img):
				img.material = null 
		)
		
# ==========================================
# 1. ゆらゆら揺れる演出 (Sway)
# options: { "intensity": 5.0, "duration": 1.0, "wait": 2.0 }
# ==========================================
func sway_image(image_id: String, options: Dictionary = {}):
	if not active_images.has(image_id): return
	var img = active_images[image_id]
	if not is_instance_valid(img): return
	
	# 入力値の設定（デフォルト値を指定）
	var intensity = options.get("intensity", 5.0)
	var duration = options.get("duration", 1.0)
	var wait_time = options.get("wait", 0.0)
	
	# 既存のTweenがあれば停止（重複防止）
	if img.has_meta("sway_tween"):
		var old_tween = img.get_meta("sway_tween")
		if old_tween.is_valid(): old_tween.kill()

	var tween = create_tween().set_loops()
	var q_dur = duration / 4.0
	
	# 揺れのアニメーションサイクル
	tween.tween_property(img, "rotation_degrees", intensity, q_dur).set_trans(Tween.TRANS_SINE)
	tween.tween_property(img, "rotation_degrees", -intensity, q_dur * 2).set_trans(Tween.TRANS_SINE)
	tween.tween_property(img, "rotation_degrees", 0.0, q_dur).set_trans(Tween.TRANS_SINE)
	
	# 待機時間
	if wait_time > 0:
		tween.tween_interval(wait_time)
		
	img.set_meta("sway_tween", tween)
	
