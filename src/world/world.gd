extends Node2D
# world.gd — Thin orchestrator. Generation logic lives in WorldGenerator,
# tileset setup in TilesetBuilder, entities in entities/.

const BLOCK_SIZE = 16.0

# Explicit preloads so class_name resolution works before editor import
const TilesetBuilderScript  = preload("res://src/world/tileset_builder.gd")
const WorldGeneratorScript  = preload("res://src/world/world_generator.gd")
const SkySystemScript       = preload("res://src/world/sky_system.gd")

# ─────────────────────────────────────────────────────────────
#  PRELOADS
# ─────────────────────────────────────────────────────────────
var player_scene         = preload("res://src/player/player.tscn")
var enemy_scene          = preload("res://src/enemy/enemy.tscn")
var torch_scene          = preload("res://src/world/entities/torch.tscn")
var resource_node_scene  = preload("res://src/world/entities/resource_node.tscn")
var crafting_table_scene = preload("res://src/world/entities/crafting_table.tscn")

# ─────────────────────────────────────────────────────────────
#  CAMERA SHAKE
# ─────────────────────────────────────────────────────────────
var shake_intensity: float = 0.0
var shake_duration:  float = 0.0

# ─────────────────────────────────────────────────────────────
#  NODES
# ─────────────────────────────────────────────────────────────
var player_inst = null

@onready var camera           = $Camera2D
@onready var tile_map         = $TileMap
@onready var hud_hp_label     = $CanvasLayer/HUD/HPLabel
@onready var hud_hp_bar       = $CanvasLayer/HUD/HPBar
@onready var hud_skin_label   = $CanvasLayer/HUD/SkinLabel
@onready var hud_weapon_label = $CanvasLayer/HUD/WeaponLabel
@onready var hud_combo_label  = $CanvasLayer/HUD/ComboLabel
@onready var hud_combo_progress = $CanvasLayer/HUD/ComboProgress
@onready var pause_button     = $CanvasLayer/HUD/PauseButton
@onready var pause_menu       = $CanvasLayer/PauseMenu
@onready var resume_button    = $CanvasLayer/PauseMenu/Panel/ResumeButton
@onready var main_menu_button = $CanvasLayer/PauseMenu/Panel/MainMenuButton

# ─────────────────────────────────────────────────────────────
#  WORLD GENERATOR
# ─────────────────────────────────────────────────────────────
var _generator = null  # WorldGenerator instance

# ─────────────────────────────────────────────────────────────
#  SKY
# ─────────────────────────────────────────────────────────────
var _sky_system = null  # SkySystem instance

# ─────────────────────────────────────────────────────────────
#  HUD EXTRAS
# ─────────────────────────────────────────────────────────────
var hud_coord_label: Label = null

# ─────────────────────────────────────────────────────────────
#  _READY
# ─────────────────────────────────────────────────────────────
func _ready():
	process_mode = PROCESS_MODE_ALWAYS
	tile_map.process_mode = PROCESS_MODE_PAUSABLE
	camera.process_mode  = PROCESS_MODE_PAUSABLE
	$CanvasLayer/HUD.process_mode = PROCESS_MODE_PAUSABLE

	# Pause buttons
	pause_button.pressed.connect(pause_game)
	resume_button.pressed.connect(resume_game)
	main_menu_button.pressed.connect(go_to_main_menu)
	pause_menu.visible = false

	# 0. Input map
	setup_inputs()

	# 1. Build TileSet
	TilesetBuilderScript.build(tile_map)

	# 2. Procedural world generation
	_setup_generator()

	# 3. Spawn player
	spawn_player()

	# 4. Spawn initial enemies
	spawn_enemies()

	# 5. Underground torches
	_generator.spawn_underground_torches(torch_scene, self, 10)

	# 6. Background sky
	RenderingServer.set_default_clear_color(Color(0.04, 0.05, 0.11))

	# 7. HUD safe area
	$CanvasLayer/HUD.resized.connect(adjust_hud_safe_area)
	if get_tree() and get_tree().root:
		get_tree().root.size_changed.connect(adjust_hud_safe_area)
	adjust_hud_safe_area()

	# 8. Coordinate label
	_create_coord_label()

	# 9. Sky system (sun, moon, clouds) on a background CanvasLayer
	_setup_sky()

