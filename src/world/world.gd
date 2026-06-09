extends Node2D

const BLOCK_SIZE = 16.0

# Preloads
var player_scene = preload("res://src/player/player.tscn")
var enemy_scene = preload("res://src/enemy/enemy.tscn")
var torch_scene = preload("res://src/world/torch.tscn")
var inventory_ui_scene = preload("res://src/ui/inventory_ui.tscn")
var resource_node_scene = preload("res://src/world/resource_node.tscn")
var crafting_table_scene = preload("res://src/world/crafting_table.tscn")

# Camera Shake
var shake_intensity: float = 0.0
var shake_duration: float = 0.0

# Nodes
var player_inst = null
@onready var camera = $Camera2D
@onready var tile_map = $TileMap
@onready var hud_hp_label = $CanvasLayer/HUD/HPLabel
@onready var hud_hp_bar = $CanvasLayer/HUD/HPBar
@onready var hud_skin_label = $CanvasLayer/HUD/SkinLabel
@onready var hud_weapon_label = $CanvasLayer/HUD/WeaponLabel
@onready var hud_combo_label = $CanvasLayer/HUD/ComboLabel

@onready var hud_combo_progress = $CanvasLayer/HUD/ComboProgress
@onready var pause_button = $CanvasLayer/HUD/PauseButton
@onready var pause_menu = $CanvasLayer/PauseMenu
@onready var resume_button = $CanvasLayer/PauseMenu/Panel/ResumeButton
@onready var main_menu_button = $CanvasLayer/PauseMenu/Panel/MainMenuButton

func _ready():
	# Configure process modes for pause system
	process_mode = PROCESS_MODE_ALWAYS
	tile_map.process_mode = PROCESS_MODE_PAUSABLE
	camera.process_mode = PROCESS_MODE_PAUSABLE
	$CanvasLayer/HUD.process_mode = PROCESS_MODE_PAUSABLE
	
	# Connect pause buttons
	pause_button.pressed.connect(pause_game)
	resume_button.pressed.connect(resume_game)
	main_menu_button.pressed.connect(go_to_main_menu)
	pause_menu.visible = false
	
	# 0. Setup input map programmatically
	setup_inputs()
	
	# 1. Programmatically construct the TileSet
	setup_tileset()
	
	# 2. Generate the level map
	generate_level()
	
	# 3. Spawn the player
	spawn_player()
	
	# 4. Spawn enemies
	spawn_enemies()
	
	# 5. Spawn torches
	_spawn_torches()
	
	# 6. Place floating tutorial labels in the world
	place_tutorial_labels()
	
	# Set background color to midnight night sky
	RenderingServer.set_default_clear_color(Color(0.04, 0.05, 0.11))
	
	spawn_resources()
	
	# 6. Adjust HUD positioning based on 16:9 safe area
	$CanvasLayer/HUD.resized.connect(adjust_hud_safe_area)
	if get_tree() and get_tree().root:
		get_tree().root.size_changed.connect(adjust_hud_safe_area)
	adjust_hud_safe_area()



func setup_inputs():
	var inputs = {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"dash": [KEY_SHIFT, KEY_K],
		"attack": [KEY_J],
		"toggle_inventory": [KEY_TAB],
		"reset": [KEY_R],
		"sneak": [KEY_S, KEY_DOWN],
		"quick_1": [KEY_1],
		"quick_2": [KEY_2],
		"quick_3": [KEY_3],
		"quick_4": [KEY_4],
		"interact": [KEY_E, KEY_F]
	}
	
	for action in inputs.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		else:
			InputMap.action_erase_events(action)
			
		for key in inputs[action]:
			var ev = InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
			
	# Also allow Left Click for attack
	var mouse_click = InputEventMouseButton.new()
	mouse_click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mouse_click)

