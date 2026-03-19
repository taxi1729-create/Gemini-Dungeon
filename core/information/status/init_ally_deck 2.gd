extends Node
class_name InitAllyDeck

# デッキのアクション（カード）定義
# type: アクションタイプ, power: 威力, ap: 消費AP, effect: 特殊効果の識別子
const KNIGHT_DECK = [
"strike","strike","strike","action_accel","action_accel","firebolt","firebolt"
]

const WITCH_DECK = [
	# ウィッチの初期デッキ定義（仕様に沿って同様に定義します）
"block","block","block","action_accel","action_accel","firebolt","firebolt","weak_point","weak_point","weak_point","weak_point"
]

static func get_deck(character_id: String) -> Array:
	if character_id == "knight": return KNIGHT_DECK.duplicate(true)
	elif character_id == "witch": return WITCH_DECK.duplicate(true)
	return []
