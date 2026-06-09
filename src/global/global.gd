extends Node

var selected_skin: String = "captenpanez"
var skins = ["captenpanez", "steve", "dream", "fiz"]

# Inventory State
var inventory = {
	"weapon": [],
	"material": [],
	"food": []
}

# Quick slots (size 4). Stores item IDs, or empty string if empty.
var quick_slots = ["iron_sword", "iron_axe", "iron_spear", ""]
var active_quick_slot = 0 # 0 to 3

# Helper to get the currently selected weapon ID
var selected_weapon: String = "iron_sword"

# Database of all items in the game
var item_database = {
	# Weapons
	"iron_sword": {
		"id": "iron_sword",
		"name": "Iron Sword",
		"type": "weapon",
		"texture": "res://assets/items/iron_sword.png",
		"inner": Color(0.85, 0.85, 0.85),
		"outline": Color(0.45, 0.48, 0.52),
		"attack_duration": 0.3,
		"attack_cooldown": 0.3
	},
	"iron_axe": {
		"id": "iron_axe",
		"name": "Iron Axe",
		"type": "weapon",
		"texture": "res://assets/items/iron_axe.png",
		"inner": Color(0.8, 0.4, 0.2),
		"outline": Color(0.3, 0.15, 0.05),
		"attack_duration": 0.5,
		"attack_cooldown": 0.6
	},
	"iron_spear": {
		"id": "iron_spear",
		"name": "Iron Spear",
		"type": "weapon",
		"texture": "res://assets/items/spear/iron_spear.png",
		"inner": Color(0.9, 0.9, 0.4),
		"outline": Color(0.6, 0.6, 0.2),
		"attack_duration": 0.7,
		"attack_cooldown": 0.8
	},
	# Materials (Examples)
	"wood": {
		"id": "wood",
		"name": "Wood",
		"type": "material",
		"texture": "res://assets/items/door_wood.png" # Placeholder
	},
	"stone": {
		"id": "stone",
		"name": "Stone",
		"type": "material",
		"texture": "res://assets/items/flint.png" # Placeholder
	},
	# Food (Examples)
	"apple": {
		"id": "apple",
		"name": "Apple",
		"type": "food",
		"texture": "res://assets/items/apple.png",
		"heal_amount": 10
	},
	"bread": {
		"id": "bread",
		"name": "Bread",
		"type": "food",
		"texture": "res://assets/items/bread.png",
		"heal_amount": 25
	}
}

# Legacy support for player.gd and menu.gd temporarily (if needed)
var weapons = [
	item_database["iron_sword"],
	item_database["iron_axe"],
	item_database["iron_spear"]
]

func _ready():
	# Initialize inventory with starting items
	add_item("iron_sword", 1)
	add_item("iron_axe", 1)
	add_item("iron_spear", 1)
	
	# Give some dummy materials and food for testing
	add_item("wood", 5)
	add_item("apple", 3)
	add_item("bread", 2)

# Function to add items to inventory
func add_item(item_id: String, amount: int = 1):
	if not item_database.has(item_id):
		return
		
	var item_type = item_database[item_id].type
	if inventory.has(item_type):
		# Check if already exists (for stackable items like food/materials)
		var found = false
		for item in inventory[item_type]:
			if item.id == item_id:
				if item.has("amount"):
					item.amount += amount
				else:
					item["amount"] = amount + 1
				found = true
				break
				
		if not found:
			var new_item = item_database[item_id].duplicate()
			new_item["amount"] = amount
			inventory[item_type].append(new_item)

func get_item_data(item_id: String):
	if item_database.has(item_id):
		return item_database[item_id]
	return null

func get_active_quick_item():
	var id = quick_slots[active_quick_slot]
	if id != "":
		return get_item_data(id)
	return null
