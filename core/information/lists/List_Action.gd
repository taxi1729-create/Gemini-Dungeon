extends Node
class_name ActionList

const ALLY_CARDS = {
	"common":{
		"companion_block": {"name": "コンパニオンブロック", "type": "skill", "target": "self","image": "shield_1",
				"effect": "add_status", "status": "def_buff","eff_val": 2, 
				"ap": 1},
		"block": {"name": "ブロック", "type": "skill", "target": "self","image": "shield_1",
				"effect": "add_shield", "eff_val": 5, 
				"ap": 1},
		"firebolt": {"name": "ファイアボルト", "type": "attack", "target": "enemy_all" , "image": "fire_1", 
				"effect": "add_status", "status":"fire", "eff_val": 2,
				"power": 30, "ap": 2},
		"weak_point": {"name": "急所突き", "type": "attack", "target": "front_enemy_single","image": "debuff_1",
				"effect": "add_status", "status": "atk_debuff", "eff_val": 2,
				"power": 5, "ap": 1},
	},
	"rare":{
		"strike": {"name": "ストライク", "type": "attack", "target": "front_enemy_single", "image": "slash_1", 
				"power": 300, "ap": 1},
		"strong_block": {"name": "全体守護", "type": "skill", "target": "ally_all", "image": "buff_1",
				"effect": "add_shield", "eff_val": 15, 
				"ap": 1,"card_skill":"deck_top",
				"gradeup":{"eff_val": 30}},
		"sweep": {"name": "薙ぎ払い", "type": "attack", "target": "front_enemy_group", "image": "slash_2", 
				"power": 7, "ap": 1},
		"thunderbolt": {"name": "サンダーボルト", "type": "attack", "target": "enemy_all", "image": "thunder_1", 
				"effect": "add_status", "status": "atk_debuff", "eff_val": 2, 
				"power": 5,"ap": 1}

	},
	"super_rare":{
		"action_accel": {"name": "アクション加速", "type": "skill", "target": "self","image": "buff_2",
				"effect": "add_ap", "eff_val": 1, 
				"ap": 0},
		"shield_attack": {"name": "シールドアタック", "type": "attack", "target": "enemy_all","image": "slash_3", 
				"effect":  "add_status", "status": "def_buff","status_target":"self", "eff_val": 1, 
				"power": 20, "ap": 1},
		"attack_up": {"name": "アタックアップ", "type": "skill", "target": "ally_all", "image": "force_1", 
				"effect": "add_status", "status": "atk_buff", "eff_val": 3, 
				"ap": 1},
		"force": {"name": "フォース", "type": "unselectable", "target": "self", "image": "force_1", 
				"effect": "add_status", 	"status": "atk_buff","timing": "start_turn","eff_val": 2, 
				}

	}
}

const ENEMY_ACTIONS = {
	"bite": {"name": "噛み付く", "type": "attack", "target": "front_enemy_single", 
			"power": 5},
	"poison_stab": {"name": "毒突き", "type": "attack", "target": "front_enemy_single", 
			 "effect": "add_status", "status": "poison", "eff_val": 4,
			"power": 3},
	"block": {"name": "ブロック", "type": "skill", "target": "self", 
			"effect": "add_status", "status": "def_buff","eff_val": 3},
	"defend": {"name": "防御", "type": "defense", "target": "ally_all", 
			"effect": "add_shield", "eff_val": 15},
	"shield_attack": {"name": "シールドアタック", "type": "attack_defence", "target": "front_enemy_single", 
			"power": 8, "effect": "add_shield", "eff_val": 15},
	"charge": {"name": "溜める", "type": "skill", "target": "self", 
			"effect": "set_next_action"},
	"strong_attack": {"name": "強攻撃", "type": "unselectable", "target": "enemy_all", 
			"power": 10}
}
