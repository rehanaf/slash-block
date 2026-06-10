# WorldGenerator.gd
# Procedural world generation using noise-based heightmaps, biome system,
# and 3D cave carving. Chunk-based so the world can extend infinitely.
class_name WorldGenerator

const TilesetBuilder = preload("res://src/world/tileset_builder.gd")

# ─────────────────────────────────────────────────────────────
#  CONSTANTS
# ─────────────────────────────────────────────────────────────
const CHUNK_WIDTH      = 16   # tiles per chunk (horizontal)
const SEA_LEVEL        = 8    # tile Y for surface (matches original world)
const DIRT_DEPTH       = 3    # how many dirt tiles below grass
const STONE_DEPTH      = 30   # how deep stone goes below dirt
const CAVE_THRESHOLD   = 0.38 # noise values above this = air (cave)
const ORE_CHANCE       = 0.10 # probability of coal ore in stone
const WORLD_SEED_BASE  = 42

# Biome IDs
const BIOME_PLAINS  = 0
const BIOME_FOREST  = 1
const BIOME_DESERT  = 2
const BIOME_SNOW    = 3

# ─────────────────────────────────────────────────────────────
#  PUBLIC CONFIG
# ─────────────────────────────────────────────────────────────
var world_seed: int = WORLD_SEED_BASE
var tile_map: TileMap = null
var resource_node_scene: PackedScene = null
var crafting_table_scene: PackedScene = null
var torch_scene: PackedScene = null
var world_node: Node2D = null  # parent node for entities

# ─────────────────────────────────────────────────────────────
#  NOISE INSTANCES
# ─────────────────────────────────────────────────────────────
var _height_noise: FastNoiseLite     # surface heightmap
var _biome_noise: FastNoiseLite      # biome temperature
var _cave_noise: FastNoiseLite       # 3D cave carving
var _feature_noise: FastNoiseLite    # tree/rock placement density
var _ore_noise: FastNoiseLite        # ore vein pattern
var _entrance_noise: FastNoiseLite   # cave entrance placement

# ─────────────────────────────────────────────────────────────
#  RUNTIME STATE
# ─────────────────────────────────────────────────────────────
var _generated_chunks: Dictionary = {}  # chunk_x → true

# ─────────────────────────────────────────────────────────────
#  INIT
# ─────────────────────────────────────────────────────────────
func setup(seed_value: int = WORLD_SEED_BASE) -> void:
	world_seed = seed_value
	_init_noise()

func _init_noise() -> void:
	# Height noise — smooth rolling terrain
	_height_noise = FastNoiseLite.new()
	_height_noise.seed = world_seed
	_height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_height_noise.frequency = 0.025
	_height_noise.fractal_octaves = 4
	_height_noise.fractal_lacunarity = 2.0
	_height_noise.fractal_gain = 0.5

	# Biome noise — large scale, very slow change
	_biome_noise = FastNoiseLite.new()
	_biome_noise.seed = world_seed + 1
	_biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_biome_noise.frequency = 0.005

	# Cave noise — 3D-style carving
	_cave_noise = FastNoiseLite.new()
	_cave_noise.seed = world_seed + 2
	_cave_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_cave_noise.frequency = 0.065
	_cave_noise.fractal_octaves = 2

	# Feature placement noise (trees, rocks)
	_feature_noise = FastNoiseLite.new()
	_feature_noise.seed = world_seed + 3
	_feature_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_feature_noise.frequency = 0.12

	# Ore vein noise
	_ore_noise = FastNoiseLite.new()
	_ore_noise.seed = world_seed + 4
	_ore_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ore_noise.frequency = 0.08

	# Cave entrance placement noise (controls where shafts spawn)
	_entrance_noise = FastNoiseLite.new()
	_entrance_noise.seed = world_seed + 5
	_entrance_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_entrance_noise.frequency = 0.04

# ─────────────────────────────────────────────────────────────
#  BIOME HELPERS
# ─────────────────────────────────────────────────────────────

