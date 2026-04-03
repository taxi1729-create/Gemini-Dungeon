extends Node
# プロジェクト設定で "CurrentStatus" としてAutoloadに登録してください
var current_area_id = "cave" # 今いるエリアのID
var encounter_level = 1      # 敵の強さなどの指標
var allies = []
var enemies = []

func sync_from_init():
	allies = [InitAllyStatus.DATA["knight"].duplicate(),InitAllyStatus.DATA["witch"].duplicate()]
	enemies = []
