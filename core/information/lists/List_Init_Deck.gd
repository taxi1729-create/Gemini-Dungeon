extends Node
class_name InitAllyDeck
## 初期デッキ（battle-spec.md「カード」の表）

const KNIGHT_DECK = ["strike", "strike", "strike", "block", "block", "sweep", "spirit"]

const WITCH_DECK = ["missile", "missile", "missile", "firebolt", "firebolt", "sparks", "barrier", "chant"]


static func get_deck(character_id: String) -> Array:
	if character_id == "knight":
		return KNIGHT_DECK.duplicate(true)
	elif character_id == "witch":
		return WITCH_DECK.duplicate(true)
	return []
