extends Node
class_name ActionList

const ALLY_CARDS = {
	"strike": {"name": "ストライク", "type": "attack", "target": "front_enemy_single", "power": 3, "ap": 1,"sleeve": "sleeve_red", "frame": "frame_normal_red", "image": "slash"},
	"block": {"name": "ブロック", "type": "skill", "target": "self", "effect": "add_def", "val": 5, "ap": 1,"sleeve": "sleeve_red", "frame": "frame_normal_red", "image": "slash"},
	"sweep": {"name": "薙ぎ払い", "type": "attack", "target": "front_enemy_group", "power": 7, "ap": 2,"sleeve": "sleeve_red", "frame": "frame_normal_red", "image": "slash"},
	"thunderbolt": {"name": "サンダーボルト", "type": "attack", "target": "enemy_all", "power": 5, "effect": "add_status", "status": "atk_down", "val": 2, "ap": 1,"sleeve": "sleeve_red", "frame": "frame_normal_red", "image": "slash"},
	"companion_block": {"name": "コンパニオンブロック", "type": "skill", "target": "self", "effect": "add_def", "val": 2, "ap": 1,"sleeve": "sleeve_red", "frame": "frame_normal_red", "image": "slash"},
	"firebolt": {"name": "ファイアボルト", "type": "attack", "target": "enemy_all", "power": 15, "ap": 2,"sleeve": "sleeve_red", "frame": "frame_normal_red", "image": "slash"},
	"weak_point": {"name": "急所突き", "type": "attack", "target": "front_enemy_single", "power": 5, "effect": "add_status", "status": "atk_down", "duration": 2, "ap": 1,"sleeve": "sleeve_red", "frame": "frame_normal_red", "image": "slash"},
	
	"action_accel": {"name": "アクション加速", "type": "skill", "target": "self", "effect": "add_ap", "val": 1, "ap": 0,"sleeve": "sleeve_red", "frame": "frame_normal_red_blu", "image": "slash"},
	"shield_attack": {"name": "シールドアタック", "type": "attack", "target": "enemy_all", "power": 2, "effect": "add_def_all", "val": 1, "ap": 1,"sleeve": "sleeve_red", "frame": "frame_normal_blu", "image": "slash"},
	"attack_up": {"name": "アタックアップ", "type": "skill", "target": "ally_all", "effect": "add_atk", "val": 3, "ap": 1,"sleeve": "sleeve_red", "frame": "frame_normal_blu", "image": "slash"},
	
	"force": {"name": "フォース", "type": "unselectable", "target": "self", "effect": "add_atk", "val": 2, "ap": 0,"sleeve": "sleeve_red", "frame": "frame_normal", "image": "slash"}
}

const ENEMY_ACTIONS = {
	"bite": {"name": "噛み付く", "type": "attack", "target": "front_enemy_single", "power": 5,"icon": "sword_icon"},
	"poison_stab": {"name": "毒突き", "type": "attack", "target": "front_enemy_single", "power": 3, "effect": "add_status", "status": "poison", "duration": 4},
	"block": {"name": "ブロック", "type": "skill", "target": "self", "effect": "add_def", "val": 3},
	"defend": {"name": "防御", "type": "defense", "target": "ally_all", "effect": "add_shield", "val": 5},
	"shield_attack": {"name": "シールドアタック", "type": "attack", "target": "front_enemy_single", "power": 8, "effect": "add_shield", "val": 5},
	"charge": {"name": "溜める", "type": "skill", "target": "self", "effect": "set_next_action", "next": "strong_attack"},
	"strong_attack": {"name": "強攻撃", "type": "unselectable", "target": "enemy_all", "power": 10}
}
