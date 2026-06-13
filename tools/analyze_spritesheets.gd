@tool
extends EditorScript

## Spritesheet grid analyser.
##
## Run via:  Script ▸ Run  (Ctrl+Shift+X) in the Godot editor.
##
## For each registered spritesheet, detects where the content-gap boundaries
## fall (using OR-collapse across rows/columns), then writes a _grid.json
## sidecar next to the PNG.  TextureCache loads these sidecars at runtime so
## no pixel analysis is needed during play.
##
## To add a new spritesheet, append an entry to SHEETS below and re-run.

## path → [cols, rows]
const SHEETS := {
	"res://media/rockz/rockz.png":  [4, 5],
	"res://media/rockz/rockz2.png": [4, 5],
}

const MIN_GAP := 4        # minimum gap width (px) to count as a separator
const BG_SUM  := 720      # r+g+b threshold: above = near-white background
const BG_ALPHA := 20      # alpha threshold: below = transparent background


func _run() -> void:
	for path: String in SHEETS:
		var cfg    := SHEETS[path] as Array
		var cols   := int(cfg[0])
		var rows   := int(cfg[1])
		print("Analysing  %s  (%d cols × %d rows)…" % [path, cols, rows])

		var img := _load_image(path)
		if img == null:
			push_error("  ✗  Cannot load image — skipped.")
			continue

		var xc := _find_cuts(img, cols, true)
		var yc := _find_cuts(img, rows, false)

		if xc.size() < cols - 1 or yc.size() < rows - 1:
			push_error("  ✗  Detected only %d x-cuts and %d y-cuts (need %d / %d) — skipped." \
					% [xc.size(), yc.size(), cols - 1, rows - 1])
			continue

		var json_path := path.get_basename() + "_grid.json"
		var text      := JSON.stringify({
			"cols":   cols,
			"rows":   rows,
			"x_cuts": xc,
			"y_cuts": yc,
		}, "\t")
		var fw := FileAccess.open(json_path, FileAccess.WRITE)
		if fw == null:
			push_error("  ✗  Cannot write %s (err %d)" % [json_path, FileAccess.get_open_error()])
			continue
		fw.store_string(text)
		fw.close()
		print("  ✓  %s" % json_path)
		print("       x_cuts = ", xc)
		print("       y_cuts = ", yc)

	print("Done — reimport the project if new .json files were created.")


func _load_image(path: String) -> Image:
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


## Returns `count - 1` cut positions (pixel coords) dividing `count` cells.
## x_axis=true  → collapses rows to find vertical cuts between columns.
## x_axis=false → collapses columns to find horizontal cuts between rows.
func _find_cuts(img: Image, count: int, x_axis: bool) -> Array[float]:
	var W    := img.get_width()
	var H    := img.get_height()
	var dim  := W if x_axis else H
	var data := img.get_data()

	# OR-collapse: mark each slice as "has content".
	var profile := PackedByteArray()
	profile.resize(dim)
	profile.fill(0)
	for y in range(H):
		var rb := y * W * 4
		for x in range(W):
			var target := x if x_axis else y
			if profile[target] == 1:
				continue
			var i := rb + x * 4
			if int(data[i + 3]) > BG_ALPHA and \
					(int(data[i]) + int(data[i + 1]) + int(data[i + 2])) < BG_SUM:
				profile[target] = 1

	# Collect gap runs (profile == 0).
	var gaps: Array[Dictionary] = []
	var gs := -1
	for i in range(dim):
		if profile[i] == 0:
			if gs < 0:
				gs = i
		else:
			if gs >= 0:
				gaps.append({"s": gs, "e": i - 1})
				gs = -1
	if gs >= 0:
		gaps.append({"s": gs, "e": dim - 1})

	# Keep internal gaps wide enough to be real separators.
	var internal: Array[Dictionary] = []
	for g in gaps:
		if g["s"] > 0 and g["e"] < dim - 1 and (g["e"] - g["s"] + 1) >= MIN_GAP:
			internal.append(g)

	var need := count - 1
	if internal.size() < need:
		print("    [warn] only %d internal gaps found (need %d); using uniform fallback" \
				% [internal.size(), need])
		var cuts: Array[float] = []
		for k in range(need):
			cuts.append(float(dim) * float(k + 1) / float(count))
		return cuts

	# Take the `need` widest gaps and sort by position.
	internal.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["e"] - a["s"]) > (b["e"] - b["s"]))
	var selected := internal.slice(0, need)
	selected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["s"]) < int(b["s"]))

	var cuts: Array[float] = []
	for g in selected:
		cuts.append((float(g["s"]) + float(g["e"])) * 0.5)
	return cuts
