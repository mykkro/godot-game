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

var _chest_editor: ChestInventoryEditor = null


func _ready() -> void:
	_build_scene_tree()
	_load_initial_chunks()
	_connect_signals()


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_WHEEL_UP and mb.button_index != MOUSE_BUTTON_WHEEL_DOWN:
		return
	var vp_w := get_viewport().get_visible_rect().size.x
	if mb.position.x < vp_w - EditorUI.PANEL_WIDTH:
		return
	# Wheel over right panel: scroll the palette, never zoom the map.
	var scroll := _ui.get_palette_scroll()
	if scroll != null and mb.pressed:
		var delta := 64 * (1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
		scroll.scroll_vertical += delta
	get_viewport().set_input_as_handled()


# ── Scene tree ────────────────────────────────────────────────────────────────

func _build_scene_tree() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var world_layer := Node2D.new()
	add_child(world_layer)

	_camera = EditorCamera.new()
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

	_chest_editor = ChestInventoryEditor.new()
	add_child(_chest_editor)
	_chest_editor.closed.connect(_on_chest_editor_closed)
	_chest_editor.chest_removed.connect(_on_chest_removed)


func _load_initial_chunks() -> void:
	for cy in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
		for cx in range(-LOAD_RADIUS, LOAD_RADIUS + 1):
			_ensure_chunk(Vector2i(cx, cy))
	_ui.set_chunks_loaded(_chunks.size())


func _connect_signals() -> void:
	_input_node.paint_cell.connect(_on_paint_cell)
	_input_node.erase_cell.connect(_on_right_click_cell)
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
	if _chest_editor.visible:
		return
	var size := _ui.get_brush_size()
	if size == 1:
		_paint_single_cell(cc, lc)
		_mark_dirty()
		return

	var half  := size / 2
	var world := Vector2i(cc.x * ChunkData.CHUNK_SIZE + lc.x,
	                      cc.y * ChunkData.CHUNK_SIZE + lc.y)
	var painted := false
	for dy in range(-half, half + 1):
		for dx in range(-half, half + 1):
			var wgx := world.x + dx
			var wgy := world.y + dy
			var bcc_x := floori(float(wgx) / ChunkData.CHUNK_SIZE)
			var bcc_y := floori(float(wgy) / ChunkData.CHUNK_SIZE)
			var blc_x := wgx - bcc_x * ChunkData.CHUNK_SIZE
			var blc_y := wgy - bcc_y * ChunkData.CHUNK_SIZE
			_paint_single_cell(Vector2i(bcc_x, bcc_y), Vector2i(blc_x, blc_y))
			painted = true
	if painted:
		_mark_dirty()


func _paint_single_cell(cc: Vector2i, lc: Vector2i) -> void:
	if _chest_editor.visible:
		return
	var terrain_sel:    String = _ui.get_terrain_palette().get_selected()
	var item_sel:       int    = _ui.get_item_palette().get_selected()
	var chest_variant:  int    = _ui.get_item_palette().get_selected_chest_variant()
	var rock_variant:   int    = _ui.get_item_palette().get_selected_rock_variant()
	var monster_sel:    String = _ui.get_monster_palette().get_selected()

	if terrain_sel == "" and item_sel == ItemPalette.NONE_TYPE and monster_sel == "":
		return

	var chunk_node := _ensure_chunk(cc)
	var data       := chunk_node.get_data()
	var cell       := data.get_cell(lc.x, lc.y)
	if cell == null:
		return

	var active_layer := _ui.get_active_layer()

	if terrain_sel != "":
		if active_layer == 0:
			cell.terrain_type = terrain_sel
			cell.is_obstacle  = not TileRegistry.is_passable(terrain_sel)
			cell.objects.clear()
			data.set_chest_variant(lc.x, lc.y, 0)
			data.set_chest_contents(lc.x, lc.y, [])
			data.set_rock_variant(lc.x, lc.y, 0)
			data.erase_terrain_overlay(lc.x, lc.y)
		else:
			data.set_terrain_overlay(lc.x, lc.y, terrain_sel)
			cell.is_obstacle = not TileRegistry.is_passable(terrain_sel)

	if item_sel != ItemPalette.NONE_TYPE:
		cell.objects.clear()
		cell.add_object(item_sel)
		if item_sel == MapObject.Type.CHEST_SMALL:
			data.set_chest_variant(lc.x, lc.y, chest_variant)
			data.set_chest_contents(lc.x, lc.y, [])
			data.set_rock_variant(lc.x, lc.y, 0)
		elif item_sel == MapObject.Type.ROCK:
			data.set_rock_variant(lc.x, lc.y, rock_variant)
			data.set_chest_variant(lc.x, lc.y, 0)
			data.set_chest_contents(lc.x, lc.y, [])
		else:
			data.set_chest_variant(lc.x, lc.y, 0)
			data.set_chest_contents(lc.x, lc.y, [])
			data.set_rock_variant(lc.x, lc.y, 0)

	if not monster_sel.is_empty():
		data.set_monster_placement(lc.x, lc.y, monster_sel)

	chunk_node.set_cell(lc.x, lc.y, cell)


## Right-click: open chest editor if cell contains a chest, otherwise erase objects.
func _on_right_click_cell(cc: Vector2i, lc: Vector2i) -> void:
	if _chest_editor.visible:
		return
	if not _chunks.has(cc):
		return
	var chunk_node := _chunks[cc] as ChunkEditorNode
	var data       := chunk_node.get_data()
	var cell       := data.get_cell(lc.x, lc.y)
	if cell == null:
		return

	if cell.objects.has(MapObject.Type.CHEST_SMALL):
		_chest_editor.open(data, lc.x, lc.y)
		# Store the current chunk coord so we know which node to redraw on close.
		_chest_editor.set_meta("chunk_coord", cc)
		return

	var active_layer := _ui.get_active_layer()
	if active_layer == 1:
		# Layer 1: right-click erases overlay and restores layer 0 passability.
		var overlay := data.get_terrain_overlay(lc.x, lc.y)
		if overlay != "":
			data.erase_terrain_overlay(lc.x, lc.y)
			cell.is_obstacle = not TileRegistry.is_passable(cell.terrain_type)
			chunk_node.set_cell(lc.x, lc.y, cell)
			_mark_dirty()
			return

	# Layer 0: default erase objects.
	if not cell.objects.is_empty():
		cell.objects.clear()
		data.set_chest_variant(lc.x, lc.y, 0)
		data.set_chest_contents(lc.x, lc.y, [])
		data.set_rock_variant(lc.x, lc.y, 0)
		chunk_node.set_cell(lc.x, lc.y, cell)
		_mark_dirty()

	# Also erase any editor-placed monster.
	if not data.get_monster_placement(lc.x, lc.y).is_empty():
		data.set_monster_placement(lc.x, lc.y, "")
		chunk_node.set_cell(lc.x, lc.y, cell)
		_mark_dirty()


func _on_hover_cell(cc: Vector2i, lc: Vector2i) -> void:
	_ui.set_chunk_coords(cc)
	_ui.set_cell_coords(lc)
	_ui.set_world_coords(cc.x * ChunkData.CHUNK_SIZE + lc.x, cc.y * ChunkData.CHUNK_SIZE + lc.y)
	if _chunks.has(cc):
		var cell := (_chunks[cc] as ChunkEditorNode).get_data().get_cell(lc.x, lc.y)
		if cell != null:
			var overlay := (_chunks[cc] as ChunkEditorNode).get_data().get_terrain_overlay(lc.x, lc.y)
			_ui.set_hover_terrain(cell.terrain_type, overlay)
	for coord in _chunks.keys():
		(_chunks[coord] as ChunkEditorNode).set_hover(
				lc if coord == cc else Vector2i(-1, -1))


# ── Chest editor callbacks ────────────────────────────────────────────────────

func _on_chest_editor_closed() -> void:
	_redraw_chest_chunk()
	_mark_dirty()


func _on_chest_removed() -> void:
	var cc := _chest_editor.get_meta("chunk_coord", Vector2i.ZERO) as Vector2i
	if not _chunks.has(cc):
		return
	var chunk_node := _chunks[cc] as ChunkEditorNode
	var data       := chunk_node.get_data()
	var lx: int    = _chest_editor.get_lx()
	var ly: int    = _chest_editor.get_ly()
	var cell       := data.get_cell(lx, ly)
	if cell != null:
		cell.objects.erase(MapObject.Type.CHEST_SMALL)
		data.set_chest_variant(lx, ly, 0)
		data.set_chest_contents(lx, ly, [])
		chunk_node.set_cell(lx, ly, cell)
	_mark_dirty()


func _redraw_chest_chunk() -> void:
	var cc := _chest_editor.get_meta("chunk_coord", Vector2i.ZERO) as Vector2i
	if _chunks.has(cc):
		(_chunks[cc] as ChunkEditorNode).queue_redraw()


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
