extends Node2D

var progress: float = 0.0
var step: int = 0

func play_slash(combo_step: int):
	step = combo_step
	progress = 1.0
	queue_redraw()

func _process(delta):
	if progress > 0.0:
		# Fast snappy fades: Combo 3 lasts slightly longer to feel heavier
		var speed = 7.5 if step != 3 else 5.5
		progress -= delta * speed
		if progress <= 0.0:
			progress = 0.0
		queue_redraw()

func _draw():
	if progress <= 0.0:
		return
		
	var t_anim = 1.0 - progress
	
	# Solid pixel art colors (matching the blue-and-white palette of the reference image)
	var color_white = Color(1.0, 1.0, 1.0)
	var color_light_blue = Color(0.55, 0.70, 1.0)
	var color_blue = Color(0.16, 0.36, 1.0)
	
	# Determine parameters based on step to form the exact arcs shown in reference image
	var start_angle = 0.0
	var end_angle = 0.0
	var r_start_radius = 18.0
	var r_end_radius = 26.0
	var max_width_base = 14.0 # Much thicker slash body
	var ellipse_scale = Vector2(1.1, 1.4) # Stretched vertically for Down/Up swings
	
	if step == 1:
		# Downward slash: sweeps top-front to bottom-front (opening left)
		start_angle = -1.4
		end_angle = 1.2
		r_start_radius = 18.0
		r_end_radius = 26.0
		max_width_base = 14.0
		ellipse_scale = Vector2(1.1, 1.4)
	elif step == 2:
		# Upward slash: sweeps bottom-front to top-front (opening left)
		start_angle = 1.2
		end_angle = -1.4
		r_start_radius = 18.0
		r_end_radius = 26.0
		max_width_base = 14.0
		ellipse_scale = Vector2(1.1, 1.4)
	elif step == 3:
		# Heavy swing: longer, much thicker diagonal lunge slash (stretched forward)
		start_angle = 0.8
		end_angle = -1.6
		r_start_radius = 20.0
		r_end_radius = 32.0
		max_width_base = 18.0
		ellipse_scale = Vector2(1.5, 1.1)
		
	# Dynamic expansion of the radius over time (the whole slash expands slightly as it fades)
	var expansion = lerp(0.0, 4.0, t_anim)
	var max_width = max_width_base * progress # Thins out over progress
	
	# Calculate divisions dynamically to ensure a solid, gap-free pixelated curve
	var max_r_current = r_end_radius + expansion
	var arc_length = max_r_current * abs(start_angle - end_angle)
	var scale_factor = max(ellipse_scale.x, ellipse_scale.y)
	var divisions = int(arc_length * 1.5 * scale_factor)
	if divisions < 15:
		divisions = 15
		
	var grid_size = 1.0
	
	for i in range(divisions + 1):
		var t = float(i) / divisions
		var angle = lerp(start_angle, end_angle, t)
		
		# Spiral radius: grows from r_start_radius to r_end_radius along the swing path.
		# This gives the slash its natural expanding spiral curve instead of a static circle segment.
		var r_center = lerp(r_start_radius, r_end_radius, t) + expansion
		
		# Asymmetric crescent thickness: peak thickness shifted towards the head (t = 0.65)
		# This creates a long, elegant trailing tail and a sharp, swift leading tip.
		var tip_fade = sin(pow(t, 1.3) * PI)
		var width = max_width * tip_fade
		
		var r_start = r_center - width / 2.0
		var r_end = r_center + width / 2.0
		
		var dir = Vector2(cos(angle), sin(angle))
		
		# Apply ellipse scaling to direction vector
		var ellipse_dir = Vector2(dir.x * ellipse_scale.x, dir.y * ellipse_scale.y)
		
		# Draw pixel blocks along the thickness
		var r = r_start
		while r <= r_end:
			var r_ratio = 0.0
			if r_end > r_start:
				r_ratio = (r - r_start) / (r_end - r_start)
				
			# Layered shading logic:
			# - Outer edge is white
			# - Middle is light blue highlight
			# - Inner edge is rich blue
			# - Tips and tail are mostly blue/light blue to taper naturally
			var col = color_blue
			
			if r_ratio > 0.65 and tip_fade > 0.25 and t > 0.15:
				col = color_white
			elif r_ratio > 0.35 and r_ratio <= 0.65 and tip_fade > 0.35:
				col = color_light_blue
			else:
				col = color_blue
				
			# Apply fading alpha over the animation progress and tips
			var final_color = col
			final_color.a = progress * tip_fade * 0.95
			
			# Calculate final position using the scaled ellipse direction
			var pos = ellipse_dir * r
			
			# Snap to pixel grid (matches the game's blocky resolution)
			var snapped_pos = (pos / grid_size).round() * grid_size
			# Draw a pixel block
			draw_rect(Rect2(snapped_pos - Vector2(grid_size/2.0, grid_size/2.0), Vector2(grid_size, grid_size)), final_color)
			r += grid_size
