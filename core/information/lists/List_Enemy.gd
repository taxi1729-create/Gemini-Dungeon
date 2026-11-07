extends Node
class_name EnemyList
## 敵の定義。actions の中からランダムに次の行動（予告）を選ぶ。
## stage：出てくる階（1〜3、ラスボスは 4）。2 階以降は HP・攻撃力を表の値に近いまま使う（下の make_enemy）
## art は ImageController.character の絵の名前。"絵@色" で色違い（ImageController.ART_PAL）
## rank：elite / boss / lastboss は HP を階の段で増やさない（バランス表の値そのまま）
## ラスボスは phase2_actions を持ち、HP が phase2_at（割合）以下になると第 2 段階へ（Cont_Battle._lastboss_check）

const DATA = {
	# ---- 1 階：暗がりの洞窟（今のまま） ----
	"goblin": {"name": "ゴブリン", "hp": 18, "spd": 4, "def": 0, "art": "goblin", "actions": ["club", "club", "flank", "guard_self"]},
	"gool": {"name": "グール", "hp": 23, "spd": 2, "def": 0, "art": "gool", "actions": ["claw", "burn_one", "poison_spit"]},
	"zombie": {"name": "ゾンビ", "hp": 29, "spd": 1, "def": 0, "art": "zombie", "actions": ["bite", "bite", "guard_allies"]},
	"skeleton": {"name": "スケルトン", "hp": 16, "spd": 5, "def": 1, "art": "skeleton", "actions": ["club", "slash"]},
	"harpy": {"name": "ハーピー", "hp": 13, "spd": 7, "def": 0, "art": "harpy", "actions": ["claw", "gust", "flank"]},
	"fire_warriar": {"name": "炎の魔神", "hp": 21, "spd": 3, "def": 0, "art": "fire_warriar", "actions": ["slash", "burn_all"]},
	"dark_knight": {"name": "デュラハン", "hp": 78, "spd": 3, "def": 1, "art": "dark_knight", "art_scale": 1.15,
		"actions": ["dark_slash", "dark_flank", "big_guard", "charge", "war_cry"]},
	"green_dragon": {"name": "緑龍", "hp": 169, "spd": 4, "def": 1, "art": "green_dragon", "art_scale": 1.2,
		"actions": ["breath", "tail", "charge", "burn_all"]},
	"necro": {"name": "ネクロマンサー", "hp": 156, "spd": 5, "def": 0, "art": "necro", "art_scale": 1.25,
		"actions": ["dark_wave", "slash", "dark_heal", "charge"]},

	# ---- 2 階：沈黙の回廊（普通 HP 30〜50／単体 12〜16／全体 9〜12） ----
	"mute_imp": {"name": "無言の小鬼", "stage": 2, "hp": 31, "spd": 5, "def": 0, "art": "goblin@hush", "art_scale": 1.05,
		"actions": ["hush_club", "hush_club", "hush_flank", "hush_guard"]},
	"corridor_ghoul": {"name": "回廊の喰屍鬼", "stage": 2, "hp": 40, "spd": 3, "def": 0, "art": "gool@hush",
		"actions": ["hush_rend", "hush_rend", "mute_spit"]},
	"silent_monk": {"name": "沈黙の修道士", "stage": 2, "hp": 42, "spd": 2, "def": 1, "art": "zombie@hush",
		"actions": ["vow_strike", "vow_strike", "vow_guard"]},
	"bone_choir": {"name": "骨の聖歌隊", "stage": 2, "hp": 32, "spd": 5, "def": 2, "art": "skeleton@hush",
		"actions": ["bone_slash", "requiem"]},
	"gargoyle": {"name": "ガーゴイル", "stage": 2, "hp": 34, "spd": 6, "def": 1, "art": "harpy@stone",
		"actions": ["stone_claw", "stone_gust", "stone_dive"]},
	"candle_wraith": {"name": "燭台の亡霊", "stage": 2, "hp": 33, "spd": 4, "def": 0, "art": "fire_warriar@hush",
		"actions": ["candle_flame", "candle_wave", "candle_slash"]},
	# 強敵 HP150
	"silent_knight": {"name": "沈黙の騎士", "stage": 2, "rank": "elite", "hp": 150, "spd": 3, "def": 2, "art": "dark_knight@hush", "art_scale": 1.2,
		"actions": ["silent_blade", "silent_flank", "silent_wall", "silent_charge", "silent_vow"]},
	# ボス HP300
	"abbess": {"name": "沈黙の修道院長", "stage": 2, "rank": "boss", "hp": 300, "spd": 5, "def": 1, "art": "necro@hush", "art_scale": 1.35,
		"actions": ["abbess_wave", "abbess_slash", "abbess_heal", "abbess_charge", "abbess_slash"]},
	"bell_dragon": {"name": "鐘楼の竜", "stage": 2, "rank": "boss", "hp": 300, "spd": 4, "def": 2, "art": "green_dragon@bronze", "art_scale": 1.3,
		"actions": ["bell_breath", "bell_tail", "bell_toll", "bell_charge", "bell_tail"]},

	# ---- 3 階：星の大聖堂（普通 HP 45〜70／単体 15〜20／全体 12〜15） ----
	"choir_imp": {"name": "聖歌隊の小悪魔", "stage": 3, "hp": 46, "spd": 6, "def": 0, "art": "goblin@star", "art_scale": 1.05,
		"actions": ["imp_strike", "imp_strike", "imp_flank", "imp_guard"]},
	"censer_ghoul": {"name": "香炉の喰屍鬼", "stage": 3, "hp": 56, "spd": 3, "def": 0, "art": "gool@star",
		"actions": ["censer_rend", "censer_rend", "censer_smoke"]},
	"fallen_pilgrim": {"name": "堕ちた巡礼者", "stage": 3, "hp": 58, "spd": 2, "def": 2, "art": "zombie@star",
		"actions": ["pilgrim_blow", "pilgrim_blow", "penance"]},
	"star_sentinel": {"name": "星の番兵", "stage": 3, "hp": 48, "spd": 5, "def": 3, "art": "skeleton@star",
		"actions": ["star_spear", "star_spear", "sentinel_guard"]},
	"glass_angel": {"name": "硝子の天使", "stage": 3, "hp": 45, "spd": 7, "def": 1, "art": "harpy@glass",
		"actions": ["glass_feather", "glass_dive", "glass_hymn"]},
	"astral_flame": {"name": "星炎の精", "stage": 3, "hp": 47, "spd": 4, "def": 0, "art": "fire_warriar@star",
		"actions": ["star_flare", "astral_burn", "star_flare"]},
	# 強敵 HP220
	"star_paladin": {"name": "星の聖騎士", "stage": 3, "rank": "elite", "hp": 220, "spd": 4, "def": 2, "art": "dark_knight@star", "art_scale": 1.25,
		"actions": ["paladin_blade", "paladin_flank", "paladin_aegis", "paladin_charge", "paladin_zeal"]},
	# ボス HP420
	"star_dragon": {"name": "大聖堂の星竜", "stage": 3, "rank": "boss", "hp": 420, "spd": 4, "def": 2, "art": "green_dragon@star", "art_scale": 1.35,
		"actions": ["star_breath", "star_tail", "star_charge", "star_wing", "star_tail"]},
	"archbishop": {"name": "大司教の亡骸", "stage": 3, "rank": "boss", "hp": 420, "spd": 5, "def": 1, "art": "necro@crimson", "art_scale": 1.4,
		"actions": ["judgment", "dark_mass", "bishop_heal", "rite_charge", "judgment"]},

	# ---- ラスボス：堕ちた双星（HP750。50% で第 2 段階：全体攻撃＋スタン） ----
	"fallen_twins": {"name": "堕ちた双星", "stage": 4, "rank": "lastboss", "hp": 750, "spd": 6, "def": 2, "art": "twins", "art_scale": 1.45,
		"actions": ["blue_star", "red_star", "twin_veil", "star_rain", "blue_star", "red_star"],
		"phase2_at": 0.5,
		"phase2_actions": ["twin_charge", "fallen_comet", "eclipse_rain", "fallen_comet", "red_star", "twin_charge"]},
}


