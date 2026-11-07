extends Node
class_name InitAllyDeck
## 初期デッキ（battle-spec.md「カード」の表）

const KNIGHT_DECK = ["strike", "strike", "strike", "block", "block", "sweep", "spirit"]

const WITCH_DECK = ["missile", "missile", "missile", "firebolt", "sparks", "barrier", "chant"]

## 新しい冒険を始める時に、各キャラへランダムに 1 枚足すカードの候補（9 回目）
## ナイト：受け流し・踏み込み・研ぎ澄ます／ウィッチ：毒ガス・リブロック・ゴーレム
const EXTRA = {
	"knight": ["parry", "k_step_in", "hone"],
	"witch": ["poison_gas", "reblock", "golem"],
}


## 初期デッキ＋候補からランダムに 1 枚
static func get_start_deck(character_id: String) -> Array:
	var d := get_deck(character_id)
	var ex: Array = EXTRA.get(character_id, [])
	if not ex.is_empty():
		d.append(ex.pick_random())
	return d


static func get_deck(character_id: String) -> Array:
	if character_id == "knight":
		return KNIGHT_DECK.duplicate(true)
	elif character_id == "witch":
		return WITCH_DECK.duplicate(true)
	return []
