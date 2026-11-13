class_name SaveRepository
extends RefCounted
## Storage behind SaveManager. Only SaveManager talks to a repository.
##
## A repository stores the whole envelope { "save_version": int, "data": Dictionary, ... }
## as is: it does not fill defaults or check versions, SaveManager does.
## Calls are synchronous. Cloud sync runs on top of SaveManager and always writes
## the local copy first, so callers never wait on the network.
# TODO(Rawisl): when accounts land, add a CloudSaveRepository; SyncService keeps the copy with the higher revision and tells the player.

## The copies a repository may hold: the main save, a leftover temp write, the backup.
enum Source { MAIN, TEMP, BACKUP }

## Error of the last load_data() / load_source() call. ERR_FILE_NOT_FOUND when there is
## nothing stored, ERR_PARSE_ERROR when the stored data is not a valid envelope.
var last_error: Error = OK

func has_data() -> bool:
	return false

## Returns the stored main envelope, or {} when nothing could be read (see last_error).
func load_data() -> Dictionary:
	last_error = ERR_UNAVAILABLE
	return {}

func save_data(_envelope: Dictionary) -> Error:
	return ERR_UNAVAILABLE

## Like load_data() for any copy. A repository with a single copy only has MAIN.
func load_source(source: Source) -> Dictionary:
	if source == Source.MAIN:
		return load_data()
	last_error = ERR_FILE_NOT_FOUND
	return {}

func has_source(source: Source) -> bool:
	return source == Source.MAIN and has_data()

## Makes a leftover temp write the main copy.
func promote_temp() -> Error:
	return ERR_UNAVAILABLE

func discard_temp() -> void:
	pass

## Keeps the broken copies aside (main as .corrupt, temp as .corrupt.tmp, backup as .corrupt.bak).
func quarantine() -> void:
	pass
