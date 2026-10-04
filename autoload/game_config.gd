extends Node

## GameConfig: Autoload quản lý tham số toàn cục của game (SRS 6.1, 6.2, v1.4).
## Thuộc quyền quản lý của TV2 (Enemy & Wave).

# -----------------------------------------------------------------------------
# 1. RUN & WAVE
# -----------------------------------------------------------------------------
@export_group("Run & Wave")
## Thời gian PREP wave 1-3 (giây)
@export var prep_time_early: float = 25.0
## Thời gian PREP từ wave 4 trở đi (giây)
@export var prep_time_normal: float = 30.0
## Thời gian PREP wave boss (giây)
@export var prep_time_boss: float = 45.0

## Số lượng quân sống tối đa cùng lúc trên map (SRS 3.2.3, 3.7.6)
@export var max_alive: int = 70
## Số lượng projectile tối đa trong object pool (SRS PRJ-04, 6.1)
@export var max_projectiles: int = 200

## Vàng thưởng cho mỗi giây PREP còn lại khi gọi wave sớm (SRS 3.3.2)
@export var early_call_gold_per_sec: int = 2
## Trần vàng tối đa nhận được khi gọi wave sớm (SRS 3.3.2, WAVE-07)
@export var early_call_cap: int = 40

## Thời gian tự chuyển từ SUMMARY sang PREP tiếp theo (giây thời gian thực, SRS 3.3.4)
@export var summary_duration: float = 10.0

## Vàng khởi điểm mặc định của run (MVP, SRS FLOW-06, GLD-06)
@export var starting_gold: int = 150
## Hệ số xuất phát mặc định ở wave 1 (SRS 3.2.1)
@export var start_mult: float = 1.0


# -----------------------------------------------------------------------------
# 2. KINH TẾ & SỬA CHỮA (ECONOMY & REPAIR)
# -----------------------------------------------------------------------------
@export_group("Economy & Repair")
## Tỷ lệ quy đổi Uy tín sang Danh vọng khi kết thúc run (30%, SRS 3.2.4, 3.9.2)
@export var conversion_rate: float = 0.30
## Tỷ lệ hoàn tiền khi bán tower (60% tổng vốn đầu tư, SRS 3.6.4, SELL-01)
@export var sell_refund_pct: float = 0.60
## Chi phí sửa thành: số gold cho mỗi 1% max_hp thiếu (SRS 3.6.1, REP-01, GLD-07)
@export var repair_gold_per_pct: int = 4


# -----------------------------------------------------------------------------
# 3. EMERGENCY REPAIR (SRS 3.5.4, 6.2, APL-04)
# -----------------------------------------------------------------------------
@export_group("Emergency Repair")
## Số lượt Emergency repair tối đa và khởi đầu trong một run (hằng số, SRS APL-04)
@export var emg_repair_charges_max: int = 3
## Cooldown Emergency repair (60s game time, hằng số, SRS APL-04, CMD-02)
@export var emergency_repair_cooldown: float = 60.0
## % hồi máu cơ bản của Emergency repair (20% max_hp)
@export var emg_repair_heal_pct_base: float = 0.20
## % hồi máu cộng thêm mỗi cấp meta EMG_REPAIR (+3% mỗi cấp, tối đa 29%)
@export var emg_repair_heal_pct_per_level: float = 0.03


