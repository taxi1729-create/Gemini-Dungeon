extends Node
class_name ActionController

static func execute_action(user: Dictionary, action: Dictionary, allies: Array, enemies: Array):
	var targets = _resolve_targets(user, action.target, allies, enemies)
	
	for target in targets:
		if target.hp <= 0: continue
		
		# 攻撃処理
		if action.has("power"):
			var dmg = max(0, action.power - target.def)
			target.hp -= dmg
		
		# 特殊効果処理
		if action.has("effect"):
			match action.effect:
				"add_def":
					target.def += action.val
				"add_def_all":
					for a in allies: a.def += action.val
				"add_ap":
					target.ap += action.val
				"add_atk":
					pass # 一時的な攻撃力加算ロジックをここに書く
				"add_status":
					StatusController.apply_status(target, action.status, action.get("duration", 2))

# ターゲットの自動判定
static func _resolve_targets(user: Dictionary, target_type: String, allies: Array, enemies: Array) -> Array:
	var is_user_ally = allies.has(user)
	var opponent_team = enemies if is_user_ally else allies
	var own_team = allies if is_user_ally else enemies
	
	match target_type:
		"self":
			return [user]
		"ally_all":
			return own_team
		"enemy_all":
			return opponent_team
		"front_enemy_single", "front_enemy_group":
			# 最も配列の前(0番目)にいる生きている敵を「目の前」と判定
			for e in opponent_team:
				if e.hp > 0: return [e]
			return []
	return []