func setup_tileset():
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(16, 16)
	
	# Add physics layer
	tileset.add_physics_layer()
	
	# Create atlas source
	var texture = load("res://assets/tileset.png")
	if not texture:
		push_error("Failed to load tileset texture!")
		return
		
	var source = TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(16, 16)
	
	# Add source to tileset FIRST so that tile_data knows about the physics layers!
	tileset.add_source(source, 1)
	
	# Define our tiles in the atlas (coordinates correspond to generate_tileset.py)
	# (x, y) coordinates
	var tiles_coords = [
		Vector2i(0, 0), # Grass
		Vector2i(1, 0), # Dirt
		Vector2i(2, 0), # Stone
		Vector2i(3, 0), # Cobblestone
		Vector2i(0, 1), # Oak Wood
		Vector2i(1, 1), # Brick
		Vector2i(2, 1), # Coal Ore
		Vector2i(3, 1), # Glass (No physics)
		Vector2i(0, 2), # Thin Oak Platform (One-way)
	]
	
	# Full 16x16 collision shape
	var collision_polygon = PackedVector2Array([
		Vector2(-8, -8),
		Vector2(8, -8),
		Vector2(8, 8),
		Vector2(-8, 8)
	])
	
	for coords in tiles_coords:
		source.create_tile(coords)
		var tile_data = source.get_tile_data(coords, 0)
		
		# Make all solid blocks collidable (Glass is coordinates (3, 1))
		if coords != Vector2i(3, 1):
			tile_data.add_collision_polygon(0)
			if coords == Vector2i(0, 2):
				# Thin collision shape (4px height from top of tile)
				var thin_collision_polygon = PackedVector2Array([
					Vector2(-8, -8),
					Vector2(8, -8),
					Vector2(8, -4),
					Vector2(-8, -4)
				])
				tile_data.set_collision_polygon_points(0, 0, thin_collision_polygon)
				tile_data.set_collision_polygon_one_way(0, 0, true)
				tile_data.set_collision_polygon_one_way_margin(0, 0, 1.0)
			else:
				tile_data.set_collision_polygon_points(0, 0, collision_polygon)
	
	# Assign to TileMap (Godot 4 property is tile_set)
	tile_map.tile_set = tileset

