extends Node
class_name ActionList
## カード・スキル・敵の行動の定義（battle-spec.md「カード」「キャラクター」「敵」）
##
## 共通の項目
##   owner    : カードの持ち主（knight / witch）。報酬・ショップのカードは持ち主のデッキへ自動で入る
##   target   : self / ally_all / enemy_all
##              front_pair         = 目の前の敵前衛（青なら A-2・A-3 の 2 体ともに当たる。全滅なら A-1 → C → 全員）
##                                   ※味方の front_enemy_single は front_pair と同じ扱い（旧名。新しいカードには使わない）
##              front_enemy_group  = 目の前の敵グループ（青なら C・A-1・A-2・A-3。全滅なら全員）
##              back_row / random_enemy / other_ally も使える
##              front_row          = 前衛の敵全体
##   power    : ダメージ（対象全員に与える）
##   effects  : 効果の配列。各効果 {"effect": 種類, "eff_val": 値, "status": 状態ID, "turns": ターン数, "to": "target"/"self"/"ally_all"}
##              種類：add_shield / add_status / heal / add_ap / draw / swap / double / extra_turn / set_next_action / add_gauge（必殺技ゲージ+）
##   keywords : "exhaust"（廃棄：使うと廃棄札へ）、"power"（パワー：type "power"。12 回目から AP はカードごと（"ap"）。使うと戦闘終了まで power_effect が効く。10 回目）
##              "consume"（消費：使う時、このカード以外の手札からランダムに 1 枚を捨札へ。捨てるカードが無ければ使えない）
##   ap_x     : true なら APX（使う時に全ての AP を消費し、その量を X とする。AP 1 以上で使える。"ap" は 1 を入れておく）
##   hits     : 多段攻撃の回数（power を hits 回与える）。hits_x = true なら X 回
##   on_kill  : "reuse"（この攻撃で倒したら捨札に行かず手札に残り、もう一度使える）
##              "reuse_free"（同上。さらにそのターンの終わりまでこのカードの AP が 0）
##   kill_ap  : この攻撃で敵を 1 体倒すごとに AP +n
##   効果の "x": true は eff_val × X
##   効果の種類（追加）：absorb_block（対象の敵のブロックの合計を自分のブロックに足す。敵のブロックはそのまま）
##
## 8 回目に追加した項目（新カード 46 枚）
##   reroll      : true なら random_enemy の多段で 1 ヒットごとに対象を引き直す（1 ヒット目はプレビューと同じ敵）
##   hit_effects : 1 ヒットごとに、当たった敵に付ける効果の配列。"if_damaged": true ならダメージを受けた時だけ
##                 power が無いカード（毒針の嵐）は hits 回、効果だけを付ける
##   ap_hits     : {"min": n, "hits": m}。使う前の AP が n 以上なら hits を m にする（二連詠唱）
##   power_used  : true なら power ＝ このターンにこのキャラが使ったカードの枚数（このカードは含まない。怒涛の締め）
##   power_from  : "poison" なら対象それぞれの毒の残り分の固定ダメージ（毒は減らさない。腐食）
##   saigo_only  : true なら「最後」の条件を満たした時だけ使える
##   効果 rank_swap : 自分の前衛・後衛を入れ替える（踏み込み）／ repeat : 同じ攻撃をもう一度（撃破の追加効果。追尾弾）
##   bonus の "target" は対象を差し替える（星降り）、"text" は説明文を差し替える
##   bonus_gekiha / bonus_hangeki / bonus_yoyaku : 撃破・反撃・予約の追加効果（仕組みは ActionController）
##   power_effect（パワー）："status"+"eff_val"（自分の攻撃力・防御力）のほか
##     "kind" : burn_atk（火傷の残りターン分 攻撃力+）/ last_stand（HP% で攻撃力・防御力+）/
##              on_plain_card（札の無いカードが発動するたび敵全体に dmg。即応で +sokuou_add）/ on_burn（消費・廃棄のたび敵全体に dmg）/
##              on_attack_poison（アタックカードのたび当たった敵に毒）/ on_debuff_card（状態異常を付けるカードのたび自分にブロック）/
##              on_own_card（このキャラがカードを使うたびもう 1 人に火傷・ブロック）/ on_gekiha_card（撃破のカードのたび自分に攻撃力+1）/
##              on_gekiha_hangeki（撃破・反撃が発動するたびランダムな敵に power×hits）/ end_herb・end_convert（自分のターン終了時）
##     "once"  : 使った時に 1 回だけ発動する効果の配列（"to" は self / other_ally / ally_all）
##     "aid_atk": もう 1 人の味方の攻撃力 +n（戦闘終了まで）
##     "exhaust_now": true なら使った時の効果の後、廃棄札へ（天啓。廃棄の札のパワーは使うと廃棄札へ行く）
##     "left" / "right" : 陣形のパワー。効果はその時の位置で毎回判定（入替・陣形変更で切り替わる）。once は使った時の位置
##   パワーの「〜するたび」は、使った後から戦闘終了まで、味方のどちらかで条件が起きるたびに発動する（同じカード 2 枚なら 2 回）
##
## 9 回目に追加した項目（カード修正 39 件）
##   bonus_sokuou / bonus_saigo / bonus_tenshin : 即応・最後・転身の札ごとの追加効果（無ければ "bonus"。渾身の一撃は転身と即応の両方）
##   bonus の "hits" は多段の回数を差し替える（終焉の光の陣形 B）
##   hits_used   : true なら hits ＝ このターンにこのキャラが使ったカードの枚数（このカードは含まない。怒涛の締め：8×X）
##   pre_rank    : 発動する前に自分をこの段へ移す（0＝前衛。魔弾）
##   効果 rank_to : 自分を eff_val の段へ移す（1＝後衛。魔法準備）／ cleanse : 対象のデバフ（ActionController.DEBUFFS）を外す（闘志）
##   power_effect の "all": true は status の効果を味方全体に（鋼鉄化・フォース。もう 1 人の分は aid_atk / aid_def）
##   kind on_kw_card : "kws" の札が付いたカードが発動するたび敵全体に dmg（即応で +sokuou_add。連撃の気迫）
##   kind on_gekiha_card の "kws" : この札のどれかが付いたカードを使うたび（狩人の本能＝陣形・予約。無ければ撃破）
##
## 10 回目に追加した項目（D：新カード 20 枚）
##   if_self_status   : {"status", "power"}。自分にその状態があれば power を足す（炎刃）
##   vs_status        : {"status", "power"}。その状態が付いた敵へのダメージに power を足す（侵食の針。敵ごとに判定）
##   power_half_block : true なら power ＝ 自分のブロックの半分（切り捨て。盾打ち）
##   per_exhaust      : 自分の廃棄札 1 枚につき power を足す（灰燼斬。ctx.exhausted）
##   効果 shield_per_status : 対象の状態 status の値 1 につきブロック +eff_val（熱き鼓動。状態は減らさない）
##   効果 dmg_half_block    : 自分（使った側）のブロックの半分のダメージを対象に（盾の返しの反撃）
##   状態 chant（詠唱の構え）: 次に使うアタックカードのダメージ +val（使うと消える）
##
## 11 回目：ステータス POW・SLD（ActionController の pow_part / sld_part）
##   pow_pct  : 味方のカード・必殺技の攻撃。ダメージ＝使う人の POW × pow_pct ÷ 100（切り捨て、最低 1）。旧 power × 5
##              （make_card・_special_play が "power": 0 を足す。power は固定の上乗せで、バッジ・砥石などが足す）
##   bonus / bonus_left・right / if_self_status / vs_status の "pow_pct" は % に足す。per_exhaust_pct は廃棄札 1 枚につき %
##   効果 add_shield の sld_pct : ブロック＝使った人の SLD × sld_pct ÷ 100（切り捨て）。旧 eff_val ÷ 5 × 100（味方全体・もう 1 人にも使った人の SLD）
##   効果 shield_per_status の sld_pct : 状態の値 1 につき SLD × %
##   固定のまま：敵の行動（power・eff_val）、パワーの効果（power_effect の dmg・shield・once のブロック）、毒・火傷などの状態の値、
##              バッジ・レリック・アイテムの加算、腐食（power_from）・盾打ち（power_half_block）・怒涛の締め（power_used）
##   敵の行動の power は 10 回目の約 1.6 倍（四捨五入）。状態異常の数値・ブロック・回復はそのまま
## art は ImageController.icon の種類名（画像ファイルは使わない）

