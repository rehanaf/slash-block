extends Node

var selected_skin: String = "captenpanez"
var skins = ["captenpanez", "steve", "dream", "fiz"]

var selected_weapon: String = "Diamond Sword"

var weapons = [
	{
		"name": "Diamond Sword",
		"texture": "res://assets/items/diamond_sword.png",
		"inner": Color(0.45, 0.85, 1.0),   # Light Cyan
		"outline": Color(0.1, 0.45, 0.95)   # Rich Blue
	},
	{
		"name": "Gold Sword",
		"texture": "res://assets/items/gold_sword.png",
		"inner": Color(1.0, 0.85, 0.2),    # Yellow
		"outline": Color(0.85, 0.4, 0.0)   # Orange/Gold
	},
	{
		"name": "Iron Sword",
		"texture": "res://assets/items/iron_sword.png",
		"inner": Color(0.85, 0.85, 0.85),  # Silver/Light Gray
		"outline": Color(0.45, 0.48, 0.52)  # Steel/Darker Gray
	},
	{
		"name": "Copper Sword",
		"texture": "res://assets/items/copper_sword.png",
		"inner": Color(0.95, 0.55, 0.25),  # Light Copper/Orange
		"outline": Color(0.7, 0.3, 0.1)     # Brown/Rust
	},
	{
		"name": "Netherite Sword",
		"texture": "res://assets/items/netherite_sword.png",
		"inner": Color(0.65, 0.55, 0.65),  # Purpleish/Dark Gray
		"outline": Color(0.2, 0.15, 0.25)   # Obsidian/Deep Purple-Black
	},
	{
		"name": "Stone Sword",
		"texture": "res://assets/items/stone_sword.png",
		"inner": Color(0.65, 0.65, 0.65),  # Gray
		"outline": Color(0.35, 0.35, 0.35)  # Dark Stone Gray
	},
	{
		"name": "Wood Sword",
		"texture": "res://assets/items/wood_sword.png",
		"inner": Color(0.85, 0.65, 0.45),  # Light Wood Brown
		"outline": Color(0.5, 0.3, 0.15)    # Dark Wood Brown
	}
]

