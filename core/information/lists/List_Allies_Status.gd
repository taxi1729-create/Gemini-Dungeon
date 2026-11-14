extends Node
class_name InitAllyStatus
## 味方の初期ステータス（battle-spec.md「キャラクター」）。art はコードで描くキャラの種類名。
## 11 回目：HP・POW（攻撃力の基礎。攻撃カードのダメージ＝POW × カードの %）・DEF（防御力）・SLD（ブロック量の基礎。ブロック＝SLD × カードの %）
##   ナイト HP100・POW20・DEF0・SLD8 ／ ウィッチ HP50・POW30・DEF0・SLD10
##   atk は攻撃力アップなどと同じ「ダメージへの固定の加算」（イベントの剣の +1 など）。def は受けるダメージから引く

const AP_PER_TURN := 3  # 毎ターン開始時に AP 3（＋APプラス・予約などの加算）。ターン終了時に残りは捨てる（9 回目）
const AP_MAX := 7  # 大きな砂時計で +5（12）

const DATA = {
	"knight": {"id": "knight", "name": "ナイト",
		"hp": 100, "max_hp": 100, "pow": 20, "def": 0, "sld": 8, "atk": 0, "shield": 0,
		"ap": 0, "max_ap": AP_MAX, "side": "ally", "art": "knight", "status_effects": {}},
	"witch": {"id": "witch", "name": "ウィッチ",
		"hp": 50, "max_hp": 50, "pow": 30, "def": 0, "sld": 10, "atk": 0, "shield": 0,
		"ap": 0, "max_ap": AP_MAX, "side": "ally", "art": "witch", "status_effects": {}},
}

## 10 回目までの初期値（古いセーブを読む時に、イベントなどで増減した分だけを引き継ぐ）
const OLD_BASE = {
	"knight": {"max_hp": 60, "def": 2},
	"witch": {"max_hp": 33, "def": 0},
}


static func get_status(character_id: String) -> Dictionary:
	return DATA[character_id].duplicate(true)


## 11 回目より前のセーブの味方（"pow" が無い）を今のステータスに直す。a は古い値の入った味方の辞書（その場で書き換える）
##   最大 HP ＝ 新しい初期値 ＋（古い最大 HP − 古い初期値）＝イベント・料理などの増減は残す。HP は割合を保つ（生きていれば 1 以上）
##   DEF ＝ 新しい初期値 ＋（古い DEF − 古い初期値）。POW・SLD は新しい初期値。atk（固定の加算）はそのまま
static func upgrade_old(a: Dictionary) -> void:
	var id := str(a.get("id", ""))
	if a.has("pow") or not DATA.has(id):
		return
	var base: Dictionary = DATA[id]
	var old: Dictionary = OLD_BASE[id]
	var old_max := maxi(1, int(a.get("max_hp", old.max_hp)))
	var old_hp := clampi(int(a.get("hp", old_max)), 0, old_max)
	var new_max := maxi(1, int(base.max_hp) + old_max - int(old.max_hp))
	var new_hp := int(round(float(old_hp) * new_max / old_max))
	if old_hp > 0:
		new_hp = clampi(new_hp, 1, new_max)
	a["max_hp"] = new_max
	a["hp"] = new_hp
	a["def"] = maxi(0, int(base.def) + int(a.get("def", old.def)) - int(old.def))
	a["pow"] = int(base.pow)
	a["sld"] = int(base.sld)
