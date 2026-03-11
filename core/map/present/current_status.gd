extends Node
class_name CurrentStatus

# 現在対峙している敵のステータス
var enemy = {
	"id": "", "hp": 0, "max_hp": 0, "def": 0, "spd": 0, "poison": 0
}

# 味方の現在のステータス（配列で管理）
var allies = [
	{"id": "knight", "hp": 0, "max_hp": 0, "def": 0, "spd": 0, "ap": 0},
	{"id": "witch", "hp": 0, "max_hp": 0, "def": 0, "spd": 0, "ap": 0}
]

# ゲーム開始時や戦闘開始時に初期値をコピーする関数
func sync_from_init():
	var k_init = InitAllyStatus.get_status("knight")
	allies[0] = k_init
	var w_init = InitAllyStatus.get_status("witch")
	allies[1] = w_init