func generate_level():
	tile_map.clear()
	
	# Base ground layer:
	# Grass at y = 8 (from x = -30 to 120)
	# Dirt from y = 9 to 11
	# Stone from y = 12 to 24 (deep stone layer)
	for x in range(-30, 120):
		# Pit 1 (small gap for jumps/dash): x = 30 to 34 (5 blocks gap)
		if x >= 30 and x <= 34:
			continue
			
		# Pit 2 (large void area): x = 74 to 81 (8 blocks gap)
		if x >= 74 and x <= 81:
			continue
			
		# Draw grass top
		tile_map.set_cell(0, Vector2i(x, 8), 1, Vector2i(0, 0))
		
		# Draw dirt
		for y in range(9, 12):
			tile_map.set_cell(0, Vector2i(x, y), 1, Vector2i(1, 0))
			
		# Draw deep stone
		for y in range(12, 25):
			# Randomly place some Coal Ore in the stone
			var tile_type = Vector2i(2, 0) # Stone
			if randf() < 0.12:
				tile_type = Vector2i(2, 1) # Coal Ore
			tile_map.set_cell(0, Vector2i(x, y), 1, tile_type)
			
	# Left boundary wall (Cobblestone)
	for y in range(-20, 8):
		for x in range(-32, -29):
			tile_map.set_cell(0, Vector2i(x, y), 1, Vector2i(3, 0))
			
	# Right boundary wall (Cobblestone)
	for y in range(-20, 8):
		for x in range(116, 120):
			tile_map.set_cell(0, Vector2i(x, y), 1, Vector2i(3, 0))

	# --- 1. Starter Cabin (Spawn Area) ---
	# x = -10 to -3, y = 5 to 7.
	# Floor at y = 8 (grass).
	# Side walls:
	for y in range(5, 8):
		tile_map.set_cell(0, Vector2i(-10, y), 1, Vector2i(0, 1)) # Oak Wood wall (Left)
		
	# Right wall with a door hole (only place top block)
	tile_map.set_cell(0, Vector2i(-3, 5), 1, Vector2i(0, 1))
	# Glass windows:
	tile_map.set_cell(0, Vector2i(-8, 6), 1, Vector2i(3, 1))
	tile_map.set_cell(0, Vector2i(-5, 6), 1, Vector2i(3, 1))
	# Roof (Brick):
	for x in range(-11, -2):
		tile_map.set_cell(0, Vector2i(x, 4), 1, Vector2i(1, 1))
		
	# --- 2. Underground Cave Pocket ---
	# Carve out a pocket under the starter area:
	# x = 1 to 14, y = 13 to 17 (fully empty air)
	for x in range(2, 13):
		for y in range(13, 17):
			tile_map.set_cell(0, Vector2i(x, y), -1) # Clear cell (air)
	# Add a pocket entry from above: downward shaft at x = 1, y = 9 to 12
	for y in range(9, 13):
		tile_map.set_cell(0, Vector2i(1, y), -1) # Tunnel entrance
	# Add thin platforms inside the cave for climbing back up:
	tile_map.set_cell(0, Vector2i(1, 12), 1, Vector2i(0, 2))
	tile_map.set_cell(0, Vector2i(1, 10), 1, Vector2i(0, 2))
	# Place some coal ore lining the cave wall
	tile_map.set_cell(0, Vector2i(2, 17), 1, Vector2i(2, 1))
	tile_map.set_cell(0, Vector2i(8, 12), 1, Vector2i(2, 1))
	tile_map.set_cell(0, Vector2i(12, 16), 1, Vector2i(2, 1))

	# --- 3. Platforms (Jump & Dash Training) ---
	# Platform 1: Oak wood platform (Single Jump height)
	for x in range(10, 15):
		tile_map.set_cell(0, Vector2i(x, 6), 1, Vector2i(0, 1))
		
	# Platform 2: Brick platform (Double Jump height)
	for x in range(20, 25):
		tile_map.set_cell(0, Vector2i(x, 4), 1, Vector2i(1, 1))
		
	# Floating Glass bridge over the first gap (x = 30 to 34)
	for x in range(30, 35):
		tile_map.set_cell(0, Vector2i(x, 2), 1, Vector2i(3, 1))
		
	# Platform 3: Cobblestone ledge after gap
	for x in range(35, 42):
		tile_map.set_cell(0, Vector2i(x, 5), 1, Vector2i(3, 0))

	# --- 4. Brick Tower & Sky Island ---
	# Tower base at x = 44 to 47. Vertical height goes up to y = -7
	for y in range(-7, 8):
		if y != 6 and y != 7:
			tile_map.set_cell(0, Vector2i(44, y), 1, Vector2i(1, 1)) # Brick wall left (leaves doorway)
		tile_map.set_cell(0, Vector2i(47, y), 1, Vector2i(1, 1)) # Brick wall right
	# Thin platforms inside the tower for vertical climbing:
	for y in range(-6, 8, 3):
		tile_map.set_cell(0, Vector2i(45, y), 1, Vector2i(0, 2))
		tile_map.set_cell(0, Vector2i(46, y), 1, Vector2i(0, 2))
	# Sky Island on top of the tower:
	# Floating Grass island from x = 48 to 68 at y = -8
	for x in range(48, 69):
		tile_map.set_cell(0, Vector2i(x, -8), 1, Vector2i(0, 0)) # Grass
		tile_map.set_cell(0, Vector2i(x, -7), 1, Vector2i(1, 0)) # Dirt
		tile_map.set_cell(0, Vector2i(x, -6), 1, Vector2i(2, 0)) # Stone
	# Add some structures (made of Oak wood) on the sky island:
	for x in range(54, 57):
		tile_map.set_cell(0, Vector2i(x, -10), 1, Vector2i(0, 1)) # Floating wood bridge

	# --- 5. Jump Pit 2 (Large Void) Ledge ---
	# Ledge at x = 70 to 73, y = 8
	# Brick floating island in the middle of pit 2:
	for x in range(77, 79):
		tile_map.set_cell(0, Vector2i(x, 5), 1, Vector2i(1, 1))

	# --- 6. Cobblestone Castle / Ruins ---
	# Large structure on the right: x = 86 to 115, y = 0 to 7
	# Castle Floor (Stone/Cobble):
	for x in range(86, 116):
		tile_map.set_cell(0, Vector2i(x, 7), 1, Vector2i(3, 0))
	# Left Wall:
	for y in range(0, 7):
		if y != 5 and y != 6:
			tile_map.set_cell(0, Vector2i(86, y), 1, Vector2i(3, 0))
	# Intermediate Castle Floors:
	# Floor 1 (Planks) at y = 4 (from x = 87 to 102)
	for x in range(87, 103):
		tile_map.set_cell(0, Vector2i(x, 4), 1, Vector2i(0, 1))
	# Floor 2 (Planks) at y = 1 (from x = 94 to 114)
	for x in range(94, 115):
		tile_map.set_cell(0, Vector2i(x, 1), 1, Vector2i(0, 1))
	# Right Wall/Tower:
	for y in range(-3, 7):
		tile_map.set_cell(0, Vector2i(115, y), 1, Vector2i(3, 0))
	# Castle Windows (Glass):
	tile_map.set_cell(0, Vector2i(86, 2), 1, Vector2i(3, 1))
	tile_map.set_cell(0, Vector2i(90, 2), 1, Vector2i(3, 1))
	tile_map.set_cell(0, Vector2i(100, 2), 1, Vector2i(3, 1))
	# Thin platforms for climbing in the castle:
	tile_map.set_cell(0, Vector2i(104, 3), 1, Vector2i(0, 2))
	tile_map.set_cell(0, Vector2i(92, 6), 1, Vector2i(0, 2))

