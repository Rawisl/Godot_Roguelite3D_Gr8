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
| struct_wall_tier1 | `#7C6D5F` | Thân tường tower bậc 1 (thay struct_stone_light trong `tower_tier1_wood.png`) |
| struct_wall_tier1_light | `#8D7D6F` | Mảng sáng trên tường tower bậc 1 (thay `#FFF1CA`) |

### Đống đổ nát (tower bị phá)

Màu phẳng theo từng mặt đá của `contents/assets/environment/rubble/tower_rubble.glb`, mỗi màu một file trong `contents/assets/environment/rubble/materials/`. Tối và ít tương phản hơn màu tháp để đống đổ nát không lấn át tower và quân; mảnh ngói xanh lấy từ `struct_roof` làm tối đi.

| Tên | Hex | Dùng cho |
|---|---|---|
| rubble_stone_light | `#8F877F` | Mặt đá sáng nhất |
| rubble_stone | `#494545` | Đá |
| rubble_stone_dark | `#2E2A27` | Đá tối, khe |
| rubble_wood | `#75655C` | Gỗ gãy |
| rubble_char | `#2A2522` | Mảng cháy sém |
| rubble_roof | `#3D4C36` | Mảnh ngói xanh, mặt trên |
| rubble_roof_dark | `#2B3625` | Mảnh ngói xanh, mặt bên và mặt dưới |

### Trạm hồi phục

Thân trạm (`contents/assets/towers/heal_station.glb`) dùng màu phẳng, mỗi màu một file `contents/assets/towers/texture/heal_station_*.tres`. Đá xám lạnh hơn `struct_stone` để trạm không lẫn với Arrow và Cannon. Hồ nước, quả cầu, vòng tầm và tia sáng nằm trong `art/materials/`. Hồ nước và quả cầu chuyển dần sang màu "cạn" theo HP còn trong kho.

| Tên | Hex | Dùng cho | File |
|---|---|---|---|
| heal_stone_light | `#C5CBD8` | Mặt đá sáng, bậc trên | `heal_station_stone_light.tres` |
| heal_stone | `#959DAC` | Thân đá | `heal_station_stone.tres` |
| heal_panel | `#595F6C` | Tấm ốp, khe tối | `heal_station_panel.tres` |
| heal_door | `#6F6961` | Cửa ở bốn góc | `heal_station_door.tres` |
| heal_crystal | `#4B8952` | Bốn tinh thể chỉa vào quả cầu | `heal_station_crystal.tres` |
| heal_water_rim | `#80DBF0` | Mép hồ nước | `heal_water.tres` |
| heal_water_core | `#DBFAFF` | Giữa hồ nước | `heal_water.tres` |
| heal_water_empty | `#52616B` | Hồ nước khi kho cạn | `heal_water.tres` |
| heal_orb_core | `#B8F7C2` | Tâm quả cầu | `energy_orb_core.tres` |
| heal_orb_rim | `#61DB80` | Viền quả cầu | `energy_orb_core.tres` |
| heal_orb_empty | `#757D85` | Quả cầu khi kho cạn | `energy_orb_core.tres` |
| heal_orb_glow | `#73EB8C` | Quầng sáng quanh quả cầu (cộng màu) | `energy_orb_glow.tres` |
| heal_ring | `#9EFFAD` | Vòng heal_range quanh trạm, tia sáng sang chỉ huy | `heal_ring.tres`, `heal_beam.tres` |
| heal_hold_track | `#5BE37A` 25% alpha | Rãnh vòng tiến trình lúc giữ E (màu `heal`) | `heal_hold_ring.tres` |
| heal_hold_fill | `#9EFFB2` 95% alpha | Phần đã đầy của vòng tiến trình | `heal_hold_ring.tres` |

Đèn và hạt sáng của quả cầu không có màu riêng: `energy_orb.gd` lấy giữa `heal_orb_core` và `heal_orb_rim`, nên chỉ cần chỉnh trong `energy_orb_core.tres`.

### Hazard Trial (tháp và phòng)

