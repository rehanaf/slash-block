extends Control

# Preload player scene for preview
var player_scene = preload("res://src/player/player.tscn")
var player_preview: CharacterBody2D = null

# Skins list
var skins = ["captenpanez", "steve", "dream", "fiz"]
var selected_idx = 0

# Nodes
@onready var char_name_label = $UI/PanelChar/CharNameLabel
@onready var preview_pos = $PreviewPosition
@onready var start_button = $UI/PanelMenu/StartButton
@onready var quit_button = $UI/PanelMenu/QuitButton
@onready var prev_button = $UI/PanelChar/PrevButton
@onready var next_button = $UI/PanelChar/NextButton

# Background elements
var clouds = []
var time = 0.0

func _ready():
	# 1. Setup Input Map just in case (reset, escape, etc.)
	setup_menu_inputs()
	
	# Set background color to sky blue
	RenderingServer.set_default_clear_color(Color(0.5, 0.7, 1.0))
	
	# 2. Spawn player preview
	spawn_preview_player()
	
	# 3. Update UI text
	update_character_ui()
	
	# Connect buttons
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	
	# Create some clouds for the background
	for i in range(5):
		clouds.append({
			"pos": Vector2(randf_range(0, 1152), randf_range(40, 200)),
			"speed": randf_range(10, 25),
			"size": Vector2(randf_range(60, 120), randf_range(20, 40))
		})

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
	# Draw background clouds
	for c in clouds:
		# Draw pixel clouds (simple gray-white blocks)
		var color = Color(1.0, 1.0, 1.0, 0.45)
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
