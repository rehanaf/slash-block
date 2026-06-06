extends CharacterBody2D

# Movement constants (in pixels, where 1 block = 16 pixels)
const BLOCK_SIZE = 16.0
const WALK_SPEED = 100.0
const ACCEL = 900.0
const FRICTION = 1000.0

# Jump calculations
const JUMP_HEIGHT_BLOCKS = 2.5
var jump_velocity: float = 0.0

# Double jump
var jumps_left: int = 2
const MAX_JUMPS = 2

# Dash state
const DASH_SPEED = 240.0
const DASH_DURATION = 0.20 # 240 * 0.20 = 48.0 pixels (3.0 blocks)
const DASH_COOLDOWN = 0.6
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT

# Attack combo state
# Area 2.0 blocks = 32 pixels
const ATTACK_RANGE_BLOCKS = 2.0
var combo_step: int = 0 # 0 = Idle, 1 = Hit 1, 2 = Hit 2, 3 = Hit 3
var combo_reset_timer: float = 0.0
const COMBO_WINDOW = 0.6
var attack_cooldown: float = 0.0
var current_attack_time: float = 0.0
var attack_duration: float = 0.3

# Skins list
var skins = ["captenpanez", "steve", "dream", "fiz"]
var current_skin_index = 0
var is_sneaking: bool = false
var drop_through_timer: float = 0.0

# Health system
var health: float = 100.0
const MAX_HEALTH = 100.0
var invulnerability_timer: float = 0.0
const INVULNERABILITY_DURATION = 1.0
var flash_timer: float = 0.0
var is_dead: bool = false

# Nodes cache
@onready var flipped_container = $FlippedContainer
@onready var bone_body = $FlippedContainer/Bones/Bone_Body
@onready var bone_head = $FlippedContainer/Bones/Bone_Body/Bone_Head
@onready var bone_left_arm = $FlippedContainer/Bones/Bone_Body/Bone_LeftArm
@onready var bone_right_arm = $FlippedContainer/Bones/Bone_Body/Bone_RightArm
@onready var bone_left_leg = $FlippedContainer/Bones/Bone_LeftLeg
@onready var bone_right_leg = $FlippedContainer/Bones/Bone_RightLeg
@onready var bone_sword = $FlippedContainer/Bones/Bone_Body/Bone_RightArm/Bone_Sword
@onready var attack_area = $FlippedContainer/AttackArea
@onready var slash_effect = $FlippedContainer/SlashEffect


# Procedural Animation helper variables
var anim_time: float = 0.0
var facing_direction: float = 1.0 # 1 = Right, -1 = Left
var body_original_y: float = 0.0
var is_preview: bool = false

# Custom animation variables
var disable_preview_anim: bool = false
var custom_animations: Dictionary = {}
var custom_anim_time: float = 0.0
var prev_state: String = ""

# Sound effects or hit signals
signal player_attacked(step)
signal skin_changed(new_skin_name)

func _ready():
	# Calculate jump velocity based on gravity to ensure it reaches exactly 2.5 blocks (40px)
	var gravity = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
	var target_jump_height = JUMP_HEIGHT_BLOCKS * BLOCK_SIZE
	# v^2 = 2 * g * h => v = sqrt(2 * g * h)
	jump_velocity = -sqrt(2.0 * gravity * target_jump_height)
	
	body_original_y = bone_body.position.y
	
	# Apply initial skin from Global autoload if available
	if has_node("/root/Global"):
		var global = get_node("/root/Global")
		var idx = skins.find(global.selected_skin)
		if idx != -1:
			current_skin_index = idx
	apply_skin(skins[current_skin_index])
	
	# Enable nearest filtering for all child sprites (pixel art crispness)
	flipped_container.texture_filter = TEXTURE_FILTER_NEAREST
	
	# Load any custom animation slots
	load_custom_animations()
	
	# Explicitly set collision layers to avoid physical collision with enemies
	collision_layer = 2
	collision_mask = 1

