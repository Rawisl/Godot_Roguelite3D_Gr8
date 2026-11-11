# PHÂN CÔNG VÀ KẾ HOẠCH TASK: SRS v2.0 (tuần 8 bổ sung đến tuần 13)

File này dành cho cả người lẫn agent. Bản bảng tính của nhóm là `Bang_phan_cong_v2.0.xlsx`; file này là bản chữ cùng nội dung, chia nhỏ theo task để đọc từng phần. Khi hai bản lệch nhau thì bản Excel là bản đúng, hãy báo để sửa lại file này.

Yêu cầu chức năng nằm ở `SRS_Endless_War_v2.0.md` (tìm theo ID như `HZT-05`, `GRID-07`). Quy tắc viết code, Git và cấu trúc thư mục nằm ở `CONTRIBUTING.md`.

## Cách agent dùng file này

1. Tìm task theo mã (ví dụ `W10-KT5`) trong mục 4. Mỗi task có đủ: người làm, giờ, việc, nghiệm thu, tệp liên quan, task phải xong trước, ID SRS.
2. Trước khi làm, kiểm tra các task trong 'Cần xong trước' đã có trong `main` chưa (xem `git log`). Chưa có thì báo, không tự làm thay trừ khi được giao.
3. Chỉ sửa trong thư mục sở hữu của người làm (mục 2). Cần sửa tệp của người khác thì làm trong cùng PR và ghi tên người sở hữu vào mô tả PR.
4. Làm xong đổi dòng `Trạng thái` của task thành `Xong` trong cùng PR.
5. Task có Nguồn CŨ giữ nguyên nghĩa của bảng phân công v3 (W6 đến W8 đã xong); chi tiết đặc tả nằm ở SRS theo mục ID SRS.

## 1. Quy tắc chung cho mọi task (Definition of Done)

- Chạy đúng ở tua x1, x2, x3; không lỗi đỏ trong Output của Godot; F5 chạy `main.tscn` và F6 chạy scene vừa sửa đều ổn.
- Mọi giá trị cân bằng nằm trong Resource hoặc trong `balance/balance.xlsx` (nhóm dữ liệu ở SRS mục 6.10). Tệp `.tres` do công cụ dịch sinh ra thì **không sửa tay**, sửa bảng rồi chạy lại công cụ.
- Mọi chuỗi hiển thị qua `tr("khoa")` và khai báo trong `data/locale/strings.csv`; không viết cứng tiếng Việt.
- Mọi nguồn sát thương đi qua `HealthComponent` với `DamageInfo` (có `damage_type`, `source`); giao tiếp giữa hệ thống qua `EventBus`; RNG gameplay dùng `run_seed`; timer gameplay dùng game time qua `TimeManager`.
- Giao dịch xây, nâng, bán, sửa, đổi vũ khí là nguyên tử (kiểm lại state lúc xác nhận).
- Có test (GUT hoặc runner trong `tests/`) cho phần logic mới; sửa test hỏng ngay trong PR gây ra thay đổi.
- Nhánh theo dạng `week<n>/chu-de`; một PR một chủ đề.

## 2. Người, vai và thư mục sở hữu

| Người | Vai | Phụ trách | Thư mục và tệp sở hữu |
| --- | --- | --- | --- |
| Ngọc | TV1 Player & Combat | Chỉ huy, chiến đấu, vũ khí và hiệu ứng, DMG-06, SkillRunner/StatBlock, TimeManager, heal_channel, phía chỉ huy của Hazard Trial, backend (Supabase), công cụ dịch bảng cân bằng, thắng/endless (logic), save/đồng bộ phía lưu và nộp điểm | `entities/commander/`, `systems/skill/`, `systems/time/`, `data/skills/`, `data/weapons/`, `common/stat_block.gd`, `common/weapon_data.gd`, `autoload/time_manager.gd`, `backend/`, `tools/balance/` |
| Kiệt | TV2 Enemy & Wave | Quân địch (10 loại), boss, wave FSM, spawner, WaveScript, scale, RunConfig/RunState, kết thúc Run, XpTracker, thang kẹt NAV, Hazard Trial phía wave và AI trong phòng, `autoload/game_config.gd` | `entities/enemy/`, `systems/wave/`, `systems/run/`, `systems/xp/`, `systems/nav/`, `systems/hazard/`, `data/enemies/`, `data/bosses/`, `data/waves/` (WaveScript), `common/enemy_data.gd`, `common/boss_data.gd`, `common/wave_*.gd`, `common/scale_config.gd`, `autoload/game_config.gd` |
| Mạnh | TV3 Tower & Build | Tower 36 cấp và 3 bậc model, Fortress và Mithril, Slot/GroundGrid/GRID-07, trụ có sẵn, kinh tế (WaveRewardTable), save, MetaShop backend, bảng cân bằng (`balance.xlsx`) | `entities/tower/`, `entities/fortress/`, `entities/projectile/`, `systems/build/`, `systems/economy/`, `systems/reward/`, `systems/save/`, `data/towers/`, `data/config/`, `balance/`, `common/tower_*.gd`, `common/fortress_stats.gd`, `levels/corridor/slots_layout.tscn`, `autoload/save_manager.gd` |
| Khang | TV4 UI/UX & Meta | HUD, panel, màn hình (gồm màn thắng, RunEnd), nút Bắt đầu wave, UI Hazard/vũ khí/Mithril, tutorial, MetaShop UI, Settings, Login/Leaderboard, SyncService, ngôn ngữ | `ui/` (trừ tab của Kim và `ui/theme/`), `systems/sync/`, `systems/tutorial/`, `data/locale/`, `autoload/game_state.gd`, `autoload/screen_manager.*` |
| Kim | TV5 Art/Level/Audio | Map và GridData, camera, model, animation, VFX, shader, âm thanh, accessibility, playtest | `contents/`, `art/`, `audio/`, `levels/corridor/` (trừ `slots_layout.tscn`), `systems/camera/`, `autoload/audio_manager.*`, `default_bus_layout.tres`, `ui/screens/tab_audio.*`, `tab_graphics.*`, `tab_accessibility.*`, `ui/theme/` |

Ranh giới: Ngọc nhận thêm một phần việc của Mạnh (xem cột Nguồn 'ĐỔI NGƯỜI'). Tutorial thuộc Khang (đổi từ Ngọc). Thư mục cấp cao mới `balance/` và `tools/balance/` được tạo theo bảng phân công này cho bảng cân bằng.

## 3. Mốc tích hợp cuối mỗi tuần

Cuối mỗi tuần cả nhóm chơi thử một lượt theo mô tả bên dưới trên `main`. Mốc không đạt nghĩa là các phần chưa ghép được với nhau, ưu tiên sửa trước khi mở task mới.

| Tuần | Ngày | Mốc | Lượt chơi kiểm | Task tạo nên mốc |
| --- | --- | --- | --- | --- |
| 8 | 8/11 | PREP mới chạy được | Vào run với 0 gold, PREP không đếm ngược, bấm 'Bắt đầu wave', đánh wave 1 trên hành lang 23.5 m, sang SUMMARY rồi PREP wave 2. | W8B-KT1, W8B-KT2, W8B-KH1, W8B-MH2, W8B-KM1, W8B-NG1 |
| 9 | 15/11 | Mốc B1 trên map và luật xây mới | Chơi đến hết Bulwark wave 5 (pha giáp, Cuồng nộ), nhặt 3 skill chủ động ở REWARD_PICK; xây trên 3 slot WALL và 3 ô grid, ô chặn kín đường bị từ chối; sửa Fortress bằng Mithril (cấp bằng debug); công cụ dịch sinh được CharacterStats, SkillData, TowerData, EnemyData từ xlsx; quân không còn va chạm nhau. | W9-KT2, W9-KH2, W9-MH4b, W9-MH5, W9-MH2, W9-NG7, W9-KT5, W9-KM7 |
| 10 | 22/11 | Mốc B2 và vòng Hazard Trial | Từ PREP bấm E vào Hazard Trial, đánh 5 quái, thắng nhận Mithril rồi sửa Fortress; run mới có sẵn Arrow và Cannon; tower nâng tới cấp 36 và đổi model ở 13, 25; vũ khí đổi được và có Swift, Rampage; RunLoading -> RunEnd -> save; MetaShop 4 mục; bảng xếp hạng nối backend. | W10-KT5, W10-NG10, W10-KH7, W10-MH9, W10-MH10, W10-NG9, W10-KT2, W10-NG6 |
| 11 | 29/11 | Đóng băng gameplay: một run trọn vẹn | Từ MainMenu: tutorial lần đầu -> wave 1-30 theo kịch bản với 10 loại quân -> mỗi PREP có Hazard -> boss wave 5..25 rơi vũ khí có hiệu ứng -> wave 30 màn thắng -> endless -> RunEnd (SURVIVED) -> nộp điểm lên bảng xếp hạng; bot chạy hết 30 wave ở x3. | W11-NG1, W11-KT9, W11-KT7, W11-KT8, W11-NG7, W11-MH9, W11-NG9, W11-KH6, W11-KH4, W11-NG4 |
| 12 | 6/12 | Đóng băng tính năng | Chốt balance.xlsx và bộ .tres sinh ra; chạy xong AC1..AC9, HZ, WP, NE, VC, TU, BL; build Windows trên máy yếu; playtest vòng 2. | W12-KT1, W12-MH5, W12-NG1, W12-NG3, W12-MH4, W12-KM5 |
| 13 | 14/12 | Nộp bài | Chỉ báo cáo, video, đệm sửa lỗi; 17/12 diễn tập. | W12-KM1, W12-KH3 |

**Chuỗi phụ thuộc găng** (trễ một mắt thì dồn tuần sau): `W8B-KM1` hành lang -> `W9-KM6` -> `W9-KM7` GridData -> `W9-MH5` GRID-07 -> `W10-MH10` trụ có sẵn -> `W11-NG1` tutorial. Và `W8B-NG1` DMG-06 -> `W9-NG5` Slow/DoT -> `W11-NG7` hiệu ứng vũ khí. Và `W10-KT7` trait quân -> `W11-KT7`, `W11-KT8` -> `W11-KT9` spawner theo WaveScript. Và `W8B-KT1` RunState -> mọi task dùng Mithril, vũ khí, thắng/endless.

## Độ phủ MVP của v2.0

Tính năng và task bảo đảm nó (logic, giao diện, art, test):

| Tính năng | Task |
| --- | --- |
| Bảng cân bằng Excel và công cụ dịch (BAL) | W8B-MH1, W9-NG7, W10-NG8, W11-NG10, W11-MH11, W10-MH8, W12-MH5 |
| PREP không đếm ngược, nút Bắt đầu wave (WAVE-11, HUD-19) | W8B-KT2, W8B-KH1, W9-KT6 |
| Hazard Trial (HZT-01..16) | W10-KT4, W10-KT5, W10-KT6, W10-NG10, W10-KM8, W10-KM9, W10-KM4, W10-KH7, W12-NG5 (test HZ1-12) |
| Mithril (MTH-01..07) | W8B-KT1, W9-MH2, W9-KH3, W9-KH4, W10-KT5 (nguồn Mithril) |
| Vũ khí (WPN-01..12) | W9-NG5, W9-NG6, W10-NG9, W10-KH9, W11-NG7, W11-MH9, W11-KM8, W11-KH8, W12-NG5 (test WP1-8) |
| Quân mới và va chạm (EN-16..27) | W9-KT5, W10-KT7, W10-KT8, W11-NG8 (Brute), W11-KT7, W11-KT8, W10-KM11, W11-KM9, W11-KH7, W12-KT3 (test NE1-8) |
| Kịch bản wave 1-30 và scale từ wave 31 (SPN-13..15, SCL-06) | W10-KT7, W11-KT9, W11-MH11, W10-MH7 |
| Thưởng theo wave (gold_mult, xp_mult, mithril_reward) | W10-MH7, W10-MH3 |
| Thắng ở wave 30 và endless (END-07..10, WAVE-13, SCR-20, SCR-21) | W11-NG9, W11-KH6, W11-KH1, W9-KH3, W11-KM2, W10-KT2 |
| run_elapsed và bảng xếp hạng (RUN-02, LBD-06, AC9) | W8B-KT1, W10-KT2, W10-NG6, W11-KT9 (SPN-15), W11-MH6, W12-NG3 |
| Trụ có sẵn và tutorial một lần theo tài khoản | W10-MH10, W11-NG1, W10-NG5, W11-KH4 |
| Hành lang 23.5 m, 3 WALL + 3 ô grid, GRID-07, GRID-08 | W8B-KM1, W8B-MH2, W9-KM6, W9-KM7, W9-MH5, W10-KH8, W11-KT5, W11-MH10 |
| Tower 36 cấp, 3 bậc model, cổng bậc 13 và 25, Trạm hồi lực 36 cấp | W8B-MH2, W10-MH8, W10-MH9, W10-KH2, W10-KM10, W11-KM10, W11-MH8 |
| Sửa Fortress bằng Mithril (bỏ sửa bằng gold) | W9-MH2, W9-KH4 |
| Hạ tầng sát thương (DMG-06, Slow, DoT) dùng chung cho vũ khí và Hazard | W8B-NG1, W9-NG5 |

## Tổng giờ ước tính

| Tuần | Ngọc | Kiệt | Mạnh | Khang | Kim | Sức chứa bảng cũ mỗi người |
| --- | --- | --- | --- | --- | --- | --- |
| 8 | 8 | 10 | 9 | 7 | 8 | một phiên (bổ sung) |
| 9 | 30 | 28 | 28 | 21 | 25 | 12h |
| 10 | 45 | 40 | 38 | 34 | 31.5 | 18h |
| 11 | 47 | 43 | 31 | 38 | 36.5 | 18h |
| 12 | 18 | 18 | 18 | 18 | 18 | 18h |
| 13 | 12 | 12 | 12 | 12 | 12 | 12h |

Giờ là ước lượng. Tuần 9 đến 11 đang vượt sức chứa của bảng cũ; nếu trễ thì cắt theo thứ tự: bậc model 2 và 3 của tower dùng chung model bậc 1 chỉ đổi màu; công cụ dịch chỉ sinh nhóm dữ liệu nhiều số nhất trước; phòng Hazard dùng lại một góc map; sau đó theo Phụ lục C mục 17 của SRS (Firebomb, edge-pan camera, HLT-12, bảng xếp hạng, đồng bộ tài khoản).

## 4. Danh sách task

Quy ước nhãn Nguồn: **CŨ** (không đổi), **CŨ-SỬA** (task cũ đổi nội dung theo v2.0), **DỜI** (đã dời trong bảng cũ), **SỬA** (sửa mã có sẵn), **MỚI** (tính năng mới của v2.0), **ĐỔI NGƯỜI** (đổi người so với bảng cũ).

### Mục lục nhanh

