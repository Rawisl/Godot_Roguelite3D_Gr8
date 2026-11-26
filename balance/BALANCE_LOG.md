# Nhật ký cân bằng

Mỗi lần đổi tham số cân bằng ghi một mục: ngày, tham số (file, giá trị cũ -> mới), lý do, số liệu dùng để quyết.
Số liệu quân, kịch bản wave và thưởng theo wave sửa trong `balance.xlsx` rồi chạy `tools/balance/generate.py`;
`GameConfig`, `ScaleConfig`, `WaveTable`, `BossData` sửa tay (xem `tools/balance/README.md`).

Công cụ đo: bot tự chơi `tests/wave_bot.tscn` (chạy hàng loạt bằng `tests/run_wave_bot.ps1`, tóm tắt bằng
`tests/wave_bot_report.py`).

---

## 2026-11-24: lần 1, XP chỉ huy (Kiệt)

### Mục tiêu
- Người chơi chủ động (đánh ở Frontline) đạt cấp 4 ở wave 4 ± 1 và cấp 8 ở wave 8 ± 1.
- Chiến lược AFK (đứng Commander, để tower giết): ở wave 12 cấp chỉ huy ≤ 0.65 × cấp của người chơi Frontline
  cùng seed, nên không mở được bậc tower 3 (cần cấp 8) sớm như người chơi chủ động.

### Số liệu trước khi đổi
- Mô hình theo kịch bản wave hiện tại (XP gốc của quân × xp_mult của wave; cần 5 + 4 × (n − 1) XP cho cấp n):

| xp_commander_pct / xp_tower_only_pct | Frontline (70% kill có chỉ huy) cấp ở wave 4 / 8 / 12 | AFK cấp ở wave 12 | Tỉ lệ AFK / Frontline |
| --- | --- | --- | --- |
| 1.0 / 0.5 (cũ) | 3 / 7 / 11 | 8 | 0.73 |
| 1.25 / 0.4 (mới) | 4 / 8 / 11 | 7 | 0.64 |

- Bot soak AFK (3 seed, 20 wave): cấp 8 ở wave 12, cấp 13 ở wave 20.
- Bot soak Frontline có skill (2 seed, 20 wave): cấp 3 / 7 / 10 ở wave 4 / 8 / 12. Tỉ lệ AFK / Frontline ở wave 12 = 0.80.

### Thay đổi
| Tham số | File | Cũ | Mới |
| --- | --- | --- | --- |
| `xp_commander_pct` | `autoload/game_config.gd` | 1.0 | 1.25 |
| `xp_tower_only_pct` | `autoload/game_config.gd` | 0.5 | 0.4 |

### Số liệu sau khi đổi
Bot soak, 2 seed mỗi chế độ, wave 1-12 ở x3:

| Chế độ | Cấp ở wave 4 / 8 / 12 | Tower cao nhất ở wave 12 |
| --- | --- | --- |
| Frontline (có skill) | 3 / 7 / 11 | 36 (soak đủ gold) |
| AFK | 2 / 4 / 7 | 24 (dừng ở cổng bậc 3, cần cấp 8) |

Tỉ lệ AFK / Frontline ở wave 12 = 7 / 11 = 0.64 (giới hạn 0.65). Frontline đạt mục tiêu cấp 4 ± 1 ở wave 4 và
8 ± 1 ở wave 8 (ở mép dưới: bot giết bằng chỉ huy ít hơn người chơi thật).

### Chưa đổi, cần xem tiếp
- Cả bot AFK lẫn bot Frontline (không soak) đều thua ở wave 5: Bulwark phá Fortress khi chỉ có 2 trụ có sẵn và khoảng
  50-85 gold mỗi wave. Mục tiêu là người mới thua ở wave 8-12. Bot còn thô (không né, không đánh boss tốt) nên chưa đủ để
  kết luận; cần một lượt chơi tay ở wave 5 trước khi giảm máu Bulwark hay tăng gold đầu game. Để lại cho kịch bản wave
  (W11-MH11) và lần cân bằng sau.
- Cổng bậc tower (cấp 4 cho bậc 2, cấp 8 cho bậc 3), Aura (+20%, 12 m) và gold chỉ huy (×1.25) giữ nguyên: chưa có số liệu
  bot qua được wave 5 để đo ảnh hưởng.
