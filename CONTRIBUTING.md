# Hướng dẫn làm việc nhóm

Tài liệu này dành cho 5 thành viên của dự án Endless Action Tower Defense, sử dụng Godot 4 với đồ họa 3D và góc máy orthographic isometric. Vui lòng đọc kỹ toàn bộ nội dung trước khi bắt đầu viết code. Mọi yêu cầu chức năng đều nằm trong tài liệu **SRS-EATD v1.4**. Các mã chú thích như `TWR-05`, `HUD-09`, `NAV-06` dùng để trỏ tới mục tương ứng trong tài liệu SRS.

---

## 1. Nguyên tắc cốt lõi

1. **Mỗi người quản lý một thư mục riêng biệt.** Chỉ chỉnh sửa file trong phạm vi công việc của mình. Nếu cần thay đổi file của người khác, hãy thông báo trực tiếp cho họ hoặc tạo một Pull Request nhỏ và tag tên họ vào để review.
2. **Tách biệt dữ liệu khỏi code.** Các chỉ số như máu, giá tiền, tầm bắn, thời gian hồi chiêu phải được lưu trong file Resource `.tres` tại thư mục `data/`. Tuyệt đối không hard-code các giá trị này trực tiếp vào script, tuân theo yêu cầu từ mục 2.5 và 6.1 của SRS.
3. **Sử dụng `EventBus` để giao tiếp.** Các hệ thống không được gọi trực tiếp node của nhau. Ví dụ, HUD chỉ nhận tín hiệu thay vì đọc trực tiếp dữ liệu từ node gameplay theo yêu cầu UI-04.
4. **Sử dụng hàm `tr("khoa")` cho mọi văn bản hiển thị.** Các khóa này được khai báo trong file `data/locale/strings.csv`. Tuyệt đối không viết cứng tiếng Việt trực tiếp vào scene hoặc script, tuân thủ yêu cầu LOC-01 và LOC-05.
5. **Không đẩy code trực tiếp lên nhánh `main`.** Mọi thay đổi đều phải được thực hiện trên nhánh phụ và đưa qua quá trình Pull Request.
6. **Đảm bảo game chạy ổn định trước khi push code.** Nhấn F5 không xuất hiện lỗi đỏ và nhấn F6 tại scene đang làm việc không bị báo lỗi thiếu file.

---

## 2. Ai làm gì, thư mục nào

Dự án gồm năm vai trò dựa theo Phụ lục B của tài liệu SRS và đã được điều chỉnh để cân bằng khối lượng công việc.

| Vai | Phụ trách | Thư mục sở hữu | Mục SRS chính |
| --- | --- | --- | --- |
| **TV1 - Player & Combat** | Chỉ huy, chiến đấu, Commander mode, Recall, Retreat, thời gian, thang chống kẹt, tutorial | `entities/commander/`, `systems/time/`, `systems/nav/`, `systems/tutorial/`, `autoload/time_manager.gd`, `ui/screens/tab_gameplay.tscn`, `ui/screens/tab_controls.tscn` | 3.4, 3.5, 3.7.4, 3.8.1, 3.8.7, 3.8.8, 4.7 |
| **TV2 - Enemy & Wave** | Quân địch, boss, sinh wave, scale, RunConfig và kết thúc Run | `entities/enemy/`, `systems/wave/`, `systems/run/`, `data/enemies/`, `data/bosses/`, `data/waves/`, `common/enemy_data.gd`, `common/boss_data.gd`, `common/wave_table.gd`, `common/wave_group.gd`, `common/scale_config.gd`, `autoload/game_config.gd` | 3.2, 3.3, 3.7, 3.8.2-3.8.6, 3.8.10, 3.11.2 |
| **TV3 - Tower & Build** | Tower, Fortress, Slot, đạn, xây dựng, kinh tế, đồng hồ boss, Overload, save | `entities/tower/`, `entities/fortress/`, `entities/projectile/`, `systems/build/`, `systems/economy/`, `systems/save/`, `data/towers/`, `data/config/`, `common/tower_data.gd`, `common/tower_level_data.gd`, `common/fortress_stats.gd`, `common/slot_zone.gd`, `levels/corridor/slots_layout.tscn`, `autoload/save_manager.gd`, `ui/screens/tab_data.tscn` | 3.6, 3.8.5, 3.8.7, 3.8.9, 3.9, 3.10.1, 3.12 |
| **TV4 - UI/UX & Meta** | HUD, panel, màn hình, hộp thoại, meta shop, Settings, flow, ngôn ngữ | `ui/` (trừ các tab của TV1, TV3, TV5), `data/locale/`, `autoload/game_state.gd`, `autoload/screen_manager.*` | 3.1, 3.10, 4.1, 4.3, 4.6, 5.3 |
| **TV5 - Art/Level/Audio** | Map, camera, model, animation, VFX, shader, âm thanh, accessibility, playtest | `contents/`, `art/`, `audio/`, `levels/corridor/` (trừ `slots_layout.tscn`), `autoload/audio_manager.*`, `default_bus_layout.tres`, `ui/screens/tab_audio.tscn`, `ui/screens/tab_graphics.tscn`, `ui/screens/tab_accessibility.tscn`, `ui/theme/` | 2.1, 2.5, 2.6, 4.2, 4.4, 4.5 |

