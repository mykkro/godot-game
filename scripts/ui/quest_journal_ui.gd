class_name QuestJournalUI
extends CanvasLayer

## Quest journal — toggle with Q.
## Active / Completed sections are collapsible; state is remembered for the session.

var _overlay:             Control         = null
var _content_vbox:        VBoxContainer   = null
var _scroll:              ScrollContainer = null
var _inventory:           Inventory       = null
var _open:                bool            = false
var _active_collapsed:    bool            = false
var _completed_collapsed: bool            = false


func _ready() -> void:
	layer        = 62
	process_mode = Node.PROCESS_MODE_ALWAYS

	var dim := ColorRect.new()
	dim.color        = Color(0, 0, 0, 0.55)
	dim.process_mode = Node.PROCESS_MODE_ALWAYS
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	# Panel anchored: full height (minus 40 px margins), 540 px wide, centred.
	var panel := PanelContainer.new()
	panel.set_anchor(SIDE_LEFT,   0.5)
	panel.set_anchor(SIDE_RIGHT,  0.5)
	panel.set_anchor(SIDE_TOP,    0.0)
	panel.set_anchor(SIDE_BOTTOM, 1.0)
	panel.offset_left   = -270.0
	panel.offset_right  =  270.0
	panel.offset_top    =   40.0
	panel.offset_bottom =  -40.0
	panel.process_mode  = Node.PROCESS_MODE_ALWAYS
	panel.add_theme_stylebox_override("panel", _make_style())
	dim.add_child(panel)

	# Root VBox — fixed header then the scrollable region fills remaining height.
	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	root_vbox.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_horizontal = Control.SIZE_FILL
	panel.add_child(root_vbox)

	# ── Fixed header ──────────────────────────────────────────────────────────
	var title_row := HBoxContainer.new()
	root_vbox.add_child(title_row)

	var title := Label.new()
	title.text                  = "Quest Journal"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	title_row.add_child(title)

	var close_btn := Button.new()
	close_btn.text         = "✕"
	close_btn.flat         = true
	close_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	close_btn.pressed.connect(close)
	title_row.add_child(close_btn)

	root_vbox.add_child(HSeparator.new())

	# ── Scrollable content ────────────────────────────────────────────────────
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal  = Control.SIZE_FILL
	_scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.process_mode           = Node.PROCESS_MODE_ALWAYS
	root_vbox.add_child(_scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", 10)
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content_vbox)

	_overlay         = dim
	_overlay.visible = false


func setup(inventory: Inventory) -> void:
	_inventory = inventory


func open() -> void:
	_open            = true
	_overlay.visible = true
	if _inventory != null:
		QuestManager.check_readiness(_inventory)
	_rebuild()


func close() -> void:
	_open            = false
	_overlay.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	if ke.keycode == KEY_Q:
		if _open:
			close()
		elif not get_tree().paused:
			open()
		get_viewport().set_input_as_handled()
	elif ke.keycode == KEY_ESCAPE and _open:
		close()
		get_viewport().set_input_as_handled()


# ── Private ───────────────────────────────────────────────────────────────────

func _rebuild() -> void:
	for c in _content_vbox.get_children():
		c.queue_free()

	# Active section.
	_content_vbox.add_child(_make_section_header(
		"Active", Color(0.65, 0.88, 0.65), _active_collapsed,
		func() -> void:
			_active_collapsed = not _active_collapsed
			_rebuild()
	))
	if not _active_collapsed:
		var active_list := VBoxContainer.new()
		active_list.add_theme_constant_override("separation", 10)
		_content_vbox.add_child(active_list)
		if QuestManager.active_quests.is_empty():
			active_list.add_child(_empty_label("No active quests."))
		else:
			for q: QuestInstance in QuestManager.active_quests:
				active_list.add_child(_make_card(q))

	_content_vbox.add_child(_make_hsep())

	# Completed section.
	_content_vbox.add_child(_make_section_header(
		"Completed", Color(0.55, 0.55, 0.65), _completed_collapsed,
		func() -> void:
			_completed_collapsed = not _completed_collapsed
			_rebuild()
	))
	if not _completed_collapsed:
		var completed_list := VBoxContainer.new()
		completed_list.add_theme_constant_override("separation", 10)
		_content_vbox.add_child(completed_list)
		if QuestManager.completed_quests.is_empty():
			completed_list.add_child(_empty_label("None yet."))
		else:
			for q: QuestInstance in QuestManager.completed_quests:
				completed_list.add_child(_make_card(q))

	var hint := Label.new()
	hint.text                 = "Press Q or Escape to close  ·  ○/◎ to track on minimap"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	_content_vbox.add_child(hint)