func _create_coord_label() -> void:
	hud_coord_label = Label.new()
	hud_coord_label.name = "CoordLabel"
	hud_coord_label.add_theme_font_size_override("font_size", 11)
	hud_coord_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7, 0.9))
	hud_coord_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hud_coord_label.add_theme_constant_override("outline_size", 3)
	hud_coord_label.text = "X: 0  Y: 0"
	# Anchor to bottom-left of HUD
	hud_coord_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hud_coord_label.offset_left   =  12.0
	hud_coord_label.offset_bottom = -12.0
	hud_coord_label.offset_top    = -32.0
	hud_coord_label.offset_right  =  200.0
	$CanvasLayer/HUD.add_child(hud_coord_label)

func _setup_sky() -> void:
	# Background CanvasLayer sits behind the world (layer -5)
	var sky_layer = CanvasLayer.new()
	sky_layer.name  = "SkyLayer"
	sky_layer.layer = -5
	add_child(sky_layer)

	_sky_system = SkySystemScript.new()
	_sky_system.name = "SkySystem"
	sky_layer.add_child(_sky_system)

# ─────────────────────────────────────────────────────────────
#  GENERATOR SETUP
# ─────────────────────────────────────────────────────────────
func _setup_generator() -> void:
	_generator = WorldGeneratorScript.new()
	_generator.tile_map              = tile_map
	_generator.world_node            = self
	_generator.resource_node_scene   = resource_node_scene
	_generator.crafting_table_scene  = crafting_table_scene

	# Use Global seed if available, otherwise random
	var seed_val = randi() if not Engine.has_singleton("Global") else Global.world_seed if "world_seed" in Global else randi()
	_generator.setup(seed_val)

	# Generate initial visible area: chunks around spawn
	_generator.generate_range(-4, 20)

# ─────────────────────────────────────────────────────────────
#  INPUT SETUP
# ─────────────────────────────────────────────────────────────
func setup_inputs():
	var inputs = {
		"move_left":        [KEY_A, KEY_LEFT],
		"move_right":       [KEY_D, KEY_RIGHT],
		"jump":             [KEY_SPACE],
		"dash":             [KEY_SHIFT, KEY_K],
		"attack":           [KEY_J],
		"toggle_inventory": [KEY_TAB],
		"reset":            [KEY_R],
		"sneak":            [KEY_S, KEY_DOWN],
		"quick_1":          [KEY_1],
		"quick_2":          [KEY_2],
		"quick_3":          [KEY_3],
		"quick_4":          [KEY_4],
		"interact":         [KEY_E, KEY_F]
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

	var mouse_click = InputEventMouseButton.new()
	mouse_click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mouse_click)

# ─────────────────────────────────────────────────────────────
#  PLAYER
# ─────────────────────────────────────────────────────────────
func spawn_player():
	# Reset quick_slots setiap world dimulai agar tidak carry-over dari sesi sebelumnya
	if has_node("/root/Global"):
		var g = get_node("/root/Global")
		g.quick_slots         = ["iron_sword", "iron_axe", "iron_spear", ""]
		g.active_quick_slot   = 0
		g.selected_weapon     = "Iron Sword"

	player_inst = player_scene.instantiate()
	player_inst.process_mode = PROCESS_MODE_PAUSABLE
	# Tambahkan ke group "player" agar drop_item bisa detect dengan is_in_group()
	player_inst.add_to_group("player")

	# Find spawn surface Y
	var spawn_surf_y = _generator.get_surface_y(0) if _generator else 8
	player_inst.position = Vector2(0.0, spawn_surf_y * BLOCK_SIZE - 20.0)
	add_child(player_inst)

	player_inst.player_attacked.connect(_on_player_attacked)
	player_inst.skin_changed.connect(_on_player_skin_changed)
	player_inst.weapon_changed.connect(_on_player_weapon_changed)

	if has_node("CanvasLayer/InventoryUI"):
		get_node("CanvasLayer/InventoryUI").quick_slot_changed.connect(player_inst._on_quick_slot_changed)

	hud_skin_label.text = "Skin: " + player_inst.skins[player_inst.current_skin_index].capitalize()
	if has_node("/root/Global"):
		hud_weapon_label.text = "Weapon: " + get_node("/root/Global").selected_weapon


