extends Node
class_name ActionController

static func execute_action(user: Dictionary, action: Dictionary, allies: Array, enemies: Array):
	var targets = _resolve_targets(user, action.target, allies, enemies)
	for target in targets:
		if target.hp <= 0: continue
		
		# 攻撃処理
		if action.has("power"):
			#print(action)
			var dmg = max(0, (action.power+user.atk - target.def))
			if target.has("shield"):
				target.shield -= dmg
				if target.shield <= 0:
					dmg = -target.shield
					target.shield=0
			target.hp -= dmg
			#if target.hp <1:
			#	print(target.name,"は倒された",target)

		# 特殊効果処理
		if action.has("effect"):
			match action.effect:
				"add_ap":
					target.ap += action.eff_val
				"add_shield":
					target.shield += action.eff_val
				"add_status":
					StatusController.apply_status(target, action.status, action.eff_val)

# ターゲットの自動判定
static func _resolve_targets(user: Dictionary, target_type: String, allies: Array, enemies: Array) -> Array:
	var is_user_ally = allies.has(user)
	var opponent_team = enemies if is_user_ally else allies
	var own_team = allies if is_user_ally else enemies
	#print(opponent_team)
	match target_type:
		"self":
			return [user]
		"ally_all":
			return own_team
		"enemy_all":
			return opponent_team
		"front_enemy_single", "front_enemy_group":
			# 最も配列の前(0番目)にいる生きている敵を「目の前」と判定
			var user_vec2 =str_to_vector2(user.grid_key)
			var min_distance =9999999
			var nearest_enemy = [user]
			for e in opponent_team:
				var enemy_vec2 =str_to_vector2(e.grid_key)
				var distance = enemy_vec2.distance_to(user_vec2)
				if distance < min_distance and e.hp > 0:
					min_distance = distance
					nearest_enemy=e
	#	print(user.id,"一番近い相手",nearest_enemy.name)
			return [nearest_enemy]
		#return []
	return []


# 文字列(A0, C3など)を Vector2(x, y) に変換する関数
static func str_to_vector2(coord_str: String) -> Vector2:
	if coord_str.length() < 2:
		return Vector2.ZERO
	
	# 1文字目(A, B, C...)を数値(0, 1, 2...)に変換
	# 'A' はアスキーコードで 65
	var x = coord_str.unicode_at(0) - 65
	
	# 2文字目以降を数値に変換
	var y = coord_str.substr(1).to_int()
	
	return Vector2(x, y)
