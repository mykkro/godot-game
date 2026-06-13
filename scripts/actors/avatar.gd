class_name Avatar
extends Actor

const MOVE_SPEED     := 200.0  # pixels / second
const PICKUP_RADIUS  := 52.0   # pixels; pickup detection zone radius
const WAYPOINT_REACH := 24.0   # pixels; distance to consider a path waypoint reached
## Max centre-to-centre distance at which the avatar can interact with an NPC.
const INTERACT_DIST  := 46.0   # COLL_RADIUS*2 + small buffer
## Collision layer mask for PickableNode (must match PickableNode.LAYER_PICKABLE).
const PICKUP_MASK    := 2

## Collision circle constants (world pixels at scale 0.56 / 256-px frame).
const COLL_RADIUS         := 18.75
const COLL_OFFSET_Y       := -29.4
const PICKUP_SOUND_VOLUME := 1.0
const SHOOT_SOUND_VOLUME  := 0.8
const DROP_SOUND_VOLUME   := 0.9
const SHOOT_COOLDOWN      := 0.5

signal npc_interact_requested(npc: Node2D)

var _world:        World        = null
var _fog_manager:  FogManager   = null
var _inventory_ui: InventoryUI  = null

var inventory: Inventory = Inventory.new()

## Nearby pickable items tracked via Area2D overlap signals.
var _path:             Array[Vector2]    = []   # queued waypoints from click-to-move
var _nearby_pickables: Dictionary        = {}   # PickableNode → true
var _pickup_area:  Area2D            = null
var _sprite:       KnightSprite      = null
var _pickup_sound: AudioStreamPlayer = null
var _shoot_sound:  AudioStreamPlayer = null
var _drop_sound:   AudioStreamPlayer = null
var _shoot_cooldown: float           = 0.0


## Must be called after the node is in the scene tree (from Main._ready).
func setup(world: World, fog_manager: FogManager,
		   inventory_ui: InventoryUI) -> void:
	_world        = world
	_fog_manager  = fog_manager
	_inventory_ui = inventory_ui


func _ready() -> void:
	# All actors share ACTOR_LAYER so player and NPCs block each other.
	collision_layer = ACTOR_LAYER
	collision_mask  = ACTOR_LAYER
	super._ready()   # calls _setup_collision() → overridden below
	_setup_pickup_area()

	_sprite = KnightSprite.new()
	_sprite.scale  = Vector2(0.56, 0.56)
	_sprite.offset = Vector2(0.0, -3.1)
	add_child(_sprite)

	_pickup_sound = AudioStreamPlayer.new()
	_pickup_sound.stream    = load("res://sounds/RPG Sound Pack/inventory/beads.wav")
	_pickup_sound.volume_db = linear_to_db(PICKUP_SOUND_VOLUME)
	_pickup_sound.bus       = AudioManager.SFX_BUS
	add_child(_pickup_sound)

	_shoot_sound = AudioStreamPlayer.new()
	_shoot_sound.stream    = load("res://sounds/RPG Sound Pack/battle/swing.wav")
	_shoot_sound.volume_db = linear_to_db(SHOOT_SOUND_VOLUME)
	_shoot_sound.bus       = AudioManager.SFX_BUS
	add_child(_shoot_sound)

	_drop_sound = AudioStreamPlayer.new()
	_drop_sound.stream    = load("res://sounds/RPG Sound Pack/inventory/coin.wav")
	_drop_sound.volume_db = linear_to_db(DROP_SOUND_VOLUME)
	_drop_sound.bus       = AudioManager.SFX_BUS
	add_child(_drop_sound)


