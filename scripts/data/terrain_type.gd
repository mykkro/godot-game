class_name TerrainType

## Thin wrapper kept for call-site compatibility during the refactor.
## Terrain is now identified by filename string; TileRegistry is authoritative.

static func is_passable(filename: String) -> bool:
	return TileRegistry.is_passable(filename)


static func blocks_projectile(_filename: String) -> bool:
	return false