Các file dùng chung cần tạo Pull Request riêng khi sửa và có thể merge ngay lập tức:

| File | Lý do |
| --- | --- |
| `project.godot` | Quản lý Autoload, InputMap, Layer Names, Localization. Nếu vô tình sửa nhầm sẽ gây xung đột cho toàn bộ nhóm. |
| `autoload/event_bus.gd` | Danh sách signal toàn hệ thống. Việc thêm một signal mới tương đương với một Pull Request nhỏ. |
| `common/health_component.gd` | Thành phần được dùng chung bởi Commander, Enemy, Tower và Fortress. |
| `main.tscn` | Cây node gốc, chỉ thêm container khi thật sự cần thiết. |
| `README.md`, `CONTRIBUTING.md` | Tài liệu dự án của nhóm. |

Bạn có quyền tạo thư mục con mới bên trong thư mục cá nhân, nhưng hãy nhớ thêm file `.gdkeep`. Nếu muốn tạo thư mục mới ở cấp phân cấp cao nhất, hãy thảo luận và xin ý kiến của cả nhóm trước.

---

## 3. Cấu trúc thư mục và nội dung lưu trữ

```
res://
  autoload/        Chứa script và scene tự động nạp khi mở game ở dạng singleton. Chỉ đặt các file đã được khai báo trong Project Settings.
  common/          Chứa các lớp Resource và Component dùng chung cho dự án.
  data/            Chứa dữ liệu cân bằng game. Tuyệt đối không đặt file code tại đây.
    towers/        Chứa dữ liệu TowerData và TowerLevelData của Arrow, Cannon, Barricade dưới dạng đuôi .tres.
    enemies/       Chứa dữ liệu EnemyData của Grunt, Archer, Brute, Bulwark dưới dạng đuôi .tres.
    bosses/        Chứa dữ liệu BossData dưới dạng đuôi .tres.
    waves/         Chứa dữ liệu WaveTable dưới dạng đuôi .tres.
    config/        Cấu hình chung của game như fortress_stats.tres, scale_config.tres.
    locale/        Chứa file strings.csv quản lý chuỗi tiếng Việt với khóa được phân loại theo ngữ cảnh.
  entities/        Lưu trữ các thực thể trong game. Mỗi loại thực thể có một thư mục riêng chứa scene .tscn và script .gd tương ứng.
    commander/     Chứa nhân vật của người chơi.
    enemy/         Chứa scene gốc enemy.tscn cùng các biến thể kế thừa như grunt, archer, brute, bulwark.
    tower/         Chứa scene gốc tower.tscn cùng các biến thể kế thừa arrow, cannon, barricade.
    fortress/      Chứa thực thể thành chính.
    projectile/    Chứa đạn tấn công của người chơi và của địch.
  systems/         Chứa logic của các hệ thống không gắn liền với một thực thể cụ thể nào.
    time/          Quản lý thời gian x1, x2, x3 và chức năng Pause.
    nav/           Hệ thống thang xử lý tình trạng kẹt quân.
    wave/          Quản lý trạng thái và bộ sinh quân của từng đợt.
    run/           Quản lý tiến trình RunConfig, RunState, RunLoading và việc kết thúc Run.
    build/         Hệ thống quản lý vị trí, xây dựng, nâng cấp và bán tháp.
    economy/       Quản lý vàng, chi phí sửa thành và hệ thống điểm uy tín.
    save/          Hệ thống lưu trữ, đọc dữ liệu và khôi phục tiến trình chơi.
    tutorial/      Quản lý các thông báo hướng dẫn.
  levels/          Quản lý bản đồ game.
    corridor/      Gồm file level.tscn do TV5 quản lý và slots_layout.tscn do TV3 quản lý.
  ui/              Quản lý mọi giao diện hiển thị trên màn hình.
    hud/           Chứa file hud.tscn và thư mục con parts/ lưu trữ từng phần riêng biệt của HUD.
    panels/        Quản lý các Panel như Build, Tower, Priority, Fortress và bảng Wave preview.
    screens/       Quản lý các màn hình, hộp thoại, bảng cài đặt Settings và các tab.
    theme/         Giao diện Theme dùng chung toàn cục.
  contents/        Chứa asset thô như model 3D, sprite, texture do TV5 quản lý.
  art/             Chứa các hiệu ứng hình ảnh, shader và VFX được làm riêng cho game.
  audio/           Quản lý nhạc nền dưới dạng đuôi .ogg và hiệu ứng âm thanh dưới dạng đuôi .wav.
  tests/           Thư mục chứa scene hoặc script phục vụ mục đích kiểm thử.
  main.tscn        Cây gốc cốt lõi của game.

```