func _physics_process(delta: float) -> void:
	var dir := _read_input()

	if dir != Vector2.ZERO:
		_path.clear()           # keyboard cancels click-to-move
		dir      = dir.normalized()
		heading  = dir.angle()
		velocity = dir * MOVE_SPEED
	elif not _path.is_empty():
		if position.distance_to(_path[0]) < WAYPOINT_REACH:
			_path.pop_front()
		if not _path.is_empty():
			dir      = (_path[0] - position).normalized()
			heading  = dir.angle()
			velocity = dir * MOVE_SPEED
		else:
			velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	if _world != null:
		_world.update_avatar_position(position)
	if _fog_manager != null:
		_fog_manager.update_avatar_position(position)

	if _shoot_cooldown > 0.0:
		_shoot_cooldown -= delta

	if _sprite != null:
		_sprite.update_anim(velocity != Vector2.ZERO, heading)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var world_pos := get_viewport().get_canvas_transform().affine_inverse() * mb.position
			_on_click(world_pos)
			get_viewport().set_input_as_handled()
		return

	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if ke.keycode == KEY_E and ke.pressed and not ke.echo:
		var npc := get_interactable_npc()
		if npc != null:
			npc_interact_requested.emit(npc)
		elif get_interactable_chest() != null:
			pass   # chest opening — to be implemented
		else:
			_try_pickup()
		get_viewport().set_input_as_handled()
	elif ke.keycode == KEY_CTRL and ke.pressed and not ke.echo:
		_try_shoot()
		get_viewport().set_input_as_handled()


## Returns the hint label for the nearest pickable ("12 × Coin"), or "".
func get_nearest_pickable_name() -> String:
	var nearest := _get_nearest_pickable()
	if nearest == null:
		return ""
	var name := PickableItemDef.get_display_name(nearest.item_type)
	if nearest.count > 1:
		return "%d × %s" % [nearest.count, name]
	return name


## Returns the item type of the nearest pickable, or -1 if none.
func get_nearest_pickable_type() -> int:
	var nearest := _get_nearest_pickable()
	return nearest.item_type if nearest != null else -1


# ── Private ──────────────────────────────────────────────────────────────────

func _setup_collision() -> void:
	var col    := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = COLL_RADIUS
	col.shape     = circle
	add_child(col)


func _setup_pickup_area() -> void:
	_pickup_area = Area2D.new()
	_pickup_area.collision_layer = 0
	_pickup_area.collision_mask  = PICKUP_MASK

	var col    := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = COLL_RADIUS
	col.shape     = circle
	_pickup_area.add_child(col)
	add_child(_pickup_area)

	_pickup_area.area_entered.connect(_on_pickup_area_entered)
	_pickup_area.area_exited.connect(_on_pickup_area_exited)


func _on_pickup_area_entered(area: Area2D) -> void:
	if area is PickableNode:
		_nearby_pickables[area] = true


func _on_pickup_area_exited(area: Area2D) -> void:
	if area is PickableNode:
		_nearby_pickables.erase(area)


func _get_nearest_pickable() -> PickableNode:
	var best:      PickableNode = null
	var best_dist: float        = INF
	for node in _nearby_pickables.keys():
		if not is_instance_valid(node):
			continue
		var d := position.distance_to((node as PickableNode).global_position)
		if d < best_dist:
			best_dist = d
			best      = node as PickableNode
	return best


func _try_pickup() -> void:
	var target := _get_nearest_pickable()
	if target == null:
		return
	var can_take := _space_for_item(target.item_type)
	if can_take == 0:
		return
	var take := mini(target.count, can_take)
	for _i in range(take):
		inventory.add(target.item_type)
	if take >= target.count:
		_nearby_pickables.erase(target)
		target.remove_from_world()
	else:
		target.update_count(target.count - take)
	if _pickup_sound != null:
		_pickup_sound.play()
	if _inventory_ui != null:
		_inventory_ui.notify_changed()


## How many of item_type can be absorbed into the current inventory
## (filling existing partial stacks first, then empty slots).
func _space_for_item(item_type: int) -> int:
	var max_stack := PickableItemDef.max_stack_size(item_type)
	var space     := 0
	for i in range(inventory.count()):
		if inventory.get_type(i) == item_type:
			space += max_stack - inventory.get_count(i)
	space += (Inventory.MAX_ITEMS - inventory.count()) * max_stack
	return space


func _try_shoot() -> void:
	if _shoot_cooldown > 0.0 or _world == null:
		return
	_shoot_cooldown = SHOOT_COOLDOWN
	var dir    := Vector2(cos(heading), sin(heading))
	var origin := position + dir * (COLL_RADIUS + ProjectileNode.RADIUS + 2.0)
	var proj   := ProjectileNode.new()
	proj.initialize(origin, dir, _world)
	_world.add_child(proj)
	if _shoot_sound != null:
		_shoot_sound.play()


