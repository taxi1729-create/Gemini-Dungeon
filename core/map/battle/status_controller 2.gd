extends Node
class_name StatusController

# 行動開始時のトリガー（毒など）
static func trigger_start_of_turn(char_data: Dictionary):
	if char_data.status_effects.has("poison"):
		var dmg = char_data.status_effects["poison"] # 蓄積ターン数をダメージとする
		char_data.hp -= dmg
		print(char_data.id, " は毒で ", dmg, " のダメージを受けた！")
		
	if char_data.status_effects.has("regen"):
		char_data.hp = min(char_data.max_hp, char_data.hp + char_data.status_effects["regen"])

# ターン終了時の蓄積ターン減少処理（全員）
static func decrease_all_durations(allies: Array, enemies: Array):
	for char in allies + enemies:
		if char.hp <= 0: continue
		var effects_to_remove = []
		for effect in char.status_effects.keys():
			char.status_effects[effect] -= 1
			if char.status_effects[effect] <= 0:
				effects_to_remove.append(effect)
		# 0になったものを削除
		for effect in effects_to_remove:
			char.status_effects.erase(effect)

# 状態異常の付与
static func apply_status(target_data: Dictionary, status_id: String, duration: int):
	if target_data.status_effects.has(status_id):
		target_data.status_effects[status_id] += duration # 重ね掛け
	else:
		target_data.status_effects[status_id] = duration
