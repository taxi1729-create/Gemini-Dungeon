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
##   {"target", "damage", "blocked", "hit_no"(何回目のヒットか 0〜), "kill"(このヒットで倒したか)} / {"target", "shield"} / {"target", "status", "status_val"} / {"target", "heal"} / {"target", "ap"}
##   {"target", "charge"} / {"target"(攻撃した側), "status": "fire", "reflect": true}
##   {"target": 使用者, "special": "draw" / "swap" / "double" / "turnabout" / "extra_turn", "val": n} … 表示側（Cont_Battle）が処理する


static func get_atk(u: Dictionary) -> int:
	return int(u.get("atk", 0)) + StatusController.val(u, "atk_buff") - StatusController.val(u, "atk_down") + int(u.get("power_atk", 0)) + formation_atk(u)


static func get_def(u: Dictionary) -> int:
	return int(u.get("def", 0)) + StatusController.val(u, "def_buff") - StatusController.val(u, "def_down") + int(u.get("power_def", 0)) + formation_def(u)


## 陣形効果（味方だけ）：前衛（rank 0）は攻撃力+2、後衛（rank 1）は防御力+2
const FORMATION_BONUS := 2


static func formation_atk(u: Dictionary) -> int:
	if u.get("side", "") == "ally" and u.has("rank") and int(u.rank) == 0:
		return FORMATION_BONUS
	return 0


static func formation_def(u: Dictionary) -> int:
	if u.get("side", "") == "ally" and u.has("rank") and int(u.rank) == 1:
		return FORMATION_BONUS
	return 0


static func get_spd(u: Dictionary) -> int:
	return int(u.get("spd", 0)) + StatusController.val(u, "spd_buff")


static func calc_damage(user: Dictionary, action: Dictionary, target: Dictionary) -> int:
	if action.get("fixed", false):
		return int(action.get("power", 0))
	return maxi(0, int(action.get("power", 0)) + get_atk(user) + relic_atk(user) - get_def(target))


## レリック「紅の剣章」：右（赤）に立つ味方は攻撃力+1（get_atk とは別に、ダメージ計算と表示で足す）
static func relic_atk(u: Dictionary) -> int:
	if str(u.get("side", "")) == "ally" and int(u.get("lane", 0)) == 1 and Inventory.has_relic("red_crest"):
		return 1
	return 0


# ============================================================
# カードを使う時の強化（キーワード・バッジ・レリック）
# ============================================================

## キーワードの条件を満たしているか。ctx = {"swapped": このラウンドに味方の誰かが入替をしたか, "alone": 手札・保留枠に他のカードが無いか}
## 陣形（jinkei）は左右どちらかの効果が必ず出るので常に true
static func keyword_on(user: Dictionary, kw: String, ctx: Dictionary) -> bool:
	match kw:
		"sokuou": return bool(ctx.get("swapped", false))
		"saigo": return bool(ctx.get("alone", false))
		"jinkei": return true
		"tenshin":
			var lane := int(user.get("lane", 0))
			var rank := int(user.get("rank", 0))
			return lane != int(user.get("start_lane", lane)) or rank != int(user.get("start_rank", rank))
	return false


## 今の条件で足される bonus（{"power", "effects"}）の配列
static func active_bonuses(user: Dictionary, card: Dictionary, ctx: Dictionary) -> Array:
	var out: Array = []
	for kw in card.get("keywords", []):
		var k := str(kw)
		if k == "jinkei":
			var b = card.get("bonus_left" if int(user.get("lane", 0)) == 0 else "bonus_right")
			if b is Dictionary:
				out.append(b)
		elif k in ["sokuou", "saigo", "tenshin"] and keyword_on(user, k, ctx):
			var b2 = card.get("bonus")
			if b2 is Dictionary:
				out.append(b2)
	return out


## 実際に発動する行動（カードのコピー）。キーワードの追加効果・バッジ・レリック（砥石・十連の数珠）を足す
## ctx の "whet" = 砥石が効く、"rosary" = 数珠が効く（Cont_Battle が決める）
static func play_action(user: Dictionary, card: Dictionary, ctx: Dictionary = {}) -> Dictionary:
	var a: Dictionary = card.duplicate(true)
	var effs: Array = ActionList.effects_of(card).duplicate(true)
	var is_atk: bool = card.has("power")
	var add := 0
	for b in active_bonuses(user, card, ctx):
		add += int(b.get("power", 0))
		for e in b.get("effects", []):
			effs.append((e as Dictionary).duplicate(true))
	var rank := int(user.get("rank", 0))
	match str(card.get("badge", "")):
		"sharp":
			if is_atk:
				add += 3
		"front":
			if is_atk and rank == 0:
				add += 5
		"fire":
			if is_atk:
				effs.append({"effect": "add_status", "status": "fire", "eff_val": 2})
		"guard":
			effs.append({"effect": "add_shield", "eff_val": 4, "to": "self"})
		"back":
			if rank == 1:
				effs.append({"effect": "add_shield", "eff_val": 6, "to": "self"})
		"aid":
			effs.append({"effect": "add_shield", "eff_val": 3, "to": "other_ally"})
		"draw":
			effs.append({"effect": "draw", "eff_val": 1, "to": "self"})
	if ctx.get("whet", false) and is_atk:
		add += 4
	if ctx.get("rosary", false):
		if is_atk:
			add += 10
		else:
			effs.append({"effect": "add_shield", "eff_val": 10, "to": "self"})
	if is_atk and add != 0:
		a["power"] = int(card.power) + add
	a["effects"] = effs
	a.erase("effect")
	return a