const ALLY_CARDS = {
	"common": {
		# --- ナイト ---
		"strike": {"no": "K001", "group": "汎用・味方支援", "rarity": "common", "pool": "none", "owner": "knight", "name": "ストライク", "type": "attack", "target": "front_pair", "art": "sword", "pow_pct": 100, "ap": 1},
		"block": {"no": "K002", "group": "汎用・味方支援", "rarity": "common", "pool": "none", "owner": "knight", "name": "ブロック", "type": "skill", "target": "self", "art": "shield", "ap": 1,
			"effects": [{"effect": "add_shield", "sld_pct": 100}]},
		"sweep": {"no": "K003", "group": "汎用・味方支援", "rarity": "common", "pool": "init", "owner": "knight", "name": "薙ぎ払い", "type": "attack", "target": "front_row", "art": "sweep", "pow_pct": 120, "ap": 1},
		"spirit": {"no": "K004", "group": "汎用・味方支援", "rarity": "common", "pool": "init", "owner": "knight", "name": "気合", "type": "skill", "target": "self", "art": "chevrons", "ap": 1, "keywords": ["yoyaku"],
			"bonus_yoyaku": {"effects": [{"effect": "add_ap", "eff_val": 2, "to": "self"}]}},  # 12 回目：ブロックを外して AP1
		"big_shield": {"no": "K005", "group": "汎用・味方支援", "rarity": "common", "pool": "init", "owner": "knight", "name": "ビッグシールド", "type": "skill", "target": "self", "art": "c_big_shield", "ap": 2,
			"effects": [{"effect": "add_shield", "sld_pct": 280}]},
		"hone": {"no": "K006", "group": "汎用・味方支援", "rarity": "common", "pool": "init", "owner": "knight", "name": "研ぎ澄ます", "type": "skill", "target": "self", "art": "c_hone", "ap": 1,
			"effects": [{"effect": "add_shield", "sld_pct": 150}, {"effect": "draw", "eff_val": 1}]},  # 10 回目：素早さ+1 → 1 枚引く
		"flash": {"no": "K007", "group": "汎用・味方支援", "rarity": "common", "pool": "init", "owner": "knight", "name": "一閃", "type": "attack", "target": "front_row", "art": "c_flash", "pow_pct": 70, "ap": 1, "keywords": ["sokuou"],
			"bonus_sokuou": {"pow_pct": 80}},
		"chop": {"no": "K008", "group": "汎用・味方支援", "rarity": "common", "pool": "init", "owner": "knight", "name": "切り刻み", "type": "attack", "target": "front_pair", "art": "c_chop", "pow_pct": 140, "ap": 2, "on_kill": "reuse_free", "keywords": ["gekiha"]},
		"flurry": {"no": "K009", "group": "汎用・味方支援", "rarity": "common", "pool": "init", "owner": "knight", "name": "乱撃", "type": "attack", "target": "front_pair", "art": "c_flurry", "pow_pct": 75, "hits": 2, "ap": 1},
		"rampart": {"no": "K010", "group": "消費・廃棄・必殺技", "rarity": "common", "pool": "init", "owner": "knight", "name": "城壁", "type": "skill", "target": "self", "art": "c_rampart", "ap": 1, "keywords": ["consume"],
			"effects": [{"effect": "add_shield", "sld_pct": 200}, {"effect": "add_status", "status": "cover", "eff_val": 1, "turns": 1, "to": "self"}]},  # 12 回目：庇う（仕組みは B）
		"parry": {"no": "K011", "group": "挑発・ブロック攻撃", "rarity": "common", "pool": "init", "owner": "knight", "name": "受け流し", "type": "skill", "target": "front_row", "art": "c_parry", "ap": 1,
			"effects": [{"effect": "add_status", "status": "taunt", "eff_val": 0, "turns": 1}, {"effect": "add_shield", "sld_pct": 160, "to": "self"}]},
		"taunt": {"no": "K012", "group": "挑発・ブロック攻撃", "rarity": "common", "pool": "init", "owner": "knight", "name": "挑発", "type": "skill", "target": "front_enemy_group", "art": "c_taunt", "ap": 0,
			"effects": [{"effect": "add_status", "status": "taunt", "eff_val": 0, "turns": 1}, {"effect": "draw", "eff_val": 1, "to": "self"}]},
		# --- ウィッチ ---
		# 12 回目（D）：ウィッチのカードは設計表（design12/cards.csv）の通り。rarity＝4 段階、pool＝init / unlock / none
		"missile": {"no": "W001", "rarity": "common", "pool": "none", "group": "汎用・味方支援", "owner": "witch", "name": "マジックミサイル", "type": "attack", "target": "front_pair", "art": "star", "pow_pct": 100, "ap": 1},
		"firebolt": {"no": "W002", "rarity": "common", "pool": "init", "group": "汎用・味方支援", "owner": "witch", "name": "ファイアボルト", "type": "attack", "target": "enemy_all", "art": "flame", "pow_pct": 70, "ap": 2,
			"effects": [{"effect": "add_status", "status": "fire", "eff_val": 3}]},
		"sparks": {"no": "W003", "rarity": "common", "pool": "init", "group": "汎用・味方支援", "owner": "witch", "name": "魔法準備", "type": "skill", "target": "self", "art": "formation", "ap": 1, "keywords": ["yoyaku"],
			"effects": [{"effect": "rank_to", "eff_val": 1}],
			"bonus_yoyaku": {"effects": [{"effect": "add_ap", "eff_val": 1, "to": "self"}]}},
		"barrier": {"no": "W004", "rarity": "common", "pool": "none", "group": "汎用・味方支援", "owner": "witch", "name": "マジックバリア", "type": "skill", "target": "self", "art": "shield", "ap": 1,
			"effects": [{"effect": "add_shield", "sld_pct": 100}]},
		"chant": {"no": "W005", "rarity": "common", "pool": "init", "group": "陣形・即応・転身", "owner": "witch", "name": "高速詠唱", "type": "skill", "target": "self", "art": "chevrons", "ap": 0, "keywords": ["tenshin"],
			"effects": [{"effect": "add_shield", "sld_pct": 60}],
			"bonus_tenshin": {"effects": [{"effect": "add_ap", "eff_val": 1, "to": "self"}]}},
		"swap_card": {"no": "W006", "rarity": "common", "pool": "init", "group": "陣形・即応・転身", "owner": "witch", "name": "スワップ", "type": "skill", "target": "self", "art": "c_swap", "ap": 0,
			"effects": [{"effect": "swap"}]},
		"draw_magic": {"no": "W007", "rarity": "common", "pool": "init", "group": "汎用・味方支援", "owner": "witch", "name": "ドローマジック", "type": "attack", "target": "front_pair", "art": "c_draw_magic", "pow_pct": 125, "ap": 1,
			"effects": [{"effect": "draw", "eff_val": 1, "to": "self"}]},
		"hit_away": {"no": "W008", "rarity": "common", "pool": "init", "group": "陣形・即応・転身", "owner": "witch", "name": "ヒットアンドアウェイ", "type": "attack", "target": "front_pair", "art": "c_hit_away", "pow_pct": 140, "ap": 1,
			"effects": [{"effect": "swap", "to": "self"}]},
		"ap_pass": {"no": "W009", "rarity": "common", "pool": "init", "group": "汎用・味方支援", "owner": "witch", "name": "APパサー", "type": "skill", "target": "other_ally", "art": "c_ap_pass", "ap": 1,
			"effects": [{"effect": "add_ap", "eff_val": 1}]},
		"golem": {"no": "W010", "rarity": "common", "pool": "init", "group": "汎用・味方支援", "owner": "witch", "name": "ゴーレム", "type": "skill", "target": "self", "art": "c_golem", "ap": 1, "keywords": ["consume"],
			"effects": [{"effect": "add_shield", "sld_pct": 220}, {"effect": "add_stat", "stat": "sld", "eff_val": 3, "to": "self"}]},  # ブロックの後に SLD+3（戦闘中）
		"reblock": {"no": "W011", "rarity": "common", "pool": "init", "group": "汎用・味方支援", "owner": "witch", "name": "リブロック", "type": "skill", "target": "self", "art": "c_reblock", "ap": 1, "keywords": ["yoyaku"],
			"effects": [{"effect": "add_shield", "sld_pct": 80}],
			"bonus_yoyaku": {"effects": [{"effect": "add_shield", "sld_pct": 80, "to": "self"}]}},
		"drain": {"no": "W012", "rarity": "common", "pool": "init", "group": "毒・状態異常", "owner": "witch", "name": "ドレイン", "type": "attack", "target": "front_enemy_group", "art": "c_drain", "pow_pct": 130, "ap": 1, "keywords": ["gekiha"],
			"effects": [{"effect": "add_status", "status": "poison", "eff_val": 1}],
			"bonus_gekiha": {"effects": [{"effect": "add_ap", "eff_val": 1, "to": "self"}]}},  # 12 回目：倒すたび AP+1 → 撃破：AP+1（1 回）
		"absorb": {"no": "W013", "rarity": "common", "pool": "init", "group": "汎用・味方支援", "owner": "witch", "name": "アブソーブ", "type": "skill", "target": "front_enemy_group", "art": "c_absorb", "ap": 1,
			"effects": [{"effect": "add_status", "status": "pow_down", "eff_val": 2, "turns": 1}, {"effect": "add_stat", "stat": "pow", "eff_val": 1, "to": "self"}]},
		"poison_gas": {"no": "W014", "rarity": "common", "pool": "init", "group": "毒・状態異常", "owner": "witch", "name": "毒ガス", "type": "skill", "target": "front_enemy_group", "art": "c_poison_gas", "ap": 1,
			"effects": [{"effect": "add_status", "status": "poison", "eff_val": 4, "turns": 4}]},
		# --- 8 回目の新カード：ナイト ---
		"k_rand_thrust": {"no": "K013", "group": "自らの状態異常", "rarity": "common", "pool": "init", "owner": "knight", "name": "乱れ突き", "type": "attack", "target": "random_enemy", "art": "c_flurry", "pow_pct": 120, "hits": 3, "reroll": true, "ap": 1,
			"effects": [{"effect": "add_status", "status": "fire", "eff_val": 1, "to": "self"}]},
		"k_rear_raid": {"no": "K014", "group": "汎用・味方支援", "rarity": "common", "pool": "init", "owner": "knight", "name": "後方強襲", "type": "attack", "target": "back_row", "art": "dagger", "pow_pct": 140, "ap": 0},
		"k_sweep_leg": {"no": "K015", "group": "汎用・味方支援", "rarity": "common", "pool": "init", "owner": "knight", "name": "足払い", "type": "attack", "target": "front_enemy_group", "art": "def_debuff", "pow_pct": 150, "ap": 0,
			"keywords": ["saigo"], "saigo_only": true,
			"effects": [{"effect": "add_stat", "stat": "def", "eff_val": -1}]},
		"k_escort": {"no": "K016", "group": "汎用・味方支援", "rarity": "common", "pool": "init", "owner": "knight", "name": "護衛の構え", "type": "skill", "target": "other_ally", "art": "shield_sword", "ap": 1, "keywords": ["jinkei"],
			"bonus_left": {"effects": [{"effect": "add_shield", "sld_pct": 160}]},
			"bonus_right": {"effects": [{"effect": "add_shield", "sld_pct": 80}, {"effect": "draw", "eff_val": 1}]}},  # 10 回目：素早さ+2 → 1 枚引く
		"k_step_in": {"no": "K017", "group": "POW強化", "rarity": "common", "pool": "init", "owner": "knight", "name": "踏み込み", "type": "skill", "target": "self", "art": "formation", "ap": 0, "keywords": ["tenshin"],
			"effects": [{"effect": "rank_swap"}],
			"bonus": {"effects": [{"effect": "add_stat", "stat": "pow", "eff_val": 1, "to": "self"}, {"effect": "add_stat", "stat": "def", "eff_val": 1, "to": "self"}]}},  # 12 回目：POW+1・DEF+1（戦闘中）
		"k_reset": {"no": "K018", "group": "汎用・味方支援", "rarity": "common", "pool": "init", "owner": "knight", "name": "構え直し", "type": "skill", "target": "self", "art": "st_reblock", "ap": 0, "keywords": ["yoyaku"],
			"bonus_yoyaku": {"effects": [{"effect": "add_shield", "sld_pct": 200}]}},
		"k_iron_counter": {"no": "K019", "group": "挑発・ブロック攻撃", "rarity": "rare", "pool": "init", "owner": "knight", "name": "鉄壁の反撃", "type": "skill", "target": "self", "art": "c_rampart", "ap": 3, "keywords": ["hangeki"],
			"effects": [{"effect": "add_shield", "sld_pct": 320}],
			"bonus_hangeki": {"effects": [{"effect": "add_status", "status": "pow_down", "eff_val": 3, "turns": 1}]}},
		"k_all_guard": {"no": "K020", "group": "汎用・味方支援", "rarity": "common", "pool": "init", "owner": "knight", "name": "総員防御", "type": "skill", "target": "ally_all", "art": "c_big_shield", "ap": 1,
			"keywords": ["saigo"], "saigo_only": true,
			"effects": [{"effect": "add_shield", "sld_pct": 200}]},
		# --- 8 回目の新カード：ウィッチ ---
		"w_curse_mist": {"no": "W015", "rarity": "common", "pool": "init", "group": "汎用・味方支援", "owner": "witch", "name": "呪いの霧", "type": "attack", "target": "front_enemy_group", "art": "drop", "pow_pct": 130, "ap": 1,
			"effects": [{"effect": "add_status", "status": "no_heal", "eff_val": 1, "turns": 1}]},
		"w_starfall": {"no": "W016", "rarity": "rare", "pool": "init", "group": "陣形・即応・転身", "owner": "witch", "name": "星降り", "type": "attack", "target": "enemy_all", "art": "star", "pow_pct": 125, "ap": 1, "keywords": ["jinkei"],
			"bonus_left": {"text": "敵全体にPOW125%ダメージ"},
			"bonus_right": {"pow_pct": 15, "target": "front_row", "text": "前衛全体にPOW140%ダメージ"}},
		"w_twin_chant": {"no": "W017", "rarity": "common", "pool": "init", "group": "予約・AP・大技", "owner": "witch", "name": "二連詠唱", "type": "attack", "target": "front_enemy_group", "art": "c_double", "pow_pct": 130, "ap": 1,
			"ap_hits": {"min": 2, "hits": 2}},
		"w_hex": {"no": "W018", "rarity": "common", "pool": "init", "group": "汎用・味方支援", "owner": "witch", "name": "衰弱の呪い", "type": "skill", "target": "enemy_all", "art": "c_atk_down", "ap": 3,
			"effects": [{"effect": "add_status", "status": "pow_down", "eff_val": 4, "turns": 1}, {"effect": "add_status", "status": "def_down", "eff_val": 3, "turns": 1},
				{"effect": "add_status", "status": "no_heal", "eff_val": 1, "turns": 1}]},
		"w_light_lance": {"no": "W019", "rarity": "common", "pool": "init", "group": "予約・AP・大技", "owner": "witch", "name": "光の槍", "type": "attack", "target": "front_pair", "art": "target_one", "pow_pct": 540, "ap": 4},
		"w_flame_ward": {"no": "W020", "rarity": "common", "pool": "init", "group": "汎用・味方支援", "owner": "witch", "name": "炎の盾", "type": "skill", "target": "other_ally", "art": "c_fire_guard", "ap": 1,
			"effects": [{"effect": "add_shield", "sld_pct": 220}, {"effect": "add_status", "status": "fire", "eff_val": 1}]},
		# --- 10 回目の新カード（D）：ナイト K051〜K060。数値は仮 ---
		"k_self_burn": {"no": "K051", "group": "自らの状態異常", "rarity": "common", "pool": "init", "owner": "knight", "name": "焼身の構え", "type": "skill", "target": "self", "art": "flame", "ap": 1,
			"effects": [{"effect": "add_status", "status": "fire", "eff_val": 2, "to": "self"}, {"effect": "add_stat", "stat": "pow", "eff_val": 2, "to": "self"},
				{"effect": "draw", "eff_val": 1, "to": "self"}]},  # 12 回目：POW+2（戦闘中）・1 枚引く
		"k_flame_blade": {"no": "K052", "group": "自らの状態異常", "rarity": "common", "pool": "init", "owner": "knight", "name": "炎刃", "type": "attack", "target": "front_pair", "art": "sword", "pow_pct": 130, "ap": 1,
			"if_self_status": {"status": "fire", "pow_pct": 230}},
		"k_hot_pulse": {"no": "K053", "group": "自らの状態異常", "rarity": "common", "pool": "init", "owner": "knight", "name": "熱き鼓動", "type": "skill", "target": "self", "art": "heart", "ap": 0,
			"effects": [{"effect": "shield_per_status", "status": "fire", "sld_pct": 60}]},
		"k_shield_bash": {"no": "K054", "group": "挑発・ブロック攻撃", "rarity": "common", "pool": "init", "owner": "knight", "name": "盾打ち", "type": "attack", "target": "front_pair", "art": "shield_sword", "power": 0, "ap": 1,
			"power_block": true},  # 12 回目：自分のブロックと同じダメージ（ブロックは残る）
		"k_lure": {"no": "K055", "group": "挑発・ブロック攻撃", "rarity": "common", "pool": "init", "owner": "knight", "name": "引きつけ", "type": "skill", "target": "self", "art": "c_taunt", "ap": 1, "keywords": ["exhaust", "horyu"],
			"effects": [{"effect": "double_block", "to": "self"}]},  # 12 回目：今ある自分のブロックを 2 倍にするだけ（挑発なし）
		"k_shield_return": {"no": "K056", "group": "挑発・ブロック攻撃", "rarity": "rare", "pool": "init", "owner": "knight", "name": "盾の返し", "type": "skill", "target": "self", "art": "shield", "ap": 1, "keywords": ["hangeki"],
			"effects": [{"effect": "add_shield", "sld_pct": 100}],
			"bonus_hangeki": {"effects": [{"effect": "dmg_half_block"}]}},
		"k_immovable": {"no": "K057", "group": "汎用・味方支援", "rarity": "common", "pool": "init", "owner": "knight", "name": "不動", "type": "skill", "target": "self", "art": "c_big_shield", "ap": 1, "keywords": ["highcost"],
			"effects": [{"effect": "add_shield", "sld_pct": 150}]},  # 12 回目：最後 → ハイコスト
		"k_pawn": {"no": "K058", "group": "消費・廃棄・必殺技", "rarity": "common", "pool": "init", "owner": "knight", "name": "捨て石", "type": "skill", "target": "self", "art": "c_rampart", "ap": 0, "keywords": ["consume"],
			"effects": [{"effect": "add_shield", "sld_pct": 160}]},
		"k_ash_slash": {"no": "K059", "group": "消費・廃棄・必殺技", "rarity": "common", "pool": "init", "owner": "knight", "name": "灰燼斬", "type": "attack", "target": "front_enemy_group", "art": "sweep", "pow_pct": 130, "ap": 1,
			"per_exhaust_pct": 10},
		# K060 闘気溜め：csv は食事の札（食材の仕組みは次回）なので、札と動きは今のまま
		"k_charge_aura": {"no": "K060", "group": "消費・廃棄・必殺技", "rarity": "common", "pool": "init", "owner": "knight", "name": "闘気溜め", "type": "skill", "target": "self", "art": "chevrons", "ap": 1, "keywords": ["yoyaku"],
			"bonus_yoyaku": {"target": "self", "effects": [{"effect": "add_gauge", "eff_val": 15, "to": "self"}]}},
		# --- 12 回目の新カード：ナイト（コモン）。ステータス増減 add_stat・庇う cover の仕組みは B ---
		"k_gather": {"no": "K081", "group": "POW強化", "rarity": "common", "pool": "unlock", "owner": "knight", "name": "力溜め", "type": "skill", "target": "self", "art": "atk_buff", "ap": 1,
			"effects": [{"effect": "add_stat", "stat": "pow", "eff_val": 3, "to": "self"}]},
		"k_brace_slash": {"no": "K082", "group": "POW強化", "rarity": "common", "pool": "unlock", "owner": "knight", "name": "踏ん張り斬り", "type": "attack", "target": "front_pair", "art": "sword", "pow_pct": 135, "ap": 1,
			"effects": [{"effect": "add_stat", "stat": "pow", "eff_val": 1, "to": "self"}]},
		"k_fighting_aura": {"no": "K083", "group": "POW強化", "rarity": "common", "pool": "unlock", "owner": "knight", "name": "気炎", "type": "skill", "target": "self", "art": "flame", "ap": 0, "keywords": ["jinkei"],
			"bonus_left": {"effects": [{"effect": "shield_pow", "pow_pct": 30, "to": "self"}]},
			"bonus_right": {"effects": [{"effect": "add_stat", "stat": "sld", "eff_val": 4, "to": "self"}]}},
		"k_lend_shoulder": {"no": "K092", "group": "汎用・味方支援", "rarity": "common", "pool": "unlock", "owner": "knight", "name": "肩を貸す", "type": "skill", "target": "other_ally", "art": "heart", "ap": 1,
			"effects": [{"effect": "add_shield", "sld_pct": 120}, {"effect": "cleanse_one"}]},
		# --- 10 回目の新カード（D）：ウィッチ W051〜W060。数値は仮 ---
		"w_venom_mist": {"no": "W051", "rarity": "common", "pool": "init", "group": "毒・状態異常", "owner": "witch", "name": "毒霧", "type": "skill", "target": "front_row", "art": "c_poison_gas", "ap": 1,
			"effects": [{"effect": "add_status", "status": "poison", "eff_val": 2, "turns": 2}, {"effect": "add_shield", "sld_pct": 100, "to": "self"}]},
		"w_erode_needle": {"no": "W052", "rarity": "common", "pool": "init", "group": "毒・状態異常", "owner": "witch", "name": "侵食の針", "type": "attack", "target": "front_pair", "art": "dagger", "pow_pct": 120, "ap": 1,
			"vs_status": {"status": "poison", "pow_pct": 220}},
		"w_bind": {"no": "W053", "rarity": "rare", "pool": "init", "group": "毒・状態異常", "owner": "witch", "name": "呪縛", "type": "skill", "target": "random_enemy", "art": "c_atk_down", "ap": 1,
			"effects": [{"effect": "add_status", "status": "pow_down", "eff_val": 2, "turns": 1}, {"effect": "add_status", "status": "def_down", "eff_val": 2, "turns": 1}]},
		"w_mana_store": {"no": "W054", "rarity": "common", "pool": "init", "group": "予約・AP・大技", "owner": "witch", "name": "魔力の蓄え", "type": "skill", "target": "self", "art": "st_ap_next", "ap": 1, "keywords": ["yoyaku"],
			"bonus_yoyaku": {"effects": [{"effect": "add_ap", "eff_val": 2, "to": "self"}]}},
		"w_chant_stance": {"no": "W055", "rarity": "common", "pool": "init", "group": "予約・AP・大技", "owner": "witch", "name": "詠唱の構え", "type": "skill", "target": "self", "art": "star", "ap": 0, "keywords": ["yoyaku"],
			"bonus_yoyaku": {"effects": [{"effect": "add_status", "status": "chant", "eff_val": 6, "to": "self"}]}},
		"w_meditate": {"no": "W056", "rarity": "common", "pool": "init", "group": "汎用・味方支援", "owner": "witch", "name": "黙想", "type": "skill", "target": "self", "art": "c_meditate", "ap": 0,
			"keywords": ["highcost"],
			"effects": [{"effect": "add_ap", "eff_val": 2}]},  # 12 回目：最後 → ハイコスト（制限なし）
		"w_wind_dance": {"no": "W057", "rarity": "common", "pool": "init", "group": "陣形・即応・転身", "owner": "witch", "name": "風の舞", "type": "skill", "target": "self", "art": "formation", "ap": 1, "keywords": ["sokuou"],
			"effects": [{"effect": "rank_swap"}],
			"bonus_sokuou": {"effects": [{"effect": "add_shield", "sld_pct": 120, "to": "self"}]}},
		"w_formation_fire": {"no": "W058", "rarity": "rare", "pool": "init", "group": "陣形・即応・転身", "owner": "witch", "name": "陣の火球", "type": "attack", "target": "front_enemy_group", "art": "flame", "pow_pct": 125, "ap": 1, "keywords": ["jinkei"],
			"bonus_left": {"text": "目の前の敵グループにPOW125%ダメージ"},
			"bonus_right": {"pow_pct": 110, "target": "back_row", "text": "後衛全体にPOW235%ダメージ"}},
		"w_turn_arrow": {"no": "W059", "rarity": "epic", "pool": "init", "group": "陣形・即応・転身", "owner": "witch", "name": "転身の矢", "type": "attack", "target": "random_enemy", "art": "target_one", "pow_pct": 130, "ap": 1, "reroll": true,
			"keywords": ["tenshin"],
			"bonus_tenshin": {"hits": 2, "text": "もう1回（ランダムな敵を選び直す）"}},
		"w_signal": {"no": "W060", "rarity": "rare", "pool": "init", "group": "陣形・即応・転身", "owner": "witch", "name": "合図", "type": "skill", "target": "other_ally", "art": "c_ap_pass", "ap": 0, "keywords": ["sokuou"],
			"effects": [{"effect": "add_shield", "sld_pct": 60}],
			"bonus_sokuou": {"effects": [{"effect": "add_ap", "eff_val": 1}]}},
		# --- 12 回目の新カード（D）：ウィッチ（コモン）。add_stat・pow_down の仕組みは B ---
		"w_mana_shield": {"no": "W091", "rarity": "common", "pool": "unlock", "group": "汎用・味方支援", "owner": "witch", "name": "魔力の盾", "type": "skill", "target": "other_ally", "art": "shield", "ap": 1,
			"effects": [{"effect": "add_shield", "sld_pct": 120}, {"effect": "add_stat", "stat": "sld", "eff_val": 2}]},
		"w_link_magic": {"no": "W092", "rarity": "common", "pool": "unlock", "group": "汎用・味方支援", "owner": "witch", "name": "連携魔法", "type": "attack", "target": "front_pair", "art": "c_double", "pow_pct": 125, "ap": 1,
			"keywords": ["tenshin"],
			"bonus_tenshin": {"pow_pct": 125, "effects": [{"effect": "add_stat", "stat": "pow", "eff_val": -1}],
				"text": "さらにPOW125%ダメージ　当たった敵にPOW-1（戦闘中。敵のダメージ-1）"}},  # 転身：さらに POW125%、当たった敵に POW−1（敵のダメージ −1。戦闘中）
		"w_first_aid": {"no": "W093", "rarity": "common", "pool": "unlock", "group": "汎用・味方支援", "owner": "witch", "name": "応急手当", "type": "skill", "target": "other_ally", "art": "heart", "ap": 0, "keywords": ["kihatsu"],
			"effects": [{"effect": "add_shield", "sld_pct": 100}]},
	},
	"rare": {
		# --- ナイト ---
		"heavy": {"no": "K021", "group": "汎用・味方支援", "rarity": "rare", "pool": "init", "owner": "knight", "name": "重撃", "type": "attack", "target": "front_pair", "art": "sword", "pow_pct": 280, "ap": 2},
		"guard_all": {"no": "K022", "group": "汎用・味方支援", "rarity": "rare", "pool": "init", "owner": "knight", "name": "守護の陣", "type": "skill", "target": "ally_all", "art": "shield", "ap": 2, "keywords": ["horyu"],
			"effects": [{"effect": "add_shield", "sld_pct": 160}]},
		"fire_guard": {"no": "K023", "group": "挑発・ブロック攻撃", "rarity": "rare", "pool": "init", "owner": "knight", "name": "ファイアガード", "type": "skill", "target": "self", "art": "c_fire_guard", "ap": 2, "keywords": ["hangeki"],
			"effects": [{"effect": "add_shield", "sld_pct": 200}, {"effect": "add_status", "status": "fire_guard", "eff_val": 2, "turns": 1}]},
		"big_swing": {"no": "K024", "group": "汎用・味方支援", "rarity": "epic", "pool": "init", "owner": "knight", "name": "大振り", "type": "attack", "target": "front_pair", "art": "c_big_swing", "pow_pct": 420, "ap": 3},
		"store": {"no": "K025", "group": "汎用・味方支援", "rarity": "rare", "pool": "init", "owner": "knight", "name": "貯める", "type": "skill", "target": "self", "art": "c_store", "ap": 2,
			"effects": [{"effect": "add_shield", "sld_pct": 200}, {"effect": "add_stat", "stat": "def", "eff_val": 1, "to": "self"}]},  # 12 回目：次ターン AP を外して DEF+1（戦闘中）
		"focus": {"no": "K026", "group": "消費・廃棄・必殺技", "rarity": "rare", "pool": "init", "owner": "knight", "name": "精神統一", "type": "skill", "target": "self", "art": "c_focus", "ap": 1, "keywords": ["yoyaku"],
			"bonus_yoyaku": {"effects": [{"effect": "add_gauge", "eff_val": 20, "to": "self"}]}},  # 10 回目：必殺技 AP-1 → 予約：ゲージ+20（リーダー決定）
		# 12 回目：バリケードはパワーに（使った時に状態 barricade を付ける。説明は kind "barricade"）
		"barricade": {"no": "K027", "group": "挑発・ブロック攻撃", "rarity": "epic", "pool": "init", "owner": "knight", "name": "バリケード", "type": "power", "ap": 3, "target": "self", "art": "c_barricade",
			"keywords": ["power"], "power_effect": {"kind": "barricade", "once": [{"effect": "add_status", "status": "barricade", "eff_val": 1, "to": "self"}]}},
		"dance": {"no": "K028", "group": "消費・廃棄・必殺技", "rarity": "rare", "pool": "init", "owner": "knight", "name": "演舞", "type": "attack", "target": "enemy_all", "art": "c_dance", "pow_pct": 75, "hits": 3, "ap": 2, "keywords": ["consume"]},
		"declare": {"no": "K029", "group": "汎用・味方支援", "rarity": "rare", "pool": "init", "owner": "knight", "name": "宣言", "type": "skill", "target": "self", "art": "c_declare", "ap": 1, "keywords": ["yoyaku"],
			"effects": [{"effect": "add_status", "status": "declare", "eff_val": 3}]},
		"holy": {"no": "K030", "group": "汎用・味方支援", "rarity": "rare", "pool": "init", "owner": "knight", "name": "聖なる加護", "type": "skill", "target": "self", "art": "c_holy", "ap": 0, "keywords": ["exhaust"],
			"effects": [{"effect": "add_shield", "sld_pct": 120}]},  # 12 回目：APX → AP0・廃棄
		"steel": {"no": "K031", "group": "汎用・味方支援", "rarity": "epic", "pool": "init", "owner": "knight", "name": "鋼鉄化", "type": "power", "ap": 2,"target": "ally_all", "art": "c_steel",
			"keywords": ["power"], "power_effect": {"status": "def_up", "eff_val": 4, "all": true}},
		# --- ウィッチ ---
		"ice_lance": {"no": "W021", "rarity": "rare", "pool": "init", "group": "汎用・味方支援", "owner": "witch", "name": "氷の槍", "type": "attack", "target": "front_pair", "art": "snow", "pow_pct": 175, "ap": 1,
			"effects": [{"effect": "rank_swap"}]},
		"weaken": {"no": "W022", "rarity": "rare", "pool": "init", "group": "汎用・味方支援", "owner": "witch", "name": "アタックダウン", "type": "skill", "target": "enemy_all", "art": "c_atk_down", "ap": 1, "keywords": ["highcost"],
			"effects": [{"effect": "add_status", "status": "pow_down", "eff_val": 6, "turns": 1}]},  # 12 回目：消費・AP2 → ハイコスト・AP1
		"break_armor": {"no": "W023", "rarity": "rare", "pool": "init", "group": "汎用・味方支援", "owner": "witch", "name": "防御力低下", "type": "skill", "target": "front_enemy_group", "art": "c_def_down", "ap": 2, "keywords": ["tenshin"],
			"effects": [{"effect": "add_status", "status": "def_down", "eff_val": 1, "turns": 1}],
			"bonus_tenshin": {"effects": [{"effect": "add_status", "status": "def_down", "eff_val": 3, "turns": 1}]}},
		"meditate": {"no": "W024", "rarity": "rare", "pool": "init", "group": "予約・AP・大技", "owner": "witch", "name": "瞑想", "type": "skill", "target": "self", "art": "c_meditate", "ap": 2,
			"effects": [{"effect": "add_status", "status": "ap_plus", "eff_val": 1, "turns": 3}]},
		"quake": {"no": "W025", "rarity": "rare", "pool": "init", "group": "汎用・味方支援", "owner": "witch", "name": "アースクエイク", "type": "attack", "target": "front_row", "art": "c_quake", "pow_pct": 275, "ap": 2, "keywords": ["consume"]},
		"absorb_block": {"no": "W026", "rarity": "rare", "pool": "init", "group": "汎用・味方支援", "owner": "witch", "name": "ブロック吸収", "type": "skill", "target": "enemy_all", "art": "c_absorb_block", "ap": 0,
			"effects": [{"effect": "absorb_block"}]},  # 12 回目：消費の札を外した
		"energy": {"no": "W027", "rarity": "rare", "pool": "init", "group": "汎用・味方支援", "owner": "witch", "name": "エナジーチャージ", "type": "skill", "target": "self", "art": "c_energy", "ap": 0, "keywords": ["exhaust"],
			"effects": [{"effect": "add_ap", "eff_val": 2}]},  # 12 回目：消費の札を外した（廃棄だけ）
		# フォース（12 回目）：持ち主のターン開始時に、味方全体の SLD+1（戦闘中。毎ターン積み重なる）。kind turn_start_stat は Cont_Battle._power_turn_start
		"force": {"no": "W028", "rarity": "rare", "pool": "init", "group": "汎用・味方支援", "owner": "witch", "name": "フォース", "type": "power", "ap": 2,"target": "ally_all", "art": "c_force",
			"keywords": ["power"], "power_effect": {"kind": "turn_start_stat", "stat": "sld", "eff_val": 1}},
		# --- 12 回目の新カード（D）：ウィッチ（レア） ---
		"w_mana_share": {"no": "W094", "rarity": "rare", "pool": "unlock", "group": "汎用・味方支援", "owner": "witch", "name": "マナの共有", "type": "skill", "target": "other_ally", "art": "c_ap_pass", "ap": 1, "keywords": ["exhaust"],
			"effects": [{"effect": "add_ap", "eff_val": 1}, {"effect": "draw", "eff_val": 2, "to": "self"}]},
		# --- 8 回目の新カード：ナイト ---
		"k_reckless": {"no": "K032", "group": "自らの状態異常", "rarity": "rare", "pool": "init", "owner": "knight", "name": "捨て身斬り", "type": "attack", "target": "front_pair", "art": "c_big_swing", "pow_pct": 170, "ap": 1,
			"effects": [{"effect": "add_status", "status": "fire", "eff_val": 2, "to": "self"}]},
		"k_judgement": {"no": "K033", "group": "汎用・味方支援", "rarity": "rare", "pool": "init", "owner": "knight", "name": "断罪の剣", "type": "attack", "target": "front_enemy_group", "art": "c_full_strike", "pow_pct": 300, "ap": 3,
			"effects": [{"effect": "add_status", "status": "no_heal", "eff_val": 1, "turns": 2}]},
		"k_desperate": {"no": "K034", "group": "消費・廃棄・必殺技", "rarity": "rare", "pool": "init", "owner": "knight", "name": "決死の突撃", "type": "attack", "target": "back_row", "art": "skull", "pow_pct": 185, "ap": 1, "keywords": ["consume"],
			"effects": [{"effect": "add_status", "status": "fire", "eff_val": 1, "to": "self"}]},
		"k_devotion": {"no": "K035", "group": "汎用・味方支援", "rarity": "rare", "pool": "init", "owner": "knight", "name": "盾の献身", "type": "skill", "target": "other_ally", "art": "heart", "ap": 0, "keywords": ["exhaust", "yoyaku"],
			"effects": [{"effect": "add_shield", "sld_pct": 140}],
			"bonus_yoyaku": {"effects": [{"effect": "add_shield", "sld_pct": 140}]}},
		"k_burning_shield": {"no": "K036", "group": "自らの状態異常", "rarity": "rare", "pool": "init", "owner": "knight", "name": "灼熱の盾", "type": "skill", "target": "self", "art": "c_fire_guard", "ap": 1, "keywords": ["consume"],
			"effects": [{"effect": "add_shield", "sld_pct": 220}, {"effect": "add_status", "status": "fire", "eff_val": 1}]},
		"k_burning_spirit": {"no": "K037", "group": "自らの状態異常", "rarity": "rare", "pool": "init", "owner": "knight", "name": "燃える闘志", "type": "power", "ap": 2,"target": "self", "art": "flame",
			"keywords": ["power"], "power_effect": {"kind": "burn_atk"}},
		# 12 回目：守りの陣＝左にいる間 自分の SLD+10／右にいる間 DEF+3。鼓舞＝左にいる間 SLD+10（自分）／右にいる間 もう 1 人の POW+3
		"k_guard_stance": {"no": "K038", "group": "汎用・味方支援", "rarity": "rare", "pool": "init", "owner": "knight", "name": "守りの陣", "type": "power", "ap": 1,"target": "self", "art": "c_barricade",
			"keywords": ["power", "jinkei"], "power_effect": {
				"left": {"status": "sld_up", "eff_val": 10},
				"right": {"status": "def_up", "eff_val": 3}}},
		"k_rally": {"no": "K039", "group": "汎用・味方支援", "rarity": "rare", "pool": "init", "owner": "knight", "name": "鼓舞", "type": "power", "ap": 1,"target": "other_ally", "art": "atk_buff",
			"keywords": ["power", "jinkei"], "power_effect": {
				"left": {"status": "sld_up", "eff_val": 10},
				"right": {"aid_atk": 3}}},
		"k_fervor": {"no": "K040", "group": "汎用・味方支援", "rarity": "epic", "pool": "init", "owner": "knight", "name": "連撃の気迫", "type": "power", "ap": 2,"target": "enemy_all", "art": "c_dance",
			"keywords": ["power", "sokuou"], "power_effect": {"kind": "on_kw_card", "kws": ["sokuou", "tenshin"], "dmg": 3, "sokuou_add": 3}},
		# --- 12 回目の新カード：ナイト（レア） ---
		"k_strong_arm": {"no": "K084", "group": "POW強化", "rarity": "rare", "pool": "unlock", "owner": "knight", "name": "剛腕", "type": "attack", "target": "front_pair", "art": "c_big_swing", "pow_pct": 180, "ap": 2,
			"if_pow": {"min": 30, "pow_pct": 140}},
		"k_rising_aura": {"no": "K085", "group": "POW強化", "rarity": "rare", "pool": "unlock", "owner": "knight", "name": "闘気の昂り", "type": "power", "ap": 2, "target": "self", "art": "chevrons",
			"keywords": ["power"], "power_effect": {"kind": "turn_stat", "stat": "pow", "eff_val": 1}},
		"k_zanshin": {"no": "K086", "group": "POW強化", "rarity": "rare", "pool": "unlock", "owner": "knight", "name": "残心", "type": "attack", "target": "front_enemy_group", "art": "c_flash", "pow_pct": 140, "ap": 2, "keywords": ["yoyaku"],
			"bonus_yoyaku": {"target": "self", "effects": [{"effect": "add_stat", "stat": "pow", "eff_val": 5, "to": "self"}]}},
		"k_joint_attack": {"no": "K093", "group": "汎用・味方支援", "rarity": "rare", "pool": "unlock", "owner": "knight", "name": "連携攻撃", "type": "attack", "target": "front_pair", "art": "shield_sword", "pow_pct": 100, "ap": 1,
			"effects": [{"effect": "add_shield", "sld_pct": 70, "to": "other_ally"}]},
		"k_substitute": {"no": "K094", "group": "汎用・味方支援", "rarity": "rare", "pool": "unlock", "owner": "knight", "name": "身代わり", "type": "skill", "target": "self", "art": "c_stand", "ap": 1,
			"effects": [{"effect": "add_shield", "sld_pct": 120}, {"effect": "add_status", "status": "cover", "eff_val": 1, "turns": 1, "to": "self"}]},
		"k_tactical_eye": {"no": "K095", "group": "汎用・味方支援", "rarity": "rare", "pool": "unlock", "owner": "knight", "name": "戦術眼", "type": "skill", "target": "self", "art": "cards", "ap": 0,
			"effects": [{"effect": "draw", "eff_val": 1}, {"effect": "add_stat", "stat": "sld", "eff_val": 5, "to": "self"}]},
		# --- 8 回目の新カード：ウィッチ ---
		"w_homing": {"no": "W029", "rarity": "rare", "pool": "init", "group": "汎用・味方支援", "owner": "witch", "name": "追尾弾", "type": "attack", "target": "random_enemy", "art": "chevrons", "pow_pct": 175, "ap": 2, "keywords": ["gekiha"],
			"bonus_gekiha": {"effects": [{"effect": "repeat"}]}},
		"w_chain_bolt": {"no": "W030", "rarity": "epic", "pool": "init", "group": "汎用・味方支援", "owner": "witch", "name": "連鎖雷", "type": "attack", "target": "enemy_all", "art": "bolt", "pow_pct": 125, "hits": 2, "ap": 3, "keywords": ["gekiha"],
			"bonus_gekiha": {"effects": [{"effect": "add_ap", "eff_val": 3, "to": "self"}]}},
		# 終焉の光：「最後」の札が付いているので、今まで通り最後の時だけ使える（saigo_only）
		"w_last_light": {"no": "W031", "rarity": "legend", "pool": "init", "group": "陣形・即応・転身", "owner": "witch", "name": "終焉の光", "type": "attack", "target": "enemy_all", "art": "burst", "pow_pct": 125, "hits": 4, "ap": 2,
			"keywords": ["saigo", "jinkei"], "saigo_only": true,
			"bonus_left": {"text": "敵全体にPOW125%ダメージ×4回"},
			"bonus_right": {"target": "front_enemy_group", "hits": 5, "text": "目の前の敵グループにPOW125%ダメージ×5回"}},
		"w_magic_shot": {"no": "W032", "rarity": "epic", "pool": "init", "group": "陣形・即応・転身", "owner": "witch", "name": "魔弾", "type": "attack", "target": "random_enemy", "art": "c_energy", "pow_pct": 170, "ap": 0, "pre_rank": 0},
		# 聖域（12 回目）：もう 1 人の味方（ナイト）に SLD200% ブロック（使った人＝ウィッチの SLD）と庇う（1 ターン。仕組みは B）。最後の札は外した
		"w_sanctuary": {"no": "W033", "rarity": "rare", "pool": "init", "group": "汎用・味方支援", "owner": "witch", "name": "聖域", "type": "skill", "target": "other_ally", "art": "c_magic_wall", "ap": 2,
			"effects": [{"effect": "add_shield", "sld_pct": 200}, {"effect": "add_status", "status": "cover", "eff_val": 1, "turns": 1}]},
		"w_needle_storm": {"no": "W034", "rarity": "rare", "pool": "init", "group": "毒・状態異常", "owner": "witch", "name": "毒針の嵐", "type": "skill", "target": "random_enemy", "art": "c_poison_gas", "ap": 2, "hits": 5, "reroll": true,
			"hit_effects": [{"effect": "add_status", "status": "poison", "eff_val": 3}]},
		"w_corrode": {"no": "W035", "rarity": "legend", "pool": "init", "group": "毒・状態異常", "owner": "witch", "name": "腐食", "type": "attack", "target": "enemy_all", "art": "skull", "power": 0, "fixed": true, "power_from": "poison", "ap": 1},
		"w_venom_edge": {"no": "W036", "rarity": "epic", "pool": "init", "group": "毒・状態異常", "owner": "witch", "name": "毒の刃", "type": "power", "ap": 2,"target": "self", "art": "dagger",
			"keywords": ["power"], "power_effect": {"kind": "on_attack_poison", "eff_val": 1, "any_card": true}},  # 12 回目：アタックカードに限らず、当たった敵に
		"w_hex_guard": {"no": "W037", "rarity": "rare", "pool": "init", "group": "毒・状態異常", "owner": "witch", "name": "呪術の加護", "type": "power", "ap": 2,"target": "self", "art": "c_absorb",
			"keywords": ["power"], "power_effect": {"kind": "on_debuff_card", "shield": 2}},
		"w_flame_aura": {"no": "W038", "rarity": "rare", "pool": "init", "group": "汎用・味方支援", "owner": "witch", "name": "炎の守り", "type": "power", "ap": 2,"target": "other_ally", "art": "flame",
			"keywords": ["power"], "power_effect": {"kind": "on_own_card", "fire": 1, "shield": 7}},
		"w_hunter": {"no": "W039", "rarity": "rare", "pool": "init", "group": "汎用・味方支援", "owner": "witch", "name": "狩人の本能", "type": "power", "ap": 2,"target": "self", "art": "horns",
			"keywords": ["power"], "power_effect": {"kind": "on_gekiha_card", "kws": ["jinkei", "yoyaku"], "atk": 1}},  # 12 回目：攻撃力+1 → POW+1（add_stat。戦闘中。キー名は "atk" のまま）
		# --- 9 回目に超レアから移した（ウィッチ） ---
		"magic_wall": {"no": "W040", "rarity": "epic", "pool": "init", "group": "汎用・味方支援", "owner": "witch", "name": "マジックウォール", "type": "skill", "target": "ally_all", "art": "c_magic_wall", "ap": 2, "keywords": ["exhaust", "consume"],
			"effects": [{"effect": "add_shield", "sld_pct": 800}]},
	},
	"super_rare": {
		# --- ナイト ---
		"fighting": {"no": "K041", "group": "汎用・味方支援", "rarity": "epic", "pool": "init", "owner": "knight", "name": "闘志", "type": "skill", "target": "ally_all", "art": "atk_buff", "ap": 1,
			"effects": [{"effect": "cleanse"}]},
		"full_strike": {"no": "K042", "group": "汎用・味方支援", "rarity": "legend", "pool": "init", "owner": "knight", "name": "渾身の一撃", "type": "attack", "target": "front_enemy_group", "art": "c_full_strike", "pow_pct": 150, "ap": 3,
			"keywords": ["tenshin", "sokuou"], "bonus_tenshin": {"pow_pct": 150}, "bonus_sokuou": {"pow_pct": 150}},
		"stand": {"no": "K043", "group": "挑発・ブロック攻撃", "rarity": "epic", "pool": "init", "owner": "knight", "name": "仁王立ち", "type": "skill", "target": "enemy_all", "art": "c_stand", "ap": 3, "keywords": ["exhaust"],
			"effects": [{"effect": "add_status", "status": "taunt", "eff_val": 0, "turns": 1}, {"effect": "add_shield", "sld_pct": 1200, "to": "self"}]},
		"mushin": {"no": "K044", "group": "消費・廃棄・必殺技", "rarity": "epic", "pool": "init", "owner": "knight", "name": "無心乱舞", "type": "attack", "target": "front_row", "art": "c_mushin", "pow_pct": 140, "hits_x": true, "ap": 1, "ap_x": true,
			"keywords": ["exhaust"]},
		# --- ウィッチ ---
		# 豪炎（12 回目）：予約の札。bonus_yoyaku の "pow_pct"・"hits_x" ＝ 次の自分のターン開始時に、同じ対象へ POW%×X 回（X は使った時の X）
		"inferno": {"no": "W041", "rarity": "rare", "pool": "init", "group": "予約・AP・大技", "owner": "witch", "name": "豪炎", "type": "attack", "target": "enemy_all", "art": "c_inferno", "pow_pct": 25, "hits_x": true, "ap": 1, "ap_x": true,
			"keywords": ["yoyaku"],
			"bonus_yoyaku": {"pow_pct": 25, "hits_x": true, "text": "POW25%ダメージ×X回"}},
		"overload": {"no": "W042", "rarity": "epic", "pool": "init", "group": "予約・AP・大技", "owner": "witch", "name": "魔力暴走", "type": "attack", "target": "front_pair", "art": "c_overload", "pow_pct": 290, "ap": 3, "on_kill": "reuse_free", "keywords": ["gekiha"],
			"bonus_gekiha": {"effects": [{"effect": "add_ap", "eff_val": 3, "to": "self"}]}},
		"insight": {"no": "W043", "rarity": "epic", "pool": "init", "group": "汎用・味方支援", "owner": "witch", "name": "ひらめき", "type": "skill", "target": "self", "art": "cards", "ap": 0,
			"effects": [{"effect": "draw", "eff_val": 2}]},
		"double_cast": {"no": "W044", "rarity": "legend", "pool": "init", "group": "汎用・味方支援", "owner": "witch", "name": "連続魔法", "type": "skill", "target": "self", "art": "c_double", "ap": 1, "keywords": ["consume"],
			"effects": [{"effect": "double"}]},  # 12 回目：廃棄 → 消費
		# --- 8 回目の新カード：ナイト ---
		"k_finisher": {"no": "K045", "group": "汎用・味方支援", "rarity": "legend", "pool": "init", "owner": "knight", "name": "怒涛の締め", "type": "attack", "target": "front_pair", "art": "c_mushin", "pow_pct": 100, "hits_used": true, "ap": 0},  # 12 回目：最後の札を外した（制限なし）
		"k_thousand": {"no": "K046", "group": "POW強化", "rarity": "epic", "pool": "init", "owner": "knight", "name": "千本突き", "type": "attack", "target": "enemy_all", "art": "target_all", "pow_pct": 20, "hits": 6, "ap": 3},
		"k_command": {"no": "K047", "group": "汎用・味方支援", "rarity": "legend", "pool": "init", "owner": "knight", "name": "陣頭指揮", "type": "skill", "target": "ally_all", "art": "crown", "ap": 1, "keywords": ["jinkei"],
			"bonus_left": {"effects": [{"effect": "add_status", "status": "ap_plus", "eff_val": 1, "turns": 2, "to": "self"}]},
			"bonus_right": {"effects": [{"effect": "add_shield", "sld_pct": 140, "to": "other_ally"}]}},
		"k_last_stand": {"no": "K048", "group": "POW強化", "rarity": "epic", "pool": "init", "owner": "knight", "name": "背水の陣", "type": "power", "ap": 2,"target": "self", "art": "c_declare",
			"keywords": ["power"], "power_effect": {"kind": "last_stand"}},
		"k_scorched": {"no": "K049", "group": "消費・廃棄・必殺技", "rarity": "legend", "pool": "init", "owner": "knight", "name": "焦土の誓い", "type": "power", "ap": 1,"target": "enemy_all", "art": "burst",
			"keywords": ["power"], "power_effect": {"kind": "on_burn", "dmg": 5}},
		# 12 回目：天啓はスキル（廃棄）に
		"k_revelation": {"no": "K050", "group": "消費・廃棄・必殺技", "rarity": "epic", "pool": "init", "owner": "knight", "name": "天啓", "type": "skill", "ap": 2,"target": "ally_all", "art": "st_ap_plus",
			"keywords": ["exhaust"], "effects": [
				{"effect": "add_status", "status": "ap_plus", "eff_val": 1, "turns": 2, "to": "ally_all"}, {"effect": "add_ap", "eff_val": 2, "to": "ally_all"}]},
		# --- 12 回目の新カード：ナイト（エピック・レジェンド） ---
		#   if_pow            : {"min", "pow_pct"}。自分の POW が min 以上なら % を足す（剛腕。レアの段に置いた）
		#   per_pow_up_pct    : 自分の POW の増えた分（ActionController.stat_delta）1 につき % を足す（覇王の一撃）
		#   per_self_status_pct : {"statuses", "pow_pct"}。自分の状態の値の合計 1 につき % を足す（苦痛の糧）
		#   burn_all_pct      : 自分の火傷を全部消し、消した数値 1 につき % を足す（不死鳥の剣。火傷が無ければダメージ 0）
		#   power_block       : true なら power ＝ 自分のブロック（盾打ち・審判の大盾。ブロックは減らない）
		#   効果 shield_pow（POW × pow_pct のブロック。気炎）/ double_block（自分のブロックを 2 倍）/ cleanse_one（デバフを 1 つ解除）
		#   power_effect kind : turn_stat（自分のターン開始時に stat+eff_val）/ on_tick_dmg（状態異常のダメージを受けるたび、ランダムな敵に同じダメージ×hits）/
		#                       on_ally_attack（もう 1 人の味方がアタックカードを使うたび、味方全体にブロック+shield）/ barricade（説明用）
		"k_overlord": {"no": "K087", "group": "POW強化", "rarity": "legend", "pool": "unlock", "owner": "knight", "name": "覇王の一撃", "type": "attack", "target": "front_enemy_group", "art": "crown", "pow_pct": 150, "ap": 2,
			"keywords": ["highcost"], "per_pow_up_pct": 10},
		"k_hellfire_stance": {"no": "K088", "group": "自らの状態異常", "rarity": "epic", "pool": "unlock", "owner": "knight", "name": "業火の構え", "type": "power", "ap": 2, "target": "self", "art": "c_fire_guard",
			"keywords": ["power"], "power_effect": {"kind": "on_tick_dmg", "hits": 2}},
		"k_pain_feast": {"no": "K089", "group": "自らの状態異常", "rarity": "epic", "pool": "unlock", "owner": "knight", "name": "苦痛の糧", "type": "attack", "target": "front_enemy_group", "art": "skull", "pow_pct": 150, "ap": 2,
			"per_self_status_pct": {"statuses": ["fire", "poison"], "pow_pct": 10}},
		"k_phoenix": {"no": "K090", "group": "自らの状態異常", "rarity": "legend", "pool": "unlock", "owner": "knight", "name": "不死鳥の剣", "type": "attack", "target": "enemy_all", "art": "c_inferno", "pow_pct": 0, "ap": 2,
			"burn_all_pct": 50},
		"k_judge_shield": {"no": "K091", "group": "挑発・ブロック攻撃", "rarity": "legend", "pool": "unlock", "owner": "knight", "name": "審判の大盾", "type": "attack", "target": "front_enemy_group", "art": "c_big_shield", "power": 0, "ap": 2,
			"power_block": true, "effects": [{"effect": "add_status", "status": "taunt", "eff_val": 0, "turns": 1}]},
		"k_twin_oath": {"no": "K096", "group": "汎用・味方支援", "rarity": "epic", "pool": "unlock", "owner": "knight", "name": "双剣の誓い", "type": "power", "ap": 2, "target": "ally_all", "art": "shield_sword",
			"keywords": ["power"], "power_effect": {"kind": "on_ally_attack", "shield": 3}},
		"k_charge_horn": {"no": "K097", "group": "汎用・味方支援", "rarity": "epic", "pool": "unlock", "owner": "knight", "name": "突撃ラッパ", "type": "skill", "target": "ally_all", "art": "horns", "ap": 2,
			"effects": [{"effect": "add_status", "status": "pow_up", "eff_val": 5, "turns": 2}]},
		"k_knight_blade": {"no": "K098", "group": "汎用・味方支援", "rarity": "epic", "pool": "unlock", "owner": "knight", "name": "騎士の剛剣", "type": "attack", "target": "front_row", "art": "c_full_strike", "pow_pct": 370, "ap": 2,
			"keywords": ["kihatsu"]},
		"k_shield_wall": {"no": "K099", "group": "汎用・味方支援", "rarity": "epic", "pool": "unlock", "owner": "knight", "name": "盾の壁", "type": "skill", "target": "ally_all", "art": "c_magic_wall", "ap": 2, "keywords": ["horyu"],
			"effects": [{"effect": "add_shield", "sld_pct": 200}]},
		"k_royal_order": {"no": "K100", "group": "汎用・味方支援", "rarity": "legend", "pool": "unlock", "owner": "knight", "name": "王命", "type": "skill", "target": "other_ally", "art": "crown", "ap": 2, "keywords": ["kihatsu"],
			"effects": [{"effect": "add_ap", "eff_val": 3}, {"effect": "add_status", "status": "pow_up", "eff_val": 3, "turns": 2}]},
		# --- 8 回目の新カード：ウィッチ ---
		# 流星の煌めき（12 回目。旧 流星群）：AP5・保留。turn_discount ＝ 自分のターン開始時（手札の補充の後）に手札にあれば、
		#   このカードの AP を n 下げる（その戦闘中。カードの辞書の ap_down。0 まで）。使うと AP+3
		"w_meteor": {"no": "W045", "rarity": "epic", "pool": "init", "group": "予約・AP・大技", "owner": "witch", "name": "流星の煌めき", "type": "skill", "target": "self", "art": "c_inferno", "ap": 5,
			"keywords": ["horyu"], "turn_discount": 1,
			"effects": [{"effect": "add_ap", "eff_val": 3}]},
		"w_star_judge": {"no": "W046", "rarity": "legend", "pool": "init", "group": "予約・AP・大技", "owner": "witch", "name": "星の審判", "type": "attack", "target": "random_enemy", "art": "crown", "pow_pct": 135, "hits": 6, "reroll": true, "ap": 7,
			"hit_effects": [{"effect": "add_status", "status": "stun", "eff_val": 1, "if_damaged": true}]},
		"w_retribution": {"no": "W047", "rarity": "legend", "pool": "init", "group": "汎用・味方支援", "owner": "witch", "name": "断罪の連鎖", "type": "power", "ap": 2,"target": "random_enemy", "art": "c_drain",
			"keywords": ["power"], "power_effect": {"kind": "on_gekiha_hangeki", "power": 2, "hits": 5}},
		"w_herbalist": {"no": "W048", "rarity": "epic", "pool": "init", "group": "汎用・味方支援", "owner": "witch", "name": "薬師の加護", "type": "power", "ap": 2,"target": "self", "art": "item_herb",
			"keywords": ["power", "exhaust"], "power_effect": {"kind": "end_herb"}},
		"w_mana_convert": {"no": "W049", "rarity": "rare", "pool": "init", "group": "予約・AP・大技", "owner": "witch", "name": "魔力の転換", "type": "power", "ap": 2,"target": "self", "art": "c_meditate",
			"keywords": ["power", "consume"], "power_effect": {"kind": "end_convert"}},
		# --- 9 回目にレアから移した（ウィッチ） ---
		# 毒の雨（12 回目）：スキル。ダメージは無く、X 回 毒 3
		"w_toxic_rain": {"no": "W050", "rarity": "epic", "pool": "init", "group": "毒・状態異常", "owner": "witch", "name": "毒の雨", "type": "skill", "target": "front_row", "art": "st_poison", "hits_x": true, "ap": 1, "ap_x": true,
			"hit_effects": [{"effect": "add_status", "status": "poison", "eff_val": 3}]},
		# --- 12 回目の新カード（D）：ウィッチ（エピック・レジェンド） ---
		#   power_effect kind on_skill_card：スキルカードが発動するたび、発動したキャラにブロック（そのキャラの SLD × sld_pct）
		"w_ward": {"no": "W095", "rarity": "epic", "pool": "unlock", "group": "汎用・味方支援", "owner": "witch", "name": "守護結界", "type": "skill", "target": "ally_all", "art": "c_barricade", "ap": 2,
			"effects": [{"effect": "add_shield", "sld_pct": 160}, {"effect": "add_status", "status": "def_up", "eff_val": 2, "turns": 1}]},
		"w_haste": {"no": "W096", "rarity": "epic", "pool": "unlock", "group": "汎用・味方支援", "owner": "witch", "name": "加速の魔法", "type": "skill", "target": "other_ally", "art": "st_ap_plus", "ap": 1, "keywords": ["kihatsu"],
			"effects": [{"effect": "add_status", "status": "ap_plus", "eff_val": 1, "turns": 2}]},
		"w_enchant": {"no": "W097", "rarity": "epic", "pool": "unlock", "group": "汎用・味方支援", "owner": "witch", "name": "魔力付与", "type": "skill", "target": "other_ally", "art": "atk_buff", "ap": 1,
			"effects": [{"effect": "add_stat", "stat": "pow", "eff_val": 3}, {"effect": "add_stat", "stat": "sld", "eff_val": 3}]},
		"w_thunder": {"no": "W098", "rarity": "epic", "pool": "unlock", "group": "汎用・味方支援", "owner": "witch", "name": "雷鳴", "type": "attack", "target": "enemy_all", "art": "bolt", "pow_pct": 140, "ap": 2,
			"keywords": ["sokuou"],
			"bonus_sokuou": {"hits": 3, "text": "3回攻撃"}},
		"w_time_bless": {"no": "W099", "rarity": "legend", "pool": "unlock", "group": "汎用・味方支援", "owner": "witch", "name": "時の祝福", "type": "skill", "target": "ally_all", "art": "hourglass", "ap": 2,
			"keywords": ["exhaust", "yoyaku"],
			"effects": [{"effect": "cleanse"}],
			"bonus_yoyaku": {"target": "self", "effects": [{"effect": "add_ap", "eff_val": 2, "to": "self"}]}},
		"w_twin_circle": {"no": "W100", "rarity": "legend", "pool": "unlock", "group": "汎用・味方支援", "owner": "witch", "name": "双星の魔法陣", "type": "power", "ap": 3, "target": "self", "art": "star",
			"keywords": ["power"], "power_effect": {"kind": "on_skill_card", "sld_pct": 50}},
	},
}

