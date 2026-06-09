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
var item_database = {}

# Time System
var tick_speed: float = 10.0 # 1.0 is normal speed
var time_elapsed: float = 0.0 # In game seconds

func _process(delta):
	time_elapsed += delta * tick_speed

# Returns a value between 0.0 and 1.0 representing the progress of a day
# 1 Day = 24 in-game minutes = 1440 in-game seconds
func get_time_of_day() -> float:
	return fmod(time_elapsed / 1440.0, 1.0)


func _ready():
	_load_all_item_resources()
	
	# Initialize inventory with starting items
	add_item("iron_sword", 1)
	add_item("iron_axe", 1)
	add_item("iron_spear", 1)
	
	# Give some dummy materials and food for testing
	add_item("wood", 5)
	add_item("apple", 3)
	add_item("bread", 2)

func _load_all_item_resources():
	var paths = [
		"res://src/data/items/weapons/",
		"res://src/data/items/materials/",
		"res://src/data/items/foods/"
	]
	
	for path in paths:
		if DirAccess.dir_exists_absolute(path):
			var dir = DirAccess.open(path)
			if dir:
				dir.list_dir_begin()
				var file_name = dir.get_next()
				while file_name != "":
					if not dir.current_is_dir() and file_name.ends_with(".tres"):
						var res_path = path + file_name
						var resource = load(res_path)
						if resource and resource.get("id") != null and resource.get("type") != null:
							item_database[resource.id] = resource
					file_name = dir.get_next()
				dir.list_dir_end()

# Function to add items to inventory
func add_item(item_id: String, amount: int = 1):
	if not item_database.has(item_id):
		return
		
	var item_data = item_database[item_id]
	var item_type = item_data.type
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
			# Dictionaries are duplicated via duplicate(), but for Objects (Resources),
			# we typically wrap them in a Dictionary to track amount separately from the shared Resource.
			var item_entry = {
				"id": item_data.id,
				"name": item_data.name,
				"type": item_data.type,
				"texture": item_data.texture,
				"resource": item_data, # Store reference to the Resource
				"amount": amount
			}
			inventory[item_type].append(item_entry)

func get_item_data(item_id: String):
	if item_database.has(item_id):
		return item_database[item_id]
	return null

func get_active_quick_item():
	var id = quick_slots[active_quick_slot]
	if id != "":
		return get_item_data(id)
	return null

func has_item(item_id: String, amount: int = 1) -> bool:
	if not item_database.has(item_id): return false
	var item_type = item_database[item_id].type
	for item in inventory[item_type]:
		if item.id == item_id and item.amount >= amount:
			return true
	return false

func remove_item(item_id: String, amount: int = 1) -> bool:
	if not has_item(item_id, amount): return false
	var item_type = item_database[item_id].type
	
	for i in range(inventory[item_type].size()):
		var item = inventory[item_type][i]
		if item.id == item_id:
			item.amount -= amount
			if item.amount <= 0:
				inventory[item_type].remove_at(i)
			return true
	return false
