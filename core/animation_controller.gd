extends Node
# 例：敵が攻撃アニメーションを再生し、終わるまで他の操作をロックする
#AnimationController.play_animation("enemy_attack", pos, {"id": enemy.anim_id})
#await AnimationController.wait_for_animation(enemy.anim_id, true)

# 例：斬撃エフェクトを出して、終わったら自動的に削除する
#AnimationController.play_animation("slash_effect", target_pos, {"auto_delete": true})

var active_anims = {}
var anim_counter = 0


# ==========================================
# 4. 座標やエフェクトの操作 (元のロジックを維持)
# ==========================================
func set_position(anim_id: String, pos: Vector2):
	if active_anims.has(anim_id) and is_instance_valid(active_anims[anim_id]["sprite"]):
		active_anims[anim_id]["sprite"].position = pos
		active_anims[anim_id]["sprite"].flip_h = !active_anims[anim_id]["sprite"].flip_h

func get_position(anim_id: String) -> Vector2:
	if active_anims.has(anim_id) and is_instance_valid(active_anims[anim_id]["sprite"]):
		return active_anims[anim_id]["sprite"].position
	return Vector2.ZERO

func _get_anim_data(anim_name: String) -> Dictionary:
	for category in AnimationList.ANIMATIONS.values():
		if category.has(anim_name): return category[anim_name]
	return {}

# ==========================================
# 1. アニメーションの再生・生成
# ==========================================
func play_animation(anim_name: String, pos: Vector2, options: Dictionary = {}) -> String:
	var data = _get_anim_data(anim_name)
	if data.is_empty(): return ""

	var anim_id = options.get("id", "")
	var sprite: Sprite2D
	var is_new = false

	if anim_id != "" and active_anims.has(anim_id):
		sprite = active_anims[anim_id]["sprite"]
		if active_anims[anim_id]["tween"] and active_anims[anim_id]["tween"].is_valid():
			active_anims[anim_id]["tween"].kill()
	else:
		sprite = Sprite2D.new()
		anim_id = "anim_" + str(anim_counter)
		anim_counter += 1
		is_new = true
		add_child(sprite)
		active_anims[anim_id] = {
			"sprite": sprite, 
			"tween": null, 
			"base_color": Color.WHITE, 
			"blink_tween": null,
			"is_looping": false
		}

	# スプライトシート設定
	sprite.texture = load(data["path"])
	sprite.hframes = data.get("x_frames", 1)
	sprite.vframes = data.get("y_frames", 1)
	
	var start_frame = data.get("start_frame", 0)
	var end_frame = data.get("end_frame", -1)
	if end_frame == -1: end_frame = (sprite.hframes * sprite.vframes) - 1
	var speed = data.get("speed", 10)

	sprite.frame = start_frame
	sprite.position = pos

	# --- 【追加】角度と向きの設定 ---
	sprite.scale = options.get("scale", sprite.scale if not is_new else Vector2.ONE)
	sprite.modulate = options.get("color", sprite.modulate if not is_new else Color.WHITE)
	sprite.rotation_degrees = options.get("angle", sprite.rotation_degrees if not is_new else 0.0)
	sprite.flip_h = options.get("flip_h", sprite.flip_h if not is_new else false)
	sprite.z_index = options.get("z_index", sprite.z_index if not is_new else 0)
	
	var is_loop = options.get("is_loop", false)
	var auto_delete = options.get("auto_delete", false)

	active_anims[anim_id]["base_color"] = sprite.modulate
	active_anims[anim_id]["is_looping"] = is_loop

	# コマ送りTween
	var duration_sec = float((end_frame - start_frame + 1) * speed) / 60.0
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	if is_loop: tween.set_loops()
	
	tween.tween_property(sprite, "frame", end_frame, duration_sec).from(start_frame)
	
	if is_loop:
		tween.tween_callback(func(): sprite.frame = start_frame)
	else:
		tween.tween_callback(func(): if auto_delete: stop_animation(anim_id))
		
	active_anims[anim_id]["tween"] = tween
	return anim_id

