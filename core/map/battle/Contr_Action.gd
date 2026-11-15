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
##   {"target": 使用者, "special": "draw" / "swap" / "double" / "extra_turn", "val": n} … 表示側（Cont_Battle）が処理する
##   {"target", "gauge": n} … 必殺技ゲージが n 増えた（add_gauge）


## ダメージへの固定の加算。12 回目：味方の「攻撃力」はすべて POW に統一したので、味方は常に 0（get_pow に入る）。
## 敵には POW が無いので、敵の atk（階での増加）と、敵に付いた POW の増減（pow_up / pow_down / add_stat の pow）がここでダメージに足される
static func get_atk(u: Dictionary) -> int:
	if str(u.get("side", "")) == "ally":
		return 0
	return int(u.get("atk", 0)) + stat_delta(u, "pow")


## DEF（受けるダメージから引く。負なら増える）＝基礎＋増減
static func get_def(u: Dictionary) -> int:
	return stat_base(u, "def") + stat_delta(u, "def")


# ------------------------------------------------------------
# 12 回目：ステータス増減（POW・SLD・DEF）
#   戦闘終了まで：効果 {"effect": "add_stat", "stat": "pow" | "sld" | "def", "eff_val": n, "to": …}（負で下げる）→ u.stat_add = {"pow": n, …}
#   ターン限定  ：状態 pow_up / pow_down・sld_up / sld_down・def_up / def_down（StatusEffectList）
#   味方の旧「攻撃力」の加算（陣形の前衛 +2・パワー・レリック紅の剣章・料理・イベント）も POW の増減に入れる
#   表示は「POW20+3」＝ stat_base ＋ stat_delta
# ------------------------------------------------------------
const STATS := ["pow", "sld", "def"]
const STAT_NAME := {"pow": "POW", "sld": "SLD", "def": "DEF"}


## 基礎の値。味方の POW は、冒険の間ずっと続く加算（イベント「赤の光」などの u.atk）を含む
static func stat_base(u: Dictionary, stat: String) -> int:
	var v := int(u.get(stat, 0))
	if stat == "pow" and str(u.get("side", "")) == "ally":
		v += int(u.get("atk", 0))
	return v


## 戦闘中の増減の合計（add_stat ＋ 状態 ＋ 陣形・パワー・レリックなど）
static func stat_delta(u: Dictionary, stat: String) -> int:
	var sa = u.get("stat_add")
	var add := int((sa as Dictionary).get(stat, 0)) if sa is Dictionary else 0
	add += StatusController.val(u, stat + "_up") - StatusController.val(u, stat + "_down")
	var ally: bool = str(u.get("side", "")) == "ally"
	match stat:
		"pow":
			if ally:
				add += int(u.get("power_atk", 0)) + formation_atk(u) + power_dyn(u, "atk") + relic_atk(u)
		"def":
			add += int(u.get("power_def", 0)) + formation_def(u) + aid_def(u) + power_dyn(u, "def")
		"sld":
			if ally:
				add += int(u.get("power_sld", 0)) + _aid_sum(u, "aid_sld")
	return add


## u のステータス stat を n 増減する（戦闘終了まで。負で下げる。何回でも積み重なる）
static func add_stat(u: Dictionary, stat: String, n: int) -> void:
	if not STATS.has(stat) or n == 0:
		return
	var sa = u.get("stat_add")
	var d: Dictionary = sa if sa is Dictionary else {}
	d[stat] = int(d.get(stat, 0)) + n
	u["stat_add"] = d


## 「POW20+3」の形（増減が 0 なら「POW20」）
static func stat_text(u: Dictionary, stat: String) -> String:
	var d := stat_delta(u, stat)
	return "%s%d%s" % [str(STAT_NAME.get(stat, stat)), stat_base(u, stat), ("%+d" % d) if d != 0 else ""]


static func _aid_sum(u: Dictionary, key: String) -> int:
	var add := 0
	var aid = u.get(key)
	if aid is Dictionary:
		for k in aid:
			add += int(aid[k])
	return add


# ------------------------------------------------------------
# 12 回目：庇う（状態 cover。城壁・聖域）
#   庇うが付いた味方が、もう 1 人の味方への敵の攻撃（単体・全体のその人の分）を代わりに受ける。
#   敵の「攻撃」（power のある行動）だけ。状態異常だけの行動（火炎の爪など）は付け替えない
# ------------------------------------------------------------

## t への敵の攻撃を受ける味方（庇う味方がいればその人。t 自身に庇うが付いていれば t のまま）
static func cover_of(t: Dictionary, allies: Array) -> Dictionary:
	if str(t.get("side", "")) != "ally" or StatusController.has(t, "cover"):
		return t
	for a in allies:
		if a != t and int(a.hp) > 0 and str(a.get("side", "")) == "ally" and StatusController.has(a, "cover"):
			return a
	return t


## 敵 user の行動 action が実際に当たる相手（resolve_targets ＋ 庇うの付け替え）。全体攻撃を庇うと同じ味方が 2 回入る
static func attack_targets(user: Dictionary, action: Dictionary, allies: Array, enemies: Array) -> Array:
	var tg := resolve_targets(user, str(action.get("target", "self")), allies, enemies)
	if str(user.get("side", "ally")) == "ally" or not action.has("power"):
		return tg
	var out: Array = []
	for t in tg:
		out.append(cover_of(t, allies))
	return out