func _make_section_header(label: String, color: Color, collapsed: bool, on_toggle: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var arrow := Button.new()
	arrow.text         = "▶" if collapsed else "▼"
	arrow.flat         = true
	arrow.process_mode = Node.PROCESS_MODE_ALWAYS
	arrow.add_theme_font_size_override("font_size", 11)
	arrow.add_theme_color_override("font_color",       color)
	arrow.add_theme_color_override("font_hover_color", color.lightened(0.25))
	arrow.pressed.connect(on_toggle)
	row.add_child(arrow)

	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", color)
	row.add_child(lbl)

	return row


func _make_card(q: QuestInstance) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s    := StyleBoxFlat.new()
	s.bg_color            = Color(0.10, 0.10, 0.16, 0.88)
	s.border_width_left   = 1; s.border_width_right  = 1
	s.border_width_top    = 1; s.border_width_bottom = 1
	s.border_color        = Color(0.28, 0.28, 0.38, 0.7)
	s.corner_radius_top_left    = 4; s.corner_radius_top_right    = 4
	s.corner_radius_bottom_left = 4; s.corner_radius_bottom_right = 4
	s.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", s)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(vbox)

	# Title row — title label + minimap-track toggle (non-completed only).
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 6)
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var title_label := Label.new()
	title_label.text                  = q.title
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 15)
	match q.state:
		QuestInstance.State.COMPLETED:
			title_label.add_theme_color_override("font_color", Color(0.50, 0.50, 0.58))
		QuestInstance.State.READY:
			title_label.add_theme_color_override("font_color", Color(0.35, 0.95, 0.45))
		_:
			title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	title_row.add_child(title_label)

	if q.state != QuestInstance.State.COMPLETED:
		var is_tracked := QuestManager.tracked_quest_id == q.quest_id
		var track_btn  := Button.new()
		track_btn.text         = "◎" if is_tracked else "○"
		track_btn.flat         = true
		track_btn.process_mode = Node.PROCESS_MODE_ALWAYS
		track_btn.tooltip_text = "Track on minimap"
		track_btn.add_theme_font_size_override("font_size", 16)
		var tc := Color(0.15, 0.90, 1.0) if is_tracked else Color(0.40, 0.40, 0.50)
		track_btn.add_theme_color_override("font_color",       tc)
		track_btn.add_theme_color_override("font_hover_color", Color(0.15, 0.90, 1.0))
		track_btn.pressed.connect(func() -> void:
			QuestManager.set_tracked(q.quest_id)
			_rebuild()
		)
		title_row.add_child(track_btn)

	vbox.add_child(title_row)

	# Description.
	var desc := Label.new()
	desc.text                  = q.description
	desc.autowrap_mode         = TextServer.AUTOWRAP_WORD
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.76, 0.80, 0.76))
	vbox.add_child(desc)

	# Status line.
	var status := Label.new()
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_theme_font_size_override("font_size", 12)
	match q.state:
		QuestInstance.State.ACTIVE:
			var have := 0 if _inventory == null else QuestManager.count_item(_inventory, q.required_item)
			status.text = "Progress: %d / %d  ·  Reward: %d coins  ·  From: %s" % \
				[have, q.required_count, q.gold_reward, q.giver_npc_name]
			status.add_theme_color_override("font_color", Color(0.60, 0.72, 0.90))
		QuestInstance.State.READY:
			status.text = "Ready to turn in at %s!  ·  Reward: %d coins" % \
				[q.giver_npc_name, q.gold_reward]
			status.add_theme_color_override("font_color", Color(0.28, 0.90, 0.40))
		QuestInstance.State.COMPLETED:
			status.text = "Completed  ·  Paid: %d coins  ·  Given by: %s" % \
				[q.gold_reward, q.giver_npc_name]
			status.add_theme_color_override("font_color", Color(0.45, 0.45, 0.55))
	vbox.add_child(status)

	return card


func _empty_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.42, 0.42, 0.48))
	lbl.add_theme_font_size_override("font_size", 13)
	return lbl


func _make_hsep() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	return sep


func _make_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color            = Color(0.06, 0.06, 0.10, 0.93)
	s.border_width_left   = 2; s.border_width_right  = 2
	s.border_width_top    = 2; s.border_width_bottom = 2
	s.border_color        = Color(0.4, 0.4, 0.5, 0.8)
	s.corner_radius_top_left    = 6; s.corner_radius_top_right    = 6
	s.corner_radius_bottom_left = 6; s.corner_radius_bottom_right = 6
	s.set_content_margin_all(24)
	return s
