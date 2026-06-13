class_name FortuneLoader

## Scans res://fortunes/ for all .xml files and loads short-to-mid quotes.
## Call FortuneLoader.get_random() anywhere to get a fortune.

const FORTUNES_DIR := "res://fortunes/"
const MAX_LEN      := 350   # skip very long multi-paragraph quotes

static var _quotes: Array[String] = []
static var _loaded: bool           = false


static func get_random() -> String:
	if not _loaded:
		_load_all()
	if _quotes.is_empty():
		return "The wise remain silent."
	return _quotes[randi() % _quotes.size()]


static func _load_all() -> void:
	_loaded = true
	var dir := DirAccess.open(FORTUNES_DIR)
	if dir == null:
		push_warning("FortuneLoader: cannot open %s" % FORTUNES_DIR)
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".xml"):
			_load_file(FORTUNES_DIR + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	print("FortuneLoader: %d quotes loaded from %s (≤ %d chars)" \
			% [_quotes.size(), FORTUNES_DIR, MAX_LEN])


static func _load_file(path: String) -> void:
	var parser := XMLParser.new()
	if parser.open(path) != OK:
		push_warning("FortuneLoader: cannot parse %s" % path)
		return

	var in_text := false
	var buf     := ""

	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				if parser.get_node_name() == "text":
					in_text = true
					buf     = ""
			XMLParser.NODE_ELEMENT_END:
				if parser.get_node_name() == "text":
					in_text = false
					var t := buf.strip_edges().replace("\t", "  ")
					if t.length() > 0 and t.length() <= MAX_LEN:
						_quotes.append(t)
			XMLParser.NODE_TEXT:
				if in_text:
					buf += parser.get_node_data()