## 必殺技（中央長押し。マップ画面でキャラごとに 1 つセット。9 回目で各キャラ 4 種）
## 10 回目：AP は使わず、必殺技ゲージが満タンの時に使える。使うと 0 に戻る
## 12 回目：上限は必殺技ごと（"gauge_max"。無ければ ActionController.GAUGE_MAX＝50。虚空連斬だけ 150）、
##   貯まり方も必殺技ごと（"gauge_by"：block＝得たブロック／targeted＝敵の攻撃の対象にされた時 +20／hp_lost＝自分のターン開始時に 最大HP−今のHP／
##   damage＝与えたダメージ／ap＝使った AP／move＝移動した時 +10／skill＝スキルカードを使うたび +10。Cont_Battle._gauge_on）。
##   "gauge_text" はその説明。"pool"：init＝最初から選べる／unlock＝ラスボスを倒すと 1 つずつ解放（SaveData）。% は specials.csv の通り（+100%）
## 必殺技だけの項目（実際に使う行動は Cont_Battle._special_play が作る）
##   desc       : 説明文（マップの選択画面・戦闘の説明帯）
##   left/right : 陣形の札。左（lane 0）／右（lane 1）に立っている時の行動（target・power・effects を上書き）
##   void_hits  : 虚空連斬。消費が発動した後の「手札 6 欄（4 枠＋空き欄 2）の空き数」× power_per ダメージ、× shield_per 自分にブロック
##   sokuou_only: 即応の条件（このラウンドに左右の入替をした）を満たした時だけ使える
##   poison_hits: 毒が付いた敵が 1 体でもいれば hits 回攻撃
##   効果 purge_self：自分のデバフ（火傷・毒・POWダウン・SLDダウン・DEFダウン・回復不可・スタン）を解除。
##                    火傷を解除した時、火傷の残りターン分 POW・DEF+（戦闘中。add_stat）
const SPECIAL_START := ["k_sp_formation", "k_sp_guard", "w_sp_explosion", "w_sp_turnskip"]
const SPECIALS = {
	"knight": [
		{"id": "k_sp_formation", "no": "KS01", "pool": "init", "name": "双陣斬", "type": "attack", "target": "front_pair", "art": "sweep", "keywords": ["jinkei"],
			"gauge_by": "block", "gauge_text": "得たブロックで貯まる",
			"pow_pct": 155,
			"left": {"type": "attack", "target": "front_pair", "pow_pct": 155},
			"right": {"type": "skill", "target": "ally_all", "effects": [{"effect": "add_shield", "sld_pct": 140}]},
			"desc": "陣形　左：目の前の敵前衛にPOW155%ダメージ／右：味方全体にブロック+SLD140%"},
		{"id": "k_sp_void", "no": "KS03", "pool": "unlock", "name": "虚空連斬", "type": "attack", "target": "enemy_all", "art": "c_mushin", "keywords": ["consume"],
			"gauge_by": "block", "gauge_max": 150, "gauge_text": "得たブロックで貯まる",
			"power": 0, "void_hits": {"pow_pct_per": 140, "sld_pct_per": 120},
			"desc": "消費　消費が発動した後、手札6欄の空き数×POW140%ダメージを敵全体に。自分に空き数×SLD120%ブロック"},
		{"id": "k_sp_purge", "no": "KS04", "pool": "unlock", "name": "浄化の誓い", "type": "skill", "target": "self", "art": "c_holy",
			"gauge_by": "hp_lost", "gauge_text": "自分のターン開始時に減っているHPの分貯まる",
			"effects": [{"effect": "purge_self"}],
			"desc": "自分のデバフを解除。火傷を解除した時、火傷の残りターン分 POW・DEF+（戦闘中）"},
		{"id": "k_sp_guard", "no": "KS02", "pool": "init", "name": "大防御", "type": "skill", "target": "self", "art": "shield",
			"gauge_by": "targeted", "gauge_text": "敵の攻撃の対象にされるたび+20",
			"effects": [{"effect": "add_shield", "sld_pct": 400}],
			"desc": "自分にブロック+SLD400%"},
	],
	"witch": [
		{"id": "w_sp_explosion", "no": "WS01", "pool": "init", "name": "爆発", "type": "attack", "target": "enemy_all", "art": "burst", "pow_pct": 170,
			"gauge_by": "damage", "gauge_text": "与えたダメージで貯まる",
			"desc": "敵全体にPOW170%ダメージ"},
		{"id": "w_sp_turnskip", "no": "WS02", "pool": "init", "name": "ターンスキップ", "type": "skill", "target": "self", "art": "hourglass",
			"gauge_by": "ap", "gauge_text": "使ったAPの分貯まる",
			"effects": [{"effect": "extra_turn"}],
			"desc": "ターン終了時、もう一度ターンを得る（追加ターンも開始時にAP+3・手札補充）"},
		{"id": "w_sp_stun", "no": "WS03", "pool": "unlock", "name": "星縛り", "type": "skill", "target": "random_enemy", "art": "star", "keywords": ["sokuou"],
			"gauge_by": "move", "gauge_text": "移動するたび+10（入替・前後の移動）",
			"sokuou_only": true, "effects": [{"effect": "add_status", "status": "stun", "eff_val": 1}],
			"desc": "即応　ランダムな敵1体にスタン1（即応の条件を満たした時だけ使える）"},
		{"id": "w_sp_venom", "no": "WS04", "pool": "unlock", "name": "毒蛇の舞", "type": "attack", "target": "front_enemy_group", "art": "st_poison", "pow_pct": 140,
			"gauge_by": "skill", "gauge_text": "スキルカードを使うたび+10",
			"poison_hits": 3,
			"desc": "目の前の敵グループにPOW140%ダメージ。毒が付いた敵がいれば3回攻撃"},
	],
}