Quy tắc đặt tên file:

* File scene và script phải đặt cùng tên và nằm chung thư mục. Ví dụ, file `slot.tscn` phải đi kèm với `slot.gd`.
* Tên file sử dụng định dạng `snake_case`. Tên node và tên class sử dụng định dạng `PascalCase`.
* Không lưu trữ các asset như hình ảnh hoặc âm thanh trong thư mục `data/` hay `entities/`.

---

## 4. Quy ước làm việc với Godot

* **Sử dụng Group:** Áp dụng Group cho các nhóm đối tượng như commander, enemy, tower, fortress, slot. Khi cần gọi đối tượng, hãy dùng lệnh `get_tree().get_nodes_in_group("tên_nhóm")` thay vì tìm kiếm node thủ công theo đường dẫn.
* **Sử dụng Unique Name:** Đối với những node mà script cần truy cập thường xuyên, hãy click chuột phải, chọn tính năng Access as Unique Name và gọi trong code bằng cú pháp `%Tên`.
* **Hệ thống Collision layer:** Các lớp dùng cho 3D Physics được quy định cứng là layer 1 cho world, layer 2 cho commander, layer 3 cho enemy, layer 4 cho structure, layer 5 cho proj_player, layer 6 cho proj_enemy và layer 7 cho click. Tuyệt đối không thay đổi bảng quy định này.
* **Tạo Scene kế thừa:** Khi tạo các biến thể con như Grunt hoặc Arrow, hãy sử dụng tính năng New Inherited Scene từ scene gốc, sau đó chỉ chỉnh sửa các dữ liệu và đặc tính riêng biệt.
* **Sử dụng Make Unique:** Nếu một shape va chạm được dùng chung giữa nhiều instance, hãy nhấn nút Make Unique để đảm bảo mỗi đối tượng hoạt động độc lập và có shape riêng.
* **Tùy chỉnh InputMap:** Hãy thiết lập phím bằng Physical Keycode. Không gán thêm các phím 1, 2, 3 theo yêu cầu INP-09.
* **Xử lý thời gian:** Mọi logic gameplay phải sử dụng thời gian trong game thông qua hệ thống `TimeManager`. Tuyệt đối không dùng hàm `Time.get_ticks_msec()` cho thời gian hồi chiêu hoặc timer liên quan đến gameplay, vì sẽ gây sai sót logic khi người chơi tua nhanh thời gian bằng tốc độ x2 hoặc x3.
* **Ghi chú mã SRS:** Khi hoàn thành code đáp ứng một yêu cầu cụ thể, hãy ghi ID của yêu cầu đó vào comment hoặc nội dung commit, ví dụ như `# SELL-04`.

