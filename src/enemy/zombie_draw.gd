extends Node2D

var left_leg_pivot: Node2D
var right_leg_pivot: Node2D
var left_arm_pivot: Node2D
var right_arm_pivot: Node2D
var body_pivot: Node2D
var head_pivot: Node2D

var is_moving: bool = false
var anim_time: float = 0.0

func _ready():
	var skin_path = "res://assets/entity/zombie/zombie.png"
	var skin_tex = load(skin_path)
	if not skin_tex:
		push_error("Failed to load zombie skin: " + skin_path)
		return
		
	var is_old_format = (skin_tex.get_height() == 32)
	
	# Option B (Pure Side-View coordinates)
	var regions = {
		"Head": Rect2(0, 8, 8, 8),
		"Body": Rect2(16, 20, 4, 12),
		"RightArm": Rect2(40, 20, 4, 12),
		"LeftArm": Rect2(40, 20, 4, 12) if is_old_format else Rect2(32, 52, 4, 12),
		"RightLeg": Rect2(0, 20, 4, 12),
		"LeftLeg": Rect2(0, 20, 4, 12) if is_old_format else Rect2(16, 52, 4, 12)
	}
	
	# Enable nearest texture filtering for crisp pixel art
	texture_filter = TEXTURE_FILTER_NEAREST
	
	# Create pivots and sprites
	# 1. Left Arm (back) - zombie arm raised forward (rotated -90 deg)
	left_arm_pivot = Node2D.new()
	left_arm_pivot.position = Vector2(0, -4)
	left_arm_pivot.rotation = -1.5708
	
	var left_arm = Sprite2D.new()
	left_arm.texture = skin_tex
	left_arm.region_enabled = true
	left_arm.region_rect = regions["LeftArm"]
	left_arm.position = Vector2(0, 4)
	left_arm.z_index = -2
	left_arm_pivot.add_child(left_arm)
	add_child(left_arm_pivot)
	
	# 2. Left Leg (back) - centered (x = 0)
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
	
	# 4. Right Leg (front) - centered (x = 0)
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
	
	# 5. Right Arm (front) - zombie arm raised forward (rotated -90 deg)
	right_arm_pivot = Node2D.new()
	right_arm_pivot.position = Vector2(0, -4)
	right_arm_pivot.rotation = -1.5708
	
	var right_arm = Sprite2D.new()
	right_arm.texture = skin_tex
	right_arm.region_enabled = true
	right_arm.region_rect = regions["RightArm"]
	right_arm.position = Vector2(0, 4)
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

func _process(delta):
	if is_moving:
		anim_time += delta
		var cycle = anim_time * 8.0
		left_leg_pivot.rotation = sin(cycle) * 0.4
		right_leg_pivot.rotation = -sin(cycle) * 0.4
		
		# Bobbing arms slightly
		left_arm_pivot.rotation = -1.5708 + sin(cycle) * 0.05
		right_arm_pivot.rotation = -1.5708 - sin(cycle) * 0.05
	else:
		anim_time = 0.0
		left_leg_pivot.rotation = 0.0
		right_leg_pivot.rotation = 0.0
		left_arm_pivot.rotation = -1.5708
		right_arm_pivot.rotation = -1.5708
