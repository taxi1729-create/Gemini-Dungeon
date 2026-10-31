extends Node
class_name FoodList
## 食材 3 種と料理（battle-spec.md「食材と料理」）

const DATA = {
	"meat": {"name": "肉", "icon": "meat", "col": Color("c9773d")},
	"veg": {"name": "野菜", "icon": "leaf", "col": Color("6fbf4a")},
	"mush": {"name": "きのこ", "icon": "mushroom", "col": Color("d9a46a")},
}

## kind: heal = 全員HP回復 / max_hp = 全員最大HP+ / ap = 次の戦闘の最初のAP+ / atk = 次の戦闘の攻撃力+ / block = 次の戦闘開始時ブロック
const RECIPES = [
	{"id": "steak", "name": "ステーキ", "use": ["meat", "meat"], "kind": "heal", "val": 18, "desc": "全員HP+18"},
	{"id": "salad", "name": "サラダ", "use": ["veg", "veg"], "kind": "max_hp", "val": 4, "desc": "全員の最大HP+4（HPも+4）"},
	{"id": "soup", "name": "きのこスープ", "use": ["mush", "mush"], "kind": "ap", "val": 2, "desc": "次の戦闘、最初のターンのAP+2"},
	{"id": "stew", "name": "シチュー", "use": ["meat", "veg"], "kind": "heal", "val": 12, "desc": "全員HP+12"},
	{"id": "skewer", "name": "串焼き", "use": ["meat", "mush"], "kind": "atk", "val": 1, "desc": "次の戦闘、全員の攻撃力+1"},
	{"id": "stir_fry", "name": "野菜炒め", "use": ["veg", "mush"], "kind": "block", "val": 8, "desc": "次の戦闘、開始時に全員8ブロック"},
]