| Mã | Người | Tuần | Giờ | Nguồn | Việc (rút gọn) |
| --- | --- | --- | --- | --- | --- |
| W8B-NG1 | Ngọc | 8 | 8 | MỚI | Công thức sát thương chung DMG-06 |
| W8B-KT1 | Kiệt | 8 | 6 | MỚI (kéo sớm từ W10-KT1) | RunConfig và RunState khung |
| W8B-KT2 | Kiệt | 8 | 4 | SỬA | Bỏ đếm ngược PREP và gọi wave sớm phía wave |
| W8B-MH1 | Mạnh | 8 | 6 | MỚI | Dựng balance/balance.xlsx khung |
| W8B-MH2 | Mạnh | 8 | 3 | SỬA | Đổi hằng số nền |
| W8B-KH1 | Khang | 8 | 7 | MỚI + SỬA | Nút 'Bắt đầu wave' (HUD-19) thay nút gọi wave sớm |
| W8B-KM1 | Kim | 8 | 8 | SỬA | Mở rộng hành lang 16 m lên 23.5 m, phần 1 |
| W9-MH4a | Ngọc | 9 | 2 | CŨ + ĐỔI NGƯỜI (Mạnh sang Ngọc) | apply_pick: ghi vào RunSkillState, gọi StatBlock, phát skill_slots_changed |
| W9-NG1 | Ngọc | 9 | 3 | CŨ | Skill Sword Wave (SKL-11) |
| W9-NG2 | Ngọc | 9 | 3 | CŨ | Skill Firebomb (SKL-12), vùng cháy tick BLAST |
| W9-NG3 | Ngọc | 9 | 3 | CŨ | Hệ kháng boss DMG-01..05, miễn taunt/knockback (AI-06, BOSS-01), hiển thị IMMUNE và RESIST |
| W9-NG4 | Ngọc | 9 | 3 | CŨ | Khóa input BOSS_INTRO (BOSS-18), test đơn vị skill |
| W9-NG5 | Ngọc | 9 | 5 | MỚI | Trạng thái Slow và DoT trên Enemy và Bulwark (Frost áp được lên boss, ngoại lệ BOSS-01; Bu... |
| W9-NG6 | Ngọc | 9 | 4 | MỚI | WeaponData và trạng thái vũ khí |
| W9-NG7 | Ngọc | 9 | 7 | MỚI | Công cụ dịch bảng cân bằng, phần lõi |
| W9-KT1 | Kiệt | 9 | 4 | CŨ | Pha giáp Bulwark (BOSS-09..14) |
| W9-KT2 | Kiệt | 9 | 4 | CŨ-SỬA | BOSS_INTRO và BOSS_COMBAT, spawn boss và hộ tống (SPN-09..12, BOSS-02, 05, 17..21) |
| W9-KT3 | Kiệt | 9 | 2 | CŨ-SỬA | Thêm state REWARD_PICK vào Wave FSM (RWP-01, 06) |
| W9-KT4 | Kiệt | 9 | 2 | CŨ-SỬA | Thang kẹt boss BOSS-04 rút gọn theo v2.0 (bậc 1 tính lại đường, bậc 2 phá Barricade hoặc t... |
| W9-KT5 | Kiệt | 9 | 8 | SỬA | Tắt va chạm giữa quân (kể cả boss và Brute) |
| W9-KT6 | Kiệt | 9 | 3 | MỚI + SỬA | Gom thay đổi dùng chung vào một PR |
| W9-KT7 | Kiệt | 9 | 5 | SỬA | Sửa các test hỏng do bỏ đếm ngược PREP, gọi sớm và va chạm giữa quân |
| W9-MH1 | Mạnh | 9 | 3 | CŨ | Đồng hồ boss và Cuồng nộ (BTM-01..04, ENR-01..06, EVB-17, BOSS-43, BOSS-27, 28) |
| W9-MH2 | Mạnh | 9 | 7 | CŨ-SỬA | Sửa Fortress bằng Mithril thay cho sửa bằng gold (MTH-01, 03..06, REP-07) |
| W9-MH3 | Mạnh | 9 | 2 | CŨ | Gold chỉ huy FRT-02 (hit_by_commander x1.25) và TGT-04 lọc miễn nhiễm |
| W9-MH4b | Mạnh | 9 | 2 | CŨ-SỬA | Nối REWARD_PICK end-to-end với màn của Khang (lượt chọn sinh tuần tự |
| W9-MH5 | Mạnh | 9 | 10 | MỚI | GRID-07 chặn kín đường |
| W9-MH6 | Mạnh | 9 | 4 | SỬA | Sửa các test hỏng do bỏ sửa Fortress bằng gold, còn 3 slot WALL, trần 3 công trình grid |
| W9-KH1 | Khang | 9 | 6 | CŨ | BossIntro SCR-10, HUD-02 thanh HP boss, HUD-04 đồng hồ Cuồng nộ |
| W9-KH2 | Khang | 9 | 6 | CŨ | Màn REWARD_PICK SCR-17 (3 thẻ, tooltip, Skip xác nhận, Esc chỉ mở Pause RWP-08; cắt Reroll... |
| W9-KH3 | Khang | 9 | 4 | MỚI | HUD theo v2.0 |
| W9-KH4 | Khang | 9 | 3 | SỬA | Panel Fortress viết lại (PNL-04, PNL-13) |
| W9-KH5 | Khang | 9 | 2 | SỬA | Sửa test giao diện hỏng do đổi HUD và panel Fortress (test_hud, test_hud_speed_heal, test_... |
| W9-KM1 | Kim | 9 | 3 | CŨ | Khung thẻ và hiệu ứng thẻ (SCR-17) |
| W9-KM2 | Kim | 9 | 3.5 | CŨ | VFX Whirlwind, Sword Wave, vùng cháy Firebomb |
| W9-KM3 | Kim | 9 | 3 | CŨ | Nhạc boss một bản, AUD-07 cue Cuồng nộ, FBK-07 chuyển pha |
| W9-KM4 | Kim | 9 | 2 | CŨ | VFX Cuồng nộ FBK-11 (lõi đỏ, hơi nước) |
| W9-KM5 | Kim | 9 | 1.5 | CŨ | Camera BOSS_INTRO tự lia tới boss trong 4 s game time, khóa dịch tay, hết intro về khung c... |
| W9-KM6 | Kim | 9 | 5 | SỬA | Hành lang 23.5 m phần 2 |
| W9-KM7 | Kim | 9 | 7 | SỬA + MỚI | GridData của map |
| W10-MH5 | Ngọc | 10 | 4 | CŨ + ĐỔI NGƯỜI (Mạnh sang Ngọc) | Trạm hồi lực phần 2 |
| W10-MH6 | Ngọc | 10 | 2 | CŨ + ĐỔI NGƯỜI (Mạnh sang Ngọc) | save.json thêm revision, updated_at, device_id (ACCT-04) |
| W10-NG1 | Ngọc | 10 | 5 | CŨ | Bị động và thẻ stat qua StatBlock |
| W10-NG10 | Ngọc | 10 | 8 | MỚI | Hazard Trial phía chỉ huy |
| W10-NG2 | Ngọc | 10 | 2 | CŨ | Kiểm skill với boss (kháng, cờ hit_by_commander) |
| W10-NG5 | Ngọc | 10 | 4 | CŨ-SỬA | Backend 2 |
| W10-NG6 | Ngọc | 10 | 7 | CŨ-SỬA | Backend 3 |
| W10-NG7 | Ngọc | 10 | 2 | CŨ | Nối lõi hồi máu với Trạm hồi lực thật (thay trạm giả), test HT1..HT5 và test input camera ... |
| W10-NG8 | Ngọc | 10 | 6 | MỚI | Công cụ dịch phần 2 |
| W10-NG9 | Ngọc | 10 | 5 | MỚI | Vũ khí qua StatBlock |
| W10-KT1 | Kiệt | 10 | 3 | CŨ-SỬA | RunLoading 8 bước (RUN-01, APL-01..04) trên RunState có sẵn; áp meta; gọi bước đặt trụ có ... |
| W10-KT2 | Kiệt | 10 | 4 | CŨ-SỬA | Kết thúc Run END-01..06, dữ liệu RunEnd (Cấp Chỉ huy, run_commander_kills, run_elapsed the... |
| W10-KT3 | Kiệt | 10 | 3 | CŨ | FRENZY, marker, giới hạn cứng (EN-01..03, WAVE-05, NAV-13, NAV-12) |
| W10-KT4 | Kiệt | 10 | 3 | MỚI | State HAZARD_TRIAL trong Wave FSM (PREP -> HAZARD_TRIAL -> PREP cùng wave, không hồi 35% v... |
| W10-KT5 | Kiệt | 10 | 8 | MỚI | Hazard Trial phía wave |
| W10-KT6 | Kiệt | 10 | 4 | MỚI | Hazard Trial AI trong phòng |
| W10-KT7 | Kiệt | 10 | 6 | MỚI | EnemyData thêm trait (is_stealth, explode_*, invuln_*, is_charger/impact_*, revive_*) và W... |
| W10-KT8 | Kiệt | 10 | 3 | MỚI | Sniper và Rider |
| W10-NG3 | Kiệt | 10 | 4 | CŨ-SỬA | Thang kẹt MVP (NAV-01..06, 08, 09, 14 log) theo v2.0 (không ally_phase; thêm NAV-15 bị chặ... |
| W10-NG4 | Kiệt | 10 | 2 | CŨ | TIME-06 tự hạ x2 + ALR-10 |
| W10-MH1 | Mạnh | 10 | 4 | CŨ | Save atomic + checksum + .bak (SAV-01..06, 10..14, 19; FLOW-01, 02, 07) |
| W10-MH10 | Mạnh | 10 | 6 | MỚI | Trụ có sẵn |
| W10-MH2 | Mạnh | 10 | 2 | CŨ-SỬA | SAV-04 nối SUMMARY, RunEnd, shop (và nối khi tutorial_done bật) |
| W10-MH3 | Mạnh | 10 | 3 | CŨ-SỬA | Thưởng boss BRW-01, 02, 04, 06, 07 theo WaveRewardTable (boss_gold = 100 x gold_mult(w), k... |
| W10-MH4 | Mạnh | 10 | 3 | CŨ-SỬA | MetaShop backend (SHP-05..09, 4 mục |
| W10-MH7 | Mạnh | 10 | 6 | MỚI + SỬA | Resource WaveRewardTable và sheet wave_rewards |
| W10-MH8 | Mạnh | 10 | 4 | MỚI | Soạn số liệu 36 cấp cho 4 loại tower trong sheet towers (giá, chỉ số, HP, kho Trạm hồi lực... |
| W10-MH9 | Mạnh | 10 | 10 | MỚI + SỬA | Tower cấp 1-36 cho cả 4 loại |
| W10-KH1 | Khang | 10 | 6 | CŨ-SỬA | HUD skill bar 3+3 ô (HUD-16), thanh XP và lượt chờ (HUD-15), biểu tượng Aura (HUD-17), XP-... |
| W10-KH2 | Khang | 10 | 3 | CŨ-SỬA | Nút nâng cấp xám 'Cần Chỉ huy cấp N' (UPG-06) áp ở cấp 13 và 25; panel Tower hiển thị cấp ... |
| W10-KH3 | Khang | 10 | 3 | CŨ | MetaShop SCR-04 (4 mục, SHP-05..09 UI) |
| W10-KH4 | Khang | 10 | 2 | CŨ-SỬA | Toast cảnh báo tối thiểu ALR-13..15, ALR-17, ALR-18; thêm ALR-19 (nhận vũ khí) và ALR-20 (... |
| W10-KH5 | Khang | 10 | 2 | CŨ | Màn Leaderboard SCR-19 |
| W10-KH6 | Khang | 10 | 2 | CŨ | Mục Tài khoản trong Settings và biểu tượng trạng thái đồng bộ ở MainMenu (GUEST, SYNCED, S... |
| W10-KH7 | Khang | 10 | 8 | MỚI | Hazard Trial |
| W10-KH8 | Khang | 10 | 3 | MỚI | UI chặn kín đường |
| W10-KH9 | Khang | 10 | 5 | MỚI | Panel vũ khí PNL-15 và ô vũ khí HUD-21 hoàn chỉnh |
| W10-KM10 | Kim | 10 | 5 | MỚI | Model 3 bậc cho tower, phần 1 (Arrow và Cannon, bậc 2 và 3) |
| W10-KM11 | Kim | 10 | 6 | MỚI | Model quân mới, phần 1 (Sniper, Rider, Assassin) |
| W10-KM3 | Kim | 10 | 2 | CŨ | Logic tab Âm thanh và Đồ họa (SET-01..04) |
| W10-KM4 | Kim | 10 | 2 | CŨ-SỬA | Nhạc theo state (COMBAT một lớp, sting SUMMARY, RunEnd); HAZARD_TRIAL dùng nhạc COMBAT (nh... |
| W10-KM6 | Kim | 10 | 3 | CŨ | VFX và SFX Trạm hồi lực |
| W10-KM8 | Kim | 10 | 6 | MỚI | Level |
| W10-KM9 | Kim | 10 | 3 | MỚI | Camera frame HAZARD_TRIAL (CAM-16) |
| W13-KM1 | Kim | 10 | 2 | DỜI | FBK-04, 05 (flash, đóng băng riêng thực thể) [dời từ tuần 13] |
| W13-KM3 | Kim | 10 | 2.5 | DỜI | FBK-08 tower bị phá (khói, mảnh vỡ, đống đổ nát) [dời từ tuần 13] |
| W11-MH5 | Ngọc | 11 | 2 | CŨ + ĐỔI NGƯỜI (Mạnh sang Ngọc) | Chính sách xung đột đơn giản |
| W11-MH6 | Ngọc | 11 | 2 | CŨ-SỬA + ĐỔI NGƯỜI (Mạnh sang Ngọc) | Hook nộp điểm ở RunEnd |
| W11-MH7 | Ngọc | 11 | 3 | CŨ-SỬA + ĐỔI NGƯỜI (Mạnh sang Ngọc) | Hồi quy Trạm hồi lực: HT6..HT12, SELL-05, giới hạn 2 trạm, nâng cấp tới cấp 36 |
| W11-NG10 | Ngọc | 11 | 4 | MỚI | Runner BAL tests/test_balance_config_runner.tscn (BAL-05, BL3, BL4) |
| W11-NG2 | Ngọc | 11 | 3 | CŨ-SỬA | Kiểm thử time scale toàn hệ thống x1/x2/x3 (gồm Hazard Trial và hiệu ứng vũ khí) |
| W11-NG3 | Ngọc | 11 | 5 | CŨ | Chạy lại test Combat, Skill, Boss (7.1, F1..F15, CM1..CM8, HT1..HT14); sửa lỗi |
| W11-NG5 | Ngọc | 11 | 4 | CŨ | Backend ổn định |
| W11-NG6 | Ngọc | 11 | 2 | CŨ | Hỗ trợ tích hợp client của Khang và Mạnh, sửa lỗi API trong ngày |
| W11-NG7 | Ngọc | 11 | 8 | MỚI | Hiệu ứng vũ khí |
| W11-NG8 | Ngọc | 11 | 6 | SỬA | Brute sửa |
| W11-NG9 | Ngọc | 11 | 8 | MỚI | Thắng ở victory_wave và endless |
| W11-KT1 | Kiệt | 11 | 4 | CŨ-SỬA | Cân bằng lần 1: XP, cổng bậc tower, Aura, gold chỉ huy (SCL-04, FRT) |
| W11-KT2 | Kiệt | 11 | 3 | CŨ | Edge case EN-05..15 (ưu tiên ca hay gặp) |
| W11-KT3 | Kiệt | 11 | 2 | CŨ | Hồi quy wave 1-20 có skill |
| W11-KT4 | Kiệt | 11 | 2 | CŨ-SỬA | Chỉnh Resource theo log cân bằng, ghi lại tham số (chỉnh trong balance.xlsx rồi chạy công ... |
| W11-KT5 | Kiệt | 11 | 3 | CŨ-SỬA | Boss điều hướng agent lớn (BOSS-03), đứng tại boss_melee_point đánh Stomp vào Fortress (BO... |
| W11-KT6 | Kiệt | 11 | 2 | CŨ | Hồi quy Trạm hồi lực: quân nhắm trạm theo ETG, slot đánh, cân bằng sơ bộ (HLT-09, HLT-10) |
| W11-KT7 | Kiệt | 11 | 9 | MỚI | Assassin (tower không chọn làm mục tiêu và không tính là 'quân trong tầm', nổ Cannon vẫn t... |
| W11-KT8 | Kiệt | 11 | 8 | MỚI | Suicide Squad và Captain |
| W11-KT9 | Kiệt | 11 | 8 | MỚI + SỬA | Spawner đọc WaveScript wave 1-30 (thành phần cố định, hộ tống, hp/dmg/speed_mult và spawn_... |
| W11-NG4 | Kiệt | 11 | 2 | CŨ-SỬA | Script hoặc bot 20 wave ở x3 nhiều seed (NAV-14); bot AFK vs bot Frontline cho F13; mở rộn... |
| W11-MH1 | Mạnh | 11 | 4 | CŨ | Khôi phục run gián đoạn (3.12.4, PRS-05, FLOW-03) |
| W11-MH10 | Mạnh | 11 | 4 | MỚI | Tua lại sheet towers/economy sau chạy thử wave 1-30 |
| W11-MH11 | Mạnh | 11 | 7 | MỚI | Kịch bản wave 1-30 trong sheet waves (loại quân, số lượng, hộ tống, spawn_duration, hệ số)... |
| W11-MH2 | Mạnh | 11 | 1 | CŨ | SAV-09 (cắt tab Dữ liệu và Xóa tiến trình SAV-16, đưa vào backlog) |
| W11-MH3 | Mạnh | 11 | 3 | CŨ | Test ACP-05 (rò rỉ), ACP-06 (save < 50 ms), hồi quy economy và save |
| W11-MH4 | Mạnh | 11 | 3 | CŨ-SỬA | Hồi quy tower (cổng bậc, Aura, xây lại, 36 cấp, trụ có sẵn) |
| W11-MH8 | Mạnh | 11 | 5 | MỚI | Tower 3 bậc model trong code (TWR-17) |
| W11-MH9 | Mạnh | 11 | 4 | MỚI | Rơi vũ khí từ boss wave 5/10/15/20/25 (RNG riêng hash(run_seed,'weapon',wave), không trùng... |
| W11-KH1 | Khang | 11 | 4 | CŨ-SỬA | RunEnd SCR-11 (PRS-06) và RunEnd endless SCR-21 ('Sống sót đến wave N') |
| W11-KH2 | Khang | 11 | 2 | CŨ | PauseMenu hoàn chỉnh (FLOW-04, 05) |
| W11-KH3 | Khang | 11 | 3 | CŨ | Settings tabs |
| W11-KH4 | Khang | 11 | 6 | CŨ-SỬA | SyncService thật |
| W11-KH6 | Khang | 11 | 3 | MỚI | Màn thắng SCR-20 (một nút 'Chơi tiếp', không đếm ngược, game dừng) |
| W11-KH7 | Khang | 11 | 5 | MỚI | Biểu tượng trait quân (tàng hình, tự nổ, bất tử một lần, hồi sinh, ủi thẳng) kèm chữ trong... |
| W11-KH8 | Khang | 11 | 2 | SỬA | SummaryPanel |
| W11-NG1 | Khang | 11 | 10 | CŨ-SỬA + MỚI + ĐỔI NGƯỜI (Ngọc sang Khang) | Tutorial một lần theo tài khoản (đổi người |
| W13-KH1 | Khang | 11 | 3 | DỜI | Kích hoạt cảnh báo T1/T2 (ALR-01..04, 07, 09, 11) [dời từ tuần 13; ALR-08 đã bỏ ở v2.0] |
| W11-KM1 | Kim | 11 | 2 | CŨ | Accessibility ACC-05, 06 và kiểm UI-05 (gồm biểu tượng trait quân) |
| W11-KM10 | Kim | 11 | 4 | MỚI | Model 3 bậc cho tower, phần 2 (Barricade và Trạm hồi lực, bậc 2 và 3) |
| W11-KM2 | Kim | 11 | 3 | CŨ-SỬA | Âm thanh hoàn chỉnh (AUD-06..09, -14 LUFS nhạc, -12 LUFS SFX); sting thắng và sting RunEnd... |
| W11-KM4 | Kim | 11 | 3 | CŨ | Tổ chức playtest >= 5 người ngoài nhóm trên bản có Hazard, vũ khí, quân mới, biểu mẫu thu ... |
| W11-KM5 | Kim | 11 | 2 | CŨ | Sửa lỗi Art/Audio từ playtest |
| W11-KM6 | Kim | 11 | 1.5 | CŨ-SỬA | Kiểm navmesh agent lớn và boss_melee_point trên hành lang mới với 3 công trình grid |
| W11-KM7 | Kim | 11 | 3 | CŨ | Chỉnh camera cùng Level trên map thật |
| W11-KM8 | Kim | 11 | 8 | MỚI | Model vũ khí và VFX |
| W11-KM9 | Kim | 11 | 6 | MỚI | Model quân mới, phần 2 (Suicide Squad, Captain, Knight, Undead) và hiệu ứng FBK-14 (giáp s... |
| W13-KM2 | Kim | 11 | 2 | DỜI | Vòng sáng slot ở PREP, tắt ở COMBAT (SLOT-06) [dời từ tuần 13] |
| W13-KM4 | Kim | 11 | 2 | DỜI | Preset hạt FBK-09 [dời từ tuần 13] |
| W12-NG1 | Ngọc | 12 | 6 | CŨ-SỬA | Build Windows; đo ACP-01..04 trên máy yếu nhất (70 quân, 6 tower, 200 projectile) |
| W12-NG2 | Ngọc | 12 | 3 | CŨ | Sửa lỗi hiệu năng và blocker (đệm) |
| W12-NG3 | Ngọc | 12 | 4 | CŨ-SỬA | Kiểm thử online AC1..AC8 cùng Khang, Kiệt, Mạnh; AC9 (lượt chơi thật nhanh nhất không bị t... |
| W12-NG4 | Ngọc | 12 | 3 | CŨ | Dự phòng demo: sao lưu backend, bản demo offline, kiểm tra backend trước ngày diễn tập |
| W12-NG5 | Ngọc | 12 | 2 | MỚI | Chạy lại test WP1..WP8 và HZ1..HZ12 trên bản cuối |
| W12-KT1 | Kiệt | 12 | 6 | CŨ-SỬA | Cân bằng cuối trong balance.xlsx |
| W12-KT2 | Kiệt | 12 | 3 | CŨ | Sửa lỗi Enemy/Boss/quân mới (đệm) |
| W12-KT3 | Kiệt | 12 | 4 | CŨ-SỬA | Checklist 7.1 nhóm Enemy, Boss, Skill + NE1..NE8 |
| W12-KT5 | Kiệt | 12 | 3 | CŨ | Kiểm thử AC6..AC8: thứ tự xếp hạng, luật nộp điểm, kiểm tra ở máy chủ |
| W12-KT6 | Kiệt | 12 | 2 | CŨ | Đệm sửa lỗi tích hợp và cân bằng theo playtest vòng 2 |
| W12-MH1 | Mạnh | 12 | 6 | CŨ-SỬA | Hồi quy tower, economy, save; cân bằng kinh tế cuối trong balance.xlsx (nhịp danh vọng 3.9... |
| W12-MH3 | Mạnh | 12 | 3 | CŨ | Sửa blocker (đệm) |
| W12-MH4 | Mạnh | 12 | 7 | CŨ-SỬA | Kiểm thử AC3, AC4 và hồi quy Trạm hồi lực, SELL-05; chạy BL1..BL4, VC1..VC5, TU1..TU4 |
| W12-MH5 | Mạnh | 12 | 2 | MỚI | Chạy lại runner BAL sau mọi lần chỉnh bảng cuối; chốt balance.xlsx và bộ .tres sinh ra |
| W12-KH1 | Khang | 12 | 4 | CŨ-SỬA | QA giao diện tiếng Việt (dấu, tràn khung, LOC-03) gồm chuỗi v2.0; đo UI < 10% frame (ACP-0... |
| W12-KH2 | Khang | 12 | 3 | CŨ | Sửa lỗi UI (đệm) |
| W12-KH5 | Khang | 12 | 7 | CŨ | Hoàn thiện Leaderboard và Login, chạy AC tests phía giao diện, QA chữ tiếng Việt màn mới, ... |
| W12-KH6 | Khang | 12 | 2 | MỚI | Kiểm toàn bộ luồng người chơi mới |
| W13-KH2 | Khang | 12 | 2 | DỜI | Slow motion 0.2x cuối run trên hoạt cảnh RunEnd (FBK-10) [dời từ tuần 13] |
| W12-KM2 | Kim | 12 | 2 | CŨ | Ghi credit và license mọi asset ngoài (gồm model dùng lại) |
| W12-KM3 | Kim | 12 | 7 | DỜI | Skin UI (menu, shop, RunEnd, màn thắng), màn Splash và Loading, skin Login và Leaderboard ... |
| W12-KM5 | Kim | 12 | 5 | CŨ | Playtest vòng 2 có online, ghi số liệu |
| W12-KM6 | Kim | 12 | 4 | CŨ | Đệm polish camera, VFX trạm, skin UI mới, sửa lỗi hiển thị |
| W13-NG1 | Ngọc | 13 | 4 | CŨ | Báo cáo phần Player & Combat |
| W13-NG2 | Ngọc | 13 | 4 | CŨ | Đệm sửa lỗi Combat, Skill, hiệu năng |
| W13-NG3 | Ngọc | 13 | 4 | CŨ | Hồi quy online và chạy thử toàn bộ demo từ máy sạch |
| W12-KT4 | Kiệt | 13 | 4 | DỜI | Báo cáo phần Enemy và Wave [dời] |
| W13-KT1 | Kiệt | 13 | 4 | CŨ | Đệm sửa lỗi Enemy, Boss, cân bằng theo playtest lần cuối |
| W13-KT2 | Kiệt | 13 | 4 | CŨ | Chạy lại checklist 7.1 nhóm Enemy, Boss |
| W12-MH2 | Mạnh | 13 | 4 | DỜI | Báo cáo phần Tower, Economy, Save [dời] |
| W13-MH1 | Mạnh | 13 | 4 | CŨ | Đệm sửa lỗi Tower, Economy, Save; hồi quy lần cuối |
| W13-MH2 | Mạnh | 13 | 4 | CŨ | Hồi quy cuối online và kinh tế |
| W12-KH3 | Khang | 13 | 4 | DỜI | Tổng hợp báo cáo (5 người) [dời] |
| W12-KH4 | Khang | 13 | 2 | DỜI | Báo cáo phần UI/Meta [dời] |
| W13-KH3 | Khang | 13 | 3 | CŨ | Đệm sửa lỗi UI |
| W13-KH4 | Khang | 13 | 3 | CŨ | QA giao diện lần cuối sau đóng băng |
| W12-KM1 | Kim | 13 | 6 | DỜI | Quay video demo, ảnh chụp (có Hazard Trial, vũ khí, thắng và endless) [dời] |
| W12-KM4 | Kim | 13 | 3 | DỜI | Báo cáo phần Art/Audio [dời] |
| W13-KM5 | Kim | 13 | 3 | CŨ | Đệm sửa lỗi Art/Audio |

### Tuần 8 bổ sung (6-8/11)

#### Ngọc (Player & Combat), tuần 8, 8h

##### W8B-NG1
- Người: Ngọc
- Tuần: 8 | Giờ ước tính: 8 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Công thức sát thương chung DMG-06: dealt_mult cộng dồn, taken_mult nhân, làm tròn gần nhất, dot_remainder, resist; gom mọi nguồn sát thương của chỉ huy và tower vào một hàm; chừa hook trần sát thương theo nguồn (cho Hazard Trial)
- Nghiệm thu: Test GUT: dealt +20% và +10% ra x1.3; taken nhân; tick DoT 5 lần cộng đúng tổng nhờ dot_remainder; kháng 0 ra IMMUNE; hook trần có thể bật/tắt
- Tệp liên quan: common/damage_info.gd, common/health_component.gd, entities/commander/commander.gd (_execute_sword_strike), entities/enemy/enemy.gd, entities/tower/tower.gd
- ID SRS: DMG-06, HZT-05 (hook)
- Cần xong trước: không

#### Kiệt (Enemy & Wave), tuần 8, 10h

##### W8B-KT1
- Người: Kiệt
- Tuần: 8 | Giờ ước tính: 6 | Nguồn: MỚI (kéo sớm từ W10-KT1)
- Trạng thái: Xong
- Việc: RunConfig và RunState khung: lớp RunState với wave_index, gold, mithril, owned_weapons, equipped_weapon, chain_cd, hazard_used, hazard_session, victory_reached, run_elapsed (RUN-02), is_starter theo slot; không ghi đĩa; WaveManager và GoldManager đọc ghi qua RunState
- Nghiệm thu: Mọi trường có giá trị mặc định đúng mục 3.2.2; không trường nào được ghi xuống đĩa (RUN-01); các task tuần 9-11 cắm vào RunState thay vì tự giữ biến
- Tệp liên quan: mới: systems/run/run_state.gd, run_config.gd; systems/wave/wave_manager.gd, systems/economy/gold_manager.gd; autoload/game_state.gd (abandon_run TODO)
- ID SRS: 3.2.2, RUN-01, RUN-02
- Cần xong trước: không

##### W8B-KT2
- Người: Kiệt
- Tuần: 8 | Giờ ước tính: 4 | Nguồn: SỬA
- Trạng thái: Xong
- Việc: Bỏ đếm ngược PREP và gọi wave sớm phía wave: xóa prep_timer, get_prep_time, prep_timer_changed, call_early, early_call_bonus, tham số prep_time_* và early_call_*; PREP chỉ kết thúc khi nhận wave_start_requested; bỏ early_call_bonus khỏi summary_data
- Nghiệm thu: PREP không tự kết thúc dù để yên 10 phút; phím G không làm gì; wave_cleared/summary_data không còn early_call_bonus
- Tệp liên quan: systems/wave/wave_manager.gd (prep_timer, call_early, _early_call_bonus), autoload/game_config.gd (prep_time_*, early_call_*), autoload/event_bus.gd (prep_timer_changed, early_call_requested)
- ID SRS: WAVE-11, WAVE-07 (Phụ lục E)
- Cần xong trước: W8B-KH1 (cùng PR hoặc liền kề)

#### Mạnh (Tower & Build), tuần 8, 9h

##### W8B-MH1
- Người: Mạnh
- Tuần: 8 | Giờ ước tính: 6 | Nguồn: MỚI
- Trạng thái: Xong
- Việc: Dựng balance/balance.xlsx khung: 7 sheet (character, skills, towers, weapons, enemies, waves, wave_rewards) với tên cột cố định; điền số khởi điểm lấy từ các .tres v1.9, tower 36 cấp theo công thức tăng đơn giản, wave 1-30 bằng công thức scale v1.9
- Nghiệm thu: Mở bằng Excel được; mỗi sheet đủ cột theo mục 6.10; towers đủ 4 loại x 36 dòng; waves đủ 30 dòng; không ô trống
- Tệp liên quan: mới: balance/balance.xlsx; nguồn số: data/config/commander_stats.tres, data/skills/*, data/towers/*, data/enemies/*, data/config/scale_config.tres
- ID SRS: BAL-01, DAT-06
- Cần xong trước: không

##### W8B-MH2
- Người: Mạnh
- Tuần: 8 | Giờ ước tính: 3 | Nguồn: SỬA
- Trạng thái: Xong
- Việc: Đổi hằng số nền: starting_gold 150 sang 0, max_ground_buildings 8 sang 3, thêm grid_cell_gap 0.5, thêm tower_max_level 36 và tower_tier2/3_level 13/25, đổi tower_gate_lv2/3 sang tower_gate_tier2/3 áp ở cấp 13 và 25; sửa các test dựa vào giá trị cũ
- Nghiệm thu: Run mới bắt đầu 0 gold; xây công trình thứ 4 trên grid bị từ chối với lý do 'Đã đủ 3 công trình'; nâng lên cấp 13 cần Chỉ huy cấp 4
- Tệp liên quan: autoload/game_config.gd (starting_gold, max_ground_buildings, tower_gate_lv2/lv3), systems/build/build_service.gd (get_upgrade_required_level), levels/corridor/grid_data.gd (cell_position)
- ID SRS: GLD-06, GRID-04, BLD-08, FRT-03, UPG-06
- Cần xong trước: không

#### Khang (UI/UX & Meta), tuần 8, 7h

##### W8B-KH1
- Người: Khang
- Tuần: 8 | Giờ ước tính: 7 | Nguồn: MỚI + SỬA
- Trạng thái: Xong
- Việc: Nút 'Bắt đầu wave' (HUD-19) thay nút gọi wave sớm: phát wave_start_requested, ghi 'Bắt đầu wave boss' ở wave boss, xám khi Pause hoặc có hộp thoại giao dịch; dọn UI cũ: call_wave_button, EarlyRow ở SummaryPanel, đồng hồ đếm ngược ở wave_counter, action call_wave, chuỗi hud.call_wave*
- Nghiệm thu: Bấm nút thì sang COMBAT hoặc BOSS_INTRO; không có phím tắt; không còn chuỗi hoặc node gọi wave sớm; SummaryPanel không còn dòng thưởng gọi sớm
- Tệp liên quan: ui/hud/parts/call_wave_button.*, ui/hud/hud.tscn, ui/hud/parts/wave_counter.*, ui/screens/summary_panel.gd (EarlyRow), ui/panels/panel_host.gd:41, project.godot (call_wave), data/locale/strings.csv
- ID SRS: WAVE-11, HUD-19, EVB-38
- Cần xong trước: W8B-KT2

#### Kim (Art/Level/Audio), tuần 8, 8h

##### W8B-KM1
- Người: Kim
- Tuần: 8 | Giờ ước tính: 8 | Nguồn: SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Mở rộng hành lang 16 m lên 23.5 m, phần 1: sàn và tường, spawn_zone, return_zone, lane_curve, command_post, navmesh thường và agent lớn (bake lại)
- Nghiệm thu: Quân đi từ spawn tới cổng không kẹt trên hành lang mới; chỉ huy đi được trọn bề ngang; wave 1 chơi được trên map mới
- Tệp liên quan: levels/corridor/level.tscn (Floor, WallBack/Front, SpawnZone, ReturnZone, LaneCurve, CommandPost, NavigationRegion3D x2)
- ID SRS: Phụ lục C #61
- Cần xong trước: không

### Tuần 9 (9-15/11)

#### Ngọc (Player & Combat), tuần 9, 30h

##### W9-NG1
- Người: Ngọc
- Tuần: 9 | Giờ ước tính: 3 | Nguồn: CŨ
- Trạng thái: Xong
- Việc: Skill Sword Wave (SKL-11)
- Nghiệm thu: 18 SLASH, rộng 3 m, trúng mọi quân; đi qua pipeline sát thương DMG-06
- Cần xong trước: W8-NG1, W8B-NG1

##### W9-NG2
- Người: Ngọc
- Tuần: 9 | Giờ ước tính: 3 | Nguồn: CŨ
- Trạng thái: Xong
- Việc: Skill Firebomb (SKL-12), vùng cháy tick BLAST
- Nghiệm thu: 6/s, 2.5 m, 4 s; tick bật cờ hit_by_commander; tick đi qua pipeline DMG-06 (sau này kích hoạt hiệu ứng vũ khí và chịu trần Hazard)
- Cần xong trước: W8-KT2, W8B-NG1

##### W9-NG3
- Người: Ngọc
- Tuần: 9 | Giờ ước tính: 3 | Nguồn: CŨ
- Trạng thái: Xong
- Việc: Hệ kháng boss DMG-01..05, miễn taunt/knockback (AI-06, BOSS-01), hiển thị IMMUNE và RESIST
- Nghiệm thu: Bulwark pha 1: Arrow không bắn, Cannon 100%, kiếm 60%
- Cần xong trước: W8-NG2, W8B-NG1

##### W9-NG4
- Người: Ngọc
- Tuần: 9 | Giờ ước tính: 3 | Nguồn: CŨ
- Trạng thái: Xong
- Việc: Khóa input BOSS_INTRO (BOSS-18), test đơn vị skill
- Nghiệm thu: Test GUT cho Whirlwind, Sword Wave, Firebomb
- Cần xong trước: W9-NG1, W9-NG2

##### W9-NG5
- Người: Ngọc
- Tuần: 9 | Giờ ước tính: 5 | Nguồn: MỚI
- Trạng thái: Xong
- Việc: Trạng thái Slow và DoT trên Enemy và Bulwark (Frost áp được lên boss, ngoại lệ BOSS-01; Burn tick qua dot_remainder)
- Nghiệm thu: Slow 20% 3 s làm mới không cộng dồn; DoT 5 tick đúng tổng; Bulwark nhận Slow nhưng vẫn miễn taunt/knockback
- Tệp liên quan: entities/enemy/enemy.gd, entities/enemy/bulwark.gd, common/health_component.gd
- ID SRS: WPN-05, WPN-06, WPN-08, BOSS-01
- Cần xong trước: W8B-NG1, W9-NG3

##### W9-NG6
- Người: Ngọc
- Tuần: 9 | Giờ ước tính: 4 | Nguồn: MỚI
- Trạng thái: Xong
- Việc: WeaponData và trạng thái vũ khí: Resource WeaponData (range_mult, effect_id, tham số), owned_weapons và equipped_weapon trong RunState (kiếm thường mặc định), tín hiệu weapon_equipped, đổi vũ khí chỉ ở PREP
- Nghiệm thu: Đầu run chỉ có kiếm thường; trao thử vũ khí bằng debug thì equip được ở PREP, bị từ chối ở COMBAT và HAZARD_TRIAL
- Tệp liên quan: mới: common/weapon_data.gd, data/weapons/; entities/commander/commander.gd; common/run_skill_state.gd (nơi lưu trạng thái run)
- ID SRS: WPN-01, WPN-02, WPN-03, EVB-43
- Cần xong trước: W8B-KT1

##### W9-NG7
- Người: Ngọc
- Tuần: 9 | Giờ ước tính: 7 | Nguồn: MỚI
- Trạng thái: Xong
- Ghi chú: sau khi W9-NG1/NG2 (sword_wave, firebomb) và W9-NG6 (data/weapons) vào main, chạy lại `python tools/balance/generate.py` để sinh các .tres đó từ bảng
- Việc: Công cụ dịch bảng cân bằng, phần lõi: script Python (openpyxl) đọc balance.xlsx, sinh CharacterStats, SkillData, TowerData và TowerLevelData x36, EnemyData; dòng chú thích 'sinh tự động', thứ tự khóa ổn định
- Nghiệm thu: Chạy hai lần cho bộ .tres giống hệt; game nạp được các .tres sinh ra; diff git gọn; XpTracker đọc xp_base và xp_step từ CharacterStats (hiện nằm ở GameConfig)
- Tệp liên quan: mới: tools/balance/*.py; common/csv_loader.gd (không dùng, có thể xóa); data/enemies/enemies.csv; autoload/game_config.gd (xp_base, xp_step)
- ID SRS: BAL-02, BAL-03, DAT-07, BL1
- Cần xong trước: W8B-MH1, W9-KT5

##### W9-MH4a
- Người: Ngọc
- Tuần: 9 | Giờ ước tính: 2 | Nguồn: CŨ + ĐỔI NGƯỜI (Mạnh sang Ngọc)
- Trạng thái: Xong
- Việc: apply_pick: ghi vào RunSkillState, gọi StatBlock, phát skill_slots_changed
- Nghiệm thu: Chọn thẻ vào đúng ô, level tăng đúng
- Cần xong trước: W9-KT3

#### Kiệt (Enemy & Wave), tuần 9, 28h

##### W9-KT1
- Người: Kiệt
- Tuần: 9 | Giờ ước tính: 4 | Nguồn: CŨ
- Trạng thái: Xong
- Việc: Pha giáp Bulwark (BOSS-09..14)
- Nghiệm thu: Chuyển pha đúng một lần, sát thương dư bị bỏ
- Cần xong trước: W9-NG3, W8-KT2

##### W9-KT2
- Người: Kiệt
- Tuần: 9 | Giờ ước tính: 4 | Nguồn: CŨ-SỬA
- Trạng thái: Xong
- Việc: BOSS_INTRO và BOSS_COMBAT, spawn boss và hộ tống (SPN-09..12, BOSS-02, 05, 17..21)
- Nghiệm thu: Boss spawn ở giây 0 BOSS_COMBAT; hộ tống 0.5 x budget; mỗi wave boss có ít nhất 1 hộ tống
- Cần xong trước: W8-KT3

##### W9-KT3
- Người: Kiệt
- Tuần: 9 | Giờ ước tính: 2 | Nguồn: CŨ-SỬA
- Trạng thái: Xong
- Việc: Thêm state REWARD_PICK vào Wave FSM (RWP-01, 06)
- Nghiệm thu: Vào REWARD_PICK khi pending_picks > 0, bỏ qua khi 0; chừa chỗ cho bước màn thắng (WAVE-13)
- Cần xong trước: W9-NG3, W8-KT3

##### W9-KT4
- Người: Kiệt
- Tuần: 9 | Giờ ước tính: 2 | Nguồn: CŨ-SỬA
- Trạng thái: Xong
- Việc: Thang kẹt boss BOSS-04 rút gọn theo v2.0 (bậc 1 tính lại đường, bậc 2 phá Barricade hoặc tower trên grid, bậc 3 hop; bỏ bậc xuyên hộ tống)
- Nghiệm thu: Boss không bao giờ bị recycle hoặc cull
- ID SRS: BOSS-04
- Cần xong trước: W9-KT2

##### W9-KT5
- Người: Kiệt
- Tuần: 9 | Giờ ước tính: 8 | Nguồn: SỬA
- Trạng thái: Xong
- Việc: Tắt va chạm giữa quân (kể cả boss và Brute): bỏ avoidance và _apply_avoidance, đổi collision layer/mask giữa quân, tách bán kính agent khỏi avoid_radius, xóa avoid_radius/avoid_priority khỏi EnemyData, BossData và bảng; bỏ ally_phase ở NAV-06
- Nghiệm thu: 20 Grunt đi qua cùng một điểm không đẩy nhau; vẫn chỉ 12 con đánh Fortress (slot đánh giữ nguyên); không lỗi console
- Tệp liên quan: entities/enemy/enemy.gd (nav.avoidance_enabled, _apply_avoidance, nav.radius = avoid_radius), enemy.tscn, common/enemy_data.gd, common/boss_data.gd, data/enemies/*, data/bosses/bulwark_boss.tres, autoload/game_config.gd (ally_phase_time)
- ID SRS: EN-16, NAV-02, NAV-06
- Cần xong trước: W9-KT2

##### W9-KT6
- Người: Kiệt
- Tuần: 9 | Giờ ước tính: 3 | Nguồn: MỚI + SỬA
- Trạng thái: Xong
- Việc: Gom thay đổi dùng chung vào một PR: GameConfig (victory_wave, starter_*_slot, starter_sell_unlock_wave, wave_max_enemy_types, weapon_drop_waves, hazard_*, path_check_min_width, boss_point_clear_radius, lbd_elapsed_tolerance), EventBus (EVB-35, EVB-38..46; bỏ tín hiệu cũ), InputMap (thêm hazard_enter, bỏ call_wave)
- Nghiệm thu: Mọi tham số và tín hiệu v2.0 có sẵn để các task sau cắm vào; không còn tham chiếu tới tín hiệu đã bỏ
- Tệp liên quan: autoload/game_config.gd, autoload/event_bus.gd, project.godot (InputMap), data/locale/strings.csv
- ID SRS: 6.3, 6.9, INP-01
- Cần xong trước: W8B-KT2

##### W9-KT7
- Người: Kiệt
- Tuần: 9 | Giờ ước tính: 5 | Nguồn: SỬA
- Trạng thái: Xong
- Việc: Sửa các test hỏng do bỏ đếm ngược PREP, gọi sớm và va chạm giữa quân: test_wave_fsm_runner, test_wave_rewards_runner, test_combat_runner, test_summary_panel, test_hud, test_playtest_arrow/barricade/bulwark_and_crowd/cannon/wave, test_attack_slot_runner, test_barricade_runner, test_bulwark_and_crd_runner, test_phase1_phase2_runner
- Nghiệm thu: Toàn bộ runner liệt kê chạy lại đạt trên hành vi mới; không còn test nào chờ prep_timer hay early_call
- Tệp liên quan: tests/ (liệt kê trong mô tả task)
- ID SRS: mục 7.1 (test 9, 8)
- Cần xong trước: W9-KT5, W8B-KT2

#### Mạnh (Tower & Build), tuần 9, 28h

##### W9-MH1
- Người: Mạnh
- Tuần: 9 | Giờ ước tính: 3 | Nguồn: CŨ
- Trạng thái: Xong
- Việc: Đồng hồ boss và Cuồng nộ (BTM-01..04, ENR-01..06, EVB-17, BOSS-43, BOSS-27, 28)
- Nghiệm thu: Hết giờ thì boss_enraged một lần, x1.3, x1.3, x1.5; boss chết cùng frame T=0 không Cuồng nộ
- Cần xong trước: W9-KT2, W8-MH3

##### W9-MH2
- Người: Mạnh
- Tuần: 9 | Giờ ước tính: 7 | Nguồn: CŨ-SỬA
- Trạng thái: Xong
- Việc: Sửa Fortress bằng Mithril thay cho sửa bằng gold (MTH-01, 03..06, REP-07): bỏ Fortress.quote_repair/repair, BuildService.repair, repair_gold_per_pct và repair_step_*; thêm mithril_repair_pct 0.20; nguồn fortress_repaired đổi sang MITHRIL; uy tín PRS-01..04
- Nghiệm thu: Mỗi viên Mithril hồi 20% max hiệu dụng, kẹp max, từ chối khi đầy máu; mithril = 0 thì từ chối; giao dịch nguyên tử; Emergency repair không đổi; cấp Mithril bằng debug để thử
- Tệp liên quan: entities/fortress/fortress.gd (quote_repair, repair), systems/build/build_service.gd (repair, _min_repair_cost), common/fortress_stats.gd, data/config/fortress_stats.tres
- ID SRS: MTH-01..06, REP-07, PRS-01..04
- Cần xong trước: W8B-KT1, W9-MH1

##### W9-MH3
- Người: Mạnh
- Tuần: 9 | Giờ ước tính: 2 | Nguồn: CŨ
- Trạng thái: Xong
- Việc: Gold chỉ huy FRT-02 (hit_by_commander x1.25) và TGT-04 lọc miễn nhiễm
- Nghiệm thu: Grunt wave 1 có cờ cho 5 gold base, không cờ 4
- Cần xong trước: W8-MH3

##### W9-MH4b
- Người: Mạnh
- Tuần: 9 | Giờ ước tính: 2 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Nối REWARD_PICK end-to-end với màn của Khang (lượt chọn sinh tuần tự: lượt sau chỉ sinh sau khi lượt trước đã phát reward_picked)
- Nghiệm thu: Nhặt được 3 skill chủ động từ XP thật
- ID SRS: RWP-01
- Cần xong trước: W9-KH2, W9-MH4a

##### W9-MH5
- Người: Mạnh
- Tuần: 9 | Giờ ước tính: 10 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: GRID-07 chặn kín đường: hàm thuần trên lưới GridData (ô OCCUPIED, RUINED và ô định xây là vật cản; đường rộng >= 3.2 m; kiểm cả đường tới cổng Fortress và tới boss_melee_point), BuildService từ chối BLOCKS_PATH không trừ gold, kiểm lại lúc xác nhận
- Nghiệm thu: Bố cục thử mất đường tới cổng hoặc tới boss_melee_point thì bị từ chối, gold không đổi; xây lại cùng chỗ không bị kiểm; ô khác vẫn xây được
- Tệp liên quan: levels/corridor/grid_data.gd, systems/build/build_service.gd (_do_build), systems/build/slot_manager.gd
- ID SRS: GRID-07, BLD-10, BOSS-03
- Cần xong trước: W9-KM7

##### W9-MH6
- Người: Mạnh
- Tuần: 9 | Giờ ước tính: 4 | Nguồn: SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Sửa các test hỏng do bỏ sửa Fortress bằng gold, còn 3 slot WALL, trần 3 công trình grid: test_build_flow, test_fortress_repair_runner, test_fortress_runner, test_fortress_panel, test_build_service_runner, test_perf_slice, test_slot_zone_runner, test_targeting_runner
- Nghiệm thu: Các runner liệt kê chạy lại đạt; test sửa Fortress đổi sang Mithril; test slot dùng W1-W3
- Tệp liên quan: tests/ (liệt kê trong mô tả task)
- ID SRS: mục 7.1 (test Fortress, tower)
- Cần xong trước: W9-MH2, W9-KM6

#### Khang (UI/UX & Meta), tuần 9, 21h

##### W9-KH1
- Người: Khang
- Tuần: 9 | Giờ ước tính: 6 | Nguồn: CŨ
- Trạng thái: Xong
- Việc: BossIntro SCR-10, HUD-02 thanh HP boss, HUD-04 đồng hồ Cuồng nộ
- Nghiệm thu: Thanh hai đoạn, nhãn CUỒNG NỘ có biểu tượng
- Cần xong trước: W9-KT2, W9-MH1

##### W9-KH2
- Người: Khang
- Tuần: 9 | Giờ ước tính: 6 | Nguồn: CŨ
- Trạng thái: Xong
- Việc: Màn REWARD_PICK SCR-17 (3 thẻ, tooltip, Skip xác nhận, Esc chỉ mở Pause RWP-08; cắt Reroll, dòng giải thích tĩnh)
- Nghiệm thu: Chọn bằng chuột; Skip hỏi xác nhận
- Cần xong trước: W9-KT3, W8-MH1

##### W9-KH3
- Người: Khang
- Tuần: 9 | Giờ ước tính: 4 | Nguồn: MỚI
- Trạng thái: Xong
- Việc: HUD theo v2.0: wave_counter bỏ đếm ngược, thêm khóa state HAZARD_TRIAL, hiển thị 'Đợt N / 30' và nhãn 'Endless'; ô Mithril cạnh gold (HUD-20) kèm gợi ý khi Fortress thiếu máu
- Nghiệm thu: Nhận Mithril thì ô viền sáng 0.3 s; không dùng màu làm kênh duy nhất (UI-05)
- Tệp liên quan: ui/hud/parts/wave_counter.gd, ui/hud/parts/gold_label.*, ui/hud/hud.tscn
- ID SRS: HUD-20, 4.1.3
- Cần xong trước: W9-MH2, W8B-KT1

##### W9-KH4
- Người: Khang
- Tuần: 9 | Giờ ước tính: 3 | Nguồn: SỬA
- Trạng thái: Xong
- Việc: Panel Fortress viết lại (PNL-04, PNL-13): một nút 'Sửa bằng Mithril (+20%)', tooltip 'Hồi thừa', xám kèm lý do khi đầy máu hoặc mithril = 0; bỏ nút +10%, +25%, đầy; sửa chuỗi panel.fortress.*
- Nghiệm thu: Nút xám đúng lý do; trạng thái Emergency repair n/3 vẫn hiển thị; panel dùng được ở cả hai chế độ ở PREP (CMD-05)
- Tệp liên quan: ui/panels/fortress_panel.*, data/locale/strings.csv (panel.fortress.*)
- ID SRS: PNL-04, PNL-13
- Cần xong trước: W9-MH2

##### W9-KH5
- Người: Khang
- Tuần: 9 | Giờ ước tính: 2 | Nguồn: SỬA
- Trạng thái: Xong
- Việc: Sửa test giao diện hỏng do đổi HUD và panel Fortress (test_hud, test_hud_speed_heal, test_summary_panel, test_fortress_panel) và thêm test cho nút Bắt đầu wave
- Nghiệm thu: Test HUD chạy lại đạt; nút Bắt đầu wave xám đúng ba lý do
- Tệp liên quan: tests/test_hud*.gd, tests/test_summary_panel.gd, tests/test_fortress_panel.gd
- ID SRS: HUD-19
- Cần xong trước: W9-KH3, W9-KH4

#### Kim (Art/Level/Audio), tuần 9, 25h

##### W9-KM1
- Người: Kim
- Tuần: 9 | Giờ ước tính: 3 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Khung thẻ và hiệu ứng thẻ (SCR-17)
- Nghiệm thu: Thẻ đọc được ở 1280x720
- Cần xong trước: W9-KH2

##### W9-KM2
- Người: Kim
- Tuần: 9 | Giờ ước tính: 3.5 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: VFX Whirlwind, Sword Wave, vùng cháy Firebomb
- Nghiệm thu: VFX đúng bán kính và theo time_scale
- Cần xong trước: W8-NG2, W9-NG1

##### W9-KM3
- Người: Kim
- Tuần: 9 | Giờ ước tính: 3 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Nhạc boss một bản, AUD-07 cue Cuồng nộ, FBK-07 chuyển pha
- Nghiệm thu: Nhạc boss không bị time_scale
- Cần xong trước: W9-KT1, W9-MH1

##### W9-KM4
- Người: Kim
- Tuần: 9 | Giờ ước tính: 2 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: VFX Cuồng nộ FBK-11 (lõi đỏ, hơi nước)
- Nghiệm thu: Không dùng blend khi che; giảm nhấp nháy tôn trọng ACC-06
- Cần xong trước: W9-MH1

##### W9-KM5
- Người: Kim
- Tuần: 9 | Giờ ước tính: 1.5 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Camera BOSS_INTRO tự lia tới boss trong 4 s game time, khóa dịch tay, hết intro về khung của state kế (CAM-11, BOSS-17)
- Nghiệm thu: Camera lia mượt tới boss rồi về khung đúng state kế
- Cần xong trước: W9-KT2

##### W9-KM6
- Người: Kim
- Tuần: 9 | Giờ ước tính: 5 | Nguồn: SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Hành lang 23.5 m phần 2: đặt lại 3 slot WALL W1-W3 trên mặt tường (xóa W4-W6), camera_bounds và size camera nhìn trọn bề ngang, boss_melee_point (cách mặt tường 1.6-2.0 m), kiểm command_post
- Nghiệm thu: Chỉ còn W1-W3; camera Frontline và overview thấy trọn bề ngang; Bulwark tới được boss_melee_point
- Tệp liên quan: levels/corridor/slots_layout.tscn, levels/corridor/level.tscn (Markers/BossMeleePoint), systems/camera/camera_bounds.gd
- ID SRS: SLOT-05, BOSS-40, CAM-04
- Cần xong trước: W8B-KM1

##### W9-KM7
- Người: Kim
- Tuần: 9 | Giờ ước tính: 7 | Nguồn: SỬA + MỚI
- Trạng thái: Chưa bắt đầu
- Việc: GridData của map: 9 hàng (tâm 0, +-2.5, +-5, +-7.5, +-10), corridor_width 23.5, bỏ hẳn no_build_lane và GRID-03 cũ, thêm GRID-08 vùng cấm quanh boss_melee_point (boss_point_clear_radius 3.2 m), kiểm starter_arrow_slot và starter_cannon_slot (SLOT-05)
- Nghiệm thu: Số ô sinh ra đúng GridData; không ô nào trong spawn_zone, return_zone hay vùng cấm boss; hai ô tham chiếu hợp lệ; test_grid_data, test_ground_grid, test_ground_grid_view chạy lại đạt với lưới mới
- Tệp liên quan: levels/corridor/grid_data.gd, grid_data.tres, ground_grid.gd; tests/test_grid_data.gd, test_ground_grid*.gd
- ID SRS: GRID-01..05, GRID-08, SLOT-05
- Cần xong trước: W9-KM6

### Tuần 10 (16-22/11)

#### Ngọc (Player & Combat), tuần 10, 45h

##### W10-NG1
- Người: Ngọc
- Tuần: 10 | Giờ ước tính: 5 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Bị động và thẻ stat qua StatBlock: Sharpness, Armored, Lifesteal, Trạm hồi lực (SKL-26); thẻ stat Thể lực, Tinh thông (SKL-13..15); cắt Lightstep, Focus, Bền thành
- Nghiệm thu: Sharpness L3 +24%; Armored L3 15%; Lifesteal L3 1.5%; SKL-26 hồi 15, 20, 25 HP/s ở level 1, 2, 3 qua StatBlock
- Cần xong trước: W9-MH4b, W9-NG3

##### W10-NG2
- Người: Ngọc
- Tuần: 10 | Giờ ước tính: 2 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Kiểm skill với boss (kháng, cờ hit_by_commander)
- Nghiệm thu: Firebomb 100% lên Bulwark pha 1
- Cần xong trước: W10-NG1

##### W10-NG5
- Người: Ngọc
- Tuần: 10 | Giờ ước tính: 4 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Backend 2: bảng saves có revision, API đọc/ghi profile và meta, kiểm tra revision và device_id (ACCT-04, 06)
- Nghiệm thu: Ghi và đọc đúng, revision tăng một mỗi lần ghi, tài khoản khác không đọc được; flags (gồm tutorial_done) nằm trong dữ liệu đồng bộ
- ID SRS: ACCT-04
- Cần xong trước: W9-MH4b

##### W10-NG6
- Người: Ngọc
- Tuần: 10 | Giờ ước tính: 7 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Backend 3: nộp điểm, một dòng tốt nhất mỗi tài khoản, kiểm tra hợp lý (LBD-06), lọc theo game_version, top 50 và hạng của tôi (LBD-01..08); migration 005 nới ràng buộc thành run_elapsed + 1 >= 15 x waves_cleared
- Nghiệm thu: Từ chối điểm vô lý (40 wave trong 100 s); lượt thật chạy nhanh nhất vẫn được nhận (AC9); xếp đúng LBD-04
- Tệp liên quan: backend/001_init.sql:76-77 (leaderboard_min_time), mới: backend/005_*.sql, backend/README.md
- ID SRS: LBD-01..08, LBD-06, AC9
- Cần xong trước: W6-NG8

##### W10-NG7
- Người: Ngọc
- Tuần: 10 | Giờ ước tính: 2 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Nối lõi hồi máu với Trạm hồi lực thật (thay trạm giả), test HT1..HT5 và test input camera (CM4)
- Nghiệm thu: HT1..HT5 đạt với trạm thật; CM4 đạt
- Cần xong trước: W8-MH5

##### W10-NG8
- Người: Ngọc
- Tuần: 10 | Giờ ước tính: 6 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Công cụ dịch phần 2: sinh WeaponData, WaveScript, WaveRewardTable; kiểm lỗi bảng (báo dòng và cột, không ghi file nào khi lỗi); chuyển các .tres cân bằng hiện có sang sinh từ bảng và xóa enemies.csv, CsvLoader không dùng
- Nghiệm thu: Xóa một ô trong sheet towers hoặc ghi số âm thì công cụ báo đúng dòng, cột và không ghi file nào (BL2); .tres cũ được thay bằng bản sinh tự động
- Tệp liên quan: tools/balance/*.py; data/weapons/, data/waves/wave_script.tres, data/waves/wave_rewards.tres
- ID SRS: BAL-02, BAL-04, BAL-06, BL2
- Cần xong trước: W9-NG7, W10-KT7, W10-MH9

##### W10-NG9
- Người: Ngọc
- Tuần: 10 | Giờ ước tính: 5 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Vũ khí qua StatBlock: range_mult nhân sword_range, Swift (tốc độ đánh x1.5, tầm x0.7, combo_window giữ nguyên), Rampage (+10%/+25%/+50% dealt_mult theo tỷ lệ máu); đổi vũ khí đổi model trên tay
- Nghiệm thu: WP6, WP7 đạt; đổi vũ khí ở PREP có hiệu lực ngay
- Tệp liên quan: entities/commander/commander.gd, common/stat_block.gd, common/character_stats.gd
- ID SRS: WPN-09, WPN-10
- Cần xong trước: W9-NG6, W8B-NG1

##### W10-NG10
- Người: Ngọc
- Tuần: 10 | Giờ ước tính: 8 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Hazard Trial phía chỉ huy: bản sao chỉ số (HP, level, skill, StatBlock, vũ khí, cooldown) và bỏ khi ra; chết trong phòng không phải chết thật (không commander_died); khóa Tab/Recall; trần sát thương 10% theo con nhiều máu nhất (boss chỉ tính core_hp) áp cho mọi nguồn; không Emergency repair, không Trạm hồi lực
- Nghiệm thu: Vào phòng 70/100 HP, mất 50, ra ngoài vẫn 70; đòn 80 vào con 500 HP chỉ gây 50; chết trong phòng không kết thúc run
- Tệp liên quan: entities/commander/commander.gd, mode_switch.gd, heal_channel.gd, common/damage_info.gd (hook trần từ W8B-NG1)
- ID SRS: HZT-05, HZT-06, HZT-10, DEAD-05, DEAD-11
- Cần xong trước: W10-KT4, W8B-NG1, W9-NG6

##### W10-MH5
- Người: Ngọc
- Tuần: 10 | Giờ ước tính: 4 | Nguồn: CŨ + ĐỔI NGƯỜI (Mạnh sang Ngọc)
- Trạng thái: Chưa bắt đầu
- Việc: Trạm hồi lực phần 2: chuẩn hóa sát thương nhận ceil(raw / dmg_mult^0.5), EVB-34, nối panel, test HT6..HT12 (HLT-09)
- Nghiệm thu: Đòn raw 17 ở wave 10 gây 14; hút máu không bị chuẩn hóa
- Cần xong trước: W8-MH5

##### W10-MH6
- Người: Ngọc
- Tuần: 10 | Giờ ước tính: 2 | Nguồn: CŨ + ĐỔI NGƯỜI (Mạnh sang Ngọc)
- Trạng thái: Chưa bắt đầu
- Việc: save.json thêm revision, updated_at, device_id (ACCT-04)
- Nghiệm thu: Revision tăng 1 mỗi lần ghi; save cũ thiếu trường vẫn đọc được
- Cần xong trước: W10-MH1

#### Kiệt (Enemy & Wave), tuần 10, 40h

##### W10-KT1
- Người: Kiệt
- Tuần: 10 | Giờ ước tính: 3 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: RunLoading 8 bước (RUN-01, APL-01..04) trên RunState có sẵn; áp meta; gọi bước đặt trụ có sẵn hoặc tutorial (A: W10-MH10)
- Nghiệm thu: RunLoading < 5 s, start_wave = 1, gold 0
- Tệp liên quan: ui/screens/run_loading.gd, systems/run/
- ID SRS: 3.2.1
- Cần xong trước: W8B-KT1, W8-KT1

##### W10-KT2
- Người: Kiệt
- Tuần: 10 | Giờ ước tính: 4 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Kết thúc Run END-01..06, dữ liệu RunEnd (Cấp Chỉ huy, run_commander_kills, run_elapsed theo RUN-02, run_seed, cờ lượt khôi phục cho LBD-02, LBD-05); thêm run_result DEFEAT/SURVIVED tách khỏi end_type
- Nghiệm thu: Thua cùng frame ghi FORTRESS_DESTROYED xử lý một lần; run_elapsed chỉ tính COMBAT và BOSS_COMBAT; RunEnd có run_result; GameState.abandon_run và quit_from_run (đang là TODO) đi qua RunState và phát run_ended
- Tệp liên quan: systems/run/, autoload/game_state.gd (abandon_run, quit_from_run), ui/screens/run_end.gd
- ID SRS: END-01..06, RUN-02
- Cần xong trước: W8-MH3, W8B-KT1

##### W10-KT3
- Người: Kiệt
- Tuần: 10 | Giờ ước tính: 3 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: FRENZY, marker, giới hạn cứng (EN-01..03, WAVE-05, NAV-13, NAV-12)
- Nghiệm thu: Wave không treo quá 300 s
- Cần xong trước: W8-KT1

##### W10-NG3
- Người: Kiệt
- Tuần: 10 | Giờ ước tính: 4 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Thang kẹt MVP (NAV-01..06, 08, 09, 14 log) theo v2.0 (không ally_phase; thêm NAV-15 bị chặn kín thì nhắm công trình gần nhất)
- Nghiệm thu: Kẹt giả lập đi đúng bậc; xếp hàng không tính kẹt; chỉ huy đứng ở điểm hẹp không làm quân bị recycle
- Tệp liên quan: entities/enemy/enemy.gd (khối stuck), entities/enemy/bulwark.gd
- ID SRS: NAV-15
- Cần xong trước: W9-KT5

##### W10-NG4
- Người: Kiệt
- Tuần: 10 | Giờ ước tính: 2 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: TIME-06 tự hạ x2 + ALR-10
- Nghiệm thu: FPS < 30 trong 3 s ở x3 thì hạ x2
- Cần xong trước: W8-KT1

##### W10-KT4
- Người: Kiệt
- Tuần: 10 | Giờ ước tính: 3 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: State HAZARD_TRIAL trong Wave FSM (PREP -> HAZARD_TRIAL -> PREP cùng wave, không hồi 35% và hồi tower lần hai); thêm vào Enums.WaveState từ cuối; TimeManager, camera, HUD nhận state mới
- Nghiệm thu: Ra khỏi phòng không chạy lại việc đầu PREP; tua x1/x2/x3 dùng được trong phòng và vào/ra phòng không làm TimeManager đổi mức tua
- Tệp liên quan: common/enums.gd:6 (WaveState, thêm HAZARD_TRIAL ở cuối), systems/wave/wave_manager.gd, autoload/time_manager.gd
- ID SRS: 3.3.1, TIME-02, TIME-08
- Cần xong trước: W9-KT3, W9-KT6

##### W10-KT5
- Người: Kiệt
- Tuần: 10 | Giờ ước tính: 8 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Hazard Trial phía wave: điều kiện vào (PREP, một lần mỗi wave, Frontline, không Pause hay hộp thoại), chọn nhóm 5 quái (mỗi loại >= 1, RNG riêng hash(run_seed,'hazard',wave); wave boss = boss + 4 hộ tống), sinh quân vào hazard_room, phân xử kết quả cuối frame DIED > WON > LEFT, trả gold, XP, Mithril khi rời phòng, không đụng spawn_queue, uy tín, run_kills
- Nghiệm thu: HZ1, HZ2, HZ5, HZ6 đạt; thắng phòng được Mithril và sửa Fortress được; boss trong phòng không rơi vũ khí và không +1 Emergency repair; Pause trong phòng không rời phòng, Abandon hoặc Quit trong phòng chốt run và mất thưởng chưa nhận (HZT-12)
- Tệp liên quan: mới: systems/hazard/ (hoặc systems/wave/), systems/xp/xp_tracker.gd, systems/wave/wave_manager.gd
- ID SRS: HZT-01, 02, 04, 07, 08, 09, 13, 15, 16; GLD-10; XP-06; MTH-02
- Cần xong trước: W10-KT4, W10-NG10, W10-KM8, W8B-KT1

##### W10-KT6
- Người: Kiệt
- Tuần: 10 | Giờ ước tính: 4 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Hazard Trial AI trong phòng: quân chỉ nhắm chỉ huy; boss trong phòng có pha giáp nhưng không BOSS_INTRO, boss_timer, Cuồng nộ
- Nghiệm thu: Quân trong phòng không tấn công tower; Bulwark trong phòng không đếm giờ
- Tệp liên quan: entities/enemy/enemy.gd, entities/enemy/bulwark.gd
- ID SRS: HZT-03, HZT-14
- Cần xong trước: W10-KT5

##### W10-KT7
- Người: Kiệt
- Tuần: 10 | Giờ ước tính: 6 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: EnemyData thêm trait (is_stealth, explode_*, invuln_*, is_charger/impact_*, revive_*) và WaveScript Resource; hàm tra kịch bản theo wave
- Nghiệm thu: Mọi trường mặc định 'tắt'; code xử lý theo trait, không rẽ nhánh theo tên loại
- Tệp liên quan: common/enemy_data.gd, entities/enemy/enemy.gd, mới: common/wave_script.gd
- ID SRS: 3.7.1, EN-27, SPN-13
- Cần xong trước: W9-KT5

##### W10-KT8
- Người: Kiệt
- Tuần: 10 | Giờ ước tính: 3 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Sniper và Rider: dữ liệu, scene, hành vi (Sniper tầm hơn Arrow cấp 1, dừng bắn như Archer; Rider chạy nhanh)
- Nghiệm thu: Sniper bắn từ ngoài tầm Arrow cấp 1; Rider cận chiến như Grunt
- Tệp liên quan: entities/enemy/ (mới sniper.*, rider.*), data/enemies/
- ID SRS: EN-19, EN-21
- Cần xong trước: W10-KT7

#### Mạnh (Tower & Build), tuần 10, 38h

##### W10-MH1
- Người: Mạnh
- Tuần: 10 | Giờ ước tính: 4 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Save atomic + checksum + .bak (SAV-01..06, 10..14, 19; FLOW-01, 02, 07)
- Nghiệm thu: Xóa save.json thì nạp từ .bak; ghi dưới 50 ms; flags.tutorial_done có mặc định false
- Cần xong trước: W9-MH2, W7-KH2

##### W10-MH2
- Người: Mạnh
- Tuần: 10 | Giờ ước tính: 2 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: SAV-04 nối SUMMARY, RunEnd, shop (và nối khi tutorial_done bật)
- Nghiệm thu: Ghi save xong mới hiển thị SUMMARY
- Cần xong trước: W10-MH1

##### W10-MH3
- Người: Mạnh
- Tuần: 10 | Giờ ước tính: 3 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Thưởng boss BRW-01, 02, 04, 06, 07 theo WaveRewardTable (boss_gold = 100 x gold_mult(w), không clear_mult, không hệ số chỉ huy)
- Nghiệm thu: Diệt sau Cuồng nộ: boss_gold và prestige x 0.5; +1 lượt tối đa 3
- ID SRS: BRW-01
- Cần xong trước: W9-MH1, W10-MH7

##### W10-MH4
- Người: Mạnh
- Tuần: 10 | Giờ ước tính: 3 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: MetaShop backend (SHP-05..09, 4 mục: FORT_HP, GOLD_PCT, CMD_HP, EMG_REPAIR; không STARTER_KIT hay UNLOCK_WAND)
- Nghiệm thu: Mua nguyên tử, không nhảy cấp
- Cần xong trước: W9-MH2, W10-MH1

##### W10-MH7
- Người: Mạnh
- Tuần: 10 | Giờ ước tính: 6 | Nguồn: MỚI + SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Resource WaveRewardTable và sheet wave_rewards: gold_mult(w), xp_mult(w), mithril_reward(w); nối công thức gold/XP/boss gold theo bảng (kill_gold = gold_reward x gold_mult x hệ số chỉ huy một lần; XP-01)
- Nghiệm thu: Gold wave 3 trùng ví dụ HZ12; wave 31 trở đi dùng 1 + 0.04(w-1); mithril_reward wave 31+ lấy giá trị wave 30; enemy.gd phát kill_gold đã gồm hệ số chỉ huy (EVB-05) và WaveManager._on_enemy_died bỏ nhân frontline_gold_mult lần nữa, tránh nhân đôi
- Tệp liên quan: mới: common/wave_reward_table.gd; systems/wave/wave_manager.gd (_on_enemy_died ~502, _end_combat_to_summary ~518), entities/enemy/enemy.gd:1277 (enemy_died.emit), systems/xp/xp_tracker.gd
- ID SRS: RWD-01, RWD-02, FRT-02, XP-01, BRW-01, MTH-02
- Cần xong trước: W8B-MH1, W8B-KT1

##### W10-MH8
- Người: Mạnh
- Tuần: 10 | Giờ ước tính: 4 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Soạn số liệu 36 cấp cho 4 loại tower trong sheet towers (giá, chỉ số, HP, kho Trạm hồi lực)
- Nghiệm thu: Gold khan hiếm: không đủ nâng cả 6 công trình lên bậc cao trước wave 30 trong tính toán thô
- Tệp liên quan: balance/balance.xlsx (sheet towers)
- ID SRS: 3.6.3, 3.9
- Cần xong trước: W8B-MH1

##### W10-MH9
- Người: Mạnh
- Tuần: 10 | Giờ ước tính: 10 | Nguồn: MỚI + SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Tower cấp 1-36 cho cả 4 loại: dữ liệu 36 cấp từ bảng, nâng từng cấp, 'MAX' ở 36; Trạm hồi lực cấp 1-36 (nâng chỉ cộng phần kho tăng thêm, xây lại giữ cấp, hoàn bán theo kho còn lại); xây lại giá bằng tổng cost; đo hiệu năng với 6 tower
- Nghiệm thu: Tower cấp 14 bị phá thì 'Xây lại' đúng cấp 14 với giá tổng cost cấp 1-14; trạm nâng cấp không hồi đầy kho
- Tệp liên quan: common/tower_data.gd, common/tower_level_data.gd, data/towers/*, entities/tower/tower.gd (apply_level), entities/tower/heal_station.gd, systems/build/slot.gd (get_rebuild_cost), ui/panels/heal_station_panel.gd
- ID SRS: TWR, UPG-01..03, HLT-01, HLT-07, HLT-08, SELL-05, TWR-15
- Cần xong trước: W9-NG7, W10-MH8

##### W10-MH10
- Người: Mạnh
- Tuần: 10 | Giờ ước tính: 6 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Trụ có sẵn: khi tutorial_done = true đặt Arrow cấp 1 ở starter_arrow_slot (ô grid hàng giữa) và Cannon cấp 1 ở W2; invested_gold = 0, cờ is_starter, khóa bán tới PREP wave 3; bị phá rồi xây lại là tower thường; BLD-11 (khóa slot khác khi tutorial chưa xong)
- Nghiệm thu: Run thứ hai có sẵn hai trụ; bán trước wave 3 xám 'Bán được từ wave 3'; trụ xây lại bán được ngay
- Tệp liên quan: systems/build/slot.gd, systems/build/build_service.gd, systems/run/commander_spawner.gd, ui/panels/tower_panel.gd, autoload/save_manager.gd (flags.tutorial_done đã có)
- ID SRS: SELL-06, TWR-13, BLD-11, 3.2.1
- Cần xong trước: W8B-KT1, W9-KM7, W10-KT1

#### Khang (UI/UX & Meta), tuần 10, 34h

##### W10-KH1
- Người: Khang
- Tuần: 10 | Giờ ước tính: 6 | Nguồn: CŨ-SỬA
- Trạng thái: Xong
- Việc: HUD skill bar 3+3 ô (HUD-16), thanh XP và lượt chờ (HUD-15), biểu tượng Aura (HUD-17), XP-05; thêm ô vũ khí (HUD-21) cạnh thanh kỹ năng
- Nghiệm thu: Quạt cooldown có số; ô khóa ở Commander; ô vũ khí chỉ đọc ngoài PREP
- ID SRS: HUD-15..17, HUD-21
- Cần xong trước: W9-MH4b, W7-KM5

##### W10-KH2
- Người: Khang
- Tuần: 10 | Giờ ước tính: 3 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Nút nâng cấp xám 'Cần Chỉ huy cấp N' (UPG-06) áp ở cấp 13 và 25; panel Tower hiển thị cấp thật và bậc model; Trạm hồi lực có nút Nâng cấp và 'MAX'
- Nghiệm thu: Tooltip đúng cấp yêu cầu; trụ có sẵn hiện nút Bán xám 'Bán được từ wave 3'
- Tệp liên quan: ui/panels/tower_panel.gd, ui/panels/heal_station_panel.gd
- ID SRS: UPG-06, PNL-02, PNL-14
- Cần xong trước: W8B-MH2, W10-MH9, W10-MH10

##### W10-KH3
- Người: Khang
- Tuần: 10 | Giờ ước tính: 3 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: MetaShop SCR-04 (4 mục, SHP-05..09 UI)
- Nghiệm thu: Shop chỉ hiện 4 mục MVP
- Cần xong trước: W10-MH4

##### W10-KH4
- Người: Khang
- Tuần: 10 | Giờ ước tính: 2 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Toast cảnh báo tối thiểu ALR-13..15, ALR-17, ALR-18; thêm ALR-19 (nhận vũ khí) và ALR-20 (kết thúc Hazard Trial)
- Nghiệm thu: Tối đa 1 banner và 3 toast
- Cần xong trước: W9-MH4b

##### W10-KH5
- Người: Khang
- Tuần: 10 | Giờ ước tính: 2 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Màn Leaderboard SCR-19: top 50, dòng hạng của tôi, Làm mới, Thử lại khi lỗi, nút Đăng nhập cho khách (LBD-08), dùng dữ liệu giả trước
- Nghiệm thu: Hiện đủ top 50 và dòng hạng riêng khi ngoài top; lỗi mạng có Thử lại
- Cần xong trước: W7-KM5

##### W10-KH6
- Người: Khang
- Tuần: 10 | Giờ ước tính: 2 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Mục Tài khoản trong Settings và biểu tượng trạng thái đồng bộ ở MainMenu (GUEST, SYNCED, SYNCING, OFFLINE, ERROR)
- Nghiệm thu: Có chữ kèm biểu tượng, đúng 5 trạng thái
- Cần xong trước: W8-MH2

##### W10-KH7
- Người: Khang
- Tuần: 10 | Giờ ước tính: 8 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Hazard Trial: input hazard_enter (phím E, khác ngữ cảnh với heal_channel) và bấm chuột vào Tháp; HUD-22 (Rời phòng, số quái còn, gold/XP tạm tính, HP bản sao), HUD-23 (chỉ báo Tháp và tooltip loại quái), đóng panel và hộp thoại khi vào, toast kết quả
- Nghiệm thu: HZ1, HZ7 đạt: Tháp xám kèm lý do ở Commander, Pause, đã dùng; bấm Rời phòng một lần không cần xác nhận; nút tua x1/x2/x3 hoạt động trong phòng; Pause trong phòng thì panel chỉ đọc (PNL-12); phím E không xung đột với hồi máu (E chỉ vào Tháp ở PREP)
- Tệp liên quan: project.godot (InputMap hazard_enter), ui/hud/*, ui/panels/panel_host.gd, ui/hud/parts/speed_buttons.gd
- ID SRS: HUD-22, HUD-23, INP-01, BLD-05, SCR-14, ALR-20
- Cần xong trước: W10-KT4, W10-KT5, W9-KT6

##### W10-KH8
- Người: Khang
- Tuần: 10 | Giờ ước tính: 3 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: UI chặn kín đường: ghost preview màu cấm, tooltip 'Sẽ chặn kín đường đi', mục xây xám lý do BLOCKS_PATH; chuỗi 'Đã đủ 3 công trình trên mặt đất'
- Nghiệm thu: Mục xây xám đúng lý do ở bố cục thử
- Tệp liên quan: ui/panels/build_panel.gd, data/locale/strings.csv
- ID SRS: BLD-10, BLD-08, PNL-01
- Cần xong trước: W9-MH5

##### W10-KH9
- Người: Khang
- Tuần: 10 | Giờ ước tính: 5 | Nguồn: MỚI
- Trạng thái: Xong
- Việc: Panel vũ khí PNL-15 và ô vũ khí HUD-21 hoàn chỉnh: danh sách owned_weapons, vũ khí chưa có hiện khóa 'Rơi từ boss', chọn là trang bị ngay (chỉ PREP)
- Nghiệm thu: WP2 đạt: đổi tức thì ở PREP, chỉ đọc ở state khác
- Tệp liên quan: mới: ui/panels/weapon_panel.*; ui/hud/parts/ (ô vũ khí)
- ID SRS: PNL-15, WPN-03
- Cần xong trước: W9-NG6, W10-KH1

#### Kim (Art/Level/Audio), tuần 10, 31.5h

##### W10-KM3
- Người: Kim
- Tuần: 10 | Giờ ước tính: 2 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Logic tab Âm thanh và Đồ họa (SET-01..04)
- Nghiệm thu: Volume áp ngay; đổi độ phân giải xác nhận 10 s
- Cần xong trước: W10-KH3

##### W10-KM4
- Người: Kim
- Tuần: 10 | Giờ ước tính: 2 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Nhạc theo state (COMBAT một lớp, sting SUMMARY, RunEnd); HAZARD_TRIAL dùng nhạc COMBAT (nhạc boss nếu có boss)
- Nghiệm thu: Crossfade 1.5 s thực
- Cần xong trước: W8-KM4, W10-KT4

##### W10-KM6
- Người: Kim
- Tuần: 10 | Giờ ước tính: 3 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: VFX và SFX Trạm hồi lực: vòng tiến trình hold, tia sáng trạm sang chỉ huy, số nổi xanh, âm bắt đầu hồi và trạm cạn (HLT-11, FBK-12, AUD-07)
- Nghiệm thu: Vòng hold và tia hồi đọc được, giảm nhấp nháy tôn trọng ACC-06
- Cần xong trước: W7-MH1

##### W13-KM1
- Người: Kim
- Tuần: 10 | Giờ ước tính: 2 | Nguồn: DỜI
- Trạng thái: Chưa bắt đầu
- Việc: FBK-04, 05 (flash, đóng băng riêng thực thể) [dời từ tuần 13]
- Nghiệm thu: Không hit stop toàn cục
- Cần xong trước: W7-KM2

##### W13-KM3
- Người: Kim
- Tuần: 10 | Giờ ước tính: 2.5 | Nguồn: DỜI
- Trạng thái: Chưa bắt đầu
- Việc: FBK-08 tower bị phá (khói, mảnh vỡ, đống đổ nát) [dời từ tuần 13]
- Nghiệm thu: Hiện đúng khi vào RUINED
- Cần xong trước: W8-KM4

##### W10-KM8
- Người: Kim
- Tuần: 10 | Giờ ước tính: 6 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Level: Tháp Hazard Trial (hazard_portal gần Fortress, chọn được bằng chuột) và hazard_room (điểm xuất hiện chỉ huy, các điểm sinh quân, khung camera cố định)
- Nghiệm thu: Phòng đủ chỗ cho 5 quân và chỉ huy; có navmesh cho phòng (quân và boss đi được); Tháp bấm được
- Tệp liên quan: levels/corridor/level.tscn (thêm hazard_portal, hazard_room)
- ID SRS: HZT-01, 6.7
- Cần xong trước: W9-KM6

##### W10-KM9
- Người: Kim
- Tuần: 10 | Giờ ước tính: 3 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Camera frame HAZARD_TRIAL (CAM-16): cắt hoặc chuyển 0.5 s sang khung phòng, không bám nhân vật, không dịch phím, rời phòng về khung PREP; phát camera_frame_changed
- Nghiệm thu: HZ7 đạt phần camera
- Tệp liên quan: systems/camera/camera_rig.gd, autoload/event_bus.gd (camera_frame_changed chưa có)
- ID SRS: CAM-16, HZT-11, EVB-35
- Cần xong trước: W10-KM8, W9-KT6

##### W10-KM10
- Người: Kim
- Tuần: 10 | Giờ ước tính: 5 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Model 3 bậc cho tower, phần 1 (Arrow và Cannon, bậc 2 và 3): dùng lại model bậc 1 làm gốc, thêm chi tiết và đổi material để dựng nhanh
- Nghiệm thu: Bậc 2 và 3 nhìn khác bậc 1 ở khoảng cách camera chuẩn
- Tệp liên quan: entities/tower/arrow.tscn, cannon.tscn, tower_model.gd
- ID SRS: TWR-17
- Cần xong trước: W8-KM4

##### W10-KM11
- Người: Kim
- Tuần: 10 | Giờ ước tính: 6 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Model quân mới, phần 1 (Sniper, Rider, Assassin): dùng lại rig KayKit hiện có, đổi material và thêm props; material độ mờ Assassin qua stealth_opacity
- Nghiệm thu: Ba loại khác nhau rõ ở camera chuẩn; Assassin mờ 0.5 qua material
- Tệp liên quan: contents/assets/characters/, art/
- ID SRS: 3.7.8, EN-20, FBK-14
- Cần xong trước: W10-KT7

### Tuần 11 (23-29/11)

#### Ngọc (Player & Combat), tuần 11, 47h

##### W11-NG2
- Người: Ngọc
- Tuần: 11 | Giờ ước tính: 3 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Kiểm thử time scale toàn hệ thống x1/x2/x3 (gồm Hazard Trial và hiệu ứng vũ khí)
- Nghiệm thu: Skill, projectile, boss clock, Cuồng nộ, hiệu ứng vũ khí đúng ở x1/x2/x3
- Cần xong trước: W10-NG3

##### W11-NG3
- Người: Ngọc
- Tuần: 11 | Giờ ước tính: 5 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Chạy lại test Combat, Skill, Boss (7.1, F1..F15, CM1..CM8, HT1..HT14); sửa lỗi
- Nghiệm thu: Không lỗi console
- Cần xong trước: W10-NG1

##### W11-NG5
- Người: Ngọc
- Tuần: 11 | Giờ ước tính: 4 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Backend ổn định: kiểm tra giới hạn gói miễn phí, sao lưu dữ liệu, tài liệu API một trang, bản demo offline (ACCT-12)
- Nghiệm thu: Tài liệu API đủ cho Khang và Mạnh tự gọi; tắt mạng vẫn chơi trọn vẹn
- Cần xong trước: W10-NG6

##### W11-NG6
- Người: Ngọc
- Tuần: 11 | Giờ ước tính: 2 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Hỗ trợ tích hợp client của Khang và Mạnh, sửa lỗi API trong ngày
- Nghiệm thu: Lỗi tích hợp được sửa trong ngày
- Cần xong trước: W10-NG6

##### W11-NG7
- Người: Ngọc
- Tuần: 11 | Giờ ước tính: 8 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Hiệu ứng vũ khí: Frost (Slow 20%/3 s), Burn (tổng 50% dmg gốc/5 s), Chain Lightning (3 mục tiêu, 20%, bán kính 2 m, chain_cd 5 s dùng chung); kích hoạt cả với tick Firebomb và skill chủ động; sát thương hiệu ứng mang damage_type của đòn, tính hit_by_commander, không tự kích hoạt lại
- Nghiệm thu: WP3, WP4, WP5, WP8 đạt; Frost làm chậm Bulwark pha 1; hiệu ứng bị trần 10% trong Hazard Trial (HZ3)
- Tệp liên quan: entities/commander/commander.gd, systems/skill/skill_runner.gd, systems/skill/whirlwind_skill.gd
- ID SRS: WPN-04..08
- Cần xong trước: W9-NG5, W10-NG9, W10-NG10

##### W11-NG8
- Người: Ngọc
- Tuần: 11 | Giờ ước tính: 6 | Nguồn: SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Brute sửa: is_charger, mục tiêu cố định FORTRESS, miễn khiêu khích và Battle Cry, va mỗi công trình một lần rồi đi vòng, va chỉ huy hất văng (tối đa 1 lần/2 s, Dodge và Deploying miễn)
- Nghiệm thu: NE5 đạt
- Tệp liên quan: entities/enemy/brute.gd, data/enemies/brute.tres
- ID SRS: EN-25
- Cần xong trước: W10-KT7

##### W11-NG9
- Người: Ngọc
- Tuần: 11 | Giờ ước tính: 8 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Thắng ở victory_wave và endless: victory_reached, run_result, thua đè thắng, thứ tự WAVE-13 (SUMMARY -> màn thắng -> REWARD_PICK -> PREP), lý do Pause VICTORY ở TimeManager, run_victory và victory_continue_requested, Abandon sau thắng là SURVIVED, scale từ wave 31
- Nghiệm thu: VC1..VC5 đạt; không thêm uy tín hay danh vọng khi thắng
- Tệp liên quan: systems/wave/wave_manager.gd (advance_from_summary ~637), autoload/time_manager.gd:18-20 (REASONS), autoload/game_state.gd
- ID SRS: END-07..10, WAVE-13, TIME-11, EVB-44, EVB-46, SCL-06
- Cần xong trước: W9-KT3, W10-KT2, W11-KH6

##### W11-NG10
- Người: Ngọc
- Tuần: 11 | Giờ ước tính: 4 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Runner BAL tests/test_balance_config_runner.tscn (BAL-05, BL3, BL4)
- Nghiệm thu: Pass với bảng chuẩn; fail khi thiếu cấp 36 hoặc spawn_duration 12 s
- Tệp liên quan: mới: tests/test_balance_config_runner.tscn
- ID SRS: BAL-05, BL3, BL4
- Cần xong trước: W10-NG8, W11-MH11

##### W11-MH5
- Người: Ngọc
- Tuần: 11 | Giờ ước tính: 2 | Nguồn: CŨ + ĐỔI NGƯỜI (Mạnh sang Ngọc)
- Trạng thái: Chưa bắt đầu
- Việc: Chính sách xung đột đơn giản: bản có revision cao hơn thắng, báo cho người chơi; device_id (ACCT-06 rút gọn)
- Nghiệm thu: Hai máy lệch revision: lấy bản cao hơn, không mất dữ liệu
- Cần xong trước: W10-NG5

##### W11-MH6
- Người: Ngọc
- Tuần: 11 | Giờ ước tính: 2 | Nguồn: CŨ-SỬA + ĐỔI NGƯỜI (Mạnh sang Ngọc)
- Trạng thái: Chưa bắt đầu
- Việc: Hook nộp điểm ở RunEnd: chỉ gửi khi đăng nhập, start_wave = 1, không phải lượt khôi phục; lấy số liệu từ RunState (LBD-02, 03, 05)
- Nghiệm thu: Khách, lượt khôi phục, start_wave > 1 không gửi điểm; run_elapsed theo RUN-02
- Cần xong trước: W10-KT2, W10-NG6

##### W11-MH7
- Người: Ngọc
- Tuần: 11 | Giờ ước tính: 3 | Nguồn: CŨ-SỬA + ĐỔI NGƯỜI (Mạnh sang Ngọc)
- Trạng thái: Chưa bắt đầu
- Việc: Hồi quy Trạm hồi lực: HT6..HT12, SELL-05, giới hạn 2 trạm, nâng cấp tới cấp 36
- Nghiệm thu: HT6..HT12 đạt
- Cần xong trước: W10-MH5

#### Kiệt (Enemy & Wave), tuần 11, 43h

##### W11-KT1
- Người: Kiệt
- Tuần: 11 | Giờ ước tính: 4 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Cân bằng lần 1: XP, cổng bậc tower, Aura, gold chỉ huy (SCL-04, FRT)
- Nghiệm thu: Người chủ động cấp 4 ở wave 4 +-1, cấp 8 ở wave 8 +-1
- Cần xong trước: W10-KT1, W11-NG4

##### W11-KT2
- Người: Kiệt
- Tuần: 11 | Giờ ước tính: 3 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Edge case EN-05..15 (ưu tiên ca hay gặp)
- Nghiệm thu: Không treo wave
- Cần xong trước: W10-KT3

##### W11-KT3
- Người: Kiệt
- Tuần: 11 | Giờ ước tính: 2 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Hồi quy wave 1-20 có skill
- Nghiệm thu: Mọi wave kết thúc
- Cần xong trước: W9-KT2

##### W11-KT4
- Người: Kiệt
- Tuần: 11 | Giờ ước tính: 2 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Chỉnh Resource theo log cân bằng, ghi lại tham số (chỉnh trong balance.xlsx rồi chạy công cụ dịch, không sửa tay .tres)
- Nghiệm thu: Log thay đổi tham số
- Cần xong trước: W11-KT1

##### W11-KT5
- Người: Kiệt
- Tuần: 11 | Giờ ước tính: 3 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Boss điều hướng agent lớn (BOSS-03), đứng tại boss_melee_point đánh Stomp vào Fortress (BOSS-32, 40) trên hành lang 23.5 m với ô grid đã đặt
- Nghiệm thu: Bulwark tới được Fortress với 3 công trình ở mọi bố cục hợp lệ; không chiếm slot đánh
- Cần xong trước: W9-KM6, W9-MH5

##### W11-NG4
- Người: Kiệt
- Tuần: 11 | Giờ ước tính: 2 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Script hoặc bot 20 wave ở x3 nhiều seed (NAV-14); bot AFK vs bot Frontline cho F13; mở rộng chạy kịch bản wave 1-30
- Nghiệm thu: Mọi wave kết thúc, cull < 0.1%
- Cần xong trước: W10-NG3

##### W11-KT6
- Người: Kiệt
- Tuần: 11 | Giờ ước tính: 2 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Hồi quy Trạm hồi lực: quân nhắm trạm theo ETG, slot đánh, cân bằng sơ bộ (HLT-09, HLT-10)
- Nghiệm thu: Ghi tỉ lệ run dùng trạm và số lần cạn kho
- Cần xong trước: W10-KT3

##### W11-KT7
- Người: Kiệt
- Tuần: 11 | Giờ ước tính: 9 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Assassin (tower không chọn làm mục tiêu và không tính là 'quân trong tầm', nổ Cannon vẫn trúng) và Knight (bất tử 5 s một lần khi máu < 50%, IMMUNE) và Undead (hồi sinh một lần, thưởng ở lần chết thứ hai)
- Nghiệm thu: NE1, NE4, NE6 đạt
- Tệp liên quan: entities/enemy/enemy.gd, entities/tower/tower.gd (_pick_target/_is_valid_target ~209-253), common/health_component.gd
- ID SRS: EN-20, EN-24, EN-26
- Cần xong trước: W10-KT7, W10-KM11

##### W11-KT8
- Người: Kiệt
- Tuần: 11 | Giờ ước tính: 8 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Suicide Squad và Captain: lao vào mục tiêu, wind-up với telegraph, nổ BLAST lên chỉ huy Frontline, tower (kể cả WALL trong bán kính), Barricade, Fortress; nổ thì không thưởng; Captain nổ khi bị diệt vẫn thưởng, bị cull không nổ
- Nghiệm thu: NE2, NE3 đạt; Dodge né được; Commander mode miễn
- Tệp liên quan: entities/enemy/enemy.gd, art/vfx/telegraph_fx_manager.gd
- ID SRS: EN-22, EN-23, FBK-06
- Cần xong trước: W10-KT7, W11-KM9

##### W11-KT9
- Người: Kiệt
- Tuần: 11 | Giờ ước tính: 8 | Nguồn: MỚI + SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Spawner đọc WaveScript wave 1-30 (thành phần cố định, hộ tống, hp/dmg/speed_mult và spawn_duration từ kịch bản), thuật toán và ScaleConfig chỉ từ wave 31, tối đa 5 loại mỗi wave kể cả boss, danh mục 10 loại quân thay cho 3 loại hardcode; lịch sinh trải đủ spawn_duration (SPN-15)
- Nghiệm thu: Wave 1-30 đúng thành phần của WaveScript không phụ thuộc run_seed; mỗi wave kéo dài >= spawn_duration; wave 31-40 tối đa 5 loại (NE8); hệ số boss wave 1-30 cũng lấy từ WaveScript (BOSS-24); phát wave_preview_ready với danh sách loại quân sắp tới cho preview PREP và Hazard Trial
- Tệp liên quan: systems/wave/wave_manager.gd (generate_wave_composition 210, _get_scene_for_enemy_id 134, _build_spawn_queue_for_wave 375, _spawn_boss), common/scale_config.gd, common/wave_table.gd
- ID SRS: SPN-13, SPN-14, SPN-15, SCL-06
- Cần xong trước: W10-KT7, W11-MH11, W10-NG8

#### Mạnh (Tower & Build), tuần 11, 31h

##### W11-MH11
- Người: Mạnh
- Tuần: 11 | Giờ ước tính: 7 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Kịch bản wave 1-30 trong sheet waves (loại quân, số lượng, hộ tống, spawn_duration, hệ số), wave 1-2 chỉ Grunt, wave boss đúng một boss và >= 1 hộ tống, số liệu 7 loại quân mới và 5 vũ khí
- Nghiệm thu: Runner BAL pass; người mới thua wave 8-12 theo ước lượng thô (SCL-04); mỗi loại quân mới có đủ gold, uy tín, XP gốc (RWD-05)
- Tệp liên quan: balance/balance.xlsx (sheet waves, enemies, weapons)
- ID SRS: SPN-08, SCL-04, 3.7.8, 3.5.13
- Cần xong trước: W10-KT7, W10-KT8, W8B-MH1

##### W11-MH1
- Người: Mạnh
- Tuần: 11 | Giờ ước tính: 4 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Khôi phục run gián đoạn (3.12.4, PRS-05, FLOW-03)
- Nghiệm thu: Mất điện giữa wave 7 chốt ABANDONED theo SUMMARY wave 6
- Cần xong trước: W10-MH1, W8-MH2

##### W11-MH2
- Người: Mạnh
- Tuần: 11 | Giờ ước tính: 1 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: SAV-09 (cắt tab Dữ liệu và Xóa tiến trình SAV-16, đưa vào backlog)
- Nghiệm thu: Hoàn tất
- Cần xong trước: W10-MH1

##### W11-MH3
- Người: Mạnh
- Tuần: 11 | Giờ ước tính: 3 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Test ACP-05 (rò rỉ), ACP-06 (save < 50 ms), hồi quy economy và save
- Nghiệm thu: Sau 10 run bộ nhớ tăng <= 5%
- Cần xong trước: W10-MH6

##### W11-MH4
- Người: Mạnh
- Tuần: 11 | Giờ ước tính: 3 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Hồi quy tower (cổng bậc, Aura, xây lại, 36 cấp, trụ có sẵn)
- Nghiệm thu: Không lỗi hồi quy
- Cần xong trước: W10-MH9, W10-MH10

##### W11-MH8
- Người: Mạnh
- Tuần: 11 | Giờ ước tính: 5 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Tower 3 bậc model trong code (TWR-17): TowerData giữ 3 scene, đổi model ngay khi nâng qua cấp 13 và 25, đống đổ nát dùng chung một model
- Nghiệm thu: Nâng Arrow từ 12 lên 13 thì đổi model bậc 2; cấp 25 đổi bậc 3
- Tệp liên quan: common/tower_data.gd, entities/tower/tower.gd, tower_model.gd
- ID SRS: TWR-17
- Cần xong trước: W10-KM10, W10-MH9

##### W11-MH9
- Người: Mạnh
- Tuần: 11 | Giờ ước tính: 4 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Rơi vũ khí từ boss wave 5/10/15/20/25 (RNG riêng hash(run_seed,'weapon',wave), không trùng, cộng tự động ở SUMMARY cùng điều kiện BRW-07), weapon_gained, summary_data.weapon_gained
- Nghiệm thu: WP1 đạt: wave 5 nhận 1 cây, wave 25 đủ 5, boss wave 30 không rơi; thua đè thắng thì không nhận
- Tệp liên quan: systems/wave/wave_manager.gd (_end_combat_to_summary)
- ID SRS: WPN-11, BRW-09, EVB-42
- Cần xong trước: W9-NG6, W10-MH3

##### W11-MH10
- Người: Mạnh
- Tuần: 11 | Giờ ước tính: 4 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Tua lại sheet towers/economy sau chạy thử wave 1-30: chỉnh trong balance.xlsx và sinh lại; test lưới (3 WALL + 9 hàng, ô bị bỏ) và chặn kín đường (2 bố cục thử)
- Nghiệm thu: Test chặn kín đường đạt; không đủ gold nâng mọi công trình trước wave 30
- Tệp liên quan: balance/balance.xlsx, tests/
- ID SRS: test Fortress/tower 4, 15
- Cần xong trước: W9-MH5, W11-MH11

#### Khang (UI/UX & Meta), tuần 11, 38h

##### W11-KH1
- Người: Khang
- Tuần: 11 | Giờ ước tính: 4 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: RunEnd SCR-11 (PRS-06) và RunEnd endless SCR-21 ('Sống sót đến wave N')
- Nghiệm thu: Đủ trường mục 3.2.4; hai loại RunEnd tách theo run_result
- Tệp liên quan: ui/screens/run_end.gd, mới: ui/screens/run_end_survived (hoặc biến thể)
- ID SRS: SCR-11, SCR-21
- Cần xong trước: W10-KT2, W10-KM3

##### W11-KH2
- Người: Khang
- Tuần: 11 | Giờ ước tính: 2 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: PauseMenu hoàn chỉnh (FLOW-04, 05)
- Nghiệm thu: Pause mở Settings vẫn đóng băng
- Cần xong trước: W11-KH1

##### W11-KH3
- Người: Khang
- Tuần: 11 | Giờ ước tính: 3 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Settings tabs: Âm thanh, Đồ họa, Tiếp cận (SET-01, 04, 06, ACC-04); cắt tab Điều khiển chỉ đọc và Dữ liệu
- Nghiệm thu: Lưu khi thoát màn Settings
- Cần xong trước: W10-NG5

##### W11-KH4
- Người: Khang
- Tuần: 11 | Giờ ước tính: 6 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: SyncService thật: kéo và đẩy profile, meta, flags (gồm tutorial_done); đồng bộ khi đăng nhập, ở RunEnd và sau mua shop; nối SCR-19 dữ liệu thật; hộp thoại tải profile cục bộ lên lần đầu (ACCT-05, 07, 08)
- Nghiệm thu: Đăng nhập máy mới kéo đúng profile và tutorial_done (TU4); mất mạng không chặn RunEnd hay shop
- Cần xong trước: W10-NG5, W10-NG6, W11-MH5, W11-MH6

##### W13-KH1
- Người: Khang
- Tuần: 11 | Giờ ước tính: 3 | Nguồn: DỜI
- Trạng thái: Chưa bắt đầu
- Việc: Kích hoạt cảnh báo T1/T2 (ALR-01..04, 07, 09, 11) [dời từ tuần 13; ALR-08 đã bỏ ở v2.0]
- Nghiệm thu: Mỗi cảnh báo hiện đúng tầng, không lặp trong 5 s
- Cần xong trước: W10-KH4

##### W11-NG1
- Người: Khang
- Tuần: 11 | Giờ ước tính: 10 | Nguồn: CŨ-SỬA + MỚI + ĐỔI NGƯỜI (Ngọc sang Khang)
- Trạng thái: Chưa bắt đầu
- Việc: Tutorial một lần theo tài khoản (đổi người: từ Ngọc sang Khang): TUT-01 xây Arrow, TUT-14 xây Cannon, TUT-15 bấm Bắt đầu wave (nút xám tới khi xây xong), Bỏ qua luôn có và tự xây trụ còn thiếu, ghi tutorial_done ngay khi xây xong, thoát giữa chừng thì chạy lại, tutorial_completed
- Nghiệm thu: TU1, TU2, TU3 đạt; run sau có trụ có sẵn; đăng nhập máy mới không chạy lại (TU4)
- Tệp liên quan: mới: systems/tutorial/; ui/; autoload/save_manager.gd (flags.tutorial_done); tín hiệu tutorial_step_completed đã có trong event_bus.gd
- ID SRS: TUT-01, 03, 08..11, 14, 15, 17; BLD-11; EVB-45
- Cần xong trước: W10-MH10, W8B-KH1, W11-KH4

##### W11-KH6
- Người: Khang
- Tuần: 11 | Giờ ước tính: 3 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Màn thắng SCR-20 (một nút 'Chơi tiếp', không đếm ngược, game dừng)
- Nghiệm thu: VC1, VC5 đạt phần giao diện
- Tệp liên quan: mới: ui/screens/victory_screen.*
- ID SRS: SCR-20, EVB-46
- Cần xong trước: W11-NG9

##### W11-KH7
- Người: Khang
- Tuần: 11 | Giờ ước tính: 5 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Biểu tượng trait quân (tàng hình, tự nổ, bất tử một lần, hồi sinh, ủi thẳng) kèm chữ trong preview wave PREP, Tháp Hazard và hover quân; preview boss hiện vũ khí sẽ rơi; tối đa 5 loại kể cả boss
- Nghiệm thu: Preview wave hiện đúng loại quân và trait của wave sắp tới
- Tệp liên quan: ui/panels/wave_preview_panel.tscn (hiện mới có scene), ui/hud/parts/enemy_bar_layer.*
- ID SRS: EN-18, MSE-06, 3.3.2, WPN-11
- Cần xong trước: W10-KT7, W11-MH11

##### W11-KH8
- Người: Khang
- Tuần: 11 | Giờ ước tính: 2 | Nguồn: SỬA
- Trạng thái: Chưa bắt đầu
- Việc: SummaryPanel: dòng 'Nhận vũ khí X', ghi chú gold/XP/Mithril của Hazard đã cộng lúc rời phòng, bỏ dòng gọi sớm (nếu còn)
- Nghiệm thu: Dòng vũ khí chỉ hiện khi có rơi; SUMMARY khi Fortress dưới 30% gợi ý 'Sửa Fortress bằng Mithril' (FORT-06)
- Tệp liên quan: ui/screens/summary_panel.gd
- ID SRS: 3.3.4, WPN-11
- Cần xong trước: W11-MH9

#### Kim (Art/Level/Audio), tuần 11, 36.5h

##### W11-KM1
- Người: Kim
- Tuần: 11 | Giờ ước tính: 2 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Accessibility ACC-05, 06 và kiểm UI-05 (gồm biểu tượng trait quân)
- Nghiệm thu: Không nhấp nháy quá 3 lần/s
- Cần xong trước: W10-KM4

##### W11-KM2
- Người: Kim
- Tuần: 11 | Giờ ước tính: 3 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Âm thanh hoàn chỉnh (AUD-06..09, -14 LUFS nhạc, -12 LUFS SFX); sting thắng và sting RunEnd endless
- Nghiệm thu: Nhạc .ogg, SFX .wav
- Cần xong trước: Mốc B2

##### W11-KM4
- Người: Kim
- Tuần: 11 | Giờ ước tính: 3 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Tổ chức playtest >= 5 người ngoài nhóm trên bản có Hazard, vũ khí, quân mới, biểu mẫu thu thập
- Nghiệm thu: Có số liệu thời gian sống và Cấp Chỉ huy
- Cần xong trước: Mốc B2

##### W11-KM5
- Người: Kim
- Tuần: 11 | Giờ ước tính: 2 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Sửa lỗi Art/Audio từ playtest
- Nghiệm thu: Danh sách lỗi đã đóng
- Cần xong trước: W11-KM4

##### W11-KM6
- Người: Kim
- Tuần: 11 | Giờ ước tính: 1.5 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Kiểm navmesh agent lớn và boss_melee_point trên hành lang mới với 3 công trình grid
- Nghiệm thu: Có đường cho agent bán kính 1.6 m
- Cần xong trước: W9-KM6

##### W13-KM2
- Người: Kim
- Tuần: 11 | Giờ ước tính: 2 | Nguồn: DỜI
- Trạng thái: Chưa bắt đầu
- Việc: Vòng sáng slot ở PREP, tắt ở COMBAT (SLOT-06) [dời từ tuần 13]
- Nghiệm thu: Chỉ hiện trên slot còn xây được
- Cần xong trước: W7-KM1

##### W13-KM4
- Người: Kim
- Tuần: 11 | Giờ ước tính: 2 | Nguồn: DỜI
- Trạng thái: Chưa bắt đầu
- Việc: Preset hạt FBK-09 [dời từ tuần 13]
- Nghiệm thu: Giới hạn 500/1500/3000
- Cần xong trước: W7-KM1

##### W11-KM7
- Người: Kim
- Tuần: 11 | Giờ ước tính: 3 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Chỉnh camera cùng Level trên map thật: size Frontline và overview, camera_bounds, tốc độ dịch; chạy CM1, CM2, CM3
- Nghiệm thu: CM1, CM2, CM3 đạt trên map thật
- Cần xong trước: W9-KM6

##### W11-KM8
- Người: Kim
- Tuần: 11 | Giờ ước tính: 8 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Model vũ khí và VFX: Frost (lớp băng), Chain Lightning (tia điện), Burn (lửa), Rampage (đổi ánh kiếm kèm biểu tượng), Swift (vệt chém nhanh), icon; dùng lại mesh vũ khí KayKit hiện có
- Nghiệm thu: Mỗi vũ khí nhận ra được ở camera chuẩn, giảm nhấp nháy theo ACC-06
- Tệp liên quan: contents/, art/vfx/, art/icons/
- ID SRS: FBK-13, WPN-01
- Cần xong trước: W9-NG6

##### W11-KM9
- Người: Kim
- Tuần: 11 | Giờ ước tính: 6 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Model quân mới, phần 2 (Suicide Squad, Captain, Knight, Undead) và hiệu ứng FBK-14 (giáp sáng Knight, xương Undead, telegraph nổ)
- Nghiệm thu: Bốn loại khác nhau rõ; telegraph hiện trước nổ
- Tệp liên quan: contents/, art/
- ID SRS: 3.7.8, FBK-14, FBK-06
- Cần xong trước: W10-KT7

##### W11-KM10
- Người: Kim
- Tuần: 11 | Giờ ước tính: 4 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Model 3 bậc cho tower, phần 2 (Barricade và Trạm hồi lực, bậc 2 và 3)
- Nghiệm thu: Bậc 2 và 3 khác bậc 1
- Tệp liên quan: entities/tower/barricade.tscn, heal_station.tscn
- ID SRS: TWR-17
- Cần xong trước: W10-KM10

### Tuần 12 (30/11-6/12)

Gameplay đóng băng 29/11, toàn bộ tính năng đóng băng 6/12. Tuần này không thêm tính năng: chỉ hoàn thiện online, kiểm thử tích hợp, cân bằng cuối trong `balance.xlsx`, build. Các task 'đệm' dùng để sửa lỗi của chính các task v2.0.

#### Ngọc (Player & Combat), tuần 12, 18h

##### W12-NG1
- Người: Ngọc
- Tuần: 12 | Giờ ước tính: 6 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Build Windows; đo ACP-01..04 trên máy yếu nhất (70 quân, 6 tower, 200 projectile)
- Nghiệm thu: 1% FPS thấp nhất >= 45; RunLoading < 5 s
- Cần xong trước: Đóng băng 29/11

##### W12-NG2
- Người: Ngọc
- Tuần: 12 | Giờ ước tính: 3 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Sửa lỗi hiệu năng và blocker (đệm)
- Nghiệm thu: Không blocker
- Cần xong trước: W12-NG1

##### W12-NG3
- Người: Ngọc
- Tuần: 12 | Giờ ước tính: 4 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Kiểm thử online AC1..AC8 cùng Khang, Kiệt, Mạnh; AC9 (lượt chơi thật nhanh nhất không bị từ chối)
- Nghiệm thu: AC1..AC9 đạt
- Cần xong trước: W11-KH4, W11-MH6

##### W12-NG4
- Người: Ngọc
- Tuần: 12 | Giờ ước tính: 3 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Dự phòng demo: sao lưu backend, bản demo offline, kiểm tra backend trước ngày diễn tập
- Nghiệm thu: Chạy được demo khi tắt mạng
- Cần xong trước: W11-NG5

##### W12-NG5
- Người: Ngọc
- Tuần: 12 | Giờ ước tính: 2 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Chạy lại test WP1..WP8 và HZ1..HZ12 trên bản cuối
- Nghiệm thu: Tất cả đạt
- Cần xong trước: W11-NG7

#### Kiệt (Enemy & Wave), tuần 12, 18h

##### W12-KT1
- Người: Kiệt
- Tuần: 12 | Giờ ước tính: 6 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Cân bằng cuối trong balance.xlsx: boss_timer trước, HP sau; XP; wave 20-30 (SCL-04); Trạm hồi lực
- Nghiệm thu: Người mới diệt Bulwark trước giờ 60-75%; người thành thạo chạm wave 30
- Cần xong trước: W11-KT4, W11-KT6

##### W12-KT2
- Người: Kiệt
- Tuần: 12 | Giờ ước tính: 3 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Sửa lỗi Enemy/Boss/quân mới (đệm)
- Nghiệm thu: Không blocker
- Cần xong trước: W11-KT7

##### W12-KT3
- Người: Kiệt
- Tuần: 12 | Giờ ước tính: 4 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Checklist 7.1 nhóm Enemy, Boss, Skill + NE1..NE8
- Nghiệm thu: Test pass
- Cần xong trước: W11-KT9

##### W12-KT5
- Người: Kiệt
- Tuần: 12 | Giờ ước tính: 3 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Kiểm thử AC6..AC8: thứ tự xếp hạng, luật nộp điểm, kiểm tra ở máy chủ
- Nghiệm thu: AC6..AC8 đạt
- Cần xong trước: W12-NG3

##### W12-KT6
- Người: Kiệt
- Tuần: 12 | Giờ ước tính: 2 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Đệm sửa lỗi tích hợp và cân bằng theo playtest vòng 2
- Nghiệm thu: Không blocker
- Cần xong trước: W12-KM5

#### Mạnh (Tower & Build), tuần 12, 18h

##### W12-MH1
- Người: Mạnh
- Tuần: 12 | Giờ ước tính: 6 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Hồi quy tower, economy, save; cân bằng kinh tế cuối trong balance.xlsx (nhịp danh vọng 3.9.2, giá 36 cấp)
- Nghiệm thu: Không lỗi hồi quy
- Cần xong trước: W11-MH3, W11-MH10

##### W12-MH3
- Người: Mạnh
- Tuần: 12 | Giờ ước tính: 3 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Sửa blocker (đệm)
- Nghiệm thu: Nộp đúng hạn
- Cần xong trước: W12-MH1

##### W12-MH4
- Người: Mạnh
- Tuần: 12 | Giờ ước tính: 7 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: Kiểm thử AC3, AC4 và hồi quy Trạm hồi lực, SELL-05; chạy BL1..BL4, VC1..VC5, TU1..TU4
- Nghiệm thu: AC3, AC4 đạt; HT6..HT12 vẫn đạt
- Cần xong trước: W11-MH5

##### W12-MH5
- Người: Mạnh
- Tuần: 12 | Giờ ước tính: 2 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Chạy lại runner BAL sau mọi lần chỉnh bảng cuối; chốt balance.xlsx và bộ .tres sinh ra
- Nghiệm thu: BL3 pass trên bản đóng băng
- Cần xong trước: W12-KT1

#### Khang (UI/UX & Meta), tuần 12, 18h

##### W12-KH1
- Người: Khang
- Tuần: 12 | Giờ ước tính: 4 | Nguồn: CŨ-SỬA
- Trạng thái: Chưa bắt đầu
- Việc: QA giao diện tiếng Việt (dấu, tràn khung, LOC-03) gồm chuỗi v2.0; đo UI < 10% frame (ACP-07)
- Nghiệm thu: Không tràn khung ở 1280x720
- Cần xong trước: W11-KH7

##### W12-KH2
- Người: Khang
- Tuần: 12 | Giờ ước tính: 3 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Sửa lỗi UI (đệm)
- Nghiệm thu: Không blocker
- Cần xong trước: W12-KH1

##### W13-KH2
- Người: Khang
- Tuần: 12 | Giờ ước tính: 2 | Nguồn: DỜI
- Trạng thái: Chưa bắt đầu
- Việc: Slow motion 0.2x cuối run trên hoạt cảnh RunEnd (FBK-10) [dời từ tuần 13]
- Nghiệm thu: RunState đóng băng trước khi chạy hiệu ứng
- Cần xong trước: W11-KH1

##### W12-KH5
- Người: Khang
- Tuần: 12 | Giờ ước tính: 7 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Hoàn thiện Leaderboard và Login, chạy AC tests phía giao diện, QA chữ tiếng Việt màn mới, đo ACP-08
- Nghiệm thu: AC1, AC2, AC6, AC7 đạt
- Cần xong trước: W11-KH4

##### W12-KH6
- Người: Khang
- Tuần: 12 | Giờ ước tính: 2 | Nguồn: MỚI
- Trạng thái: Chưa bắt đầu
- Việc: Kiểm toàn bộ luồng người chơi mới: MainMenu -> tutorial -> wave -> Hazard -> RunEnd bằng tay một lượt và ghi lỗi
- Nghiệm thu: Danh sách lỗi luồng
- Cần xong trước: Đóng băng 29/11

#### Kim (Art/Level/Audio), tuần 12, 18h

##### W12-KM2
- Người: Kim
- Tuần: 12 | Giờ ước tính: 2 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Ghi credit và license mọi asset ngoài (gồm model dùng lại)
- Nghiệm thu: Danh sách license đủ
- Cần xong trước: Mốc B2

##### W12-KM3
- Người: Kim
- Tuần: 12 | Giờ ước tính: 7 | Nguồn: DỜI
- Trạng thái: Chưa bắt đầu
- Việc: Skin UI (menu, shop, RunEnd, màn thắng), màn Splash và Loading, skin Login và Leaderboard [thay cho đệm; dời từ tuần 10]
- Nghiệm thu: Đồng bộ palette; hiển thị tiến trình tải
- Cần xong trước: W11-KH1, W11-KH6

##### W12-KM5
- Người: Kim
- Tuần: 12 | Giờ ước tính: 5 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Playtest vòng 2 có online, ghi số liệu
- Nghiệm thu: >= 5 người chơi
- Cần xong trước: Đóng băng 29/11

##### W12-KM6
- Người: Kim
- Tuần: 12 | Giờ ước tính: 4 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Đệm polish camera, VFX trạm, skin UI mới, sửa lỗi hiển thị
- Nghiệm thu: Không còn lỗi hiển thị ở 1280x720
- Cần xong trước: W12-KM5

### Tuần 13 (7-14/12)

Chỉ test, sửa lỗi, báo cáo và video. 14/12 đóng băng bản nộp, 15 và 16/12 dự phòng, 17/12 diễn tập.

#### Ngọc (Player & Combat), tuần 13, 12h

##### W13-NG1
- Người: Ngọc
- Tuần: 13 | Giờ ước tính: 4 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Báo cáo phần Player & Combat
- Nghiệm thu: Nộp đúng hạn
- Cần xong trước: Đóng băng 6/12

##### W13-NG2
- Người: Ngọc
- Tuần: 13 | Giờ ước tính: 4 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Đệm sửa lỗi Combat, Skill, hiệu năng
- Nghiệm thu: Không blocker
- Cần xong trước: W12-NG2

##### W13-NG3
- Người: Ngọc
- Tuần: 13 | Giờ ước tính: 4 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Hồi quy online và chạy thử toàn bộ demo từ máy sạch
- Nghiệm thu: Demo chạy từ máy sạch cả khi có và không có mạng
- Cần xong trước: W12-NG4

#### Kiệt (Enemy & Wave), tuần 13, 12h

##### W13-KT1
- Người: Kiệt
- Tuần: 13 | Giờ ước tính: 4 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Đệm sửa lỗi Enemy, Boss, cân bằng theo playtest lần cuối
- Nghiệm thu: Không blocker
- Cần xong trước: W12-KT1

##### W12-KT4
- Người: Kiệt
- Tuần: 13 | Giờ ước tính: 4 | Nguồn: DỜI
- Trạng thái: Chưa bắt đầu
- Việc: Báo cáo phần Enemy và Wave [dời]
- Nghiệm thu: Nộp đúng hạn
- Cần xong trước: W12-KT1

##### W13-KT2
- Người: Kiệt
- Tuần: 13 | Giờ ước tính: 4 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Chạy lại checklist 7.1 nhóm Enemy, Boss
- Nghiệm thu: Checklist đạt
- Cần xong trước: W12-KT6

#### Mạnh (Tower & Build), tuần 13, 12h

##### W13-MH1
- Người: Mạnh
- Tuần: 13 | Giờ ước tính: 4 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Đệm sửa lỗi Tower, Economy, Save; hồi quy lần cuối
- Nghiệm thu: Không lỗi hồi quy
- Cần xong trước: W12-MH1

##### W12-MH2
- Người: Mạnh
- Tuần: 13 | Giờ ước tính: 4 | Nguồn: DỜI
- Trạng thái: Chưa bắt đầu
- Việc: Báo cáo phần Tower, Economy, Save [dời]
- Nghiệm thu: Nộp đúng hạn
- Cần xong trước: W12-MH1

##### W13-MH2
- Người: Mạnh
- Tuần: 13 | Giờ ước tính: 4 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Hồi quy cuối online và kinh tế
- Nghiệm thu: Đạt
- Cần xong trước: W12-MH4

#### Khang (UI/UX & Meta), tuần 13, 12h

##### W13-KH3
- Người: Khang
- Tuần: 13 | Giờ ước tính: 3 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Đệm sửa lỗi UI
- Nghiệm thu: Không tràn khung ở 1280x720
- Cần xong trước: W12-KH2

##### W12-KH3
- Người: Khang
- Tuần: 13 | Giờ ước tính: 4 | Nguồn: DỜI
- Trạng thái: Chưa bắt đầu
- Việc: Tổng hợp báo cáo (5 người) [dời]
- Nghiệm thu: Báo cáo đủ phần của 5 người
- Cần xong trước: W12-KT4, W12-MH2, W12-KM4

##### W12-KH4
- Người: Khang
- Tuần: 13 | Giờ ước tính: 2 | Nguồn: DỜI
- Trạng thái: Chưa bắt đầu
- Việc: Báo cáo phần UI/Meta [dời]
- Nghiệm thu: Nộp đúng hạn
- Cần xong trước: W11-KH3

##### W13-KH4
- Người: Khang
- Tuần: 13 | Giờ ước tính: 3 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: QA giao diện lần cuối sau đóng băng
- Nghiệm thu: Không tràn khung ở 1280x720
- Cần xong trước: W12-KH5

#### Kim (Art/Level/Audio), tuần 13, 12h

##### W13-KM5
- Người: Kim
- Tuần: 13 | Giờ ước tính: 3 | Nguồn: CŨ
- Trạng thái: Chưa bắt đầu
- Việc: Đệm sửa lỗi Art/Audio
- Nghiệm thu: Không blocker
- Cần xong trước: W12-KM6

##### W12-KM1
- Người: Kim
- Tuần: 13 | Giờ ước tính: 6 | Nguồn: DỜI
- Trạng thái: Chưa bắt đầu
- Việc: Quay video demo, ảnh chụp (có Hazard Trial, vũ khí, thắng và endless) [dời]
- Nghiệm thu: Video hoàn chỉnh có phần online và Trạm hồi lực
- Cần xong trước: Đóng băng 6/12, W13-NG3

##### W12-KM4
- Người: Kim
- Tuần: 13 | Giờ ước tính: 3 | Nguồn: DỜI
- Trạng thái: Chưa bắt đầu
- Việc: Báo cáo phần Art/Audio [dời]
- Nghiệm thu: Nộp đúng hạn
- Cần xong trước: Đóng băng 6/12

## 5. Điểm cần nhớ khi ghép các phần với nhau

Những chỗ dễ làm 'rách' game nếu hai người làm riêng:

1. **Gold của quân:** `enemy.gd` phát `enemy_died` với kill_gold đã gồm hệ số chỉ huy; `WaveManager` không được nhân `frontline_gold_mult` lần nữa (W10-MH7). Hazard Trial dùng đúng công thức này (GLD-10, không clear_mult).
2. **Phím E** vừa là hồi máu (`heal_channel`, chỉ ở COMBAT/BOSS_COMBAT, Frontline) vừa là vào Hazard Trial (`hazard_enter`, chỉ ở PREP, Frontline). Hai action tách riêng trong InputMap (W9-KT6, W10-KH7).
3. **Trạng thái wave:** `HAZARD_TRIAL` thêm vào cuối `Enums.WaveState`; ra khỏi phòng quay về PREP cùng wave, không hồi 35% lần hai, không đổi mức tua (W10-KT4). Tua x1/x2/x3 vẫn dùng trong phòng.
4. **Pause:** `TimeManager` có lý do `USER`, `REWARD_PICK`, thêm `VICTORY` (W11-NG9). Màn thắng chạy trước REWARD_PICK (WAVE-13).
5. **XP của Hazard Trial** cộng khi rời phòng; lượt chọn sinh ra chờ tới REWARD_PICK của wave đó (XP-06, RWP-01).
6. **Mithril** nằm trong `RunState` (không lưu đĩa), nguồn duy nhất là thắng Hazard Trial (W10-KT5), nơi tiêu duy nhất là sửa Fortress (W9-MH2). Trước khi Hazard xong thì cấp bằng debug để thử.
7. **Bảng cân bằng:** mọi `.tres` của nhân vật, skill, tower, vũ khí, quân, WaveScript, WaveRewardTable do công cụ sinh. Người sửa số phải sửa `balance.xlsx` rồi chạy lại công cụ (W9-NG7, W10-NG8) và chạy runner BAL (W11-NG10).
8. **Lưới và đường đi:** GRID-07 (W9-MH5) và GRID-08 (W9-KM7) dựa vào `boss_melee_point` (W9-KM6); trụ có sẵn (W10-MH10) phải nằm ngoài vùng cấm GRID-08.
9. **Run đầu tiên và các run sau:** `flags.tutorial_done` trong save quyết định có tutorial hay hai trụ có sẵn (W10-MH10, W11-NG1); cờ này đồng bộ theo tài khoản (W10-NG5, W11-KH4).
10. **Tắt va chạm giữa quân** (W9-KT5) đổi hành vi xếp hàng ở Fortress và Barricade; sau đó phải chạy lại crowd, thang kẹt và boss (W10-NG3, W11-KT5, W11-NG4).

## 6. Việc ngoài MVP (không làm trừ khi MVP xong sớm)

WAVE-12 (công tắc tự bắt đầu wave), TUT-06 và TUT-16 (gợi ý tutorial thêm), StartSelect/StartPack soạn lại, Barrage, merge skill, Reroll, hoàn tác bán, rebind phím, migration save và các mục Should/Could khác của backlog trong bảng Excel. Các dòng backlog lỗi thời vì v2.0 (Trượng phép, di chuyển tower, STARTER_KIT) nằm ở sheet 'Backlog đề xuất chỉnh' của file Excel.
