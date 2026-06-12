class_name Avatar
extends Actor

const MOVE_SPEED     := 200.0  # pixels / second
const PICKUP_RADIUS  := 52.0   # pixels; pickup detection zone radius
## Collision layer mask for PickableNode (must match PickableNode.LAYER_PICKABLE).
const PICKUP_MASK    := 2

## Collision circle constants (world pixels at scale 0.56 / 256-px frame).
const COLL_RADIUS         := 18.75
const COLL_OFFSET_Y       := -29.4
const PICKUP_SOUND_VOLUME := 1.0
const SHOOT_COOLDOWN      := 0.5

var _world:        World        = null
var _fog_manager:  FogManager   = null
var _inventory_ui: InventoryUI  = null

var inventory: Inventory = Inventory.new()

## Nearby pickable items tracked via Area2D overlap signals.
var _nearby_pickables: Dictionary = {}   # PickableNode → true
var _pickup_area:  Area2D            = null
var _sprite:       KnightSprite      = null
var _pickup_sound: AudioStreamPlayer = null
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
	_sprite.offset = Vector2(0.0, -45.0)
	add_child(_sprite)

	_pickup_sound = AudioStreamPlayer.new()
	_pickup_sound.stream    = load("res://sounds/pickup.wav")
	_pickup_sound.volume_db = linear_to_db(PICKUP_SOUND_VOLUME)
	add_child(_pickup_sound)


func _physics_process(delta: float) -> void:
	var dir := _read_input()

	if dir != Vector2.ZERO:
		dir      = dir.normalized()
		heading  = dir.angle()
		velocity = dir * MOVE_SPEED
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
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if ke.keycode == KEY_E and ke.pressed and not ke.echo:
		_try_pickup()
		get_viewport().set_input_as_handled()
	elif ke.keycode == KEY_CTRL and ke.pressed and not ke.echo:
		_try_shoot()
		get_viewport().set_input_as_handled()


## Returns the name of the nearest pickable for the hint UI, or "".
func get_nearest_pickable_name() -> String:
	var nearest := _get_nearest_pickable()
	if nearest == null:
		return ""
	return PickableItemDef.get_display_name(nearest.item_type)


# ── Private ──────────────────────────────────────────────────────────────────

func _setup_collision() -> void:
	var col    := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = COLL_RADIUS
	col.shape     = circle
	col.position  = Vector2(0.0, COLL_OFFSET_Y)
	add_child(col)


func _setup_pickup_area() -> void:
	_pickup_area = Area2D.new()
	_pickup_area.collision_layer = 0
	_pickup_area.collision_mask  = PICKUP_MASK

	var col    := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = COLL_RADIUS
	col.shape     = circle
	col.position  = Vector2(0.0, COLL_OFFSET_Y)
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
	if not inventory.has_space():
		return
	inventory.add(target.item_type)
	_nearby_pickables.erase(target)
	target.remove_from_world()
	if _pickup_sound != null:
		_pickup_sound.play()
	if _inventory_ui != null:
		_inventory_ui.notify_changed()


func _try_shoot() -> void:
	if _shoot_cooldown > 0.0 or _world == null:
		return
	_shoot_cooldown = SHOOT_COOLDOWN
	var dir    := Vector2(cos(heading), sin(heading))
	var origin := position + Vector2(0.0, COLL_OFFSET_Y) \
			+ dir * (COLL_RADIUS + ProjectileNode.RADIUS + 2.0)
	var proj   := ProjectileNode.new()
	proj.initialize(origin, dir, _world)
	_world.add_child(proj)


## Called by Main when InventoryUI emits drop_requested(slot_index).
func drop_item(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= inventory.items.size():
		return
	var item_type := inventory.items[slot_index]
	if not _world.drop_item_near(position, item_type):
		return  # No free cell found; item stays in inventory.
	inventory.items.remove_at(slot_index)
	if _inventory_ui != null:
		_inventory_ui.notify_changed()


static func _read_input() -> Vector2:
	return Vector2(
		float(Input.is_action_pressed("ui_right")) - float(Input.is_action_pressed("ui_left")),
		float(Input.is_action_pressed("ui_down"))  - float(Input.is_action_pressed("ui_up"))
	)