Phòng (`levels/corridor/hazard_room.tscn`) là một đảo tròn lơ lửng: sàn `env_grass`, tường `struct_stone`, mặt dưới đảo và đá trôi `env_rock`. Tím chỉ dùng cho Hazard Trial để tháp và hốc sinh quái không lẫn với màu phe địch hay telegraph đỏ.

Quanh đảo là bầu trời vẽ sẵn (`contents/assets/environment/hazard_room/hazard_backdrop.png`, tạo bằng ChatGPT, nhìn xoáy mây từ trên xuống) dán lên một quả cầu luôn bao quanh camera, qua `art/materials/hazard_sky.tres`. Shader `art/shaders/hazard_sky.gdshader` đặt tâm ảnh thẳng dưới camera, chân trời rơi vào vòng mây ngoài của ảnh (`rim_angle`); nửa trên là ảnh phản chiếu qua chân trời, mờ dần trong `cloud_band_height` độ, rồi chuyển từ `hazard_sky_horizon` lên `hazard_sky_zenith` (đậm hẳn ở `zenith_angle` độ); `brightness` giảm sáng cả bầu trời. Khi chỉ huy ở trong phòng, `hazard_room.gd` chuyển nắng sang `#D9C2FF` trong 0.5 s; ra phòng thì trả lại.

| Tên | Hex | Dùng cho | File |
|---|---|---|---|
| hazard_glow | `#9B6BFF` | Vòng sáng trên hốc sinh quái, vòng và tinh thể trên tháp, đèn tháp | `art/materials/hazard_glow.tres` |
| hazard_pad | `#6A6A80` | Nền đá của hốc sinh quái, bệ và nắp tháp (cùng `struct_slate`) | `art/materials/hazard_pad.tres` |
| hazard_sky_horizon | `#564CB8` | Màu chân trời phía trên dải mây và ngoài mép ảnh (trung bình vòng ngoài của ảnh) | `hazard_sky.tres` (`horizon_color`) |
| hazard_sky_zenith | `#2A1660` | Tím đậm ở đỉnh bầu trời phòng Hazard Trial | `hazard_sky.tres` (`zenith_color`) |
| hazard_crosshair | `#FFFFFF` (alpha 0.85) | Crosshair giữa màn hình trong phòng Hazard Trial khi chuột bị khóa | `CameraRig.crosshair_color` (`systems/camera/camera_rig.gd`) |
| hazard_sun | `#D9C2FF` | Màu nắng trong phòng | `hazard_room.gd` (`sun_color`) |
| env_dirt | `#A88D63` | Vòng đất chỗ chỉ huy xuất hiện | `art/materials/env_dirt.tres` |
| env_rock | `#757575` | Mặt dưới đảo, đá trôi, móng tháp | `art/materials/env_rock.tres` |

## Nhân vật

| Tên | Hex | Dùng cho | Nguồn |
|---|---|---|---|
| ally_steel | `#AAB5BF` | Giáp chỉ huy | `knight_texture.png` |
| ally_steel_dark | `#556060` | Giáp tối, mũ | `knight_texture.png` |
| ally_cape | `#CC2929` | Áo choàng chỉ huy | `knight_texture.png` (đã chốt giữ, xem mục Xung đột) |
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
| ally_accent | `#E8C25A` | Điểm nhấn phe ta, vòng aura Frontline quanh chỉ huy (`aura_ring.tres`) và icon aura trên tháp |
| enemy_primary | `#7A4FA0` | Viền, aura, thanh máu quân địch |
| enemy_boss | `#B0402E` | Điểm nhấn boss (không trùng telegraph) |

## Tín hiệu gameplay

| Tên | Hex | Dùng cho |
|---|---|---|
| danger | `#FF2D2D` | Telegraph Stomp, Shell, Overload (vòng đỏ viền đậm + họa tiết) |
| danger_fill | `#FF2D2D` 35% alpha | Phần nền bên trong telegraph |
| safe_zone | `#4FE0C0` | Retreat Zone, ReturnZone |
| build_ring | `#FFFFFF` 60% alpha | Vòng build slot ở PREP |
| ruined | `#4A4038` | Tông chung của đống đổ nát, chưa file nào dùng trực tiếp. Model dùng bộ `rubble_*` ở mục Công trình |
| ruined_ring | `#A8876B` 80% alpha | Vòng slot RUINED trên sàn (sáng hơn `ruined` để đọc được trên cỏ) |
| gold | `#FFC83D` | Gold, phần thưởng |