# ==========================================
# 2. 放物線移動 (Arc Move) 
# ==========================================
func move_animation_arc(anim_id: String, end_pos: Vector2, options: Dictionary = {}):
	if not active_anims.has(anim_id): return
	var sprite = active_anims[anim_id]["sprite"]
	if not is_instance_valid(sprite): return
	
	var start_pos = sprite.position
	var start_angle = sprite.rotation_degrees
	var end_angle = options.get("end_angle", start_angle)
	var duration_sec = float(options.get("duration", 30)) / 60.0
	#マイナスで上方向にジャンプ
	var arc_height = options.get("height", -100.0) 

	var tween = create_tween()
	
	# 角度のアニメーション（指定がある場合のみ並列実行）
	if start_angle != end_angle:
		tween.set_parallel(true)
		tween.tween_property(sprite, "rotation_degrees", end_angle, duration_sec)
		tween.set_parallel(false)
	
	# 放物線座標の計算
	tween.tween_method(
		_calculate_arc_position.bind(sprite, start_pos, end_pos, arc_height),
		0.0, 1.0, duration_sec
	)

func _calculate_arc_position(t: float, sprite: Sprite2D, start: Vector2, end: Vector2, height: float):
	if not is_instance_valid(sprite): return
	var current_x = lerp(start.x, end.x, t)
	var current_y = lerp(start.y, end.y, t)
	var arc_y = 4 * height * t * (1.0 - t)
	sprite.position = Vector2(current_x, current_y + arc_y)

# ==========================================
# 3. ユーティリティ (待機・停止・エフェクト)
# ==========================================
func wait_for_animation(anim_id: String, block_input: bool = false):
	if not active_anims.has(anim_id): return
	if block_input: get_tree().root.gui_disable_input = true
	
	var tween = active_anims[anim_id]["tween"]
	if tween and tween.is_valid() and tween.is_running():
		if active_anims[anim_id]["is_looping"]:
			await tween.loop_finished
		else:
			await tween.finished
			
	if block_input: get_tree().root.gui_disable_input = false

func stop_animation(anim_id: String):
	if not active_anims.has(anim_id): return
	var anim = active_anims[anim_id]
	if anim["tween"] and anim["tween"].is_valid(): anim["tween"].kill()
	if is_instance_valid(anim["sprite"]): anim["sprite"].queue_free()
	active_anims.erase(anim_id)

func set_blink(anim_id: String, do_blink: bool, blink_color: Color = Color.GREEN):
	if not active_anims.has(anim_id): return
	var anim = active_anims[anim_id]
	if anim.get("blink_tween") and anim["blink_tween"].is_valid(): anim["blink_tween"].kill()
	if do_blink:
		anim["blink_tween"] = create_tween().set_loops()
		anim["blink_tween"].tween_property(anim["sprite"], "modulate", anim["base_color"], 0.3)
		anim["blink_tween"].tween_property(anim["sprite"], "modulate", blink_color, 0.3)
	else:
		anim["sprite"].modulate = anim["base_color"]

func flash_color(anim_id: String, flash_color: Color, duration_frames: int):
	if not active_anims.has(anim_id): return
	var anim = active_anims[anim_id]
	var duration_sec = float(duration_frames) / 60.0
	anim["sprite"].modulate = flash_color
	create_tween().tween_property(anim["sprite"], "modulate", anim["base_color"], duration_sec)

func shake_animation(anim_id: String):
	if not active_anims.has(anim_id): return
	var sprite = active_anims[anim_id]["sprite"]
	var base_pos = sprite.position
	var tween = create_tween()
	for i in range(4):
		tween.tween_property(sprite, "position", base_pos + Vector2(randf_range(-15, 15), 0), 0.05)
	tween.tween_property(sprite, "position", base_pos, 0.05)