func _unhandled_input(event):
	if is_preview or is_dead:
		return
		
	if event.is_action_pressed("change_skin"):
		cycle_skin()
		
	if event.is_action_pressed("attack") and attack_cooldown <= 0:
		trigger_attack()
		
	if event.is_action_pressed("jump"):
		var sneak_pressed = Input.is_action_pressed("sneak")
		var on_one_way = false
		
		if sneak_pressed and is_on_floor():
			# Check if we are standing on a thin one-way platform
			for i in get_slide_collision_count():
				var collision = get_slide_collision(i)
				var collider = collision.get_collider()
				if collider is TileMap:
					if collision.get_normal().y < -0.9: # Landing/standing on top
						var local_point = collider.to_local(collision.get_position() - Vector2(0, -2))
						var tile_pos = collider.local_to_map(local_point)
						var atlas_coords = collider.get_cell_atlas_coords(0, tile_pos)
						if atlas_coords == Vector2i(0, 2):
							on_one_way = true
							break
		
		if on_one_way:
			# Drop through the one-way platform
			drop_through_timer = 0.15
			position.y += 4.0 # Push body down slightly past the 4px platform top
			velocity.y = 0.0 # Reset vertical velocity so gravity takes over smoothly
		else:
			# Normal Jump
			if is_on_floor():
				velocity.y = jump_velocity
				jumps_left = 1
				spawn_jump_particles()
			elif jumps_left > 0:
				velocity.y = jump_velocity
				jumps_left -= 1
				spawn_jump_particles()
				
	if event.is_action_pressed("dash") and dash_cooldown_timer <= 0:
		start_dash()

func _process(delta):
	if is_preview:
		if disable_preview_anim:
			return
		anim_time += delta
		var bob = sin(anim_time * 4.0) * 0.4
		bone_body.position.y = body_original_y + bob
		bone_head.position.y = -6.0 + bob * 0.5
		bone_head.rotation = sin(anim_time * 2.0) * 0.02
		
		bone_left_arm.rotation = -0.15 + sin(anim_time * 2.0) * 0.04
		bone_right_arm.rotation = 0.15 - sin(anim_time * 2.0) * 0.04
		
		bone_left_leg.rotation = -0.1
		bone_right_leg.rotation = 0.1
		bone_left_leg.position = Vector2(0.0, 6.0 - bob * 0.2)
		bone_right_leg.position = Vector2(0.0, 6.0 - bob * 0.2)
		
		bone_sword.rotation = lerp_angle(bone_sword.rotation, 0.0, 15.0 * delta)
		bone_sword.position = lerp(bone_sword.position, Vector2(0, 10.0), 15.0 * delta)
		return

	if is_dead:
		return

	# Update timers
	if invulnerability_timer > 0.0:
		invulnerability_timer -= delta
		
	if flash_timer > 0.0:
		flash_timer -= delta
		if flash_timer <= 0.0:
			flipped_container.modulate = Color.WHITE
		else:
			# Flashing red effect
			flipped_container.modulate = Color(1.0, 0.4, 0.4, 1.0)
			
	if combo_reset_timer > 0:
		combo_reset_timer -= delta
		if combo_reset_timer <= 0:
			combo_step = 0
			
	if attack_cooldown > 0:
		attack_cooldown -= delta
		current_attack_time += delta
		
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
		
	# (Polled action inputs moved to event-driven _unhandled_input)
		
	# Update animations
	animate_procedurally(delta)

