extends Node
class_name StatusController
## 状態異常の発動・付与・時間経過（データ形は StatusEffectList の説明を参照）


## 次のターンに効く状態。表示では「予約」1 つ（アイコン st_reserve）にまとめる（中身はそのまま）
const RESERVE := ["ap_next", "focus", "declare", "reblock", "yoyaku"]


## 予約の中身（説明の文の配列）。無ければ空
static func reserve_lines(u: Dictionary) -> Array:
	var out: Array = []
	for id in RESERVE:
		if not has(u, id):
			continue
		var v := val(u, id)
		match id:
			"ap_next": out.append("[i:st_ap_next]次の自分のターン AP+%d" % v)
			"focus": out.append("[i:st_focus]精神統一：%s必殺技の AP-%d" % ["このターン " if u.status_effects.focus.get("active", false) else "次の自分のターン ", v])
			"declare": out.append("[i:st_declare]宣言：次の自分のターン開始時までに HP が減らなければ %dターン APプラス" % v)
			"reblock": out.append("[i:st_reblock]リブロック：次の自分のターン開始時にブロック+%d" % v)
			"yoyaku":
				# 予約の札：積んだ効果をそれぞれ説明する
				for p in u.status_effects.yoyaku.get("list", []):
					var pd: Dictionary = p
					out.append("[i:kw_yoyaku]次の自分のターン開始時に %s" % DeckController.effect_text(u, {"effects": pd.get("effects", [])}))
	return out


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
	if status_id in ["fire", "poison", "regen"]:
		turns = maxi(turns, amount)  # 火傷・毒・リジェネは強さ＝残りターン
	if status_id in ["stun", "hangeki", "yoyaku"]:
		turns = -1  # 次の自分のターン（開始時）に消えるので、ターン終了では減らさない
	if status_id == "stun":
		amount = 1  # スタンは重ねても 1 回休むだけ
		if se.has("stun"):
			return
	if se.has(status_id):
		var e: Dictionary = se[status_id]
		if status_id == "focus" and e.get("active", false):
			# 精神統一が効いているターンに重ねた分は、次の自分のターンに効く
			e["pend"] = int(e.get("pend", 0)) + amount
			return
		if status_id == "taunt":
			e["val"] = amount  # 挑発は最後に挑発したキャラ
		else:
			e["val"] = int(e.val) + amount
		e["turns"] = -1 if (turns < 0 or int(e.turns) < 0) else maxi(int(e.turns), turns)
	else:
		se[status_id] = {"val": amount, "turns": turns}


static func remove(u: Dictionary, id: String) -> void:
	u.status_effects.erase(id)


## 精神統一：このターン必殺技の AP をいくつ減らすか（付けたターンには効かない）
static func focus_cut(u: Dictionary) -> int:
	var e = u.get("status_effects", {}).get("focus")
	if e is Dictionary and e.get("active", false):
		return int(e.val)
	return 0


## ターン開始時（宣言の判定、火傷・毒のダメージ、AP プラス、リブロック、精神統一）。ダメージはブロックを無視
## 呼ぶ前にブロックを 0 に戻しておくこと（リブロックはその後に足す）
static func trigger_start_of_turn(u: Dictionary) -> Array:
	var evs: Array = []
	var se: Dictionary = u.status_effects
	# 宣言：火傷・毒より前に判定する。成否どちらでも消える
	if se.has("declare"):
		var d: Dictionary = se.declare
		var ok: bool = int(u.hp) >= int(d.get("hp", u.hp))
		se.erase("declare")
		if ok:
			apply_status(u, "ap_plus", 1, int(d.val))  # このターンから val ターン、AP+1
		evs.append({"target": u, "declare": ok})
	for k in se.keys():
		var e: Dictionary = se[k]
		match k:
			"fire", "poison":
				var v := int(e.val)
				var before := int(u.hp)
				u["hp"] = maxi(0, before - v)
				# lost / overkill は戦闘の集計用
				evs.append({"target": u, "damage": v, "tick": k, "lost": before - int(u.hp),
						"overkill": maxi(0, v - before) if int(u.hp) <= 0 else 0})
			"regen":
				# リジェネ：残りターン分 HP 回復（最大 HP を超えてよい）。回復不可の間は回復しない
				if se.has("no_heal"):
					evs.append({"target": u, "heal": 0, "no_heal": true, "tick": k})
					continue
				var rv := int(e.val)
				u["hp"] = int(u.hp) + rv
				evs.append({"target": u, "heal": rv, "tick": k})
			"ap_plus":
				evs.append({"target": u, "ap": int(e.val), "ap_gain": int(e.val)})
			"ap_next":
				evs.append({"target": u, "ap": int(e.val), "ap_gain": int(e.val)})
			"reblock":
				var v := int(e.val)
				u["shield"] = int(u.get("shield", 0)) + v
				evs.append({"target": u, "shield": v, "reblock": true})
			"focus":
				e["active"] = true
				evs.append({"target": u, "focus": int(e.val)})
			"yoyaku":
				# 予約の札：中身（[{"target", "effects"}]）を Cont_Battle が発動する
				evs.append({"target": u, "yoyaku": (e.get("list", []) as Array).duplicate(true)})
	if se.has("ap_next"):
		se.erase("ap_next")
	if se.has("reblock"):
		se.erase("reblock")
	se.erase("yoyaku")
	se.erase("hangeki")  # 反撃は次の自分のターン開始まで
	return evs


## 持ち主のターン終了時：残りターンを 1 減らす（火傷・毒は強さも 1 減る）
static func end_of_turn(u: Dictionary) -> void:
	var remove_ids: Array = []
	# 精神統一：効いたターンの終わりで消える（そのターン中に重ねた分は次のターンへ）
	var f = u.status_effects.get("focus")
	if f is Dictionary and f.get("active", false):
		if int(f.get("pend", 0)) > 0:
			f["val"] = int(f.pend)
			f["pend"] = 0
			f["active"] = false
		else:
			u.status_effects.erase("focus")
	for k in u.status_effects.keys():
		var e: Dictionary = u.status_effects[k]
		if int(e.turns) < 0:
			continue
		e["turns"] = int(e.turns) - 1
		if k in ["fire", "poison", "regen"]:
			e["val"] = int(e.turns)
		if int(e.turns) <= 0:
			remove_ids.append(k)
	for k in remove_ids:
		u.status_effects.erase(k)


## 以前のラウンド終了処理（今はターン終了で減らすので何もしない。呼び出し互換のため残す）
static func decrease_all_durations(_units: Array) -> void:
	pass