# ------------------------------------------------------------
# 必殺技のゲージ（10 回目）：味方の辞書 u.sp_gauge（0〜GAUGE_MAX）。満タンで必殺技が使え、使うと 0 に戻る。
#   ウィッチ＝与えたダメージ（HP とブロックへの合計）、ナイト＝得たブロックで貯まる（Cont_Battle が数える）。
#   カードの効果で増やす時は {"effect": "add_gauge", "eff_val": n, "to": "self"}（イベント {"target", "gauge": 増えた量}）
# ------------------------------------------------------------
const GAUGE_MAX := 50  # 普通の上限。12 回目：上限は必殺技ごと（虚空連斬だけ 150）＝ gauge_max(u)


## 12 回目：u が選んでいる必殺技のゲージの上限（Cont_Battle が u.sp_gauge_max に入れる。無ければ 50）
static func gauge_max(u: Dictionary) -> int:
	return maxi(1, int(u.get("sp_gauge_max", GAUGE_MAX)))


## 必殺技のデータ sp の上限（"gauge_max" が無ければ 50）
static func special_gauge_max(sp: Dictionary) -> int:
	return maxi(1, int(sp.get("gauge_max", GAUGE_MAX)))


## u の必殺技ゲージを n 増やす（味方だけ。上限 gauge_max(u) で頭打ち）。実際に増えた量を返す
static func add_gauge(u: Dictionary, n: int) -> int:
	if str(u.get("side", "")) != "ally" or n <= 0:
		return 0
	var mx := gauge_max(u)
	var before := clampi(int(u.get("sp_gauge", 0)), 0, mx)
	u["sp_gauge"] = mini(mx, before + n)
	return int(u.sp_gauge) - before


## 必殺技ゲージが満タンか
static func gauge_full(u: Dictionary) -> bool:
	return int(u.get("sp_gauge", 0)) >= gauge_max(u)


## もう 1 人の味方のパワーで上がった防御力（鋼鉄化：味方全体）。u.aid_def = {渡した味方の id: n}
static func aid_def(u: Dictionary) -> int:
	var add := 0
	var aid: Dictionary = u.get("aid_def", {})
	for k in aid:
		add += int(aid[k])
	return add


## デバフ（闘志・浄化で外す）：火傷・毒・攻撃力低下・防御力低下・回復不可・スタン
const DEBUFFS := ["fire", "poison", "pow_down", "sld_down", "def_down", "no_heal", "stun"]  # 12 回目：攻撃力低下 → POW ダウン、SLD ダウンを追加


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


## パワーで変わる攻撃力・防御力。u.powers = 使ったパワーの power_effect の配列（Cont_Battle が入れる。戦闘終了まで）
##   burn_atk  ：攻撃力 + 自分の火傷の残りターン
##   last_stand：HP の残り X% で 攻撃力・防御力 +Y（Y＝(100−X)/10 切り捨て。10 回目に素早さから防御力へ）
##   u.aid_atk = {渡した味方の id: n}（鼓舞の B：もう 1 人の攻撃力 +n）
static func power_dyn(u: Dictionary, stat: String) -> int:
	var add := 0
	for pe0 in u.get("powers", []):
		var pe := power_side(u, pe0)
		match str(pe.get("kind", "")):
			"burn_atk":
				if stat == "atk":
					var f = u.get("status_effects", {}).get("fire")
					if f is Dictionary:
						add += maxi(0, int(f.turns))
			"last_stand":
				add += last_stand_y(u)
	if stat == "atk":
		var aid: Dictionary = u.get("aid_atk", {})
		for k in aid:
			add += int(aid[k])
	return add


## 陣形のパワー（left / right）は、持ち主の今の位置（左＝lane 0）の側の power_effect。陣形でなければそのまま
static func power_side(u: Dictionary, pe) -> Dictionary:
	if not (pe is Dictionary):
		return {}
	var d: Dictionary = pe
	if d.has("left") or d.has("right"):
		return d.get("left" if int(u.get("lane", 0)) == 0 else "right", {})
	return d


## 背水の陣の Y（HP の残り X%＝切り捨て、Y＝(100−X)/10 切り捨て）
static func last_stand_y(u: Dictionary) -> int:
	var mx := maxi(1, int(u.get("max_hp", 1)))
	var pct := clampi(int(u.get("hp", 0)) * 100 / mx, 0, 100)
	return (100 - pct) / 10


static func calc_damage(user: Dictionary, action: Dictionary, target: Dictionary) -> int:
	if str(action.get("power_from", "")) == "poison":
		return StatusController.val(target, "poison")  # 腐食：毒の残り分の固定ダメージ
	if action.get("fixed", false):
		return int(action.get("power", 0))
	# 12 回目：味方の攻撃力の加算（レリック紅の剣章なども）は POW に入った（get_pow）。get_atk は敵のダメージの加算だけ
	return maxi(0, pow_part(user, action, target) + int(action.get("power", 0)) + vs_status_add(action, target) + get_atk(user) - get_def(target))


