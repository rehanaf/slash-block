# sky_system.gd
# Renders sun, scrolling cloud background, and moon phases behind the world.
# Attach to a CanvasLayer (layer = -5) so it renders behind tiles.
extends Node2D

# ─────────────────────────────────────────────────────────────
#  TEXTURES
# ─────────────────────────────────────────────────────────────
const SUN_TEX   = preload("res://assets/environment/sun.png")
const MOON_TEX  = preload("res://assets/environment/moon_phases.png")
const CLOUD_TEX = preload("res://assets/environment/clouds.png")

# Moon: 512×256, 4 cols × 2 rows, each frame 128×128
const MOON_FRAME_W = 128
const MOON_FRAME_H = 128
const MOON_COLS    = 4
const MOON_PHASES  = 8   # 4×2

# ─────────────────────────────────────────────────────────────
#  ARC PARAMETERS  (viewport-space proportional)
# ─────────────────────────────────────────────────────────────
const ARC_W  = 0.92  # fraction of viewport width  (half-width of ellipse)
const ARC_H  = 0.60  # fraction of viewport height (height of arc)
const ARC_CY = 0.60  # arc center Y as fraction of viewport height

# ─────────────────────────────────────────────────────────────
#  CLOUD SCROLLING
# ─────────────────────────────────────────────────────────────
# clouds.png adalah background langit statis — tidak bergerak.
# Tile-nya hanya untuk menutupi seluruh lebar viewport.
const CLOUD_Y_FRACTION   = 0.50   # vertical center = middle of screen
const CLOUD_HEIGHT_FRAC  = 5.00   # 5x viewport height — zoomed in cloud detail

# ─────────────────────────────────────────────────────────────
#  NODES
# ─────────────────────────────────────────────────────────────
var _sun:              Sprite2D
var _moon:             Sprite2D
var _cloud_container:  Node2D     # scrolling container
var _cloud_tiles:      Array = [] # Sprite2D tiles inside container
var _cloud_tile_w:     float = 0.0

# ─────────────────────────────────────────────────────────────
#  DAY TRACKING
# ─────────────────────────────────────────────────────────────
var _prev_time: float = 0.0
var _day_index: int   = 0

# ─────────────────────────────────────────────────────────────
#  INIT
# ─────────────────────────────────────────────────────────────
func _ready() -> void:
	_build_clouds()
	_build_sun()
	_build_moon()

func _build_sun() -> void:
	_sun = Sprite2D.new()
	_sun.texture        = SUN_TEX
	_sun.texture_filter = TEXTURE_FILTER_NEAREST
	_sun.scale          = Vector2(8.0, 8.0)  # 16×16 → 128×128 px
	# Additive blend: sun glows against sky, no hard edge
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_sun.material = mat
	add_child(_sun)

func _build_moon() -> void:
	_moon = Sprite2D.new()
	_moon.texture        = MOON_TEX
	_moon.region_enabled = true
	_moon.region_rect    = Rect2(0, 0, MOON_FRAME_W, MOON_FRAME_H)
	_moon.texture_filter = TEXTURE_FILTER_NEAREST
	_moon.scale          = Vector2(1.5, 1.5)  # 128×128 → 192×192 px

	# Additive blending: black pixels become transparent,
	# bright moon pixels glow naturally against the dark sky.
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_moon.material = mat

	add_child(_moon)

func _build_clouds() -> void:
	var vp = _vp_size()

	# Scale cloud texture so its height fills CLOUD_HEIGHT_FRAC of the viewport
	var cloud_scale  = (vp.y * CLOUD_HEIGHT_FRAC) / 256.0
	_cloud_tile_w    = 256.0 * cloud_scale

	# How many tiles needed to cover viewport width + 1 extra for seamless loop
	var num_tiles    = int(ceil(vp.x / _cloud_tile_w)) + 2

	_cloud_container = Node2D.new()
	_cloud_container.position = Vector2(0.0, vp.y * CLOUD_Y_FRACTION)
	_cloud_container.modulate = Color(1, 1, 1, 0.0)  # alpha controlled in _process
	add_child(_cloud_container)

	# Shared additive material for all cloud tiles
	var cloud_mat = CanvasItemMaterial.new()
	cloud_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	for i in range(num_tiles):
		var s = Sprite2D.new()
		s.texture        = CLOUD_TEX
		s.texture_filter = TEXTURE_FILTER_NEAREST
		s.scale          = Vector2(cloud_scale, cloud_scale)
		# Sprite2D draws centered, so offset by half tile width
		s.position       = Vector2((i + 0.5) * _cloud_tile_w, 0.0)
		s.material       = cloud_mat
		_cloud_container.add_child(s)
		_cloud_tiles.append(s)

