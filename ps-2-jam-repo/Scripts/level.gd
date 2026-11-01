extends Node3D

@export_group("Dungeon")
@export var size: Vector2i = Vector2i(10, 10)
@export_range(1, 1000) var target_tiles: int = 35
@export var generate_on_ready: bool = true

@export_group("Progression")
@export var current_level: int = 1
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var level_indicator: Label = $"MUI/Level indicator/Label"

@export_group("Enemies")
@export var turret_scene: PackedScene
@export var enemy_count: int = 3

@export_group("Scenes")
@export var tile_scene: PackedScene
@export var wall_scene: PackedScene
@export var pillar_scene: PackedScene

@export_group("Player")
@export var player_scene: PackedScene
@export var player_spawn_height: float = 0.5

var player_instance: CharacterBody3D
var player_spawn_position: Vector3
var start_cell: Vector2i
var enemies_remaining: int = 0

const TILE_SIZE := 2.0

const DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT
]

var dungeon: Dictionary = {}
var generated_root: Node3D


func _ready() -> void:
	add_to_group("DungeonManager")

	if not GameManager.player_died.is_connected(_on_player_died):
		GameManager.player_died.connect(_on_player_died)

	if generate_on_ready:
		generate_dungeon()


func generate_dungeon() -> void:
	if size.x <= 0 or size.y <= 0:
		return

	if tile_scene == null or wall_scene == null or pillar_scene == null:
		push_error("Assign all three dungeon scenes!")
		return

	if is_instance_valid(generated_root):
		generated_root.queue_free()

	generated_root = Node3D.new()
	generated_root.name = "GeneratedDungeon"
	add_child(generated_root)

	dungeon.clear()

	generate_layout()
	build_dungeon()
	corrupt_materials()
	spawn_player()
	spawn_enemies()
	update_deterioration_environment()
	level_indicator.text = "Level : " + str(current_level)


# random walk stuff
func generate_layout() -> void:
	start_cell = Vector2i(size.x / 2, size.y / 2)
	var current := start_cell

	dungeon[start_cell] = true

	var max_tiles := mini(target_tiles, size.x * size.y)

	while dungeon.size() < max_tiles:
		var direction: Vector2i = DIRECTIONS.pick_random()
		var next: Vector2i = current + direction

		if next.x < 0 or next.x >= size.x:
			continue

		if next.y < 0 or next.y >= size.y:
			continue

		current = next
		dungeon[current] = true


# build actual layout
func build_dungeon() -> void:
	var placed_pillars: Dictionary = {}

	for cell: Vector2i in dungeon:

		var world_pos := Vector3(
			cell.x * TILE_SIZE,
			0.0,
			cell.y * TILE_SIZE
		)

		# floor tile
		var tile := tile_scene.instantiate() as Node3D
		generated_root.add_child(tile)
		tile.position = world_pos

		var north := cell + Vector2i.UP
		var south := cell + Vector2i.DOWN
		var west := cell + Vector2i.LEFT
		var east := cell + Vector2i.RIGHT

		# place walls where no neighbor exists
		if not dungeon.has(north):
			place_wall(world_pos + Vector3(0, 0, -1), 0.0)

		if not dungeon.has(south):
			place_wall(world_pos + Vector3(0, 0, 1), 0.0)

		if not dungeon.has(west):
			place_wall(world_pos + Vector3(-1, 0, 0), PI / 2.0)

		if not dungeon.has(east):
			place_wall(world_pos + Vector3(1, 0, 0), PI / 2.0)

		var corners: Array[Vector2i] = [
			Vector2i(cell.x * 2 - 1, cell.y * 2 - 1),
			Vector2i(cell.x * 2 + 1, cell.y * 2 - 1),
			Vector2i(cell.x * 2 - 1, cell.y * 2 + 1),
			Vector2i(cell.x * 2 + 1, cell.y * 2 + 1)
		]

		for corner: Vector2i in corners:
			if placed_pillars.has(corner):
				continue

			placed_pillars[corner] = true

			var pillar := pillar_scene.instantiate() as Node3D
			generated_root.add_child(pillar)

			pillar.position = Vector3(corner.x, 1.25, corner.y)


func place_wall(pos: Vector3, rotation_y: float) -> void:
	var wall := wall_scene.instantiate() as Node3D
	generated_root.add_child(wall)

	wall.position = pos + Vector3(0, 1.25, 0)
	wall.rotation.y = rotation_y + PI / 2.0


