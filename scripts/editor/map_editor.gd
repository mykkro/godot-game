extends Control

const MENU_SCENE      := "res://scenes/menu.tscn"
const AUTOSAVE_SECS   := 60.0
const LOAD_RADIUS     := 1   # Load (2r+1)² chunks around origin.

var _camera:     EditorCamera  = null
var _chunk_root: Node2D        = null
var _ui:         EditorUI      = null
var _input_node: EditorInput   = null

var _chunks:     Dictionary    = {}   # Vector2i → ChunkEditorNode
var _dirty:      bool          = false
var _autosave:   bool          = true
var _timer:      Timer         = null


func _ready() -> void:
	_build_scene_tree()
	_load_initial_chunks()
	_connect_signals()


# ── Scene tree ────────────────────────────────────────────────────────────────

func _build_scene_tree() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var world_layer := Node2D.new()
	add_child(world_layer)

	_camera = EditorCamera.new()
	# Centre on chunk (0,0); zoom out so the full chunk is visible at startup.
	_camera.position = Vector2(512, 512)
	_camera.zoom     = Vector2(0.5, 0.5)
	world_layer.add_child(_camera)
	_camera.make_current()

	_chunk_root = Node2D.new()
	world_layer.add_child(_chunk_root)

	_ui = EditorUI.new()
	add_child(_ui)

	_input_node = EditorInput.new()
	add_child(_input_node)
	_input_node.setup(_camera)

	_timer = Timer.new()
	_timer.wait_time  = AUTOSAVE_SECS
	_timer.autostart  = true
	_timer.one_shot   = false
	_timer.timeout.connect(_on_autosave_tick)
	add_child(_timer)

	_ui.set_exit_guard(func() -> bool: return _dirty)


func _load_initial_chunks() -> void:
	for cy in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for cx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			_ensure_chunk(Vector2i(cx, cy))
	_ui.set_chunks_loaded(_chunks.size())


func _connect_signals() -> void:
	_input_node.paint_cell.connect(_on_paint_cell)
	_input_node.erase_cell.connect(_on_erase_cell)
	_input_node.hover_cell.connect(_on_hover_cell)

	_ui.save_pressed.connect(_on_save)
	_ui.menu_pressed.connect(_on_go_to_menu)
	_ui.autosave_toggled.connect(func(on: bool): _autosave = on)


# ── Chunk management ──────────────────────────────────────────────────────────

func _ensure_chunk(cc: Vector2i) -> ChunkEditorNode:
	if _chunks.has(cc):
		return _chunks[cc] as ChunkEditorNode

	var data := ChunkPersistence.load_chunk(cc.x, cc.y)
	if data == null:
		data = ChunkGenerator.generate(cc.x, cc.y)

	var node := ChunkEditorNode.new()
	node.position = Vector2(cc.x * ChunkData.CHUNK_SIZE * ChunkData.CELL_SIZE,
	                        cc.y * ChunkData.CHUNK_SIZE * ChunkData.CELL_SIZE)
	_chunk_root.add_child(node)
	node.initialize(data)
	_chunks[cc] = node
	return node


# ── Edit operations ───────────────────────────────────────────────────────────

func _on_paint_cell(cc: Vector2i, lc: Vector2i) -> void:
	var terrain_sel: String = _ui.get_terrain_palette().get_selected()
	var item_sel:    int    = _ui.get_item_palette().get_selected()

	if terrain_sel == "" and item_sel == ItemPalette.NONE_TYPE:
		return

	var chunk_node := _ensure_chunk(cc)
	var data       := chunk_node.get_data()
	var cell       := data.get_cell(lc.x, lc.y)
	if cell == null:
		return

	if terrain_sel != "":
		cell.terrain_type = terrain_sel
		cell.is_obstacle  = not TileRegistry.is_passable(terrain_sel)
		cell.objects.clear()

	if item_sel != ItemPalette.NONE_TYPE:
		if not cell.objects.has(item_sel):
			cell.add_object(item_sel)

	chunk_node.set_cell(lc.x, lc.y, cell)
	_mark_dirty()


func _on_erase_cell(cc: Vector2i, lc: Vector2i) -> void:
	if not _chunks.has(cc):
		return
	var chunk_node := _chunks[cc] as ChunkEditorNode
	var data       := chunk_node.get_data()
	var cell       := data.get_cell(lc.x, lc.y)
	if cell == null:
		return

	# Right-click removes all objects but leaves terrain intact.
	if not cell.objects.is_empty():
		cell.objects.clear()
		chunk_node.set_cell(lc.x, lc.y, cell)
		_mark_dirty()


func _on_hover_cell(cc: Vector2i, lc: Vector2i) -> void:
	_ui.set_chunk_coords(cc)
	_ui.set_cell_coords(lc)
	if _chunks.has(cc):
		var cell := (_chunks[cc] as ChunkEditorNode).get_data().get_cell(lc.x, lc.y)
		if cell != null:
			_ui.set_hover_terrain(cell.terrain_type)
	for coord in _chunks.keys():
		(_chunks[coord] as ChunkEditorNode).set_hover(
				lc if coord == cc else Vector2i(-1, -1))


# ── Persistence ───────────────────────────────────────────────────────────────

func _on_save() -> void:
	for coord in _chunks.keys():
		var node := _chunks[coord] as ChunkEditorNode
		ChunkPersistence.save(node.get_data())
	_dirty = false
	_ui.set_unsaved(false)
	var t := Time.get_datetime_dict_from_system()
	_ui.set_last_saved("%02d:%02d:%02d" % [t.hour, t.minute, t.second])


func _on_autosave_tick() -> void:
	if _autosave and _dirty:
		_on_save()


func _mark_dirty() -> void:
	if not _dirty:
		_dirty = true
		_ui.set_unsaved(true)


# ── Navigation ────────────────────────────────────────────────────────────────

func _on_go_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
