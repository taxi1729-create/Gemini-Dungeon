extends Node
class_name StatusController
## 状態異常の発動・付与・時間経過（データ形は StatusEffectList の説明を参照）


static func has(u: Dictionary, id: String) -> bool:
	return u.get("status_effects", {}).has(id)


static func val(u: Dictionary, id: String) -> int:
	var e = u.get("status_effects", {}).get(id)
	return int(e.val) if e is Dictionary else 0


## 表示用の数字
static func label(u: Dictionary, id: String) -> String:
	var e = u.get("status_effects", {}).get(id)
	if not (e is Dictionary):
		return ""
	match StatusEffectList.DATA.get(id, {}).get("label", "val"):
		"neg": return "-%d" % int(e.val)
		"turns": return "%dT" % int(e.turns) if int(e.turns) > 0 else str(e.val)
		"none": return ""
	return str(e.val)


## 付与。turns = -1 なら戦闘中ずっと。同じ状態は強さを足し、残りターンは長い方
static func apply_status(target: Dictionary, status_id: String, amount: int, turns: int = -1) -> void:
	var se: Dictionary = target.status_effects
	if status_id in ["fire", "poison"]:
		turns = maxi(turns, amount)  # 火傷・毒は強さ＝残りターン
	if se.has(status_id):
		var e: Dictionary = se[status_id]
		if status_id == "taunt":
			e["val"] = amount  # 挑発は最後に挑発したキャラ
		else:
			e["val"] = int(e.val) + amount
		e["turns"] = -1 if (turns < 0 or int(e.turns) < 0) else maxi(int(e.turns), turns)
	else:
		se[status_id] = {"val": amount, "turns": turns}


static func remove(u: Dictionary, id: String) -> void:
	u.status_effects.erase(id)


## ターン開始時（火傷・毒のダメージ、AP プラス）。ダメージはブロックを無視
static func trigger_start_of_turn(u: Dictionary) -> Array:
	var evs: Array = []
	for k in u.status_effects.keys():
		var e: Dictionary = u.status_effects[k]
		match k:
			"fire", "poison":
				var v := int(e.val)
				u["hp"] = maxi(0, int(u.hp) - v)
				evs.append({"target": u, "damage": v, "tick": k})
			"ap_plus":
				evs.append({"target": u, "ap": int(e.val), "ap_gain": int(e.val)})
			"ap_next":
				evs.append({"target": u, "ap": int(e.val), "ap_gain": int(e.val)})
	if u.status_effects.has("ap_next"):
		u.status_effects.erase("ap_next")
	return evs


## 持ち主のターン終了時：残りターンを 1 減らす（火傷・毒は強さも 1 減る）
static func end_of_turn(u: Dictionary) -> void:
	var remove_ids: Array = []
	for k in u.status_effects.keys():
		var e: Dictionary = u.status_effects[k]
		if int(e.turns) < 0:
			continue
		e["turns"] = int(e.turns) - 1
		if k in ["fire", "poison"]:
			e["val"] = int(e.turns)
		if int(e.turns) <= 0:
			remove_ids.append(k)
	for k in remove_ids:
		u.status_effects.erase(k)


## 以前のラウンド終了処理（今はターン終了で減らすので何もしない。呼び出し互換のため残す）
static func decrease_all_durations(_units: Array) -> void:
	pass
