# core/map/present/current_deck.gd
extends Node
# ※プロジェクト設定で "CurrentDeck" としてAutoloadに登録します

var decks = {
	"knight": [],
	"witch": []
}

# ゲーム開始時やマップ突入時に一度だけ呼ばれる
func sync_from_init():
	decks["knight"] = InitAllyDeck.get_deck("knight")
	decks["witch"] = InitAllyDeck.get_deck("witch")


# リザルト画面でカードを獲得した時などに使う関数
func add_card(char_id: String, card_id: String):
	if decks.has(char_id):
		decks[char_id].append(card_id)

# イベントなどでカードを削除する時などに使う関数
func remove_card(char_id: String, card_id: String):
	if decks.has(char_id):
		decks[char_id].erase(card_id) # 最初に見つかったものを1つ削除