# ─────────────────────────────────────────────────────────────
#  ENEMIES
# ─────────────────────────────────────────────────────────────
func spawn_enemies():
	# Scatter enemies based on terrain surface
	var enemy_configs = [
		{tile_x =  10, type = "zombie"},
		{tile_x =  30, type = "skeleton"},
		{tile_x =  60, type = "creeper"},
		{tile_x =  90, type = "zombie"},
		{tile_x = 120, type = "skeleton"},
		{tile_x = 150, type = "creeper"},
	]
	for cfg in enemy_configs:
		var surf_y = _generator.get_surface_y(cfg.tile_x) if _generator else 8
		spawn_enemy_at(Vector2(cfg.tile_x * BLOCK_SIZE, surf_y * BLOCK_SIZE - 20.0), cfg.type)

func spawn_enemy_at(pos: Vector2, type: String = "zombie"):
	var e = enemy_scene.instantiate()
	e.enemy_type = type
	e.process_mode = PROCESS_MODE_PAUSABLE
	e.position = pos
	add_child(e)

# ─────────────────────────────────────────────────────────────
#  _PROCESS
# ─────────────────────────────────────────────────────────────
func _process(delta):
	_update_day_night_cycle()

	if player_inst:
		# Camera follow
		var target_pos = player_inst.global_position + Vector2(0, -10)
		camera.global_position = camera.global_position.lerp(target_pos, 8.0 * delta)

		# Void death — must be below cave bottom (SEA_LEVEL + DIRT + STONE + buffer ≈ 60 tiles)
		if player_inst.global_position.y > 60.0 * BLOCK_SIZE:
			player_inst.take_damage(100.0, Vector2.ZERO)

		# Stream chunks as player explores
		var player_tile_x = int(player_inst.global_position.x / BLOCK_SIZE)
		if _generator:
			_generator.stream_around(player_tile_x, 8)

		# HUD
		hud_hp_bar.value = player_inst.health
		hud_hp_label.text = "HP: " + str(max(0, int(player_inst.health))) + " / 100"
		if player_inst.combo_step > 0 and player_inst.combo_reset_timer > 0:
			hud_combo_progress.value = (player_inst.combo_reset_timer / player_inst.COMBO_WINDOW) * 100.0
			hud_combo_label.text = "Combo: " + str(player_inst.combo_step) + "/3"
			hud_combo_progress.visible = true
		else:
			hud_combo_progress.visible = false
			hud_combo_label.text = "Combo: Ready"

		# Koordinat tile (X=0 di spawn)
		if hud_coord_label:
			var tile_x = int(floor(player_inst.global_position.x / BLOCK_SIZE))
			var tile_y = int(floor(player_inst.global_position.y / BLOCK_SIZE))
			hud_coord_label.text = "X: %d  Y: %d" % [tile_x, tile_y]

	# Camera shake
	if shake_duration > 0:
		shake_duration -= delta
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_intensity
		if shake_duration <= 0:
			camera.offset = Vector2.ZERO

	# Reset
	if Input.is_action_just_pressed("reset") and not get_tree().paused:
		get_tree().reload_current_scene()