---

## 5. Quy trình làm việc với Git

### 5.1 Xử lý nhánh

Mỗi thành viên làm việc trên một nhánh riêng với tên nhánh được đặt theo cú pháp `week<n>/chu-de`:

```
week1/battle-cry
week1/wave-spawner
week3/cannon-tower
week4/hud-fortress-bar
week4/level-blockout

```

Mỗi nhánh chỉ phục vụ một chủ đề duy nhất và nên được hoàn thành nhanh chóng trong vài ngày. Sau khi code xong, hãy tạo Pull Request để gộp vào nhánh `main`.

### 5.2 Thao tác hằng ngày

```
git checkout main
git pull origin main
git checkout <target branch>
git rebase main          # hoặc: git merge main

```

Mỗi khi hoàn thành một phần việc nhỏ, hãy thực hiện commit, đẩy code lên nhánh và tạo Pull Request. Tuyệt đối không để dồn code cả tuần mới push lên một lần.

### 5.3 Pull Request

* Tiêu đề Pull Request phải tuân thủ quy ước đặt tên commit ở mục 6.
* Một Pull Request chỉ giải quyết một chủ đề duy nhất và giới hạn ở một vài file scene để dễ kiểm duyệt.
* Mỗi Pull Request cần ít nhất một thành viên khác xem xét duyệt lỗi. Nếu có thay đổi ở các file dùng chung như đã nêu tại mục 2, cần gắn tên người tạo ra file đó vào phần review.
* Sử dụng tính năng Squash and merge để giữ cho lịch sử commit của nhánh `main` gọn gàng. Tiêu đề khi squash sẽ lấy theo tiêu đề của Pull Request.
* Trước khi bấm tạo Pull Request, hãy đánh dấu hoàn thành danh sách sau:
* [ ] Nhấn F5 chạy `main.tscn` không xuất hiện lỗi báo đỏ.
* [ ] Nhấn F6 tại scene vừa chỉnh sửa không bị lỗi thiếu file.
* [ ] Đã lưu lại tất cả thay đổi bằng phím tắt Ctrl+Shift+S trong Godot.
* [ ] Chỉ chỉnh sửa file trong thư mục cá nhân hoặc đã thông báo trước với nhóm nếu phải sửa file của người khác.
* [ ] Đã commit đầy đủ các file đuôi `.uid` và `.import` mới được tạo ra.
* [ ] Đã dọn sạch các file rác như thư mục `.godot/`, file đuôi `*.tmp` hoặc các bản sao scene trùng lặp.



---

## 6. Quy ước viết commit

Sử dụng định dạng: `[loại]: <mô tả ngắn thay đổi trong phạm vi nào>`

```
[feat]: add Cannon level 1-3 for tower
[fix]: fix Archer's range
[data]: set budget wave 5 (3.7.6)
[ui]: add HP Fortress in hud

```

### Phân loại commit

