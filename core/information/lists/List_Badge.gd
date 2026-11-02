extends Node
class_name BadgeList
## バッジ（カード 1 枚に 1 つ付く強化。付け直すと上書き）battle-spec.md「バッジ」
## バッジ付きのカードはデッキの ID を "カードID@バッジID" と書く（ActionList.make_card が分解して card.badge に入れる）
## for: 付けられるカード（all = 全部 / attack = power のあるカード / ap = AP1 以上（APX は除く） / burn = 廃棄か消費のあるカード）
## icon は ImageController.icon の種類名（サブエージェント C が描く）。short はカードの紋章に書く 1 文字

const DATA = {
	"sharp": {"name": "鋭のバッジ", "short": "鋭", "icon": "b_sharp", "for": "attack", "price": 70, "desc": "ダメージ+3"},
	"guard": {"name": "堅のバッジ", "short": "堅", "icon": "b_guard", "for": "all", "price": 70, "desc": "使うと自分にブロック+4"},
	"light": {"name": "軽のバッジ", "short": "軽", "icon": "b_light", "for": "ap", "price": 90, "desc": "消費AP-1"},
	"draw": {"name": "引のバッジ", "short": "引", "icon": "b_draw", "for": "all", "price": 80, "desc": "使うとカードを1枚引く"},
	"fire": {"name": "炎のバッジ", "short": "炎", "icon": "b_fire", "for": "attack", "price": 70, "desc": "当てた敵に火傷2"},
	"first": {"name": "先のバッジ", "short": "先", "icon": "b_first", "for": "all", "price": 60, "desc": "戦闘開始時、このカードが優先して手札に来る"},
	"front": {"name": "前のバッジ", "short": "前", "icon": "b_front", "for": "attack", "price": 70, "desc": "前衛にいる時、さらに5ダメージ"},
	"back": {"name": "後のバッジ", "short": "後", "icon": "b_back", "for": "all", "price": 70, "desc": "後衛にいる時、使うと自分にブロック+6"},
	"aid": {"name": "援のバッジ", "short": "援", "icon": "b_aid", "for": "all", "price": 60, "desc": "使うと、もう1人の味方にブロック+3"},
	"keep": {"name": "残のバッジ", "short": "残", "icon": "b_keep", "for": "burn", "price": 60, "desc": "廃棄・消費の効果を無効にする"},
}


static func random_id() -> String:
	return DATA.keys().pick_random()


## このバッジをカードに付けられるか
static func can_attach(badge_id: String, card: Dictionary) -> bool:
	if not DATA.has(badge_id) or card.is_empty():
		return false
	match DATA[badge_id].for:
		"attack": return card.has("power")
		"ap": return int(card.get("ap", 0)) >= 1 and not card.get("ap_x", false)
		"burn": return ActionList.has_keyword(card, "exhaust") or ActionList.has_keyword(card, "consume")
	return true