## Skill chỉ huy (VFX)

Whirlwind và Sword Wave đổi bộ màu theo kiếm đang cầm (id kiếm lấy từ `weapon_equipped`), hình dạng giữ nguyên. Kiếm thường dùng tông thép bạc trung tính để khi đổi sang kiếm nguyên tố thì màu "bừng lên"; Hàn Sương giữ bộ xanh băng cũ, không trùng vàng của aura. Mỗi bộ là một file `SkillPalette` trong `art/materials/palettes/` (chỉnh màu ở đó); `skill_whirlwind.tres` và `skill_sword_wave.tres` giữ bộ Frost làm mặc định khi xem trong editor. Firebomb dùng hổ phách có họa tiết lửa, không gạch chéo, để không nhầm với telegraph đỏ của boss.

### Kiếm thường (`art/materials/palettes/skill_palette_sword_base.tres`)

| Tên | Hex | Dùng cho |
|---|---|---|
| skill_base_core | `#F4F6F8` | Phần trắng giữa lưỡi Sword Wave và đầu vệt quét Whirlwind |
| skill_base_rim | `#C9D1D9` | Viền lưỡi Sword Wave và viền ngoài vệt quét Whirlwind |
| skill_base_band | `#8A97A6` | Quầng sáng trước lưỡi Sword Wave, ngoài viền Whirlwind; thân vệt đoạn gần lưỡi |
| skill_base_shard | `#B4BEC9` | Thân vệt (Sword Wave và Whirlwind), đoạn sát lưỡi kiếm |
| skill_base_mid | `#5B6673` | Thân vệt, đoạn giữa đuôi |
| skill_base_tail | `#2E343C` | Thân vệt, đoạn cuối đuôi |
| skill_base_spark | `#E6EBF0` | Tia bay từ lưỡi Sword Wave về sau theo sóng và tia sáng bay vào tâm của Whirlwind |

### Hàn Sương (`art/materials/palettes/skill_palette_frost.tres`)

| Tên | Hex | Dùng cho |
|---|---|---|
| skill_frost_core | `#E9FCFF` | Phần trắng giữa lưỡi Sword Wave và đầu vệt quét Whirlwind |
| skill_frost_rim | `#A9E9F7` | Viền lưỡi Sword Wave và viền ngoài vệt quét Whirlwind |
| skill_frost_band | `#29B9E8` | Quầng sáng trước lưỡi Sword Wave, ngoài viền Whirlwind; thân vệt đoạn gần lưỡi |
| skill_frost_shard | `#85DBF2` | Thân vệt (Sword Wave và Whirlwind), đoạn sát lưỡi kiếm |
| skill_frost_mid | `#24799D` | Thân vệt, đoạn giữa đuôi |
| skill_frost_tail | `#17394E` | Thân vệt, đoạn cuối đuôi |
| skill_frost_spark | `#C6F5FF` | Tia bay từ lưỡi Sword Wave về sau theo sóng và tia sáng bay vào tâm của Whirlwind |

### Lôi Kiếm (`art/materials/palettes/skill_palette_chain_lightning.tres`)

| Tên | Hex | Dùng cho |
|---|---|---|
| skill_lightning_core | `#FBF2FF` | Phần trắng giữa lưỡi Sword Wave và đầu vệt quét Whirlwind |
| skill_lightning_rim | `#DCC2FF` | Viền lưỡi Sword Wave và viền ngoài vệt quét Whirlwind |
| skill_lightning_band | `#9A5CFF` | Quầng sáng trước lưỡi Sword Wave, ngoài viền Whirlwind; thân vệt đoạn gần lưỡi |
| skill_lightning_shard | `#C3A2FF` | Thân vệt (Sword Wave và Whirlwind), đoạn sát lưỡi kiếm |
| skill_lightning_mid | `#5B33A8` | Thân vệt, đoạn giữa đuôi |
| skill_lightning_tail | `#2A1A4F` | Thân vệt, đoạn cuối đuôi |
| skill_lightning_spark | `#F0E0FF` | Tia bay từ lưỡi Sword Wave về sau theo sóng và tia sáng bay vào tâm của Whirlwind |