func spawn_resources():
	var y_pos = 128 - 8 # Block size 16. Grass is at y=8 -> 128. Half block height is 8.
	
	# Spawn Crafting Table
	var table = crafting_table_scene.instantiate()
	table.position = Vector2(-5 * 16, y_pos)
	add_child(table)
	
	# Spawn Trees
	var tree_x = [10, 15, 20]
	for x in tree_x:
		var tree = resource_node_scene.instantiate()
		tree.node_type = "tree"
		tree.position = Vector2(x * 16, y_pos)
		add_child(tree)
		
	# Spawn Rocks
	var rock_x = [85, 90, 95]
	for x in rock_x:
		var rock = resource_node_scene.instantiate()
		rock.node_type = "rock"
		rock.position = Vector2(x * 16, y_pos)
		add_child(rock)
		
	# Spawn an Apple tree for food drops
	var apple_tree = resource_node_scene.instantiate()
	apple_tree.node_type = "tree"
	apple_tree.drop_item_id = "apple"
	apple_tree.position = Vector2(25 * 16, y_pos)
	add_child(apple_tree)

func spawn_player():
	player_inst = player_scene.instantiate()
	player_inst.process_mode = PROCESS_MODE_PAUSABLE
	player_inst.position = Vector2(0, 8 * BLOCK_SIZE - 20) # Spawn on grass
	add_child(player_inst)
	
	# Connect signals
	player_inst.player_attacked.connect(_on_player_attacked)
	player_inst.skin_changed.connect(_on_player_skin_changed)
	player_inst.weapon_changed.connect(_on_player_weapon_changed)
	
	if has_node("CanvasLayer/InventoryUI"):
		var inv_ui = get_node("CanvasLayer/InventoryUI")
		inv_ui.quick_slot_changed.connect(player_inst._on_quick_slot_changed)
	
	# Update initial HUD
	hud_skin_label.text = "Skin: " + player_inst.skins[player_inst.current_skin_index].capitalize()
	if has_node("/root/Global"):
		hud_weapon_label.text = "Weapon: " + get_node("/root/Global").selected_weapon


func spawn_enemies():
	# Strategic Enemy spawns with mixed types:
	# Enemy 1: Ground near spawn - Zombie
	spawn_enemy_at(Vector2(14 * BLOCK_SIZE, 8 * BLOCK_SIZE - 20), "zombie")
	# Enemy 2: On Platform 2 (brick) - Skeleton
	spawn_enemy_at(Vector2(22 * BLOCK_SIZE, 4 * BLOCK_SIZE - 20), "skeleton")
	# Enemy 3: Inside the underground cave - Creeper
	spawn_enemy_at(Vector2(7 * BLOCK_SIZE, 15 * BLOCK_SIZE - 20), "creeper")
	# Enemy 4: On the sky island - Skeleton
	spawn_enemy_at(Vector2(58 * BLOCK_SIZE, -8 * BLOCK_SIZE - 20), "skeleton")
	# Enemy 5: Castle ground level - Creeper
	spawn_enemy_at(Vector2(95 * BLOCK_SIZE, 7 * BLOCK_SIZE - 20), "creeper")
	# Enemy 6: Castle intermediate planks floor - Zombie
	spawn_enemy_at(Vector2(101 * BLOCK_SIZE, 4 * BLOCK_SIZE - 20), "zombie")
	# Enemy 7: Castle upper planks floor - Skeleton
	spawn_enemy_at(Vector2(104 * BLOCK_SIZE, 1 * BLOCK_SIZE - 20), "skeleton")