## Called by InventoryUI via drop_requested(slot_index, count).
## Merges into nearby same-type piles first, then drops any remainder as a new pile.
func drop_item(slot_index: int, count: int) -> void:
	if slot_index < 0 or slot_index >= inventory.count():
		return
	var item_type  := inventory.get_type(slot_index)
	var remaining  := count
	var max_stack  := PickableItemDef.max_stack_size(item_type)

	# Merge into nearby stackable piles before creating a new one.
	if max_stack > 1:
		for node in _nearby_pickables.keys():
			if remaining <= 0:
				break
			if not is_instance_valid(node):
				continue
			var p := node as PickableNode
			if p.item_type != item_type:
				continue
			var space := max_stack - p.count
			if space <= 0:
				continue
			var merge := mini(remaining, space)
			p.update_count(p.count + merge)
			remaining -= merge

	# Drop any remainder onto an adjacent free cell.
	var drop_origin := position + Vector2(0.0, COLL_OFFSET_Y)
	if remaining > 0:
		if _world.drop_item_near(drop_origin, item_type, remaining):
			remaining = 0

	var dropped := count - remaining
	if dropped == 0:
		return
	inventory.remove_from_slot(slot_index, dropped)
	if _drop_sound != null:
		_drop_sound.play()
	if _inventory_ui != null:
		_inventory_ui.notify_changed()


func _on_click(world_pos: Vector2) -> void:
	if _world == null:
		return
	var gc := _world.world_to_cell_coords(world_pos)
	if not _is_cell_visible(gc):
		return
	var path := Pathfinder.find_path(_world, position, world_pos)
	if not path.is_empty():
		path[path.size() - 1] = world_pos
		_path = path


func _is_cell_visible(gc: Vector2i) -> bool:
	if _fog_manager == null:
		return true
	var cc := Vector2i(
		int(floor(float(gc.x) / ChunkData.CHUNK_SIZE)),
		int(floor(float(gc.y) / ChunkData.CHUNK_SIZE))
	)
	var lx  := gc.x - cc.x * ChunkData.CHUNK_SIZE
	var ly  := gc.y - cc.y * ChunkData.CHUNK_SIZE
	var fog := _fog_manager.get_fog_data(cc)
	if fog == null:
		return false
	return fog.get_level(lx, ly) >= FogData.PARTIAL


## Returns the nearest chest within INTERACT_DIST and roughly in front.
func get_interactable_chest() -> ChestNode:
	var best:      ChestNode = null
	var best_dist: float     = INF
	for node in get_tree().get_nodes_in_group("chests"):
		var chest := node as ChestNode
		if chest == null:
			continue
		var d := global_position.distance_to(chest.global_position)
		if d > INTERACT_DIST:
			continue
		var to_chest := (chest.global_position - global_position).angle()
		var diff     := absf(wrapf(to_chest - heading, -PI, PI))
		if diff > PI * 0.75:
			continue
		if d < best_dist:
			best_dist = d
			best      = chest
	return best


## Returns the nearest NPC that is within INTERACT_DIST and roughly in front.
func get_interactable_npc() -> Node2D:
	if _world == null:
		return null
	var best:      Node2D = null
	var best_dist: float  = INF
	for child in _world.get_children():
		if not (child is NpcKnight or child is NpcMelee):
			continue
		var npc := child as Node2D
		var d   := position.distance_to(npc.position)
		if d > INTERACT_DIST:
			continue
		var to_npc := (npc.position - position).angle()
		var diff   := absf(wrapf(to_npc - heading, -PI, PI))
		if diff > PI * 0.75:   # within 135° forward arc
			continue
		if d < best_dist:
			best_dist = d
			best      = npc
	return best


static func _read_input() -> Vector2:
	return Vector2(
		float(Input.is_action_pressed("ui_right")) - float(Input.is_action_pressed("ui_left")),
		float(Input.is_action_pressed("ui_down"))  - float(Input.is_action_pressed("ui_up"))
	)
