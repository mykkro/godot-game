class_name ConsoleUI
extends CanvasLayer

const MAX_LINES := 300

var _output: RichTextLabel = null
var _input:  LineEdit      = null
var _lines:  Array[String] = []

var _history:     Array[String] = []
var _history_idx: int           = -1
var _input_saved: String        = ""

var _avatar: Avatar = null


func _ready() -> void:
	layer        = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible      = false
	_build_ui()


func setup(avatar: Avatar) -> void:
	_avatar = avatar


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.10, 0.92)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		style.set_border_width(side, 1)
	style.border_color = Color(0.35, 0.35, 0.45, 0.8)
	for c in range(4):
		style.set_corner_radius(c, 6)
	style.set_content_margin_all(10)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left   =  180
	panel.offset_top    =    8
	panel.offset_right  = -180
	panel.offset_bottom =  210
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	_output = RichTextLabel.new()
	_output.bbcode_enabled         = false
	_output.scroll_active          = true
	_output.scroll_following       = true
	_output.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	_output.custom_minimum_size    = Vector2(0, 120)
	_output.add_theme_font_size_override("normal_font_size", 13)
	_output.add_theme_color_override("default_color", Color(0.80, 0.85, 0.80))
	vbox.add_child(_output)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	vbox.add_child(sep)

	_input = LineEdit.new()
	_input.placeholder_text = "Enter command…  (/help for list)"
	_input.add_theme_font_size_override("font_size", 14)
	_input.add_theme_color_override("font_color",             Color(1.0, 1.0, 0.9))
	_input.add_theme_color_override("font_placeholder_color", Color(0.5, 0.5, 0.45))
	_input.add_theme_color_override("caret_color",            Color(1.0, 1.0, 0.8))
	_input.process_mode = Node.PROCESS_MODE_ALWAYS
	_input.text_submitted.connect(_on_submitted)
	_input.gui_input.connect(_on_input_key)
	vbox.add_child(_input)


# ── Input handling ────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return

	if ke.keycode == KEY_QUOTELEFT or ke.keycode == KEY_SLASH:
		visible = not visible
		if visible:
			_input.grab_focus()
			get_tree().paused = true
		else:
			get_tree().paused = false
		get_viewport().set_input_as_handled()
		return

	# Console open — swallow everything so the game never sees it.
	if visible:
		if ke.keycode == KEY_ESCAPE:
			visible           = false
			get_tree().paused = false
		get_viewport().set_input_as_handled()


func _on_submitted(text: String) -> void:
	_input.clear()
	_input.grab_focus()
	_history_idx = -1
	_input_saved = ""
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return
	if _history.is_empty() or _history.back() != trimmed:
		_history.append(trimmed)
	_execute(trimmed)