## 入替（テンキー 7）
const SWAP = {"id": "swap", "name": "入替", "type": "skill", "target": "self", "art": "swap", "ap": 1, "effects": [{"effect": "swap"}]}

## 敵の行動。target は敵から見た向き：
##   front_enemy_single = 予告した側（左＝青／右＝赤）の味方（挑発されていれば挑発してきた味方）
##   enemy_all = 味方 2 人 / ally_all = 敵の仲間全員 / self
##   move = true なら、反対側へ移動してから攻撃する（狙う側も移動先の側になる）
const ENEMY_ACTIONS = {
	"club": {"name": "棍棒", "type": "attack", "target": "front_enemy_single", "power": 16},
	"claw": {"name": "引っかく", "type": "attack", "target": "front_enemy_single", "power": 18},
	"bite": {"name": "噛み付く", "type": "attack", "target": "front_enemy_single", "power": 16},
	"slash": {"name": "斬りつけ", "type": "attack", "target": "front_enemy_single", "power": 21},
	"gust": {"name": "突風", "type": "attack", "target": "enemy_all", "power": 11},
	"flank": {"name": "回り込み", "type": "attack", "target": "front_enemy_single", "power": 19, "move": true},
	"guard_self": {"name": "身構える", "type": "skill", "target": "self", "effects": [{"effect": "add_shield", "eff_val": 10}]},
	"guard_allies": {"name": "防御陣", "type": "skill", "target": "ally_all", "effects": [{"effect": "add_shield", "eff_val": 8}]},
	"burn_one": {"name": "火炎の爪", "type": "skill", "target": "front_enemy_single", "effects": [{"effect": "add_status", "status": "fire", "eff_val": 5}]},
	"burn_all": {"name": "炎の渦", "type": "skill", "target": "enemy_all", "effects": [{"effect": "add_status", "status": "fire", "eff_val": 4}]},
	"poison_spit": {"name": "毒液", "type": "skill", "target": "front_enemy_single", "effects": [{"effect": "add_status", "status": "poison", "eff_val": 4, "turns": 4}]},
	"war_cry": {"name": "雄叫び", "type": "skill", "target": "ally_all", "effects": [{"effect": "add_status", "status": "atk_buff", "eff_val": 3}]},
	"dark_slash": {"name": "闇の斬撃", "type": "attack", "target": "front_enemy_single", "power": 32},
	"dark_flank": {"name": "影走り", "type": "attack", "target": "front_enemy_single", "power": 29, "move": true},
	"big_guard": {"name": "鉄壁", "type": "skill", "target": "self", "effects": [{"effect": "add_shield", "eff_val": 18}]},
	"charge": {"name": "力を溜める", "type": "skill", "target": "self", "effects": [{"effect": "set_next_action", "next": "strong_attack"}]},
	"strong_attack": {"name": "強攻撃", "type": "attack", "target": "enemy_all", "power": 30},
	"breath": {"name": "炎の息", "type": "attack", "target": "enemy_all", "power": 21},
	"tail": {"name": "尻尾の一撃", "type": "attack", "target": "front_enemy_single", "power": 38},
	"dark_wave": {"name": "暗黒波", "type": "attack", "target": "enemy_all", "power": 19},
	"dark_heal": {"name": "闇の再生", "type": "skill", "target": "self", "effects": [{"effect": "heal", "eff_val": 24}]},

	# ---- 2 階：沈黙の回廊（9 回目・C。単体 12〜16／全体 9〜12） ----
	"hush_club": {"name": "黙打ち", "type": "attack", "target": "front_enemy_single", "power": 19},
	"hush_flank": {"name": "忍び寄り", "type": "attack", "target": "front_enemy_single", "power": 21, "move": true},
	"hush_guard": {"name": "口を閉ざす", "type": "skill", "target": "self", "effects": [{"effect": "add_shield", "eff_val": 12}]},
	"hush_rend": {"name": "裂き爪", "type": "attack", "target": "front_enemy_single", "power": 22},
	"mute_spit": {"name": "沈黙の毒液", "type": "skill", "target": "front_enemy_single", "effects": [{"effect": "add_status", "status": "poison", "eff_val": 4, "turns": 4}]},
	"vow_strike": {"name": "誓いの拳", "type": "attack", "target": "front_enemy_single", "power": 21},
	"vow_guard": {"name": "沈黙の誓い", "type": "skill", "target": "ally_all", "effects": [{"effect": "add_shield", "eff_val": 9}]},
	"bone_slash": {"name": "骨の刃", "type": "attack", "target": "front_enemy_single", "power": 22},
	"requiem": {"name": "鎮魂歌", "type": "attack", "target": "enemy_all", "power": 14},
	"stone_claw": {"name": "石の爪", "type": "attack", "target": "front_enemy_single", "power": 21},
	"stone_gust": {"name": "石礫の風", "type": "attack", "target": "enemy_all", "power": 14},
	"stone_dive": {"name": "急降下", "type": "attack", "target": "front_enemy_single", "power": 22, "move": true},
	"candle_flame": {"name": "蒼い灯火", "type": "skill", "target": "front_enemy_single", "effects": [{"effect": "add_status", "status": "fire", "eff_val": 5}]},
	"candle_wave": {"name": "燭台の揺らめき", "type": "attack", "target": "enemy_all", "power": 16},
	"candle_slash": {"name": "蝋の刃", "type": "attack", "target": "front_enemy_single", "power": 19},
	"silent_blade": {"name": "無音の剣", "type": "attack", "target": "front_enemy_single", "power": 26},
	"silent_flank": {"name": "影渡り", "type": "attack", "target": "front_enemy_single", "power": 24, "move": true},
	"silent_wall": {"name": "黙する鉄壁", "type": "skill", "target": "self", "effects": [{"effect": "add_shield", "eff_val": 24}]},
	"silent_charge": {"name": "息を潜める", "type": "skill", "target": "self", "effects": [{"effect": "set_next_action", "next": "silent_burst"}]},
	"silent_burst": {"name": "沈黙の波動", "type": "attack", "target": "enemy_all", "power": 19,
		"effects": [{"effect": "add_status", "status": "atk_down", "eff_val": 2, "turns": 2}]},
	"silent_vow": {"name": "静寂の誓い", "type": "skill", "target": "ally_all", "effects": [{"effect": "add_status", "status": "atk_buff", "eff_val": 2}]},
	"abbess_wave": {"name": "沈黙の讃歌", "type": "attack", "target": "enemy_all", "power": 18,
		"effects": [{"effect": "add_status", "status": "no_heal", "eff_val": 1, "turns": 2}]},
	"abbess_slash": {"name": "戒律の鞭", "type": "attack", "target": "front_enemy_single", "power": 26},
	"abbess_heal": {"name": "静かな祈り", "type": "skill", "target": "self", "effects": [{"effect": "heal", "eff_val": 30}]},
	"abbess_charge": {"name": "鐘を待つ", "type": "skill", "target": "self", "effects": [{"effect": "set_next_action", "next": "abbess_judgment"}]},
	"abbess_judgment": {"name": "沈黙の審判", "type": "attack", "target": "enemy_all", "power": 19,
		"effects": [{"effect": "add_status", "status": "def_down", "eff_val": 2, "turns": 2}]},
	"bell_breath": {"name": "鐘楼の息", "type": "attack", "target": "enemy_all", "power": 18,
		"effects": [{"effect": "add_status", "status": "fire", "eff_val": 3}]},
	"bell_tail": {"name": "青銅の尾", "type": "attack", "target": "front_enemy_single", "power": 26},
	"bell_toll": {"name": "弔いの鐘", "type": "skill", "target": "ally_all", "effects": [{"effect": "add_status", "status": "atk_buff", "eff_val": 2}]},
	"bell_charge": {"name": "鐘が鳴りだす", "type": "skill", "target": "self", "effects": [{"effect": "set_next_action", "next": "great_toll"}]},
	"great_toll": {"name": "大鐘の響き", "type": "attack", "target": "enemy_all", "power": 19,
		"effects": [{"effect": "add_status", "status": "atk_down", "eff_val": 2, "turns": 2}]},

	# ---- 3 階：星の大聖堂（単体 15〜20／全体 12〜15） ----
	"imp_strike": {"name": "小悪魔の槍", "type": "attack", "target": "front_enemy_single", "power": 24},
	"imp_flank": {"name": "回り込み突き", "type": "attack", "target": "front_enemy_single", "power": 26, "move": true},
	"imp_guard": {"name": "翼で守る", "type": "skill", "target": "self", "effects": [{"effect": "add_shield", "eff_val": 15}]},
	"censer_rend": {"name": "灰の爪", "type": "attack", "target": "front_enemy_single", "power": 27},
	"censer_smoke": {"name": "毒香", "type": "skill", "target": "enemy_all", "effects": [{"effect": "add_status", "status": "poison", "eff_val": 3, "turns": 3}]},
	"pilgrim_blow": {"name": "巡礼の杖", "type": "attack", "target": "front_enemy_single", "power": 29},
	"penance": {"name": "贖罪の祈り", "type": "skill", "target": "ally_all", "effects": [{"effect": "add_shield", "eff_val": 12}]},
	"star_spear": {"name": "星の槍", "type": "attack", "target": "front_enemy_single", "power": 27},
	"sentinel_guard": {"name": "番兵の盾", "type": "skill", "target": "self", "effects": [{"effect": "add_shield", "eff_val": 18}]},
	"glass_feather": {"name": "硝子の羽", "type": "attack", "target": "enemy_all", "power": 19},
	"glass_dive": {"name": "硝子の急降下", "type": "attack", "target": "front_enemy_single", "power": 27, "move": true},
	"glass_hymn": {"name": "光の聖歌", "type": "skill", "target": "ally_all", "effects": [{"effect": "add_shield", "eff_val": 12}]},
	"star_flare": {"name": "星の閃き", "type": "attack", "target": "front_enemy_single", "power": 24,
		"effects": [{"effect": "add_status", "status": "fire", "eff_val": 2}]},
	"astral_burn": {"name": "星炎の渦", "type": "skill", "target": "enemy_all", "effects": [{"effect": "add_status", "status": "fire", "eff_val": 4}]},
	"paladin_blade": {"name": "星の聖剣", "type": "attack", "target": "front_enemy_single", "power": 32},
	"paladin_flank": {"name": "天翔け", "type": "attack", "target": "front_enemy_single", "power": 29, "move": true},
	"paladin_aegis": {"name": "星の盾", "type": "skill", "target": "self", "effects": [{"effect": "add_shield", "eff_val": 30}]},
	"paladin_charge": {"name": "祈りを捧げる", "type": "skill", "target": "self", "effects": [{"effect": "set_next_action", "next": "paladin_meteor"}]},
	"paladin_meteor": {"name": "流星の裁き", "type": "attack", "target": "enemy_all", "power": 24,
		"effects": [{"effect": "add_status", "status": "fire", "eff_val": 3}]},
	"paladin_zeal": {"name": "聖戦の誓い", "type": "skill", "target": "ally_all", "effects": [{"effect": "add_status", "status": "atk_buff", "eff_val": 3}]},
	"star_breath": {"name": "星の息", "type": "attack", "target": "enemy_all", "power": 22},
	"star_tail": {"name": "星屑の尾", "type": "attack", "target": "front_enemy_single", "power": 32},
	"star_charge": {"name": "星を呑む", "type": "skill", "target": "self", "effects": [{"effect": "set_next_action", "next": "supernova"}]},
	"supernova": {"name": "超新星", "type": "attack", "target": "enemy_all", "power": 24,
		"effects": [{"effect": "add_status", "status": "fire", "eff_val": 4}]},
	"star_wing": {"name": "星の翼", "type": "skill", "target": "self", "effects": [{"effect": "add_shield", "eff_val": 30}]},
	"judgment": {"name": "断罪", "type": "attack", "target": "front_enemy_single", "power": 30},
	"dark_mass": {"name": "黒ミサ", "type": "attack", "target": "enemy_all", "power": 21,
		"effects": [{"effect": "add_status", "status": "no_heal", "eff_val": 1, "turns": 2}]},
	"bishop_heal": {"name": "偽りの奇跡", "type": "skill", "target": "self", "effects": [{"effect": "heal", "eff_val": 40}]},
	"rite_charge": {"name": "儀式の支度", "type": "skill", "target": "self", "effects": [{"effect": "set_next_action", "next": "last_rite"}]},
	"last_rite": {"name": "終油の秘跡", "type": "attack", "target": "enemy_all", "power": 24,
		"effects": [{"effect": "add_status", "status": "atk_down", "eff_val": 2, "turns": 2}]},

	# ---- ラスボス：堕ちた双星（単体 18〜28／全体 14〜18。第 2 段階で全体攻撃＋スタン） ----
	"blue_star": {"name": "蒼星の刃", "type": "attack", "target": "front_enemy_single", "power": 35,
		"effects": [{"effect": "add_status", "status": "def_down", "eff_val": 2, "turns": 2}]},
	"red_star": {"name": "紅星の槍", "type": "attack", "target": "front_enemy_single", "power": 38,
		"effects": [{"effect": "add_status", "status": "fire", "eff_val": 3}]},
	"twin_veil": {"name": "双星の帳", "type": "skill", "target": "self", "effects": [{"effect": "add_shield", "eff_val": 40}]},
	"star_rain": {"name": "星の雨", "type": "attack", "target": "enemy_all", "power": 22},
	"twin_charge": {"name": "双星が重なる", "type": "skill", "target": "self", "effects": [{"effect": "set_next_action", "next": "twin_doom"}]},
	"twin_doom": {"name": "双星の終焉", "type": "attack", "target": "enemy_all", "power": 29,
		"effects": [{"effect": "add_status", "status": "stun", "eff_val": 1}]},
	"fallen_comet": {"name": "堕ちる彗星", "type": "attack", "target": "front_enemy_single", "power": 45},
	"eclipse_rain": {"name": "蝕の流星雨", "type": "attack", "target": "enemy_all", "power": 26,
		"effects": [{"effect": "add_status", "status": "fire", "eff_val": 3}]},
}


