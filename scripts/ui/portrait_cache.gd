## Loads and caches portrait textures: assets/characters/<id>/<id>_portrait_<expr>.png (or neutral).
class_name PortraitCache
extends RefCounted

static var _cache: Dictionary = {}
static var _dirs: Array[String] = ["res://assets/characters", "res://assets/npcs", "res://assets/bosses"]


static func get_portrait(who: String, expression: String = "neutral") -> Texture2D:
	if who == "" or who == "narrator" or who == "system":
		return null
	var key: String = who + "/" + expression
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	for dir in _dirs:
		for expr in [expression, "neutral"]:
			var path: String = "%s/%s/%s_portrait_%s.png" % [dir, who, who, expr]
			if ResourceLoader.exists(path):
				tex = load(path) as Texture2D
				break
		if tex != null:
			break
	_cache[key] = tex
	return tex
