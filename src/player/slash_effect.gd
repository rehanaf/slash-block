extends Node2D

# References
@onready var bone_sword = $"../Bones/Bone_Body/Bone_RightArm/Bone_Sword"

# Trail settings
var trail_points = []
const TRAIL_LIFETIME = 0.20 # How long each trail segment lasts in seconds

# State
var is_active = false
var current_color = Color(0.16, 0.55, 1.0)
var active_timer = 0.0
var max_active_time = 0.35 # Attack swing duration

func play_slash(combo_step: int, skin_color: Color):
	current_color = skin_color
	is_active = true
	# Combo 3 swing lasts slightly longer
	max_active_time = 0.45 if combo_step == 3 else 0.30
	active_timer = max_active_time
	
	# Clear previous trail
	trail_points.clear()
	queue_redraw()

func _process(delta):
	# Update existing trail points lifetime
	for i in range(trail_points.size() - 1, -1, -1):
		trail_points[i].time_left -= delta
		if trail_points[i].time_left <= 0.0:
			trail_points.remove_at(i)
			
	if is_active:
		active_timer -= delta
		if active_timer <= 0.0:
			is_active = false
		
		# Sample current sword position
		if bone_sword:
			# Define base and tip offsets relative to Bone_Sword in local space
			var sword_base_offset = Vector2(2, -2)
			var sword_tip_offset = Vector2(16, -16)
			
			var global_base = bone_sword.to_global(sword_base_offset)
			var global_tip = bone_sword.to_global(sword_tip_offset)
			
			var local_base = to_local(global_base)
			var local_tip = to_local(global_tip)
			
			# Add to trail history
			trail_points.push_front({
				"base": local_base,
				"tip": local_tip,
				"time_left": TRAIL_LIFETIME,
				"max_time": TRAIL_LIFETIME
			})
			
	queue_redraw()

func _draw():
	if trail_points.size() < 2:
		return
		
	# Draw ribbon segments
	for i in range(trail_points.size() - 1):
		var p1 = trail_points[i]
		var p2 = trail_points[i + 1]
		
		var alpha1 = p1.time_left / p1.max_time
		var alpha2 = p2.time_left / p2.max_time
		
		# Base color palette derived from skin_color
		# White/light core at the tip, colored body, dark/alpha fade at the base
		var col_tip1 = Color.WHITE
		col_tip1.a = alpha1 * 0.95
		
		var col_body1 = current_color
		col_body1.a = alpha1 * 0.85
		
		var col_base1 = current_color.darkened(0.4)
		col_base1.a = alpha1 * 0.3
		
		var col_tip2 = Color.WHITE
		col_tip2.a = alpha2 * 0.95
		
		var col_body2 = current_color
		col_body2.a = alpha2 * 0.85
		
		var col_base2 = current_color.darkened(0.4)
		col_base2.a = alpha2 * 0.3
		
		# We draw the ribbon in two parts (inner-to-middle and middle-to-tip)
		# to form a beautiful gradient slash trail
		var mid1 = p1.base.lerp(p1.tip, 0.45)
		var mid2 = p2.base.lerp(p2.tip, 0.45)
		
		# Part 1 (Base to Mid):
		# Draw as two triangles to prevent triangulation failure on self-intersecting quads
		draw_polygon(
			PackedVector2Array([p1.base, mid1, mid2]),
			PackedColorArray([col_base1, col_body1, col_body2])
		)
		draw_polygon(
			PackedVector2Array([p1.base, mid2, p2.base]),
			PackedColorArray([col_base1, col_body2, col_base2])
		)
		
		# Part 2 (Mid to Tip):
		draw_polygon(
			PackedVector2Array([mid1, p1.tip, p2.tip]),
			PackedColorArray([col_body1, col_tip1, col_tip2])
		)
		draw_polygon(
			PackedVector2Array([mid1, p2.tip, mid2]),
			PackedColorArray([col_body1, col_tip2, col_body2])
		)