func _on_input_key(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed:
		return
	if ke.keycode == KEY_UP:
		if _history.is_empty():
			return
		if _history_idx == -1:
			_input_saved = _input.text
			_history_idx = _history.size() - 1
		elif _history_idx > 0:
			_history_idx -= 1
		_input.text         = _history[_history_idx]
		_input.caret_column = _input.text.length()
		_input.accept_event()
	elif ke.keycode == KEY_DOWN:
		if _history_idx == -1:
			return
		_history_idx += 1
		if _history_idx >= _history.size():
			_history_idx = -1
			_input.text  = _input_saved
		else:
			_input.text  = _history[_history_idx]
		_input.caret_column = _input.text.length()
		_input.accept_event()
	elif ke.keycode == KEY_PAGEUP:
		var sb := _output.get_v_scroll_bar()
		sb.value -= sb.page
		_input.accept_event()
	elif ke.keycode == KEY_PAGEDOWN:
		var sb := _output.get_v_scroll_bar()
		sb.value += sb.page
		_input.accept_event()


# ── Command dispatch ──────────────────────────────────────────────────────────

func _execute(text: String) -> void:
	if not text.begins_with("/"):
		_print_line("[hint] Commands start with /  — type /help for list")
		return
	var parts := _parse_args(text.substr(1))
	if parts.is_empty():
		return
	match parts[0].to_lower():
		"set_date":   _cmd_set_date(parts)
		"set_time":   _cmd_set_time(parts)
		"give":       _cmd_give(parts)
		"coins":      _cmd_coins(parts)
		"items":      _cmd_items(parts)
		"pos":        _cmd_pos()
		"tp":         _cmd_tp(parts)
		"day":        _cmd_day()
		"night":      _cmd_night()
		"timescale":  _cmd_timescale(parts)
		"clear_inv":  _cmd_clear_inv()
		"perk":       _cmd_perk(parts)
		"name":       _cmd_name(parts)
		"stats":      _cmd_stats()
		"hp":         _cmd_hp(parts)
		"heal":       _cmd_heal(parts)
		"xp":         _cmd_xp(parts)
		"level":      _cmd_level(parts)
		"stat":       _cmd_stat(parts)
		"monsters":   _cmd_monsters()
		"killall":    _cmd_killall()
		"help":       _cmd_help()
		var unknown:  _print_line("Unknown: /" + unknown + "  (try /help)")


# ── Command implementations ───────────────────────────────────────────────────

func _cmd_help() -> void:
	_print_line("/give <name> [n]         give item(s) — use /items to browse names")
	_print_line("/coins <n>               add n coins")
	_print_line("/items [filter]          list item names")
	_print_line("/pos                     show player position")
	_print_line("/tp <x> <y>              teleport player")
	_print_line("/day  /night             jump to 8 AM / 10 PM")
	_print_line("/set_date MM/DD          set date")
	_print_line("/set_time HH:MM          set time (24 h)")
	_print_line("/timescale <n>           game clock speed (1=normal, 0=stop)")
	_print_line("/clear_inv               wipe player inventory")
	_print_line("/perk [name] [lvl]       show or set a perk  (/perk trader 3)")
	_print_line("/name <new name>         rename your character")
	_print_line("── battle ──────────────────────────────")
	_print_line("/stats                   show all battle stats")
	_print_line("/hp [n]                  show or set current HP")
	_print_line("/heal [n]                heal n HP (default: full)")
	_print_line("/xp <n>                  add XP (auto level-up)")
	_print_line("/level <n>               jump to level n")
	_print_line("/stat <name> <value>     set a stat (attack magic defense max_hp max_mana)")
	_print_line("/monsters                list all active monsters with HP")
	_print_line("/killall                 despawn all active monsters")


func _cmd_give(parts: Array) -> void:
	if parts.size() < 2:
		_print_line("Usage: /give <name_fragment> [count]")
		return
	var query   := (parts[1] as String).to_lower()
	var count   := int(parts[2]) if parts.size() >= 3 else 1
	count = maxi(1, count)

	var exact:   Array[int] = []
	var partial: Array[int] = []
	for key in MapObject.Type:
		var val: int = MapObject.Type[key]
		if not PickableItemDef.is_pickable(val):
			continue
		var display := MapObject.get_display_name(val).to_lower()
		if display == query:
			exact.append(val)
		elif display.contains(query):
			partial.append(val)

	# Prefer exact match; fall back to partial only when no exact hit.
	var matches := exact if not exact.is_empty() else partial

	if matches.is_empty():
		_print_line("No pickable item matches '%s'" % query)
		return
	if matches.size() > 1:
		_print_line("%d matches — be more specific:" % matches.size())
		for i in range(mini(5, matches.size())):
			_print_line("  %s" % MapObject.get_display_name(matches[i]))
		if matches.size() > 5:
			_print_line("  … and %d more" % (matches.size() - 5))
		return

	if _avatar == null:
		_print_line("No avatar reference — call setup() first")
		return
	var item_type := matches[0]
	var added     := 0
	for _i in range(count):
		if not _avatar.inventory.add(item_type):
			break
		added += 1
	_print_line("Gave %d× %s" % [added, MapObject.get_display_name(item_type)])


func _cmd_coins(parts: Array) -> void:
	if parts.size() < 2:
		_print_line("Usage: /coins <amount>")
		return
	var amount := maxi(1, int(parts[1] as String))
	if _avatar == null:
		_print_line("No avatar reference")
		return
	var added := 0
	for _i in range(amount):
		if not _avatar.inventory.add(MapObject.Type.COIN):
			break
		added += 1
	_print_line("Added %d coin(s)" % added)


func _cmd_items(parts: Array) -> void:
	var filter := (parts[1] as String).to_lower() if parts.size() > 1 else ""
	var results: Array[String] = []
	for key in MapObject.Type:
		var val: int = MapObject.Type[key]
		if not PickableItemDef.is_pickable(val):
			continue
		var name := MapObject.get_display_name(val)
		if filter.is_empty() or name.to_lower().contains(filter):
			results.append(name)
	if results.is_empty():
		_print_line("No items match '%s'" % filter)
		return
	_print_line("%d item(s)%s:" % [results.size(), (" matching '%s'" % filter) if not filter.is_empty() else ""])
	for i in range(mini(5, results.size())):
		_print_line("  " + results[i])
	if results.size() > 5:
		_print_line("  … and %d more (narrow with /items <filter>)" % (results.size() - 5))


func _cmd_pos() -> void:
	if _avatar == null:
		_print_line("No avatar reference")
		return
	var p := _avatar.position
	_print_line("Position: (%.0f, %.0f)" % [p.x, p.y])


func _cmd_tp(parts: Array) -> void:
	if parts.size() < 3:
		_print_line("Usage: /tp <x> <y>")
		return
	if _avatar == null:
		_print_line("No avatar reference")
		return
	var x := float(parts[1] as String)
	var y := float(parts[2] as String)
	_avatar.position = Vector2(x, y)
	_print_line("Teleported to (%.0f, %.0f)" % [x, y])


func _cmd_day() -> void:
	var dt    := GameClock.get_date_time()
	var new_s := GameClock.to_seconds(dt["year"], dt["month_idx"], dt["day"], 8, 0)
	GameClock.load_time(new_s)
	_print_line("Time → 8:00 AM")


func _cmd_night() -> void:
	var dt    := GameClock.get_date_time()
	var new_s := GameClock.to_seconds(dt["year"], dt["month_idx"], dt["day"], 22, 0)
	GameClock.load_time(new_s)
	_print_line("Time → 10:00 PM")


func _cmd_timescale(parts: Array) -> void:
	if parts.size() < 2:
		_print_line("Current timescale: %.2f  (1 = normal)" % GameClock.time_scale)
		return
	var scale := float(parts[1] as String)
	GameClock.time_scale = maxf(0.0, scale)
	_print_line("Time scale → %.2f×" % GameClock.time_scale)


func _cmd_set_date(parts: Array) -> void:
	if parts.size() < 2:
		_print_line("Usage: /set_date MM/DD")
		return
	var tokens := (parts[1] as String).split("/")
	if tokens.size() != 2:
		_print_line("Usage: /set_date MM/DD")
		return
	var month: int = int(tokens[0])
	var day:   int = int(tokens[1])
	if month < 1 or month > 12 or day < 1 or day > 30:
		_print_line("Invalid: month 1–12, day 1–30")
		return
	var dt    := GameClock.get_date_time()
	var new_s := GameClock.to_seconds(dt["year"], month - 1, day,
				_hour24(dt["hour12"], dt["am_pm"]), dt["minute"])
	GameClock.load_time(new_s)
	_print_line("Date → %d %s, Year %d" % [day, GameClock.MONTH_NAMES[month - 1], dt["year"]])


func _cmd_set_time(parts: Array) -> void:
	if parts.size() < 2:
		_print_line("Usage: /set_time HH:MM")
		return
	var tokens := (parts[1] as String).split(":")
	if tokens.size() != 2:
		_print_line("Usage: /set_time HH:MM")
		return
	var hour:   int = int(tokens[0])
	var minute: int = int(tokens[1])
	if hour < 0 or hour > 23 or minute < 0 or minute > 59:
		_print_line("Invalid: HH 0–23, MM 0–59")
		return
	var dt    := GameClock.get_date_time()
	var new_s := GameClock.to_seconds(dt["year"], dt["month_idx"], dt["day"], hour, minute)
	GameClock.load_time(new_s)
	_print_line("Time → %02d:%02d" % [hour, minute])


func _cmd_perk(parts: Array) -> void:
	if _avatar == null:
		_print_line("No avatar reference")
		return
	if parts.size() == 1:
		# Show all current perks.
		var any := false
		for key in PerkDef.ID:
			var id: PerkDef.ID = PerkDef.ID[key]
			var lv := _avatar.perks.get_level(id)
			var name := PerkDef.get_level_name(id, lv) if lv > 0 else "(none)"
			_print_line("%s: %s (level %d)" % [PerkDef.get_perk_name(id), name, lv])
			any = true
		if not any:
			_print_line("No perks defined yet.")
		return
	# /perk <perk_name> <level>
	if parts.size() < 3:
		_print_line("Usage: /perk <perk_name> <level>  e.g. /perk trader 3")
		return
	var perk_key := (parts[1] as String).to_upper()
	if not PerkDef.ID.has(perk_key):
		_print_line("Unknown perk '%s'.  Known: %s" \
				% [parts[1], ", ".join(PerkDef.ID.keys()).to_lower()])
		return
	var perk_id: PerkDef.ID = PerkDef.ID[perk_key]
	var level := clampi(int(parts[2] as String), 0, PerkDef.get_max_level(perk_id))
	_avatar.perks.set_level(perk_id, level)
	var label := PerkDef.get_level_name(perk_id, level) if level > 0 else "(none)"
	_print_line("%s → %s (level %d)" % [PerkDef.get_perk_name(perk_id), label, level])


func _cmd_name(parts: Array) -> void:
	if _avatar == null:
		_print_line("No avatar reference")
		return
	if parts.size() < 2:
		_print_line("Name: " + (_avatar.char_name if not _avatar.char_name.is_empty() else "(unset)"))
		return
	var new_name := " ".join(parts.slice(1)).strip_edges()
	if new_name.is_empty():
		_print_line("Name cannot be empty")
		return
	_avatar.char_name = new_name
	SaveManager.save_character(_avatar.char_name, _avatar.char_birth_time)
	_print_line("Character renamed to: " + new_name)


func _cmd_stats() -> void:
	if _avatar == null:
		_print_line("No avatar reference")
		return
	var s := _avatar.stats
	_print_line("── Hero Stats ───────────────────────────")
	_print_line("Level  : %d  (XP %d / %d)" % [s.level, s.xp, s.xp_to_next()])
	_print_line("HP     : %d / %d" % [s.current_hp, s.max_hp])
	_print_line("Mana   : %d / %d" % [s.current_mana, s.max_mana])
	_print_line("Attack : %d   Magic: %d   Defense: %d" % [s.attack, s.magic, s.defense])


func _cmd_hp(parts: Array) -> void:
	if _avatar == null:
		_print_line("No avatar reference")
		return
	var s := _avatar.stats
	if parts.size() < 2:
		_print_line("HP: %d / %d" % [s.current_hp, s.max_hp])
		return
	var val := clampi(int(parts[1] as String), 0, s.max_hp)
	s.current_hp = val
	s.changed.emit()
	SaveManager.save_stats(s)
	_print_line("HP set to %d / %d" % [s.current_hp, s.max_hp])


func _cmd_heal(parts: Array) -> void:
	if _avatar == null:
		_print_line("No avatar reference")
		return
	var s      := _avatar.stats
	var before := s.current_hp
	if parts.size() < 2:
		s.heal(s.max_hp)
	else:
		s.heal(maxi(0, int(parts[1] as String)))
	SaveManager.save_stats(s)
	_print_line("Healed %d HP  (%d → %d / %d)" % [s.current_hp - before, before, s.current_hp, s.max_hp])


func _cmd_xp(parts: Array) -> void:
	if parts.size() < 2:
		_print_line("Usage: /xp <amount>")
		return
	if _avatar == null:
		_print_line("No avatar reference")
		return
	var amount := maxi(0, int(parts[1] as String))
	var s      := _avatar.stats
	var before := s.level
	var leveled := s.add_xp(amount)
	SaveManager.save_stats(s)
	if leveled:
		_print_line("Gained %d XP → Level %d → %d!  HP %d/%d" % [amount, before, s.level, s.current_hp, s.max_hp])
	else:
		_print_line("Gained %d XP  (Level %d, %d / %d XP)" % [amount, s.level, s.xp, s.xp_to_next()])


func _cmd_level(parts: Array) -> void:
	if parts.size() < 2:
		_print_line("Usage: /level <n>")
		return
	if _avatar == null:
		_print_line("No avatar reference")
		return
	var target := maxi(1, int(parts[1] as String))
	var s      := _avatar.stats
	# Recompute base stats for the target level from scratch.
	s.level    = target
	s.xp       = 0
	s.max_hp   = 30 + (target - 1) * 3
	s.max_mana = 10 + (target - 1) * 1
	s.current_hp   = s.max_hp
	s.current_mana = s.max_mana
	s.changed.emit()
	SaveManager.save_stats(s)
	_print_line("Level set to %d  (HP %d/%d, Mana %d/%d)" \
			% [s.level, s.current_hp, s.max_hp, s.current_mana, s.max_mana])


func _cmd_stat(parts: Array) -> void:
	if parts.size() < 3:
		_print_line("Usage: /stat <name> <value>")
		_print_line("Names: attack  magic  defense  max_hp  max_mana")
		return
	if _avatar == null:
		_print_line("No avatar reference")
		return
	var s    := _avatar.stats
	var name := (parts[1] as String).to_lower()
	var val  := maxi(0, int(parts[2] as String))
	match name:
		"attack":   s.attack    = val
		"magic":    s.magic     = val
		"defense":  s.defense   = val
		"max_hp":
			s.max_hp   = maxi(1, val)
			s.current_hp = mini(s.current_hp, s.max_hp)
		"max_mana":
			s.max_mana   = maxi(0, val)
			s.current_mana = mini(s.current_mana, s.max_mana)
		_:
			_print_line("Unknown stat '%s'.  Use: attack magic defense max_hp max_mana" % name)
			return
	s.changed.emit()
	SaveManager.save_stats(s)
	_print_line("%s → %d" % [name, val])


func _cmd_monsters() -> void:
	var nodes := get_tree().get_nodes_in_group("monsters")
	if nodes.is_empty():
		_print_line("No active monsters")
		return
	_print_line("%d active monster(s):" % nodes.size())
	for node in nodes:
		var m := node as MonsterNode
		if m == null:
			continue
		_print_line("  %-20s HP %d/%d  id=%s%s" % [
			m.species, m.current_hp, m.max_hp, m.monster_id,
			"  [editor]" if m.is_editor_placed else ""])


func _cmd_killall() -> void:
	var nodes := get_tree().get_nodes_in_group("monsters")
	var count := nodes.size()
	for node in nodes:
		node.queue_free()
	_print_line("Despawned %d monster(s)" % count)


func _cmd_clear_inv() -> void:
	if _avatar == null:
		_print_line("No avatar reference")
		return
	var n := _avatar.inventory.count()
	_avatar.inventory.items.clear()
	_print_line("Cleared %d item(s) from inventory" % n)


# ── Argument parsing ─────────────────────────────────────────────────────────

## Split on spaces, but treat text enclosed in single quotes as one token.
## /give 'Gold Bar' 10  →  ["give", "Gold Bar", "10"]
static func _parse_args(text: String) -> Array[String]:
	var parts: Array[String] = []
	var current              := ""
	var in_quote             := false
	for ch in text:
		if ch == "'":
			in_quote = not in_quote
		elif ch == " " and not in_quote:
			if not current.is_empty():
				parts.append(current)
				current = ""
		else:
			current += ch
	if not current.is_empty():
		parts.append(current)
	return parts


# ── Output ────────────────────────────────────────────────────────────────────

func _print_line(msg: String) -> void:
	_lines.append(msg)
	if _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	_output.text = "\n".join(_lines)


static func _hour24(h12: int, am_pm: String) -> int:
	if am_pm == "AM":
		return 0 if h12 == 12 else h12
	return 12 if h12 == 12 else h12 + 12