# ------------------------------------------------------------
# 11 回目：POW（攻撃力の基礎）・SLD（ブロック量の基礎）
#   カードの攻撃 ＝ "pow_pct"（POW の %）。ダメージ＝POW × % ÷ 100（切り捨て、最低 1）＋ "power"（固定の上乗せ）＋攻撃力 − 防御力
#     キーワードの追加効果・炎刃（if_self_status）・侵食の針（vs_status）の "pow_pct" は % に足してから切り捨てる
#     "power" は固定の上乗せ（バッジ・砥石・数珠・詠唱の構え・盾打ち・怒涛の締めなど）。敵の行動・アイテム・パワーは "power" だけ
#   カードのブロック ＝ 効果 add_shield の "sld_pct"（使った人の SLD の %。切り捨て）＋ "eff_val"（固定）
#     味方全体・もう 1 人の味方に与えるブロックも、使った人（user）の SLD で計算する
# ------------------------------------------------------------
## 12 回目：基礎 ＋ 増減（stat_base ＋ stat_delta）。0 未満にはならない
static func get_pow(u: Dictionary) -> int:
	return maxi(0, stat_base(u, "pow") + stat_delta(u, "pow"))


static func get_sld(u: Dictionary) -> int:
	return maxi(0, stat_base(u, "sld") + stat_delta(u, "sld"))


## POW × % の部分（% が無い行動は 0）。target を渡すと侵食の針（vs_status の pow_pct）も足す
static func pow_part(user: Dictionary, action: Dictionary, target: Dictionary = {}) -> int:
	var pct := int(action.get("pow_pct", 0))
	var vs = action.get("vs_status")
	if not target.is_empty() and vs is Dictionary and StatusController.has(target, str(vs.get("status", ""))):
		pct += int(vs.get("pow_pct", 0))
	if pct <= 0:
		return 0
	return maxi(1, get_pow(user) * pct / 100)


## 効果 1 つの SLD × % の部分（sld_pct が無ければ 0）
static func sld_part(user: Dictionary, eff: Dictionary) -> int:
	var pct := int(eff.get("sld_pct", 0))
	if pct <= 0:
		return 0
	return get_sld(user) * pct / 100


## 効果 1 つのブロック量（X 倍の前。add_shield の sld_pct＋eff_val）
static func shield_amount(user: Dictionary, eff: Dictionary) -> int:
	return int(eff.get("eff_val", 0)) + sld_part(user, eff)


## 攻撃力・防御力を見ない「基本のダメージ」（POW × % ＋固定の上乗せ）。カードの左上の色分けの基準
static func base_power(user: Dictionary, action: Dictionary) -> int:
	return pow_part(user, action) + int(action.get("power", 0))


## 行動の「すぐ出るブロック」の合計（effects の add_shield。to が自分・味方全体・もう 1 人でも 1 人分の量）。X の倍率は x
static func shield_total(user: Dictionary, action: Dictionary, x: int = 1) -> int:
	var total := 0
	for e in ActionList.effects_of(action):
		var ed: Dictionary = e
		if str(ed.get("effect", "")) == "add_shield":
			total += shield_amount(user, ed) * (x if ed.get("x", false) else 1)
	return total


## カードの持ち主（戦闘外の表示用）：今の冒険の味方（いなければ初期ステータス）
static func owner_unit(card: Dictionary) -> Dictionary:
	var ow := str(card.get("owner", ""))
	for a in CurrentStatus.allies:
		if str((a as Dictionary).get("id", "")) == ow:
			return a
	return InitAllyStatus.get_status(ow) if InitAllyStatus.DATA.has(ow) else {}


## D（10 回目・侵食の針）：その状態が付いた敵へのダメージの固定の上乗せ（11 回目からは vs_status の pow_pct を pow_part で足す）
static func vs_status_add(action: Dictionary, target: Dictionary) -> int:
	var vs = action.get("vs_status")
	if vs is Dictionary and StatusController.has(target, str(vs.get("status", ""))):
		return int(vs.get("power", 0))
	return 0


## レリック「紅の剣章」：右（赤）に立つ味方は攻撃力+1（get_atk とは別に、ダメージ計算と表示で足す）
static func relic_atk(u: Dictionary) -> int:
	var add := 0
	if str(u.get("side", "")) == "ally" and int(u.get("lane", 0)) == 1 and Inventory.has_relic("red_crest"):
		add += 1
	# D（10 回目）：イベント「双子の肖像画」の赤い絵（この階の間、右のキャラの攻撃力+1）
	if str(u.get("side", "")) == "ally" and int(u.get("lane", 0)) == 1:
		add += CurrentStatus.floor_fx_val("right_atk")
	# D（10 回目）：イベント「石像の問い」の剣（この階の間、ナイトの攻撃力+1）
	if str(u.get("side", "")) == "ally" and str(u.get("id", "")) == "knight":
		add += CurrentStatus.floor_fx_val("knight_atk")
	return add


# ============================================================
# カードを使う時の強化（キーワード・バッジ・レリック）
# ============================================================

## キーワードの条件を満たしているか。ctx = {"swapped": このラウンドに味方の誰かが入替をしたか, "alone": 手札（空き欄を含む 6 欄）に他のカードが無いか}
## 陣形（jinkei）は左右どちらかの効果が必ず出るので常に true
static func keyword_on(user: Dictionary, kw: String, ctx: Dictionary) -> bool:
	match kw:
		"sokuou": return bool(ctx.get("swapped", false)) or CurrentStatus.sokuou_always()  # D：聖歌の楽譜（次の戦闘の間、即応が常に成立）
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
			var b2 = card.get("bonus_" + k, card.get("bonus"))  # 札ごとの追加効果（渾身の一撃は転身と即応の両方）
			if b2 is Dictionary:
				out.append(b2)
	return out


