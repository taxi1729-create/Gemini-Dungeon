extends Node
class_name ActionController
## 行動（カード・スキル・敵の技・道具）の対象決定とダメージ計算。
## 結果はその場で確定し、イベント配列で返す（表示側が演出に使う）。
##
## 立ち位置
##   味方：lane 0 = 左（青ターゲット）／ lane 1 = 右（赤ターゲット）
##   敵  ：row 0 = 前衛（最大 4 体）／ row 1 = 後衛（最大 2 体）
##   各キャラの画面上の位置は pos（Vector2）
##
## イベントの形
##   {"target", "damage", "blocked"} / {"target", "shield"} / {"target", "status", "status_val"} / {"target", "heal"} / {"target", "ap"}
##   {"target", "charge"} / {"target"(攻撃した側), "status": "fire", "reflect": true}
##   {"target": 使用者, "special": "draw" / "swap" / "double" / "turnabout" / "extra_turn", "val": n} … 表示側（Cont_Battle）が処理する


static func get_atk(u: Dictionary) -> int:
	return int(u.get("atk", 0)) + StatusController.val(u, "atk_buff") - StatusController.val(u, "atk_down") + int(u.get("power_atk", 0))


static func get_def(u: Dictionary) -> int:
	return int(u.get("def", 0)) + StatusController.val(u, "def_buff") - StatusController.val(u, "def_down") + int(u.get("power_def", 0))


static func get_spd(u: Dictionary) -> int:
	return int(u.get("spd", 0)) + StatusController.val(u, "spd_buff")


static func calc_damage(user: Dictionary, action: Dictionary, target: Dictionary) -> int:
	if action.get("fixed", false):
		return int(action.get("power", 0))
	return maxi(0, int(action.get("power", 0)) + get_atk(user) - get_def(target))


## カードに表示する「実際のダメージ」（主な対象＝最初の対象に対して）。対象がいなければ攻撃力だけ反映
static func effective_power(user: Dictionary, action: Dictionary, allies: Array, enemies: Array) -> int:
	if not action.has("power"):
		return 0
	var t := resolve_targets(user, action.get("target", "self"), allies, enemies)
	if t.is_empty():
		return maxi(0, int(action.power) + get_atk(user))
	return calc_damage(user, action, t[0])


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


static func execute_action(user: Dictionary, action: Dictionary, allies: Array, enemies: Array) -> Array:
	var events: Array = []
	var targets := resolve_targets(user, action.get("target", "self"), allies, enemies)
	var is_ally: bool = user.get("side", "ally") == "ally"
	var friends := (allies if is_ally else enemies).filter(func(e): return e.hp > 0)
	# ダメージ
	if action.has("power"):
		for t in targets:
			if t.hp <= 0:
				continue
			var dmg := calc_damage(user, action, t)
			var blocked := mini(int(t.get("shield", 0)), dmg)
			t["shield"] = int(t.get("shield", 0)) - blocked
			dmg -= blocked
			t["hp"] = maxi(0, int(t.hp) - dmg)
			events.append({"target": t, "damage": dmg, "blocked": blocked})
			# ファイアガード：攻撃してきた相手に火傷
			if StatusController.has(t, "fire_guard") and user.hp > 0 and user != t:
				var v := StatusController.val(t, "fire_guard")
				StatusController.apply_status(user, "fire", v, v)
				events.append({"target": user, "status": "fire", "status_val": v, "reflect": true})
	# 効果
	for eff in ActionList.effects_of(action):
		var to: String = eff.get("to", "target")
		var recips: Array = targets
		if to == "self":
			recips = [user]
		elif to == "ally_all":
			recips = friends
		var kind: String = eff.get("effect", "")
		if kind in ["draw", "swap", "double", "turnabout", "extra_turn"]:
			events.append({"target": user, "special": kind, "val": int(eff.get("eff_val", 0))})
			continue
		for t in recips:
			if t.hp <= 0:
				continue
			var ev := {"target": t}
			_apply_effect(user, t, eff, ev)
			events.append(ev)
	return events


static func _apply_effect(user: Dictionary, t: Dictionary, eff: Dictionary, ev: Dictionary) -> void:
	var v := int(eff.get("eff_val", 0))
	match eff.get("effect", ""):
		"add_ap":
			t["ap"] = mini(int(t.get("max_ap", 10)), int(t.get("ap", 0)) + v)
			ev["ap"] = v
		"add_shield":
			t["shield"] = int(t.get("shield", 0)) + v
			ev["shield"] = v
		"add_status":
			var sid: String = eff.status
			var turns := int(eff.get("turns", -1))
			# 自分のターン中に自分へ付けた期間つきの効果は、このターンの終わりで減らないよう 1 足す
			if turns > 0 and t == user:
				turns += 1
			if sid == "taunt":
				v = int(user.get("uid", 0))  # 挑発してきたキャラ
			StatusController.apply_status(t, sid, v, turns)
			ev["status"] = sid
			ev["status_val"] = int(eff.get("eff_val", v)) if sid != "taunt" else 1
		"heal":
			var before := int(t.hp)
			t["hp"] = mini(int(t.max_hp), before + v)
			ev["heal"] = int(t.hp) - before
		"set_next_action":
			t["next_action"] = eff.get("next", "strong_attack")
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
				# 挑発されていれば、挑発してきた味方を狙う
				if StatusController.has(user, "taunt"):
					var uid := StatusController.val(user, "taunt")
					for a in foes:
						if int(a.get("uid", -1)) == uid:
							return [a]
				# 予告した側（左＝青／右＝赤）にいる味方。倒れていれば残った方
				var lane := int(user.get("target_lane", 0))
				for a in foes:
					if int(a.get("lane", 0)) == lane:
						return [a]
				return [foes[0]]
			# 味方の単体攻撃：目の前の敵グループで HP が一番低い敵（同じなら近い方）
			var group := front_group(user, foes)
			var up: Vector2 = user.get("pos", Vector2.ZERO)
			var best = group[0]
			for e in group:
				if int(e.hp) < int(best.hp) or (int(e.hp) == int(best.hp) and up.distance_to(e.pos) < up.distance_to(best.pos)):
					best = e
			return [best]
		"front_enemy_group":
			return front_group(user, foes) if is_ally else foes
		"front_row":
			var row0 := foes.filter(func(e): return int(e.get("row", 0)) == 0)
			return row0 if not row0.is_empty() else foes
	return []


## 目の前の敵グループ：自分の側（左の味方なら画面の左半分、右なら右半分）にいる敵。いなければ全員
static func front_group(user: Dictionary, foes: Array) -> Array:
	var left: bool = int(user.get("lane", 0)) == 0
	var side := foes.filter(func(e): return is_left(e) == left)
	return side if not side.is_empty() else foes


static func is_left(u: Dictionary) -> bool:
	return Vector2(u.get("pos", Vector2.ZERO)).x < 360.0
