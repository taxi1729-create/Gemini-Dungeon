extends Node
class_name StatusController
## 状態異常の発動・付与・時間経過


## 手番の開始時（火傷・毒）。シールドを無視してHPに直接ダメージ。
static func trigger_start_of_turn(u: Dictionary) -> Array:
	var evs: Array = []
	for k in u.status_effects.keys():
		var st: Dictionary = StatusEffectList.DATA.get(k, {})
		if st.get("timing") == "start_turn":
			var v := int(u.status_effects[k])
			u["hp"] = maxi(0, int(u.hp) - v)
			evs.append({"target": u, "damage": v, "tick": k})
	return evs


## 手番の終了時（再生）
static func trigger_end_of_turn(u: Dictionary) -> Array:
	var evs: Array = []
	var v := int(u.status_effects.get("regen", 0))
	if v > 0 and u.hp > 0:
		var before := int(u.hp)
		u["hp"] = mini(int(u.max_hp), before + v)
		evs.append({"target": u, "heal": int(u.hp) - before})
	return evs


## ラウンド終了時：全員の状態異常を1ずつ減らす
static func decrease_all_durations(units: Array) -> void:
	for u in units:
		if u.hp <= 0:
			continue
		var remove: Array = []
		for k in u.status_effects.keys():
			u.status_effects[k] -= 1
			if u.status_effects[k] <= 0:
				remove.append(k)
		for k in remove:
			u.status_effects.erase(k)


static func apply_status(target: Dictionary, status_id: String, amount: int) -> void:
	target.status_effects[status_id] = int(target.status_effects.get(status_id, 0)) + amount
