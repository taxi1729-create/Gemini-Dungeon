extends Node
class_name InitAllyDeck
## 初期デッキ（カードIDの並び）

const KNIGHT_DECK = [
	"strike", "strike", "strike", "block", "block", "sweep", "action_accel",
]

const WITCH_DECK = [
	"firebolt", "firebolt", "weak_point", "weak_point", "companion_block",
	"block", "action_accel", "force",
]


static func get_deck(character_id: String) -> Array:
	if character_id == "knight":
		return KNIGHT_DECK.duplicate(true)
	elif character_id == "witch":
		return WITCH_DECK.duplicate(true)
	return []