## カードに表示する「実際のダメージ」（主な対象＝最初の対象に対して）。対象がいなければ攻撃力だけ反映
static func effective_power(user: Dictionary, action: Dictionary, allies: Array, enemies: Array) -> int:
	if not action.has("power"):
		return 0
	var t := resolve_targets(user, action.get("target", "self"), allies, enemies)
	if t.is_empty():
		return maxi(0, int(action.power) + get_atk(user) + relic_atk(user))
	return calc_damage(user, action, t[0])


## 多段攻撃の回数（hits_x なら X 回）
static func hit_count(action: Dictionary, x: int = 1) -> int:
	if action.get("hits_x", false):
		return maxi(0, x)
	return maxi(1, int(action.get("hits", 1)))


## 予想：[{target, damage(ブロック後・全ヒットの合計), kill}]。x は APX の X
static func preview(user: Dictionary, action: Dictionary, allies: Array, enemies: Array, x: int = 1) -> Array:
	var out: Array = []
	var n := hit_count(action, x)
	for t in resolve_targets(user, action.get("target", "self"), allies, enemies):
		var ev := {"target": t}
		if action.has("power"):
			var dmg := calc_damage(user, action, t)
			# 1 回ごとにブロックが削れていく
			var sh := int(t.get("shield", 0))
			var total := 0
			for i in n:
				var b := mini(sh, dmg)
				sh -= b
				total += dmg - b
			ev["damage"] = total
			ev["kill"] = total >= int(t.hp)
		out.append(ev)
	return out


## x は APX の X（hits_x の回数と、効果の "x": true の倍率に使う）
static func execute_action(user: Dictionary, action: Dictionary, allies: Array, enemies: Array, x: int = 1) -> Array:
	var events: Array = []
	var targets := resolve_targets(user, action.get("target", "self"), allies, enemies)
	var is_ally: bool = user.get("side", "ally") == "ally"
	var friends := (allies if is_ally else enemies).filter(func(e): return e.hp > 0)
	# ダメージ（hits 回。1 回ごとに攻撃力・防御力・ブロックを計算）
	var kills := 0
	if action.has("power"):
		for h in hit_count(action, x):
			for t in targets:
				if t.hp <= 0 or user.hp <= 0:
					continue
				var dmg := calc_damage(user, action, t)
				var blocked := mini(int(t.get("shield", 0)), dmg)
				t["shield"] = int(t.get("shield", 0)) - blocked
				dmg -= blocked
				var before := int(t.hp)
				t["hp"] = maxi(0, before - dmg)
				var killed: bool = int(t.hp) <= 0
				if killed:
					kills += 1
				# lost = 実際に減った HP、overkill = 倒した時の余り（戦闘の集計に使う）
				events.append({"target": t, "damage": dmg, "blocked": blocked, "hit_no": h, "kill": killed,
						"lost": before - int(t.hp), "overkill": maxi(0, dmg - before) if killed else 0})
				# ファイアガード：攻撃してきた相手に火傷
				if StatusController.has(t, "fire_guard") and user.hp > 0 and user != t:
					var v := StatusController.val(t, "fire_guard")
					StatusController.apply_status(user, "fire", v, v)
					events.append({"target": user, "status": "fire", "status_val": v, "reflect": true, "hit_no": h})
	# 倒した数に応じて AP（kill_ap）
	if kills > 0 and int(action.get("kill_ap", 0)) > 0 and user.hp > 0:
		var gain := kills * int(action.kill_ap)
		user["ap"] = mini(int(user.get("max_ap", 10)), int(user.get("ap", 0)) + gain)
		events.append({"target": user, "ap": gain})
	# 効果
	for eff in ActionList.effects_of(action):
		var to: String = eff.get("to", "target")
		var recips: Array = targets
		if to == "self":
			recips = [user]
		elif to == "ally_all":
			recips = friends
		elif to == "other_ally":
			recips = friends.filter(func(f): return f != user)
		var kind: String = eff.get("effect", "")
		if kind in ["draw", "swap", "double", "turnabout", "extra_turn"]:
			events.append({"target": user, "special": kind, "val": int(eff.get("eff_val", 0))})
			continue
		if kind == "absorb_block":
			# 対象の敵のブロックの合計を自分のブロックに足す（敵のブロックはそのまま）
			var total := 0
			for t in recips:
				if t.hp > 0:
					total += int(t.get("shield", 0))
			user["shield"] = int(user.get("shield", 0)) + total
			events.append({"target": user, "shield": total})
			continue
		for t in recips:
			if t.hp <= 0:
				continue
			var ev := {"target": t}
			_apply_effect(user, t, eff, ev, x)
			events.append(ev)
	return events