# ------------------------------------------------------------
# 撃破・反撃・予約の札（後で効く追加効果）
#   カードに keywords: ["gekiha"] などと、追加効果 "bonus_gekiha" / "bonus_hangeki" / "bonus_yoyaku" = {"effects": [...]} を書く
#   （bonus_○○ が無く、即応・最後・転身の札も無いカードは "bonus" を使う）。効果の形は普通の effects と同じ。
#   撃破 gekiha ：この攻撃で敵を 1 体以上倒したら、effects を発動（1 回の発動につき 1 回。"to" は普通の効果と同じ。
#                対象 "target" はこのカードの対象のうち生きている敵）。execute_action が {"target": 使用者, "gekiha": 倒した数} を出す
#   反撃 hangeki：使うと自分に状態 hangeki（次の自分のターン開始時に消える）。その間に自分を攻撃してきた敵それぞれに
#                effects を 1 回の攻撃につき 1 回発動（効果の対象は攻撃してきた敵。"to" は見ない）。{"target": 敵, "hangeki": true} を出す
#   予約 yoyaku ：使うと自分に状態 yoyaku。次の自分のターン開始時（ブロックが 0 に戻った後）に effects を発動
#                （対象は bonus_yoyaku.target、無ければカードの対象で、その時に決め直す）。表示は「予約」にまとまる
#   倒したらもう一度（on_kill）・倒すと AP（kill_ap）・ファイアガードは今の仕組みのまま、札（gekiha / hangeki）だけ付ける
# ------------------------------------------------------------
const KW_TIMED := ["gekiha", "hangeki", "yoyaku"]


## 札 k（gekiha / hangeki / yoyaku）の追加効果 {"effects": [...], "target"?}。無ければ {}
static func timed_bonus(card: Dictionary, k: String) -> Dictionary:
	var b = card.get("bonus_" + k)
	if b is Dictionary:
		return b
	var kws: Array = card.get("keywords", [])
	if not (kws.has("sokuou") or kws.has("saigo") or kws.has("tenshin")):
		var b2 = card.get("bonus")
		if b2 is Dictionary:
			return b2
	return {}


## 撃破：倒した数 kills > 0 の時の追加効果のイベント（execute_action の中から呼ぶ）
static func _gekiha_events(user: Dictionary, action: Dictionary, kills: int, allies: Array, enemies: Array, x: int) -> Array:
	var out: Array = []
	if kills <= 0 or not ActionList.has_keyword(action, "gekiha"):
		return out
	out.append({"target": user, "gekiha": kills})
	var effs: Array = action.get("gekiha_effects", timed_bonus(action, "gekiha").get("effects", []))
	if not effs.is_empty() and user.hp > 0:
		out.append_array(execute_action(user, {"target": action.get("target", "self"), "effects": effs}, allies, enemies, x))
	return out


## 反撃：attacker が owner を攻撃した時（1 回の攻撃につき 1 回）。owner の状態 hangeki の効果を attacker に付ける
static func _hangeki_events(attacker: Dictionary, owner: Dictionary) -> Array:
	var out: Array = []
	var e = owner.get("status_effects", {}).get("hangeki")
	if not (e is Dictionary) or attacker == owner or int(attacker.hp) <= 0:
		return out
	if str(attacker.get("side", "")) == str(owner.get("side", "")):
		return out
	for eff in e.get("effects", []):
		var e2: Dictionary = (eff as Dictionary).duplicate(true)
		# 攻撃してきた敵は自分のターン中なので、期間つきの効果はそのターンの終わりで減らないよう 1 足す
		if int(e2.get("turns", -1)) > 0:
			e2["turns"] = int(e2.turns) + 1
		var ev := {"target": attacker, "hangeki": true}
		_apply_effect(owner, attacker, e2, ev)
		out.append(ev)
	return out


## D（12 回目）：期間つきで付けた時に「この後に動く味方」へは 1 ターン足す状態（敵の攻撃の時まで残したいステータス増減）
const ROUND_STATS := ["pow_up", "sld_up", "def_up"]


## D（12 回目）：味方 t が、味方 user より後にこのラウンドで動くか（行動順はウィッチ → ナイト。Cont_Battle.round_order）
static func acts_later(user: Dictionary, t: Dictionary) -> bool:
	if t == user or str(user.get("side", "")) != "ally" or str(t.get("side", "")) != "ally":
		return false
	return str(user.get("id", "")) == "witch" and str(t.get("id", "")) == "knight"


## 状態 hangeki / yoyaku に、効果（add_status の "payload"）を積む
static func _attach_payload(t: Dictionary, sid: String, payload: Dictionary) -> void:
	var e = t.status_effects.get(sid)
	if not (e is Dictionary):
		return
	match sid:
		"hangeki":
			var list: Array = e.get("effects", [])
			list.append_array((payload.get("effects", []) as Array).duplicate(true))
			e["effects"] = list
		"yoyaku":
			var list2: Array = e.get("list", [])
			list2.append(payload.duplicate(true))
			e["list"] = list2


