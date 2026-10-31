extends Node
class_name ActionController
## 行動（カード・敵の技・道具）の対象決定とダメージ計算。
## 実行結果はイベント配列で返し、表示側（Cont_Battle）が演出に使う。


static func _st(u: Dictionary, k: String) -> int:
	return int(u.get("status_effects", {}).get(k, 0))


static func get_atk(u: Dictionary) -> int:
	return int(u.get("atk", 0)) + _st(u, "atk_buff") - _st(u, "atk_debuff")


static func get_def(u: Dictionary) -> int:
	return int(u.get("def", 0)) + _st(u, "def_buff") - _st(u, "def_debuff")


static func calc_damage(user: Dictionary, action: Dictionary, target: Dictionary) -> int:
	return maxi(0, int(action.get("power", 0)) + get_atk(user) - get_def(target))


## 戻り値: [{"target": 辞書, "damage": n, "blocked": n, "shield": n, "status": id, "status_val": n, "heal": n, "ap": n}, ...]
static func execute_action(user: Dictionary, action: Dictionary, allies: Array, enemies: Array) -> Array:
	var events: Array = []
	var targets := resolve_targets(user, action.get("target", "self"), allies, enemies)
	var to_self: bool = action.get("effect_target", "target") == "self"
	for t in targets:
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
		if action.has("effect") and not to_self:
			_apply_effect(t, action, ev)
		events.append(ev)
	if action.has("effect") and to_self and user.hp > 0:
		var ev2 := {"target": user}
		_apply_effect(user, action, ev2)
		events.append(ev2)
	return events


static func _apply_effect(t: Dictionary, action: Dictionary, ev: Dictionary) -> void:
	var v := int(action.get("eff_val", 0))
	match action.effect:
		"add_ap":
			t["ap"] = mini(int(t.get("max_ap", 5)), int(t.get("ap", 0)) + v)
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
			var n = nearest(user, foes)
			return [] if n == null else [n]
		"front_enemy_group":
			var n = nearest(user, foes)
			if n == null:
				return []
			var left := is_left(n)
			return foes.filter(func(e): return is_left(e) == left)
	return []


## グリッド上で一番近い相手（同距離なら配列の先頭）
static func nearest(user: Dictionary, foes: Array):
	var best = null
	var best_d := INF
	var up := str_to_vector2(user.get("grid_key", "E2"))
	for e in foes:
		var d := str_to_vector2(e.get("grid_key", "E2")).distance_to(up)
		if d < best_d:
			best_d = d
			best = e
	return best


## 戦場の左半分（A〜E列）にいるか
static func is_left(u: Dictionary) -> bool:
	return str_to_vector2(u.get("grid_key", "E2")).x < 4.5


## "A0" → Vector2(0, 0)、"C3" → Vector2(2, 3)
static func str_to_vector2(coord_str: String) -> Vector2:
	if coord_str.length() < 2:
		return Vector2.ZERO
	return Vector2(coord_str.unicode_at(0) - 65, coord_str.substr(1).to_int())
