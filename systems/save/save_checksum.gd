class_name SaveChecksum
extends RefCounted
## Detects a damaged save file. Not an anti-cheat measure.
##
## JSON reads every number back as float ("5" becomes "5.0"), so the text is put through
## one JSON round trip with sorted keys before hashing; the save side and the load side
## then hash the same string.

const PREFIX := "sha256:"

## Checksum of one "data" dictionary, PREFIX followed by the hex digest.
static func compute(data: Dictionary) -> String:
	var canonical := JSON.stringify(JSON.parse_string(JSON.stringify(data, "", true)), "", true)
	return PREFIX + canonical.sha256_text()

## True when the envelope's checksum matches its data. An envelope without a checksum
## (written before checksums existed) counts as matching; the caller decides whether to warn.
static func matches(envelope: Dictionary) -> bool:
	if not envelope.has("checksum"):
		return true
	var stored: Variant = envelope["checksum"]
	var data: Variant = envelope.get("data")
	if not stored is String or not data is Dictionary:
		return false
	return stored == compute(data)