| Loại | Áp dụng khi |
| --- | --- |
| `feat` | Thêm chức năng mới. |
| `fix` | Sửa lỗi. |
| `data` | Chỉnh số liệu cân bằng trong file `.tres` hoặc bảng CSV nhưng không làm thay đổi code. |
| `ui` | Thay đổi giao diện thông qua scene, bố cục, hoặc theme. |
| `art` | Thêm hoặc đổi model, sprite, shader, animation và VFX. |
| `audio` | Thêm hoặc đổi nhạc, SFX và kênh bus. |
| `level` | Điều chỉnh bản đồ, navmesh và vị trí slot. |
| `refactor` | Cải tổ lại cấu trúc code nhưng không làm thay đổi hành vi hoạt động. |
| `perf` | Tối ưu hóa hiệu năng game. |
| `test` | Thêm mới hoặc chỉnh sửa dữ liệu test. |
| `docs` | Thay đổi tài liệu dự án như README, CONTRIBUTING, hoặc các đoạn comment chú thích lớn. |
| `chore` | Xử lý các việc vặt như tinh chỉnh cấu hình, cập nhật `.gitignore` hoặc di chuyển file. |
| `revert` | Hoàn tác lại một commit đã tạo trước đó. |

### Phạm vi ảnh hưởng

Chọn phạm vi thay đổi dựa theo thư mục hoặc hệ thống mà bạn đang làm việc:

`commander`, `time`, `nav`, `tutorial`, `enemy`, `boss`, `wave`, `run`, `tower`, `fortress`, `projectile`, `build`, `economy`, `save`, `hud`, `panel`, `screen`, `settings`, `locale`, `audio`, `level`, `common`, `autoload`, `project`

### Quy tắc viết mô tả commit

* Viết commit bằng tiếng Anh, diễn đạt ngắn gọn.
* Sử dụng các động từ mang tính mệnh lệnh chủ động như thêm, sửa, bỏ, đổi, tách.
* Nếu commit giải quyết một yêu cầu cụ thể trong SRS, hãy ghi ID của yêu cầu đó ở cuối tiêu đề, ví dụ như mã NAV-06 hoặc tổ hợp mã SELL-02 và PNL-11.
* Mỗi commit chỉ giải quyết một vấn đề. Không gộp nhiều thay đổi khác nhau vào chung một commit, ví dụ như không viết chung việc thêm Cannon và sửa HUD.
* Nếu cần giải thích chi tiết, hãy xuống một dòng trống và viết mô tả vào phần thân commit. Cần tập trung giải thích lý do thực hiện thay đổi thay vì diễn giải lại đoạn code bằng văn bản.

### Ví dụ so sánh đúng và sai

| Đúng | Sai |
| --- | --- |
| `[feat]: add Dodge with Iframe = 0.3s (CMB-06)` | `update code` |
| `[fix]: fix double add gold` | `fix bug` |
| `[data]: update Arrow dmg from 12 to 10` | `change num` |
| `[refactor]: split spawner from wave manager` | `changed many things` |
| `[chore]: Update input map to add action dodge` | `some changes` |
| `[doc]: Update comments in <file> ` | `comments` |
---

## 7. Xử lý và phòng tránh xung đột trong Godot

Xung đột dữ liệu trong Godot chủ yếu xuất phát từ file `.tscn` và `project.godot`.

**Những điều cần làm:**

* Chia các scene lớn thành nhiều sub-scene nhỏ gọn. Hiện tại dự án đã áp dụng cách này với các phần HUD, Settings và Level. Nhờ vậy, hai người cùng sửa hai sub-scene khác nhau sẽ không gây xung đột.
* Luôn sử dụng tính năng Inherited Scene khi cần tạo ra các biến thể mới. Tuyệt đối không copy paste trực tiếp nguyên bản scene.
* Chỉ mở scene do người khác quản lý với mục đích xem tham khảo. Nếu lỡ tay mở chỉnh sửa thì phải đóng lại ngay và không được lưu.
* Thực hiện commit file `.tscn` ngay lập tức sau khi hoàn tất một thay đổi nhỏ, tránh tình trạng để dồn việc.
* Chỉ di chuyển hoặc thay đổi tên file bên trong bảng FileSystem của giao diện Godot để hệ thống tự động cập nhật lại đường dẫn an toàn cho toàn bộ dự án.

