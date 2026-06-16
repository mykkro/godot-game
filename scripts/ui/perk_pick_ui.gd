class_name PerkPickUI
extends CanvasLayer

signal perk_picked

var _stats:      HeroStats      = null
var _perks:      CharacterPerks = null
var _choices:    Array          = []   # Array[PerkDef.ID]

var _overlay:    Control       = null
var _header_lbl: Label         = null
var _cards_vbox: VBoxContainer = null
var _picking:    bool          = false


func _ready() -> void:
    layer        = 80
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_ui()


func open(stats: HeroStats, perks: CharacterPerks) -> void:
    _stats = stats
    _perks = perks

    var pool: Array = []
    for key in PerkDef.ID:
        var id: PerkDef.ID = PerkDef.ID[key]
        if perks.get_level(id) < PerkDef.get_max_level(id):
            pool.append(id)
    pool.shuffle()
    _choices = pool.slice(0, mini(3, pool.size()))

    if _choices.is_empty():
        perk_picked.emit()
        return

    _header_lbl.text = "LEVEL UP!  —  Choose a Perk"
    _build_cards()
    _overlay.visible  = true
    get_tree().paused = true


func _unhandled_input(event: InputEvent) -> void:
    if not _overlay.visible:
        return
    if not (event is InputEventKey):
        return
    var ke := event as InputEventKey
    if ke.echo or not ke.pressed:
        return
    var idx := -1
    match ke.keycode:
        KEY_1: idx = 0
        KEY_2: idx = 1
        KEY_3: idx = 2
    if idx >= 0 and idx < _choices.size():
        _apply_pick(_choices[idx])
        get_viewport().set_input_as_handled()


func _apply_pick(perk_id: PerkDef.ID) -> void:
    if _picking:
        return
    _picking = true
    var new_level := _perks.get_level(perk_id) + 1
    _perks.set_level(perk_id, new_level)

    var delta := PerkDef.get_stat_delta(perk_id)
    if delta.has("attack"):
        _stats.attack  += delta["attack"]
    if delta.has("max_hp"):
        _stats.max_hp    += delta["max_hp"]
        _stats.current_hp = mini(_stats.current_hp + delta["max_hp"], _stats.max_hp)
    if delta.has("max_mana"):
        _stats.max_mana += delta["max_mana"]
    if delta.has("defense"):
        _stats.defense += delta["defense"]
    if delta.has("magic"):
        _stats.magic   += delta["magic"]
    _stats.changed.emit()

    _overlay.visible  = false
    get_tree().paused = false
    perk_picked.emit()
    _picking = false


func _build_cards() -> void:
    for c in _cards_vbox.get_children():
        _cards_vbox.remove_child(c)
        c.queue_free()
    for i in range(_choices.size()):
        var perk_id: PerkDef.ID = _choices[i]
        var cur_lv  := _perks.get_level(perk_id)
        _cards_vbox.add_child(_make_card(perk_id, cur_lv, cur_lv + 1, i + 1))
    if _cards_vbox.get_child_count() > 0:
        (_cards_vbox.get_child(0) as Button).grab_focus()


func _build_ui() -> void:
    _overlay = Control.new()
    _overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    _overlay.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(_overlay)

    var dim := ColorRect.new()
    dim.color = Color(0, 0, 0, 0.65)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.process_mode = Node.PROCESS_MODE_ALWAYS
    _overlay.add_child(dim)

    var center := CenterContainer.new()
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.process_mode = Node.PROCESS_MODE_ALWAYS
    _overlay.add_child(center)

    var panel := _make_panel()
    center.add_child(panel)

    var vbox := VBoxContainer.new()
    vbox.custom_minimum_size = Vector2(520, 0)
    vbox.add_theme_constant_override("separation", 14)
    panel.add_child(vbox)

    _header_lbl = Label.new()
    _header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _header_lbl.add_theme_font_size_override("font_size", 22)
    _header_lbl.add_theme_color_override("font_color", Color(0.92, 0.78, 0.30))
    vbox.add_child(_header_lbl)

    vbox.add_child(_hsep())

    _cards_vbox = VBoxContainer.new()
    _cards_vbox.add_theme_constant_override("separation", 10)
    vbox.add_child(_cards_vbox)

    var key_hint := Label.new()
    key_hint.text = "1 / 2 / 3  —  select"
    key_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    key_hint.add_theme_font_size_override("font_size", 11)
    key_hint.add_theme_color_override("font_color", Color(0.42, 0.42, 0.52))
    vbox.add_child(key_hint)

    _overlay.visible = false