static func _apply_effect(user: Dictionary, t: Dictionary, eff: Dictionary, ev: Dictionary, x: int = 1) -> void:
	var v := int(eff.get("eff_val", 0))
	if eff.get("x", false):
		v *= x
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
			if sid == "declare" and not t.status_effects.declare.has("hp"):
				t.status_effects.declare["hp"] = int(t.hp)  # 宣言：この HP から減らなければ成功
			ev["status"] = sid
			ev["status_val"] = v if sid != "taunt" else 1
		"heal":
			var before := int(t.hp)
			t["hp"] = mini(int(t.max_hp), before + v)
			ev["heal"] = int(t.hp) - before
			# 宣言中に回復したら、判定の基準も上げる（回復分で減った HP を隠さない）
			if StatusController.has(t, "declare") and t.status_effects.declare.has("hp"):
				t.status_effects.declare["hp"] = int(t.status_effects.declare.hp) + int(ev.heal)
		"heal_pct":
			# 最大 HP の v% 回復（上限は最大 HP）
			var before2 := int(t.hp)
			var amount := int(ceil(int(t.max_hp) * v / 100.0))
			t["hp"] = maxi(before2, mini(int(t.max_hp), before2 + amount))
			ev["heal"] = int(t.hp) - before2
			if StatusController.has(t, "declare") and t.status_effects.declare.has("hp"):
				t.status_effects.declare["hp"] = int(t.status_effects.declare.hp) + int(ev.heal)
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
		"other_ally":
			return friends.filter(func(f): return f != user)
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
			# 味方の単体攻撃：目の前の前衛で HP が一番低い敵（同じなら近い方）。全滅なら front_group の代わりの順
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
			# 前衛全体（A-2・A-3・B-3・B-2）。全滅なら後衛
			var fr := _in_slots(foes, FRONT_SLOTS)
			if fr.is_empty():
				fr = _in_slots(foes, BACK_SLOTS)
			return fr if not fr.is_empty() else foes
		"back_row":
			# 後衛全体（A-1・B-1・C）。全滅なら前衛全体
			var br := _in_slots(foes, BACK_SLOTS)
			if br.is_empty():
				br = _in_slots(foes, FRONT_SLOTS)
			return br if not br.is_empty() else foes
		"random_enemy":
			# ランダムな敵 1 体。user.rand_seq（Cont_Battle が行動のたびに引き直す）で決めるので、プレビューと実行で同じ敵になる
			if foes.is_empty():
				return []
			return [foes[posmod(hash(int(user.get("rand_seq", 0))), foes.size())]]
	return []


## 敵の位置名（battle-spec.md「配置」）。A＝左（青の味方の目の前）、B＝右（赤）、C＝中央の奥（強敵・ボス）
const FRONT_SLOTS := ["A-2", "A-3", "B-3", "B-2"]
const BACK_SLOTS := ["A-1", "B-1", "C"]
## 目の前の敵：lane ごとに [目の前の前衛, 同じ側の後衛, C] の順に、生きている敵がいる最初の組
const FRONT_CHAIN := [[["A-2", "A-3"], ["A-1"], ["C"]], [["B-3", "B-2"], ["B-1"], ["C"]]]


## 目の前の敵グループ（front_enemy_group）：目の前の前衛（青なら A-2・A-3、赤なら B-3・B-2）。
## 全滅していれば 同じ側の後衛（A-1／B-1）→ C → 全員 の順に代わる
static func front_group(user: Dictionary, foes: Array) -> Array:
	var lane := clampi(int(user.get("lane", 0)), 0, 1)
	for slots in FRONT_CHAIN[lane]:
		var g := _in_slots(foes, slots)
		if not g.is_empty():
			return g
	return foes


## 位置名が slots に入る敵（位置名が無い古いデータは画面の位置と row から推定）
static func _in_slots(foes: Array, slots: Array) -> Array:
	return foes.filter(func(e): return slots.has(slot_of(e)))


static func slot_of(e: Dictionary) -> String:
	if e.has("slot"):
		return str(e.slot)
	var x := Vector2(e.get("pos", Vector2.ZERO)).x
	if int(e.get("row", 0)) == 0:
		return "A-3" if x < 360.0 else "B-3"
	if absf(x - 360.0) < 1.0:
		return "C"
	return "A-1" if x < 360.0 else "B-1"


static func is_left(u: Dictionary) -> bool:
	return Vector2(u.get("pos", Vector2.ZERO)).x < 360.0