**Những điều tuyệt đối tránh:**

* Tránh sắp xếp lại thứ tự hoặc thay đổi tên hàng loạt các node khi không thật sự cần thiết.
* Không ấn nút Reimport hoặc thay đổi cài đặt thông số import của những asset không thuộc quyền quản lý của mình.
* Không đẩy thư mục `.godot/` lên kho chứa code chung.
* Không tự ý chỉnh sửa file `project.godot` trong các nhánh tính năng phụ. Như đã đề cập ở mục 2, việc sửa đổi file này phải được thông qua một Pull Request độc lập.

**Cách giải quyết khi bị conflict trong file `.tscn`:**

1. Không tự ý gỡ bỏ marker `<<<<<<<` bằng phương pháp thủ công trên file text của scene.
2. Sử dụng lệnh `git checkout --theirs` hoặc `--ours` để chọn lấy toàn bộ phiên bản code đúng đắn nhất và kiểm tra lại cẩn thận. Sau đó, tiến hành làm lại phần thay đổi của riêng bạn thông qua giao diện phần mềm Godot.
3. Mở lại scene bằng Godot và bấm F6 để kiểm tra. Chỉ tiến hành commit khi mọi thứ đã chạy hoàn toàn ổn định.

Nếu xảy ra xung đột ở các file quan trọng như `project.godot` hoặc `event_bus.gd`, bạn phải tiến hành gộp thủ công thật cẩn thận bằng cách thêm dòng và giữ lại code của cả hai bên. Sau khi thao tác xong, cần nhờ người khởi tạo file kiểm tra kỹ lưỡng lại một lần nữa.

---

## 8. Thống nhất công việc giữa các thành viên

Các nhóm công việc có tính phụ thuộc lẫn nhau cần phải thống nhất giao thức chung trước khi bắt tay vào code:

| Các vai kết hợp | Mục tiêu cần thống nhất | Thời gian hoàn thành |
| --- | --- | --- |
| TV3 và TV4 | API phục vụ việc xây dựng, nâng cấp, bán và các signal như `tower_built`, `tower_sold`, `gold_changed`. | Đầu tuần 3 |
| TV2 và TV3 | Tính năng `AttackSlot` của thành Fortress, Barricade, tower cùng biến `nav_progress` di chuyển của quân địch. | Tuần 4 |
| TV2 và TV3 | Cơ chế đồng hồ boss, hệ thống Overload và các pha tạo giáp của boss Bulwark. | Đầu tuần 5. Đây là mốc rủi ro cao nhất rơi vào tuần 6-7. |
| TV1 và TV2 | Hệ thống thang xử lý kẹt quân nằm tại `systems/nav` và cách tương tác với boss. | Tuần 7 |
| TV4 và TV5 | Các thành phần thiết kế như Theme, bộ biểu tượng icon set và skin UI. | Tuần 5 |
| TV3 và TV5 | Vị trí bố trí 14 slot và cấu trúc hình dạng bản đồ map. | Tuần 3 |

Nếu cần thêm signal mới vào hệ thống EventBus, hãy tạo một Pull Request chuyên biệt chỉ chứa duy nhất dòng code thêm signal đó. Cần ghi chú thật rõ ràng về tên tín hiệu, các tham số đi kèm, đối tượng phát tín hiệu và đối tượng nhận tín hiệu.

---

## 9. Mốc thời gian dự án theo SRS 7.3

Hãy tham khảo bảng phân công để biết lịch trình chi tiết của từng thành viên. Dưới đây là các cột mốc dự án chung cần đạt:

