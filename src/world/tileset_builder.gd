# TilesetBuilder.gd
# Responsible for constructing the TileSet programmatically.
# Extracted from world.gd to keep concerns separated.
class_name TilesetBuilder

## Tile atlas coordinates (correspond to generate_tileset.py layout)
const TILE_GRASS        = Vector2i(0, 0)
const TILE_DIRT         = Vector2i(1, 0)
const TILE_STONE        = Vector2i(2, 0)
const TILE_COBBLESTONE  = Vector2i(3, 0)
const TILE_OAK_WOOD     = Vector2i(0, 1)
const TILE_BRICK        = Vector2i(1, 1)
const TILE_COAL_ORE     = Vector2i(2, 1)
const TILE_GLASS        = Vector2i(3, 1) # No physics
const TILE_OAK_PLATFORM = Vector2i(0, 2) # One-way thin platform

## Source ID used when adding the atlas source to the TileSet
const SOURCE_ID = 1

## Build and return a fully configured TileSet, then assign it to tile_map.
static func build(tile_map: TileMap) -> TileSet:
	var tileset = TileSet.new()
	tileset.tile_size = Vector2i(16, 16)

	# Add physics layer
	tileset.add_physics_layer()

	# Load texture
	var texture = load("res://assets/tileset.png")
	if not texture:
		push_error("[TilesetBuilder] Failed to load res://assets/tileset.png")
		return tileset

	# Create atlas source
	var source = TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(16, 16)

	# Add source FIRST so tile_data is aware of physics layers
	tileset.add_source(source, SOURCE_ID)

	# Full solid collision polygon
	var solid_poly = PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8),
		Vector2(8, 8),   Vector2(-8, 8)
	])

	# Thin one-way collision polygon (top 4px of tile)
	var thin_poly = PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8),
		Vector2(8, -4),  Vector2(-8, -4)
	])

	var all_tiles = [
		TILE_GRASS, TILE_DIRT, TILE_STONE, TILE_COBBLESTONE,
		TILE_OAK_WOOD, TILE_BRICK, TILE_COAL_ORE, TILE_GLASS,
		TILE_OAK_PLATFORM
	]

	for coords in all_tiles:
		source.create_tile(coords)
		var tile_data = source.get_tile_data(coords, 0)

		# Glass has no collision
		if coords == TILE_GLASS:
			continue

		tile_data.add_collision_polygon(0)

		if coords == TILE_OAK_PLATFORM:
			# Thin one-way platform
			tile_data.set_collision_polygon_points(0, 0, thin_poly)
			tile_data.set_collision_polygon_one_way(0, 0, true)
			tile_data.set_collision_polygon_one_way_margin(0, 0, 1.0)
		else:
			tile_data.set_collision_polygon_points(0, 0, solid_poly)

	tile_map.tile_set = tileset
	return tileset