func spawn_enemy_at(pos: Vector2, type: String = "zombie"):
	var enemy_inst = enemy_scene.instantiate()
	enemy_inst.enemy_type = type
	enemy_inst.process_mode = PROCESS_MODE_PAUSABLE
	enemy_inst.position = pos
	add_child(enemy_inst)

func _spawn_torches():
	var torch_positions = [
		Vector2(-6 * BLOCK_SIZE, 6 * BLOCK_SIZE),   # Inside starter cabin
		Vector2(-6 * BLOCK_SIZE, 17 * BLOCK_SIZE),  # Cave
		Vector2(1 * BLOCK_SIZE, 17 * BLOCK_SIZE),   # Cave extension
		Vector2(101 * BLOCK_SIZE, 3 * BLOCK_SIZE),  # Castle interior
		Vector2(104 * BLOCK_SIZE, 0 * BLOCK_SIZE)   # Castle top
	]
	
	for pos in torch_positions:
		var t = torch_scene.instantiate()
		t.position = pos
		add_child(t)

func place_tutorial_labels():
	create_world_label("<- Starter Cabin", Vector2(-6 * BLOCK_SIZE, 3 * BLOCK_SIZE))
	create_world_label("Underground Cave Entrance v", Vector2(1 * BLOCK_SIZE, 7 * BLOCK_SIZE))
	create_world_label("Climb Brick Tower ->", Vector2(41 * BLOCK_SIZE, 7 * BLOCK_SIZE))
	create_world_label("Sky Island (Skeletons!)", Vector2(50 * BLOCK_SIZE, -9.5 * BLOCK_SIZE))
	create_world_label("Lava Void Pit (Jump/Dash!)", Vector2(70 * BLOCK_SIZE, 6.5 * BLOCK_SIZE))
	create_world_label("Cobblestone Ruins / Castle", Vector2(85 * BLOCK_SIZE, 6.0 * BLOCK_SIZE))

func create_world_label(txt: String, pos: Vector2):
	var l = Label.new()
	l.text = txt
	l.scale = Vector2(0.2, 0.2) # crisp text when scaled up by camera
	l.position = pos
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_font_size_override("font_size", 32)
	add_child(l)

func _process(delta):
	_update_day_night_cycle()
	
	# Camera follow
	if player_inst:
		# Lerp camera to player position
		var target_pos = player_inst.global_position + Vector2(0, -10)
		camera.global_position = camera.global_position.lerp(target_pos, 8.0 * delta)
		
		# Void death check:
		if player_inst.global_position.y > 19.0 * BLOCK_SIZE:
			player_inst.take_damage(100.0, Vector2.ZERO)
			
	# Apply camera shake
	if shake_duration > 0:
		shake_duration -= delta
		var offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_intensity
		camera.offset = offset
		if shake_duration <= 0:
			camera.offset = Vector2.ZERO
			
	# Update combo progress bar fill in HUD
	if player_inst:
		hud_hp_bar.value = player_inst.health
		hud_hp_label.text = "HP: " + str(max(0, int(player_inst.health))) + " / 100"
		
		if player_inst.combo_step > 0 and player_inst.combo_reset_timer > 0:
			hud_combo_progress.value = (player_inst.combo_reset_timer / player_inst.COMBO_WINDOW) * 100.0
			hud_combo_label.text = "Combo: " + str(player_inst.combo_step) + "/3"
			hud_combo_progress.visible = true
		else:
			hud_combo_progress.visible = false
			hud_combo_label.text = "Combo: Ready"
			
	# Reset player when pressing R
	if Input.is_action_just_pressed("reset") and not get_tree().paused:
		get_tree().reload_current_scene()


