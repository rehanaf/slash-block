extends Node2D

# References
@onready var bone_sword = $"../Bones/Bone_Body/Bone_RightArm/Bone_Sword"

func _ready():
	top_level = true


# Trail settings
var trail_points = []
const TRAIL_LIFETIME = 0.20 # How long each trail segment lasts in seconds

# State
var is_active = false
var color_inner = Color(0.1, 0.45, 0.95)
var color_outer = Color(0.45, 0.85, 1.0)
var active_timer = 0.0
var max_active_time = 0.35 # Attack swing duration

func play_slash(combo_step: int, inner: Color, outer: Color):
	color_inner = inner
	color_outer = outer
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

func is_degenerate(a: Vector2, b: Vector2, c: Vector2) -> bool:
	return abs((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)) < 0.01

func _draw():
	if trail_points.size() < 2:
		return
		
	# Draw ribbon segments with a smooth inner-to-outer color gradient
	for i in range(trail_points.size() - 1):
		var p1 = trail_points[i]
		var p2 = trail_points[i + 1]
		
		var alpha1 = p1.time_left / p1.max_time
		var alpha2 = p2.time_left / p2.max_time
		
		# Inner edge colors (at the sword hilt)
		var col_inner1 = color_inner
		col_inner1.a = alpha1 * 0.85
		
		var col_inner2 = color_inner
		col_inner2.a = alpha2 * 0.85
		
		# Outer edge colors (at the sword tip)
		var col_outer1 = color_outer
		col_outer1.a = alpha1 * 0.85
		
		var col_outer2 = color_outer
		col_outer2.a = alpha2 * 0.85
		
		# Midpoint colors for smooth interpolation
		var col_mid1 = color_inner.lerp(color_outer, 0.5)
		col_mid1.a = alpha1 * 0.85
		
		var col_mid2 = color_inner.lerp(color_outer, 0.5)
		col_mid2.a = alpha2 * 0.85
		
		var mid1 = p1.base.lerp(p1.tip, 0.5)
		var mid2 = p2.base.lerp(p2.tip, 0.5)
		
		# Part 1 (Base to Mid):
		# Draw as two triangles to prevent triangulation failure on self-intersecting quads
		if not is_degenerate(p1.base, mid1, mid2):
			draw_polygon(
				PackedVector2Array([p1.base, mid1, mid2]),
				PackedColorArray([col_inner1, col_mid1, col_mid2])
			)
		if not is_degenerate(p1.base, mid2, p2.base):
			draw_polygon(
				PackedVector2Array([p1.base, mid2, p2.base]),
				PackedColorArray([col_inner1, col_mid2, col_inner2])
			)
		
		# Part 2 (Mid to Tip):
		if not is_degenerate(mid1, p1.tip, p2.tip):
			draw_polygon(
				PackedVector2Array([mid1, p1.tip, p2.tip]),
				PackedColorArray([col_mid1, col_outer1, col_outer2])
			)
		if not is_degenerate(mid1, p2.tip, mid2):
			draw_polygon(
				PackedVector2Array([mid1, p2.tip, mid2]),
				PackedColorArray([col_mid1, col_outer2, col_mid2])
			)

