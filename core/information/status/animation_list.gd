# core/information/status/animation_list.gd
extends Node
class_name AnimationList

const ANIMATIONS = {
	"general": {
		# x_frames: 横の分割数, y_frames: 縦の分割数, start_frame: 開始コマ, end_frame: 終了コマ(-1で最後まで)
		# speed: 1コマを表示するフレーム数 (例: 10なら、60fps環境で1秒間に6コマ進む)
		"idle_k": {"path": "res://index/design/image/animation/dark_hero_x4y8.png", "x_frames": 4, "y_frames": 8, "start_frame": 0, "end_frame": 3, "speed": 15},
		"idle_w": {"path": "res://index/design/image/animation/witch_action_x3_y4.png", "x_frames": 3, "y_frames": 4, "start_frame": 9, "end_frame": 11, "speed": 20},
		"turn_k": {"path": "res://index/design/image/animation/dark_hero_x4y8.png", "x_frames": 4, "y_frames": 8, "start_frame": 4, "end_frame": 7, "speed": 9},
		"turn_w": {"path": "res://index/design/image/animation/witch_action_x3_y4.png", "x_frames": 3, "y_frames": 4, "start_frame": 9, "end_frame": 11, "speed": 30}
	},
	"attack": {
		# 例: 3x2の6コマ画像で、2コマ目から始まり、4コマ目で終わる設定
		"slash": {"path": "res://index/design/image/animation/dark_hero_x4y8.png", "x_frames": 4, "y_frames": 8, "start_frame": 8, "end_frame": 11, "speed": 6},
		"shoot": {"path": "res://index/design/image/animation/knight_power_up_x3.png", "x_frames": 3, "y_frames": 1, "start_frame": 0, "end_frame": 2, "speed": 10}
	},
	"skill": {
		"knight_skill":{"path":"res://index/design/image/animation/dark_hero_x4y8.png", "x_frames": 4, "y_frames": 8, "start_frame": 12, "end_frame": 15, "speed": 10},
		"cast_magic": {"path": "res://index/design/image/animation/witch_action_x3_y4.png", "x_frames": 3, "y_frames": 4, "start_frame": 0, "end_frame": 2, "speed": 10}
	},
	"damage": {
		"hit": {"path": "res://index/design/image/animation/dark_hero_x4y8.png", "x_frames": 4, "y_frames": 8, "start_frame": 16, "end_frame": 19, "speed": 10},
		"defeat_blu": {"path": "res://index/design/image/animation/defeat_x6_y2.png", "x_frames": 6, "y_frames": 2, "start_frame": 0, "end_frame": 5, "speed": 5},
		"defeat_red": {"path": "res://index/design/image/animation/defeat_x6_y2.png", "x_frames": 6, "y_frames": 2, "start_frame": 6, "end_frame": 11, "speed": 15}
	},
	"item": {
		"use_item": {"path": "res://index/design/animation/image/knight_power_up_x3.png", "x_frames": 3, "y_frames": 1, "start_frame": 0, "end_frame": 2, "speed": 10}
	},
	"enemy":{
		"zombie": {"path":"res://index/design/image/animation/zombie_x6_y1.png", "x_frames": 6, "y_frames": 1, "start_frame": 0, "end_frame": -1, "speed": 10},
		"goblin": {"path":"res://index/design/image/animation/enemies_x6_y4.png", "x_frames": 6, "y_frames": 4, "start_frame": 0, "end_frame": 5, "speed": 7},
		"gool": {"path":"res://index/design/image/animation/enemies_x6_y4.png", "x_frames": 6, "y_frames": 4, "start_frame": 6, "end_frame": 11, "speed": 5},
		"skeleton": {"path":"res://index/design/image/animation/enemies_x6_y4.png", "x_frames": 6, "y_frames": 4, "start_frame": 12, "end_frame": 17, "speed": 10},
		"harpy": {"path":"res://index/design/image/animation/enemies_x6_y4.png", "x_frames": 6, "y_frames": 4, "start_frame": 18, "end_frame": 23, "speed": 14},						
		"fire_war": {"path":"res://index/design/image/animation/fire_warrior_x3_y1.png", "x_frames": 3, "y_frames": 1, "start_frame": 0, "end_frame": -1, "speed": 23},
		"dark_knight_wa": {"path":"res://index/design/image/animation/dark_kngight_x6_y2.png", "x_frames": 6, "y_frames": 2, "start_frame": 0, "end_frame": 6, "speed": 20},
		"dark_knight_at": {"path":"res://index/design/image/animation/dark_kngight_x6_y2.png", "x_frames": 6, "y_frames": 2, "start_frame": 9, "end_frame": 15, "speed": 20},
		"green_dragon_wa": {"path":"res://index/design/image/animation/green_dragon_idle_attack_x8_y2.png", "x_frames": 8, "y_frames": 2, "start_frame": 0, "end_frame": 7, "speed": 10}	,
		"green_dragon_at": {"path":"res://index/design/image/animation/green_dragon_idle_attack_x8_y2.png", "x_frames": 8, "y_frames": 2, "start_frame": 8, "end_frame": 15, "speed": 20}	,
		"necro_wa": {"path":"res://index/design/image/animation/necromansar_idle_attacl_x8_y2.png", "x_frames": 8, "y_frames": 2, "start_frame": 0, "end_frame": 7, "speed": 15}	,
		"necro_at": {"path":"res://index/design/image/animation/necromansar_idle_attacl_x8_y2.png", "x_frames": 8, "y_frames": 2, "start_frame": 8, "end_frame": 15, "speed": 15}			
	}
}

const MOTION_GROUPS = {
	"knight_motions": {
		"idle": "idle_k",
		"turn": "turn_k",         # 自分のターン
		"attack": "slash",
		"damage": "hit",
		"skill": "knight_skill",  # スキル発動
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
	},
	"zombie":{
		"idle": "zombie",
		"defeat": "defeat_blu"        # 敗北,
	},
	"goblin":{
		"idle": "goblin",
		"defeat": "defeat_blu"        # 敗北,
	},
	"gool":{
		"idle": "gool",
		"defeat": "defeat_blu"        # 敗北,
	},
	"skeleton":{
		"idle": "skeleton",
		"defeat": "defeat_blu"        # 敗北,
	},
	"harpy":{
		"idle": "harpy",
		"defeat": "defeat_blu"        # 敗北,
	},
	"fire_war":{
		"idle": "fire_war",
		"defeat": "defeat_blu"        # 敗北,
	},
	"dark_knight":{
		"idle": "dark_knight_wa",
		"attack": "dark_knight_at",
		"defeat": "defeat_red"        # 敗北,
	},
	"green_dragon":{
		"idle": "green_dragon_wa",
		"attack": "green_dragon_at",
		"defeat": "defeat_red"        # 敗北,
	},
	"necro":{
		"idle": "necro_wa",
		"attack": "necro_at",
		"defeat": "defeat_red"        # 敗北,
	}
	
}
