import os
from PIL import Image

def generate_tileset():
    # We will generate a 64x48 tileset image containing 16x16 tiles:
    # Row 0: Grass (0,0), Dirt (1,0), Stone (2,0), Cobblestone (3,0)
    # Row 1: Oak Planks (0,1), Brick (1,1), Coal Ore (2,1), Glass (3,1)
    # Row 2: Thin Oak Platform (0,2)
    
    tile_size = 16
    cols = 4
    rows = 3
    
    # Create target image (fully transparent canvas)
    img = Image.new("RGBA", (tile_size * cols, tile_size * rows), (0, 0, 0, 0))
    
    blocks_dir = os.path.join("assets", "blocks")
    
    # Mapping of tile coordinates (x, y) to block asset filenames
    mapping = {
        (0, 0): "grass_side_carried.png",
        (1, 0): "dirt.png",
        (2, 0): "stone.png",
        (3, 0): "cobblestone.png",
        (0, 1): "planks_oak.png",
        (1, 1): "brick.png",
        (2, 1): "coal_ore.png",
        (3, 1): "glass.png"
    }
    
    for (col, row), filename in mapping.items():
        src_path = os.path.join(blocks_dir, filename)
        if not os.path.exists(src_path):
            raise FileNotFoundError(f"Required block texture not found: {src_path}")
            
        with Image.open(src_path) as src_img:
            src_img = src_img.convert("RGBA")
            # Crop to tile_size x tile_size just in case size differs
            src_tile = src_img.crop((0, 0, tile_size, tile_size))
            img.paste(src_tile, (col * tile_size, row * tile_size))
            
    # Thin Oak Platform (0, 2):
    # Take top 4 rows of planks_oak.png, transparent underneath
    planks_path = os.path.join(blocks_dir, "planks_oak.png")
    if not os.path.exists(planks_path):
        raise FileNotFoundError(f"Required block texture not found: {planks_path}")
        
    with Image.open(planks_path) as planks_img:
        planks_img = planks_img.convert("RGBA")
        # Crop the top 4 rows
        platform_part = planks_img.crop((0, 0, tile_size, 4))
        # Create a new transparent 16x16 tile
        platform_tile = Image.new("RGBA", (tile_size, tile_size), (0, 0, 0, 0))
        # Paste the top part at (0,0) in the 16x16 tile
        platform_tile.paste(platform_part, (0, 0))
        # Paste into the atlas at col=0, row=2
        img.paste(platform_tile, (0, 2 * tile_size))
        
    # Ensure output directory exists
    os.makedirs("assets", exist_ok=True)
    img.save("assets/tileset.png")
    print("Tileset compiled successfully at assets/tileset.png")

if __name__ == "__main__":
    generate_tileset()