func _physics_process(delta):
	if is_preview:
		return
		
	if is_dead:
		var gravity = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
		velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		move_and_slide()
		return
		
	# Handle drop through timer for one-way platform
	if drop_through_timer > 0.0:
		drop_through_timer -= delta
		set_collision_mask_value(1, false) # Disable environment collision
	else:
		set_collision_mask_value(1, true)  # Re-enable environment collision

	var gravity = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
	
	# Handle Dash active phase
	if is_dashing:
		dash_timer -= delta
		velocity = dash_direction * DASH_SPEED
		move_and_slide()
		
		# Spawn dash dust/ghost trail effect
		if Engine.get_physics_frames() % 2 == 0:
			create_ghost_trail()
			
		if dash_timer <= 0:
			is_dashing = false
			# Dampen speed slightly after dash
			velocity.x *= 0.5
		return

	# Add gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		jumps_left = MAX_JUMPS
		
	# Check sneak state (only on floor and when not attacking)
	is_sneaking = Input.is_action_pressed("sneak") and is_on_floor() and attack_cooldown <= 0

	# (Polled jump and dash inputs moved to event-driven _unhandled_input)

	# Handle horizontal movement
	var direction = 0.0
	if attack_cooldown <= 0:
		direction = Input.get_axis("move_left", "move_right")
	
	if direction != 0:
		facing_direction = sign(direction)
		flipped_container.scale.x = facing_direction
		
		# Accelerate
		var target_speed = WALK_SPEED
		if is_sneaking:
			target_speed = WALK_SPEED * 0.4 # Walk slower when sneaking (40% speed)
		velocity.x = move_toward(velocity.x, direction * target_speed, ACCEL * delta)
	else:
		if attack_cooldown > 0:
			# Auto-dash forward up to 16px to stop exactly at the edge of the block
			var safe_dist = get_safe_lunge_distance()
			velocity.x = facing_direction * (safe_dist / attack_duration)
		else:
			# Decelerate / Friction
			velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	move_and_slide()

func start_dash():
	is_dashing = true
	dash_timer = DASH_DURATION
	dash_cooldown_timer = DASH_COOLDOWN
	
	# Dash direction based on input, fallback to facing direction
	var input_dir = Input.get_axis("move_left", "move_right")
	if input_dir != 0:
		dash_direction = Vector2(sign(input_dir), 0)
	else:
		dash_direction = Vector2(facing_direction, 0)
		
	# Zero out vertical speed
	velocity.y = 0
	
	# Small screenshake/impact
	if get_parent() and get_parent().has_method("shake_camera"):
		get_parent().shake_camera(2.0, 0.1)

func trigger_attack():
	# Decide next combo step
	if combo_step == 0 or combo_reset_timer <= 0:
		combo_step = 1
	elif combo_step == 1:
		combo_step = 2
	elif combo_step == 2:
		combo_step = 3
	else:
		combo_step = 1 # Loop back
		
	# Setup cooldowns
	if combo_step == 3:
		attack_cooldown = 0.4
		attack_duration = 0.4
	else:
		attack_cooldown = 0.3
		attack_duration = 0.3
		
	current_attack_time = 0.0
	combo_reset_timer = COMBO_WINDOW
	
	# Trigger slash graphic effect
	if slash_effect:
		slash_effect.play_slash(combo_step)
		
	# Detect hits in Area2D
	check_attack_collisions()
	
	# Emit signal
	player_attacked.emit(combo_step)
	
	# Small camera shake on third hit
	if combo_step == 3 and get_parent() and get_parent().has_method("shake_camera"):
		get_parent().shake_camera(3.0, 0.15)

func check_attack_collisions():
	var targets = attack_area.get_overlapping_bodies()
	for target in targets:
		if target == self:
			continue
		if target.has_method("take_damage"):
			# Calculate damage and knockback
			var dmg = 10
			var kb_force = 120.0
			if combo_step == 2:
				dmg = 12
				kb_force = 150.0
			elif combo_step == 3:
				dmg = 20
				kb_force = 240.0
				
			var kb_dir = Vector2(facing_direction, -0.3).normalized()
			target.take_damage(dmg, kb_dir * kb_force)

func cycle_skin():
	current_skin_index = (current_skin_index + 1) % skins.size()
	var skin_name = skins[current_skin_index]
	apply_skin(skin_name)
	skin_changed.emit(skin_name)
	spawn_skin_particles()

