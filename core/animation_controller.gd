# core/animation_controller.gd
extends Node

var active_anims = {}
var anim_counter = 0

# アニメーション名からデータを検索する補助関数
func _get_anim_data(anim_name: String) -> Dictionary:
	for category in AnimationList.ANIMATIONS.values():
		if category.has(anim_name):
			return category[anim_name]
	return {}

# 1. アニメーションを再生する関数
# is_loop を true にすると、手動で消去するまでループ再生します
func play_animation(anim_name: String, pos: Vector2, scale: Vector2, color: Color, rotation_deg: float, flip_h: bool, duration_frames: int, is_loop: bool = false) -> String:
	var data = _get_anim_data(anim_name)
	if data.is_empty():
		push_error("AnimationController: アニメーションが見つかりません - " + anim_name)
		return ""

	var sprite = Sprite2D.new()
	sprite.texture = load(data["path"])
	
	# 分割数の設定 (Godotでは hframes, vframes と呼びます)
	sprite.hframes = data.get("x_frames", 1)
	sprite.vframes = data.get("y_frames", 1)
	
	var start_frame = data.get("start_frame", 0)
	var end_frame = data.get("end_frame", -1)
	
	# end_frame が -1 の場合は、分割数から最後のフレーム番号を計算
	if end_frame == -1:
		end_frame = (sprite.hframes * sprite.vframes) - 1

	sprite.frame = start_frame
	sprite.position = pos
	sprite.scale = scale
	sprite.modulate = color
	sprite.rotation_degrees = rotation_deg
	sprite.flip_h = flip_h
	add_child(sprite)
	
	var anim_id = "anim_" + str(anim_counter)
	anim_counter += 1
	active_anims[anim_id] = {"sprite": sprite, "tween": null}
	
	# Tweenによるコマ送りアニメーションの作成
	var duration_sec = duration_frames / 60.0
	var tween = create_tween()
	
	# コマ送りを等間隔にするため、TRANS_LINEAR を指定
	tween.set_trans(Tween.TRANS_LINEAR)
	
	if is_loop:
		tween.set_loops() # 無限ループ
	
	# start_frame から end_frame まで数値を変化させる
	tween.tween_property(sprite, "frame", end_frame, duration_sec).from(start_frame)
	
	# ループしない場合は、アニメーション終了後に自動で消去する
	if not is_loop:
		tween.tween_callback(func():
			stop_animation(anim_id)
		)
		
	active_anims[anim_id]["tween"] = tween
	return anim_id

# 2. アニメーションを強制終了・消去する関数
func stop_animation(anim_id: String):
	if not active_anims.has(anim_id):
		return
		
	var anim_data = active_anims[anim_id]
	if anim_data["tween"] and anim_data["tween"].is_valid():
		anim_data["tween"].kill() # 動いているTweenを止める
		
	if is_instance_valid(anim_data["sprite"]):
		anim_data["sprite"].queue_free() # ノードを削除
		
	active_anims.erase(anim_id)
