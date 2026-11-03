## The scratch directory of a suspended run (Saves.suspended: the probes, the test runner, captures, debug starts):
## one per process, user://scratch/<pid>, so two runs on one machine (two worktrees, the build lead beside the
## studio assistant) never read or overwrite each other's autosave or settings. The first use empties it (a
## process id can come round again), the run's end removes it (Saves._exit_tree), and a directory a killed run
## left behind is pruned once nothing in it has changed for STALE_S.
class_name ScratchDir
extends RefCounted

const STALE_S := 7 * 86400


## `root`/<pid>, empty and ready for this run; the stale directories of runs long gone are pruned first.
static func claim(root: String, pid: int) -> String:
	var path: String = root.path_join(str(pid))
	prune_stale(root, path)
	remove(path)
	DirAccess.make_dir_recursive_absolute(path)
	return path


## Delete `path` and everything under it; nothing happens when it does not exist.
static func remove(path: String) -> void:
	var da := DirAccess.open(path)
	if da == null:
		return
	da.include_hidden = true
	for f in da.get_files():
		DirAccess.remove_absolute(path.path_join(f))
	for d in da.get_directories():
		remove(path.path_join(d))
	DirAccess.remove_absolute(path)


## The latest modification time (Unix seconds) of any file under `path`; 0 when it holds no file.
static func newest(path: String) -> int:
	var da := DirAccess.open(path)
	if da == null:
		return 0
	da.include_hidden = true
	var out: int = 0
	for f in da.get_files():
		out = maxi(out, FileAccess.get_modified_time(path.path_join(f)))
	for d in da.get_directories():
		out = maxi(out, newest(path.path_join(d)))
	return out


## Remove the per-process directories under `root` (named by a process id), `keep` aside, in which nothing has
## changed for STALE_S. Anything else there (the flat saves/ of older builds, which may still be running) stays.
static func prune_stale(root: String, keep: String) -> void:
	var da := DirAccess.open(root)
	if da == null:
		return
	var now: int = int(Time.get_unix_time_from_system())
	for d in da.get_directories():
		var p: String = root.path_join(d)
		if d.is_valid_int() and p != keep and now - newest(p) > STALE_S:
			remove(p)
