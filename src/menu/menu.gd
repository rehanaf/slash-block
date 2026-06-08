extends Control

# Preload player scene for preview
var player_scene = preload("res://src/player/player.tscn")
var player_preview: CharacterBody2D = null

# Skins list
var skins = ["captenpanez", "steve", "dream", "fiz"]
var selected_idx = 0
var weapons = []
var selected_weapon_idx = 0

# Nodes
@onready var char_name_label = $UI/MenuContainer/PanelChar/CharNameLabel
@onready var preview_pos = $PreviewPosition
@onready var start_button = $UI/MenuContainer/PanelMenu/StartButton
@onready var quit_button = $UI/MenuContainer/PanelMenu/QuitButton
@onready var prev_button = $UI/MenuContainer/PanelChar/PrevButton
@onready var next_button = $UI/MenuContainer/PanelChar/NextButton
@onready var weapon_label = $UI/MenuContainer/PanelWeapon/WeaponLabel
@onready var weapon_prev_button = $UI/MenuContainer/PanelWeapon/PrevButton
@onready var weapon_next_button = $UI/MenuContainer/PanelWeapon/NextButton

# Background elements
var clouds = []
var stars = []
var time = 0.0

func _ready():
	# 1. Setup Input Map just in case (reset, escape, etc.)
	setup_menu_inputs()
	
	# Set background color to midnight night sky
	RenderingServer.set_default_clear_color(Color(0.04, 0.05, 0.11))
	
	# 2. Spawn player preview
	spawn_preview_player()
	
	# 3. Update UI text
	update_character_ui()
	
	# Connect buttons
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	
	# Connect resize signal
	resized.connect(adjust_menu_safe_area)
	if get_tree() and get_tree().root:
		get_tree().root.size_changed.connect(adjust_menu_safe_area)
	adjust_menu_safe_area()
	# Initialize weapons
	weapons = []
	for w in Global.weapons:
		weapons.append(w["name"])
	selected_weapon_idx = weapons.find(Global.selected_weapon)
	if selected_weapon_idx == -1:
		selected_weapon_idx = 0
	Global.selected_weapon = weapons[selected_weapon_idx]
	# Connect weapon navigation buttons
	weapon_prev_button.pressed.connect(_on_weapon_prev_pressed)
	weapon_next_button.pressed.connect(_on_weapon_next_pressed)
	update_weapon_ui()
	
	# Create some moonlit clouds for the background
	for i in range(5):
		clouds.append({
			"pos": Vector2(randf_range(0, 1152), randf_range(40, 200)),
			"speed": randf_range(5, 15),
			"size": Vector2(randf_range(60, 120), randf_range(20, 40))
		})
	
	# Create stars for the night sky
	for i in range(40):
		stars.append({
			"pos": Vector2(randf_range(0, 1152), randf_range(10, 320)),
			"brightness": randf_range(0.3, 1.0),
			"twinkle_speed": randf_range(1.5, 4.0),
			"twinkle_offset": randf_range(0, TAU),
			"size": 1.0 if randf() > 0.2 else 2.0
		})

func adjust_menu_safe_area():
	var view_size = get_viewport().get_visible_rect().size
	var target_ratio = 16.0 / 9.0
	var actual_ratio = view_size.x / view_size.y
	var margin_x = 0.0
	if actual_ratio > target_ratio:
		margin_x = (view_size.x - (view_size.y * target_ratio)) / 2.0
		
	# Shift the entire MenuContainer instead of individual panels!
	var menu_container = get_node_or_null("UI/MenuContainer")
	if menu_container:
		menu_container.offset_left = margin_x
		menu_container.offset_right = -margin_x
		
	var preview_position = get_node_or_null("PreviewPosition")
	if preview_position:
		preview_position.position.x = 768.0 + margin_x
		
	if player_preview:
		player_preview.position.x = 768.0 + margin_x


func setup_menu_inputs():
	# Make sure actions like ui_cancel are ready
	if not InputMap.has_action("reset"):
		InputMap.add_action("reset")
		var ev = InputEventKey.new()
		ev.physical_keycode = KEY_R
		InputMap.action_add_event("reset", ev)

func spawn_preview_player():
	player_preview = player_scene.instantiate()
	player_preview.is_preview = true
	# Set high scale so it looks big and pixelated
	player_preview.scale = Vector2(8, 8)
	# Position it at the marker
	player_preview.position = preview_pos.position
	player_preview.z_index = 5
	$UI.add_child(player_preview)
	
	# Update the initial skin
	selected_idx = skins.find(Global.selected_skin)
	if selected_idx == -1:
		selected_idx = 0
	player_preview.apply_skin(skins[selected_idx])


func update_character_ui():
	var active_skin = skins[selected_idx]
	Global.selected_skin = active_skin
	
	# Format name nicely
	var display_name = active_skin.capitalize()
	if active_skin == "captenpanez":
		display_name = "Capten Panez"
		
	char_name_label.text = display_name
	
	# Update preview skin
	if player_preview:
		player_preview.apply_skin(active_skin)
		
	# UI Button click pop animations
	var tween = create_tween()
	char_name_label.scale = Vector2(1.15, 1.15)
	tween.tween_property(char_name_label, "scale", Vector2(1.0, 1.0), 0.15)

func _process(delta):
	time += delta
	# Animate clouds
	for c in clouds:
		c.pos.x += c.speed * delta
		if c.pos.x > 1200:
			c.pos.x = -150
			c.pos.y = randf_range(40, 200)
	queue_redraw()

func _draw():
	# Draw twinkling stars
	for s in stars:
		var twinkle = (sin(time * s.twinkle_speed + s.twinkle_offset) + 1.0) * 0.5
		var alpha = s.brightness * (0.4 + twinkle * 0.6)
		var star_color = Color(0.9, 0.92, 1.0, alpha)
		draw_rect(Rect2(s.pos, Vector2(s.size, s.size)), star_color)
	
	# Draw background clouds (moonlit, semi-transparent)
	for c in clouds:
		var color = Color(0.5, 0.55, 0.7, 0.12)
		draw_rect(Rect2(c.pos, c.size), color)
		draw_rect(Rect2(c.pos + Vector2(10, -10), c.size - Vector2(20, 0)), color)

func _on_start_pressed():
	# Play transition sound / delay and load scene
	var tween = create_tween()
	start_button.scale = Vector2(1.1, 1.1)
	tween.tween_property(start_button, "scale", Vector2(1.0, 1.0), 0.1)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://src/world/world.tscn")
	)

func _on_quit_pressed():
	get_tree().quit()

func _on_prev_pressed():
	selected_idx = (selected_idx - 1 + skins.size()) % skins.size()
	update_character_ui()

func _on_next_pressed():
	selected_idx = (selected_idx + 1) % skins.size()
	update_character_ui()

func update_weapon_ui():
	if weapon_label:
		weapon_label.text = weapons[selected_weapon_idx]
	# Update global selected weapon
	if has_node("/root/Global"):
		var global = get_node("/root/Global")
		global.selected_weapon = weapons[selected_weapon_idx]

func _on_weapon_prev_pressed():
	selected_weapon_idx = (selected_weapon_idx - 1 + weapons.size()) % weapons.size()
	update_weapon_ui()

func _on_weapon_next_pressed():
	selected_weapon_idx = (selected_weapon_idx + 1) % weapons.size()
	update_weapon_ui()
