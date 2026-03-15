extends Node

var active_anims = {}
var anim_counter = 0

func _get_anim_data(anim_name: String) -> Dictionary:
	for category in AnimationList.ANIMATIONS.values():
		if category.has(anim_name): return category[anim_name]
	return {}

# 速度(speed)を反映した再生
func play_animation(anim_name: String, pos: Vector2, scale: Vector2, color: Color, rotation_deg: float, flip_h: bool, is_loop: bool = false) -> String:
	var data = _get_anim_data(anim_name)
	if data.is_empty(): return ""

	var sprite = Sprite2D.new()
	sprite.texture = load(data["path"])
	sprite.hframes = data.get("x_frames", 1)
	sprite.vframes = data.get("y_frames", 1)
	
	var start_frame = data.get("start_frame", 0)
	var end_frame = data.get("end_frame", -1)
	if end_frame == -1: end_frame = (sprite.hframes * sprite.vframes) - 1
	var frames_count = end_frame - start_frame + 1
	var speed = data.get("speed", 10) # 1コマのフレーム数

	sprite.frame = start_frame
	sprite.position = pos
	sprite.scale = scale
	sprite.modulate = color
	sprite.rotation_degrees = rotation_deg
	sprite.flip_h = flip_h
	add_child(sprite)
	
	var anim_id = "anim_" + str(anim_counter)
	anim_counter += 1
	
	# 全体の秒数 = コマ数 * 1コマのフレーム数 / 60.0fps
	var duration_sec = float(frames_count * speed) / 60.0
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	if is_loop: tween.set_loops()
	tween.tween_property(sprite, "frame", end_frame, duration_sec).from(start_frame)
	
	if not is_loop:
		tween.tween_callback(func(): stop_animation(anim_id))
		
	active_anims[anim_id] = {"sprite": sprite, "tween": tween, "base_color": color, "blink_tween": null}
	return anim_id

func stop_animation(anim_id: String):
	if not active_anims.has(anim_id): return
	var anim = active_anims[anim_id]
	if anim["tween"] and anim["tween"].is_valid(): anim["tween"].kill()
	if anim["blink_tween"] and anim["blink_tween"].is_valid(): anim["blink_tween"].kill()
	if is_instance_valid(anim["sprite"]): anim["sprite"].queue_free()
	active_anims.erase(anim_id)

# 位置の即時移動 (アクションB用)
func set_position(anim_id: String, pos: Vector2):
	if active_anims.has(anim_id) and is_instance_valid(active_anims[anim_id]["sprite"]):
		active_anims[anim_id]["sprite"].position = pos

# 対象を点滅させる機能 (長押し用)
func set_blink(anim_id: String, do_blink: bool, blink_color: Color = Color.GREEN):
	if not active_anims.has(anim_id): return
	var anim = active_anims[anim_id]
	var sprite = anim["sprite"]
	
	if anim["blink_tween"] and anim["blink_tween"].is_valid():
		anim["blink_tween"].kill()
	
	if do_blink:
		var bt = create_tween().set_loops()
		bt.tween_property(sprite, "modulate", anim["base_color"], 0.3)
		bt.tween_property(sprite, "modulate", blink_color, 0.3)
		anim["blink_tween"] = bt
	else:
		sprite.modulate = anim["base_color"]
