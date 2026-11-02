extends Node
## Inventory（Autoload）：道具・食材・レリック・ゴールド

const ITEM_MAX := 3  # アイテムは 3 つまで。上から順に詰める

var items: Array = []
var foods: Array = []  # [{"id": 食材ID, "grade": 1〜3}, ...]
var relics: Array = []  # レリックID（RelicList.MAX まで・重複なし。手に入れた順）
var gold := 0


func reset() -> void:
	items = ["herb", "fire_potion"]
	foods = [{"id": "meat", "grade": 1}, {"id": "mush", "grade": 1}, {"id": "fish", "grade": 1}]
	relics = []
	gold = 50


# ------------------------------------------------------------
# 食材
# ------------------------------------------------------------
func add_food(food_id: String, grade: int = 1) -> void:
	if FoodList.DATA.has(food_id) and grade >= 1:
		foods.append({"id": food_id, "grade": clampi(grade, 1, 3)})


## その食材の foods の index（グレードの高い順）
func food_indices(food_id: String) -> Array:
	var out: Array = []
	for i in foods.size():
		if foods[i].id == food_id:
			out.append(i)
	out.sort_custom(func(a, b): return int(foods[a].grade) > int(foods[b].grade))
	return out


func remove_food_at(i: int) -> void:
	if i >= 0 and i < foods.size():
		foods.remove_at(i)


func food_total() -> int:
	return foods.size()


## 「肉 G3・G1　きのこ G2　魚 なし」の形
func foods_text() -> String:
	var parts: Array = []
	for k in FoodList.DATA:
		var gs: Array = []
		for i in food_indices(k):
			gs.append("G%d" % int(foods[i].grade))
		parts.append("%s %s" % [FoodList.DATA[k].name, "・".join(gs) if not gs.is_empty() else "なし"])
	return "　".join(parts)


# ------------------------------------------------------------
# 道具
# ------------------------------------------------------------
func remove_item(item_id: String) -> void:
	items.erase(item_id)


func remove_item_at(i: int) -> void:
	if i >= 0 and i < items.size():
		items.remove_at(i)


## アイテムを入れる。いっぱいなら false
func add_item(item_id: String) -> bool:
	if items.size() >= ITEM_MAX:
		return false
	items.append(item_id)
	return true


func items_full() -> bool:
	return items.size() >= ITEM_MAX


# ------------------------------------------------------------
# レリック
# ------------------------------------------------------------
func has_relic(id: String) -> bool:
	return relics.has(id)


## レリックを加える。持っている・いっぱい（5 つ）なら false（いっぱいの時は交換の画面を出すこと）
func add_relic(id: String) -> bool:
	if relics.has(id) or relics.size() >= RelicList.MAX or not RelicList.DATA.has(id):
		return false
	relics.append(id)
	return true


## old を捨てて new を入れる（交換）
func swap_relic(old_id: String, new_id: String) -> void:
	var i := relics.find(old_id)
	if i >= 0 and not relics.has(new_id):
		relics[i] = new_id


func relics_full() -> bool:
	return relics.size() >= RelicList.MAX
