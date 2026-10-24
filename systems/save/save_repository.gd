class_name SaveRepository
extends RefCounted
## Storage behind SaveManager. Only SaveManager talks to a repository.
##
## A repository stores the whole envelope { "save_version": int, "data": Dictionary, ... }
## as is: it does not fill defaults or check versions, SaveManager does.
## Calls are synchronous. Cloud sync runs on top of SaveManager and always writes
## the local copy first, so callers never wait on the network.
##
## TODO(week 11): CloudSaveRepository for accounts; SyncService keeps the copy with the
## higher revision and tells the player.

## Error of the last load_data() call. ERR_FILE_NOT_FOUND when there is nothing stored,
## ERR_PARSE_ERROR when the stored data is not a valid envelope.
var last_error: Error = OK

func has_data() -> bool:
	return false

## Returns the stored envelope, or {} when nothing could be read (see last_error).
func load_data() -> Dictionary:
	last_error = ERR_UNAVAILABLE
	return {}

func save_data(_envelope: Dictionary) -> Error:
	return ERR_UNAVAILABLE