func apply_skin(skin_name: String):
	var base_path = "res://assets/skin/" + skin_name + "/"
	
	# Verify we can load textures
	var head_tex = load(base_path + "head.png")
	var body_tex = load(base_path + "body.png")
	var l_arm_tex = load(base_path + "leftArm.png")
	var r_arm_tex = load(base_path + "rightArm.png")
	var l_leg_tex = load(base_path + "leftLeg.png")
	var r_leg_tex = load(base_path + "rightLeg.png")
	
	if head_tex: $FlippedContainer/Bones/Bone_Body/Bone_Head/Head.texture = head_tex
	if body_tex: $FlippedContainer/Bones/Bone_Body/Body.texture = body_tex
	if l_arm_tex: $FlippedContainer/Bones/Bone_Body/Bone_LeftArm/LeftArm.texture = l_arm_tex
	if r_arm_tex: $FlippedContainer/Bones/Bone_Body/Bone_RightArm/RightArm.texture = r_arm_tex
	if l_leg_tex: $FlippedContainer/Bones/Bone_LeftLeg/LeftLeg.texture = l_leg_tex
	if r_leg_tex: $FlippedContainer/Bones/Bone_RightLeg/RightLeg.texture = r_leg_tex


func animate_procedurally(delta):
	anim_time += delta
	
	# Track state transitions to reset custom animation playback timers
	var current_state = "idle"
	if abs(velocity.x) > 5.0 and is_on_floor():
		current_state = "walk"
	elif not is_on_floor():
		current_state = "air"
	elif is_dashing:
		current_state = "dash"
		
	if current_state != prev_state:
		custom_anim_time = 0.0
		prev_state = current_state
	
	# Default pivot transforms relative to body
	# Head: (0, -6), Body: (0, 0), Arms: (0, -4), Legs: Left (-1, 6), Right (1, 6)
	
	# Determine movement state (plays walk animation if keys are pressed, even when blocked by walls)
	var is_moving = (Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right")) and is_on_floor() and attack_cooldown <= 0
	var in_air = not is_on_floor()
	
	# 1. Idle Bobbing
	if not is_moving and not in_air and not is_dashing:
		if custom_animations.has("idle") and attack_cooldown <= 0:
			custom_anim_time += delta
			play_custom_animation("idle", custom_anim_time)
		else:
			var bob = sin(anim_time * 4.0) * 0.4
			if is_sneaking:
				# Sneak idle: crouched down
				bone_body.position.y = body_original_y + bob + 3.0
				bone_head.position.y = -12.0 - bob * 0.5 + 2.0
				bone_head.rotation = sin(anim_time * 2.0) * 0.02
				
				# Arms raised/bent slightly
				bone_left_arm.rotation = -0.3 + sin(anim_time * 2.0) * 0.04
				if attack_cooldown <= 0:
					bone_right_arm.rotation = 0.3 - sin(anim_time * 2.0) * 0.04
					
				# Legs bent
				bone_left_leg.rotation = -0.3
				bone_right_leg.rotation = 0.3
				bone_left_leg.position = Vector2(0.0, 4.0)
				bone_right_leg.position = Vector2(0.0, 4.0)
			else:
				bone_body.position.y = body_original_y + bob
				bone_head.position.y = -12.0 - bob * 0.5
				bone_head.rotation = sin(anim_time * 2.0) * 0.02

				# Arms rest slightly open
				bone_left_arm.rotation = -0.15 + sin(anim_time * 2.0) * 0.04
				if attack_cooldown <= 0:
					bone_right_arm.rotation = 0.15 - sin(anim_time * 2.0) * 0.04
					
				# Legs slightly open
				bone_left_leg.rotation = -0.1
				bone_right_leg.rotation = 0.1
				bone_left_leg.position = Vector2(0.0, 6.0 - bob * 0.2)
				bone_right_leg.position = Vector2(0.0, 6.0 - bob * 0.2)
		
	# 2. Walk Animation
	elif is_moving and not in_air and not is_dashing:
		if custom_animations.has("walk") and attack_cooldown <= 0:
			custom_anim_time += delta
			play_custom_animation("walk", custom_anim_time)
		else:
			# Faster oscillation for walk cycle
			var cycle = anim_time * 12.0
			var bob = abs(sin(cycle)) * 0.8
			if is_sneaking:
				# Sneak walking: lower posture and shorter swing
				bone_body.position.y = body_original_y - bob + 3.4
				bone_head.position.y = -12.4 + bob * 0.8 + 2.0
				bone_head.rotation = sin(cycle) * 0.03
				
				# Legs swing with smaller angle, bent posture
				bone_left_leg.rotation = sin(cycle) * 0.3 - 0.2
				bone_right_leg.rotation = -sin(cycle) * 0.3 + 0.2
				bone_left_leg.position = Vector2(0.0, 4.0)
				bone_right_leg.position = Vector2(0.0, 4.0)
				
				bone_left_arm.rotation = -sin(cycle) * 0.2 - 0.2
				if attack_cooldown <= 0:
					bone_right_arm.rotation = sin(cycle) * 0.2 + 0.2
			else:
				bone_body.position.y = body_original_y - bob + 0.4
				bone_head.position.y = -12.4 + bob * 0.8
				bone_head.rotation = sin(cycle) * 0.03
				
				# Legs swing back and forth
				bone_left_leg.rotation = sin(cycle) * 0.6
				bone_right_leg.rotation = -sin(cycle) * 0.6
				bone_left_leg.position = Vector2(0.0, 6.0)
				bone_right_leg.position = Vector2(0.0, 6.0)
				
				# Left arm swings in opposition to left leg
				bone_left_arm.rotation = -sin(cycle) * 0.4
				if attack_cooldown <= 0:
					# Right arm swings in opposition to right leg
					bone_right_arm.rotation = sin(cycle) * 0.4

	# 3. Jump/In Air Pose
	elif in_air and not is_dashing:
		bone_body.position.y = body_original_y
		bone_head.position.y = -12.0
		
		# Lean head slightly up/down based on vertical speed
		bone_head.rotation = clamp(velocity.y * 0.002, -0.2, 0.2)
		
		# Legs extended/spread
		bone_left_leg.rotation = -0.2
		bone_right_leg.rotation = 0.2
		
		# Arms raised slightly
		bone_left_arm.rotation = -0.3
		if attack_cooldown <= 0:
			bone_right_arm.rotation = -0.3

	# 4. Dash Pose
	elif is_dashing:
		# Body leans forward sharply
		bone_body.position.y = body_original_y + 1.0
		bone_head.position.y = -12.0
		bone_head.rotation = 0.25

		
		# Limbs trail behind
		bone_left_leg.rotation = -0.5
		bone_right_leg.rotation = -0.3
		bone_left_arm.rotation = -0.8
		if attack_cooldown <= 0:
			bone_right_arm.rotation = -1.2

	# 5. Handle Attack Animations (Right Arm override)
	if attack_cooldown > 0:
		if custom_animations.has("attack"):
			var anim = custom_animations["attack"]
			var anim_dur = anim.get("duration", 1.0)
			var t = (current_attack_time / attack_duration) * anim_dur
			var kfs = anim.get("keyframes", [])
			var pose = sample_custom_pose(kfs, t, anim_dur, false)
			apply_custom_pose(pose)
		else:
			var t = current_attack_time / attack_duration # 0.0 to 1.0
			
			if combo_step == 1:
				# Combo 1: Fast horizontal swing (from top-back to bottom-front)
				# Rotates right arm from -1.8 rad down to 1.2 rad
				bone_right_arm.rotation = lerp(-1.6, 1.0, ease_out_cubic(t))
			elif combo_step == 2:
				# Combo 2: Upward backhand slash (from bottom-back to top-front)
				# Rotates right arm from 1.5 rad up to -1.2 rad
				bone_right_arm.rotation = lerp(1.2, -1.4, ease_out_cubic(t))
			elif combo_step == 3:
				# Combo 3: Overhead spin/slam (spins all the way around)
				# Rotates right arm from -2.0 rad to 2.2 rad
				bone_right_arm.rotation = lerp(-2.2, 2.0, ease_out_cubic(t))

	# Keep sword holding angle diagonal relative to right arm
	# At rest, if right arm is 0 rad (straight down), we want the sword pointing forward-up (around 0.0 rad = 0 deg relative to arm, texture is already diagonal)
	if attack_cooldown <= 0:
		# Smoothly return sword to default diagonal stance (0.7854 rad = +45 deg relative to arm, forming a perpendicular 90-deg angle)
		if custom_animations.has("idle") and not is_moving and not in_air and not is_dashing:
			pass
		elif custom_animations.has("walk") and is_moving and not in_air and not is_dashing:
			pass
		else:
			bone_sword.rotation = lerp_angle(bone_sword.rotation, 0.7854, 15.0 * delta)
			bone_sword.position = lerp(bone_sword.position, Vector2(0, 10.0), 15.0 * delta)
	else:
		if custom_animations.has("attack"):
			pass
		else:
			# During attack, bend sword forward to align with swing direction relative to its +45 deg base
			var target_sword_rot = 1.08 if combo_step != 2 else 0.48
			bone_sword.rotation = lerp_angle(bone_sword.rotation, target_sword_rot, 25.0 * delta)
			bone_sword.position = lerp(bone_sword.position, Vector2(0, 10.0), 25.0 * delta)

# Ease function for snappy swing animations
func ease_out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)

