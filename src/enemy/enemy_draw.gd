extends Node2D

var enemy_type: String = "zombie"

# Shared pivots (humanoid)
var left_leg_pivot: Node2D
var right_leg_pivot: Node2D
var left_arm_pivot: Node2D
var right_arm_pivot: Node2D
var body_pivot: Node2D
var head_pivot: Node2D

# Creeper extra leg pivots (back pair)
var back_left_leg_pivot: Node2D
var back_right_leg_pivot: Node2D

var is_moving: bool = false
var anim_time: float = 0.0

# Creeper fuse visual
var fuse_progress: float = 0.0
var base_scale: Vector2 = Vector2.ONE

func setup(type: String):
	enemy_type = type
	_build_body()
	base_scale = scale

func _build_body():
	var skin_path: String
	match enemy_type:
		"zombie": skin_path = "res://assets/entity/zombie/zombie.png"
		"skeleton": skin_path = "res://assets/entity/skeleton/skeleton.png"
		"creeper": skin_path = "res://assets/entity/creeper/creeper.png"
		_: skin_path = "res://assets/entity/zombie/zombie.png"
	
	var skin_tex = load(skin_path)
	if not skin_tex:
		push_error("Failed to load enemy skin: " + skin_path)
		return
	
	var is_old_format = (skin_tex.get_height() == 32)
	texture_filter = TEXTURE_FILTER_NEAREST
	
	match enemy_type:
		"creeper": _build_creeper(skin_tex)
		"skeleton": _build_humanoid(skin_tex, is_old_format, true)
		_: _build_humanoid(skin_tex, is_old_format, false)

func _build_humanoid(skin_tex, is_old_format: bool, thin: bool):
	var limb_w = 2 if thin else 4
	
	var regions = {
		"Head": Rect2(0, 8, 8, 8),
		"Body": Rect2(16, 20, limb_w, 12),
		"RightArm": Rect2(40, 20, limb_w, 12),
		"LeftArm": Rect2(40, 20, limb_w, 12) if is_old_format else Rect2(32, 52, limb_w, 12),
		"RightLeg": Rect2(0, 20, limb_w, 12),
		"LeftLeg": Rect2(0, 20, limb_w, 12) if is_old_format else Rect2(16, 52, limb_w, 12)
	}
	
	# Zombie arms raised forward, Skeleton arms hang down
	var arm_rot = -1.5708 if enemy_type == "zombie" else 0.0
	var arm_offset_y = 4.0 if enemy_type == "zombie" else 6.0
	
	# 1. Left Arm (back)
	left_arm_pivot = Node2D.new()
	left_arm_pivot.position = Vector2(0, -4)
	left_arm_pivot.rotation = arm_rot
	var left_arm = Sprite2D.new()
	left_arm.texture = skin_tex
	left_arm.region_enabled = true
	left_arm.region_rect = regions["LeftArm"]
	left_arm.position = Vector2(0, arm_offset_y)
	left_arm.z_index = -2
	left_arm_pivot.add_child(left_arm)
	add_child(left_arm_pivot)
	
	# 2. Left Leg (back)
	left_leg_pivot = Node2D.new()
	left_leg_pivot.position = Vector2(0, 6)
	var left_leg = Sprite2D.new()
	left_leg.texture = skin_tex
	left_leg.region_enabled = true
	left_leg.region_rect = regions["LeftLeg"]
	left_leg.position = Vector2(0, 5)
	left_leg.z_index = -1
	left_leg_pivot.add_child(left_leg)
	add_child(left_leg_pivot)
	
	# 3. Body
	body_pivot = Node2D.new()
	body_pivot.position = Vector2(0, 0)
	var body = Sprite2D.new()
	body.texture = skin_tex
	body.region_enabled = true
	body.region_rect = regions["Body"]
	body.position = Vector2(0, 0)
	body.z_index = 0
	body_pivot.add_child(body)
	add_child(body_pivot)
	
	# 4. Right Leg (front)
	right_leg_pivot = Node2D.new()
	right_leg_pivot.position = Vector2(0, 6)
	var right_leg = Sprite2D.new()
	right_leg.texture = skin_tex
	right_leg.region_enabled = true
	right_leg.region_rect = regions["RightLeg"]
	right_leg.position = Vector2(0, 5)
	right_leg.z_index = 1
	right_leg_pivot.add_child(right_leg)
	add_child(right_leg_pivot)
	
	# 5. Right Arm (front)
	right_arm_pivot = Node2D.new()
	right_arm_pivot.position = Vector2(0, -4)
	right_arm_pivot.rotation = arm_rot
	var right_arm = Sprite2D.new()
	right_arm.texture = skin_tex
	right_arm.region_enabled = true
	right_arm.region_rect = regions["RightArm"]
	right_arm.position = Vector2(0, arm_offset_y)
	right_arm.z_index = 2
	right_arm_pivot.add_child(right_arm)
	add_child(right_arm_pivot)
	
	# 6. Head
	head_pivot = Node2D.new()
	head_pivot.position = Vector2(0, -6)
	var head = Sprite2D.new()
	head.texture = skin_tex
	head.region_enabled = true
	head.region_rect = regions["Head"]
	head.position = Vector2(0, -4)
	head.z_index = 0
	head_pivot.add_child(head)
	add_child(head_pivot)

