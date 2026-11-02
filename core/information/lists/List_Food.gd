extends Node
class_name FoodList
## 食材 3 種（グレード 1〜3）と料理（battle-spec.md「食材と料理」）
## 食材は Inventory.foods に {"id": 食材ID, "grade": 1〜3} の配列で持つ。
## 料理は食材を 1〜3 個選び、グレードの合計（レリック「料理人の鍋」で +1）で料理が決まる。

const DATA = {
	"meat": {"name": "肉", "icon": "meat", "col": Color("c9773d"), "how": "超過ダメージの合計"},
	"mush": {"name": "きのこ", "icon": "mushroom", "col": Color("d9a46a"), "how": "倒すまでのターン数"},
	"fish": {"name": "魚", "icon": "fish", "col": Color("5aa8d8"), "how": "減らされたHP（2人の合計）"},
}

const PICK_MAX := 3  # 料理に入れられる食材の数


## 戦闘勝利時の食材のグレード（0 = 得られない）
static func meat_grade(overkill_total: int) -> int:
	if overkill_total >= 30:
		return 3
	if overkill_total >= 10:
		return 2
	if overkill_total >= 1:
		return 1
	return 0


static func mush_grade(rounds: int) -> int:
	if rounds <= 5:
		return 3
	if rounds <= 10:
		return 2
	if rounds <= 20:
		return 1
	return 0


static func fish_grade(hp_lost_total: int) -> int:
	if hp_lost_total <= 5:
		return 3
	if hp_lost_total <= 20:
		return 2
	if hp_lost_total <= 40:
		return 1
	return 0


## 料理の一覧。heal_pct = 全員の HP 回復（最大 HP の %）。next = 次の戦闘の効果（CurrentStatus.next_battle に足す）
## next のキー：atk（攻撃力）/ def（防御力）/ regen（リジェネのターン数）/ ap（最初のターンの AP）
const DISHES = {
	"plain": {"name": "まかない飯", "heal_pct": 30, "next": {}, "desc": "HP30%回復"},
	"yakiniku": {"name": "ガッツリ焼肉", "heal_pct": 45, "next": {"atk": 1}, "desc": "HP45%回復。次の戦闘で味方全体の攻撃力+1"},
	"mush_pot": {"name": "森のきのこ鍋", "heal_pct": 45, "next": {"regen": 2}, "desc": "HP45%回復。次の戦闘で味方全体に2ターンリジェネ"},
	"fish_set": {"name": "焼き魚定食", "heal_pct": 45, "next": {"def": 3}, "desc": "HP45%回復。次の戦闘で味方全体の防御力+3"},
	"plate": {"name": "彩りプレート", "heal_pct": 45, "next": {}, "desc": "HP45%回復"},
	"steak": {"name": "極上ステーキ", "heal_pct": 60, "next": {"atk": 3}, "desc": "HP60%回復。次の戦闘で味方全体の攻撃力+3"},
	"mush_soup": {"name": "秘伝きのこスープ", "heal_pct": 60, "next": {"regen": 5}, "desc": "HP60%回復。次の戦闘で味方全体に5ターンリジェネ"},
	"sashimi": {"name": "大漁の舟盛り", "heal_pct": 60, "next": {"def": 3}, "desc": "HP60%回復。次の戦闘で味方全体の防御力+3"},
	"kiwami": {"name": "三種の極み膳", "heal_pct": 60, "next": {"ap": 3}, "max_hp": 3, "item": "ultimate_soup",
		"desc": "HP60%回復。最大HP+3。次の戦闘で最初のAP+3。アイテム「極みスープ」を得る"},
	"dinner": {"name": "豪華ディナー", "heal_pct": 60, "next": {"ap": 1}, "desc": "HP60%回復。次の戦闘で最初のAP+1"},
}


## 選んだ食材（[{id, grade}, ...]）からできる料理の ID。bonus はレリックによるグレードの緩和（+1）
static func dish_for(picked: Array, bonus: int = 0) -> String:
	if picked.is_empty():
		return ""
	var g := bonus
	var cnt := {"meat": 0, "mush": 0, "fish": 0}
	for f in picked:
		g += int(f.grade)
		cnt[f.id] = int(cnt.get(f.id, 0)) + 1
	if g >= 8:
		if cnt.meat >= 3:
			return "steak"
		if cnt.mush >= 3:
			return "mush_soup"
		if cnt.fish >= 3:
			return "sashimi"
		if cnt.meat == 1 and cnt.mush == 1 and cnt.fish == 1:
			return "kiwami"
		return "dinner"
	if g >= 6:
		if cnt.meat >= 2:
			return "yakiniku"
		if cnt.mush >= 2:
			return "mush_pot"
		if cnt.fish >= 2:
			return "fish_set"
		return "plate"
	return "plain"


## 合計グレード（表示用）
static func grade_sum(picked: Array, bonus: int = 0) -> int:
	var g := bonus
	for f in picked:
		g += int(f.grade)
	return g
