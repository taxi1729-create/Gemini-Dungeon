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


## card_id はデッキの ID（バッジ付きなら "カードID@バッジID"）。完全一致を 1 枚消す
func remove_card(char_id: String, card_id: String) -> void:
	if decks.has(char_id):
		decks[char_id].erase(card_id)


## デッキの index 番目のカードにバッジを付ける（付いていれば上書き）
func attach_badge(char_id: String, index: int, badge_id: String) -> void:
	if decks.has(char_id) and index >= 0 and index < decks[char_id].size():
		decks[char_id][index] = ActionList.with_badge(str(decks[char_id][index]), badge_id)