| Tuần làm việc | Mục tiêu cần hoàn thành |
| --- | --- |
| Tuần 1 | Cài đặt repo chung, chốt quy ước thiết kế scene, thiết lập EventBus, GameConfig, nhúng font tiếng Việt, xử lý camera và logic di chuyển. |
| Tuần 2 | Hoàn thiện Vertical slice cơ bản bao gồm người chơi có thể đánh 1 quân, xây 1 tháp bắn được và luồng chạy của 1 đợt lính wave. |
| Tuần 3 | Hoàn thành 14 vị trí slot, 3 loại tháp cơ bản, các loại địch Grunt, Archer, Brute và chu trình xây dựng cơ bản. |
| Tuần 4 | Thiết lập logic Targeting ngắm bắn, AttackSlot, hệ thống sinh quân wave, TimeManager và panel quản lý Tower. |
| Tuần 5 | Xây dựng chế độ Commander mode, kịch bản wave quân đầy đủ, hệ thống vàng thưởng quân và tính năng sửa chữa Fortress. |
| Tuần 6 | Cập nhật hệ thống Emergency repair, kiểm thử kỹ luồng time scale x1, x2, x3 và dựng khung thiết kế boss. |
| Tuần 7 | **Cột mốc bắt buộc:** Game phải chạy trơn tru từ đợt wave 1 đến khi tiêu diệt xong con boss đầu tiên. |
| Tuần 8 | Xây dựng hệ thống Meta shop, quy trình RunLoading, logic kết thúc Run và tạo thang chống kẹt quân MVP. |
| Tuần 9 | Bổ sung kỹ năng Barrage, màn hình RunEnd, bảng Settings, hướng dẫn tutorial, hệ thống khôi phục trạng thái run và cho chạy thử playtest nội bộ nhóm. |
| Tuần 10 | Giai đoạn đóng băng tính năng để tập trung toàn lực vào kiểm thử bug, cân bằng lại số liệu cuối cùng, build xuất game chuẩn, làm báo cáo và quay video demo. |

Nếu tiến độ bị trễ so với cột mốc tuần 7, nhóm sẽ ngừng phát triển toàn bộ các hạng mục không bắt buộc. Đồng thời, nhóm sẽ cân nhắc cắt giảm thêm các tính năng như kỹ năng Barrage, rút gọn phần hướng dẫn tutorial và thu gọn bảng cài đặt Settings dựa theo hướng dẫn xử lý khủng hoảng tại mục 17 thuộc Phụ lục C của tài liệu SRS.

---

## 10. Quản lý asset ngoài và bản quyền license

Bất kỳ asset nào lấy từ nguồn bên ngoài đều phải được ghi danh ngay lập tức vào bảng quản lý của file `README.md`, bao gồm thông tin về tên asset, nguồn gốc, giấy phép sử dụng license và các ghi chú liên quan. Việc thiếu sót trong ghi chép sẽ gây khó khăn lớn cho việc truy xuất lại thông tin vào cuối kỳ học, đặc biệt là khi khâu báo cáo dự án bắt buộc yêu cầu một danh sách liệt kê license minh bạch.

---

## 11. Các hành vi tuyệt đối nghiêm cấm

* Đẩy code thẳng lên nhánh `main`.
* Tiến hành commit thư mục `.godot/`, các file định dạng build gốc, hoặc bản nén zip chứa các asset.
* Chỉnh sửa file nằm trong thư mục của người khác quản lý mà không báo trước.
* Hard-code chuỗi văn bản tiếng Việt trực tiếp vào code hoặc file scene.
* Viết cứng các số liệu cân bằng chiến đấu trực tiếp vào bên trong script.
* Push code khi phần Output của Godot vẫn còn báo lỗi màu đỏ.
* Thay đổi tên file hoặc di chuyển vị trí file bằng Windows Explorer thay vì trình quản lý của Godot.

Nếu có bất kỳ thắc mắc nào liên quan đến cấu trúc dự án, ranh giới quyền quản lý file hay các yêu cầu của tài liệu SRS, hãy chủ động thảo luận và hỏi ý kiến nhóm trước khi tự mình đưa ra quyết định.