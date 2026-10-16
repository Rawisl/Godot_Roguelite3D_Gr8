# SOFTWARE REQUIREMENTS SPECIFICATION

## Chiến Tuyến Vô Tận (Endless War)

| **Hạng mục** | **Nội dung** |
| --- | --- |
| Mã tài liệu | SRS-EW-1.8 |
| Phiên bản | 1.8. Dựa trên v1.7. Thêm vòng lặp khuyến khích Frontline (FRT, XP), Skill Tree 3 chọn 1 (SKL, RWP), thay Overload và Retreat bằng Enrage (ENR). Chuyển Barrage, di chuyển/hoán đổi tower, STARTER_KIT sang \[Should]. Áp dụng từ Tuần 6. Bản này là bản đầy đủ, tự đứng được, không cần đọc kèm v1.7 |
| Ngày phát hành | 16/10/2026 |
| Nền tảng phát triển | Godot 4.x, 3D, camera orthographic isometric |
| Đội ngũ, thời gian | 5 người, 12 tuần (Tuần 1-5 đã hoàn thành, Tuần 6-12 theo bảng phân công v2) |
| Trạng thái | Bản nền để nhóm chia task, viết test và cân bằng. Mọi con số là **giá trị khởi điểm**, chỉnh qua Resource/CSV khi playtest. |

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

4. Yêu cầu giao diện ngoài

   - 4.1 Giao diện người dùng: màn hình, HUD, panel
   - 4.2 Input và chuột trong isometric
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

Tài liệu đặc tả đầy đủ yêu cầu của game Chiến Tuyến Vô Tận (Endless War), làm căn cứ chung cho thiết kế, lập trình, cân bằng, kiểm thử và nghiệm thu của nhóm 5 người. Mỗi yêu cầu có **ID duy nhất** để trích dẫn khi chia task và viết test.

## 1.2 Phạm vi sản phẩm

Game PC một người chơi, thể loại Action Tower Defense, Strategy, Roguelite (endless). Người chơi là chỉ huy bảo vệ **Fortress** trước các làn sóng quái vật, điểm số là **số wave hoàn thành** trong một run. Giữa các run, người chơi dùng **Danh vọng** để mạnh dần qua meta shop.

