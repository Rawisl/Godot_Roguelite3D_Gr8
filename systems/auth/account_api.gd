class_name AccountApi
extends RefCounted

var _auth: Node


func _init(auth: Node = null) -> void:
	_auth = auth if auth != null else AuthService


static func data_for_sync(save_data: Dictionary) -> Dictionary:
	var result := {}
	for section in ["profile", "meta", "flags"]:
		var value: Variant = save_data.get(section, {})
		result[section] = value.duplicate(true) if value is Dictionary else {}
	return result


## A missing cloud save is revision 0 with empty data and timestamps.
func pull_save() -> Dictionary:
	if not _auth.is_signed_in():
		return {"ok": false, "error": AuthService.ERR_NOT_SIGNED_IN}
	var owner: String = _auth.user_id
	var response: Dictionary = await _auth.rest(HTTPClient.METHOD_GET,
			"/rest/v1/saves?user_id=eq.%s&select=revision,device_id,updated_at,data" % owner.uri_encode())
	if not response["ok"]:
		return response
	if owner != _auth.user_id or not _auth.is_signed_in():
		return {"ok": false, "error": AuthService.ERR_NOT_SIGNED_IN}
	if not response.get("data") is Array:
		return {"ok": false, "error": AuthService.ERR_SERVER}
	if response["data"].is_empty():
		return {"ok": true, "revision": 0, "device_id": "", "updated_at": "", "data": {}}
	if response["data"].size() != 1 or not _valid_save_row(response["data"][0]):
		return {"ok": false, "error": AuthService.ERR_SERVER}
	var row: Dictionary = response["data"][0]
	return {"ok": true, "revision": int(row["revision"]), "device_id": row["device_id"] if row["device_id"] != null else "",
		"updated_at": row["updated_at"], "data": row["data"]}


## The caller supplies the next local revision; conflicts never overwrite cloud data.
func push_save(revision: int, device_id: String, data: Dictionary) -> Dictionary:
	if not _auth.is_signed_in():
		return {"ok": false, "conflict": false, "error": AuthService.ERR_NOT_SIGNED_IN}
	var owner: String = _auth.user_id
	var payload := {"revision": revision, "device_id": device_id, "data": data_for_sync(data)}
	var response: Dictionary = await _auth.rest(HTTPClient.METHOD_PATCH,
			"/rest/v1/saves?user_id=eq.%s" % owner.uri_encode(), payload, true, "return=representation")
	if response["ok"] and not response.get("data") is Array:
		return {"ok": false, "conflict": false, "error": AuthService.ERR_SERVER}
	if owner == _auth.user_id and response["ok"] and response["data"].is_empty():
		payload["user_id"] = owner
		response = await _auth.rest(HTTPClient.METHOD_POST, "/rest/v1/saves", payload, true, "return=representation")
	if owner != _auth.user_id or not _auth.is_signed_in():
		return {"ok": false, "conflict": false, "error": AuthService.ERR_NOT_SIGNED_IN}
	if not response["ok"]:
		var detail: Dictionary = response["data"] if response.get("data") is Dictionary else {}
		return {"ok": false, "conflict": detail.get("code", "") in ["PT409", "23505"],
			"revision": revision, "error": response.get("error", AuthService.ERR_SERVER)}
	if not response.get("data") is Array or response["data"].is_empty():
		return {"ok": false, "conflict": false, "error": AuthService.ERR_SERVER}
	if not response["data"][0] is Dictionary or not _valid_revision(response["data"][0].get("revision")):
		return {"ok": false, "conflict": false, "error": AuthService.ERR_SERVER}
	return {"ok": true, "conflict": false, "revision": int(response["data"][0]["revision"])}


static func _valid_revision(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
			and value >= 0 and value <= 2147483647 and float(value) == floor(float(value))


static func _valid_save_row(value: Variant) -> bool:
	return value is Dictionary and value.has_all(["revision", "device_id", "updated_at", "data"]) \
			and _valid_revision(value.get("revision")) \
			and (value.get("device_id") == null or value["device_id"] is String) \
			and value.get("updated_at") is String and value.get("data") is Dictionary
