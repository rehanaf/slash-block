extends CanvasLayer

signal quick_slot_changed(slot_index, item_id)

@onready var quickbar = $MarginContainer/HBoxContainer/QuickSlots
@onready var inv_button = $MarginContainer/HBoxContainer/InventoryButton
@onready var inventory_panel = $InventoryPanel
@onready var item_grid = $InventoryPanel/MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var tab_container = $InventoryPanel/MarginContainer/VBoxContainer/TabContainer

var current_tab = "weapon"

func _ready():
	inventory_panel.hide()
	
	# Setup inventory button
	inv_button.pressed.connect(toggle_inventory)
	
	# Setup tabs
	for i in range(tab_container.get_tab_count()):
		tab_container.set_tab_title(i, ["Weapon", "Material", "Food"][i])
	tab_container.tab_changed.connect(_on_tab_changed)
	
	update_quickbar()

func update_quickbar():
	for i in range(4):
		var slot_node = quickbar.get_child(i)
		var item_id = Global.quick_slots[i]
		var icon_rect = slot_node.get_node("Icon")
		
		# Highlight active slot
		var bg = slot_node.get_node("BG")
		if i == Global.active_quick_slot:
			bg.color = Color(0.3, 0.6, 0.9, 0.8) # Active color
		else:
			bg.color = Color(0.1, 0.1, 0.1, 0.6) # Inactive color
		
		if item_id != "":
			var data = Global.get_item_data(item_id)
			if data and data.has("texture"):
				icon_rect.texture = load(data.texture)
				icon_rect.show()
			else:
				icon_rect.hide()
		else:
			icon_rect.hide()

func toggle_inventory():
	inventory_panel.visible = !inventory_panel.visible
	if inventory_panel.visible:
		refresh_inventory_grid()

func _on_tab_changed(tab_idx):
	var tabs = ["weapon", "material", "food"]
	current_tab = tabs[tab_idx]
	refresh_inventory_grid()

func refresh_inventory_grid():
	# Clear existing items
	for child in item_grid.get_children():
		child.queue_free()
		
	# Populate based on current tab
	var items = Global.inventory[current_tab]
	for item in items:
		var slot = create_item_slot(item)
		item_grid.add_child(slot)

func create_item_slot(item_data):
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(48, 48)
	
	# Background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	style.set_border_width_all(1)
	style.border_color = Color(0.3, 0.3, 0.3)
	panel.add_theme_stylebox_override("panel", style)
	
	# Icon
	var tr = TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture = load(item_data.texture)
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.offset_left = 4
	tr.offset_top = 4
	tr.offset_right = -4
	tr.offset_bottom = -4
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(tr)
	
	# Amount label
	if item_data.has("amount") and item_data.amount > 1:
		var label = Label.new()
		label.text = str(item_data.amount)
		label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 4)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(label)
		
	# Connect click event directly to panel
	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_inventory_item_clicked(item_data)
	)
	
	return panel

func _on_inventory_item_clicked(item_data):
	if item_data.type == "weapon":
		# Assign to current quick slot
		Global.quick_slots[Global.active_quick_slot] = item_data.id
		update_quickbar()
		quick_slot_changed.emit(Global.active_quick_slot, item_data.id)

func select_quick_slot(index: int):
	if index >= 0 and index < 4:
		Global.active_quick_slot = index
		update_quickbar()
		var item_id = Global.quick_slots[index]
		quick_slot_changed.emit(index, item_id)

func _unhandled_input(event):
	if event.is_action_pressed("toggle_inventory"):
		toggle_inventory()
	elif event.is_action_pressed("quick_1"):
		select_quick_slot(0)
	elif event.is_action_pressed("quick_2"):
		select_quick_slot(1)
	elif event.is_action_pressed("quick_3"):
		select_quick_slot(2)
	elif event.is_action_pressed("quick_4"):
		select_quick_slot(3)
