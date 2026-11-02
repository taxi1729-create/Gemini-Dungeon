extends Node
class_name EventList
## イベント「？」（battle-spec.md「イベント」）。choices の id は Cont_Event.gd で処理する。

const DATA = {
	"lost_item": {"title": "落とし物", "icon": "coin",
		"text": "通路の隅に、誰かの荷物が落ちている。",
		"choices": [["gold40", "ゴールド40を拾う"], ["item", "道具を1つ持っていく"]]},
	"altar": {"title": "古い祭壇", "icon": "star",
		"text": "血の跡が残る祭壇。捧げものをすれば力を授けてくれそうだ。",
		"choices": [["altar", "全員HP-6でレアカードを得る"], ["leave", "立ち去る"]]},
	"mushrooms": {"title": "きのこの群生", "icon": "mushroom",
		"text": "見たことのないきのこがびっしり生えている。",
		"choices": [["mush3", "きのこ×3を採る"], ["eat", "その場で食べる（運しだい）"]]},
	"smith": {"title": "鍛冶師", "icon": "sword",
		"text": "洞窟に住みついた鍛冶師が「いらないカードを引き取ろう」と言う。",
		"choices": [["remove", "カードを1枚削除する"], ["leave", "立ち去る"]]},
	"spring": {"title": "癒やしの泉", "icon": "heart",
		"text": "澄んだ水が湧いている。体の芯から温まりそうだ。",
		"choices": [["heal12", "全員HP+12"], ["maxhp", "1人の最大HP+5"]]},
	"lost_monster": {"title": "迷子の魔物", "icon": "horns",
		"text": "はぐれた魔物の群れが道をふさいでいる。倒せば多めのゴールドが手に入りそうだ。",
		"choices": [["fight", "戦う（勝てばゴールド2倍）"], ["leave", "逃げる"]]},
	"craftsman": {"title": "旅の細工師", "icon": "badge",
		"text": "旅の細工師が「カードに付けるバッジを1つ、ただで作ってやろう」と言う。",
		"choices": [["badge", "%sをもらう（付けるカードを選ぶ）"], ["leave", "立ち去る"]]},
}
