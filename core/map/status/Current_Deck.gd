extends Node
## CurrentDeck（Autoload）：各キャラのマスターデッキ（カードIDの配列）

var decks = {
	"knight": [],
	"witch": [],
}


func sync_from_init() -> void:
	decks["knight"] = InitAllyDeck.get_deck("knight")
	decks["witch"] = InitAllyDeck.get_deck("witch")


func add_card(char_id: String, card_id: String) -> void:
	if decks.has(char_id):
		decks[char_id].append(card_id)


func remove_card(char_id: String, card_id: String) -> void:
	if decks.has(char_id):
		decks[char_id].erase(card_id)
