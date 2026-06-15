class_name MonsterBook
extends CanvasLayer

var _open_flag:    bool          = false
var _all_species:  Array[String] = []   # sorted master list

## UI refs
var _root:         Control       = null
var _filter_input: LineEdit      = null
var _list_vbox:    VBoxContainer = null
var _detail_sprite: TextureRect  = null
var _detail_name:   Label        = null
var _detail_tier:   Label        = null
var _detail_stats:  VBoxContainer = null
var _detail_empty:  Label        = null


func _ready() -> void:
	layer        = 75
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Build sorted species list from MonsterStats table.
	for sp in MonsterStats._table.keys():
		_all_species.append(sp as String)
	_all_species.sort()

	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if ke.echo or not ke.pressed:
		return

	if _open_flag:
		if ke.keycode == KEY_B or ke.keycode == KEY_ESCAPE:
			_close()
		get_viewport().set_input_as_handled()
		return

	if ke.keycode == KEY_B and not get_tree().paused:
		_open()
		get_viewport().set_input_as_handled()


func _open() -> void:
	_open_flag      = true
	_root.visible   = true
	get_tree().paused = true
	_filter_input.text = ""
	_filter_input.grab_focus()
	_rebuild_list("")
	_show_detail("")   # start empty


func _close() -> void:
	_open_flag      = false
	_root.visible   = false
	get_tree().paused = false


# ── List ──────────────────────────────────────────────────────────────────────

func _rebuild_list(filter: String) -> void:
	for c in _list_vbox.get_children():
		c.queue_free()

	var q := filter.to_lower().strip_edges()
	for sp in _all_species:
		if not q.is_empty() and not sp.to_lower().contains(q):
			continue
		var btn := _make_list_btn(sp)
		_list_vbox.add_child(btn)

	if _list_vbox.get_child_count() == 0:
		var empty := Label.new()
		empty.text = "No matches"
		empty.add_theme_font_size_override("font_size", 13)
		empty.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
		_list_vbox.add_child(empty)


func _make_list_btn(species: String) -> Button:
	var btn := Button.new()
	btn.text              = species
	btn.flat              = true
	btn.alignment         = HORIZONTAL_ALIGNMENT_LEFT
	btn.clip_text         = true
	btn.add_theme_font_size_override("font_size", 13)

	var stats    := MonsterStats.for_species(species)
	var tc       := _tier_color(int(stats.get("xp", 10)))
	btn.add_theme_color_override("font_color",        tc.darkened(0.1))
	btn.add_theme_color_override("font_hover_color",  tc)
	btn.add_theme_color_override("font_focus_color",  tc)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)

	btn.pressed.connect(func() -> void: _show_detail(species))
	return btn


# ── Detail panel ──────────────────────────────────────────────────────────────

func _show_detail(species: String) -> void:
	if species.is_empty():
		_detail_sprite.texture = null
		_detail_name.text      = ""
		_detail_tier.text      = ""
		_detail_empty.visible  = true
		for c in _detail_stats.get_children():
			c.queue_free()
		return

	_detail_empty.visible      = false
	_detail_sprite.texture     = TextureCache.get_being_texture(species)
	_detail_name.text          = species

	var s   := MonsterStats.for_species(species)
	var xp  := int(s.get("xp", 10))
	_detail_tier.text = _tier_label(xp)
	_detail_tier.add_theme_color_override("font_color", _tier_color(xp))

	for c in _detail_stats.get_children():
		c.queue_free()

	var rows: Array = [
		["HP",      str(int(s.get("hp",      10)))],
		["Attack",  str(int(s.get("attack",   4)))],
		["Defense", str(int(s.get("defense",  1)))],
		["Magic",   str(int(s.get("magic",    0)))],
		["XP",      str(xp)],
	]
	for row in rows:
		_detail_stats.add_child(_stat_row(row[0], row[1]))