## 敵を作る。floor_no は階の中の段（0〜7）
static func make_enemy(enemy_id: String, floor_no: int) -> Dictionary:
	var base: Dictionary = DATA[enemy_id]
	var stage := int(base.get("stage", 1))
	var rank := str(base.get("rank", "normal"))
	var hp := int(round(base.hp * (1.0 + 0.06 * floor_no)))
	var atk := 1 + int(floor_no / 2.0)
	if stage >= 2:
		# 2 階以降：普通の敵だけ段で少し増える（HP +3%／段、攻撃力 +1／3 段）。強敵・ボスは表の値そのまま
		if rank == "normal":
			hp = int(round(base.hp * (1.0 + 0.03 * floor_no)))
			atk = int(floor_no / 3.0)
		else:
			hp = int(base.hp)
			atk = 0
	var e := {
		"base_id": enemy_id, "name": base.name, "art": base.art,
		"art_scale": base.get("art_scale", 1.0),
		"hp": hp, "max_hp": hp, "spd": base.spd, "def": base.def,
		"shield": 0, "side": "enemy", "status_effects": {}, "atk": atk,
		"actions": base.actions.duplicate(), "intent": {}, "intent_id": "", "next_action": "", "target_lane": 0,
	}
	if base.has("phase2_actions"):
		e["phase"] = 1  # ラスボスの段階（1 → 2）。戦闘中のセーブではこの値と actions を残す
	return e
