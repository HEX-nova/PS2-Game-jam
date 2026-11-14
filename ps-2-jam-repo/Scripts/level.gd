extends Node3D

enum LevelMode { STANDARD, TIME_ATTACK, SHORT_GAUNTLET }

@export_group("Level Configuration")
@export var level_mode: LevelMode = LevelMode.STANDARD
@export var max_gauntlet_levels: int = 5
@export var spawn_hub_scene_path: String = "res://Scenes/MainMenu.tscn" # Point to your main hub/menu

@export_group("Time Attack Settings")
@export var time_remaining: float = 30.0 # Starting seconds
@export var time_gained_per_kill: float = 3.0

@export_group("Dungeon")
@export var size: Vector2i = Vector2i(10, 10)
@export_range(1, 1000) var target_tiles: int = 35
@export var generate_on_ready: bool = true

@export_group("Progression")
@export var current_level: int = GameManager.current_level
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var level_indicator: Label = $"MUI/Level indicator/Label"

@export_group("Enemies")
@export var turret_scene: PackedScene
@export var spider_scene: PackedScene
@export var enemy_count: int = 3

@export_group("Scenes")
@export var tile_scene: PackedScene
@export var wall_scene: PackedScene
@export var pillar_scene: PackedScene

@export_group("Visual Themes / Materials")
@export var possible_wall_materials: Array[Material] = []
@export var possible_tile_materials: Array[Material] = []

@export_group("Player")
@export var player_scene: PackedScene
@export var player_spawn_height: float = 0.5

var player_instance: CharacterBody3D
var player_spawn_position: Vector3
var start_cell: Vector2i
var enemies_remaining: int = 0
var turrets_remaining: int = 0
var spiders_remaining: int = 0

const TILE_SIZE := 2.0
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var dungeon: Dictionary = {}
var generated_root: Node3D


func _ready() -> void:
	GameManager.current_level = current_level
	add_to_group("DungeonManager")

	if not GameManager.player_died.is_connected(_on_player_died):
		GameManager.player_died.connect(_on_player_died)

	if generate_on_ready:
		generate_dungeon()


func _process(delta: float) -> void:
	# Handle Time Attack countdown logic
	if level_mode == LevelMode.TIME_ATTACK and enemies_remaining > 0:
		time_remaining -= delta
		
		# Update UI text to show timer & rot intensity
		if level_indicator:
			level_indicator.text = "TIME: %.1fs | Lvl: %d" % [max(0.0, time_remaining), current_level]
			
		# Trigger deterioration climax in the final 10 seconds!
		if time_remaining <= 10.0:
			apply_time_attack_climax_rot(time_remaining)
			
		if time_remaining <= 0.0:
			game_over_time_out()


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
	
	if level_mode != LevelMode.TIME_ATTACK:
		corrupt_materials()
		update_deterioration_environment()
		if level_indicator:
			level_indicator.text = "Level : " + str(current_level)

	spawn_player()
	spawn_enemies()


func generate_layout() -> void:
	dungeon.clear()
	
	if level_mode == LevelMode.TIME_ATTACK:
		# TIME ATTACK: Solid open arena box (No maze, completely clear and fair!)
		for x in range(size.x):
			for y in range(size.y):
				dungeon[Vector2i(x, y)] = true
		start_cell = Vector2i(size.x / 2, size.y / 2)
	else:
		# STANDARD / GAUNTLET: Random walk layout
		start_cell = Vector2i(size.x / 2, size.y / 2)
		var current := start_cell
		dungeon[start_cell] = true
		var max_tiles := mini(target_tiles, size.x * size.y)

		while dungeon.size() < max_tiles:
			var direction: Vector2i = DIRECTIONS.pick_random()
			var next: Vector2i = current + direction
			if next.x < 0 or next.x >= size.x or next.y < 0 or next.y >= size.y:
				continue
			current = next
			dungeon[current] = true


