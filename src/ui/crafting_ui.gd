extends CanvasLayer

@onready var panel = $Panel
@onready var recipes_container = $Panel/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer

# Simple recipe system
var recipes = [
	{
		"output": "iron_sword",
		"output_amount": 1,
		"ingredients": {
			"stone": 5,
			"wood": 2
		}
	},
	{
		"output": "iron_axe",
		"output_amount": 1,
		"ingredients": {
			"stone": 3,
			"wood": 3
		}
	},
	{
		"output": "iron_spear",
		"output_amount": 1,
		"ingredients": {
			"stone": 2,
			"wood": 4
		}
	}
]

func _ready():
	hide()
	$Panel/MarginContainer/VBoxContainer/CloseButton.pressed.connect(hide)
	
func toggle_ui():
	visible = !visible
	if visible:
		refresh_ui()

func refresh_ui():
	for child in recipes_container.get_children():
		child.queue_free()
		
	for recipe in recipes:
		var recipe_panel = create_recipe_ui(recipe)
		recipes_container.add_child(recipe_panel)

func create_recipe_ui(recipe: Dictionary) -> Control:
	var hbox = HBoxContainer.new()
	
	var output_data = Global.get_item_data(recipe.output)
	if not output_data: return hbox
	
	# Output Icon
	var out_tex = TextureRect.new()
	out_tex.texture = output_data.texture
	out_tex.custom_minimum_size = Vector2(32, 32)
	out_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	out_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hbox.add_child(out_tex)
	
	# Output Label
	var out_label = Label.new()
	out_label.text = output_data.name
	out_label.custom_minimum_size = Vector2(100, 0)
	hbox.add_child(out_label)
	
	# Ingredients Label
	var ing_label = Label.new()
	var ing_text = "Requires: "
	var can_craft = true
	
	for req_id in recipe.ingredients.keys():
		var req_amount = recipe.ingredients[req_id]
		var req_data = Global.get_item_data(req_id)
		var has_amount = _count_player_item(req_id)
		
		var color = "green" if has_amount >= req_amount else "red"
		ing_text += "[color=%s]%s %s[/color]  " % [color, str(req_amount), req_data.name]
		
		if has_amount < req_amount:
			can_craft = false
			
	var rt_label = RichTextLabel.new()
	rt_label.bbcode_enabled = true
	rt_label.text = ing_text
	rt_label.custom_minimum_size = Vector2(200, 32)
	rt_label.fit_content = true
	hbox.add_child(rt_label)
	
	# Craft Button
	var btn = Button.new()
	btn.text = "Craft"
	btn.disabled = !can_craft
	btn.pressed.connect(func(): _craft_item(recipe))
	hbox.add_child(btn)
	
	return hbox

func _count_player_item(item_id: String) -> int:
	if not Global.item_database.has(item_id): return 0
	var type = Global.item_database[item_id].type
	for item in Global.inventory[type]:
		if item.id == item_id:
			return item.amount
	return 0

func _craft_item(recipe: Dictionary):
	# Deduct ingredients
	for req_id in recipe.ingredients.keys():
		Global.remove_item(req_id, recipe.ingredients[req_id])
		
	# Add output
	Global.add_item(recipe.output, recipe.output_amount)
	
	# Refresh UI to update colors and buttons
	refresh_ui()
