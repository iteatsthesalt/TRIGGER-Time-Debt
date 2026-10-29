## Loads and caches portrait textures. Lookup order (docs/ART_PIPELINE.md §6):
##   assets/portraits/<id>/<id>_<expr>.png          (imported PixelLab expression sets)
##   assets/<group>/<id>/<id>_portrait_<expr>.png   (catalog crops kept by the build agent)
## falling back to the neutral expression, then null (the dialogue box hides the frame).
class_name PortraitCache
extends RefCounted

static var _cache: Dictionary = {}
static var _dirs: Array[String] = ["res://assets/characters", "res://assets/npcs", "res://assets/bosses"]
const STUDIO_DIR := "res://assets/portraits"


static func get_portrait(who: String, expression: String = "neutral") -> Texture2D:
	if who == "" or who == "narrator" or who == "system":
		return null
	var key: String = who + "/" + expression
	if _cache.has(key):
		return _cache[key]
	var tex: Texture2D = null
	for expr in [expression, "neutral"]:
		var studio: String = "%s/%s/%s_%s.png" % [STUDIO_DIR, who, who, expr]
		if ResourceLoader.exists(studio):
			tex = load(studio) as Texture2D
			break
	if tex == null:
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