# ─────────────────────────────────────────────────────────────
#  DAY / NIGHT CYCLE
# ─────────────────────────────────────────────────────────────
func _update_day_night_cycle():
	var time = Global.get_time_of_day()
	var night_sky      = Color(0.04, 0.05, 0.11)
	var night_mod      = Color(0.2, 0.2, 0.3)
	var dawn_sky       = Color(0.8, 0.5, 0.3)
	var dawn_mod       = Color(0.8, 0.7, 0.6)
	var day_sky        = Color(0.5, 0.8, 0.95)
	var day_mod        = Color(1.0, 1.0, 1.0)
	var dusk_sky       = Color(0.9, 0.4, 0.2)
	var dusk_mod       = Color(0.9, 0.7, 0.5)

	var sky_color: Color
	var mod_color: Color

	if time < 0.25:
		var t = time / 0.25
		sky_color = night_sky.lerp(dawn_sky, t)
		mod_color = night_mod.lerp(dawn_mod, t)
	elif time < 0.5:
		var t = (time - 0.25) / 0.25
		sky_color = dawn_sky.lerp(day_sky, t)
		mod_color = dawn_mod.lerp(day_mod, t)
	elif time < 0.75:
		var t = (time - 0.5) / 0.25
		sky_color = day_sky.lerp(dusk_sky, t)
		mod_color = day_mod.lerp(dusk_mod, t)
	else:
		var t = (time - 0.75) / 0.25
		sky_color = dusk_sky.lerp(night_sky, t)
		mod_color = dusk_mod.lerp(night_mod, t)

	RenderingServer.set_default_clear_color(sky_color)
	if has_node("CanvasModulate"):
		$CanvasModulate.color = mod_color

# ─────────────────────────────────────────────────────────────
#  INPUT
# ─────────────────────────────────────────────────────────────
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			resume_game()
		else:
			pause_game()

# ─────────────────────────────────────────────────────────────
#  PAUSE
# ─────────────────────────────────────────────────────────────
func pause_game():
	get_tree().paused = true
	pause_menu.visible = true
	resume_button.grab_focus()

func resume_game():
	get_tree().paused = false
	pause_menu.visible = false

func go_to_main_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://src/menu/menu.tscn")

# ─────────────────────────────────────────────────────────────
#  CAMERA SHAKE
# ─────────────────────────────────────────────────────────────
func shake_camera(intensity: float, duration: float):
	shake_intensity = intensity
	shake_duration  = duration

# ─────────────────────────────────────────────────────────────
#  HUD SIGNALS
# ─────────────────────────────────────────────────────────────
func _on_player_attacked(_step: int):
	var tween = create_tween()
	hud_combo_label.scale = Vector2(1.2, 1.2)
	tween.tween_property(hud_combo_label, "scale", Vector2(1.0, 1.0), 0.15)

func _on_player_skin_changed(new_skin_name: String):
	hud_skin_label.text = "Skin: " + new_skin_name.capitalize()
	var tween = create_tween()
	hud_skin_label.scale = Vector2(1.2, 1.2)
	tween.tween_property(hud_skin_label, "scale", Vector2(1.0, 1.0), 0.15)

func _on_player_weapon_changed(new_weapon_name: String):
	hud_weapon_label.text = "Weapon: " + new_weapon_name
	var tween = create_tween()
	hud_weapon_label.scale = Vector2(1.2, 1.2)
	tween.tween_property(hud_weapon_label, "scale", Vector2(1.0, 1.0), 0.15)

# ─────────────────────────────────────────────────────────────
#  PARTICLES
# ─────────────────────────────────────────────────────────────
func create_particles(pos: Vector2, color: Color, count: int):
	var particles = GPUParticles2D.new()
	particles.global_position = pos
	particles.amount = count
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.45

	var img = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var texture = ImageTexture.create_from_image(img)
	particles.texture = texture
	particles.texture_filter = TEXTURE_FILTER_NEAREST

	var mat = ParticleProcessMaterial.new()
	mat.particle_flag_disable_z = true
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 120.0
	mat.initial_velocity_min = 40.0
	mat.initial_velocity_max = 80.0
	mat.gravity = Vector3(0, 240, 0)
	mat.scale_min = 1.0
	mat.scale_max = 2.5
	mat.color = color

	var gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = gradient
	mat.color_ramp = grad_tex

	particles.process_material = mat
	add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)

# ─────────────────────────────────────────────────────────────
#  HUD SAFE AREA
# ─────────────────────────────────────────────────────────────
func adjust_hud_safe_area():
	var view_size    = get_viewport().get_visible_rect().size
	var target_ratio = 16.0 / 9.0
	var actual_ratio = view_size.x / view_size.y
	var margin_x = 0.0
	if actual_ratio > target_ratio:
		margin_x = (view_size.x - (view_size.y * target_ratio)) / 2.0
	var hud = $CanvasLayer/HUD
	if hud:
		hud.offset_left  = margin_x
		hud.offset_right = -margin_x
