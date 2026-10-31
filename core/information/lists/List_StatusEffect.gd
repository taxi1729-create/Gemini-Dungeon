extends Node
class_name StatusEffectList
## 状態異常は 3 種類だけ（battle-spec.md「カード」）。
## decays = true ならラウンド終了ごとに 1 減る。false なら戦闘中ずっと続く。

const DATA = {
	"fire": {"name": "火傷", "short": "火傷", "timing": "start_turn", "decays": true, "icon": "flame", "good": false,
		"desc": "ターン開始時に数値分のダメージ。毎ラウンド1減る"},
	"atk_buff": {"name": "攻撃力アップ", "short": "攻↑", "timing": "all", "decays": false, "icon": "atk_buff", "good": true,
		"desc": "与えるダメージ +数値（戦闘中ずっと）"},
	"spd_buff": {"name": "素早さアップ", "short": "速↑", "timing": "all", "decays": false, "icon": "chevrons", "good": true,
		"desc": "素早さ +数値（次のラウンドの行動順から）"},
}
