extends CharacterBody2D

var enemy_type: String = "zombie"

var health: int = 100
var max_health: int = 100
var knockback: Vector2 = Vector2.ZERO
var flash_timer: float = 0.0

# Chase parameters
const DETECT_RANGE = 220.0
const ZOMBIE_WALK_SPEED = 30.0

# Gravity
var gravity = 980.0

var spawn_position: Vector2 = Vector2.ZERO

# Skeleton arrow
var arrow_cooldown: float = 0.0
const ARROW_COOLDOWN_TIME = 2.0

# Creeper fuse
var fuse_timer: float = 0.0
const FUSE_DURATION = 1.5
var is_fusing: bool = false

# UI display
@onready var health_bar = $HealthBar
@onready var visual = $Visual

func _ready():
	spawn_position = global_position
	add_to_group("enemies")
	collision_layer = 4 # Match player's attack mask
	collision_mask = 1  # Collides only with TileMap (environment)
	
	# Set type-specific stats
	match enemy_type:
		"skeleton":
			health = 80
			max_health = 80
		"creeper":
			health = 60
			max_health = 60
	
	# Build visual based on type
	if visual:
		visual.setup(enemy_type)
		visual.scale.x = -1.0  # Face left by default
		
	# Create a simple health bar programmatically if not present
	update_health_bar()

func _physics_process(delta):
	# Add gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Reduce arrow cooldown
	if arrow_cooldown > 0:
		arrow_cooldown -= delta
	
	# Apply knockback or chase player
	if knockback.length() > 5.0:
		velocity.x = knockback.x
		# Apply vertical knockback directly if starting knockback
		if knockback.y != 0:
			velocity.y = knockback.y
			knockback.y = 0 # Only apply vertical impulse once
		# Friction on knockback
		knockback.x = move_toward(knockback.x, 0.0, 400.0 * delta)
		
		# Face the direction of the player who hit us
		if abs(velocity.x) > 10.0:
			visual.scale.x = -sign(velocity.x)
			
		# Disable walk animation during hitstun
		if visual:
			visual.is_moving = false
	else:
		# Type-specific AI
		match enemy_type:
			"zombie": _ai_zombie(delta)
			"skeleton": _ai_skeleton(delta)
			"creeper": _ai_creeper(delta)
		
	move_and_slide()
	
	# Handle flash animation
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0:
			# Don't reset modulate if creeper is fusing (fuse handler manages it)
			if not (enemy_type == "creeper" and is_fusing):
				visual.modulate = Color.WHITE
		else:
			# Red flashing
			visual.modulate = Color(1.0, 0.3, 0.3, 1.0)