### Xích Tiêu (`art/materials/palettes/skill_palette_burn.tres`)

| Tên | Hex | Dùng cho |
|---|---|---|
| skill_burn_core | `#FFF6DC` | Phần trắng giữa lưỡi Sword Wave và đầu vệt quét Whirlwind |
| skill_burn_rim | `#FFD48A` | Viền lưỡi Sword Wave và viền ngoài vệt quét Whirlwind |
| skill_burn_band | `#FF7A1F` | Quầng sáng trước lưỡi Sword Wave, ngoài viền Whirlwind; thân vệt đoạn gần lưỡi |
| skill_burn_shard | `#FFB45C` | Thân vệt (Sword Wave và Whirlwind), đoạn sát lưỡi kiếm |
| skill_burn_mid | `#B8360F` | Thân vệt, đoạn giữa đuôi |
| skill_burn_tail | `#4F1A0A` | Thân vệt, đoạn cuối đuôi |
| skill_burn_spark | `#FFE0A0` | Tia bay từ lưỡi Sword Wave về sau theo sóng và tia sáng bay vào tâm của Whirlwind |

### Nộ Kiếm (`art/materials/palettes/skill_palette_rampage.tres`)

| Tên | Hex | Dùng cho |
|---|---|---|
| skill_rampage_core | `#FFE4DC` | Phần trắng giữa lưỡi Sword Wave và đầu vệt quét Whirlwind |
| skill_rampage_rim | `#FF8A70` | Viền lưỡi Sword Wave và viền ngoài vệt quét Whirlwind |
| skill_rampage_band | `#D61E1E` | Quầng sáng trước lưỡi Sword Wave, ngoài viền Whirlwind; thân vệt đoạn gần lưỡi |
| skill_rampage_shard | `#F05A45` | Thân vệt (Sword Wave và Whirlwind), đoạn sát lưỡi kiếm |
| skill_rampage_mid | `#7A0D0D` | Thân vệt, đoạn giữa đuôi |
| skill_rampage_tail | `#330606` | Thân vệt, đoạn cuối đuôi |
| skill_rampage_spark | `#FF9C80` | Tia bay từ lưỡi Sword Wave về sau theo sóng và tia sáng bay vào tâm của Whirlwind |

### Truy Phong (`art/materials/palettes/skill_palette_swift.tres`)

| Tên | Hex | Dùng cho |
|---|---|---|
| skill_swift_core | `#F2FFF0` | Phần trắng giữa lưỡi Sword Wave và đầu vệt quét Whirlwind |
| skill_swift_rim | `#C2F5B8` | Viền lưỡi Sword Wave và viền ngoài vệt quét Whirlwind |
| skill_swift_band | `#4CD96A` | Quầng sáng trước lưỡi Sword Wave, ngoài viền Whirlwind; thân vệt đoạn gần lưỡi |
| skill_swift_shard | `#96EB8C` | Thân vệt (Sword Wave và Whirlwind), đoạn sát lưỡi kiếm |
| skill_swift_mid | `#2A8A45` | Thân vệt, đoạn giữa đuôi |
| skill_swift_tail | `#133D22` | Thân vệt, đoạn cuối đuôi |
| skill_swift_spark | `#DDFFD4` | Tia bay từ lưỡi Sword Wave về sau theo sóng và tia sáng bay vào tâm của Whirlwind |

### Firebomb