## 実際に発動する行動（カードのコピー）。キーワードの追加効果・バッジ・レリック（砥石・十連の数珠）を足す
## ctx の "whet" = 砥石が効く、"rosary" = 数珠が効く（Cont_Battle が決める）
static func play_action(user: Dictionary, card: Dictionary, ctx: Dictionary = {}) -> Dictionary:
	var a: Dictionary = card.duplicate(true)
	var effs: Array = ActionList.effects_of(card).duplicate(true)
	var is_atk: bool = card.has("power")
	var add := 0  # 固定の上乗せ（power）
	var add_pct := 0  # POW の % の上乗せ（11 回目：キーワードの追加効果・炎刃・灰燼斬）
	for b in active_bonuses(user, card, ctx):
		add += int(b.get("power", 0))
		add_pct += int(b.get("pow_pct", 0))
		for e in b.get("effects", []):
			effs.append((e as Dictionary).duplicate(true))
		if b.has("target"):
			a["target"] = str(b.target)  # 星降り：陣形で対象が変わる
		if b.has("hits"):
			a["hits"] = int(b.hits)  # 終焉の光：陣形で回数が変わる
	# 二連詠唱：使う前の AP（ctx.ap_before。プレビューでは今の AP）が min 以上なら hits を増やす
	var aph = card.get("ap_hits")
	if aph is Dictionary and int(ctx.get("ap_before", user.get("ap", 0))) >= int(aph.get("min", 0)):
		a["hits"] = int(aph.get("hits", 1))
	# 怒涛の締め：power ＝ このターンにこのキャラが使ったカードの枚数（このカードは含まない）
	if card.get("power_used", false):
		a["power"] = int(user.get("cards_used", 0))
	# 怒涛の締め（9 回目）：hits ＝ このターンにこのキャラが使ったカードの枚数（このカードは含まない）
	if card.get("hits_used", false):
		a["hits"] = int(user.get("cards_used", 0))
	# 撃破・反撃・予約の札：使った時には効かず、後で効く効果として行動に持たせる（timed_bonus の説明を参照）
	for k in KW_TIMED:
		if not ActionList.has_keyword(card, k):
			continue
		var tb := timed_bonus(card, k)
		var teffs: Array = (tb.get("effects", []) as Array).duplicate(true)
		# D（12 回目・豪炎）：予約の追加効果が攻撃（bonus_yoyaku の pow_pct）だけのカードも予約を積む
		if teffs.is_empty() and not (k == "yoyaku" and int(tb.get("pow_pct", 0)) > 0):
			continue
		match k:
			"gekiha":
				a["gekiha_effects"] = (a.get("gekiha_effects", []) as Array) + teffs
			"hangeki":
				effs.append({"effect": "add_status", "status": "hangeki", "eff_val": 1, "to": "self", "payload": {"effects": teffs}})
			"yoyaku":
				var ypl := {"target": str(tb.get("target", card.get("target", "self"))), "effects": teffs}
				# D（12 回目・豪炎）：予約の攻撃。次の自分のターン開始時に POW × pow_pct を hits 回（hits_x なら使った時の X 回。_apply_effect が入れる）
				if int(tb.get("pow_pct", 0)) > 0:
					ypl["pow_pct"] = int(tb.pow_pct)
					ypl["hits"] = maxi(1, int(tb.get("hits", 1)))
					ypl["hits_x"] = bool(tb.get("hits_x", false))
				effs.append({"effect": "add_status", "status": "yoyaku", "eff_val": 1, "to": "self", "payload": ypl})
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
	# D（10 回目の新カード）：盾打ち・炎刃・灰燼斬・詠唱の構え
	if card.get("power_half_block", false):
		a["power"] = int(floor(int(user.get("shield", 0)) / 2.0))
	# A（12 回目のナイトのカード）：盾打ち・審判の大盾・剛腕・覇王の一撃・苦痛の糧・不死鳥の剣
	if card.get("power_block", false):
		a["power"] = int(user.get("shield", 0))  # 自分のブロックと同じダメージ（ブロックは減らない）
	var ipw = card.get("if_pow")
	if ipw is Dictionary and get_pow(user) >= int(ipw.get("min", 0)):
		add_pct += int(ipw.get("pow_pct", 0))
	if int(card.get("per_pow_up_pct", 0)) > 0:
		add_pct += int(card.per_pow_up_pct) * maxi(0, stat_delta(user, "pow"))
	var pss = card.get("per_self_status_pct")
	if pss is Dictionary:
		var ssum := 0
		for sid0 in pss.get("statuses", []):
			ssum += StatusController.val(user, str(sid0))
		add_pct += int(pss.get("pow_pct", 0)) * ssum
	if int(card.get("burn_all_pct", 0)) > 0:
		add_pct += int(card.burn_all_pct) * StatusController.val(user, "fire")
		a["burn_all_used"] = true  # execute_action で自分の火傷を全部消す
	var iss = card.get("if_self_status")
	if iss is Dictionary and StatusController.has(user, str(iss.get("status", ""))):
		add += int(iss.get("power", 0))
		add_pct += int(iss.get("pow_pct", 0))
	if int(card.get("per_exhaust", 0)) > 0:
		add += int(card.per_exhaust) * int(ctx.get("exhausted", 0))
	if int(card.get("per_exhaust_pct", 0)) > 0:
		add_pct += int(card.per_exhaust_pct) * int(ctx.get("exhausted", 0))
	if is_atk and StatusController.has(user, "chant"):
		add += StatusController.val(user, "chant")
		a["chant_used"] = true  # execute_action で状態 chant を外す
	if is_atk and add != 0:
		a["power"] = int(a.power) + add
	if is_atk and add_pct != 0:
		a["pow_pct"] = int(a.get("pow_pct", 0)) + add_pct
	a["effects"] = effs
	a.erase("effect")
	return a


