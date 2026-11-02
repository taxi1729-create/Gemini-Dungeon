extends SceneTree
func _init():
	var files = []
	_walk("res://index/core", files)
	for f in files:
		var s = load(f)
	print("[check] loaded ", files.size(), " scripts")
	quit()
func _walk(d, out):
	var da = DirAccess.open(d)
	for f in da.get_files():
		if f.ends_with(".gd"): out.append(d + "/" + f)
	for sub in da.get_directories(): _walk(d + "/" + sub, out)
