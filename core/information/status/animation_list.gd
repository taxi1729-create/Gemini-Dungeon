# core/information/status/animation_list.gd
extends Node
class_name AnimationList

const ANIMATIONS = {
	"general": {
		# x_frames: 横の分割数, y_frames: 縦の分割数, start_frame: 開始コマ, end_frame: 終了コマ(-1で最後まで)
		# speed: 1コマを表示するフレーム数 (例: 10なら、60fps環境で1秒間に6コマ進む)
		"idle_k": {"path": "res://index/design/image/animation/kngiht_action_x4_y2.png", "x_frames": 4, "y_frames": 2, "start_frame": 3, "end_frame": 6, "speed": 10},
		"idle_w": {"path": "res://index/design/image/animation/witch_action_x3_y4.png", "x_frames": 3, "y_frames": 4, "start_frame": 9, "end_frame": 11, "speed": 20},
		"turn_k": {"path": "res://index/design/image/animation/knight_power_up_x3.png", "x_frames": 3, "y_frames": 1, "start_frame": 0, "end_frame": 2, "speed": 10},
		"turn_w": {"path": "res://index/design/image/animation/witch_action_x3_y4.png", "x_frames": 3, "y_frames": 4, "start_frame": 9, "end_frame": 11, "speed": 30}
	},
	"attack": {
		# 例: 3x2の6コマ画像で、2コマ目から始まり、4コマ目で終わる設定
		"slash": {"path": "res://index/design/image/animation/knight_power_up_x3.png", "x_frames": 3, "y_frames": 1, "start_frame": 0, "end_frame": 2, "speed": 10},
		"shoot": {"path": "res://index/design/image/animation/knight_power_up_x3.png", "x_frames": 3, "y_frames": 1, "start_frame": 0, "end_frame": 2, "speed": 10}
	},
	"skill": {
		"cast_magic": {"path": "res://index/design/image/animation/knight_power_up_x3.png", "x_frames": 3, "y_frames": 1, "start_frame": 0, "end_frame": 2, "speed": 10}
	},
	"damage": {
		"hit": {"path": "res://index/design/image/animation/knight_power_up_x3.png", "x_frames": 3, "y_frames": 1, "start_frame": 0, "end_frame": 2, "speed": 10}
	},
	"item": {
		"use_item": {"path": "res://index/design/animation/image/knight_power_up_x3.png", "x_frames": 3, "y_frames": 1, "start_frame": 0, "end_frame": 2, "speed": 10}
	}
}

const MOTION_GROUPS = {
	"knight_motions": {
		"idle": "idle_k",
		"turn": "turn_k",         # 自分のターン
		"attack": "slash",
		"damage": "hit",
		"skill": "cast_magic",  # スキル発動
		"victory": "win",       # 勝利
		"defeat": "dead"        # 敗北
	},
	"witch_motions": {
		"idle": "idle_w",
		"turn": "turn_w",         # 自分のターン
		"attack": "cast_magic",
		"damage": "hit",
		"skill": "cast_magic",  # スキル発動
		"victory": "win",       # 勝利
		"defeat": "dead"        # 敗北
	}
}