# --- Zombie AI ---
func _ai_zombie(delta):
	var player = get_parent().get_node_or_null("Player")
	if not player or player.is_dead:
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		if visual: visual.is_moving = false
		return
	
	var diff_x = player.global_position.x - global_position.x
	var diff_y = player.global_position.y - global_position.y
	
	if abs(diff_x) < DETECT_RANGE and abs(diff_y) < 80.0:
		velocity.x = sign(diff_x) * ZOMBIE_WALK_SPEED
		if visual:
			visual.scale.x = sign(diff_x)
			visual.is_moving = true
		
		# Contact damage
		if abs(diff_x) < 14.0 and abs(diff_y) < 20.0 and not player.is_dead and player.invulnerability_timer <= 0.0:
			var kb_dir = Vector2(sign(diff_x), -0.5).normalized()
			player.take_damage(10, kb_dir * 180.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		if visual: visual.is_moving = false

# --- Skeleton AI ---
func _ai_skeleton(delta):
	var player = get_parent().get_node_or_null("Player")
	if not player or player.is_dead:
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		if visual: visual.is_moving = false
		return
	
	var diff_x = player.global_position.x - global_position.x
	var diff_y = player.global_position.y - global_position.y
	
	if abs(diff_x) > DETECT_RANGE or abs(diff_y) > 80.0:
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		if visual: visual.is_moving = false
		return
	
	# Face player
	if visual: visual.scale.x = sign(diff_x)
	
	var dist = abs(diff_x)
	
	if dist < 70.0:
		# Too close, back away
		velocity.x = -sign(diff_x) * ZOMBIE_WALK_SPEED * 0.8
		if visual: visual.is_moving = true
	elif dist > 160.0:
		# Too far, approach
		velocity.x = sign(diff_x) * ZOMBIE_WALK_SPEED * 0.8
		if visual: visual.is_moving = true
	else:
		# Sweet spot: stop and shoot
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		if visual: visual.is_moving = false
		
		if arrow_cooldown <= 0:
			shoot_arrow(player)
			arrow_cooldown = ARROW_COOLDOWN_TIME

func shoot_arrow(target):
	var arrow_script = load("res://src/enemy/arrow.gd")
	var arrow = Area2D.new()
	arrow.set_script(arrow_script)
	
	var dir = (target.global_position + Vector2(0, -8) - global_position).normalized()
	arrow.direction = dir
	arrow.global_position = global_position + Vector2(0, -4) + dir * 10
	
	get_parent().add_child(arrow)
	
	# Visual: briefly raise front arm to aim
	if visual and visual.right_arm_pivot:
		visual.right_arm_pivot.rotation = -1.5708
		var tween = create_tween()
		tween.tween_interval(0.3)
		tween.tween_property(visual.right_arm_pivot, "rotation", 0.0, 0.2)

# --- Creeper AI ---
func _ai_creeper(delta):
	var player = get_parent().get_node_or_null("Player")
	if not player or player.is_dead:
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		if visual: visual.is_moving = false
		_update_fuse(-delta * 2.0)
		return
	
	var diff_x = player.global_position.x - global_position.x
	var diff_y = player.global_position.y - global_position.y
	
	if abs(diff_x) > DETECT_RANGE or abs(diff_y) > 80.0:
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		if visual: visual.is_moving = false
		_update_fuse(-delta * 2.0)
		return
	
	# Face player
	if visual: visual.scale.x = sign(diff_x)
	
	var dist = abs(diff_x)
	
	if dist < 20.0:
		# Close enough, fuse
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		if visual: visual.is_moving = false
		_update_fuse(delta)
	elif dist < 40.0 and is_fusing:
		# Still in range during fuse, keep fusing
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		if visual: visual.is_moving = false
		_update_fuse(delta)
	else:
		# Chase player (slightly faster than zombie)
		velocity.x = sign(diff_x) * ZOMBIE_WALK_SPEED * 1.15
		if visual: visual.is_moving = true
		if is_fusing:
			_update_fuse(-delta * 1.5) # Fuse decays when moving away

func _update_fuse(amount: float):
	fuse_timer = clamp(fuse_timer + amount, 0.0, FUSE_DURATION)
	is_fusing = fuse_timer > 0.0
	
	if visual and visual.has_method("set_fuse_progress"):
		visual.set_fuse_progress(fuse_timer / FUSE_DURATION)
	
	if fuse_timer >= FUSE_DURATION:
		explode()

func explode():
	# Area damage to player
	var player = get_parent().get_node_or_null("Player")
	if player and not player.is_dead:
		var dist = global_position.distance_to(player.global_position)
		if dist < 55.0:
			var kb_dir = (player.global_position - global_position).normalized()
			player.take_damage(35, kb_dir * 250.0)
	
	# Camera shake
	if get_parent() and get_parent().has_method("shake_camera"):
		get_parent().shake_camera(6.0, 0.3)
	
	# Explosion particles
	if get_parent() and get_parent().has_method("create_particles"):
		get_parent().create_particles(global_position, Color(1.0, 0.6, 0.1, 0.9), 20)  # Fire
		get_parent().create_particles(global_position, Color(0.3, 0.3, 0.3, 0.7), 15)  # Smoke
		get_parent().create_particles(global_position, Color(1.0, 1.0, 0.3, 0.8), 10)  # Flash
	
	_schedule_respawn()
	queue_free()

# --- Common ---
func take_damage(amount: int, kb: Vector2):
	health -= amount
	flash_timer = 0.15
	knockback = kb
	
	# Spawn damage text popup
	spawn_damage_text(amount)
	
	# Spawn particles
	spawn_hit_particles()
	
	if health <= 0:
		die()
	else:
		update_health_bar()

func update_health_bar():
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
		# Hide health bar if full, show if damaged
		health_bar.visible = (health < max_health)

func spawn_damage_text(amount: int):
	var label = Label.new()
	label.text = str(amount)
	# Custom style for damage text
	label.scale = Vector2(0.4, 0.4) # Since camera zoom is 2.5x
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = global_position + Vector2(-10, -20) + Vector2(randf_range(-5, 5), randf_range(-5, 2))
	
	# Font override
	label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	label.add_theme_font_size_override("font_size", 32)
	
	get_parent().add_child(label)
	
	# Tween to float up and fade
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 15, 0.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

func spawn_respawn_text():
	var label = Label.new()
	label.text = "RESPAWN!"
	label.scale = Vector2(0.3, 0.3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = global_position + Vector2(-20, -25)
	label.add_theme_color_override("font_color", Color(0.2, 1, 0.2))
	label.add_theme_font_size_override("font_size", 32)
	get_parent().add_child(label)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 12, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

func spawn_hit_particles():
	if get_parent() and get_parent().has_method("create_particles"):
		match enemy_type:
			"zombie":
				get_parent().create_particles(global_position, Color(0.6, 0.1, 0.1, 0.8), 8)
			"skeleton":
				get_parent().create_particles(global_position, Color(0.85, 0.85, 0.8, 0.8), 8)
			"creeper":
				get_parent().create_particles(global_position, Color(0.2, 0.6, 0.1, 0.8), 8)

func die():
	# Spawn type-specific death particles
	if get_parent() and get_parent().has_method("create_particles"):
		match enemy_type:
			"zombie":
				get_parent().create_particles(global_position, Color(0.7, 0.9, 0.3, 0.8), 12)
				get_parent().create_particles(global_position, Color(0.9, 0.9, 0.9, 0.5), 8)
			"skeleton":
				get_parent().create_particles(global_position, Color(0.9, 0.9, 0.85, 0.8), 12)
				get_parent().create_particles(global_position, Color(0.6, 0.6, 0.55, 0.5), 8)
			"creeper":
				get_parent().create_particles(global_position, Color(0.3, 0.8, 0.2, 0.8), 12)
				get_parent().create_particles(global_position, Color(0.5, 0.5, 0.5, 0.5), 8)
	
	_schedule_respawn()
	queue_free()

func _schedule_respawn():
	var timer = Timer.new()
	timer.wait_time = 5.0
	timer.one_shot = true
	var type = enemy_type
	var pos = spawn_position
	timer.timeout.connect(func():
		var enemy_scene_res = load("res://src/enemy/enemy.tscn")
		var new_enemy = enemy_scene_res.instantiate()
		new_enemy.enemy_type = type
		new_enemy.position = pos
		get_parent().add_child(new_enemy)
		timer.queue_free()
	)
	get_parent().add_child(timer)
	timer.start()