# -----------------------------------------------------------------------------
# 4. CHỐNG KẸT & ĐIỀU HƯỚNG (NAV ANTI-STUCK - SRS 3.7.4, 6.2)
# -----------------------------------------------------------------------------
@export_group("Anti-Stuck & Navigation")
## Thời gian phát hiện quân kẹt khi tiến độ dưới stuck_progress_min (3.0s, NAV-01)
@export var stuck_detect_time: float = 3.0
## Quãng đường nav tối thiểu phải tiến được trong stuck_detect_time (0.5m, NAV-01)
@export var stuck_progress_min: float = 0.5
## Số lần recycle tối đa cho mỗi quân trước khi bị cull (2 lần, NAV-08, NAV-09)
@export var recycle_max: int = 2
## Bán kính hop cục bộ bậc 2 (3.0m, [Should], NAV-07)
@export var hop_radius: float = 3.0
## Quãng đường tối đa được phép tiến gần Fortress khi hop (4.0m, [Should], NAV-07)
@export var hop_max_advance: float = 4.0
## Giới hạn cứng: sau 300s kể từ lần spawn cuối, cull mọi quân thường và kết thúc wave (NAV-13)
@export var wave_hard_cap: float = 300.0
## Thời gian watchdog kiểm tra bế tắc toàn wave (45s, [Should], NAV-11)
@export var wave_stall_timeout: float = 45.0
## Thời gian không gây được sát thương để loại mục tiêu (10s, [Should], NAV-10)
@export var no_damage_timeout: float = 10.0

## Thời gian phát hiện boss kẹt (5.0s, BOSS-04)
@export var boss_stuck_time: float = 5.0
## Bán kính hop của boss (6.0m, BOSS-04)
@export var boss_hop_radius: float = 6.0


# -----------------------------------------------------------------------------
# 5. BOSS & OVERLOAD (SRS 3.8.5, 6.2)
# -----------------------------------------------------------------------------
@export_group("Boss & Overload")
## Thời gian boss_timer khởi điểm (90s, wave 5)
@export var boss_timer_base: float = 90.0
## Trần tối đa của boss_timer (120s, BTM-03, BOSS-25)
@export var boss_timer_max: float = 120.0
## Thời lượng cutscene BOSS_INTRO (4.0s, BOSS-17)
@export var boss_intro_duration: float = 4.0
## Khung thời gian mở Retreat trước khi hết giờ (15s cuối, RET-01)
@export var boss_retreat_window: float = 15.0
## Khung thời gian khóa tốc độ về x1 trước khi hết giờ (20s cuối, TIME-03, ALR-06)
@export var boss_lock_x1_window: float = 20.0


## ===================================================================
## FUNCTIONS (Thêm ở cuối file theo quy ước nhóm)
## ===================================================================

## Lấy thời gian chuẩn bị (PREP) theo wave và trạng thái boss (SRS 3.3.2)
func get_prep_time(wave: int, is_boss: bool) -> float:
	if is_boss:
		return prep_time_boss
	if wave <= 3:
		return prep_time_early
	return prep_time_normal

## Tính thời gian tiêu chuẩn par_time cho wave (SRS 3.3.3, BRW-04)
## Wave thường: spawn_duration + 15s. Wave boss: 0.6 * boss_timer.
func get_par_time(spawn_duration: float, is_boss: bool, boss_timer: float = 90.0) -> float:
	if is_boss:
		return 0.6 * boss_timer
	return spawn_duration + 15.0

## Tính hệ số thưởng clear_mult theo clear_time và par_time (SRS 3.3.3)
## Fast (<= 0.7 * par): 1.25 | Normal (<= 1.3 * par): 1.00 | Slow: 0.80
func get_clear_mult(clear_time: float, par_time: float) -> float:
	if par_time <= 0.0:
		return 1.0
	if clear_time <= 0.7 * par_time:
		return 1.25
	elif clear_time <= 1.3 * par_time:
		return 1.00
	else:
		return 0.80

## Tính boss_timer theo thứ tự boss n = wave / 5 (SRS 3.8.5)
## boss_timer = min(120, 90 + 3(n-1))
func get_boss_timer(n: int) -> float:
	var boss_idx: int = maxi(1, n)
	return minf(boss_timer_max, boss_timer_base + 3.0 * float(boss_idx - 1))

## Tính % máu Fortress bị mất khi boss Overload: y% = min(60, 30 + 5n)% (SRS 3.8.5)
func get_overload_fortress_pct(n: int) -> float:
	var boss_idx: int = maxi(1, n)
	return minf(0.60, 0.30 + 0.05 * float(boss_idx))