func _update_day_night_cycle():
	var time = Global.get_time_of_day()
	var sky_color: Color
	var modulate_color: Color
	
	# Day/Night Colors
	var night_sky = Color(0.04, 0.05, 0.11)
	var night_modulate = Color(0.2, 0.2, 0.3)
	
	var dawn_sky = Color(0.8, 0.5, 0.3)
	var dawn_modulate = Color(0.8, 0.7, 0.6)
	
	var day_sky = Color(0.5, 0.8, 0.95)
	var day_modulate = Color(1.0, 1.0, 1.0)
	
	var dusk_sky = Color(0.9, 0.4, 0.2)
	var dusk_modulate = Color(0.9, 0.7, 0.5)
	
	# Interpolate based on time
	if time < 0.25: # Night to Dawn (0-6 hours)
		var t = time / 0.25
		sky_color = night_sky.lerp(dawn_sky, t)
		modulate_color = night_modulate.lerp(dawn_modulate, t)
	elif time < 0.5: # Dawn to Day (6-12 hours)
		var t = (time - 0.25) / 0.25
		sky_color = dawn_sky.lerp(day_sky, t)
		modulate_color = dawn_modulate.lerp(day_modulate, t)
	elif time < 0.75: # Day to Dusk (12-18 hours)
		var t = (time - 0.5) / 0.25
		sky_color = day_sky.lerp(dusk_sky, t)
		modulate_color = day_modulate.lerp(dusk_modulate, t)
	else: # Dusk to Night (18-24 hours)
		var t = (time - 0.75) / 0.25
		sky_color = dusk_sky.lerp(night_sky, t)
		modulate_color = dusk_modulate.lerp(night_modulate, t)
		
	RenderingServer.set_default_clear_color(sky_color)
	if has_node("CanvasModulate"):
		$CanvasModulate.color = modulate_color

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		# Get viewport.gui_get_focus_owner() or similar if needed, but simple toggle is best
		if get_tree().paused:
			resume_game()
		else:
			pause_game()

func pause_game():
	get_tree().paused = true
	pause_menu.visible = true
	# Grab focus for immediate keyboard usability
	resume_button.grab_focus()

func resume_game():
	get_tree().paused = false
	pause_menu.visible = false

func go_to_main_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/menu/menu.tscn")

func shake_camera(intensity: float, duration: float):
	shake_intensity = intensity
	shake_duration = duration

func _on_player_attacked(step: int):
	# Visual punch in HUD
	var tween = create_tween()
	hud_combo_label.scale = Vector2(1.2, 1.2)
	tween.tween_property(hud_combo_label, "scale", Vector2(1.0, 1.0), 0.15)

func _on_player_skin_changed(new_skin_name: String):
	hud_skin_label.text = "Skin: " + new_skin_name.capitalize()
	# Flash label
	var tween = create_tween()
	hud_skin_label.scale = Vector2(1.2, 1.2)
	tween.tween_property(hud_skin_label, "scale", Vector2(1.0, 1.0), 0.15)

func _on_player_weapon_changed(new_weapon_name: String):
	hud_weapon_label.text = "Weapon: " + new_weapon_name
	# Flash label
	var tween = create_tween()
	hud_weapon_label.scale = Vector2(1.2, 1.2)
	tween.tween_property(hud_weapon_label, "scale", Vector2(1.0, 1.0), 0.15)


# GPUParticles2D pixel particle burst
func create_particles(pos: Vector2, color: Color, count: int):
	var particles = GPUParticles2D.new()
	particles.global_position = pos
	
	# Configure particle settings
	particles.amount = count
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.45
	
	# Create a tiny 2x2 white texture for crisp pixel representation
	var img = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var texture = ImageTexture.create_from_image(img)
	particles.texture = texture
	
	# Nearest texture filtering is key to pixel art crispness
	particles.texture_filter = TEXTURE_FILTER_NEAREST
	
	# Configure process material
	var mat = ParticleProcessMaterial.new()
	mat.particle_flag_disable_z = true
	
	# Movement directions and speed
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 120.0
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 80.0
	
	# Gravity pull
	mat.gravity = Vector3(0, 240, 0)
	
	# Random scaling and color
	mat.scale_min = 1.0
	mat.scale_max = 2.5
	mat.color = color
	
	# Fade out color over lifetime
	var gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = gradient
	mat.color_ramp = grad_tex
	
	particles.process_material = mat
	add_child(particles)
	
	# Emit!
	particles.emitting = true
	
	# Automatically clean up when finished
	particles.finished.connect(particles.queue_free)

func adjust_hud_safe_area():
	var view_size = get_viewport().get_visible_rect().size
	var target_ratio = 16.0 / 9.0
	var actual_ratio = view_size.x / view_size.y
	var margin_x = 0.0
	if actual_ratio > target_ratio:
		margin_x = (view_size.x - (view_size.y * target_ratio)) / 2.0
		
	# Shift the entire HUD container instead of individual elements!
	var hud = $CanvasLayer/HUD
	if hud:
		hud.offset_left = margin_x
		hud.offset_right = -margin_x


