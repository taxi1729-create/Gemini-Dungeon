extends Node
class_name ActionController
## 行動（カード・スキル・敵の技・道具）の対象決定とダメージ計算。
## 結果はその場で確定し、イベント配列で返す（表示側が演出に使う）。
##
## 立ち位置
##   前後の概念はない。味方は lane 0 = 左（青ターゲット）／ lane 1 = 右（赤ターゲット）
##   各キャラの画面上の位置は pos（Vector2）に入っている


static func _st(u: Dictionary, k: String) -> int:
	return int(u.get("status_effects", {}).get(k, 0))


static func get_atk(u: Dictionary) -> int:
	return int(u.get("atk", 0)) + _st(u, "atk_buff")


static func get_def(u: Dictionary) -> int:
	return int(u.get("def", 0))


static func get_spd(u: Dictionary) -> int:
	return int(u.get("spd", 0)) + _st(u, "spd_buff")


static func calc_damage(user: Dictionary, action: Dictionary, target: Dictionary) -> int:
	if action.get("fixed", false):
		return int(action.get("power", 0))
	return maxi(0, int(action.get("power", 0)) + get_atk(user) - get_def(target))


## 予想：[{target, damage(ブロック後), kill}]
static func preview(user: Dictionary, action: Dictionary, allies: Array, enemies: Array) -> Array:
	var out: Array = []
	for t in resolve_targets(user, action.get("target", "self"), allies, enemies):
		var ev := {"target": t}
		if action.has("power"):
			var dmg := calc_damage(user, action, t)
			var after := maxi(0, dmg - int(t.get("shield", 0)))
			ev["damage"] = after
			ev["kill"] = after >= int(t.hp)
		out.append(ev)
	return out


## 戻り値: [{"target": 辞書, "damage": n, "blocked": n, "shield": n, "status": id, "status_val": n, "heal": n, "ap": n}, ...]
## draw / turnabout / extra_turn / swap は表示側（Cont_Battle）で処理する。
static func execute_action(user: Dictionary, action: Dictionary, allies: Array, enemies: Array) -> Array:
	var events: Array = []
	for t in resolve_targets(user, action.get("target", "self"), allies, enemies):
		if t.hp <= 0:
			continue
		var ev := {"target": t}
		if action.has("power"):
			var dmg := calc_damage(user, action, t)
			var blocked := mini(int(t.get("shield", 0)), dmg)
			t["shield"] = int(t.get("shield", 0)) - blocked
			dmg -= blocked
			t["hp"] = maxi(0, int(t.hp) - dmg)
			ev["damage"] = dmg
			ev["blocked"] = blocked
		elif action.has("effect"):
			_apply_effect(t, action, ev)
		events.append(ev)
	return events


static func _apply_effect(t: Dictionary, action: Dictionary, ev: Dictionary) -> void:
	var v := int(action.get("eff_val", 0))
	match action.effect:
		"add_ap":
			t["ap"] = int(t.get("ap", 0)) + v
			ev["ap"] = v
		"add_shield":
			t["shield"] = int(t.get("shield", 0)) + v
			ev["shield"] = v
		"add_status":
			StatusController.apply_status(t, action.status, v)
			ev["status"] = action.status
			ev["status_val"] = v
		"heal":
			var before := int(t.hp)
			t["hp"] = mini(int(t.max_hp), before + v)
			ev["heal"] = int(t.hp) - before
		"set_next_action":
			t["next_action"] = action.get("next", "strong_attack")
			ev["charge"] = true


static func resolve_targets(user: Dictionary, target_type: String, allies: Array, enemies: Array) -> Array:
	var is_ally: bool = user.get("side", "ally") == "ally"
	var foes := (enemies if is_ally else allies).filter(func(e): return e.hp > 0)
	var friends := (allies if is_ally else enemies).filter(func(e): return e.hp > 0)
	match target_type:
		"self":
			return [user]
		"ally_all":
			return friends
		"enemy_all":
			return foes
		"front_enemy_single":
			if foes.is_empty():
				return []
			if not is_ally:
				# 敵の単体攻撃：予告した側（左＝青／右＝赤）にいる味方。倒れていれば残った方
				var lane := int(user.get("target_lane", 0))
				for a in foes:
					if int(a.get("lane", 0)) == lane:
						return [a]
				return [foes[0]]
			# 味方の単体攻撃：一番近い敵
			var up: Vector2 = user.get("pos", Vector2.ZERO)
			var best = foes[0]
			for e in foes:
				if up.distance_to(e.get("pos", Vector2.ZERO)) < up.distance_to(best.get("pos", Vector2.ZERO)):
					best = e
			return [best]
		"front_enemy_group":
			# 自分の側（左右）にいる敵全員。いなければ反対側の敵全員
			var left: bool = int(user.get("lane", 0)) == 0
			var side := foes.filter(func(e): return is_left(e) == left)
			return side if not side.is_empty() else foes
	return []


static func is_left(u: Dictionary) -> bool:
	return Vector2(u.get("pos", Vector2.ZERO)).x < 360.0