static func _stat_row(label: String, value: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	var k := Label.new()
	k.text                    = label
	k.custom_minimum_size     = Vector2(72, 0)
	k.add_theme_font_size_override("font_size", 15)
	k.add_theme_color_override("font_color", Color(0.55, 0.60, 0.72))
	var v := Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", 15)
	v.add_theme_color_override("font_color", Color(0.92, 0.92, 1.00))
	h.add_child(k)
	h.add_child(v)
	return h


# ── Tier helpers ──────────────────────────────────────────────────────────────

static func _tier_label(xp: int) -> String:
	if xp <= 6:   return "Tier I — Harmless"
	if xp <= 12:  return "Tier II — Threatening"
	if xp <= 25:  return "Tier III — Dangerous"
	return         "Tier IV — Boss"


static func _tier_color(xp: int) -> Color:
	if xp <= 6:   return Color(0.45, 0.90, 0.50)
	if xp <= 12:  return Color(0.90, 0.88, 0.25)
	if xp <= 25:  return Color(0.95, 0.52, 0.18)
	return         Color(1.00, 0.25, 0.25)


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := _make_panel()
	center.add_child(panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	panel.add_child(outer)

	# ── Header row ──
	var header := HBoxContainer.new()
	outer.add_child(header)

	var title := Label.new()
	title.text = "📖  Monster Book"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.92, 0.80, 0.35))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var count_lbl := Label.new()
	count_lbl.text = "%d species" % _all_species.size()
	count_lbl.add_theme_font_size_override("font_size", 13)
	count_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.58))
	count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(count_lbl)

	outer.add_child(_hsep())

	# ── Body: list + detail side-by-side ──
	var body := HBoxContainer.new()
	body.add_theme_constant_override("h_separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)

	body.add_child(_build_list_panel())
	body.add_child(_vsep())
	body.add_child(_build_detail_panel())

	outer.add_child(_hsep())

	# ── Footer hint ──
	var hint := Label.new()
	hint.text = "B  /  Escape  —  close"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.38, 0.38, 0.50))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(hint)

	_root.visible = false


func _build_list_panel() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.custom_minimum_size    = Vector2(185, 0)
	col.size_flags_vertical    = Control.SIZE_EXPAND_FILL

	# Search input
	_filter_input = LineEdit.new()
	_filter_input.placeholder_text = "Search…"
	_filter_input.add_theme_font_size_override("font_size", 13)
	_filter_input.add_theme_color_override("font_color",             Color(0.95, 0.95, 0.85))
	_filter_input.add_theme_color_override("font_placeholder_color", Color(0.45, 0.45, 0.50))
	_filter_input.process_mode = Node.PROCESS_MODE_ALWAYS
	_filter_input.text_changed.connect(func(t: String) -> void: _rebuild_list(t))
	col.add_child(_filter_input)

	# Scrollable list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size    = Vector2(0, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_list_vbox = VBoxContainer.new()
	_list_vbox.add_theme_constant_override("separation", 2)
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_vbox)

	return col


func _build_detail_panel() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	col.custom_minimum_size   = Vector2(240, 0)

	# Empty-state label
	_detail_empty = Label.new()
	_detail_empty.text = "← Select a monster"
	_detail_empty.add_theme_font_size_override("font_size", 15)
	_detail_empty.add_theme_color_override("font_color", Color(0.35, 0.35, 0.48))
	_detail_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_empty.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_detail_empty.size_flags_vertical  = Control.SIZE_EXPAND_FILL
	col.add_child(_detail_empty)

	# Sprite
	_detail_sprite = TextureRect.new()
	_detail_sprite.custom_minimum_size    = Vector2(96, 96)
	_detail_sprite.expand_mode            = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_detail_sprite.stretch_mode           = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_detail_sprite.size_flags_horizontal  = Control.SIZE_SHRINK_CENTER
	col.add_child(_detail_sprite)

	# Monster name
	_detail_name = Label.new()
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_name.add_theme_font_size_override("font_size", 22)
	_detail_name.add_theme_color_override("font_color", Color(1.0, 0.88, 0.60))
	col.add_child(_detail_name)

	# Tier
	_detail_tier = Label.new()
	_detail_tier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_tier.add_theme_font_size_override("font_size", 13)
	col.add_child(_detail_tier)

	col.add_child(_hsep())

	# Stats VBox
	_detail_stats = VBoxContainer.new()
	_detail_stats.add_theme_constant_override("separation", 6)
	col.add_child(_detail_stats)

	# Push everything up
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	return col


# ── Style helpers ─────────────────────────────────────────────────────────────

static func _make_panel() -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color     = Color(0.06, 0.06, 0.11, 0.97)
	s.border_color = Color(0.48, 0.38, 0.22, 0.90)
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(18)
	p.add_theme_stylebox_override("panel", s)
	return p


static func _hsep() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_color_override("color", Color(0.30, 0.28, 0.42, 0.55))
	return s


static func _vsep() -> VSeparator:
	var s := VSeparator.new()
	s.add_theme_color_override("color", Color(0.30, 0.28, 0.42, 0.55))
	return s
