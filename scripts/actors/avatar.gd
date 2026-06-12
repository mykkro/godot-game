class_name Avatar
extends Actor

const MOVE_SPEED     := 200.0  # pixels / second
const PICKUP_RADIUS  := 52.0   # pixels; pickup detection zone radius
## Collision layer mask for PickableNode (must match PickableNode.LAYER_PICKABLE).
const PICKUP_MASK    := 2

var _world:        World        = null
var _fog_manager:  FogManager   = null
var _inventory_ui: InventoryUI  = null

var inventory: Inventory = Inventory.new()

## Nearby pickable items tracked via Area2D overlap signals.
var _nearby_pickables: Dictionary = {}   # PickableNode → true
var _pickup_area: Area2D = null


## Must be called after the node is in the scene tree (from Main._ready).
func setup(world: World, fog_manager: FogManager,
		   inventory_ui: InventoryUI) -> void:
	_world        = world
	_fog_manager  = fog_manager
	_inventory_ui = inventory_ui


func _ready() -> void:
	collision_radius = 14.0
	super._ready()
	_setup_pickup_area()


func _physics_process(_delta: float) -> void:
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

	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if ke.keycode == KEY_E and ke.pressed and not ke.echo:
		_try_pickup()
		get_viewport().set_input_as_handled()


## Returns the name of the nearest pickable for the hint UI, or "".
func get_nearest_pickable_name() -> String:
	var nearest := _get_nearest_pickable()
	if nearest == null:
		return ""
	return PickableItemDef.get_display_name(nearest.item_type)


func _draw() -> void:
	draw_circle(Vector2.ZERO, collision_radius, Color(0.20, 0.55, 1.00))
	var tip := Vector2(cos(heading), sin(heading)) * (collision_radius + 5.0)
	draw_line(Vector2.ZERO, tip, Color.WHITE, 2.5)
	draw_arc(Vector2.ZERO, collision_radius, 0.0, TAU, 24,
			 Color(0.10, 0.30, 0.70), 1.5)


# ── Private ──────────────────────────────────────────────────────────────────

func _setup_pickup_area() -> void:
	_pickup_area = Area2D.new()
	_pickup_area.collision_layer = 0
	_pickup_area.collision_mask  = PICKUP_MASK

	var col    := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = PICKUP_RADIUS
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
	if not inventory.has_space():
		return
	inventory.add(target.item_type)
	_nearby_pickables.erase(target)
	target.remove_from_world()
	if _inventory_ui != null:
		_inventory_ui.notify_changed()


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