## 効果の配列（"effects" が無い古い形の行動にも対応）
static func effects_of(a: Dictionary) -> Array:
	if a.has("effects"):
		return a.effects
	if a.has("effect"):
		return [{"effect": a.effect, "eff_val": a.get("eff_val", 0), "status": a.get("status", ""), "turns": a.get("turns", -1),
				"next": a.get("next", ""), "to": a.get("effect_target", "target")}]
	return []


static func has_keyword(a: Dictionary, k: String) -> bool:
	return a.get("keywords", []).has(k)


## カードIDからカード辞書（rarity・id 付きのコピー）を作る。
## "カードID@バッジID" ならバッジ付き（c.badge = バッジID、c.deck_id = 元の文字列。c.id はカードIDだけ）
static func make_card(card_id: String) -> Dictionary:
	var base := base_id(card_id)
	var badge := badge_of(card_id)
	for rarity in ALLY_CARDS:  # 見出し（common / rare / super_rare …）。カードのレア度はデータの "rarity" が正（12 回目）
		if ALLY_CARDS[rarity].has(base):
			var c: Dictionary = ALLY_CARDS[rarity][base].duplicate(true)
			if c.has("pow_pct") and not c.has("power"):
				c["power"] = 0  # 11 回目：POW% の攻撃も "power"（固定の上乗せ）を持たせてアタックとして扱う
			c["id"] = base
			c["deck_id"] = card_id
			c["rarity"] = norm_rarity(c.get("rarity", rarity))  # 12 回目：common / rare / epic / legend の 4 段階にそろえる
			if not c.has("keywords"):
				c["keywords"] = []
			if badge != "" and BadgeList.DATA.has(badge):
				c["badge"] = badge
			return c
	return {}


