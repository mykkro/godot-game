class_name DebugOverlay
extends CanvasLayer

## Toggle with F3.  The overlay sits on a CanvasLayer so it is always
## drawn in screen-space on top of everything else.

var _visible_flag: bool = false

# References set by setup().
var _world:       World      = null
var _fog_manager: FogManager = null
var _avatar:      Avatar     = null

# UI nodes built in _ready().
var _panel: PanelContainer = null
var _label: Label          = null


func setup(world: World, fog_manager: FogManager, avatar: Avatar) -> void:
	_world       = world
	_fog_manager = fog_manager
	_avatar      = avatar


func _ready() -> void:
	layer = 100  # Draw above everything.

	# --- Panel background -------------------------------------------------
	_panel = PanelContainer.new()
	_panel.position = Vector2(8, 8)
	# Fixed width so the panel never resizes as text changes.
	_panel.custom_minimum_size = Vector2(340, 0)
	add_child(_panel)

	var style := StyleBoxFlat.new()
	style.bg_color                   = Color(0, 0, 0, 0.55)
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	style.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", style)

	# --- Monospace font ---------------------------------------------------
	var mono_font := SystemFont.new()
	mono_font.font_names = PackedStringArray(
			["Courier New", "Consolas", "Lucida Console", "DejaVu Sans Mono", "monospace"])
	mono_font.font_style = TextServer.FONT_BOLD

	# --- Label inside the panel -------------------------------------------
	_label = Label.new()
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.autowrap_mode         = TextServer.AUTOWRAP_OFF
	_label.clip_text             = true
	_label.add_theme_font_override("font",              mono_font)
	_label.add_theme_font_size_override("font_size",    13)
	_label.add_theme_color_override("font_color",       Color(1, 1, 1))
	_label.add_theme_color_override("font_shadow_color",Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_panel.add_child(_label)

	_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if key_event.keycode == KEY_F3 and key_event.pressed and not key_event.echo:
		_visible_flag = not _visible_flag
		_panel.visible = _visible_flag
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _visible_flag or _avatar == null:
		return
	_label.text = _build_text()


# ── Text assembly ─────────────────────────────────────────────────────────────

func _build_text() -> String:
	var pos: Vector2   = _avatar.position
	var heading: float = _avatar.heading

	# World pixel position.
	var wx: float = snapped(pos.x, 0.1)
	var wy: float = snapped(pos.y, 0.1)

	# Chunk grid coordinates.
	var chunk_coord := Vector2i(
		int(floor(pos.x / ChunkData.CHUNK_PIXEL_SIZE)),
		int(floor(pos.y / ChunkData.CHUNK_PIXEL_SIZE))
	)

	# Local cell position within the chunk (0-15).
	var cell_global := Vector2i(
		int(floor(pos.x / ChunkData.CELL_SIZE)),
		int(floor(pos.y / ChunkData.CELL_SIZE))
	)
	var cell_local := Vector2i(
		cell_global.x - chunk_coord.x * ChunkData.CHUNK_SIZE,
		cell_global.y - chunk_coord.y * ChunkData.CHUNK_SIZE
	)

	# Sub-cell position (0.0-63.99…).
	var sub_x := fmod(pos.x, ChunkData.CELL_SIZE)
	var sub_y := fmod(pos.y, ChunkData.CELL_SIZE)
	if sub_x < 0: sub_x += ChunkData.CELL_SIZE
	if sub_y < 0: sub_y += ChunkData.CELL_SIZE

	# Heading as compass direction + degrees.
	var deg     := rad_to_deg(heading)
	var compass := _heading_compass(heading)

	var lines: PackedStringArray = PackedStringArray()
	lines.append("=== DEBUG (F3 to hide) ===")
	lines.append("")

	# Position block.
	lines.append("[Position]")
	lines.append("  World:    %.1f, %.1f" % [wx, wy])
	lines.append("  Chunk:    %d, %d" % [chunk_coord.x, chunk_coord.y])
	lines.append("  Cell:     %d, %d  (local in chunk)" % [cell_local.x, cell_local.y])
	lines.append("  Sub-cell: %.1f, %.1f  (px within cell)" % [sub_x, sub_y])
	lines.append("  Heading:  %.1f°  %s" % [deg, compass])
	lines.append("")

	# Avatar / actor status.
	lines.append("[Avatar]")
	lines.append("  Speed:    %.0f px/s" % _avatar.velocity.length())
	lines.append("")

	# Current cell terrain/objects.
	lines.append("[Cell under avatar]")
	var cell_str := "  (chunk not loaded)"
	if _world != null:
		var cell := _world.get_cell_at(pos)
		if cell != null:
			var terrain_name: String = TerrainType.Type.keys()[cell.terrain_type] \
					if cell.terrain_type < TerrainType.Type.size() else "?"
			cell_str  = "  Terrain:  %s (%d)" % [terrain_name, cell.terrain_type]
			cell_str += "\n  Obstacle: %s" % str(cell.is_obstacle)
			if cell.objects.is_empty():
				cell_str += "\n  Objects:  (none)"
			else:
				var names: PackedStringArray = PackedStringArray()
				for obj_type in cell.objects:
					var key: String = MapObject.Type.keys()[obj_type] \
							if obj_type < MapObject.Type.size() else "?"
					names.append(key)
				cell_str += "\n  Objects:  " + ", ".join(names)
	lines.append(cell_str)
	lines.append("")

	# Fog.
	lines.append("[Fog of War]")
	var fog_str := "  (unavailable)"
	if _world != null:
		# Look up fog from FogManager's internal dict by chunk coord.
		var fog_data: FogData = _fog_manager._fog_data.get(chunk_coord, null)
		if fog_data != null:
			var level    := fog_data.get_level(cell_local.x, cell_local.y)
			var labels: Array[String] = ["UNEXPLORED", "DIM", "PARTIAL", "VISIBLE"]
			var lname: String = labels[level] if level < labels.size() else "?"
			fog_str = "  Level:    %d (%s)" % [level, lname]
	lines.append(fog_str)

	return "\n".join(lines)


static func _heading_compass(rad: float) -> String:
	# Normalise to [0, TAU).
	var a := fmod(rad, TAU)
	if a < 0.0:
		a += TAU
	# 8-point compass; each sector is TAU/8 wide, centred on a direction.
	var idx := int(round(a / (TAU / 8.0))) % 8
	var points: Array[String] = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
	return points[idx]