# ─────────────────────────────────────────────────────────────
#  UPDATE
# ─────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	var time = Global.get_time_of_day()
	var vp   = _vp_size()

	_track_day(time)
	_update_sun(time, vp)
	_update_moon(time, vp)
	_update_clouds(delta, time, vp)

	_prev_time = time

# ─────────────────────────────────────────────────────────────
#  DAY TRACKING
# ─────────────────────────────────────────────────────────────
func _track_day(time: float) -> void:
	if _prev_time > 0.9 and time < 0.1:
		_day_index += 1

# ─────────────────────────────────────────────────────────────
#  SUN
# ─────────────────────────────────────────────────────────────
func _update_sun(time: float, vp: Vector2) -> void:
	if time < 0.25 or time > 0.75:
		_sun.visible = false
		return

	var day_t = (time - 0.25) / 0.50           # 0=sunrise, 1=sunset
	var angle = lerp(PI, 0.0, day_t)

	_sun.position = Vector2(
		vp.x * 0.5 + cos(angle) * (vp.x * ARC_W * 0.5),
		vp.y * ARC_CY - sin(angle) * (vp.y * ARC_H)
	)

	# Warm orange at horizon, bright white at noon
	var noon_t = 1.0 - abs(day_t - 0.5) * 2.0
	_sun.modulate = Color(
		1.0,
		lerp(0.60, 1.00, noon_t),
		lerp(0.20, 0.95, noon_t),
		1.0
	)
	_sun.visible = true

# ─────────────────────────────────────────────────────────────
#  MOON
# ─────────────────────────────────────────────────────────────
func _update_moon(time: float, vp: Vector2) -> void:
	var night_t: float
	if time >= 0.75:
		night_t = (time - 0.75) / 0.50
	elif time <= 0.25:
		night_t = (time + 0.25) / 0.50
	else:
		_moon.visible = false
		return

	var angle = lerp(PI, 0.0, night_t)
	_moon.position = Vector2(
		vp.x * 0.5 + cos(angle) * (vp.x * ARC_W * 0.5),
		vp.y * ARC_CY - sin(angle) * (vp.y * ARC_H)
	)

	# Pick moon phase frame from 4×2 grid
	var phase = _day_index % MOON_PHASES
	var col   = phase % MOON_COLS
	var row   = phase / MOON_COLS
	_moon.region_rect = Rect2(col * MOON_FRAME_W, row * MOON_FRAME_H,
		MOON_FRAME_W, MOON_FRAME_H)

	# Additive blend handles color — just keep modulate white
	_moon.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_moon.visible  = true

# ─────────────────────────────────────────────────────────────
#  CLOUDS  (single scrolling background strip)
# ─────────────────────────────────────────────────────────────
func _update_clouds(delta: float, time: float, vp: Vector2) -> void:
	# Fade in saat siang (0.25–0.75), fade out saat dawn/dusk
	var alpha: float
	if time >= 0.25 and time <= 0.75:
		var fade_in  = clampf((time - 0.25) / 0.10, 0.0, 1.0)
		var fade_out = clampf((0.75 - time) / 0.10, 0.0, 1.0)
		alpha = min(fade_in, fade_out) * 0.80
	else:
		alpha = 0.0
	_cloud_container.modulate.a = alpha

	# Parallax: cloud bergeser sedikit mengikuti kamera (kedalaman jauh)
	var camera = get_viewport().get_camera_2d()
	if camera and _cloud_tile_w > 0.0:
		# Factor kecil (0.04) = awan bergerak 4% dari kecepatan dunia
		var parallax_x = fmod(camera.global_position.x * 0.04, _cloud_tile_w)
		_cloud_container.position.x = -parallax_x


# ─────────────────────────────────────────────────────────────
#  HELPER
# ─────────────────────────────────────────────────────────────
func _vp_size() -> Vector2:
	return get_viewport().get_visible_rect().size