# Visual effects spawners
func create_ghost_trail():
	# Spawn a temporary visual node for dash trail in the world
	var trail = Sprite2D.new()
	trail.texture = $FlippedContainer/Bones/Bone_Body/Body.texture
	trail.texture_filter = TEXTURE_FILTER_NEAREST
	trail.global_position = bone_body.global_position
	trail.global_rotation = bone_body.global_rotation
	trail.global_scale = global_scale * flipped_container.scale
	# Make it look like a red/blue glitch trail
	trail.modulate = Color(0.3, 0.7, 1.0, 0.5)
	get_parent().add_child(trail)
	
	# Tween to fade out and delete
	var tween = create_tween()
	tween.tween_property(trail, "modulate:a", 0.0, 0.2)
	tween.tween_callback(trail.queue_free)

func spawn_jump_particles():
	if get_parent() and get_parent().has_method("create_particles"):
		get_parent().create_particles(global_position + Vector2(0, 16), Color(0.9, 0.9, 0.9, 0.6), 8)

func spawn_skin_particles():
	if get_parent() and get_parent().has_method("create_particles"):
		get_parent().create_particles(global_position, Color(0.8, 1.0, 0.4, 0.8), 12)

# Helper functions for custom animation loading and playback
func load_custom_animations():
	custom_animations.clear()
	for slot in ["idle", "walk", "attack"]:
		var path = "user://custom_" + slot + ".json"
		if FileAccess.file_exists(path):
			var file = FileAccess.open(path, FileAccess.READ)
			if file:
				var content = file.get_as_text()
				file.close()
				var json = JSON.new()
				var parse_err = json.parse(content)
				if parse_err == OK:
					var data = json.get_data()
					if data is Dictionary and data.has("keyframes"):
						# Reconstruct keyframe poses properly, converting JSON fields
						var raw_keyframes = data["keyframes"]
						var parsed_keyframes = []
						for rkf in raw_keyframes:
							var kf_time = float(rkf["time"])
							var kf_rotations = {}
							for bone in rkf["rotations"].keys():
								var val = rkf["rotations"][bone]
								if val is Dictionary:
									kf_rotations[bone] = {
										"rot": float(val.get("rot", 0.0)),
										"off": Vector2(float(val.get("off_x", 0.0)), float(val.get("off_y", 0.0))),
										"scl": Vector2(float(val.get("scl_x", 1.0)), float(val.get("scl_y", 1.0))),
										"skw": Vector2(float(val.get("skw_x", 0.0)), float(val.get("skw_y", 0.0)))
									}
								else:
									# Backward compatibility: float rotation
									kf_rotations[bone] = {
										"rot": float(val),
										"off": Vector2.ZERO,
										"scl": Vector2.ONE,
										"skw": Vector2.ZERO
									}
							parsed_keyframes.append({
								"time": kf_time,
								"rotations": kf_rotations
							})

						
						custom_animations[slot] = {
							"duration": float(data.get("duration", 1.0)),
							"loop": bool(data.get("loop", true)),
							"keyframes": parsed_keyframes
						}
						print("Successfully loaded custom animation slot: ", slot)

