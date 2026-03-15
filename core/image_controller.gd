extends Node
# プロジェクト設定で "ImageController" としてAutoloadに登録推奨

# 表示中の画像を管理するための辞書 (ID: Sprite2D)
var active_images = {}
var image_counter = 0

# 指定したタイプの画像パスをImageListから探す補助関数
func _get_image_path(image_name: String) -> String:
	for category in ImageList.DATA.values():
		if category.has(image_name):
			return category[image_name]
	return ""

# 1. 画像を表示する関数
# 戻り値として、操作・消去時に使う「画像ID」を返します
func show_image(image_name: String, pos: Vector2, scale: Vector2, color: Color, rotation_deg: float, flip_h: bool, duration_frames: int) -> String:
	var path = _get_image_path(image_name)
	if path == "":
		push_error("ImageController: 画像が見つかりません - " + image_name)
		return ""

	var sprite = Sprite2D.new()
	sprite.texture = load(path)
	sprite.position = pos
	sprite.scale = scale
	sprite.modulate = color
	sprite.rotation_degrees = rotation_deg
	sprite.flip_h = flip_h
	
	# 最初は透明にしておく（フェードイン表示させるため）
	sprite.modulate.a = 0.0
	add_child(sprite)
	
	var image_id = "img_" + str(image_counter)
	image_counter += 1
	active_images[image_id] = sprite
	
	# フレーム数を秒に変換してTweenアニメーション (60fps想定)
	var duration_sec = duration_frames / 60.0
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", color.a, duration_sec) # 指定フレームかけて本来の透明度へ
	
	return image_id
func get_image_position(image_id: String) -> Vector2:
	if active_images.has(image_id):
		var img = active_images[image_id]
		if is_instance_valid(img):
			return img.position
	
	# 見つからない場合はゼロベクトルを返すか、エラーログを出す
	push_warning("ImageController: ID " + image_id + " が見つかりません。")
	return Vector2.ZERO
# 2. 画像を操作する関数
func manipulate_image(image_id: String, target_pos: Vector2, target_scale: Vector2, target_color: Color, target_rotation_deg: float, flip_h: bool, duration_frames: int):
	if not active_images.has(image_id):
		push_error("ImageController: 操作対象の画像が存在しません - " + image_id)
		return
		
	var sprite = active_images[image_id]
	sprite.flip_h = flip_h # フリップは即時反映
	
	var duration_sec = duration_frames / 60.0
	var tween = create_tween().set_parallel(true) # 複数の変化を同時に行う
	
	tween.tween_property(sprite, "position", target_pos, duration_sec)
	tween.tween_property(sprite, "scale", target_scale, duration_sec)
	tween.tween_property(sprite, "modulate", target_color, duration_sec)
	tween.tween_property(sprite, "rotation_degrees", target_rotation_deg, duration_sec)

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
