# Palette – Endless War

Bộ màu dùng chung cho map, nhân vật, VFX và UI. Màu môi trường, công trình và nhân vật hút từ texture thật trong `contents/assets/` (KayKit, gói fortress và tower, gói bush và stone). Màu hiển thị trong game còn chịu ảnh hưởng của `art/shaders/toon.gdshader` và ánh sáng trong `levels/corridor/level.tscn`.

Nguyên tắc:
- Nền nhạt, ít bão hòa; nhân vật và công trình nổi hơn nền. Kiểm tra: chụp màn hình, chuyển đen trắng vẫn phân biệt được.
- **Đỏ cảnh báo chỉ dùng cho telegraph và nguy hiểm** (FBK-06). Không dùng cho trang trí.
- Thông tin quan trọng luôn có kênh thứ hai ngoài màu: họa tiết, icon, chữ (UI-05, ACC-01).
- Không nhấp nháy quá 3 lần/giây (ACC-06).

## Môi trường

| Tên | Hex | Dùng cho | Nguồn |
|---|---|---|---|
| env_grass | `#7FA05A` | Sàn cỏ hành lang | Chọn tay, nhạt hơn cỏ asset để làm nền |
| env_grass_dark | `#2B6020` | Bụi cây, cỏ trang trí | `T_Grass.png`, `T_Bush_temp_climate.png` |
| env_bark | `#602B0B` | Thân bụi cây | `T_Bush_temp_climate.png` |
| env_rock | `#757575` | Đá trang trí | `T_Stone.png` |
| env_dirt | `#A88D63` | Đường đất, làn đi | Chọn tay, cùng tông với struct_stone |

## Công trình (Fortress, tower, barricade)

Hai texture `Texture_MAp_ELfs.png` (fortress) và `Texture_MAp_fortress_elves.png` (tower) dùng chung bộ màu.

| Tên | Hex | Dùng cho |
|---|---|---|
| struct_stone_light | `#FFEAD5` | Thân tường, thân tháp (mảng sáng nhất) |
| struct_stone | `#BF9F75` | Đá ốp, chân tường |
| struct_stone_dark | `#6A604A` | Mạch đá, bóng tường |
| struct_slate | `#6A6A80` | Đá xám xanh, viền mái |
| struct_gray | `#959595` | Đá xám, kim loại |
| struct_wood | `#95806A` | Cửa gỗ, khung |
| struct_roof | `#607555` | Mái xanh |
| struct_roof_dark | `#4A6040` | Mái xanh tối, sọc trang trí |
| struct_trim | `#0B0B0B` | Ô cửa, khe tối |

## Nhân vật

| Tên | Hex | Dùng cho | Nguồn |
|---|---|---|---|
| ally_steel | `#AAB5BF` | Giáp chỉ huy | `knight_texture.png` |
| ally_steel_dark | `#556060` | Giáp tối, mũ | `knight_texture.png` |
| ally_cape | `#CC2929` | Áo choàng chỉ huy | `knight_texture.png` ⚠️ xem mục Xung đột |
| ally_trim | `#CC9629` | Viền vàng giáp, chuôi kiếm | `knight_texture.png` |
| enemy_bone | `#F4F4F4` | Xương skeleton | `skeleton_texture_A/B.png` |
| enemy_cloth | `#991F47` | Mũ trùm, khăn, áo choàng quân địch | `skeleton_texture_A/B.png` |
| enemy_cloth_dark | `#66293D` | Vải tối | `skeleton_texture_A/B.png` |
| enemy_leather | `#995C3D` | Đai, bao tay da | `skeleton_texture_A/B.png` |
| enemy_glow_a | `#99FFDD` | Mắt phát sáng, texture A (boss) | `skeleton_texture_A.png` |
| enemy_glow_b | `#FFBB33` | Mắt phát sáng, texture B (quân thường) | `skeleton_texture_B.png` |

## Phe ta và phe địch (UI, viền, aura)

Không trùng màu với model để vòng chọn, thanh máu, aura luôn tách khỏi nhân vật.

| Tên | Hex | Dùng cho |
|---|---|---|
| ally_primary | `#3F7FD0` | Vòng chọn chỉ huy, thanh máu phe ta, cờ Fortress |
| ally_accent | `#E8C25A` | Điểm nhấn phe ta |
| enemy_primary | `#7A4FA0` | Viền, aura, thanh máu quân địch |
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

## Xung đột cần nhóm quyết

- **Áo choàng chỉ huy đỏ** (`ally_cape #CC2929`) gần với `danger #FF2D2D`, trái nguyên tắc "đỏ chỉ dùng cho telegraph". Hướng xử lý: đổi texture áo choàng sang xanh `ally_primary`, hoặc chấp nhận vì telegraph luôn có viền đậm và họa tiết (FBK-06).
- **Mắt quân thường vàng** (`enemy_glow_b #FFBB33`) gần với `gold #FFC83D`. Mắt rất nhỏ trên màn hình nên ít khả năng gây nhầm, chỉ cần để ý khi làm VFX rơi gold.
- **Vải quân địch đỏ thẫm** (`enemy_cloth #991F47`) khác hẳn `enemy_primary #7A4FA0`. Giữ `enemy_primary` tím cho aura và thanh máu để không lẫn với telegraph đỏ.

## Việc còn lại

- [x] Hút màu môi trường, công trình, nhân vật từ asset thật
- [ ] Chốt xung đột áo choàng đỏ của chỉ huy
- [ ] Kiểm tra bằng ảnh đen trắng và công cụ giả lập mù màu
- [ ] Đưa màu UI vào `ui/theme/` cho TV4