## カードに表示する「実際のダメージ」（主な対象＝最初の対象に対して）。対象がいなければ攻撃力だけ反映
static func effective_power(user: Dictionary, action: Dictionary, allies: Array, enemies: Array) -> int:
	if not action.has("power"):
		return 0
	var rk := _pre_rank_begin(user, action)
	var t := resolve_targets(user, action.get("target", "self"), allies, enemies)
	var out := maxi(0, base_power(user, action) + get_atk(user)) if t.is_empty() else calc_damage(user, action, t[0])
	_pre_rank_end(user, rk)
	return out


## 魔弾（pre_rank）：予想の間だけ移動先の段で計算する。元の段を返す（-1 = 変えていない）
static func _pre_rank_begin(user: Dictionary, action: Dictionary) -> int:
	if not action.has("pre_rank") or str(user.get("side", "")) != "ally" or not user.has("rank"):
		return -1
	var old := int(user.rank)
	user["rank"] = int(action.pre_rank)
	return old


static func _pre_rank_end(user: Dictionary, old: int) -> void:
	if old >= 0:
		user["rank"] = old


## 多段攻撃の回数（hits_x なら X 回。hits_used なら play_action が入れた回数で、0 回もある）
static func hit_count(action: Dictionary, x: int = 1) -> int:
	if action.get("hits_x", false):
		return maxi(0, x)
	if action.get("hits_used", false):
		return maxi(0, int(action.get("hits", 0)))
	return maxi(1, int(action.get("hits", 1)))


## 予想：[{target, damage(ブロック後・全ヒットの合計), kill}]。x は APX の X
static func preview(user: Dictionary, action: Dictionary, allies: Array, enemies: Array, x: int = 1) -> Array:
	var out: Array = []
	var n := hit_count(action, x)
	if action.get("reroll", false):
		n = mini(n, 1)  # 1 ヒットごとに引き直す攻撃は、1 ヒット目の敵だけ予想する
	var rk := _pre_rank_begin(user, action)
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
	_pre_rank_end(user, rk)
	return out


## x は APX の X（hits_x の回数と、効果の "x": true の倍率に使う）
static func execute_action(user: Dictionary, action: Dictionary, allies: Array, enemies: Array, x: int = 1) -> Array:
	var events: Array = []
	# 魔弾：自分が前衛（pre_rank）に移動してから発動する（表示側は special "rank_to" で絵を動かす）
	if action.has("pre_rank") and str(user.get("side", "")) == "ally" and user.has("rank"):
		user["rank"] = int(action.pre_rank)
		events.append({"target": user, "special": "rank_to", "val": int(action.pre_rank)})
	# D（詠唱の構え）：上乗せを使ったアタックカードが発動したら状態 chant を外す
	if action.get("chant_used", false) and StatusController.has(user, "chant"):
		StatusController.remove(user, "chant")
	# A（不死鳥の剣）：自分の火傷を全部消す（消した分の % は play_action が足してある）
	if action.get("burn_all_used", false) and StatusController.has(user, "fire"):
		StatusController.remove(user, "fire")
		events.append({"target": user, "cleanse": ["fire"]})
	var targets := attack_targets(user, action, allies, enemies)  # 12 回目：敵の攻撃は庇う（cover）の味方へ付け替える
	var is_ally: bool = user.get("side", "ally") == "ally"
	var friends := (allies if is_ally else enemies).filter(func(e): return e.hp > 0)
	# ダメージ（hits 回。1 回ごとに攻撃力・防御力・ブロックを計算）
	var kills := 0
	var hit_owners: Array = []  # 攻撃した相手（反撃の判定用）
	var hit_effs: Array = action.get("hit_effects", [])
	var foes_all: Array = enemies if is_ally else allies
	if action.has("power") or not hit_effs.is_empty():
		for h in hit_count(action, x):
			var tg: Array = targets
			# 1 ヒットごとに引き直す（2 ヒット目から。1 ヒット目はプレビューと同じ敵）
			if action.get("reroll", false) and h > 0:
				var alive_foes: Array = foes_all.filter(func(e): return e.hp > 0)
				tg = [] if alive_foes.is_empty() else [alive_foes[randi() % alive_foes.size()]]
			for t in tg:
				if t.hp <= 0 or user.hp <= 0:
					continue
				# 毒針の嵐（power が無い）は効果だけ。腐食は毒の無い敵には当てない
				if not action.has("power") or (str(action.get("power_from", "")) == "poison" and StatusController.val(t, "poison") <= 0):
					if not action.has("power"):
						events.append_array(_hit_effect_events(user, t, hit_effs, h, 0, x))
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
					events.append({"target": user, "status": "fire", "status_val": v, "reflect": true, "hit_no": h, "hangeki": true})
				if not hit_owners.has(t):
					hit_owners.append(t)
				events.append_array(_hit_effect_events(user, t, hit_effs, h, dmg, x))
	# 反撃：攻撃された相手に状態 hangeki があれば、攻撃してきた側に追加効果（1 回の攻撃につき 1 回）
	for o in hit_owners:
		if StatusController.has(o, "hangeki"):
			events.append_array(_hangeki_events(user, o))
	# 撃破：1 体以上倒したら追加効果（1 回）
	events.append_array(_gekiha_events(user, action, kills, allies, enemies, x))
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
		elif to in ["left_ally", "right_ally"]:
			# D（双色の香）：左（lane 0）／右（lane 1）に立つ味方
			var want_lane := 0 if to == "left_ally" else 1
			recips = friends.filter(func(f): return int(f.get("lane", 0)) == want_lane)
		elif to in ["front_ally", "back_ally"]:
			# D（陣中の酒）：前衛（rank 0）／後衛（rank 1）の味方
			var want_rank := 0 if to == "front_ally" else 1
			recips = friends.filter(func(f): return int(f.get("rank", 0)) == want_rank)
		var kind: String = eff.get("effect", "")
		if kind == "rank_to":
			# 魔法準備：自分を指定の段へ（1＝後衛）。表示側は special "rank_to" で絵を動かす
			if str(user.get("side", "")) == "ally" and user.has("rank"):
				user["rank"] = int(eff.get("eff_val", 1))
			events.append({"target": user, "special": "rank_to", "val": int(eff.get("eff_val", 1))})
			continue
		if kind == "cleanse":
			# 闘志：対象のデバフを外す
			for t in recips:
				if t.hp <= 0:
					continue
				var gone: Array = []
				for sid in DEBUFFS:
					if StatusController.has(t, sid):
						StatusController.remove(t, sid)
						gone.append(sid)
				events.append({"target": t, "cleanse": gone})
			continue
		if kind in ["draw", "swap", "double", "extra_turn", "rank_swap", "repeat"]:
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


