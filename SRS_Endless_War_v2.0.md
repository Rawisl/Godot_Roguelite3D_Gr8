# SOFTWARE REQUIREMENTS SPECIFICATION

## Chiến Tuyến Vô Tận (Endless War)

| **Hạng mục** | **Nội dung** |
| --- | --- |
| Mã tài liệu | SRS-EW-2.0 |
| Phiên bản | 2.0. Dựa trên v1.9, áp các thay đổi đã chốt trong bản xem trước `preview_srs_v2.0_hazard.md` (chốt 05/11). Sáu thay đổi lớn: (1) PREP không đếm ngược, người chơi tự bấm bắt đầu wave, bỏ gọi wave sớm và phím G; trong PREP được vào Hazard Trial một lần mỗi wave (HZT), thắng phòng được Mithril, dùng để sửa Fortress thay cho gold (MTH). (2) Vũ khí là biến thể của kiếm với 5 hiệu ứng, boss wave 5 đến 25 chắc chắn rơi một cây chưa có (WPN). (3) Xây ít chỗ hơn: 3 slot WALL và tối đa 3 công trình trên ô grid (tổng 6), lưới đất phủ cả bề ngang hành lang, bỏ no_build_lane, thêm luật cấm chặn kín đường (GRID-07); tower có cấp 1-36, đổi model ở cấp 13 và 25; bỏ di chuyển tower (MOV). (4) Mỗi run bắt đầu với 0 gold và hai trụ có sẵn (Arrow, Cannon); tutorial chạy một lần theo tài khoản. (5) Có màn thắng khi qua wave `victory_wave` (30), sau đó chơi tiếp endless. (6) Thêm 7 loại quân mới, sửa Brute, tắt va chạm giữa quân, mỗi wave tối đa 5 loại kể cả boss. Số liệu cân bằng lấy từ bảng Excel và công cụ dịch sang `.tres` (BAL). Mã bị bỏ ghi ở Phụ lục E. Bản này tự đứng được, không cần đọc kèm v1.9 |
| Ngày phát hành | 05/11/2026 |
| Nền tảng phát triển | Godot 4.x, 3D, camera orthographic isometric |
| Đội ngũ, thời gian | 5 người, 13 tuần: Tuần 1-12 làm tính năng (đóng băng toàn bộ tính năng 6/12), Tuần 13 (7-14/12) chỉ test, sửa lỗi, báo cáo và nộp bài (đóng băng bản nộp 14/12), 15-16/12 dự phòng, 17/12 diễn tập (mục 7.3). Tuần 1-8 đã hoàn thành theo v1.9, phần v2.0 áp dụng từ Tuần 9 |
| Trạng thái | **Thiết kế đã duyệt:** Đã duyệt toàn bộ yêu cầu v2.0 ở mục 3 đến 7.2 cùng các quyết định Phụ lục C mục 38 đến 66 ngày 05/11. **Chưa chốt:** lịch v2.0 (mục 7.3) và phân vai v2.0 (Phụ lục B), chờ bảng phân công cập nhật. Mọi con số là giá trị khởi điểm. Số liệu cân bằng (nhân vật, tower, skill, vũ khí, quân theo wave, thưởng theo wave) chỉnh trong bảng cân bằng (mục 6.10), các tham số khác chỉnh qua Resource/GameConfig khi playtest. Chỗ v2.0 tự đặt thêm ngoài bản xem trước ghi ở Phụ lục C mục 38 đến 66 |

## Mục lục

1. Giới thiệu

2. Mô tả tổng quan

3. Yêu cầu chức năng

   - 3.1 Luồng ứng dụng
   - 3.2 Vòng đời Run
   - 3.3 Wave
   - 3.4 Điều khiển thời gian
   - 3.5 Nhân vật chỉ huy
   - 3.6 Fortress, Build slot, Grid và Tower
   - 3.7 Kẻ địch, Spawner và Scale
   - 3.8 Boss
   - 3.9 Kinh tế: Gold, Uy tín, Danh vọng
   - 3.10 Meta shop và Buff một wave
   - 3.11 Chọn wave khởi đầu và áp dụng meta
   - 3.12 Save/Load
   - 3.13 Tài khoản và đồng bộ profile \[MVP rút gọn]
   - 3.14 Bảng xếp hạng \[MVP rút gọn]
   - 3.15 Hazard Trial

4. Yêu cầu giao diện ngoài

   - 4.1 Giao diện người dùng: màn hình, HUD, panel
   - 4.2 Input, chuột và camera trong isometric
   - 4.3 Cảnh báo và thông báo
   - 4.4 Phản hồi và hiệu ứng
   - 4.5 Âm thanh
   - 4.6 Settings
   - 4.7 Hướng dẫn (tutorial)

5. Yêu cầu phi chức năng

6. Yêu cầu dữ liệu

7. Kiểm chứng và nghiệm thu

8. Phụ lục

# 1. GIỚI THIỆU

## 1.1 Mục đích

Tài liệu đặc tả đầy đủ yêu cầu của game Chiến Tuyến Vô Tận (Endless War), làm căn cứ chung cho thiết kế, lập trình, cân bằng, kiểm thử và nghiệm thu của nhóm 5 người. Mỗi yêu cầu có ID duy nhất để trích dẫn khi chia task và viết test.

## 1.2 Phạm vi sản phẩm

Game PC một người chơi, thể loại Action Tower Defense, Strategy, Roguelite. Người chơi là chỉ huy bảo vệ **Fortress** trước các làn sóng quái vật, điểm số là **số wave hoàn thành** trong một run. Qua wave victory_wave (30) là thắng, sau đó run chơi tiếp ở chế độ endless đến khi thua hoặc bỏ (mục 3.2.4). Giữa các run, người chơi dùng **Danh vọng** để mạnh dần qua meta shop.

**Ngoài phạm vi (Won't):** material và crafting, nhiều map, xây dựng tự do (free-placement; ô grid ở mục 3.6.2 không phải free-placement vì mỗi ô là một slot cố định), cơ chế "bỏ thành" và 3 lần bỏ thành, checkpoint giữa run, multiplayer thời gian thực, đồng bộ trạng thái run lên đám mây (tài khoản, đồng bộ profile và bảng xếp hạng ở mục 3.13 và 3.14 chỉ ở mức rút gọn \[MVP], phần mở rộng là \[Should]), lồng tiếng, tự bạo boss gây sát thương TRUE (Overload) và hành động Retreat. Bỏ ở v2.0: di chuyển và hoán đổi tower (MOV), gọi wave sớm, đếm ngược PREP, sửa Fortress bằng gold, STARTER_KIT, Trượng phép và mục shop UNLOCK_WAND (Phụ lục E).

## 1.3 Thuật ngữ

| **Thuật ngữ** | **Định nghĩa** |
| --- | --- |
| Run | Một lượt chơi từ lúc xuất phát đến khi thua hoặc bỏ. Không lưu giữa chừng. Qua victory_wave thì run đã thắng và chơi tiếp endless (mục 3.2.4) |
| Wave | Một đợt quân địch. Gồm các state PREP, COMBAT, SUMMARY (và BOSS_INTRO, BOSS_COMBAT ở wave boss). Trong PREP có thể vào HAZARD_TRIAL rồi quay lại PREP |
| Fortress | Thành chính, duy nhất, cố định. HP về 0 thì hết run |
| Tower | Công trình tấn công hoặc phòng thủ (Arrow, Cannon, Barricade, Trạm hồi lực), đặt trong build slot. Cấp 1 đến 36, chia ba bậc model (TWR-17) |
| Build slot | Vị trí xây cố định, thuộc zone WALL hoặc GROUND. Slot WALL là Marker3D đặt tay; slot GROUND là ô grid sinh sẵn từ GridData lúc nạp level (mục 3.6.2). Zone NEAR và FAR của v1.6 gộp thành GROUND vì có cùng luật |
| Ô grid (cell) | Một slot GROUND có kích thước grid_cell_size, slot_id là cell_id dạng G_c_r (GRID-01) |
| BLOCKS_PATH | Lý do từ chối xây khi công trình định xây làm mất đường đi từ spawn_zone tới cổng Fortress hoặc tới boss_melee_point (GRID-07). Thay cho no_build_lane của v1.9 |
| Frontline | Chế độ chỉ huy chiến đấu trực tiếp trên mặt đất. Là chế độ tăng trưởng: XP, skill, Aura, gold chỉ huy (mục 3.5.10 đến 3.5.12) |
| Commander | Chế độ chỉ huy đứng trên tường Fortress điều phối, bất khả xâm phạm nhưng không gây sát thương và không nhận bonus Frontline (CMD-10) |
| Recall | Channel để đổi từ Frontline về Commander, có thể bị ngắt |
| Telegraph | Vùng cảnh báo hiển thị trước đòn AoE |
| Enrage (Cuồng nộ) | Trạng thái boss khi đồng hồ boss_timer về 0 mà boss còn sống: nhanh hơn, đánh mạnh hơn, vĩnh viễn đến khi chết (ENR-01) |
| XP, Cấp Chỉ huy | XP nhận khi quân chết, chia theo cờ hit_by_commander (XP-01). Đủ XP thì lên Cấp Chỉ huy, mỗi cấp cho 1 lượt chọn ở REWARD_PICK và mở khóa nâng cấp tower (FRT-03). Chỉ tồn tại trong run |
| hit_by_commander | Cờ của từng quân, bật ở lần đầu chỉ huy gây ≥ 1 sát thương lên quân đó (XP-03) |
| Aura Tiền tuyến | Bonus sát thương cho tower trong bán kính khi chỉ huy ở Frontline (FRT-01) |
| Skill | Kỹ năng nhặt trong run qua REWARD_PICK: chủ động (phím 1-3), bị động. Khác kỹ năng nền (đòn kiếm, Dodge, Battle Cry, Recall/Deploy, Emergency repair) không chiếm ô (SKL-01) |
| REWARD_PICK | State sau SUMMARY: người chơi dùng hết lượt chọn đang chờ, mỗi lượt 3 chọn 1 (mục 3.3.6) |
| Uy tín (prestige_pending) | Điểm tích lũy trong run |
| Danh vọng (prestige_balance) | Tiền tệ vĩnh viễn, quy đổi từ Uy tín khi hết run |
| StartPack \[Should] | Gói xuất phát cố định theo mốc wave (gold, công trình, hệ số) |
| Game time | Thời gian đã nhân time_scale, dừng khi Pause. Dùng cho mọi timer gameplay |
| Resource | Tệp dữ liệu .tres của Godot chứa tham số, chỉnh không cần sửa code |
| EventBus | Autoload phát tín hiệu chung giữa hệ thống |
| damage_type | Loại sát thương: PIERCE, BLAST, SLASH, MAGIC, TRAP, TRUE (TRUE ở v1.8 chỉ còn cú rơi khỏi map) |
| RUINED | Trạng thái build slot khi tower bị phá. Slot nhớ loại và cấp của tower đã mất để xây lại giữ cấp (SLOT-02, SLOT-08). Người chơi có thể dọn đống đổ nát để slot về EMPTY (CLR-01) |
| nav_progress | Mét đã đi dọc lane_curve, tính bằng lane_ref_length trừ số mét còn lại tới cổng Fortress. Dùng chung cho quân đi bộ và quân bay để xếp thứ tự First (TWR-16) |
| lane_curve | Curve3D tim hành lang từ spawn_zone đến cổng Fortress, do Level sở hữu (TWR-16) |
| Xây lại (rebuild) | Dựng lại tower bị phá ở đúng cấp cũ trong một lần bấm, giá bằng tổng cost cấp 1 đến cấp đó theo TowerData (BLD-07) |
| Dọn đổ nát (clear ruin) | Đưa slot RUINED về EMPTY ở PREP, miễn phí, bỏ đống đổ nát cùng ruined_type và ruined_level (CLR-01) |
| clear_mult, par_time | Hệ số gold theo tốc độ dọn wave (Fast 1.25, Normal 1.00, Slow 0.80), so clear time với par_time (mục 3.3.3) |
| Emergency repair | Hồi HP Fortress miễn phí gold, chỉ ở Commander mode, tối đa 3 lượt mỗi run, +1 lượt khi diệt boss (CMD-02, BRW-07) |
| FRENZY | Trạng thái quân lẻ sau 240 s: tốc độ x1.5, đi thẳng Fortress (EN-02) |
| Recycle, Cull | Hai bậc cuối của thang xử lý kẹt: đưa quân về spawn_zone (NAV-08), hoặc xóa quân không thưởng (NAV-09) |
| RunConfig, RunState | RunConfig: giá trị cố định của một run, tạo ở RunLoading. RunState: trạng thái thay đổi trong run (mục 3.2.2, 6.7) |
| Trạm hồi lực (heal tower) | Loại tower thứ tư, cấp 1-36 như tower khác (kho HP theo cấp), chỉ đặt trên ô grid. HP của trạm vừa là máu vừa là kho để chỉ huy Frontline hút hồi máu. Hết kho hoặc bị quân phá thì thành RUINED, không tự hồi (mục 3.6.6) |
| Hold, Healing | Hai pha của heal_channel (phím E). Hold: giữ phím đủ heal_hold_time để được phép hồi. Healing: hồi liên tục đến khi có hành động khác, đầy máu hoặc hết kho (HLT-03 đến HLT-05) |
| camera_bounds | Hình chữ nhật trên mặt phẳng ngang do Level đặt tay, giới hạn điểm focus của camera (CAM-04) |
| Chơi khách, tài khoản \[MVP rút gọn] | Chơi khách là chế độ mặc định, không cần mạng, không có hạng. Tài khoản đồng bộ profile lên máy chủ và cho phép lên bảng xếp hạng (mục 3.13, 3.14) |
| Hazard Trial (HAZARD_TRIAL) | Phòng thử thách bên trong Tháp Hazard Trial, một công trình đứng gần Fortress (không phải cổng). Vào được một lần mỗi wave, chỉ trong PREP: 5 quái lấy từ wave sắp tới. Thắng phòng được Mithril. Chỉ số chỉ huy trong phòng độc lập với bên ngoài (mục 3.15) |
| Mithril | Tài nguyên trong run, chỉ kiếm từ Hazard Trial, dùng để sửa Fortress ở PREP. Mỗi viên sửa 20% fortress_max_hp (mục 3.9.3) |
| Vũ khí (weapon) | Biến thể của kiếm, khác tầm đánh, VFX, model và một hiệu ứng (Frost, Chain Lightning, Burn, Rampage, Swift). Chỉ giữ trong run (mục 3.5.13) |
| Kiếm gốc | Vũ khí mặc định đầu run, không có hiệu ứng (WPN-02) |
| victory_wave | Wave mốc thắng, mặc định 30, trong GameConfig. Hoàn thành wave này là thắng (END-07) |
| Endless | Phần run sau khi đã thắng. Chết hay bỏ ở endless là "sống sót", tổng kết ghi số wave (END-10) |
| Trụ có sẵn (starter tower) | Một Arrow và một Cannon cấp 1 đặt ở slot mặc định đầu mỗi run khi tutorial đã xong (mục 3.2.1, SELL-06) |
| tutorial_done | Cờ trong profile.flags, bật khi hoàn thành hoặc bỏ qua tutorial; đồng bộ theo tài khoản (mục 4.7, ACCT-04) |
| Bậc model (tier) | Nhóm cấp tower dùng chung một model: bậc 1 cấp 1-12, bậc 2 cấp 13-24, bậc 3 cấp 25-36 (TWR-17) |
| Bảng cân bằng | Tệp `balance/balance.xlsx`, nguồn gốc duy nhất của số liệu cân bằng; công cụ dịch sinh `.tres` từ bảng (mục 6.10) |

## 1.4 Quy ước

| **Mục** | **Quy ước** |
| --- | --- |
| ID yêu cầu | Dạng PREFIX-nn. Bảng tiền tố ở Phụ lục A |
| Tham số | snake_case, lưu trong GameConfig và các Resource. Giá trị ghi kèm là giá trị khởi điểm |
| Số liệu cân bằng | Từ v2.0, chỉ số nhân vật, tower (36 cấp), skill, vũ khí, chỉ số quân, kịch bản quân và thưởng theo wave 1-30 nằm trong bảng cân bằng (mục 6.10). Số ghi trong SRS cho các nhóm này là giá trị khởi điểm để viết logic và test, bảng là nguồn chuẩn |
| Thời gian | Timer gameplay dùng game time. Animation UI, cảnh báo, fade dùng thời gian thực |
| Điểm số | waves_cleared = số wave đã hoàn thành trọn vẹn. Chết ở wave N nghĩa là waves_cleared = N-1 |
| Ưu tiên | \[MVP] bắt buộc, \[Should] làm nếu đủ tiến độ, \[Could] chỉ khi dư thời gian. Không đánh dấu nghĩa là MVP. ID của mục bị chuyển sang \[Should] được giữ nguyên để không gãy tham chiếu |
| Làm tròn | Làm tròn một lần ở cuối công thức, trừ khi ghi khác. Mặc định: khoản người chơi nhận (gold, uy tín, danh vọng, tiền hoàn bán, HP sửa bằng Mithril) làm tròn xuống. Khoản người chơi phải trả là số nguyên trong dữ liệu (giá xây, nâng). Sát thương lên chỉ huy và Fortress làm tròn lên. Sát thương lên quân thường và boss làm tròn gần nhất (DMG-06). Chỉ số quân, boss và budget theo công thức scale làm tròn gần nhất |
| Máu hồi | commander_hp lưu float trong RunState để hồi nhỏ (Lifesteal 0.5%, Healing theo frame) không bị cắt về 0. Chỉ làm tròn xuống khi hiển thị và khi phát commander_hp_changed (EVB-08). Chết khi commander_hp <= 0 |
| Mức độ bắt buộc | "phải" là bắt buộc, "nên" là khuyến nghị, "có thể" là tùy chọn |

## 1.5 Cấu trúc tài liệu

Mục 3 và 4: yêu cầu chức năng và giao diện, mỗi mục con gồm mô tả, dữ liệu, luật (ID), edge case. Mục 5: phi chức năng. Mục 6: tham số và cấu trúc dữ liệu. Mục 7: test case và lịch nghiệm thu. Phụ lục: bảng tiền tố ID, phân vai, vấn đề còn mở, nhật ký đồng bộ so với các bản trước. Từ v1.8, mọi yêu cầu mới đều gắn rõ \[MVP] hoặc \[Should]; ID của mục bị xóa ở v1.8 và v1.9 được giữ lại với nhãn \[ĐÃ XÓA v1.8] hoặc \[ĐÃ XÓA v1.9]. Từ v2.0, mã bị bỏ được xóa khỏi bảng và ghi ở Phụ lục E (mã, lý do), số mã cũ không dùng lại cho nghĩa mới. Mục mới của v2.0 không ghi tag thì là MVP.

# 2. MÔ TẢ TỔNG QUAN

## 2.1 Bối cảnh sản phẩm

| **Hạng mục** | **Nội dung** |
| --- | --- |
| Góc nhìn | Camera orthographic isometric cố định, nhìn ngang từ trái sang phải. Fortress ở cực trái, điểm spawn ở cực phải, map là hành lang ngang |
| Map | 1 map duy nhất. Tính ngẫu nhiên nằm ở nội dung wave, không ở địa hình. Người chơi học bố cục slot và tối ưu qua các run |
| Điểm khác biệt | Người chơi tự chọn ra trận trực tiếp (rủi ro cao, thưởng cao) hoặc điều phối từ trên thành (an toàn, phụ thuộc bố trí) |
| Trụ cột | Một vòng lặp chiều sâu: Chuẩn bị (kèm Hazard Trial tùy chọn), Chiến đấu, Tổng kết, Wave kế. Mọi thứ khác là mở rộng |

## 2.2 Chức năng chính

1. Vòng lặp wave: wave 1-30 theo kịch bản trong bảng cân bằng, qua victory_wave (30) là thắng, sau đó endless với công thức scale (mục 3.7.6).
2. Hai chế độ điều khiển (Frontline, Commander) dùng chung một camera, một nhân vật. Frontline là chế độ tăng trưởng (XP, skill, Aura, gold chỉ huy, Hazard Trial); Commander là chế độ phòng thủ và quản lý (priority, Emergency repair).
3. Xây dựng phòng thủ trên slot cố định: 3 slot WALL và ô grid phủ bề ngang hành lang (tối đa 3 công trình trên grid, tổng 6), 4 loại tower (Arrow, Cannon, Barricade, Trạm hồi lực), mỗi loại cấp 1-36 với ba bậc model. Nâng lên bậc 2 và bậc 3 bị giới hạn theo Cấp Chỉ huy (FRT-03). Luật cấm chặn kín đường (GRID-07). Dọn đống đổ nát ở PREP (CLR). Mỗi run có sẵn một Arrow và một Cannon.
4. Kẻ địch data-driven với bảng ưu tiên mục tiêu: 3 loại gốc (Grunt, Archer, Brute bản sửa) và 7 loại mới (Sniper, Assassin, Rider, Suicide Squad, Suicide Squad Captain, Knight, Undead). Mỗi wave tối đa 5 loại kể cả boss.
5. Wave boss với giáp theo pha, đồng hồ Cuồng nộ. Boss wave 5 đến 25 rơi vũ khí.
6. Tiến triển roguelite: Danh vọng và meta shop 4 mục. Trong run: Skill Tree 3 chọn 1 từ XP, 5 vũ khí từ boss. Buff một wave và chọn wave khởi đầu là \[Should].
7. Tua tốc độ thay cho checkpoint. PREP không giới hạn thời gian, người chơi tự bấm bắt đầu wave.

8. Frontline có phần thưởng riêng và tạo ra sức mạnh mà Commander không có (FRT, XP, SKL).

9. **Hồi máu chỉ có ở tiền tuyến.** Commander mode không còn regen. Trong wave, chỉ huy hồi máu bằng Lifesteal hoặc bằng Trạm hồi lực đặt trên mặt đất (hold E, đứng yên, không bị đánh). Đầu mỗi PREP vẫn hồi 35% cho cả hai chế độ (HLT, mục 3.5.7).

10. Camera theo ngữ cảnh: Frontline bám nhân vật và zoom gần, Commander và PREP dịch bằng phím WASD trong giới hạn camera_bounds (CAM).

11. \[MVP rút gọn] Yếu tố online: tài khoản, đồng bộ profile, bảng xếp hạng, luôn kèm chế độ chơi khách (ACCT, LBD).

12. **Hazard Trial và Mithril (v2.0).** Mỗi PREP được vào một phòng 5 quái của wave sắp tới. Thắng phòng được Mithril, cách duy nhất để sửa Fortress ở PREP (HZT, MTH).

13. **Số liệu cân bằng từ bảng Excel (v2.0).** Một tệp `balance/balance.xlsx`, một lệnh sinh lại mọi `.tres` cân bằng, một runner kiểm config sinh ra (BAL).

## 2.3 Nhóm người dùng

| **Nhóm** | **Đặc điểm** | **Hệ quả yêu cầu** |
| --- | --- | --- |
| Người chơi mới | Chưa biết cơ chế | Tutorial một lần theo tài khoản, hướng dẫn xây hai trụ đầu (mục 4.7), PREP không giới hạn thời gian, wave 1-2 chỉ Grunt, cảnh báo boss rõ |
| Người chơi thành thạo | Chơi lặp, tối ưu | Tua x2/x3, Hazard Trial lấy Mithril, chọn vũ khí, target priority, endless sau wave 30. \[Should] chọn wave khởi đầu |
| Nhóm phát triển (5 vai) | Combat, Enemy & Wave, Tower & Build, UI/Meta, Art/Level/Audio | Dữ liệu tách khỏi code, EventBus, scene sở hữu riêng (mục 5) |

## 2.4 Môi trường vận hành

Windows PC (mục tiêu chính), Godot 4.x, bàn phím và chuột. Gamepad là \[Could]. Cấu hình tối thiểu chốt theo **máy yếu nhất của nhóm** và ghi vào báo cáo (ACP-01).

## 2.5 Ràng buộc

| **Ràng buộc** | **Chi tiết** |
| --- | --- |
| Nhân lực, thời gian | 5 người, 13 tuần. Tuần 1-5 đã xong, Tuần 6-8 làm tính năng v1.8 và v1.9, từ Tuần 9 làm thêm thay đổi v2.0 (mỗi người tối đa 2 phiên mỗi tuần, tuần 10-12 là 3 phiên). Tuần 12 đóng băng toàn bộ tính năng (6/12); Tuần 13 chỉ test, sửa lỗi, báo cáo và nộp bài (14/12). Mục tiêu hoàn thành 80-90% tổng phạm vi ở bản nộp 14/12 (mục 7.3) |
| Asset | Ưu tiên low-poly có sẵn (Kenney, Quaternius), thống nhất palette và shader toon/flat. Mỗi loại tower cần 3 model theo bậc (TWR-17), mỗi vũ khí một model |
| Dữ liệu | Toàn bộ chỉ số trong Resource hoặc CSV, không hard-code. Số liệu cân bằng sinh từ bảng Excel bằng script Python (mục 6.10) |
| Git | Mỗi người sở hữu scene riêng, tách dữ liệu bằng Resource, tránh xung đột .tscn |
| Camera | Góc camera cố định (pitch, yaw), chỉ đổi vị trí và size. Frontline bám nhân vật và zoom gần, không dịch bằng chuột. Commander và PREP dịch bằng WASD, có clamp (CAM). Cuộn chuột zoom và kéo chuột là \[Could] |

## 2.6 Giả định và phụ thuộc

- Người chơi dùng chuột và bàn phím.
- Bố cục hành lang đủ hẹp để nằm trọn trong camera tổng quan.
- Bat (quân bay) là \[Should] và là điều kiện để priority Flying và khả năng bắn trên không của Arrow có ý nghĩa. Bỏ Bat thì bỏ luôn priority Flying.
- Góc camera (camera_pitch -45, camera_yaw 20) là giá trị khởi điểm, chốt ở tuần 1.

## 2.7 Phạm vi theo mức ưu tiên

| **Nhóm** | **Nội dung** |
| --- | --- |
| **Must (MVP)** | 1 map, Fortress, 3 slot WALL cố định và ô grid mặt đất phủ bề ngang hành lang (tối đa 3 công trình, tổng 6), luật cấm chặn kín (GRID-07), dọn đổ nát ở PREP, 1 nhân vật (Kiếm) với 5 vũ khí biến thể rơi từ boss (WPN), Frontline và Commander rút gọn, camera theo ngữ cảnh (Frontline bám nhân vật và zoom, Commander và PREP dịch bằng phím, CAM), 4 tower (Arrow, Cannon, Barricade và Trạm hồi lực) cấp 1-36 với 3 bậc model và 2 priority (First, Nearest), hai trụ có sẵn đầu run, 10 loại quân (Grunt, Archer, Brute bản sửa và 7 loại mới, mục 3.7.8), kịch bản wave 1-30 trong bảng cân bằng, công thức scale từ wave 31, thắng ở victory_wave rồi endless, 1 boss (Bulwark, lặp có scale) với pha giáp và đồng hồ Cuồng nộ, tổng kết wave, thưởng clear time, tua x2/x3, nút bắt đầu wave (PREP không đếm ngược), Hazard Trial và Mithril (HZT, MTH), vòng lặp Frontline (Aura, gold chỉ huy, XP, giới hạn bậc tower), Skill Tree MVP (3 chủ động, 4 bị động gồm Trạm hồi lực, 2 thẻ stat, level 3, 3+3 ô, không Reroll), Emergency repair (3 lượt), chỉ báo ngoài màn hình rút gọn (HUD-10), meta shop 4 mục (FORT_HP, GOLD_PCT, CMD_HP, EMG_REPAIR), save/load (ghi atomic, checksum, .bak, khôi phục run gián đoạn), thang xử lý kẹt MVP, tutorial một lần theo tài khoản (TUT-01, TUT-03, TUT-14, TUT-15), Settings (Âm thanh, Đồ họa, Tiếp cận cơ bản, Tài khoản), tài khoản, chơi khách, đồng bộ profile và bảng xếp hạng ở mức rút gọn (ACCT, LBD), bảng cân bằng Excel và công cụ dịch (BAL), tiếng Việt |
| **Should** | Boss Barrage, Elite có giáp tiền tuyến (FRT-05), chiến lợi phẩm Brute (FRT-06), merge skill, skill level 4-5, Sword Throw, War Horn, Arrow Rain, mở ô skill và mở skill bằng danh vọng, kéo thả ô skill, Reroll mua thêm, priority Highest HP/Lowest HP và "Áp dụng cho mọi tower cùng loại", preview boss PNL-05, chỉ báo quân lẻ (phần còn lại của HUD-10), UI scale, LOD animation, con trỏ động, modifier wave, nhiều điểm spawn, StartSelect cùng chọn wave khởi đầu, buff một wave (BUFF\_CHARGE), bẫy, Bat, Healer, Debuffer, mục shop UNLOCK_TRAP, công tắc tự bắt đầu wave (WAVE-12), hoàn tác bán 3 s, tiếng Anh và pseudo-localization, 3 preset mù màu và chế độ tương phản cao, nhạc phân lớp, tăng tempo nhạc boss, panning theo vị trí, lọc thông thấp khi Pause, rebind phím, migration save, hop cục bộ, watchdog cấp wave, NAV-10, overlay debug và bot soak test 200 wave, online mở rộng (hàng đợi nền, hộp thoại chọn bản khi xung đột, lọc tên hiển thị, xóa tài khoản), Reroll, ducking AUD-05, tab Điều khiển và Dữ liệu của Settings, TUT-04/05, thẻ Bền thành, bị động Focus và Lightstep (cắt khỏi MVP ở v1.9), +1 giới hạn Trạm hồi lực theo Cấp Chỉ huy (HLT-12), edge-pan và look-ahead camera (CAM-03, CAM-06), gợi ý tutorial Trạm hồi lực (TUT-13) |
| **Could** | Xóa skill, skill tree nhiều nhánh, base upgrade nhiều nhánh, tower thứ 5-6, spell scroll, Shaman, boss thứ 3, relic tăng giờ boss, gamepad, reset shop hoàn 80%, zoom camera bằng cuộn chuột, kéo camera bằng chuột, Last Stand |
| **Won't** | Xem mục 1.2 |

## 2.8 Nguyên tắc thiết kế

| **Nguyên tắc** | **Hệ quả** |
| --- | --- |
| Chuyển chế độ không phải nút thoát hiểm tức thì | Recall có channel, hủy khi bị đánh (MODE-01) |
| Mọi quyết định đầu tư diễn ra ở PREP | Xây, nâng, bán bằng gold, sửa Fortress bằng Mithril, đổi vũ khí chỉ ở PREP |
| Gold luôn khan hiếm | Buộc chọn tower, slot và cấp. Run bắt đầu với 0 gold, chỉ có hai trụ có sẵn |
| Sửa thành phải đổi bằng rủi ro | Mithril chỉ kiếm từ Hazard Trial: người chơi đánh 5 quái của wave sắp tới để có tài nguyên sửa thành (HZT, MTH) |
| PREP không ép thời gian | Không đếm ngược, người chơi tự bấm bắt đầu wave; tốc độ chơi đến từ tua x2/x3 (WAVE-11) |
| Boss là bài kiểm tra cách xây dựng | Mỗi boss miễn nhiễm loại sát thương của một loại tower ở pha 1 |
| Luôn có đường thắng, không bế tắc | Kiếm luôn gây sát thương lên boss (60% ở pha giáp), boss luôn có thể bị hạ, wave luôn kết thúc khi hết quân (ENR-06) |
| Thua boss không đồng nghĩa thua run | Hạ boss chậm bị phạt bằng Cuồng nộ, boss mạnh lên chứ không xóa tower hay Fortress tức thì (ENR-01..06) |
| Sức mạnh trong run đến từ chiến đấu trực tiếp | Cấp tower, skill, gold bonus đều gắn với việc chỉ huy gây sát thương (FRT-01..03, XP-01..05). Tower tự giết vẫn cho phần thưởng nhưng chậm hơn |
| Máu chỉ huy phải đổi bằng rủi ro | Commander mode không hồi máu. Giữa wave chỉ có hồi đầu PREP (35%). Trong wave chỉ có Lifesteal và Trạm hồi lực, mà trạm đòi chỉ huy ra Frontline, đứng yên và không bị đánh (HLT-03 đến HLT-06) |
| Kết quả xác định, dễ test | RNG theo luồng riêng mỗi wave, tie-break theo entity_id |

# 3. YÊU CẦU CHỨC NĂNG

## 3.1 Luồng ứng dụng

Boot -> MainMenu\
MainMenu -> RunLoading -> Run -> RunEnd\
Run -> (màn thắng ở victory_wave, SCR-20) -> Run (endless)\
\[Should] MainMenu -> StartSelect -> RunLoading\
MainMenu <-> MetaShop\
MainMenu <-> Settings\
MainMenu <-> Login | Leaderboard (mục 3.13, 3.14; ẩn khi online_enabled = false)\
RunEnd -> RunLoading | MetaShop | MainMenu\
Run -> (Pause) -> Run | RunEnd (Abandon)

| **State** | **Vào khi** | **Hành động cho phép** | **Ra khi** |
| --- | --- | --- | --- |
| Boot | Mở game | Đọc save, tải config, khôi phục run gián đoạn (mục 3.12.4), khôi phục phiên đăng nhập (ACCT-03) | Vào MainMenu |
| MainMenu | Từ Boot, RunEnd, MetaShop | Play, Meta Shop, Settings, Quit, Đăng nhập, Bảng xếp hạng | Chọn nút. MVP: Play vào thẳng RunLoading |
| StartSelect \[Should] | Bấm Play (khi đã làm StartSelect) | Chọn wave khởi đầu \[Should], nạp buff, xác nhận | Xác nhận hoặc Back |
| RunLoading | Bấm Play (MVP), xác nhận StartSelect \[Should], hoặc Chơi lại ở RunEnd | Không (màn hình chờ) | Khởi tạo xong |
| Run | Sau RunLoading | Theo state của wave (mục 3.3) | Điều kiện kết thúc (mục 3.2.4) |
| RunEnd | Run kết thúc | Xem tổng kết (thua ở SCR-11 hoặc sống sót ở SCR-21, END-10), chọn bước kế | Chọn nút |
| MetaShop | Từ MainMenu hoặc RunEnd | Mua, xem chi tiết | Back |

| **ID** | **Tình huống** | **Xử lý** |
| --- | --- | --- |
| FLOW-01 | Lần chạy đầu, chưa có save | Tạo save mặc định với flags.tutorial_done = false, chỉ mở wave 1. Run đầu chạy tutorial (có nút Skip) cho tới khi tutorial_done = true (mục 4.7). Đăng nhập tài khoản đã có tutorial_done = true thì đồng bộ về và không chạy lại (ACCT-04) |
| FLOW-02 | Save hỏng hoặc sai version | Theo quy trình SAV-01, SAV-02: thử .tmp, .bak, rồi cho "Tạo save mới" và giữ tệp hỏng đổi tên .corrupt |
| FLOW-03 | Tắt game đột ngột giữa Run | Không lưu trạng thái Run. run_flag (run_in_progress, start_wave, start_mult, waves_cleared, prestige_pending) được ghi khi bắt đầu Run và ở mỗi SUMMARY. Lần mở sau chốt run như ABANDONED (mục 3.12.4) |
| FLOW-04 | Bấm Quit khi đang ở Run | Hộp thoại xác nhận. Đồng ý thì chốt ABANDONED rồi thoát |
| FLOW-05 | Cửa sổ mất focus | Tự pause (mặc định bật; MVP luôn bật, tùy chọn tắt ở tab Gameplay là \[Should]) |
| FLOW-06 | MVP: không có StartSelect | Play vào thẳng RunLoading với start_wave = 1, starting_gold = 0, start_mult = 1.0, kèm hai trụ có sẵn hoặc tutorial (mục 3.2.1). \[Should] Khi đã làm StartSelect: bỏ qua màn này nếu chưa mở mốc nào ngoài wave 1 và kho buff rỗng |
| FLOW-07 | Save ghi dở khi tắt máy | Ghi atomic qua tệp tạm (mục 3.12.2) |

## 3.2 Vòng đời Run

### 3.2.1 Khởi tạo (RunLoading)

Thứ tự bắt buộc:

| **Bước** | **Nội dung** |
| --- | --- |
| 1 | Tạo RunConfig. MVP: start_wave = 1, starting_gold = 0, start_mult = 1.0. \[Should] Lấy từ StartSelect: start_wave, starting_gold, StartPack, start_mult, buff đã nạp |
| 2 | Sinh run_seed. Mỗi wave dùng luồng RNG riêng seed = hash(run_seed, wave_index) |
| 3 | Nạp map, đặt Fortress với fortress_max_hp = 1000 × (1 + 0.05 × cấp FORT_HP), HP đầy (FORT-04). Đặt chỉ huy ở chế độ Frontline tại deploy_point |
| 4 | **Trụ có sẵn \[MVP].** Khi start_wave = 1 và profile.flags.tutorial_done = true: đặt một Arrow cấp 1 ở slot starter_arrow_slot và một Cannon cấp 1 ở slot starter_cannon_slot (GameConfig, mục 6.3), HP đầy, priority mặc định, invested_gold = 0, cờ is_starter = true (SELL-06). Khi tutorial_done = false: không đặt, tutorial hướng dẫn người chơi xây hai trụ này miễn phí ở đúng hai slot đó (TUT-01, TUT-14). \[Should] Khi start_wave > 1: đặt công trình của StartPack thay cho trụ có sẵn |
| 5 | Áp meta: commander_max_hp = 100 + 10 × cấp CMD_HP, lượng hồi Emergency repair emg_repair_heal_pct = 20% + 3% × cấp EMG_REPAIR, gold_pct_meta = 0.04 × cấp GOLD_PCT. Đặt Emergency repair về trạng thái khởi đầu: emg_repair_charges = 3 (tối đa emg_repair_charges_max = 3), emg_repair_cd = 0. **Khởi tạo Skill và XP \[MVP]:** xp = 0, commander_level = 0, pending_picks = 0, ô skill trống, stat_stacks rỗng, rerolls_left = rerolls_per_run, reward_rng seed = hash(run_seed, "reward", 0), heal_station_built = false (RWP-06). **Khởi tạo v2.0:** mithril = 0 (MTH-01), owned_weapons = \[kiếm gốc], equipped_weapon = kiếm gốc (WPN-02), hazard_used = false (HZT-01), victory_reached = false (END-07) |
| 6 | \[Should] Nạp các lượt buff đã chọn vào run_buffs_loaded |
| 7 | Ghi run_in_progress = true vào save |
| 8 | Vào PREP của wave start_wave |

### 3.2.2 RunState

| **Nhóm** | **Trường** |
| --- | --- |
| Tiến trình | wave_index, waves_cleared, run_elapsed (game time chỉ của COMBAT và BOSS_COMBAT, RUN-02), run_seed, victory_reached (bool, END-07) |
| Kinh tế | gold, mithril (MTH-01), prestige_pending, wave_gold_base, wave_prestige_buffer |
| Hazard Trial | hazard_used (bool, reset khi vào PREP của wave mới), hazard_session khi đang trong phòng: nhóm quái, max HP lớn nhất của nhóm, bản sao chỉ số chỉ huy, gold và XP tạm tính, số con đã giết (mục 3.15). Xóa khi rời phòng |
| Vũ khí | owned_weapons (danh sách weapon_id, luôn có kiếm gốc), equipped_weapon, chain_cd (giây game time còn lại của Chain Lightning, WPN-07) |
| Fortress | fortress_hp, fortress_max_hp (giá trị hiệu dụng, khởi tạo từ RunConfig, tăng được bởi thẻ Bền thành \[Should], SKL-15) |
| Emergency repair | emg_repair_charges (0-3), emg_repair_cd (giây game time còn lại), emg_repair_heal_pct |
| Chỉ huy | commander_hp (float), commander_max_hp (hiệu dụng, khởi tạo từ RunConfig, tăng được bởi thẻ Thể lực, SKL-15), mode, position, skill_cooldowns, heal_phase (IDLE, HOLD, HEALING), heal_hold (float, game time, HLT-03) |
| Skill và XP \[MVP] | xp (float), commander_level, pending_picks, active_slots[3], passive_slots[3] (mỗi ô {id, level}), stat_stacks (Dictionary), rerolls_left, reward_rng, heal_station_built (bool, RWP-06). Mất khi hết run (RUN-01) |
| Tower | Bảng slot_id (W1-W3 hoặc cell_id của ô grid) -> {state, tower_type, level, hp, target_priority, invested_gold, is_starter, ruined_type, ruined_level}. ruined_type và ruined_level chỉ có giá trị khi state = RUINED (SLOT-02, SLOT-08). is_starter chỉ đúng với trụ có sẵn còn nguyên (SELL-06) |
| Thống kê run | run_kills (không tính quân bị cull, RWD-03, và quân trong Hazard Trial, HZT-04), run_commander_kills (số quân chết có hit_by_commander), run_gold_earned (gold nhận từ quân, boss, clear time, Hazard Trial; không tính tiền bán tower), run_bosses_defeated, damage_by_tower_type (sát thương tower gây ra, theo loại). Dùng cho RunEnd (mục 3.2.4). Chỉ run_kills và run_bosses_defeated cộng vào profile.stats ở RunEnd (mục 3.12.1); run_gold_earned, run_commander_kills và damage_by_tower_type chỉ dùng trong lượt chơi, không ghi xuống đĩa |
| Wave | wave_modifiers, spawn_queue, enemies_alive, wave_clear_timer |
| Boss | boss_timer, phase, boss_enraged |
| Buff \[Should] | run_buffs_loaded, active_buff |
| Điều khiển | time_scale, is_paused (dẫn xuất từ pause_requests, TIME-11) |

**RUN-01.** Không trường nào của RunState (kể cả xp, Cấp Chỉ huy, skill đã nhặt, Mithril, vũ khí) được ghi xuống đĩa giữa Run, trừ run_flag (FLOW-03) và \[Should] kho buff khi kích hoạt (BUF-04). Số lượt Emergency repair không được lưu: mỗi run mới (kể cả sau khi khôi phục run gián đoạn) luôn bắt đầu ở 3/3.

**RUN-02.** run_elapsed (giây, float) là tổng game time (TIME-10 loại a: đã nhân time_scale, dừng khi Pause) trôi qua trong hai state COMBAT và BOSS_COMBAT, tính từ frame vào state tới frame wave kết thúc (mục 3.3.3, SPN-11). Không tính: RunLoading, PREP (không giới hạn), HAZARD_TRIAL, BOSS_INTRO, SUMMARY, REWARD_PICK, màn thắng SCR-20, RunEnd, và mọi lúc Pause (game time đứng yên). Tua x2, x3 không làm run_elapsed nhỏ đi vì game time đã nhân time_scale: một wave chơi ở x3 có cùng run_elapsed như ở x1 nếu diễn biến như nhau. Wave đang dở lúc run kết thúc vẫn cộng phần đã chơi. Dùng cho SCR-20, RunEnd và bảng xếp hạng (LBD-04, LBD-06).

### 3.2.3 Tham số Run

PREP không có thời lượng (WAVE-11). max_alive 70. victory_wave 30 (END-07). Tên tham số và nơi lưu ở mục 6.3.

### 3.2.4 Kết thúc Run

| **Loại** | **Điều kiện** |
| --- | --- |
| FORTRESS_DESTROYED | fortress_hp <= 0 |
| COMMANDER_DIED | commander_hp <= 0 ở Frontline (Commander mode không thể chết, CMD-10) |
| ABANDONED | Abandon ở Pause, FLOW-03, FLOW-04 |

Hai điều kiện thua cùng frame thì ghi FORTRESS_DESTROYED. Chết trong Hazard Trial không phải COMMANDER_DIED (DEAD-11).

**Thắng và endless (v2.0).** Ngoài end_type, mỗi run có run_result:

| **run_result** | **Điều kiện** | **Tổng kết** |
| --- | --- | --- |
| DEFEAT (thua) | Run kết thúc (mọi end_type) khi victory_reached = false, tức chết hoặc bỏ ở wave 1 đến victory_wave | RunEnd thua (SCR-11) |
| VICTORY (thắng) | Hoàn thành wave victory_wave (mặc định 30). Run không kết thúc: hiện màn thắng rồi chơi tiếp endless | Màn thắng giữa run (SCR-20) |
| SURVIVED (sống sót) | Run kết thúc khi victory_reached = true, tức chết hoặc bỏ từ wave victory_wave + 1 | RunEnd endless (SCR-21), ghi số wave |

Thắng không cho thêm uy tín hay danh vọng. Bảng xếp hạng vẫn xếp theo waves_cleared nên người sống lâu trong endless xếp trên (LBD-04).

**Trình tự kết thúc:**

1. Chặn input, slow motion 0.2x trong 1.5 s (thời gian thực, chỉ hoạt cảnh, FBK-10).
2. Dừng spawner, hủy toàn bộ quân và projectile.
3. Tính danh vọng:

prestige_gain = floor( (prestige_pending + 0.5 × wave_prestige_buffer) × conversion_rate × start_mult )

conversion_rate = 30% cho cả ba loại kết thúc. wave_prestige_buffer là uy tín từ quân đã diệt trong wave đang dở.

Phạm vi của start_mult: chỉ nhân vào prestige_gain (bù cho việc bỏ qua các wave đầu). start_mult không ảnh hưởng độ khó wave (scale theo wave_index thật, mục 3.7.6), gold thưởng, đồng hồ boss hay bất kỳ công thức nào khác.

4. Cập nhật save: cộng danh vọng, cộng thống kê run (run_kills, run_bosses_defeated), tăng total_runs thêm 1 vào profile.stats, cập nhật max_wave_cleared và best_by_start, đặt run_in_progress = false, kiểm tra mốc mới mở.
5. Vào RunEnd (SCR-11 nếu run_result = DEFEAT, SCR-21 nếu SURVIVED), chờ người chơi bấm nút, không tự chuyển màn.

**RunEnd hiển thị:** loại kết thúc, run_result (thua hoặc "Sống sót đến wave N"), waves_cleared, so với kỷ lục ("Kỷ lục mới"), tổng quân diệt, gold kiếm được, uy tín thu về, conversion_rate, start_mult, prestige_gain, số dư mới, mốc mới mở, bosses_defeated, Cấp Chỉ huy đạt được, số quân chỉ huy tự hạ (run_commander_kills), loại tower gây nhiều sát thương nhất (damage_by_tower_type, không tính Barricade, ẩn dòng nếu chưa có tower nào gây sát thương). Nút: **Chơi lại** (vào RunLoading, \[Should] vào StartSelect khi đã có), **Meta Shop**, **Menu chính**.

| **ID** | **Tình huống** | **Xử lý** |
| --- | --- | --- |
| END-01 | Chỉ huy chết đúng frame Fortress sập | Ghi FORTRESS_DESTROYED, xử lý một lần, không cộng danh vọng hai lần. RunState không kết thúc run ngay khi nhận `commander_died` hay tín hiệu Fortress sập: chỉ đánh dấu điều kiện thua, rồi xử lý cuối frame (`call_deferred`). Nếu có cả hai thì ghi FORTRESS_DESTROYED. Sau khi đã chốt, mọi điều kiện thua đến sau bị bỏ qua |
| END-02 | start_wave > 1 | waves_cleared theo số thứ tự tuyệt đối. Kỷ lục lưu riêng theo mốc (best_by_start) |
| END-03 | Chết ở wave 1 với prestige_pending = 0 | prestige_gain = 0, vẫn hiện RunEnd |
| END-04 | Bấm Chơi lại liên tục | Chỉ nhận một lần bấm, khóa nút cho đến khi chuyển màn |
| END-05 | Kết thúc run trong lúc ghi save | Hoàn tất ghi save trước rồi mới chuyển màn |
| END-06 | Đạt mốc mở khóa nhưng đồng thời thua | Mốc vẫn mở (dựa max_wave_cleared đã cập nhật ở bước 4) |
| END-07 | Hoàn thành wave victory_wave | Khi wave có wave_index = victory_wave vào SUMMARY và waves_cleared tăng (không thua cùng frame, WAVE-02): đặt victory_reached = true một lần mỗi run ngay khi vào SUMMARY. Rời SUMMARY theo đúng thứ tự của WAVE-13: SUMMARY (bấm Tiếp tục hoặc hết 10 s) → màn thắng SCR-20 (phát run_victory, EVB-44; game dừng, TIME-11, lý do VICTORY) → bấm "Chơi tiếp" (EVB-46) → REWARD_PICK nếu pending_picks > 0 → PREP của wave victory_wave + 1. Bấm Tiếp tục hay hết 10 s đều đi qua màn thắng trước, không bao giờ vào thẳng REWARD_PICK hay PREP. victory_wave nằm trong GameConfig, mặc định 30 |
| END-08 | Fortress sập hoặc chỉ huy chết đúng frame hoàn thành wave victory_wave | Thua đè thắng (WAVE-02): không thắng, run_result = DEFEAT, waves_cleared = victory_wave − 1 |
| END-09 | \[Should] start_wave > 1 | Mốc thắng vẫn theo wave tuyệt đối victory_wave, không trừ các wave đã bỏ qua |
| END-10 | Run kết thúc khi victory_reached = true | run_result = SURVIVED với mọi end_type (kể cả ABANDONED khi bỏ ở Pause). RunEnd endless ghi "Sống sót đến wave N" (N = wave_index lúc kết thúc), waves_cleared và các chỉ số như RunEnd thường. Công thức danh vọng không đổi |

## 3.3 Wave

### 3.3.1 State machine

PREP -> COMBAT -> SUMMARY -> REWARD_PICK -> PREP (wave n+1)\
PREP -> BOSS_INTRO -> BOSS_COMBAT -> SUMMARY -> REWARD_PICK -> PREP\
PREP -> HAZARD_TRIAL -> PREP (cùng wave, tối đa một lần, mục 3.15)\
SUMMARY (wave victory_wave) -> màn thắng SCR-20 (FSM vẫn ở SUMMARY) -> REWARD_PICK -> PREP (END-07, WAVE-13)\
Mọi state -> RUN_END (khi thỏa mục 3.2.4)

REWARD_PICK là \[MVP]. Không có lượt chờ (pending_picks = 0) hoặc pool rỗng thì bỏ qua state này (RWP-06). HAZARD_TRIAL là state của wave FSM nhưng không phải một phần của wave: quay về PREP không chạy lại các việc đầu PREP (hồi 35% chỉ huy, hồi đầy tower, TWR-01).

### 3.3.2 PREP

| **Hạng mục** | **Đặc tả** |
| --- | --- |
| Thời lượng | Không giới hạn, không đếm ngược (WAVE-11). Wave boss cũng vậy |
| Cho phép | Xây, nâng cấp, bán, sửa Fortress bằng Mithril (MTH-03), đổi target priority, đổi vũ khí (WPN-03), vào Hazard Trial một lần (HZT-01), dịch camera bằng WASD ở cả hai chế độ (nhân vật đứng yên, CAM-02), đổi chế độ (không cooldown, không channel). \[Should] Kích hoạt buff |
| Không có quái | Chỉ huy và Fortress không nhận sát thương (trong Hazard Trial chỉ bản sao chỉ số của chỉ huy nhận sát thương, HZT-06). Tower hồi đầy HP ở đầu PREP (TWR-01, trừ Trạm hồi lực, HLT-08). Chỉ huy hồi prep_heal_pct (35%, cả hai chế độ, một lần khi vào PREP từ SUMMARY hoặc REWARD_PICK, không lặp lại khi ra khỏi Hazard Trial). Không dùng được Trạm hồi lực ở PREP (HLT-03) |
| **Kết thúc** | Bấm nút **Bắt đầu wave** (HUD-19, WAVE-11) |
| Preview | Loại quân sắp tới (tối đa 5 loại kể cả boss, SPN-14), modifier \[Should]. Wave boss: tên boss, miễn nhiễm pha 1, boss_timer, vũ khí sẽ rơi nếu còn (WPN-11); \[Should] PNL-05 đầy đủ và cảnh báo BOSS-15 |

### 3.3.3 COMBAT

- Khóa xây, nâng, bán, sửa bằng Mithril, đổi vũ khí. Emergency repair (Commander) vẫn dùng được.
- Chỉ huy đang Commander thì ở command_post. Đang Frontline thì giữ vị trí.
- Kết thúc khi spawn_queue rỗng và enemies_alive == 0.
- **Clear time** đo bằng game time từ lần spawn đầu đến lần diệt cuối, nên tua tốc độ không ảnh hưởng thưởng.
- par_time = spawn_duration + 15 s (wave thường). Wave boss dùng par_time_boss = 0.6 × boss_timer (BRW-04).

| **Mốc** | **Điều kiện** | **Hệ số gold (clear\_mult)** |
| --- | --- | --- |
| Fast | clear_time ≤ 0.7 × par_time | 1.25 |
| Normal | ≤ 1.3 × par_time | 1.00 |
| Slow | lớn hơn | 0.80 |

### 3.3.4 SUMMARY

- Hiển thị: quân đã diệt (theo loại), clear time và mốc, gold (gốc, hệ số, tổng), uy tín, HP Fortress, tower bị phá (kèm giá xây lại), lượt Emergency repair nhận được khi diệt boss (nếu có, BRW-07), vũ khí nhận được khi diệt boss (nếu có, WPN-11), XP nhận (từ chỉ huy / từ tower), Cấp Chỉ huy, số lượt chọn đang chờ. Gold, XP và Mithril từ Hazard Trial đã cộng lúc rời phòng nên không hiện lại ở đây.
- Áp gold và prestige_pending ngay khi vào state, không chờ bấm (GLD-08). Tăng waves_cleared. Ghi save trước rồi mới hiển thị (SAV-05).
- Tự chuyển sau 10 giây thời gian thực, hoặc bấm Continue: SummaryPanel phát summary_continue_requested (EVB-37) và wave FSM rời SUMMARY theo thứ tự cố định của WAVE-13: (1) nếu vừa thắng (END-07) thì hiện màn thắng SCR-20 và chờ "Chơi tiếp"; (2) nếu pending_picks > 0 thì sang REWARD_PICK; (3) sang PREP của wave kế.
- Chỉ huy không nhận sát thương ở SUMMARY.

### 3.3.5 Edge case của wave

| **ID** | **Tình huống** | **Xử lý** |
| --- | --- | --- |
| WAVE-01 | Spawn vượt max_alive (70) | Quân dư chờ trong spawn\_queue, spawn tiếp khi số quân sống giảm dưới max_alive |
| WAVE-02 | Fortress sập và diệt quân cuối cùng frame | Thua đè thắng: kết thúc run, wave đó không tính vào waves_cleared, không cộng gold (GLD-08) |
| WAVE-03 | Quân kẹt | Theo thang xử lý kẹt NAV-01 đến NAV-09: sửa nhẹ trước, không xóa quân ngay. \[Should] NAV-07, NAV-10, NAV-11 |
| WAVE-04 | Quân rơi ngoài map | Theo NAV-04 |
| WAVE-05 | Còn quân lẻ | 60 s sau lần spawn cuối: marker định vị (EN-01). 240 s: FRENZY (EN-02). 300 s: giới hạn cứng, cull mọi quân còn lại không phải boss (NAV-13) |
| WAVE-06 | Tua x3 rồi Fortress tụt nhanh | Không tự giảm tốc (giữ quyền kiểm soát), HUD cảnh báo dưới 30% HP |
| WAVE-08 | Wave có 0 quân (lỗi bảng) | Ép tối thiểu 1 Grunt, ghi cảnh báo |
| WAVE-09 | Boss wave có Cuồng nộ | Cuồng nộ không kết thúc wave (ENR-06): wave vẫn kết thúc khi spawn_queue rỗng và enemies_alive == 0. Diệt boss sau Cuồng nộ vẫn tính hoàn thành, thưởng boss nhân enrage_reward_mult (BRW-02) |
| WAVE-10 | Pause lúc wave chuyển state | Chuyển state theo game time, không mất sự kiện |
| WAVE-11 | Kết thúc PREP | PREP không có đồng hồ. Chỉ kết thúc khi người chơi bấm nút Bắt đầu wave (HUD-19), nút phát wave_start_requested (EVB-38), wave FSM chuyển sang COMBAT hoặc BOSS_INTRO. Không có phím tắt (phím G và thưởng gọi wave sớm đã bỏ). Nút xám kèm lý do khi: đang Pause, đang có hộp thoại giao dịch, tutorial chưa xây xong hai trụ (TUT-15). Bấm đúng frame đang xử lý giao dịch thì giao dịch hoàn tất trước hoặc bị từ chối (BLD-02) |
| WAVE-12 \[Should] | Công tắc tự bắt đầu wave | Tùy chọn QoL ở tab Gameplay: khi bật, PREP tự kết thúc sau một khoảng chờ (auto_start_delay, chưa chốt) nếu người chơi không thao tác. Mặc định tắt. MVP không có |
| WAVE-13 \[MVP] | Rời SUMMARY | Một thứ tự duy nhất, wave FSM chạy khi nhận summary_continue_requested (EVB-37), một lần mỗi SUMMARY (bấm Tiếp tục đúng lúc hết 10 s chỉ tính một lần, tín hiệu đến sau bị bỏ). (1) SummaryPanel đóng. (2) Nếu SUMMARY này vừa bật victory_reached (END-07): mở màn thắng SCR-20, phát run_victory (EVB-44), thêm lý do Pause VICTORY (TIME-11); wave FSM vẫn ở SUMMARY, không đếm ngược, chờ victory_continue_requested (EVB-46) rồi bỏ lý do VICTORY. (3) Nếu pending_picks > 0 và pool không rỗng (RWP-06): sang REWARD_PICK, chọn hết lượt chờ. (4) Sang PREP của wave kế. Bấm Tiếp tục hay hết 10 s đều đi đủ các bước theo đúng thứ tự này; bước (2) chỉ có ở wave victory_wave, một lần mỗi run |

### 3.3.6 REWARD_PICK (3 chọn 1) \[MVP]

State nằm giữa SUMMARY và PREP. Người chơi dùng hết các lượt chọn đang chờ (pending_picks, sinh ra từ lên Cấp Chỉ huy, XP-04), mỗi lượt chọn 1 trong tối đa 3 thẻ. Màn hình là SCR-17.

| **ID** | **Đặc tả** | **Tag** |
| --- | --- | --- |
| RWP-01 | Vào REWARD_PICK khi pending_picks > 0. Game dừng. Lượt chọn sinh ra từ XP của Hazard Trial (XP-06) chờ tới REWARD_PICK của wave đó. Người chơi chọn lần lượt hết các lượt chờ, rồi vào PREP. Khi có nhiều lượt chờ, màn REWARD_PICK gọi RewardOfferGenerator tuần tự: lượt kế chỉ được sinh sau khi lượt trước đã phát reward_picked và RunSkillState đã cập nhật, không sinh trước. | MVP |
| RWP-02 | Mỗi lượt hiển thị tối đa 3 thẻ, không trùng nhau. Loại thẻ: skill chủ động, skill bị động, stat. \[Should] thẻ merge | MVP |
| RWP-03 | **Reroll**: đổi cả 3 thẻ, không tốn lượt chọn, `rerolls_left` khởi đầu 1 mỗi run (SKL-08). Hết thì nút xám. Cắt khỏi MVP ở v1.9: MVP không có nút Reroll và rerolls_left = 0 | SHOULD |
| RWP-04 | **Bỏ qua (Skip)**: mất luôn lượt chọn đó, có xác nhận một lần ("Bỏ qua sẽ mất lượt chọn này"), không bù gold | MVP |
| RWP-05 | RNG riêng seed = hash(run_seed, "reward", số lượt đã dùng) để test và replay tái hiện được | MVP |
| RWP-06 | Pool rỗng (mọi ô đầy, mọi skill và stat max) thì bỏ qua REWARD_PICK, XP vẫn tăng, Cấp Chỉ huy vẫn tăng (vì gating FRT-03). Pool chỉ có 1-2 thẻ thì hiện đúng 1-2 thẻ. Không có thẻ gold, thẻ hồi HP. **Lọc thẻ Trạm hồi lực (SKL-26):** chỉ vào pool khi heal_station_built = true (đã xây ít nhất một Trạm hồi lực trong run, cờ không tắt khi trạm bị phá hay bị bán). Chưa xây thì thẻ không hiện và pool tính như thiếu một thẻ bị động | MVP |
| RWP-07 | Trọng số khởi điểm (chỉnh qua GameConfig, mục 6.3): skill đã có chưa max 40, skill mới (khi loại đó còn ô trống) 30, stat chưa đủ stat_max_stacks 20. Skill đã max không bao giờ hiện lại | MVP |
| RWP-08 | Pause trong REWARD_PICK: cho phép (game đã dừng). Esc không đóng màn (chỉ mở Pause) | MVP |
| RWP-09 | \[Should] Thẻ merge (SKL-20..22), skill hiếm ở lượt boss (BRW-03), Reroll mua thêm (REROLL_PLUS) | SHOULD |

Cài đặt: RewardOfferGenerator là hàm thuần nhận RunSkillState, danh sách SkillData và RNG, trả 3 thẻ; test bằng GUT, không đụng scene. Chọn thẻ phát `reward_picked` (EVB-29), StatBlock tính lại ngay (SKL-15).

## 3.4 Điều khiển thời gian

| **ID** | **Đặc tả** |
| --- | --- |
| TIME-01 | time_scale có ba mức x1, x2, x3, chọn bằng nút trên HUD (TIME-09, HUD-14), không có phím tắt. Pause là trạng thái riêng, không phải time_scale = 0 |
| TIME-02 | Pause được ở mọi state của Run (PREP, HAZARD_TRIAL, COMBAT, BOSS_INTRO, BOSS_COMBAT, SUMMARY, REWARD_PICK). Khi pause mọi timer gameplay dừng, UI vẫn chạy. Bộ đếm tự chuyển 10 s của SUMMARY (thời gian thực) cũng dừng khi Pause |
| TIME-03 | Mức tốc độ chọn được giữ từ PREP sang COMBAT của cùng wave. Tự về x1 (các nút tua về trạng thái tắt) khi vào BOSS_INTRO và khi vào SUMMARY. Từ SUMMARY, REWARD_PICK sang PREP kế tiếp mức luôn x1 và các nút tua tắt, không khôi phục mức người chơi đã chọn ở wave trước (HUD-14). Không còn khóa x1 theo đồng hồ boss: BOSS_COMBAT cho tua x2/x3 bình thường |
| TIME-04 | Tween, Timer, particle, animation gameplay chạy theo time_scale. Animation UI bỏ qua time scale |
| TIME-05 | Âm thanh không đổi tốc độ và pitch khi tua. Giảm tải bằng giới hạn tần suất SFX (AUD-01, AUD-03) |
| TIME-06 | Giới hạn max_physics_steps_per_frame (Project Setting của Godot, mặc định 8, mục 6.3). FPS dưới 30 liên tục 3 s ở x3 thì tự hạ về x2 kèm thông báo (ALR-10). Hạ time scale trước khi đụng tới logic AI hay tần suất quét |
| TIME-07 | Cooldown kỹ năng, cooldown đổi chế độ, đồng hồ boss, clear time đều tính bằng game time |
| TIME-08 | Không dùng Pause để né cooldown hay tối ưu quyết định. Ở COMBAT, BOSS_COMBAT và HAZARD_TRIAL, khi Pause mọi panel chỉ đọc: không đổi priority, không Emergency repair, không đổi chế độ, không dùng skill. PREP không bị giới hạn |
| TIME-09 | **Nút tua nhanh:** tua chỉ điều khiển bằng cụm nút HUD (HUD-14), gọi set_time_scale(1\|2\|3). Bấm nút mức đang tắt thì bật mức đó, bấm lại đúng nút đang bật thì tắt (về x1). Hiển thị luôn theo time_scale thực, kể cả khi bị hạ tự động (TIME-06). Không đổi mức tốc độ khi đang Pause |
| TIME-10 \[MVP] | **Ba loại đồng hồ** do TimeManager cung cấp: (a) game time, đã nhân time_scale và dừng khi Pause, cho mọi timer gameplay (TIME-07, CHAR-05), gồm heal_hold_time và nhịp hút máu của Trạm hồi lực (HLT-03, HLT-06); (b) **thời gian thực có thể pause** (không nhân time_scale, dừng khi Pause), cho bộ đếm 10 s của SUMMARY (TIME-02), đếm BOSS_INTRO, hoàn tác bán 3 s \[Should] (PNL-10); (c) **thời gian thực thuần**, không dừng khi Pause, cho animation UI, chuyển camera 0.5 s và dịch camera bằng phím, kể cả khi Pause (MSE-08, CAM-03), retarget_delay 0.3 s (CMD-01), crossfade nhạc. Mọi timer mới phải khai báo thuộc loại nào |
| TIME-11 \[MVP] | **Pause theo tập lý do:** TimeManager giữ tập `pause_requests` với các lý do `USER` (Esc, nút Pause, mất focus cửa sổ vì INP-08 mở menu Pause), `REWARD_PICK` (RWP-01) và `VICTORY` (màn thắng SCR-20, END-07). `is_paused = pause_requests không rỗng`. Thêm hoặc bỏ một lý do không ảnh hưởng lý do khác (Esc trong REWARD_PICK thêm `USER`, bỏ `USER` thì game vẫn dừng vì còn `REWARD_PICK`). `pause_changed` (EVB-19) chỉ phát khi `is_paused` thực sự đổi. Lấy lại focus không tự bỏ `USER` (INP-08). Đổi time_scale khi đang Pause bị từ chối (TIME-09) |
Kiểm tra mọi hệ thống (projectile, DoT, đồng hồ boss) đúng ở x1/x2/x3 là hạng mục nghiệm thu bắt buộc của tuần 6.

## 3.5 Nhân vật chỉ huy

Chỉ huy là một thực thể duy nhất với hai chế độ. Camera, HP và hệ thống damage dùng chung, chỉ khác input map, UI và luật nhận sát thương.

### 3.5.1 Chỉ số (CharacterStats)

| **Tham số** | **Giá trị** | **Ghi chú** |
| --- | --- | --- |
| commander_max_hp | 100 | Cộng meta CMD_HP (+10 mỗi cấp) |
| move_speed | 6 m/s |  |
| armor_pct | 0% | 0% gốc. Nguồn cộng duy nhất ở MVP: passive Armored (SKL-14). Trần 75% (APL-03) |
| sword_damage | 20 | Đòn 1 và 2. Đòn 3 nhân 1.5. damage_type = SLASH |
| sword_range | 2.2 m | Hình quạt 120 độ |
| sword_max_targets* | 3 | Số mục tiêu tối đa trúng một đòn đánh thường (CMB-09) |
| skill_sword_wave_speed* | 20 m/s | Tốc độ bay của Sword Wave (SKL-11, bảng 3.5.12.1) |
| skill_firebomb_cast_range* | 10 m | Tầm ném tối đa của Firebomb (SKL-12, bảng 3.5.12.1) |
| attack_interval | 0.45 s | Tính cả recovery |
| dodge_distance | 4 m |  |
| dodge_iframe | 0.3 s |  |
| dodge_cooldown | 1.5 s |  |
| skill_cooldown | 12 s | Battle Cry |
| mode_switch_cooldown | 5 s | Cả hai chiều |
| prep_heal_pct | 35% | Hồi khi vào PREP, áp cho cả hai chế độ (hạ từ 60% ở v1.9) |
| commander_regen_pct_per_sec | \[ĐÃ XÓA v1.9] | Commander mode không còn regen (mục 3.5.7). Chỉ huy ở chế độ này bất khả xâm phạm nên HP không đổi |
| heal_hold_time* | 1.0 s | Game time. Thời gian giữ E để được phép hồi (HLT-03) |
| combo_window* | 0.35 s | 3.5.2, 3.5.3. Cửa sổ nối đòn, mở ngay khi hết attack_interval. `combo_reset_time` đã bỏ ở v1.8 (CHAR-07) |
| combo_hit3_knockback* | 1.5 m | 3.5.3 |
| input_buffer_time* | 0.15 s | CHAR-04 |
| skill_animation_time* | 0.5 s | 3.5.2 |
| battle_cry_radius* / battle_cry_duration* / battle_cry_damage_mult* | 6 m / 4 s / 0.7 | 3.5.3, 3.5.7 |
| recall_time_in_zone* / recall_time_outside* | 0.6 s / 3 s | 3.5.5 |
| deploy_invuln_time* | 0.6 s | 3.5.2 |
| deploy_point_search_radius* | 4 m | MODE-02 |
| deploy_clear_radius* | 0.8 m | MODE-02. Bán kính trống quanh điểm hạ |
| deploy_shockwave_radius* | 3 m | 3.5.5. Bán kính shockwave khi Deploy |
| deploy_shockwave_distance* | 2 m | 3.5.5. Quãng đẩy lùi, gây STAGGER (AI-04), Brute và boss miễn |
| fall_damage_pct* | 0.15 | DEAD-06, sát thương TRUE, HP tối thiểu 1 |
| commander_low_hp_warning_pct* | 25% | ALR-02, DEAD-07 |

*\[Should] hiệu ứng trạng thái (3.5.7): Slow −40% trong tối đa 3 s, Stun tối đa 1.5 s rồi miễn 3 s, Weaken −25% trong tối đa 5 s.*

Mọi chỉ số chỉ huy đọc qua StatBlock (add, mul). Skill bị động, thẻ stat và hiệu ứng vũ khí (Rampage, Swift, tầm đánh của vũ khí) ghi vào StatBlock, không sửa CharacterStats (SKL-15, WPN-09, WPN-10).

Từ v2.0, các giá trị trong bảng trên là khởi điểm; CharacterStats được sinh từ sheet nhân vật của bảng cân bằng (mục 6.10). sword_damage là sát thương cơ bản dùng để tính sát thương hiệu ứng vũ khí (WPN-04). sword_range nhân với range_mult của vũ khí đang trang bị.

### 3.5.2 State machine

Frontline:  Idle <-> Move -> Attack(combo 1-2-3) -> Idle\
Move/Idle -> Dodge -> Idle\
Move/Idle -> Skill -> Idle\
Any -> Stunned -> Idle\
Idle/Move -> Recalling -> Arriving -> Commanding\
Idle -> HealHold -> Healing -> Idle (heal_channel, HLT-03 đến HLT-05)\
Commander:  Commanding -> Deploying -> Idle (Frontline)\
Any -> Dead

| **State** | **Cho phép** | **Ngắt bởi** |
| --- | --- | --- |
| Idle, Move | Mọi hành động Frontline ở COMBAT, BOSS_COMBAT và HAZARD_TRIAL. Ở PREP nhân vật đứng yên, WASD dịch camera (CAM-02) |  |
| Attack | Đòn kế trong cửa sổ combo 0.35 s. Dodge hủy được recovery. | Stun |
| Dodge | Bất tử dodge_iframe, xuyên qua quân địch | Không ngắt được |
| Skill | Battle Cry: animation 0.5 s, khóa di chuyển. **Skill chủ động (SKL-xx): theo từng skill, mặc định hủy được recovery đòn kiếm như Dodge, không khóa di chuyển** | Stun (mất cooldown) |
| Stunned | Không hành động | Hết thời gian |
| Recalling | Đứng yên, channel về thành | Nhận sát thương, di chuyển, Dodge |
| HealHold | Đứng yên, giữ E đủ heal_hold_time cạnh một Trạm hồi lực còn kho (HLT-03) | Mọi hành động và mọi sát thương (HLT-04), nhả E |
| Healing | Đứng yên, hồi máu từ Trạm hồi lực (HLT-05, HLT-06) | Mọi hành động và mọi sát thương (HLT-04), đầy máu, hết kho |
| Deploying | Bất tử 0.6 s, không tấn công | Không ngắt được |
| Commanding | Các lệnh Commander. Bất khả xâm phạm (CMD-10) | Chuyển chế độ |

### 3.5.3 Frontline

- **Di chuyển:** WASD theo trục màn hình, chuẩn hóa vector chéo. Chỉ ở COMBAT, BOSS_COMBAT và HAZARD_TRIAL. Ở PREP WASD dịch camera (CAM-02).
- **Aim:** chuột, raycast xuống mặt phẳng ngang tại độ cao chân chỉ huy (MSE-01). Ray không trúng thì giữ hướng cũ.
- **Đánh thường:** combo 3 đòn, đòn 3 có knockback nhẹ 1.5 m (Brute và boss miễn). Nối đòn theo CHAR-07: không bấm trong combo_window thì combo về đòn 1. Mỗi đòn trúng tối đa sword_max_targets mục tiêu (CMB-09). Tầm và hiệu ứng theo vũ khí đang trang bị (mục 3.5.13).
- **Dodge:** theo hướng di chuyển. Đứng yên thì lùi về sau hướng aim.
- **Battle Cry (Q):** taunt mọi quân trong bán kính 6 m trong 4 s, chỉ huy nhận -30% sát thương trong thời gian đó. Cooldown 12 s. Dùng để tank và kéo aggro.
- **Hồi máu tại Trạm hồi lực (E):** giữ E đủ heal_hold_time khi đứng yên cạnh một Trạm hồi lực, rồi hồi liên tục đến khi có hành động khác hoặc đầy máu (mục 3.6.6).

| **ID** | **Luật chiến đấu** |
| --- | --- |
| CMB-01 | Mỗi đòn gây sát thương một lần cho mỗi mục tiêu, và tối đa sword_max_targets mục tiêu (CMB-09) |
| CMB-02 | Hitbox chỉ hoạt động ở khung active của animation |
| CMB-03 | Đòn đang wind-up không hủy được bằng di chuyển, chỉ bằng Dodge |
| CMB-04 | Chỉ huy bị knockback bởi Brute và boss. Dodge và Deploying miễn knockback |
| CMB-05 | Không friendly fire từ tower của mình. Sát thương AoE của quân địch và boss thì có |
| CMB-06 | Dodge xuyên thân quân địch, không xuyên Barricade, tower, tường |
| CMB-07 | Va chạm mềm với quân địch. Bị vây kín thì Dodge là đường thoát |
| CMB-08 | Cooldown chạy theo game time, tiếp tục đếm trong PREP và SUMMARY. Cooldown dừng trong REWARD_PICK (game dừng). Lên cấp skill ở REWARD_PICK thì cooldown còn lại giữ nguyên và kẹp xuống tối đa cooldown mới (remaining <= total). |
| CMB-09 | Giới hạn cleave: đòn đánh thường quét hình quạt 120 độ, tầm sword_range 2.2 m, chỉ trúng tối đa sword_max_targets (3) mục tiêu. Chọn theo thứ tự: khoảng cách tới chỉ huy gần hơn, rồi góc lệch so với hướng aim nhỏ hơn, rồi entity_id nhỏ hơn (kết quả xác định, không phụ thuộc thứ tự va chạm của engine). Danh sách mục tiêu chốt một lần ở khung active (CMB-02). Knockback của đòn 3 chỉ áp lên các mục tiêu đã trúng. Battle Cry không gây sát thương nên không chịu giới hạn này |
| CMB-10 \[MVP] | Sát thương từ skill chủ động của chỉ huy (gồm vùng cháy gây sát thương theo tick) đều tính là sát thương chỉ huy cho cờ hit_by_commander (XP-03). Mỗi skill khai báo damage_type và source = commander. Skill không chịu giới hạn sword_max_targets |

### 3.5.4 Commander mode

- Đứng cố định tại command_post (Marker3D trên tường). Không di chuyển, không tấn công, không dùng skill chủ động (SKL-06).
- Camera vẫn là một Camera3D, chuyển sang khung overview và dịch được bằng WASD trong giới hạn camera_bounds (CAM-01, CAM-03).
- **Bất khả xâm phạm:** damage_taken = 0. Ở Commander mode chỉ huy không nhận sát thương và không thể bị nhắm bởi bất kỳ nguồn nào, kể cả AoE và đạn đang bay (CMD-10).
- Không có regen và không dùng được Trạm hồi lực: HP chỉ huy ở chế độ này không đổi vì bất khả xâm phạm (CMD-10, mục 3.5.7).
- command_post cách slot gần nhất (kể cả ô grid) tối thiểu 3 m (BOSS-08, GRID-03).

| **ID** | **Lệnh và luật** |
| --- | --- |
| CMD-01 | Chỉnh target priority. \[MVP] 2 lựa chọn: First, Nearest. \[Should] Highest HP, Lowest HP, Flying, Boss và nút "Áp dụng cho mọi tower cùng loại". retarget_delay 0.3 s. Chỉ đổi được ở Commander mode và theo thời gian thực, không đổi được khi Pause (CMD-04) |
| CMD-02 | **Emergency repair (R):** hồi emg_repair_heal_pct (20% + 3% × cấp EMG_REPAIR, tối đa 29%) của fortress_max_hp, miễn phí gold, chỉ ở Commander mode. Giới hạn 3 lượt trong cả run (emg_repair_charges, khởi đầu 3/3). Mỗi lần dùng tốn 1 lượt và bắt đầu cooldown emergency_repair_cooldown = 60 s game time giữa hai lần dùng. Cooldown chạy xuyên wave, không giảm được bằng meta hay relic. Hết lượt (0/3) thì không dùng được dù cooldown đã về 0. Lượt được cộng lại theo BRW-07 (+1 khi diệt boss) |
| CMD-03 | \[Could] Skill tower, spell scroll, tối đa 1 spell |
| CMD-04 | Ở COMBAT và BOSS_COMBAT, đổi priority chỉ thực hiện được khi game chạy, chịu retarget_delay 0.3 s. Panel mở khi Pause thì chỉ đọc (TIME-08, PNL-12). \[MVP] 2 priority |
| CMD-05 | Trong PREP, panel đổi target, xây dựng, sửa Fortress bằng Mithril và đổi vũ khí dùng được ở cả hai chế độ. Riêng vào Hazard Trial cần Frontline (HZT-01) |
| CMD-06 | Tower bị phá thì priority của slot reset mặc định khi xây lại |
| CMD-07 | Emergency repair khi Fortress đầy HP: từ chối, không tốn lượt, không tốn cooldown |
| CMD-08 | Dùng khi Fortress chỉ thiếu ít hơn lượng hồi (nhưng chưa đầy): vẫn tốn 1 lượt và cooldown, HP kẹp ở max (FORT-03). HUD hiện tooltip "Hồi thừa" khi Fortress thiếu dưới 10% |
| CMD-09 | Điều kiện dùng Emergency repair: đang Commander mode, emg_repair_charges > 0, emg_repair_cd = 0, Fortress chưa đầy HP, không Pause (TIME-08). Thiếu điều kiện nào thì từ chối và HUD báo đúng lý do (HUD-13) |
| CMD-10 | **Bất khả xâm phạm ở Commander mode:** từ frame vào Arriving đến hết Commanding, chỉ huy không thể bị nhắm và không nhận sát thương từ bất kỳ nguồn nào (đạn, AoE, telegraph). Đạn và vùng nổ đang tác dụng lên vị trí chỉ huy bị vô hiệu, không gây knockback hay hiệu ứng trạng thái. Cái giá của chế độ này (v1.8): không gây sát thương, XP từ tower chỉ 50% (XP-02), không có Aura (FRT-01), không có gold chỉ huy (FRT-02), không dùng được skill chủ động (SKL-06), không dùng được Trạm hồi lực (HLT-03), không có regen (mục 3.5.7), không được bonus clear time do chỉ huy đánh. Rủi ro khi chuyển chế độ nằm ở Recall (channel) và Deploy |

### 3.5.5 Chuyển chế độ

Chuyển chế độ **không được là nút thoát hiểm tức thì**.

| **Hướng** | **Luật** |
| --- | --- |
| **Commander sang Frontline (Deploy)** | Tab. Hạ xuống deploy_point ở cổng thành, bất tử 0.6 s, không tấn công. Sinh shockwave đẩy lùi (không sát thương) quanh điểm hạ (deploy_shockwave_radius 3 m, đẩy lùi deploy_shockwave_distance 2 m, gây STAGGER theo AI-04, Brute và boss miễn) |
| **Frontline sang Commander (Recall)** | Tab. Trong return_zone (bán kính 5 m quanh cổng): channel 0.6 s. Ngoài: 3 s. Bị đánh, di chuyển hoặc Dodge thì hủy, không tốn cooldown |
| Cooldown | mode_switch_cooldown 5 s sau khi **hoàn tất** một lần chuyển |
| PREP | Chuyển tự do |
| HAZARD_TRIAL | Khóa chuyển chế độ (Tab không làm gì, không Recall) |
| BOSS_INTRO | Khóa chuyển chế độ |

| **ID** | **Tình huống** | **Xử lý** |
| --- | --- | --- |
| MODE-01 | Bấm Tab khi bị đánh để né damage | Recall hủy khi nhận sát thương. Không có khung bất tử đầu Recall |
| MODE-02 | deploy_point bị quân chiếm | Thuật toán xác định (không ngẫu nhiên): (1) deploy_point không có quân địch trong deploy_clear_radius 0.8 m thì dùng ngay. (2) Ngược lại duyệt ứng viên trên các vòng bán kính 1, 2, 3, 4 m (deploy_point_search_radius) quanh deploy_point, mỗi vòng 8 hướng cách đều bắt đầu từ hướng về Fortress, xoay theo chiều kim đồng hồ. Mỗi ứng viên chiếu lên navmesh, hợp lệ khi không có quân địch trong deploy_clear_radius, không trong spawn_zone, không trong collider tower, Barricade, tường. Chọn ứng viên hợp lệ đầu tiên theo thứ tự vòng nhỏ trước. (3) Không có thì dùng deploy_point mặc định kèm shockwave đẩy lùi; bất tử 0.6 s vẫn áp dụng |
| MODE-03 | Bấm Tab trong cooldown | HUD hiện cooldown, không xếp hàng lệnh |
| MODE-04 | Đang Attack hoặc Skill mà bấm Tab | Bỏ qua, không hủy đòn |
| MODE-05 | Hoàn tất Recall đúng lúc có sát thương chưa xử lý | Trước frame chuyển tính theo Frontline. Từ frame Arriving chỉ huy bất khả xâm phạm, mọi sát thương và đạn chưa xử lý bị hủy (CMD-10) |
| MODE-06 | Chuyển chế độ khi wave chuyển sang SUMMARY | Hoàn tất bình thường |
| MODE-07 | Recall thành công | Mọi quân đang nhắm chỉ huy reset về bảng ưu tiên gốc |
| MODE-08 | \[ĐÃ XÓA v1.8] | Retreat không còn |

### 3.5.6 Aggro

| **ID** | **Đặc tả** |
| --- | --- |
| AGG-01 | Quân bị chỉ huy đánh trúng có provoked_by_player = true trong aggro_duration 4 s (làm mới mỗi lần trúng). Trong thời gian đó ưu tiên chỉ huy nếu trong aggro_range |
| AGG-02 | Battle Cry ép mọi quân trong 6 m nhắm chỉ huy 4 s. Boss miễn taunt, chỉ chịu AGG-01 |
| AGG-03 | Chỉ huy ở Commander không là mục tiêu của bất kỳ quân nào (kể cả Archer và boss tầm xa). Cờ provoked_by_player xóa khi Recall hoàn tất |
| AGG-04 | Quân tầm xa theo bảng ưu tiên. Chỉ huy Frontline trong tầm bắn bị nhắm, đó là rủi ro chủ đích |
| AGG-05 | Chỉ huy chạy xa quá leash_distance 25 m: quân về bảng ưu tiên gốc |
| AGG-06 | Tối đa max_aggro_melee 8 quân cận chiến cùng đánh chỉ huy. Dư đứng vòng ngoài |

### 3.5.7 Sát thương, hồi máu, hiệu ứng

damage_taken = raw × (1 - min(armor_pct, 0.75)) × skill_mult

Ở Commander mode chỉ huy không nhận sát thương từ bất kỳ nguồn nào (damage_taken = 0, CMD-10). skill_mult 0.7 khi Battle Cry. Làm tròn lên, tối thiểu 1 nếu raw > 0 (áp dụng khi Frontline). Sát thương TRUE (chỉ cú rơi khỏi map ở v1.8) bỏ qua armor, skill_mult và i-frame của chỉ huy Frontline (DMG-05).

| **Nguồn hồi** | **Luật** |
| --- | --- |
| Đầu PREP | prep_heal_pct × commander_max_hp, không vượt max. Áp cho cả hai chế độ, một lần khi vào PREP (không áp lại khi ra khỏi Hazard Trial) |
| Hazard Trial | Máu mất hay hồi trong phòng chỉ đổi bản sao chỉ số của phòng, không mang ra ngoài (HZT-06) |
| Regen Commander | \[ĐÃ XÓA v1.9] Commander mode không còn regen. Chỉ huy ở chế độ này bất khả xâm phạm (CMD-10) nên HP không đổi |
| Lifesteal, thẻ Thể lực | Từ REWARD_PICK (SKL-13, mục 3.5.12.3). Không có thẻ hồi HP trực tiếp (RWP-06) |
| Trạm hồi lực | Chỉ ở Frontline, trong COMBAT và BOSS_COMBAT. Đứng yên trong heal_range, giữ E rồi hồi liên tục, tốc độ 10 HP/s và tăng theo skill Trạm hồi lực (SKL-26). Tiêu hao HP kho của trạm (mục 3.6.6) |
| Frontline | Không có regen tự nhiên. Ngoài các nguồn trên không có nguồn hồi nào khác |

**Hiệu ứng trạng thái** (từ Debuffer, boss; \[Should]): Slow (-40% tốc độ, tối đa 3 s), Stun (tối đa 1.5 s rồi miễn stun 3 s), Weaken (-25% sát thương gây ra, tối đa 5 s). Không cộng dồn, chỉ làm mới. Dodge không xóa hiệu ứng.

### 3.5.8 Chết và trạng thái đặc biệt

| **ID** | **Tình huống** | **Xử lý** |
| --- | --- | --- |
| DEAD-01 | commander_hp <= 0 ở Frontline (Commander mode miễn nhiễm, CMD-10, DEAD-09) | Chuyển RunEnd COMMANDER_DIED qua DEAD-10. Không hồi sinh ở MVP |
| DEAD-02 | Hai sát thương chí mạng cùng frame | Xử lý cái đầu, cờ is_dead chặn lần hai |
| DEAD-03 | Chết khi Recall, Stunned | Như DEAD-01. Deploying bất tử nên không chết được |
| DEAD-04 | \[ĐÃ XÓA v1.8] | Overload không còn |
| DEAD-05 | Chết trong PREP hoặc SUMMARY | Không xảy ra. Ngoại lệ là bản sao chỉ số trong Hazard Trial (DEAD-11) |
| DEAD-06 | Rơi khỏi map, kẹt địa hình | Dịch về deploy_point, chịu 15% commander_max_hp (TRUE), HP tối thiểu 1, ghi log |
| DEAD-07 | HP dưới 25% | Viền đỏ, nhịp tim, giảm nhạc nền. Không đổi cơ chế |
| DEAD-08 | \[Could] Last Stand | Chỉ nếu có tài nguyên, làm mục meta shop |
| DEAD-09 | Chỉ huy ở Commander mode | Không thể chết: mọi nguồn sát thương bị vô hiệu (CMD-10). Run chỉ kết thúc qua Fortress sập hoặc Abandon khi ở chế độ này |
| DEAD-10 \[MVP] | Phát tín hiệu chết | Chỉ huy phát `commander_died(cause)` (EVB-10) đúng một lần mỗi run, chặn bằng cờ is_dead (DEAD-02); cờ chỉ xóa khi bắt đầu run mới. `cause` ở MVP chỉ có `ENEMY_DAMAGE` (cú rơi khỏi map không giết được, DEAD-06). Tín hiệu `commander_died` không phải end_type: end_type COMMANDER_DIED do RunState ghi vào `run_ended` theo END-01 |
| DEAD-11 \[MVP] | HP chỉ huy về 0 trong Hazard Trial | Không phải chết thật: **không** phát `commander_died`, không kết thúc run, không bật cờ is_dead. Phòng kết thúc với kết quả DIED (HZT-07), chỉ huy về PREP với đúng HP và trạng thái lúc vào phòng, giữ gold và XP của số con đã giết (HZT-08) |

### 3.5.9 Edge case input của nhân vật

| **ID** | **Tình huống** | **Xử lý** |
| --- | --- | --- |
| CHAR-01 | Đổi chế độ khi đang giữ phím | Xóa input đang giữ, yêu cầu nhả rồi bấm lại (INP-07) |
| CHAR-02 | Con trỏ trên UI | Chuột trái không kích hoạt đòn đánh |
| CHAR-03 | Nhiều phím cùng frame | Ưu tiên: Dodge > Skill > Attack > Mode switch (INP-02). Nhiều skill cùng frame thì ô số nhỏ trước |
| CHAR-04 | Buffer input | Tối đa **1 lệnh** trong `input_buffer_time` 0.15 s (game time) cuối state hiện tại, chi tiết ở CHAR-08 |
| CHAR-05 | Time scale x3 | Buffer, cửa sổ combo, i-frame theo game time. Kiểm thử cảm giác ở x2, x3 |
| CHAR-06 | Pause giữa Dodge, Skill, Recall | Đóng băng nguyên trạng |
| CHAR-07 \[MVP] | Timeline combo | `attack_interval` 0.45 s tính từ lúc bắt đầu đòn, gồm cả recovery. Hết `attack_interval` thì mở `combo_window` 0.35 s để nối đòn kế (đòn 1 sang 2 sang 3). Lệnh Attack bấm sớm hơn nằm trong buffer (CHAR-08). Hết cửa sổ mà không bấm thì combo về đòn 1. Sau đòn 3 combo cũng về đòn 1. Không còn tham số combo_reset_time |
| CHAR-08 \[MVP] | Quy tắc buffer | (a) Chỉ buffer `dodge`, `skill_1..3`, `attack`. **Không buffer `mode_switch` và `heal_channel`** (MODE-03, MODE-04, HLT-03). (b) Chỉ 1 ô. Lệnh mới ghi đè lệnh trong ô khi ưu tiên cao hơn hoặc bằng (Dodge > Skill > Attack, INP-02), thấp hơn thì bỏ. (c) Cửa sổ 0.15 s đo ngược từ thời điểm state hiện tại cho phép hành động kế: hết attack_interval với Attack, hết state Dodge với Dodge, hết skill_animation_time với Skill. (d) Chạy lệnh trong buffer ngay khi state cho phép. Hết hạn thì bỏ. (e) Xóa buffer khi đổi ngữ cảnh, Pause hoặc mất focus (INP-07, INP-08), vào Stunned, Recalling, Dead. (f) Theo game time (CHAR-05): ở x3, 0.15 s game time bằng 50 ms thời gian thực, đây là chủ đích |

### 3.5.10 Vòng lặp Frontline \[MVP]

Mục tiêu: Commander vẫn an toàn và vẫn thắng được, nhưng chậm hơn, nghèo hơn và yếu hơn Frontline. Người chơi ra Frontline vì muốn mạnh hơn, không phải vì bị ép.

| **ID** | **Đặc tả** | **Tag** |
| --- | --- | --- |
| FRT-01 | **Aura Tiền tuyến.** Khi chỉ huy ở Frontline (kể cả đang Dodge, không áp khi Stunned, Recalling, Deploying), mọi tower (WALL, ô grid) trong frontline_aura_radius (12 m) quanh chỉ huy có dealt_mult cộng thêm frontline_aura_dmg_bonus (+0.20), cộng dồn với các khoản dealt_mult khác theo DMG-06. Quét mỗi scan_interval (0.2 s, lệch pha), tower chỉ đọc cờ `aura_active`. Hiển thị vòng sáng quanh chỉ huy và biểu tượng nhỏ trên tower nhận. Tower Barricade và Trạm hồi lực không tấn công nên không hưởng | MVP |
| FRT-02 | **Gold chỉ huy.** Quân chết có hit_by_commander = true cộng vào wave_gold_base với hệ số frontline_gold_mult (1.25) trên gold_reward(w), tức kill_gold của RWD-02. Quân không có cờ thì 1.0. Hệ số áp một lần mỗi quân, kể cả trong Hazard Trial (GLD-10). Hệ số này nằm **trong** wave_gold_base nên chịu gold_pct_total và clear_mult như mọi khoản gold từ quân (mục 3.9.1). Không áp lên boss_gold. Số nổi gold hiển thị đã gồm hệ số, kèm biểu tượng kiếm | MVP |
| FRT-03 | **Giới hạn bậc tower theo Cấp Chỉ huy.** Cổng chỉ đặt ở đầu bậc model (TWR-17): nâng tower lên cấp tower_tier2_level (13) cần commander_level >= tower_gate_tier2 (4); lên cấp tower_tier3_level (25) cần commander_level >= tower_gate_tier3 (8). Trong cùng một bậc không có cổng. Áp cho cả bốn loại tower, kể cả Trạm hồi lực. Xây mới luôn cấp 1. Xây lại (BLD-07) không bị chặn vì commander_level không giảm. Nút Nâng cấp xám kèm "Cần Chỉ huy cấp N" (UPG-06). Ước lượng: người chơi chủ động đạt cấp 4 ở khoảng wave 4, cấp 8 ở khoảng wave 8; người đứng yên chỉ nhận 50% XP nên chậm khoảng 1,6 đến 2 lần | MVP |
| FRT-04 | Aura và gold chỉ huy tắt hoàn toàn ở Commander mode. Đổi chế độ cập nhật cờ aura_active trong cùng frame (không trễ quá 1 scan_interval) | MVP |
| FRT-05 | **Elite có giáp tiền tuyến.** Từ wave 8, mỗi wave 1 Brute "Giáp nặng" với kháng PIERCE 0.4, BLAST 0.4, SLASH 1.0 (EnemyData thêm resist_table tùy chọn). Buộc có chỉ huy hoặc skill SLASH để giải quyết | SHOULD |
| FRT-06 | **Chiến lợi phẩm.** Brute chết rơi 1 gói tiếp tế ở vị trí chết, bán kính nhặt 1 m, tồn tại 12 s game time: cộng gold bằng 1.0 × gold_reward(w) và hồi 2% fortress_max_hp, tối đa 3 gói mỗi wave. Chỉ chỉ huy Frontline nhặt được | SHOULD |

Giả định kỹ thuật: Cấp Chỉ huy (commander_level) chỉ tăng, không giảm trong một run. Tower WALL cũng nhận Aura nếu nằm trong bán kính (chỉ huy đứng gần cổng).

### 3.5.11 XP và Cấp Chỉ huy \[MVP]

| **Ai giết** | **XP nhận (hệ số trên xp_value)** |
| --- | --- |
| Chỉ huy giết (kiếm hoặc skill) | xp_commander_pct = 100% |
| Tower giết, quân đã có cờ hit_by_commander | 100% |
| Tower giết, quân chưa có cờ | xp_tower_only_pct = 50% |
| Quân bị cull chống kẹt, dọn cuối run | 0 (giống RWD-03) |

| **ID** | **Đặc tả** | **Tag** |
| --- | --- | --- |
| XP-01 | xp_value theo loại (EnemyData): Grunt 1, Archer 2, Brute 5, boss 30, Bat 2 \[Should]; 7 loại mới theo bảng cân bằng. Wave 1-30 nhân thêm xp_mult(w) của bảng thưởng theo wave (mặc định 1, mục 6.10), từ wave 31 hệ số là 1. XP là điểm kinh nghiệm trong run, không phải tiền tệ, không mua bán được. Tiền tệ gồm gold, Mithril (chỉ trong run) và danh vọng (mục 3.9) | MVP |
| XP-02 | Bảng hệ số ở trên. XP lẻ cộng dồn dạng số thực, thanh XP hiển thị làm tròn xuống | MVP |
| XP-03 | Cờ hit_by_commander bật ở lần đầu chỉ huy gây ≥ 1 điểm sát thương thật (kiếm hoặc skill, gồm tick vùng cháy). Battle Cry (taunt) và shockwave Deploy không gây sát thương nên không tính. Cờ thuộc về quân, không mất khi recycle (NAV-08) | MVP |
| XP-04 | Chỉ huy bắt đầu run ở **cấp 0**. XP cần để lên cấp n (n ≥ 1): xp_to_level(n) = xp_base + xp_step × (n − 1) = 5 + 4 × (n − 1). XP dư chuyển sang cấp kế. Mỗi lần lên cấp: commander_level += 1, pending_picks += 1, phát level_up. Một wave lên nhiều cấp thì nhiều lượt chọn. RunState.xp là XP trong cấp hiện tại (reset về phần dư khi lên cấp), to_next = xp_to_level(commander_level + 1). Tổng tích lũy chỉ dùng để cân bằng và test, không lưu. | MVP |
| XP-05 | Thanh XP và số lượt chờ hiển thị ở HUD trong COMBAT (HUD-15) nhưng không dừng trận. Chọn ở REWARD_PICK (RWP-01). Đã max hết skill và stat: XP và cấp vẫn tăng (vẫn mở khóa nâng cấp tower), không có lượt chọn mới | MVP |
| XP-06 | **XP trong Hazard Trial.** Quân trong phòng cho xp_value như ngoài wave (hệ số 100% vì chỉ chỉ huy giết được). XP tích trong phòng và chỉ cộng vào chỉ huy khi rời phòng (thắng, bấm rời hoặc chết, HZT-08). Lên cấp từ khoản này sinh lượt chọn như thường, chờ tới REWARD_PICK của wave đó (RWP-01) | MVP |

Cân bằng thô: XP tích lũy để đạt cấp n là 2n² + 3n (cấp 4 = 44, cấp 8 = 152, cấp 10 = 230). Tổng ngân sách quân đến wave 10 khoảng 194, cộng boss (30 mỗi boss) khoảng 60, tức khoảng 254 XP nếu 100%, tương ứng cấp 10. Người chỉ để tower giết nhận khoảng một nửa nên chạm cấp 8 ở khoảng wave 11-12. **Mục tiêu playtest:** người chơi chủ động chạm cấp 4 ở wave 4 ± 1 và cấp 8 ở wave 8 ± 1. Từ v2.0 các ước tính này tính lại theo kịch bản wave và xp_mult(w) trong bảng cân bằng; xp_base và xp_step cũng nằm trong bảng (sheet nhân vật).

### 3.5.12 Skill của chỉ huy \[MVP]

| **ID** | **Đặc tả** | **Tag** |
| --- | --- | --- |
| SKL-01 | Hai nhóm ô: 3 ô chủ động (phím 1, 2, 3) và 3 ô bị động, trống khi bắt đầu run. Skill nền (đòn kiếm, Dodge, Battle Cry Q, Recall/Deploy, Emergency repair R) không chiếm ô | MVP |
| SKL-02 | Skill có level 1 đến `skill_max_level` = 3 ở MVP (\[Should] 5). Chọn lại thẻ đã có thì lên level. Max thì không xuất hiện lại | MVP |
| SKL-03 | Skill mới vào ô trống có số nhỏ nhất. Ô không dồn lại khi một ô trống (MVP không có xóa skill) | MVP |
| SKL-04 | Pool MVP: chủ động Whirlwind, Sword Wave, Firebomb. Bị động Sharpness, Armored, Lifesteal, Trạm hồi lực (SKL-26); \[Should] Lightstep, Focus (cắt khỏi MVP ở v1.9). Stat Thể lực, Tinh thông; \[Should] Bền thành (cắt khỏi MVP ở v1.9). Mỗi stat tối đa `stat_max_stacks` = 3. Số liệu ở bảng 3.5.12.1 đến 3.5.12.3 | MVP |
| SKL-05 | Skill chủ động bấm tay, nhắm theo vị trí chuột (có hướng), cooldown theo game time (CHAR-05), phím vật lý (INP-09). Nhiều phím cùng frame: Dodge > Skill > Attack > Mode switch, nhiều skill cùng frame thì ô số nhỏ trước (INP-02) | MVP |
| SKL-06 | Skill chủ động chỉ chạy ở Frontline. Ở Commander mode phím 1-3 không làm gì, HUD xám. Không dùng được khi Stunned; khi Recalling thì bấm skill hủy Recall như di chuyển | MVP |
| SKL-07 | Skill bị động liên quan chỉ huy chỉ có tác dụng ở Frontline (đa số tính theo hành động chiến đấu). Lifesteal hồi theo kill bằng kiếm hoặc skill | MVP |
| SKL-08 | Reroll khởi đầu 1 lần mỗi run (RWP-03), cắt khỏi MVP ở v1.9. \[Should] mua thêm bằng danh vọng (REROLL_PLUS) | SHOULD |
| SKL-09 | Skill chủ động nhân sát thương theo DMG-06 và kháng boss theo DMG-01 như mọi nguồn khác. Cấm skill nào đổi số lượt hay cooldown Emergency repair (APL-04), đổi CMD-10 hay làm chỉ huy bị đánh ở Commander mode | MVP |
| SKL-10 | **Whirlwind** (chủ động, SLASH): xoay 1 vòng quanh người, trúng mọi quân trong bán kính. Số liệu bảng 3.5.12.1 | MVP |
| SKL-11 | **Sword Wave** (chủ động, SLASH): kiếm khí lưỡi liềm bay thẳng về phía chuột, trúng mọi quân trên đường bay | MVP |
| SKL-12 | **Firebomb** (chủ động, BLAST): ném tới vị trí chuột, vùng cháy gây sát thương theo tick mỗi giây. Dùng BLAST để tái dùng bảng kháng boss hiện có | MVP |
| SKL-13 | Bị động Sharpness, Lifesteal; \[Should] Lightstep, Focus. Số liệu bảng 3.5.12.2 | MVP |
| SKL-14 | Bị động Armored: +5% armor_pct mỗi level (L3 = 15%), vào trần 75% (APL-03). Là nguồn armor duy nhất ở MVP | MVP |
| SKL-15 | Mọi bị động và stat ghi vào StatBlock theo add và mul, tính lại khi `reward_picked`. Không sửa trực tiếp CharacterStats hay TowerData. Riêng thẻ Thể lực và \[Should] Bền thành tăng commander_max_hp và fortress_max_hp hiệu dụng trong RunState (không sửa RunConfig): cộng phẳng theo giá trị gốc của RunConfig (không lãi kép), làm tròn xuống, hồi đúng lượng vừa tăng, xử lý một lần khi phát reward_picked (EVB-29). | MVP |
| SKL-20 | **Merge:** hai skill cùng đạt level tối đa là nguyên liệu, cả hai biến mất, skill merge vào ô nguyên liệu chủ động (số nhỏ nếu cùng loại), vào ở level 1. Một thẻ trong lượt chọn chắc chắn là merge khi có công thức đủ điều kiện. Công thức đầu tiên: Cyclone (Whirlwind + Lightstep), Inferno (Firebomb + Focus) | SHOULD |
| SKL-21 | Panel gợi ý công thức ở thẻ (icon + "Cần cả hai max") | SHOULD |
| SKL-22 | Skill merge không làm nguyên liệu tiếp | SHOULD |
| SKL-23 | Kéo thả đổi ô (PREP, REWARD_PICK, Pause trong PREP), hoán đổi hoặc chuyển ô trống | SHOULD |
| SKL-24 | Mở ô thứ 4, 5 (SLOT_ACTIVE, SLOT_PASSIVE) và mở skill vào pool bằng danh vọng, level tối đa 5, thêm Sword Throw (Disarmed), War Horn, Arrow Rain | SHOULD |
| SKL-25 | Xóa skill | COULD |
| SKL-26 \[MVP] | **Trạm hồi lực** (bị động): mỗi level +5 HP/s tốc độ hồi cho chỉ huy khi hồi tại Trạm hồi lực (level 1, 2, 3 cho 15, 20, 25 HP/s; chưa có skill là 10 HP/s). Vì heal_drain_rate cố định, nâng tốc độ hồi cũng là nâng hệ số k (0.75, 1.0, 1.25). Không đổi HP kho (theo cấp trạm trong bảng cân bằng, cấp 1 là 300), không đổi heal_range, không làm trạm tự hồi (HLT-08). Ghi vào StatBlock theo SKL-15 (khóa heal_rate_add), không sửa TowerData. Lọc khỏi pool theo RWP-06 | MVP |

**3.5.12.1 Skill chủ động \[MVP]** (số liệu khởi điểm; từ v2.0 SkillData sinh từ sheet skill của bảng cân bằng, mục 6.10)

| **Skill** | **damage_type** | **Level 1** | **Mỗi level** | **Level 3** |
| --- | --- | --- | --- | --- |
| Whirlwind (SKL-10) | SLASH | Xoay 1 vòng, bán kính 3 m, 15 sát thương, cooldown 6 s | +5 sát thương, −0.5 s | 25 sát thương, 5 s |
| Sword Wave (SKL-11) | SLASH | Kiếm khí lưỡi liềm rộng 3 m, bay thẳng 4 m về phía chuột với tốc độ 20 m/s (skill_sword_wave_speed), dừng khi chạm tường, Barricade hoặc rìa spawn_zone, trúng mọi quân, 18 sát thương, cooldown 5 s | +3 sát thương, +0.5 m bề rộng | 24 sát thương, rộng 4 m |
| Firebomb (SKL-12) | BLAST | Ném tới vị trí chuột trong tầm skill_firebomb_cast_range 10 m (chuột xa hơn thì rơi ở mép tầm, không vào spawn_zone), vùng cháy 2.5 m trong 4 s, 6 sát thương mỗi giây, cooldown 8 s | +2/s, +0.5 m | 10/s, vùng 3.5 m |

Tương tác với boss pha 1 (Bulwark): Whirlwind và Sword Wave còn 60% (SLASH), Firebomb 100% (BLAST), Cannon 100%, Arrow 0% (miễn nhiễm). Chỉ huy luôn có công cụ gây sát thương lên giáp ngay cả khi tower yếu.

**3.5.12.2 Bị động \[MVP]**

| **Skill** | **Mỗi level** | **Level 3** | **Ghi chú** |
| --- | --- | --- | --- |
| Sharpness | +8% sát thương kiếm và skill | +24% | |
| Lightstep \[Should] | +5% tốc chạy, −0.1 s cooldown Dodge | +15%, −0.3 s | Dodge cooldown gốc 1.5 s |
| Armored | +5% armor chỉ huy | 15% | Nguồn armor duy nhất ở MVP, trần 75% (APL-03) |
| Lifesteal | Mỗi quân bị diệt bằng kiếm hoặc skill hồi 0.5% commander_max_hp | 1.5% | Frontline vốn không regen |
| Focus \[Should] | −6% cooldown mọi skill chủ động | −18% | |
| Trạm hồi lực | +5 HP/s tốc độ hồi cho chỉ huy tại Trạm hồi lực (k tăng theo) | 25 HP/s, k = 1.25 | Level 0 là 10 HP/s. Pool lọc theo RWP-06 |

**3.5.12.3 Thẻ stat \[MVP]** (tối đa `stat_max_stacks` = 3 lần mỗi loại)

| **Thẻ** | **Tác dụng mỗi lần** |
| --- | --- |
| Thể lực | +10 HP tối đa chỉ huy (cộng phẳng, hồi cùng lượng) |
| Tinh thông | +5% sát thương skill chủ động |
| Bền thành \[Should] | +4% fortress_max_hp gốc của RunConfig (làm tròn xuống), hồi đúng lượng tăng |

Ước tính nhịp: kỷ lục dự kiến 10-20 wave tương ứng cấp 10-20, tức 10-20 lượt chọn. Tổng 3 chủ động × 3 + 3 bị động × 3 + 2 stat × 3 = 24 lượt để bão hòa mọi thứ (vượt xa một run), nên người chơi giỏi bão hòa được các skill mình chọn, người chơi mới thấy được một "build".

### 3.5.13 Vũ khí \[MVP]

Mọi vũ khí là biến thể của kiếm: dùng chung kiểu cầm, animation, combo và skill chủ động. Mỗi cây khác nhau ở tầm đánh, VFX, model và một hiệu ứng. Run bắt đầu với kiếm gốc; boss wave 5, 10, 15, 20, 25 mỗi lần rơi một cây chưa có, đến wave 25 là đủ 5 cây.

| **Vũ khí (hiệu ứng)** | **Đặc tả (giá trị khởi điểm, nằm trong bảng cân bằng)** |
| --- | --- |
| Kiếm gốc | Không hiệu ứng, range_mult 1.0 |
| Frost | Mỗi đòn trúng làm chậm mục tiêu 20% trong 3 giây. Đòn nào trúng cũng làm mới thời gian, không cooldown, không cộng dồn |
| Chain Lightning | Đòn trúng phóng tia điện: 20% sát thương cơ bản mỗi mục tiêu, tối đa 3 con kể cả con đầu tiên. Lan trong bán kính 2 m quanh con vừa trúng, không trúng một con hai lần trong một chuỗi. Cooldown 5 giây chung cho người chơi |
| Burn | Tổng 50% sát thương cơ bản chia đều trong 5 giây. Không cộng dồn; trúng lại chỉ làm mới thời gian |
| Rampage | Theo tỷ lệ commander_hp / commander_max_hp: trên 50% đến 80% thì +10% sát thương; trên 30% đến 50% thì +25%; từ 30% trở xuống thì +50%; trên 80% thì không cộng |
| Swift | Tốc độ đánh +50%, tầm đánh −30%. Animation chém nhanh hơn, thời gian giữ combo (combo_window) không đổi |

| **ID** | **Đặc tả** | **Tag** |
| --- | --- | --- |
| WPN-01 | **Dữ liệu.** Mỗi vũ khí là một WeaponData (mục 6.6): weapon_id, khóa tên, model, VFX, range_mult, effect_id và tham số hiệu ứng. Số liệu sinh từ sheet vũ khí của bảng cân bằng (BAL-04). Sát thương đòn kiếm vẫn là SLASH (DMG-01) | MVP |
| WPN-02 | **Đầu run.** owned_weapons = \[kiếm gốc], equipped_weapon = kiếm gốc. Kiếm gốc không mất, luôn chọn lại được | MVP |
| WPN-03 | **Đổi vũ khí** bất cứ lúc nào trong PREP, ở cả hai chế độ, kể cả khi Pause trong PREP (như BLD-04), qua ô vũ khí trên HUD (HUD-21) hoặc panel vũ khí (PNL-15). Tức thì, miễn phí, phát weapon_equipped (EVB-43). Không đổi được ở HAZARD_TRIAL, COMBAT, BOSS_INTRO, BOSS_COMBAT, SUMMARY, REWARD_PICK. Hazard Trial dùng vũ khí đang trang bị lúc vào phòng (HZT-06) | MVP |
| WPN-04 | **Phạm vi hiệu ứng.** Hiệu ứng kích hoạt ở mọi lần trúng có sát thương > 0 của đòn kiếm thường và skill chủ động (gồm tick vùng cháy Firebomb). Battle Cry và shockwave Deploy không gây sát thương nên không kích hoạt. Sát thương do chính hiệu ứng gây ra (tia Chain Lightning, tick Burn) không kích hoạt hiệu ứng lần nữa. **Sát thương hiệu ứng** = tỷ lệ của hiệu ứng × sát thương cơ bản (sword_damage qua StatBlock, không gồm hệ số đòn 3), rồi nhân dealt_mult của chỉ huy và kháng của mục tiêu theo DMG-06; tính là sát thương chỉ huy (XP-03, CMB-10) và mang damage_type của đòn kích hoạt (SLASH với kiếm, Whirlwind, Sword Wave; BLAST với Firebomb). Không áp cho quân còn spawn_grace (SPN-02) | MVP |
| WPN-05 | **Lên boss.** Hiệu ứng có tác dụng lên boss, kể cả làm chậm của Frost (ngoại lệ của BOSS-01), trừ khi boss đang ở pha có resist(damage_type của đòn kích hoạt) = 0 (DMG-01, DMG-02). Sát thương hiệu ứng lên boss nhân resist như mọi nguồn khác. Làm chậm của Frost nhân với hệ số tốc độ Cuồng nộ (ENR-02) | MVP |
| WPN-06 | **Frost.** Đòn trúng đặt Slow frost_slow_pct (0.20) trong frost_duration (3 s game time) lên mục tiêu. Trúng lại làm mới thời gian, không cộng dồn với chính nó. Không cooldown | MVP |
| WPN-07 | **Chain Lightning.** Khi chain_cd = 0, đòn trúng mục tiêu đầu tiên bắt đầu một chuỗi: mục tiêu đầu và tối đa chain_max_targets − 1 (2) mục tiêu tiếp theo mỗi con nhận chain_damage_pct (0.20) sát thương cơ bản. Mục tiêu kế là quân gần con vừa trúng nhất trong chain_radius (2 m), chưa trúng trong chuỗi này, hòa thì entity_id nhỏ hơn. Một đòn trúng nhiều mục tiêu (cleave, Whirlwind) chỉ mở một chuỗi, từ mục tiêu được chọn đầu tiên theo CMB-09. Bắt đầu chuỗi thì chain_cd = chain_cooldown (5 s game time), chung cho người chơi | MVP |
| WPN-08 | **Burn.** Đòn trúng đặt Burn: tổng burn_total_pct (0.50) sát thương cơ bản chia đều theo tick mỗi giây trong burn_duration (5 s). Trúng lại khi đang cháy chỉ làm mới thời gian về 5 s, không cộng dồn lượng. Tick dùng dot_remainder như DMG-06 | MVP |
| WPN-09 | **Rampage.** Cộng vào dealt_mult của sát thương kiếm và mọi skill chủ động, cùng nhóm với Sharpness và Tinh thông (DMG-06): +0.10 khi tỷ lệ máu trong (0.5, 0.8], +0.25 trong (0.3, 0.5], +0.50 khi ≤ 0.3. Tỷ lệ máu đọc lúc trúng đích (PRJ-07). Trong Hazard Trial dùng máu của bản sao trong phòng | MVP |
| WPN-10 | **Swift.** attack_interval chia swift_attack_speed_mult (1.5), sword_range nhân swift_range_mult (0.7). Animation đòn kiếm tăng tốc cùng tỷ lệ; combo_window (CHAR-07) và input_buffer_time không đổi | MVP |
| WPN-11 | **Rơi từ boss.** Ở các wave trong weapon_drop_waves (5, 10, 15, 20, 25): khi boss bị diệt (kể cả sau Cuồng nộ) và wave vào SUMMARY với waves_cleared tăng (cùng điều kiện với BRW-07), thêm một vũ khí chưa có vào owned_weapons, chọn ngẫu nhiên đều trong các cây chưa có bằng RNG riêng seed = hash(run_seed, "weapon", wave_index), không trùng. Không cần nhặt, không tự trang bị; SUMMARY hiện dòng "Nhận vũ khí X", toast ALR-19, phát weapon_gained (EVB-42). Đủ 5 cây thì không rơi gì; boss sau wave 25 không rơi. Thua đè thắng trong wave đó thì không nhận (GLD-08). Boss trong Hazard Trial không rơi vũ khí (HZT-04). \[Should] start_wave > 1: boss đã bỏ qua không tính bù (như STR-08) | MVP |
| WPN-12 | **Chỉ trong run.** Vũ khí mất khi hết run, không ghi save (RUN-01), không có trong meta shop | MVP |

## 3.6 Fortress, Build slot, Grid và Tower

### 3.6.1 Fortress

Thực thể duy nhất, cố định, không xây, không bán, không di chuyển. HP là HP chung của cả run.

| **Tham số** | **Giá trị** | **Ghi chú** |
| --- | --- | --- |
| fortress_max_hp | 1000 | Cộng meta FORT_HP (+5% mỗi cấp). Sửa bằng Mithril tính theo % nên một viên luôn hồi cùng tỷ lệ (MTH-03) |
| fortress_armor_pct | 0% | Luôn 0% ở MVP. Trần 60% chỉ dự phòng cho nâng cấp thành \[Could] |
| fortress_melee_slots | 12 | Vị trí quân cận chiến đánh cùng lúc |
| mithril_repair_pct | 20% | HP hồi cho mỗi viên Mithril, tính trên fortress_max_hp hiệu dụng. Chỉ PREP (MTH-03) |
| low_hp_warning_pct | 30% | Cảnh báo HUD |

fortress_damage = raw × (1 - fortress_armor_pct) × ward_mult, làm tròn lên một lần ở cuối, tối thiểu 1 (trừ TRUE). ward_mult = 0.75 khi BUFF_WARD \[Should] đang hoạt động, ngược lại 1. BUFF_WARD là hệ số giảm sát thương độc lập, không cộng vào fortress_armor_pct nên không chịu trần APL-03. Grunt, Brute đứng ở melee_slot dọc tường. Archer bắn Fortress khi không còn mục tiêu ưu tiên. Boss đánh thường (kể cả khi Cuồng nộ, ENR-02).

| **ID** | **Sửa chữa** |
| --- | --- |
| REP-02 | **Emergency repair** theo CMD-02. Không đổi ở v2.0, không tốn Mithril (MTH-06) |
| REP-03 | Không có regen tự nhiên ở MVP |
| REP-07 | **Sửa trong PREP chỉ bằng Mithril** theo mục 3.9.3 (MTH-03 đến MTH-05). Không còn sửa bằng gold |

| **ID** | **Edge case Fortress** | **Xử lý** |
| --- | --- | --- |
| FORT-01 | Quá 12 quân muốn đánh | Dư đứng hàng chờ, quay sang mục tiêu khác nếu có |
| FORT-02 | Nhiều sát thương làm HP dưới 0 cùng frame | Chốt fortress_hp = 0 một lần, phát fortress_destroyed một lần |
| FORT-03 | Sát thương âm hoặc hồi vượt max | Kẹp trong \[0, fortress_max_hp] |
| FORT-04 | Meta FORT_HP giữa hai run | Áp khi RunLoading, HP khởi đầu luôn đầy |
| FORT-05 | Fortress bị đánh ở PREP, SUMMARY | Không xảy ra |
| FORT-06 | SUMMARY khi Fortress dưới 30% | Giữ cảnh báo HUD, gợi ý "Sửa Fortress bằng Mithril" ở PREP kế (gợi ý vào Hazard Trial nếu mithril = 0) |

### 3.6.2 Build slot và Grid

Vị trí xây gồm hai loại, đều là slot theo nghĩa của các luật SLOT bên dưới:

- **Slot WALL** (W1-W3): Marker3D đặt tay trên tường Fortress với slot_id, zone, allowed_types, position, facing.
- **Ô grid (zone GROUND)**: mặt đất hành lang được chia thành ô vuông grid_cell_size (2 m), hai ô kề nhau cách nhau grid_cell_gap (0.5 m), mỗi cột có grid_rows (9) ô phủ bề ngang hành lang 23.5 m (v2.0 mở rộng từ 16 m). Lúc nạp level, GroundGrid đọc Resource GridData và sinh sẵn một slot cho mỗi ô hợp lệ (cùng scene slot với WALL), gán slot_id = cell_id, zone GROUND, position = tâm ô, facing hướng về phía spawn, allowed_types để trống (theo zone). Sau bước này mỗi ô là một slot bình thường: có trạng thái, bấm được, nhận tower, bị phá, xây lại như slot WALL. Từ v2.0 không còn làn cấm xây ở giữa (no_build_lane); đường đi cho quân được giữ bằng luật cấm chặn kín (GRID-07).

Tổng công trình tối đa là 6: 3 slot WALL cộng tối đa max_ground_buildings (3) công trình trên grid. Ngưỡng đo hiệu năng (ACP-01, TWR-15) tính theo 6 công trình.

| **Zone** | **ID** | **Số vị trí** | **Loại cho phép (MVP)** | **Ghi chú** |
| --- | --- | --- | --- | --- |
| WALL | W1-W3 | 3 slot | Arrow, Cannon | Trên tường Fortress, an toàn với quân cận chiến. W2 là slot mặc định của Cannon có sẵn (starter_cannon_slot) |
| GROUND | Ô grid G_c_r | Theo GridData, tối đa 3 công trình (max_ground_buildings) | Arrow, Cannon, Barricade, Trạm hồi lực | Phủ bề ngang hành lang, từ trước cổng tới trước spawn_zone. Arrow có sẵn đứng ở ô starter_arrow_slot và tính vào max_ground_buildings, nên người chơi còn 2 chỗ đất tự xây |

Barricade và Trạm hồi lực không đặt được ở WALL (HLT-01). Bẫy \[Should] dùng ô grid, chiếm một ô. Nếu sau này cần luật riêng cho một phần mặt đất (ví dụ tower chỉ đặt được phía xa), thêm trường zone cho từng ô trong GridData, không đổi cell_id.

Bố cục grid của mỗi map do Level khai báo trong GridData (số cột, grid_rows hàng, khoảng cách ô). Số cột theo chiều dài hành lang do map quyết định. StartPack \[Should] trỏ tới ô bằng cell_id (GRID-01). Đổi map thì sửa GridData.

| **Tham số** | **Giá trị** | **Ghi chú** |
| --- | --- | --- |
| grid_cell_size | Theo GameConfig (mục 6.3), khởi điểm 2 m | Mỗi công trình chiếm đúng 1 ô |
| grid_cell_gap | Theo GameConfig, khởi điểm 0.5 m | Khoảng trống giữa hai ô kề nhau |
| grid_rows | Theo GridData, khởi điểm 9 | 9 × 2 m + 8 × 0.5 m = 22 m, nằm trọn trong bề ngang hành lang 23.5 m (mỗi bên dư 0.75 m). Tâm ô theo bề ngang ở 0, ±2.5, ±5, ±7.5, ±10 m; hàng giữa là hàng 4 (tâm 0) |
| Hàng, cột | Theo GridData. Cột đánh số từ phía cổng (cột 0 sát cổng nhất), hàng đánh số theo chiều ngang hành lang (0 đến grid_rows − 1) | Chỉ số dùng trong cell_id (GRID-01) |
| max_ground_buildings | Theo GameConfig (mục 6.3), khởi điểm 3 | Trần cố định suốt run. Ô RUINED cũng chiếm chỗ (GRID-04) |

| **ID** | **Luật** |
| --- | --- |
| SLOT-01 | Mỗi slot (slot WALL hoặc ô grid) chứa tối đa 1 công trình. Trạng thái: EMPTY, OCCUPIED, RUINED. Slot RUINED nhớ ruined_type và ruined_level của tower vừa mất (SLOT-08) |
| SLOT-02 | RUINED hoạt động như trống (xây được ở PREP) nhưng hiện đống đổ nát, có collision và obstacle, và còn nhớ loại, cấp của tower đã mất (SLOT-08). Ô grid RUINED vẫn chiếm 1 chỗ trong trần max_ground_buildings (GRID-04) cho tới khi được xây lên hoặc dọn (CLR-01). Đống đổ nát tính là vật cản khi kiểm chặn kín đường (GRID-07) |
| SLOT-04 | \[Could] Thêm slot WALL chỉ cần thêm marker và dữ liệu; thêm ô grid chỉ cần sửa GridData |
| SLOT-05 | Vị trí slot WALL và cell_id của ô grid cố định qua các run. Kiểm tra lúc nạp level: đủ W1-W3, tiền tố slot_id (W cho WALL, G cho GROUND) khớp zone, không trùng slot_id, starter_cannon_slot là slot WALL có thật, starter_arrow_slot là ô grid hợp lệ (không nằm trong spawn_zone, return_zone, vùng cấm quanh boss_melee_point của GRID-08 hay quá gần command_post) \[LOG] |
| SLOT-06 | Vòng sáng slot ở PREP, tắt ở COMBAT, chỉ hiện trên slot còn xây được; với ô grid là lưới ô hiện ở PREP. Khi đủ max_ground_buildings, ô grid EMPTY hiện màu khóa. Biểu tượng vẽ trên cùng (MSE-04) |
| SLOT-07 | Vật che tầm nhìn dùng shader xuyên thấu (MSE-05) |
| SLOT-08 | Ghi nhớ khi tower bị phá: slot RUINED lưu ruined_type và ruined_level, là loại và cấp của tower trước khi bị phá, để xây lại giữ cấp (BLD-07). ruined_type và ruined_level bị xóa khi xây bất kỳ công trình nào lên slot hoặc khi dọn đổ nát (CLR-01). Slot RUINED không bán được. Mất mức nhớ khi xây đè là chủ đích: xây lại một lần hay xây cấp 1 rồi nâng có cùng tổng gold (BLD-07) nên người chơi không thiệt. |

| **ID** | **Luật grid** |
| --- | --- |
| GRID-01 | Mỗi ô có cell_id ổn định dạng G_c_r: G là zone GROUND, c là chỉ số cột, r là chỉ số hàng (ví dụ G_3_2, G_5_0), là slot_id của slot sinh ra ở ô đó. RunState, save và StartPack trỏ tới ô bằng cell_id |
| GRID-02 | Mọi slot ô grid được sinh một lần lúc nạp level, trước khi hệ thống Tower & Build thu thập danh sách slot, và tồn tại suốt run kể cả khi EMPTY. Không tạo hay xóa slot ô grid giữa run |
| GRID-03 | GridData chỉ chứa ô mặt đất, và toàn bộ ô nằm ngoài spawn_zone, return_zone và cách command_post ≥ grid_min_gap_to_command_post. Ô vi phạm bị bỏ khi nạp và ghi lỗi \[LOG] |
| GRID-04 | Phân biệt hai giá trị. **Trần** max_ground_buildings (3) cố định suốt run, không thao tác nào làm trần tăng hay giảm. **Số chỗ đã dùng** ground_used là số ô grid đang OCCUPIED hoặc RUINED, luôn ≤ trần. Khi ground_used = trần thì mục xây trên ô EMPTY xám kèm lý do (BLD-08). Xây trên ô RUINED (xây lại hoặc xây loại khác) không bị chặn vì ô đó đã chiếm chỗ. Bán (SELL-03) hoặc dọn đổ nát (CLR-02) trên ô grid làm ground_used giảm 1, tức trả lại 1 chỗ |
| GRID-05 | Collider chọn (pickable) của ô grid nhỏ hơn ô một chút (mặc định 1.9 m với ô 2 m) để không chồng lên ô bên cạnh (MSE-02) |
| GRID-06 | Lưới ô, vòng sáng và collider chọn của ô grid không nằm trong nhóm nguồn bake navmesh |
| GRID-07 \[MVP] | **Cấm chặn kín đường.** Lúc xác nhận xây trên ô grid EMPTY (kể cả xây loại khác lên ô RUINED), kiểm tra còn đường đi từ spawn_zone tới cả hai đích: (1) cổng Fortress và (2) boss_melee_point (BOSS-40, thiếu marker thì dùng điểm dự phòng của BOSS-40), khi coi mọi ô OCCUPIED, RUINED và ô định xây là vật cản (đống đổ nát và Barricade cũng là vật cản). Với đích (2), đường phải đưa được tâm agent lớn tới đúng điểm đó. Mất đường tới một trong hai đích thì từ chối giao dịch, không trừ gold, lý do BLOCKS_PATH; mục xây hiện xám kèm "Sẽ chặn kín đường đi" (BLD-10, HUD-05). Đường phải đủ rộng cho agent lớn của boss (path_check_min_width, mặc định 3.2 m bằng hai lần bán kính nav_layer_large, BOSS-03). Kiểm bằng hàm thuần trên lưới ô của GridData (không cắt lại navmesh lúc chạy), nguyên tử như BLD-02. Xây lại cùng chỗ (BLD-07) không bao giờ làm đổi tập vật cản nên không cần kiểm |
| GRID-08 \[MVP] | **Vùng cấm xây quanh điểm đứng của Bulwark.** Ô grid có điểm gần nhất (theo hình vuông grid_cell_size của ô) cách boss_melee_point dưới boss_point_clear_radius (GameConfig, khởi điểm 3.2 m, bằng hai lần bán kính nav_layer_large 1.6 m: thân boss cộng một khoảng trống bằng thân boss để agent lớn tiến vào và quay mặt) thì không được sinh slot: bỏ lúc nạp như GRID-03 và ghi \[LOG]. Thiếu marker thì vùng cấm tính quanh điểm dự phòng của BOSS-40. starter_arrow_slot không được nằm trong vùng này (SLOT-05). Cùng với đích (2) của GRID-07, luật này bảo đảm Bulwark luôn tới được điểm đứng và Stomp chạm Fortress dù người chơi xây thế nào |

### 3.6.3 Tower

Arrow, Cannon, Barricade và Trạm hồi lực đều có cấp 1 đến tower_max_level (36): cấp 1 khi xây, nâng từng cấp một. Giá và chỉ số của từng cấp nằm trong bảng cân bằng (sheet tower, mục 6.10) và được sinh thành TowerData của từng loại cùng dữ liệu theo cấp. Cấp 1 (giá trị khởi điểm) đủ để viết logic và test; các cấp sau lấy từ bảng. Nâng lên bậc 2 (cấp 13) và bậc 3 (cấp 25) bị giới hạn theo Cấp Chỉ huy (FRT-03, UPG-06).

| **Loại** | **Chỉ số thay đổi theo cấp (cột trong bảng)** | **Cấp 1 (khởi điểm)** |
| --- | --- | --- |
| **Arrow** (đơn mục tiêu, bắn được mục tiêu bay, PIERCE) | cost, damage, fire_rate, range, hp | 50 gold, 10 sát thương, 1.0/s, 14 m, 120 HP |
| **Cannon** (sát thương lan, chỉ mặt đất, BLAST) | cost, damage, fire_rate, range_max (range_min cố định 4 m), blast_radius, hp | 90 gold, 35 sát thương, 0.4/s, 4-12 m, nổ 2.5 m, 150 HP |
| **Barricade** (tank building, không tấn công) | cost, hp, aggro_weight | 40 gold, 300 HP, aggro_weight 1.0 |
| **Trạm hồi lực** (không tấn công, mục 3.6.6) | cost, hp (kho) | 80 gold, kho 300 HP |

| **ID** | **Bậc model** |
| --- | --- |
| TWR-17 \[MVP] | **Ba bậc model.** Cấp 1 đến 12 dùng model bậc 1, cấp 13 đến 24 model bậc 2, cấp 25 đến 36 model bậc 3 (ranh giới tower_tier2_level = 13, tower_tier3_level = 25 trong GameConfig). TowerData của mỗi loại giữ ba scene model. Nâng qua ranh giới bậc thì đổi model ngay, phát slot_changed (EVB-13) như mọi lần nâng. Đống đổ nát dùng chung một model cho mọi loại và mọi bậc (quyết định đã chốt). Cảnh báo và tooltip dùng số cấp thật (ví dụ "Arrow cấp 14") |

Ai đánh được tower: tower trên ô grid (kể cả Trạm hồi lực) và Barricade bị mọi loại quân theo bảng ưu tiên. Tower WALL chỉ bị Archer, boss có is_ranged, Bat và sát thương AoE, không bị quân cận chiến mặt đất.

| **ID** | **Hồi HP, phá hủy** |
| --- | --- |
| TWR-01 | Tower hồi đầy HP miễn phí ở đầu mỗi PREP (tower_full_heal_on_prep = true). Ngoại lệ: Trạm hồi lực không tự hồi bao giờ (HLT-08) |
| TWR-02 | HP = 0 trong wave: vào RUINED, hủy projectile chưa rời nòng, không rơi thưởng, ghi ruined_type và ruined_level (SLOT-08) |
| TWR-03 | Tower bị phá không hoàn tiền. Xây lại ở PREP giữ nguyên cấp đã có, giá bằng tổng cost từ cấp 1 đến cấp đó theo TowerData (SLOT-08, BLD-07) |
| TWR-04 | Projectile đã rời nòng vẫn bay tiếp đến khi va chạm hoặc hết tầm |

### 3.6.4 Xây, nâng cấp, bán, dọn đổ nát (chỉ PREP)

**Luồng xây:** chọn slot trống hoặc slot RUINED (slot WALL hoặc ô grid), hiện menu loại cho phép, chọn loại (ghost preview kèm vòng tầm bắn), xác nhận (kiểm tra gold, kiểm tra chặn kín đường với ô grid theo GRID-07, trừ gold, tạo tower, animation dựng 0.5 s chỉ là hiệu ứng, tower hoạt động ngay). Từ v2.0 không còn di chuyển hay hoán đổi tower: người chơi tự chọn loại và slot khi xây.

| **ID** | **Xây** | **Xử lý** |
| --- | --- | --- |
| BLD-01 | Không đủ gold | Nút xám, hiện giá và số thiếu |
| BLD-02 | Bấm Xây đúng frame PREP kết thúc | Giao dịch nguyên tử: hoàn tất trước khi chuyển state hoặc bị từ chối. \[Should] Việc hủy hoàn tác bán khi PREP kết thúc cũng nguyên tử với chuyển state |
| BLD-03 | Bấm nhiều lần trên một slot | Khóa slot khi đang xử lý |
| BLD-04 | Xây khi Pause | Cho phép (PREP vẫn là PREP) |
| BLD-05 | Bấm Bắt đầu wave hoặc vào Hazard Trial khi đang mở menu xây | Đóng menu, hủy lựa chọn chưa xác nhận |
| BLD-06 | Slot không hợp lệ với loại tower | Loại đó không xuất hiện trong menu |
| BLD-07 | Xây lại ở slot RUINED | Ở PREP, menu xây của slot RUINED có thêm mục đầu tiên "Xây lại \[loại] cấp n": tạo ngay tower đó ở đúng cấp n với giá rebuild_cost = tổng cost cấp 1 đến cấp n của loại đó trong TowerData (hệ số 1.00, tính theo dữ liệu, không theo invested_gold hay giá bán). Đây chỉ là tiện ích thao tác: tổng gold bằng xây cấp 1 rồi nâng lần lượt. Các mục xây thường ở cấp 1 vẫn còn. Kiểm tra gold >= rebuild_cost rồi trừ, nguyên tử như BLD-02. Không đủ gold: nút xám kèm giá và số thiếu (BLD-01). Tower xây lại đầy HP, target_priority về mặc định (CMD-06), invested_gold = rebuild_cost |
| BLD-08 | Xây trên ô grid EMPTY khi grid đã đủ max_ground_buildings | Các mục xây thường xám kèm lý do "Đã đủ 3 công trình trên mặt đất". Chỉ bán (SELL-03) hoặc dọn đổ nát (CLR-02) mới trả lại chỗ (ground_used giảm 1); ô RUINED chưa dọn vẫn chiếm chỗ. Kiểm tra trần lại ngay lúc xác nhận, nguyên tử như BLD-02 (GRID-04) |
| BLD-09 | Xây Trạm hồi lực khi đã đủ heal_tower_max_count | Mục xây xám kèm lý do "Tối đa 2 Trạm hồi lực". Đếm cả ô OCCUPIED và RUINED (HLT-02). Kiểm tra lại ngay lúc xác nhận, nguyên tử như BLD-02 |
| BLD-10 \[MVP] | Xây trên ô grid làm mất đường đi | Từ chối với lý do BLOCKS_PATH theo GRID-07, không trừ gold. Ghost preview hiện màu cấm kèm tooltip "Sẽ chặn kín đường đi". Kiểm tra lại ngay lúc xác nhận, nguyên tử như BLD-02 |
| BLD-11 \[MVP] | Xây trong lúc tutorial chưa xong (tutorial_done = false) | Chỉ hai slot mặc định sáng; slot starter_arrow_slot chỉ cho Arrow, slot starter_cannon_slot chỉ cho Cannon, giá 0 gold, invested_gold = 0 và is_starter = true như trụ có sẵn (SELL-06). Mọi slot khác khóa kèm lý do "Làm theo hướng dẫn" cho tới khi xây xong cả hai (TUT-15) |

| **ID** | **Nâng cấp** |
| --- | --- |
| UPG-01 | Tốn gold theo bảng cấp kế (cost của cấp n + 1 trong TowerData), tức thì, mỗi lần một cấp, và phải đủ điều kiện Cấp Chỉ huy khi qua ranh giới bậc (UPG-06) |
| UPG-02 | Giữ target_priority, HP hồi đầy theo max_hp mới. Ngoại lệ: Trạm hồi lực chỉ cộng phần max_hp tăng thêm vào kho, không hồi đầy (HLT-08) |
| UPG-03 | Cấp tower_max_level (36): hiện "MAX" |
| UPG-04 | Không nâng được tower RUINED |
| UPG-05 | Không đủ gold: như BLD-01 |
| UPG-06 \[MVP] | Nâng lên cấp tower_tier2_level (13) yêu cầu commander_level ≥ tower_gate_tier2 (4), lên cấp tower_tier3_level (25) yêu cầu ≥ tower_gate_tier3 (8) (FRT-03). Các cấp khác không cần điều kiện. Không đủ: nút xám kèm "Cần Chỉ huy cấp N". Kiểm tra lại lúc xác nhận như BLD-02 |

| **ID** | **Bán** |
| --- | --- |
| SELL-01 | Hoàn sell_refund_pct 60% tổng gold đã đầu tư (invested_gold: xây cộng các lần nâng), làm tròn xuống |
| SELL-02 | Chỉ PREP. MVP: xác nhận ở mọi cấp bằng hộp thoại chung (SCR-14). Hộp thoại giao dịch tuân theo SCR-14 về tự đóng và kiểm tra lại state lúc xác nhận. \[Should] Khi đã làm hoàn tác 3 s thời gian thực (PNL-10) thì bán cấp 1 không cần xác nhận |
| SELL-03 | Slot về EMPTY, priority reset mặc định, không giữ ruined_type và ruined_level. Bán công trình trên ô grid trả lại 1 chỗ: ground_used giảm 1, trần max_ground_buildings vẫn là 3 (GRID-04). Slot RUINED không bán được, muốn bỏ thì dùng Dọn đổ nát (CLR-01) |
| SELL-04 | Công trình đặt sẵn (trụ có sẵn và \[Should] StartPack): giá trị đầu tư của cấp đặt sẵn là 0, cộng giá các lần nâng sau đó; bán hoàn 60% phần đó |
| SELL-05 | Bán Trạm hồi lực hoàn sell_refund_pct × invested_gold × (hp / max_hp của cấp hiện tại), làm tròn xuống. Kho đã hút bớt thì hoàn ít hơn, để không có cách "mua, hút máu, bán lại" kiếm lời (HLT-08). Trạm RUINED không bán được, chỉ dọn (CLR-01) |
| SELL-06 \[MVP] | **Trụ có sẵn.** Arrow và Cannon có sẵn đầu run (mục 3.2.1) và hai trụ xây theo tutorial (BLD-11) có is_starter = true: không bán được cho tới PREP của wave starter_sell_unlock_wave (3); trước đó nút Bán xám kèm "Bán được từ wave 3". Từ PREP wave 3 bán theo SELL-01 và SELL-04: đầu tư cấp 1 tính là 0, nên chỉ hoàn 60% số gold đã bỏ ra nâng cấp. Trụ có sẵn bị phá rồi xây lại là tower thường (TWR-13), is_starter = false, bán được ngay |

**Dọn đổ nát \[MVP]:** chọn slot RUINED, panel Build (PNL-01) có nút "Dọn đổ nát" ở cuối menu. Bấm là slot về EMPTY ngay.

| **ID** | **Dọn đổ nát** |
| --- | --- |
| CLR-01 | Chỉ ở PREP (kể cả PREP boss và lúc Pause như BLD-04), trên slot RUINED (slot WALL hoặc ô grid). Slot về EMPTY: bỏ đống đổ nát, collision và NavigationObstacle3D, xóa ruined_type và ruined_level nên mất mục "Xây lại" (BLD-07) |
| CLR-02 | Miễn phí, không hoàn gold. Không cần hộp thoại xác nhận vì không mất gold: xây lại chỉ là tiện ích, tổng gold bằng xây cấp 1 rồi nâng (BLD-07). Dọn trên ô grid trả lại 1 chỗ: ground_used giảm 1, trần max_ground_buildings vẫn là 3 (GRID-04) |
| CLR-03 | Nguyên tử như BLD-02, khóa slot khi đang xử lý như BLD-03. Kiểm tra lại state PREP và slot vẫn RUINED ngay lúc bấm |
| CLR-04 | Phát slot_changed (EVB-13) với slot_state EMPTY. RunState xóa ruined_type, ruined_level của slot đó |

### 3.6.5 Hành vi tower trong chiến đấu

Mỗi tower quét theo scan_interval 0.2 s. Chọn mục tiêu theo target_priority, giữ mục tiêu đến khi mục tiêu chết, ra khỏi tầm, hoặc retarget_delay 0.3 s sau khi đổi priority.

**Mục tiêu hợp lệ:** quân sống, trong tầm, tower có khả năng đánh (Cannon bỏ qua mục tiêu bay), resist(damage_type) > 0 (DMG-02), không trong spawn_grace (EN-04).

Sát thương tower gây ra = base × dealt_mult, với dealt_mult = 1 + (aura_active ? frontline_aura_dmg_bonus : 0) + các khoản khác (DMG-06, FRT-01).

| **Priority** | **Cách chọn** |
| --- | --- |
| **First** | Quân có nav_progress lớn nhất (gần Fortress nhất dọc tim hành lang, áp dụng chung cho quân đi bộ và quân bay). nav_progress định nghĩa ở TWR-16, do từng quân tự cập nhật mỗi path_update_interval 0.3 s, tower chỉ đọc giá trị đã lưu. Mặc định Arrow |
| **Nearest** | Quân gần tower nhất theo khoảng cách thẳng. Mặc định Cannon |
| **Highest HP** \[Should] | HP hiện tại cao nhất |
| **Lowest HP** \[Should] | HP hiện tại thấp nhất |

| **ID** | **Targeting** | **Xử lý** |
| --- | --- | --- |
| TGT-01 | Nhiều mục tiêu cùng giá trị | Tie-break: gần tower hơn, rồi entity_id nhỏ hơn |
| TGT-02 | Không có mục tiêu hợp lệ | Idle |
| TGT-03 | Đổi priority khi đang chờ bắn | Áp dụng sau retarget_delay |
| TGT-04 | Boss miễn nhiễm loại sát thương của tower | Bỏ khỏi danh sách hợp lệ (DMG-02), hiện biểu tượng miễn nhiễm. Chỉ còn boss thì Idle |
| TGT-05 | Cannon với mục tiêu trong min_range | Bỏ qua mục tiêu đó |
| TGT-06 | Chỉ huy Battle Cry | Tower không bị ảnh hưởng |
| TGT-07 | Line-of-sight của tower | MVP không cần line-of-sight: tower chỉ xét tầm bắn và các điều kiện hợp lệ ở trên. Đạn Arrow và Cannon không va chạm Barricade, tường, Fortress hay tower khác trên đường bay, chỉ trúng quân địch (PRJ-01, PRJ-02) |

| **ID** | **Projectile** |
| --- | --- |
| PRJ-01 | **Arrow:** đạn 30 m/s, tự dẫn. Mục tiêu chết khi đạn đang bay thì đạn bay tiếp đến vị trí cuối, chỉ trúng nếu có quân chạm trên đường. Không đổi mục tiêu giữa chừng |
| PRJ-02 | **Cannon:** đạn đường vòng, bắn về vị trí dự đoán. Nổ giảm dần theo khoảng cách (100% tâm, 50% mép) |
| PRJ-03 | Nổ Cannon không friendly fire với chỉ huy và tower |
| PRJ-04 | Object pool, max_projectiles 200. Vượt thì tower chờ lượt kế (không mất lượt) |
| PRJ-05 | Chạy theo game time, đúng ở x1/x2/x3 |
| PRJ-06 | Hủy mọi projectile khi hết SUMMARY hoặc kết thúc Run |
| PRJ-07 | Buff (\[Should] BUFF_FURY, meta, modifier) tính lúc trúng đích |
| PRJ-08 | Nổ Cannon (BLAST, bán kính theo cấp trong bảng cân bằng) không gây knockback và không gây STAGGER lên quân địch ở MVP. Lý do: STAGGER ngắt đòn 0.4 s rồi miễn knockback 2 s (AI-04); nếu mỗi viên đạn diện rộng đều gây hiệu ứng này, cả cụm quân đang đánh Barricade bị gián đoạn đồng loạt, nhả slot (CRD-03) và tăng ca kẹt (NAV-03). Nguồn knockback lên quân thường ở MVP chỉ gồm đòn 3 của chỉ huy (combo_hit3_knockback) và shockwave khi Deploy (mục 3.5.5, deploy_shockwave_*). Stomp của Bulwark chỉ knockback chỉ huy (BOSS-07). \[Could] Knockback nhẹ cho Cannon bậc 3 nếu playtest cần |

| **ID** | **Barricade** | **Đặc tả** |
| --- | --- | --- |
| TWR-05 | Thu hút | Nhiều Barricade: chọn cái có distance / aggro_weight nhỏ nhất |
| TWR-06 | Giới hạn | Tối đa max_attackers_per_barricade 5, dư chuyển mục tiêu hoặc chờ |
| TWR-07 | Bị phá | Quân đang nhắm chọn lại theo bảng ưu tiên, không đứng khựng |
| TWR-08 | \[ĐÃ XÓA v1.8] | Không còn Overload phá tower |
| TWR-09 | \[ĐÃ XÓA v1.8] | |
| TWR-10 | Bán trước boss | Bán trước boss vẫn hợp lệ ở PREP, hoàn 60% |
| TWR-11 | Tower phá đúng frame wave hết quân | Wave vẫn kết thúc, RUINED sang PREP |
| TWR-12 | Abandon | RunState bị hủy, không ảnh hưởng |
| TWR-13 | Công trình đặt sẵn (trụ có sẵn, \[Should] StartPack) bị phá | Xây lại theo SLOT-08: giữ cấp đã có, giá bằng tổng cost từ cấp 1 đến cấp đó (ví dụ trụ Arrow có sẵn còn cấp 1: 50 gold). Công trình xây lại là tower thường: giá trị đầu tư bằng số gold đã trả, hoàn bán 60% (SELL-01), is_starter = false nên không bị khóa bán (SELL-06), không còn đánh dấu miễn phí (SELL-04 chỉ áp cho bản đặt sẵn). Slot vẫn RUINED thì trụ có sẵn không tự đặt lại |
| TWR-14 | Arrow bắn trên không | Chỉ kiểm chứng được khi có Bat \[Should] |
| TWR-15 | Tua x3 với 6 tower (3 WALL + 3 trên grid) | Quét theo scan_interval game time, các tower lệch pha theo slot_id, ứng viên lấy bằng area query. Không tính đường theo tower. FPS tụt thì hạ time scale trước (TIME-06). Dự phòng: nếu level chưa có lane_curve thì dùng hình chiếu x dọc hành lang (cùng công thức TWR-16 với đường thẳng) |
| TWR-16 | nav_progress thống nhất cho quân đi bộ và quân bay | nav_remaining = chiều dài lane_curve trừ lane_curve.get_closest_offset(vị trí quân), tức số mét còn lại tới cổng Fortress. nav_progress = lane_ref_length - nav_remaining (mét), lane_ref_length là chiều dài lane dài nhất của level, nên mọi lane so sánh trực tiếp theo quãng còn lại tới thành. lane_curve là Curve3D tim hành lang từ spawn_zone đến cổng Fortress, một đường ở MVP (SPN-01; khi đó nav_progress chạy từ 0 tại spawn đến lane_ref_length tại cổng), do Level sở hữu. Mọi quân dùng cùng công thức: quân đi bộ chỉ lấy hình chiếu, không dùng quãng navmesh còn lại, nên đi vòng Barricade không làm lệch thứ tự với quân bay; quân bay (Bat) tính theo hình chiếu vị trí bay xuống mặt phẳng ngang. Cập nhật mỗi path_update_interval 0.3 s (lệch pha), tower chỉ đọc. Hòa nav_progress: TGT-01. \[Should] Nhiều điểm spawn: mỗi điểm một lane_curve nối vào đoạn cuối chung, nav_remaining tính trên lane của chính quân đó |

### 3.6.6 Trạm hồi lực (heal tower)

Trạm hồi lực là tower thứ tư, không tấn công. Chỉ huy ở Frontline đứng cạnh trạm để hồi máu ngay trong lúc chiến đấu, đổi HP của trạm lấy HP của chỉ huy. HP của trạm là kho dùng một lần: không tự hồi, cạn kho hoặc bị quân phá thì thành RUINED. Mục tiêu thiết kế: đây là nguồn hồi máu trong wave duy nhất ngoài Lifesteal, và nó buộc người chơi ra tiền tuyến (mục 2.8). Từ v2.0 trạm có cấp 1-36 như tower khác: giá và kho HP theo cấp nằm trong bảng cân bằng; tốc độ hồi, drain và tầm không đổi theo cấp.

| **Tham số** | **Giá trị khởi điểm** | **Ghi chú** |
| --- | --- | --- |
| heal_tower_cost | 80 gold (cấp 1) | Giá xây cấp 1. Các cấp sau và giá xây lại theo bảng cân bằng (BLD-07) |
| heal_tower_hp | 300 (cấp 1) | Kho tối đa của cấp 1. Kho tối đa từng cấp theo bảng cân bằng; skill và meta không đổi được |
| heal_range | 3 m | Từ tâm ô tới chân chỉ huy |
| heal_drain_rate | 20 HP/s | Tốc độ trạm mất HP khi hồi ở mức đầy, cố định |
| heal_rate_base | 10 HP/s | Tốc độ hồi cho chỉ huy khi chưa có skill SKL-26 |
| k (suy ra) | heal_rate / heal_drain_rate | 0.5 khi chưa có skill. Không phải tham số riêng |
| heal_hold_time | 1.0 s | Game time, thuộc CharacterStats (mục 6.4) |
| heal_tower_max_count | 2 | GameConfig. Đếm cả ô OCCUPIED và RUINED |
| heal_tower_dmg_norm_exp | 0.5 | Hệ số e của HLT-09 |

Skill Trạm hồi lực (SKL-26) chỉ nâng tốc độ hồi cho chỉ huy. Vì heal_drain_rate cố định nên nâng tốc độ hồi chính là nâng k:

| **Level skill** | **Tốc độ hồi** | **k** | **Một kho 300 HP (cấp 1) đổi được** |
| --- | --- | --- | --- |
| 0 (chưa có) | 10 HP/s | 0.5 | 150 HP chỉ huy |
| 1 | 15 HP/s | 0.75 | 225 HP |
| 2 | 20 HP/s | 1.0 | 300 HP |
| 3 | 25 HP/s | 1.25 | 375 HP |

Lượng hồi thực tế bị kẹp ở commander_max_hp (khoảng 100 cộng 10 mỗi cấp CMD_HP), nên phần kho dư không phải lúc nào cũng dùng hết.

| **ID** | **Luật** | **Tag** |
| --- | --- | --- |
| HLT-01 | **Loại và vị trí.** Trạm hồi lực có cấp 1 đến tower_max_level (36) như tower khác, chịu cổng bậc theo Cấp Chỉ huy (FRT-03) và đổi model theo bậc (TWR-17). Không tấn công, không có target_priority, không nhận Aura (FRT-01). Chỉ đặt trên ô grid (zone GROUND), không đặt trên slot WALL (BLD-06). Chiếm 1 trong max_ground_buildings ô (GRID-04). Cấp 36 hiện "MAX" (UPG-03) | MVP |
| HLT-02 | **Giới hạn số lượng.** Tối đa heal_tower_max_count (2) Trạm hồi lực cùng lúc, đếm cả ô OCCUPIED và RUINED để không né giới hạn bằng cách để trạm bị phá. Bán hoặc dọn đổ nát trả lại 1 chỗ. Xây lại trên ô RUINED (BLD-07) không tăng số đếm. Xây loại khác đè lên ô RUINED của trạm cũng trả lại 1 chỗ. Vượt giới hạn: BLD-09 | MVP |
| HLT-03 | **Phím E và hold.** Action heal_channel. Giữ E liên tục heal_hold_time (1.0 s game time) để được phép hồi. Hold chỉ là cổng điều kiện, chưa hồi gì trong lúc hold. Điều kiện để hold tăng, phải thỏa đủ: chỉ huy ở Frontline và state Idle (đứng yên); wave đang ở COMBAT hoặc BOSS_COMBAT (không dùng ở PREP, HAZARD_TRIAL, BOSS_INTRO, SUMMARY); chân chỉ huy cách tâm một Trạm hồi lực có HP > 0 không quá heal_range; commander_hp < commander_max_hp; game không Pause. Thiếu điều kiện thì hold không tăng và HUD báo đúng lý do (HUD-05, HUD-18). Hold đo bằng game time (TIME-10 loại a): ở x3 hold đủ sau 0.33 s thực, đúng chủ đích | MVP |
| HLT-04 | **Hành động hủy** (dùng chung cho hold và Healing): (1) di chuyển, (2) Dodge, (3) đánh thường, (4) skill chủ động hoặc Battle Cry, (5) bấm Tab, (6) nhận sát thương từ bất kỳ nguồn nào kể cả AoE và đạn, (7) bị knockback hoặc Stun, (8) rời heal_range của trạm đang hút, (9) Pause hoặc mất focus (INP-07, INP-08 xóa input đang giữ), (10) chỉ huy chết. Hủy lúc hold: heal_hold về 0. Hủy lúc Healing: HP đã hồi giữ nguyên. Sau khi bị hủy phải nhả E rồi giữ lại, không tự hold lại. Cùng frame có cả điều kiện đủ hold và một hành động hủy thì hủy thắng | MVP |
| HLT-05 | **Healing.** Hold đủ thì vào state Healing và hồi liên tục theo HLT-06. Nhả E trong lúc Healing không dừng hồi. Healing kết thúc khi: có hành động hủy (HLT-04); commander_hp đạt commander_max_hp (tự dừng, chỉ huy vẫn đứng yên ở Idle); trạm đang hút hết kho (HLT-07), khi đó phải hold lại để hút từ trạm kế, kể cả khi còn trạm khác trong tầm | MVP |
| HLT-06 | **Công thức hồi.** heal_rate = heal_rate_base + 5 × level skill SKL-26 (đọc qua StatBlock): 10, 15, 20, 25 HP/s. k = heal_rate / heal_drain_rate. Mỗi physics tick (game time, dt): heal = min(heal_rate × dt, commander_max_hp − commander_hp, hp_trạm × k); hp_trạm −= heal / k; commander_hp += heal (float, mục 1.4). Chỉ trừ HP trạm đúng bằng phần chỉ huy dùng được, nên khi gần đầy máu không bị hao thừa. Trạm nguồn là trạm trong heal_range gần chỉ huy nhất (hòa: slot_id nhỏ hơn), chốt lúc bắt đầu hold và giữ đến hết Healing. Kết quả giống nhau ở x1, x2, x3 | MVP |
| HLT-07 | **Hết máu là bể trụ.** HP trạm về 0, do quân phá hoặc do bị hút cạn, thì trạm thành RUINED theo TWR-02 (ghi ruined_type = heal_station, ruined_level = cấp lúc bị phá, SLOT-08), kênh đang hút kết thúc, không rơi thưởng. Bị hút cạn: toast ALR-17. Bị quân phá: gộp vào ALR-07. Xây lại ở PREP giữ cấp theo BLD-07 (giá bằng tổng cost cấp 1 đến cấp đó), kho đầy theo max_hp của cấp đó | MVP |
| HLT-08 | **Không tự hồi, là vật tiêu hao.** HP trạm không bao giờ tự hồi: TWR-01 không áp dụng (không hồi đầy ở đầu PREP), không hồi trong COMBAT, không sửa bằng Mithril, Emergency repair không áp dụng, skill và meta không tăng HP tối đa hay tốc độ nạp kho. Nâng cấp là ngoại lệ của UPG-02: hp += max_hp(cấp mới) − max_hp(cấp cũ), không hồi đầy, để nâng cấp không thành cách nạp lại kho. HP còn lại giữ nguyên qua các wave. Cách duy nhất có kho đầy là xây lại sau khi RUINED. Bán theo SELL-05. Không dùng Trạm hồi lực ở PREP (HLT-03) để khỏi phí kho | MVP |
| HLT-09 | **Chuẩn hóa sát thương nhận.** Mọi sát thương của quân địch và boss (kể cả AoE) lên Trạm hồi lực = ceil(raw ÷ dmg_mult(w)^e), e = heal_tower_dmg_norm_exp (0.5), w = wave_index hiện tại, tối thiểu 1, áp lúc trúng đích (PRJ-07). raw đã gồm dmg_mult(w) (SCL-05), nên ở wave 10 (dmg_mult 1.70) trạm chịu khoảng 77% sát thương thô, ở wave 20 (2.86) khoảng 59%. Hút máu (HLT-06) không phải sát thương nên không bị chuẩn hóa. Mục đích: chống "tower giấy" ở wave cao khi HP trạm không tự hồi | MVP |
| HLT-10 | **Mục tiêu của quân.** Trạm hồi lực là TOWER_GROUND: bị Grunt (ưu tiên 3), Archer, Bulwark (ưu tiên 3 trong 8 m phía trước) và AoE nhắm theo bảng ETG như mọi tower trên ô grid, chiếm slot đánh theo max_attackers_per_tower (3). Barricade vẫn thu hút Grunt trước. Không có luật nhắm riêng | MVP |
| HLT-11 | **Hiển thị.** Khi chỉ huy Frontline trong tầm hoặc giữ Shift: vòng heal_range quanh trạm. Thanh kho HP (có số) hiện khi trạm bị thương hoặc đang hồi. Dưới 20% kho: đổi hình dạng thanh (viền gạch, biểu tượng) và toast ALR-18. Lúc hold: vòng tiến trình quanh chân chỉ huy kèm số giây. Lúc Healing: tia sáng từ trạm sang chỉ huy và số nổi xanh lục (FBK-12, FBK-01). Mọi trạng thái có biểu tượng hoặc chữ ngoài màu (UI-05), giảm nhấp nháy theo ACC-06 | MVP |
| HLT-12 | **Mở thêm giới hạn.** Khi commander_level ≥ heal_tower_limit_lv (6), heal_tower_max_count tăng thêm 1 (tối đa 3), như cổng cấp của FRT-03. Cấp Chỉ huy không giảm nên giới hạn không giảm trong run | SHOULD |
| HLT-13 | **Tương tác khác.** Commander mode không dùng được (HLT-03). Recall và đổi chế độ bằng Tab hủy hồi (HLT-04). Hazard Trial không có trạm nên không hồi được trong phòng. Dọn đổ nát như tower thường (CLR). BOSS_INTRO khóa input nên không dùng được (BOSS-18) | MVP |

| **ID** | **Tình huống** | **Xử lý** |
| --- | --- | --- |
| HLT-14 | Hai trạm cùng trong tầm | Hút trạm gần nhất. Hết kho thì kênh kết thúc, hold lại để hút trạm còn lại (HLT-05) |
| HLT-15 | Trạm bị phá đúng lúc đang hút | RUINED, kênh kết thúc, phần HP đã hồi giữ nguyên (HLT-07) |
| HLT-16 | Hold đủ đúng frame wave sang SUMMARY | Hủy, vì không còn COMBAT (HLT-03) |
| HLT-17 | Bị sát thương đúng frame hold đủ | Hủy thắng, không vào Healing (HLT-04) |
| HLT-18 | Lifesteal hồi đầy máu giữa lúc Healing | Tự dừng, không hút thêm từ tick đó (HLT-05, HLT-06) |
| HLT-19 | Vừa Deploy xuống sát trạm | Deploying bất tử nhưng không hold được. Hold bắt đầu sau khi về Idle (HLT-03) |

## 3.7 Kẻ địch, Spawner và Scale

### 3.7.1 Dữ liệu (EnemyData)

Trường: base_hp, base_damage, attack_interval, attack_range, move_speed, spawn_cost, is_flying, is_ranged, knockback_immune, aggro_range, target_rules, gold_reward, prestige_reward, xp_value (XP-01), resist_table (tùy chọn, mặc định kháng 1.0 mọi loại, dùng cho FRT-05 \[Should]), damage_type. Từ v2.0 thêm các trường đặc tính (trait) cho quân mới, mỗi trường có giá trị mặc định "tắt": is_stealth và stealth_opacity (EN-20), explode_on_contact, explode_on_death, explode_radius, explode_damage, explode_windup (EN-22, EN-23), invuln_hp_threshold và invuln_duration (EN-24), is_charger, impact_damage, impact_knockback (EN-25), revive_count, revive_delay, revive_dmg_mult (EN-26). Bỏ avoid_radius và avoid_priority vì quân không va chạm nhau (EN-16). Code xử lý theo trait khai báo trong dữ liệu, không rẽ nhánh theo tên loại quân. Chỉ số và trait của mọi loại sinh từ sheet quân của bảng cân bằng (mục 6.10).

**Chỉ số gốc ở wave 1 (khởi điểm của 3 loại gốc, giữ từ v1.9; giá trị chuẩn nằm trong bảng cân bằng):**

| **Loại** | **HP** | **Damage** | **Nhịp** | **Tầm** | **Tốc độ** | **Cost** | **aggro\_range** | **Phạm vi** |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Grunt | 40 | 6 | 1.0 s | 1.5 m | 3.5 m/s | 1 | 10 m | MVP |
| Archer | 30 | 8 | 1.5 s | 11 m | 3.0 m/s | 2 | bằng tầm | MVP |
| Brute | 250 | 25 | 2.0 s | 2.0 m | 2.0 m/s | 6 | 4 m | MVP |
| Bat (bay) | 20 | 5 | 0.8 s | 1.2 m | 5.0 m/s | 2 | không dùng | Should |
| Healer | 40 | 4 | 2.0 s | 9 m | 2.8 m/s | 4 | không dùng | Should |
| Debuffer | 35 | 5 | 2.0 s | 9 m | 2.8 m/s | 3 | bằng tầm | Should |
| Shaman | 45 | 5 | 2.0 s | 8 m | 2.8 m/s | 4 | không dùng | Could |

damage_type: Archer là PIERCE, các loại còn lại là SLASH. Brute miễn knockback và stun.

**Quân mới v2.0 \[MVP]** (chỉ số cụ thể như HP, sát thương, tầm, tốc độ, cost, gold, uy tín, XP, bán kính nổ đặt trong bảng cân bằng; luật ở mục 3.7.8):

| **Loại** | **Ngoại hình** | **Đặc điểm** | **damage_type** |
| --- | --- | --- | --- |
| Sniper | Như skeleton, mắt phát sáng, cung to | Tầm xa, bắn cực xa (EN-19) | PIERCE |
| Assassin | Như Brute, áo choàng, dao găm, máu giấy, độ mờ (opacity) 0.5 | Tàng hình với tower, hero vẫn thấy mờ và đánh được (EN-20) | SLASH |
| Rider | Cưỡi ngựa | Chạy nhanh, đánh cận chiến như thường (EN-21) | SLASH |
| Suicide Squad | Như Archer, cõng bom | Lao vào mục tiêu rồi tự nổ (EN-22) | BLAST |
| Suicide Squad Captain | Như Suicide Squad, cầm thêm kiếm | Đánh tay được, tự nổ khi hết máu (EN-23) | SLASH (đòn kiếm), BLAST (vụ nổ) |
| Knight | Full giáp | Bất tử 5 giây khi máu dưới 50%, một lần (EN-24) | SLASH |
| Undead | Xương cầm lưỡi hái | Hồi sinh một lần, sau đó tăng sát thương. Không tự nổ (EN-26) | SLASH |
| Brute (sửa) | Như hiện tại | Ủi thẳng từ spawn tới Fortress; va tower gây sát thương lớn lên tower, va hero hất hero văng ra (EN-25) | SLASH |

xp_value (XP-01): Grunt 1, Archer 2, Brute 5, boss 30; 7 loại mới theo bảng cân bằng; \[Should] Bat 2; Healer, Debuffer, Shaman đặt 3 khi làm (tạm thời, chỉnh trong EnemyData).

### 3.7.2 State machine

SPAWN -> ADVANCE <-> CHASE -> ATTACK -> (ADVANCE | CHASE)\
ADVANCE/CHASE -> WAIT (không có slot đánh) -> CHASE\
Any -> STAGGER -> (trạng thái trước)\
Any -> FRENZY (WAVE-05)\
Any -> DEAD

| **State** | **Hành vi** | **Chuyển khi** |
| --- | --- | --- |
| SPAWN | Ra khỏi spawn_zone, chưa bị nhắm | Ra khỏi vùng |
| ADVANCE | Đi dọc đường về Fortress, tìm mục tiêu | Có mục tiêu hợp lệ |
| CHASE | Tới mục tiêu (melee: attack_slot, tầm xa: tới khi trong tầm) | Đến nơi thì ATTACK |
| ATTACK | Wind-up 0.4 s, sát thương ở khung active, recovery | Mục tiêu chết hoặc mất hợp lệ |
| WAIT | Đứng vòng chờ vì hết slot | Có slot hoặc chọn mục tiêu khác |
| STAGGER | Knockback, bị gián đoạn 0.4 s | Hết thời gian, sau đó **miễn knockback 2 s** |
| FRENZY | Tốc độ x1.5, đi thẳng Fortress | Chỉ kết thúc khi chết |
| DEAD | Animation, hiển thị thưởng, giải phóng slot |  |

| **ID** | **Luật đòn đánh** |
| --- | --- |
| AI-01 | Sát thương cận chiến áp dụng ở khung active. Mục tiêu không còn hợp lệ hoặc ngoài tầm thì đòn hụt |
| AI-02 | Đạn Archer cong, bay tới vị trí mục tiêu lúc bắn, 20 m/s, không tự dẫn, Dodge né được, không bị Barricade chắn |
| AI-03 | Không friendly fire giữa quân địch (kể cả Brute và AoE boss) |
| AI-04 | Knockback ngắt wind-up, sau đó miễn knockback 2 s |
| AI-05 | Combo 3 của chỉ huy và Cannon không stun. Không có khống chế lên kẻ địch ở MVP |
| AI-06 | Boss miễn taunt, knockback, hồi máu, buff từ Healer và Shaman |

### 3.7.3 Chọn mục tiêu

Mỗi target_rules là danh sách có thứ tự, chọn mục tiêu đầu tiên hợp lệ. category: PLAYER, BARRICADE, TOWER_GROUND (tower trên ô grid, trừ Barricade; gồm Trạm hồi lực, HLT-10), TOWER_WALL, FORTRESS, ALLY_MELEE_LOW_HP, ALLY_RANGED.

**ETG-01, bộ lọc hợp lệ:**

| **Điều kiện** | **Loại bỏ** |
| --- | --- |
| Chỉ huy ở Commander | Không có gì nhắm được chỉ huy khi ở Commander |
| Mục tiêu ở WALL | Melee mặt đất không nhắm được. Archer, Bat, Barrage thì được |
| Mục tiêu phía sau quân (xa Fortress hơn hoặc đã đi qua) | Loại, trừ chỉ huy đang khiêu khích |
| Mục tiêu hết slot đánh (melee) | Tạm loại, xử lý ở WAIT |
| RUINED hoặc đã chết | Loại |

| **Loại** | **Thứ tự ưu tiên** | **Ghi chú** |
| --- | --- | --- |
| **Grunt** | 1. PLAYER nếu bị khiêu khích và trong aggro_range. 2. BARRICADE theo nav_distance / aggro_weight. 3. TOWER_GROUND gần nhất theo nav. 4. FORTRESS | Barricade là vật cản để quân đuổi theo |
| **Archer** | Trong tầm: 1. Tower (TOWER_GROUND hoặc TOWER_WALL). 2. PLAYER (chỉ Frontline). 3. BARRICADE. 4. FORTRESS. Gần nhất, hòa thì entity_id nhỏ | Tiến đến khi có mục tiêu trong tầm rồi dừng bắn (hold), không kiting |
| **Brute** (sửa ở v2.0) | FORTRESS cố định. Không đổi mục tiêu vì khiêu khích hay Battle Cry | Ủi thẳng về thành, va công trình và chỉ huy trên đường (EN-25) |
| **Sniper** | Như Archer, với tầm của Sniper | Dừng bắn khi có mục tiêu trong tầm (EN-19) |
| **Assassin**, **Rider**, **Knight**, **Undead** | Như Grunt | Assassin không bị tower nhắm (EN-20) |
| **Suicide Squad**, **Suicide Squad Captain** | Như Grunt | Suicide Squad nổ khi tới tầm mục tiêu (EN-22); Captain đánh thường rồi nổ khi chết (EN-23) |
| **Bat** \[Should] | 1. Tower gần nhất, ưu tiên Arrow. 2. FORTRESS | Bay qua Barricade, không nhắm chỉ huy |
| **Healer** \[Should] | 1. ALLY_MELEE_LOW_HP (HP dưới 70%, trong 8 m). 2. ALLY_RANGED bị thương. 3. Như Archer | Skill hồi thì đánh yếu như Archer |
| **Debuffer** \[Should] | 1. Tower (giảm tốc bắn 30%, 5 s). 2. PLAYER (Slow hoặc Weaken) | Không cộng dồn |
| **Shaman** \[Could] | Buff +25% damage 6 s: ALLY_RANGED rồi ALLY_MELEE. Không buff lại khi còn hiệu lực |  |

| **ID** | **Chọn lại mục tiêu** |
| --- | --- |
| ETG-02 | Quét mỗi retarget_interval 0.4 s, lệch pha theo entity_id |
| ETG-03 | Chọn lại ngay khi: mục tiêu chết hoặc RUINED, chỉ huy đánh trúng, Battle Cry, Recall thành công, mất slot. Khi nhiều quân cùng mất mục tiêu, "ngay" nghĩa là theo lô (ETG-08) |
| ETG-04 | Đang ATTACK thì hoàn tất đòn rồi mới chọn lại, trừ khi mục tiêu chết |
| ETG-05 | Hết aggro_duration hoặc vượt leash_distance: về bảng gốc |
| ETG-06 | Không có mục tiêu hợp lệ: mặc định FORTRESS |
| ETG-07 | Tie-break: khoảng cách nav nhỏ hơn, rồi entity_id nhỏ hơn |
| ETG-08 \[Should] | Retarget hàng loạt (khi nhiều Barricade bị phá cùng lúc, TWR-07, EN-07): không retarget đồng bộ trong một frame. Quân mất mục tiêu đặt cờ needs_retarget, xử lý theo thứ tự entity_id tăng dần, tối đa retarget_batch_size (8) quân mỗi physics frame, tức ETG-03 "chọn lại ngay" được hiểu là trong tối đa ceil(N / 8) frame (70 quân: 9 frame, khoảng 0.15 s ở 60 FPS). Quân chưa tới lượt đứng chờ (WAIT, không tính kẹt, NAV-02) tối đa vài frame; đòn đang wind-up vào mục tiêu RUINED bị hụt (AI-01). Phòng giật khung hình khi 15 đến 20 quân cùng gọi lại đường đi. (Tên cũ OVL-07 ở v1.7) |

### 3.7.4 Di chuyển, slot đánh, đám đông

NavigationAgent3D, cập nhật đường mỗi path_update_interval 0.3 s (lệch pha). Barricade dùng NavigationObstacle3D.

| **Đối tượng** | **Số slot đánh** |
| --- | --- |
| Fortress | 12 |
| Mỗi Barricade | 5 |
| Chỉ huy | 8 |
| Tower trên ô grid không phải Barricade (kể cả Trạm hồi lực) | 3 (khởi điểm) |

| **ID** | **Đặc tả** |
| --- | --- |
| CRD-01 | Quân melee giữ chỗ slot khi còn cách mục tiêu dưới 6 m. Hết slot thì WAIT ở vòng chờ cách 3 m |
| CRD-02 | WAIT quá 3 s: chọn lại mục tiêu, loại mục tiêu đầy trong 5 s |
| CRD-03 | Giải phóng slot khi quân chết, đổi mục tiêu, bị knockback xa quá 3 m, mục tiêu RUINED |
| CRD-04 | Kiểm tra mỗi 2 s, tự giải phóng slot có chủ không hợp lệ |
| CRD-05 | Giải phóng slot chỉ huy khi Recall thành công |
| CRD-06 | \[Should] Bat không chiếm melee_slot của Fortress hay tower (các slot chỉ dành cho quân đi bộ). Bat đánh từ trên cao trong attack_range 1.2 m, tối đa bat_max_per_target (6) Bat cùng đánh một mục tiêu; Bat dư lượn vòng ngoài và chọn lại mục tiêu sau 3 s như CRD-02 |

Va chạm (v2.0): quân không va chạm với nhau (kể cả boss và Brute), theo EN-16; quân vẫn va chạm với chỉ huy (mềm, CMB-07), tower, Barricade, đống đổ nát, tường và Fortress. Slot đánh ở bảng trên vẫn giữ để quân không dồn một chỗ. Bat không va chạm mặt đất. max_alive 70. Quân ngoài camera giảm tần suất animation (LOD, \[Should]), không giảm logic tấn công.

**Thang xử lý kẹt (v1.4).** Phần MVP gồm: phát hiện kẹt (NAV-01, 02), rơi khỏi map (NAV-03, 04), tắc do chỉ huy (NAV-05), bậc 1 (NAV-06), bậc 3 recycle (NAV-08), bậc 4 cull (NAV-09), boss riêng (NAV-12), giới hạn cứng (NAV-13), log (NAV-14). Phần \[Should]: bậc 2 hop cục bộ (NAV-07), NAV-10, watchdog cấp wave (NAV-11), overlay debug và bot soak test (trong NAV-14). Khi chưa làm bậc 2, bậc 1 chuyển thẳng sang bậc 3 sau 3 s.

| **ID** | **Chống kẹt** |
| --- | --- |
| NAV-01 | **Phát hiện kẹt.** Mỗi 0.5 s tính tiến độ dọc đường đi tới mục tiêu hiện tại (quãng nav còn lại). Quân bị coi là kẹt khi tiến được dưới stuck_progress_min (0.5 m) trong stuck_detect_time (3 s) trong lúc đang ADVANCE hoặc CHASE, có mục tiêu hợp lệ và không thuộc trường hợp loại trừ (NAV-02). Đo tiến độ dọc đường đi, không đo độ dịch chuyển thô, nên quân bị đẩy qua lại tại chỗ vẫn bị phát hiện |
| NAV-02 | **Không tính là kẹt:** WAIT, ATTACK, STAGGER, spawn_grace, đang bị Recall tắc do chỉ huy (NAV-05), đang chờ hồi sinh (EN-26). Quân không va chạm nhau (EN-16) nên không còn ca bị đồng đội chặn đường. Bộ đếm bậc (NAV-06, NAV-08, NAV-09 và NAV-07 nếu có) reset sau 10 s tiến triển bình thường |
| NAV-03 | Bị knockback ra ngoài navmesh: kẹp về điểm nav gần nhất |
| NAV-04 | Rơi khỏi map: đưa về điểm nav hợp lệ gần nhất phía sau vị trí rơi. Rơi lần hai trong cùng wave: xử lý như bậc 3 (NAV-08) |
| NAV-05 | Tắc do chỉ huy trong hành lang hẹp: đi vòng, không được thì chờ 2 s (không tính vào bộ đếm NAV-01) rồi mới bắt đầu thang xử lý kẹt. GRID-07 giữ luôn còn đường đi đủ rộng cho agent lớn và chỉ huy chỉ va chạm mềm (CMB-07), nên chỉ huy không chặn kín được hành lang; NAV-05 chỉ phòng hờ cho điểm hẹp cục bộ. Level không được tạo điểm nào hẹp hơn 4 m |
| NAV-06 | **Bậc 1 (ngay khi phát hiện kẹt):** tính lại đường đi. Từ v2.0 quân không va chạm nhau nên không cần tắt va chạm đồng đội (ally_phase đã bỏ) |
| NAV-07 | **\[Should] Bậc 2 (còn kẹt sau bậc 1 thêm 3 s): hop cục bộ.** Dịch tới điểm nav hợp lệ gần nhất trong hop_radius (3 m) theo chiều tiến. Điều kiện: không vượt qua Barricade, tower hoặc tường; không tiến gần Fortress hơn hop_max_advance (4 m theo đường nav) so với vị trí cũ; không rơi vào spawn_zone; không chồng lên quân khác. Không tìm được điểm hợp lệ thì sang bậc 3. Mục đích: gỡ kẹt mà không cho quân "vượt tuyến" phòng thủ. Khi chưa làm: bậc 1 chuyển thẳng sang bậc 3 sau 3 s |
| NAV-08 | **Bậc 3 (còn kẹt sau bậc 1 thêm 3 s khi chưa có bậc 2, hoặc sau bậc 2 thêm 3 s khi đã có, hoặc kẹt lần thứ 3 trong cùng wave): recycle.** Đưa quân về điểm ngẫu nhiên trong spawn_zone, giữ nguyên HP, buff và thưởng, không hoàn ngân sách wave. Tối đa recycle_max (2) lần cho mỗi quân. Quân được đi lại từ đầu nên không mất kill hợp lệ. Quân đã FRENZY khi bị recycle giữ cờ FRENZY: vẫn tốc độ x1.5, mục tiêu cố định FORTRESS, bỏ qua taunt và slot chờ (EN-02); bộ đếm bậc kẹt vẫn reset theo NAV-02. Đồng hồ giới hạn cứng NAV-13 chạy theo lần spawn cuối của wave, không reset khi recycle; quân recycle sau giây 240 có thể không kịp tới Fortress và bị cull ở giây 300 (không thưởng, ghi log kèm cờ frenzy) |
| NAV-09 | **Bậc 4 (đã recycle đủ lần mà vẫn kẹt): cull.** Xóa quân, tính vào điều kiện kết thúc wave (enemies_alive giảm), không thưởng, không tính kill (RWD-03, tránh lợi dụng để nhận thưởng không cần diệt). Ghi log STUCK_CULL kèm loại quân, vị trí, wave, run_seed |
| NAV-10 | **\[Should] Không có tiến triển khi đang đánh:** quân ATTACK mà đòn hụt liên tiếp 3 lần (AI-01), hoặc ATTACK và WAIT quá no_damage_timeout (10 s) mà mục tiêu không mất HP: loại mục tiêu đó khỏi danh sách trong 10 s và chọn lại (như CRD-02). Vẫn không tiến triển thì xử lý từ bậc 2 (hoặc bậc 3 khi chưa có bậc 2). Khi chưa làm, ca này được FRENZY (EN-02) và giới hạn cứng (NAV-13) đỡ |
| NAV-11 | **\[Should] Watchdog cấp wave:** sau khi spawn_queue rỗng, mỗi 5 s kiểm tra tổng tiến độ nav của quân sống (trừ boss) và tổng sát thương hai bên. Không có thay đổi trong wave_stall_timeout (45 s) thì áp dụng bậc 3 (recycle) cho toàn bộ quân sống một lần. Khi chưa làm, FRENZY ở 240 s và giới hạn cứng 300 s thay thế |
| NAV-12 | Boss không bao giờ bị recycle hay cull (BOSS-04). Boss có thang xử lý kẹt riêng |
| NAV-13 | **Giới hạn cứng:** wave_hard_cap (300 s sau lần spawn cuối), mọi quân còn sống không phải boss bị cull (không thưởng) và wave kết thúc. Đảm bảo wave luôn kết thúc dù các cơ chế trên đều lỗi. Áp dụng cả với quân FRENZY |
| NAV-15 \[MVP] | **Bị chặn kín.** Nếu quân không tìm được đường tới mục tiêu hiện tại (đường navmesh không tới được, ví dụ bị vật cản và chỉ huy chắn kín ở điểm hẹp), quân chọn công trình gần nhất theo khoảng cách thẳng (TOWER_GROUND hoặc BARRICADE, không xét WALL) làm mục tiêu để phá đường, như bậc 2 của BOSS-04. Có đường lại thì về bảng ưu tiên gốc. GRID-07 làm ca này hiếm, luật chỉ là lưới an toàn |
| NAV-14 | **Log và kiểm chứng:** mỗi lần kích hoạt bậc 3-4 (và bậc 2 khi có) ghi log (loại quân, vị trí, wave, state, nav_distance, quân lân cận). stuck_cull_count xuất được ở Settings, Dữ liệu, Xuất log lỗi. **Nghiệm thu MVP:** chạy tay hoặc bằng script ít nhất 20 wave ở x3 với seed khác nhau, mọi wave kết thúc, quân bị cull dưới 0.1% tổng số quân. \[Should] Bản debug có overlay tô màu quân kẹt. Bot tự chơi 200 wave ở x3 với seed ngẫu nhiên, mọi wave kết thúc, quân bị cull dưới 0.1% |

### 3.7.5 Spawner

| **ID** | **Đặc tả** |
| --- | --- |
| SPN-01 | MVP có 1 điểm spawn ở cực phải (vùng chữ nhật rộng bằng hành lang). \[Should] 2-3 điểm, mỗi wave chọn ngẫu nhiên |
| SPN-02 | spawn_zone (12 m đầu hành lang): chỉ huy Frontline không vào được (tường vô hình đẩy mềm), tower không nhắm quân còn spawn_grace (EN-04). Skill có hướng (Sword Wave, Firebomb) cũng không gây sát thương và không bật hit_by_commander lên quân còn spawn_grace |
| SPN-03 | Vị trí sinh ngẫu nhiên theo RNG wave. Bị chiếm (overlap 1 m) thì hoãn 0.2 s và thử lại. Quá 3 s thì sinh ở vị trí cuối thử được |
| SPN-04 | Spawn dựa hoàn toàn vào spawn_queue |

**Wave 1 đến victory_wave (30): kịch bản cố định \[MVP].** Thành phần mỗi wave (loại quân, số lượng, hộ tống của wave boss) lấy từ sheet kịch bản wave của bảng cân bằng (WaveScript, mục 6.10). Spawner chỉ xếp thứ tự và chia nhóm theo bước 4, 5 bên dưới, không rút ngẫu nhiên thành phần. Danh sách vẫn sinh một lần khi vào PREP để preview và Hazard Trial dùng đúng (HZT-02).

**Từ wave 31: thuật toán sinh thành phần** (chạy một lần khi vào PREP để preview đúng, dùng RNG hash(run_seed, wave_index)):

1. Tính budget(w) và spawn_duration(w).
2. Rút tập loại của wave: tối đa wave_max_enemy_types (5) loại kể cả boss (SPN-14), rút theo weight trong các loại đủ min_wave, không trùng. Loại quân mới xuất hiện lần đầu (min_wave = w) đảm bảo intro_count (2 với Archer và Bat, 1 với Brute), trừ ngân sách trước. Từ wave 31 mọi loại đã qua min_wave nên bước intro thường không còn tác dụng.
3. Lặp: lập ứng viên trong tập loại đã rút (spawn_cost không vượt ngân sách, chưa vượt max_per_wave, thỏa trần), rút theo weight, trừ ngân sách, dừng khi hết ứng viên.
4. Chia group_count = clamp(2 + floor(w/5), 2, 6) nhóm, mỗi quân cách 0.4-0.8 s, giữa nhóm nghỉ tối thiểu 3 s, giãn thêm theo SPN-15.
5. Trong mỗi nhóm, melee sinh trước, tầm xa sau.

| **Loại** | **weight** | **min\_wave** | **max\_per\_wave** |
| --- | --- | --- | --- |
| Grunt | 10 | 1 | không |
| Archer | 4 | 3 | không (thỏa SPN-05) |
| Brute | 2 | 6 | floor(w/4) |
| Bat \[Should] | 3 | 8 | floor(w/3) |
| Healer \[Should] | 2 | 10 | 3 |
| Debuffer \[Should] | 2 | 12 | 3 |
| Shaman \[Could] | 2 | 15 | 2 |
| 7 loại mới (v2.0) | Theo bảng cân bằng | Theo bảng cân bằng | Theo bảng cân bằng |

| **ID** | **Trần** |
| --- | --- |
| SPN-05 | Archer không quá 40% số quân |
| SPN-06 | Quân hỗ trợ tổng không quá 20% |
| SPN-07 | Không sinh hỗ trợ nếu chưa có ít nhất 3 quân chiến đấu |
| SPN-08 | Wave 1-2 chỉ có Grunt (ràng buộc khi soạn kịch bản wave trong bảng cân bằng) |
| SPN-09 | Boss sinh ở giây 0 của BOSS_COMBAT, vị trí riêng trong spawn_zone |
| SPN-10 | Quân hộ tống: wave 1-30 theo kịch bản; từ wave 31 dùng 0.5 × budget(w), trải trong spawn_duration, sinh theo cùng thuật toán thành phần ở mục 3.7.5 |
| SPN-11 | Wave boss kết thúc khi spawn_queue rỗng và enemies_alive == 0 |
| SPN-12 | Wave sau boss dùng công thức thường, không bù ngân sách |
| SPN-13 \[MVP] | **Kịch bản wave 1-30.** Thành phần wave 1 đến victory_wave lấy nguyên từ WaveScript (bảng cân bằng), xác định, không phụ thuộc run_seed. Từ wave victory_wave + 1 dùng thuật toán ngẫu nhiên ở trên. Wave trong kịch bản thiếu dữ liệu thì xử lý như WAVE-08 và ghi lỗi |
| SPN-14 \[MVP] | **Tối đa 5 loại mỗi wave**, đếm cả boss là một loại (wave_max_enemy_types, GameConfig). Áp cho kịch bản (runner BAL kiểm, BAL-05) và cho thuật toán từ wave 31 (bước 2) |
| SPN-15 \[MVP] | **Lịch sinh trải đủ spawn_duration.** Áp cho mọi wave (kịch bản wave 1-30 và thuật toán từ wave 31), kể cả hộ tống của wave boss. Sau khi chia nhóm (bước 4), nếu quân cuối cùng có thời điểm sinh kế hoạch sớm hơn spawn_duration(w) game time tính từ đầu COMBAT hoặc BOSS_COMBAT thì giãn đều khoảng nghỉ giữa các nhóm để quân cuối sinh đúng ở spawn_duration(w); lịch vốn dài hơn thì giữ nguyên. WAVE-01 (max_alive) và SPN-03 (thử lại vị trí) chỉ làm lịch dài thêm. Vì wave chỉ kết thúc khi spawn_queue rỗng (mục 3.3.3, SPN-11), mỗi wave đã hoàn thành kéo dài ít nhất spawn_duration(w) game time dù người chơi hạ quân nhanh tới đâu. Wave boss: boss sinh ở giây 0 (SPN-09), hộ tống trải tới spawn_duration; kịch bản wave boss phải có ít nhất 1 hộ tống (BAL-05). Lịch chỉ có một nhóm (ví dụ wave boss có đúng một hộ tống, hoặc mọi quân cùng một nhóm) thì không có khoảng nghỉ để giãn: dời thẳng mục sinh cuối cùng tới đúng spawn_duration(w); các mục trước nó giữ thời điểm cũ |

**Modifier wave \[Should]:** rút 0 hoặc 1 từ wave 4, xác suất p = clamp(0.1 + 0.02w, 0, 0.5), không ở wave boss, hiển thị ở preview.

| **Modifier** | **Tác dụng** |
| --- | --- |
| Swift | Tốc độ quân +25% |
| Armored | Sát thương quân nhận -20% |
| Horde | Ngân sách +30%, HP quân -20% |
| Fog | Tầm bắn mọi tower -20% |

### 3.7.6 Công thức scale (endless)

Từ v2.0 công thức chỉ dùng từ wave 31 (wave victory_wave + 1), cho wave w là số thứ tự tuyệt đối, nằm trong ScaleConfig. Wave 1 đến 30 dùng hệ số hp_mult, dmg_mult, speed_mult của từng wave trong sheet kịch bản wave của bảng cân bằng (WaveScript, SPN-13); giá trị khởi điểm của bảng là chính công thức dưới đây nên sang wave 31 không bị gãy. budget(w) và spawn_duration(w) của wave 1-30 cũng thay bằng kịch bản (spawn_duration ghi trong bảng, dùng cho par_time).

| **Đại lượng** | **Công thức** |
| --- | --- |
| budget(w) | round(8 + 2.2(w-1) + 0.05(w-1)^2) |
| spawn_duration(w) | clamp(15 + 0.5(w-1), 15, 45) s |
| hp_mult(w) | 1 + 0.10(w-1) + 0.004(w-1)^2 |
| dmg_mult(w) | 1 + 0.06(w-1) + 0.002(w-1)^2 |
| speed_mult(w) | min(1.25, 1 + 0.005(w-1)) |

| **Wave** | **budget** | **spawn\_duration** | **hp\_mult** | **dmg\_mult** | **speed\_mult** |
| --- | --- | --- | --- | --- | --- |
| 1 | 8 | 15 | 1.00 | 1.00 | 1.000 |
| 5 | 18 | 17 | 1.46 | 1.27 | 1.020 |
| 10 | 32 | 19.5 | 2.22 | 1.70 | 1.045 |
| 15 | 49 | 22 | 3.18 | 2.23 | 1.070 |
| 20 | 68 | 24.5 | 4.34 | 2.86 | 1.095 |
| 30 | 114 | 29.5 | 7.26 | 4.42 | 1.145 |

| **ID** | **Đặc tả** |
| --- | --- |
| SCL-01 | Mọi hệ số trong ScaleConfig, đổi không cần sửa code |
| SCL-02 | Sau scale_soft_cap_wave 40, tốc độ tăng budget giảm còn một nửa: budget(w) = round(f(40) + budget_soft_cap_factor × (f(w) − f(40))), f là công thức budget ở bảng trên chưa làm tròn. hp_mult, dmg_mult vẫn tăng. Chủ động khiến run phải kết thúc |
| SCL-03 | par_time dùng thời lượng kế hoạch. Queue bị dồn do max_alive thì wave tự xuống Slow |
| SCL-04 | Mục tiêu cân bằng: người mới thua ở wave 8-12, người thành thạo chạm victory_wave (30) |
| SCL-06 \[MVP] | Công thức chỉ áp từ wave victory_wave + 1. Wave 1-30 đọc hệ số từ WaveScript; thiếu thì dùng công thức và ghi cảnh báo |
| SCL-05 | Hệ số áp lúc sinh quân, không đổi khi đã sống. Armored, Horde chồng lên |

### 3.7.7 Frenzy, thưởng khi chết, edge case

| **ID** | **Đặc tả** |
| --- | --- |
| EN-01 | 60 s sau lần spawn cuối: marker định vị trên HUD (HUD-10, phần quân lẻ là \[Should]) |
| EN-02 | 240 s: FRENZY. Tốc độ x1.5, mục tiêu cố định FORTRESS, bỏ qua taunt và slot chờ. Tầm xa đến tầm bắn Fortress rồi bắn. Frenzy không thay thế thang xử lý kẹt và vẫn chịu giới hạn cứng 300 s (NAV-13). Quân bị recycle trong FRENZY giữ trạng thái FRENZY (NAV-08, EN-03) |
| EN-03 | Đã FRENZY không quay lại. Cờ FRENZY thuộc về quân, không mất khi recycle (NAV-08), stagger hay đổi mục tiêu |
| EN-04 | spawn_grace: quân mới sinh (kể cả boss) bất tử, không bị nhắm, không tấn công và không dừng hold cho đến khi rời spawn_zone. Backstop: spawn_grace tự hết sau spawn_grace_max_time (10 s) dù chưa rời vùng, để không quân nào bất tử vĩnh viễn |
| RWD-01 | Thưởng hiển thị tức thì khi chết (số nổi là kill_gold theo RWD-02, tức đã gồm frontline_gold_mult nếu quân có cờ hit_by_commander (FRT-02), trước gold_pct_total và clear_mult, làm tròn gần nhất để hiển thị), ví thật cộng ở SUMMARY (GLD-02). Một lần theo cờ is_dead. wave_gold_base cộng giá trị chưa làm tròn, chỉ làm tròn một lần ở công thức gold_gain (mục 3.9.1) |
| RWD-02 | **Công thức gold chung của một quân thường** (dùng ở cả wave thật và Hazard Trial). gold_reward(w) = gold_reward_gốc × gold_mult(w), chưa gồm hệ số chỉ huy. kill_gold = gold_reward(w) × cmd_mult, với cmd_mult = frontline_gold_mult (1.25) nếu quân có cờ hit_by_commander (FRT-02), ngược lại 1.0. Hệ số chỉ huy áp đúng một lần, ở bước này; không công thức nào phía sau nhân lại. Wave 1-30: gold_mult(w) lấy từ bảng thưởng theo wave (WaveRewardTable, mục 6.10), khởi điểm bằng (1 + 0.04(w-1)). Từ wave 31: gold_mult(w) = 1 + 0.04(w-1). Boss không dùng kill_gold mà dùng boss_gold(w) (BRW-01), không nhân cmd_mult. prestige_reward cố định theo loại |
| RWD-03 | Kill do tower, chỉ huy (kiếm hoặc skill) đều tính. Quân bị cull do chống kẹt (NAV-09, NAV-13) hoặc dọn cuối run không thưởng và không tính kill. Recycle không ảnh hưởng thưởng |
| RWD-04 | Kill trong FRENZY nhận đủ thưởng |
| RWD-05 | Thưởng gốc (gold / uy tín): Grunt 4/1, Archer 7/2, Brute 20/5, Bat 6/2, Healer 12/3, Debuffer 9/3, Shaman 12/3. 7 loại mới theo bảng cân bằng |
| EN-05 | Chỉ huy vừa Recall, quân đang chuẩn bị đòn: đòn hụt (AI-01), chọn lại mục tiêu |
| EN-06 | Archer bị Barricade chắn: không có line-of-sight ở MVP, chỉ dùng khoảng cách |
| EN-07 | Barricade bị phá khi 5 Grunt đang đánh: cả 5 chọn lại (TWR-07) |
| EN-08 | Tower WALL là mục tiêu duy nhất nhưng ngoài tầm: Archer tiếp tục ADVANCE đến trong 11 m |
| EN-09 | Nhiều Healer hồi một quân: mỗi quân chỉ nhận một lần hồi mỗi 2 s |
| EN-10 | Khi spawn_queue rỗng và mọi quân còn sống đều là Healer (một hoặc nhiều): toàn bộ Healer đó cùng chuyển hành xử Archer (dòng "Như Archer" của bảng ETG-01) cho đến hết wave. Còn Healer lẫn quân khác thì chưa chuyển. Chuyển một lần, không quay lại. Shaman \[Could] áp dụng cùng quy tắc |
| EN-11 | Quân tầm xa bị chỉ huy chạy sát dưới 2 m: vẫn bắn, không kiting |
| EN-12 | Bị knockback vào Fortress hoặc Barricade: kẹp ngoài collider |
| EN-13 | Tua x3 với 70 quân: khớp TIME-06 |
| EN-14 | Chỉ huy chết khi quân đang ATTACK: hủy theo trình tự kết thúc Run |
| EN-15 | Quân sống sót qua PREP (lỗi): hủy khi vào PREP kế, ghi log, không tính kill |

### 3.7.8 Quân mới và va chạm (v2.0) \[MVP]

| **ID** | **Đặc tả** |
| --- | --- |
| EN-16 | **Tắt va chạm giữa quân.** Mọi quân (kể cả boss) không va chạm vật lý và không né nhau (không avoidance giữa quân). Quân vẫn va chạm với chỉ huy (mềm), tower, Barricade, đống đổ nát, tường, Fortress. Hệ slot đánh (CRD-01 đến CRD-05, max_attackers_*) giữ nguyên để quân không dồn một chỗ |
| EN-17 | **Tối đa 5 loại mỗi wave** kể cả boss: xem SPN-14. Áp cho cả Hazard Trial vì nhóm quái lấy từ wave (HZT-02) |
| EN-18 | **Hiển thị trait.** Preview wave ở PREP, Tháp Hazard Trial (HUD-23) và hover quân (MSE-06) hiện biểu tượng trait của loại quân: tàng hình, tự nổ, bất tử một lần, hồi sinh, ủi thẳng, kèm chữ (UI-05). Người chơi biết trước wave có gì để chọn tower và vũ khí |
| EN-19 | **Sniper.** Quân tầm xa (is_ranged), attack_range lớn hơn tầm Arrow cấp 1 (giá trị trong bảng cân bằng). Chọn mục tiêu và dừng bắn như Archer (bảng ETG-01, EN-08, EN-11); đạn như AI-02 |
| EN-20 | **Assassin.** is_stealth: tower không chọn Assassin làm mục tiêu (bỏ khỏi danh sách hợp lệ của mục 3.6.5), Assassin không tính là "quân trong tầm" của tower. Sát thương vùng của nổ Cannon vẫn trúng Assassin nếu nó nằm trong vùng nổ của mục tiêu khác. Chỉ huy thấy Assassin ở độ mờ stealth_opacity (0.5, EnemyData, áp qua material), đánh được bằng kiếm, skill và hiệu ứng vũ khí. Máu thấp. Thanh máu (HUD-09) và hover vẫn hiện |
| EN-21 | **Rider.** move_speed cao (bảng cân bằng), cận chiến như Grunt. Không có luật riêng khác |
| EN-22 | **Suicide Squad.** explode_on_contact: chọn mục tiêu như Grunt; khi mục tiêu trong attack_range thì vào wind-up explode_windup (có telegraph vòng đỏ, FBK-06) rồi nổ: sát thương explode_damage (BLAST, scale theo dmg_mult) trong explode_radius lên chỉ huy Frontline, tower (kể cả WALL trong bán kính), Barricade, Fortress; không friendly fire quân địch (AI-03); chỉ huy Commander miễn (CMD-10); Dodge né được. Sau khi nổ quân chết **không thưởng** gold, XP, uy tín và không tính kill (vì không bị diệt), enemies_alive giảm. Bị diệt trước khi nổ thì không nổ và thưởng bình thường |
| EN-23 | **Suicide Squad Captain.** Đánh cận chiến như Grunt. explode_on_death: khi bị diệt (HP về 0) thì nổ tại chỗ sau explode_windup, cùng luật vùng nổ với EN-22, và vẫn thưởng bình thường. Bị cull (NAV-09, NAV-13) thì không nổ |
| EN-24 | **Knight.** Lần đầu HP xuống dưới invuln_hp_threshold (50% max HP) mà còn sống: bất tử invuln_duration (5 s game time), một lần mỗi con. Trong lúc bất tử, sát thương nhận = 0 và kháng mọi loại coi như 0: tower bỏ Knight khỏi danh sách hợp lệ, đòn chỉ huy hiện "IMMUNE" (như DMG-02). Cú đánh làm HP từ trên ngưỡng về 0 thì Knight chết, không bất tử. Hiển thị lớp giáp phát sáng kèm biểu tượng (UI-05) |
| EN-25 | **Brute (sửa).** is_charger: đi dọc lane_curve thẳng tới Fortress, mục tiêu cố định FORTRESS, không chọn mục tiêu khác, không chịu khiêu khích (AGG-01) và Battle Cry (AGG-02). Va một tower trên ô grid hoặc Barricade trên đường: gây impact_damage lên công trình đó (một lần mỗi công trình mỗi Brute), rồi đi vòng tiếp, không dừng đánh. Va chỉ huy Frontline: gây sát thương đòn thường và hất văng chỉ huy impact_knockback (như cú húc của Sứ giả khe nứt), tối đa một lần mỗi 2 s; Dodge và Deploying miễn (CMB-04). Tới Fortress thì đánh Fortress bằng đòn thường ở melee_slot. Vẫn miễn knockback và stun. Trong Hazard Trial ủi về phía chỉ huy (HZT-14) |
| EN-26 | **Undead.** revive_count = 1: lần đầu HP về 0 thì nằm xuống revive_delay (game time), không bị nhắm, không chiếm slot, rồi hồi sinh tại chỗ với đầy max HP; sau hồi sinh sát thương đòn nhân revive_dmg_mult. Thưởng gold, XP, uy tín, kill và enemy_died (EVB-05) chỉ tính ở lần chết thứ hai. Bị cull lúc đang nằm thì không thưởng. Cờ hit_by_commander giữ qua lần hồi sinh. Không tự nổ |
| EN-27 | **Tương tác chung.** Mọi trait đọc từ EnemyData (mục 3.7.1). Hiệu ứng vũ khí (WPN) áp lên quân mới như quân thường; Knight đang bất tử không nhận hiệu ứng có sát thương. Quân mới chịu FRENZY, thang kẹt NAV và giới hạn cứng NAV-13 như quân thường |

## 3.8 Boss

Mỗi wave boss có đúng một boss. Không có hai boss đồng thời ở MVP. Boss trong Hazard Trial của PREP boss là bản sao riêng trong phòng, tồn tại trước khi boss thật sinh ở BOSS_COMBAT nên không đồng thời (HZT-03).

### 3.8.1 Loại sát thương

Mọi nguồn sát thương phải khai báo damage_type.

| **Nguồn** | **damage\_type** |
| --- | --- |
| Arrow, đạn Archer | PIERCE |
| Cannon | BLAST |
| Kiếm chỉ huy | SLASH |
| Trượng phép | \[ĐÃ BỎ v2.0] Mọi vũ khí là biến thể của kiếm. MAGIC vẫn giữ trong bảng kháng nhưng chưa có nguồn |
| Hiệu ứng vũ khí (Chain Lightning, Burn) | Theo đòn kích hoạt: SLASH hoặc BLAST (WPN-04) |
| Vụ nổ Suicide Squad, Suicide Squad Captain | BLAST (EN-22, EN-23) |
| Bẫy \[Should] | TRAP |
| Skill chủ động của chỉ huy | Whirlwind SLASH, Sword Wave SLASH, Firebomb BLAST (SKL-10..12) |
| Cú rơi khỏi map | TRUE (bỏ qua giáp, kháng, i-frame, skill_mult; không tác dụng lên chỉ huy ở Commander mode) |

| **ID** | **Đặc tả** |
| --- | --- |
| DMG-01 | Lên boss: damage = raw × resist(damage_type, phase), áp dụng lúc trúng đích. resist = 0 là miễn nhiễm |
| DMG-02 | Tower dùng resist = 0 để loại mục tiêu khỏi danh sách hợp lệ. Chỉ huy đánh trúng thì hiện "IMMUNE" và không gây sát thương |
| DMG-03 | resist < 1: số nổi xám kèm nhãn "RESIST" |
| DMG-04 | Sát thương lên boss không có sàn tối thiểu 1. resist = 0 cho đúng 0 |
| DMG-05 | Sát thương TRUE (ở v1.8 chỉ còn cú rơi khỏi map, DEAD-06) không bị giảm bởi armor, skill_mult, BUFF_WARD \[Should], i-frame. Ngoại lệ duy nhất: chỉ huy ở Commander mode bất khả xâm phạm với mọi nguồn (CMD-10) |
| DMG-06 | Công thức chung lên quân thường (không phải boss), áp dụng lúc trúng đích (PRJ-07): damage = round(raw × dealt_mult × taken_mult), tối thiểu 1 nếu raw > 0, làm tròn gần nhất một lần ở cuối. raw là sát thương gốc của nguồn đã gồm hệ số đòn và suy giảm vùng nổ (combo_hit3_mult, PRJ-02). dealt_mult = 1 + tổng các khoản cộng thêm của bên gây (cộng dồn, ví dụ BUFF_FURY +0.25 cho mọi tower, Aura Tiền tuyến +0.20 cho tower trong 12 m quanh chỉ huy Frontline FRT-01, Sharpness và Tinh thông cho sát thương của chỉ huy). taken_mult = tích các hệ số giảm của bên nhận (nhân với nhau, ví dụ Armored 0.8, đặt lúc sinh quân theo SCL-05). Hai nhóm nhân với nhau, không cộng chung: BUFF_FURY cùng Armored cho 1.25 × 0.8 = 1.0. Quân thường coi như resist = 1. Lên boss: damage = round(raw × dealt_mult × resist(damage_type, phase)) theo DMG-01, không có sàn 1 (DMG-04). **DoT** (vùng cháy Firebomb): mỗi quân giữ một biến dot_remainder (float). Mỗi tick cộng raw × dealt_mult × kháng vào biến, trừ máu phần nguyên (floor) và giữ phần lẻ; sàn 1 sát thương không áp cho từng tick. Nhờ đó +5% của thẻ Tinh thông không bị làm tròn mất. |

### 3.8.2 Dữ liệu (BossData)

armor_hp, core_hp, resist_table (theo pha), move_speed, attack_*, target_rules, phase2_speed_mult, phase2_attack_rate_mult, is_ranged. Giá trị dưới đây là ở wave 1 trước hệ số scale.

|  | **Bulwark (Siege Walker, cận chiến) \[MVP]** | **Barrage (Artillery Mech, tầm xa) \[Should]** |
| --- | --- | --- |
| Xuất hiện | Wave 5 | Wave 10 |
| armor_hp / core_hp | 1200 / 900 | 1000 / 800 |
| Tốc độ | 1.6 m/s (pha 2 x1.2) | 1.4 m/s (pha 2 x1.2) |
| Đòn | **Stomp**: damage 45, AoE 3 m, wind-up 1.0 s (vòng đỏ), nhịp 2.5 s, knockback 3 m lên chỉ huy | **Shell**: damage 40, AoE 2 m, tầm 18 m, barrage_hold_distance 13 m (BOSS-41), đạn cong 15 m/s, nhịp 3 s, đánh dấu điểm rơi 1.2 s trước khi nổ |
| Pha 2 | Nhịp đánh nhanh hơn 30% (1.9 s) | Bắn **2 quả** mỗi nhịp vào hai mục tiêu khác nhau nếu có |
| Miễn nhiễm pha 1 | PIERCE, MAGIC | BLAST, TRAP |
| Bảng kháng pha 1 | PIERCE 0, MAGIC 0, BLAST 1.0, SLASH 0.6, TRAP 1.0 | BLAST 0, TRAP 0, PIERCE 1.0, SLASH 0.6, MAGIC 1.0 |
| is_ranged | Không | Có |

Bulwark dạy cần Cannon (hoặc kiếm, skill BLAST/SLASH), Barrage dạy ngược lại là cần Arrow. Người chơi chỉ xây một loại tower sẽ bị đánh vào điểm yếu ở một trong hai boss khi có Barrage.

**MVP chỉ có Bulwark.** BOSS-22 (MVP): mọi wave boss dùng Bulwark với chỉ số scale theo hp_mult(w), dmg_mult(w), speed_mult(w); pha 1 miễn nhiễm PIERCE, MAGIC nên bắt buộc dùng Cannon, kiếm hoặc skill BLAST/SLASH, Arrow không bắn. Khi làm Barrage \[Should] thì quay lại luân phiên theo n (xem BOSS-22 bản \[Should] ở mục 3.8.10). Dòng Barrage trong các bảng bên dưới chỉ áp dụng khi đã làm Barrage.

**Thứ tự mục tiêu:**

| **Boss** | **Thứ tự** |
| --- | --- |
| Bulwark | 1. PLAYER nếu khiêu khích và trong 4 m. 2. BARRICADE trong 8 m phía trước. 3. TOWER_GROUND trong 8 m phía trước. 4. FORTRESS. Không nhắm TOWER_WALL và chỉ huy Commander |
| Barrage \[Should] | Trong tầm 18 m: 1. Tower, ưu tiên Arrow rồi gần nhất. 2. PLAYER (chỉ Frontline). 3. BARRICADE. 4. FORTRESS. Bắn khi mục tiêu trong tầm, tiếp tục ADVANCE tới khi cách mục tiêu đang nhắm barrage_hold_distance rồi mới dừng (hold, BOSS-41) |

### 3.8.3 Luật chung của boss

| **ID** | **Đặc tả** |
| --- | --- |
| BOSS-01 | Miễn taunt, knockback, hồi máu, buff Healer và Shaman, Slow, Stun, Weaken. Ngoại lệ v2.0: hiệu ứng vũ khí (kể cả làm chậm của Frost) có tác dụng lên boss theo WPN-05 |
| BOSS-02 | Không dùng slot đánh (không chiếm melee_slot). Không tính vào max_alive (vẫn tính vào enemies_alive) |
| BOSS-03 | Agent điều hướng lớn nav_layer_large (bán kính 1.6 m). Luôn còn đường đi rộng tối thiểu path_check_min_width (3.2 m) tới cổng Fortress và tới boss_melee_point nhờ luật cấm chặn kín (GRID-07) và vùng cấm xây quanh điểm đứng (GRID-08) |
| BOSS-04 | **Kẹt** (NAV-01 với ngưỡng boss_stuck_time 5 s): boss không bao giờ bị recycle hay cull. Bậc 1: tính lại đường với agent lớn. Bậc 2 (thêm 5 s): nếu vật cản là Barricade hoặc tower trên ô grid thì đặt vật đó làm mục tiêu bắt buộc để Stomp hoặc Shell phá đường. Bậc 3 (thêm 5 s): hop tới điểm nav hợp lệ gần nhất trong boss_hop_radius (6 m) theo chiều tiến, không vượt Fortress. Từ v2.0 boss không va chạm quân hộ tống (EN-16) nên bỏ bậc xuyên qua hộ tống của v1.9. Mọi bậc ghi log. Thang này độc lập với NAV-07, vẫn là MVP dù NAV-07 là \[Should] |
| BOSS-05 | spawn_grace (EN-04) áp dụng cho boss |
| BOSS-06 | Stomp và Shell không friendly fire quân địch. Gây sát thương tower, Barricade, Fortress, chỉ huy |
| BOSS-07 | Stomp, Shell có telegraph. Dodge (i-frame) né được. Knockback Stomp bị miễn khi Dodge hoặc Deploying |
| BOSS-08 | command_post cách slot gần nhất (kể cả ô grid, GRID-03) tối thiểu 3 m để hiệu ứng nổ không chồng lên chỉ huy (chỉ mang tính hình ảnh, chỉ huy ở Commander mode không nhận sát thương). Không còn liên quan tới hiệu ứng nổ Overload |
| BOSS-42 \[MVP] | Hộ tống và boss tính hit_by_commander như quân thường (XP-03). Boss chết cho XP boss (30) theo bảng XP |
| BOSS-43 \[MVP] | Khi Cuồng nộ mà chỉ huy ở Commander mode: tower vẫn bắn bình thường (không có Aura), Fortress chịu 1.5 lần sát thương đòn boss, người chơi có thể Deploy để thêm Aura và skill. Đây là lựa chọn rủi ro cố ý |

### 3.8.4 Pha giáp

Hai thanh HP tách biệt.

ARMORED --(armor_hp = 0)--> TRANSITION (2.5 s) --> EXPOSED --(core_hp = 0)--> DEAD\
ARMORED | TRANSITION | EXPOSED --(boss_timer = 0)--> thêm cờ ENRAGED (không đổi pha, ENR-01)

| **Pha** | **Bảng kháng** | **Hành vi** |
| --- | --- | --- |
| ARMORED | resist_table pha 1 | Đánh, di chuyển bình thường. Sát thương chảy vào armor_hp |
| TRANSITION | Mọi loại x1.5, không miễn nhiễm | Choáng 2.5 s, không di chuyển, không tấn công. Sát thương chảy vào core_hp |
| EXPOSED | Mọi loại x1.25, không miễn nhiễm | Lõi phát sáng, tốc độ và nhịp đánh tăng theo phase2_speed_mult và phase2_attack_rate_mult |

| **ID** | **Đặc tả** |
| --- | --- |
| BOSS-09 | Sát thương dư khi armor_hp về 0 bị bỏ |
| BOSS-10 | Chuyển pha một lần, cờ phase_broken |
| BOSS-11 | Đồng hồ không dừng trong TRANSITION |
| BOSS-12 | Không hồi giáp, không có pha thứ ba ở MVP |
| BOSS-13 | Thanh HP hai đoạn (giáp xám, lõi đỏ), biểu tượng kháng đồng bộ với tower đang miễn nhiễm |
| BOSS-14 | Quân hộ tống không bị ảnh hưởng bởi chuyển pha |

### 3.8.5 Đồng hồ Cuồng nộ

| **Tham số** | **Công thức** | **Ví dụ** |
| --- | --- | --- |
| boss_timer (đồng hồ Cuồng nộ) | min(120, 90 + 3(n−1)) s, n = w/5 | n=1: 90 s, n=2: 93 s |

| **ID** | **Đặc tả** |
| --- | --- |
| BTM-01 | Bắt đầu ở giây 0 của BOSS_COMBAT, theo game time, dừng khi Pause |
| BTM-02 | Hiển thị cố định trên HUD từ BOSS_INTRO (đứng yên ở giá trị đầy) |
| BTM-03 | Không cộng thêm giờ ở MVP. Relic tăng giờ là \[Could] |
| BTM-04 | Mốc cảnh báo: T-30 s banner T2 "Mech sắp cuồng nộ", T-10 s số đếm cỡ lớn kèm bíp mỗi giây, T-0 Cuồng nộ (ENR-01). Không còn mốc T-20, T-15, T-5 và không khóa tua x1 |

### 3.8.6 Flow wave boss

PREP (boss) -> BOSS_INTRO -> BOSS_COMBAT -> SUMMARY

**PREP boss:** không giới hạn thời gian như mọi PREP (WAVE-11). Preview: tên boss, miễn nhiễm pha 1, boss_timer, vũ khí sẽ rơi nếu còn (WPN-11). Hazard Trial của PREP boss gồm boss cộng 4 quân (HZT-02). \[Should] PNL-05 đầy đủ.

| **ID** | **PREP boss** |
| --- | --- |
| BOSS-15 \[Should] | Cảnh báo không chặn nếu không có tower gây được sát thương lên boss ở pha 1 (Frontline luôn gây được 60% nên không bế tắc) |
| BOSS-16 | \[ĐÃ XÓA v1.8] |

| **ID** | **BOSS\_INTRO** |
| --- | --- |
| BOSS-17 | 4 s game time. Camera lia tới boss, hiện tên và biểu tượng miễn nhiễm |
| BOSS-18 | Khóa input gameplay và chuyển chế độ. Chỉ huy bất tử. Cho Pause và Skip (sau 1 s) |
| BOSS-19 | time_scale về x1. Đồng hồ chưa chạy |
| BOSS-20 | Kết thúc intro: boss và hộ tống sinh, đồng hồ chạy |
| BOSS-21 | Boss chết trước giờ: chuỗi chết 2 s, hủy đồng hồ, không Cuồng nộ |

### 3.8.7 Cuồng nộ (Enrage, thay Overload)

Xảy ra khi boss_timer về 0 và boss còn sống. Không có sát thương TRUE, không phá tower, không phạt chỉ huy; hạ boss chậm chỉ làm boss mạnh hơn.

| **ID** | **Đặc tả** | **Tag** |
| --- | --- | --- |
| ENR-01 | boss_timer <= 0 và boss còn sống: đặt boss_enraged = true (một lần mỗi wave), phát `boss_enraged`, banner T1 "Mech cuồng nộ". Xử lý ở cuối physics frame, sau xử lý sát thương và kiểm tra thua | MVP |
| ENR-02 | Hiệu ứng: move_speed × enrage_speed_mult (1.3), attack_interval ÷ enrage_attack_rate_mult (1.3), sát thương đòn × enrage_damage_mult (1.5). Chồng lên pha 2 / EXPOSED. Vĩnh viễn đến khi boss chết. Không đổi HP, kháng, không hồi giáp | MVP |
| ENR-03 | Không sát thương TRUE, không phá tower, không phạt chỉ huy. Chỉ huy Commander vẫn bất khả xâm phạm (CMD-10). Fortress chỉ chịu sát thương thường từ đòn boss (đã nhân) | MVP |
| ENR-04 | Boss chết đúng frame timer = 0: xử lý boss chết trước, không Cuồng nộ. Fortress sập cùng frame: thua đè thắng (BOSS-28) | MVP |
| ENR-05 | Đồng hồ HUD dừng ở 0 và đổi thành nhãn "CUỒNG NỘ" có biểu tượng, không chỉ dựa vào màu (UI-05). Lõi boss phát sáng đỏ | MVP |
| ENR-06 | Wave boss vẫn kết thúc khi spawn_queue rỗng và enemies_alive == 0 (SPN-11). Cuồng nộ không có lối thoát: cách duy nhất là hạ boss. Luôn có đường thắng vì kiếm gây ≥ 60% lên boss (mục 2.8) | MVP |

### 3.8.8 Retreat \[ĐÃ XÓA v1.8]

Toàn bộ mục này bị xóa: RET-01 đến RET-12, Retreat Zone, phím F, nút Retreat HUD, EVB-24 (`retreat_zone_changed`), Area3D `Retreat Zone` và các tham chiếu tới Retreat Zone trong điều kiện loại ô grid (GRID-03). Lý do: Retreat cùng Overload khiến vòng boss xoay quanh việc trốn về thành. ID RET-xx không được dùng lại.

### 3.8.9 Thưởng boss

| **ID** | **Đặc tả** |
| --- | --- |
| BRW-01 | Diệt boss: boss_gold(w) = boss_gold_base (100) × gold_mult(w) (wave 1-30 theo WaveRewardTable, khởi điểm 100 × (1 + 0.04(w-1)); từ wave 31 theo công thức), boss_prestige 15. clear_mult và frontline_gold_mult không áp lên boss_gold (FRT-02); gold_pct_total có áp (mục 3.9.1) |
| BRW-02 | Diệt boss sau khi Cuồng nộ: boss_gold và boss_prestige nhân enrage_reward_mult (0.5), làm tròn xuống. Thưởng từ hộ tống tính bình thường |
| BRW-03 | \[Should] Diệt boss cho lượt 3 chọn 1 nâng hạng (skill hiếm) |
| BRW-04 | par_time_boss = 0.6 × boss_timer. Mốc 0.7 / 1.3 như wave thường. Clear time tính đến khi cả boss và hộ tống chết |
| BRW-05 | \[ĐÃ XÓA v1.8] |
| BRW-06 | Ghi bosses_defeated, hiển thị ở RunEnd |
| BRW-07 | **Lượt Emergency repair:** khi boss bị diệt (kể cả sau Cuồng nộ) và wave vào SUMMARY với waves_cleared tăng, cộng +1 vào emg_repair_charges, tối đa 3. Nếu đang 3/3 thì lượt thừa bị bỏ, không bảo lưu. Không cộng nếu run kết thúc trong wave đó (thua đè thắng, GLD-08). Wave thường không cộng. Cộng cùng lúc với gold ở SUMMARY và hiển thị dòng "Emergency repair +1 (n/3)" |
| BRW-08 | Lượt thưởng không đổi emg_repair_cd: cooldown 60 s tiếp tục đếm bình thường (chạy cả ở SUMMARY và PREP). Chủ đích: lượt thưởng là kho dự trữ cho các lần dùng sau; cooldown không bị reset để không dùng liên tiếp được. Với start_wave > 1 \[Should], các boss đã bỏ qua khi xuất phát không được tính bù (STR-08) |
| BRW-09 \[MVP] | **Vũ khí:** boss ở wave 5, 10, 15, 20, 25 bị diệt thì nhận một vũ khí chưa có theo WPN-11, cùng thời điểm và cùng điều kiện với BRW-07. Boss trong Hazard Trial không cho BRW-01 phần uy tín, BRW-07 hay BRW-09 (HZT-04) |

### 3.8.10 Boss trong endless

| **ID** | **Đặc tả** |
| --- | --- |
| BOSS-22 | Wave boss khi w % 5 == 0. MVP: mọi wave boss là Bulwark với chỉ số scale theo wave. \[Should] Khi làm Barrage: n=1 Bulwark, n=2 Barrage, thứ tự cố định, rồi theo BOSS-23 |
| BOSS-23 \[Should] | Từ n >= 3: rút ngẫu nhiên từ pool bằng RNG wave, không lặp boss ngay trước |
| BOSS-24 | Chỉ số nhân hp_mult(w), dmg_mult(w), speed_mult(w) (wave 1-30 lấy từ WaveScript, từ wave 31 theo công thức, mục 3.7.6). Không có hệ số riêng ở MVP. Bảng dưới tính theo công thức, cũng là giá trị khởi điểm của bảng cân bằng |
| BOSS-25 | boss_timer tăng chậm, trần 120 s |
| BOSS-26 \[Should] | start_wave > 1: boss theo số thứ tự tuyệt đối (luân phiên theo n khi đã có Barrage) |

| **Wave** | **Boss (MVP)** | **armor\_hp** | **core\_hp** | **Sát thương đòn (Stomp)** | **boss\_timer** |
| --- | --- | --- | --- | --- | --- |
| 5 | Bulwark | 1757 | 1318 | 57 | 90 s |
| 10 | Bulwark | 2669 | 2002 | 77 | 93 s |
| 15 | Bulwark | 3821 | 2866 | 100 | 96 s |

\[Should] Khi có Barrage, wave 10 là Barrage (armor_hp 2224, core_hp 1779, Shell 68, 93 s) và wave 15 rút theo BOSS-23. Số trong bảng tính từ hp_mult(w), dmg_mult(w) chưa làm tròn (wave 10: 2.224 và 1.702), làm tròn gần nhất một lần ở cuối.

Kiểm tra cân bằng thô wave 5: Cannon cấp 1 (\~14 dps mỗi cái, 2 cái) cộng kiếm 60% (\~27 dps) cho \~55 dps lên giáp, xấp xỉ 32 s phá giáp. Pha lõi \~14 s (gồm TRANSITION 2.5 s nhận x1.5, rồi EXPOSED x1.25). Cộng thời gian boss đi vào tầm (\~27 s) là \~73 s trong giới hạn 90 s. Mục tiêu playtest: 60-75% người mới diệt được Bulwark trước giờ. Số trong bảng tính từ hp\_mult và dmg\_mult chưa làm tròn (ví dụ wave 5: 1.464 và 1.272), làm tròn gần nhất một lần ở cuối.

### 3.8.11 Edge case boss

| **ID** | **Tình huống** | **Xử lý** |
| --- | --- | --- |
| BOSS-27 | Boss chết đúng frame boss_timer = 0 | Boss chết xử lý trước, không Cuồng nộ (ENR-04) |
| BOSS-28 | Boss chết cùng frame Fortress sập | Thua đè thắng, FORTRESS_DESTROYED |
| BOSS-29 | \[ĐÃ XÓA v1.8] | |
| BOSS-30 | \[ĐÃ XÓA v1.8] | |
| BOSS-31 | Boss chỉ còn Cannon và kiếm khả dụng (ví dụ Barrage \[Should] phá hết tower WALL) | Không bế tắc: kiếm gây 60%, Firebomb gây 100% (BLAST) |
| BOSS-32 | Bulwark tới Fortress trước hết giờ | Đánh bằng Stomp tại boss_melee_point (BOSS-40), không chiếm melee_slot. Có thể tank bằng Frontline |
| BOSS-33 \[Should] | Barrage không có mục tiêu trong 18 m | ADVANCE tới khi có |
| BOSS-34 | Chỉ huy đứng giữa vòng Stomp và Battle Cry | Không taunt boss nhưng taunt hộ tống. Stomp theo target_rules |
| BOSS-35 | Chuyển pha khi chỉ huy đang đánh | Đòn tiếp theo chảy vào core_hp với x1.5 |
| BOSS-36 | \[ĐÃ XÓA v1.8] | BOSS_COMBAT cho tua x2/x3 bình thường (TIME-03) |
| BOSS-37 | Boss trong spawn_zone chưa bị nhắm | Bất tử. Ra khỏi vùng sau ~8 s, tối đa spawn_grace_max_time 10 s (EN-04) |
| BOSS-38 | Abandon giữa wave boss | Chốt ABANDONED |
| BOSS-39 | enemies_alive == 0 nhưng đồng hồ còn (lỗi) | Coi như boss chết (BOSS-21), ghi log |
| BOSS-40 | Vị trí đứng của Bulwark khi tới Fortress (boss_melee_point) | Marker3D do Level đặt, một điểm mỗi level, ngoài tường Fortress ở giữa mặt tường hướng ra hành lang. Ràng buộc: tâm boss cách mặt ngoài collider Fortress từ 1.6 m (bán kính agent nav_layer_large, BOSS-03) đến 2.0 m để AoE 3 m của Stomp luôn chạm tường; nằm trên navmesh của agent lớn; không nằm trong collider tower hay Barricade (bảo đảm bởi vùng cấm xây GRID-08). Bulwark đi tới điểm này, dừng, quay mặt về Fortress rồi Stomp theo nhịp (BOSS-32), không chiếm melee_slot (BOSS-02). Thiếu marker: dùng điểm navmesh gần cổng nhất cách tường 1.8 m và ghi log. Barrage không dùng, đứng ở tầm bắn (BOSS-01). Quân không va chạm Bulwark (EN-16) nên không bị Bulwark chắn đường |
| BOSS-41 \[Should] | Barrage dừng ngoài tầm mọi tower | Shell tầm 18 m lớn hơn tầm Arrow và Cannon ở các cấp thấp (Arrow cấp 1 là 14 m, tầm theo cấp trong bảng cân bằng), nên nếu Barrage dừng ngay khi có mục tiêu trong tầm thì không tower nào bắn trả được. Vì vậy Barrage bắn từ 18 m nhưng chỉ dừng khi cách mục tiêu đang nhắm barrage_hold_distance (13 m), nhỏ hơn tầm Arrow cấp 1 (14 m), nên tower Arrow ở mọi cấp bị nhắm đều bắn trả được. Mục tiêu bị phá thì chọn lại (ETG-03) và tiếp tục ADVANCE nếu cần. Không dừng khi còn trong spawn_zone (EN-04) |

## 3.9 Kinh tế: Gold, Mithril, Uy tín, Danh vọng

Từ v2.0 game có ba loại tiền tệ: gold và Mithril chỉ tồn tại trong run, danh vọng lưu vĩnh viễn.

|  | **Gold** | **Mithril** | **Uy tín và Danh vọng** |
| --- | --- | --- | --- |
| Phạm vi | Trong run, mất khi hết run | Trong run, mất khi hết run | Uy tín tích lũy trong run, quy đổi thành Danh vọng lưu vĩnh viễn |
| Kiếm từ | Diệt quân, boss, clear time, Hazard Trial, bán tower | Thắng Hazard Trial (MTH-02) | Diệt quân, boss, hoàn thành wave (không từ Hazard Trial) |
| Tiêu vào | Xây, nâng cấp | Sửa Fortress ở PREP (MTH-03) | Meta shop, mở khóa |
| Vai trò | Áp lực chọn lựa trong run | Đổi rủi ro ở Hazard Trial lấy độ bền thành | Tiến triển giữa các run |

**Nguyên tắc:** gold luôn khan hiếm. Run bắt đầu với 0 gold và hai trụ có sẵn. Giá 36 cấp tower và thưởng gold theo wave nằm trong bảng cân bằng (mục 6.10); bảng phải giữ được nguyên tắc người chơi không đủ gold để nâng mọi công trình cùng lúc và phải chọn.

### 3.9.1 Gold

| **Nguồn** | **Công thức** |
| --- | --- |
| Diệt quân | kill_gold = gold_reward_gốc × gold_mult(w) × (hit_by_commander ? frontline_gold_mult : 1), cộng vào wave_gold_base (RWD-02, FRT-02) |
| Diệt boss | boss_gold(w) = boss_gold_base × gold_mult(w) (khởi điểm 100 × (1 + 0.04(w-1))), không nhân clear_mult, không nhân frontline_gold_mult; nhân enrage_reward_mult nếu boss chết sau Cuồng nộ (BRW-02) |
| Clear time | clear_mult (1.25 / 1.00 / 0.80) lên wave_gold_base |
| Hazard Trial | Gold của số quái đã giết trong phòng, cộng khi rời phòng (GLD-10) |
| Bán tower | 60% tổng đầu tư, làm tròn xuống |

gold_gain = floor( wave_gold_base × (1 + gold_pct_total) × clear_mult )\
\+ floor( boss_gold × (1 + gold_pct_total) )

gold_pct_total = gold_pct_meta + gold_pct_buff (cộng, không nhân chồng). MVP: gold_pct_buff = 0 vì buff là \[Should]. Không áp lên tiền bán tower. Làm tròn một lần ở cuối. gold_mult(w) của wave 1-30 lấy từ bảng thưởng theo wave (WaveRewardTable), từ wave 31 bằng 1 + 0.04(w-1).

Số liệu gold theo wave của v1.9 không còn dùng làm tham chiếu: nhịp gold đến wave 30 được cân bằng trực tiếp trong bảng cân bằng. **Mục tiêu playtest:** gold đủ để xây thêm và nâng dần, không đủ để đưa cả 6 công trình lên bậc cao cùng lúc trước wave 30.

| **ID** | **Luật** |
| --- | --- |
| GLD-01 | Gold là số nguyên không âm. Kiểm tra gold >= cost trước khi trừ, giao dịch nguyên tử |
| GLD-02 | Số nổi hiển thị kill_gold theo RWD-02 (đã gồm frontline_gold_mult nếu có cờ), trước gold_pct_total và clear_mult (RWD-01). Ví thật chỉ tăng ở SUMMARY, trừ gold của Hazard Trial (GLD-10) |
| GLD-03 | Thua giữa wave: gold chưa cộng bị hủy, không quy đổi sang danh vọng |
| GLD-04 | Không lãi, không trần. Gold dư không mang sang run sau |
| GLD-05 | HUD: gold hiện có và "+xx" mờ tích lũy |
| GLD-06 | starting_gold: MVP cố định 0 (GameConfig). \[Should] lấy từ StartPack |
| GLD-08 | Gold ở SUMMARY cộng đúng một lần. Wave kết thúc cùng lúc thua: không cộng |
| GLD-10 \[MVP] | **Gold Hazard Trial.** Dùng đúng công thức của wave thật (RWD-02, BRW-01, mục 3.9.1), w là wave_index của PREP, bỏ clear_mult: hazard_gold = floor( hazard_gold_base × (1 + gold_pct_total) ) + floor( hazard_boss_gold × (1 + gold_pct_total) ). hazard_gold_base = Σ kill_gold của các quân thường đã giết trong phòng (HZT-16). Trong phòng chỉ chỉ huy gây sát thương nên mọi quân bị giết đều có cờ hit_by_commander, cmd_mult = frontline_gold_mult đã nằm sẵn trong kill_gold và không nhân thêm lần nữa. hazard_boss_gold = boss_gold(w) nếu boss trong phòng bị diệt, ngược lại 0; không nhân frontline_gold_mult (FRT-02), không có enrage_reward_mult vì boss trong phòng không Cuồng nộ (HZT-03). Quân tự nổ (EN-22) cho 0. Cộng vào ví ngay khi rời phòng với mọi kết quả (thắng, rời, chết), phát gold_changed (EVB-06), tính vào run_gold_earned |

### 3.9.2 Uy tín và Danh vọng

| **Nguồn uy tín** | **Giá trị** | **Cộng vào prestige\_pending** |
| --- | --- | --- |
| Diệt quân | prestige_reward cố định theo loại | SUMMARY |
| Diệt boss | 15 | SUMMARY |
| Hoàn thành wave | 2 + floor(w/5) | SUMMARY |

Quy đổi theo công thức ở mục 3.2.4. conversion_rate 30%.

| **ID** | **Luật** |
| --- | --- |
| PRS-01 | Danh vọng là số nguyên không âm, không trần ở MVP |
| PRS-02 | Không có uy tín từ bán tower, sửa Fortress, tua tốc độ hay quái trong Hazard Trial (HZT-04). Thắng ở victory_wave không thưởng thêm uy tín hay danh vọng |
| PRS-03 | ABANDONED quy đổi như hai loại kia (không lợi thế hơn chơi tiếp) |
| PRS-04 | Kết thúc ở wave 1 trước khi hoàn thành wave: chỉ có buffer 50% |
| PRS-05 | FLOW-03 (crash): dùng prestige_pending ghi ở SUMMARY gần nhất, buffer wave dở mất |
| PRS-06 | RunEnd hiển thị đủ chi tiết quy đổi |

Ước tính (xuất phát wave 1, chưa buffer): waves_cleared 5 cho ~23 danh vọng, 9 cho ~55, 10 cho ~65, 20 cho ~217. Mục tiêu nhịp: món đầu tiên (40) sau 1-2 run, khoảng 30% cửa hàng sau ~10 run.

### 3.9.3 Mithril \[MVP]

Mithril là tài nguyên trong run, kiếm duy nhất bằng cách thắng Hazard Trial (mục 3.15), và là cách duy nhất để sửa Fortress trong PREP, thay cho sửa bằng gold của v1.9.

| **ID** | **Đặc tả** |
| --- | --- |
| MTH-01 | Mithril là số nguyên không âm trong RunState, khởi đầu 0 mỗi run (kể cả \[Should] start_wave > 1), mất khi hết run, không quy đổi danh vọng, không ghi save (RUN-01), không mua bằng gold hay danh vọng |
| MTH-02 | **Nguồn.** Thắng Hazard Trial (kết quả WON: mọi con trong nhóm đã bị diệt hoặc tự nổ và chỉ huy còn sống, HZT-07, HZT-16) cộng mithril_reward(w) Mithril, w là wave_index của PREP. Wave 1-30 lấy từ bảng thưởng theo wave (WaveRewardTable, khởi điểm 1 mỗi wave); từ wave 31 dùng giá trị của wave victory_wave. Rời phòng hoặc chết trong phòng không có Mithril. Phát mithril_changed (EVB-39) và toast ALR-20 |
| MTH-03 | **Sửa Fortress.** Chỉ ở PREP (kể cả PREP boss và lúc Pause trong PREP như BLD-04), ở cả hai chế độ (CMD-05), qua panel Fortress (PNL-04). Mỗi lần bấm tốn đúng 1 Mithril và hồi floor(mithril_repair_pct × fortress_max_hp) HP (mithril_repair_pct = 0.20, FortressStats), kẹp ở fortress_max_hp (FORT-03). fortress_max_hp là giá trị hiệu dụng ở RunState nên một viên luôn hồi 20% dù cấp FORT_HP khác nhau |
| MTH-04 | Fortress đầy HP: từ chối, không trừ Mithril. Fortress thiếu ít hơn 20%: vẫn cho sửa, tốn 1 Mithril, HP kẹp ở max; nút hiện tooltip "Hồi thừa" (như CMD-08). mithril = 0: nút xám kèm "Cần Mithril, thắng Hazard Trial để nhận" (HUD-05) |
| MTH-05 | Không sửa bằng Mithril ở HAZARD_TRIAL, COMBAT, BOSS_INTRO, BOSS_COMBAT, SUMMARY, REWARD_PICK. Giao dịch nguyên tử như BLD-02: bấm đúng frame PREP kết thúc thì hoàn tất trước hoặc bị từ chối, kiểm tra lại state và số Mithril lúc xác nhận |
| MTH-06 | Emergency repair (CMD-02) giữ nguyên, không tốn và không cho Mithril. Trạm hồi lực không sửa được bằng Mithril (HLT-08) |
| MTH-07 | HUD hiện ô Mithril cạnh gold (HUD-20). Số Mithril thưởng theo wave đến wave 30 nằm trong bảng cân bằng |

## 3.10 Meta shop và Buff một wave

### 3.10.1 Cấu trúc

Một màn hình. Không hoàn tiền ở MVP. MVP có 4 mục (FORT_HP, GOLD_PCT, CMD_HP, EMG_REPAIR). STARTER_KIT và UNLOCK_WAND đã bỏ ở v2.0 (thay bằng trụ có sẵn và vũ khí rơi từ boss, Phụ lục E).

| **ID mục** | **Tên** | **Tác dụng mỗi cấp** | **Số cấp** | **Chi phí (danh vọng)** | **Phạm vi** |
| --- | --- | --- | --- | --- | --- |
| FORT_HP | Thành kiên cố | +5% fortress_max_hp | 5 | 40 / 70 / 110 / 160 / 230 | MVP |
| GOLD_PCT | Tay buôn giỏi | +4% gold từ quân và boss | 4 | 60 / 100 / 160 / 240 | MVP |
| CMD_HP | Thể chất chỉ huy | +10 commander_max_hp | 3 | 40 / 80 / 140 | MVP |
| EMG_REPAIR | Sửa chữa hiệu quả | +3 điểm % lượng hồi mỗi lượt Emergency repair (20% lên 23 / 26 / 29%) | 3 | 50 / 90 / 150 | MVP |
| BUFF_CHARGE | Bùa một wave | Mua lượt buff | Kho tối đa 5 mỗi loại | 20 mỗi lượt | Should |
| UNLOCK_TRAP | Mở khóa Bẫy | Thêm Bẫy vào menu xây | 1 | 100 | Should |
| SLOT_ACTIVE | Ô kỹ năng chủ động | Mở ô chủ động thứ 4, 5 (SKL-24) | 2 | 80 / 180 | Should |
| SLOT_PASSIVE | Ô kỹ năng bị động | Mở ô bị động thứ 4, 5 (SKL-24) | 2 | 80 / 180 | Should |
| REROLL_PLUS | Thêm lượt đổi thẻ | +1 Reroll mỗi run (SKL-08) | 2 | 50 / 100 | Should |
| SKILL_UNLOCK_* | Mở skill mới vào pool | Thêm Sword Throw, War Horn, Arrow Rain... (SKL-24) | 1 mỗi mục | 60 đến 120 mỗi mục | Should |

Tổng chi phí các mục vĩnh viễn MVP = 610 (FORT_HP) + 560 (GOLD_PCT) + 260 (CMD_HP) + 290 (EMG_REPAIR) = 1 720 danh vọng. Cộng lại chỉ đưa lên khoảng +25% HP thành, +16% gold, +30 HP chỉ huy ("chi phí cao, buff thấp").

### 3.10.2 Buff một wave \[Should]

Toàn bộ mục 3.10.2 là \[Should] từ v1.4, gồm cả mục shop BUFF_CHARGE và màn StartSelect dùng để nạp buff. Khi chưa làm, MVP không có kho buff, không có phím V, không có panel PNL-06 và gold_pct_buff = 0.

| **Buff** | **Tác dụng trong đúng một wave** |
| --- | --- |
| BUFF_FURY (Nổi giận) | +25% sát thương mọi tower (lúc trúng đích) |
| BUFF_WARD (Hộ thành) | Fortress nhận -25% sát thương (ward_mult 0.75, nhân sau armor, mục 3.6.1). **Không** áp lên TRUE (ở v1.8 chỉ còn cú rơi khỏi map, không đánh Fortress) |
| BUFF_FORTUNE (Tài lộc) | +25% vào gold_pct_buff của wave đó |

| **ID** | **Luật** |
| --- | --- |
| BUF-01 | Mua ở shop cộng vào buff_stock\[loại], tối đa 5 mỗi loại |
| BUF-02 | Ở StartSelect, **nạp** tối đa 2 lượt vào run (chưa trừ kho) |
| BUF-03 | Kích hoạt ở PREP của bất kỳ wave nào, tối đa **1 buff hoạt động mỗi wave** |
| BUF-04 | Kích hoạt trừ ngay 1 lượt khỏi kho và **ghi save**. Hiệu lực từ đầu COMBAT đến hết SUMMARY |
| BUF-05 | Không kích hoạt trong COMBAT hoặc BOSS_INTRO. Được ở PREP wave boss |
| BUF-06 | Hết run: lượt nạp chưa kích hoạt tự về kho (chưa từng bị trừ) |
| BUF-07 | Wave boss có Cuồng nộ vẫn tính buff đã dùng |
| BUF-08 | HUD hiển thị buff đang hoạt động và số lượt còn nạp |

### 3.10.3 Luật chung của shop

| **ID** | **Luật** |
| --- | --- |
| SHP-05 | Mua là giao dịch nguyên tử: kiểm tra số dư, trừ, tăng cấp, ghi save. Ghi save lỗi thì hoàn tác và báo lỗi |
| SHP-06 | Không đủ danh vọng: nút xám kèm số thiếu. Tối đa cấp: "MAX" |
| SHP-07 | Khóa nút khi đang xử lý, chỉ nhận một lần bấm |
| SHP-08 | Mua tuần tự, không nhảy cấp |
| SHP-09 | Hiển thị tác dụng hiện tại, cấp kế, chi phí, số dư sau khi mua |
| SHP-10 | Không hoàn tiền hay reset ở MVP (reset hoàn 80% là \[Could]) |
| SHP-11 | Mục \[Should] chưa làm thì **ẩn** khỏi shop (MVP chỉ hiện 4 mục) |
| SHP-12 | Dùng được từ MainMenu và RunEnd. Số dư cập nhật sau khi RunEnd áp prestige_gain |
| SHP-13 | EMG_REPAIR chỉ tăng **lượng hồi**. Không mục shop nào đổi được số lượt tối đa (3), số lượt khởi đầu (3) hay cooldown (60 s) của Emergency repair. Mô tả mục trong shop nêu rõ giới hạn 3 lượt mỗi run |

## 3.11 Chọn wave khởi đầu và áp dụng meta

### 3.11.1 StartSelect, mốc và StartPack \[Should]

Từ v1.4, màn StartSelect (gồm chọn mốc và nạp buff) là \[Should]. MVP vào thẳng RunLoading với start_wave = 1 (FLOW-06). Các luật STR bên dưới chỉ có hiệu lực khi làm mục này.

Mốc M mở khi max_wave_cleared >= M. Mỗi mốc có StartPack cố định trong Resource.

| **Mốc** | **start\_mult** | **Gold khởi điểm** | **Công trình đặt sẵn (miễn phí)** |
| --- | --- | --- | --- |
| 1 | 1.0 | 0 | Hai trụ có sẵn (mục 3.2.1) |
| 5 | 0.8 | Soạn lại khi làm | Soạn lại khi làm |
| 10 | 0.6 | Soạn lại khi làm | Soạn lại khi làm |
| 15 | 0.5 | Soạn lại khi làm | Soạn lại khi làm |
| 20 | 0.4 | Soạn lại khi làm | Soạn lại khi làm |

Từ v2.0, gold và công trình của StartPack ở mốc 5 trở lên phải soạn lại trong Resource StartPack khi làm mục này, theo bố cục mới: chỉ dùng W1-W3 và tối đa 3 ô grid (trỏ bằng cell_id), cấp theo thang 1-36. Bảng công trình của v1.9 (6 slot WALL, cấp 1-3) không còn dùng. Mục tiêu: giá trị tương đương mỗi mốc khoảng 80% gold tích lũy tự nhiên đến mốc đó. Ví dụ phạt: xuất phát wave 10 và thua ở wave 21 cho ≈ 97 danh vọng so với ≈ 217 nếu chơi từ wave 1.

**StartSelect** gồm: thẻ mốc (mốc khóa hiện mờ kèm điều kiện), thông tin mỗi mốc (gold, công trình, start_mult, best_by_start), nạp buff (tối đa 2), nút Bắt đầu và Quay lại.

| **ID** | **Đặc tả** |
| --- | --- |
| STR-01 | Mốc mở theo max_wave_cleared tuyệt đối. Chơi từ mốc cao vẫn mở tiếp mốc cao hơn |
| STR-02 | best_by_start\[M] lưu riêng theo mốc, không so trực tiếp |
| STR-03 | Mặc định chọn sẵn mốc **cao nhất đã mở**, hệ số phạt hiển thị rõ cạnh thẻ |
| STR-04 | Xuất phát mốc M: wave_index = M, waves_cleared = M-1. Boss theo n = M/5 |
| STR-05 | Công trình đặt sẵn hoạt động ngay ở PREP đầu với HP đầy, priority mặc định |
| STR-06 | Tutorial chỉ chạy khi start_wave = 1 và profile.flags.tutorial_done = false (mục 4.7). Mốc muộn không chạy tutorial và không đặt trụ có sẵn (dùng StartPack) |
| STR-07 | Quay lại sau khi nạp buff: hủy lựa chọn nạp, không mất gì |
| STR-08 | Fortress và chỉ huy đầy HP, cooldown các kỹ năng khởi đầu bằng 0. Emergency repair luôn khởi đầu ở **3/3 lượt** với emg_repair_cd = 0, ở mọi mốc xuất phát. Các wave boss bị bỏ qua khi xuất phát ở mốc muộn không được tính bù thêm lượt (BRW-08) hay vũ khí (WPN-11). Mithril khởi đầu 0, vũ khí chỉ có kiếm gốc |

### 3.11.2 Áp dụng meta \[MVP]

| **ID** | **Đặc tả** |
| --- | --- |
| APL-01 | Mọi modifier meta lưu trong RunConfig **bất biến** suốt run. RunConfig giữ giá trị gốc; giá trị hiệu dụng (fortress_max_hp, commander_max_hp) nằm ở RunState và chỉ tăng bởi thẻ stat (SKL-15) |
| APL-02 | Cộng vào tham số gốc **một lần** khi RunLoading |
| APL-03 | Trần: armor_pct chỉ huy 75%, fortress_armor_pct 60%. Trần chỉ áp lên giá trị armor; BUFF_WARD không phải armor mà là hệ số riêng ward_mult (mục 3.6.1). Ở MVP nguồn duy nhất cộng armor chỉ huy là bị động Armored (tối đa 15%, SKL-14) nên trần 75% chỉ để dự phòng, không dùng để cân bằng |
| APL-04 | emergency_repair_cooldown (60 s) và emg_repair_charges_max (3) là hằng số của GameConfig, không bị meta, buff, relic hay skill thay đổi (SKL-09). Lượng hồi tối đa sau meta là 29% |

## 3.12 Save/Load

### 3.12.1 Tệp và cấu trúc

| **Tệp** | **Nội dung** |
| --- | --- |
| user://endlesswar_save.json | Tiến trình chính |
| user://endlesswar_save.bak | Bản chính trước lần ghi gần nhất |
| user://endlesswar_save.tmp | Bản đang ghi dở |
| user://save.premigrate.bak | \[Should] Bản trước migration (giữ một bản) |
| user://settings.cfg | Cài đặt, **tách riêng** khỏi save |

{\
"save_version": 1,\
"revision": 0,\
"updated_at": "<ISO 8601 UTC>",\
"device_id": "<uuid>",\
"checksum": "sha256:\<hash của chuỗi data đã chuẩn hóa>",\
"data": {\
"profile": {\
"prestige_balance": 120,\
"max_wave_cleared": 11,\
"best_by_start": { "1": 11 },\
"stats": { "total_runs": 9, "total_kills": 1450, "bosses_defeated": 3 }\
},\
"meta": {\
"levels": { "FORT_HP": 2, "GOLD_PCT": 1, "CMD_HP": 0, "EMG_REPAIR": 0 },\
"unlocks": { "TRAP": false, "WAND": false },\
"buff_stock": { "FURY": 1, "WARD": 0, "FORTUNE": 2 }\
},\
"run_flag": {\
"run_in_progress": false,\
"start_wave": 1,\
"start_mult": 1.0,\
"waves_cleared": 0,\
"prestige_pending": 0\
},\
"flags": { "tutorial_done": true }\
}\
}

unlocked_starts **không lưu**, luôn tính lại từ max_wave_cleared. Ba trường ngoài `data` là revision (số nguyên, tăng 1 mỗi lần ghi save thành công), updated_at và device_id (uuid sinh một lần ở máy, lưu cùng save). Chúng chỉ phục vụ đồng bộ tài khoản \[Should] (ACCT-04, ACCT-06); thiếu thì dùng revision 0 và sinh device_id mới, không ảnh hưởng chơi offline và không đổi save_version. Checksum chỉ để phát hiện hỏng tệp, không chống gian lận. Các trường unlocks và buff_stock phục vụ mục \[Should]; ở MVP có thể bỏ trống hoặc không ghi, thiếu thì dùng giá trị mặc định (SAV-10). Các cấp \[Should] của meta.levels (SLOT_ACTIVE, SLOT_PASSIVE, REROLL_PLUS, SKILL_UNLOCK_*) cũng thiếu thì mặc định 0. Dữ liệu skill và XP của run không ghi xuống đĩa (RUN-01). **flags.tutorial_done (v2.0):** false ở save mới; bật true một lần khi tutorial xây xong hai trụ hoặc khi bấm Bỏ qua (TUT-08, TUT-15), ghi save ngay (SAV-04). Từ đó mọi run có trụ có sẵn (mục 3.2.1). Thiếu trường thì coi là false (SAV-10). Cấu trúc save không đổi nên save_version vẫn là 1.

### 3.12.2 Quy trình ghi

1. Serialize data, tính checksum, ghi ra endlesswar_save.tmp.
2. Đọc lại endlesswar_save.tmp, kiểm tra parse và checksum. Sai thì hủy, giữ bản cũ.
3. Nếu endlesswar_save.json tồn tại: sao chép thành endlesswar_save.bak.
4. Thay endlesswar_save.json bằng endlesswar_save.tmp (xóa bản cũ trước rồi đổi tên nếu nền tảng không cho ghi đè).

| **ID** | **Đặc tả** |
| --- | --- |
| SAV-01 | **Thứ tự tải:** endlesswar_save.json, endlesswar_save.tmp (nếu hợp lệ), endlesswar_save.bak. Bản đầu tiên qua checksum và version được dùng |
| SAV-02 | Tất cả hỏng: thông báo, "Tạo save mới", giữ tệp hỏng đổi tên .corrupt |
| SAV-03 | Ghi một luồng có hàng đợi. Nhiều yêu cầu gần nhau gộp thành một lần ghi mới nhất |
| SAV-04 | **Thời điểm ghi:** xác nhận StartSelect \[Should], SUMMARY mỗi wave, RunEnd, mua ở shop, kích hoạt buff \[Should], hoàn tất tutorial. **Không ghi trong COMBAT** |
| SAV-05 | Ghi ở SUMMARY hoàn tất trước khi hiển thị màn tổng kết |
| SAV-06 | Dọn endlesswar_save.tmp mồ côi khi khởi động (sau khi xét SAV-01) |

### 3.12.3 Migration

MVP chỉ có save_version = 1 nên chưa cần migration. Khi phát hành bản có save_version = 2 trở lên thì phải làm SAV-07 và SAV-08 trước. SAV-09 đến SAV-11 vẫn là MVP vì rẻ và bảo vệ dữ liệu.

| **ID** | **Đặc tả** |
| --- | --- |
| SAV-07 | **\[Should]** save_version là số nguyên tăng dần. Mỗi lần đổi cấu trúc thêm migrate_vN_to_vN+1, chạy nối tiếp |
| SAV-08 | **\[Should]** Trước migrate, sao chép thành save.premigrate.bak. Migrate lỗi thì dùng bản này |
| SAV-09 | save_version lớn hơn version hỗ trợ: từ chối nạp, **không ghi đè**, báo cập nhật game |
| SAV-10 | Trường thiếu: dùng mặc định, không coi là hỏng |
| SAV-11 | Trường thừa: giữ nguyên khi ghi lại |

### 3.12.4 Khôi phục run bị gián đoạn

Khi khởi động, **trước** MainMenu, nếu run_in_progress = true:

1. Chốt run như ABANDONED với prestige_gain = floor(prestige_pending × conversion_rate × start_mult). Không có buffer (PRS-05).
2. Cập nhật max_wave_cleared, best_by_start, prestige_balance.
3. Đặt run_in_progress = false, ghi save.
4. Hiện hộp thoại một lần: "Phiên chơi trước bị gián đoạn, đã quy đổi X danh vọng".

\[Should] Buff đã kích hoạt trước sự cố đã bị trừ. Buff chỉ nạp chưa kích hoạt không mất.

### 3.12.5 Edge case save

| **ID** | **Tình huống** | **Xử lý** |
| --- | --- | --- |
| SAV-12 | Ổ đĩa đầy, không quyền ghi | Giữ trong bộ nhớ, thông báo lỗi kèm "Thử lại". RunEnd có "Tiếp tục không lưu" kèm cảnh báo. Mua shop bị hoàn tác |
| SAV-13 | Tắt game giữa lúc ghi | Quy trình 4 bước và SAV-01 đảm bảo không có trạng thái nửa vời |
| SAV-14 | Sửa tay endlesswar_save.json | Checksum sai, chuyển sang .bak |
| SAV-15 | Chạy hai phiên bản cùng lúc | "Bản sau thắng", không khóa tệp ở MVP |
| SAV-16 | Xóa tiến trình | Xác nhận hai bước, đổi tên save.deleted, không xóa settings.cfg |
| SAV-17 | Chuyển máy | Copy thư mục user:// là đủ, **trừ auth.cfg** (phiên đăng nhập không dùng được ở máy khác, phải đăng nhập lại; ACCT-03). Có tài khoản thì chuyển máy bằng đăng nhập và đồng bộ (ACCT-05) |
| SAV-18 | Đồng hồ hệ thống đổi | Không ảnh hưởng |
| SAV-19 | Giá trị vô lý (số âm, cấp vượt max) | Kẹp về khoảng hợp lệ, ghi log |

## 3.13 Tài khoản và đồng bộ profile \[MVP rút gọn]

Mục đích: thêm yếu tố online cho game. Tài khoản chỉ là lớp bổ sung trên nền save cục bộ. Game luôn chơi được đầy đủ khi không có tài khoản hoặc không có mạng. Dữ liệu đồng bộ nhỏ: profile, meta, flags. Trạng thái run không đồng bộ (RUN-01). **Phạm vi MVP:** đăng nhập, đồng bộ profile (lấy bản có revision cao hơn) và bảng xếp hạng top 50. Phần mở rộng đánh dấu \[Should].

| **ID** | **Đặc tả** | **Tag** |
| --- | --- | --- |
| ACCT-01 | **SaveRepository.** Mọi thao tác đọc ghi tiến trình đi qua một giao diện SaveRepository với hai bản cài đặt: LocalSaveRepository (mục 3.12, bắt buộc) và CloudSaveRepository. Tách giao diện này là việc kiến trúc rẻ, làm từ Tuần 6 để không phải sửa lại save/load khi thêm tài khoản | MVP (kiến trúc) |
| ACCT-02 | **Chơi khách.** Trạng thái mặc định là GUEST. Mọi chức năng chơi được như cũ, không có hạng trên bảng xếp hạng. Đăng nhập là tùy chọn, từ MainMenu hoặc Settings | MVP |
| ACCT-03 | **Đăng ký, đăng nhập, đăng xuất** bằng email và mật khẩu qua dịch vụ xác thực có sẵn của nhà cung cấp backend. Client không tự lưu mật khẩu, không chứa khóa quản trị, chỉ dùng khóa công khai. Phiên đăng nhập (token, có hạn dùng và được làm mới) lưu ở tệp riêng user://auth.cfg, **không nằm trong endlesswar_save.json** và không nằm trong quy trình chuyển máy (SAV-17). Đăng xuất xóa auth.cfg và về GUEST. Khởi động thử khôi phục phiên, không được thì về GUEST và báo nhẹ | MVP |
| ACCT-04 | **Dữ liệu đồng bộ:** profile, meta (levels, unlocks, buff_stock), flags (gồm tutorial_done, nên tutorial chỉ chạy một lần theo tài khoản dù đổi máy). **Không đồng bộ:** run_flag, settings.cfg, mọi trạng thái trong run, auth.cfg. endlesswar_save.json thêm ba trường ngoài `data` (mục 3.12.1): revision, updated_at, device_id | MVP |
| ACCT-05 | **Thời điểm đồng bộ:** khi đăng nhập (kéo và so sánh), ở RunEnd, sau mỗi lần mua ở shop. Không đồng bộ trong COMBAT (SAV-04). SUMMARY mỗi wave chỉ ghi cục bộ. Ghi cloud chạy bất đồng bộ, luôn ghi cục bộ trước, không chặn UI và không làm ghi save vượt ACP-06 | MVP |
| ACCT-06 | **Xung đột (MVP rút gọn).** Cùng device_id thì bản có revision cao hơn thắng. Khác device_id và revision lệch nhau: lấy bản có revision cao hơn, hiện thông báo "Đã dùng dữ liệu từ máy khác" và giữ bản kia ở save.conflict.bak. \[Should] Hộp thoại cho người chơi chọn bản giữ lại, hiển thị prestige_balance, max_wave_cleared, total_runs của mỗi bên. **Không tự gộp** danh vọng | MVP / SHOULD |
| ACCT-07 | **Mất mạng (MVP rút gọn).** Chơi tiếp bình thường. Yêu cầu gửi lỗi thì thử lại ở lần RunEnd hoặc mua shop kế tiếp (gửi bản mới nhất). Timeout sync_timeout 10 s. MainMenu hiện biểu tượng kèm chữ trạng thái: GUEST, SYNCED, SYNCING, OFFLINE, ERROR. Lỗi mạng không bao giờ chặn RunEnd hay mua shop. \[Should] Hàng đợi nền gộp bản mới nhất (như SAV-03) và trạng thái CONFLICT | MVP / SHOULD |
| ACCT-08 | **Đăng nhập lần đầu.** Máy đã có profile cục bộ và tài khoản chưa có dữ liệu: hỏi "Tải profile cục bộ lên tài khoản". Cả hai bên đều có dữ liệu: theo ACCT-06 | MVP |
| ACCT-09 | **Bảo mật.** Chỉ dùng HTTPS, kiểm tra phản hồi, không ghi token vào log (NAV-14, xuất log lỗi). Phân quyền theo hàng ở phía máy chủ: mỗi tài khoản chỉ đọc và ghi dữ liệu của mình. Máy chủ từ chối giá trị vô lý như SAV-19. Chống gian lận chỉ ở mức LBD-06 | MVP |
| ACCT-10 | **Phân công.** Phía máy chủ (bảng dữ liệu, xác thực, phân quyền, API) do vai Player & Combat đảm nhiệm: xác thực và bảng dữ liệu ở Tuần 6, API đồng bộ và bảng xếp hạng ở Tuần 10, ổn định và tài liệu API ở Tuần 11. Phía client (SaveRepository, màn Login, SyncService, màn Leaderboard) do vai UI/UX & Meta | MVP |
| ACCT-11 | **Cắt giảm.** Online không còn là hạng mục cắt đầu tiên. Trễ Mốc B1 thì cắt theo Phụ lục C mục 17 trước. Chỉ cắt online khi vẫn trễ sau Mốc B2, theo thứ tự: bảng xếp hạng (mục 3.14), rồi đồng bộ (ACCT-04 đến ACCT-08). Giữ ACCT-01, ACCT-02, ACCT-12 | MVP |
| ACCT-12 | **Cờ bật tắt.** GameConfig có online_enabled và backend_url (không hard-code trong mã). online_enabled = false hoặc máy chủ không khả dụng thì ẩn nút Đăng nhập và Bảng xếp hạng hoặc báo "Không kết nối được", game chạy bình thường (demo và chấm điểm không phụ thuộc mạng) | MVP |

## 3.14 Bảng xếp hạng \[MVP rút gọn]

Làm sau ACCT-03 đến ACCT-05 (cần đăng nhập và đồng bộ chạy). Một bảng dữ liệu, một màn hình (SCR-19).

| **ID** | **Đặc tả** | **Tag** |
| --- | --- | --- |
| LBD-01 | Mỗi tài khoản có đúng một dòng: **lượt chơi tốt nhất**, không cộng dồn qua các lượt | MVP |
| LBD-02 | **Lượt hợp lệ để gửi điểm:** đã đăng nhập; start_wave = 1 (mốc xuất phát cao có start_mult khác nên không so được); kết thúc bình thường ở RunEnd, tính cả ba loại kết thúc (bỏ cuộc ở wave N cũng chỉ được waves_cleared = N-1 như thua nên không có lợi thế); **không phải lượt bị gián đoạn rồi khôi phục (FLOW-03)** vì thiếu run_elapsed đầy đủ. Tài khoản khách không có hạng | MVP |
| LBD-03 | Gửi điểm ở RunEnd, sau khi save cục bộ hoàn tất (END-05). Thất bại thì thử lại ở RunEnd kế tiếp (ACCT-07) | MVP |
| LBD-04 | **Thứ tự xếp:** (1) waves_cleared giảm dần; (2) hòa thì run_elapsed (RUN-02: game time chỉ của COMBAT và BOSS_COMBAT, đã nhân time_scale nên tua nhanh, thời gian suy nghĩ ở PREP và Hazard Trial không ảnh hưởng) nhỏ hơn xếp trên; (3) vẫn hòa thì ai gửi trước (timestamp của máy chủ, không dùng giờ máy) xếp trên. Nhờ vậy mọi hạng đều duy nhất | MVP |
| LBD-05 | **Dữ liệu gửi:** waves_cleared, run_elapsed, run_seed, game_version, tên hiển thị. Điểm lấy từ RunState của lượt vừa chơi, **không lấy từ max_wave_cleared trong save** (save chỉ có checksum chống hỏng tệp, sửa tay được) | MVP |
| LBD-06 | **Kiểm tra ở máy chủ (mức rẻ):** run_elapsed + lbd_elapsed_tolerance (1 s) ≥ lbd_min_seconds_per_wave (15 s) × waves_cleared, và waves_cleared không vượt trần hợp lý do máy chủ cấu hình. Không mô phỏng lại game. Sàn này không bao giờ từ chối một lượt chơi thật: mỗi wave đã hoàn thành có COMBAT hoặc BOSS_COMBAT kéo dài ít nhất spawn_duration(w) game time (SPN-15), spawn_duration của mọi wave không nhỏ hơn lbd_min_seconds_per_wave (BAL-05 kiểm wave 1-30; công thức từ wave 31 luôn ≥ 15 s), và run_elapsed đếm đúng phần thời gian đó (RUN-02). Đổi lbd_min_seconds_per_wave thì phải giữ nó ≤ spawn_duration nhỏ nhất. Gian lận tinh vi hơn được chấp nhận ở phạm vi đồ án (Phụ lục C) | MVP |
| LBD-07 | **Phiên bản.** Mỗi dòng ghi game_version. Bảng chỉ hiển thị bản đang chạy, và phát hành bản đổi cân bằng thì bảng mới bắt đầu lại, để điểm không so sánh sai giữa hai bản cân bằng | MVP |
| LBD-08 | **Hiển thị.** Top lbd_top_n (50) và hạng của chính người chơi (hiện thêm một dòng riêng nếu ngoài top 50): hạng, tên hiển thị, waves_cleared, run_elapsed dạng mm:ss. Làm mới khi mở màn. Lỗi mạng: "Không tải được bảng xếp hạng" kèm nút Thử lại. Khách: nút "Đăng nhập để có hạng" | MVP |
| LBD-09 | **Tên hiển thị** dài từ display_name_min_len (3) đến display_name_max_len (16) ký tự, đặt khi đăng ký. Bộ lọc tên phản cảm và chức năng báo cáo là \[Should] (Phụ lục C mục 34) | MVP |
| LBD-10 | Bảng xếp hạng phản ánh cả tiến triển meta (FORT_HP, CMD_HP...), không chỉ kỹ năng. Chấp nhận ở phạm vi này, không làm bảng riêng không tính meta | MVP |

Từ v2.0 thứ tự xếp giữ nguyên theo waves_cleared: run đã thắng và sống lâu trong endless tự xếp trên run thua trước wave 30. Không có cột riêng cho số lần thắng.

## 3.15 Hazard Trial \[MVP]

Hazard Trial là phòng thử thách tùy chọn trong PREP. Người chơi đánh trước 5 quái của wave sắp tới để lấy gold, XP và Mithril, nhưng chỉ số trong phòng không ảnh hưởng chỉ huy bên ngoài. Phòng là một khu vực riêng do Level đặt (hazard_room, mục 6.7), quân của wave thật không vào được.

| **Tham số** | **Giá trị khởi điểm** | **Ghi chú** |
| --- | --- | --- |
| hazard_enemy_count | 5 | Số quái trong nhóm (HZT-02) |
| hazard_damage_cap_pct | 0.10 | Trần mỗi lần gây sát thương của hero, theo máu tối đa của con nhiều máu nhất nhóm (HZT-05) |
| mithril_reward(w) | 1 mỗi wave | Bảng thưởng theo wave (WaveRewardTable), wave 1-30 (MTH-02) |
| hazard_boss_escorts | 4 | Wave boss: boss cộng 4 quân (HZT-02) |

| **ID** | **Đặc tả** | **Tag** |
| --- | --- | --- |
| HZT-01 | **Vào phòng.** Chỉ trong PREP (kể cả PREP boss), **một lần mỗi wave** (hazard_used, reset khi vào PREP của wave mới), chỉ khi chỉ huy ở Frontline, không Pause, không có hộp thoại đang mở. Tháp Hazard Trial đặt gần Fortress (hazard_portal). Vì ở PREP nhân vật đứng yên (CAM-02), người chơi vào bằng phím E (action hazard_enter) hoặc bấm chuột vào Tháp, không cần đi tới Tháp. Vào phòng thì đóng panel và hộp thoại đang mở (BLD-05, SCR-14), wave FSM chuyển PREP sang HAZARD_TRIAL, phát hazard_trial_entered (EVB-40). Thiếu điều kiện thì cổng xám kèm lý do (HUD-23) | MVP |
| HZT-02 | **Nhóm quái.** hazard_enemy_count (5) con lấy từ các loại quân của wave sắp tới (wave_index của PREP này, theo kịch bản SPN-13 hoặc danh sách đã sinh từ wave 31), loại nào cũng có ít nhất 1 con; các con còn lại rút theo tỷ lệ số lượng từng loại trong wave bằng RNG riêng seed = hash(run_seed, "hazard", wave_index). Wave boss: nhóm gồm boss cộng hazard_boss_escorts (4) quân của wave đó, mỗi loại hộ tống ít nhất 1 con. Wave chỉ có ít loại hơn số chỗ thì lặp lại các loại đã có. Danh sách nhóm hiện ở cổng trước khi vào | MVP |
| HZT-03 | **Chỉ số quái** y như quân của wave đó ngoài wave thật: cùng EnemyData, BossData, cùng hệ số hp_mult, dmg_mult, speed_mult của wave (mục 3.7.6), cùng trait (mục 3.7.8). Boss trong phòng có pha giáp như thường (mục 3.8.4) nhưng không có BOSS_INTRO, không có boss_timer và không Cuồng nộ | MVP |
| HZT-04 | **Không đụng wave thật.** Giết quái trong phòng không làm wave thật ít quân đi (spawn_queue của COMBAT không đổi), không cộng uy tín, không tính vào run_kills, run_bosses_defeated hay profile.stats. Boss trong phòng cho boss_gold và XP boss như ngoài (GLD-10, XP-06) nhưng không có boss_prestige, không +1 Emergency repair (BRW-07) và không rơi vũ khí (WPN-11) | MVP |
| HZT-05 | **Giới hạn sát thương 10%.** Mỗi lần hero gây sát thương lên một quái trong phòng (mỗi đòn trên mỗi mục tiêu, mỗi tick vùng cháy, mỗi tia Chain Lightning, mỗi tick Burn) bị kẹp tối đa floor(hazard_damage_cap_pct × hp_cap_ref). hp_cap_ref là máu tối đa của con nhiều máu nhất trong nhóm, chốt lúc tạo nhóm; với boss chỉ tính core_hp (không cộng armor_hp). Kẹp áp sau mọi hệ số (DMG-06, DMG-01). Áp cho mọi nguồn sát thương của hero trong phòng (đòn thường, skill, hiệu ứng vũ khí). Ngoài phòng không áp | MVP |
| HZT-06 | **Chỉ số độc lập, một chiều.** Lúc vào, phòng chép chỉ số hiện tại của chỉ huy: commander_hp, commander_max_hp, commander_level, ô skill và level, StatBlock, vũ khí đang trang bị, cooldown hiện tại. Trong phòng chỉ bản sao này thay đổi (máu mất, cooldown, hiệu ứng, Lifesteal). Trạng thái bên ngoài đóng băng trong lúc ở phòng. Rời phòng thì bỏ bản sao, chỉ huy về PREP với đúng trạng thái lúc vào. Chỉ phần thưởng (gold, XP, Mithril) mang ra (HZT-08) | MVP |
| HZT-07 | **Kết thúc phòng.** Ba kết quả: WON khi mọi con trong nhóm đã **xử lý xong** (bị diệt hẳn hoặc tự nổ, HZT-16) và HP bản sao còn trên 0; LEFT khi bấm nút Rời phòng (HUD-22); DIED khi HP bản sao về 0 (DEAD-11). Kết quả chốt **một lần ở cuối frame** (như END-01): trong cùng frame có nhiều điều kiện thì ưu tiên DIED, rồi WON, rồi LEFT; sau khi đã chốt, điều kiện đến sau bị bỏ qua. Với mọi kết quả, hero bị đưa ra ngoài, không mất gì, wave FSM về PREP, hazard_used = true, phát hazard_trial_exited (EVB-41). WON hiện toast kết quả rồi tự đưa ra. Esc trong phòng mở Pause, không rời phòng (INP-03) | MVP |
| HZT-08 | **Phần thưởng.** Gold (GLD-10) và XP (XP-06) tính theo số con đã giết (quân tự nổ không tính, HZT-16), cộng khi rời phòng với mọi kết quả. WON cộng thêm mithril_reward(w) Mithril (MTH-02). Gold và XP tạm tính hiện trên HUD trong phòng (HUD-22) | MVP |
| HZT-09 | **Không vào lại.** Sau khi rời phòng với bất kỳ kết quả nào, Tháp khóa đến PREP của wave sau. Tháp hiện trạng thái "Đã dùng ở wave này" | MVP |
| HZT-10 | **Hành động trong phòng.** Như Frontline ở COMBAT: di chuyển, đánh, Dodge, Battle Cry, skill chủ động. Không xây, nâng, bán, sửa, đổi vũ khí, đổi priority; Tab bị khóa (mục 3.5.5); không có Emergency repair; không có Trạm hồi lực (HLT-13). Tua x1/x2/x3 dùng như COMBAT; vào và ra phòng không đổi mức tua | MVP |
| HZT-11 | **Camera.** Camera cố định khung phòng, không bám nhân vật, không dịch bằng phím; WASD di chuyển nhân vật (CAM-16) | MVP |
| HZT-12 | **Pause, thoát.** Pause được (TIME-02); ở Pause mọi panel chỉ đọc (TIME-08). Abandon hay Quit trong phòng chốt run như thường (FLOW-04), phần thưởng phòng chưa rời thì mất. Crash trong phòng xử lý theo FLOW-03 | MVP |
| HZT-13 | **Ngoài phòng.** Trong lúc ở phòng, bản đồ chính không có quân, Fortress và tower không đổi. Không có cách nào sinh quân thật trước khi bấm Bắt đầu wave | MVP |
| HZT-14 | **AI trong phòng.** Mục tiêu duy nhất của quái là chỉ huy (không có tower, Barricade, Fortress trong phòng). Sniper, Archer bắn chỉ huy; Suicide Squad lao vào chỉ huy rồi nổ; Brute ủi về phía chỉ huy (EN-25); Assassin hiện mờ như ngoài (EN-20). Battle Cry vẫn taunt quân thường. Boss dùng bảng mục tiêu riêng với PLAYER là lựa chọn duy nhất | MVP |
| HZT-15 | **Giao dịch đang dở.** Vào phòng đúng frame đang xác nhận giao dịch (xây, bán, sửa) thì giao dịch hoàn tất trước hoặc bị từ chối (BLD-02) | MVP |
| HZT-16 | **Khi nào một con tính là xử lý xong** (cho WON ở HZT-07). (a) **Bị diệt hẳn:** HP về 0 và không còn lần hồi sinh; Undead đang nằm chờ hồi sinh (EN-26) chưa xong. (b) **Tự nổ:** Suicide Squad đã nổ (EN-22) thì biến mất và tính là xong, nhưng không cho gold, XP và không tính vào số con đã giết. (c) **Captain chờ nổ:** Suicide Squad Captain có HP về 0 thì gold và XP tính ngay lúc đó như ngoài (EN-23), nhưng chỉ tính là xong khi vụ nổ sau explode_windup đã gây sát thương; trong lúc chờ nổ phòng chưa WON, và nếu vụ nổ làm HP bản sao về 0 thì kết quả là DIED. Số con đã giết (kills ở EVB-41, gold và XP ở HZT-08) chỉ đếm (a) và (c). Nhóm toàn quân tự nổ hết mà chỉ huy còn sống vẫn là WON và vẫn có Mithril (MTH-02) | MVP |


# 4. YÊU CẦU GIAO DIỆN NGOÀI

## 4.1 Giao diện người dùng

### 4.1.1 Nguyên tắc

| **ID** | **Đặc tả** |
| --- | --- |
| UI-01 | Độ phân giải thiết kế 1920x1080, stretch mode = canvas_items, aspect = expand. Hỗ trợ 1280x720 đến 3840x2160. HUD neo vào góc hoặc cạnh |
| UI-02 | Animation UI chạy theo **thời gian thực**. Số liệu gameplay hiển thị lấy từ game time |
| UI-03 | Mọi chuỗi chữ qua tr(), không viết cứng (LOC-01) |
| UI-04 | UI đăng ký tín hiệu qua EventBus (fortress_hp_changed, gold_changed, state_changed, boss_timer_changed...; danh mục chuẩn ở mục 6.9) và chỉ vẽ, không đọc trực tiếp node gameplay |
| UI-05 | Thông tin thiết yếu không dựa vào màu đơn thuần: luôn kèm biểu tượng, hình dạng hoặc chữ |
| UI-06 | UI không quá 10% thời gian frame |
| UI-07 | Lề an toàn 3% mỗi cạnh. Không đặt thông tin quan trọng ở giữa màn hình trừ banner tạm thời |

### 4.1.2 Danh sách màn hình

| **ID** | **Màn hình** | **Nội dung** | **Đi tới** |
| --- | --- | --- | --- |
| SCR-01 | Boot / Splash | Logo, thanh tải, kiểm tra save | MainMenu |
| SCR-02 | MainMenu | Play, Meta Shop, Settings, Quit. Số dư danh vọng và kỷ lục. Nút Đăng nhập hoặc tên tài khoản, nút Bảng xếp hạng, biểu tượng trạng thái đồng bộ (ACCT-07) | RunLoading (MVP), StartSelect \[Should], MetaShop, Settings, Login (SCR-18), Leaderboard (SCR-19) |
| SCR-03 | StartSelect \[Should] | Thẻ mốc, nạp buff | RunLoading, Back |
| SCR-04 | MetaShop | 4 mục MVP (thêm mục Should khi đã làm), số dư, chi tiết | Back |
| SCR-05 | Settings | 4 tab MVP (Âm thanh, Đồ họa, Tiếp cận, Tài khoản), thêm tab Điều khiển chỉ đọc, Dữ liệu và Gameplay \[Should] (mục 4.6) | Back |
| SCR-06 | RunLoading | Thanh tải, mẹo chơi | Run |
| SCR-07 | HUD trong Run | Mục 4.1.3 | Pause, RunEnd |
| SCR-08 | PauseMenu | Resume, Settings, Abandon, Quit | Run, Settings, RunEnd |
| SCR-09 | SummaryPanel | Tổng kết wave, XP, Cấp Chỉ huy, lượt chọn chờ, vũ khí nhận được (WPN-11) | Màn thắng (SCR-20) ở wave victory_wave, REWARD_PICK (SCR-17) hoặc wave kế |
| SCR-10 | BossIntro overlay | Tên boss, miễn nhiễm pha 1 | BOSS_COMBAT |
| SCR-11 | RunEnd (thua) | Mục 3.2.4, run_result = DEFEAT: "Thất bại ở wave N" | RunLoading, MetaShop, MainMenu |
| SCR-12 | Hộp thoại hệ thống | Xác nhận, lỗi save, khôi phục run, cảnh báo hiệu năng | Đóng |
| SCR-17 \[MVP] | RewardPick | 3 thẻ, thanh slot hiện tại, \[Should] nút Reroll (còn n), nút Bỏ qua (có xác nhận), dòng giải thích tĩnh cách chọn 3 chọn 1 | PREP |
| SCR-18 | Login | Đăng nhập, đăng ký, tiếp tục chơi khách (ACCT-02, ACCT-03). Thông báo lỗi nêu rõ nguyên nhân (sai mật khẩu, mất mạng, email đã dùng) | MainMenu |
| SCR-20 \[MVP] | Màn thắng (giữa run) | Hiện một lần khi hoàn thành victory_wave (END-07): tiêu đề chiến thắng, waves_cleared, run_elapsed (thời gian chiến đấu, RUN-02), quân đã diệt, gold kiếm được, uy tín đang tích (chưa quy đổi), bosses_defeated, Cấp Chỉ huy, vũ khí đã có. Game dừng (TIME-11, lý do VICTORY). Một nút "Chơi tiếp (endless)", phát victory_continue_requested (EVB-46); không tự đóng, không đếm ngược | REWARD_PICK hoặc PREP của wave kế (WAVE-13) |
| SCR-21 \[MVP] | RunEnd (endless) | Mục 3.2.4, run_result = SURVIVED: "Sống sót đến wave N", cùng các chỉ số của RunEnd và nhãn đã thắng | RunLoading, MetaShop, MainMenu |
| SCR-19 | Leaderboard | Top 50 và hạng của chính người chơi (LBD-08). Nút Làm mới, Thử lại khi lỗi | MainMenu |

| **ID** | **Luật điều hướng** |
| --- | --- |
| SCR-13 | Back và Esc cùng tác dụng ở mọi màn ngoài Run. Esc trong Run theo INP-03 |
| SCR-14 | Hộp thoại xác nhận dùng một mẫu chung: tiêu đề, hậu quả cụ thể, nút hủy (mặc định focus), nút xác nhận. Hộp thoại giao dịch (bán, sửa bằng Mithril, hủy xây) chỉ hợp lệ trong PREP: (1) khi PREP kết thúc hoặc khi vào Hazard Trial thì tự đóng như hủy, không thực hiện giao dịch (trong lúc có hộp thoại giao dịch, nút Bắt đầu wave và Tháp Hazard Trial đã xám theo WAVE-11, HZT-01, nên ca này chỉ xảy ra do lỗi hoặc tự động); (2) bấm Xác nhận ở đúng frame chuyển state theo BLD-02 (nguyên tử: hoàn tất hoặc bị từ chối, không có trạng thái giữa); (3) kiểm tra lại state PREP và trạng thái slot ngay lúc xác nhận, không dựa vào lúc mở hộp thoại. PREP không có đồng hồ nên hộp thoại không ảnh hưởng thời gian. Hộp thoại hệ thống không liên quan giao dịch (SET-01, Abandon, thoát) không bị ràng buộc này |
| SCR-15 | Chuyển màn fade 0.25 s (thời gian thực), khóa input trong lúc fade |
| SCR-16 | Menu điều hướng bằng chuột, mũi tên và Enter. Focus luôn rõ. ui_focus_next (Tab) **vô hiệu trong Run** |

### 4.1.3 HUD trong run

| **Vùng** | **Thành phần** |
| --- | --- |
| Trên trái | Thanh HP Fortress (lớn, có số), HP chỉ huy (nhỏ hơn), biểu tượng Aura cạnh HP chỉ huy (HUD-17), thanh XP ngay dưới HP chỉ huy (HUD-15) |
| Trên giữa | Số wave (kèm "/ 30" trước khi thắng, nhãn "Endless" sau khi thắng), trạng thái, đồng hồ boss, bộ đếm quân |
| Trên phải | Gold (kèm "+xx"), ô Mithril (HUD-20), cụm nút tua nhanh x1/x2/x3 (HUD-14), nút Pause |
| Dưới trái | Thanh kỹ năng theo chế độ: hai hàng ô skill (HUD-16) với ô vũ khí bên phải (HUD-21), dưới đó là ô Emergency repair (HUD-13); biểu tượng chế độ kèm cooldown chuyển |
| Dưới giữa | Panel ngữ cảnh, nút Bắt đầu wave (HUD-19). Trong Hazard Trial: nút Rời phòng (HUD-22) |
| Dưới phải | \[Should] Buff đang hoạt động và nút kích hoạt buff |
| Giữa (tạm thời) | Banner cảnh báo và thông báo wave |

Không có minimap.

**Thanh kỹ năng:** Frontline gồm Đánh (chuột trái), Dodge (Space), Battle Cry (Q), **Skill 1-3**, Đổi chế độ (Tab), ô vũ khí đang trang bị (HUD-21). Commander gồm Emergency repair (R, hiển thị **số lượt còn lại n/3** cùng cooldown) và Đổi chế độ (Tab); **skill 1-3 hiển thị xám kèm biểu tượng khóa**. Cooldown có vòng quét kèm **số giây**.

| **Thành phần** | **PREP** | **HAZARD\_TRIAL** | **COMBAT** | **BOSS\_INTRO** | **BOSS\_COMBAT** | **SUMMARY** | **REWARD\_PICK** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| HP Fortress, chỉ huy | Có | HP bản sao trong phòng; HP Fortress mờ | Có | Có | Có | Có | Tối thiểu |
| Đồng hồ | Không (PREP không giới hạn) | Không | Clear time tạm tính (mờ) | Boss timer đầy, đứng yên | Boss timer chạy, về 0 thì nhãn CUỒNG NỘ | Không | Không |
| Nút Bắt đầu wave | Có | Ẩn | Ẩn | Ẩn | Ẩn | Ẩn | Ẩn |
| Tháp Hazard Trial (chỉ báo) | Có | Ẩn | Ẩn | Ẩn | Ẩn | Ẩn | Ẩn |
| Nút Rời phòng, số quái còn, gold và XP tạm tính | Ẩn | Có | Ẩn | Ẩn | Ẩn | Ẩn | Ẩn |
| Gold, Mithril | Có | Có | Có | Có | Có | Có | Tối thiểu |
| Ô vũ khí | Có (đổi được) | Chỉ đọc | Chỉ đọc | Chỉ đọc | Chỉ đọc | Chỉ đọc | Ẩn |
| Tua tốc độ | Có | Có | Có | Khóa | Có | Khóa (về x1) | Khóa (về x1) |
| Panel Build/Tower | Có | Ẩn | Chỉ đọc | Ẩn | Chỉ đọc | Ẩn | Ẩn |
| Thanh HP boss | Ẩn | Có nếu nhóm có boss | Ẩn | Hiện tên | Có | Ẩn | Ẩn |
| Thanh XP, ô skill | Có | Có (của bản sao) | Có | Có | Có | Có | Có (màn SCR-17) |
| Kích hoạt buff \[Should] | Có | Ẩn | Ẩn | Ẩn | Ẩn | Ẩn | Ẩn |

Game dừng ở REWARD_PICK (RWP-01) và ở màn thắng (SCR-20).

| **ID** | **Luật HUD** |
| --- | --- |
| HUD-01 | Thanh HP Fortress đổi hình dạng dưới 30% (nhấp nháy viền, biểu tượng) |
| HUD-02 | Thanh HP boss hai đoạn (giáp xám, lõi đỏ), biểu tượng kháng cạnh thanh |
| HUD-03 | Số đếm quân = enemies_alive + len(spawn_queue) trên tổng của wave. Boss hiển thị riêng |
| HUD-04 | Đồng hồ boss đổi màu và cỡ chữ theo mốc: T-30 vàng, T-10 đỏ cỡ lớn, kèm biểu tượng. Khi Cuồng nộ: nhãn "CUỒNG NỘ" (ENR-05) |
| HUD-05 | Nút bị khóa: xám kèm lý do khi rê chuột. Không phát âm lỗi quá 1 lần mỗi 0.5 s |
| HUD-06 | Cooldown chuyển chế độ trên nút Tab. Bấm trong cooldown chỉ nhấp nháy số giây |
| HUD-07 | \[Should] Buff đang hoạt động: biểu tượng và nhãn. Tooltip nêu chưa trừ lượt nếu chưa kích hoạt |
| HUD-08 | Commander mode: viền màn hình nhạt xanh, biểu tượng chế độ và biểu tượng khiên "bất khả xâm phạm" cạnh thanh HP chỉ huy |
| HUD-09 | **Thanh máu quân:** chỉ hiện khi bị thương hoặc rê chuột, ẩn sau 3 s. Tối đa **40** thanh cùng lúc, ưu tiên quân gần chỉ huy và bị nhắm. Boss dùng thanh HUD. Object pool |
| HUD-10 \[MVP rút gọn] | Chỉ báo ngoài màn hình ở mép khung: mũi tên boss chưa vào khung, mũi tên Fortress bị tấn công khi camera ở xa (Frontline bám nhân vật nên Fortress thường ngoài khung). Mũi tên có biểu tượng kèm màu (UI-05). \[Should] Bản đầy đủ: thêm quân lẻ sau 60 s |
| HUD-11 | \[ĐÃ XÓA v1.9] Biểu tượng regen Commander mode. Regen 2%/s bị bỏ, thay bằng Trạm hồi lực (3.6.6) |
| HUD-12 | F1 bật/tắt HUD (cho ảnh chụp), không ảnh hưởng gameplay |
| HUD-13 | **Ô Emergency repair:** hiển thị n/3 bằng ba chấm kèm số, vòng quét cooldown 60 s kèm số giây. Khóa thì xám kèm lý do khi rê chuột: "Đang hồi (còn xx s)", "Hết lượt. +1 lượt khi diệt boss", "Fortress đầy HP", "Chỉ dùng ở Commander mode". Khi nhận +1 lượt: viền sáng 0.3 s và toast T3 "Emergency repair +1 (n/3)". Thông tin không chỉ dựa vào màu (UI-05) |
| HUD-14 | **Cụm nút tua nhanh** (thay cho phím tắt): ba nút x1, x2, x3, nút đang hoạt động sáng và có viền. Bấm x2 hoặc x3 để **bật** mức đó. Bấm lại đúng nút đang bật để **tắt** (về x1). Bấm nút mức khác thì chuyển thẳng, không qua x1. Bấm x1 luôn về x1. Nút không nhận focus bàn phím nên Space, Enter không kích hoạt được (INP-04). Khi bị khóa (BOSS_INTRO, SUMMARY, REWARD_PICK, TIME-03): nút x2 và x3 xám kèm biểu tượng khóa và tooltip lý do, nút x1 sáng. Sau khi mở khóa ở PREP kế tiếp, các nút ở trạng thái tắt, người chơi bật lại nếu muốn |
| HUD-15 \[MVP] | Thanh XP dưới thanh HP chỉ huy: số cấp, % tiến trình, số lượt chọn đang chờ. Khi lên cấp: viền sáng 0.3 s và toast T3 "Lên cấp n (+1 lượt chọn)". Hiển thị tách hai màu **kèm họa tiết** cho XP từ chỉ huy và từ tower (UI-05) |
| HUD-16 \[MVP] | Hai hàng ô skill (3 chủ động với phím 1-3, 3 bị động) có icon, chấm level, quạt cooldown kèm số giây. Ô trống: viền nét đứt. Ở Commander mode ô chủ động xám kèm khóa |
| HUD-17 \[MVP] | Biểu tượng Aura ở góc cạnh thanh HP chỉ huy khi Aura hoạt động, kèm tooltip "+20% sát thương tower trong 12 m" |
| HUD-18 \[MVP] | **Trạng thái Trạm hồi lực** cạnh thanh HP chỉ huy khi có ít nhất 1 trạm: biểu tượng phím E kèm chữ trạng thái: "Sẵn sàng", "Giữ E (0.6 s)", "Đang hồi (+15 HP/s)", hoặc lý do không dùng được ("Quá xa trạm", "Đã đầy máu", "Chỉ dùng khi chiến đấu", "Trạm đã cạn", "Đang bị tấn công"), theo HUD-05. Kèm số trạm còn kho trên tổng (ví dụ 2/2). Không phụ thuộc màu (UI-05) |
| HUD-19 \[MVP] | **Nút Bắt đầu wave** ở dưới giữa, chỉ hiện ở PREP. Bấm thì phát wave_start_requested (EVB-38) và PREP kết thúc (WAVE-11). Ở wave boss nút ghi "Bắt đầu wave boss". Xám kèm lý do khi Pause, khi có hộp thoại giao dịch, khi tutorial chưa xây xong hai trụ (TUT-15) (HUD-05). Nút không nhận focus bàn phím (INP-04). Nếu chưa dùng Hazard Trial ở wave này, nút có dòng nhắc nhỏ "Chưa vào Hazard Trial", không chặn |
| HUD-20 \[MVP] | **Ô Mithril** cạnh gold: biểu tượng kèm số. Nhận Mithril: viền sáng 0.3 s. Ở PREP khi Fortress thiếu máu và mithril > 0, ô hiện nút nhỏ "Sửa thành" bên trái số Mithril. Bấm nút thì mở panel Fortress (PNL-04) giống như bấm vào Fortress trên bản đồ; việc sửa vẫn bấm trong panel, nút không tự trừ Mithril. Nút không nhận focus bàn phím (INP-04). Không phụ thuộc màu (UI-05) |
| HUD-21 \[MVP] | **Ô vũ khí** cạnh thanh kỹ năng: biểu tượng vũ khí đang trang bị và tên hiệu ứng, số vũ khí đã có trên 6 (kiếm gốc và 5 cây). Chuột trái vào ô ở PREP mở panel vũ khí (PNL-15). Ngoài PREP chỉ đọc kèm tooltip "Đổi vũ khí ở giai đoạn chuẩn bị". Chain Lightning hiện vòng cooldown kèm số giây (ACC-07) |
| HUD-22 \[MVP] | **HUD trong Hazard Trial:** nút "Rời phòng" ở dưới giữa (bấm một lần, không cần xác nhận, HZT-07), số quái còn trên 5 (con chưa xử lý xong theo HZT-16, Captain chờ nổ và Undead chờ hồi sinh vẫn tính là còn), gold và XP tạm tính, phần thưởng Mithril nếu thắng, nhãn "Chỉ số trong phòng không mang ra ngoài". Thanh HP chỉ huy hiển thị HP của bản sao. Khi kết thúc: toast kết quả (Thắng, Đã rời, Gục ngã) kèm phần thưởng |
| HUD-23 \[MVP] | **Tháp Hazard Trial** trên bản đồ ở PREP: biểu tượng trên cùng (như MSE-04), trạng thái "Sẵn sàng (E)", "Cần Frontline", "Đã dùng ở wave này" kèm biểu tượng; rê chuột hiện danh sách loại quái của nhóm (HZT-02) và phần thưởng Mithril. Ẩn ngoài PREP |
| HUD-24 \[MVP] | **Nút mũi tên ẩn/hiện kỹ năng** ngay trên hai hàng ô skill, chỉ có mũi tên, không có chữ: mũi tên xuống khi đang hiện (bấm để ẩn), mũi tên lên khi đã ẩn (bấm để hiện); tooltip ghi "Ẩn kỹ năng" hoặc "Hiện kỹ năng" (UI-05). Nút ẩn hoặc hiện cả hai hàng ô skill (HUD-16) và ô vũ khí (HUD-21), ô Emergency repair vẫn hiện. Chỉ ẩn phần hiển thị: phím 1-3 vẫn dùng skill, cooldown vẫn chạy, hiện lại thì đúng số giây còn lại. Ẩn ô vũ khí thì panel vũ khí đang mở cũng đóng. Nút không nhận focus bàn phím (INP-04), không có phím tắt. Run mới luôn hiện lại. Cooldown vẫn luôn có số khi đang hiện (ACC-07); ẩn là lựa chọn của người chơi như F1 (HUD-12) |

### 4.1.4 Panel tương tác

Mọi panel mở ở dưới giữa, không che hành lang.

| **ID** | **Panel** | **Nội dung** | **Mở khi** |
| --- | --- | --- | --- |
| PNL-01 | Build | Loại cho phép, giá, mô tả, chỉ số cấp 1, ghost preview kèm vòng tầm bắn. Slot RUINED: mục đầu là "Xây lại \[loại] cấp n" kèm tổng giá, hiện số thiếu nếu không đủ gold; cuối menu có nút "Dọn đổ nát" (CLR-01). Ô grid EMPTY khi grid đã đủ max_ground_buildings: các mục xây xám kèm lý do (BLD-08). Xây sẽ chặn kín đường: mục xây xám kèm lý do BLOCKS_PATH (BLD-10). Tutorial chưa xong: chỉ hai slot mặc định (BLD-11) | PREP, chọn slot hoặc ô grid |
| PNL-02 | Tower | Loại, cấp, HP, chỉ số hiện tại và cấp kế, Nâng cấp lên cấp kế kèm giá (xám kèm "Cần Chỉ huy cấp N" khi qua ranh giới bậc mà chưa đủ, UPG-06), bậc model hiện tại (TWR-17), Bán (xám kèm "Bán được từ wave 3" với trụ có sẵn, SELL-06), priority | PREP hoặc COMBAT, chọn tower |
| PNL-03 | Commander (priority) | 2 lựa chọn (First, Nearest); \[Should] 4 lựa chọn và nút "Áp dụng cho mọi tower cùng loại" | Chọn tower ở Commander hoặc PREP |
| PNL-04 | Fortress | HP, số Mithril đang có, nút "Sửa bằng Mithril (+20%)" (MTH-03), tooltip ghi sẵn số HP sẽ hồi và "Hồi thừa" khi thiếu dưới 20% (MTH-04). Nút xám khi Fortress đầy máu hoặc mithril = 0, kèm lý do. **Số lượt Emergency repair còn lại n/3, cooldown 60 s** và dòng gợi ý "Nhận +1 lượt khi diệt boss" khi lượt dưới 3 | PREP, chọn Fortress |
| PNL-05 \[Should] | Wave preview | Loại quân, modifier, cảnh báo boss. Thu gọn, mở rộng khi rê chuột | PREP |
| PNL-06 | Buff \[Should] | Kho buff, chọn 1 để kích hoạt | PREP, phím V |

| **ID** | **Luật** |
| --- | --- |
| PNL-07 | COMBAT: panel Tower không có Nâng cấp và Bán. Chỉ đổi priority ở Commander mode và khi không Pause. Frontline không đổi được priority trong chiến đấu |
| PNL-08 | Giao dịch cập nhật ngay và **giữ panel mở**. Khóa nút 0.15 s giữa hai lần bấm |
| PNL-09 | Không đủ gold: nút xám kèm số thiếu. Tối đa cấp: "MAX" |
| PNL-10 | **\[Should] Hoàn tác bán.** Khi chưa làm: bán ở mọi cấp đều có xác nhận (SELL-02). Khi làm: bán cấp 2+ có xác nhận. Bán cấp 1 không xác nhận, có hoàn tác 3 s thời gian thực; bộ đếm tạm dừng khi Pause và chạy tiếp phần còn lại khi bỏ Pause. Hoàn tác tự hủy khi: PREP kết thúc (bấm Bắt đầu wave), vào Hazard Trial, có giao dịch khác (xây, nâng, bán, sửa), hoặc Abandon. Hoàn tác khôi phục loại, cấp, target_priority, invested_gold và HP đầy. Áp dụng cả công trình đặt sẵn (SELL-04) |
| PNL-11 | Panel tự đóng khi: vào COMBAT (trừ Commander), tower thành RUINED, Esc, chọn thứ khác. Hộp thoại giao dịch đang mở của panel đó đóng cùng lúc, không thực hiện giao dịch (SCR-14) |
| PNL-12 | Mở panel khi Pause: ở PREP cho phép mọi thao tác. Ở COMBAT, BOSS_COMBAT và HAZARD_TRIAL panel chỉ đọc, các nút đổi priority xám kèm tooltip "Không đổi được khi tạm dừng" |
| PNL-13 | Panel Fortress (PNL-04) chỉ **hiển thị** trạng thái Emergency repair, không có nút kích hoạt (dùng bằng phím R ở Commander mode). Vì lượt khan hiếm, tooltip ở PREP gợi ý ưu tiên sửa bằng Mithril và để dành lượt cho COMBAT |
| PNL-14 | **Panel Trạm hồi lực:** tên, cấp, thanh kho HP kèm số, dòng "Hồi cho chỉ huy: x HP/s" (theo skill SKL-26), nút Nâng cấp (tooltip nêu chỉ cộng phần kho tăng thêm, HLT-08; "MAX" ở cấp 36), nút Bán (tooltip nêu hoàn theo HP còn, SELL-05). **Không có** nút priority hay sửa (HLT-08). Khi RUINED dùng panel đổ nát chung (xây lại, dọn) |
| PNL-15 \[MVP] | **Panel vũ khí:** danh sách owned_weapons (kiếm gốc luôn có), mỗi dòng có biểu tượng, tên, tầm đánh, mô tả hiệu ứng với số liệu hiện tại; vũ khí chưa có hiện ô khóa kèm "Rơi từ boss". Chọn một dòng là trang bị ngay (WPN-03). Chỉ đổi được ở PREP; mở ở state khác thì chỉ đọc |

## 4.2 Input, chuột và camera trong isometric

### 4.2.1 Bảng phím mặc định

| **Hành động** | **Phím** | **Ngữ cảnh** |
| --- | --- | --- |
| Di chuyển | W A S D | Frontline, COMBAT, BOSS_COMBAT và HAZARD_TRIAL (theo trục màn hình) |
| Dịch camera | W A S D | Commander mode và PREP (CAM-02). Cùng phím, khác ngữ cảnh |
| Hồi máu ở Trạm hồi lực | E (giữ) | Frontline, COMBAT, đứng yên trong tầm trạm (HLT-03) |
| Vào Hazard Trial | E (bấm) hoặc chuột trái vào Tháp | PREP, Frontline (HZT-01). Cùng phím E với hồi máu nhưng khác ngữ cảnh |
| Đưa camera về giữa | C | Commander mode và PREP (CAM-08) |
| Đánh thường | Chuột trái | Frontline, không trên UI |
| Dodge | Space | Frontline |
| Battle Cry | Q | Frontline |
| Skill chủ động 1-3 | 1, 2, 3 | Frontline (ở REWARD_PICK: chọn thẻ bằng chuột hoặc phím 1-3 khi có focus thẻ) |
| Đổi chế độ | Tab | Cả hai |
| Emergency repair | R | Commander |
| Bật/tắt xem slot và lưới ô | B | PREP |
| Kích hoạt buff \[Should] | V | PREP |
| Nâng cấp tower đang chọn | U | PREP |
| Bán tower đang chọn | Delete | PREP |
| Hiện tầm bắn mọi tower | Giữ Shift | Mọi lúc |
| Chọn, đặt | Chuột trái | PREP, Commander |
| Bắt đầu wave, Rời phòng, đổi vũ khí | Chuột trái vào nút HUD (HUD-19, HUD-22, HUD-21) | PREP, HAZARD_TRIAL. Không có phím tắt |
| Hủy, bỏ chọn | Chuột phải | Mọi lúc |
| Đóng panel, Pause | Esc | Mọi lúc |
| Ẩn HUD | F1 | Mọi lúc |

| **ID** | **Luật input** |
| --- | --- |
| INP-01 | Mọi hành động qua InputMap. Tên thống nhất: move_up, move_down, move_right, move_left, attack, dodge, battle_cry, skill_1, skill_2, skill_3, mode_switch, emergency_repair, heal_channel, hazard_enter, camera_recenter, build_toggle, upgrade, sell, show_ranges, pause, select, cancel, toggle_hud và \[Should] buff_menu. Tua nhanh, Bắt đầu wave và Rời phòng không nằm trong InputMap vì chỉ có nút HUD (HUD-14, HUD-19, HUD-22). call_wave và relocate đã bỏ ở v2.0 |
| INP-02 | Ưu tiên khi nhiều phím cùng frame: **Dodge > Skill > Attack > Mode switch > Hồi máu (E)**; nhiều skill cùng frame thì ô số nhỏ trước. Pause và HUD xử lý độc lập |
| INP-03 | **Esc theo chuỗi:** (1) đóng hộp thoại, (2) đóng panel, (3) hủy chế độ đặt hoặc bỏ chọn, (4) mở Pause. Mỗi lần bấm một bước |
| INP-04 | Vô hiệu ui_focus_next, ui_focus_prev trong Run. Space trong gameplay không kích hoạt nút UI còn focus: **giải phóng focus** sau mỗi lần bấm nút UI |
| INP-05 | **\[Should] Rebind:** không trùng phím trong cùng ngữ cảnh: hộp thoại "Đã dùng cho \[Hành động], hoán đổi?". Không gán Esc và F1. Có "Khôi phục mặc định". **MVP:** phím cố định theo InputMap, bảng phím chỉ đọc (tab Điều khiển) là \[Should] |
| INP-06 | Tua tốc độ **không có phím tắt**. Phím số 1-3 là skill chủ động (SKL-05) |
| INP-07 | Đổi ngữ cảnh (đổi chế độ, mở panel, Pause): xóa toàn bộ input đang giữ |
| INP-08 | Mất focus cửa sổ: nhả phím ảo, tự Pause nếu bật. Lấy lại focus không tự tiếp tục |
| INP-09 | Mọi action trong InputMap dùng **phím vật lý** (physical_keycode) để WASD đúng vị trí trên AZERTY, Dvorak. Khi làm rebind \[Should] thì cũng lưu theo physical_keycode |
| INP-10 | \[Could] Gamepad: cần trái di chuyển, cần phải aim, A dodge, X đánh, Y Battle Cry, LB đổi chế độ. Con trỏ ảo cho xây dựng cần thiết kế riêng |

### 4.2.2 Chuột và camera

Camera orthographic, camera_pitch -45, camera_yaw 20 (giá trị khởi điểm, đọc qua Camera3D).

| **ID** | **Đặc tả** |
| --- | --- |
| MSE-01 | **Aim:** raycast qua con trỏ xuống mặt phẳng ngang tại độ cao chân chỉ huy. Không trúng thì giữ hướng cũ |
| MSE-02 | **Chọn công trình, slot:** physics picking trên tầng pickable (collider lớn hơn mesh 20%; collider ô grid theo GRID-05), không phụ thuộc mesh bị mờ |
| MSE-03 | Thứ tự chọn: UI > tower > Fortress > slot trống > quân địch (chỉ hover) > mặt đất |
| MSE-04 | Biểu tượng slot và ô grid vẽ **trên cùng** (billboard, tắt depth test) ở PREP nên slot sau tường vẫn bấm được |
| MSE-05 | **Xuyên thấu:** vật thể nhóm occluder dither mờ alpha 0.3 khi che (a) chỉ huy, (b) quân trong 3 m quanh chỉ huy, (c) vật đang hover. Bán kính 2.5 m, chuyển 0.15 s. Dùng dithering, không blend |
| MSE-06 | Hover công trình: outline và vòng tầm bắn. Hover quân: tên, HP, mục tiêu hiện tại sau 0.3 s |
| MSE-07 | \[Should] Con trỏ đổi hình theo ngữ cảnh (mặc định, chọn được, cấm, mục tiêu). Kích thước theo UI scale. MVP: con trỏ hệ thống mặc định |
| MSE-08 | Camera Frontline bám chỉ huy có smoothing, zoom gần, kẹp trong camera_bounds. Commander và PREP dùng khung overview, dịch bằng phím (CAM-02). Chuyển camera 0.5 s **thời gian thực** (CAM-05) |
| MSE-09 | \[Could] Kéo chuột giữa dịch camera |
| MSE-10 | Con trỏ ra ngoài cửa sổ: giữ hướng aim cuối. Tùy chọn khóa con trỏ (mặc định tắt) |

### 4.2.3 Camera

Camera là một Camera3D orthographic dùng chung cho mọi chế độ. Góc camera (pitch, yaw) không đổi, chỉ đổi vị trí điểm focus và size (độ lớn khung nhìn). Mọi giá trị số là khởi điểm, chốt ở tuần 1 cùng góc camera (Phụ lục C).

| **ID** | **Đặc tả** | **Tag** |
| --- | --- | --- |
| CAM-01 | **Frontline (COMBAT, BOSS_COMBAT).** Focus bám chỉ huy với smoothing (camera_follow_smooth 0.15 s), size gần camera_size_frontline sao cho nhìn thấy khoảng 12 đến 14 m mỗi bên chỉ huy theo chiều hành lang. Không dịch tay, không zoom tay. Chuột không điều khiển camera | MVP |
| CAM-02 | **Commander mode và PREP.** Camera chuyển sang khung overview (size camera_size_overview, lớn hơn Frontline). Nhân vật đứng yên, WASD dịch focus của camera với tốc độ camera_pan_speed (không phải di chuyển nhân vật). Chiều ngang hành lang luôn nằm trọn khung, chiều dài hành lang xem bằng cách dịch. Mỗi ngữ cảnh chỉ có một nghĩa cho WASD (CAM-10) | MVP |
| CAM-03 | **Dịch bằng phím.** Dịch theo trục màn hình, vector chéo chuẩn hóa, có gia tốc ngắn (0.1 s) để không giật. Tốc độ theo **thời gian thực**, vẫn dịch được khi Pause (xem layout lúc suy nghĩ), giống TIME-10 loại b. \\[Should] Edge-pan: chuột chạm mép màn hình thì dịch, tắt được trong Settings | MVP (phím), SHOULD (edge-pan) |
| CAM-04 | **camera_bounds.** Hình chữ nhật trên mặt phẳng ngang do Level đặt tay trong scene (không tính tự động từ mesh), giới hạn điểm focus. Phải đủ rộng để Fortress ở cực trái và điểm spawn ở cực phải đều vào được khung ở Commander và PREP. Mọi chế độ đều kẹp focus trong camera_bounds | MVP |
| CAM-05 | **Chuyển khung.** Đổi chế độ (Tab), Recall, Deploy và vào/ra PREP: nội suy focus và size trong 0.5 s **thời gian thực** (MSE-08). Trong lúc chuyển, input dịch camera bị bỏ qua. Nội suy dùng ease-out, tắt thành cắt tức thì khi bật Giảm chuyển động (ACC-05) | MVP |
| CAM-06 | \\[Should] **Look-ahead.** Ở Frontline focus lệch tối đa camera_lookahead (2 m) về phía con trỏ để thấy xa hơn hướng đang đánh. Tắt được trong Settings | SHOULD |
| CAM-07 | **Không nhớ vị trí dịch.** Mỗi lần vào Commander hoặc vào PREP, camera đặt về focus mặc định: Commander lấy vị trí chỉ huy kẹp trong camera_bounds, PREP lấy giữa hành lang. Không lưu vị trí dịch qua lần chuyển hay qua wave | MVP |
| CAM-08 | **Về giữa.** Phím C (camera_recenter) đưa focus về mặc định của CAM-07 trong 0.3 s thời gian thực. Chỉ ở Commander mode và PREP | MVP |
| CAM-09 | **Không zoom tay.** Cuộn chuột không đổi size và kéo chuột không dịch camera ở MVP. \\[Could] Zoom bằng cuộn chuột và kéo chuột giữa (MSE-09). Nếu làm, size phải kẹp trong khoảng [camera_size_frontline, camera_size_overview] | COULD |
| CAM-10 | **Phím WASD theo ngữ cảnh.** Đổi ngữ cảnh (Tab, đổi state) xóa input đang giữ (INP-07) để không bị trôi nhân vật hay trôi camera. Trong các state khóa input (BOSS_INTRO, REWARD_PICK, hộp thoại) WASD không làm gì | MVP |
| CAM-11 | **BOSS_INTRO.** Camera tự lia tới boss trong 4 s game time (BOSS-17) bất kể chế độ, khóa dịch tay. Hết intro camera về khung của state kế tiếp theo CAM-05 | MVP |
| CAM-12 | **Picking và aim theo camera hiện tại.** Raycast chuột (MSE-01, MSE-02) luôn dùng camera đang hoạt động ở frame đó, nên dịch camera không làm sai chọn slot hay hướng đánh. Xuyên thấu (MSE-05) áp theo chỉ huy, không theo focus camera | MVP |
| CAM-13 | **Rung màn hình** (FBK-03) cộng vào vị trí camera sau khi kẹp, biên độ có trần, không đưa camera ra ngoài camera_bounds quá 0.3 m | MVP |
| CAM-14 | **Chiếu sáng và bóng.** Camera Frontline thấy ít vùng hơn nên tắt render, animation và âm thanh vị trí của quân ngoài khung theo LOD (\\[Should], mục 3.7) nhưng **không** giảm logic AI hay tấn công | SHOULD |
| CAM-16 \[MVP] | **Hazard Trial.** Vào phòng: camera cắt (hoặc chuyển 0.5 s theo CAM-05) sang khung cố định của hazard_room do Level đặt, size đủ thấy cả phòng; không bám nhân vật, không dịch bằng phím, C không làm gì. WASD di chuyển nhân vật. Rời phòng: về khung PREP mặc định (CAM-07). Phát camera_frame_changed với frame HAZARD_TRIAL (EVB-35) | MVP |
| CAM-15 | **Settings.** \\[Should] Tốc độ dịch camera (0.5x đến 2x), bật tắt edge-pan, bật tắt look-ahead. MVP dùng giá trị mặc định | SHOULD |


## 4.3 Cảnh báo và thông báo

| **Tầng** | **Ví dụ** | **Hiển thị** | **Âm thanh** |
| --- | --- | --- | --- |
| **T1 (nghiêm trọng)** | Fortress dưới 30%, chỉ huy dưới 25%, boss Cuồng nộ (T-0) | Banner giữa, viền HUD nhấp nháy | Còi, không bị nhạc lấn |
| **T2 (quan trọng)** | Tower bị phá, tua bị hạ, boss sắp Cuồng nộ (T-30), nhận vũ khí | Toast góc trên giữa 2.5 s | Chuông ngắn |
| **T3 (thông tin)** | Đã lưu, nhận gold, nhận Mithril, mở khóa mốc, lên cấp | Toast nhỏ góc dưới phải 2 s | Không hoặc nhẹ |

| **ID** | **Điều kiện** | **Tầng** | **Nội dung mẫu** |
| --- | --- | --- | --- |
| ALR-01 | fortress_hp chạm 30% (một lần mỗi wave) | T1 | "Thành sắp thất thủ" |
| ALR-02 | commander_hp chạm 25% | T1 | Viền đỏ, nhịp tim |
| ALR-03 | Boss T-30 | T2 | "Mech sắp cuồng nộ" |
| ALR-04 | Boss Cuồng nộ (T-0) | T1 | "Mech cuồng nộ" |
| ALR-05 | \[ĐÃ XÓA v1.8] | | |
| ALR-06 | \[ĐÃ XÓA v1.8] | | |
| ALR-07 | Tower vào RUINED (nhiều tower cùng frame: gộp thành một toast "N tower bị phá") | T2 | "Arrow cấp 2 ở W3 bị phá (xây lại 120 gold)" (gợi ý camera, không tự động) |
| ALR-09 | Wave kế là boss | T2 | "Boss ở wave kế. Kiểm tra miễn nhiễm" |
| ALR-10 | FPS tụt, tự hạ tốc độ | T2 | "Đã hạ về x2 để giữ ổn định" |
| ALR-11 | Lưu thất bại | T1 | Hộp thoại |
| ALR-12 | \[Should] Bán, hoàn tác 3 s | T3 | "Hoàn tác (3)". Biến mất khi hoàn tác bị hủy. Tooltip "Hết hạn khi vào chiến đấu" |
| ALR-17 | Trạm hồi lực bị hút cạn (HLT-07) | T2 | "Trạm hồi lực ở ô G3 đã cạn (xây lại 80 gold)". Trạm bị quân phá thì gộp vào ALR-07 |
| ALR-18 | Kho Trạm hồi lực dưới 20% (một lần mỗi trạm mỗi lần xây) | T3 | "Trạm hồi lực sắp cạn" (HLT-11) |
| ALR-19 | Nhận vũ khí từ boss (WPN-11) | T2 | "Nhận vũ khí Frost. Đổi ở giai đoạn chuẩn bị" |
| ALR-20 | Kết thúc Hazard Trial (HZT-07) | T3 | "Thắng Hazard Trial: +1 Mithril, +34 gold, +12 XP" hoặc "Đã rời phòng: +20 gold, +6 XP" |

| **ID** | **Luật** |
| --- | --- |
| ALR-13 | Tối đa **1 banner** và **3 toast**. Vượt thì xếp hàng theo tầng rồi thời gian. T1 chen được T2, T3 |
| ALR-14 | Cùng loại không hiện lại trong 5 s (trừ số đếm từ T-10) |
| ALR-15 | Hiển thị và thời gian sống theo **thời gian thực** |
| ALR-16 | Không che hành lang và nút kỹ năng. \[Should] T2, T3 tắt được trong Settings (tab Gameplay), MVP luôn bật. **T1 không tắt được** |

## 4.4 Phản hồi và hiệu ứng

| **ID** | **Đặc tả** |
| --- | --- |
| FBK-01 | Số sát thương nổi: trắng (thường), xám kèm "RESIST", "IMMUNE", đỏ (chỉ huy nhận), xanh lục (hồi). Lệch ngẫu nhiên ±0.3 m |
| FBK-02 | Gộp số sát thương của tower lên cùng mục tiêu trong 0.2 s. Tối đa 60 số nổi (pool). \[Should] Có thể tắt (SET-03), MVP luôn bật |
| FBK-03 | Rung màn hình cho: chỉ huy trúng đòn nặng, Stomp, Fortress nhận sát thương lớn, Cuồng nộ boss. Biên độ có trần. Giảm hoặc tắt được (ACC-05) |
| FBK-04 | Flash trắng 0.1 s khi chỉ huy trúng đòn, bỏ nếu "Giảm nhấp nháy" |
| FBK-05 | **Không dùng hit stop toàn cục**. Cảm giác va chạm bằng đóng băng animation riêng thực thể 0.05 s, chớp trắng shader và âm thanh |
| FBK-06 | Telegraph Stomp, Shell \[Should]: vòng đỏ viền đậm có họa tiết (không chỉ màu), chiếu sát mặt đất (quân và công trình đứng trên vòng), không che đè lên tường hay chỉ huy |
| FBK-07 | Boss chuyển pha: hơi nước, giáp bay, lõi sáng, banner "Lộ lõi" 1.5 s, giảm nhạc 0.5 s |
| FBK-08 | Tower bị phá: khói, mảnh vỡ, đống đổ nát. Xây xong: hiệu ứng dựng 0.5 s |
| FBK-09 | Giới hạn hạt theo preset (Thấp 500, Trung bình 1500, Cao 3000). Vượt thì bỏ hiệu ứng thứ yếu trước, không bỏ telegraph |
| FBK-10 | Slow motion 0.2x cuối run là hiệu ứng thời gian thực trên hoạt cảnh, sau khi RunState đóng băng |
| FBK-11 \[MVP] | Cuồng nộ boss: lõi đỏ phát sáng, hơi nước, giảm nhạc 0.5 s, rung màn hình theo ACC-05 |
| FBK-13 \[MVP] | Hiệu ứng vũ khí: mỗi vũ khí có VFX riêng trên lưỡi kiếm; Frost hiện lớp băng trên quân bị chậm, Chain Lightning vẽ tia giữa các mục tiêu, Burn hiện lửa trên quân đang cháy, Rampage đổi ánh kiếm theo bậc máu kèm biểu tượng (UI-05), Swift có vệt chém nhanh. Giảm nhấp nháy theo ACC-06 |
| FBK-14 \[MVP] | Quân mới: Assassin vẽ ở độ mờ stealth_opacity qua material (không hardcode, EN-20); Knight bất tử có lớp giáp sáng; Undead chờ hồi sinh có hiệu ứng xương; Suicide Squad có telegraph trước nổ (FBK-06) |
| FBK-12 \[MVP] | Trạm hồi lực: vòng tiến trình hold quanh chân chỉ huy, tia sáng từ trạm sang chỉ huy khi đang hồi, số nổi xanh lục (FBK-01) gộp 0.5 s, trạm cạn: khói và hiệu ứng như FBK-08. Giảm nhấp nháy theo ACC-06 |

## 4.5 Âm thanh

| **Bus** | **Nội dung** | **Mặc định** |
| --- | --- | --- |
| Master | Tổng | 80% |
| Music | Nhạc nền | 60% |
| SFX | Tiếng gameplay | 80% |
| UI | Nhấp nút, cảnh báo | 70% |

| **State** | **Nhạc** |
| --- | --- |
| MainMenu, MetaShop | Vòng lặp nhạc menu |
| PREP | Nhạc nhẹ, nhịp chậm |
| COMBAT | MVP: một vòng lặp nhạc chiến đấu. \[Should] Nhạc theo lớp: thêm lớp khi enemies_alive vượt 20 và 45 |
| BOSS_INTRO, BOSS_COMBAT | Nhạc boss riêng. \[Should] Pha lõi thêm lớp, T-30 tăng tempo |
| SUMMARY | Sting thắng rồi nhạc PREP |
| HAZARD_TRIAL | Dùng nhạc COMBAT (nhạc boss nếu nhóm có boss) |
| Màn thắng (SCR-20) | Sting chiến thắng riêng, rồi nhạc PREP khi chơi tiếp |
| RunEnd | Sting thua rồi nhạc nền lặng. RunEnd endless dùng sting riêng nhẹ hơn |

| **ID** | **Đặc tả** |
| --- | --- |
| AUD-01 | Khi tua x2, x3: **không đổi tốc độ và pitch** của nhạc và SFX. Nhạc không bị ảnh hưởng bởi time_scale |
| AUD-02 | Tối đa 32 SFX, tối đa 4 lần phát cùng một âm. Ưu tiên T1 > chỉ huy > boss > tower > quân. T1 không bao giờ bị loại |
| AUD-03 | Cùng một âm không phát quá một lần trong 50 ms (80 ms ở x3) |
| AUD-04 | **\[Should]** Panning theo vị trí trên màn hình, giảm âm theo khoảng cách tới tâm camera. Ngoài màn hình giảm 50%. MVP: phát stereo, không định vị |
| AUD-05 \[Should] | Ducking: T1 hạ Music 6 dB trong 1.5 s (cần để T1 "không bị nhạc lấn", mục 4.3). MVP: không ducking, âm T1 đặt to hơn nhạc nền |
| AUD-06 | Crossfade nhạc 1.5 s (thời gian thực). Pause: nhạc giảm 50%, SFX gameplay dừng, SFX UI chạy. **\[Should]** Thêm lọc thông thấp cho nhạc khi Pause |
| AUD-07 | Âm báo quan trọng có kiểu riêng phân biệt: Stomp wind-up, Shell rơi \[Should], Cuồng nộ boss, lên cấp, thẻ thưởng xuất hiện, tower bị phá, bắt đầu hồi ở Trạm hồi lực (nhịp nhẹ) và trạm cạn, Fortress trúng đòn nặng |
| AUD-08 | Mất focus: tắt tiếng Master (tùy chọn, mặc định bật). Lấy lại focus fade-in 0.5 s |
| AUD-09 | Nhạc .ogg (stream), SFX ngắn .wav (preload). Chuẩn hóa -14 LUFS (nhạc), -12 (SFX) |
| AUD-10 | Không lồng tiếng ở MVP |

## 4.6 Settings

Lưu trong user://settings.cfg, tách khỏi save. Áp dụng ngay, riêng Video cần xác nhận.

| **Tab** | **Mục** |
| --- | --- |
| Gameplay \[Should] | Tự pause khi mất focus (mặc định bật), khóa con trỏ, hiển thị số sát thương, bật/tắt cảnh báo T2 và T3, tự bắt đầu wave (WAVE-12), Xem lại hướng dẫn, Ngôn ngữ. MVP: các giá trị này cố định theo mặc định, chưa có tab \[Should] Tốc độ dịch camera, edge-pan, look-ahead (CAM-15). |
| Điều khiển \[Should] | Bảng phím chỉ đọc. Rebind toàn bộ, Khôi phục mặc định (INP-05) |
| Âm thanh | Master, Music, SFX, UI, tắt tiếng khi mất focus |
| Đồ họa | Chế độ cửa sổ, độ phân giải, VSync, giới hạn FPS (60, 120, không), preset chất lượng, chất lượng bóng, giới hạn hạt, kiểu xuyên thấu. \[Should] UI scale 80-150% |
| Tiếp cận | Mục 5.2 |
| Dữ liệu \[Should] | Mở thư mục save, Xóa tiến trình (SAV-16), Xuất log lỗi |
| Tài khoản | Đăng nhập, đăng xuất, đồng bộ ngay, trạng thái đồng bộ, tên hiển thị (mục 3.13) |

| **ID** | **Luật** |
| --- | --- |
| SET-01 | Đổi độ phân giải hoặc chế độ cửa sổ: "Giữ thay đổi?" đếm ngược 10 s thời gian thực. Không xác nhận thì hoàn về cũ |
| SET-02 | Preset chỉ là bộ giá trị. Đổi từng mục thì thành "Tùy chỉnh". Mặc định theo GPU (không phát hiện được thì Trung bình) |
| SET-03 | Tắt số sát thương chỉ ẩn số của tower và quân, **không** ẩn sát thương chỉ huy nhận |
| SET-04 | settings.cfg hỏng: dùng mặc định, không ảnh hưởng save, giữ tệp hỏng .corrupt |
| SET-05 | Mở Settings từ Pause: Run vẫn đóng băng. \[Should] Đổi ngôn ngữ áp dụng ngay |
| SET-06 | Lưu khi **thoát màn Settings**, không lưu từng thay đổi |

## 4.7 Hướng dẫn (tutorial)

Từ v2.0 tutorial **chạy một lần theo tài khoản**: chạy ở run có start_wave = 1 khi profile.flags.tutorial_done = false. Phần lõi là hướng dẫn xây **hai trụ đầu** (một Arrow, một Cannon) miễn phí ở hai slot mặc định trong dữ liệu (starter_arrow_slot, starter_cannon_slot). Xây xong cả hai thì ghi tutorial_done = true vào profile, ghi save (SAV-04) và đồng bộ theo tài khoản (ACCT-04); các run sau game tự xây hai trụ này ở cùng chỗ khi bắt đầu run (mục 3.2.1). Gợi ý ngữ cảnh khác trong wave 1-3 mỗi gợi ý hiện một lần trong run đó. **MVP có TUT-01, TUT-03, TUT-14, TUT-15**; TUT-04, TUT-05, TUT-06, TUT-07, TUT-12, TUT-13, TUT-16 là \[Should]. Phần giải thích 3 chọn 1 không làm bằng hệ tutorial mà là dòng chữ tĩnh trong SCR-17 (\[MVP]).

| **ID** | **Wave / State** | **Gợi ý** | **Điều kiện qua bước** |
| --- | --- | --- | --- |
| TUT-01 | Wave 1, PREP | "Bấm vào ô sáng trên mặt đất để xây Arrow miễn phí. Dùng WASD để dịch camera xem toàn bản đồ" | Xây Arrow ở starter_arrow_slot (BLD-11) |
| TUT-14 | Wave 1, PREP, sau TUT-01 | "Bấm vào slot sáng trên tường để xây Cannon miễn phí" | Xây Cannon ở starter_cannon_slot (BLD-11) |
| TUT-15 | Wave 1, PREP, sau TUT-14 | "Chuẩn bị xong thì bấm Bắt đầu wave. Không có giới hạn thời gian" | Bấm Bắt đầu wave. Nút Bắt đầu wave xám cho tới khi xây xong cả hai trụ (WAVE-11); xây xong là ghi tutorial_done = true ngay, trước khi bấm |
| TUT-03 | Wave 1, COMBAT | "WASD di chuyển, chuột trái đánh, Space né. Đánh trúng quân để nhận XP đầy đủ và mở nâng cấp tower" | Đánh trúng 1 quân |
| TUT-04 \[Should] | Wave 2, PREP | "Bấm Tab để chuyển sang Commander" | Chuyển được |
| TUT-05 \[Should] | Wave 2, COMBAT | "Chọn tower, đổi mục tiêu ưu tiên" | Đổi được |
| TUT-06 \[Should] | Wave 3, PREP | "Sửa Fortress bằng Mithril khi bị thương" | Nếu Fortress bị thương và có Mithril, không bắt buộc |
| TUT-16 \[Should] | Wave 2, PREP | "Vào Tháp Hazard Trial (E) để đánh trước 5 quái của wave sắp tới và nhận Mithril" | Vào phòng hoặc bỏ qua |
| TUT-07 \[Should] | Wave 5, PREP | Giới thiệu boss: pha giáp, miễn nhiễm, đồng hồ Cuồng nộ, vũ khí sẽ rơi | Xem ít nhất 2 s |
| TUT-13 \[Should] | Wave 3, COMBAT, khi đã có Trạm hồi lực và HP chỉ huy dưới 50% | "Đứng cạnh Trạm hồi lực, đứng yên và giữ E để hồi máu" | Hồi được ít nhất 1 lần |

| **ID** | **Luật** |
| --- | --- |
| TUT-08 | Nút **Bỏ qua** luôn có. Bỏ qua khi chưa xây xong hai trụ thì game tự xây ngay những trụ còn thiếu ở slot mặc định (như run sau), ghi tutorial_done = true |
| TUT-09 | Gợi ý không chặn gameplay, trừ nút Bắt đầu wave chờ hai trụ (TUT-15). TUT-01 chờ tối đa 30 s rồi nhắc lại |
| TUT-10 | Thoát giữa chừng trước khi xây xong hai trụ: tutorial_done vẫn false, run sau chạy lại tutorial. Sau khi đã xong: gợi ý còn lại không tự hiện ở run sau. Có "Xem lại hướng dẫn" ở Settings (tab Gameplay \[Should]), chỉ hiện lại gợi ý, không đặt lại tutorial_done |
| TUT-11 | Tutorial không đổi kịch bản wave hay chỉ số. Hai trụ xây theo tutorial giống hệt trụ có sẵn: cấp 1, invested_gold = 0, khóa bán tới wave 3 (SELL-06) |
| TUT-12 \[Should] | Gợi ý Aura Tiền tuyến ở wave 3 ("Đứng gần tower khi đang chiến đấu để tăng sát thương cho chúng") |
| TUT-17 | Tài khoản đã có tutorial_done = true đăng nhập trên máy mới: sau khi đồng bộ (ACCT-05), run kế tiếp có trụ có sẵn, không chạy tutorial. Run đang chơi lúc đăng nhập không đổi |

# 5. YÊU CẦU PHI CHỨC NĂNG

## 5.1 Hiệu năng và nghiệm thu kỹ thuật

| **ID** | **Chỉ tiêu** | **Điều kiện đo** |
| --- | --- | --- |
| ACP-01 | **60 FPS** ổn định (percentile 1% không dưới 45) | 70 quân, 6 tower, 200 projectile, x1, preset Trung bình, máy yếu nhất của nhóm (ghi rõ cấu hình). Đo riêng chi phí quét mục tiêu của 6 tower, mục tiêu dưới 1 ms/frame (TWR-15) |
| ACP-02 | Không dưới 30 FPS quá 3 s ở x3, nếu có thì tự hạ x2 | Cùng điều kiện |
| ACP-03 | RunLoading dưới 5 s | SSD, lần đầu và lần sau |
| ACP-04 | Bộ nhớ khoảng 1.5 GB cho toàn game | Sau 30 phút chơi liên tục |
| ACP-05 | Không rò rỉ: sau 10 run liên tiếp, node và bộ nhớ không tăng quá 5% | Performance monitors |
| ACP-06 | Ghi save dưới 50 ms | SAV-05 |
| ACP-07 | UI tối đa 10% thời gian frame | UI-06 |
| ACP-08 | Đồng bộ cloud và tải bảng xếp hạng chạy bất đồng bộ, không làm percentile 1% FPS thấp hơn ACP-01, không chặn UI quá 100 ms; mất mạng không làm chậm RunEnd hay shop | Mạng chậm 1 s và mất mạng, ở MainMenu, RunEnd, MetaShop |

**Biện pháp hiệu năng:** giới hạn ~70 quân, cập nhật path theo timer 0.3 s, tower quét theo scan_interval, object pool cho projectile, số nổi, thanh máu. Nếu ACP-01 không đạt, giảm giới hạn thanh máu (40) và số nổi (60) trước khi đụng tới logic.

## 5.2 Khả năng tiếp cận

| **ID** | **Đặc tả** |
| --- | --- |
| ACC-01 | **\[Should]** Mù màu: ba preset (Deuteranopia, Protanopia, Tritanopia) cho HUD và telegraph. **MVP:** chỉ cần thỏa UI-05, tức thông tin quan trọng luôn có kênh thứ hai ngoài màu (biểu tượng, họa tiết, chữ) |
| ACC-02 | \[Should] UI scale 80-150%. MVP: chữ tối thiểu 14 px ở 1080p |
| ACC-03 | **\[Should]** Độ tương phản cao cho telegraph và viền công trình (tùy chọn) |
| ACC-04 | Tùy chọn giữ-hoặc-bật cho Shift và các phím giữ |
| ACC-05 | Giảm rung màn hình: Bình thường, Giảm 50%, Tắt |
| ACC-06 | Giảm nhấp nháy: tắt flash trắng, viền cảnh báo tĩnh, không nhấp nháy quá 3 lần/giây. Giới hạn 3 lần/giây áp dụng cho mọi hiệu ứng nhấp nháy ngay cả khi tùy chọn đang tắt |
| ACC-07 | Đồng hồ và cooldown luôn có **số** |
| ACC-08 | Chơi được chỉ bằng chuột và phím bên trái bàn phím, không yêu cầu hai phím xa nhau cùng lúc |
| ACC-09 | Không có thông tin quan trọng nào chỉ truyền bằng âm thanh. MVP: tiếng Stomp chuẩn bị nện đất có telegraph vòng đỏ kèm họa tiết và thanh đếm wind-up 1.0 s (UI-05); đồng hồ boss có số và nhãn CUỒNG NỘ, banner ở T-30 và T-0 (ALR-03, ALR-04, ACC-07, ENR-05); còi T1 luôn đi kèm banner và biểu tượng. \[Should] Tùy chọn Settings "Chỉ báo thị giác thay âm thanh" thêm biểu tượng hướng và viền màn hình theo loại sự kiện |

## 5.3 Ngôn ngữ

| **ID** | **Đặc tả** |
| --- | --- |
| LOC-01 | **Tiếng Việt** (MVP, ngôn ngữ duy nhất khi phát hành). **\[Should]** Tiếng Anh (mặc định nếu OS không phải vi). CSV, khóa theo ngữ cảnh (hud.wave, shop.fort_hp.desc), không dùng câu tiếng Anh làm khóa. Cột tiếng Anh có thể để trống ở MVP. Kiến trúc tr() và CSV theo khóa vẫn là MVP để thêm ngôn ngữ sau không phải sửa code |
| LOC-02 | **Font hỗ trợ đầy đủ dấu tiếng Việt** (ằ, ẫ, ộ, ữ, đ), kiểm tra cả in đậm. Chốt font ở tuần 1 |
| LOC-03 | Chừa 40% dư chiều rộng, dùng autowrap và clip_text, không cắt giữa từ |
| LOC-04 | Số, thời gian, đơn vị định dạng độc lập ngôn ngữ (dấu chấm thập phân, mm:ss) |
| LOC-05 | Chuỗi tham số dùng chỗ giữ chỗ có tên ({gold}, {tower}), không nối chuỗi |
| LOC-06 | **\[Should]** Kiểm thử bằng pseudo-localization |

## 5.4 Độ tin cậy và toàn vẹn dữ liệu

- Ghi save atomic và có bản sao lưu (mục 3.12). Không có trạng thái mà cả ba tệp đều không đọc được (SAV-13).
- Mất mạng, hết hạn phiên hay máy chủ lỗi không làm mất tiến trình cục bộ và không chặn lối chơi (ACCT-07, ACCT-12). Bản cục bộ luôn được ghi trước khi gửi lên cloud.
- Mọi giao dịch (xây, nâng, bán, sửa bằng Mithril, đổi vũ khí, mua) nguyên tử (BLD-02, GLD-01, MTH-05, SHP-05).
- Sự kiện thua và thưởng xử lý đúng một lần (is_dead, boss_enraged, END-01).
- Kết quả sinh wave xác định theo run_seed và wave_index.
- Không có tình huống bế tắc: quân lẻ có FRENZY, boss luôn hạ được (kiếm gây ≥ 60%, ENR-06), kẹt có thang xử lý (không xóa quân ngay), giới hạn cứng 300 s. \[Should] Thêm watchdog cấp wave.

## 5.5 Khả năng bảo trì và kiểm thử

- Toàn bộ chỉ số nằm trong Resource hoặc CSV (GameConfig, CharacterStats, TowerData, EnemyData, BossData, ScaleConfig, WaveTable, WaveScript, WaveRewardTable, WeaponData, WaveModifier, StartPack, ShopItem). Số liệu cân bằng sinh từ `balance/balance.xlsx` bằng một lệnh, có runner kiểm config (mục 6.10).
- Autoload EventBus cho tín hiệu chung. Mỗi người sở hữu scene riêng.
- Ghi log cho các sự kiện bất thường (kẹt, hủy quân, giá trị vô lý, quân sống sót qua PREP).
- Seed cố định cho phép tái hiện lỗi wave.

# 6. YÊU CẦU DỮ LIỆU

## 6.1 Nguyên tắc sở hữu dữ liệu

| **ID** | **Nguyên tắc** |
| --- | --- |
| DAT-01 | Mỗi tham số có đúng một Resource sở hữu. Hệ thống khác đọc qua tham chiếu, không chép giá trị. Số liệu ghi ở nhiều mục của SRS (ví dụ 12 slot Fortress ở 3.6.1 và 3.7.4) thì mục thứ hai chỉ trỏ về tên biến |
| DAT-02 | Quy tắc chọn chỗ: (1) mô tả một thực thể hoặc một loại thực thể thì thuộc Resource của thực thể đó. (2) Luật toàn cục dùng chung nhiều hệ thống, hoặc số chỉnh nhịp game thì thuộc GameConfig. (3) Bảng, công thức theo wave, mốc, cấp thì thuộc ScaleConfig, WaveTable, StartPack, ShopItem |
| DAT-03 | Resource chỉ đọc khi chạy. Giá trị đã cộng meta (max HP Fortress, max HP chỉ huy, mức hồi Emergency repair, gold_pct_meta) được tính một lần ở RunLoading và lưu vào RunConfig, không ghi ngược vào Resource (APL-01, APL-02) |
| DAT-04 | Tham số dạng tỷ lệ (*_pct, *_ratio) lưu trong khoảng 0.0 đến 1.0 (60% ghi 0.6). Mục tiêu đơn vị: mét, giây game time. Giá trị thời gian thực ghi rõ trong ghi chú |
| DAT-05 | Cùng một khái niệm không được dùng một tên cho nhiều giá trị. Biến cấu hình (Resource) và biến trạng thái (RunState) phải khác tên |
| DAT-06 | Nguồn chuẩn của giá trị: bảng ở các mục 3.5.1, 3.6.1, 3.6.2 (GridData), 3.6.3, 3.7.1, 3.7.5, 3.7.6, 3.8.2, 3.10.1, 3.11.1 cho Resource tương ứng, mục 6.3 cho GameConfig. Mục 6.4 đến 6.7 là bản tra cứu nơi lưu. Hai nơi lệch nhau thì sửa theo nguồn chuẩn và ghi vào Phụ lục D. **Từ v2.0, với số liệu cân bằng (mục 6.10) nguồn chuẩn là bảng cân bằng**; số trong SRS chỉ là khởi điểm |
| DAT-07 | File `.tres` do công cụ dịch sinh ra không sửa tay (BAL-03). Muốn đổi số thì sửa bảng rồi chạy lại công cụ. Tham số không thuộc bảng (luật GameConfig, thời gian UI, camera...) vẫn sửa tay như cũ |

## 6.2 Danh mục Resource

| **Resource** | **Sở hữu** | **Mục tham chiếu** | **Vai phụ trách** |
| --- | --- | --- | --- |
| GameConfig | Luật toàn cục, nhịp game, kinh tế, giới hạn hiệu năng, chống kẹt | 6.3 | Chia theo nhóm, mỗi nhóm một vai |
| CharacterStats | Mọi chỉ số riêng của chỉ huy. Sinh từ bảng cân bằng (v2.0) | 3.5.1, 6.4 | Player & Combat |
| FortressStats | Mọi chỉ số riêng của Fortress | 3.6.1, 6.5 | Tower & Build |
| GridData | Bố cục ô grid của một level: gốc, số cột, grid_rows hàng, khoảng cách ô. Hàm đổi (cột, hàng) sang vị trí và cell_id; hàm thuần kiểm chặn kín đường (GRID-07) | 3.6.2 | Level (người làm Level), Tower & Build |
| TowerData | Bốn loại tower (Arrow, Cannon, Barricade, Trạm hồi lực), mỗi loại 36 cấp và 3 scene model theo bậc. Dữ liệu theo cấp sinh từ bảng cân bằng | 3.6.3, 3.6.6, 6.6 | Tower & Build |
| EnemyData | Chỉ số gốc, trait và thưởng gốc theo loại quân (10 loại MVP). Sinh từ bảng cân bằng | 3.7.1, 3.7.8, 6.6 | Enemy & Wave |
| BossData | Bulwark \[MVP], Barrage \[Should] | 3.8.2, 6.6 | Enemy & Wave |
| ScaleConfig | Công thức scale endless | 3.7.6, 6.6 | Enemy & Wave |
| WaveTable | Trọng số và trần sinh quân (dùng từ wave 31) | 3.7.5, 6.6 | Enemy & Wave |
| WaveScript \[MVP] | Kịch bản wave 1-30: loại quân, số lượng, hộ tống, spawn_duration, hp_mult, dmg_mult, speed_mult mỗi wave. Sinh từ bảng cân bằng | 3.7.5, 3.7.6, 6.10 | Enemy & Wave |
| WaveRewardTable \[MVP] | Thưởng theo wave 1-30: gold_mult, xp_mult, mithril_reward. Sinh từ bảng cân bằng | 3.9, 6.10 | Tower & Build (kinh tế) |
| WeaponData \[MVP] | Kiếm gốc và 5 vũ khí: range_mult, model, VFX, hiệu ứng và tham số. Sinh từ bảng cân bằng | 3.5.13, 6.10 | Player & Combat |
| WaveModifier \[Should] | Hệ số modifier wave | 3.7.5 | Enemy & Wave |
| StartPack \[Should] | Gói xuất phát theo mốc | 3.11.1 | UI/UX & Meta |
| ShopItem | Giá, số cấp, tác dụng mỗi cấp (4 mục MVP) | 3.10.1, 6.6 | UI/UX & Meta |
| SkillData \[MVP] | Skill và thẻ stat: id, loại ACTIVE / PASSIVE / STAT, max_level, bảng giá trị theo level, icon, damage_type, tag, trọng số. Bảng giá trị sinh từ bảng cân bằng | 3.5.12, 6.6 | Player & Combat (nội dung), Tower & Build (RewardOfferGenerator) |

## 6.3 GameConfig

**Run và wave**

| **Tham số** | **Giá trị** | **Ghi chú** |
| --- | --- | --- |
| starting_gold | 0 | GLD-06. MVP cố định (v2.0, trước là 150) |
| victory_wave | 30 | END-07. Wave mốc thắng; công thức scale dùng từ victory_wave + 1 (SCL-06) |
| starter_arrow_slot / starter_cannon_slot | Ô grid ở hàng giữa (hàng 4), cột hợp lệ gần Fortress nhất, ngoài vùng cấm quanh boss_melee_point (GRID-08) (cell_id khai trong GameConfig theo GridData của map) / W2 | mục 3.2.1, BLD-11. Vị trí mặc định của hai trụ có sẵn |
| starter_sell_unlock_wave | 3 | SELL-06. Trụ có sẵn bán được từ PREP của wave này |
| max_alive | 70 | WAVE-01 |
| wave_max_enemy_types | 5 | SPN-14. Đếm cả boss |
| summary_auto_advance* | 10 s | Thời gian thực (3.3.4) |
| boss_wave_interval* | 5 | BOSS-22: wave boss khi w chia hết cho giá trị này |
| weapon_drop_waves | 5, 10, 15, 20, 25 | WPN-11 |

**Hazard Trial và Mithril (v2.0)**

| **Tham số** | **Giá trị** | **Ghi chú** |
| --- | --- | --- |
| hazard_enemy_count | 5 | HZT-02 |
| hazard_boss_escorts | 4 | HZT-02. Số quân đi cùng boss trong phòng |
| hazard_damage_cap_pct | 0.10 | HZT-05 |
| mithril_reward(w) | Bảng thưởng theo wave (khởi điểm 1) | MTH-02. Nằm trong WaveRewardTable, không phải GameConfig |

**Kinh tế**

| **Tham số** | **Giá trị** | **Ghi chú** |
| --- | --- | --- |
| clear_mult_fast* / clear_mult_normal* / clear_mult_slow* | 1.25 / 1.00 / 0.80 | clear_mult là kết quả chọn theo mốc |
| clear_fast_threshold* / clear_slow_threshold* | 0.7 / 1.3 | Nhân với par_time |
| par_time_offset* | 15 s | par_time = spawn_duration + offset |
| par_time_boss_ratio* | 0.6 | par_time_boss = ratio × boss_timer |
| gold_reward_growth_per_wave* | 0.04 | RWD-02, dùng cho cả boss_gold từ wave 31; wave 1-30 dùng gold_mult(w) của WaveRewardTable |
| boss_gold_base* | 100 |  |
| boss_prestige | 15 |  |
| wave_prestige_base* / wave_prestige_step* | 2 / 5 | wave_prestige(w) = base + floor(w / step) |
| prestige_buffer_ratio* | 0.5 | Hệ số buffer uy tín wave dở (3.2.4) |
| conversion_rate | 0.30 |  |
| sell_refund_pct | 0.60 |  |

**Emergency repair**

| **Tham số** | **Giá trị** | **Ghi chú** |
| --- | --- | --- |
| emg_repair_charges_max | 3 | Hằng số, meta và buff không đổi được (APL-04) |
| emg_repair_charges_start* | 3 | Mọi mốc xuất phát |
| emg_repair_base_heal_pct* | 0.20 | Mức hồi gốc. Bonus +0.03 mỗi cấp nằm ở ShopItem EMG_REPAIR |
| emergency_repair_cooldown | 60 s | Hằng số, chạy xuyên wave |
| emg_repair_boss_refund | 1 | BRW-07 |

**Trần giáp (APL-03)**

| **Tham số** | **Giá trị** | **Ghi chú** |
| --- | --- | --- |
| commander_armor_cap* | 0.75 | Kẹp lúc tính sát thương. armor_pct trong CharacterStats không tự kẹp |
| fortress_armor_cap* | 0.60 | Tương tự cho FortressStats |

**Tower chung**

| **Tham số** | **Giá trị** | **Ghi chú** |
| --- | --- | --- |
| max_projectiles | 200 | PRJ-04 |
| scan_interval | 0.2 s |  |
| retarget_delay | 0.3 s |  |
| tower_full_heal_on_prep | true | TWR-01 |
| max_attackers_per_barricade | 5 | TWR-06 |
| max_attackers_per_tower* | 3 | Tower trên ô grid không phải Barricade, gồm cả Trạm hồi lực (HLT-10). Giá trị khởi điểm, cần playtest |
| sell_undo_window* | 3 s | \[Should] Thời gian thực, dừng khi Pause (PNL-10) |

**Grid**

| **Tham số** | **Giá trị** | **Ghi chú** |
| --- | --- | --- |
| grid_cell_size | 2 m | 3.6.2. Mỗi công trình chiếm 1 ô |
| grid_cell_gap | 0.5 m | 3.6.2. Khoảng trống giữa hai ô |
| max_ground_buildings | 3 | GRID-04. Trần cố định; ô RUINED cũng chiếm chỗ. Cộng 3 WALL là 6 |
| path_check_min_width | 3.2 m | GRID-07. Bề rộng đường tối thiểu khi kiểm chặn kín, bằng đường kính agent lớn. Áp cho cả đường tới cổng và đường tới boss_melee_point |
| boss_point_clear_radius | 3.2 m | GRID-08. Bán kính cấm sinh ô grid quanh boss_melee_point, đo tới điểm gần nhất của ô; bằng hai lần bán kính nav_layer_large (1.6 m) |
| grid_min_gap_to_command_post* | 3 m | GRID-03, BOSS-08 |

**Quân và aggro**

| **Tham số** | **Giá trị** | **Ghi chú** |
| --- | --- | --- |
| retarget_interval | 0.4 s | ETG-02 |
| path_update_interval | 0.3 s |  |
| aggro_duration | 4 s | AGG-01 |
| leash_distance | 25 m | AGG-05 |
| max_aggro_melee | 8 | AGG-06. Sức chứa slot đánh chỉ huy |
| bat_max_per_target* | 6 | CRD-06 \[Should]. Số Bat tối đa cùng đánh một mục tiêu |
| enemy_windup_time* | 0.4 s | Trạng thái ATTACK, chung mọi loại quân |
| enemy_stagger_time* | 0.4 s | STAGGER |
| enemy_knockback_immunity_time* | 2 s | AI-04 |
| retarget_batch_size* | 8 | ETG-08 \[Should]. Số quân retarget tối đa mỗi physics frame sau sự kiện hàng loạt |
| spawn_grace_max_time* | 10 s | EN-04. Trần thời gian bất tử khi mới sinh |
| frenzy_speed_mult* | 1.5 | EN-02 |
| straggler_marker_time* | 60 s | EN-01 |
| frenzy_time* | 240 s | EN-02 |

*Sức chứa slot đánh Fortress (12) thuộc FortressStats, không lặp ở đây.*

**Chống kẹt và đám đông (MVP)**

| **Tham số** | **Giá trị** | **Ghi chú** |
| --- | --- | --- |
| stuck_detect_time | 3 s | NAV-01 |
| stuck_progress_min | 0.5 m | NAV-01 |
| stuck_escalate_time* | 3 s | Thời gian giữa hai bậc (NAV-07, NAV-08). Khác stuck_detect_time |
| stuck_reset_time* | 10 s | NAV-02 |
| queue_block_distance* | 1.5 m | NAV-02 |
| commander_block_wait* | 2 s | NAV-05 |
| recycle_max | 2 | NAV-08 |
| wave_hard_cap | 300 s | NAV-13, tính từ lần spawn cuối |
| boss_stuck_time | 5 s | BOSS-04 |
| boss_stuck_step_time* | 5 s | Khoảng giữa các bậc của boss |
| boss_hop_radius | 6 m |  |
| crowd_claim_distance* / crowd_wait_ring* | 6 m / 3 m | CRD-01 |
| crowd_wait_retarget_time* / crowd_full_target_ignore_time* | 3 s / 5 s | CRD-02 |
| crowd_slot_audit_interval* | 2 s | CRD-04 |

\[Should] (chưa làm thì để trống): wave_stall_timeout 45 s, hop_radius 3 m, hop_max_advance 4 m, no_damage_timeout 10 s.

**Boss chung**

| **Tham số** | **Giá trị** | **Ghi chú** |
| --- | --- | --- |
| boss_intro_duration* / boss_intro_skip_delay* | 4 s / 1 s | BOSS-17, BOSS-18 |
| boss_transition_time* | 2.5 s | Pha TRANSITION |
| boss_timer_base* / _step* / _max* | 90 / 3 / 120 s | boss_timer(n) = min(max, base + step × (n−1)), n = w / 5 |
| enrage_warn_time* | 30 s | BTM-04 |
| enrage_countdown_time* | 10 s | BTM-04 |
| enrage_speed_mult* / enrage_attack_rate_mult* / enrage_damage_mult* | 1.3 / 1.3 / 1.5 | ENR-02 |
| enrage_reward_mult* | 0.5 | BRW-02 |

**Vòng lặp Frontline và Skill \[MVP]**

| **Tham số** | **Giá trị** | **Ghi chú** |
| --- | --- | --- |
| frontline_aura_radius* | 12 m | FRT-01 |
| frontline_aura_dmg_bonus* | 0.20 | FRT-01 |
| frontline_gold_mult* | 1.25 | FRT-02 |
| xp_commander_pct* / xp_tower_only_pct* | 1.0 / 0.5 | XP-02 |
| xp_base* / xp_step* | 5 / 4 | XP-04 |
| tower_max_level | 36 | UPG-03 |
| tower_tier2_level / tower_tier3_level | 13 / 25 | TWR-17. Cấp đầu bậc model 2 và 3 |
| tower_gate_tier2* / tower_gate_tier3* | 4 / 8 | FRT-03. Cấp Chỉ huy cần để nâng lên cấp 13 và cấp 25 (thay tower_gate_lv2/lv3) |
| skill_max_level* | 3 | SKL-02, \[Should] 5 |
| skill_slots_active* / skill_slots_passive* | 3 / 3 | SKL-01 |
| stat_max_stacks* | 3 | SKL-04 |
| rerolls_per_run* | 1 | RWP-03 |
| reward_weight_owned* / _new* / _stat* | 40 / 30 / 20 | RWP-07 |

Nút cân bằng ưu tiên khi chỉnh (không sửa code): tower_gate_tier2/tier3 trước, bonus Aura sau, xp_tower_only_pct cuối (Phụ lục C #15, #26).

**Thời gian**

| **Tham số** | **Giá trị** | **Ghi chú** |
| --- | --- | --- |
| fps_downscale_floor* / fps_downscale_duration* | 30 FPS / 3 s | TIME-06. Hiện chỉ định nghĩa hạ x3 về x2 |
| max_physics_steps_per_frame | 8 (đề xuất) | Là Project Setting của Godot (Physics > Common), không phải Resource. SRS chưa ghi giá trị, 8 là mặc định của Godot |

**Trạm hồi lực, camera, tài khoản**

| **Tham số** | **Giá trị** | **Ghi chú** |
| --- | --- | --- |
| heal_tower_cost / heal_tower_hp | 80 gold / 300 | HLT-01, HLT-08. Không có level |
| heal_range / heal_drain_rate / heal_rate_base | 3 m / 20 HP/s / 10 HP/s | HLT-06. heal_rate tăng 5 HP/s mỗi level SKL-26 |
| heal_tower_max_count / heal_tower_limit_lv | 2 / 6 | HLT-02. heal_tower_limit_lv chỉ dùng khi làm HLT-12 \[Should] |
| heal_tower_dmg_norm_exp | 0.5 | HLT-09 |
| camera_size_frontline / camera_size_overview | theo CAM-01 (12-14 m mỗi bên) / chốt ở tuần 1 | CAM-01, CAM-02. Chỉnh bằng mắt trên map thật |
| camera_follow_smooth / camera_pan_speed | 0.15 s / chốt ở tuần 1 | CAM-01, CAM-03. Thời gian thực |
| camera_lookahead | 2 m | \[Should] CAM-06 |
| online_enabled / backend_url | true / để trống trong repo | ACCT-12. Không đưa khóa riêng vào repo |
| sync_timeout / lbd_top_n | 10 s / 50 | ACCT-07, LBD-08 |
| lbd_min_seconds_per_wave | 15 s | LBD-06. Phải ≤ spawn_duration nhỏ nhất của mọi wave (SPN-15, BAL-05) |
| lbd_elapsed_tolerance | 1 s | LBD-06. Sai số tổng do làm tròn frame |
| display_name_min_len / display_name_max_len | 3 / 16 | LBD-09 |


**Giới hạn UI, cảnh báo, âm thanh**

| **Nhóm** | **Giá trị** | **Nguồn** |
| --- | --- | --- |
| Thanh máu quân, số nổi | tối đa 40 thanh, 60 số, gộp số trong 0.2 s | HUD-09, FBK-02 |
| Cảnh báo | tối đa 1 banner, 3 toast, không lặp trong 5 s, toast T2 sống 2.5 s, T3 sống 2 s | ALR-13, ALR-14, 4.3 |
| Nhấp nháy | tối đa 3 lần/giây mọi hiệu ứng | ACC-06 |
| SFX | tối đa 32, tối đa 4 lần cùng âm, chống lặp 50 ms (80 ms ở x3) | AUD-02, AUD-03 |
| Ducking \[Should], crossfade | T1 hạ nhạc 6 dB trong 1.5 s, crossfade nhạc 1.5 s | AUD-05, AUD-06 |
| Thời gian UI (thời gian thực) | khóa nút giao dịch 0.15 s, fade chuyển màn 0.25 s, xác nhận độ phân giải 10 s | PNL-08, SCR-15, SET-01 |

*Âm lượng mặc định bus (Master 80%, Music 60%, SFX 80%, UI 70%) và giới hạn hạt theo preset (500, 1500, 3000) thuộc settings.cfg, không thuộc GameConfig.*

## 6.4 CharacterStats

Từ v2.0 CharacterStats sinh từ sheet character của bảng cân bằng (mục 6.10); bảng dưới là giá trị khởi điểm.

| **Tham số** | **Giá trị** | **Ghi chú** |
| --- | --- | --- |
| commander_max_hp | 100 | Giá trị gốc. HP thực = 100 + 10 × cấp CMD_HP, tính ở RunLoading |
| armor_pct | 0.0 | 0 gốc. Nguồn cộng duy nhất ở MVP: passive Armored (SKL-14). Trần lấy từ commander_armor_cap (GameConfig) |
| prep_heal_pct | 0.35 | Hạ từ 0.60 ở v1.9. Áp cho cả hai chế độ |
| heal_hold_time* | 1.0 s | Game time. Thời gian giữ E để được phép hồi ở Trạm hồi lực (HLT-03). commander_regen_pct_per_sec đã xóa ở v1.9 |
| commander_low_hp_warning_pct* | 0.25 | ALR-02, DEAD-07 |
| move_speed | 6 m/s |  |
| dodge_distance / dodge_iframe / dodge_cooldown | 4 m / 0.3 s / 1.5 s |  |
| sword_damage / sword_damage_type | 20 / SLASH |  |
| sword_range / sword_arc_deg | 2.2 m / 120 |  |
| sword_max_targets | 3 | CMB-09 |
| skill_sword_wave_speed* | 20 m/s | SKL-11 |
| skill_firebomb_cast_range* | 10 m | SKL-12 |
| attack_interval / combo_hit3_mult | 0.45 s / 1.5 |  |
| skill_cooldown | 12 s | Battle Cry |
| mode_switch_cooldown | 5 s | Cả hai chiều |
| Tham số kỹ thuật khác* | combo\_\*, input_buffer_time, skill_animation_time, battle_cry\_\*, recall_time\_\*, deploy\_* (gồm deploy_clear_radius, deploy_shockwave_*), fall_damage_pct | Cùng thuộc CharacterStats, giá trị ở bảng mục 3.5.1 |

## 6.5 FortressStats

| **Tham số** | **Giá trị** | **Nguồn** |
| --- | --- | --- |
| fortress_max_hp | 1000 | Giá trị gốc. HP thực = 1000 × (1 + 0.05 × cấp FORT_HP), tính ở RunLoading |
| fortress_armor_pct | 0.0 | Luôn 0 ở MVP. Trần lấy từ fortress_armor_cap (GameConfig) |
| fortress_melee_slots | 12 | Nguồn duy nhất của số 12 (3.7.4 trỏ về đây) |
| mithril_repair_pct | 0.20 | HP hồi mỗi viên Mithril, theo fortress_max_hp hiệu dụng (MTH-03). Thay repair_gold_per_pct của v1.9 |
| low_hp_warning_pct | 0.30 | UI đọc từ đây (ALR-01, HUD-01) |

## 6.6 Các Resource còn lại

Bảng giá trị đầy đủ nằm ở mục đã trỏ. Bảng này chỉ ghi phần giá trị đã có trong SRS nhưng chưa có chỗ đặt.

| **Resource** | **Giá trị nằm ở** | **Bổ sung** |
| --- | --- | --- |
| TowerData | 3.6.3 | arrow_projectile_speed* = 30 m/s (PRJ-01). cannon_falloff_edge* = 0.5 (sát thương nổ ở mép, PRJ-02). default_priority*: Arrow = First, Cannon = Nearest. Dữ liệu 36 cấp của bốn loại (cost, chỉ số, hp; kho của Trạm hồi lực, cấp 1 là heal_tower_hp* = 300 và heal_tower_cost* = 80) sinh từ sheet towers (BAL). model_tier_scenes: 3 scene model theo bậc (TWR-17). Trạm hồi lực không có target_priority. |
| EnemyData | 3.7.1, RWD-05 | xp_value: Grunt 1, Archer 2, Brute 5 (XP-01). resist_table tùy chọn (FRT-05 \[Should]). Archer: projectile_speed* = 20 m/s (AI-02). Trait của quân mới (mục 3.7.1, 3.7.8) và chỉ số của 7 loại mới sinh từ sheet enemies (BAL). avoid_radius và avoid_priority đã bỏ (EN-16) |
| BossData | 3.8.2 | xp_value = 30 (XP-01). nav_radius* = 1.6 m (BOSS-03). resist_table pha TRANSITION = ×1.5 và EXPOSED = ×1.25 cho mọi loại, không miễn nhiễm (3.8.4) |
| ScaleConfig | 3.7.6 | scale_soft_cap_wave = 40. budget_soft_cap_factor* = 0.5 (SCL-02) |
| WaveTable | 3.7.5 | archer_max_ratio* = 0.40 (SPN-05). support_max_ratio* = 0.20 (SPN-06). support_min_combat* = 3 (SPN-07). group_count = clamp(2 + floor(w/5), 2, 6). Khoảng cách spawn trong nhóm 0.4 đến 0.8 s, nghỉ giữa nhóm 3 s. spawn_overlap_radius* = 1 m, spawn_retry_delay* = 0.2 s, spawn_retry_timeout* = 3 s (SPN-03). escort_budget_ratio* = 0.5 (SPN-10). intro_count*: Archer 2, Bat 2, Brute 1 (bước 2 của thuật toán mục 3.7.5) |
| ShopItem | 3.10.1 | Tác dụng mỗi cấp nằm ở đây: FORT_HP +0.05, GOLD_PCT +0.04, CMD_HP +10, EMG_REPAIR +0.03 (cộng vào emg_repair_base_heal_pct). \[Should]: SLOT_ACTIVE, SLOT_PASSIVE, REROLL_PLUS, SKILL_UNLOCK_*, BUFF_CHARGE, UNLOCK_TRAP. STARTER_KIT và UNLOCK_WAND đã bỏ ở v2.0 |
| WeaponData | 3.5.13 | frost_slow_pct* = 0.20, frost_duration* = 3 s; chain_damage_pct* = 0.20, chain_max_targets* = 3, chain_radius* = 2 m, chain_cooldown* = 5 s; burn_total_pct* = 0.50, burn_duration* = 5 s; rampage bậc (0.8, 0.5, 0.3) và bonus (0.10, 0.25, 0.50); swift_attack_speed_mult* = 1.5, swift_range_mult* = 0.7. Sinh từ sheet weapons (BAL) |
| WaveScript | 3.7.5, SPN-13 | Mỗi wave 1-30: danh sách {enemy_type, count, is_escort}, spawn_duration, hp_mult, dmg_mult, speed_mult. Sinh từ sheet waves (BAL) |
| WaveRewardTable | 3.9.1, MTH-02 | Mỗi wave 1-30: gold_mult, xp_mult, mithril_reward. Sinh từ sheet wave_rewards (BAL) |
| SkillData | 3.5.12 | Một Resource cho mỗi skill, bảng giá trị theo level tại 3.5.12.1 đến 3.5.12.3. Trọng số reward lấy từ GameConfig (reward_weight_*) SKL-26 (Trạm hồi lực): bảng heal_rate theo level 10, 15, 20, 25 HP/s (3.6.6). |

## 6.7 Dữ liệu chạy (không phải Resource)

| **Đối tượng** | **Chứa** | **Ghi chú** |
| --- | --- | --- |
| RunConfig | start_wave, starting_gold, start_mult (MVP cố định, chỉ đổi khi có \[Should] chọn wave khởi đầu), run_seed và các giá trị gốc đã cộng meta: fortress_max_hp, commander_max_hp, emg_repair_heal_pct, gold_pct_meta | Tạo ở RunLoading, bất biến suốt run (APL-01). emg_repair_heal_pct = emg_repair_base_heal_pct + 0.03 × cấp EMG_REPAIR |
| RunState | Theo bảng 3.2.2, gồm emg_repair_charges, emg_repair_cd, wave_index, gold, mithril, owned_weapons, equipped_weapon, chain_cd, hazard_used, hazard_session, victory_reached, is_starter theo slot, ruined_type và ruined_level theo slot (slot WALL và ô grid), xp, commander_level, pending_picks, active_slots, passive_slots, stat_stacks, rerolls_left, reward_rng, boss_enraged, thống kê run... | Không ghi xuống đĩa giữa run (RUN-01) Thêm heal_phase, heal_hold, heal_station_built (3.2.2) và HP kho của từng Trạm hồi lực theo slot. |
| Dữ liệu trong scene (Marker3D, Area3D) | spawn_zone 12 m đầu hành lang, return_zone bán kính 5 m, 3 slot WALL, node GroundGrid (sinh ô grid từ GridData), command_post, deploy_point, boss_melee_point (BOSS-40), lane_curve (TWR-16), hazard_portal (Tháp Hazard Trial gần Fortress, HZT-01), hazard_room (khu vực phòng: điểm xuất hiện chỉ huy, các điểm sinh quái, khung camera cố định, CAM-16) | Cố định theo level, người làm Level sở hữu |

## 6.8 Cấu trúc save

Xem mục 3.12.1. settings.cfg là tệp riêng, cấu trúc ConfigFile của Godot, chứa âm lượng bus và cài đặt đồ họa (xem ghi chú cuối mục 6.3). user://auth.cfg là tệp riêng cho phiên đăng nhập (ACCT-03), không thuộc endlesswar_save.json và không đồng bộ. Các trường revision, updated_at, device_id nằm cạnh checksum (mục 3.12.1).

## 6.9 Danh mục tín hiệu EventBus

Danh mục này là nguồn chuẩn cho tên và payload tín hiệu của autoload EventBus (UI-04, mục 5.5). Quy ước: (1) tên snake_case, động từ ở thì quá khứ (gold_changed); (2) payload có kiểu tường minh, không truyền tham chiếu node, chỉ giá trị; (3) chỉ vai phát bởi mới được emit, vai khác chỉ lắng nghe; (4) thêm hoặc đổi tín hiệu phải sửa bảng này và ghi vào Phụ lục D trước khi merge; (5) giá trị StringName dùng đúng tên state và loại đã nêu trong SRS (PREP, HAZARD_TRIAL, COMBAT, BOSS_INTRO, BOSS_COMBAT, SUMMARY, REWARD_PICK, RUN_END; FRONTLINE, COMMANDER).

| **ID** | **Tín hiệu (payload)** | **Phát bởi, lắng nghe** |
| --- | --- | --- |
| EVB-01 | state_changed(new_state: StringName, old_state: StringName) | Enemy & Wave (wave FSM). Nghe: UI, Audio, thời gian |
| EVB-02 | wave_started(wave_index: int, is_boss: bool) | Enemy & Wave. Nghe: UI, Audio |
| EVB-03 | wave_cleared(wave_index: int, clear_time: float, summary_data: Dictionary) | Enemy & Wave. Nghe: UI (SummaryPanel), RunState. summary_data gồm kills_by_type, gold_base, gold_mult, gold_total, prestige_gain_wave, fortress_hp, ruined_towers (kèm giá xây lại), emg_repair_gained (mục 3.3.4), weapon_gained (WPN-11, rỗng nếu không có), xp_from_commander, xp_from_towers, commander_level, pending_picks |
| EVB-04 | enemy_count_changed(alive: int, queued: int, total: int) | Enemy & Wave. Nghe: UI |
| EVB-05 | enemy_died(enemy_type: StringName, gold_reward: float, world_pos: Vector3, source: StringName, hit_by_commander: bool) | Enemy & Wave. gold_reward mang giá trị kill_gold (RWD-02, đã gồm hệ số chỉ huy), bên nghe không nhân thêm frontline_gold_mult. Nghe: UI (số nổi), RunState (kill, thống kê), XpTracker (XP-01..03) |
| EVB-06 | gold_changed(new_gold: int, delta: int) | RunState. Nghe: UI, panel Tower |
| EVB-07 | fortress_hp_changed(new_hp: int, max_hp: int, delta: int) | Tower & Build (Fortress). Nghe: UI, cảnh báo ALR |
| EVB-08 | commander_hp_changed(new_hp: int, max_hp: int, delta: int) | Player & Combat. Nghe: UI, cảnh báo ALR |
| EVB-09 | commander_mode_changed(new_mode: StringName) | Player & Combat. Nghe: UI, camera, Audio |
| EVB-10 | commander_died(cause: StringName) | Player & Combat. Phát đúng một lần (DEAD-10). cause MVP: `ENEMY_DAMAGE`. Nghe: RunState (END-01) |
| EVB-11 | skill_cooldown_changed(skill_id: StringName, remaining: float, total: float) | Player & Combat. skill_id: battle_cry, dodge, mode_switch, emg_repair, skill_1, skill_2, skill_3. Nghe: UI |
| EVB-12 | emg_repair_changed(charges: int, cooldown_left: float) | Player & Combat. Nghe: UI (HUD-13) |
| EVB-13 | slot_changed(slot_id: StringName, slot_state: StringName, tower_type: StringName, level: int) | Tower & Build. Nghe: UI, panel Tower, Art |
| EVB-14 | target_priority_changed(slot_id: StringName, priority: StringName) | Tower & Build. Nghe: panel Tower |
| EVB-15 | boss_timer_changed(seconds_left: float) | Enemy & Wave (boss). Nghe: UI, cảnh báo ALR, Audio |
| EVB-16 | boss_phase_changed(new_phase: StringName) | Enemy & Wave (boss). Nghe: UI, Audio |
| EVB-17 | boss_enraged() | Enemy & Wave (boss). Nghe: UI, Audio, Player & Combat |
| EVB-18 | time_scale_changed(new_scale: int, locked: bool) | Thời gian (TimeManager). Nghe: UI (cụm nút tua), Audio |
| EVB-19 | pause_changed(is_paused: bool) | Thời gian (TimeManager). Nghe: UI, Audio |
| EVB-20 | alert_requested(tier: int, key: StringName, params: Dictionary) | Mọi vai. Nghe: UI (hàng đợi cảnh báo ALR, tier 1 đến 3) |
| EVB-21 | run_ended(end_type: StringName, stats: Dictionary) | RunState. stats có run_result (DEFEAT hoặc SURVIVED, mục 3.2.4). Nghe: UI (RunEnd), Save |
| EVB-22 | meta_changed(item_id: StringName, new_level: int, prestige: int) | UI/UX & Meta (shop). Nghe: UI |
| EVB-23 | settings_changed(section: StringName, key: StringName, value: Variant) | UI/UX & Meta (Settings). Nghe: Audio, camera, UI |
| EVB-24 | \[ĐÃ XÓA v1.8] retreat_zone_changed | Retreat không còn. Không dùng lại số này |
| EVB-26 | xp_changed(xp: float, level: int, to_next: float, pending_picks: int) | RunState. Nghe: UI (HUD-15) |
| EVB-27 | level_up(new_level: int, pending_picks: int) | RunState. Nghe: UI, Audio, panel Tower (UPG-06) |
| EVB-28 | reward_offered(cards: Array, rerolls_left: int) | Tower & Build (RewardOfferGenerator). Nghe: UI (SCR-17) |
| EVB-29 | reward_picked(card_id: StringName, slot_kind: StringName, new_level: int) | UI. Nghe: Player & Combat (StatBlock, SkillRunner), RunState |
| EVB-30 | skill_slots_changed(active: Array, passive: Array, levels: Dictionary) | Player & Combat. levels là cấp của từng skill đang nằm trong ô (id -> cấp). Nghe: UI (HUD-16, ô skill ở SCR-17) |
| EVB-31 | aura_changed(active: bool) | Player & Combat. Nghe: UI (HUD-17), Tower & Build |
| EVB-32 | commander_low_hp_changed(is_low: bool) | Player & Combat. Phát khi HP chỉ huy xuống dưới commander_low_hp_warning_pct (is_low = true) hoặc lên lại (false), chỉ khi trạng thái đổi (DEAD-07). Nghe: UI (viền đỏ, nhịp tim), Audio (giảm nhạc nền) |
| EVB-33 | heal_state_changed(state: StringName, source_slot: StringName, hold_progress: float) | Player & Combat. state thuộc IDLE, HOLD, HEALING, CANCELLED, DEPLETED. Phát khi đổi state, hold_progress cập nhật tối đa 10 lần/giây. Nghe: UI (HUD-18, HLT-11), Audio (AUD-07), hiệu ứng (FBK-12) |
| EVB-34 | heal_tower_hp_changed(slot_id: StringName, new_hp: int, max_hp: int) | Tower & Build. Phát khi HP kho đổi, gộp tối đa 10 lần/giây. Nghe: UI (HLT-11, PNL-14), cảnh báo ALR-17, ALR-18 |
| EVB-35 | camera_frame_changed(frame: StringName) | Art / Level / Audio (CameraRig). frame thuộc FRONTLINE, OVERVIEW, BOSS_INTRO, HAZARD_TRIAL. Phát khi bắt đầu chuyển khung (CAM-05). Nghe: UI (HUD-10, tooltip phím), Audio |
| EVB-36 | sync_state_changed(state: StringName, detail: String) | UI/UX & Meta (SyncService). state thuộc GUEST, SYNCED, SYNCING, OFFLINE, ERROR (ACCT-07; CONFLICT là \[Should]). Nghe: UI (MainMenu, Settings) |
| EVB-37 | summary_continue_requested() | UI/UX & Meta (SummaryPanel). Phát khi bấm Tiếp tục hoặc hết 10 s đếm ngược ở SUMMARY (thời gian thực, dừng khi Pause), tối đa một lần mỗi SUMMARY. Nghe: Enemy & Wave (rời SUMMARY theo WAVE-13: màn thắng SCR-20 nếu vừa thắng, rồi REWARD_PICK nếu pending_picks > 0, rồi PREP) |
| EVB-38 | wave_start_requested() | UI/UX & Meta (nút Bắt đầu wave, HUD-19). Nghe: Enemy & Wave (kết thúc PREP, WAVE-11) |
| EVB-39 | mithril_changed(new_mithril: int, delta: int) | RunState. Nghe: UI (HUD-20, PNL-04) |
| EVB-40 | hazard_trial_entered(wave_index: int, enemy_types: Array) | Enemy & Wave (HazardTrial). Nghe: UI (HUD-22), camera (CAM-16), Audio, Player & Combat (tạo bản sao chỉ số, HZT-06) |
| EVB-41 | hazard_trial_exited(result: StringName, kills: int, gold: int, xp: float, mithril: int) | Enemy & Wave (HazardTrial). result thuộc WON, LEFT, DIED. Phát sau khi RunState đã cộng thưởng. Nghe: UI (toast ALR-20, HUD-23), camera, Audio |
| EVB-42 | weapon_gained(weapon_id: StringName) | RunState. Nghe: UI (SummaryPanel, ALR-19, HUD-21) |
| EVB-43 | weapon_equipped(weapon_id: StringName) | Player & Combat. Nghe: UI (HUD-21, PNL-15), Art (model, VFX) |
| EVB-44 | run_victory(wave_index: int) | RunState. Phát một lần mỗi run, ở bước mở màn thắng của WAVE-13 (sau khi SummaryPanel đóng, END-07). Nghe: UI (mở SCR-20), Audio, Save |
| EVB-45 | tutorial_completed() | UI/UX & Meta (tutorial). Phát khi ghi tutorial_done = true (TUT-08, TUT-15). Nghe: Save, SyncService |
| EVB-46 | victory_continue_requested() | UI/UX & Meta (màn thắng SCR-20). Phát khi bấm "Chơi tiếp", một lần. Nghe: Enemy & Wave (bỏ lý do Pause VICTORY, đi tiếp WAVE-13: REWARD_PICK nếu pending_picks > 0, ngược lại PREP của wave victory_wave + 1) |
| EVB-47 | xp_gained(amount: float, from_commander: bool) | XpTracker. Phát mỗi lần quân chết cho XP, ngay trước xp_changed; from_commander theo cờ hit_by_commander (XP-01). Nghe: UI (HUD-15, tách phần XP từ chỉ huy và từ tower) |

## 6.10 Bảng cân bằng Excel và công cụ dịch sang config \[MVP]

Từ v2.0 mọi số liệu cân bằng lấy từ một bảng Excel và được dịch sang `.tres` của game bằng công cụ, không sửa tay trong `.tres`. Mục đích: người cân bằng chỉnh số ở một chỗ, nhìn được cả 36 cấp và 30 wave cùng lúc, và game luôn đọc dữ liệu đã qua kiểm tra.

| **Sheet** | **Nội dung** | **Sinh ra** |
| --- | --- | --- |
| character | Chỉ số nhân vật (CharacterStats, mục 3.5.1 và 6.4), gồm xp_base, xp_step | `data/config/commander_stats.tres` |
| skills | Bảng giá trị theo level của skill chủ động, bị động và thẻ stat (mục 3.5.12) | `data/skills/*.tres` (SkillData) |
| towers | Giá và chỉ số 36 cấp của Arrow, Cannon, Barricade, Trạm hồi lực (mục 3.6.3, 3.6.6), một dòng mỗi loại mỗi cấp | `data/towers/<loại>.tres` và `data/towers/<loại>_l<n>.tres` (TowerData và dữ liệu theo cấp) |
| weapons | Kiếm gốc và 5 vũ khí: range_mult, tham số hiệu ứng (mục 3.5.13) | `data/weapons/*.tres` (WeaponData) |
| enemies | Chỉ số gốc, trait, thưởng gốc, xp_value của mọi loại quân (mục 3.7.1, 3.7.8) | `data/enemies/*.tres` (EnemyData) |
| waves | Kịch bản wave 1-30: mỗi wave một dòng mỗi loại quân (loại, số lượng, là hộ tống hay không), spawn_duration, hp_mult, dmg_mult, speed_mult (SPN-13, mục 3.7.6) | `data/waves/wave_script.tres` (WaveScript) |
| wave_rewards | Thưởng theo wave 1-30: gold_mult, xp_mult, mithril_reward (RWD-02, XP-01, MTH-02) | `data/waves/wave_rewards.tres` (WaveRewardTable) |

| **ID** | **Đặc tả** |
| --- | --- |
| BAL-01 | **Nguồn gốc duy nhất.** Bảng `balance/balance.xlsx` là nguồn chuẩn của mọi số liệu trong bảng trên (DAT-06). Mỗi nhóm số liệu một sheet, tên sheet và tên cột cố định như bảng trên để công cụ đọc được |
| BAL-02 | **Công cụ dịch.** Script Python trong `tools/balance/` dùng thư viện `openpyxl` đọc thẳng file Excel; **một lệnh** sinh lại mọi `.tres` ở cột "Sinh ra". Yêu cầu Python 3.13 và `pip install openpyxl`. Script không cần Godot để chạy |
| BAL-03 | **File sinh tự động.** Mỗi `.tres` sinh ra có dòng chú thích đầu file ghi rõ là file sinh tự động, sửa bảng chứ không sửa file. Chạy lại công cụ với cùng bảng cho ra cùng nội dung (thứ tự khóa ổn định) để diff trong git gọn |
| BAL-04 | **Phạm vi sinh.** Chỉ các Resource ở bảng trên. GameConfig, FortressStats, BossData, ScaleConfig, WaveTable (dùng từ wave 31), GridData, ShopItem và tham số UI giữ nguyên cách sửa tay hiện có. Từ wave 31 vẫn dùng công thức scale của ScaleConfig (mục 3.7.6) |
| BAL-05 | **Runner kiểm config.** Runner `tests/test_balance_config_runner.tscn` đọc các `.tres` đã sinh và kiểm: đủ cấp 1 đến tower_max_level (36) cho cả bốn loại tower; đủ wave 1 đến victory_wave (30) trong WaveScript và WaveRewardTable; mỗi wave không quá wave_max_enemy_types (5) loại quân kể cả boss; wave boss (w chia hết cho 5) có đúng một boss và ít nhất 1 hộ tống; spawn_duration mỗi wave ≥ lbd_min_seconds_per_wave (SPN-15, LBD-06); mọi loại quân trong kịch bản có EnemyData; không có ô trống, không có số âm. Runner chạy headless và nằm trong bộ runner chuẩn của mục 7 |
| BAL-06 | **Lỗi bảng.** Bảng thiếu ô, sai kiểu hoặc có số âm thì công cụ báo dòng và cột lỗi rồi dừng, không ghi file nào (không để bộ `.tres` nửa cũ nửa mới) |
| BAL-07 | **Không sửa tay.** Sửa tay một `.tres` sinh ra sẽ bị ghi đè ở lần chạy sau (DAT-07). Review PR kiểm `.tres` cân bằng đi kèm thay đổi tương ứng của `balance.xlsx` |

# 7. KIỂM CHỨNG VÀ NGHIỆM THU

## 7.1 Test case bắt buộc

Từ v2.0 đã bỏ các test của gọi wave sớm, đếm ngược PREP, sửa Fortress bằng gold, 8 Barricade sát no_build_lane, di chuyển và hoán đổi tower (MOV) và STARTER_KIT; thêm các nhóm HZ, WP, NE, VC, TU, BL ở cuối mục.

**Flow, wave, thời gian**

1. Cùng run_seed và wave_index: danh sách quân và boss sinh ra giống hệt qua nhiều lần chạy. Wave 1-30 có đúng thành phần của WaveScript, không phụ thuộc run_seed (SPN-13).
2. Bảng scale mục 3.7.6 và bảng boss mục 3.8.10 khớp công thức (hp_mult và dmg_mult chưa làm tròn, làm tròn gần nhất một lần) ở wave 31 trở lên; wave 1-30 đọc hệ số từ WaveScript (SCL-06). Từ wave 31 mỗi wave có tối đa 5 loại kể cả boss (SPN-14).
3. Vượt max_alive: quân dư chờ trong queue, không bị hủy, wave vẫn kết thúc.
4. FRENZY ở giây 240 và giới hạn cứng ở giây 300: quân cuối luôn chết hoặc bị cull, wave không treo (EN-02, NAV-13). Quân kẹt thật ở giây 250 bị recycle vẫn giữ FRENZY, đi thẳng Fortress với tốc độ x1.5; nếu không kịp thì bị cull ở giây 300 có log cờ frenzy (NAV-08).
5. Tua x1/x2/x3 không làm sai clear time, cooldown, combo, đồng hồ boss, telegraph, projectile (TIME-04).
6. Wave kết thúc cùng lúc Fortress sập: thua đè thắng, không cộng gold (WAVE-02, GLD-08).
7. Nhấn Play ở MainMenu vào thẳng RunLoading, start_wave = 1, starting_gold = 0; tutorial_done = true thì có Arrow cấp 1 ở starter_arrow_slot và Cannon cấp 1 ở starter_cannon_slot (FLOW-06, mục 3.2.1).
8. Pause ở BOSS_INTRO và SUMMARY: mở được Pause, đồng hồ BOSS_INTRO và bộ đếm 10 s của SUMMARY dừng, bỏ Pause thì chạy tiếp (TIME-02).
9. PREP không tự kết thúc dù để yên 10 phút game time; chỉ bấm nút Bắt đầu wave mới sang COMBAT (hoặc BOSS_INTRO). Phím G không làm gì. Nút xám khi Pause và khi có hộp thoại giao dịch (WAVE-11, HUD-19).
10. Vào Run: chỉ huy ở Frontline tại deploy_point, HP đầy (mục 3.2.1).
11. Wave sinh 0 quân do bảng lỗi: ép tối thiểu 1 Grunt, ghi cảnh báo, wave vẫn chạy và kết thúc (WAVE-08).

**Chỉ huy**

1. Recall bị hủy khi nhận sát thương, không tốn cooldown (MODE-01).
2. Deploy khi cổng kín quân không làm chỉ huy kẹt (MODE-02).
3. Dodge xuyên quân nhưng bị Barricade chặn (CMB-06).
4. Chỉ huy đứng yên ở điểm hẹp nhất của hành lang, không đánh: quân không chặn được hoàn toàn, vẫn còn đường đi và không có quân bị recycle chỉ vì chỉ huy (GRID-07, NAV-05, NAV-15).
5. Battle Cry kéo Grunt và Archer, không kéo boss (AGG-02).
6. Ở Commander, không gì có thể nhắm được chỉ huy (ETG-01).
7. Ở Commander mode, chỉ huy không nhận sát thương từ bất kỳ nguồn nào: đạn Archer đang bay, Stomp và AoE, \[Should] Shell nổ tại command_post. HP không đổi, không knockback (CMD-10).
8. Recall hoàn tất đúng frame đạn trúng: đạn trước frame Arriving gây sát thương bình thường, từ Arriving trở đi bị hủy (MODE-05).
9. Chỉ huy và Fortress chết cùng frame ghi FORTRESS_DESTROYED (END-01).
10. Cleave: đặt 6 Grunt trong hình quạt 120 độ, tầm 2.2 m. Mỗi đòn chỉ trúng đúng 3 quân gần chỉ huy nhất, mỗi quân nhận sát thương một lần, đòn 3 chỉ knockback 3 quân đó. Hòa khoảng cách chọn theo góc lệch nhỏ hơn, rồi entity_id (CMB-01, CMB-09).
11. Deploy khi deploy_point bị 10 quân vây: chỉ huy xuất hiện ở ứng viên hợp lệ đầu tiên theo thứ tự vòng 1, 2, 3, 4 m, kết quả giống nhau qua nhiều lần chạy cùng kịch bản. Kín cả 4 m thì dùng điểm mặc định kèm shockwave (MODE-02).

**Fortress, tower**

1. Xây, nâng, bán từng loại tower: tổng gold khớp TowerData sinh từ bảng cân bằng. Trụ có sẵn hoàn 0 + 60% phần gold nâng cấp (SELL-04, SELL-06). \[Should] Tower từ StartPack hoàn 0.
2. Bán tower ở mọi cấp đều hiện hộp thoại xác nhận (SELL-02, PNL-10 chưa làm). Đang mở hộp thoại bán thì nút Bắt đầu wave và Tháp Hazard Trial xám; ép PREP kết thúc bằng công cụ debug: hộp thoại tự đóng, tower không bị bán, gold và slot giữ nguyên (SCR-14).
3. Bấm Xây đúng frame PREP kết thúc: không mất gold, không có tower ma (BLD-02).
4. Chặn kín đường: dựng bố cục thử trên GridData có một điểm hẹp, xây công trình thứ ba ở ô làm mất đường rộng 3.2 m thì bị từ chối với BLOCKS_PATH, gold không đổi; ô khác vẫn xây được. Đống đổ nát và Barricade tính là vật cản. Bố cục thử thứ hai: công trình thứ ba còn để đường rộng 3.2 m tới cổng nhưng làm mất đường tới boss_melee_point thì cũng bị từ chối với BLOCKS_PATH. Với 3 công trình ở mọi bố cục hợp lệ, quân tới được cổng và Bulwark tới được boss_melee_point (GRID-07, BLD-10, BOSS-03).
5. Hai priority MVP (First, Nearest) chọn đúng mục tiêu trong kịch bản cố định 5 quân, kết quả xác định (TGT-01). \[Should] Thêm Highest HP, Lowest HP.
6. Emergency repair và sửa bằng Mithril không cùng lúc làm HP vượt max (FORT-03, MTH-04).
7. Nổ Cannon không gây sát thương cho chỉ huy và tower (PRJ-03).
8. Slot Fortress: 20 quân đến cùng lúc, đúng 12 đánh, 8 chờ, slot giải phóng khi quân chết (CRD-01 đến 04). Quân không va chạm nhau nhưng vẫn giữ đúng số slot (EN-16).
9. Tower cấp 14 bị phá: slot RUINED nhớ loại và cấp. Ở PREP kế, "Xây lại" tạo đúng tower cấp 14 với giá là tổng cost cấp 1 đến 14 theo TowerData, không phụ thuộc gold đã đầu tư, model bậc 2. Hoàn bán tower xây lại là 60% số gold đã trả, priority về mặc định (SLOT-08, BLD-07, TWR-03, TWR-17, CMD-06).
10. Slot RUINED không đủ gold: nút "Xây lại" xám kèm số thiếu, vẫn xây thường cấp 1 được. Xây thường hoặc xây loại khác thì slot quên cấp cũ. Bấm "Xây lại" đúng frame PREP kết thúc: không mất gold, không có tower ma (BLD-07, BLD-02).
11. Trụ có sẵn bị phá ở wave 1 rồi xây lại: giữ cấp, trả giá thường, giá trị đầu tư bằng gold đã trả, is_starter = false nên bán được ngay ở wave 2, hoàn 60% (TWR-13, SELL-06).
12. Nổ Cannon trúng cụm 10 Grunt đang đánh Barricade: không quân nào vào STAGGER hay bị knockback, slot đánh giữ nguyên (PRJ-08, CRD-03).
13. nav_progress thống nhất: quân đi bộ và quân bay cùng hình chiếu trên lane_curve có nav_progress bằng nhau (sai số dưới 0.01 m). Quân đi bộ vòng qua Barricade không làm thứ tự First đảo ngược so với quân bay. Quân bay vượt lên trước thì Arrow ở priority First chọn quân bay (TWR-16, cần Bat nên là \[Should]). \[Should] Hai lane khác độ dài: quân cùng nav_remaining có cùng nav_progress.
14. Đủ 3 công trình trên grid (kể cả ô RUINED): mục xây trên ô EMPTY xám kèm lý do "Đã đủ 3 công trình trên mặt đất", không xây được công trình thứ 4; xây trên ô RUINED vẫn được. Bán một công trình thì xây thêm được một (GRID-04, BLD-08).
15. Nạp level: có đúng 3 slot WALL W1-W3; số ô grid sinh ra đúng số ô khai báo trong GridData, mỗi cột 9 ô cách nhau 0.5 m (trừ ô bị bỏ theo GRID-03, GRID-08), không ô nào nằm trong spawn_zone, return_zone hay vùng cấm quanh boss_melee_point; slot_id không trùng; bấm vào mép giữa hai ô chỉ chọn một ô (GRID-02, GRID-03, GRID-05, GRID-08, SLOT-05).
16. Sang run mới mọi ô grid về EMPTY, cell_id không đổi (SLOT-05). (Test Overload phá ô grid của v1.7 đã xóa cùng TWR-08.)
17. \[MVP] Dọn đổ nát ở PREP: slot RUINED về EMPTY ngay, không có hộp thoại, gold không đổi, mất mục "Xây lại". Dọn đống đổ nát Barricade thì obstacle mất. Grid đang đủ 3 (có ô RUINED): dọn một ô thì ground_used còn 2 (trần vẫn 3) và xây được trên ô EMPTY khác. Ở COMBAT không có nút. Bấm đúng frame PREP kết thúc: hoặc dọn xong trước khi chuyển state hoặc bị từ chối (CLR-01 đến CLR-04, GRID-04).
18. Nâng cấp 36 cấp: Arrow cấp 12 nâng lên 13 khi commander_level = 3 bị chặn kèm "Cần Chỉ huy cấp 4"; ở cấp 4 thì nâng được và model đổi sang bậc 2; cấp 13 lên 24 không cần thêm điều kiện; lên 25 cần cấp 8; cấp 36 hiện "MAX" (FRT-03, UPG-01, UPG-03, UPG-06, TWR-17).
19. Trụ có sẵn: ở PREP wave 1 và 2 nút Bán xám kèm "Bán được từ wave 3"; ở PREP wave 3 bán được. Arrow có sẵn nâng lên cấp 2 rồi bán: hoàn floor(0.6 × cost cấp 2) (SELL-06, SELL-04).
20. Trạm hồi lực cấp 1 còn 120/300 kho, nâng lên cấp 2: kho tăng đúng phần max_hp tăng thêm, không hồi đầy. Bị phá ở cấp 2 rồi xây lại: giữ cấp 2, kho đầy theo cấp 2 (HLT-07, HLT-08, UPG-02).
21. \[MVP] Vùng cấm và điểm đứng của Bulwark, nghiệm thu trên map thật: (a) nạp level thì không có ô grid nào có điểm gần nhất cách boss_melee_point dưới boss_point_clear_radius (3.2 m), starter_arrow_slot nằm ngoài vùng đó; (b) bố cục xấu nhất: runner thử mọi tập 3 ô mà GRID-07 chấp nhận (xây lần lượt) trong các ô cách boss_melee_point không quá 10 m, chọn tập có khe hẹp nhất trên đường tới boss_melee_point theo hàm kiểm của GridData, đặt Barricade ở cả 3 ô, 3 slot WALL có tower; (c) sinh Bulwark wave 5 ở x1 và x3, không cho tower và chỉ huy gây sát thương: Bulwark dừng trong 0.3 m quanh boss_melee_point, không kích hoạt bậc 2 hay bậc 3 của BOSS-04, quay mặt về Fortress và Stomp đầu tiên làm fortress_hp giảm (GRID-07, GRID-08, BOSS-03, BOSS-32, BOSS-40).

**Kẻ địch**

1. Grunt chọn Barricade trước tower, chuyển sang chỉ huy khi bị khiêu khích, trở lại bảng gốc sau 4 s (ETG-05).
2. Archer ưu tiên tower rồi người chơi rồi Barricade, dừng đúng tầm 11 m.
3. Quân melee không nhắm tower WALL.
4. Quân trong spawn_zone không bị tower nhắm, chỉ huy không vào được (SPN-02, EN-04).
5. Thưởng chỉ tính một lần khi hai sát thương chí mạng cùng frame (RWD-01).
6. Kẹt giả lập (khóa quân bằng vật cản): đi đúng bậc 1, rồi bậc 3 (recycle), rồi bậc 4 (cull); mỗi bậc chỉ kích hoạt khi bậc trước không gỡ được, bộ đếm reset sau 10 s tiến triển (NAV-06, NAV-08, NAV-09). \[Should] Có thêm bậc 2 hop (NAV-07).
7. \[Should] Hop cục bộ không vượt qua Barricade, tower hoặc tường, không tiến quá 4 m về phía Fortress (NAV-07).
8. Quân không va chạm nhau: 10 Grunt đi qua nhau không chen, không có ca kẹt do đồng đội; quân ở WAIT không bị tính kẹt (EN-16, NAV-02). \[Should] Quân ATTACK hụt 3 đòn liên tiếp chọn lại mục tiêu (NAV-10).
9. Cull chỉ xảy ra sau khi recycle đủ 2 lần, không thưởng, không tính kill, có log (NAV-08, NAV-09, RWD-03).
10. Sau 300 s kể từ lần spawn cuối, wave luôn kết thúc (NAV-13). \[Should] Watchdog: giữ 5 quân bất động ngoài tầm mọi tower, sau 45 s bị recycle (NAV-11).
11. Kiểm tra kẹt MVP: chạy tay hoặc script ít nhất 20 wave ở x3 với seed khác nhau, mọi wave kết thúc, quân bị cull dưới 0.1% (NAV-14). \[Should] Soak test bằng bot 200 wave ở x3.
12. \[Should] Spawn_queue rỗng, còn hai Healer là quân cuối: cả hai chuyển hành xử Archer và wave kết thúc. Còn một Healer cùng một Grunt thì chưa chuyển (EN-10).
13. \[Should] Sát thương lên quân thường: BUFF_FURY cùng Armored, raw 20 gây đúng 20 (1.25 × 0.8, không phải 21 như khi cộng chung); raw 1 gây 1. Lên boss không có sàn 1 (DMG-06, DMG-04).

**Boss**

1. Bulwark pha 1: Arrow không bắn, Cannon 100%, kiếm 60% (DMG-02). \[Should] Barrage: ngược lại.
2. armor_hp về 0 chuyển pha đúng một lần, sát thương dư bị bỏ (BOSS-09, BOSS-10).
3. TRANSITION: boss không di chuyển, không tấn công, nhận x1.5, đồng hồ không dừng (BOSS-11).
4. Bulwark bị Barricade chặn đường quá 5 s: đặt vật cản làm mục tiêu bắt buộc rồi phá đường. Boss không bao giờ bị recycle hay cull (BOSS-04, NAV-12).
5. Bulwark tới Fortress dừng đúng boss_melee_point, Stomp chạm tường, không chiếm melee_slot. Thiếu marker thì dùng điểm dự phòng và ghi log (BOSS-32, BOSS-40).
6. enemies_alive == 0 khi đồng hồ boss chưa về 0 (lỗi giả lập): coi như boss chết, wave kết thúc không Cuồng nộ, có log (BOSS-39, BOSS-21).
7. \[Should] Barrage tiến vào 18 m của Arrow cấp 1 (tầm 14 m): vẫn bắn nhưng tiếp tục ADVANCE, dừng ở 13 m rồi bị Arrow bắn trả. Barrage không dừng và không bắn khi còn trong spawn_zone dù có tower trong 18 m; spawn_grace tự hết sau tối đa 10 s (BOSS-41, EN-04).
8. Tua x2/x3 dùng được suốt BOSS_COMBAT, không có khóa theo đồng hồ boss (TIME-03).

Các test Overload, Retreat, ép x1 ở T-20, cảnh báo y% và retarget sau Overload của v1.7 đã xóa. Test Cuồng nộ, kháng boss với skill và đường thắng nằm ở nhóm "Frontline, XP, Skill, Cuồng nộ" (F10 đến F12, F14).

**Kinh tế, shop, save**

1. Wave 1 mặc định: 0 gold và hai trụ có sẵn (tutorial_done = true) hoặc tutorial xây hai trụ (tutorial_done = false). Gold sau wave 1 khớp WaveRewardTable và số quân diệt (GLD-06, RWD-02).
2. clear_mult không đổi khi tua tốc độ. gold_pct_total chỉ áp lên gold từ quân và boss.
3. Thua giữa wave: gold không cộng, buffer uy tín tính 50%, waves_cleared không tăng.
4. prestige_gain với start_mult 1.0 khớp công thức, làm tròn xuống một lần. \[Should] Với start_mult 0.6 cũng khớp.
5. Shop MVP chỉ hiện 4 mục (FORT_HP, GOLD_PCT, CMD_HP, EMG_REPAIR), mục \[Should] bị ẩn; tổng chi phí 1 720 danh vọng (SHP-11, mục 3.10.1).
6. Mua từng cấp: không nhảy cấp, không mua khi thiếu tiền, bấm liên tục chỉ trừ một lần. Ghi save lỗi thì hoàn tác (SHP-05 đến 08).
7. Gold Hazard Trial cộng khi rời phòng, không nhân clear_mult; gold quân trong wave thật vẫn cộng ở SUMMARY (GLD-02, GLD-10).
8. \[Should] Nạp 2 buff, kích hoạt 1: kho trừ đúng 1, hết run hoàn lượt còn lại.
9. \[Should] BUFF_WARD bật, ép fortress_armor_pct = 60% bằng công cụ debug: raw 100 gây ceil(100 × 0.4 × 0.75) = 30. TRUE (cú rơi khỏi map) không bị giảm (DMG-05, mục 3.6.1, APL-03).
10. \[Should] Mở mốc 10 sau khi hoàn thành wave 10. Chơi từ mốc 10 lên wave 20 mở mốc 20 và ghi best_by_start\["10"] riêng.
11. Mất điện giữa wave 7 (hoặc khi đang ở Hazard Trial của PREP wave 7): lần mở sau tự chốt run theo waves_cleared đã ghi ở SUMMARY wave 6, thông báo một lần.
12. Xóa endlesswar_save.json giữa lúc chơi: nạp từ endlesswar_save.bak. Hỏng cả hai: thông báo, giữ .corrupt.
13. Sửa checksum: chuyển .bak. save_version lớn hơn: từ chối nạp, không ghi đè (SAV-09). \[Should] Migrate không mất dữ liệu (SAV-07, SAV-08).
14. RunEnd: run_kills, run_gold_earned, bosses_defeated và loại tower gây nhiều sát thương nhất khớp số liệu chơi. run_kills và bosses_defeated cộng vào profile.stats, tăng profile.stats.total_runs thêm 1, đúng một lần, run_gold_earned và damage_by_tower_type không lưu (mục 3.2.4, BRW-06).
15. Mở hai phiên bản game cùng lúc: bản ghi sau thắng, không lỗi, save không hỏng (SAV-15).
16. Đổi đồng hồ hệ thống lùi và tiến giữa Run: cooldown, đồng hồ boss, timestamp save không bị ảnh hưởng (SAV-18).

**UI, input, âm thanh, tiếp cận**

1. Esc theo chuỗi: hộp thoại, panel, hủy chọn, Pause (INP-03).
2. Space khi nút UI còn focus: là Dodge, không kích hoạt nút (INP-04). Tab trong Run đổi chế độ (trừ HAZARD_TRIAL). E ở PREP vào Hazard Trial, ở COMBAT là hold hồi máu (HZT-01, HLT-03).
3. WASD theo vị trí phím vật lý (physical_keycode trong InputMap), đúng trên bố cục AZERTY. Esc và F1 không gán được. Tab Điều khiển hiển thị bảng phím chỉ đọc. \[Should] Rebind trùng phím hiện hộp thoại hoán đổi.
4. Slot sau tường vẫn bấm được ở PREP, tường mờ khi chỉ huy đứng sau. Aim đúng ở địa hình cao.
5. Ở x3 cảnh báo T1 hiện đủ thời gian thực. Tối đa 1 banner và 3 toast, T1 chen T2 (ALR-13, ALR-15).
6. Thanh máu quân không vượt 40 với 70 quân. Nhạc không đổi pitch ở x3, SFX lặp bị giới hạn.
7. \[Should] Cảnh báo T1 vẫn nghe rõ khi nhạc đang phát (ducking, AUD-05). MVP: âm T1 to hơn nhạc nền.
8. Đổi độ phân giải không xác nhận: tự hoàn sau 10 s. settings.cfg hỏng: game chạy mặc định, save nguyên vẹn.
9. Chữ tiếng Việt đúng dấu, không tràn khung ở 1280x720 đến 3840x2160 (LOC-02, LOC-03). \[Should] Đổi ngôn ngữ giữa Pause: chữ đổi ngay, không tràn khung.
10. Telegraph vẫn nhận biết bằng họa tiết (UI-05, FBK-06). Giảm nhấp nháy bật: không flash trắng, viền cảnh báo tĩnh. Mọi hiệu ứng không nhấp nháy quá 3 lần/giây (ACC-06). \[Should] Ba preset mù màu (ACC-01).
11. Chạy 30 phút liên tục: FPS và bộ nhớ trong ngưỡng ACP-01, ACP-04, ACP-05.
12. \[Should] Bán tower cấp 1 rồi hoàn tác trong 3 s thời gian thực (kể cả ở x2, x3): gold, slot, loại, cấp và priority trở lại đúng (PNL-10).
13. \[Should] Bán tower cấp 1 rồi bấm Pause: bộ đếm 3 s dừng, bỏ Pause thì chạy tiếp phần còn lại, hoàn tác vẫn bấm được trong phần đó (PNL-10).
14. Nút tua nhanh: bấm x2 thì bật, bấm lại x2 thì tắt về x1. Đang x2 bấm x3 thì chuyển thẳng x3. Bấm x1 luôn về x1. Phím 1, 2, 3 không tua nhanh vì là skill chủ động (TIME-09, HUD-14, SKL-05).
15. Nút tua khóa ở BOSS_INTRO, SUMMARY, REWARD_PICK và màn thắng: x2, x3 xám kèm biểu tượng khóa, hiển thị luôn khớp time_scale thực. BOSS_COMBAT tua bình thường. Sang PREP kế tiếp nút ở trạng thái tắt (TIME-03, HUD-14).
16. Crossfade nhạc 1.5 s thời gian thực khi chuyển PREP sang COMBAT: không ngắt, không đổi pitch, chạy đúng khi Pause và ở x3 (AUD-06).
17. Tắt hết âm thanh vẫn nhận biết đủ: telegraph Stomp (vòng đỏ có họa tiết, thanh wind-up), đồng hồ Cuồng nộ có số, nhãn CUỒNG NỘ và banner ở T-30 và T-0 (ACC-09, ALR-03, ALR-04, ENR-05).
18. Mọi tín hiệu ở mục 6.9 tồn tại trong EventBus đúng tên và kiểu payload. HUD vẫn chạy khi chỉ nhận tín hiệu, không đọc trực tiếp node gameplay (UI-04, EVB-01 đến EVB-46; EVB-24 đã xóa ở v1.8, EVB-25 đã bỏ ở v2.0).

**Emergency repair (giới hạn lượt)**

1. Xuất phát ở wave 1: luôn 3/3 lượt, emg_repair_cd = 0. Run mới sau khi khôi phục run gián đoạn cũng 3/3 (STR-08, RUN-01). \[Should] Xuất phát ở mốc muộn cũng 3/3.
2. Dùng lần 1: còn 2/3, cooldown 60 s. Bấm R trong 60 s: từ chối, không tốn lượt, HUD hiện "Đang hồi" (CMD-02, HUD-13).
3. Cooldown chạy xuyên wave (dùng cuối COMBAT, sang PREP wave sau vẫn còn) và không đổi khi tua x1/x2/x3 (theo game time).
4. Dùng hết 3 lượt: 0/3, R xám kèm "Hết lượt" dù cooldown đã về 0 (CMD-02, CMD-09).
5. Fortress đầy HP: R bị từ chối, không tốn lượt lẫn cooldown (CMD-07). Fortress thiếu ít hơn lượng hồi: tốn 1 lượt, HP kẹp ở max (CMD-08, FORT-03).
6. Từ 0/3 diệt boss bằng bất kỳ cách nào: thành 1/3. Wave boss mà boss bị Cuồng nộ rồi mới chết vẫn +1. Boss không bị diệt thì không cộng. Wave thường: không đổi (BRW-07).
7. Đang 3/3 diệt boss: vẫn 3/3, không bảo lưu. Đang 2/3 qua boss: 3/3. Lượt thưởng không reset emg_repair_cd (BRW-07, BRW-08).
8. Thua đúng frame wave boss kết thúc: không cộng lượt (GLD-08). \[Should] Xuất phát ở mốc muộn: không tính bù các boss đã bỏ qua (STR-08).
9. Meta EMG_REPAIR cấp 0/1/2/3 hồi 20/23/26/29%. Không đổi được số lượt hay cooldown, không thể mua cấp vượt 3 (SHP-13, APL-04).
10. Dùng R khi đang Pause hoặc ở Frontline: bị từ chối, không tốn lượt (CMD-09, TIME-08).

**Frontline, XP, Skill, Cuồng nộ \[MVP]** (nhóm test mới của v1.8)

| # | Test | Liên quan |
| --- | --- | --- |
| F1 | Tower giết quân chưa bị chỉ huy đánh: nhận 50% xp_value. Chỉ huy đánh 1 đòn rồi tower giết: 100%. Chỉ huy giết: 100%. Quân bị cull: 0 XP | XP-02, XP-03 |
| F2 | Battle Cry và shockwave Deploy không bật cờ hit_by_commander. Tick vùng cháy Firebomb bật cờ ở tick đầu | XP-03, CMB-10 |
| F3 | Đường cong XP: xp_to_level(1..4) = 5, 9, 13, 17, cộng dồn ra tích lũy 5, 14, 27, 44, khớp xp_to_level (XP dư chuyển cấp, một wave lên nhiều cấp thì nhiều lượt chờ) | XP-04 |
| F4 | Aura: chỉ huy Frontline ở 11 m một Arrow, Arrow nhận sát thương nhân 1.2 (dealt_mult 1.2). Ở 13 m: không. Vào Commander: tắt trong ≤ 1 scan_interval. Stunned, Recalling, Deploying: tắt | FRT-01, FRT-04 |
| F5 | Gold chỉ huy: Grunt wave 1 có cờ cho wave_gold_base 4 × 1.25 = 5 (chưa làm tròn); không cờ 4. boss_gold không nhân | FRT-02 |
| F6 | Nâng tower theo bậc: Cấp Chỉ huy 3 thì Arrow cấp 12 không nâng lên cấp 13 được (nút xám "Cần Chỉ huy cấp 4"), nhưng cấp 1 lên 12 không bị chặn. Cấp 4: nâng được tới cấp 24, cấp 25 xám tới cấp 8. Chỉ huy cấp 8, tower cấp 25 bị phá: xây lại RUINED cấp 25 được (BLD-07 không kiểm gating). Xây tạm cấp 1 rồi nâng lại cũng được vì cấp Chỉ huy không giảm | FRT-03, UPG-06, BLD-07 |
| F7 | REWARD_PICK: RNG theo run_seed cho cùng 3 thẻ; không có hai thẻ trùng; skill đã max không xuất hiện; pool rỗng bỏ qua state; \[Should] Reroll không tốn lượt; Skip hỏi xác nhận và mất lượt | RWP-01..07 |
| F8 | Skill: phím 1-3 chỉ chạy ở Frontline; ở Commander không làm gì; cooldown đúng ở x1/x2/x3; Whirlwind 15 SLASH bán kính 3 m, Sword Wave, Firebomb (6/s BLAST) đúng bảng level; skill hủy recovery đòn kiếm | SKL-05, SKL-06, SKL-10..12 |
| F9 | StatBlock: Sharpness L3 +24% sát thương, Armored L3 armor 15% (trần 75% giữ), Lifesteal L3 hồi 1.5% commander_max_hp mỗi kill, \[Should] Focus L3 −18% cooldown skill chủ động | SKL-13..15 |
| F10 | Bulwark pha 1: Firebomb (BLAST) gây 100%, kiếm và Whirlwind 60%, Arrow không bắn (IMMUNE), Cannon 100% | DMG-01, DMG-02 |
| F11 | Cuồng nộ: boss_timer về 0 thì boss_enraged = true một lần, tốc độ × 1.3, nhịp × 1.3, sát thương × 1.5; không có sát thương TRUE, không tower nào thành RUINED, chỉ huy Commander HP không đổi. Diệt sau Cuồng nộ: boss_gold và boss_prestige × 0.5, +1 lượt Emergency repair | ENR-01..06, BRW-02, BRW-07 |
| F12 | Boss chết đúng frame T=0: không Cuồng nộ. Fortress sập cùng frame: FORTRESS_DESTROYED | ENR-04, BOSS-27, BOSS-28 |
| F13 | Chiến lược AFK (bot đứng Commander, nâng tower tối đa có thể): đến wave 12 không vượt quá cấp tower cho phép bởi FRT-03, và Cấp Chỉ huy ≤ 0.65 × Cấp của bot Frontline cùng seed; tỷ lệ sống sót đến wave 15 thấp hơn bot Frontline ít nhất 20 điểm phần trăm (mục tiêu cân bằng, chỉnh qua tham số) | FRT-01..03, XP-02 |
| F14 | Đường thắng: tắt mọi tower, chỉ huy Frontline vẫn hạ được Bulwark wave 5 trong 2 × boss_timer (sau Cuồng nộ có thể thua, ghi lại tỉ lệ) | mục 2.8 |
| F15 | Làm tròn máu và DoT: Lifesteal cấp 1 với commander_max_hp 100 hồi cộng dồn 0.5 mỗi kill, đủ 1 HP sau 2 kill. Firebomb cấp 1 với Tinh thông +5% gây tổng 25 sau 4 tick (6.3 mỗi tick, không phải 24). \[Should] Thẻ Bền thành tăng fortress_max_hp và hồi đúng lượng tăng | DMG-06, SKL-15, mục 1.4 |

Pause, sửa bằng Mithril, trần armor, tải quét (v1.3, cập nhật v2.0), hoàn tác bán \[Should]

1. Pause trong COMBAT ở Commander mode: mở panel Tower, nút đổi priority xám kèm tooltip, bấm không có tác dụng. Bỏ Pause rồi đổi: áp dụng sau retarget_delay 0.3 s (TIME-08, CMD-04, PNL-12).
2. Pause ở PREP: mở panel, xây, nâng, bán, sửa vẫn hoạt động bình thường (PNL-12).
3. Frontline trong COMBAT, không Pause: panel Tower không có nút đổi priority (PNL-07).
4. Sửa bằng Mithril: Fortress 1000 HP còn 700, 2 Mithril: bấm một lần còn 1 Mithril, HP 900; bấm lần nữa HP 1000 (kẹp, tooltip "Hồi thừa"), còn 0 Mithril, nút xám. Fortress 1050 HP: một viên hồi floor(0.2 × 1050) = 210. Đầy máu: từ chối, không trừ Mithril. Ở COMBAT không có nút (MTH-03 đến MTH-05).
5. Trần armor: ở MVP chỉ có bị động Armored cộng armor chỉ huy (tối đa 15%), armor Fortress luôn 0%. Ép giá trị 90% bằng công cụ debug: kẹp về 75% cho chỉ huy và 60% cho Fortress (APL-03).
6. Tải quét: 6 tower và 70 quân ở x1, chi phí quét mục tiêu dưới 1 ms/frame, tower không gọi tính đường. Quân đổi nav_progress thì priority First đổi theo trong một chu kỳ quét (TWR-15, ACP-01).
7. \[Should] Bán tower cấp 1 rồi bấm Bắt đầu wave, sau đó bấm hoàn tác khi COMBAT đã bắt đầu: bị từ chối, toast đã biến mất, gold và slot giữ nguyên trạng thái sau bán (PNL-10, ALR-12, BLD-02).
8. \[Should] Bán tower rồi xây, nâng hoặc sửa trong 3 s: hoàn tác bị hủy ngay. Bán rồi bấm Bắt đầu wave, vào Hazard Trial hoặc Abandon: cũng bị hủy (PNL-10).
9. \[Should] Hoàn tác bán khôi phục đúng loại, cấp, target_priority, invested_gold, HP đầy. Bán tower StartPack rồi hoàn tác: tower trở lại, gold không đổi (PNL-10, SELL-04).

**Camera (v1.9)**

| # | Test | Liên quan |
| --- | --- | --- |
| CM1 | Frontline: chỉ huy đứng giữa khung, thấy 12 đến 14 m mỗi bên theo chiều hành lang. Chỉ huy chạy hết hành lang: camera bám có smoothing và không vượt camera_bounds | CAM-01, CAM-04 |
| CM2 | PREP: WASD dịch camera, nhân vật không nhúc nhích. Dịch về hai đầu hành lang: thấy được Fortress và điểm spawn, giữ phím tiếp cũng không đi quá camera_bounds | CAM-02, CAM-03, CAM-04 |
| CM3 | Dịch camera ở PREP rồi vào COMBAT, sau đó Tab sang Commander: camera ở focus mặc định, không giữ vị trí dịch cũ. C đưa focus về mặc định trong 0.3 s | CAM-07, CAM-08 |
| CM4 | Giữ W lúc Tab: sau khi đổi ngữ cảnh không có nhân vật trôi hay camera trôi cho đến khi nhấn lại. Ở REWARD_PICK và hộp thoại, WASD không làm gì | CAM-10, INP-07 |
| CM5 | Chuyển khung mất 0.5 s thời gian thực ở x1, x2, x3 và không đổi khi Pause. Dịch camera vẫn hoạt động khi Pause | CAM-03, CAM-05, TIME-10 |
| CM6 | Sau khi dịch camera, bấm slot và aim bằng chuột vẫn trúng đúng vị trí dưới con trỏ | CAM-12, MSE-01, MSE-02 |
| CM7 | BOSS_INTRO: camera lia tới boss trong 4 s game time, WASD không dịch được, xong về đúng khung của COMBAT | CAM-11, BOSS-17 |
| CM8 | Frontline ở Fortress bị đánh: HUD-10 hiện mũi tên mép khung chỉ về Fortress. Boss chưa vào khung: mũi tên boss | HUD-10 |

**Trạm hồi lực (v1.9)**

| # | Test | Liên quan |
| --- | --- | --- |
| HT1 | Hold: giữ E 1.0 s game time cạnh trạm có kho khi chỉ huy thiếu máu thì vào Healing. Ở x3, hold đủ sau khoảng 0.33 s thời gian thực. Nhả E trước 1.0 s: hold về 0 | HLT-03, TIME-10 |
| HT2 | Mỗi hành động hủy đều ngắt hold và ngắt Healing (di chuyển, Dodge, đánh, skill, Tab, nhận sát thương kể cả AoE, knockback, rời tầm, Pause). Sau khi hủy phải nhả rồi nhấn lại E mới hold lại. HP đã hồi giữ nguyên | HLT-04 |
| HT3 | Điều kiện: không hold được ở PREP, SUMMARY, Commander mode, khi đầy máu, khi quá 3 m, khi trạm 0 HP. HUD-18 hiện đúng lý do từng trường hợp | HLT-03, HUD-18 |
| HT4 | Công thức: chưa có SKL-26, thiếu 100 HP, 300 kho: sau 10 s chỉ huy +100, trạm −200 (k 0.5). SKL-26 level 2 (20 HP/s, k 1.0): chỉ huy +200, trạm −200 sau 10 s. Kết quả giống nhau ở x1, x2, x3 (sai lệch dưới 1 HP) | HLT-06 |
| HT5 | Gần đầy máu: thiếu 3 HP ở k 0.5 thì trạm chỉ mất 6 HP, không hao thừa. Chỉ huy dừng ở commander_max_hp và Healing tự kết thúc | HLT-05, HLT-06 |
| HT6 | Kho về 0 (do hút hoặc do quân đánh): trạm thành RUINED, kênh dừng, hiện ALR-17 (hút cạn) hoặc ALR-07 (bị phá). Xây lại trạm cấp 1: 80 gold, kho đầy 300 | HLT-07, BLD-07 |
| HT7 | Không tự hồi: Trạm 120 HP sang PREP vẫn 120 HP, sang wave sau vẫn 120 HP. Emergency repair và sửa Fortress bằng Mithril không đổi HP trạm | HLT-08, TWR-01 |
| HT8 | Chuẩn hóa: ở wave 10 (dmg_mult 1.70), đòn raw 17 gây 14. Ở wave 20 (2.86), raw 40 gây 24. Hút máu không bị chuẩn hóa. Tối thiểu 1 | HLT-09 |
| HT9 | Giới hạn: xây trạm thứ ba bị từ chối kèm lý do. Hai trạm đều RUINED vẫn chiếm chỗ. Bán hoặc dọn một trạm RUINED thì xây được. Không đặt được trên slot WALL | HLT-01, HLT-02, BLD-09 |
| HT10 | Hai trạm cùng trong tầm: hút trạm gần nhất. Hết kho thì kênh dừng, phải hold lại để hút trạm còn lại | HLT-05, HLT-14 |
| HT11 | Tập trung quân: Grunt, Archer, Bulwark nhắm trạm theo bảng ETG như tower thường. Mỗi trạm tối đa 3 quân cận chiến đánh cùng lúc | HLT-10, CRD-01 |
| HT12 | Panel: trạm có nút Nâng cấp (cấp 36 hiện "MAX"), không có priority, sửa. Bán trạm còn 150/300 HP hoàn bằng một nửa mức hoàn của trạm đầy | PNL-14, UPG-03, SELL-05 |
| HT13 | Bỏ regen: Commander mode giữ nguyên HP (bất khả xâm phạm), vào PREP hồi 35% commander_max_hp một lần. Passive Lifesteal vẫn hồi khi giết quân | CMD-10, 3.5.7 |
| HT14 | Thẻ SKL-26 chỉ vào pool thưởng sau khi đã xây ít nhất một trạm trong run; sau đó không bị loại kể cả khi trạm bị phá hoặc bán | SKL-26, RWP-06, RUN |

**Tài khoản và bảng xếp hạng \[MVP rút gọn] (v1.9)**

| # | Test | Liên quan |
| --- | --- | --- |
| AC1 | Không mạng, hoặc online_enabled = false: game khởi động và chơi trọn vẹn như khách, nút online ẩn hoặc báo không kết nối, không lỗi console | ACCT-02, ACCT-12 |
| AC2 | Đăng nhập, đóng game, mở lại: phiên được khôi phục từ auth.cfg. Đăng xuất xóa auth.cfg. endlesswar_save.json không chứa token | ACCT-03, ACCT-04 |
| AC3 | Hai máy lệch revision: lấy bản revision cao hơn, hiện thông báo, bản kia giữ ở save.conflict.bak. \[Should] Hộp thoại chọn bản. Không tự gộp | ACCT-06 |
| AC4 | Ngắt mạng giữa lúc RunEnd: RunEnd và shop vẫn hoàn tất, yêu cầu gửi lại ở RunEnd hoặc mua shop kế tiếp, biểu tượng đúng trạng thái | ACCT-05, ACCT-07 |
| AC5 | Không gửi đồng bộ trong COMBAT. Ghi save cục bộ vẫn dưới 50 ms khi đang đồng bộ | ACCT-05, ACP-06, ACP-08 |
| AC6 | Xếp hạng: hai tài khoản cùng waves_cleared thì run_elapsed nhỏ hơn xếp trên; trùng cả hai thì gửi trước xếp trên. Hạng của chính mình hiện dòng riêng khi ngoài top 50 | LBD-04, LBD-08 |
| AC7 | Không được tính điểm: tài khoản khách, run bắt đầu từ wave > 1, run khôi phục sau gián đoạn. Điểm lấy từ RunState, sửa max_wave_cleared trong endlesswar_save.json không đổi hạng | LBD-02, LBD-05 |
| AC8 | Máy chủ từ chối điểm vô lý (ví dụ 40 wave trong 100 s) và dữ liệu của tài khoản khác | LBD-06, ACCT-09 |
| AC9 | Lượt chơi thật nhanh nhất không bị từ chối: công cụ debug cho sát thương vô hạn, chơi wave 1 đến 10 ở x3, bấm Bắt đầu wave ngay ở mỗi PREP, có vào Hazard Trial và Pause giữa trận. Mỗi wave (kể cả wave boss 5 và 10, boss chết ngay) có COMBAT hoặc BOSS_COMBAT kéo dài ≥ spawn_duration(w) game time; run_elapsed bằng tổng game time của COMBAT và BOSS_COMBAT (sai số dưới 0.1 s), không tăng trong PREP, HAZARD_TRIAL, BOSS_INTRO, SUMMARY, REWARD_PICK và khi Pause; chạy lại ở x1 với cùng run_seed thì run_elapsed lệch dưới 1 s so với lần x3. Máy chủ chấp nhận điểm. Gửi tay run_elapsed = 15 × waves_cleared − 2 thì bị từ chối. Thêm ca một nhóm: wave boss chỉnh kịch bản còn đúng 1 hộ tống, boss chết ngay ở giây đầu; hộ tống sinh đúng ở spawn_duration(w) và BOSS_COMBAT kéo dài ≥ spawn_duration(w) | RUN-02, SPN-15, LBD-06 |

**Hazard Trial \[MVP] (v2.0)**

| # | Test | Liên quan |
| --- | --- | --- |
| HZ1 | Vào phòng: ở PREP, Frontline, bấm E hoặc bấm vào Tháp thì vào; ở Commander, khi Pause hoặc khi có hộp thoại thì Tháp xám kèm lý do. Vào lần hai trong cùng PREP bị từ chối ("Đã dùng ở wave này"); PREP wave sau vào lại được | HZT-01, HZT-09, HUD-23 |
| HZ2 | Nhóm quái: wave có 3 loại thì nhóm 5 con có đủ cả 3 loại; cùng run_seed và wave_index cho cùng nhóm. Wave boss: boss cộng 4 quân của wave đó. Chỉ số quái khớp quân của wave thật (hp_mult, dmg_mult) | HZT-02, HZT-03 |
| HZ3 | Giới hạn 10%: nhóm có con máu tối đa 500, đòn kiếm 80 sát thương chỉ gây 50; tick Firebomb, tia Chain Lightning, tick Burn cũng bị kẹp. Ngoài phòng đòn đó gây đủ 80 | HZT-05 |
| HZ4 | Chỉ số một chiều: vào phòng với 70/100 HP, mất 50 HP trong phòng, rời phòng thì HP ngoài vẫn 70; cooldown và hiệu ứng trong phòng không mang ra. Lên skill hay đổi vũ khí ở PREP rồi mới vào thì phòng dùng bản mới | HZT-06, WPN-03 |
| HZ5 | Thắng phòng: giết đủ 5 con thì +mithril_reward(w) Mithril (mặc định 1), gold và XP của 5 con cộng khi ra; toast ALR-20. Rời phòng sau khi giết 2 con: gold và XP của 2 con, 0 Mithril. Chết trong phòng: không phát commander_died, run không kết thúc, giữ gold và XP của số đã giết, 0 Mithril | HZT-07, HZT-08, DEAD-11, MTH-02, GLD-10, XP-06 |
| HZ6 | Không đụng wave thật: giết 5 con trong phòng, wave thật vẫn có đủ số quân của WaveScript; prestige_pending không đổi; run_kills không đổi. Boss trong phòng chết: có boss_gold, không +1 Emergency repair, không rơi vũ khí | HZT-04, BRW-09 |
| HZ7 | Trong phòng: Tab không làm gì, không xây hay đổi vũ khí, camera cố định khung phòng, WASD di chuyển nhân vật; Esc mở Pause không rời phòng. Ra phòng không hồi 35% lần nữa, tower không hồi đầy lần nữa | HZT-10, HZT-11, CAM-16, mục 3.3.1 |
| HZ8 | XP trong phòng đủ lên cấp: thanh XP chỉ tăng khi rời phòng; lượt chọn mới chờ tới REWARD_PICK sau SUMMARY của wave đó | XP-06, RWP-01 |
| HZ9 | Quân tự nổ: con cuối là Suicide Squad tự nổ vào chỉ huy, bản sao còn HP: kết quả WON, +mithril_reward(w), gold và XP chỉ của 4 con đã giết, kills = 4 ở hazard_trial_exited. Nhóm 5 Suicide Squad đều tự nổ, chỉ huy còn sống: WON, 0 gold, 0 XP, vẫn +Mithril | HZT-07, HZT-16, EN-22, MTH-02 |
| HZ10 | Cùng frame: con cuối bị diệt (hoặc tự nổ) đúng frame HP bản sao về 0: kết quả DIED, 0 Mithril, giữ gold và XP của số con đã giết, hazard_trial_exited phát đúng một lần với result DIED. Bấm Rời phòng đúng frame con cuối bị diệt: kết quả WON | HZT-07, HZT-16, DEAD-11 |
| HZ11 | Captain chờ nổ: Captain là con cuối, HP về 0 thì gold và XP của nó vào phần tạm tính ngay, nhưng trong explode_windup phòng chưa WON và HUD còn 1 con. Vụ nổ không giết bản sao (Dodge hoặc đứng ngoài explode_radius): WON sau khi nổ xong. Vụ nổ đưa HP bản sao về 0: DIED, giữ gold và XP của Captain, 0 Mithril. Undead là con cuối đang nằm chờ hồi sinh: chưa WON cho tới lần chết thứ hai | HZT-07, HZT-16, EN-23, EN-26, HUD-22 |
| HZ12 | Gold phòng có số cụ thể, nhóm dựng sẵn bằng công cụ test, WaveRewardTable khởi điểm (gold_mult(w) = 1 + 0.04(w−1)), frontline_gold_mult 1.25. (a) PREP wave 3, gold_pct_total = 0, nhóm 3 Grunt (gốc 4) và 2 Archer (gốc 7), giết cả 5: kill_gold Grunt = 4 × 1.08 × 1.25 = 5.4, Archer = 7 × 1.08 × 1.25 = 9.45, hazard_gold = floor(35.1) = **35** (nhân 1.25 hai lần sẽ ra 43, là lỗi). (b) Như (a) với gold_pct_total = 0.10: floor(38.61) = **38**. (c) PREP wave 5, gold_pct_total = 0.10, Bulwark và 4 Grunt, giết cả 5: phần quân floor(4 × 4 × 1.16 × 1.25 × 1.1) = floor(25.52) = 25, phần boss floor(100 × 1.16 × 1.1) = floor(127.6) = 127, hazard_gold = **152**. Gold tạm tính trên HUD-22 và gold trong hazard_trial_exited khớp các số này; wave_gold_base của wave thật không đổi | GLD-10, RWD-02, FRT-02, BRW-01 |

**Vũ khí \[MVP] (v2.0)**

| # | Test | Liên quan |
| --- | --- | --- |
| WP1 | Đầu run chỉ có kiếm gốc. Diệt Bulwark wave 5: SUMMARY hiện "Nhận vũ khí X", owned_weapons có 2 cây, không tự trang bị. Đến wave 25 có đủ 5 cây khác nhau; boss wave 30 không rơi gì. Cùng run_seed cho cùng thứ tự rơi. Thua đúng frame wave boss kết thúc: không nhận | WPN-02, WPN-11, BRW-09 |
| WP2 | Đổi vũ khí ở PREP (cả hai chế độ, cả khi Pause): tức thì; ở COMBAT, HAZARD_TRIAL ô vũ khí chỉ đọc | WPN-03, HUD-21, PNL-15 |
| WP3 | Frost: đòn trúng làm chậm 20% trong 3 s, đánh lại làm mới thời gian, không cộng dồn. Lên Bulwark pha 1 bằng kiếm (SLASH 0.6) vẫn làm chậm | WPN-06, WPN-05, BOSS-01 |
| WP4 | Chain Lightning: 4 Grunt đứng cách nhau 1.5 m, đòn trúng con đầu thì 3 con nhận 20% sát thương cơ bản, con thứ tư không; đòn trong 5 s kế không mở chuỗi; không con nào trúng hai lần | WPN-07 |
| WP5 | Burn: tổng 50% sát thương cơ bản trong 5 s qua 5 tick; trúng lại ở giây 3 làm mới về 5 s, không cộng dồn lượng. Tick dùng dot_remainder | WPN-08, DMG-06 |
| WP6 | Rampage: HP 90%, 70%, 40%, 30% lần lượt cho dealt_mult +0, +0.10, +0.25, +0.50; cộng cùng Sharpness, áp cho kiếm và cả ba skill chủ động | WPN-09, DMG-06 |
| WP7 | Swift: attack_interval 0.45 s thành 0.30 s, sword_range 2.2 m thành 1.54 m, combo_window vẫn 0.35 s | WPN-10, CHAR-07 |
| WP8 | Sát thương hiệu ứng tính hit_by_commander, mang damage_type của đòn kích hoạt; boss đang có resist = 0 với loại đó thì hiệu ứng không áp. Tia Chain và tick Burn không kích hoạt hiệu ứng lần nữa | WPN-04, WPN-05, XP-03 |

**Quân mới và va chạm \[MVP] (v2.0)**

| # | Test | Liên quan |
| --- | --- | --- |
| NE1 | Assassin: tower không bao giờ chọn Assassin làm mục tiêu dù trong tầm; nổ Cannon nhắm con khác vẫn trúng Assassin trong vùng nổ; chỉ huy thấy ở opacity 0.5 và đánh được | EN-20 |
| NE2 | Suicide Squad tới tầm Barricade thì nổ sau wind-up: Barricade, tower và chỉ huy trong bán kính mất máu, quân khác không; quân nổ không cho gold, XP, kill. Bị giết trước khi nổ: không nổ, thưởng bình thường | EN-22 |
| NE3 | Captain bị diệt thì nổ tại chỗ và vẫn thưởng; bị cull thì không nổ | EN-23 |
| NE4 | Knight: đòn làm HP xuống 45% thì bất tử 5 s (tower bỏ mục tiêu, kiếm hiện IMMUNE), sau đó nhận sát thương bình thường; không bất tử lần hai. Đòn từ 60% về 0: chết luôn | EN-24 |
| NE5 | Brute ủi thẳng tới Fortress: không đổi mục tiêu khi bị Battle Cry hay khiêu khích; va Barricade trên đường gây impact_damage một lần rồi đi vòng tiếp; va chỉ huy hất văng, Dodge thì miễn | EN-25 |
| NE6 | Undead chết lần đầu: không có enemy_died, không thưởng, hồi sinh sau revive_delay với đầy máu và sát thương tăng; chết lần hai mới thưởng và tính kill | EN-26 |
| NE7 | Tắt va chạm: 20 Grunt cùng đi qua một điểm không đẩy nhau, vẫn chỉ 12 con đánh Fortress (slot đánh giữ nguyên). Sniper đứng ngoài tầm Arrow cấp 1 vẫn bắn được | EN-16, EN-19, CRD-01 |
| NE8 | Mỗi wave không quá 5 loại kể cả boss ở wave 1-30 (WaveScript) và ở wave 31-40 (thuật toán, nhiều seed) | SPN-14, EN-17 |

**Thắng, endless, tutorial và trụ có sẵn \[MVP] (v2.0)**

| # | Test | Liên quan |
| --- | --- | --- |
| VC1 | Hoàn thành wave 30: victory_reached = true, run_victory phát một lần, sau SUMMARY hiện màn thắng, game dừng; bấm "Chơi tiếp" thì sang REWARD_PICK hoặc PREP wave 31. Không có thêm uy tín hay danh vọng | END-07, SCR-20, PRS-02 |
| VC2 | Chết ở wave 30: RunEnd thua (DEFEAT), waves_cleared 29. Fortress sập đúng frame hoàn thành wave 30: thua đè thắng, không hiện màn thắng | END-08, WAVE-02 |
| VC3 | Chết ở wave 34 sau khi thắng: RunEnd endless "Sống sót đến wave 34", waves_cleared 33, run_result SURVIVED. Abandon ở wave 32 cũng là SURVIVED. Bảng xếp hạng nhận waves_cleared như thường | END-10, SCR-21, LBD-04 |
| VC4 | Đổi victory_wave trong GameConfig thành 10: thắng ở wave 10, công thức scale dùng từ wave 11 | END-07, SCL-06 |
| VC5 | Hoàn thành wave 30 khi có 2 lượt chọn đang chờ (pending_picks = 2), chạy hai lần: (a) bấm Tiếp tục ở SUMMARY; (b) không bấm, chờ hết 10 s. Cả hai lần đúng thứ tự SUMMARY → màn thắng → REWARD_PICK → PREP wave 31: màn thắng hiện trước, REWARD_PICK không mở khi màn thắng còn mở, màn thắng không tự đóng sau 10 s; bấm "Chơi tiếp" thì vào REWARD_PICK chọn đủ 2 lượt rồi vào PREP wave 31. summary_continue_requested và run_victory mỗi tín hiệu phát đúng một lần; bấm Tiếp tục đúng frame hết 10 s cũng chỉ một lần. Lặp lại với pending_picks = 0: màn thắng rồi thẳng PREP wave 31 | WAVE-13, END-07, EVB-37, EVB-44, EVB-46, SCR-20, RWP-01 |
| TU1 | Save mới (tutorial_done = false): run đầu không có trụ có sẵn, chỉ hai slot mặc định sáng, xây Arrow rồi Cannon miễn phí, nút Bắt đầu wave mở sau khi xây xong, tutorial_done = true được ghi save ngay | TUT-01, TUT-14, TUT-15, BLD-11, SAV-04 |
| TU2 | Run sau (tutorial_done = true): vào PREP wave 1 đã có Arrow và Cannon cấp 1 ở đúng hai slot mặc định, 0 gold, không có gợi ý xây | mục 3.2.1, FLOW-06 |
| TU3 | Bỏ qua tutorial khi mới xây Arrow: game tự xây Cannon, tutorial_done = true. Thoát game trước khi xây xong: run sau chạy lại tutorial | TUT-08, TUT-10 |
| TU4 | Đăng nhập tài khoản đã có tutorial_done = true trên máy mới: sau đồng bộ, run kế tiếp có trụ có sẵn, không chạy tutorial | ACCT-04, TUT-17 |

**Bảng cân bằng \[MVP] (v2.0)**

| # | Test | Liên quan |
| --- | --- | --- |
| BL1 | Chạy công cụ dịch hai lần với cùng `balance.xlsx`: bộ `.tres` giống hệt, mỗi file có dòng chú thích sinh tự động | BAL-02, BAL-03 |
| BL2 | Xóa một ô trong sheet towers hoặc ghi số âm: công cụ báo đúng dòng, cột và không ghi file nào | BAL-06 |
| BL3 | Runner `test_balance_config_runner` pass với bảng chuẩn: đủ 36 cấp mỗi loại tower, đủ wave 1-30, mỗi wave ≤ 5 loại kể cả boss, wave boss có đúng một boss và ít nhất 1 hộ tống, spawn_duration mọi wave ≥ 15 s, không ô trống, không số âm. Sửa tay một `.tres` để thiếu cấp 36, hoặc đặt spawn_duration một wave 12 s: runner fail | BAL-05 |
| BL4 | Wave 31 trở đi đọc ScaleConfig, không đọc WaveScript; hệ số wave 30 của bảng khởi điểm và công thức ở wave 31 liền mạch | BAL-04, SCL-06 |


## 7.2 Định nghĩa "Hoàn thành" (Definition of Done)

Chạy đúng ở x1, x2, x3; có test case tương ứng; không lỗi console; giá trị chỉnh được qua Resource hoặc CSV; không chuỗi viết cứng.

## 7.3 Lịch nghiệm thu

| **Tuần** | **Mốc chức năng** | **Chính** |
| --- | --- | --- |
| 1-5 | Đã hoàn thành: repo, scene, EventBus, GameConfig, blockout, combat cơ bản, Grunt/Archer/Brute, 14 slot, Arrow/Cannon/Barricade, luồng xây, Battle Cry, aggro | Cả nhóm |
| 6 (19-25/10) | Họp chốt v1.9 và bảng phân công v3. TimeManager, input edge, chết/hồi, sinh wave theo bảng, targeting 2 priority, AttackSlot, Aura Tiền tuyến, panel Tower, thanh máu quân, số sát thương nổi. Kéo sớm: bỏ regen và prep_heal 35%, lõi kênh hồi máu (trạm giả), backend xác thực, SaveRepository, camera_bounds, hộp thoại, HUD-18 | Cả nhóm |
| 7 (26/10-1/11) | **Mốc A:** vòng lặp wave PREP-COMBAT-SUMMARY chơi được wave 1-4: Commander mode, Recall/Deploy, xây/nâng/bán, dọn đổ nát, XP và Cấp Chỉ huy, camera (CAM-01 đến CAM-05, 07, 08), AudioManager | Combat, Enemy, Tower, UI, Art |
| 8 (2-8/11) | SkillData, thanh XP trên HUD, SkillRunner và Whirlwind, RewardOfferGenerator, cổng cấp tower, kinh tế gold, HUD đủ vùng, Crowd, khung Bulwark, model Bulwark, Trạm hồi lực phần Tower và panel (HLT, PNL-14), màn Login nối backend | Combat, Tower, UI, Enemy, Art |
| 9 (9-15/11) | **Mốc B1:** chơi đến hết Bulwark đầu: pha giáp, Cuồng nộ, kháng boss, Sword Wave, Firebomb, màn REWARD_PICK nhặt được 3 skill chủ động. **v2.0 (đề xuất):** bảng cân bằng và công cụ dịch cùng runner BAL (bảng khởi điểm từ số v1.9), PREP không đếm ngược và nút Bắt đầu wave, grid 3 + 3 và GRID-07, starting_gold 0 và trụ có sẵn | Cả nhóm |
| 10 (16-22/11) | **Mốc B2:** vòng skill hoàn chỉnh (4 bị động gồm SKL-26, 2 stat), RunConfig/RunState/RunEnd data, save atomic, MetaShop 4 mục, thưởng boss, thang kẹt MVP, HUD skill/XP, Trạm hồi lực phần 2, API đồng bộ và bảng xếp hạng. **v2.0 (đề xuất):** Hazard Trial và Mithril, tower 36 cấp và 3 bậc model, vũ khí và rơi từ boss, tắt va chạm giữa quân | Cả nhóm |
| 11 (23-29/11) | **Đóng băng gameplay (29/11):** RunEnd (thua, endless) và màn thắng, Pause, Settings (Âm thanh, Đồ họa, Tiếp cận, Tài khoản), tutorial một lần theo tài khoản (TUT-01, TUT-03, TUT-14, TUT-15), 7 loại quân mới và Brute sửa, kịch bản wave 1-30, khôi phục run, SyncService và nộp điểm, cân bằng lần 1, accessibility, playtest ngoài nhóm | Cả nhóm |
| 12 (30/11-6/12) | **Đóng băng toàn bộ tính năng (6/12).** Hoàn thiện online, test AC1..AC9 và các nhóm test v2.0 (HZ, WP, NE, VC, TU, BL), cân bằng cuối trong bảng cân bằng (SCL-04, FRT, boss 60-75%, Trạm hồi lực, wave 1-30), đo ACP-01..08, build Windows, playtest vòng 2 | Cả nhóm |
| 13 (7-14/12) | Chỉ test theo mục 7.1, sửa lỗi, báo cáo, video demo. 14/12 đóng băng bản nộp. 15 và 16/12 dự phòng. 17/12 diễn tập. Mục tiêu hoàn thành 80-90% tổng phạm vi (MVP 100% gồm online rút gọn, SHOULD chọn lọc) | Cả nhóm |

Từ v1.9, tuần 10 đến 12 mỗi người làm 3 buổi mỗi tuần (khoảng 18 giờ), các tuần khác 2 buổi (12 giờ). Trễ mốc B1 (15/11) thì không làm mục \[Should] nào và cắt theo thứ tự ở Phụ lục C mục 17. Online (mục 3.13, 3.14) là MVP rút gọn và chỉ bị cắt khi vẫn trễ sau Mốc B2 (ACCT-11). Giao diện SaveRepository (ACCT-01) làm từ tuần 6. Chi tiết phân công từng người xem Bang_phan_cong_v3. Thiết kế v2.0 đã duyệt (05/11); riêng phần v2.0 trong lịch trên (các ô ghi "đề xuất") và phân vai v2.0 ở Phụ lục B vẫn là đề xuất, chờ bảng phân công cập nhật (Phụ lục C mục 60).

# 8. PHỤ LỤC

## Phụ lục A. Bảng tiền tố ID

| **Tiền tố** | **Nội dung** | **Mục** |
| --- | --- | --- |
| FLOW | Luồng ứng dụng | 3.1 |
| END | Kết thúc Run | 3.2.4 |
| RUN | Trạng thái Run | 3.2.2 |
| WAVE | Wave | 3.3 |
| TIME | Điều khiển thời gian | 3.4 |
| CHAR, CMB, CMD, MODE, AGG, DEAD | Chỉ huy | 3.5 |
| FRT | Vòng lặp Frontline (Aura, gold chỉ huy, cổng cấp tower) | 3.5.10 |
| XP | XP và Cấp Chỉ huy | 3.5.11 |
| SKL | Skill của chỉ huy | 3.5.12 |
| RWP | REWARD_PICK (3 chọn 1) | 3.3.6 |
| FORT, REP | Fortress, sửa chữa | 3.6.1 |
| SLOT | Build slot | 3.6.2 |
| GRID | Ô grid mặt đất (zone GROUND) | 3.6.2 |
| TWR, TGT, PRJ | Tower, targeting, projectile | 3.6.3, 3.6.5 |
| BLD, UPG, SELL, CLR | Xây, nâng (UPG-06 giới hạn bậc theo Cấp Chỉ huy), bán, dọn đổ nát. MOV đã bỏ ở v2.0, không dùng lại | 3.6.4 |
| HLT | Trạm hồi lực | 3.6.6 |
| AI, ETG, CRD, NAV | Kẻ địch | 3.7 |
| SPN, SCL, EN, RWD | Spawner, scale, thưởng, quân mới v2.0 (EN-16 trở đi) | 3.7, 3.7.8 |
| BOSS, DMG, BTM, ENR, BRW | Boss, Cuồng nộ (OVL và RET đã xóa ở v1.8, không dùng lại) | 3.8 |
| GLD, PRS | Gold, uy tín | 3.9 |
| MTH | Mithril (v2.0) | 3.9.3 |
| WPN | Vũ khí (v2.0) | 3.5.13 |
| HZT | Hazard Trial (v2.0) | 3.15 |
| SHP, BUF | Meta shop, buff | 3.10 |
| STR, APL | Wave khởi đầu, áp dụng meta | 3.11 |
| SAV | Save/Load | 3.12 |
| ACCT | Tài khoản, đồng bộ \[MVP rút gọn] | 3.13 |
| LBD | Bảng xếp hạng \[MVP rút gọn] | 3.14 |
| UI, SCR, HUD, PNL | Giao diện | 4.1 |
| INP, MSE | Input, chuột | 4.2.1, 4.2.2 |
| CAM | Camera | 4.2.3 |
| ALR | Cảnh báo | 4.3 |
| FBK | Phản hồi | 4.4 |
| AUD | Âm thanh | 4.5 |
| SET | Settings | 4.6 |
| TUT | Tutorial | 4.7 |
| ACP | Nghiệm thu kỹ thuật | 5.1 |
| ACC | Tiếp cận | 5.2 |
| LOC | Ngôn ngữ | 5.3 |
| DAT | Sở hữu và nguồn chuẩn của dữ liệu | 6.1 |
| EVB | Danh mục tín hiệu EventBus | 6.9 |
| BAL | Bảng cân bằng Excel và công cụ dịch (v2.0) | 6.10 |

Mã bị bỏ ở v2.0 liệt kê ở Phụ lục E, không dùng lại số cho nghĩa mới.

## Phụ lục B. Phân vai

| **Vai** | **Phụ trách** |
| --- | --- |
| Player & Combat | Nhân vật, vũ khí, chuyển chế độ, HP và damage system dùng chung. Từ v1.8: Aura Tiền tuyến, SkillRunner, StatBlock, nội dung SkillData. Từ v1.9: heal_channel (HLT-03 đến HLT-06). Phía máy chủ của tài khoản và bảng xếp hạng (ACCT-10) |
| Enemy & Wave | State machine, target priority, spawner, scale, boss (Bulwark, Cuồng nộ), XpTracker (XP, cờ hit_by_commander). Từ v1.9: thang xử lý kẹt (NAV), TIME-06 tự hạ x2, nhắm Trạm hồi lực theo ETG (HLT-10). Từ v2.0 (đề xuất): kịch bản wave 1-30 và WaveScript, 7 loại quân mới, Brute sửa, tắt va chạm giữa quân (EN-16 trở đi), Hazard Trial phần sinh nhóm quái, state HAZARD_TRIAL và nút Bắt đầu wave ở wave FSM |
| Tower & Build | Slot, ô grid (GroundGrid sinh slot từ GridData, trần max_ground_buildings), đặt/nâng cấp (kèm cổng cấp UPG-06), targeting priority, projectile, RewardOfferGenerator (hàm thuần, test bằng GUT). Từ v1.9: Trạm hồi lực (kho HP, RUINED, giới hạn số lượng, HLT-01, HLT-02, HLT-07 đến HLT-09), save/load và SaveRepository (ACCT-01). Từ v2.0 (đề xuất): grid 3 + 3 và GRID-07, tower 36 cấp và bậc model, trụ có sẵn (SELL-06), Mithril và sửa Fortress (MTH), WaveRewardTable, công cụ dịch bảng cân bằng và runner BAL (sở hữu data/config) |
| UI/UX & Meta | HUD (gồm thanh XP, ô skill), panel Commander, màn RewardPick, shop 4 mục, tổng kết. Từ v1.9: HUD-18, PNL-14, màn Login, Leaderboard, SyncService (ACCT, LBD phía client). \[Should] menu chọn wave và nạp buff. Từ v2.0 (đề xuất): HUD-19 đến HUD-23, PNL-15, màn thắng SCR-20 và RunEnd endless SCR-21, tutorial một lần theo tài khoản |
| Art / Level / Audio | Camera (CAM, CameraRig, CAM-16), blockout và dựng map, hành lang rộng 23.5 m, GridData của map (bố cục ô 9 hàng, grid_rows), boss_melee_point (BOSS-40, GRID-08), hazard_portal và hazard_room, 3 model bậc cho mỗi tower, model vũ khí và quân mới, prop, VFX, âm thanh, tích hợp asset, shader xuyên thấu |

## Phụ lục C. Vấn đề còn mở

Đã duyệt mục 38 đến 61 ngày 05/11. Mục 62 đến 66 (sửa theo review nhất quán 05/11) đã chốt. Có sửa: mục 39 (vào qua Tháp Hazard Trial, không phải cổng), mục 43 (trần 10% với boss chỉ tính core_hp), mục 47 (Cannon ở W2, Arrow ở ô đất hàng giữa), mục 61 (hành lang rộng 23.5 m, 9 hàng ô). Cách trang bị vũ khí (WPN-02, WPN-03, WPN-11) giữ như đã viết.

| **#** | **Vấn đề** | **Đề xuất** |
| --- | --- | --- |
| 1 | Toàn bộ con số là giá trị khởi điểm | Cân bằng theo SCL-04, mục tiêu boss 60-75%, nhịp danh vọng (mục 3.9.2). Chỉnh boss_timer trước, HP sau. Chỉnh conversion_rate trước, giá shop sau |
| 2 | \[Đã chốt v1.5] Xây lại tower bị phá: mất cấp hay giữ cấp | Chốt giữ 100% cấp, giá bằng tổng cost cấp 1 đến cấp cũ theo TowerData, hệ số 1.00 (SLOT-08, BLD-07). Chỉ để người chơi khỏi bấm nâng lại, tổng gold không đổi nên không ảnh hưởng cân bằng. Xem lại nếu playtest thấy phạt khi tower bị phá quá nhẹ: khi đó thêm phụ phí xây lại |
| 3 | Line-of-sight cho Archer, Shell (tower đã chốt không cần, TGT-07) | MVP bỏ qua, thêm ở Should nếu phi lý |
| 4 | \[ĐÃ XÓA v1.8] Retreat không còn | |
| 5 | Mặc định chọn mốc cao nhất (STR-03) có thể khiến bỏ qua giai đoạn đầu (chỉ xét khi làm StartSelect \[Should]) | Hạ start_mult (mốc 10 từ 0.6 xuống 0.5) thay vì khóa tính năng |
| 6 | Adds khi chuyển pha boss, boss thứ 3 (boss bay, cần Bat) | \[Could] |
| 7 | Số slot đánh của tower thường (3) là ước tính | Kiểm chứng bằng playtest |
| 8 | Góc camera và bố cục hành lang | Art thử ở tuần 1, nếu che nhau nhiều thì giảm yaw về 0 |
| 9 | Phím tắt build | Nếu xây chậm, thêm Z, X, C (phím số 1-3 là skill chủ động từ v1.8) |
| 10 | Gamepad, hoàn tác bán (PNL-10) | Gamepad là Could. PNL-10 đã chuyển sang Should từ v1.4 |
| 11 | Tên game, logo, palette, font | Art chốt trước tuần 3 |
| 12 | \[ĐÃ CHỐT v1.8] 3 chọn 1 là MVP, dùng XP. Không có gói gold | RWP-06 |
| 13 | Emergency repair chỉ còn 3 lượt/run, +1 mỗi boss (tối đa 1 lượt hồi mỗi 5 wave) nên nguồn hồi Fortress miễn phí khan hiếm hơn nhiều | Playtest theo dõi HP Fortress giữa hai boss. Nếu hao quá nhanh, chỉnh emg_repair_heal_pct hoặc emg_repair_charges_max trước, không đụng cooldown 60 s |
| 14 | Thang xử lý kẹt (NAV-01 đến NAV-14) dùng ngưỡng ước tính: 3 s phát hiện, 3 m hop, 2 lần recycle, 45 s watchdog | MVP: chạy tay hoặc script ít nhất 20 wave ở x3 (tuần 10), chỉnh ngưỡng theo log STUCK_CULL. Mục tiêu cull dưới 0.1%. Bot soak 200 wave là Should |
| 15 | Commander mode bất khả xâm phạm: người chơi có thể ở Commander gần như cả run | **Sửa v1.8:** Commander mode vẫn bất khả xâm phạm nhưng có giá rõ ràng: XP 50%, không Aura, không gold chỉ huy, không skill, tower chậm lên cấp (CMD-10, FRT-01..03). Theo dõi test F13. Nếu AFK vẫn thống trị: tăng frontline_aura_dmg_bonus lên 0.30, tăng tower_gate_tier2/tier3 lên 5/10, hoặc giảm xp_tower_only_pct xuống 0.35 (chỉnh qua Resource, không sửa code) |
| 16 | \[Cập nhật v2.0] Sửa Fortress theo % máu: mỗi Mithril hồi 20% fortress_max_hp nên FORT_HP làm Fortress bền hơn và mỗi viên hồi nhiều HP hơn | Theo dõi sức mạnh meta FORT_HP khi playtest. Nếu quá mạnh, giảm mỗi cấp từ 5% xuống 4% hoặc giảm mithril_repair_pct |
| 17 | Nếu sau v1.4 nhóm vẫn quá tải | **Sửa v1.9:** Các mục cắt cũ (Reroll, ducking AUD-05, tab Dữ liệu và Điều khiển, TUT-04/05, thẻ Bền thành, bị động Focus và Lightstep) đã chuyển sang \[Should] từ v1.9. Ứng viên cắt tiếp theo, theo thứ tự: (1) Firebomb (giữ Whirlwind, Sword Wave), (2) edge-pan và look-ahead camera, (3) HLT-12, (4) bảng xếp hạng, (5) đồng bộ tài khoản. Quyết định cuối tuần 9 |
| 18 | Chỉ phát hành tiếng Việt | Nếu giảng viên hoặc người chấm yêu cầu tiếng Anh, thêm cột tiếng Anh vào CSV và bật mục Ngôn ngữ trong Settings (kiến trúc tr() đã sẵn) |
| 19 | Di chuyển trong lúc đánh thường chưa có tốc độ riêng (CMB-03 chỉ nói di chuyển không hủy đòn) | MVP: giữ tốc độ đầy đủ. Nếu playtest thấy đánh bị "trượt" quá nhiều, thêm attack_move_speed_mult* (ví dụ 0.5) vào CharacterStats |
| 20 | Các mặc định mới của v1.5 chưa được nhóm xác nhận: chỉ huy xuất phát ở Frontline (mục 3.2.1), Pause được ở mọi state kể cả BOSS_INTRO và SUMMARY (TIME-02), early_call_bonus cộng ở SUMMARY (GLD-09, đã bỏ ở v2.0), "tower dùng nhiều nhất" tính theo sát thương (mục 3.2.4) | Nhóm rà soát ở buổi họp kế tiếp. Chọn khác thì sửa đúng ID đã nêu và ghi vào Phụ lục D |
| 21 | Các giá trị mới của v1.6 chưa được nhóm xác nhận: sword_max_targets = 3 (CMB-09), Cannon không knockback (PRJ-08), boss_melee_point cách tường 1.6 đến 2.0 m (BOSS-40), retarget_batch_size = 8 (ETG-08 \[Should]), deploy_clear_radius = 0.8 m (MODE-02), lane_curve làm gốc cho nav_progress (TWR-16) | Nhóm xác nhận ở buổi họp kế tiếp. sword_max_targets là nút cân bằng Frontline: tăng nếu quét cụm quá yếu, giảm nếu Frontline lấn át tower. Chọn khác thì sửa đúng ID đã nêu và ghi vào Phụ lục D |
| 22 | \[Cập nhật v2.0] Gold dư ở endless: khi 6 công trình (3 WALL + 3 trên grid) đã cấp 36, gold chỉ còn dùng để xây lại (GLD-04 không lãi, không trần; sửa Fortress dùng Mithril) | Theo dõi khi playtest từ wave 30 trở lên. Giá 36 cấp trong bảng cân bằng nên giữ khan hiếm gold tới wave 30, gold còn dùng để xây lại tower bị phá. Nếu gold dư thật, ứng viên \[Could] là buff mua bằng gold; không thêm ở MVP |
| 23 | Save scumming: người chơi chép thư mục user:// để quay lại bản cũ (checksum chỉ phát hiện hỏng tệp, mục 3.12.1) | Chấp nhận ở MVP vì game offline. Trạng thái Run không ghi giữa chừng (RUN-01) nên chỉ quay lại được profile. Không thêm timestamp hay cơ chế chống gian lận |
| 24 | \[Đã chốt v1.7, cập nhật v2.0] Ô grid RUINED không bán được (SLOT-08) nên chiếm 1 trong 3 chỗ của max_ground_buildings | Chốt: Dọn đổ nát ở PREP (CLR-01: miễn phí, ô về EMPTY, trả lại 1 chỗ trong trần, trần vẫn 3, mất ruined_type và ruined_level). Hoán đổi với đống đổ nát (MOV-02) đã bỏ cùng MOV ở v2.0. Ô RUINED vẫn tính vào trần cho tới khi được dọn hoặc xây lên |
| 25 | \[ĐÃ BỎ v2.0] Di chuyển và hoán đổi tower (MOV) | Bỏ ở v2.0: người chơi tự chọn loại và slot khi xây. Đổi bố cục thì bán (60%) rồi xây lại. Xem Phụ lục E |
| 26 | Các giá trị mới của v1.8 chưa được nhóm xác nhận: frontline_aura_radius 12 m và bonus 0.20, frontline_gold_mult 1.25, tower_gate_lv2/lv3 = 4/8 (v2.0 đổi thành tower_gate_tier2/tier3, cổng ở cấp 13 và 25), xp_tower_only_pct 0.5, enrage_* (1.3/1.3/1.5/0.5), level skill tối đa 3, 3+3 ô | Họp chốt 19/10. Mọi giá trị nằm trong Resource, đổi không sửa code. Nút cân bằng ưu tiên: tower_gate_tier2/tier3 trước, bonus Aura sau |
| 27 | Cuồng nộ có thể làm boss "vượt tầm kiểm soát" nếu người chơi yếu | MVP chấp nhận: thua boss sau Cuồng nộ là hậu quả cố ý. Nếu playtest thấy mục tiêu 60-75% người mới diệt Bulwark không đạt, chỉnh boss_timer trước, enrage_damage_mult sau (không chỉnh HP trước) |
| 28 | Chỉ 1 boss (Bulwark lặp) có thể nhàm | MVP chấp nhận; Barrage \[Should] làm ngay khi MVP xong, ưu tiên cao hơn mọi mục Should khác |
| 29 | Firebomb dùng BLAST để tái dùng bảng kháng, nên Bulwark (BLAST 1.0) chịu Firebomb 100% | Giữ. Nếu Firebomb quá mạnh vs Bulwark, giảm sát thương gốc chứ không thêm loại sát thương |
| 30 | Mọi giá trị Trạm hồi lực (80 gold, kho 300, 10 đến 25 HP/s, hold 1.0 s, e = 0.5, tối đa 2 trạm) là khởi điểm | Theo dõi ở playtest: tỉ lệ run có dùng trạm, số lần cạn kho, có trở thành máu vô hạn hay vô dụng không. Chỉnh kho và giá trước, rồi đến e |
| 31 | SELL-05 (bán Trạm hồi lực hoàn tiền theo HP kho còn lại) do bản v1.9 thêm để khớp logic, chưa ai đề xuất | Nhóm xác nhận. Nếu không đồng ý thì hoàn nguyên giá như tower thường |
| 32 | Camera: camera_size_overview và camera_bounds chưa thử trên map thật. Nếu hành lang dài hơn khung nhìn quá nhiều thì dịch camera mệt | Art và Level thử ở tuần 1 và tuần 7, chỉnh size và tốc độ dịch trước khi đổi thiết kế |
| 33 | Backend dùng gói miễn phí có thể bị giới hạn hoặc tạm dừng khi ít hoạt động, ảnh hưởng buổi demo | Giữ ACCT-12 để game không phụ thuộc mạng. Kiểm tra backend trước buổi demo, chuẩn bị bản demo ngoại tuyến |
| 34 | Bảng xếp hạng chỉ chống gian lận ở mức rẻ (LBD-06). Bộ lọc tên hiển thị phản cảm và chức năng báo cáo chưa có (LBD-09) | Chấp nhận ở phạm vi đồ án. Nếu công khai rộng thì làm thêm |
| 35 | Chưa đặc tả xóa tài khoản và xóa dữ liệu trên máy chủ (quyền riêng tư) | Làm nếu dùng ngoài lớp. Hiện chỉ có đăng xuất |
| 36 | Người nhận phần máy chủ (ACCT-10) | Đã chốt ở v1.9: phần máy chủ giao vai Player & Combat, phần client giao vai UI/UX & Meta. Đóng mục này |
| 37 | Thứ tự cắt khi trễ (bổ sung cho mục 17) | Đã gộp vào mục 17 từ bảng phân công v3. Đóng mục này |

**Quyết định tự đặt ở v2.0** (bản xem trước chưa ghi; trạng thái: đã duyệt 05/11)

| **#** | **Vấn đề** | **Đề xuất** |
| --- | --- | --- |
| 38 | Hazard Trial nằm ở đâu trong wave FSM | State riêng HAZARD_TRIAL: PREP sang HAZARD_TRIAL rồi về PREP cùng wave; ra phòng không chạy lại hồi 35% và hồi tower đầu PREP (mục 3.3.1) |
| 39 | Ở PREP nhân vật đứng yên (CAM-02) nên không đi tới Tháp được | Vào bằng phím E (action riêng hazard_enter) hoặc bấm chuột vào cổng; phòng là khu vực riêng hazard_room trong level, camera cố định khung phòng (HZT-01, HZT-11, CAM-16) |
| 40 | Bản sao chỉ số gồm những gì | Chép cả cooldown hiện tại; trạng thái ngoài đóng băng trong lúc ở phòng; tua x1/x2/x3 dùng như COMBAT (HZT-06, HZT-10) |
| 41 | Cách chọn 5 quái và AI trong phòng | Mỗi loại ít nhất 1, phần còn lại rút theo tỷ lệ số lượng trong wave, RNG riêng; quái trong phòng chỉ nhắm chỉ huy (HZT-02, HZT-14) |
| 42 | Boss trong phòng | Không BOSS_INTRO, không boss_timer và Cuồng nộ; có boss_gold và XP boss; không uy tín, không +1 Emergency repair, không rơi vũ khí, không tính kill (HZT-03, HZT-04) |
| 43 | "Máu tối đa của con nhiều máu nhất" | Chốt lúc tạo nhóm; boss chỉ tính core_hp (chốt 05/11); kẹp áp sau mọi hệ số sát thương (HZT-05) |
| 44 | Gold phòng, Mithril sau wave 30, sửa thừa | Gold phòng cộng khi rời phòng như XP, không nhân clear_mult (GLD-10); từ wave 31 mithril_reward bằng giá trị wave 30 (MTH-02); Fortress thiếu dưới 20% vẫn sửa được và tốn 1 viên (MTH-04) |
| 45 | Cột của bảng thưởng và kịch bản wave | WaveRewardTable có gold_mult(w) (thay 1 + 0.04(w−1)), xp_mult(w), mithril_reward(w), không thêm thưởng hoàn thành wave; WaveScript chứa thêm hp_mult, dmg_mult, speed_mult, spawn_duration với khởi điểm bằng công thức v1.9. SCL-02 (soft cap wave 40) giữ vì thuộc công thức v1.9 dùng từ wave 31 |
| 46 | Trạm hồi lực 36 cấp | Chỉ giá và kho theo cấp; nâng cấp cộng phần kho tăng thêm, không hồi đầy; cổng bậc FRT-03 áp cho cả bốn loại tower (HLT-01, HLT-08) |
| 47 | Slot mặc định của trụ có sẵn | **Chốt 05/11:** Cannon ở W2; Arrow ở ô grid hàng giữa (hàng 4), cột hợp lệ gần Fortress nhất, tính vào 3 chỗ đất (starter_arrow_slot, starter_cannon_slot trong GameConfig); trụ có sẵn bị phá rồi xây lại là tower thường, bán được ngay (TWR-13, SELL-06) |
| 48 | Luồng tutorial | Chỉ hai slot mặc định xây được và nút Bắt đầu wave khóa tới khi xây xong; tutorial_done ghi ngay khi xây xong; Bỏ qua thì game tự xây trụ còn thiếu; thoát trước khi xong thì run sau chạy lại (BLD-11, TUT-08, TUT-10, TUT-15) |
| 49 | STARTER_KIT, StartPack, Trượng phép mâu thuẫn với v2.0 | Bỏ STARTER_KIT (SHP-01 đến SHP-04) vì trùng trụ có sẵn và dùng bố cục cũ; bỏ Trượng phép và UNLOCK_WAND vì mọi vũ khí là biến thể kiếm; StartPack mốc 5 đến 20 soạn lại khi làm StartSelect |
| 50 | Nhận và trang bị vũ khí | Có kiếm gốc không hiệu ứng; vũ khí rơi được cộng tự động ở SUMMARY cùng điều kiện BRW-07, không tự trang bị, RNG riêng (WPN-02, WPN-11) |
| 51 | Chi tiết hiệu ứng vũ khí | Kích hoạt cả với tick Firebomb; "sát thương cơ bản" là sword_damage qua StatBlock, không gồm hệ số đòn 3; hiệu ứng mang damage_type của đòn kích hoạt và không tự kích hoạt lại; làm chậm của Frost áp lên boss (ngoại lệ BOSS-01); một đòn cleave chỉ mở một chuỗi Chain (WPN-04 đến WPN-07) |
| 52 | Màn thắng và loại kết quả | Màn thắng hiện sau SUMMARY wave 30, chỉ một nút "Chơi tiếp", game dừng; run_result (DEFEAT, SURVIVED) tách khỏi end_type; bỏ ở Pause sau khi thắng cũng là SURVIVED (END-07, END-10, SCR-20) |
| 53 | Bản xem trước ghi "8 loại quân mới" nhưng bảng có 7 loại mới cộng Brute sửa | SRS ghi 7 loại mới cộng Brute sửa (8 dòng) |
| 54 | Hành vi chi tiết của quân mới | Suicide Squad nổ thì không thưởng; Captain nổ khi chết vẫn thưởng; bị cull không nổ; vụ nổ là BLAST có telegraph. Nổ Cannon vẫn trúng Assassin; Knight bất tử coi như kháng 0. Brute miễn khiêu khích và Battle Cry, va mỗi công trình một lần. Undead hồi sinh đầy máu, thưởng ở lần chết thứ hai (EN-19 đến EN-26) |
| 55 | Tắt va chạm giữa quân kéo theo thang kẹt | Áp cả boss; bỏ ally_phase (NAV-06) và bậc xuyên hộ tống của BOSS-04; thêm NAV-15 cho ca bị chặn kín |
| 56 | Cách kiểm chặn kín đường | Hàm thuần trên lưới GridData, coi ô có công trình hoặc đống đổ nát là vật cản, bề rộng tối thiểu path_check_min_width 3.2 m cho agent lớn (GRID-07) |
| 57 | Phím và khóa của nút Bắt đầu wave | Không có phím tắt; xám khi Pause, khi có hộp thoại giao dịch, khi tutorial chưa xong (WAVE-11, HUD-19) |
| 58 | Chi tiết công cụ và runner BAL | Tên sheet và đường dẫn `.tres` như mục 6.10; runner `tests/test_balance_config_runner.tscn` kiểm thêm wave boss có đúng một boss và mọi loại quân có EnemyData; bảng lỗi thì không ghi file nào (BAL-05, BAL-06) |
| 59 | Tín hiệu mới | EVB-38 đến EVB-45 (tên và payload ở mục 6.9) |
| 60 | Mục tiêu cân bằng, tag, phân vai, lịch | SCL-04: người thành thạo chạm wave 30. Mục mới v2.0 đều MVP trừ WAVE-12 và TUT-16. Phân vai v2.0 ở Phụ lục B (công cụ BAL giao Tower & Build vì sở hữu data/config) và phần v2.0 của lịch 7.3 chờ bảng phân công cập nhật |
| 61 | Hành lang mở rộng từ 16 m lên 23.5 m để có 9 hàng ô (chốt 05/11) | Level chỉnh lại theo bề rộng mới: navmesh, spawn_zone, return_zone, vị trí 3 slot WALL trên mặt tường, boss_melee_point, khung camera (CAM) để nhìn trọn bề ngang. Cập nhật khi dựng level |

**Sửa theo review nhất quán 05/11** (trạng thái: đã chốt 05/11)

| **#** | **Vấn đề** | **Đề xuất** |
| --- | --- | --- |
| 62 | Hazard Trial không có kết quả khi con cuối tự nổ; thứ tự khi nhiều điều kiện cùng frame | WON khi mọi con đã xử lý xong (bị diệt hẳn hoặc tự nổ) và chỉ huy còn sống; quân tự nổ vẫn 0 gold, 0 XP. Chốt cuối frame, ưu tiên DIED, rồi WON, rồi LEFT (tự chọn: bấm Rời phòng đúng frame thắng vẫn tính WON vì nhóm đã xong). Captain chờ nổ và Undead chờ hồi sinh chưa tính là xong (HZT-07, HZT-16, MTH-02, HUD-22, test HZ9 đến HZ11) |
| 63 | Gold Hazard Trial có thể nhân frontline_gold_mult hai lần | Một công thức chung: kill_gold = gold_reward(w) × cmd_mult định nghĩa một lần ở RWD-02, áp cho quân thường ở cả wave thật và phòng; boss dùng boss_gold(w) = boss_gold_base × gold_mult(w), không nhân hệ số chỉ huy. GLD-10 dùng cùng dạng hai floor như gold_gain, bỏ clear_mult (RWD-01, RWD-02, FRT-02, GLD-02, GLD-10, BRW-01, EVB-05, test HZ12) |
| 64 | GRID-07 chỉ giữ đường tới cổng, Bulwark có thể không tới được boss_melee_point | GRID-07 kiểm thêm đường tới boss_melee_point với path_check_min_width. Thêm GRID-08: vùng cấm boss_point_clear_radius 3.2 m (hai lần bán kính Bulwark 1.6 m). Tự chọn cách bỏ ô trong vùng ngay lúc nạp như GRID-03 thay vì khóa xây lúc chạy: hàm kiểm đơn giản hơn và người chơi không thấy ô không bao giờ dùng được. starter_arrow_slot phải ngoài vùng (SLOT-05, BOSS-03, BOSS-40, mục 6.3, test Fortress, tower 4 và 21). Level kiểm lại vị trí Arrow có sẵn sau khi đặt boss_melee_point theo hành lang 23.5 m |
| 65 | Thứ tự rời SUMMARY ở wave thắng không khớp giữa END-07 và EVB-37 | WAVE-13 là nguồn duy nhất: SUMMARY → màn thắng → REWARD_PICK nếu có lượt chờ → PREP, cho cả bấm Tiếp tục và hết 10 s. Wave FSM vẫn ở SUMMARY trong lúc màn thắng mở (không thêm state); run_victory phát lúc mở màn thắng; thêm EVB-46 victory_continue_requested; màn thắng không đếm ngược (END-07, mục 3.3.1, 3.3.4, EVB-37, EVB-44, EVB-46, SCR-20, test VC5) |
| 66 | Sàn run_elapsed của máy chủ có thể từ chối lượt chơi thật | RUN-02: run_elapsed là game time chỉ của COMBAT và BOSS_COMBAT (không tính PREP, HAZARD_TRIAL, BOSS_INTRO, SUMMARY, REWARD_PICK, màn thắng, Pause; tua x2, x3 không làm giảm). Tự chọn giữ sàn 15 s và thêm ràng buộc lịch sinh SPN-15 (quân cuối sinh không sớm hơn spawn_duration) thay vì hạ sàn, vì giữ được chống gian lận và làm par_time khớp thời lượng thật. Hệ quả: không wave nào xong trước spawn_duration game time. BAL-05 kiểm spawn_duration ≥ 15 s và wave boss có hộ tống; thêm lbd_elapsed_tolerance 1 s (LBD-04, LBD-06, mục 6.3, test AC9, BL3) |

## Phụ lục D. Nhật ký đồng bộ (so với các bản soạn Phần 1-7)

Các dòng 1 đến 53 là lịch sử đến v1.7, giữ nguyên để truy vết; dòng 77 trở đi là v2.0. Một số nội dung trong đó (Overload, Retreat, ép x1 ở T-20, shop 5 mục, MOV là MVP) đã bị thay thế bởi các dòng 54 trở đi. Khi mâu thuẫn, mục 3 đến 7 của tài liệu này và các dòng 54 trở đi là nguồn đúng.

| **#** | **Thay đổi đã áp dụng vào bản hợp nhất** |
| --- | --- |
| 1 | **TIME-03:** thêm ép x1 từ T-20 s của đồng hồ boss và khóa đến hết wave. Làm rõ mức tốc độ chỉ giữ từ PREP sang COMBAT trong một wave vì SUMMARY luôn về x1 (bản soạn ghi "giữ qua các wave" mâu thuẫn với quy tắc về x1 ở SUMMARY) |
| 2 | **TIME-05** chốt theo AUD-01: không đổi pitch, giảm tần suất SFX |
| 3 | **Công thức danh vọng** dùng dạng có buffer: floor((pending + 0.5 × buffer) × rate × mult) |
| 4 | **FLOW-03:** run_flag thêm start_wave, start_mult. **FLOW-06:** bỏ qua StartSelect chỉ khi không có mốc mở và kho buff rỗng. **FLOW-05:** mặc định nằm ở Settings |
| 5 | **Thứ tự khởi tạo Run** hợp nhất theo Phần 6 (StartPack, STARTER_KIT, FORT_HP, CMD_HP, EMG_REPAIR, GOLD_PCT, buff) |
| 6 | **WAVE-09** chi tiết hóa theo OVL-05, BRW-02, BRW-05. Boss wave dùng par_time_boss |
| 7 | **Input:** thêm F, G, B, V, U, Delete, Shift, F1 vào bảng phím. **CHAR-03** thêm Retreat lên đầu ưu tiên trong 15 s cuối |
| 8 | **CMD-02:** cooldown lấy từ EMG_REPAIR. **CharacterStats:** commander_max_hp cộng CMD_HP. **FORT-04** thêm FORT_HP |
| 9 | **ETG-01 và Commander mode (3.5.4):** Sửa lại câu "Archer và boss" của Phần 2 để khớp Phần 5 |
| 10 | **TGT-04** khái quát thành DMG-02 (miễn nhiễm theo damage_type). Mọi nguồn sát thương có damage_type; DEAD-04 tham chiếu OVL-01, OVL-02, DMG-05 |
| 11 | **SLOT-03** bổ sung làn 4 m cho boss. **SELL-04** mở rộng cho StartPack. **SELL-02** thêm hoàn tác 3 s cho cấp 1 (PNL-10) |
| 12 | **RWD-01:** thưởng hiển thị tức thì, ví thật cộng ở SUMMARY (GLD-02). Số nổi hiển thị giá trị gốc |
| 13 | **Thanh máu quân** theo HUD-09 (tối đa 40). **EN-01** dùng HUD-10 |
| 14 | **BUFF\_WARD** không giảm sát thương TRUE (DMG-05, OVL-01). gold_pct_total áp lên boss_gold, clear_mult thì không |
| 15 | **SUMMARY** tự chuyển sau 10 s thời gian thực (Phần 1 ghi 10 s không nêu loại) |
| 16 | GLD-07: chi phí sửa Fortress (theo % máu thiếu) làm tròn lên; REP-01 làm tròn phần trăm sửa được theo gold có xuống |
| 17 | **v1.2, Commander mode bất khả xâm phạm** (mục 3.5.1, 3.5.2, 3.5.4, 3.5.7, CMD-10, MODE-05, AGG-03, DEAD-04, DEAD-09, DMG-05, OVL-01, BOSS-08, HUD-08, HUD-11): hoàn thiện các chỗ đã sửa dở. Không nguồn nào, kể cả TRUE, gây sát thương hoặc nhắm được chỉ huy ở Commander mode. Bỏ mode_mult khỏi công thức, regen 2%/s hồi liên tục. Sửa lỗi chính tả "xác thương" |
| 18 | **v1.2, Emergency repair giới hạn 3 lượt/run** (CMD-02, CMD-07 đến CMD-09, BRW-07, BRW-08, STR-08, APL-04, SHP-13, mục 3.2.1, 3.2.2, 3.3.4): giữ cooldown 60 s và miễn phí gold, +1 lượt khi hoàn thành wave boss (tối đa 3/3, kể cả Overload, không bảo lưu lượt thừa). Vì cooldown cố định, EMG_REPAIR đổi tác dụng từ "-5 s cooldown" sang "+3 điểm % lượng hồi mỗi cấp". Bỏ emergency_repair_min_cooldown và repair_cooldown |
| 19 | **v1.2, Nút tua nhanh** (TIME-01, TIME-03, TIME-09, HUD-14, INP-01, INP-02, INP-06): tua chỉ điều khiển bằng cụm nút HUD x1/x2/x3, bấm để bật, bấm lại để tắt. Bỏ phím 1, 2, 3 và hành động speed_1..3 khỏi InputMap |
| 20 | **v1.2, Thiết kế lại xử lý kẹt** (WAVE-03 đến WAVE-05, NAV-01 đến NAV-14, BOSS-04, EN-02, RWD-03, mục 5.4, 6.2): phát hiện theo tiến độ dọc đường đi thay vì độ dịch chuyển, không tính kẹt cho quân xếp hàng hợp lệ. Thang 4 bậc (tính lại đường và xuyên đồng đội, hop cục bộ có giới hạn, recycle về spawn_zone, cull không thưởng). Thêm watchdog cấp wave, giới hạn cứng 300 s, log và soak test. Boss có thang riêng, không bao giờ bị xóa |
| 21 | **v1.2, giao diện và tham số** (HUD-13, PNL-04, PNL-13, mục 4.1.3, 6.1, 6.2): hiển thị n/3 lượt Emergency repair, lý do khóa, toast khi nhận lượt. Tách tham số Emergency repair và tham số kẹt thành các dòng riêng |
| 22 | **v1.2, test case và phụ lục C** (mục 7.1): thêm nhóm Emergency repair (10 mục), 2 mục Commander bất khả xâm phạm, 6 mục xử lý kẹt, 1 mục boss kẹt, 2 mục nút tua. Phụ lục C thêm mục 13-15 |
| 23 | v1.3, chi phí sửa Fortress (REP-01, GLD-07, mục 3.6.1, 3.10.1, 6.2): đổi repair_gold_per_hp (0.4 gold/HP) thành repair_gold_per_pct (4 gold cho 1% máu tối đa), giá không tăng theo FORT_HP nên meta HP không làm giá sửa lệch đi |
| 24 | v1.3, trần armor (mục 3.5.1, 3.6.1, APL-03): ghi rõ armor luôn 0% ở MVP, trần 75% và 60% chỉ để dự phòng cho relic, meta hoặc nâng cấp thành \[Could] |
| 25 | v1.3, Pause (TIME-08, CMD-01, CMD-04, PNL-07, PNL-12): ở COMBAT và BOSS_COMBAT Pause làm panel chỉ đọc, không đổi priority; PREP không giới hạn. Đổi priority chỉ ở Commander mode, thời gian thực |
| 26 | v1.3, tải quét mục tiêu (mục 3.6.5, TWR-15, ACP-01): nav_progress do quân cập nhật một lần, tower chỉ đọc; tower lệch pha theo slot_id; thêm chỉ tiêu quét dưới 1 ms/frame và phương án dự phòng hình chiếu x |
| 27 | v1.3, hoàn tác bán (PNL-10, SELL-02, ALR-12, BLD-02, test mục 7.1): hoàn tác 3 s thời gian thực, tự hủy khi PREP kết thúc, có giao dịch khác hoặc Abandon; khôi phục đủ trạng thái tower; thêm 9 mục test và Phụ lục C mục 16 |
| 28 | **v1.4, buff một wave và StartSelect sang \[Should]** (mục 2.2, 2.7, 3.1, FLOW-06, 3.2.1, 3.2.2, RUN-01, 3.3.2, 3.9.1, 3.10.1, 3.10.2, 3.11.1, 3.12.1, SAV-04, SCR-02, SCR-03, SCR-04, SCR-11, 4.1.3, HUD-07, PNL-06, 4.2.1, INP-01): MVP bấm Play vào thẳng RunLoading với start_wave = 1, starting_gold = 150; Chơi lại ở RunEnd vào RunLoading; shop còn 5 mục (tổng ≈ 2100 danh vọng); gold_pct_buff = 0. Giữ nguyên ID BUF-01..08, STR-01..08 |
| 29 | **v1.4, thang xử lý kẹt thu gọn** (mục 3.7.4, NAV-02, NAV-07, NAV-08, NAV-10, NAV-11, NAV-14, WAVE-03, BOSS-04, mục 5.4, 6.2, Phụ lục C mục 14, test 7.1): chuyển hop (NAV-07), NAV-10, watchdog (NAV-11), overlay debug và bot soak 200 wave sang \[Should]. Giữ lại recycle (NAV-08) và cull (NAV-09) vì cull ngay sau bậc 1 mâu thuẫn nguyên tắc "không xóa quân ngay" và làm mất thưởng người chơi. Nghiệm thu MVP: chạy tay hoặc script ≥ 20 wave ở x3, cull dưới 0.1%. Thang kẹt của boss độc lập với NAV-07 |
| 30 | **v1.4, migration save sang \[Should]** (mục 3.12.1, 3.12.3, SAV-07, SAV-08): chỉ bỏ migration và save.premigrate.bak. Giữ lại khôi phục run gián đoạn (3.12.4, PRS-05) vì FLOW-03 và run_flag phụ thuộc vào nó và chi phí thấp; giữ SAV-09 đến SAV-19 vì là hệ quả của checksum và quy trình ghi, không tốn thêm việc |
| 31 | **v1.4, hoàn tác bán sang \[Should]** (SELL-02, BLD-02, PNL-10, ALR-12, test 7.1, Phụ lục C mục 10): MVP xác nhận bán ở mọi cấp để bù cho việc không có hoàn tác |
| 32 | **v1.4, tiếng Anh sang \[Should]** (mục 2.7, LOC-01, LOC-06, mục 4.6, SET-05, test 7.1, Phụ lục C mục 18): MVP chỉ tiếng Việt, giữ kiến trúc tr(), CSV theo khóa, placeholder có tên, font và LOC-03 để thêm ngôn ngữ sau không phải sửa code |
| 33 | **v1.4, accessibility thu gọn** (ACC-01, ACC-03, mục 4.6, test 7.1): chuyển 3 preset mù màu và tương phản cao sang \[Should]. Giữ lại ACC-05 (giảm rung), ACC-06 (giảm nhấp nháy, giới hạn 3 lần/giây áp dụng mọi hiệu ứng) vì chi phí thấp và liên quan an toàn, cùng UI-05 làm kênh thay thế màu |
| 34 | **v1.4, âm thanh thu gọn** (mục 4.5, AUD-04, AUD-06): chuyển nhạc phân lớp, tăng tempo nhạc boss, panning, lọc thông thấp khi Pause sang \[Should]. Giữ lại ducking (AUD-05) vì mục 4.3 yêu cầu còi T1 "không bị nhạc lấn", và crossfade, quy tắc Pause cho SFX |
| 35 | **v1.4, rebind phím sang \[Should]** (INP-05, INP-09, mục 4.6, test 7.1): MVP phím cố định, tab Điều khiển chỉ đọc. Giữ lại SET-01 (xác nhận 10 s khi đổi độ phân giải) vì tránh kẹt màn hình sai độ phân giải |
| 36 | **v1.4, lịch và phụ lục** (mục 7.3, Phụ lục B, Phụ lục C mục 17, 18): lịch nghiệm thu viết lại theo bảng phân công mới, mốc boss chơi được là tuần 7, kiểm thử time scale ở tuần 6. Giữ nguyên 10 tuần, không kéo dài |
| 37 | v1.4, hộp thoại giao dịch và chuyển state (SCR-14, SELL-02, PNL-11, test 7.1): hộp thoại bán, sửa chỉ hợp lệ trong PREP, tự đóng không thực hiện khi PREP kết thúc, kiểm tra lại state lúc xác nhận, không dừng đồng hồ PREP. Lỗ hổng xuất hiện khi hoàn tác bán chuyển sang \[Should] và MVP dùng xác nhận thay thế |
| 38 | v1.4, giá xây lại công trình STARTER_KIT (TWR-13): gộp STARTER_KIT với StartPack, xây lại giá thường, giá trị đầu tư tính theo gold đã trả |
| 39 | v1.4, FRENZY và recycle (EN-02, EN-03, NAV-08, test 7.1): quân bị recycle giữ cờ FRENZY, đồng hồ giới hạn cứng không reset, cull ở giây 300 có log cờ frenzy |
| 40 | v1.5, xây lại tower bị phá (Phụ lục C mục 2, SLOT-01, SLOT-02, SLOT-08, BLD-07, TWR-02, TWR-03, TWR-13, SELL-03, SHP-04, PNL-01, ALR-07, mục 3.2.2, 3.3.4, 6.7, test 7.1): slot RUINED nhớ loại và cấp. Xây lại giữ 100% cấp, giá bằng tổng cost cấp 1 đến cấp cũ theo TowerData (hệ số 1.00, không theo invested_gold). Chỉ là tiện ích thao tác, tổng gold không đổi so với xây cấp 1 rồi nâng. Thay quy tắc "về cấp 1" của TWR-03 và mục 38 ở trên |
| 41 | v1.5, số liệu (mục 1.4, 3.7.6, 3.8.10): bảng boss tính lại từ hp_mult, dmg_mult chưa làm tròn (bản cũ dùng giá trị làm tròn 2 chữ số nên lệch vài đơn vị, ví dụ Stomp wave 5 là 57 không phải 58). Kiểm tra cân bằng thô wave 5 sửa pha lõi ~9 s thành ~14 s và tổng ~73 s. SCL-02 thêm công thức budget sau soft cap. Mục 1.4 ghi chiều làm tròn mặc định |
| 42 | v1.5, bổ sung chỗ thiếu định nghĩa (mục 3.2.1, 3.2.2, 3.2.4, TIME-02, TIME-06, GLD-09, RWD-01, SPN-10, WAVE-01, CharacterStats, UI-04, INP-01): chỉ huy xuất phát ở Frontline; Pause được ở mọi state; early_call_bonus cộng ở SUMMARY; RunState thêm thống kê run; "tower dùng nhiều nhất" định nghĩa theo sát thương; thêm commander_low_hp_warning_pct; UI-04 dùng state_changed khớp EventBus; INP-01 dùng toggle_hud, buff_menu |
| 43 | v1.5, sửa trình bày và tham chiếu: mã tài liệu SRS-EW và tên game ở mục 1.1 (bỏ SRS-EATD), bước 4 và 5 của mục 3.2.4 tách thành mục danh sách, tham chiếu Retreat ở mục 3.5.5 trỏ 3.8.8, Phụ lục A thêm RUN và DAT, mục 1.3 thêm 7 thuật ngữ, ghi chú CharacterStats cho commander_mode_damage_mult khớp mục 6.4 |
| 44 | v1.5, mục 6: dọn bản hợp nhất (hai mục 6.7 thành 6.7 và 6.8, bỏ tiêu đề và đoạn rỗng, bỏ 5 dòng trùng ở bảng Boss chung vì vi phạm DAT-01), thêm DAT-06 (nguồn chuẩn), thêm tham số còn thiếu (sell_undo_window, spawn_overlap_radius, spawn_retry_delay, spawn_retry_timeout, escort_budget_ratio, intro_count, commander_low_hp_warning_pct, thời gian UI). Các dòng cũ của nhật ký nhắc "mục 6.1, 6.2" trỏ về cấu trúc mục 6 trước v1.5 |
| 45 | v1.6, xử lý góp ý rà soát SRS v1.5. Bổ sung: CMB-09 và sword_max_targets (giới hạn cleave), TWR-16 (nav_progress thống nhất cho quân đi bộ và quân bay, đổi mô tả First ở mục 3.6.5), làm rõ REP-01 và thêm REP-06 (missing_pct là số thực, ví dụ 1050 HP còn 1033 tốn 7 gold), PRJ-08 (Cannon không knockback), BOSS-40 và boss_melee_point (mục 6.7), EN-10 (điều kiện chuyển hành xử Healer), MODE-02 (thuật toán chọn điểm hạ, thêm deploy_clear_radius), OVL-07 và retarget_batch_size (retarget theo lô), ACC-09 (chỉ báo thị giác thay âm thanh), mục 6.9 và tiền tố EVB (danh mục EventBus), phạm vi start_mult (mục 3.2.4), TIME-03 làm rõ PREP kế tiếp luôn ở x1, và 14 test case mới ở mục 7.1. Xóa commander_mode_damage_mult khỏi CharacterStats (mục 3.5.1, 6.4) vì bất khả xâm phạm dùng cờ chặn (CMD-10). Đã đối chiếu và không sửa: REP-01 và AGG-01 đến AGG-06 đã được định nghĩa ở mục 3.6.1 và 3.5.6 (góp ý báo thiếu là nhầm), AUD-05 đã có test (mục 7.1, nhóm UI mục 7). Phụ lục C mục 21 thêm các giá trị chờ xác nhận |
| 46 | v1.6, xử lý góp ý vòng hai. Sửa lỗi do bản v1.6 đầu: xóa dòng TWR-05 thừa ở cuối mục 6.9; thiếu dấu chấm ở test giá sửa mục 7.1. Bổ sung: deploy_shockwave_radius, deploy_shockwave_distance và sửa PRJ-08 cho khớp shockwave Deploy (mục 3.5.5); sword_max_targets ở mục 6.4; EVB-03 dùng summary_data; EVB-24 retreat_zone_changed; REP-01 và PNL-04 làm rõ sửa một phần khi thiếu gold; damage_by_tower_type và run_gold_earned chỉ dùng trong lượt chơi (mục 3.2.2, 7.1); TWR-16 đổi sang mét còn lại tới thành để so sánh giữa các lane; TGT-07 (tower không cần line-of-sight); CRD-06 và bat_max_per_target (Bat không chiếm melee_slot, \[Should]); bước 7 Overload làm rõ GONE bỏ hitbox; BOSS-40 làm rõ quân xếp hàng sau Bulwark không tính kẹt; Phụ lục C mục 22, 23. Đã đối chiếu và không sửa: Barricade RUINED giữ obstacle là chủ đích (SLOT-02, SLOT-03 vẫn giữ làn 4 m); Frontline không hồi máu là chủ đích (mục 3.5.5); lạm dụng i-frame Deploy không xảy ra vì mode_switch_cooldown 5 s áp dụng hai chiều và Deploy chỉ từ Commander (MODE-03) |
| 47 | v1.6, xử lý góp ý vòng ba và tự rà soát. Bổ sung: DMG-06 (công thức sát thương chung lên quân thường, dealt_mult cộng dồn, taken_mult nhân, làm tròn gần nhất; mục 1.4); ward_mult cho BUFF_WARD tách khỏi fortress_armor_pct nên không chịu trần APL-03 (mục 3.6.1, 3.10.2); WAVE-07 cho phép gọi wave sớm ở PREP boss với cùng trần 40 gold; NAV-05 ghi rõ chỉ huy không chặn kín được hành lang nhờ SLOT-03. Tự rà soát v1.6: OVL-07 bỏ mâu thuẫn "giữ nguyên vị trí" với "đòn hụt", ETG-03 trỏ OVL-07, GLD-07 dùng missing_pct, sai số test nav_progress đổi sang mét, glossary thêm nav_progress và lane_curve, sửa số test mới thành 14. Đã đối chiếu và không đổi cơ chế: chỉ huy bất tử chặn đường không khả thi vì làn 4 m, gọi wave sớm ở PREP boss chỉ đổi thời gian chuẩn bị lấy tối đa 40 gold |
| 48 | v1.6, xử lý góp ý vòng bốn. Bổ sung: BOSS-41 và barrage_hold_distance 13 m (Barrage bắn từ 18 m nhưng chỉ dừng khi nằm trong tầm Arrow cấp 1, trước đó không tower nào bắn trả được); EN-04 và spawn_grace_max_time 10 s (quân trong spawn_grace không tấn công, không hold, tự hết grace); khóa time_scale từ T-20 mở khi đồng hồ boss dừng chứ không chờ hết wave (TIME-03, BTM-04, HUD-14); bộ đếm hoàn tác bán dừng khi Pause (PNL-10, sell_undo_window); BRW-08 ghi rõ chủ đích cooldown Emergency repair không reset; 3 test mới. Đã đối chiếu và không đổi cơ chế: Emergency repair bị cooldown sau thưởng là chủ đích (BRW-08), thưởng vẫn là một lượt dự trữ. Bốn mục lặp lại từ vòng ba (chỉ huy chặn đường, công thức sát thương lên quân thường, BUFF_WARD với trần giáp, gọi wave sớm ở PREP boss) đã xử lý ở mục 47 |
| 49 | v1.6 sửa mâu thuẫn nội bộ của v1.6. DEAD-03, bảng state 3.5.2 (Deploying) và 3.5.5 (Deploy) ghi rõ bất tử trừ sát thương TRUE của Overload, khớp bước 3 mục 3.8.7 và OVL-02. Thanh kỹ năng (4.1.3) chuyển Retreat từ Commander sang Frontline, khớp RET-01 và RET-07. ETG-01 sửa "gần Fortress hơn" thành "xa Fortress hơn quân (đã đi qua)". Nút tua mở khóa khi đồng hồ boss dừng: sửa ô BOSS_COMBAT ở bảng HUD theo state và câu cuối HUD-14, khớp TIME-03. STARTER_KIT: giá trị đầu tư khởi đầu 0, cộng giá các lần nâng, bán hoàn 60% phần đó (SHP-01, SELL-04, PNL-10, test 1 nhóm Fortress, tower ở 7.1), khớp SELL-01. SPN-02: tower bỏ qua quân còn spawn_grace thay vì mọi quân trong spawn_zone, khớp EN-04. GLD-02: số nổi hiển thị gold_reward(w) theo RWD-02, khớp RWD-01; mục 12 của nhật ký này giữ nguyên làm lịch sử. Mục 2.8: mỗi boss miễn nhiễm hai loại sát thương ở pha 1, khớp 3.8.2. PNL-04: nút sửa xám khi gold không đủ trả ceil(min(1, missing_pct) × repair_gold_per_pct), khớp REP-01. Kết thúc Run (3.2.2, bước 4 mục 3.2.4): cộng total_runs thêm 1. |
| 50 | **v1.7, chuyển slot NEAR/FAR sang ô grid (mỗi ô là một slot sinh sẵn từ GridData).** Giữ 6 slot WALL W1-W6; N1-N4, F1-F4 thay bằng ô grid 2 m (bố cục ô do GridData của từng map khai báo), tối đa max_ground_buildings = 8 công trình nên tổng vẫn 14. Sửa: mục 1.2 (Won't), 1.3 (Build slot, thêm Ô grid, no_build_lane), 2.2, 2.7, 3.2.2 (RunState), 3.6.2 (viết lại, SLOT-01 đến SLOT-06, thêm GRID-01 đến GRID-06, tham số bố cục grid, ô tham chiếu), 3.5 (command_post), BOSS-08, TWR-08, TWR-15, bước 5 Overload (3.8.7), luồng xây 3.6.4, thêm BLD-08, SELL-03, 3.9.1, STARTER_KIT và StartPack (N1-N4 thành G_0_1, G_0_2, G_1_1, G_1_2), PNL-01, 4.2.1 (phím B), MSE-02, MSE-04, TUT-01, DAT-06, 6.2 (GridData), 6.3 (nhóm Grid), 6.7, EVB-13, EVB-14 (slot_id kiểu StringName), 7.1 (test 4 sửa, thêm test 14-16), 7.3 tuần 3, Phụ lục A (GRID), Phụ lục B, Phụ lục C mục 22 và thêm mục 24. Không đổi: luồng xây bằng menu gold, nâng cấp UPG, xây lại BLD-07, bán SELL, Overload chỉ phá công trình mặt đất, NAV-05 và BOSS-03 (vẫn dựa vào làn 4 m của SLOT-03) |
| 51 | v1.7, **di chuyển tower ở PREP** (mục 1.3, 2.2, 2.7, 3.6.4, 3.8 PREP boss, PNL-02, 4.2.1, INP-01, 6.9, 7.1, 7.3, Phụ lục A, C): thêm MOV-01 đến MOV-07 (chỉ PREP, tới slot EMPTY hợp lệ theo zone, giữ cấp, priority, giá trị đầu tư, tôn trọng trần grid, nguyên tử, miễn phí), phím M và action relocate, EVB-25 tower_moved, test 17-20, Phụ lục C mục 25 |
| 52 | v1.7, **hoán đổi tower và dọn đổ nát** (mục 1.3, 2.2, 2.7, SLOT-02, SLOT-08, GRID-04, 3.6.4, BLD-08, SELL-03, 3.8 PREP boss, PNL-01, PNL-02, EVB-25, 7.1, 7.3, Phụ lục A, C): di chuyển chỉ trong cùng nhóm vị trí (WALL với WALL, ô grid với ô grid), không còn WALL xuống ô grid hay ngược lại nên trần grid không đổi khi di chuyển; đích OCCUPIED thì hoán đổi hai tower, đích RUINED thì hoán đổi tower với đống đổ nát (MOV-01 đến MOV-07 viết lại). Thêm CLR-01 đến CLR-04: dọn slot RUINED về EMPTY ở PREP, miễn phí, trả lại 1 chỗ trên grid (ground_used giảm 1, trần vẫn 8). GRID-04 tách rõ trần max_ground_buildings với số chỗ đã dùng ground_used. EVB-25 thêm swap_kind. Test 17-19 viết lại, thêm test 21. Phụ lục C mục 24, 25 chốt. Thay quy tắc "chỉ tới slot EMPTY" và "WALL xuống ô grid" của mục 51 |
| 53 | v1.7, **gộp NEAR và FAR thành zone GROUND** (mục 1.3, 2.2, 2.7, 3.6.2, SLOT-05, GRID-01, GRID-03, 3.6.3, TWR-08, 3.7 TOWER_GROUND, max_attackers_per_tower, BOSS-04, bước 5 Overload, STARTER_KIT, StartPack, 6.2 GridData, 7.1, 7.3, Phụ lục A): NEAR và FAR không có luật nào khác nhau (cùng loại tower, chung trần 8, cùng nhóm mục tiêu, cùng bị Overload). cell_id đổi từ N_c_r, F_c_r sang G_c_r để không đổi khi chỉnh map; ô tham chiếu thành G_0_1, G_0_2, G_1_1, G_1_2. Cần luật riêng cho một phần mặt đất thì thêm trường zone trong GridData |
| 54 | **v1.8, vòng lặp Frontline** (mục 3.5.10, 3.5.11, 3.9.1, UPG-06, CMD-10, HUD-15..17, GameConfig mục 6.3): Aura Tiền tuyến, gold chỉ huy 1.25, XP 100%/50% theo hit_by_commander, giới hạn cấp tower theo Cấp Chỉ huy (4/8) để chặn chiến lược nâng tower rồi đứng yên |
| 55 | **v1.8, Skill Tree MVP** (mục 3.3.6, 3.5.12, RWP, SKL, SCR-17, EVB-26..31, INP-01, 4.2.1): REWARD_PICK chuyển từ \[Should] sang \[MVP], level tối đa 3, 3+3 ô, 3 chủ động, 5 bị động, 3 stat, Reroll 1. Merge, level 4-5, mở ô, kéo thả chuyển \[Should] |
| 56 | **v1.8, xóa Overload và Retreat, thêm Enrage** (mục 3.8.1, 3.8.4 đến 3.8.11, TWR-08/09, DEAD-04, MODE-08, BRW-02/05/07, BOSS-08/16/29/30/36, HUD-01/04/10/14, ALR-03..06, TIME-03, EVB-17/24, tham số GameConfig, test mục 7.1): bỏ 8 bước giải quyết trong một frame, sát thương TRUE lên Fortress, phá tower hàng loạt, Retreat Zone và phím F. Thay bằng ENR-01..06 |
| 57 | **v1.8, Emergency repair:** giữ 3 lượt, cooldown 60 s; +1 lượt chuyển từ "hoàn thành wave boss" sang "diệt boss" (BRW-07), gắn thưởng với chiến đấu trực tiếp |
| 58 | **v1.8, chuyển sang \[Should]:** Barrage, di chuyển và hoán đổi tower (MOV), STARTER_KIT (shop còn 4 mục), 2 priority nâng cao, PNL-05, HUD-10, UI scale, LOD, con trỏ động, TUT-06/07, tab Gameplay của Settings |
| 59 | **v1.8, test** (mục 7.1): xóa các test Overload, Retreat, ép x1 T-20; thêm F1..F15. Lịch 7.3 viết lại theo mốc A (W7), B1 (W9), B2 (W10), đóng băng (W11) |
| 60 | **v1.8, giả định kỹ thuật G1..G7:** phiên 6 giờ, tối đa 2 phiên mỗi người mỗi tuần; W5 đã Done; GridData đã dựng; Firebomb là BLAST; armor chỉ huy chỉ từ Armored; commander_level không giảm; Aura áp cả tower WALL |
| 61 | **v1.8, bản hợp nhất đầy đủ** (16/10/2026): toàn bộ thay đổi 54 đến 60 được áp thẳng vào văn bản của v1.7, không còn phải đọc kèm tệp "thay đổi". Quyết định khi hợp nhất: (a) commander_level bắt đầu ở 0 để khớp tích lũy 2n² + 3n của XP-04; (b) bảng boss mục 3.8.10 tính lại đúng công thức (wave 10 Bulwark armor_hp 2669, core_hp 2002, Stomp 77; bản thay đổi ghi gần đúng 2664/1998); (c) đổi tên BUFF_FURY từ "Cuồng nộ" sang "Nổi giận" để không trùng Enrage; (d) mục 2.7 MVP bỏ tab Gameplay của Settings (khớp bảng phân công), hành vi mặc định cố định; (e) ETG-08 (tên cũ OVL-07) và các tham chiếu cập nhật; (f) đưa bảng số liệu SKL-10..15 vào mục 3.5.12.1 đến 3.5.12.3 thay vì trỏ sang tệp ngoài |
| 62 | **v1.8, sửa mâu thuẫn W6 (TimeManager, input, chết và hồi):** (a) DEAD-01 chỉ áp ở Frontline, khớp 3.2.4 và DEAD-09; thêm DEAD-10 (`commander_died` đúng một lần, cause MVP là ENEMY_DAMAGE, phân biệt với end_type COMMANDER_DIED); (b) CHAR-04 trỏ sang CHAR-08: chỉ buffer dodge, skill, attack, không buffer mode_switch, 1 ô, ghi đè theo ưu tiên, xóa khi đổi ngữ cảnh; (c) CHAR-07: một timeline combo, bỏ combo_reset_time (mục 3.5.1, 3.5.3); (d) TIME-10 ba loại đồng hồ, TIME-11 Pause theo tập lý do (USER, REWARD_PICK), RunState mục 3.2.2; (e) END-01 xử lý điều kiện thua cuối frame; (f) EVB-10 ghi rõ cause và số lần phát. Chưa đổi `event_bus.gd`: cần PR riêng thêm tham số cho EVB-01, 08, 10, 18 |
| 63 | **v1.8, chết và hồi (W6):** thêm EVB-32 `commander_low_hp_changed(is_low)` cho DEAD-07; thêm tham số `fall_y_threshold` (CharacterStats) cho DEAD-06; chỉ huy bỏ qua mọi sát thương ở PREP và SUMMARY (DEAD-05) |
| 64 | **v1.9, camera** (mục 2.2, 2.5, 3.2.1, 3.3.2, 3.5.2, 4.2, MSE-08, HUD-10, EVB-35, test CM1..CM8): thêm 4.2.3 (CAM-01 đến CAM-15). Frontline bám nhân vật và zoom gần, Commander và PREP dịch bằng WASD trong camera_bounds do Level đặt tay, không nhớ vị trí dịch, C về giữa. HUD-10 bản rút gọn lên \[MVP]. Cuộn chuột và kéo chuột vẫn \[Could] |
| 65 | **v1.9, Trạm hồi lực** (mục 3.6.6 HLT-01 đến HLT-19, SKL-26, BLD-09, UPG-03, TWR-01, SELL-05, PNL-14, HUD-18, ALR-17, ALR-18, FBK-12, AUD-07, EVB-33, EVB-34, test HT1..HT14): tower thứ tư, không tấn công, kho HP 300, hút bằng E sau hold 1.0 s, tối đa 2, chỉ ô grid, không tự hồi, chuẩn hóa sát thương theo căn bậc hai dmg_mult |
| 66 | **v1.9, bỏ regen Commander** (mục 3.5.1, 3.5.7, HUD-11, 6.4): xóa commander_regen_pct_per_sec và HUD-11; Commander mode bất khả xâm phạm nên không cần hồi. prep_heal_pct hạ 60% xuống 35% |
| 67 | **v1.9, SKL-26 Trạm hồi lực** (SKL-04, RWP-06, 3.5.12.2): bị động thứ sáu, chỉ vào pool sau khi đã xây trạm (heal_station_built). Mỗi level +5 HP/s tốc độ hồi, drain cố định nên k tăng. Pool 6 bị động, 3 ô bị động nên trần vẫn 27 lượt chọn |
| 68 | **v1.9, tài khoản và đồng bộ (MVP rút gọn từ bảng phân công v3)** (mục 3.13 ACCT-01 đến ACCT-12, SAV-17, mục 3.12.1, 6.3, 6.8, SCR-02, SCR-18, SET, ACP-08, mục 5.4, EVB-36, test AC1..AC5): local-first qua SaveRepository, chơi khách, auth.cfg riêng, revision và device_id, xung đột do người chơi chọn |
| 69 | **v1.9, bảng xếp hạng (MVP rút gọn từ bảng phân công v3)** (mục 3.14 LBD-01 đến LBD-10, SCR-19, test AC6..AC8): một dòng tốt nhất mỗi tài khoản, xếp theo waves_cleared, run_elapsed, thời điểm gửi; top 50 và hạng của mình; kiểm tra hợp lý ở máy chủ |
| 70 | **v1.9, tham số và dữ liệu** (mục 6.2, 6.3, 6.4, 6.6, 6.7, 6.8): thêm nhóm Trạm hồi lực, camera, tài khoản; bảng EVB-33 đến EVB-36; test 18 cập nhật phạm vi EVB |
| 71 | **v1.9, tiền tố, vai, lịch, Phụ lục C** (Phụ lục A thêm HLT, CAM, ACCT, LBD; Phụ lục B; mục 7.3; Phụ lục C mục 30 đến 37): các điểm cần nhóm xác nhận gồm SELL-05, các giá trị khởi điểm, người làm máy chủ và rủi ro backend gói miễn phí |
| 72 | **v1.9, bảng phân công v3 và lịch** (mục 7.3, ACCT-10, ACCT-11, Phụ lục C mục 17, 36, 37): hạn cuối tuần 13 (14/12), diễn tập 17/12; tuần 10 đến 12 làm 3 buổi mỗi tuần; đóng băng gameplay 29/11 và toàn bộ tính năng 6/12; báo cáo và video dời sang tuần 13 |
| 73 | **v1.9, online lên MVP rút gọn** (mục 2.2, 2.7, 3.1, 3.13, 3.14, ACCT-02..12, LBD-01..10, SCR-02, SCR-05, SCR-18, SCR-19, 4.6, 5.4, EVB-36, test AC, Phụ lục A, B): rút gọn gồm không hàng đợi nền (thử lại ở RunEnd hoặc mua shop kế tiếp), không hộp thoại chọn bản (lấy bản revision cao hơn, giữ save.conflict.bak), bỏ trạng thái CONFLICT, lọc tên là \[Should]. Settings thêm tab Tài khoản |
| 74 | **v1.9, cắt khỏi MVP sang \[Should]** (mục 2.7, RWP-03, SKL-04, SKL-08, SKL-13, SKL-15, 3.5.12.2, 3.5.12.3, REP-06, AUD-05, TUT-04, TUT-05, SCR-05, SCR-17, 4.6, INP-05, test F7, F9, F15, mục 7 của nhóm UI): Reroll, ducking, tab Điều khiển và Dữ liệu, TUT-04/05, thẻ Bền thành, bị động Focus và Lightstep. Pool MVP còn 4 bị động và 2 thẻ stat, nhịp bão hòa 24 lượt chọn |
| 75 | **v1.9, đồng bộ phân vai với bảng phân công v3** (Phụ lục B, EVB-35): CameraRig chuyển từ Player & Combat sang Art / Level / Audio; SaveRepository và save/load thuộc Tower & Build; thang xử lý kẹt, TIME-06 và nhắm Trạm hồi lực thuộc Enemy & Wave. Không đổi yêu cầu chức năng |
| 76 | **v1.9, tín hiệu tiếp tục ở SUMMARY** (mục 3.3.4, 6.9, EVB-37, TIME-02): thêm summary_continue_requested, do SummaryPanel phát khi bấm Tiếp tục hoặc hết 10 s đếm ngược (thời gian thực, dừng khi Pause). Wave FSM nghe tín hiệu này để rời SUMMARY sang REWARD_PICK hoặc PREP, bỏ bộ đếm riêng đang tính theo game time. Không đổi yêu cầu chức năng |
| 77 | **v2.0, PREP và Hazard Trial** (mục 2.2, 2.8, 3.1, 3.2.3, 3.3.1, 3.3.2, 3.15, WAVE-11, WAVE-12, TIME-02, TIME-08, TIME-11, DEAD-11, XP-06, CAM-16, HUD-19, HUD-22, HUD-23, EVB-38, EVB-40, EVB-41, test HZ1 đến HZ8): bỏ đếm ngược PREP, gọi wave sớm và phím G; thêm nút Bắt đầu wave và state HAZARD_TRIAL. Nguồn: preview_srs_v2.0_hazard.md (chốt 05/11) |
| 78 | **v2.0, Mithril** (mục 3.6.1, 3.9, 3.9.3, MTH-01 đến MTH-07, REP-07, PNL-04, PNL-13, HUD-20, EVB-39, 6.5): sửa Fortress ở PREP chỉ bằng Mithril, mỗi viên 20%; bỏ sửa bằng gold (REP-01, REP-04 đến REP-06, GLD-07) |
| 79 | **v2.0, vũ khí** (mục 3.5.13, WPN-01 đến WPN-12, BRW-09, BOSS-01, HUD-21, PNL-15, FBK-13, EVB-42, EVB-43, test WP1 đến WP8): 5 biến thể kiếm, boss wave 5 đến 25 rơi cây chưa có; bỏ Trượng phép và UNLOCK_WAND |
| 80 | **v2.0, xây dựng** (mục 1.3, 2.7, 3.6.2 đến 3.6.6, SLOT-05, GRID-03, GRID-04, GRID-07, TWR-13, TWR-15, TWR-17, BLD-08, BLD-10, BLD-11, UPG-01 đến UPG-06, SELL-03 đến SELL-06, CLR-02, HLT-01, HLT-07, HLT-08, FRT-03, 6.3, test Fortress, tower): 3 WALL + 3 ô grid, lưới 9 hàng phủ hành lang 23.5 m (bản đầu ghi 6 hàng và 16 m, sửa theo Phụ lục C mục 61), bỏ no_build_lane và SLOT-03, tower 36 cấp với 3 bậc model, cổng bậc ở cấp 13 và 25, trụ có sẵn khóa bán tới wave 3; bỏ MOV-01 đến MOV-07, EVB-25 và phím M |
| 81 | **v2.0, đầu run, thắng và endless** (mục 1.2, 3.2.1, 3.2.2, 3.2.4, END-07 đến END-10, FLOW-01, FLOW-06, GLD-06, STR-06, SCR-11, SCR-20, SCR-21, 4.7, TUT-01, TUT-14 đến TUT-17, flags.tutorial_done, ACCT-04, EVB-21, EVB-44, EVB-45, test VC và TU): 0 gold, hai trụ có sẵn, tutorial một lần theo tài khoản, victory_wave 30 rồi endless; bỏ STARTER_KIT (SHP-01 đến SHP-04), TUT-02 và ALR-08 |
| 82 | **v2.0, quân địch** (mục 3.7.1, 3.7.3, 3.7.4, 3.7.5, 3.7.6, 3.7.8, EN-16 đến EN-27, SPN-13, SPN-14, SCL-06, NAV-02, NAV-06, NAV-15, BOSS-04, BOSS-40, test NE): 7 loại mới, Brute sửa, tắt va chạm giữa quân, tối đa 5 loại mỗi wave, kịch bản wave 1-30, công thức scale từ wave 31; bỏ WAVE-07 |
| 83 | **v2.0, bảng cân bằng** (mục 1.4, 5.5, 6.1, 6.2, 6.6, 6.10, DAT-06, DAT-07, BAL-01 đến BAL-07, test BL1 đến BL4): số liệu cân bằng sinh từ `balance/balance.xlsx` bằng script Python và `openpyxl`, có runner kiểm config. Phụ lục E thêm danh sách mã bỏ; Phụ lục C thêm mục 38 đến 60 (quyết định tự đặt, sau đó đã duyệt 05/11) |
| 84 | **05/11: sửa theo review nhất quán (7 mục)** (HZT-07, HZT-16, MTH-02, HUD-22, RWD-01, RWD-02, FRT-02, GLD-02, GLD-10, BRW-01, EVB-05, GRID-07, GRID-08, SLOT-05, BOSS-03, BOSS-40, END-07, WAVE-13, mục 3.3.1, 3.3.4, EVB-37, EVB-44, EVB-46, SCR-20, RUN-02, SPN-15, LBD-04, LBD-06, BAL-05, mục 6.3, Phụ lục B, trang đầu, mục 2.5, 7.3, test HZ9 đến HZ12, Fortress và tower 4 và 21, VC5, AC9, BL3): (1) kết thúc Hazard Trial khi quân tự nổ và cùng frame; (2) một công thức gold cho phòng, hệ số chỉ huy áp một lần; (3) giữ đường và vùng cấm xây quanh boss_melee_point; (4) thứ tự rời SUMMARY ở wave thắng; (5) định nghĩa run_elapsed và lịch sinh trải đủ spawn_duration để sàn máy chủ không từ chối điểm thật; (6) Phụ lục B và nhật ký dòng 80 đổi bố cục 6 hàng thành 9 hàng, hành lang 23.5 m; (7) trang đầu tách thiết kế đã duyệt với lịch và phân vai chờ chốt, 13 tuần khớp mục 7.3. Quyết định tự đặt ghi ở Phụ lục C mục 62 đến 66 |
| 85 | **07/11: đồng bộ theo code UI tuần 9** (HUD-20, EVB-30): ô Mithril có nút "Sửa thành" mở panel Fortress (trước đây chỉ là dấu gợi ý); skill_slots_changed thêm tham số levels để thanh slot của màn REWARD_PICK đọc cấp skill thay vì tự nhớ |
| 86 | **11/11: đồng bộ theo code UI tuần 10** (mục 4.1.3, HUD-15, HUD-16, HUD-17, HUD-21, HUD-24, EVB-47): thêm nút mũi tên ẩn/hiện kỹ năng (HUD-24) chỉ ẩn phần hiển thị, phím 1-3 vẫn dùng được; bỏ dòng vùng "Dưới trái, trên thanh HP chỉ huy" vì mâu thuẫn với HUD-15 (thanh HP chỉ huy nằm ở trên trái); thanh XP và biểu tượng Aura đặt ở trên trái cạnh HP chỉ huy, hai hàng ô skill và ô vũ khí ở dưới trái trên ô Emergency repair; thêm xp_gained để thanh XP tô riêng phần XP từ chỉ huy và từ tower |

## Phụ lục E. Mã đã bỏ ở v2.0

Các mã dưới đây đã xóa khỏi bảng của mục 3 đến 7. Số mã không được dùng lại cho nghĩa mới.

| **Mã** | **Nội dung cũ** | **Lý do bỏ** |
| --- | --- | --- |
| WAVE-07 | Gọi wave sớm liên tục để bơm gold | Bỏ gọi wave sớm và thưởng gọi sớm; PREP kết thúc bằng nút Bắt đầu wave (WAVE-11) |
| GLD-07 | Chi phí sửa Fortress bằng gold | Sửa Fortress ở PREP chỉ bằng Mithril (MTH-03) |
| GLD-09 | early_call_bonus cộng ở SUMMARY | Bỏ thưởng gọi wave sớm |
| REP-01 | Sửa bằng gold +10%, +25%, đầy HP | Thay bằng sửa bằng Mithril (MTH-03, REP-07) |
| REP-04 | Đầy HP thì từ chối, không trừ gold | Thay bằng MTH-04 |
| REP-05 | Không sửa bằng gold trong COMBAT | Thay bằng MTH-05 |
| REP-06 | Giá sửa không đổi theo cấp FORT_HP | Hết giá sửa bằng gold; FORT-04 vẫn giữ phần meta |
| SLOT-03 | Làn thông thoáng 4 m bảo đảm bằng no_build_lane | Bỏ no_build_lane; đường đi bảo đảm bằng luật cấm chặn kín (GRID-07) |
| MOV-01 đến MOV-07 | Di chuyển và hoán đổi tower \[Should] | Bỏ di chuyển tower; người chơi chọn loại và slot khi xây |
| EVB-25 | tower_moved | Đi cùng MOV |
| SHP-01 đến SHP-04 | Luật STARTER_KIT \[Should] | Thay bằng hai trụ có sẵn đầu run (mục 3.2.1, SELL-06) |
| ALR-08 | Cảnh báo PREP còn 5 s | PREP không còn đếm ngược |
| TUT-02 | Gợi ý gọi wave sớm (G) | Bỏ phím G; thay bằng TUT-15 (bấm Bắt đầu wave) |

**Tham số, phím và mục bỏ theo** (không phải mã yêu cầu): prep_time_early, prep_time_late, prep_early_until_wave, prep_time_boss, early_call_gold_per_sec, early_call_cap, early_call_bonus (RunState), repair_gold_per_pct, repair_step_small_pct, repair_step_large_pct, no_build_lane_min_width, no_build_lane_min_ratio, ally_phase_time, avoid_radius và avoid_priority (EnemyData), tower_gate_lv2 và tower_gate_lv3 (đổi tên thành tower_gate_tier2, tower_gate_tier3), phím G (call_wave), phím M (relocate), slot W4 đến W6, mục shop STARTER_KIT và UNLOCK_WAND, Trượng phép, bảng chỉ số tower 3 cấp (thay bằng 36 cấp trong bảng cân bằng), bảng gold theo wave tham chiếu v1.7.

Hết tài liệu SRS-EW-2.0 (Hazard Trial).
