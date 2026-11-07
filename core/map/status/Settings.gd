extends Node
## Settings（Autoload）
## 遊び方の設定（今は演出ライトモードだけ）。user://settings.json に保存する。
## セーブデータ（user://save.json）とは別のファイルなので、セーブを消しても設定は残る。
## 読み込んだ値は ImageController.light_mode に入れる（演出の各所はそちらを見る）。

const PATH := "user://settings.json"

var light_mode := false


func _ready() -> void:
	load_settings()


## ファイルから読み込む（無い・壊れている時は既定値のまま）
func load_settings() -> void:
	light_mode = false
	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if d is Dictionary:
				light_mode = bool((d as Dictionary).get("light_mode", false))
	ImageController.light_mode = light_mode


## ライトモードを切り替えて保存する
func set_light_mode(on: bool) -> void:
	light_mode = on
	ImageController.light_mode = on
	save_settings()


func save_settings() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("設定を保存できませんでした: %s" % PATH)
		return
	f.store_string(JSON.stringify({"light_mode": light_mode}))
	f.close()  # Web 版は close した時に IndexedDB へ書き出される