func build_dungeon() -> void:
	# Randomly pick a wall and tile material theme for this level generation
	var active_wall_mat: Material = possible_wall_materials.pick_random() if possible_wall_materials.size() > 0 else null
	var active_tile_mat: Material = possible_tile_materials.pick_random() if possible_tile_materials.size() > 0 else null

	var placed_pillars: Dictionary = {}
	for cell: Vector2i in dungeon:
		var world_pos := Vector3(cell.x * TILE_SIZE, 0.0, cell.y * TILE_SIZE)
		var tile := tile_scene.instantiate() as Node3D
		generated_root.add_child(tile)
		tile.position = world_pos
		
		# Apply random tile material if available
		if active_tile_mat and tile is MeshInstance3D:
			tile.material_override = active_tile_mat
		elif active_tile_mat:
			apply_material_recursive(tile, active_tile_mat)

		if not dungeon.has(cell + Vector2i.UP): place_wall(world_pos + Vector3(0, 0, -1), 0.0, active_wall_mat)
		if not dungeon.has(cell + Vector2i.DOWN): place_wall(world_pos + Vector3(0, 0, 1), 0.0, active_wall_mat)
		if not dungeon.has(cell + Vector2i.LEFT): place_wall(world_pos + Vector3(-1, 0, 0), PI / 2.0, active_wall_mat)
		if not dungeon.has(cell + Vector2i.RIGHT): place_wall(world_pos + Vector3(1, 0, 0), PI / 2.0, active_wall_mat)

		var corners: Array[Vector2i] = [
			Vector2i(cell.x * 2 - 1, cell.y * 2 - 1), Vector2i(cell.x * 2 + 1, cell.y * 2 - 1),
			Vector2i(cell.x * 2 - 1, cell.y * 2 + 1), Vector2i(cell.x * 2 + 1, cell.y * 2 + 1)
		]
		for corner in corners:
			if placed_pillars.has(corner): continue
			placed_pillars[corner] = true
			var pillar := pillar_scene.instantiate() as Node3D
			generated_root.add_child(pillar)
			pillar.position = Vector3(corner.x, 1.25, corner.y)


func place_wall(pos: Vector3, rotation_y: float, wall_mat: Material) -> void:
	var wall := wall_scene.instantiate() as Node3D
	generated_root.add_child(wall)
	wall.position = pos + Vector3(0, 1.25, 0)
	wall.rotation.y = rotation_y + PI / 2.0

	# Apply random wall material if available
	if wall_mat:
		if wall is MeshInstance3D:
			wall.material_override = wall_mat
		else:
			apply_material_recursive(wall, wall_mat)


# Helper to apply materials down node hierarchies if scenes contain multiple meshes
func apply_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		apply_material_recursive(child, mat)


func spawn_player() -> void:
	GameManager.max_health = 75 + 25 * GameManager.current_level
	GameManager.max_energy = 75 + 15 * GameManager.current_level
	GameManager.health = GameManager.max_health
	GameManager.energy = GameManager.max_energy
	
	player_spawn_position = to_global(Vector3(start_cell.x * TILE_SIZE, player_spawn_height, start_cell.y * TILE_SIZE))

	if is_instance_valid(player_instance):
		player_instance.global_position = player_spawn_position
		player_instance.velocity = Vector3.ZERO
		return

	if player_scene == null: return

	player_instance = player_scene.instantiate() as CharacterBody3D
	player_instance.global_position = player_spawn_position
	player_instance.scale = Vector3(0.5, 0.5, 0.5)
	add_child(player_instance)


func spawn_enemies() -> void:
	if turret_scene == null and spider_scene == null: return

	var available_cells: Array = dungeon.keys()
	available_cells.erase(start_cell)
	available_cells.shuffle()

	var spawn_target = mini(enemy_count + current_level - 1, available_cells.size())
	enemies_remaining = spawn_target
	turrets_remaining = 0
	spiders_remaining = 0

	var enemy_queue: Array[PackedScene] = []
	if turret_scene != null and spider_scene != null:
		var guaranteed_count = min(2, spawn_target / 2)
		for i in range(guaranteed_count):
			enemy_queue.append(turret_scene)
			enemy_queue.append(spider_scene)
		while enemy_queue.size() < spawn_target:
			enemy_queue.append(turret_scene if randf() < 0.5 else spider_scene)
	else:
		var single_scene = turret_scene if turret_scene != null else spider_scene
		for i in range(spawn_target): enemy_queue.append(single_scene)

	enemy_queue.shuffle()

	for i in range(spawn_target):
		var enemy_cell: Vector2i = available_cells.pop_front()
		var chosen_scene: PackedScene = enemy_queue[i]
		var enemy := chosen_scene.instantiate() as Node3D
		
		if chosen_scene == turret_scene:
			enemy.set_meta("enemy_type", "turret")
			turrets_remaining += 1
		else:
			enemy.set_meta("enemy_type", "spider")
			spiders_remaining += 1

		generated_root.add_child(enemy)
		var y_offset = 0.0 if enemy.get_meta("enemy_type") == "turret" else 2.0
		enemy.position = Vector3(enemy_cell.x * TILE_SIZE, y_offset, enemy_cell.y * TILE_SIZE)
		enemy.tree_exited.connect(func(): _on_enemy_defeated(enemy))

	GameManager.turrets_left = turrets_remaining
	GameManager.spiders_left = spiders_remaining