func play_custom_animation(slot: String, time_in_anim: float):
	var anim = custom_animations[slot]
	var kfs = anim.get("keyframes", [])
	var loop_anim = anim.get("loop", true)
	var anim_duration = anim.get("duration", 1.0)
	
	var t = time_in_anim
	if loop_anim:
		t = fmod(t, anim_duration)
	else:
		t = min(t, anim_duration)
		
	var pose = sample_custom_pose(kfs, t, anim_duration, loop_anim)
	apply_custom_pose(pose)

func sample_custom_pose(kfs: Array, t: float, anim_dur: float, loop_anim: bool) -> Dictionary:
	if kfs.size() == 0:
		return {}
	if kfs.size() == 1:
		return kfs[0].rotations
		
	var kf_a = kfs[0]
	var kf_b = kfs[kfs.size() - 1]
	
	# Case: t is before the first keyframe
	if t <= kf_a.time:
		if loop_anim:
			kf_a = kfs[kfs.size() - 1]
			kf_b = kfs[0]
			var t_diff = (anim_dur - kf_a.time) + kf_b.time
			var w = 0.0
			if t_diff > 0.0:
				w = (t + (anim_dur - kf_a.time)) / t_diff
			return interpolate_custom_poses(kf_a.rotations, kf_b.rotations, w)
		else:
			return kf_a.rotations
			
	# Case: t is after the last keyframe
	if t >= kf_b.time:
		if loop_anim:
			kf_a = kfs[kfs.size() - 1]
			kf_b = kfs[0]
			var t_diff = (anim_dur - kf_a.time) + kf_b.time
			var w = 0.0
			if t_diff > 0.0:
				w = (t - kf_a.time) / t_diff
			return interpolate_custom_poses(kf_a.rotations, kf_b.rotations, w)
		else:
			return kf_b.rotations
			
	# Case: t is between two keyframes
	for i in range(kfs.size() - 1):
		if t >= kfs[i].time and t <= kfs[i+1].time:
			kf_a = kfs[i]
			kf_b = kfs[i+1]
			break
			
	var t_diff = kf_b.time - kf_a.time
	var w = 0.0
	if t_diff > 0.0:
		w = (t - kf_a.time) / t_diff
	return interpolate_custom_poses(kf_a.rotations, kf_b.rotations, w)