## Returns a biome ID for a given world-space tile X.
func get_biome(tile_x: int) -> int:
	var v = _biome_noise.get_noise_1d(float(tile_x))
	if v < -0.4:
		return BIOME_SNOW
	elif v < -0.05:
		return BIOME_PLAINS
	elif v < 0.3:
		return BIOME_FOREST
	else:
		return BIOME_DESERT

## Returns terrain height amplitude for a biome.
func _biome_amplitude(biome: int) -> float:
	match biome:
		BIOME_PLAINS:  return 3.0
		BIOME_FOREST:  return 5.0
		BIOME_DESERT:  return 7.0
		BIOME_SNOW:    return 2.5
	return 3.0

## Returns surface tile type for a biome.
func _biome_surface_tile(biome: int) -> Vector2i:
	match biome:
		BIOME_DESERT: return TilesetBuilder.TILE_STONE       # sandy-looking
		BIOME_SNOW:   return TilesetBuilder.TILE_GRASS       # still grass in snow biome
		_:            return TilesetBuilder.TILE_GRASS

## Returns sub-surface tile for a biome.
func _biome_sub_tile(biome: int) -> Vector2i:
	match biome:
		BIOME_DESERT: return TilesetBuilder.TILE_COBBLESTONE # dry sub-surface
		_:            return TilesetBuilder.TILE_DIRT

## Returns tree density [0..1] per biome.
func _biome_tree_density(biome: int) -> float:
	match biome:
		BIOME_PLAINS:  return 0.15
		BIOME_FOREST:  return 0.50
		BIOME_DESERT:  return 0.0
		BIOME_SNOW:    return 0.06
	return 0.1

# ─────────────────────────────────────────────────────────────
#  SURFACE HEIGHT
# ─────────────────────────────────────────────────────────────

## Returns the surface tile Y coordinate for a given tile X.
## Lower Y = higher in the world (Godot's Y axis is inverted).
func get_surface_y(tile_x: int) -> int:
	var biome = get_biome(tile_x)
	var amplitude = _biome_amplitude(biome)
	var raw = _height_noise.get_noise_1d(float(tile_x))  # -1..1
	return SEA_LEVEL + int(round(raw * amplitude))

# ─────────────────────────────────────────────────────────────
#  CHUNK GENERATION
# ─────────────────────────────────────────────────────────────

## Generate a single chunk. chunk_x is in chunk coordinates (multiply by CHUNK_WIDTH for tile X).
func generate_chunk(chunk_x: int) -> void:
	if _generated_chunks.has(chunk_x):
		return
	_generated_chunks[chunk_x] = true

	var tile_x_start = chunk_x * CHUNK_WIDTH
	var tile_x_end   = tile_x_start + CHUNK_WIDTH

	for tile_x in range(tile_x_start, tile_x_end):
		_generate_column(tile_x)

	# Carve entrance shafts after columns are placed
	_carve_cave_entrances(chunk_x)

	if world_node:
		_spawn_chunk_features(chunk_x)

## Generate all chunks in a tile range [x_from, x_to].
func generate_range(tile_x_from: int, tile_x_to: int) -> void:
	var chunk_from = int(floor(float(tile_x_from) / CHUNK_WIDTH))
	var chunk_to   = int(floor(float(tile_x_to)   / CHUNK_WIDTH))
	for cx in range(chunk_from, chunk_to + 1):
		generate_chunk(cx)