func _build_creeper(skin_tex):
	var leg_region = Rect2(0, 20, 4, 6)
	
	# 1. Back Left Leg (far side)
	back_left_leg_pivot = Node2D.new()
	back_left_leg_pivot.position = Vector2(0, 6)
	var bl_leg = Sprite2D.new()
	bl_leg.texture = skin_tex
	bl_leg.region_enabled = true
	bl_leg.region_rect = leg_region
	bl_leg.position = Vector2(0, 3)
	bl_leg.z_index = -2
	back_left_leg_pivot.add_child(bl_leg)
	add_child(back_left_leg_pivot)
	
	# 2. Back Right Leg (far side)
	back_right_leg_pivot = Node2D.new()
	back_right_leg_pivot.position = Vector2(0, 6)
	var br_leg = Sprite2D.new()
	br_leg.texture = skin_tex
	br_leg.region_enabled = true
	br_leg.region_rect = leg_region
	br_leg.position = Vector2(0, 3)
	br_leg.z_index = -1
	back_right_leg_pivot.add_child(br_leg)
	add_child(back_right_leg_pivot)
	
	# 3. Body
	body_pivot = Node2D.new()
	body_pivot.position = Vector2(0, 0)
	var body = Sprite2D.new()
	body.texture = skin_tex
	body.region_enabled = true
	body.region_rect = Rect2(16, 20, 4, 12)
	body.position = Vector2(0, 0)
	body.z_index = 0
	body_pivot.add_child(body)
	add_child(body_pivot)
	
	# 4. Front Left Leg (near side) - reuse left_leg_pivot for animation compat
	left_leg_pivot = Node2D.new()
	left_leg_pivot.position = Vector2(0, 6)
	var fl_leg = Sprite2D.new()
	fl_leg.texture = skin_tex
	fl_leg.region_enabled = true
	fl_leg.region_rect = leg_region
	fl_leg.position = Vector2(0, 3)
	fl_leg.z_index = 1
	left_leg_pivot.add_child(fl_leg)
	add_child(left_leg_pivot)
	
	# 5. Front Right Leg (near side) - reuse right_leg_pivot for animation compat
	right_leg_pivot = Node2D.new()
	right_leg_pivot.position = Vector2(0, 6)
	var fr_leg = Sprite2D.new()
	fr_leg.texture = skin_tex
	fr_leg.region_enabled = true
	fr_leg.region_rect = leg_region
	fr_leg.position = Vector2(0, 3)
	fr_leg.z_index = 2
	right_leg_pivot.add_child(fr_leg)
	add_child(right_leg_pivot)
	
	# 6. Head
	head_pivot = Node2D.new()
	head_pivot.position = Vector2(0, -6)
	var head = Sprite2D.new()
	head.texture = skin_tex
	head.region_enabled = true
	head.region_rect = Rect2(0, 8, 8, 8)
	head.position = Vector2(0, -4)
	head.z_index = 3
	head_pivot.add_child(head)
	add_child(head_pivot)

# --- Creeper Fuse Visual ---
func set_fuse_progress(progress: float):
	fuse_progress = progress
	if progress > 0:
		# Swell effect
		var swell = 1.0 + progress * 0.35
		scale = base_scale * swell
		# Flash white/red with increasing frequency
		var flash_speed = 6.0 + progress * 14.0
		var flash = fmod(fuse_progress * flash_speed, 1.0)
		if flash > 0.5:
			modulate = Color(1.8, 1.8, 1.8)
		else:
			modulate = Color(1.0 + progress, 1.0 - progress * 0.7, 1.0 - progress * 0.7)
	else:
		modulate = Color.WHITE
		scale = base_scale

# --- Animation ---
func _process(delta):
	match enemy_type:
		"creeper": _animate_creeper(delta)
		_: _animate_humanoid(delta)

func _animate_humanoid(delta):
	if is_moving:
		anim_time += delta
		var cycle = anim_time * 8.0
		if left_leg_pivot:
			left_leg_pivot.rotation = sin(cycle) * 0.4
		if right_leg_pivot:
			right_leg_pivot.rotation = -sin(cycle) * 0.4
		
		if enemy_type == "zombie":
			if left_arm_pivot:
				left_arm_pivot.rotation = -1.5708 + sin(cycle) * 0.05
			if right_arm_pivot:
				right_arm_pivot.rotation = -1.5708 - sin(cycle) * 0.05
		elif enemy_type == "skeleton":
			if left_arm_pivot:
				left_arm_pivot.rotation = -sin(cycle) * 0.3
			if right_arm_pivot:
				right_arm_pivot.rotation = sin(cycle) * 0.3
	else:
		anim_time = 0.0
		if left_leg_pivot:
			left_leg_pivot.rotation = 0.0
		if right_leg_pivot:
			right_leg_pivot.rotation = 0.0
		
		if enemy_type == "zombie":
			if left_arm_pivot:
				left_arm_pivot.rotation = -1.5708
			if right_arm_pivot:
				right_arm_pivot.rotation = -1.5708
		elif enemy_type == "skeleton":
			if left_arm_pivot:
				left_arm_pivot.rotation = 0.0
			if right_arm_pivot:
				right_arm_pivot.rotation = 0.0

func _animate_creeper(delta):
	if is_moving:
		anim_time += delta
		var cycle = anim_time * 8.0
		# Quadruped gait: front-right + back-left in phase, opposite pair out of phase
		if right_leg_pivot:
			right_leg_pivot.rotation = sin(cycle) * 0.35
		if back_left_leg_pivot:
			back_left_leg_pivot.rotation = sin(cycle) * 0.35
		if left_leg_pivot:
			left_leg_pivot.rotation = -sin(cycle) * 0.35
		if back_right_leg_pivot:
			back_right_leg_pivot.rotation = -sin(cycle) * 0.35
	else:
		anim_time = 0.0
		for pivot in [left_leg_pivot, right_leg_pivot, back_left_leg_pivot, back_right_leg_pivot]:
			if pivot:
				pivot.rotation = 0.0