func interpolate_custom_poses(pose_a: Dictionary, pose_b: Dictionary, w: float) -> Dictionary:
	var pose_out = {}
	for bone in pose_a.keys():
		var b_a = pose_a[bone]
		var b_b = pose_b[bone]
		
		# Handle backward compatibility: check if float or Dictionary
		var rot_a = b_a.get("rot", 0.0) if b_a is Dictionary else b_a
		var rot_b = b_b.get("rot", 0.0) if b_b is Dictionary else b_b
		
		var off_a = b_a.get("off", Vector2.ZERO) if b_a is Dictionary else Vector2.ZERO
		var off_b = b_b.get("off", Vector2.ZERO) if b_b is Dictionary else Vector2.ZERO
		
		var scl_a = b_a.get("scl", Vector2.ONE) if b_a is Dictionary else Vector2.ONE
		var scl_b = b_b.get("scl", Vector2.ONE) if b_b is Dictionary else Vector2.ONE
		
		var skw_a = b_a.get("skw", Vector2.ZERO) if b_a is Dictionary else Vector2.ZERO
		var skw_b = b_b.get("skw", Vector2.ZERO) if b_b is Dictionary else Vector2.ZERO
		
		pose_out[bone] = {
			"rot": lerp_angle(rot_a, rot_b, w),
			"off": lerp(off_a, off_b, w),
			"scl": lerp(scl_a, scl_b, w),
			"skw": lerp(skw_a, skw_b, w)
		}
	return pose_out