# ─────────────────────────────────────────────────────────────
#  COLUMN GENERATION
# ─────────────────────────────────────────────────────────────
func _generate_column(tile_x: int) -> void:
	var biome    = get_biome(tile_x)
	var surf_y   = get_surface_y(tile_x)
	var surf_tile = _biome_surface_tile(biome)
	var sub_tile  = _biome_sub_tile(biome)

	# Surface (grass/stone/etc)
	tile_map.set_cell(0, Vector2i(tile_x, surf_y), TilesetBuilder.SOURCE_ID, surf_tile)

	# Sub-surface (dirt/cobble)
	for y in range(surf_y + 1, surf_y + DIRT_DEPTH + 1):
		tile_map.set_cell(0, Vector2i(tile_x, y), TilesetBuilder.SOURCE_ID, sub_tile)

	# Deep stone with caves and ores
	var stone_bottom = surf_y + DIRT_DEPTH + STONE_DEPTH + 1
	for y in range(surf_y + DIRT_DEPTH + 1, stone_bottom):
		var cx = float(tile_x)
		var cy = float(y)

		# Cave carving: use 2D noise evaluated at (x, y) to create hollow pockets
		var cave_val = abs(_cave_noise.get_noise_2d(cx, cy))
		if cave_val > CAVE_THRESHOLD:
			# Air — this creates the cave
			continue

		# Ore or stone
		var ore_val = _ore_noise.get_noise_2d(cx * 1.3, cy * 0.9)
		var depth_ratio = float(y - surf_y) / float(STONE_DEPTH)
		var ore_prob = ORE_CHANCE * depth_ratio  # deeper = more ore
		if ore_val > (1.0 - ore_prob * 2.0):
			tile_map.set_cell(0, Vector2i(tile_x, y), TilesetBuilder.SOURCE_ID, TilesetBuilder.TILE_COAL_ORE)
		else:
			tile_map.set_cell(0, Vector2i(tile_x, y), TilesetBuilder.SOURCE_ID, TilesetBuilder.TILE_STONE)

# ─────────────────────────────────────────────────────────────
#  CAVE ENTRANCE CARVING
# ─────────────────────────────────────────────────────────────

## Carves cave entrances at regular intervals so the player always finds one.
## One entrance every ENTRANCE_INTERVAL tiles, position jittered by noise.
## Always 2 tiles wide and always digs through dirt into stone.
func _carve_cave_entrances(chunk_x: int) -> void:
	const ENTRANCE_INTERVAL = 30  # tiles between entrances

	var tile_x_start = chunk_x * CHUNK_WIDTH
	var tile_x_end   = tile_x_start + CHUNK_WIDTH

	# Find every entrance whose anchor falls in this chunk
	var first_anchor = int(ceil(float(tile_x_start) / ENTRANCE_INTERVAL)) * ENTRANCE_INTERVAL
	var anchor = first_anchor
	while anchor < tile_x_end:
		# Jitter position within ±8 tiles using noise
		var jitter = int(_entrance_noise.get_noise_1d(float(anchor)) * 8.0)
		var entrance_x = anchor + jitter

		# Stay inside current chunk bounds
		if entrance_x >= tile_x_start and entrance_x < tile_x_end - 2:
			_carve_shaft(entrance_x)

		anchor += ENTRANCE_INTERVAL

## Carve a 2-wide vertical shaft at tile_x, from surface down into caves.
## Alternating zig-zag one-way platforms inside the shaft for climbing back out.
func _carve_shaft(tile_x: int) -> void:
	var surf_y    = get_surface_y(tile_x)
	var max_depth = DIRT_DEPTH + STONE_DEPTH

	# ── Step 1: Carve, tracking actual depth ─────────────────────
	var carved_depth = max_depth - 1  # default: full depth

	for w in range(2):
		var col = tile_x + w
		tile_map.set_cell(0, Vector2i(col, surf_y), -1)  # clear surface tile

		for dy in range(1, max_depth):
			var ty = surf_y + dy
			tile_map.set_cell(0, Vector2i(col, ty), -1)

			# Must clear all dirt before early-stopping
			if dy <= DIRT_DEPTH + 3:
				continue

			# Stop when connected to a pre-existing cave pocket
			var two_below = tile_map.get_cell_source_id(0, Vector2i(col, ty + 2))
			if w == 0 and two_below == -1:
				carved_depth = dy  # record actual depth from first column
			if two_below == -1:
				break

	# ── Step 2: Zig-zag platforms INSIDE the shaft ───────────────
	# Alternate between left column (tile_x) and right column (tile_x + 1)
	# every 4 tiles so player can jump between them to climb out.
	# Start below dirt layer so entrance opening feels natural.
	var platform_start_dy = DIRT_DEPTH + 2
	var platform_end_dy   = max(carved_depth - 1, platform_start_dy + 8)

	var step = 0
	var dy   = platform_start_dy
	while dy <= platform_end_dy:
		var ty = surf_y + dy
		# Even step = left column, odd step = right column
		var pcol = tile_x if step % 2 == 0 else tile_x + 1
		tile_map.set_cell(0, Vector2i(pcol, ty),
			TilesetBuilder.SOURCE_ID, TilesetBuilder.TILE_OAK_PLATFORM)
		step += 1
		dy   += 4

