extends Control

# Joystick variables
var joystick_active = false
var joystick_center = Vector2(120, 500)
var joystick_pos = Vector2(120, 500)
const JOYSTICK_MAX_RADIUS = 120.0
const JOYSTICK_DEADZONE = 10.0
var joystick_touch_index = -1

# Buttons config
var buttons = {}

func _ready():
	# Make it full screen and ignore mouse events (so it doesn't block other UI)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Show on mobile devices, HTML5 mobile web, touchscreen, or in debug/editor runs!
	visible = OS.has_feature("mobile") or OS.has_feature("web") or DisplayServer.is_touchscreen_available() or OS.is_debug_build()
	
	setup_buttons()
	resized.connect(setup_buttons)
	if get_tree() and get_tree().root:
		get_tree().root.size_changed.connect(setup_buttons)


func setup_buttons():
	var view_size = get_viewport().get_visible_rect().size
	var target_ratio = 16.0 / 9.0
	var actual_ratio = view_size.x / view_size.y
	
	var margin_x = 0.0
	if actual_ratio > target_ratio:
		margin_x = (view_size.x - (view_size.y * target_ratio)) / 2.0
		
	# Shift the entire TouchControls container itself!
	offset_left = margin_x
	offset_right = -margin_x
	
	# Compute dimensions relative to the container coordinates
	var safe_width = view_size.x - 2.0 * margin_x
	var safe_height = view_size.y
	
	# Position joystick in bottom-left (relative to the container)
	joystick_center = Vector2(180, safe_height - 180)
	joystick_pos = joystick_center
	
	# Action buttons in bottom-right (relative to the container)
	buttons = {
		"attack": {
			"center": Vector2(safe_width - 140, safe_height - 140),
			"radius": 70.0,
			"color": Color(0.9, 0.2, 0.2, 0.35), # Transparent red
			"color_pressed": Color(0.9, 0.2, 0.2, 0.7),
			"action": "attack",
			"pressed": false,
			"touch_index": -1,
			"label": "ATTACK"
		},
		"jump": {
			"center": Vector2(safe_width - 320, safe_height - 140),
			"radius": 60.0,
			"color": Color(0.2, 0.6, 0.9, 0.35), # Transparent blue
			"color_pressed": Color(0.2, 0.6, 0.9, 0.7),
			"action": "jump",
			"pressed": false,
			"touch_index": -1,
			"label": "JUMP"
		},
		"dash": {
			"center": Vector2(safe_width - 140, safe_height - 320),
			"radius": 56.0,
			"color": Color(0.9, 0.7, 0.1, 0.35), # Transparent yellow
			"color_pressed": Color(0.9, 0.7, 0.1, 0.7),
			"action": "dash",
			"pressed": false,
			"touch_index": -1,
			"label": "DASH"
		}
	}
	queue_redraw()

func _input(event):
	# Allow toggling touch controls visibility on PC with the 'T' key for testing
	if event is InputEventKey and event.pressed and not event.is_echo() and event.keycode == KEY_T:
		visible = not visible
		queue_redraw()
		get_viewport().set_input_as_handled()
		return

	if not visible:
		return
		
	# Handle touch and mouse emulation
	var is_touch = event is InputEventScreenTouch
	var is_drag = event is InputEventScreenDrag
	
	# PC mouse testing support
	var is_mouse_click = event is InputEventMouseButton
	var is_mouse_motion = event is InputEventMouseMotion
	
	if is_touch or is_mouse_click or is_drag or is_mouse_motion:
		# Convert global event to local event coordinates to align with our shifted container!
		var local_event = make_input_local(event)
		var pos = local_event.position
		var index = event.index if (is_touch or is_drag) else 0
		
		if is_touch or is_mouse_click:
			var pressed = event.pressed if is_touch else event.is_pressed()
			
			# If click/touch is started
			if pressed:
				# Check action buttons
				for b_name in buttons.keys():
					var btn = buttons[b_name]
					if pos.distance_to(btn.center) < btn.radius:
						btn.pressed = true
						btn.touch_index = index
						
						# Press action
						Input.action_press(btn.action)
						var ev = InputEventAction.new()
						ev.action = btn.action
						ev.pressed = true
						Input.parse_input_event(ev)
						
						queue_redraw()
						get_viewport().set_input_as_handled()
						return
						
				# Check joystick area
				if pos.distance_to(joystick_center) < JOYSTICK_MAX_RADIUS + 40.0:
					joystick_active = true
					joystick_touch_index = index
					update_joystick(pos)
					get_viewport().set_input_as_handled()
			else:
				var handled_release = false
				# Release action buttons
				for b_name in buttons.keys():
					var btn = buttons[b_name]
					if btn.pressed and (not is_touch or btn.touch_index == index):
						btn.pressed = false
						btn.touch_index = -1
						
						# Release action
						Input.action_release(btn.action)
						var ev = InputEventAction.new()
						ev.action = btn.action
						ev.pressed = false
						Input.parse_input_event(ev)
						
						queue_redraw()
						handled_release = true
						
				# Release joystick
				if joystick_active and (not is_touch or joystick_touch_index == index):
					joystick_active = false
					joystick_touch_index = -1
					joystick_pos = joystick_center
					
					# Release movement actions
					Input.action_release("move_left")
					Input.action_release("move_right")
					Input.action_release("sneak")
					
					# Parse release events
					for act in ["move_left", "move_right", "sneak"]:
						var ev = InputEventAction.new()
						ev.action = act
						ev.pressed = false
						Input.parse_input_event(ev)
						
					queue_redraw()
					handled_release = true
					
				if handled_release:
					get_viewport().set_input_as_handled()
					
		elif is_drag or is_mouse_motion:
			# Dragging joystick
			if joystick_active and (not is_drag or joystick_touch_index == index):
				update_joystick(pos)
				get_viewport().set_input_as_handled()
				
			# Dragging off buttons (cancellation)
			for b_name in buttons.keys():
				var btn = buttons[b_name]
				if btn.pressed and (not is_drag or btn.touch_index == index):
					if pos.distance_to(btn.center) > btn.radius * 1.6:
						btn.pressed = false
						btn.touch_index = -1
						
						# Release action
						Input.action_release(btn.action)
						var ev = InputEventAction.new()
						ev.action = btn.action
						ev.pressed = false
						Input.parse_input_event(ev)
						
						queue_redraw()
						get_viewport().set_input_as_handled()