func _make_card(perk_id: PerkDef.ID, cur_lv: int, new_lv: int, key_num: int) -> Button:
    var btn := Button.new()
    btn.custom_minimum_size   = Vector2(0, 90)
    btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    btn.process_mode = Node.PROCESS_MODE_ALWAYS

    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.08, 0.08, 0.14, 0.95)
    normal.border_color = Color(0.50, 0.42, 0.22, 0.85)
    normal.set_border_width_all(2)
    normal.set_corner_radius_all(8)
    normal.set_content_margin_all(12)
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color     = Color(0.14, 0.14, 0.22, 0.95)
    hover.border_color = Color(0.92, 0.78, 0.30)
    btn.add_theme_stylebox_override("normal",  normal)
    btn.add_theme_stylebox_override("hover",   hover)
    btn.add_theme_stylebox_override("focus",   hover)
    btn.add_theme_stylebox_override("pressed", hover)

    # Two-column layout: left = name+level, right = description
    var hbox := HBoxContainer.new()
    hbox.add_theme_constant_override("h_separation", 14)
    hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
    btn.add_child(hbox)

    # Left column — key number, perk name, level badge
    var left := VBoxContainer.new()
    left.add_theme_constant_override("separation", 4)
    left.custom_minimum_size = Vector2(170, 0)
    left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    left.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hbox.add_child(left)

    var name_lbl := Label.new()
    name_lbl.text = "[%d]  %s" % [key_num, PerkDef.get_perk_name(perk_id)]
    name_lbl.add_theme_font_size_override("font_size", 16)
    name_lbl.add_theme_color_override("font_color", Color(0.92, 0.78, 0.30))
    name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    left.add_child(name_lbl)

    var lvl_lbl := Label.new()
    if cur_lv == 0:
        lvl_lbl.text = "NEW"
        lvl_lbl.add_theme_color_override("font_color", Color(0.40, 0.90, 0.50))
    else:
        lvl_lbl.text = "Lv %d → %d" % [cur_lv, new_lv]
        lvl_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.95))
    lvl_lbl.add_theme_font_size_override("font_size", 13)
    lvl_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    left.add_child(lvl_lbl)

    # Divider
    var vsep := VSeparator.new()
    vsep.add_theme_color_override("color", Color(0.30, 0.28, 0.42, 0.55))
    vsep.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hbox.add_child(vsep)

    # Right column — description, expands to fill remaining width
    var desc_lbl := Label.new()
    desc_lbl.text = PerkDef.perk_description(perk_id, new_lv)
    desc_lbl.add_theme_font_size_override("font_size", 14)
    desc_lbl.add_theme_color_override("font_color", Color(0.82, 0.82, 0.90))
    desc_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD
    desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    desc_lbl.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
    desc_lbl.mouse_filter          = Control.MOUSE_FILTER_IGNORE
    hbox.add_child(desc_lbl)

    var id_captured := perk_id
    btn.pressed.connect(func() -> void: _apply_pick(id_captured))

    return btn


static func _make_panel() -> PanelContainer:
    var p := PanelContainer.new()
    var s := StyleBoxFlat.new()
    s.bg_color     = Color(0.06, 0.06, 0.11, 0.97)
    s.border_color = Color(0.50, 0.35, 0.20, 0.90)
    s.set_border_width_all(2)
    s.set_corner_radius_all(10)
    s.set_content_margin_all(20)
    p.add_theme_stylebox_override("panel", s)
    return p


static func _hsep() -> HSeparator:
    var s := HSeparator.new()
    s.add_theme_color_override("color", Color(0.30, 0.28, 0.42, 0.55))
    return s
