class_name WaveTable
extends Resource

## WaveTable: Bảng cấu hình danh sách quái và quy luật sinh wave (SRS 3.7.5, v1.4).
## Thuộc quyền quản lý của TV2 (Enemy & Wave).

@export var groups: Array[WaveGroup] = []
## Chu kỳ xuất hiện wave boss (mỗi 5 wave: wave 5, 10, 15... SRS 3.8.10)
@export var boss_every: int = 5


## ===================================================================
## FUNCTIONS (Thêm ở cuối file theo quy ước nhóm)
## ===================================================================

## Kiểm tra wave có phải là wave boss hay không (w % boss_every == 0)
func is_boss_wave(wave: int) -> bool:
	return (wave > 0) and (wave % boss_every == 0)

## Lấy thứ tự boss n = wave / 5 (ví dụ: wave 5 -> n=1, wave 10 -> n=2)
func get_boss_index(wave: int) -> int:
	if not is_boss_wave(wave):
		return 0
	return wave / boss_every

## Lọc các nhóm quân hợp lệ xuất hiện ở wave hiện tại (wave >= min_wave)
func get_available_groups(wave: int) -> Array[WaveGroup]:
	var result: Array[WaveGroup] = []
	for g in groups:
		if g != null and g.is_available_at(wave):
			result.append(g)
	return result

## Lấy danh sách quân bắt buộc phải xuất hiện lần đầu (intro_count khi wave == min_wave, SRS 3.7.5)
func get_intro_spawns(wave: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for g in groups:
		if g != null and g.enemy != null and g.min_wave == wave and g.intro_count > 0:
			result.append({
				"enemy": g.enemy,
				"count": g.intro_count
			})
	return result
