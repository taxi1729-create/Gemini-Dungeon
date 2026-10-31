extends Node2D
## 休憩所：食材を使ってHPを回復する

var status_label: Label
var buttons: Array = []


func _ready() -> void:
	CurrentStatus.ensure_started()
	add_child(GuiBackground.new("camp"))
	var ui := CanvasLayer.new()
	add_child(ui)
	var col: Dictionary = ImageController.COL
	UiSystem.make_label(ui, "休憩所", Vector2(0, 60), Vector2(720, 70), 48, col.gold)
	UiSystem.make_label(ui, "焚き火で食事をとって体を休めよう", Vector2(0, 130), Vector2(720, 40), 22, col.sub)
	status_label = UiSystem.make_label(ui, "", Vector2(60, 190), Vector2(600, 120), 26, col.text)
	buttons.append(UiSystem.make_button(ui, "小回復（全員HP+10・食材2）", Vector2(90, 1000), Vector2(540, 76), _heal.bind(10, 2), 26))
	buttons.append(UiSystem.make_button(ui, "大回復（全員全回復・食材5）", Vector2(90, 1088), Vector2(540, 76), _heal.bind(999, 5), 26))
	buttons.append(UiSystem.make_button(ui, "仮眠（全員HP+4・食材なし）", Vector2(90, 1176), Vector2(540, 76), _heal.bind(4, 0), 26))
	_refresh()


func _refresh() -> void:
	var lines: Array = []
	for a in CurrentStatus.allies:
		lines.append("%s　HP %d / %d" % [a.name, a.hp, a.max_hp])
	lines.append("食材 %d 個" % Inventory.food_total())
	status_label.text = "\n".join(lines)
	buttons[0].disabled = Inventory.food_total() < 2
	buttons[1].disabled = Inventory.food_total() < 5


func _heal(amount: int, cost: int) -> void:
	if not Inventory.consume_random_food(cost):
		return
	for a in CurrentStatus.allies:
		a["hp"] = mini(int(a.max_hp), maxi(1, int(a.hp)) + amount)
	for b in buttons:
		b.disabled = true
	_refresh()
	for b in buttons:
		b.disabled = true
	UiSystem.toast(self, "体力が回復した！", 560, ImageController.COL.good)
	await get_tree().create_timer(1.2).timeout
	UiSystem.goto("map")