## "カードID@バッジID" → カードID
static func base_id(deck_id: String) -> String:
	var i := deck_id.find("@")
	return deck_id if i < 0 else deck_id.substr(0, i)


## "カードID@バッジID" → バッジID（無ければ ""）
static func badge_of(deck_id: String) -> String:
	var i := deck_id.find("@")
	return "" if i < 0 else deck_id.substr(i + 1)


static func with_badge(deck_id: String, badge_id: String) -> String:
	return base_id(deck_id) + ("@" + badge_id if badge_id != "" else "")


static func owner_of(card_id: String) -> String:
	return make_card(card_id).get("owner", "knight")


## 報酬・宝箱・ショップ用：レア以上のカードID
static func random_rare_id(owner: String = "") -> String:
	return random_card_id("rare", owner)


## バッジ付きのカードID（付けられるバッジをランダムに。付けられなければバッジなし）
static func random_badged_id(min_tier: String = "", owner: String = "") -> String:
	var cid := random_card_id(min_tier, owner)
	var c := make_card(cid)
	var ok: Array = BadgeList.DATA.keys().filter(func(b): return BadgeList.can_attach(b, c))
	return cid if ok.is_empty() else with_badge(cid, ok.pick_random())


## 報酬用にランダムなカードIDを選ぶ（12 回目・C：コモン:レア:エピック:レジェンド＝50:25:10:5。解放済みのカードだけ）。
## min_tier＝これ以上のレア度だけ（"rare"・"epic"。古い "super_rare" はエピック以上）。owner・type を指定するとそれだけ。except は出さない。
## 条件に合うカードが無い時は、type → owner → min_tier の順に条件を外す
static func random_card_id(min_tier: String = "", owner: String = "", type: String = "", except: Array = []) -> String:
	var min_i := 0 if min_tier == "" else RARITIES.find(norm_rarity(min_tier))
	var table := drop_table(min_i, owner, type, except)
	if table.is_empty() and type != "":
		table = drop_table(min_i, owner, "", except)
	if table.is_empty() and owner != "":
		table = drop_table(min_i, "", "", except)
	if table.is_empty() and min_i > 0:
		table = drop_table(0, owner, "", except)
	if table.is_empty():
		table = drop_table(0, "", "", [])
	if table.is_empty():
		return str(card_ids()[0])
	var total := 0
	for r in table:
		total += int(RARITY_WEIGHT[r])
	var roll := randi() % total
	for r in RARITIES:
		if table.has(r):
			roll -= int(RARITY_WEIGHT[r])
			if roll < 0:
				var ids: Array = table[r]
				return str(ids[randi() % ids.size()])
	return str(card_ids()[0])