func spawn_player() -> void:
	player_spawn_position = to_global(Vector3(
		start_cell.x * TILE_SIZE,
		player_spawn_height,
		start_cell.y * TILE_SIZE
	))

	if is_instance_valid(player_instance):
		player_instance.global_position = player_spawn_position
		player_instance.velocity = Vector3.ZERO
		return

	if player_scene == null:
		push_error("Assign a player scene!")
		return

	player_instance = player_scene.instantiate() as CharacterBody3D
	player_instance.global_position = player_spawn_position
	player_instance.scale = Vector3(0.5, 0.5, 0.5)
	add_child(player_instance)


func spawn_enemies() -> void:
	if turret_scene == null:
		return

	var available_cells: Array = dungeon.keys()
	available_cells.erase(start_cell)
	available_cells.shuffle()

	var spawn_target = mini(enemy_count + current_level - 1, available_cells.size() - 50)
	enemies_remaining = spawn_target

	for i in range(spawn_target):
		var turret_cell: Vector2i = available_cells.pop_front()

		var turret := turret_scene.instantiate() as Node3D
		generated_root.add_child(turret)

		turret.position = Vector3(
			turret_cell.x * TILE_SIZE,
			0.0,
			turret_cell.y * TILE_SIZE
		)

		turret.tree_exited.connect(_on_enemy_defeated)

	print("Level ", current_level, " started with ", enemies_remaining, " enemies.")


func _on_enemy_defeated() -> void:
	if not is_instance_valid(generated_root):
		return

	enemies_remaining -= 1
	print("Enemy eliminated! Remaining: ", enemies_remaining)

	if enemies_remaining <= 0:
		advance_level()


func advance_level() -> void:
	current_level += 1
	print("ALL ENEMIES DEFEATED! Advancing to Level ", current_level)
	
	target_tiles += 5
	generate_dungeon()


# handle environment color drain early on
func update_deterioration_environment() -> void:
	if not world_environment or not world_environment.environment:
		return

	var env = world_environment.environment
	env.adjustment_enabled = true

	var corruption := 0.0
	
	if current_level <= 4:
		corruption = clampf(float(current_level - 1) / 3.0, 0.0, 1.0)
		env.adjustment_saturation = lerp(1.0, 0.2, corruption)
		env.adjustment_contrast = lerp(1.0, 1.4, corruption)
		print("Environment rotting... Corruption factor: ", corruption)
	else:
		env.adjustment_saturation = 1.0
		env.adjustment_contrast = 1.0
		print("Environment reset for texture corruption phase.")


# texture corruption logic for later levels
func corrupt_materials() -> void:
	var wall_mat_path = "res://Materials/walls.tres"
	var corrupted_tex_path = "res://Assets/textures/CorruptedTexture.jpg"
	
	if not ResourceLoader.exists(wall_mat_path):
		push_error("Wall material not found at: " + wall_mat_path)
		return

	var wall_mat = load(wall_mat_path) as StandardMaterial3D
	if not wall_mat:
		return

	print("Current Level for Corruption Check: ", current_level)

	if current_level == 5:
		# level 5: normal pink checkers
		wall_mat.albedo_color = Color(1.0, 1.0, 1.0)
		
		if ResourceLoader.exists(corrupted_tex_path):
			wall_mat.albedo_texture = load(corrupted_tex_path)
			print("Level 5: Corrupted texture active with normal colors.")
		else:
			push_error("FAILED TO FIND TEXTURE AT: " + corrupted_tex_path)
			
	elif current_level == 6:
		# level 6: white checkers
		if ResourceLoader.exists(corrupted_tex_path):
			wall_mat.albedo_texture = load(corrupted_tex_path)
		
		wall_mat.albedo_color = Color(2.5, 1.978, 0.0, 1.0) # color goes here
		print("Level 6: Texture shifted to white checkers.")
		
	elif current_level >= 7:
		# level 7+: fully bleached white error state
		wall_mat.albedo_color = Color(5.0, 5.0, 5.0) 
		print("Level 7+: Maximum bleached white error state!")
		
	else:
		# normal clean state
		wall_mat.albedo_color = Color(1.0, 1.0, 1.0)
		print("Level pristine, normal textures active.")


func _on_player_died() -> void:
	print("PLAYER DIED! RESPAWNING...")

	await get_tree().create_timer(0.5).timeout

	if not is_instance_valid(player_instance):
		return

	player_instance.global_position = player_spawn_position
	player_instance.velocity = Vector3.ZERO

	GameManager.respawn()
	print("PLAYER RESPAWNED!")