| Tên | Hex | Dùng cho |
|---|---|---|
| skill_fire_core | `#FFB347` | Vùng cháy Firebomb, quả bom, tàn lửa (`skill_fire_zone.tres`, `skill_firebomb.tres`) |
| skill_fire_rim | `#FFD46B` | Viền vùng cháy |
| skill_fire_dark | `#C7541F` | Mảng lửa tối trong vùng cháy |

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
| ui_bg | `#1C1F26` | Nền panel tối, chữ trên nền sáng (nút, tab đang chọn, khung nội dung) |
| ui_bg_alt | `#2A2F3A` | Nền phụ, nền thanh tiến trình |
| ui_text | `#F2EFE6` | Chữ chính trên nền tối |
| ui_text_dim | `#A9A79F` | Chữ phụ trên nền tối, tab không được chọn |
| ui_accent | `#E8C25A` | Điểm nhấn (tiêu đề, số liệu nổi bật). Theme hiện chưa dùng |
| ui_alert_t1 | `#FF2D2D` | Cảnh báo T1 |
| ui_alert_t2 | `#FF9A2E` | Cảnh báo T2 |
| ui_alert_t3 | `#E8E05A` | Cảnh báo T3 |
| ui_error | `#FF6B57` | Chữ báo lỗi trong form (không dùng `ui_alert_t2`, màu đó dành cho cảnh báo T2) |
| ui_border | `#474D5A` | Viền mảnh của khung Vàng/Mithril, khung thanh boss và ô slot màn chọn thưởng |
| ui_badge_hover | `#FFDC73` | Nút "Sửa thành" trên HUD khi rê chuột (nền thường dùng `gold`) |
| ui_badge_pressed | `#DAA32B` | Nút "Sửa thành" trên HUD khi bấm |

Nút và vùng nội dung dùng màu đá `struct_stone`, `struct_stone_light`, `env_dirt`, `struct_stone_dark` (mục Công trình, Môi trường) để đồng bộ với tường và tháp.

### Áp dụng trong theme

`ui/theme/main_theme.tres` là theme chung của project. `ui/theme/light_panel_theme.tres` gắn vào node cha của vùng nền sáng (hiện là `Tabs` trong `settings.tscn`) để chữ bên trong chuyển sang tối.

| Thành phần | Nền | Viền | Chữ |
|---|---|---|---|
| Nút thường (Button, OptionButton) | `struct_stone` | | `ui_bg` |
| Nút rê chuột | `struct_stone_light` | `struct_stone` | `ui_bg` |
| Nút nhấn | `env_dirt` | `struct_stone_dark` | `ui_bg` |
| Nút focus | | `ui_bg`, 3 px | `ui_bg` |
| Nút bị khóa | `struct_stone` 35% alpha | | `struct_stone_dark` |
| Tab đang chọn | `struct_stone` | | `ui_bg` |
| Tab không chọn | `ui_bg` | | `ui_text_dim` |
| Tab rê chuột | `struct_stone` 45% alpha | | `ui_text` |
| Khung nội dung tab | `struct_stone_light` | `struct_stone`, 4 px | `ui_bg` (qua `light_panel_theme`) |
| Label | | | `ui_text`; trong vùng sáng là `ui_bg` |
| PanelContainer | `ui_bg` 90% alpha | | |
| DialogPanel | `ui_bg` | `ui_bg_alt` | |
| ProgressBar | `ui_bg_alt`, phần đầy `ally_primary` | | `ui_text` |

Biến thể (Theme Type Variation) cho TV4 dùng khi cần:

| Biến thể | Kiểu gốc | Màu |
|---|---|---|
| EnemyBar | ProgressBar | phần đầy `enemy_primary` |
| BossBar | ProgressBar | phần đầy `enemy_boss` |
| AlertT1, AlertT2, AlertT3 | PanelContainer | nền `ui_bg` 92%, viền 3 px `ui_alert_t1/t2/t3` |
| DrawerPanel | PanelContainer | nền `env_bark`, viền `enemy_leather` |
| DimLabel | Label | `ui_text_dim`; trong vùng sáng là `struct_stone_dark` |
| ErrorLabel | Label | `ui_error` |
| FormCaption | Label | `ui_text_dim`, cỡ 22 (nhãn ô nhập trong form) |
| HudLabel | Label | `ui_text`, cỡ 20 |
| HudHint | Label | `ui_text_dim`, cỡ 16 (chữ phụ trên HUD) |
| Keycap | PanelContainer | nền `ui_bg_alt`, viền 2 px `ui_text`, bo 6 px (ô phím như [E]) |
| KeycapLabel | Label | `ui_text`, cỡ 20 (chữ trong Keycap) |
| SpeedToggle | Button | khi bật (`toggle_mode` pressed): nền `ui_accent`, viền 3 px `ui_text`, chữ `ui_bg` |
| RewardCard | Button | thẻ REWARD_PICK, bo 12 px, có bóng. Thường `#F1DEC3`, rê chuột `struct_stone_light` (bóng lớn hơn), nhấn `#E2C9A6`, xám `#B4ADA3`, đã chọn (`picked`) `struct_stone_light` với quầng `ui_accent` |
| RewardCardTitle, RewardCardLevel, RewardCardText | Label | `ui_bg`, cỡ 32 / 24 / 22 (tên, cấp, mô tả trên thẻ) |
| RewardFrameActive, RewardFramePassive, RewardFrameStat | Panel | chỉ viền 8 px theo loại thẻ: `ui_card_active`, `ui_card_passive`, `ui_card_stat` |
| RewardKindActive, RewardKindPassive, RewardKindStat | PanelContainer | dải nhãn loại thẻ, nền theo loại, bo 8 px |
| RewardKindLabel, RewardKindLabelLight | Label | chữ trên dải: `ui_bg` (dải vàng), `ui_text` (dải tím, xanh), cỡ 20 |

Màu loại thẻ (khung, dải nhãn; chủ động và bị động trùng màu nhóm ô slot trên cùng màn):

| Tên | Hex | Dùng cho |
|---|---|---|
| ui_card_active | `#FFC83D` | Kỹ năng chủ động |
| ui_card_passive | `#7A4FA0` | Kỹ năng bị động |
| ui_card_stat | `#2F6FA8` | Chỉ số |

Ô nhập (LineEdit) dùng chung trong theme, không cần biến thể: nền `ui_bg_alt`, viền 2 px `ui_text_dim`, focus viền `ui_accent`, chữ `ui_text` cỡ 26, gợi ý (placeholder) `ui_text_dim` 60%.

## Xung đột màu

- **Áo choàng chỉ huy đỏ** (`ally_cape #CC2929`) gần với `danger #FF2D2D`, trái nguyên tắc "đỏ chỉ dùng cho telegraph". Hướng xử lý: đổi texture áo choàng sang xanh `ally_primary`, hoặc chấp nhận vì telegraph luôn có viền đậm và họa tiết (FBK-06). **Đã chốt (15/10): giữ áo choàng đỏ.**
- **Mắt quân thường vàng** (`enemy_glow_b #FFBB33`) gần với `gold #FFC83D`. Mắt rất nhỏ trên màn hình nên ít khả năng gây nhầm, chỉ cần để ý khi làm VFX rơi gold.
- **Vải quân địch đỏ thẫm** (`enemy_cloth #991F47`) khác hẳn `enemy_primary #7A4FA0`. Giữ `enemy_primary` tím cho aura và thanh máu để không lẫn với telegraph đỏ.

## Việc còn lại

- [x] Hút màu môi trường, công trình, nhân vật từ asset thật
- [x] Chốt xung đột áo choàng đỏ của chỉ huy
- [ ] Kiểm tra bằng ảnh đen trắng và công cụ giả lập mù màu
- [x] Đưa màu UI vào `ui/theme/` (xem mục Áp dụng trong theme)

## Số sát thương nổi

| Tên | Hex | Dùng cho |
|---|---|---|
| fbk_normal | `#FFFFFF` | Sát thương thường lên quân địch |
| fbk_resist | `#C8C8C8` | Kèm chữ RESIST hoặc IMMUNE (xám sáng để đọc được trên nền cỏ) |
| fbk_commander | `#E04545` | Sát thương chỉ huy nhận |
| fbk_heal | `#9CFF6A` | Số hồi máu "+n" |

## Boss Skeletal Centipede (VFX)