# ============================================================
# 12 回目（C）：レア度 4 段階・排出（pool）・カードの解放
# ============================================================
## レア度（低い順）。データの "rarity"。古い値（normal・super_rare など）は norm_rarity で読み替える
const RARITIES := ["common", "rare", "epic", "legend"]
const RARITY_NAME := {"common": "コモン", "rare": "レア", "epic": "エピック", "legend": "レジェンド"}
## 報酬・ショップ・イベントでの出やすさ（比）
const RARITY_WEIGHT := {"common": 50, "rare": 25, "epic": 10, "legend": 5}
## 解放した "pool": "unlock" のカード ID（値は true）。SaveData が周回をまたぐ記録（user://unlock.json）から入れる
static var unlocked_cards: Dictionary = {}


## レア度の値を 4 段階にそろえる（古い normal → common、super_rare → epic。知らない値は common）
static func norm_rarity(v: Variant) -> String:
	match str(v):
		"rare": return "rare"
		"epic", "super_rare", "super", "sr": return "epic"
		"legend", "legendary": return "legend"
	return "common"


## レア度の番号（0＝コモン 〜 3＝レジェンド）
static func rarity_rank(v: Variant) -> int:
	return RARITIES.find(norm_rarity(v))


## カードのデータ（コピーしない。読むだけ）。無ければ空
static func card_raw(card_id: String) -> Dictionary:
	var base := base_id(card_id)
	for sec in ALLY_CARDS:
		var d: Dictionary = ALLY_CARDS[sec]
		if d.has(base):
			return d[base]
	return {}


