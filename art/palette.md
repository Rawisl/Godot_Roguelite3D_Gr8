# Palette – Endless War

Bộ màu dùng chung cho map, nhân vật, VFX và UI. **Bản nháp**: các màu môi trường cần hút lại từ asset thật (craftpix low poly, KayKit) rồi cập nhật mã hex.

Nguyên tắc:
- Nền nhạt, ít bão hòa; nhân vật và công trình nổi hơn nền. Kiểm tra: chụp màn hình, chuyển đen trắng vẫn phân biệt được.
- **Đỏ cảnh báo chỉ dùng cho telegraph và nguy hiểm** (FBK-06). Không dùng cho trang trí.
- Thông tin quan trọng luôn có kênh thứ hai ngoài màu: họa tiết, icon, chữ (UI-05, ACC-01).
- Không nhấp nháy quá 3 lần/giây (ACC-06).

## Môi trường

| Tên | Hex | Dùng cho |
|---|---|---|
| env_grass | `#7FA05A` | Sàn cỏ hành lang |
| env_grass_dark | `#5E7F44` | Cỏ tối, bụi cây |
| env_stone | `#9A9A8E` | Đá, tường hành lang |
| env_stone_dark | `#6B6B62` | Bóng đá, nền tường |
| env_wood | `#8A6A45` | Gỗ, tower thô |
| env_dirt | `#A88D63` | Đường đất, làn đi |

## Phe ta và phe địch

| Tên | Hex | Dùng cho |
|---|---|---|
| ally_primary | `#3F7FD0` | Chỉ huy, viền tower, cờ Fortress |
| ally_accent | `#E8C25A` | Điểm nhấn phe ta |
| enemy_primary | `#7A4FA0` | Viền, aura quân địch |
| enemy_boss | `#B0402E` | Điểm nhấn boss (không trùng telegraph) |

## Tín hiệu gameplay

| Tên | Hex | Dùng cho |
|---|---|---|
| danger | `#FF2D2D` | Telegraph Stomp, Shell, Overload (vòng đỏ viền đậm + họa tiết) |
| danger_fill | `#FF2D2D` 35% alpha | Phần nền bên trong telegraph |
| safe_zone | `#4FE0C0` | Retreat Zone, ReturnZone |
| build_ring | `#FFFFFF` 60% alpha | Vòng build slot ở PREP |
| ruined | `#4A4038` | Đống đổ nát |
| gold | `#FFC83D` | Gold, phần thưởng |

## Số nổi (FBK-01)

| Tên | Hex | Dùng cho |
|---|---|---|
| dmg_normal | `#FFFFFF` | Sát thương thường |
| dmg_resist | `#A0A0A0` | RESIST, IMMUNE |
| dmg_player | `#FF4A4A` | Chỉ huy nhận sát thương |
| heal | `#5BE37A` | Hồi máu |

## UI

| Tên | Hex | Dùng cho |
|---|---|---|
| ui_bg | `#1C1F26` | Nền panel |
| ui_bg_alt | `#2A2F3A` | Nền phụ, ô |
| ui_text | `#F2EFE6` | Chữ chính |
| ui_text_dim | `#A9A79F` | Chữ phụ, disabled |
| ui_accent | `#E8C25A` | Nút chính, focus |
| ui_alert_t1 | `#FF2D2D` | Cảnh báo T1 |
| ui_alert_t2 | `#FF9A2E` | Cảnh báo T2 |
| ui_alert_t3 | `#E8E05A` | Cảnh báo T3 |

## Việc còn lại

- [ ] Hút màu môi trường từ asset thật, cập nhật bảng trên
- [ ] Kiểm tra bằng ảnh đen trắng và công cụ giả lập mù màu
- [ ] Đưa màu UI vào `ui/theme/` cho TV4