func update_joystick(touch_pos: Vector2):
	var dir = touch_pos - joystick_center
	var dist = dir.length()
	
	if dist > JOYSTICK_MAX_RADIUS:
		joystick_pos = joystick_center + dir.normalized() * JOYSTICK_MAX_RADIUS
	else:
		joystick_pos = touch_pos
		
	# Calculate input vector (-1.0 to 1.0)
	var input_vec = (joystick_pos - joystick_center) / JOYSTICK_MAX_RADIUS
	
	# Simulate Left/Right actions
	if input_vec.x < -0.3:
		# Press left
		if not Input.is_action_pressed("move_left"):
			Input.action_press("move_left")
			var ev = InputEventAction.new()
			ev.action = "move_left"
			ev.pressed = true
			Input.parse_input_event(ev)
		Input.action_release("move_right")
	elif input_vec.x > 0.3:
		# Press right
		if not Input.is_action_pressed("move_right"):
			Input.action_press("move_right")
			var ev = InputEventAction.new()
			ev.action = "move_right"
			ev.pressed = true
			Input.parse_input_event(ev)
		Input.action_release("move_left")
	else:
		# Reset horizontal
		Input.action_release("move_left")
		Input.action_release("move_right")
		
	# Simulate Down/Sneak action
	if input_vec.y > 0.5:
		if not Input.is_action_pressed("sneak"):
			Input.action_press("sneak")
			var ev = InputEventAction.new()
			ev.action = "sneak"
			ev.pressed = true
			Input.parse_input_event(ev)
	else:
		Input.action_release("sneak")
		
	queue_redraw()

func _draw():
	if not visible:
		return
		
	# Draw joystick background circle
	draw_circle(joystick_center, JOYSTICK_MAX_RADIUS, Color(0.1, 0.1, 0.1, 0.3))
	draw_circle(joystick_center, JOYSTICK_MAX_RADIUS, Color(1.0, 1.0, 1.0, 0.25), false, 2.0)
	
	# Draw joystick knob circle
	draw_circle(joystick_pos, 44.0, Color(0.8, 0.8, 0.8, 0.55))
	draw_circle(joystick_pos, 44.0, Color(1.0, 1.0, 1.0, 0.4), false, 2.0)
	
	# Draw action buttons
	for b_name in buttons.keys():
		var btn = buttons[b_name]
		var col = btn.color_pressed if btn.pressed else btn.color
		
		# Circle fill
		draw_circle(btn.center, btn.radius, col)
		# Circle border
		draw_circle(btn.center, btn.radius, Color(1, 1, 1, 0.35), false, 1.5)
		
		# Draw label text inside circle
		var font = get_theme_font("font")
		var font_size = 20
		var label_size = font.get_string_size(btn.label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(font, btn.center - label_size / 2.0 + Vector2(0, 7.0), btn.label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(1, 1, 1, 0.85))