## 1 ヒットごとの効果（hit_effects）のイベント。dealt = このヒットで実際に与えたダメージ（"if_damaged" の判定に使う）
static func _hit_effect_events(user: Dictionary, t: Dictionary, effs: Array, h: int, dealt: int, x: int) -> Array:
	var out: Array = []
	for he in effs:
		if (he as Dictionary).get("if_damaged", false) and dealt <= 0:
			continue
		if int(t.hp) <= 0:
			break
		var ev := {"target": t, "hit_no": h}
		_apply_effect(user, t, he, ev, x)
		out.append(ev)
	return out


static func _apply_effect(user: Dictionary, t: Dictionary, eff: Dictionary, ev: Dictionary, x: int = 1) -> void:
	var v := int(eff.get("eff_val", 0))
	if str(eff.get("effect", "")) == "add_shield":
		v = shield_amount(user, eff)  # 11 回目：使った人（user）の SLD × sld_pct ＋固定の eff_val
	if eff.get("x", false):
		v *= x
	match eff.get("effect", ""):
		"add_ap":
			t["ap"] = mini(int(t.get("max_ap", 10)), int(t.get("ap", 0)) + v)
			ev["ap"] = v
		"add_shield":
			t["shield"] = int(t.get("shield", 0)) + v
			ev["shield"] = v
		"add_gauge":
			# 必殺技ゲージ（10 回目。闘気溜め・精神統一など）
			ev["gauge"] = add_gauge(t, v)
		"add_stat":
			# 12 回目：ステータス増減（戦闘終了まで。負で下げる）。敵が対象なら pow は敵のダメージの増減になる（get_atk）
			var stt := str(eff.get("stat", "pow"))
			add_stat(t, stt, v)
			ev["stat"] = stt
			ev["stat_val"] = v
		"add_status":
			var sid: String = eff.status
			var turns := int(eff.get("turns", -1))
			# 自分のターン中に自分へ付けた期間つきの効果は、このターンの終わりで減らないよう 1 足す
			if turns > 0 and t == user and StatusController.canon(sid) != "cover":
				turns += 1  # 庇う（cover）はラウンドで数えるので足さない
			elif turns > 0 and acts_later(user, t) and StatusController.canon(sid) in ROUND_STATS:
				turns += 1  # D（12 回目・守護結界）：この後に動く味方へ付けた DEF・POW・SLD の増減も、そのターンの終わりで減らないよう 1 足す
			if sid == "taunt":
				v = int(user.get("uid", 0))  # 挑発してきたキャラ
			StatusController.apply_status(t, sid, v, turns)
			if eff.get("payload") is Dictionary:
				var pld: Dictionary = eff.payload
				if pld.get("hits_x", false):
					# D（12 回目・豪炎）：予約の攻撃の回数＝使った時の X
					pld = pld.duplicate(true)
					pld["hits"] = maxi(0, x)
					pld.erase("hits_x")
				_attach_payload(t, sid, pld)  # 反撃・予約の効果を状態に積む
			if sid == "declare" and not t.status_effects.declare.has("hp"):
				t.status_effects.declare["hp"] = int(t.hp)  # 宣言：この HP から減らなければ成功
			ev["status"] = sid
			ev["status_val"] = v if sid != "taunt" else 1
		"heal", "heal_pct" when StatusController.has(t, "no_heal"):
			# 回復不可：回復しない
			ev["heal"] = 0
			ev["no_heal"] = true
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
		"shield_pow":
			# A（気炎）：使った人の POW × pow_pct のブロック（切り捨て）
			var pv := get_pow(user) * int(eff.get("pow_pct", 0)) / 100
			t["shield"] = int(t.get("shield", 0)) + pv
			ev["shield"] = pv
		"double_block":
			# A（引きつけ）：今あるブロックを 2 倍にする（増えた分をブロックとして数える）
			var db := int(t.get("shield", 0))
			t["shield"] = db * 2
			ev["shield"] = db
		"cleanse_one":
			# A（肩を貸す）：デバフを 1 つ解除（DEBUFFS の並びで最初に見つかったもの）
			var one: Array = []
			for sid1 in DEBUFFS:
				if StatusController.has(t, sid1):
					StatusController.remove(t, sid1)
					one.append(sid1)
					break
			ev["cleanse"] = one
		"shield_per_status":
			# D（熱き鼓動）：対象の状態の値 1 につきブロック +v（状態は減らさない）
			# 11 回目：sld_pct があれば、状態の値 1 につき SLD × %（合計してから切り捨て）
			var sn := StatusController.val(t, str(eff.get("status", "fire")))
			var sv := v * sn + get_sld(user) * int(eff.get("sld_pct", 0)) * sn / 100
			t["shield"] = int(t.get("shield", 0)) + sv
			ev["shield"] = sv
		"dmg_half_block":
			# D（盾の返し）：自分（user）のブロックの半分のダメージ。相手のブロックから減らす
			var hd := int(floor(int(user.get("shield", 0)) / 2.0))
			var hb := mini(int(t.get("shield", 0)), hd)
			t["shield"] = int(t.get("shield", 0)) - hb
			var hbefore := int(t.hp)
			t["hp"] = maxi(0, hbefore - (hd - hb))
			ev["damage"] = hd - hb
			ev["blocked"] = hb
			ev["kill"] = int(t.hp) <= 0
			ev["lost"] = hbefore - int(t.hp)
		"set_next_action":
			t["next_action"] = eff.get("next", "strong_attack")
			ev["charge"] = true
		"purge_self":
			# D（浄化の誓い）：デバフを解除。火傷を解除した時は、火傷の残りターン分 攻撃力・防御力+（戦闘中）
			var fire_left := 0
			var f = t.status_effects.get("fire")
			if f is Dictionary:
				fire_left = maxi(0, int(f.turns))
			var gone: Array = []
			for sid in DEBUFFS:  # A の cleanse と同じデバフの一覧（火傷の残りターンを先に読むので別の効果にしている）
				if t.status_effects.has(sid):
					t.status_effects.erase(sid)
					gone.append(sid)
			ev["purge"] = gone
			if fire_left > 0:
				add_stat(t, "pow", fire_left)  # 12 回目：攻撃力・防御力 → POW・DEF（戦闘終了まで）
				add_stat(t, "def", fire_left)
				ev["purge_bonus"] = fire_left


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
		"front_pair", "front_enemy_single":
			if foes.is_empty():
				return []
			if not is_ally:
				return _enemy_single(user, foes)
			# 味方の「目の前の敵前衛」（front_pair）：目の前の前衛 2 体（青なら A-2・A-3）にまとめて当たる。
			# 全滅していれば 同じ側の後衛 → C → 全員。旧 front_enemy_single（味方側）もこれと同じ
			return front_group(user, foes)
		"front_enemy_group":
			# 目の前の敵グループ：C・A-1・A-2・A-3（赤なら C・B-1・B-2・B-3）。全滅なら全員
			return enemy_group(user, foes) if is_ally else foes
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