func _on_enemy_defeated(enemy_node: Node3D) -> void:
	if not is_instance_valid(generated_root): 
		return

	enemies_remaining -= 1

	# Reward time per kill in Time Attack mode!
	if level_mode == LevelMode.TIME_ATTACK:
		time_remaining += time_gained_per_kill 
		
		# SPAWN REPLACEMENT ENEMY INSTANTLY IN TIME ATTACK
		spawn_single_replacement_enemy()

	# Track specific types
	if enemy_node.has_meta("enemy_type"):
		if enemy_node.get_meta("enemy_type") == "turret":
			turrets_remaining -= 1
			GameManager.turrets_left = turrets_remaining
		else:
			spiders_remaining -= 1
			GameManager.spiders_left = spiders_remaining

	# For standard or short gauntlet modes, clear level when all die
	if level_mode != LevelMode.TIME_ATTACK and enemies_remaining <= 0:
		advance_level()


# Helper function to keep the horde infinite during Time Attack
func spawn_single_replacement_enemy() -> void:
	var available_cells: Array = dungeon.keys()
	available_cells.erase(start_cell)
	
	if is_instance_valid(player_instance):
		var player_cell = Vector2i(
			floor(player_instance.global_position.x / TILE_SIZE),
			floor(player_instance.global_position.z / TILE_SIZE)
		)
		available_cells.erase(player_cell)
		
		# Sort available cells by distance to player so they spawn nearby!
		available_cells.sort_custom(func(a, b):
			return a.distance_to(player_cell) < b.distance_to(player_cell)
		)

	if available_cells.is_empty():
		return

	var pool_size = mini(3, available_cells.size())
	var enemy_cell: Vector2i = available_cells[randi() % pool_size]
	
	var chosen_scene: PackedScene = spider_scene if randf() > 0.5 else turret_scene
	if chosen_scene == null:
		chosen_scene = spider_scene if spider_scene != null else turret_scene
	if chosen_scene == null:
		return

	var enemy := chosen_scene.instantiate() as Node3D
	
	if chosen_scene == turret_scene:
		enemy.set_meta("enemy_type", "turret")
		turrets_remaining += 1
	else:
		enemy.set_meta("enemy_type", "spider")
		spiders_remaining += 1

	generated_root.add_child(enemy)
	var y_offset = 0.0 if enemy.get_meta("enemy_type") == "turret" else 2.0
	enemy.position = Vector3(enemy_cell.x * TILE_SIZE, y_offset, enemy_cell.y * TILE_SIZE)
	
	enemy.tree_exited.connect(func(): _on_enemy_defeated(enemy))
	enemies_remaining += 1


func advance_level() -> void:
	if level_mode == LevelMode.SHORT_GAUNTLET and current_level >= max_gauntlet_levels:
		print("Gauntlet complete! Returning to spawn room...")
		GameManager.current_level = 1
		get_tree().change_scene_to_file(spawn_hub_scene_path)
		return

	current_level += 1
	GameManager.current_level = current_level
	target_tiles += 5
	generate_dungeon()


# 5-Level Deterioration Mapping (Max rot at Level 5)
func corrupt_materials() -> void:
	var wall_mat_path = "res://Materials/walls.tres"
	var corrupted_tex_path = "res://Assets/textures/CorruptedTexture.jpg"
	if not ResourceLoader.exists(wall_mat_path): return
	var wall_mat = load(wall_mat_path) as StandardMaterial3D
	if not wall_mat: return

	if current_level == max_gauntlet_levels or current_level >= 5:
		wall_mat.albedo_color = Color(5.0, 5.0, 5.0) 
		if ResourceLoader.exists(corrupted_tex_path):
			wall_mat.albedo_texture = load(corrupted_tex_path)
	else:
		var corruption_factor = float(current_level - 1) / float(max_gauntlet_levels - 1)
		wall_mat.albedo_color = Color(1.0 - (corruption_factor * 0.2), 1.0 - (corruption_factor * 0.5), 1.0 - corruption_factor)


func apply_time_attack_climax_rot(t_left: float) -> void:
	if not world_environment or not world_environment.environment: return
	var env = world_environment.environment
	env.adjustment_enabled = true
	
	var intensity = (10.0 - t_left) / 10.0 
	env.adjustment_saturation = lerp(1.0, 0.0, intensity)
	env.adjustment_contrast = lerp(1.0, 2.5, intensity)


func update_deterioration_environment() -> void:
	if not world_environment or not world_environment.environment: return
	var env = world_environment.environment
	env.adjustment_enabled = true
	var corruption = clampf(float(current_level - 1) / float(max_gauntlet_levels), 0.0, 1.0)
	env.adjustment_saturation = lerp(1.0, 0.1, corruption)
	env.adjustment_contrast = lerp(1.0, 1.8, corruption)


func _on_player_died() -> void:
	await get_tree().create_timer(0.5).timeout
	if not is_instance_valid(player_instance): return
	player_instance.global_position = player_spawn_position
	player_instance.velocity = Vector3.ZERO
	GameManager.respawn()


func game_over_time_out() -> void:
	print("TIME EXPIRED! GAME OVER.")
	get_tree().change_scene_to_file(spawn_hub_scene_path)