# ─────────────────────────────────────────────────────────────
#  FEATURE SPAWNING (Trees, Rocks, Crafting Table)
# ─────────────────────────────────────────────────────────────

## Spawns entities (trees, rocks) for a given chunk.
func _spawn_chunk_features(chunk_x: int) -> void:
	if not resource_node_scene or not world_node:
		return

	var tile_x_start = chunk_x * CHUNK_WIDTH
	var tile_x_end   = tile_x_start + CHUNK_WIDTH

	# Place crafting table in the very first chunk only
	if chunk_x == 0 and crafting_table_scene:
		var surf_y = get_surface_y(2)
		var table = crafting_table_scene.instantiate()
		table.position = Vector2(2 * 16.0, surf_y * 16.0)
		world_node.add_child(table)

	for tile_x in range(tile_x_start, tile_x_end):
		var biome    = get_biome(tile_x)
		var surf_y   = get_surface_y(tile_x)
		var world_pos = Vector2(tile_x * 16.0, surf_y * 16.0)

		var feat_val = _feature_noise.get_noise_1d(float(tile_x))

		var tree_density = _biome_tree_density(biome)

		# Tree placement
		if feat_val > (1.0 - tree_density) and biome != BIOME_DESERT:
			var tree = resource_node_scene.instantiate()
			tree.node_type = "tree"
			tree.drop_item_id = "wood"
			tree.position = world_pos
			world_node.add_child(tree)

		# Rock placement (sparse across all biomes)
		elif feat_val < -0.75:
			var rock = resource_node_scene.instantiate()
			rock.node_type = "rock"
			rock.drop_item_id = "stone"
			rock.position = world_pos
			world_node.add_child(rock)

## Spawn torches underground near cave openings (called post-generation).
func spawn_underground_torches(torch_scene_ref: PackedScene, parent: Node2D, count: int = 8) -> void:
	if not torch_scene_ref: return
	var rng = RandomNumberGenerator.new()
	rng.seed = world_seed + 99

	var attempts = 0
	var placed   = 0
	while placed < count and attempts < 1000:
		attempts += 1
		var tile_x = rng.randi_range(-30, 120)
		var surf_y = get_surface_y(tile_x)
		var cave_y = surf_y + rng.randi_range(DIRT_DEPTH + 3, DIRT_DEPTH + 15)

		# Check it's an air tile (cave)
		var cell = tile_map.get_cell_source_id(0, Vector2i(tile_x, cave_y))
		if cell == -1:
			# Check tile below is solid (torch needs a floor)
			var below = tile_map.get_cell_source_id(0, Vector2i(tile_x, cave_y + 1))
			if below != -1:
				var t = torch_scene_ref.instantiate()
				t.position = Vector2(tile_x * 16.0, cave_y * 16.0)
				parent.add_child(t)
				placed += 1

# ─────────────────────────────────────────────────────────────
#  RUNTIME CHUNK STREAMING
# ─────────────────────────────────────────────────────────────

## Call this every frame with the player's tile X to stream nearby chunks.
func stream_around(player_tile_x: int, radius_chunks: int = 6) -> void:
	var center_chunk = int(floor(float(player_tile_x) / CHUNK_WIDTH))
	for cx in range(center_chunk - radius_chunks, center_chunk + radius_chunks + 1):
		generate_chunk(cx)