**Ngoài phạm vi (Won't):** material và crafting, nhiều map, xây dựng tự do (free-placement; ô grid ở mục 3.6.2 không phải free-placement vì mỗi ô là một slot cố định), cơ chế "bỏ thành" và 3 lần bỏ thành, checkpoint giữa run, multiplayer, đồng bộ đám mây, lồng tiếng, tự bạo boss gây sát thương TRUE (Overload) và hành động Retreat.

## 1.3 Thuật ngữ

| **Thuật ngữ** | **Định nghĩa** |
| --- | --- |
| Run | Một lượt chơi từ lúc xuất phát đến khi thua hoặc bỏ. Không lưu giữa chừng |
| Wave | Một đợt quân địch. Gồm các state PREP, COMBAT, SUMMARY (và BOSS_INTRO, BOSS_COMBAT ở wave boss) |
| Fortress | Thành chính, duy nhất, cố định. HP về 0 thì hết run |
| Tower | Công trình tấn công hoặc phòng thủ (Arrow, Cannon, Barricade), đặt trong build slot |
| Build slot | Vị trí xây cố định, thuộc zone WALL hoặc GROUND. Slot WALL là Marker3D đặt tay; slot GROUND là **ô grid** sinh sẵn từ GridData lúc nạp level (mục 3.6.2). Zone NEAR và FAR của v1.6 gộp thành GROUND vì có cùng luật |
| Ô grid (cell) | Một slot GROUND có kích thước grid_cell_size, slot_id là cell_id dạng G_c_r (GRID-01) |
| no_build_lane | Dải dọc lane_curve không có ô grid nào, giữ làn thông thoáng cho quân và boss (GRID-03) |
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
| Di chuyển tower (relocate) \[Should] | Chuyển một tower đang có sang slot khác cùng nhóm vị trí (slot WALL với slot WALL, ô grid với ô grid) ở PREP, giữ nguyên loại, cấp, priority và giá trị đầu tư. Slot đích có tower hoặc đống đổ nát thì hai bên hoán đổi chỗ (MOV-01, MOV-02) |
| Dọn đổ nát (clear ruin) | Đưa slot RUINED về EMPTY ở PREP, miễn phí, bỏ đống đổ nát cùng ruined_type và ruined_level (CLR-01) |
| clear_mult, par_time | Hệ số gold theo tốc độ dọn wave (Fast 1.25, Normal 1.00, Slow 0.80), so clear time với par_time (mục 3.3.3) |
| Emergency repair | Hồi HP Fortress miễn phí gold, chỉ ở Commander mode, tối đa 3 lượt mỗi run, +1 lượt khi diệt boss (CMD-02, BRW-07) |
| FRENZY | Trạng thái quân lẻ sau 240 s: tốc độ x1.5, đi thẳng Fortress (EN-02) |
| Recycle, Cull | Hai bậc cuối của thang xử lý kẹt: đưa quân về spawn_zone (NAV-08), hoặc xóa quân không thưởng (NAV-09) |
| RunConfig, RunState | RunConfig: giá trị cố định của một run, tạo ở RunLoading. RunState: trạng thái thay đổi trong run (mục 3.2.2, 6.7) |

## 1.4 Quy ước

| **Mục** | **Quy ước** |
| --- | --- |
| ID yêu cầu | Dạng PREFIX-nn. Bảng tiền tố ở Phụ lục A |
| Tham số | snake_case, lưu trong GameConfig và các Resource. Giá trị ghi kèm là giá trị khởi điểm |
| Thời gian | Timer gameplay dùng game time. Animation UI, cảnh báo, fade dùng thời gian thực |
| Điểm số | waves_cleared = số wave đã hoàn thành trọn vẹn. Chết ở wave N nghĩa là waves_cleared = N-1 |
| Ưu tiên | **\[MVP]** bắt buộc, **\[Should]** làm nếu đủ tiến độ, **\[Could]** chỉ khi dư thời gian. Không đánh dấu nghĩa là MVP. ID của mục bị chuyển sang \[Should] được giữ nguyên để không gãy tham chiếu |
| Làm tròn | Làm tròn **một lần ở cuối** công thức, trừ khi ghi khác. Mặc định: khoản người chơi nhận (gold, uy tín, danh vọng, tiền hoàn bán) làm tròn xuống. Khoản người chơi phải trả (giá sửa) làm tròn lên. Sát thương lên chỉ huy và Fortress làm tròn lên. Sát thương lên quân thường và boss làm tròn gần nhất (DMG-06). Chỉ số quân, boss và budget theo công thức scale làm tròn gần nhất |
| Máu hồi | commander_hp lưu float trong RunState để hồi nhỏ (Lifesteal 0.5%, regen theo frame) không bị cắt về 0. Chỉ làm tròn xuống khi hiển thị và khi phát commander_hp_changed (EVB-08). Chết khi commander_hp <= 0 |
| Mức độ bắt buộc | "phải" là bắt buộc, "nên" là khuyến nghị, "có thể" là tùy chọn |

## 1.5 Cấu trúc tài liệu

Mục 3 và 4 là yêu cầu chức năng và giao diện, mỗi mục con gồm: mô tả, dữ liệu, luật (ID), edge case. Mục 5 là phi chức năng. Mục 6 gom tham số và cấu trúc dữ liệu. Mục 7 gồm test case và lịch nghiệm thu. Phụ lục có bảng tiền tố ID, phân vai, vấn đề còn mở, và nhật ký đồng bộ so với các bản nháp trước. Từ v1.8, mọi yêu cầu mới đều gắn rõ **\[MVP]** hoặc **\[Should]**; ID của mục bị xóa được giữ lại với nhãn \[ĐÃ XÓA v1.8] để không gãy tham chiếu.

# 2. MÔ TẢ TỔNG QUAN

## 2.1 Bối cảnh sản phẩm

| **Hạng mục** | **Nội dung** |
| --- | --- |
| Góc nhìn | Camera orthographic isometric cố định, nhìn ngang từ trái sang phải. Fortress ở cực trái, điểm spawn ở cực phải, map là hành lang ngang |
| Map | **1 map duy nhất**. Tính ngẫu nhiên nằm ở nội dung wave, không ở địa hình. Người chơi học bố cục slot và tối ưu qua các run |
| Điểm khác biệt | Người chơi tự chọn **ra trận trực tiếp** (rủi ro cao, thưởng cao) hoặc **điều phối từ trên thành** (an toàn, phụ thuộc bố trí) |
| Trụ cột | Một vòng lặp chiều sâu: Chuẩn bị, Chiến đấu, Tổng kết, Wave kế. Mọi thứ khác là mở rộng |

## 2.2 Chức năng chính

1. Vòng lặp wave endless với độ khó scale theo công thức.
2. Hai chế độ điều khiển (Frontline, Commander) dùng chung một camera, một nhân vật. **Frontline là chế độ tăng trưởng** (XP, skill, Aura, gold chỉ huy); **Commander là chế độ phòng thủ và quản lý** (priority, sửa chữa).
3. Xây dựng phòng thủ trên slot cố định: 6 slot WALL và ô grid mặt đất (tối đa 8 công trình trên grid), 3 loại tower, 3 cấp mỗi loại. Cấp tower tối đa bị giới hạn theo Cấp Chỉ huy (FRT-03). Dọn đống đổ nát ở PREP (CLR). \[Should] Di chuyển và hoán đổi tower.
4. Kẻ địch data-driven với bảng ưu tiên mục tiêu.
5. Wave boss với giáp theo pha, đồng hồ Cuồng nộ.
6. Tiến triển roguelite: Danh vọng và meta shop 4 mục. Trong run: **Skill Tree 3 chọn 1** từ XP. Buff một wave và chọn wave khởi đầu là \[Should].
7. Tua tốc độ và gọi wave sớm thay cho checkpoint.

8. Frontline có phần thưởng riêng và tạo ra sức mạnh mà Commander không có (FRT, XP, SKL).

## 2.3 Nhóm người dùng

| **Nhóm** | **Đặc điểm** | **Hệ quả yêu cầu** |
| --- | --- | --- |
| Người chơi mới | Chưa biết cơ chế | Tutorial ngữ cảnh (mục 4.7), wave 1-2 chỉ Grunt, cảnh báo boss rõ |
| Người chơi thành thạo | Chơi lặp, tối ưu | Tua x2/x3, gọi wave sớm, target priority. \[Should] chọn wave khởi đầu |
| Nhóm phát triển (5 vai) | Combat, Enemy & Wave, Tower & Build, UI/Meta, Art/Level/Audio | Dữ liệu tách khỏi code, EventBus, scene sở hữu riêng (mục 5) |

## 2.4 Môi trường vận hành

Windows PC (mục tiêu chính), Godot 4.x, bàn phím và chuột. Gamepad là \[Could]. Cấu hình tối thiểu chốt theo **máy yếu nhất của nhóm** và ghi vào báo cáo (ACP-01).

## 2.5 Ràng buộc

| **Ràng buộc** | **Chi tiết** |
| --- | --- |
| Nhân lực, thời gian | 5 người, 12 tuần. Tuần 1-5 đã xong, Tuần 6-12 làm tính năng v1.8 (mỗi người tối đa 2 phiên mỗi tuần). Mục tiêu hoàn thành 80-90% tổng phạm vi ở cuối Tuần 12 |
| Asset | Ưu tiên low-poly có sẵn (Kenney, Quaternius), thống nhất palette và shader toon/flat |
| Dữ liệu | Toàn bộ chỉ số trong Resource hoặc CSV, không hard-code |
| Git | Mỗi người sở hữu scene riêng, tách dữ liệu bằng Resource, tránh xung đột .tscn |
| Camera | Không có điều khiển camera thủ công ở MVP |

## 2.6 Giả định và phụ thuộc

- Người chơi dùng chuột và bàn phím.
- Bố cục hành lang đủ hẹp để nằm trọn trong camera tổng quan.
- Bat (quân bay) là \[Should] và là điều kiện để priority Flying và khả năng bắn trên không của Arrow có ý nghĩa. Bỏ Bat thì bỏ luôn priority Flying.
- Góc camera (camera_pitch -45, camera_yaw 20) là giá trị khởi điểm, chốt ở tuần 1.

## 2.7 Phạm vi theo mức ưu tiên

| **Nhóm** | **Nội dung** |
| --- | --- |
| **Must (MVP)** | 1 map, Fortress, 6 slot WALL cố định và ô grid mặt đất (tối đa 8 công trình, tổng 14), dọn đổ nát ở PREP, 1 nhân vật (Kiếm), Frontline và Commander rút gọn, 3 tower (Arrow, Cannon, Barricade) với **2 priority (First, Nearest)**, 3 quân (Grunt, Archer, Brute), bảng trọng số và công thức scale endless, **1 boss (Bulwark, lặp có scale) với pha giáp và đồng hồ Cuồng nộ**, tổng kết wave, thưởng clear time, tua x2/x3, gọi wave sớm, **vòng lặp Frontline (Aura, gold chỉ huy, XP, giới hạn cấp tower)**, **Skill Tree MVP (3 chủ động, 5 bị động, 3 thẻ stat, level 3, 3+3 ô, Reroll 1 lần)**, Emergency repair (3 lượt), meta shop 4 mục (FORT_HP, GOLD_PCT, CMD_HP, EMG_REPAIR), save/load (ghi atomic, checksum, .bak, khôi phục run gián đoạn), thang xử lý kẹt MVP, tutorial rút gọn (TUT-01..05), Settings (Âm thanh, Đồ họa, Tiếp cận cơ bản, Điều khiển chỉ đọc, Dữ liệu), tiếng Việt |
| **Should** | Boss Barrage, Elite có giáp tiền tuyến (FRT-05), chiến lợi phẩm Brute (FRT-06), merge skill, skill level 4-5, Sword Throw, War Horn, Arrow Rain, mở ô skill và mở skill bằng danh vọng, kéo thả ô skill, Reroll mua thêm, di chuyển và hoán đổi tower (MOV), STARTER_KIT, priority Highest HP/Lowest HP và "Áp dụng cho mọi tower cùng loại", preview boss PNL-05, chỉ báo ngoài màn hình HUD-10, UI scale, LOD animation, con trỏ động, modifier wave, nhiều điểm spawn, **StartSelect cùng chọn wave khởi đầu**, **buff một wave (BUFF\_CHARGE)**, Trượng phép, bẫy, Bat, Healer, Debuffer, mục shop UNLOCK_TRAP và UNLOCK_WAND, **hoàn tác bán 3 s**, **tiếng Anh và pseudo-localization**, **3 preset mù màu và chế độ tương phản cao**, **nhạc phân lớp, tăng tempo nhạc boss, panning theo vị trí, lọc thông thấp khi Pause**, **rebind phím**, **migration save**, **hop cục bộ, watchdog cấp wave, NAV-10, overlay debug và bot soak test 200 wave** |
| **Could** | Xóa skill, skill tree nhiều nhánh, base upgrade nhiều nhánh, tower 4-5, spell scroll, Shaman, boss thứ 3, relic tăng giờ boss, gamepad, reset shop hoàn 80%, kéo camera, Last Stand |
| **Won't** | Xem mục 1.2 |

## 2.8 Nguyên tắc thiết kế

| **Nguyên tắc** | **Hệ quả** |
| --- | --- |
| Chuyển chế độ không phải nút thoát hiểm tức thì | Recall có channel, hủy khi bị đánh (MODE-01) |
| Mọi quyết định đầu tư diễn ra ở PREP | Xây, nâng, bán, sửa bằng gold chỉ ở PREP |
| Gold luôn khan hiếm | Buộc chọn tower, zone, và có sửa Fortress hay không |
| Boss là bài kiểm tra cách xây dựng | Mỗi boss miễn nhiễm loại sát thương của một loại tower ở pha 1 |
| Luôn có đường thắng, không bế tắc | Kiếm luôn gây sát thương lên boss (60% ở pha giáp), boss luôn có thể bị hạ, wave luôn kết thúc khi hết quân (ENR-06) |
| Thua boss không đồng nghĩa thua run | **Hạ boss chậm bị phạt bằng Cuồng nộ**, boss mạnh lên chứ không xóa tower hay Fortress tức thì (ENR-01..06) |
| Sức mạnh trong run đến từ chiến đấu trực tiếp | Cấp tower, skill, gold bonus đều gắn với việc chỉ huy gây sát thương (FRT-01..03, XP-01..05). Tower tự giết vẫn cho phần thưởng nhưng chậm hơn |
| Kết quả xác định, dễ test | RNG theo luồng riêng mỗi wave, tie-break theo entity_id |

# 3. YÊU CẦU CHỨC NĂNG

## 3.1 Luồng ứng dụng

Boot -> MainMenu\
MainMenu -> RunLoading -> Run -> RunEnd\
\[Should] MainMenu -> StartSelect -> RunLoading\
MainMenu <-> MetaShop\
MainMenu <-> Settings\
RunEnd -> RunLoading | MetaShop | MainMenu\
Run -> (Pause) -> Run | RunEnd (Abandon)

| **State** | **Vào khi** | **Hành động cho phép** | **Ra khi** |
| --- | --- | --- | --- |
| Boot | Mở game | Đọc save, tải config, khôi phục run gián đoạn (mục 3.12.4) | Vào MainMenu |
| MainMenu | Từ Boot, RunEnd, MetaShop | Play, Meta Shop, Settings, Quit | Chọn nút. MVP: Play vào thẳng RunLoading |
| StartSelect \[Should] | Bấm Play (khi đã làm StartSelect) | Chọn wave khởi đầu \[Should], nạp buff, xác nhận | Xác nhận hoặc Back |
| RunLoading | Bấm Play (MVP), xác nhận StartSelect \[Should], hoặc Chơi lại ở RunEnd | Không (màn hình chờ) | Khởi tạo xong |
| Run | Sau RunLoading | Theo state của wave (mục 3.3) | Điều kiện kết thúc (mục 3.2.4) |
| RunEnd | Run kết thúc | Xem tổng kết, chọn bước kế | Chọn nút |
| MetaShop | Từ MainMenu hoặc RunEnd | Mua, xem chi tiết | Back |

| **ID** | **Tình huống** | **Xử lý** |
| --- | --- | --- |
| FLOW-01 | Lần chạy đầu, chưa có save | Tạo save mặc định, chỉ mở wave 1, bật tutorial ở run đầu (có nút Skip) |
| FLOW-02 | Save hỏng hoặc sai version | Theo quy trình SAV-01, SAV-02: thử .tmp, .bak, rồi cho "Tạo save mới" và giữ tệp hỏng đổi tên .corrupt |
| FLOW-03 | Tắt game đột ngột giữa Run | Không lưu trạng thái Run. run_flag (run_in_progress, start_wave, start_mult, waves_cleared, prestige_pending) được ghi khi bắt đầu Run và ở mỗi SUMMARY. Lần mở sau chốt run như ABANDONED (mục 3.12.4) |
| FLOW-04 | Bấm Quit khi đang ở Run | Hộp thoại xác nhận. Đồng ý thì chốt ABANDONED rồi thoát |
| FLOW-05 | Cửa sổ mất focus | Tự pause (**mặc định bật**; MVP luôn bật, tùy chọn tắt ở tab Gameplay là \[Should]) |
| FLOW-06 | MVP: không có StartSelect | Play vào thẳng RunLoading với start_wave = 1, starting_gold = 150, start_mult = 1.0. \[Should] Khi đã làm StartSelect: bỏ qua màn này nếu chưa mở mốc nào ngoài wave 1 **và** kho buff rỗng |
| FLOW-07 | Save ghi dở khi tắt máy | Ghi atomic qua tệp tạm (mục 3.12.2) |

## 3.2 Vòng đời Run

### 3.2.1 Khởi tạo (RunLoading)

Thứ tự **bắt buộc**:

| **Bước** | **Nội dung** |
| --- | --- |
| 1 | Tạo RunConfig. MVP: start_wave = 1, starting_gold = 150, start_mult = 1.0. \[Should] Lấy từ StartSelect: start_wave, starting_gold, StartPack, start_mult, buff đã nạp |
| 2 | Sinh run_seed. Mỗi wave dùng luồng RNG riêng seed = hash(run_seed, wave_index) |
| 3 | Nạp map, đặt Fortress với fortress_max_hp = 1000 × (1 + 0.05 × cấp FORT_HP), HP đầy (FORT-04). Đặt chỉ huy ở chế độ Frontline tại deploy_point |
| 4 | \[Should] Nếu start_wave = 1 thì đặt công trình từ STARTER_KIT (SHP-02). \[Should] Đặt công trình của StartPack khi start_wave > 1. MVP: bắt đầu với 0 công trình |
| 5 | Áp meta: commander_max_hp = 100 + 10 × cấp CMD_HP, lượng hồi Emergency repair emg_repair_heal_pct = 20% + 3% × cấp EMG_REPAIR, gold_pct_meta = 0.04 × cấp GOLD_PCT. Đặt Emergency repair về trạng thái khởi đầu: emg_repair_charges = 3 (tối đa emg_repair_charges_max = 3), emg_repair_cd = 0. **Khởi tạo Skill và XP \[MVP]:** xp = 0, commander_level = 0, pending_picks = 0, ô skill trống, stat_stacks rỗng, rerolls_left = rerolls_per_run, reward_rng seed = hash(run_seed, "reward", 0) |
| 6 | \[Should] Nạp các lượt buff đã chọn vào run_buffs_loaded |
| 7 | Ghi run_in_progress = true vào save |
| 8 | Vào PREP của wave start_wave |

### 3.2.2 RunState

| **Nhóm** | **Trường** |
| --- | --- |
| Tiến trình | wave_index, waves_cleared, run_elapsed (game time), run_seed |
| Kinh tế | gold, prestige_pending, wave_gold_base, wave_prestige_buffer, early_call_bonus |
| Fortress | fortress_hp, fortress_max_hp (giá trị hiệu dụng, khởi tạo từ RunConfig, tăng được bởi thẻ Bền thành, SKL-15) |
| Emergency repair | emg_repair_charges (0-3), emg_repair_cd (giây game time còn lại), emg_repair_heal_pct |
| Chỉ huy | commander_hp (float), commander_max_hp (hiệu dụng, khởi tạo từ RunConfig, tăng được bởi thẻ Thể lực, SKL-15), mode, position, skill_cooldowns |
| Skill và XP \[MVP] | xp (float), commander_level, pending_picks, active_slots[3], passive_slots[3] (mỗi ô {id, level}), stat_stacks (Dictionary), rerolls_left, reward_rng. Mất khi hết run (RUN-01) |
| Tower | Bảng slot_id (W1-W6 hoặc cell_id của ô grid) -> {state, tower_type, level, hp, target_priority, invested_gold, ruined_type, ruined_level}. ruined_type và ruined_level chỉ có giá trị khi state = RUINED (SLOT-02, SLOT-08) |
| Thống kê run | run_kills (không tính quân bị cull, RWD-03), run_commander_kills (số quân chết có hit_by_commander), run_gold_earned (gold nhận từ quân, boss, clear time, gọi wave sớm; không tính tiền bán tower), run_bosses_defeated, damage_by_tower_type (sát thương tower gây ra, theo loại). Dùng cho RunEnd (mục 3.2.4). Chỉ run_kills và run_bosses_defeated cộng vào profile.stats ở RunEnd (mục 3.12.1); run_gold_earned, run_commander_kills và damage_by_tower_type chỉ dùng trong lượt chơi, không ghi xuống đĩa |
| Wave | wave_modifiers, spawn_queue, enemies_alive, wave_clear_timer |
| Boss | boss_timer, phase, boss_enraged |
| Buff \[Should] | run_buffs_loaded, active_buff |
| Điều khiển | time_scale, is_paused (dẫn xuất từ pause_requests, TIME-11) |

**RUN-01.** Không trường nào của RunState (kể cả xp, Cấp Chỉ huy, skill đã nhặt) được ghi xuống đĩa giữa Run, trừ run_flag (FLOW-03) và \[Should] kho buff khi kích hoạt (BUF-04). Số lượt Emergency repair không được lưu: mỗi run mới (kể cả sau khi khôi phục run gián đoạn) luôn bắt đầu ở 3/3.

### 3.2.3 Tham số Run

prep_time chọn theo wave: prep_time_early 25 s (wave 1-3), prep_time_late 30 s (từ wave 4). prep_time_boss 45 s. max_alive 70. Tên tham số và nơi lưu ở mục 6.3.

### 3.2.4 Kết thúc Run

| **Loại** | **Điều kiện** |
| --- | --- |
| FORTRESS_DESTROYED | fortress_hp <= 0 |
| COMMANDER_DIED | commander_hp <= 0 ở Frontline (Commander mode không thể chết, CMD-10) |
| ABANDONED | Abandon ở Pause, FLOW-03, FLOW-04 |

Game endless **không có màn thắng**. Hai điều kiện thua cùng frame thì ghi FORTRESS_DESTROYED.

**Trình tự kết thúc:**

1. Chặn input, slow motion 0.2x trong 1.5 s (thời gian thực, chỉ hoạt cảnh, FBK-10).
2. Dừng spawner, hủy toàn bộ quân và projectile.
3. Tính danh vọng:

prestige_gain = floor( (prestige_pending + 0.5 × wave_prestige_buffer) × conversion_rate × start_mult )

conversion_rate = 30% cho cả ba loại kết thúc. wave_prestige_buffer là uy tín từ quân đã diệt trong wave **đang dở**.

Phạm vi của start_mult: chỉ nhân vào prestige_gain (bù cho việc bỏ qua các wave đầu). start_mult không ảnh hưởng độ khó wave (scale theo wave_index thật, mục 3.7.6), gold thưởng, đồng hồ boss hay bất kỳ công thức nào khác.

4. Cập nhật save: cộng danh vọng, cộng thống kê run (run_kills, run_bosses_defeated), tăng total_runs thêm 1 vào profile.stats, cập nhật max_wave_cleared và best_by_start, đặt run_in_progress = false, kiểm tra mốc mới mở.
5. Vào RunEnd, chờ người chơi bấm nút, không tự chuyển màn.

**RunEnd hiển thị:** loại kết thúc, waves_cleared, so với kỷ lục ("Kỷ lục mới"), tổng quân diệt, gold kiếm được, uy tín thu về, conversion_rate, start_mult, prestige_gain, số dư mới, mốc mới mở, bosses_defeated, Cấp Chỉ huy đạt được, số quân chỉ huy tự hạ (run_commander_kills), loại tower gây nhiều sát thương nhất (damage_by_tower_type, không tính Barricade, ẩn dòng nếu chưa có tower nào gây sát thương). Nút: **Chơi lại** (vào RunLoading, \[Should] vào StartSelect khi đã có), **Meta Shop**, **Menu chính**.

| **ID** | **Tình huống** | **Xử lý** |
| --- | --- | --- |
| END-01 | Chỉ huy chết đúng frame Fortress sập | Ghi FORTRESS_DESTROYED, xử lý **một lần**, không cộng danh vọng hai lần. RunState không kết thúc run ngay khi nhận `commander_died` hay tín hiệu Fortress sập: chỉ đánh dấu điều kiện thua, rồi xử lý **cuối frame** (`call_deferred`). Nếu có cả hai thì ghi FORTRESS_DESTROYED. Sau khi đã chốt, mọi điều kiện thua đến sau bị bỏ qua |
| END-02 | start_wave > 1 | waves_cleared theo số thứ tự tuyệt đối. Kỷ lục lưu riêng theo mốc (best_by_start) |
| END-03 | Chết ở wave 1 với prestige_pending = 0 | prestige_gain = 0, vẫn hiện RunEnd |
| END-04 | Bấm Chơi lại liên tục | Chỉ nhận một lần bấm, khóa nút cho đến khi chuyển màn |
| END-05 | Kết thúc run trong lúc ghi save | Hoàn tất ghi save trước rồi mới chuyển màn |
| END-06 | Đạt mốc mở khóa nhưng đồng thời thua | Mốc vẫn mở (dựa max_wave_cleared đã cập nhật ở bước 4) |

## 3.3 Wave

### 3.3.1 State machine

PREP -> COMBAT -> SUMMARY -> REWARD_PICK -> PREP (wave n+1)\
PREP -> BOSS_INTRO -> BOSS_COMBAT -> SUMMARY -> REWARD_PICK -> PREP\
Mọi state -> RUN_END (khi thỏa mục 3.2.4)

REWARD_PICK là **\[MVP]**. Không có lượt chờ (pending_picks = 0) hoặc pool rỗng thì bỏ qua state này (RWP-06).

### 3.3.2 PREP

| **Hạng mục** | **Đặc tả** |
| --- | --- |
| Thời lượng | prep_time, đếm ngược trên HUD. Wave boss dùng prep_time_boss |
| Cho phép | Xây, nâng cấp, bán, sửa Fortress bằng gold, đổi target priority, di chuyển tự do, đổi chế độ (không cooldown, không channel). \[Should] Kích hoạt buff |
| Không có quái | Chỉ huy và Fortress không nhận sát thương. Tower hồi đầy HP ở đầu PREP (TWR-01). Chỉ huy hồi prep_heal_pct |
| Kết thúc | Hết giờ hoặc bấm **Gọi wave sớm** |
| Gọi wave sớm | Bonus gold = thời_gian_PREP_còn_lại × early_call_gold_per_sec (2), tối đa early_call_cap (40). Bonus ghi vào early_call_bonus và cộng cùng gold của wave ở SUMMARY (GLD-09) |
| Preview | Loại quân sắp tới, modifier \[Should]. Wave boss: tên boss, miễn nhiễm pha 1, boss_timer; \[Should] PNL-05 đầy đủ và cảnh báo BOSS-15 |

### 3.3.3 COMBAT

- Khóa xây, nâng, bán, sửa bằng gold. Emergency repair (Commander) vẫn dùng được.
- Chỉ huy đang Commander thì ở command_post. Đang Frontline thì giữ vị trí.
- **Kết thúc** khi spawn_queue rỗng **và** enemies_alive == 0.
- **Clear time** đo bằng game time từ lần spawn đầu đến lần diệt cuối, nên tua tốc độ không ảnh hưởng thưởng.
- par_time = spawn_duration + 15 s (wave thường). Wave boss dùng par_time_boss = 0.6 × boss_timer (BRW-04).

| **Mốc** | **Điều kiện** | **Hệ số gold (clear\_mult)** |
| --- | --- | --- |
| Fast | clear_time ≤ 0.7 × par_time | 1.25 |
| Normal | ≤ 1.3 × par_time | 1.00 |
| Slow | lớn hơn | 0.80 |

### 3.3.4 SUMMARY

- Hiển thị: quân đã diệt (theo loại), clear time và mốc, gold (gốc, hệ số, bonus gọi wave sớm, tổng), uy tín, HP Fortress, tower bị phá (kèm giá xây lại), lượt Emergency repair nhận được khi diệt boss (nếu có, BRW-07), **XP nhận (từ chỉ huy / từ tower), Cấp Chỉ huy, số lượt chọn đang chờ**.
- Áp gold và prestige_pending **ngay khi vào state**, không chờ bấm (GLD-08). Tăng waves_cleared. **Ghi save trước rồi mới hiển thị** (SAV-05).
- Tự chuyển sau **10 giây thời gian thực**, hoặc bấm Continue: nếu pending_picks > 0 thì sang REWARD_PICK, ngược lại sang PREP.
- Chỉ huy không nhận sát thương ở SUMMARY.

### 3.3.5 Edge case của wave

| **ID** | **Tình huống** | **Xử lý** |
| --- | --- | --- |
| WAVE-01 | Spawn vượt max_alive (70) | Quân dư **chờ trong spawn\_queue**, spawn tiếp khi số quân sống giảm dưới max_alive |
| WAVE-02 | Fortress sập và diệt quân cuối cùng frame | **Thua đè thắng**: kết thúc run, wave đó không tính vào waves_cleared, không cộng gold (GLD-08) |
| WAVE-03 | Quân kẹt | Theo thang xử lý kẹt NAV-01 đến NAV-09: sửa nhẹ trước, không xóa quân ngay. \[Should] NAV-07, NAV-10, NAV-11 |
| WAVE-04 | Quân rơi ngoài map | Theo NAV-04 |
| WAVE-05 | Còn quân lẻ | 60 s sau lần spawn cuối: marker định vị (EN-01). 240 s: FRENZY (EN-02). 300 s: giới hạn cứng, cull mọi quân còn lại không phải boss (NAV-13) |
| WAVE-06 | Tua x3 rồi Fortress tụt nhanh | Không tự giảm tốc (giữ quyền kiểm soát), HUD cảnh báo dưới 30% HP |
| WAVE-07 | Gọi wave sớm liên tục để bơm gold | Chỉ ở PREP, bonus theo thời gian còn lại, có trần early_call_cap. Không có gọi wave khi đang COMBAT ở MVP. PREP wave boss cũng được gọi sớm, cùng công thức và cùng trần early_call_cap: prep_time_boss dài hơn không tăng bonus, người chơi đổi thời gian chuẩn bị lấy tối đa 40 gold |
| WAVE-08 | Wave có 0 quân (lỗi bảng) | Ép tối thiểu 1 Grunt, ghi cảnh báo |
| WAVE-09 | Boss wave có Cuồng nộ | Cuồng nộ không kết thúc wave (ENR-06): wave vẫn kết thúc khi spawn_queue rỗng và enemies_alive == 0. Diệt boss sau Cuồng nộ vẫn tính hoàn thành, thưởng boss nhân enrage_reward_mult (BRW-02) |
| WAVE-10 | Pause lúc wave chuyển state | Chuyển state theo game time, không mất sự kiện |

### 3.3.6 REWARD_PICK (3 chọn 1) \[MVP]

State nằm giữa SUMMARY và PREP. Người chơi dùng hết các lượt chọn đang chờ (pending_picks, sinh ra từ lên Cấp Chỉ huy, XP-04), mỗi lượt chọn 1 trong tối đa 3 thẻ. Màn hình là SCR-17.

| **ID** | **Đặc tả** | **Tag** |
| --- | --- | --- |
| RWP-01 | Vào REWARD_PICK khi pending_picks > 0. Game dừng (không tính vào prep_time). Người chơi chọn lần lượt hết các lượt chờ, rồi vào PREP. Khi có nhiều lượt chờ, màn REWARD_PICK gọi RewardOfferGenerator tuần tự: lượt kế chỉ được sinh sau khi lượt trước đã phát reward_picked và RunSkillState đã cập nhật, không sinh trước. | MVP |
| RWP-02 | Mỗi lượt hiển thị tối đa 3 thẻ, không trùng nhau. Loại thẻ: skill chủ động, skill bị động, stat. \[Should] thẻ merge | MVP |
| RWP-03 | **Reroll**: đổi cả 3 thẻ, không tốn lượt chọn, `rerolls_left` khởi đầu 1 mỗi run (SKL-08). Hết thì nút xám | MVP |
| RWP-04 | **Bỏ qua (Skip)**: mất luôn lượt chọn đó, có xác nhận một lần ("Bỏ qua sẽ mất lượt chọn này"), không bù gold | MVP |
| RWP-05 | RNG riêng seed = hash(run_seed, "reward", số lượt đã dùng) để test và replay tái hiện được | MVP |
| RWP-06 | Pool rỗng (mọi ô đầy, mọi skill và stat max) thì bỏ qua REWARD_PICK, XP vẫn tăng, Cấp Chỉ huy vẫn tăng (vì gating FRT-03). Pool chỉ có 1-2 thẻ thì hiện đúng 1-2 thẻ. Không có thẻ gold, thẻ hồi HP | MVP |
| RWP-07 | Trọng số khởi điểm (chỉnh qua GameConfig, mục 6.3): skill đã có chưa max 40, skill mới (khi loại đó còn ô trống) 30, stat chưa đủ stat_max_stacks 20. Skill đã max không bao giờ hiện lại | MVP |
| RWP-08 | Pause trong REWARD_PICK: cho phép (game đã dừng). Esc không đóng màn (chỉ mở Pause) | MVP |
| RWP-09 | \[Should] Thẻ merge (SKL-20..22), skill hiếm ở lượt boss (BRW-03), Reroll mua thêm (REROLL_PLUS) | SHOULD |

Cài đặt: RewardOfferGenerator là hàm thuần nhận RunSkillState, danh sách SkillData và RNG, trả 3 thẻ; test bằng GUT, không đụng scene. Chọn thẻ phát `reward_picked` (EVB-29), StatBlock tính lại ngay (SKL-15).

## 3.4 Điều khiển thời gian

| **ID** | **Đặc tả** |
| --- | --- |
| TIME-01 | time_scale có ba mức x1, x2, x3, chọn bằng **nút trên HUD** (TIME-09, HUD-14), không có phím tắt. Pause là trạng thái riêng, không phải time_scale = 0 |
| TIME-02 | Pause được ở mọi state của Run (PREP, COMBAT, BOSS_INTRO, BOSS_COMBAT, SUMMARY, REWARD_PICK). Khi pause mọi timer gameplay dừng, UI vẫn chạy. Bộ đếm tự chuyển 10 s của SUMMARY (thời gian thực) cũng dừng khi Pause |
| TIME-03 | Mức tốc độ chọn được giữ từ PREP sang COMBAT của cùng wave. **Tự về x1** (các nút tua về trạng thái tắt) khi vào BOSS_INTRO và khi vào SUMMARY. Từ SUMMARY, REWARD_PICK sang PREP kế tiếp mức luôn x1 và các nút tua tắt, không khôi phục mức người chơi đã chọn ở wave trước (HUD-14). **Không còn khóa x1 theo đồng hồ boss**: BOSS_COMBAT cho tua x2/x3 bình thường |
| TIME-04 | Tween, Timer, particle, animation gameplay chạy theo time_scale. Animation UI bỏ qua time scale |
| TIME-05 | **Âm thanh không đổi tốc độ và pitch** khi tua. Giảm tải bằng giới hạn tần suất SFX (AUD-01, AUD-03) |
| TIME-06 | Giới hạn max_physics_steps_per_frame (Project Setting của Godot, mặc định 8, mục 6.3). FPS dưới 30 liên tục 3 s ở x3 thì tự hạ về x2 kèm thông báo (ALR-10). Hạ time scale trước khi đụng tới logic AI hay tần suất quét |
| TIME-07 | Cooldown kỹ năng, cooldown đổi chế độ, đồng hồ boss, clear time đều tính bằng game time |
| TIME-08 | Không dùng Pause để né cooldown hay tối ưu quyết định. Ở COMBAT và BOSS_COMBAT, khi Pause mọi panel chỉ đọc: không đổi priority, không Emergency repair, không đổi chế độ, không dùng skill. PREP không bị giới hạn |
| TIME-09 | **Nút tua nhanh:** tua chỉ điều khiển bằng cụm nút HUD (HUD-14), gọi set_time_scale(1\|2\|3). Bấm nút mức đang tắt thì bật mức đó, bấm lại đúng nút đang bật thì tắt (về x1). Hiển thị luôn theo time_scale thực, kể cả khi bị hạ tự động (TIME-06). Không đổi mức tốc độ khi đang Pause |
| TIME-10 \[MVP] | **Ba loại đồng hồ** do TimeManager cung cấp: (a) **game time**, đã nhân time_scale và dừng khi Pause, cho mọi timer gameplay (TIME-07, CHAR-05); (b) **thời gian thực có thể pause** (không nhân time_scale, dừng khi Pause), cho bộ đếm 10 s của SUMMARY (TIME-02), đếm BOSS_INTRO, hoàn tác bán 3 s \[Should] (PNL-10); (c) **thời gian thực thuần**, không dừng khi Pause, cho animation UI, chuyển camera 0.5 s (MSE-08), retarget_delay 0.3 s (CMD-01), crossfade nhạc. Mọi timer mới phải khai báo thuộc loại nào |
| TIME-11 \[MVP] | **Pause theo tập lý do:** TimeManager giữ tập `pause_requests` với các lý do `USER` (Esc, nút Pause, mất focus cửa sổ vì INP-08 mở menu Pause) và `REWARD_PICK` (RWP-01). `is_paused = pause_requests không rỗng`. Thêm hoặc bỏ một lý do không ảnh hưởng lý do khác (Esc trong REWARD_PICK thêm `USER`, bỏ `USER` thì game vẫn dừng vì còn `REWARD_PICK`). `pause_changed` (EVB-19) chỉ phát khi `is_paused` thực sự đổi. Lấy lại focus không tự bỏ `USER` (INP-08). Đổi time_scale khi đang Pause bị từ chối (TIME-09) |
Kiểm tra mọi hệ thống (projectile, DoT, đồng hồ boss) đúng ở x1/x2/x3 là hạng mục nghiệm thu bắt buộc của tuần 6.

## 3.5 Nhân vật chỉ huy

Chỉ huy là **một thực thể duy nhất** với hai chế độ. Camera, HP và hệ thống damage dùng chung, chỉ khác input map, UI và luật nhận sát thương.

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
| prep_heal_pct | 60% | Hồi khi vào PREP |
| commander_regen_pct_per_sec | 2% | Chỉ ở Commander mode, hồi liên tục (chỉ huy không nhận sát thương ở chế độ này) |
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

Mọi chỉ số chỉ huy đọc qua StatBlock (add, mul). Skill bị động và thẻ stat ghi vào StatBlock, không sửa CharacterStats (SKL-15).

### 3.5.2 State machine

Frontline:  Idle <-> Move -> Attack(combo 1-2-3) -> Idle\
Move/Idle -> Dodge -> Idle\
Move/Idle -> Skill -> Idle\
Any -> Stunned -> Idle\
Idle/Move -> Recalling -> Arriving -> Commanding\
Commander:  Commanding -> Deploying -> Idle (Frontline)\
Any -> Dead

| **State** | **Cho phép** | **Ngắt bởi** |
| --- | --- | --- |
| Idle, Move | Mọi hành động Frontline |  |
| Attack | Đòn kế trong cửa sổ combo 0.35 s. Dodge hủy được recovery. | Stun |
| Dodge | Bất tử dodge_iframe, xuyên qua quân địch | Không ngắt được |
| Skill | Battle Cry: animation 0.5 s, khóa di chuyển. **Skill chủ động (SKL-xx): theo từng skill, mặc định hủy được recovery đòn kiếm như Dodge, không khóa di chuyển** | Stun (mất cooldown) |
| Stunned | Không hành động | Hết thời gian |
| Recalling | Đứng yên, channel về thành | Nhận sát thương, di chuyển, Dodge |
| Deploying | Bất tử 0.6 s, không tấn công | Không ngắt được |
| Commanding | Các lệnh Commander. **Bất khả xâm phạm** (CMD-10) | Chuyển chế độ |

### 3.5.3 Frontline

- **Di chuyển:** WASD theo trục màn hình, chuẩn hóa vector chéo.
- **Aim:** chuột, raycast xuống mặt phẳng ngang tại độ cao chân chỉ huy (MSE-01). Ray không trúng thì giữ hướng cũ.
- **Đánh thường:** combo 3 đòn, đòn 3 có knockback nhẹ 1.5 m (Brute và boss miễn). Nối đòn theo CHAR-07: không bấm trong combo_window thì combo về đòn 1. Mỗi đòn trúng tối đa sword_max_targets mục tiêu (CMB-09).
- **Dodge:** theo hướng di chuyển. Đứng yên thì lùi về sau hướng aim.
- **Battle Cry (Q):** taunt mọi quân trong bán kính 6 m trong 4 s, chỉ huy nhận -30% sát thương trong thời gian đó. Cooldown 12 s. Đây là công cụ tank và kéo aggro.

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
- Camera vẫn là một Camera3D, chuyển sang khung overview (MSE-08).
- **Bất khả xâm phạm:** damage_taken = 0. Ở Commander mode chỉ huy không nhận sát thương và không thể bị nhắm bởi bất kỳ nguồn nào, kể cả AoE và đạn đang bay (CMD-10).
- command_post cách slot gần nhất (kể cả ô grid) tối thiểu 3 m (BOSS-08, GRID-03).

| **ID** | **Lệnh và luật** |
| --- | --- |
| CMD-01 | Chỉnh target priority. **\[MVP] 2 lựa chọn: First, Nearest.** \[Should] Highest HP, Lowest HP, Flying, Boss và nút "Áp dụng cho mọi tower cùng loại". retarget_delay 0.3 s. Chỉ đổi được ở Commander mode và theo thời gian thực, không đổi được khi Pause (CMD-04) |
| CMD-02 | **Emergency repair (R):** hồi emg_repair_heal_pct (20% + 3% × cấp EMG_REPAIR, tối đa 29%) của fortress_max_hp, miễn phí gold, chỉ ở Commander mode. **Giới hạn 3 lượt trong cả run** (emg_repair_charges, khởi đầu 3/3). Mỗi lần dùng tốn 1 lượt và bắt đầu cooldown emergency_repair_cooldown = **60 s** game time giữa hai lần dùng. Cooldown chạy xuyên wave, không giảm được bằng meta hay relic. Hết lượt (0/3) thì không dùng được dù cooldown đã về 0. **Lượt được cộng lại theo BRW-07 (+1 khi diệt boss)** |
| CMD-03 | \[Could] Skill tower, spell scroll, tối đa 1 spell |
| CMD-04 | Ở COMBAT và BOSS_COMBAT, đổi priority chỉ thực hiện được khi game chạy, chịu retarget_delay 0.3 s. Panel mở khi Pause thì chỉ đọc (TIME-08, PNL-12). \[MVP] 2 priority |
| CMD-05 | Trong PREP, panel đổi target, xây dựng và sửa Fortress dùng được ở **cả hai chế độ** |
| CMD-06 | Tower bị phá thì priority của slot reset mặc định khi xây lại |
| CMD-07 | Emergency repair khi Fortress đầy HP: từ chối, **không tốn lượt, không tốn cooldown** |
| CMD-08 | Dùng khi Fortress chỉ thiếu ít hơn lượng hồi (nhưng chưa đầy): vẫn tốn 1 lượt và cooldown, HP kẹp ở max (FORT-03). HUD hiện tooltip "Hồi thừa" khi Fortress thiếu dưới 10% |
| CMD-09 | Điều kiện dùng Emergency repair: đang Commander mode, emg_repair_charges > 0, emg_repair_cd = 0, Fortress chưa đầy HP, không Pause (TIME-08). Thiếu điều kiện nào thì từ chối và HUD báo đúng lý do (HUD-13) |
| CMD-10 | **Bất khả xâm phạm ở Commander mode:** từ frame vào Arriving đến hết Commanding, chỉ huy không thể bị nhắm và không nhận sát thương từ **bất kỳ nguồn nào** (đạn, AoE, telegraph). Đạn và vùng nổ đang tác dụng lên vị trí chỉ huy bị vô hiệu, không gây knockback hay hiệu ứng trạng thái. **Cái giá của chế độ này (v1.8): không gây sát thương, XP từ tower chỉ 50% (XP-02), không có Aura (FRT-01), không có gold chỉ huy (FRT-02), không dùng được skill chủ động (SKL-06), không được bonus clear time do chỉ huy đánh.** Rủi ro khi chuyển chế độ nằm ở Recall (channel) và Deploy |

### 3.5.5 Chuyển chế độ

Chuyển chế độ **không được là nút thoát hiểm tức thì**.

| **Hướng** | **Luật** |
| --- | --- |
| **Commander sang Frontline (Deploy)** | Tab. Hạ xuống deploy_point ở cổng thành, bất tử 0.6 s, không tấn công. Sinh **shockwave đẩy lùi** (không sát thương) quanh điểm hạ (deploy_shockwave_radius 3 m, đẩy lùi deploy_shockwave_distance 2 m, gây STAGGER theo AI-04, Brute và boss miễn) |
| **Frontline sang Commander (Recall)** | Tab. Trong return_zone (bán kính 5 m quanh cổng): channel 0.6 s. Ngoài: 3 s. Bị đánh, di chuyển hoặc Dodge thì **hủy**, không tốn cooldown |
| Cooldown | mode_switch_cooldown 5 s sau khi **hoàn tất** một lần chuyển |
| PREP | Chuyển tự do |
| BOSS_INTRO | Khóa chuyển chế độ |

| **ID** | **Tình huống** | **Xử lý** |
| --- | --- | --- |
| MODE-01 | Bấm Tab khi bị đánh để né damage | Recall hủy khi nhận sát thương. Không có khung bất tử đầu Recall |
| MODE-02 | deploy_point bị quân chiếm | Thuật toán xác định (không ngẫu nhiên): (1) deploy_point không có quân địch trong deploy_clear_radius 0.8 m thì dùng ngay. (2) Ngược lại duyệt ứng viên trên các vòng bán kính 1, 2, 3, 4 m (deploy_point_search_radius) quanh deploy_point, mỗi vòng 8 hướng cách đều bắt đầu từ hướng về Fortress, xoay theo chiều kim đồng hồ. Mỗi ứng viên chiếu lên navmesh, hợp lệ khi không có quân địch trong deploy_clear_radius, không trong spawn_zone, không trong collider tower, Barricade, tường. Chọn ứng viên hợp lệ đầu tiên theo thứ tự vòng nhỏ trước. (3) Không có thì dùng deploy_point mặc định kèm shockwave đẩy lùi; bất tử 0.6 s vẫn áp dụng |
| MODE-03 | Bấm Tab trong cooldown | HUD hiện cooldown, không xếp hàng lệnh |
| MODE-04 | Đang Attack hoặc Skill mà bấm Tab | Bỏ qua, không hủy đòn |
| MODE-05 | Hoàn tất Recall đúng lúc có sát thương chưa xử lý | Trước frame chuyển tính theo Frontline. Từ frame Arriving chỉ huy **bất khả xâm phạm**, mọi sát thương và đạn chưa xử lý bị hủy (CMD-10) |
| MODE-06 | Chuyển chế độ khi wave chuyển sang SUMMARY | Hoàn tất bình thường |
| MODE-07 | Recall thành công | Mọi quân đang nhắm chỉ huy reset về bảng ưu tiên gốc |
| MODE-08 | \[ĐÃ XÓA v1.8] | Retreat không còn |

### 3.5.6 Aggro

| **ID** | **Đặc tả** |
| --- | --- |
| AGG-01 | Quân bị chỉ huy đánh trúng có provoked_by_player = true trong aggro_duration 4 s (làm mới mỗi lần trúng). Trong thời gian đó ưu tiên chỉ huy nếu trong aggro_range |
| AGG-02 | Battle Cry ép mọi quân trong 6 m nhắm chỉ huy 4 s. **Boss miễn taunt**, chỉ chịu AGG-01 |
| AGG-03 | Chỉ huy ở Commander không là mục tiêu của bất kỳ quân nào (kể cả Archer và boss tầm xa). Cờ provoked_by_player xóa khi Recall hoàn tất |
| AGG-04 | Quân tầm xa theo bảng ưu tiên. Chỉ huy Frontline trong tầm bắn bị nhắm, đó là rủi ro chủ đích |
| AGG-05 | Chỉ huy chạy xa quá leash_distance 25 m: quân về bảng ưu tiên gốc |
| AGG-06 | Tối đa max_aggro_melee 8 quân cận chiến cùng đánh chỉ huy. Dư đứng vòng ngoài |

### 3.5.7 Sát thương, hồi máu, hiệu ứng

damage_taken = raw × (1 - min(armor_pct, 0.75)) × skill_mult

Ở Commander mode chỉ huy không nhận sát thương từ bất kỳ nguồn nào (damage_taken = 0, CMD-10). skill_mult 0.7 khi Battle Cry. Làm tròn lên, tối thiểu 1 nếu raw > 0 (áp dụng khi Frontline). Sát thương TRUE (chỉ cú rơi khỏi map ở v1.8) bỏ qua armor, skill_mult và i-frame của chỉ huy Frontline (DMG-05).

| **Nguồn hồi** | **Luật** |
| --- | --- |
| Đầu PREP | prep_heal_pct × commander_max_hp, không vượt max |
| Regen Commander | 2%/s liên tục khi ở Commander mode |
| Lifesteal, thẻ Thể lực | Từ REWARD_PICK (SKL-13, mục 3.5.12.3). Không có thẻ hồi HP trực tiếp (RWP-06) |
| Frontline | Không có regen tự nhiên |

**Hiệu ứng trạng thái** (từ Debuffer, boss; \[Should]): Slow (-40% tốc độ, tối đa 3 s), Stun (tối đa 1.5 s rồi **miễn stun 3 s**), Weaken (-25% sát thương gây ra, tối đa 5 s). Không cộng dồn, chỉ làm mới. Dodge không xóa hiệu ứng.

### 3.5.8 Chết và trạng thái đặc biệt

| **ID** | **Tình huống** | **Xử lý** |
| --- | --- | --- |
| DEAD-01 | commander_hp <= 0 **ở Frontline** (Commander mode miễn nhiễm, CMD-10, DEAD-09) | Chuyển RunEnd COMMANDER_DIED qua DEAD-10. Không hồi sinh ở MVP |
| DEAD-02 | Hai sát thương chí mạng cùng frame | Xử lý cái đầu, cờ is_dead chặn lần hai |
| DEAD-03 | Chết khi Recall, Stunned | Như DEAD-01. Deploying bất tử nên không chết được |
| DEAD-04 | \[ĐÃ XÓA v1.8] | Overload không còn |
| DEAD-05 | Chết trong PREP hoặc SUMMARY | Không xảy ra |
| DEAD-06 | Rơi khỏi map, kẹt địa hình | Dịch về deploy_point, chịu 15% commander_max_hp (TRUE), **HP tối thiểu 1**, ghi log |
| DEAD-07 | HP dưới 25% | Viền đỏ, nhịp tim, giảm nhạc nền. Không đổi cơ chế |
| DEAD-08 | \[Could] Last Stand | Chỉ nếu có tài nguyên, làm mục meta shop |
| DEAD-09 | Chỉ huy ở Commander mode | Không thể chết: mọi nguồn sát thương bị vô hiệu (CMD-10). Run chỉ kết thúc qua Fortress sập hoặc Abandon khi ở chế độ này |
| DEAD-10 \[MVP] | Phát tín hiệu chết | Chỉ huy phát `commander_died(cause)` (EVB-10) **đúng một lần** mỗi run, chặn bằng cờ is_dead (DEAD-02); cờ chỉ xóa khi bắt đầu run mới. `cause` ở MVP chỉ có `ENEMY_DAMAGE` (cú rơi khỏi map không giết được, DEAD-06). Tín hiệu `commander_died` không phải end_type: end_type COMMANDER_DIED do RunState ghi vào `run_ended` theo END-01 |

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
| CHAR-08 \[MVP] | Quy tắc buffer | (a) Chỉ buffer `dodge`, `skill_1..3`, `attack`. **Không buffer `mode_switch`** (MODE-03, MODE-04). (b) Chỉ 1 ô. Lệnh mới ghi đè lệnh trong ô khi ưu tiên cao hơn hoặc bằng (Dodge > Skill > Attack, INP-02), thấp hơn thì bỏ. (c) Cửa sổ 0.15 s đo ngược từ thời điểm state hiện tại cho phép hành động kế: hết attack_interval với Attack, hết state Dodge với Dodge, hết skill_animation_time với Skill. (d) Chạy lệnh trong buffer ngay khi state cho phép. Hết hạn thì bỏ. (e) Xóa buffer khi đổi ngữ cảnh, Pause hoặc mất focus (INP-07, INP-08), vào Stunned, Recalling, Dead. (f) Theo game time (CHAR-05): ở x3, 0.15 s game time bằng 50 ms thời gian thực, đây là chủ đích |

### 3.5.10 Vòng lặp Frontline \[MVP]

Mục tiêu: Commander vẫn an toàn và vẫn thắng được, nhưng **chậm hơn, nghèo hơn và yếu hơn** Frontline. Người chơi ra Frontline vì muốn mạnh, không vì bị ép.

| **ID** | **Đặc tả** | **Tag** |
| --- | --- | --- |
| FRT-01 | **Aura Tiền tuyến.** Khi chỉ huy ở **Frontline** (kể cả đang Dodge, không áp khi Stunned, Recalling, Deploying), mọi tower (WALL, ô grid) trong frontline_aura_radius (12 m) quanh chỉ huy có dealt_mult cộng thêm frontline_aura_dmg_bonus (+0.20), cộng dồn với các khoản dealt_mult khác theo DMG-06. Quét mỗi scan_interval (0.2 s, lệch pha), tower chỉ đọc cờ `aura_active`. Hiển thị vòng sáng quanh chỉ huy và biểu tượng nhỏ trên tower nhận. Tower Barricade không tấn công nên không hưởng | MVP |
| FRT-02 | **Gold chỉ huy.** Quân chết có hit_by_commander = true cộng vào wave_gold_base với hệ số frontline_gold_mult (1.25) trên gold_reward(w). Quân không có cờ thì 1.0. Hệ số này nằm **trong** wave_gold_base nên chịu gold_pct_total và clear_mult như mọi khoản gold từ quân (mục 3.9.1). Không áp lên boss_gold. Số nổi gold hiển thị đã gồm hệ số, kèm biểu tượng kiếm | MVP |
| FRT-03 | **Giới hạn cấp tower theo Cấp Chỉ huy.** Nâng tower lên cấp 2 cần commander_level >= tower_gate_lv2 (4); lên cấp 3 cần commander_level >= tower_gate_lv3 (8). Xây mới luôn cấp 1. Xây lại (BLD-07) không bị chặn vì commander_level không giảm. Nút Nâng cấp xám kèm "Cần Chỉ huy cấp N" (UPG-06). Ước lượng: người chơi chủ động đạt cấp 4 ở khoảng wave 4, cấp 8 ở khoảng wave 8; người đứng yên chỉ nhận 50% XP nên chậm khoảng 1,6 đến 2 lần | MVP |
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
| XP-01 | xp_value theo loại (EnemyData): Grunt 1, Archer 2, Brute 5, boss 30, Bat 2 \[Should]. XP là điểm kinh nghiệm trong run, không phải tiền tệ, không mua bán được. Game vẫn đúng hai loại tiền (gold, danh vọng) | MVP |
| XP-02 | Bảng hệ số ở trên. XP lẻ cộng dồn dạng số thực, thanh XP hiển thị làm tròn xuống | MVP |
| XP-03 | Cờ hit_by_commander bật ở lần đầu chỉ huy gây ≥ 1 điểm sát thương thật (kiếm hoặc skill, gồm tick vùng cháy). Battle Cry (taunt) và shockwave Deploy không gây sát thương nên không tính. Cờ thuộc về quân, không mất khi recycle (NAV-08) | MVP |
| XP-04 | Chỉ huy bắt đầu run ở **cấp 0**. XP cần để lên cấp n (n ≥ 1): xp_to_level(n) = xp_base + xp_step × (n − 1) = 5 + 4 × (n − 1). XP dư chuyển sang cấp kế. Mỗi lần lên cấp: commander_level += 1, pending_picks += 1, phát level_up. Một wave lên nhiều cấp thì nhiều lượt chọn. RunState.xp là XP trong cấp hiện tại (reset về phần dư khi lên cấp), to_next = xp_to_level(commander_level + 1). Tổng tích lũy chỉ dùng để cân bằng và test, không lưu. | MVP |
| XP-05 | Thanh XP và số lượt chờ hiển thị ở HUD trong COMBAT (HUD-15) nhưng **không dừng trận**. Chọn ở REWARD_PICK (RWP-01). Đã max hết skill và stat: XP và cấp vẫn tăng (vẫn mở khóa nâng cấp tower), không có lượt chọn mới | MVP |

Cân bằng thô: XP tích lũy để đạt cấp n là 2n² + 3n (cấp 4 = 44, cấp 8 = 152, cấp 10 = 230). Tổng ngân sách quân đến wave 10 khoảng 194, cộng boss (30 mỗi boss) khoảng 60, tức khoảng 254 XP nếu 100%, tương ứng cấp 10. Người chỉ để tower giết nhận khoảng một nửa nên chạm cấp 8 ở khoảng wave 11-12. **Mục tiêu playtest:** người chơi chủ động chạm cấp 4 ở wave 4 ± 1 và cấp 8 ở wave 8 ± 1.

### 3.5.12 Skill của chỉ huy \[MVP]

| **ID** | **Đặc tả** | **Tag** |
| --- | --- | --- |
| SKL-01 | Hai nhóm ô: **3 ô chủ động** (phím 1, 2, 3) và **3 ô bị động**, trống khi bắt đầu run. Skill nền (đòn kiếm, Dodge, Battle Cry Q, Recall/Deploy, Emergency repair R) không chiếm ô | MVP |
| SKL-02 | Skill có level 1 đến `skill_max_level` = **3** ở MVP (\[Should] 5). Chọn lại thẻ đã có thì lên level. Max thì không xuất hiện lại | MVP |
| SKL-03 | Skill mới vào ô trống có số nhỏ nhất. Ô không dồn lại khi một ô trống (MVP không có xóa skill) | MVP |
| SKL-04 | Pool MVP: **chủ động** Whirlwind, Sword Wave, Firebomb. **Bị động** Sharpness, Lightstep, Armored, Lifesteal, Focus. **Stat** Thể lực, Tinh thông, Bền thành, mỗi stat tối đa `stat_max_stacks` = 3. Số liệu ở bảng 3.5.12.1 đến 3.5.12.3 | MVP |
| SKL-05 | Skill chủ động bấm tay, nhắm theo vị trí chuột (có hướng), cooldown theo game time (CHAR-05), phím vật lý (INP-09). Nhiều phím cùng frame: Dodge > Skill > Attack > Mode switch, nhiều skill cùng frame thì ô số nhỏ trước (INP-02) | MVP |
| SKL-06 | Skill chủ động **chỉ chạy ở Frontline**. Ở Commander mode phím 1-3 không làm gì, HUD xám. Không dùng được khi Stunned; khi Recalling thì bấm skill hủy Recall như di chuyển | MVP |
| SKL-07 | Skill bị động liên quan chỉ huy chỉ có tác dụng ở Frontline (đa số tính theo hành động chiến đấu). Lifesteal hồi theo kill bằng kiếm hoặc skill | MVP |
| SKL-08 | Reroll khởi đầu 1 lần mỗi run (RWP-03). \[Should] mua thêm bằng danh vọng (REROLL_PLUS) | MVP / SHOULD |
| SKL-09 | Skill chủ động nhân sát thương theo DMG-06 và kháng boss theo DMG-01 như mọi nguồn khác. Cấm skill nào đổi số lượt hay cooldown Emergency repair (APL-04), đổi CMD-10 hay làm chỉ huy bị đánh ở Commander mode | MVP |
| SKL-10 | **Whirlwind** (chủ động, SLASH): xoay 1 vòng quanh người, trúng mọi quân trong bán kính. Số liệu bảng 3.5.12.1 | MVP |
| SKL-11 | **Sword Wave** (chủ động, SLASH): kiếm khí lưỡi liềm bay thẳng về phía chuột, trúng mọi quân trên đường bay | MVP |
| SKL-12 | **Firebomb** (chủ động, BLAST): ném tới vị trí chuột, vùng cháy gây sát thương theo tick mỗi giây. Dùng BLAST để tái dùng bảng kháng boss hiện có | MVP |
| SKL-13 | Bị động Sharpness, Lightstep, Focus, Lifesteal. Số liệu bảng 3.5.12.2 | MVP |
| SKL-14 | Bị động Armored: +5% armor_pct mỗi level (L3 = 15%), vào trần 75% (APL-03). Là nguồn armor duy nhất ở MVP | MVP |
| SKL-15 | Mọi bị động và stat ghi vào StatBlock theo add và mul, tính lại khi `reward_picked`. Không sửa trực tiếp CharacterStats hay TowerData. Riêng thẻ Thể lực và Bền thành tăng commander_max_hp và fortress_max_hp hiệu dụng trong RunState (không sửa RunConfig): cộng phẳng theo giá trị gốc của RunConfig (không lãi kép), làm tròn xuống, hồi đúng lượng vừa tăng, xử lý một lần khi phát reward_picked (EVB-29). | MVP |
| SKL-20 | **Merge:** hai skill cùng đạt level tối đa là nguyên liệu, cả hai biến mất, skill merge vào ô nguyên liệu chủ động (số nhỏ nếu cùng loại), vào ở level 1. Một thẻ trong lượt chọn chắc chắn là merge khi có công thức đủ điều kiện. Công thức đầu tiên: Cyclone (Whirlwind + Lightstep), Inferno (Firebomb + Focus) | SHOULD |
| SKL-21 | Panel gợi ý công thức ở thẻ (icon + "Cần cả hai max") | SHOULD |
| SKL-22 | Skill merge không làm nguyên liệu tiếp | SHOULD |
| SKL-23 | Kéo thả đổi ô (PREP, REWARD_PICK, Pause trong PREP), hoán đổi hoặc chuyển ô trống | SHOULD |
| SKL-24 | Mở ô thứ 4, 5 (SLOT_ACTIVE, SLOT_PASSIVE) và mở skill vào pool bằng danh vọng, level tối đa 5, thêm Sword Throw (Disarmed), War Horn, Arrow Rain | SHOULD |
| SKL-25 | Xóa skill | COULD |

**3.5.12.1 Skill chủ động \[MVP]** (số liệu khởi điểm, chỉnh trong SkillData)

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
| Lightstep | +5% tốc chạy, −0.1 s cooldown Dodge | +15%, −0.3 s | Dodge cooldown gốc 1.5 s |
| Armored | +5% armor chỉ huy | 15% | Nguồn armor duy nhất ở MVP, trần 75% (APL-03) |
| Lifesteal | Mỗi quân bị diệt bằng kiếm hoặc skill hồi 0.5% commander_max_hp | 1.5% | Frontline vốn không regen |
| Focus | −6% cooldown mọi skill chủ động | −18% | |

**3.5.12.3 Thẻ stat \[MVP]** (tối đa `stat_max_stacks` = 3 lần mỗi loại)

| **Thẻ** | **Tác dụng mỗi lần** |
| --- | --- |
| Thể lực | +10 HP tối đa chỉ huy (cộng phẳng, hồi cùng lượng) |
| Tinh thông | +5% sát thương skill chủ động |
| Bền thành | +4% fortress_max_hp gốc của RunConfig (làm tròn xuống), hồi đúng lượng tăng |

Ước tính nhịp: kỷ lục dự kiến 10-20 wave tương ứng cấp 10-20, tức 10-20 lượt chọn. Tổng 3 chủ động × 3 + 3 bị động × 3 + 3 stat × 3 = 27 lượt để bão hòa mọi thứ (vượt xa một run), nên người chơi giỏi bão hòa được các skill mình chọn, người chơi mới thấy được một "build".

## 3.6 Fortress, Build slot, Grid và Tower

### 3.6.1 Fortress

Thực thể duy nhất, cố định, không xây, không bán, không di chuyển. HP là HP chung của cả run.

| **Tham số** | **Giá trị** | **Ghi chú** |
| --- | --- | --- |
| fortress_max_hp | 1000 | Cộng meta FORT_HP (+5% mỗi cấp). Giá sửa tính theo % nên không tăng theo cấp này (REP-01) |
| fortress_armor_pct | 0% | Luôn 0% ở MVP. Trần 60% chỉ dự phòng cho nâng cấp thành \[Could] |
| fortress_melee_slots | 12 | Vị trí quân cận chiến đánh cùng lúc |
| repair_gold_per_pct | 4 | Gold cho mỗi 1% fortress_max_hp thiếu. Sửa bằng gold, chỉ PREP. Giá không phụ thuộc cấp FORT_HP |
| low_hp_warning_pct | 30% | Cảnh báo HUD |

fortress_damage = raw × (1 - fortress_armor_pct) × ward_mult, làm tròn lên một lần ở cuối, tối thiểu 1 (trừ TRUE). ward_mult = 0.75 khi BUFF_WARD \[Should] đang hoạt động, ngược lại 1. BUFF_WARD là hệ số giảm sát thương độc lập, không cộng vào fortress_armor_pct nên không chịu trần APL-03. Grunt, Brute đứng ở melee_slot dọc tường. Archer bắn Fortress khi không còn mục tiêu ưu tiên. Boss đánh thường (kể cả khi Cuồng nộ, ENR-02).

| **ID** | **Sửa chữa** |
| --- | --- |
| REP-01 | Sửa bằng gold, chỉ PREP: +10%, +25%, đầy HP. Chi phí = missing_pct × repair_gold_per_pct, làm tròn lên một lần ở cuối (GLD-07). missing_pct = (fortress_max_hp - fortress_hp) / fortress_max_hp × 100 là số thực, không làm tròn trước khi nhân (ví dụ max 1050, HP 1033: thiếu 1.619%, chi phí ceil(6.476) = 7 gold). Nút +10% và +25% hồi min(10 hoặc 25, missing_pct)% máu tối đa và tính giá theo phần thực sự hồi. HP hồi được làm tròn xuống thành số nguyên, riêng nút đầy HP đặt đúng fortress_max_hp. Chi phí không phụ thuộc fortress_max_hp. Không đủ gold cho cả bước thì sửa floor(gold / repair_gold_per_pct)% máu tối đa, làm tròn xuống theo từng 1%; phần thiếu còn dưới 1% thì sửa hết nếu đủ gold theo công thức chi phí |
| REP-02 | **Emergency repair** theo CMD-02 |
| REP-03 | Không có regen tự nhiên ở MVP |
| REP-04 | Đầy HP: từ chối, không trừ gold |
| REP-05 | Không sửa bằng gold trong COMBAT |
| REP-06 | fortress_max_hp hiệu dụng chỉ đổi khi chọn thẻ Bền thành ở REWARD_PICK (SKL-15), không đổi trong wave, và giá trị gốc ở RunConfig cố định (APL-01) nên giá sửa chỉ phụ thuộc missing_pct, không đổi giữa các cấp FORT_HP khi cùng tỷ lệ thiếu. Đổi cấp FORT_HP ở Meta shop chỉ có hiệu lực từ Run sau (FORT-04) |

| **ID** | **Edge case Fortress** | **Xử lý** |
| --- | --- | --- |
| FORT-01 | Quá 12 quân muốn đánh | Dư đứng hàng chờ, quay sang mục tiêu khác nếu có |
| FORT-02 | Nhiều sát thương làm HP dưới 0 cùng frame | Chốt fortress_hp = 0 một lần, phát fortress_destroyed một lần |
| FORT-03 | Sát thương âm hoặc hồi vượt max | Kẹp trong \[0, fortress_max_hp] |
| FORT-04 | Meta FORT_HP giữa hai run | Áp khi RunLoading, HP khởi đầu luôn đầy |
| FORT-05 | Fortress bị đánh ở PREP, SUMMARY | Không xảy ra |
| FORT-06 | SUMMARY khi Fortress dưới 30% | Giữ cảnh báo HUD, gợi ý "Sửa Fortress" ở PREP kế |

### 3.6.2 Build slot và Grid

Vị trí xây gồm hai loại, đều là **slot** theo nghĩa của các luật SLOT bên dưới:

- **Slot WALL** (W1-W6): Marker3D đặt tay trên tường Fortress với slot_id, zone, allowed_types, position, facing. Giữ nguyên như v1.6.
- **Ô grid (zone GROUND)**: mặt đất hai bên lane_curve được chia thành ô vuông grid_cell_size. Lúc nạp level, GroundGrid đọc Resource GridData và **sinh sẵn một slot cho mỗi ô hợp lệ** (cùng scene slot với WALL), gán slot_id = cell_id, zone GROUND, position = tâm ô, facing hướng về phía spawn, allowed_types để trống (theo zone). Sau bước này mỗi ô là một slot bình thường: có trạng thái, bấm được, nhận tower, bị phá, xây lại như slot WALL.

Tổng công trình tối đa vẫn là **14**: 6 slot WALL cộng tối đa max_ground_buildings (8) công trình trên grid, nên cân bằng gold (mục 3.9.1) và ngưỡng đo hiệu năng (ACP-01, TWR-15) giữ nguyên.

| **Zone** | **ID** | **Số vị trí** | **Loại cho phép (MVP)** | **Ghi chú** |
| --- | --- | --- | --- | --- |
| WALL | W1-W6 | 6 slot | Arrow, Cannon | Trên tường Fortress, an toàn với quân cận chiến |
| GROUND | Ô grid G_c_r | Theo GridData, tối đa 8 công trình (max_ground_buildings) | Arrow, Cannon, Barricade | Mặt đất hai bên lane, từ trước cổng tới trước spawn_zone. Gộp NEAR và FAR của v1.6 |

Barricade không đặt được ở WALL. Bẫy \[Should] dùng ô grid, chiếm một ô. Nếu sau này cần luật riêng cho một phần mặt đất (ví dụ tower chỉ đặt được phía xa), thêm trường zone cho từng ô trong GridData, không đổi cell_id.

**Bố cục grid của mỗi map do Level khai báo trong GridData** (số hàng, số cột, số ô). SRS không chốt số ô: các luật không phụ thuộc số ô, bố cục chỉ cần thỏa GRID-03 và có đủ 4 ô tham chiếu bên dưới (đổi tên hay bỏ ô tham chiếu thì sửa STARTER_KIT và StartPack theo). Đổi map thì sửa GridData.

| **Tham số** | **Giá trị** | **Ghi chú** |
| --- | --- | --- |
| grid_cell_size | Theo GameConfig (mục 6.3), khởi điểm 2 m | Mỗi công trình chiếm đúng 1 ô |
| no_build_lane | Dải dọc lane_curve không có ô, rộng ≥ no_build_lane_min_width (4 m) và ≥ no_build_lane_min_ratio (30%) bề rộng hành lang | GRID-03, SLOT-03 |
| Hàng, cột | Theo GridData. Cột đánh số từ phía cổng (cột 0 sát cổng nhất), hàng đánh số theo chiều ngang hành lang | Chỉ số dùng trong cell_id (GRID-01) |
| max_ground_buildings | Theo GameConfig (mục 6.3), khởi điểm 8 | Trần cố định suốt run. Ô RUINED cũng chiếm chỗ (GRID-04) |

**Ô tham chiếu** (dùng cho STARTER_KIT và StartPack, đều \[Should]; thay N1-N4 của v1.6): G_0_1, G_0_2 (cột sát cổng, hai ô giáp no_build_lane ở hai bên lane), G_1_1, G_1_2 (cột kế tiếp, cùng hai hàng đó).

| **ID** | **Luật** |
| --- | --- |
| SLOT-01 | Mỗi slot (slot WALL hoặc ô grid) chứa tối đa 1 công trình. Trạng thái: EMPTY, OCCUPIED, RUINED. Slot RUINED nhớ ruined_type và ruined_level của tower vừa mất (SLOT-08) |
| SLOT-02 | RUINED hoạt động như trống (xây được ở PREP) nhưng hiện đống đổ nát, có collision và obstacle, và còn nhớ loại, cấp của tower đã mất (SLOT-08). Ô grid RUINED vẫn chiếm 1 chỗ trong trần max_ground_buildings (GRID-04) cho tới khi được xây lên hoặc dọn (CLR-01) |
| SLOT-03 | Dù đặt đủ max_ground_buildings Barricade trên các ô sát no_build_lane, hành lang vẫn còn **làn thông thoáng tối thiểu 4 m** (và ít nhất 30% chiều rộng). Làn này được bảo đảm bằng dữ liệu: GridData không có ô nào trong no_build_lane (GRID-03). Barricade dùng NavigationObstacle3D, không cắt lại navmesh lúc chạy |
| SLOT-04 | \[Could] Thêm slot WALL chỉ cần thêm marker và dữ liệu; thêm ô grid chỉ cần sửa GridData |
| SLOT-05 | Vị trí slot WALL và cell_id của ô grid cố định qua các run. Kiểm tra lúc nạp level: đủ W1-W6, tiền tố slot_id (W cho WALL, G cho GROUND) khớp zone, không trùng slot_id \[LOG] |
| SLOT-06 | Vòng sáng slot ở PREP, tắt ở COMBAT, chỉ hiện trên slot còn xây được; với ô grid là lưới ô hiện ở PREP. Khi đủ max_ground_buildings, ô grid EMPTY hiện màu khóa. Biểu tượng vẽ trên cùng (MSE-04) |
| SLOT-07 | Vật che tầm nhìn dùng shader xuyên thấu (MSE-05) |
| SLOT-08 | Ghi nhớ khi tower bị phá: slot RUINED lưu ruined_type và ruined_level, là loại và cấp của tower trước khi bị phá, để xây lại giữ cấp (BLD-07). ruined_type và ruined_level bị xóa khi xây bất kỳ công trình nào lên slot hoặc khi dọn đổ nát (CLR-01). \[Should] Khi hoán đổi với tower (MOV-02), chúng đi cùng đống đổ nát sang slot kia. Slot RUINED không bán được. Mất mức nhớ khi xây đè là chủ đích: xây lại một lần hay xây cấp 1 rồi nâng có cùng tổng gold (BLD-07) nên người chơi không thiệt. |

| **ID** | **Luật grid** |
| --- | --- |
| GRID-01 | Mỗi ô có cell_id ổn định dạng G_c_r: G là zone GROUND, c là chỉ số cột, r là chỉ số hàng (ví dụ G_3_2, G_5_0), là slot_id của slot sinh ra ở ô đó. RunState, save, STARTER_KIT và StartPack trỏ tới ô bằng cell_id |
| GRID-02 | Mọi slot ô grid được sinh **một lần lúc nạp level**, trước khi hệ thống Tower & Build thu thập danh sách slot, và tồn tại suốt run kể cả khi EMPTY. Không tạo hay xóa slot ô grid giữa run |
| GRID-03 | GridData chỉ chứa ô mặt đất, nằm ngoài no_build_lane (rộng ≥ no_build_lane_min_width và ≥ no_build_lane_min_ratio bề rộng hành lang), và **toàn bộ ô** nằm ngoài spawn_zone, return_zone và cách command_post ≥ grid_min_gap_to_command_post. Ô vi phạm bị bỏ khi nạp và ghi lỗi \[LOG] |
| GRID-04 | Phân biệt hai giá trị. **Trần** max_ground_buildings (8) cố định suốt run, không thao tác nào làm trần tăng hay giảm. **Số chỗ đã dùng** ground_used là số ô grid đang OCCUPIED hoặc RUINED, luôn ≤ trần. Khi ground_used = trần thì mục xây trên ô EMPTY xám kèm lý do (BLD-08). Xây trên ô RUINED (xây lại hoặc xây loại khác) không bị chặn vì ô đó đã chiếm chỗ. Bán (SELL-03) hoặc dọn đổ nát (CLR-02) trên ô grid làm ground_used giảm 1, tức trả lại 1 chỗ; \[Should] di chuyển và hoán đổi không đổi ground_used (MOV-04) |
| GRID-05 | Collider chọn (pickable) của ô grid nhỏ hơn ô một chút (mặc định 1.9 m với ô 2 m) để không chồng lên ô bên cạnh (MSE-02) |
| GRID-06 | Lưới ô, vòng sáng và collider chọn của ô grid không nằm trong nhóm nguồn bake navmesh |

### 3.6.3 Tower

Mỗi tower có 3 cấp (cấp 1 khi xây, 2 lần nâng). Dữ liệu trong TowerData. Nâng lên cấp 2 và cấp 3 bị giới hạn theo Cấp Chỉ huy (FRT-03, UPG-06).

**Arrow** (đơn mục tiêu, bắn được mục tiêu bay, damage_type PIERCE)

| **Cấp** | **Chi phí** | **Sát thương** | **Tốc độ bắn** | **Tầm** | **HP** |
| --- | --- | --- | --- | --- | --- |
| 1 | 50 | 10 | 1.0/s | 14 m | 120 |
| 2 | 70 | 16 | 1.2/s | 15 m | 160 |
| 3 | 110 | 24 | 1.4/s | 16 m | 220 |

**Cannon** (sát thương lan, chỉ mặt đất, BLAST)

| **Cấp** | **Chi phí** | **Sát thương** | **Tốc độ bắn** | **Tầm min-max** | **Bán kính nổ** | **HP** |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 90 | 35 | 0.4/s | 4-12 m | 2.5 m | 150 |
| 2 | 120 | 55 | 0.45/s | 4-13 m | 3.0 m | 200 |
| 3 | 180 | 80 | 0.5/s | 4-14 m | 3.5 m | 260 |

**Barricade** (tank building, không tấn công)

| **Cấp** | **Chi phí** | **HP** | **aggro\_weight** |
| --- | --- | --- | --- |
| 1 | 40 | 300 | 1.0 |
| 2 | 60 | 500 | 1.2 |
| 3 | 90 | 800 | 1.5 |

Ai đánh được tower: tower trên ô grid và Barricade bị mọi loại quân theo bảng ưu tiên. Tower WALL chỉ bị Archer, boss có is_ranged, Bat và sát thương AoE, **không** bị quân cận chiến mặt đất.

| **ID** | **Hồi HP, phá hủy** |
| --- | --- |
| TWR-01 | Tower hồi đầy HP miễn phí ở đầu mỗi PREP (tower_full_heal_on_prep = true) |
| TWR-02 | HP = 0 trong wave: vào RUINED, hủy projectile chưa rời nòng, không rơi thưởng, ghi ruined_type và ruined_level (SLOT-08) |
| TWR-03 | Tower bị phá không hoàn tiền. Xây lại ở PREP giữ nguyên cấp đã có, giá bằng tổng cost từ cấp 1 đến cấp đó theo TowerData (SLOT-08, BLD-07) |
| TWR-04 | Projectile đã rời nòng vẫn bay tiếp đến khi va chạm hoặc hết tầm |

### 3.6.4 Xây, nâng cấp, bán, dọn đổ nát (chỉ PREP); di chuyển \[Should]

**Luồng xây:** chọn slot trống hoặc slot RUINED (slot WALL hoặc ô grid), hiện menu loại cho phép, chọn loại (ghost preview kèm vòng tầm bắn), xác nhận (kiểm tra gold, trừ gold, tạo tower, animation dựng 0.5 s chỉ là hiệu ứng, tower hoạt động ngay).

| **ID** | **Xây** | **Xử lý** |
| --- | --- | --- |
| BLD-01 | Không đủ gold | Nút xám, hiện giá và số thiếu |
| BLD-02 | Bấm Xây đúng frame PREP kết thúc | Giao dịch nguyên tử: hoàn tất trước khi chuyển state hoặc bị từ chối. \[Should] Việc hủy hoàn tác bán khi PREP kết thúc cũng nguyên tử với chuyển state |
| BLD-03 | Bấm nhiều lần trên một slot | Khóa slot khi đang xử lý |
| BLD-04 | Xây khi Pause | Cho phép (PREP vẫn là PREP) |
| BLD-05 | Gọi wave sớm khi đang mở menu xây | Đóng menu, hủy lựa chọn chưa xác nhận |
| BLD-06 | Slot không hợp lệ với loại tower | Loại đó không xuất hiện trong menu |
| BLD-07 | Xây lại ở slot RUINED | Ở PREP, menu xây của slot RUINED có thêm mục đầu tiên "Xây lại \[loại] cấp n": tạo ngay tower đó ở đúng cấp n với giá rebuild_cost = tổng cost cấp 1 đến cấp n của loại đó trong TowerData (hệ số 1.00, tính theo dữ liệu, không theo invested_gold hay giá bán). Đây chỉ là tiện ích thao tác: tổng gold bằng xây cấp 1 rồi nâng lần lượt. Các mục xây thường ở cấp 1 vẫn còn. Kiểm tra gold >= rebuild_cost rồi trừ, nguyên tử như BLD-02. Không đủ gold: nút xám kèm giá và số thiếu (BLD-01). Tower xây lại đầy HP, target_priority về mặc định (CMD-06), invested_gold = rebuild_cost |
| BLD-08 | Xây trên ô grid EMPTY khi grid đã đủ max_ground_buildings | Các mục xây thường xám kèm lý do "Đã đủ 8 công trình trên mặt đất". Chỉ bán (SELL-03) hoặc dọn đổ nát (CLR-02) mới trả lại chỗ (ground_used giảm 1); ô RUINED chưa dọn vẫn chiếm chỗ. Kiểm tra trần lại ngay lúc xác nhận, nguyên tử như BLD-02 (GRID-04) |

| **ID** | **Nâng cấp** |
| --- | --- |
| UPG-01 | Tốn gold theo bảng cấp kế, tức thì, và phải đủ điều kiện Cấp Chỉ huy (UPG-06) |
| UPG-02 | Giữ target_priority, HP hồi đầy theo max_hp mới |
| UPG-03 | Cấp tối đa: hiện "MAX" |
| UPG-04 | Không nâng được tower RUINED |
| UPG-05 | Không đủ gold: như BLD-01 |
| UPG-06 \[MVP] | Nâng lên cấp 2 yêu cầu commander_level ≥ tower_gate_lv2, lên cấp 3 yêu cầu ≥ tower_gate_lv3 (FRT-03). Không đủ: nút xám kèm "Cần Chỉ huy cấp N". Kiểm tra lại lúc xác nhận như BLD-02 |

| **ID** | **Bán** |
| --- | --- |
| SELL-01 | Hoàn sell_refund_pct 60% tổng gold đã đầu tư (xây cộng các lần nâng), làm tròn xuống |
| SELL-02 | Chỉ PREP. MVP: xác nhận ở mọi cấp bằng hộp thoại chung (SCR-14). Hộp thoại giao dịch tuân theo SCR-14 về tự đóng và kiểm tra lại state lúc xác nhận. \[Should] Khi đã làm hoàn tác 3 s thời gian thực (PNL-10) thì bán cấp 1 không cần xác nhận |
| SELL-03 | Slot về EMPTY, priority reset mặc định, không giữ ruined_type và ruined_level. Bán công trình trên ô grid trả lại 1 chỗ: ground_used giảm 1, trần max_ground_buildings vẫn là 8 (GRID-04). Slot RUINED không bán được, muốn bỏ thì dùng Dọn đổ nát (CLR-01) |
| SELL-04 | Công trình từ **StartPack hoặc STARTER\_KIT** (đều \[Should]): Giá trị đầu tư của công trình đặt sẵn bắt đầu từ 0 và cộng giá các lần nâng; bán hoàn 60% phần đó |

**Luồng di chuyển \[Should]:** toàn bộ MOV-01..07 gắn \[Should]; nút "Di chuyển" và phím M ẩn ở MVP; EVB-25 cũng \[Should]. Chọn tower (PNL-02), bấm "Di chuyển" hoặc phím M, vào chế độ di chuyển: ghost của tower kèm vòng tầm bắn bám theo con trỏ. Chỉ slot cùng nhóm vị trí với slot nguồn (slot WALL với slot WALL, ô grid với ô grid) là đích hợp lệ và tô xanh. Rê lên slot EMPTY: tower sẽ chuyển sang. Rê lên slot OCCUPIED hoặc RUINED: hai bên sẽ hoán đổi, ghost mờ của tower hoặc đống đổ nát kia hiện ở slot nguồn để người chơi thấy trước kết quả. Slot khác nhóm tô đỏ kèm lý do "Chỉ đổi chỗ trên tường với tường, mặt đất với mặt đất". Bấm chuột trái vào slot hợp lệ để xác nhận, thay đổi có hiệu lực ngay. Chuột phải hoặc Esc hủy (INP-03), tower ở nguyên chỗ.

| **ID** | **Di chuyển \[Should]** |
| --- | --- |
| MOV-01 \[Should] | Chỉ ở PREP (kể cả PREP boss và lúc Pause như BLD-04). Nguồn là slot OCCUPIED. Tower giữ nguyên loại, cấp, HP, target_priority, invested_gold và trạng thái công trình đặt sẵn (SELL-04). Tower nhận vị trí, facing và pha quét (TWR-15) của slot đích. Đích EMPTY thì slot nguồn về EMPTY, không có ruined_type, ruined_level; đích OCCUPIED hoặc RUINED thì hoán đổi theo MOV-02 |
| MOV-02 \[Should] | Chỉ di chuyển trong **cùng nhóm vị trí**: slot WALL với slot WALL, ô grid với ô grid. Không di chuyển từ WALL xuống ô grid hay từ ô grid lên WALL. Trong cùng nhóm, slot đích ở trạng thái nào cũng nhận: **EMPTY** thì tower chuyển sang. **OCCUPIED** thì hai tower hoán đổi chỗ, mỗi tower giữ đủ thuộc tính theo MOV-01. **RUINED** thì tower sang slot đích, còn đống đổ nát cùng ruined_type, ruined_level, collision và obstacle chuyển sang slot nguồn; slot nguồn thành RUINED và vẫn xây lại được (BLD-07). Thứ được đổi sang slot mới phải hợp lệ với allowed_types của slot đó (BLD-06); với bảng zone MVP điều này luôn đúng trong cùng nhóm. Nguồn luôn là tower; muốn bỏ đống đổ nát thì dùng Dọn đổ nát (CLR-01) |
| MOV-03 \[Should] | Di chuyển và hoán đổi **miễn phí** (không tốn gold, invested_gold không đổi) và không giới hạn số lần mỗi PREP |
| MOV-04 \[Should] | Trần grid (GRID-04): di chuyển và hoán đổi chỉ trong cùng nhóm nên ground_used không đổi và không bị trần chặn, kể cả khi grid đã đủ max_ground_buildings |
| MOV-05 \[Should] | Giao dịch nguyên tử như BLD-02: xác nhận đúng frame PREP kết thúc thì hoàn tất trước khi chuyển state hoặc bị từ chối, không có tower ở hai nơi hay mất tower. Hoán đổi cập nhật cả hai slot trong cùng một giao dịch, không có frame nào hai thứ chung một slot hay một thứ biến mất. Kiểm tra lại trạng thái hai slot ngay lúc xác nhận |
| MOV-06 \[Should] | Chế độ di chuyển tự hủy (tower ở nguyên chỗ) khi PREP kết thúc, khi gọi wave sớm (như BLD-05), khi mở panel khác hoặc đổi chế độ chỉ huy (INP-07) |
| MOV-07 \[Should] | RunState cập nhật bản ghi của cả hai slot_id trong cùng giao dịch MOV-05 (chuyển hoặc hoán đổi), không dựa vào thứ tự tín hiệu. Sau đó phát slot_changed (EVB-13) cho cả hai slot, rồi một tower_moved (EVB-25) |

**Dọn đổ nát \[MVP]:** chọn slot RUINED, panel Build (PNL-01) có nút "Dọn đổ nát" ở cuối menu. Bấm là slot về EMPTY ngay.

| **ID** | **Dọn đổ nát** |
| --- | --- |
| CLR-01 | Chỉ ở PREP (kể cả PREP boss và lúc Pause như BLD-04), trên slot RUINED (slot WALL hoặc ô grid). Slot về EMPTY: bỏ đống đổ nát, collision và NavigationObstacle3D, xóa ruined_type và ruined_level nên mất mục "Xây lại" (BLD-07) |
| CLR-02 | Miễn phí, không hoàn gold. Không cần hộp thoại xác nhận vì không mất gold: xây lại chỉ là tiện ích, tổng gold bằng xây cấp 1 rồi nâng (BLD-07). Dọn trên ô grid trả lại 1 chỗ: ground_used giảm 1, trần max_ground_buildings vẫn là 8 (GRID-04) |
| CLR-03 | Nguyên tử như BLD-02, khóa slot khi đang xử lý như BLD-03. Kiểm tra lại state PREP và slot vẫn RUINED ngay lúc bấm |
| CLR-04 | Phát slot_changed (EVB-13) với slot_state EMPTY. RunState xóa ruined_type, ruined_level của slot đó |

### 3.6.5 Hành vi tower trong chiến đấu

Mỗi tower quét theo scan_interval 0.2 s. Chọn mục tiêu theo target_priority, giữ mục tiêu đến khi mục tiêu chết, ra khỏi tầm, hoặc retarget_delay 0.3 s sau khi đổi priority.

**Mục tiêu hợp lệ:** quân sống, trong tầm, tower có khả năng đánh (Cannon bỏ qua mục tiêu bay), resist(damage_type) > 0 (DMG-02), không trong spawn_grace (EN-04).

Sát thương tower gây ra = base × dealt_mult, với dealt_mult = 1 + (aura_active ? frontline_aura_dmg_bonus : 0) + các khoản khác (DMG-06, FRT-01).

| **Priority** | **Cách chọn** |
| --- | --- |
| **First** | Quân có nav_progress lớn nhất (gần Fortress nhất dọc tim hành lang, áp dụng chung cho quân đi bộ và quân bay). nav_progress định nghĩa ở TWR-16, do từng quân tự cập nhật mỗi path_update_interval 0.3 s, tower chỉ đọc giá trị đã lưu. Mặc định Arrow |
| **Nearest** | Quân gần **tower** nhất theo khoảng cách thẳng. Mặc định Cannon |
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
| PRJ-07 | Buff (\[Should] BUFF_FURY, meta, modifier) tính **lúc trúng đích** |
| PRJ-08 | Nổ Cannon (BLAST, bán kính tối đa 3.5 m ở cấp 3) không gây knockback và không gây STAGGER lên quân địch ở MVP. Lý do: STAGGER ngắt đòn 0.4 s rồi miễn knockback 2 s (AI-04); nếu mỗi viên đạn diện rộng đều gây hiệu ứng này, cả cụm quân đang đánh Barricade bị gián đoạn đồng loạt, nhả slot (CRD-03) và tăng ca kẹt (NAV-03). Nguồn knockback lên quân thường ở MVP chỉ gồm đòn 3 của chỉ huy (combo_hit3_knockback) và shockwave khi Deploy (mục 3.5.5, deploy_shockwave_*). Stomp của Bulwark chỉ knockback chỉ huy (BOSS-07). \[Could] Knockback nhẹ cho Cannon cấp 3 nếu playtest cần |

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
| TWR-13 \[Should] | Tower từ StartPack \[Should] hoặc STARTER_KIT bị phá | Xây lại theo SLOT-08: giữ cấp đặt sẵn, giá bằng tổng cost từ cấp 1 đến cấp đó (ví dụ Arrow cấp 1 của STARTER_KIT: 50 gold). Công trình xây lại là tower thường: giá trị đầu tư bằng số gold đã trả, hoàn bán 60% (SELL-01), không còn đánh dấu miễn phí (SELL-04 chỉ áp cho bản đặt sẵn). Slot vẫn trống trong lúc RUINED thì STARTER_KIT không đặt lại |
| TWR-14 | Arrow bắn trên không | Chỉ kiểm chứng được khi có Bat \[Should] |
| TWR-15 | Tua x3 với 14 tower (6 WALL + 8 trên grid) | Quét theo scan_interval game time, các tower lệch pha theo slot_id, ứng viên lấy bằng area query. Không tính đường theo tower. FPS tụt thì hạ time scale trước (TIME-06). Dự phòng: nếu level chưa có lane_curve thì dùng hình chiếu x dọc hành lang (cùng công thức TWR-16 với đường thẳng) |
| TWR-16 | nav_progress thống nhất cho quân đi bộ và quân bay | nav_remaining = chiều dài lane_curve trừ lane_curve.get_closest_offset(vị trí quân), tức số mét còn lại tới cổng Fortress. nav_progress = lane_ref_length - nav_remaining (mét), lane_ref_length là chiều dài lane dài nhất của level, nên mọi lane so sánh trực tiếp theo quãng còn lại tới thành. lane_curve là Curve3D tim hành lang từ spawn_zone đến cổng Fortress, một đường ở MVP (SPN-01; khi đó nav_progress chạy từ 0 tại spawn đến lane_ref_length tại cổng), do Level sở hữu. Mọi quân dùng cùng công thức: quân đi bộ chỉ lấy hình chiếu, không dùng quãng navmesh còn lại, nên đi vòng Barricade không làm lệch thứ tự với quân bay; quân bay (Bat) tính theo hình chiếu vị trí bay xuống mặt phẳng ngang. Cập nhật mỗi path_update_interval 0.3 s (lệch pha), tower chỉ đọc. Hòa nav_progress: TGT-01. \[Should] Nhiều điểm spawn: mỗi điểm một lane_curve nối vào đoạn cuối chung, nav_remaining tính trên lane của chính quân đó |

## 3.7 Kẻ địch, Spawner và Scale

### 3.7.1 Dữ liệu (EnemyData)

Trường: base_hp, base_damage, attack_interval, attack_range, move_speed, spawn_cost, is_flying, is_ranged, knockback_immune, aggro_range, target_rules, gold_reward, prestige_reward, **xp_value** (XP-01), **resist_table** (tùy chọn, mặc định kháng 1.0 mọi loại, dùng cho FRT-05 \[Should]), avoid_radius, avoid_priority, damage_type. Không có logic riêng theo loại trong code ngoài khai báo dữ liệu.

**Chỉ số gốc ở wave 1:**

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

**xp_value** (XP-01): Grunt 1, Archer 2, Brute 5, boss 30; \[Should] Bat 2; Healer, Debuffer, Shaman đặt 3 khi làm (tạm thời, chỉnh trong EnemyData).

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
| AI-02 | Đạn Archer cong, bay tới **vị trí mục tiêu lúc bắn**, 20 m/s, không tự dẫn, Dodge né được, không bị Barricade chắn |
| AI-03 | Không friendly fire giữa quân địch (kể cả Brute và AoE boss) |
| AI-04 | Knockback ngắt wind-up, sau đó miễn knockback 2 s |
| AI-05 | Combo 3 của chỉ huy và Cannon **không stun**. Không có khống chế lên kẻ địch ở MVP |
| AI-06 | Boss miễn taunt, knockback, hồi máu, buff từ Healer và Shaman |

### 3.7.3 Chọn mục tiêu

Mỗi target_rules là danh sách có thứ tự, chọn **mục tiêu đầu tiên hợp lệ**. category: PLAYER, BARRICADE, TOWER_GROUND (tower trên ô grid, trừ Barricade), TOWER_WALL, FORTRESS, ALLY_MELEE_LOW_HP, ALLY_RANGED.

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
| **Archer** | Trong tầm: 1. Tower (TOWER_GROUND hoặc TOWER_WALL). 2. PLAYER (chỉ Frontline). 3. BARRICADE. 4. FORTRESS. Gần nhất, hòa thì entity_id nhỏ | Tiến đến khi có mục tiêu trong tầm rồi **dừng bắn** (hold), không kiting |
| **Brute** | 1. PLAYER khi khiêu khích **và** chỉ huy trong 4 m. 2. FORTRESS | Đi thẳng về thành, vẫn bị Battle Cry ép |
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
| Tower trên ô grid không phải Barricade | 3 (khởi điểm) |

| **ID** | **Đặc tả** |
| --- | --- |
| CRD-01 | Quân melee giữ chỗ slot khi còn cách mục tiêu dưới 6 m. Hết slot thì WAIT ở vòng chờ cách 3 m |
| CRD-02 | WAIT quá 3 s: chọn lại mục tiêu, loại mục tiêu đầy trong 5 s |
| CRD-03 | Giải phóng slot khi quân chết, đổi mục tiêu, bị knockback xa quá 3 m, mục tiêu RUINED |
| CRD-04 | Kiểm tra mỗi 2 s, tự giải phóng slot có chủ không hợp lệ |
| CRD-05 | Giải phóng slot chỉ huy khi Recall thành công |
| CRD-06 | \[Should] Bat không chiếm melee_slot của Fortress hay tower (các slot chỉ dành cho quân đi bộ). Bat đánh từ trên cao trong attack_range 1.2 m, tối đa bat_max_per_target (6) Bat cùng đánh một mục tiêu; Bat dư lượn vòng ngoài và chọn lại mục tiêu sau 3 s như CRD-02 |

Va chạm: Grunt, Archer avoid_radius 0.5 m (ưu tiên 1). Brute 0.9 m (ưu tiên 3, đẩy được quân nhỏ). Bat không va chạm mặt đất. max_alive 70. Quân ngoài camera giảm tần suất animation (LOD, \[Should]), **không** giảm logic tấn công.

**Thang xử lý kẹt (v1.4).** Phần **MVP** gồm: phát hiện kẹt (NAV-01, 02), rơi khỏi map (NAV-03, 04), tắc do chỉ huy (NAV-05), bậc 1 (NAV-06), bậc 3 recycle (NAV-08), bậc 4 cull (NAV-09), boss riêng (NAV-12), giới hạn cứng (NAV-13), log (NAV-14). Phần **\[Should]**: bậc 2 hop cục bộ (NAV-07), NAV-10, watchdog cấp wave (NAV-11), overlay debug và bot soak test (trong NAV-14). Khi chưa làm bậc 2, bậc 1 chuyển thẳng sang bậc 3 sau 3 s.

| **ID** | **Chống kẹt** |
| --- | --- |
| NAV-01 | **Phát hiện kẹt.** Mỗi 0.5 s tính tiến độ dọc đường đi tới mục tiêu hiện tại (quãng nav còn lại). Quân bị coi là **kẹt** khi tiến được dưới stuck_progress_min (0.5 m) trong stuck_detect_time (3 s) trong lúc đang ADVANCE hoặc CHASE, có mục tiêu hợp lệ và không thuộc trường hợp loại trừ (NAV-02). Đo tiến độ dọc đường đi, không đo độ dịch chuyển thô, nên quân bị đẩy qua lại tại chỗ vẫn bị phát hiện |
| NAV-02 | **Không tính là kẹt:** WAIT, ATTACK, STAGGER, spawn_grace, đang bị Recall tắc do chỉ huy (NAV-05). Quân bị chặn bởi đồng đội đang ATTACK hoặc WAIT ngay phía trước (trong 1.5 m theo đường đi) chuyển sang WAIT (xếp hàng hợp lệ) thay vì bị tính kẹt. Bộ đếm bậc (NAV-06, NAV-08, NAV-09 và NAV-07 nếu có) reset sau 10 s tiến triển bình thường |
| NAV-03 | Bị knockback ra ngoài navmesh: kẹp về điểm nav gần nhất |
| NAV-04 | Rơi khỏi map: đưa về điểm nav hợp lệ gần nhất phía sau vị trí rơi. Rơi lần hai trong cùng wave: xử lý như bậc 3 (NAV-08) |
| NAV-05 | Tắc do chỉ huy trong hành lang hẹp: đi vòng, không được thì chờ 2 s (không tính vào bộ đếm NAV-01) rồi mới bắt đầu thang xử lý kẹt. SLOT-03 giữ làn thông thoáng tối thiểu 4 m và chỉ huy chỉ va chạm mềm (CMB-07), nên chỉ huy không chặn kín được hành lang; NAV-05 chỉ phòng hờ cho điểm hẹp cục bộ. Level không được tạo điểm nào hẹp hơn 4 m |
| NAV-06 | **Bậc 1 (ngay khi phát hiện kẹt):** tính lại đường đi và **tắt va chạm với đồng đội** (ally_phase) trong 1.5 s. Phần lớn ca kẹt là quân chen nhau nên bậc này gỡ được mà không đổi vị trí quân |
| NAV-07 | **\[Should] Bậc 2 (còn kẹt sau bậc 1 thêm 3 s): hop cục bộ.** Dịch tới điểm nav hợp lệ gần nhất trong hop_radius (3 m) theo chiều tiến. Điều kiện: không vượt qua Barricade, tower hoặc tường; không tiến gần Fortress hơn hop_max_advance (4 m theo đường nav) so với vị trí cũ; không rơi vào spawn_zone; không chồng lên quân khác. Không tìm được điểm hợp lệ thì sang bậc 3. Mục đích: gỡ kẹt mà không cho quân "vượt tuyến" phòng thủ. Khi chưa làm: bậc 1 chuyển thẳng sang bậc 3 sau 3 s |
| NAV-08 | **Bậc 3 (còn kẹt sau bậc 1 thêm 3 s khi chưa có bậc 2, hoặc sau bậc 2 thêm 3 s khi đã có, hoặc kẹt lần thứ 3 trong cùng wave): recycle.** Đưa quân về điểm ngẫu nhiên trong spawn_zone, giữ nguyên HP, buff và thưởng, không hoàn ngân sách wave. Tối đa recycle_max (2) lần cho mỗi quân. Quân được đi lại từ đầu nên không mất kill hợp lệ. Quân đã FRENZY khi bị recycle giữ cờ FRENZY: vẫn tốc độ x1.5, mục tiêu cố định FORTRESS, bỏ qua taunt và slot chờ (EN-02); bộ đếm bậc kẹt vẫn reset theo NAV-02. Đồng hồ giới hạn cứng NAV-13 chạy theo lần spawn cuối của wave, không reset khi recycle; quân recycle sau giây 240 có thể không kịp tới Fortress và bị cull ở giây 300 (không thưởng, ghi log kèm cờ frenzy) |
| NAV-09 | **Bậc 4 (đã recycle đủ lần mà vẫn kẹt): cull.** Xóa quân, tính vào điều kiện kết thúc wave (enemies_alive giảm), **không thưởng, không tính kill** (RWD-03, tránh lợi dụng để nhận thưởng không cần diệt). Ghi log STUCK_CULL kèm loại quân, vị trí, wave, run_seed |
| NAV-10 | **\[Should] Không có tiến triển khi đang đánh:** quân ATTACK mà đòn hụt liên tiếp 3 lần (AI-01), hoặc ATTACK và WAIT quá no_damage_timeout (10 s) mà mục tiêu không mất HP: loại mục tiêu đó khỏi danh sách trong 10 s và chọn lại (như CRD-02). Vẫn không tiến triển thì xử lý từ bậc 2 (hoặc bậc 3 khi chưa có bậc 2). Khi chưa làm, ca này được FRENZY (EN-02) và giới hạn cứng (NAV-13) đỡ |
| NAV-11 | **\[Should] Watchdog cấp wave:** sau khi spawn_queue rỗng, mỗi 5 s kiểm tra tổng tiến độ nav của quân sống (trừ boss) và tổng sát thương hai bên. Không có thay đổi trong wave_stall_timeout (45 s) thì áp dụng bậc 3 (recycle) cho toàn bộ quân sống một lần. Khi chưa làm, FRENZY ở 240 s và giới hạn cứng 300 s thay thế |
| NAV-12 | **Boss** không bao giờ bị recycle hay cull (BOSS-04). Boss có thang xử lý kẹt riêng |
| NAV-13 | **Giới hạn cứng:** wave_hard_cap (300 s sau lần spawn cuối), mọi quân còn sống không phải boss bị cull (không thưởng) và wave kết thúc. Đảm bảo wave luôn kết thúc dù các cơ chế trên đều lỗi. Áp dụng cả với quân FRENZY |
| NAV-14 | **Log và kiểm chứng:** mỗi lần kích hoạt bậc 3-4 (và bậc 2 khi có) ghi log (loại quân, vị trí, wave, state, nav_distance, quân lân cận). stuck_cull_count xuất được ở Settings, Dữ liệu, Xuất log lỗi. **Nghiệm thu MVP:** chạy tay hoặc bằng script ít nhất 20 wave ở x3 với seed khác nhau, mọi wave kết thúc, quân bị cull dưới 0.1% tổng số quân. **\[Should]** Bản debug có overlay tô màu quân kẹt. Bot tự chơi 200 wave ở x3 với seed ngẫu nhiên, mọi wave kết thúc, quân bị cull dưới 0.1% |

### 3.7.5 Spawner

| **ID** | **Đặc tả** |
| --- | --- |
| SPN-01 | MVP có 1 điểm spawn ở cực phải (vùng chữ nhật rộng bằng hành lang). \[Should] 2-3 điểm, mỗi wave chọn ngẫu nhiên |
| SPN-02 | spawn_zone (12 m đầu hành lang): chỉ huy Frontline không vào được (tường vô hình đẩy mềm), tower không nhắm quân còn spawn_grace (EN-04). Skill có hướng (Sword Wave, Firebomb) cũng không gây sát thương và không bật hit_by_commander lên quân còn spawn_grace |
| SPN-03 | Vị trí sinh ngẫu nhiên theo RNG wave. Bị chiếm (overlap 1 m) thì hoãn 0.2 s và thử lại. Quá 3 s thì sinh ở vị trí cuối thử được |
| SPN-04 | Spawn dựa hoàn toàn vào spawn_queue |

**Thuật toán sinh thành phần** (chạy một lần khi vào PREP để preview đúng, dùng RNG hash(run_seed, wave_index)):

1. Tính budget(w) và spawn_duration(w).
2. Loại quân **mới xuất hiện lần đầu** (min_wave = w) đảm bảo intro_count (2 với Archer và Bat, 1 với Brute), trừ ngân sách trước.
3. Lặp: lập ứng viên (đủ min_wave, spawn_cost không vượt ngân sách, chưa vượt max_per_wave, thỏa trần), rút theo weight, trừ ngân sách, dừng khi hết ứng viên.
4. Chia group_count = clamp(2 + floor(w/5), 2, 6) nhóm, mỗi quân cách 0.4-0.8 s, giữa nhóm nghỉ 3 s.
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

| **ID** | **Trần** |
| --- | --- |
| SPN-05 | Archer không quá 40% số quân |
| SPN-06 | Quân hỗ trợ tổng không quá 20% |
| SPN-07 | Không sinh hỗ trợ nếu chưa có ít nhất 3 quân chiến đấu |
| SPN-08 | Wave 1-2 chỉ có Grunt |
| SPN-09 | Boss sinh ở giây 0 của BOSS_COMBAT, vị trí riêng trong spawn_zone |
| SPN-10 | Quân hộ tống dùng 0.5 × budget(w), trải trong spawn_duration, sinh theo cùng thuật toán thành phần ở mục 3.7.5 |
| SPN-11 | Wave boss kết thúc khi spawn_queue rỗng và enemies_alive == 0 |
| SPN-12 | Wave sau boss dùng công thức thường, không bù ngân sách |

**Modifier wave \[Should]:** rút 0 hoặc 1 từ wave 4, xác suất p = clamp(0.1 + 0.02w, 0, 0.5), không ở wave boss, hiển thị ở preview.

| **Modifier** | **Tác dụng** |
| --- | --- |
| Swift | Tốc độ quân +25% |
| Armored | Sát thương quân nhận -20% |
| Horde | Ngân sách +30%, HP quân -20% |
| Fog | Tầm bắn mọi tower -20% |

### 3.7.6 Công thức scale (endless)

Áp dụng cho wave w (số thứ tự tuyệt đối). Nằm trong ScaleConfig.

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
| SCL-04 | Mục tiêu cân bằng: người mới thua ở wave 8-12, người thành thạo qua wave 20-25 |
| SCL-05 | Hệ số áp lúc sinh quân, không đổi khi đã sống. Armored, Horde chồng lên |

### 3.7.7 Frenzy, thưởng khi chết, edge case

| **ID** | **Đặc tả** |
| --- | --- |
| EN-01 | 60 s sau lần spawn cuối: marker định vị trên HUD (HUD-10 \[Should]) |
| EN-02 | 240 s: FRENZY. Tốc độ x1.5, mục tiêu cố định FORTRESS, bỏ qua taunt và slot chờ. Tầm xa đến tầm bắn Fortress rồi bắn. Frenzy không thay thế thang xử lý kẹt và vẫn chịu giới hạn cứng 300 s (NAV-13). Quân bị recycle trong FRENZY giữ trạng thái FRENZY (NAV-08, EN-03) |
| EN-03 | Đã FRENZY không quay lại. Cờ FRENZY thuộc về quân, không mất khi recycle (NAV-08), stagger hay đổi mục tiêu |
| EN-04 | spawn_grace: quân mới sinh (kể cả boss) bất tử, không bị nhắm, không tấn công và không dừng hold cho đến khi rời spawn_zone. Backstop: spawn_grace tự hết sau spawn_grace_max_time (10 s) dù chưa rời vùng, để không quân nào bất tử vĩnh viễn |
| RWD-01 | Thưởng **hiển thị tức thì** khi chết (số nổi là gold_reward(w) theo RWD-02, trước gold_pct_total và clear_mult, đã gồm frontline_gold_mult nếu quân có cờ hit_by_commander (FRT-02), làm tròn gần nhất để hiển thị), **ví thật cộng ở SUMMARY** (GLD-02). Một lần theo cờ is_dead. wave_gold_base cộng giá trị chưa làm tròn, chỉ làm tròn một lần ở công thức gold_gain (mục 3.9.1) |
| RWD-02 | gold_reward(w) = gold_reward_gốc × (1 + 0.04(w-1)). Quân có cờ hit_by_commander nhân thêm frontline_gold_mult (FRT-02). prestige_reward cố định theo loại |
| RWD-03 | Kill do tower, chỉ huy (kiếm hoặc skill) đều tính. Quân bị cull do chống kẹt (NAV-09, NAV-13) hoặc dọn cuối run không thưởng và không tính kill. Recycle không ảnh hưởng thưởng |
| RWD-04 | Kill trong FRENZY nhận đủ thưởng |
| RWD-05 | Thưởng gốc (gold / uy tín): Grunt 4/1, Archer 7/2, Brute 20/5, Bat 6/2, Healer 12/3, Debuffer 9/3, Shaman 12/3 |
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

## 3.8 Boss

Mỗi wave boss có **đúng một boss**. Không có hai boss đồng thời ở MVP.

### 3.8.1 Loại sát thương

Mọi nguồn sát thương phải khai báo damage_type.

| **Nguồn** | **damage\_type** |
| --- | --- |
| Arrow, đạn Archer | PIERCE |
| Cannon | BLAST |
| Kiếm chỉ huy | SLASH |
| Trượng phép \[Should] | MAGIC |
| Bẫy \[Should] | TRAP |
| Skill chủ động của chỉ huy | Whirlwind SLASH, Sword Wave SLASH, Firebomb BLAST (SKL-10..12) |
| Cú rơi khỏi map | TRUE (bỏ qua giáp, kháng, i-frame, skill_mult; không tác dụng lên chỉ huy ở Commander mode) |

| **ID** | **Đặc tả** |
| --- | --- |
| DMG-01 | Lên boss: damage = raw × resist(damage_type, phase), áp dụng **lúc trúng đích**. resist = 0 là miễn nhiễm |
| DMG-02 | Tower dùng resist = 0 để **loại mục tiêu khỏi danh sách hợp lệ**. Chỉ huy đánh trúng thì hiện "IMMUNE" và không gây sát thương |
| DMG-03 | resist < 1: số nổi xám kèm nhãn "RESIST" |
| DMG-04 | Sát thương lên boss **không có sàn tối thiểu 1**. resist = 0 cho đúng 0 |
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

**MVP chỉ có Bulwark.** BOSS-22 (MVP): mọi wave boss dùng Bulwark với chỉ số scale theo hp_mult(w), dmg_mult(w), speed_mult(w); pha 1 miễn nhiễm PIERCE, MAGIC nên **bắt buộc dùng Cannon, kiếm hoặc skill BLAST/SLASH**, Arrow không bắn. Khi làm Barrage \[Should] thì quay lại luân phiên theo n (xem BOSS-22 bản \[Should] ở mục 3.8.10). Dòng Barrage trong các bảng bên dưới chỉ áp dụng khi đã làm Barrage.

**Thứ tự mục tiêu:**

| **Boss** | **Thứ tự** |
| --- | --- |
| Bulwark | 1. PLAYER nếu khiêu khích và trong 4 m. 2. BARRICADE trong 8 m phía trước. 3. TOWER_GROUND trong 8 m phía trước. 4. FORTRESS. Không nhắm TOWER_WALL và chỉ huy Commander |
| Barrage \[Should] | Trong tầm 18 m: 1. Tower, ưu tiên Arrow rồi gần nhất. 2. PLAYER (chỉ Frontline). 3. BARRICADE. 4. FORTRESS. Bắn khi mục tiêu trong tầm, tiếp tục ADVANCE tới khi cách mục tiêu đang nhắm barrage_hold_distance rồi mới dừng (hold, BOSS-41) |

### 3.8.3 Luật chung của boss

| **ID** | **Đặc tả** |
| --- | --- |
| BOSS-01 | Miễn taunt, knockback, hồi máu, buff Healer và Shaman, Slow, Stun, Weaken |
| BOSS-02 | Không dùng slot đánh (không chiếm melee_slot). Không tính vào max_alive (vẫn tính vào enemies_alive) |
| BOSS-03 | Agent điều hướng lớn nav_layer_large (bán kính 1.6 m). Luôn có làn thông thoáng rộng tối thiểu 4 m (SLOT-03) |
| BOSS-04 | **Kẹt** (NAV-01 với ngưỡng boss_stuck_time 5 s): boss **không bao giờ bị recycle hay cull**. Bậc 1: tính lại đường với agent lớn. Bậc 2 (thêm 5 s): nếu vật cản là Barricade hoặc tower trên ô grid thì đặt vật đó làm mục tiêu bắt buộc để Stomp hoặc Shell phá đường. Bậc 3 (thêm 5 s): hop tới điểm nav hợp lệ gần nhất trong boss_hop_radius (6 m) theo chiều tiến, không vượt Fortress. Bậc 4 (thêm 5 s): xuyên qua quân hộ tống (ally_phase) cho tới khi hết kẹt. Mọi bậc ghi log. Thang này độc lập với NAV-07, vẫn là MVP dù NAV-07 là \[Should] |
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
| BOSS-09 | Sát thương dư khi armor_hp về 0 **bị bỏ** |
| BOSS-10 | Chuyển pha **một lần**, cờ phase_broken |
| BOSS-11 | Đồng hồ **không dừng** trong TRANSITION |
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
| BTM-04 | Mốc cảnh báo: **T-30 s** banner T2 "Mech sắp cuồng nộ", **T-10 s** số đếm cỡ lớn kèm bíp mỗi giây, **T-0** Cuồng nộ (ENR-01). Không còn mốc T-20, T-15, T-5 và không khóa tua x1 |

### 3.8.6 Flow wave boss

PREP (boss) -> BOSS_INTRO -> BOSS_COMBAT -> SUMMARY

**PREP boss:** prep_time_boss 45 s. Preview: tên boss, miễn nhiễm pha 1, boss_timer. \[Should] PNL-05 đầy đủ.

| **ID** | **PREP boss** |
| --- | --- |
| BOSS-15 \[Should] | Cảnh báo không chặn nếu không có tower gây được sát thương lên boss ở pha 1 (Frontline luôn gây được 60% nên không bế tắc) |
| BOSS-16 | \[ĐÃ XÓA v1.8] |

| **ID** | **BOSS\_INTRO** |
| --- | --- |
| BOSS-17 | 4 s game time. Camera lia tới boss, hiện tên và biểu tượng miễn nhiễm |
| BOSS-18 | Khóa input gameplay và chuyển chế độ. Chỉ huy bất tử. Cho Pause và Skip (sau 1 s) |
| BOSS-19 | time_scale về x1. Đồng hồ **chưa chạy** |
| BOSS-20 | Kết thúc intro: boss và hộ tống sinh, đồng hồ chạy |
| BOSS-21 | Boss chết trước giờ: chuỗi chết 2 s, hủy đồng hồ, không Cuồng nộ |

### 3.8.7 Cuồng nộ (Enrage, thay Overload)

Xảy ra khi boss_timer về 0 và boss còn sống. Không có sát thương TRUE, không phá tower, không phạt chỉ huy; hạ boss chậm chỉ làm boss mạnh hơn.

| **ID** | **Đặc tả** | **Tag** |
| --- | --- | --- |
| ENR-01 | boss_timer <= 0 và boss còn sống: đặt boss_enraged = true (một lần mỗi wave), phát `boss_enraged`, banner T1 "Mech cuồng nộ". Xử lý ở cuối physics frame, **sau** xử lý sát thương và kiểm tra thua | MVP |
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
| BRW-01 | Diệt boss: boss_gold(w) = 100 × (1 + 0.04(w-1)), boss_prestige 15. clear_mult không áp lên boss_gold |
| BRW-02 | Diệt boss **sau khi Cuồng nộ**: boss_gold và boss_prestige nhân enrage_reward_mult (0.5), làm tròn xuống. Thưởng từ hộ tống tính bình thường |
| BRW-03 | \[Should] Diệt boss cho lượt 3 chọn 1 nâng hạng (skill hiếm) |
| BRW-04 | par_time_boss = 0.6 × boss_timer. Mốc 0.7 / 1.3 như wave thường. Clear time tính đến khi **cả boss và hộ tống** chết |
| BRW-05 | \[ĐÃ XÓA v1.8] |
| BRW-06 | Ghi bosses_defeated, hiển thị ở RunEnd |
| BRW-07 | **Lượt Emergency repair:** khi **boss bị diệt** (kể cả sau Cuồng nộ) và wave vào SUMMARY với waves_cleared tăng, cộng **+1** vào emg_repair_charges, tối đa 3. Nếu đang 3/3 thì lượt thừa bị bỏ, không bảo lưu. Không cộng nếu run kết thúc trong wave đó (thua đè thắng, GLD-08). Wave thường không cộng. Cộng cùng lúc với gold ở SUMMARY và hiển thị dòng "Emergency repair +1 (n/3)" |
| BRW-08 | Lượt thưởng **không** đổi emg_repair_cd: cooldown 60 s tiếp tục đếm bình thường (chạy cả ở SUMMARY và PREP). Chủ đích: lượt thưởng là kho dự trữ cho các lần dùng sau, không phải hồi tức thì; cooldown không bị reset để không dùng liên tiếp được. Với start_wave > 1 \[Should], các boss đã bỏ qua khi xuất phát không được tính bù (STR-08) |

### 3.8.10 Boss trong endless

| **ID** | **Đặc tả** |
| --- | --- |
| BOSS-22 | Wave boss khi w % 5 == 0. **MVP: mọi wave boss là Bulwark** với chỉ số scale theo wave. \[Should] Khi làm Barrage: n=1 Bulwark, n=2 Barrage, thứ tự cố định, rồi theo BOSS-23 |
| BOSS-23 \[Should] | Từ n >= 3: rút ngẫu nhiên từ pool bằng RNG wave, không lặp boss ngay trước |
| BOSS-24 | Chỉ số nhân hp_mult(w), dmg_mult(w), speed_mult(w). Không có hệ số riêng ở MVP |
| BOSS-25 | boss_timer tăng chậm, trần 120 s |
| BOSS-26 \[Should] | start_wave > 1: boss theo số thứ tự tuyệt đối (luân phiên theo n khi đã có Barrage) |

| **Wave** | **Boss (MVP)** | **armor\_hp** | **core\_hp** | **Sát thương đòn (Stomp)** | **boss\_timer** |
| --- | --- | --- | --- | --- | --- |
| 5 | Bulwark | 1757 | 1318 | 57 | 90 s |
| 10 | Bulwark | 2669 | 2002 | 77 | 93 s |
| 15 | Bulwark | 3821 | 2866 | 100 | 96 s |

\[Should] Khi có Barrage, wave 10 là Barrage (armor_hp 2224, core_hp 1779, Shell 68, 93 s) và wave 15 rút theo BOSS-23. Số trong bảng tính từ hp_mult(w), dmg_mult(w) chưa làm tròn (wave 10: 2.224 và 1.702), làm tròn gần nhất một lần ở cuối.

Kiểm tra cân bằng thô wave 5: Cannon cấp 1 (\~14 dps mỗi cái, 2 cái) cộng kiếm 60% (\~27 dps) cho \~55 dps lên giáp, xấp xỉ 32 s phá giáp. Pha lõi \~14 s (gồm TRANSITION 2.5 s nhận x1.5, rồi EXPOSED x1.25). Cộng thời gian boss đi vào tầm (\~27 s) là \~73 s trong giới hạn 90 s. **Mục tiêu playtest: 60-75% người mới diệt được Bulwark trước giờ. Số trong bảng tính từ hp\_mult và dmg\_mult chưa làm tròn (ví dụ wave 5: 1.464 và 1.272), làm tròn gần nhất một lần ở cuối.**

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
| BOSS-40 | Vị trí đứng của Bulwark khi tới Fortress (boss_melee_point) | Marker3D do Level đặt, một điểm mỗi level, ngoài tường Fortress ở giữa mặt tường hướng ra hành lang. Ràng buộc: tâm boss cách mặt ngoài collider Fortress từ 1.6 m (bán kính agent nav_layer_large, BOSS-03) đến 2.0 m để AoE 3 m của Stomp luôn chạm tường; nằm trên navmesh của agent lớn; không nằm trong collider tower hay Barricade. Bulwark đi tới điểm này, dừng, quay mặt về Fortress rồi Stomp theo nhịp (BOSS-32), không chiếm melee_slot (BOSS-02). Thiếu marker: dùng điểm navmesh gần cổng nhất cách tường 1.8 m và ghi log. Barrage không dùng, đứng ở tầm bắn (BOSS-01). Quân bị Bulwark chắn đường trong 1.5 m khi Bulwark đang ATTACK hoặc đứng tại điểm này được tính là xếp hàng hợp lệ (WAIT), không tính kẹt (NAV-02) |
| BOSS-41 \[Should] | Barrage dừng ngoài tầm mọi tower | Shell tầm 18 m lớn hơn tầm Arrow cấp 3 (16 m) và Cannon (14 m), nên nếu Barrage dừng ngay khi có mục tiêu trong tầm thì không tower nào bắn trả được. Vì vậy Barrage bắn từ 18 m nhưng chỉ dừng khi cách mục tiêu đang nhắm barrage_hold_distance (13 m), nhỏ hơn tầm Arrow cấp 1 (14 m), nên tower Arrow ở mọi cấp bị nhắm đều bắn trả được. Mục tiêu bị phá thì chọn lại (ETG-03) và tiếp tục ADVANCE nếu cần. Không dừng khi còn trong spawn_zone (EN-04) |

## 3.9 Kinh tế: Gold, Uy tín, Danh vọng

Game có đúng **hai loại tiền tệ**.

|  | **Gold** | **Uy tín và Danh vọng** |
| --- | --- | --- |
| Phạm vi | Trong run, mất khi hết run | Uy tín tích lũy trong run, quy đổi thành Danh vọng lưu vĩnh viễn |
| Kiếm từ | Diệt quân, boss, clear time, gọi wave sớm, bán tower | Diệt quân, boss, hoàn thành wave |
| Tiêu vào | Xây, nâng cấp, sửa Fortress | Meta shop, mở khóa |
| Vai trò | Áp lực chọn lựa trong run | Tiến triển giữa các run |

**Nguyên tắc:** gold luôn khan hiếm. Đủ 14 công trình cấp 3 (6 WALL + 8 trên grid) tốn ~3000 gold trong khi tổng gold đến wave 10 khoảng 1100 (đã gồm gold chỉ huy, FRT-02).

### 3.9.1 Gold

| **Nguồn** | **Công thức** |
| --- | --- |
| Diệt quân | gold_reward_gốc × (1 + 0.04(w-1)) × (hit_by_commander ? frontline_gold_mult : 1), cộng vào wave_gold_base (FRT-02) |
| Diệt boss | 100 × (1 + 0.04(w-1)), không nhân clear_mult; nhân enrage_reward_mult nếu boss chết sau Cuồng nộ (BRW-02) |
| Clear time | clear_mult (1.25 / 1.00 / 0.80) lên wave_gold_base |
| Gọi wave sớm | Thời gian PREP còn × 2, tối đa 40 |
| Bán tower | 60% tổng đầu tư, làm tròn xuống |

gold_gain = floor( wave_gold_base × (1 + gold_pct_total) × clear_mult )\
\+ floor( boss_gold × (1 + gold_pct_total) )\
\+ early_call_bonus

gold_pct_total = gold_pct_meta + gold_pct_buff (cộng, không nhân chồng). MVP: gold_pct_buff = 0 vì buff là \[Should]. Không áp lên tiền bán tower và early_call_bonus. Làm tròn một lần ở cuối.

Giả định 40% quân có cờ hit_by_commander thì tổng gold từ quân tăng khoảng 10% so với v1.7. Bảng "Gold từ quân (base)" dưới đây tính theo v1.7; nhân thêm 1.10 làm giá trị tham khảo. **Mục tiêu playtest:** 14 công trình cấp 3 vẫn tốn khoảng 3000 gold và tổng gold đến wave 10 khoảng 1100.

| **Wave** | **Loại** | **Gold từ quân (base, theo v1.7)** | **Boss gold** |
| --- | --- | --- | --- |
| 1 | Thường | ~32 (Fast ~40) | 0 |
| 4 | Thường | ~67 | 0 |
| 5 | Boss | ~42 | 116 |
| 9 | Thường | ~153 | 0 |
| 10 | Boss | ~87 | 136 |
| 14 | Thường | ~274 | 0 |
| 20 | Boss | ~239 | 176 |

| **ID** | **Luật** |
| --- | --- |
| GLD-01 | Gold là số nguyên không âm. Kiểm tra gold >= cost **trước** khi trừ, giao dịch nguyên tử |
| GLD-02 | Số nổi hiển thị gold_reward(w) theo RWD-02 (đã gồm frontline_gold_mult nếu có cờ), trước gold_pct_total và clear_mult (RWD-01). Ví thật chỉ tăng ở SUMMARY |
| GLD-03 | Thua giữa wave: gold chưa cộng bị hủy, không quy đổi sang danh vọng |
| GLD-04 | Không lãi, không trần. Gold dư không mang sang run sau |
| GLD-05 | HUD: gold hiện có và "+xx" mờ tích lũy |
| GLD-06 | starting_gold: MVP cố định 150. \[Should] lấy từ StartPack |
| GLD-07 | Sửa Fortress: chi phí = missing_pct × repair_gold_per_pct (REP-01), làm tròn lên |
| GLD-08 | Gold ở SUMMARY cộng đúng một lần. Wave kết thúc cùng lúc thua: không cộng |
| GLD-09 | early_call_bonus được ghi nhận khi bấm Gọi wave sớm và cộng cùng gold của wave ở SUMMARY như mọi khoản gold khác (GLD-02, GLD-08). HUD hiện "+xx" ngay khi bấm. Thua trong wave đó thì khoản này bị hủy (GLD-03) |

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
| PRS-02 | Không có uy tín từ bán tower, sửa Fortress hay tua tốc độ |
| PRS-03 | ABANDONED quy đổi như hai loại kia (không lợi thế hơn chơi tiếp) |
| PRS-04 | Kết thúc ở wave 1 trước khi hoàn thành wave: chỉ có buffer 50% |
| PRS-05 | FLOW-03 (crash): dùng prestige_pending ghi ở SUMMARY gần nhất, buffer wave dở **mất** |
| PRS-06 | RunEnd hiển thị đủ chi tiết quy đổi |

Ước tính (xuất phát wave 1, chưa buffer): waves_cleared 5 cho ~23 danh vọng, 9 cho ~55, 10 cho ~65, 20 cho ~217. Mục tiêu nhịp: món đầu tiên (40) sau 1-2 run, khoảng 30% cửa hàng sau ~10 run.

## 3.10 Meta shop và Buff một wave

### 3.10.1 Cấu trúc

Một màn hình. Không hoàn tiền ở MVP. **MVP có 4 mục** (FORT_HP, GOLD_PCT, CMD_HP, EMG_REPAIR). STARTER_KIT chuyển sang \[Should].

| **ID mục** | **Tên** | **Tác dụng mỗi cấp** | **Số cấp** | **Chi phí (danh vọng)** | **Phạm vi** |
| --- | --- | --- | --- | --- | --- |
| FORT_HP | Thành kiên cố | +5% fortress_max_hp | 5 | 40 / 70 / 110 / 160 / 230 | MVP |
| GOLD_PCT | Tay buôn giỏi | +4% gold từ quân và boss | 4 | 60 / 100 / 160 / 240 | MVP |
| CMD_HP | Thể chất chỉ huy | +10 commander_max_hp | 3 | 40 / 80 / 140 | MVP |
| EMG_REPAIR | Sửa chữa hiệu quả | +3 điểm % lượng hồi mỗi lượt Emergency repair (20% lên 23 / 26 / 29%) | 3 | 50 / 90 / 150 | MVP |
| STARTER_KIT | Bộ khởi đầu | Xem bên dưới | 3 | 60 / 120 / 200 | Should |
| BUFF_CHARGE | Bùa một wave | Mua lượt buff | Kho tối đa 5 mỗi loại | 20 mỗi lượt | Should |
| UNLOCK_TRAP | Mở khóa Bẫy | Thêm Bẫy vào menu xây | 1 | 100 | Should |
| UNLOCK_WAND | Mở khóa Trượng phép | Thêm lựa chọn vũ khí | 1 | 150 | Should |
| SLOT_ACTIVE | Ô kỹ năng chủ động | Mở ô chủ động thứ 4, 5 (SKL-24) | 2 | 80 / 180 | Should |
| SLOT_PASSIVE | Ô kỹ năng bị động | Mở ô bị động thứ 4, 5 (SKL-24) | 2 | 80 / 180 | Should |
| REROLL_PLUS | Thêm lượt đổi thẻ | +1 Reroll mỗi run (SKL-08) | 2 | 50 / 100 | Should |
| SKILL_UNLOCK_* | Mở skill mới vào pool | Thêm Sword Throw, War Horn, Arrow Rain... (SKL-24) | 1 mỗi mục | 60 đến 120 mỗi mục | Should |

Tổng chi phí các mục vĩnh viễn MVP = 610 (FORT_HP) + 560 (GOLD_PCT) + 260 (CMD_HP) + 290 (EMG_REPAIR) = **1 720 danh vọng** (≈ 1 940 nếu có STARTER_KIT). Cộng lại chỉ đưa lên khoảng +25% HP thành, +16% gold, +30 HP chỉ huy ("chi phí cao, buff thấp").

**STARTER\_KIT \[Should]** (công trình đặt sẵn ở wave 1): cấp 1 = 1 Arrow cấp 1 ở W1. Cấp 2 = thêm 1 Barricade cấp 1 ở ô G_0_1 (ô tham chiếu, mục 3.6.2). Cấp 3 = thêm 1 Arrow cấp 1 ở W2.

| **ID** | **Luật STARTER\_KIT \[Should]** |
| --- | --- |
| SHP-01 \[Should] | Công trình miễn phí, giá trị đầu tư của công trình đặt sẵn bắt đầu từ 0 và cộng giá các lần nâng; bán hoàn 60% phần đó |
| SHP-02 \[Should] | Chỉ khi start_wave = 1. Mốc muộn \[Should] dùng công trình của StartPack, bỏ qua kit để không cộng dồn |
| SHP-03 \[Should] | Slot bị chiếm vẫn xây lại và nâng cấp bình thường |
| SHP-04 \[Should] | Bị phá thì xây lại theo TWR-13 (giữ cấp, giá thường) |

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
| 1 | 1.0 | 150 | Không (áp dụng STARTER_KIT) |
| 5 | 0.8 | 100 | Arrow cấp 2 (W1), Arrow cấp 1 (W2), Barricade cấp 1 (G_0_1) |
| 10 | 0.6 | 250 | Arrow cấp 2 (W1, W2), Cannon cấp 2 (G_0_1), Barricade cấp 2 (G_0_2) |
| 15 | 0.5 | 400 | Arrow cấp 3 (W1, W2), Cannon cấp 2 (G_0_1, G_0_2), Barricade cấp 2 (G_1_1, G_1_2) |
| 20 | 0.4 | 600 | Arrow cấp 3 (W1, W2, W3), Cannon cấp 3 (W4, G_0_1, G_0_2), Barricade cấp 3 (G_1_1, G_1_2) |

Giá trị tương đương mỗi mốc khoảng 80% gold tích lũy tự nhiên đến mốc đó. Ví dụ phạt: xuất phát wave 10 và thua ở wave 21 cho ≈ 97 danh vọng so với ≈ 217 nếu chơi từ wave 1.

**StartSelect** gồm: thẻ mốc (mốc khóa hiện mờ kèm điều kiện), thông tin mỗi mốc (gold, công trình, start_mult, best_by_start), nạp buff (tối đa 2), chọn vũ khí (khi mở Trượng phép), nút Bắt đầu và Quay lại.

| **ID** | **Đặc tả** |
| --- | --- |
| STR-01 | Mốc mở theo max_wave_cleared tuyệt đối. Chơi từ mốc cao vẫn mở tiếp mốc cao hơn |
| STR-02 | best_by_start\[M] lưu riêng theo mốc, không so trực tiếp |
| STR-03 | Mặc định chọn sẵn mốc **cao nhất đã mở**, hệ số phạt hiển thị rõ cạnh thẻ |
| STR-04 | Xuất phát mốc M: wave_index = M, waves_cleared = M-1. Boss theo n = M/5 |
| STR-05 | Công trình đặt sẵn hoạt động ngay ở PREP đầu với HP đầy, priority mặc định |
| STR-06 | Tutorial chỉ ở run đầu của mốc 1 |
| STR-07 | Quay lại sau khi nạp buff: hủy lựa chọn nạp, không mất gì |
| STR-08 | Fortress và chỉ huy đầy HP, cooldown các kỹ năng khởi đầu bằng 0. **Emergency repair luôn khởi đầu ở 3/3 lượt** với emg_repair_cd = 0, ở mọi mốc xuất phát. Các wave boss bị bỏ qua khi xuất phát ở mốc muộn không được tính bù thêm lượt (BRW-08) |

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
| user://save.json | Tiến trình chính |
| user://save.bak | Bản chính trước lần ghi gần nhất |
| user://save.tmp | Bản đang ghi dở |
| user://save.premigrate.bak | \[Should] Bản trước migration (giữ một bản) |
| user://settings.cfg | Cài đặt, **tách riêng** khỏi save |

{\
"save_version": 1,\
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

unlocked_starts **không lưu**, luôn tính lại từ max_wave_cleared. Checksum chỉ để phát hiện hỏng tệp, không chống gian lận. Các trường unlocks và buff_stock phục vụ mục \[Should]; ở MVP có thể bỏ trống hoặc không ghi, thiếu thì dùng giá trị mặc định (SAV-10). Các cấp \[Should] của meta.levels (STARTER_KIT, SLOT_ACTIVE, SLOT_PASSIVE, REROLL_PLUS, SKILL_UNLOCK_*) cũng thiếu thì mặc định 0. Dữ liệu skill và XP của run không ghi xuống đĩa (RUN-01).

### 3.12.2 Quy trình ghi

1. Serialize data, tính checksum, ghi ra save.tmp.
2. Đọc lại save.tmp, kiểm tra parse và checksum. Sai thì hủy, giữ bản cũ.
3. Nếu save.json tồn tại: sao chép thành save.bak.
4. Thay save.json bằng save.tmp (xóa bản cũ trước rồi đổi tên nếu nền tảng không cho ghi đè).

| **ID** | **Đặc tả** |
| --- | --- |
| SAV-01 | **Thứ tự tải:** save.json, save.tmp (nếu hợp lệ), save.bak. Bản đầu tiên qua checksum và version được dùng |
| SAV-02 | Tất cả hỏng: thông báo, "Tạo save mới", giữ tệp hỏng đổi tên .corrupt |
| SAV-03 | Ghi một luồng có hàng đợi. Nhiều yêu cầu gần nhau gộp thành một lần ghi mới nhất |
| SAV-04 | **Thời điểm ghi:** xác nhận StartSelect \[Should], SUMMARY mỗi wave, RunEnd, mua ở shop, kích hoạt buff \[Should], hoàn tất tutorial. **Không ghi trong COMBAT** |
| SAV-05 | Ghi ở SUMMARY hoàn tất trước khi hiển thị màn tổng kết |
| SAV-06 | Dọn save.tmp mồ côi khi khởi động (sau khi xét SAV-01) |

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
| SAV-14 | Sửa tay save.json | Checksum sai, chuyển sang .bak |
| SAV-15 | Chạy hai phiên bản cùng lúc | "Bản sau thắng", không khóa tệp ở MVP |
| SAV-16 | Xóa tiến trình | Xác nhận hai bước, đổi tên save.deleted, không xóa settings.cfg |
| SAV-17 | Chuyển máy | Copy thư mục user:// là đủ |
| SAV-18 | Đồng hồ hệ thống đổi | Không ảnh hưởng |
| SAV-19 | Giá trị vô lý (số âm, cấp vượt max) | Kẹp về khoảng hợp lệ, ghi log |

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
| SCR-02 | MainMenu | Play, Meta Shop, Settings, Quit. Số dư danh vọng và kỷ lục | RunLoading (MVP), StartSelect \[Should], MetaShop, Settings |
| SCR-03 | StartSelect \[Should] | Thẻ mốc, nạp buff, vũ khí | RunLoading, Back |
| SCR-04 | MetaShop | 4 mục MVP (thêm mục Should khi đã làm), số dư, chi tiết | Back |
| SCR-05 | Settings | 5 tab MVP (Điều khiển chỉ đọc, Âm thanh, Đồ họa, Tiếp cận, Dữ liệu), thêm tab Gameplay \[Should] (mục 4.6) | Back |
| SCR-06 | RunLoading | Thanh tải, mẹo chơi | Run |
| SCR-07 | HUD trong Run | Mục 4.1.3 | Pause, RunEnd |
| SCR-08 | PauseMenu | Resume, Settings, Abandon, Quit | Run, Settings, RunEnd |
| SCR-09 | SummaryPanel | Tổng kết wave, XP, Cấp Chỉ huy, lượt chọn chờ | REWARD_PICK (SCR-17) hoặc wave kế |
| SCR-10 | BossIntro overlay | Tên boss, miễn nhiễm pha 1 | BOSS_COMBAT |
| SCR-11 | RunEnd | Mục 3.2.4 | RunLoading, MetaShop, MainMenu |
| SCR-12 | Hộp thoại hệ thống | Xác nhận, lỗi save, khôi phục run, cảnh báo hiệu năng | Đóng |
| SCR-17 \[MVP] | RewardPick | 3 thẻ, thanh slot hiện tại, nút Reroll (còn n), nút Bỏ qua (có xác nhận), dòng giải thích tĩnh cách chọn 3 chọn 1 | PREP |

| **ID** | **Luật điều hướng** |
| --- | --- |
| SCR-13 | Back và Esc cùng tác dụng ở mọi màn ngoài Run. Esc trong Run theo INP-03 |
| SCR-14 | Hộp thoại xác nhận dùng một mẫu chung: tiêu đề, hậu quả cụ thể, nút hủy (mặc định focus), nút xác nhận. Hộp thoại giao dịch (bán, sửa, hủy xây) chỉ hợp lệ trong PREP: (1) khi PREP kết thúc thì tự đóng như hủy, không thực hiện giao dịch, hiện toast "Hết giờ chuẩn bị"; (2) bấm Xác nhận ở đúng frame chuyển state theo BLD-02 (nguyên tử: hoàn tất hoặc bị từ chối, không có trạng thái giữa); (3) kiểm tra lại state PREP và trạng thái slot ngay lúc xác nhận, không dựa vào lúc mở hộp thoại; (4) không dừng đồng hồ PREP, hộp thoại không làm đồng hồ chậm lại (chỉ Pause của người chơi theo TIME-08 mới dừng). Hộp thoại hệ thống không liên quan giao dịch (SET-01, Abandon, thoát) không bị ràng buộc này |
| SCR-15 | Chuyển màn fade 0.25 s (thời gian thực), khóa input trong lúc fade |
| SCR-16 | Menu điều hướng bằng chuột, mũi tên và Enter. Focus luôn rõ. ui_focus_next (Tab) **vô hiệu trong Run** |

### 4.1.3 HUD trong run

| **Vùng** | **Thành phần** |
| --- | --- |
| Trên trái | Thanh HP Fortress (lớn, có số), HP chỉ huy (nhỏ hơn) |
| Trên giữa | Số wave, trạng thái, đồng hồ (PREP hoặc boss), bộ đếm quân |
| Trên phải | Gold (kèm "+xx"), cụm nút tua nhanh x1/x2/x3 (HUD-14), nút Pause |
| Dưới trái | Thanh kỹ năng theo chế độ, biểu tượng chế độ kèm cooldown chuyển |
| Dưới giữa | Panel ngữ cảnh, nút Gọi wave sớm |
| Dưới phải | \[Should] Buff đang hoạt động và nút kích hoạt buff |
| Dưới trái, trên thanh HP chỉ huy | Thanh XP và hai hàng ô skill (HUD-15, HUD-16), biểu tượng Aura (HUD-17) |
| Giữa (tạm thời) | Banner cảnh báo và thông báo wave |

Không có minimap.

**Thanh kỹ năng:** Frontline gồm Đánh (chuột trái), Dodge (Space), Battle Cry (Q), **Skill 1-3**, Đổi chế độ (Tab). Commander gồm Emergency repair (R, hiển thị **số lượt còn lại n/3** cùng cooldown) và Đổi chế độ (Tab); **skill 1-3 hiển thị xám kèm biểu tượng khóa**. Cooldown có vòng quét kèm **số giây**.

| **Thành phần** | **PREP** | **COMBAT** | **BOSS\_INTRO** | **BOSS\_COMBAT** | **SUMMARY** | **REWARD\_PICK** |
| --- | --- | --- | --- | --- | --- | --- |
| HP Fortress, chỉ huy | Có | Có | Có | Có | Có | Tối thiểu |
| Đồng hồ | Đếm ngược PREP | Clear time tạm tính (mờ) | Boss timer đầy, đứng yên | Boss timer chạy, về 0 thì nhãn CUỒNG NỘ | Không | Không |
| Gọi wave sớm | Có | Ẩn | Ẩn | Ẩn | Ẩn | Ẩn |
| Tua tốc độ | Có | Có | Khóa | Có | Khóa (về x1) | Khóa (về x1) |
| Panel Build/Tower | Có | Chỉ đọc | Ẩn | Chỉ đọc | Ẩn | Ẩn |
| Thanh HP boss | Ẩn | Ẩn | Hiện tên | Có | Ẩn | Ẩn |
| Thanh XP, ô skill | Có | Có | Có | Có | Có | Có (màn SCR-17) |
| Kích hoạt buff \[Should] | Có | Ẩn | Ẩn | Ẩn | Ẩn | Ẩn |

Game dừng ở REWARD_PICK (RWP-01).

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
| HUD-10 \[Should] | Chỉ báo ngoài màn hình: boss chưa vào khung, Fortress bị tấn công khi camera ở xa (Frontline), quân lẻ sau 60 s |
| HUD-11 | Commander mode: biểu tượng regen (+2%/s) cạnh thanh HP chỉ huy khi HP chưa đầy |
| HUD-12 | F1 bật/tắt HUD (cho ảnh chụp), không ảnh hưởng gameplay |
| HUD-13 | **Ô Emergency repair:** hiển thị n/3 bằng ba chấm kèm số, vòng quét cooldown 60 s kèm số giây. Khóa thì xám kèm lý do khi rê chuột: "Đang hồi (còn xx s)", "Hết lượt. +1 lượt khi diệt boss", "Fortress đầy HP", "Chỉ dùng ở Commander mode". Khi nhận +1 lượt: viền sáng 0.3 s và toast T3 "Emergency repair +1 (n/3)". Thông tin không chỉ dựa vào màu (UI-05) |
| HUD-14 | **Cụm nút tua nhanh** (thay cho phím tắt): ba nút x1, x2, x3, nút đang hoạt động sáng và có viền. Bấm x2 hoặc x3 để **bật** mức đó. Bấm lại đúng nút đang bật để **tắt** (về x1). Bấm nút mức khác thì chuyển thẳng, không qua x1. Bấm x1 luôn về x1. Nút không nhận focus bàn phím nên Space, Enter không kích hoạt được (INP-04). Khi bị khóa (BOSS_INTRO, SUMMARY, REWARD_PICK, TIME-03): nút x2 và x3 xám kèm biểu tượng khóa và tooltip lý do, nút x1 sáng. Sau khi mở khóa ở PREP kế tiếp, các nút ở trạng thái tắt, người chơi bật lại nếu muốn |
| HUD-15 \[MVP] | Thanh XP dưới thanh HP chỉ huy: số cấp, % tiến trình, số lượt chọn đang chờ. Khi lên cấp: viền sáng 0.3 s và toast T3 "Lên cấp n (+1 lượt chọn)". Hiển thị tách hai màu **kèm họa tiết** cho XP từ chỉ huy và từ tower (UI-05) |
| HUD-16 \[MVP] | Hai hàng ô skill (3 chủ động với phím 1-3, 3 bị động) có icon, chấm level, quạt cooldown kèm số giây. Ô trống: viền nét đứt. Ở Commander mode ô chủ động xám kèm khóa |
| HUD-17 \[MVP] | Biểu tượng Aura ở góc cạnh thanh HP chỉ huy khi Aura hoạt động, kèm tooltip "+20% sát thương tower trong 12 m" |

### 4.1.4 Panel tương tác

Mọi panel mở ở dưới giữa, không che hành lang.

| **ID** | **Panel** | **Nội dung** | **Mở khi** |
| --- | --- | --- | --- |
| PNL-01 | Build | Loại cho phép, giá, mô tả, chỉ số cấp 1, ghost preview kèm vòng tầm bắn. Slot RUINED: mục đầu là "Xây lại \[loại] cấp n" kèm tổng giá, hiện số thiếu nếu không đủ gold; cuối menu có nút "Dọn đổ nát" (CLR-01). Ô grid EMPTY khi grid đã đủ max_ground_buildings: các mục xây xám kèm lý do (BLD-08) | PREP, chọn slot hoặc ô grid |
| PNL-02 | Tower | Loại, cấp, HP, chỉ số hiện tại và cấp kế, Nâng cấp (xám kèm "Cần Chỉ huy cấp N" khi chưa đủ, UPG-06), \[Should] Di chuyển hoặc hoán đổi (chỉ PREP, MOV-01, MOV-02), Bán, priority | PREP hoặc COMBAT, chọn tower |
| PNL-03 | Commander (priority) | 2 lựa chọn (First, Nearest); \[Should] 4 lựa chọn và nút "Áp dụng cho mọi tower cùng loại" | Chọn tower ở Commander hoặc PREP |
| PNL-04 | Fortress | HP, chi phí sửa, +10% / +25% / Đầy, **số lượt Emergency repair còn lại n/3, cooldown 60 s** và dòng gợi ý "Nhận +1 lượt khi diệt boss" khi lượt dưới 3. Nút sửa chỉ xám khi Fortress đầy máu hoặc gold dưới ceil(min(1, missing_pct) × repair_gold_per_pct), nếu gold không đủ cho cả bước thì bấm sẽ sửa phần gold chi trả được (REP-01), tooltip ghi sẵn số % và gold sẽ dùng | PREP, chọn Fortress |
| PNL-05 \[Should] | Wave preview | Loại quân, modifier, cảnh báo boss. Thu gọn, mở rộng khi rê chuột | PREP |
| PNL-06 | Buff \[Should] | Kho buff, chọn 1 để kích hoạt | PREP, phím V |

| **ID** | **Luật** |
| --- | --- |
| PNL-07 | COMBAT: panel Tower không có Nâng cấp và Bán. Chỉ đổi priority ở Commander mode và khi không Pause. Frontline không đổi được priority trong chiến đấu |
| PNL-08 | Giao dịch cập nhật ngay và **giữ panel mở**. Khóa nút 0.15 s giữa hai lần bấm |
| PNL-09 | Không đủ gold: nút xám kèm số thiếu. Tối đa cấp: "MAX" |
| PNL-10 | **\[Should] Hoàn tác bán.** Khi chưa làm: bán ở mọi cấp đều có xác nhận (SELL-02). Khi làm: bán cấp 2+ có xác nhận. Bán cấp 1 không xác nhận, có hoàn tác 3 s thời gian thực; bộ đếm tạm dừng khi Pause và chạy tiếp phần còn lại khi bỏ Pause. Hoàn tác tự hủy khi: PREP kết thúc (hết giờ hoặc Call wave early), có giao dịch khác (xây, nâng, bán, sửa), hoặc Abandon. Hoàn tác khôi phục loại, cấp, target_priority, invested_gold và HP đầy. Áp dụng cả tower StartPack và STARTER_KIT (Giá trị đầu tư của công trình đặt sẵn bắt đầu từ 0 và cộng giá các lần nâng; bán hoàn 60% phần đó) |
| PNL-11 | Panel tự đóng khi: vào COMBAT (trừ Commander), tower thành RUINED, Esc, chọn thứ khác. Hộp thoại giao dịch đang mở của panel đó đóng cùng lúc, không thực hiện giao dịch (SCR-14) |
| PNL-12 | Mở panel khi Pause: ở PREP cho phép mọi thao tác. Ở COMBAT và BOSS_COMBAT panel chỉ đọc, các nút đổi priority xám kèm tooltip "Không đổi được khi tạm dừng" |
| PNL-13 | Panel Fortress (PNL-04) chỉ **hiển thị** trạng thái Emergency repair, không có nút kích hoạt (dùng bằng phím R ở Commander mode). Vì lượt khan hiếm, tooltip ở PREP gợi ý ưu tiên sửa bằng gold và để dành lượt cho COMBAT |

## 4.2 Input và chuột trong isometric

### 4.2.1 Bảng phím mặc định

| **Hành động** | **Phím** | **Ngữ cảnh** |
| --- | --- | --- |
| Di chuyển | W A S D | Frontline (theo trục màn hình) |
| Đánh thường | Chuột trái | Frontline, không trên UI |
| Dodge | Space | Frontline |
| Battle Cry | Q | Frontline |
| Skill chủ động 1-3 | 1, 2, 3 | Frontline (ở REWARD_PICK: chọn thẻ bằng chuột hoặc phím 1-3 khi có focus thẻ) |
| Đổi chế độ | Tab | Cả hai |
| Emergency repair | R | Commander |
| Gọi wave sớm | G | PREP |
| Bật/tắt xem slot và lưới ô | B | PREP |
| Kích hoạt buff \[Should] | V | PREP |
| Nâng cấp tower đang chọn | U | PREP |
| Bán tower đang chọn | Delete | PREP |
| Di chuyển tower đang chọn \[Should] | M | PREP |
| Hiện tầm bắn mọi tower | Giữ Shift | Mọi lúc |
| Chọn, đặt | Chuột trái | PREP, Commander |
| Hủy, bỏ chọn | Chuột phải | Mọi lúc |
| Đóng panel, Pause | Esc | Mọi lúc |
| Ẩn HUD | F1 | Mọi lúc |

| **ID** | **Luật input** |
| --- | --- |
| INP-01 | Mọi hành động qua InputMap. Tên thống nhất: move_up, move_down, move_right, move_left, attack, dodge, battle_cry, skill_1, skill_2, skill_3, mode_switch, emergency_repair, call_wave, build_toggle, upgrade, \[Should] relocate, sell, show_ranges, pause, select, cancel, toggle_hud và \[Should] buff_menu. Tua nhanh không nằm trong InputMap vì chỉ có nút HUD (HUD-14) |
| INP-02 | Ưu tiên khi nhiều phím cùng frame: **Dodge > Skill > Attack > Mode switch**; nhiều skill cùng frame thì ô số nhỏ trước. Pause và HUD xử lý độc lập |
| INP-03 | **Esc theo chuỗi:** (1) đóng hộp thoại, (2) đóng panel, (3) hủy chế độ đặt hoặc bỏ chọn, (4) mở Pause. Mỗi lần bấm một bước |
| INP-04 | Vô hiệu ui_focus_next, ui_focus_prev trong Run. Space trong gameplay không kích hoạt nút UI còn focus: **giải phóng focus** sau mỗi lần bấm nút UI |
| INP-05 | **\[Should] Rebind:** không trùng phím trong cùng ngữ cảnh: hộp thoại "Đã dùng cho \[Hành động], hoán đổi?". Không gán Esc và F1. Có "Khôi phục mặc định". **MVP:** phím cố định theo InputMap, tab Điều khiển trong Settings hiển thị bảng phím chỉ đọc |
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
| MSE-08 | Camera Frontline bám chỉ huy có smoothing, kẹp biên map. Commander và PREP dùng khung overview. Chuyển camera 0.5 s **thời gian thực** |
| MSE-09 | \[Could] Kéo chuột giữa dịch camera |
| MSE-10 | Con trỏ ra ngoài cửa sổ: giữ hướng aim cuối. Tùy chọn khóa con trỏ (mặc định tắt) |

## 4.3 Cảnh báo và thông báo

| **Tầng** | **Ví dụ** | **Hiển thị** | **Âm thanh** |
| --- | --- | --- | --- |
| **T1 (nghiêm trọng)** | Fortress dưới 30%, chỉ huy dưới 25%, boss Cuồng nộ (T-0) | Banner giữa, viền HUD nhấp nháy | Còi, không bị nhạc lấn |
| **T2 (quan trọng)** | Tower bị phá, PREP còn 5 s, tua bị hạ, boss sắp Cuồng nộ (T-30) | Toast góc trên giữa 2.5 s | Chuông ngắn |
| **T3 (thông tin)** | Đã lưu, nhận gold, mở khóa mốc, lên cấp | Toast nhỏ góc dưới phải 2 s | Không hoặc nhẹ |

| **ID** | **Điều kiện** | **Tầng** | **Nội dung mẫu** |
| --- | --- | --- | --- |
| ALR-01 | fortress_hp chạm 30% (một lần mỗi wave) | T1 | "Thành sắp thất thủ" |
| ALR-02 | commander_hp chạm 25% | T1 | Viền đỏ, nhịp tim |
| ALR-03 | Boss T-30 | T2 | "Mech sắp cuồng nộ" |
| ALR-04 | Boss Cuồng nộ (T-0) | T1 | "Mech cuồng nộ" |
| ALR-05 | \[ĐÃ XÓA v1.8] | | |
| ALR-06 | \[ĐÃ XÓA v1.8] | | |
| ALR-07 | Tower vào RUINED (nhiều tower cùng frame: gộp thành một toast "N tower bị phá") | T2 | "Arrow cấp 2 ở W3 bị phá (xây lại 120 gold)" (gợi ý camera, không tự động) |
| ALR-08 | PREP còn 5 s | T2 | Nhấp nháy đồng hồ |
| ALR-09 | Wave kế là boss | T2 | "Boss ở wave kế. Kiểm tra miễn nhiễm" |
| ALR-10 | FPS tụt, tự hạ tốc độ | T2 | "Đã hạ về x2 để giữ ổn định" |
| ALR-11 | Lưu thất bại | T1 | Hộp thoại |
| ALR-12 | \[Should] Bán, hoàn tác 3 s | T3 | "Hoàn tác (3)". Biến mất khi hoàn tác bị hủy. Tooltip "Hết hạn khi vào chiến đấu" ở 3 s cuối PREP |

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
| FBK-06 | Telegraph Stomp, Shell \[Should]: vòng đỏ viền đậm có họa tiết (không chỉ màu), vẽ trên cùng, không bị vật che làm mờ |
| FBK-07 | Boss chuyển pha: hơi nước, giáp bay, lõi sáng, banner "Lộ lõi" 1.5 s, giảm nhạc 0.5 s |
| FBK-08 | Tower bị phá: khói, mảnh vỡ, đống đổ nát. Xây xong: hiệu ứng dựng 0.5 s |
| FBK-09 | Giới hạn hạt theo preset (Thấp 500, Trung bình 1500, Cao 3000). Vượt thì bỏ hiệu ứng thứ yếu trước, không bỏ telegraph |
| FBK-10 | Slow motion 0.2x cuối run là hiệu ứng thời gian thực trên hoạt cảnh, sau khi RunState đóng băng |
| FBK-11 \[MVP] | Cuồng nộ boss: lõi đỏ phát sáng, hơi nước, giảm nhạc 0.5 s, rung màn hình theo ACC-05 |

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
| RunEnd | Sting thua rồi nhạc nền lặng |

| **ID** | **Đặc tả** |
| --- | --- |
| AUD-01 | Khi tua x2, x3: **không đổi tốc độ và pitch** của nhạc và SFX. Nhạc không bị ảnh hưởng bởi time_scale |
| AUD-02 | Tối đa 32 SFX, tối đa 4 lần phát cùng một âm. Ưu tiên T1 > chỉ huy > boss > tower > quân. T1 không bao giờ bị loại |
| AUD-03 | Cùng một âm không phát quá một lần trong 50 ms (80 ms ở x3) |
| AUD-04 | **\[Should]** Panning theo vị trí trên màn hình, giảm âm theo khoảng cách tới tâm camera. Ngoài màn hình giảm 50%. MVP: phát stereo, không định vị |
| AUD-05 | Ducking: T1 hạ Music 6 dB trong 1.5 s (cần để T1 "không bị nhạc lấn", mục 4.3) |
| AUD-06 | Crossfade nhạc 1.5 s (thời gian thực). Pause: nhạc giảm 50%, SFX gameplay dừng, SFX UI chạy. **\[Should]** Thêm lọc thông thấp cho nhạc khi Pause |
| AUD-07 | Âm báo quan trọng có kiểu riêng phân biệt: Stomp wind-up, Shell rơi \[Should], Cuồng nộ boss, lên cấp, thẻ thưởng xuất hiện, tower bị phá, Fortress trúng đòn nặng |
| AUD-08 | Mất focus: tắt tiếng Master (tùy chọn, mặc định bật). Lấy lại focus fade-in 0.5 s |
| AUD-09 | Nhạc .ogg (stream), SFX ngắn .wav (preload). Chuẩn hóa -14 LUFS (nhạc), -12 (SFX) |
| AUD-10 | Không lồng tiếng ở MVP |

## 4.6 Settings

Lưu trong user://settings.cfg, tách khỏi save. Áp dụng ngay, riêng Video cần xác nhận.

| **Tab** | **Mục** |
| --- | --- |
| Gameplay \[Should] | Tự pause khi mất focus (mặc định bật), khóa con trỏ, hiển thị số sát thương, bật/tắt cảnh báo T2 và T3, Xem lại hướng dẫn, Ngôn ngữ. MVP: các giá trị này cố định theo mặc định, chưa có tab |
| Điều khiển | MVP: bảng phím chỉ đọc. \[Should] Rebind toàn bộ, Khôi phục mặc định |
| Âm thanh | Master, Music, SFX, UI, tắt tiếng khi mất focus |
| Đồ họa | Chế độ cửa sổ, độ phân giải, VSync, giới hạn FPS (60, 120, không), preset chất lượng, chất lượng bóng, giới hạn hạt, kiểu xuyên thấu. \[Should] UI scale 80-150% |
| Tiếp cận | Mục 5.2 |
| Dữ liệu | Mở thư mục save, Xóa tiến trình, Xuất log lỗi |

| **ID** | **Luật** |
| --- | --- |
| SET-01 | Đổi độ phân giải hoặc chế độ cửa sổ: "Giữ thay đổi?" đếm ngược 10 s thời gian thực. Không xác nhận thì hoàn về cũ |
| SET-02 | Preset chỉ là bộ giá trị. Đổi từng mục thì thành "Tùy chỉnh". Mặc định theo GPU (không phát hiện được thì Trung bình) |
| SET-03 | Tắt số sát thương chỉ ẩn số của tower và quân, **không** ẩn sát thương chỉ huy nhận |
| SET-04 | settings.cfg hỏng: dùng mặc định, không ảnh hưởng save, giữ tệp hỏng .corrupt |
| SET-05 | Mở Settings từ Pause: Run vẫn đóng băng. \[Should] Đổi ngôn ngữ áp dụng ngay |
| SET-06 | Lưu khi **thoát màn Settings**, không lưu từng thay đổi |

## 4.7 Hướng dẫn (tutorial)

Kích hoạt ở run đầu của mốc 1, dùng gợi ý ngữ cảnh trong wave 1-3, mỗi gợi ý hiện một lần. **MVP chỉ có TUT-01 đến TUT-05**; TUT-06, TUT-07 và TUT-12 là \[Should]. Phần giải thích 3 chọn 1 không làm bằng hệ tutorial mà là dòng chữ tĩnh trong SCR-17 (\[MVP]).

| **ID** | **Wave / State** | **Gợi ý** | **Điều kiện qua bước** |
| --- | --- | --- | --- |
| TUT-01 | Wave 1, PREP | "Bấm vào slot hoặc ô sáng để xây Arrow" | Xây được 1 tower |
| TUT-02 | Wave 1, PREP | "Bấm Gọi wave sớm (G) để nhận gold, hoặc chờ" | Bất kỳ |
| TUT-03 | Wave 1, COMBAT | "WASD di chuyển, chuột trái đánh, Space né. Đánh trúng quân để nhận XP đầy đủ và mở nâng cấp tower" | Đánh trúng 1 quân |
| TUT-04 | Wave 2, PREP | "Bấm Tab để chuyển sang Commander" | Chuyển được |
| TUT-05 | Wave 2, COMBAT | "Chọn tower, đổi mục tiêu ưu tiên" | Đổi được |
| TUT-06 \[Should] | Wave 3, PREP | "Sửa Fortress bằng gold khi bị thương" | Nếu Fortress bị thương, không bắt buộc |
| TUT-07 \[Should] | Wave 5, PREP | Giới thiệu boss: pha giáp, miễn nhiễm, đồng hồ Cuồng nộ | Xem ít nhất 2 s |

| **ID** | **Luật** |
| --- | --- |
| TUT-08 | Nút **Bỏ qua** luôn có, ghi tutorial_done |
| TUT-09 | Gợi ý không chặn gameplay. TUT-01 chờ tối đa 30 s rồi nhắc lại |
| TUT-10 | Thoát giữa chừng: gợi ý còn lại không tự hiện ở run sau. Có "Xem lại hướng dẫn" ở Settings (tab Gameplay \[Should]) |
| TUT-11 | Tutorial không đổi kịch bản wave hay chỉ số |
| TUT-12 \[Should] | Gợi ý Aura Tiền tuyến ở wave 3 ("Đứng gần tower khi đang chiến đấu để tăng sát thương cho chúng") |

# 5. YÊU CẦU PHI CHỨC NĂNG

## 5.1 Hiệu năng và nghiệm thu kỹ thuật

| **ID** | **Chỉ tiêu** | **Điều kiện đo** |
| --- | --- | --- |
| ACP-01 | **60 FPS** ổn định (percentile 1% không dưới 45) | 70 quân, 14 tower, 200 projectile, x1, preset Trung bình, máy yếu nhất của nhóm (ghi rõ cấu hình). Đo riêng chi phí quét mục tiêu của 14 tower, mục tiêu dưới 1 ms/frame (TWR-15) |
| ACP-02 | Không dưới 30 FPS quá 3 s ở x3, nếu có thì tự hạ x2 | Cùng điều kiện |
| ACP-03 | RunLoading dưới 5 s | SSD, lần đầu và lần sau |
| ACP-04 | Bộ nhớ khoảng 1.5 GB cho toàn game | Sau 30 phút chơi liên tục |
| ACP-05 | Không rò rỉ: sau 10 run liên tiếp, node và bộ nhớ không tăng quá 5% | Performance monitors |
| ACP-06 | Ghi save dưới 50 ms | SAV-05 |
| ACP-07 | UI tối đa 10% thời gian frame | UI-06 |

**Biện pháp hiệu năng:** giới hạn ~70 quân, cập nhật path theo timer 0.3 s, tower quét theo scan_interval, object pool cho projectile, số nổi, thanh máu. Nếu ACP-01 không đạt, giảm giới hạn thanh máu (40) và số nổi (60) trước khi đụng tới logic.

## 5.2 Khả năng tiếp cận

| **ID** | **Đặc tả** |
| --- | --- |
| ACC-01 | **\[Should]** Mù màu: ba preset (Deuteranopia, Protanopia, Tritanopia) cho HUD và telegraph. **MVP:** chỉ cần thỏa UI-05, tức thông tin quan trọng luôn có kênh thứ hai ngoài màu (biểu tượng, họa tiết, chữ) |
| ACC-02 | \[Should] UI scale 80-150%. MVP: chữ tối thiểu 14 px ở 1080p |
| ACC-03 | **\[Should]** Độ tương phản cao cho telegraph và viền công trình (tùy chọn) |
| ACC-04 | Tùy chọn giữ-hoặc-bật cho Shift và các phím giữ |
| ACC-05 | Giảm rung màn hình: Bình thường, Giảm 50%, Tắt |
| ACC-06 | Giảm nhấp nháy: tắt flash trắng, viền cảnh báo tĩnh, không nhấp nháy quá 3 lần/giây. **Giới hạn 3 lần/giây áp dụng cho mọi hiệu ứng nhấp nháy ngay cả khi tùy chọn đang tắt** |
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
- Mọi giao dịch (xây, nâng, bán, sửa, mua) nguyên tử (BLD-02, GLD-01, SHP-05).
- Sự kiện thua và thưởng xử lý đúng một lần (is_dead, boss_enraged, END-01).
- Kết quả sinh wave xác định theo run_seed và wave_index.
- Không có tình huống bế tắc: quân lẻ có FRENZY, boss luôn hạ được (kiếm gây ≥ 60%, ENR-06), kẹt có thang xử lý (không xóa quân ngay), giới hạn cứng 300 s. \[Should] Thêm watchdog cấp wave.

## 5.5 Khả năng bảo trì và kiểm thử

- Toàn bộ chỉ số nằm trong Resource hoặc CSV (GameConfig, TowerData, EnemyData, BossData, ScaleConfig, WaveTable, WaveModifier, StartPack, ShopItem).
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
| DAT-06 | Nguồn chuẩn của giá trị: bảng ở các mục 3.5.1, 3.6.1, 3.6.2 (GridData), 3.6.3, 3.7.1, 3.7.5, 3.7.6, 3.8.2, 3.10.1, 3.11.1 cho Resource tương ứng, mục 6.3 cho GameConfig. Mục 6.4 đến 6.7 là bản tra cứu nơi lưu. Hai nơi lệch nhau thì sửa theo nguồn chuẩn và ghi vào Phụ lục D |

## 6.2 Danh mục Resource

| **Resource** | **Sở hữu** | **Mục tham chiếu** | **Vai phụ trách** |
| --- | --- | --- | --- |
| GameConfig | Luật toàn cục, nhịp game, kinh tế, giới hạn hiệu năng, chống kẹt | 6.3 | Chia theo nhóm, mỗi nhóm một vai |
| CharacterStats | Mọi chỉ số riêng của chỉ huy | 3.5.1, 6.4 | Player & Combat |
| FortressStats | Mọi chỉ số riêng của Fortress | 3.6.1, 6.5 | Tower & Build |
| GridData | Bố cục ô grid của một level: gốc, số cột, tâm z các hàng. Hàm đổi (cột, hàng) sang vị trí và cell_id | 3.6.2 | Level (người làm Level), Tower & Build |
| TowerData | Ba loại tower, ba cấp | 3.6.3, 6.6 | Tower & Build |
| EnemyData | Chỉ số gốc và thưởng gốc theo loại quân | 3.7.1, 6.6 | Enemy & Wave |
| BossData | Bulwark \[MVP], Barrage \[Should] | 3.8.2, 6.6 | Enemy & Wave |
| ScaleConfig | Công thức scale endless | 3.7.6, 6.6 | Enemy & Wave |
| WaveTable | Trọng số và trần sinh quân | 3.7.5, 6.6 | Enemy & Wave |
| WaveModifier \[Should] | Hệ số modifier wave | 3.7.5 | Enemy & Wave |
| StartPack \[Should] | Gói xuất phát theo mốc | 3.11.1 | UI/UX & Meta |
| ShopItem | Giá, số cấp, tác dụng mỗi cấp (4 mục MVP) | 3.10.1, 6.6 | UI/UX & Meta |
| SkillData \[MVP] | Skill và thẻ stat: id, loại ACTIVE / PASSIVE / STAT, max_level, bảng giá trị theo level, icon, damage_type, tag, trọng số | 3.5.12, 6.6 | Player & Combat (nội dung), Tower & Build (RewardOfferGenerator) |

## 6.3 GameConfig

**Run và wave**

| **Tham số** | **Giá trị** | **Ghi chú** |
| --- | --- | --- |
| starting_gold | 150 | GLD-06. MVP cố định |
| prep_time_early* | 25 s | Dùng khi wave ≤ prep_early_until_wave |
| prep_early_until_wave* | 3 |  |
| prep_time_late* | 30 s | Từ wave kế tiếp. prep_time trong các mục khác là giá trị chọn theo hai tham số trên |
| prep_time_boss | 45 s |  |
| max_alive | 70 | WAVE-01 |
| summary_auto_advance* | 10 s | **Thời gian thực** (3.3.4) |
| boss_wave_interval* | 5 | BOSS-22: wave boss khi w chia hết cho giá trị này |

**Kinh tế**

| **Tham số** | **Giá trị** | **Ghi chú** |
| --- | --- | --- |
| early_call_gold_per_sec | 2 |  |
| early_call_cap | 40 |  |
| clear_mult_fast* / clear_mult_normal* / clear_mult_slow* | 1.25 / 1.00 / 0.80 | clear_mult là kết quả chọn theo mốc |
| clear_fast_threshold* / clear_slow_threshold* | 0.7 / 1.3 | Nhân với par_time |
| par_time_offset* | 15 s | par_time = spawn_duration + offset |
| par_time_boss_ratio* | 0.6 | par_time_boss = ratio × boss_timer |
| gold_reward_growth_per_wave* | 0.04 | RWD-02, dùng cho cả boss_gold |
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
| max_attackers_per_tower* | 3 | Tower trên ô grid không phải Barricade. Giá trị khởi điểm, cần playtest |
| sell_undo_window* | 3 s | \[Should] Thời gian thực, dừng khi Pause (PNL-10) |

**Grid**

| **Tham số** | **Giá trị** | **Ghi chú** |
| --- | --- | --- |
| grid_cell_size | 2 m | 3.6.2. Mỗi công trình chiếm 1 ô |
| max_ground_buildings | 8 | GRID-04. Trần cố định; ô RUINED cũng chiếm chỗ. Cộng 6 WALL là 14 |
| no_build_lane_min_width* / no_build_lane_min_ratio* | 4 m / 0.30 | GRID-03, SLOT-03 |
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
| ally_phase_time* | 1.5 s | NAV-06 |
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
| tower_gate_lv2* / tower_gate_lv3* | 4 / 8 | FRT-03 |
| skill_max_level* | 3 | SKL-02, \[Should] 5 |
| skill_slots_active* / skill_slots_passive* | 3 / 3 | SKL-01 |
| stat_max_stacks* | 3 | SKL-04 |
| rerolls_per_run* | 1 | RWP-03 |
| reward_weight_owned* / _new* / _stat* | 40 / 30 / 20 | RWP-07 |

Nút cân bằng ưu tiên khi chỉnh (không sửa code): tower_gate_lv2/lv3 trước, bonus Aura sau, xp_tower_only_pct cuối (Phụ lục C #15, #26).

**Thời gian**

| **Tham số** | **Giá trị** | **Ghi chú** |
| --- | --- | --- |
| fps_downscale_floor* / fps_downscale_duration* | 30 FPS / 3 s | TIME-06. Hiện chỉ định nghĩa hạ x3 về x2 |
| max_physics_steps_per_frame | 8 (đề xuất) | Là **Project Setting** của Godot (Physics > Common), không phải Resource. SRS chưa ghi giá trị, 8 là mặc định của Godot |

**Giới hạn UI, cảnh báo, âm thanh**

| **Nhóm** | **Giá trị** | **Nguồn** |
| --- | --- | --- |
| Thanh máu quân, số nổi | tối đa 40 thanh, 60 số, gộp số trong 0.2 s | HUD-09, FBK-02 |
| Cảnh báo | tối đa 1 banner, 3 toast, không lặp trong 5 s, toast T2 sống 2.5 s, T3 sống 2 s | ALR-13, ALR-14, 4.3 |
| Nhấp nháy | tối đa 3 lần/giây mọi hiệu ứng | ACC-06 |
| SFX | tối đa 32, tối đa 4 lần cùng âm, chống lặp 50 ms (80 ms ở x3) | AUD-02, AUD-03 |
| Ducking, crossfade | T1 hạ nhạc 6 dB trong 1.5 s, crossfade nhạc 1.5 s | AUD-05, AUD-06 |
| Thời gian UI (thời gian thực) | khóa nút giao dịch 0.15 s, fade chuyển màn 0.25 s, xác nhận độ phân giải 10 s | PNL-08, SCR-15, SET-01 |

*Âm lượng mặc định bus (Master 80%, Music 60%, SFX 80%, UI 70%) và giới hạn hạt theo preset (500, 1500, 3000) thuộc settings.cfg, không thuộc GameConfig.*

## 6.4 CharacterStats

| **Tham số** | **Giá trị** | **Ghi chú** |
| --- | --- | --- |
| commander_max_hp | 100 | Giá trị gốc. HP thực = 100 + 10 × cấp CMD_HP, tính ở RunLoading |
| armor_pct | 0.0 | 0 gốc. Nguồn cộng duy nhất ở MVP: passive Armored (SKL-14). Trần lấy từ commander_armor_cap (GameConfig) |
| prep_heal_pct | 0.60 |  |
| commander_regen_pct_per_sec | 0.02 | Chỉ ở Commander mode |
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
| repair_gold_per_pct | 4 | Gold cho mỗi 1% fortress_max_hp thiếu, chỉ sửa bằng gold ở PREP (REP-01). Không liên quan Emergency repair |
| low_hp_warning_pct | 0.30 | UI đọc từ đây (ALR-01, HUD-01) |
| repair_step_small_pct* / repair_step_large_pct* | 0.10 / 0.25 | Hai nút sửa nhanh (REP-01). Nút thứ ba là "đầy HP" |

## 6.6 Các Resource còn lại

Bảng giá trị đầy đủ nằm ở mục đã trỏ. Dưới đây chỉ ghi phần **giá trị đã có trong SRS nhưng chưa có chỗ đặt**.

| **Resource** | **Giá trị nằm ở** | **Bổ sung** |
| --- | --- | --- |
| TowerData | 3.6.3 | arrow_projectile_speed* = 30 m/s (PRJ-01). cannon_falloff_edge* = 0.5 (sát thương nổ ở mép, PRJ-02). default_priority*: Arrow = First, Cannon = Nearest |
| EnemyData | 3.7.1, RWD-05 | xp_value: Grunt 1, Archer 2, Brute 5 (XP-01). resist_table tùy chọn (FRT-05 \[Should]). Archer: projectile_speed* = 20 m/s (AI-02). avoid_radius 0.5 / 0.5 / 0.9, avoid_priority 1 / 1 / 3 cho Grunt / Archer / Brute |
| BossData | 3.8.2 | xp_value = 30 (XP-01). nav_radius* = 1.6 m (BOSS-03). resist_table pha TRANSITION = ×1.5 và EXPOSED = ×1.25 cho mọi loại, không miễn nhiễm (3.8.4) |
| ScaleConfig | 3.7.6 | scale_soft_cap_wave = 40. budget_soft_cap_factor* = 0.5 (SCL-02) |
| WaveTable | 3.7.5 | archer_max_ratio* = 0.40 (SPN-05). support_max_ratio* = 0.20 (SPN-06). support_min_combat* = 3 (SPN-07). group_count = clamp(2 + floor(w/5), 2, 6). Khoảng cách spawn trong nhóm 0.4 đến 0.8 s, nghỉ giữa nhóm 3 s. spawn_overlap_radius* = 1 m, spawn_retry_delay* = 0.2 s, spawn_retry_timeout* = 3 s (SPN-03). escort_budget_ratio* = 0.5 (SPN-10). intro_count*: Archer 2, Bat 2, Brute 1 (bước 2 của thuật toán mục 3.7.5) |
| ShopItem | 3.10.1 | Tác dụng mỗi cấp nằm ở đây: FORT_HP +0.05, GOLD_PCT +0.04, CMD_HP +10, EMG_REPAIR +0.03 (cộng vào emg_repair_base_heal_pct). \[Should]: STARTER_KIT, SLOT_ACTIVE, SLOT_PASSIVE, REROLL_PLUS, SKILL_UNLOCK_*, BUFF_CHARGE, UNLOCK_TRAP, UNLOCK_WAND |
| SkillData | 3.5.12 | Một Resource cho mỗi skill, bảng giá trị theo level tại 3.5.12.1 đến 3.5.12.3. Trọng số reward lấy từ GameConfig (reward_weight_*) |

## 6.7 Dữ liệu chạy (không phải Resource)

| **Đối tượng** | **Chứa** | **Ghi chú** |
| --- | --- | --- |
| RunConfig | start_wave, starting_gold, start_mult (MVP cố định, chỉ đổi khi có \[Should] chọn wave khởi đầu), run_seed và **các giá trị gốc đã cộng meta**: fortress_max_hp, commander_max_hp, emg_repair_heal_pct, gold_pct_meta | Tạo ở RunLoading, bất biến suốt run (APL-01). emg_repair_heal_pct = emg_repair_base_heal_pct + 0.03 × cấp EMG_REPAIR |
| RunState | Theo bảng 3.2.2, gồm emg_repair_charges, emg_repair_cd, wave_index, gold, early_call_bonus, ruined_type và ruined_level theo slot (slot WALL và ô grid), **xp, commander_level, pending_picks, active_slots, passive_slots, stat_stacks, rerolls_left, reward_rng**, boss_enraged, thống kê run... | Không ghi xuống đĩa giữa run (RUN-01) |
| Dữ liệu trong scene (Marker3D, Area3D) | spawn_zone 12 m đầu hành lang, return_zone bán kính 5 m, 6 slot WALL, node GroundGrid (sinh ô grid từ GridData), command_post, deploy_point, boss_melee_point (BOSS-40), lane_curve (TWR-16) | Cố định theo level, người làm Level sở hữu |

## 6.8 Cấu trúc save

Xem mục 3.12.1. settings.cfg là tệp riêng, cấu trúc ConfigFile của Godot, chứa âm lượng bus và cài đặt đồ họa (xem ghi chú cuối mục 6.3).

## 6.9 Danh mục tín hiệu EventBus

Danh mục này là nguồn chuẩn cho tên và payload tín hiệu của autoload EventBus (UI-04, mục 5.5). Quy ước: (1) tên snake_case, động từ ở thì quá khứ (gold_changed); (2) payload có kiểu tường minh, không truyền tham chiếu node, chỉ giá trị; (3) chỉ vai phát bởi mới được emit, vai khác chỉ lắng nghe; (4) thêm hoặc đổi tín hiệu phải sửa bảng này và ghi vào Phụ lục D trước khi merge; (5) giá trị StringName dùng đúng tên state và loại đã nêu trong SRS (PREP, COMBAT, BOSS_INTRO, BOSS_COMBAT, SUMMARY, REWARD_PICK, RUN_END; FRONTLINE, COMMANDER).

| **ID** | **Tín hiệu (payload)** | **Phát bởi, lắng nghe** |
| --- | --- | --- |
| EVB-01 | state_changed(new_state: StringName, old_state: StringName) | Enemy & Wave (wave FSM). Nghe: UI, Audio, thời gian |
| EVB-02 | wave_started(wave_index: int, is_boss: bool) | Enemy & Wave. Nghe: UI, Audio |
| EVB-03 | wave_cleared(wave_index: int, clear_time: float, summary_data: Dictionary) | Enemy & Wave. Nghe: UI (SummaryPanel), RunState. summary_data gồm kills_by_type, gold_base, gold_mult, early_call_bonus, gold_total, prestige_gain_wave, fortress_hp, ruined_towers (kèm giá xây lại), emg_repair_gained (mục 3.3.4), xp_from_commander, xp_from_towers, commander_level, pending_picks |
| EVB-04 | enemy_count_changed(alive: int, queued: int, total: int) | Enemy & Wave. Nghe: UI |
| EVB-05 | enemy_died(enemy_type: StringName, gold_reward: float, world_pos: Vector3, source: StringName, hit_by_commander: bool) | Enemy & Wave. Nghe: UI (số nổi), RunState (kill, thống kê), XpTracker (XP-01..03) |
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
| EVB-21 | run_ended(end_type: StringName, stats: Dictionary) | RunState. Nghe: UI (RunEnd), Save |
| EVB-22 | meta_changed(item_id: StringName, new_level: int, prestige: int) | UI/UX & Meta (shop). Nghe: UI |
| EVB-23 | settings_changed(section: StringName, key: StringName, value: Variant) | UI/UX & Meta (Settings). Nghe: Audio, camera, UI |
| EVB-24 | \[ĐÃ XÓA v1.8] retreat_zone_changed | Retreat không còn. Không dùng lại số này |
| EVB-25 \[Should] | tower_moved(from_slot_id: StringName, to_slot_id: StringName, tower_type: StringName, level: int, swap_kind: StringName) | Tower & Build (MOV-07). swap_kind: NONE (đích EMPTY), TOWER (hoán đổi hai tower), RUINED (hoán đổi với đống đổ nát). Nghe: UI (panel Tower), Audio. RunState đã cập nhật trong giao dịch, không nghe tín hiệu này để ghi |
| EVB-26 | xp_changed(xp: float, level: int, to_next: float, pending_picks: int) | RunState. Nghe: UI (HUD-15) |
| EVB-27 | level_up(new_level: int, pending_picks: int) | RunState. Nghe: UI, Audio, panel Tower (UPG-06) |
| EVB-28 | reward_offered(cards: Array, rerolls_left: int) | Tower & Build (RewardOfferGenerator). Nghe: UI (SCR-17) |
| EVB-29 | reward_picked(card_id: StringName, slot_kind: StringName, new_level: int) | UI. Nghe: Player & Combat (StatBlock, SkillRunner), RunState |
| EVB-30 | skill_slots_changed(active: Array, passive: Array) | Player & Combat. Nghe: UI (HUD-16) |
| EVB-31 | aura_changed(active: bool) | Player & Combat. Nghe: UI (HUD-17), Tower & Build |

# 7. KIỂM CHỨNG VÀ NGHIỆM THU

## 7.1 Test case bắt buộc

**Flow, wave, thời gian**

1. Cùng run_seed và wave_index: danh sách quân và boss sinh ra giống hệt qua nhiều lần chạy.
2. Bảng scale mục 3.7.6 và bảng boss mục 3.8.10 khớp công thức (hp_mult và dmg_mult chưa làm tròn, làm tròn gần nhất một lần). Wave 3 có đúng 2 Archer intro, wave 6 có đúng 1 Brute intro.
3. Vượt max_alive: quân dư chờ trong queue, không bị hủy, wave vẫn kết thúc.
4. FRENZY ở giây 240 và giới hạn cứng ở giây 300: quân cuối luôn chết hoặc bị cull, wave không treo (EN-02, NAV-13). Quân kẹt thật ở giây 250 bị recycle vẫn giữ FRENZY, đi thẳng Fortress với tốc độ x1.5; nếu không kịp thì bị cull ở giây 300 có log cờ frenzy (NAV-08).
5. Tua x1/x2/x3 không làm sai clear time, cooldown, combo, đồng hồ boss, telegraph, projectile (TIME-04).
6. Wave kết thúc cùng lúc Fortress sập: thua đè thắng, không cộng gold (WAVE-02, GLD-08).
7. Nhấn Play ở MainMenu vào thẳng RunLoading, start_wave = 1, starting_gold = 150 (FLOW-06).
8. Pause ở BOSS_INTRO và SUMMARY: mở được Pause, đồng hồ BOSS_INTRO và bộ đếm 10 s của SUMMARY dừng, bỏ Pause thì chạy tiếp (TIME-02).
9. Gọi wave sớm rồi thua trong wave đó: early_call_bonus không được cộng. Thắng thì bonus cộng cùng gold ở SUMMARY. Ở PREP wave boss: cùng công thức, trần 40 gold (WAVE-07, GLD-09, GLD-08).
10. Vào Run: chỉ huy ở Frontline tại deploy_point, HP đầy (mục 3.2.1).
11. Wave sinh 0 quân do bảng lỗi: ép tối thiểu 1 Grunt, ghi cảnh báo, wave vẫn chạy và kết thúc (WAVE-08).

**Chỉ huy**

1. Recall bị hủy khi nhận sát thương, không tốn cooldown (MODE-01).
2. Deploy khi cổng kín quân không làm chỉ huy kẹt (MODE-02).
3. Dodge xuyên quân nhưng bị Barricade chặn (CMB-06).
4. Chỉ huy đứng yên ở điểm hẹp nhất của hành lang, không đánh: quân không chặn được hoàn toàn, vẫn còn làn thông thoáng từ 4 m trở lên và không có quân bị recycle chỉ vì chỉ huy (SLOT-03, NAV-05).
5. Battle Cry kéo Grunt và Archer, không kéo boss (AGG-02).
6. Ở Commander, không gì có thể nhắm được chỉ huy (ETG-01).
7. Ở Commander mode, chỉ huy không nhận sát thương từ bất kỳ nguồn nào: đạn Archer đang bay, Stomp và AoE, \[Should] Shell nổ tại command_post. HP không đổi, không knockback (CMD-10).
8. Recall hoàn tất đúng frame đạn trúng: đạn trước frame Arriving gây sát thương bình thường, từ Arriving trở đi bị hủy (MODE-05).
9. Chỉ huy và Fortress chết cùng frame ghi FORTRESS_DESTROYED (END-01).
10. Cleave: đặt 6 Grunt trong hình quạt 120 độ, tầm 2.2 m. Mỗi đòn chỉ trúng đúng 3 quân gần chỉ huy nhất, mỗi quân nhận sát thương một lần, đòn 3 chỉ knockback 3 quân đó. Hòa khoảng cách chọn theo góc lệch nhỏ hơn, rồi entity_id (CMB-01, CMB-09).
11. Deploy khi deploy_point bị 10 quân vây: chỉ huy xuất hiện ở ứng viên hợp lệ đầu tiên theo thứ tự vòng 1, 2, 3, 4 m, kết quả giống nhau qua nhiều lần chạy cùng kịch bản. Kín cả 4 m thì dùng điểm mặc định kèm shockwave (MODE-02).

**Fortress, tower**

1. Xây, nâng, bán từng loại tower: tổng gold khớp bảng. \[Should] Tower từ STARTER_KIT hoàn 0 + 60% invested_gold (SELL-04) và tower từ StartPack hoàn 0.
2. Bán tower ở mọi cấp đều hiện hộp thoại xác nhận (SELL-02, PNL-10 chưa làm). Mở hộp thoại bán ở giây cuối PREP rồi để PREP hết: hộp thoại tự đóng, tower không bị bán, gold và slot giữ nguyên, đồng hồ PREP không bị dừng bởi hộp thoại (SCR-14).
3. Bấm Xây đúng frame PREP kết thúc: không mất gold, không có tower ma (BLD-02).
4. Đặt đủ 8 Barricade trên các ô grid sát no_build_lane: quân và boss vẫn tới được Fortress (SLOT-03, GRID-03, BOSS-03).
5. Hai priority MVP (First, Nearest) chọn đúng mục tiêu trong kịch bản cố định 5 quân, kết quả xác định (TGT-01). \[Should] Thêm Highest HP, Lowest HP.
6. Emergency repair và sửa gold không cùng lúc làm HP vượt max (FORT-03).
7. Nổ Cannon không gây sát thương cho chỉ huy và tower (PRJ-03).
8. Slot Fortress: 20 quân đến cùng lúc, đúng 12 đánh, 8 chờ, slot giải phóng khi quân chết (CRD-01 đến 04).
9. Tower cấp 3 bị phá: slot RUINED nhớ loại và cấp. Ở PREP kế, "Xây lại" tạo đúng tower cấp 3 với giá là tổng cost cấp 1 đến 3 theo TowerData (Arrow 230, Cannon 390, Barricade 190), không phụ thuộc gold đã đầu tư. Hoàn bán tower xây lại là 60% số gold đã trả, priority về mặc định (SLOT-08, BLD-07, TWR-03, CMD-06).
10. Slot RUINED không đủ gold: nút "Xây lại" xám kèm số thiếu, vẫn xây thường cấp 1 được. Xây thường hoặc xây loại khác thì slot quên cấp cũ. Bấm "Xây lại" đúng frame PREP kết thúc: không mất gold, không có tower ma (BLD-07, BLD-02).
11. \[Should] Tower từ STARTER_KIT bị phá rồi xây lại: giữ cấp đặt sẵn, trả giá thường, giá trị đầu tư bằng gold đã trả, hoàn bán 60% (TWR-13).
12. Nổ Cannon trúng cụm 10 Grunt đang đánh Barricade: không quân nào vào STAGGER hay bị knockback, slot đánh giữ nguyên (PRJ-08, CRD-03).
13. nav_progress thống nhất: quân đi bộ và quân bay cùng hình chiếu trên lane_curve có nav_progress bằng nhau (sai số dưới 0.01 m). Quân đi bộ vòng qua Barricade không làm thứ tự First đảo ngược so với quân bay. Quân bay vượt lên trước thì Arrow ở priority First chọn quân bay (TWR-16, cần Bat nên là \[Should]). \[Should] Hai lane khác độ dài: quân cùng nav_remaining có cùng nav_progress.
14. Đủ 8 công trình trên grid (kể cả ô RUINED): mục xây trên ô EMPTY xám kèm lý do, không xây được công trình thứ 9; xây trên ô RUINED vẫn được. Bán một công trình thì xây thêm được một (GRID-04, BLD-08).
15. Nạp level: số ô grid sinh ra đúng số ô khai báo trong GridData, không ô nào nằm trong no_build_lane, return_zone; slot_id không trùng; bấm vào mép giữa hai ô chỉ chọn một ô (GRID-02, GRID-03, GRID-05, SLOT-05).
16. Sang run mới mọi ô grid về EMPTY, cell_id không đổi (SLOT-05). (Test Overload phá ô grid của v1.7 đã xóa cùng TWR-08.)
17. \[Should] Di chuyển Arrow cấp 2 (priority Nearest) từ W1 sang W2 đang trống, và Cannon từ G_0_1 sang một ô grid khác đang trống: slot nguồn về EMPTY, slot đích OCCUPIED, cấp, priority và invested_gold giữ nguyên, bán sau đó hoàn đúng 60% invested_gold; ground_used không đổi; tower từ STARTER_KIT di chuyển vẫn giữ giá trị đầu tư gốc 0 (MOV-01, MOV-04, SELL-04).
18. \[Should] Di chuyển từ W1 xuống ô grid trống, và từ ô grid lên slot WALL trống: ô đích đỏ kèm lý do, không cho xác nhận, tower ở nguyên chỗ. Grid đủ 8: di chuyển và hoán đổi giữa hai ô grid vẫn được, ground_used vẫn 8 (MOV-02, MOV-04, GRID-04).
19. \[Should] Hoán đổi Arrow cấp 3 ở W1 (priority Lowest HP) với Cannon cấp 1 ở W2: hai tower đổi chỗ, mỗi tower giữ cấp, HP, priority và invested_gold của mình. Hoán đổi Arrow ở G_0_1 với ô G_1_1 đang RUINED (Cannon cấp 2): G_1_1 có Arrow, G_0_1 thành RUINED nhớ Cannon cấp 2 và menu có "Xây lại Cannon cấp 2". Hoán đổi với đống đổ nát Barricade: obstacle chuyển theo sang slot nguồn. Số đếm grid không đổi; không frame nào thấy hai thứ chung một slot (MOV-02, MOV-05, SLOT-08).
20. \[Should] Đang ở chế độ di chuyển thì PREP hết hoặc bấm G: chế độ tự hủy, tower ở slot nguồn. Bấm xác nhận đúng frame PREP kết thúc: tower ở đúng một slot, gold không đổi (MOV-05, MOV-06).
21. \[MVP] Dọn đổ nát ở PREP: slot RUINED về EMPTY ngay, không có hộp thoại, gold không đổi, mất mục "Xây lại". Dọn đống đổ nát Barricade thì obstacle mất. Grid đang đủ 8 (có ô RUINED): dọn một ô thì ground_used còn 7 (trần vẫn 8) và xây được trên ô EMPTY khác. Ở COMBAT không có nút. Bấm đúng frame PREP kết thúc: hoặc dọn xong trước khi chuyển state hoặc bị từ chối (CLR-01 đến CLR-04, GRID-04).

**Kẻ địch**

1. Grunt chọn Barricade trước tower, chuyển sang chỉ huy khi bị khiêu khích, trở lại bảng gốc sau 4 s (ETG-05).
2. Archer ưu tiên tower rồi người chơi rồi Barricade, dừng đúng tầm 11 m.
3. Quân melee không nhắm tower WALL.
4. Quân trong spawn_zone không bị tower nhắm, chỉ huy không vào được (SPN-02, EN-04).
5. Thưởng chỉ tính một lần khi hai sát thương chí mạng cùng frame (RWD-01).
6. Kẹt giả lập (khóa quân bằng vật cản): đi đúng bậc 1, rồi bậc 3 (recycle), rồi bậc 4 (cull); mỗi bậc chỉ kích hoạt khi bậc trước không gỡ được, bộ đếm reset sau 10 s tiến triển (NAV-06, NAV-08, NAV-09). \[Should] Có thêm bậc 2 hop (NAV-07).
7. \[Should] Hop cục bộ không vượt qua Barricade, tower hoặc tường, không tiến quá 4 m về phía Fortress (NAV-07).
8. Quân xếp hàng sau đồng đội đang ATTACK hoặc WAIT không bị tính kẹt (NAV-02). \[Should] Quân ATTACK hụt 3 đòn liên tiếp chọn lại mục tiêu (NAV-10).
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

1. Wave 1 mặc định: 150 gold, chưa có công trình (MVP; STARTER_KIT là \[Should]). Sau wave 1 ở mốc Fast cộng ~40 gold.
2. clear_mult không đổi khi tua tốc độ. gold_pct_total chỉ áp lên gold từ quân và boss.
3. Thua giữa wave: gold không cộng, buffer uy tín tính 50%, waves_cleared không tăng.
4. prestige_gain với start_mult 1.0 khớp công thức, làm tròn xuống một lần. \[Should] Với start_mult 0.6 cũng khớp.
5. Shop MVP chỉ hiện 4 mục (FORT_HP, GOLD_PCT, CMD_HP, EMG_REPAIR), mục \[Should] bị ẩn; tổng chi phí 1 720 danh vọng (SHP-11, mục 3.10.1).
6. Mua từng cấp: không nhảy cấp, không mua khi thiếu tiền, bấm liên tục chỉ trừ một lần. Ghi save lỗi thì hoàn tác (SHP-05 đến 08).
7. \[Should] STARTER_KIT áp dụng khi start_wave = 1 (SHP-02).
8. \[Should] Nạp 2 buff, kích hoạt 1: kho trừ đúng 1, hết run hoàn lượt còn lại.
9. \[Should] BUFF_WARD bật, ép fortress_armor_pct = 60% bằng công cụ debug: raw 100 gây ceil(100 × 0.4 × 0.75) = 30. TRUE (cú rơi khỏi map) không bị giảm (DMG-05, mục 3.6.1, APL-03).
10. \[Should] Mở mốc 10 sau khi hoàn thành wave 10. Chơi từ mốc 10 lên wave 20 mở mốc 20 và ghi best_by_start\["10"] riêng.
11. Mất điện giữa wave 7: lần mở sau tự chốt run theo waves_cleared đã ghi ở SUMMARY wave 6, thông báo một lần.
12. Xóa save.json giữa lúc chơi: nạp từ save.bak. Hỏng cả hai: thông báo, giữ .corrupt.
13. Sửa checksum: chuyển .bak. save_version lớn hơn: từ chối nạp, không ghi đè (SAV-09). \[Should] Migrate không mất dữ liệu (SAV-07, SAV-08).
14. RunEnd: run_kills, run_gold_earned, bosses_defeated và loại tower gây nhiều sát thương nhất khớp số liệu chơi. run_kills và bosses_defeated cộng vào profile.stats, tăng profile.stats.total_runs thêm 1, đúng một lần, run_gold_earned và damage_by_tower_type không lưu (mục 3.2.4, BRW-06).
15. Mở hai phiên bản game cùng lúc: bản ghi sau thắng, không lỗi, save không hỏng (SAV-15).
16. Đổi đồng hồ hệ thống lùi và tiến giữa Run: cooldown, đồng hồ boss, timestamp save không bị ảnh hưởng (SAV-18).

**UI, input, âm thanh, tiếp cận**

1. Esc theo chuỗi: hộp thoại, panel, hủy chọn, Pause (INP-03).
2. Space khi nút UI còn focus: là Dodge, không kích hoạt nút (INP-04). Tab trong Run đổi chế độ.
3. WASD theo vị trí phím vật lý (physical_keycode trong InputMap), đúng trên bố cục AZERTY. Esc và F1 không gán được. Tab Điều khiển hiển thị bảng phím chỉ đọc. \[Should] Rebind trùng phím hiện hộp thoại hoán đổi.
4. Slot sau tường vẫn bấm được ở PREP, tường mờ khi chỉ huy đứng sau. Aim đúng ở địa hình cao.
5. Ở x3 cảnh báo T1 hiện đủ thời gian thực. Tối đa 1 banner và 3 toast, T1 chen T2 (ALR-13, ALR-15).
6. Thanh máu quân không vượt 40 với 70 quân. Nhạc không đổi pitch ở x3, SFX lặp bị giới hạn.
7. Cảnh báo T1 vẫn nghe rõ khi nhạc đang phát (ducking, AUD-05).
8. Đổi độ phân giải không xác nhận: tự hoàn sau 10 s. settings.cfg hỏng: game chạy mặc định, save nguyên vẹn.
9. Chữ tiếng Việt đúng dấu, không tràn khung ở 1280x720 đến 3840x2160 (LOC-02, LOC-03). \[Should] Đổi ngôn ngữ giữa Pause: chữ đổi ngay, không tràn khung.
10. Telegraph vẫn nhận biết bằng họa tiết (UI-05, FBK-06). Giảm nhấp nháy bật: không flash trắng, viền cảnh báo tĩnh. Mọi hiệu ứng không nhấp nháy quá 3 lần/giây (ACC-06). \[Should] Ba preset mù màu (ACC-01).
11. Chạy 30 phút liên tục: FPS và bộ nhớ trong ngưỡng ACP-01, ACP-04, ACP-05.
12. \[Should] Bán tower cấp 1 rồi hoàn tác trong 3 s thời gian thực (kể cả ở x2, x3): gold, slot, loại, cấp và priority trở lại đúng (PNL-10).
13. \[Should] Bán tower cấp 1 rồi bấm Pause: bộ đếm 3 s dừng, bỏ Pause thì chạy tiếp phần còn lại, hoàn tác vẫn bấm được trong phần đó (PNL-10).
14. Nút tua nhanh: bấm x2 thì bật, bấm lại x2 thì tắt về x1. Đang x2 bấm x3 thì chuyển thẳng x3. Bấm x1 luôn về x1. Phím 1, 2, 3 không tua nhanh vì là skill chủ động (TIME-09, HUD-14, SKL-05).
15. Nút tua khóa ở BOSS_INTRO, SUMMARY và REWARD_PICK: x2, x3 xám kèm biểu tượng khóa, hiển thị luôn khớp time_scale thực. BOSS_COMBAT tua bình thường. Sang PREP kế tiếp nút ở trạng thái tắt (TIME-03, HUD-14).
16. Crossfade nhạc 1.5 s thời gian thực khi chuyển PREP sang COMBAT: không ngắt, không đổi pitch, chạy đúng khi Pause và ở x3 (AUD-06).
17. Tắt hết âm thanh vẫn nhận biết đủ: telegraph Stomp (vòng đỏ có họa tiết, thanh wind-up), đồng hồ Cuồng nộ có số, nhãn CUỒNG NỘ và banner ở T-30 và T-0 (ACC-09, ALR-03, ALR-04, ENR-05).
18. Mọi tín hiệu ở mục 6.9 tồn tại trong EventBus đúng tên và kiểu payload. HUD vẫn chạy khi chỉ nhận tín hiệu, không đọc trực tiếp node gameplay (UI-04, EVB-01 đến EVB-31; EVB-24 đã xóa, EVB-25 là \[Should]).

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
| F6 | Nâng tower: Cấp Chỉ huy 3 thì Arrow cấp 1 không nâng cấp 2 được (nút xám "Cần Chỉ huy cấp 4"). Cấp 4: nâng được cấp 2, nhưng cấp 3 xám tới cấp 8. Chỉ huy cấp 8, tower cấp 3 bị phá: xây lại RUINED cấp 3 được (BLD-07 không kiểm gating). Xây tạm cấp 1 rồi nâng lại cấp 3 cũng được vì cấp Chỉ huy không giảm | FRT-03, UPG-06, BLD-07 |
| F7 | REWARD_PICK: RNG theo run_seed cho cùng 3 thẻ; không có hai thẻ trùng; skill đã max không xuất hiện; pool rỗng bỏ qua state; Reroll không tốn lượt; Skip hỏi xác nhận và mất lượt | RWP-01..07 |
| F8 | Skill: phím 1-3 chỉ chạy ở Frontline; ở Commander không làm gì; cooldown đúng ở x1/x2/x3; Whirlwind 15 SLASH bán kính 3 m, Sword Wave, Firebomb (6/s BLAST) đúng bảng level; skill hủy recovery đòn kiếm | SKL-05, SKL-06, SKL-10..12 |
| F9 | StatBlock: Sharpness L3 +24% sát thương, Armored L3 armor 15% (trần 75% giữ), Lifesteal L3 hồi 1.5% commander_max_hp mỗi kill, Focus L3 −18% cooldown skill chủ động | SKL-13..15 |
| F10 | Bulwark pha 1: Firebomb (BLAST) gây 100%, kiếm và Whirlwind 60%, Arrow không bắn (IMMUNE), Cannon 100% | DMG-01, DMG-02 |
| F11 | Cuồng nộ: boss_timer về 0 thì boss_enraged = true một lần, tốc độ × 1.3, nhịp × 1.3, sát thương × 1.5; không có sát thương TRUE, không tower nào thành RUINED, chỉ huy Commander HP không đổi. Diệt sau Cuồng nộ: boss_gold và boss_prestige × 0.5, +1 lượt Emergency repair | ENR-01..06, BRW-02, BRW-07 |
| F12 | Boss chết đúng frame T=0: không Cuồng nộ. Fortress sập cùng frame: FORTRESS_DESTROYED | ENR-04, BOSS-27, BOSS-28 |
| F13 | Chiến lược AFK (bot đứng Commander, nâng tower tối đa có thể): đến wave 12 không vượt quá cấp tower cho phép bởi FRT-03, và Cấp Chỉ huy ≤ 0.65 × Cấp của bot Frontline cùng seed; tỷ lệ sống sót đến wave 15 thấp hơn bot Frontline ít nhất 20 điểm phần trăm (mục tiêu cân bằng, chỉnh qua tham số) | FRT-01..03, XP-02 |
| F14 | Đường thắng: tắt mọi tower, chỉ huy Frontline vẫn hạ được Bulwark wave 5 trong 2 × boss_timer (sau Cuồng nộ có thể thua, ghi lại tỉ lệ) | mục 2.8 |
| F15 | Làm tròn máu và DoT: Lifesteal cấp 1 với commander_max_hp 100 hồi cộng dồn 0.5 mỗi kill, đủ 1 HP sau 2 kill. Firebomb cấp 1 với Tinh thông +5% gây tổng 25 sau 4 tick (6.3 mỗi tick, không phải 24). Thẻ Bền thành tăng fortress_max_hp và hồi đúng lượng tăng | DMG-06, SKL-15, mục 1.4 |

Pause, giá sửa, trần armor, tải quét (v1.3), hoàn tác bán \[Should]

1. Pause trong COMBAT ở Commander mode: mở panel Tower, nút đổi priority xám kèm tooltip, bấm không có tác dụng. Bỏ Pause rồi đổi: áp dụng sau retarget_delay 0.3 s (TIME-08, CMD-04, PNL-12).
2. Pause ở PREP: mở panel, xây, nâng, bán, sửa vẫn hoạt động bình thường (PNL-12).
3. Frontline trong COMBAT, không Pause: panel Tower không có nút đổi priority (PNL-07).
4. Giá sửa: thiếu 20% máu tối đa tốn 80 gold ở cả fortress_max_hp 1000 và 1500. Không đủ gold thì sửa floor(gold / 4)% máu tối đa. Fortress đầy máu: từ chối, không trừ gold. Fortress 1050 HP còn 1033: thiếu 1.619%, chi phí 7 gold (ceil(6.476)), không làm tròn phần trăm trước khi nhân. Gold 6, thiếu 20%: bấm +10% sửa 1% máu (floor(6 / 4)), trừ 4 gold (REP-01, REP-06, GLD-07).
5. Trần armor: ở MVP chỉ có bị động Armored cộng armor chỉ huy (tối đa 15%), armor Fortress luôn 0%. Ép giá trị 90% bằng công cụ debug: kẹp về 75% cho chỉ huy và 60% cho Fortress (APL-03).
6. Tải quét: 14 tower và 70 quân ở x1, chi phí quét mục tiêu dưới 1 ms/frame, tower không gọi tính đường. Quân đổi nav_progress thì priority First đổi theo trong một chu kỳ quét (TWR-15, ACP-01).
7. \[Should] Bán tower cấp 1 ở giây cuối PREP rồi bấm hoàn tác sau khi COMBAT bắt đầu: bị từ chối, toast đã biến mất, gold và slot giữ nguyên trạng thái sau bán (PNL-10, ALR-12, BLD-02).
8. \[Should] Bán tower rồi xây, nâng hoặc sửa trong 3 s: hoàn tác bị hủy ngay. Bán rồi Call wave early hoặc Abandon: cũng bị hủy (PNL-10).
9. \[Should] Hoàn tác bán khôi phục đúng loại, cấp, target_priority, invested_gold, HP đầy. Bán tower StartPack rồi hoàn tác: tower trở lại, gold không đổi (PNL-10, SELL-04).

## 7.2 Định nghĩa "Hoàn thành" (Definition of Done)

Chạy đúng ở x1, x2, x3; có test case tương ứng; không lỗi console; giá trị chỉnh được qua Resource hoặc CSV; không chuỗi viết cứng.

## 7.3 Lịch nghiệm thu

| **Tuần** | **Mốc chức năng** | **Chính** |
| --- | --- | --- |
| 1-5 | Đã hoàn thành: repo, scene, EventBus, GameConfig, blockout, combat cơ bản, Grunt/Archer/Brute, 14 slot, Arrow/Cannon/Barricade, luồng xây, Battle Cry, aggro | Cả nhóm |
| 6 (19-25/10) | Họp chốt v1.8. TimeManager, input edge, chết/hồi, sinh wave theo bảng, targeting 2 priority, AttackSlot, Aura Tiền tuyến, panel Tower, thanh máu quân, số sát thương nổi | Combat, Enemy, Tower, UI, Art |
| 7 (26/10-1/11) | **Mốc A:** vòng lặp wave PREP-COMBAT-SUMMARY chơi được wave 1-4: Commander mode, Recall/Deploy, xây/nâng/bán, dọn đổ nát, XP và Cấp Chỉ huy, camera, AudioManager | Combat, Enemy, Tower, UI, Art |
| 8 (2-8/11) | SkillData, thanh XP trên HUD, SkillRunner và Whirlwind, RewardOfferGenerator, cổng cấp tower, kinh tế gold, HUD đủ vùng, Crowd, khung Bulwark, model Bulwark | Combat, Tower, UI, Enemy, Art |
| 9 (9-15/11) | **Mốc B1:** chơi đến hết Bulwark đầu: pha giáp, Cuồng nộ, kháng boss, Sword Wave, Firebomb, màn REWARD_PICK nhặt được 3 skill chủ động | Cả nhóm |
| 10 (16-22/11) | **Mốc B2:** vòng skill hoàn chỉnh (5 bị động, 3 stat), RunConfig/RunState/RunEnd data, save atomic, MetaShop 4 mục, thưởng boss, thang kẹt MVP, HUD skill/XP | Cả nhóm |
| 11 (23-29/11) | **Đóng băng tính năng MVP (29/11):** RunEnd, Pause, Settings, tutorial rút gọn, khôi phục run, cân bằng lần 1, accessibility, playtest ngoài nhóm | Cả nhóm |
| 12 (30/11-6/12) | Test theo mục 7.1 (đã sửa), cân bằng cuối (SCL-04, FRT, boss 60-75%), đo ACP-01..07, build Windows, báo cáo, video demo. **Mục tiêu hoàn thành 80-90% tổng phạm vi** (MVP 100%, SHOULD chọn lọc) | Cả nhóm |

Trễ mốc B1 (15/11) thì không làm mục \[Should] nào và cắt theo thứ tự ở Phụ lục C mục 17. Chi tiết phân công từng người xem Bang_phan_cong_v2.md.

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
| BLD, UPG, SELL, CLR, MOV \[Should] | Xây, nâng (UPG-06 giới hạn theo Cấp Chỉ huy), bán, dọn đổ nát, di chuyển và hoán đổi \[Should] | 3.6.4 |
| AI, ETG, CRD, NAV | Kẻ địch | 3.7 |
| SPN, SCL, EN, RWD | Spawner, scale, thưởng | 3.7 |
| BOSS, DMG, BTM, ENR, BRW | Boss, Cuồng nộ (OVL và RET đã xóa ở v1.8, không dùng lại) | 3.8 |
| GLD, PRS | Gold, uy tín | 3.9 |
| SHP, BUF | Meta shop, buff | 3.10 |
| STR, APL | Wave khởi đầu, áp dụng meta | 3.11 |
| SAV | Save/Load | 3.12 |
| UI, SCR, HUD, PNL | Giao diện | 4.1 |
| INP, MSE | Input, chuột | 4.2 |
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

## Phụ lục B. Phân vai

| **Vai** | **Phụ trách** |
| --- | --- |
| Player & Combat | Nhân vật, vũ khí, chuyển chế độ, HP và damage system dùng chung. Từ v1.8: Aura Tiền tuyến, SkillRunner, StatBlock, nội dung SkillData |
| Enemy & Wave | State machine, target priority, spawner, scale, boss (Bulwark, Cuồng nộ), XpTracker (XP, cờ hit_by_commander) |
| Tower & Build | Slot, ô grid (GroundGrid sinh slot từ GridData, trần max_ground_buildings), đặt/nâng cấp (kèm cổng cấp UPG-06), targeting priority, projectile, RewardOfferGenerator (hàm thuần, test bằng GUT) |
| UI/UX & Meta | HUD (gồm thanh XP, ô skill), panel Commander, màn RewardPick, shop 4 mục, tổng kết, save/load. \[Should] menu chọn wave và nạp buff |
| Art / Level / Audio | Blockout và dựng map, GridData của map (bố cục ô, no_build_lane), prop, VFX, âm thanh, tích hợp asset, shader xuyên thấu |

## Phụ lục C. Vấn đề còn mở

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
| 15 | Commander mode bất khả xâm phạm: người chơi có thể ở Commander gần như cả run | **Sửa v1.8:** Commander mode vẫn bất khả xâm phạm nhưng có giá rõ ràng: XP 50%, không Aura, không gold chỉ huy, không skill, tower chậm lên cấp (CMD-10, FRT-01..03). Theo dõi test F13. Nếu AFK vẫn thống trị: tăng frontline_aura_dmg_bonus lên 0.30, tăng tower_gate_lv2/3 lên 5/10, hoặc giảm xp_tower_only_pct xuống 0.35 (chỉnh qua Resource, không sửa code) |
| 16 | Giá sửa Fortress theo % máu (4 gold/1%) nên FORT_HP làm Fortress bền hơn mà không tăng giá sửa | Theo dõi sức mạnh meta FORT_HP khi playtest. Nếu quá mạnh, giảm mỗi cấp từ 5% xuống 4% |
| 17 | Nếu sau v1.4 nhóm vẫn quá tải | **Sửa v1.8:** Ứng viên cắt tiếp theo, theo thứ tự: (1) Firebomb (giữ Whirlwind, Sword Wave), (2) Reroll, (3) ducking AUD-05, (4) tab Dữ liệu và Điều khiển của Settings, (5) TUT-04/05, (6) thẻ stat Bền thành, (7) 2 bị động Focus và Lightstep. Quyết định cuối tuần 9 |
| 18 | Chỉ phát hành tiếng Việt | Nếu giảng viên hoặc người chấm yêu cầu tiếng Anh, thêm cột tiếng Anh vào CSV và bật mục Ngôn ngữ trong Settings (kiến trúc tr() đã sẵn) |
| 19 | Di chuyển trong lúc đánh thường chưa có tốc độ riêng (CMB-03 chỉ nói di chuyển không hủy đòn) | MVP: giữ tốc độ đầy đủ. Nếu playtest thấy đánh bị "trượt" quá nhiều, thêm attack_move_speed_mult* (ví dụ 0.5) vào CharacterStats |
| 20 | Các mặc định mới của v1.5 chưa được nhóm xác nhận: chỉ huy xuất phát ở Frontline (mục 3.2.1), Pause được ở mọi state kể cả BOSS_INTRO và SUMMARY (TIME-02), early_call_bonus cộng ở SUMMARY (GLD-09), "tower dùng nhiều nhất" tính theo sát thương (mục 3.2.4) | Nhóm rà soát ở buổi họp kế tiếp. Chọn khác thì sửa đúng ID đã nêu và ghi vào Phụ lục D |
| 21 | Các giá trị mới của v1.6 chưa được nhóm xác nhận: sword_max_targets = 3 (CMB-09), Cannon không knockback (PRJ-08), boss_melee_point cách tường 1.6 đến 2.0 m (BOSS-40), retarget_batch_size = 8 (ETG-08 \[Should]), deploy_clear_radius = 0.8 m (MODE-02), lane_curve làm gốc cho nav_progress (TWR-16) | Nhóm xác nhận ở buổi họp kế tiếp. sword_max_targets là nút cân bằng Frontline: tăng nếu quét cụm quá yếu, giảm nếu Frontline lấn át tower. Chọn khác thì sửa đúng ID đã nêu và ghi vào Phụ lục D |
| 22 | Gold dư ở late game: khi 14 công trình (6 WALL + 8 trên grid) đã cấp 3, gold chỉ còn dùng để xây lại và sửa Fortress (GLD-04 không lãi, không trần) | Theo dõi khi playtest từ wave 30 trở lên. Thiết kế hiện chủ đích khan hiếm gold (mục 3.9.1: 14 công trình cấp 3 tốn khoảng 3000 gold, tổng gold đến wave 10 khoảng 1100) và gold còn dùng để xây lại tower bị phá. Nếu gold dư thật, ứng viên \[Could] là buff mua bằng gold; không thêm ở MVP |
| 23 | Save scumming: người chơi chép thư mục user:// để quay lại bản cũ (checksum chỉ phát hiện hỏng tệp, mục 3.12.1) | Chấp nhận ở MVP vì game offline. Trạng thái Run không ghi giữa chừng (RUN-01) nên chỉ quay lại được profile. Không thêm timestamp hay cơ chế chống gian lận |
| 24 | \[Đã chốt v1.7] Ô grid RUINED không bán được (SLOT-08) nên chiếm 1 trong 8 chỗ của max_ground_buildings | Chốt: thêm Dọn đổ nát ở PREP (CLR-01: miễn phí, ô về EMPTY, trả lại 1 chỗ trong trần, trần vẫn 8, mất ruined_type và ruined_level) và cho hoán đổi tower với đống đổ nát trong cùng nhóm vị trí (MOV-02). Ô RUINED vẫn tính vào trần cho tới khi được dọn hoặc xây lên |
| 25 | \[Should] Di chuyển và hoán đổi tower miễn phí, không giới hạn ở PREP (MOV-03), kể cả PREP boss | \[Đã chốt v1.7] Di chuyển chỉ trong cùng nhóm vị trí (MOV-02) nên không dồn được tower ground lên WALL. Tính năng này chuyển sang \[Should] ở v1.8. Người chơi vẫn đổi bố cục theo từng wave; theo dõi khi playtest. Di chuyển luôn miễn phí |
| 26 | Các giá trị mới của v1.8 chưa được nhóm xác nhận: frontline_aura_radius 12 m và bonus 0.20, frontline_gold_mult 1.25, tower_gate_lv2/lv3 = 4/8, xp_tower_only_pct 0.5, enrage_* (1.3/1.3/1.5/0.5), level skill tối đa 3, 3+3 ô | Họp chốt 19/10. Mọi giá trị nằm trong Resource, đổi không sửa code. Nút cân bằng ưu tiên: tower_gate_lv2/3 trước, bonus Aura sau |
| 27 | Cuồng nộ có thể làm boss "vượt tầm kiểm soát" nếu người chơi yếu | MVP chấp nhận: thua boss sau Cuồng nộ là hậu quả cố ý. Nếu playtest thấy mục tiêu 60-75% người mới diệt Bulwark không đạt, chỉnh boss_timer trước, enrage_damage_mult sau (không chỉnh HP trước) |
| 28 | Chỉ 1 boss (Bulwark lặp) có thể nhàm | MVP chấp nhận; Barrage \[Should] làm ngay khi MVP xong, ưu tiên cao hơn mọi mục Should khác |
| 29 | Firebomb dùng BLAST để tái dùng bảng kháng, nên Bulwark (BLAST 1.0) chịu Firebomb 100% | Giữ. Nếu Firebomb quá mạnh vs Bulwark, giảm sát thương gốc chứ không thêm loại sát thương |

## Phụ lục D. Nhật ký đồng bộ (so với các bản nháp Phần 1-7)

Các dòng 1 đến 53 là lịch sử đến v1.7, giữ nguyên để truy vết. Một số nội dung trong đó (Overload, Retreat, ép x1 ở T-20, shop 5 mục, MOV là MVP) đã bị thay thế bởi các dòng 54 trở đi. Khi mâu thuẫn, mục 3 đến 7 của tài liệu này và các dòng 54 trở đi là nguồn đúng.

| **#** | **Thay đổi đã áp dụng vào bản hợp nhất** |
| --- | --- |
| 1 | **TIME-03:** thêm ép x1 từ T-20 s của đồng hồ boss và khóa đến hết wave. Làm rõ mức tốc độ chỉ giữ từ PREP sang COMBAT trong một wave vì SUMMARY luôn về x1 (bản nháp ghi "giữ qua các wave" mâu thuẫn với quy tắc về x1 ở SUMMARY) |
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
| 15 | **SUMMARY** tự chuyển sau 10 s **thời gian thực** (Phần 1 ghi 10 s không nêu loại) |
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
| 29 | **v1.4, thang xử lý kẹt thu gọn** (mục 3.7.4, NAV-02, NAV-07, NAV-08, NAV-10, NAV-11, NAV-14, WAVE-03, BOSS-04, mục 5.4, 6.2, Phụ lục C mục 14, test 7.1): chuyển hop (NAV-07), NAV-10, watchdog (NAV-11), overlay debug và bot soak 200 wave sang \[Should]. **Giữ lại** recycle (NAV-08) và cull (NAV-09) vì cull ngay sau bậc 1 mâu thuẫn nguyên tắc "không xóa quân ngay" và làm mất thưởng người chơi. Nghiệm thu MVP: chạy tay hoặc script ≥ 20 wave ở x3, cull dưới 0.1%. Thang kẹt của boss độc lập với NAV-07 |
| 30 | **v1.4, migration save sang \[Should]** (mục 3.12.1, 3.12.3, SAV-07, SAV-08): chỉ bỏ migration và save.premigrate.bak. **Giữ lại** khôi phục run gián đoạn (3.12.4, PRS-05) vì FLOW-03 và run_flag phụ thuộc vào nó và chi phí thấp; giữ SAV-09 đến SAV-19 vì là hệ quả của checksum và quy trình ghi, không tốn thêm việc |
| 31 | **v1.4, hoàn tác bán sang \[Should]** (SELL-02, BLD-02, PNL-10, ALR-12, test 7.1, Phụ lục C mục 10): MVP **xác nhận bán ở mọi cấp** để bù cho việc không có hoàn tác |
| 32 | **v1.4, tiếng Anh sang \[Should]** (mục 2.7, LOC-01, LOC-06, mục 4.6, SET-05, test 7.1, Phụ lục C mục 18): MVP chỉ tiếng Việt, **giữ** kiến trúc tr(), CSV theo khóa, placeholder có tên, font và LOC-03 để thêm ngôn ngữ sau không phải sửa code |
| 33 | **v1.4, accessibility thu gọn** (ACC-01, ACC-03, mục 4.6, test 7.1): chuyển 3 preset mù màu và tương phản cao sang \[Should]. **Giữ lại** ACC-05 (giảm rung), ACC-06 (giảm nhấp nháy, giới hạn 3 lần/giây áp dụng mọi hiệu ứng) vì chi phí thấp và liên quan an toàn, cùng UI-05 làm kênh thay thế màu |
| 34 | **v1.4, âm thanh thu gọn** (mục 4.5, AUD-04, AUD-06): chuyển nhạc phân lớp, tăng tempo nhạc boss, panning, lọc thông thấp khi Pause sang \[Should]. **Giữ lại** ducking (AUD-05) vì mục 4.3 yêu cầu còi T1 "không bị nhạc lấn", và crossfade, quy tắc Pause cho SFX |
| 35 | **v1.4, rebind phím sang \[Should]** (INP-05, INP-09, mục 4.6, test 7.1): MVP phím cố định, tab Điều khiển chỉ đọc. **Giữ lại** SET-01 (xác nhận 10 s khi đổi độ phân giải) vì tránh kẹt màn hình sai độ phân giải |
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

Hết tài liệu SRS-EW-1.8.