## 目の前の敵グループ（front_enemy_group）の位置：青＝C・A-1・A-2・A-3、赤＝C・B-1・B-2・B-3
const GROUP_SLOTS := [["C", "A-1", "A-2", "A-3"], ["C", "B-1", "B-2", "B-3"]]


## 目の前の敵グループ（front_enemy_group）：C と自分の側の後衛・前衛。全滅していれば全員
static func enemy_group(user: Dictionary, foes: Array) -> Array:
	var lane := clampi(int(user.get("lane", 0)), 0, 1)
	var g := _in_slots(foes, GROUP_SLOTS[lane])
	return g if not g.is_empty() else foes


## 敵の単体攻撃（敵の行動の front_enemy_single）：挑発されていれば挑発した味方、
## そうでなければ予告した側（左＝青／右＝赤）にいる味方。倒れていれば残った方
static func _enemy_single(user: Dictionary, foes: Array) -> Array:
	if StatusController.has(user, "taunt"):
		var uid := StatusController.val(user, "taunt")
		for a in foes:
			if int(a.get("uid", -1)) == uid:
				return [a]
	var lane := int(user.get("target_lane", 0))
	for a in foes:
		if int(a.get("lane", 0)) == lane:
			return [a]
	return [foes[0]]


## 目の前の敵前衛（front_pair）：目の前の前衛（青なら A-2・A-3、赤なら B-3・B-2）。
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