func apply_custom_pose(pose: Dictionary):
	# Base position mapping
	var base_positions = {
		"body": Vector2(0, body_original_y),
		"head": Vector2(0, -12),
		"left_arm": Vector2(0, -10),
		"right_arm": Vector2(0, -10),
		"left_leg": Vector2(0, 6),
		"right_leg": Vector2(0, 6),
		"sword": Vector2(0, 10)
	}
	
	for bone_name in base_positions.keys():
		var bone = null
		match bone_name:
			"body": bone = bone_body
			"head": bone = bone_head
			"left_arm": bone = bone_left_arm
			"right_arm": bone = bone_right_arm
			"left_leg": bone = bone_left_leg
			"right_leg": bone = bone_right_leg
			"sword": bone = bone_sword
			
		if not bone:
			continue
			
		var b_pose = pose.get(bone_name, {
			"rot": 0.0,
			"off": Vector2.ZERO,
			"scl": Vector2.ONE,
			"skw": Vector2.ZERO
		})
		
		# If the loaded data was in old format (float rotation only)
		if b_pose is float:
			b_pose = {
				"rot": b_pose,
				"off": Vector2.ZERO,
				"scl": Vector2.ONE,
				"skw": Vector2.ZERO
			}
			
		var target_pos = base_positions[bone_name] + b_pose.get("off", Vector2.ZERO)
		
		# 1. Translation matrix
		var mat_trans = Transform2D(0.0, target_pos)
		
		# 2. Rotation matrix
		var mat_rot = Transform2D(b_pose.get("rot", 0.0), Vector2.ZERO)
		
		# 3. Skew/Shear matrix
		var skw = b_pose.get("skw", Vector2.ZERO)
		var mat_skew = Transform2D(
			Vector2(1.0, tan(skw.y)),
			Vector2(tan(skw.x), 1.0),
			Vector2.ZERO
		)
		
		# 4. Scale matrix
		var scl = b_pose.get("scl", Vector2.ONE)
		var mat_scale = Transform2D(
			Vector2(scl.x, 0.0),
			Vector2(0.0, scl.y),
			Vector2.ZERO
		)
		
		# Combine matrices: Translation * Rotation * Skew * Scale
		bone.transform = mat_trans * mat_rot * mat_skew * mat_scale


func get_safe_lunge_distance() -> float:
	if not is_on_floor():
		return 16.0
		
	var space_state = get_world_2d().direct_space_state
	
	# Build exclude list with player and all enemies
	var exclude_list = [get_rid()]
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is CollisionObject2D:
			exclude_list.append(enemy.get_rid())
			
	# Query 9 points from 16.0px ahead down to 0.0px to find the maximum safe lunge distance
	for dist in [16.0, 14.0, 12.0, 10.0, 8.0, 6.0, 4.0, 2.0, 0.0]:
		var check_x = facing_direction * dist
		var from_pos = global_position + Vector2(check_x, 0.0)
		var to_pos = global_position + Vector2(check_x, 40.0)
		
		var query = PhysicsRayQueryParameters2D.create(from_pos, to_pos)
		query.exclude = exclude_list
		query.collision_mask = 1 # ONLY detect TileMap (Layer 1), ignore Player (2) and Enemy (4)
		
		var result = space_state.intersect_ray(query)
		if not result.is_empty():
			return dist
	return 0.0

func take_damage(amount: float, kb: Vector2):
	if is_dead or invulnerability_timer > 0.0:
		return
		
	health -= amount
	invulnerability_timer = INVULNERABILITY_DURATION
	flash_timer = 0.2
	velocity = kb
	
	# Small camera shake
	if get_parent() and get_parent().has_method("shake_camera"):
		get_parent().shake_camera(4.0, 0.2)
		
	# Spawn damage particles
	if get_parent() and get_parent().has_method("create_particles"):
		get_parent().create_particles(global_position, Color(0.9, 0.15, 0.15, 0.8), 8)
		
	if health <= 0:
		die()

func die():
	is_dead = true
	health = 0.0
	velocity = Vector2.ZERO
	
	# Death particles
	if get_parent() and get_parent().has_method("create_particles"):
		get_parent().create_particles(global_position, Color(0.9, 0.1, 0.1, 0.95), 25)
		get_parent().create_particles(global_position, Color(0.15, 0.15, 0.15, 0.85), 20)
		
	# Display "YOU DIED" text
	var label = Label.new()
	label.text = "YOU DIED"
	label.scale = Vector2(0.4, 0.4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = global_position + Vector2(-36, -30)
	label.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1))
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 6)
	get_parent().add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 16, 1.5)
	tween.tween_callback(label.queue_free)
	
	# Reload scene after 1.5s
	get_tree().create_timer(1.5).timeout.connect(func():
		get_tree().reload_current_scene()
	)