Đòn chém lưỡi liềm vẽ kiểu mực trắng đen: thân trắng, dải xám ở mép trong, viền mực đen. Màu đặt trong uniform của shader, chỉnh ở material.

| Tên | Hex | Dùng cho |
|---|---|---|
| boss_slash_core | `#FFFFFF` | Thân vệt chém, lớp sáng trên lưỡi, hạt sao `*` (`boss_slash_crescent.tres`, `boss_blade_glow_core.tres`, `boss_star_particle.tres`) |
| boss_slash_band | `#B8B8B8` | Dải xám ở mép trong của vệt chém |
| boss_slash_ink | `#050505` | Viền mực của vệt, vết nứt, viền lớp sáng trên lưỡi (`boss_blade_glow_ink.tres`) và viền hạt sao |
| boss_roll_eye | `#FF2A2A` (alpha 0,45, cộng sáng) | Mắt sáng đỏ khi boss cuộn lại (`boss_roll_eye_glow.tres`), không viền |
| boss_roll_eye_halo | `#FF8C1F` (alpha 0,8, cộng sáng) | Quầng cam sáng sau mỗi mắt khi boss gầm, luôn quay về camera, hiện xuyên đầu để thấy được ở camera game (`boss_roll_eye_halo.tres`, chỉnh `falloff` cho độ mềm, kích thước ở `Halo` trong `centipede_fx.tscn`) |
| boss_roll_eye_spark | `#8C0005` | Hạt đỏ đậm bay ra từ mắt khi mắt sáng (`boss_roll_eye_particle.tres`) |
| boss_roll_body | `#A040FF` (`veil` và `rim` 0,12) | Lớp sáng tím trong suốt phủ cả thân khi boss bung ra (`boss_roll_body_glow.tres`), không viền |
| boss_roll_line | `#FFFFFF` (alpha 0,8) | Nét tốc độ phía sau boss khi lăn (`boss_roll_speed_lines.tres`), không viền |
| boss_spit_core_hot | `#E4FF8A` | Ánh sáng nhạt ở đầu luồng phun độc (đầu color ramp lõi, `hot_color` trong `boss_spit_*.tres`) |
| boss_spit_core | `#3DCC1F` → `#1F8C14` | Lõi axit của luồng phun độc (color ramp node `Head/SpitEmitter/Core` trong `art/vfx/centipede_fx.tscn`), có ánh `#8CFF2E` ngay sau miệng |
| boss_spit_drop | `#5BD62A` | Giọt độc văng ra (color ramp node `Drops`) |
| boss_spit_smoke | `#2FB7A0` → `#1F6F5C` | Khói xanh ngọc bám theo luồng (color ramp node `Smoke`) |
| boss_spit_pool_core | `#1F8C14` (alpha 0,85) | Thân bãi độc trên sàn (`boss_spit_pool.tres`) |
| boss_spit_pool_rim | `#8CFF2E` (alpha 0,95) | Mép sáng quanh mỗi vũng độc |
| boss_spit_pool_bubble | `#E4FF8A` | Bọt sủi trong bãi độc |

## Fox Commander (VFX)

Vệt chém trắng theo lưỡi kiếm của 3 đòn combo (dải dựng sẵn từ Blender, `art/vfx/fox_commander/fox_slash_trails.tscn`). Màu đặt trong uniform của shader `fox_slash_trail.gdshader`, chỉnh ở `art/materials/fox_slash_trail.tres`. Khi bật "Giảm nhấp nháy", vệt bị ẩn hẳn (độ đục về 0 qua `fox_slash_trails.gd`), không đổi màu.

| Tên | Hex | Dùng cho |
|---|---|---|
| fox_trail_rim | `#4D6B8C` | Mép trong và đuôi vệt (`color_rim`) |
| fox_trail_mid | `#9EC7E6` | Thân vệt (`color_mid`) |
| fox_trail_bright | `#E0F2FF` | Phần sáng gần mép lưỡi (`color_bright`) |
| fox_trail_core | `#FFFFFF` | Lõi trắng ngay sau lưỡi kiếm (`color_core`) |
