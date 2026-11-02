extends Node
class_name RelicList
## レリック（2 人に常に効く。5 つまで・重複不可。6 つ目は交換）battle-spec.md「レリック」
## icon は ImageController.icon の種類名（サブエージェント C が描く）

const MAX := 5

const DATA = {
	"blue_crest": {"name": "蒼の盾章", "icon": "r_blue_crest", "price": 150,
		"desc": "左（青）に立つ味方は、ターン開始時にブロック+4"},
	"red_crest": {"name": "紅の剣章", "icon": "r_red_crest", "price": 150,
		"desc": "右（赤）に立つ味方は攻撃力+1"},
	"oath": {"name": "誓いの紋章", "icon": "r_oath", "price": 140,
		"desc": "キャラ固有スキルを使うと、味方全体にブロック+4"},
	"hourglass": {"name": "大きな砂時計", "icon": "r_hourglass", "price": 160,
		"desc": "AP の上限+5"},
	"light_boots": {"name": "軽い靴", "icon": "r_boots", "price": 140,
		"desc": "入替・陣形変更は、各ターン最初の1回だけ AP0"},
	"whetstone": {"name": "砥石", "icon": "r_whetstone", "price": 150,
		"desc": "各ターン、最初に使うアタックカードのダメージ+4"},
	"ash_altar": {"name": "灰の祭壇", "icon": "r_ash_altar", "price": 130,
		"desc": "消費・廃棄が発動した時、その味方にブロック+3"},
	"chef_pot": {"name": "料理人の鍋", "icon": "r_chef_pot", "price": 120,
		"desc": "料理の達成グレードを1緩和する（合計グレード+1として扱う）"},
	"merchant_bell": {"name": "行商人の鈴", "icon": "r_bell", "price": 120,
		"desc": "ショップの品ぞろえが3つ増える"},
	"rosary": {"name": "十連の数珠", "icon": "r_rosary", "price": 170,
		"desc": "カードアクションを10回使うたび、次のアタックカードはダメージ+10、スキルカードは自分にブロック+10"},
}


static func random_id(exclude: Array = []) -> String:
	var keys: Array = DATA.keys().filter(func(k): return not exclude.has(k))
	return "" if keys.is_empty() else keys.pick_random()
