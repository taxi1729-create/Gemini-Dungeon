extends Node
# プロジェクト設定で "CurrentStatus" としてAutoloadに登録してください
var current_area_id = "cave" # 今いるエリアのID
var encounter_level = 1      # 敵の強さなどの指標
var allies = []
var enemies = []

func sync_from_init():
	allies = [
		{"id": "knight", "hp": 20, "max_hp": 20, "def": 1, "spd": 3, "ap": 3, "color": Color.GREEN, "status_effects": {}},
		{"id": "witch", "hp": 15, "max_hp": 15, "def": 0, "spd": 6, "ap": 3, "color": Color.PURPLE, "status_effects": {}}
	]
	enemies = []