## 全カードの ID
static func card_ids() -> Array:
	var out: Array = []
	for sec in ALLY_CARDS:
		var d: Dictionary = ALLY_CARDS[sec]
		out.append_array(d.keys())
	return out


## カードのレア度（データの "rarity"。無ければ見出しから）
static func rarity_of(card_id: String) -> String:
	var base := base_id(card_id)
	for sec in ALLY_CARDS:
		var d: Dictionary = ALLY_CARDS[sec]
		if d.has(base):
			var c: Dictionary = d[base]
			return norm_rarity(c.get("rarity", sec))
	return "common"


## 排出：init＝初期から／unlock＝解放されてから／none＝報酬に出ない。データに無ければ init
static func pool_of(card_id: String) -> String:
	var p := str(card_raw(card_id).get("pool", "init"))
	return p if p in ["init", "unlock", "none"] else "init"


## グループ名（データの "group"。無ければ No. から CardGroupList の表で引く。どちらも無ければ ""）
static func group_of(card_id: String) -> String:
	var c := card_raw(card_id)
	var g := str(c.get("group", ""))
	return g if g != "" else CardGroupList.of_no(str(c.get("no", "")))


## 報酬・ショップ・イベントに出るカードか（init、または解放済みの unlock）
static func can_drop(card_id: String) -> bool:
	var base := base_id(card_id)
	match pool_of(base):
		"init": return true
		"unlock": return unlocked_cards.has(base)
	return false


## まだ解放していないカード（"pool": "unlock" で未解放）か。カード一覧の表示用
static func is_card_locked(card_id: String) -> bool:
	var base := base_id(card_id)
	return pool_of(base) == "unlock" and not unlocked_cards.has(base)


## まだ解放していないカードの ID
static func locked_card_ids() -> Array:
	return card_ids().filter(func(k): return is_card_locked(str(k)))


## 出せるカードをレア度ごとに分けた表 {レア度: [ID…]}（カードが無いレア度は入らない）
static func drop_table(min_i: int, owner: String, type: String, except: Array) -> Dictionary:
	var out := {}
	for sec in ALLY_CARDS:
		var d: Dictionary = ALLY_CARDS[sec]
		for k in d:
			var c: Dictionary = d[k]
			if (owner != "" and str(c.get("owner", "")) != owner) or (type != "" and str(c.get("type", "")) != type):
				continue
			if except.has(k) or not can_drop(str(k)):
				continue
			var r := norm_rarity(c.get("rarity", sec))
			if RARITIES.find(r) < min_i:
				continue
			if not out.has(r):
				out[r] = []
			(out[r] as Array).append(str(k))
	return out


## 必殺技の排出：init＝最初から選べる／unlock＝ラスボスを倒すと 1 つずつ解放。データに無ければ SPECIAL_START かどうか
static func special_pool(special_id: String) -> String:
	for ch in SPECIALS:
		for s in SPECIALS[ch]:
			if str(s.id) == special_id:
				var p := str(s.get("pool", ""))
				if p in ["init", "unlock"]:
					return p
	return "init" if SPECIAL_START.has(special_id) else "unlock"


static func special(char_id: String, special_id: String) -> Dictionary:
	for s in SPECIALS[char_id]:
		if s.id == special_id:
			return s
	return SPECIALS[char_id][0]


## 必殺技の ID の一覧（両キャラ）
static func special_ids() -> Array:
	var out: Array = []
	for ch in ["knight", "witch"]:
		for s in SPECIALS[ch]:
			out.append(str(s.id))
	return out


## 必殺技の ID → 持ち主（無ければ ""）
static func special_owner(special_id: String) -> String:
	for ch in ["knight", "witch"]:
		for s in SPECIALS[ch]:
			if s.id == special_id:
				return ch
	return ""
