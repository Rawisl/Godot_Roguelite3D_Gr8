class_name WaveGroup
extends Resource

## WaveGroup: Định nghĩa nhóm quân tham gia bốc thăm sinh wave (SRS 3.7.5, v1.4).
## Thuộc quyền quản lý của TV2 (Enemy & Wave).

@export var enemy: EnemyData
@export var weight: float = 10.0
@export var min_wave: int = 1
## Giới hạn số lượng tối đa mỗi wave (-1 là không giới hạn cố định, SRS 3.7.5)
@export var max_per_wave: int = -1
## Số lượng bắt buộc sinh ra khi wave đúng bằng min_wave (SRS 3.7.5 mục 2)
@export var intro_count: int = 0


## ===================================================================
## FUNCTIONS (Thêm ở cuối file theo quy ước nhóm)
## ===================================================================

## Kiểm tra loại quân này đã mở khóa ở wave hiện tại hay chưa
func is_available_at(wave: int) -> bool:
	return wave >= min_wave

## Tính số lượng tối đa được phép sinh ở wave w (hỗ trợ công thức đặc thù như Brute: floor(w/4))
func get_max_allowed(wave: int) -> int:
	if enemy != null and enemy.id == &"brute":
		return maxi(1, int(floor(float(wave) / 4.0)))
	if max_per_wave > 0:
		return max_per_wave
	return 999999
