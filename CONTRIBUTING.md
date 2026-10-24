# Hướng dẫn làm việc nhóm

Tài liệu này dành cho 5 thành viên của dự án Chiến Tuyến Vô Tận (Endless War), sử dụng Godot 4 với đồ họa 3D và góc máy orthographic isometric. Vui lòng đọc kỹ toàn bộ nội dung trước khi bắt đầu viết code. Mọi yêu cầu chức năng đều nằm trong tài liệu **SRS-EW v1.9**.

---

## 1. Nguyên tắc cốt lõi

1. **Mỗi người quản lý một thư mục riêng biệt.** Chỉ chỉnh sửa file trong phạm vi công việc của mình. Nếu cần thay đổi file của người khác, bạn được phép sửa trực tiếp trong Pull Request của mình, chỉ cần tag tên người sở hữu để họ biết. Việc tag chỉ để thông báo, không cần họ approve hay review mới được merge.
2. **Tách biệt dữ liệu khỏi code.** Các chỉ số như máu, giá tiền, tầm bắn, thời gian hồi chiêu phải được lưu trong file Resource `.tres` tại thư mục `data/`. Tuyệt đối không hard-code các giá trị này trực tiếp vào script, tuân theo yêu cầu từ mục 2.5 và 6.1 của SRS. Số liệu skill của chỉ huy (SKL) nằm trong `data/skills/`.
3. **Sử dụng `EventBus` để giao tiếp.** Các hệ thống không được gọi trực tiếp node của nhau. Ví dụ, HUD chỉ nhận tín hiệu thay vì đọc trực tiếp dữ liệu từ node gameplay theo yêu cầu UI-04.
4. **Sử dụng hàm `tr("khoa")` cho mọi văn bản hiển thị.** Các khóa này được khai báo trong file `data/locale/strings.csv`. Tuyệt đối không viết cứng tiếng Việt trực tiếp vào scene hoặc script, tuân thủ yêu cầu LOC-01 và LOC-05.
5. **Không đẩy code trực tiếp lên nhánh `main`.** Mọi thay đổi đều phải được thực hiện trên nhánh phụ và đưa qua quá trình Pull Request.
6. **Đảm bảo game chạy ổn định trước khi push code.** Nhấn F5 không xuất hiện lỗi đỏ và nhấn F6 tại scene đang làm việc không bị báo lỗi thiếu file.

---

## 2. Ai làm gì, thư mục nào

Dự án gồm năm vai trò dựa theo Phụ lục B của tài liệu SRS và đã được điều chỉnh để cân bằng khối lượng công việc.

| Vai | Phụ trách | Thư mục sở hữu | Mục SRS chính |
| --- | --- | --- | --- |
| **TV1 - Player & Combat** | Chỉ huy, chiến đấu, Commander mode, Recall và Deploy, Aura Tiền tuyến, SkillRunner và StatBlock, nội dung skill, thời gian (TimeManager), kênh hồi máu `heal_channel` (phím E), tutorial, **phía máy chủ** của tài khoản và bảng xếp hạng | `entities/commander/`, `systems/time/`, `systems/tutorial/`, `systems/skill/`, `data/skills/`, `common/stat_block.gd`, `autoload/time_manager.gd`, `backend/` | 3.4 (trừ TIME-06), 3.5 (gồm 3.5.10, 3.5.12), 3.6.6 (HLT-03..06, HLT-14), 3.8.1, 3.13 và 3.14 (phía máy chủ, ACCT-10), 4.7 |
| **TV2 - Enemy & Wave** | Quân địch, boss Bulwark và Cuồng nộ, sinh wave, scale, XpTracker (XP, cờ `hit_by_commander`), RunConfig và kết thúc Run, thang chống kẹt (NAV), TIME-06 tự hạ x2, quân nhắm Trạm hồi lực theo bảng ETG | `entities/enemy/`, `systems/wave/`, `systems/run/`, `systems/xp/`, `systems/nav/`, `data/enemies/`, `data/bosses/`, `data/waves/`, `common/enemy_data.gd`, `common/boss_data.gd`, `common/wave_table.gd`, `common/wave_group.gd`, `common/scale_config.gd`, `autoload/game_config.gd` | 3.2, 3.3, 3.4 (TIME-06), 3.5.11, 3.7 (gồm 3.7.4), 3.8.2-3.8.4, 3.8.6, 3.8.10, 3.11.2 |
| **TV3 - Tower & Build** | Tower, Fortress, Slot và GroundGrid, đạn, xây dựng, cổng cấp tower theo cấp Chỉ huy, kinh tế, đồng hồ boss và Cuồng nộ, RewardOfferGenerator và SkillData schema, **Trạm hồi lực** (thực thể tower thứ 4, kho HP, RUINED), save và `SaveRepository` | `entities/tower/` (gồm `heal_station`), `entities/fortress/`, `entities/projectile/`, `systems/build/`, `systems/economy/`, `systems/reward/`, `systems/save/`, `data/towers/`, `data/config/`, `common/tower_data.gd`, `common/tower_level_data.gd`, `common/fortress_stats.gd`, `common/slot_zone.gd`, `common/skill_data.gd`, `common/run_skill_state.gd`, `levels/corridor/slots_layout.tscn`, `autoload/save_manager.gd` | 3.3.6, 3.6 (gồm 3.6.6, trừ HLT-03..06), 3.8.5, 3.8.7, 3.8.9, 3.9, 3.10.1, 3.12, ACCT-01, ACCT-04, ACCT-06 |
| **TV4 - UI/UX & Meta** | HUD (gồm thanh XP, ô skill, HUD-18 trạng thái Trạm hồi lực), panel (gồm PNL-14), màn RewardPick, màn hình, hộp thoại, meta shop 4 mục, Settings, flow, ngôn ngữ, **phía client online**: màn Login, Leaderboard, tab Tài khoản, `SyncService` | `ui/` (trừ các tab của TV5), `systems/sync/`, `data/locale/`, `autoload/game_state.gd`, `autoload/screen_manager.*` | 3.1, 3.3.6 (phần giao diện), 3.10, 3.13 và 3.14 (phía client), 4.1, 4.3, 4.6, 5.3 |
| **TV5 - Art/Level/Audio** | Map và GridData, **camera (CAM, CameraRig)**, model (gồm Trạm hồi lực), animation, VFX (gồm vòng sáng Aura, VFX skill, VFX Trạm hồi lực), shader, âm thanh, accessibility, playtest | `contents/`, `art/`, `audio/`, `levels/corridor/` (trừ `slots_layout.tscn`), `systems/camera/`, `autoload/audio_manager.*`, `default_bus_layout.tres`, `ui/screens/tab_audio.tscn`, `ui/screens/tab_graphics.tscn`, `ui/screens/tab_accessibility.tscn`, `ui/theme/` | 2.1, 2.5, 2.6, 4.2 (gồm 4.2.3), 4.4, 4.5 |

Ghi chú về ranh giới: `SkillData` là Resource do TV3 định nghĩa schema (`common/skill_data.gd`), còn file `.tres` số liệu từng skill trong `data/skills/` do TV1 điền. Riêng cờ `hit_by_commander` nằm trong `DamageInfo` và `HealthComponent` (file dùng chung), do TV2 đề xuất và TV1 review. Settings ở bản MVP có 4 tab (Âm thanh, Đồ họa, Tiếp cận, Tài khoản). Tab Điều khiển chỉ đọc, tab Dữ liệu và tab Gameplay là `[Should]`. Cờ `heal_*` của Trạm hồi lực nằm trong `GameConfig` (TV2 sở hữu file) và `TowerData` (TV3), TV3 đề xuất giá trị. Thư mục `backend/` là thư mục mới ở cấp cao nhất, đã nằm trong phân công v3 nhưng vẫn cần cả nhóm xác nhận theo quy định ở cuối mục này. Các thư mục `systems/camera/` và `systems/sync/` cũng là thư mục mới, người sở hữu tạo kèm `.gdkeep`.

Các file dùng chung dưới đây dễ gây xung đột cho cả nhóm. Thay đổi nhỏ gắn liền với tính năng đang làm (một dòng Autoload, một signal, một action InputMap) được phép nằm chung Pull Request của tính năng đó, miễn là ghi rõ trong mô tả và tag người sở hữu. Chỉ tách thành Pull Request riêng, merge ngay, khi thay đổi lớn hoặc không thuộc tính năng nào:

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
    towers/        Chứa dữ liệu TowerData và TowerLevelData của Arrow, Cannon, Barricade và Trạm hồi lực (1 cấp, HP kho 300, giá 80) dưới dạng đuôi .tres.
    enemies/       Chứa dữ liệu EnemyData của Grunt, Archer, Brute, Bulwark dưới dạng đuôi .tres.
    bosses/        Chứa dữ liệu BossData dưới dạng đuôi .tres.
    waves/         Chứa dữ liệu WaveTable dưới dạng đuôi .tres.
    config/        Cấu hình chung của game như fortress_stats.tres, scale_config.tres.
    skills/        Chứa dữ liệu SkillData (Whirlwind, Sword Wave, Firebomb, 4 bị động gồm Sharpness, Armored, Lifesteal và Trạm hồi lực, 2 thẻ stat Thể lực và Tinh thông) dưới dạng đuôi .tres.
    locale/        Chứa file strings.csv quản lý chuỗi tiếng Việt với khóa được phân loại theo ngữ cảnh.
  entities/        Lưu trữ các thực thể trong game. Mỗi loại thực thể có một thư mục riêng chứa scene .tscn và script .gd tương ứng.
    commander/     Chứa nhân vật của người chơi.
    enemy/         Chứa scene gốc enemy.tscn cùng các biến thể kế thừa như grunt, archer, brute, bulwark.
    tower/         Chứa scene gốc tower.tscn cùng các biến thể kế thừa arrow, cannon, barricade, heal_station.
    fortress/      Chứa thực thể thành chính.
    projectile/    Chứa đạn tấn công của người chơi và của địch.
  systems/         Chứa logic của các hệ thống không gắn liền với một thực thể cụ thể nào.
    time/          Quản lý thời gian x1, x2, x3 và chức năng Pause.
    nav/           Hệ thống thang xử lý tình trạng kẹt quân (TV2 sở hữu).
    wave/          Quản lý trạng thái và bộ sinh quân của từng đợt.
    run/           Quản lý tiến trình RunConfig, RunState, RunLoading và việc kết thúc Run.
    build/         Hệ thống quản lý vị trí, xây dựng, nâng cấp và bán tháp.
    economy/       Quản lý vàng, chi phí sửa thành và hệ thống điểm uy tín.
    save/          Hệ thống lưu trữ, đọc dữ liệu và khôi phục tiến trình chơi, gồm SaveRepository và LocalSaveRepository.
    tutorial/      Quản lý các thông báo hướng dẫn.
    camera/        CameraRig: Frontline bám nhân vật, Commander và PREP dịch bằng WASD trong camera_bounds, BOSS_INTRO (TV5 sở hữu).
    sync/          SyncService: kéo và đẩy profile, meta, flags với backend, không chặn UI (TV4 sở hữu).
    skill/         SkillRunner (phím 1-3, ô, cooldown) và StatBlock của chỉ huy.
    xp/            XpTracker: XP theo cờ hit_by_commander, cấp Chỉ huy, lượt chọn chờ.
    reward/        RewardOfferGenerator (hàm thuần, test bằng GUT) và apply_pick cho màn REWARD_PICK.
  levels/          Quản lý bản đồ game.
    corridor/      Gồm file level.tscn do TV5 quản lý và slots_layout.tscn do TV3 quản lý.
  ui/              Quản lý mọi giao diện hiển thị trên màn hình.
    hud/           Chứa file hud.tscn và thư mục con parts/ lưu trữ từng phần riêng biệt của HUD.
    panels/        Quản lý các Panel như Build, Tower, Priority và Fortress. Bảng Wave preview là [Should].
    screens/       Quản lý các màn hình (gồm RewardPick), hộp thoại, bảng cài đặt Settings và các tab.
    theme/         Giao diện Theme dùng chung toàn cục.
  contents/        Chứa asset thô như model 3D, sprite, texture do TV5 quản lý.
  art/             Chứa các hiệu ứng hình ảnh, shader và VFX được làm riêng cho game.
  audio/           Quản lý nhạc nền dưới dạng đuôi .ogg và hiệu ứng âm thanh dưới dạng đuôi .wav.
  tests/           Thư mục chứa scene hoặc script phục vụ mục đích kiểm thử.
  backend/         Mã và cấu hình phía máy chủ (BaaS): bảng dữ liệu, phân quyền, hướng dẫn API. Chỉ chứa khóa công khai, không bao giờ chứa khóa quản trị (TV1 sở hữu).
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
* **Tùy chỉnh InputMap:** Hãy thiết lập phím bằng Physical Keycode. Phím số 1, 2, 3 là skill chủ động (SKL-05) và tua tốc độ không có phím tắt (INP-06). Phím E là `heal_channel` (giữ để hồi máu ở Trạm hồi lực), phím C là `camera_recenter`. WASD chỉ có một nghĩa trong mỗi ngữ cảnh: di chuyển nhân vật ở Frontline, dịch camera ở Commander và PREP (CAM-10). Mọi action dùng phím vật lý theo INP-09.
* **Xử lý thời gian:** Mọi logic gameplay phải sử dụng thời gian trong game thông qua hệ thống `TimeManager`. Tuyệt đối không dùng hàm `Time.get_ticks_msec()` cho thời gian hồi chiêu hoặc timer liên quan đến gameplay, vì sẽ gây sai sót logic khi người chơi tua nhanh thời gian bằng tốc độ x2 hoặc x3.
* **Sát thương và XP:** Mọi nguồn sát thương, kể cả skill và vùng cháy theo tick, phải đi qua `HealthComponent` với `DamageInfo` có `damage_type` và `source` để cờ `hit_by_commander` hoạt động (XP-03, CMB-10). Không trừ máu trực tiếp.
* **Ngẫu nhiên có seed:** Mọi RNG gameplay (sinh wave, thẻ REWARD_PICK) dùng `run_seed` theo RWP-05 và SPN-05. Không gọi `randi()` toàn cục trong logic gameplay để test và replay tái hiện được.
* **Lưu và mạng:** Mọi đọc ghi tiến trình đi qua `SaveRepository` (ACCT-01), không gọi thẳng `FileAccess` cho save. Các lệnh gọi mạng chạy bất đồng bộ, không chặn UI quá 100 ms và mất mạng không được làm chậm RunEnd hay cửa hàng (ACP-08). Token đăng nhập lưu ở `auth.cfg` riêng, không bao giờ nằm trong `endlesswar_save.json`.
* **Bí mật:** Không commit `auth.cfg`, khóa quản trị hay mật khẩu của backend. Trong repo chỉ có khóa công khai của dự án BaaS. Thêm `auth.cfg` vào `.gitignore`.
* **Hồi máu chỉ huy:** Không còn hồi tự động theo giây ở Commander mode. Chỉ huy hồi 35% HP tối đa khi vào PREP (`prep_heal_pct`) và qua Trạm hồi lực. Không thêm `commander_regen_pct_per_sec` trở lại.

---

## 5. Quy trình làm việc với Git

### 5.1 Xử lý nhánh

Mỗi thành viên làm việc trên một nhánh riêng với tên nhánh được đặt theo cú pháp `week<n>/chu-de`:

```
week6/time-manager
week7/xp-tracker
week8/skill-runner
week9/reward-pick-screen
week10/save-atomic

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
* Mỗi Pull Request cần ít nhất một thành viên khác xem xét duyệt lỗi. Nếu có thay đổi ở file dùng chung hoặc thư mục của người khác như đã nêu tại mục 2, gắn tên người sở hữu vào mô tả để thông báo, không cần họ approve.
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

`commander`, `skill`, `xp`, `reward`, `time`, `nav`, `camera`, `heal`, `backend`, `sync`, `tutorial`, `enemy`, `boss`, `wave`, `run`, `tower`, `fortress`, `projectile`, `build`, `economy`, `save`, `hud`, `panel`, `screen`, `settings`, `locale`, `audio`, `level`, `common`, `autoload`, `project`

### Quy tắc viết mô tả commit

* Viết commit bằng tiếng Anh, diễn đạt ngắn gọn.
* Sử dụng các động từ mang tính mệnh lệnh chủ động như thêm, sửa, bỏ, đổi, tách.
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
| `[docs]: Update comments in <file> ` | `comments` |
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
| TV2 và TV1 | Cờ `hit_by_commander` trong `DamageInfo` và `HealthComponent` (XP-01, XP-03), nguồn sát thương của skill. | Tuần 6 |
| TV3 và TV1 | `Aura Tiền tuyến`: cờ `aura_active`, `dealt_mult` cộng thêm (FRT-01, DMG-06). | Tuần 6 |
| TV3, TV1, TV4 | Schema `SkillData`, `RunSkillState` và các signal EVB-26..31 (`xp_changed`, `level_up`, `reward_picked`, `skill_slots_changed`). | Cuối tuần 7 |
| TV2 và TV3 | Đồng hồ boss, Cuồng nộ (ENR-01..06) và các pha giáp của Bulwark. | Đầu tuần 8. Rủi ro cao nhất, nằm trên đường găng của mốc B1. |
| TV3, TV2, TV4 | Luồng REWARD_PICK: state trong Wave FSM (TV2), RewardOfferGenerator và `apply_pick` (TV3), màn RewardPick (TV4). | Đầu tuần 8 chốt chữ ký hàm, nối đầy đủ ở tuần 9 |
| TV3 và TV4 | API xây, nâng, bán và cổng cấp tower (`can_upgrade`, UPG-06), signal `tower_built`, `tower_sold`, `gold_changed`. | Đã chốt ở tuần 3, bổ sung cổng cấp ở tuần 7 |
| TV2 và TV3 | Thang xử lý kẹt quân tại `systems/nav` (TV2 viết, TV3 review phần Barricade và tower) và cách tương tác với boss (BOSS-04 rút gọn). | Tuần 9, bản MVP đầy đủ ở tuần 10 |
| TV4 và TV5 | Theme, bộ icon set (gồm icon skill và icon Trạm hồi lực) và skin UI. | Tuần 7-8, skin hoàn chỉnh tuần 10 |
| TV1, TV3, TV4, TV5, TV2 | **Trạm hồi lực**: lõi `heal_channel` với trạm giả (TV1, tuần 6), mesh tạm (TV5, tuần 6), dữ liệu `TowerData` và `GameConfig` (TV3, tuần 6), HUD-18 với tín hiệu giả (TV4, tuần 6), quân nhắm trạm theo ETG (TV2, tuần 6). Thực thể tower thật và panel PNL-14 ở tuần 8, nối lõi với trạm thật và chuẩn hóa sát thương ở tuần 10 (W10-NG7, W10-MH5). | Tuần 6 đến tuần 10. Chốt EVB-33, EVB-34 trước khi nối |
| TV1, TV4, TV3 | **Online**: backend một lần ở tuần 6 (TV1), màn Login chạy thật ở tuần 8 (TV4), `SaveRepository` ở tuần 6 (TV3). API đồng bộ và bảng xếp hạng ở tuần 10 (TV1), `SyncService` và hook nộp điểm ở tuần 11 (TV4, TV3). TV1 viết tài liệu API một trang trước tuần 11. | Tuần 6 chốt hợp đồng API, tuần 11 nối đầy đủ |
| TV5 và TV1 | **Camera**: `camera_bounds` và size camera trên map thật (TV5), InputMap `camera_recenter` và WASD theo ngữ cảnh (TV1), signal `camera_frame_changed` (EVB-35). | Tuần 6 chốt, camera chạy ở tuần 7 |

Nếu cần thêm signal mới vào hệ thống EventBus, hãy tạo một Pull Request chuyên biệt chỉ chứa duy nhất dòng code thêm signal đó. Cần ghi chú thật rõ ràng về tên tín hiệu, các tham số đi kèm, đối tượng phát tín hiệu và đối tượng nhận tín hiệu.

---

## 9. Mốc thời gian dự án theo SRS 7.3

Hãy tham khảo file bảng phân công (`Bang_phan_cong_v3`) để biết chi tiết từng người. Tuần 1-5 đã hoàn thành. Tuần 7-9 và tuần 13 mỗi người 2 phiên (12 giờ), tuần 10-12 mỗi người 3 phiên (khoảng 18 giờ). Tuần 6 có việc kéo sớm cho người đã xong phần cũ. Các cột mốc chung:

| Tuần làm việc | Mục tiêu cần hoàn thành |
| --- | --- |
| Tuần 6 (19-25/10) | Họp chốt SRS v1.9 và bảng phân công v3. TimeManager, input edge, chết và hồi (prep_heal 35%, bỏ regen), sinh wave theo bảng, targeting, AttackSlot, Aura Tiền tuyến, panel Tower, thanh máu quân. Kéo sớm: lõi `heal_channel` với trạm giả, backend xác thực, `SaveRepository`, `camera_bounds`, HUD-18, bố cục màn Login. |
| Tuần 7 (26/10-1/11) | **Mốc A:** vòng lặp wave PREP-COMBAT-SUMMARY chơi được wave 1-4, có Commander mode, xây, nâng, bán, XP và Cấp Chỉ huy hiển thị, camera Frontline và Commander. |
| Tuần 8 (2-8/11) | SkillRunner và Whirlwind, RewardOfferGenerator, cổng cấp tower, kinh tế gold, HUD đủ vùng, Crowd, khung Bulwark, Trạm hồi lực phần Tower và panel PNL-14, màn Login nối backend. |
| Tuần 9 (9-15/11) | **Mốc B1:** chơi đến hết Bulwark đầu, nhặt được 3 skill chủ động qua REWARD_PICK, Cuồng nộ chạy. |
| Tuần 10 (16-22/11) | **Mốc B2:** vòng skill hoàn chỉnh (4 bị động, 2 thẻ stat), RunConfig và RunState, save atomic, Meta shop 4 mục, RunEnd, thang kẹt MVP, nối lõi hồi máu với Trạm hồi lực thật, API đồng bộ và bảng xếp hạng. |
| Tuần 11 (23-29/11) | **Đóng băng gameplay 29/11.** Tutorial rút gọn, Settings, khôi phục run gián đoạn, `SyncService` và nộp điểm, cân bằng lần 1, playtest ngoài nhóm. |
| Tuần 12 (30/11-6/12) | **Đóng băng toàn bộ tính năng 6/12.** Hoàn thiện online, test AC1..AC8, chạy checklist 7.1 (gồm CM, HT, AC), cân bằng cuối, build Windows. |
| Tuần 13 (7-14/12) | Chỉ test, sửa lỗi, báo cáo và video demo. 14/12 đóng băng bản nộp, 15 và 16/12 dự phòng, **17/12 diễn tập.** |

Barrage, di chuyển tower, Gameplay tab trong Settings và các mục `[Should]` khác chỉ làm khi MVP xong sớm.

Nếu tiến độ trễ hơn mốc B1 quá 2 ngày hoặc một người nghỉ cả tuần, nhóm dừng toàn bộ hạng mục không bắt buộc và cắt theo thứ tự ở Phụ lục C mục 17 của SRS: Firebomb, edge-pan và look-ahead camera, HLT-12, bảng xếp hạng, rồi đồng bộ tài khoản. Các mục cắt cũ (Reroll, ducking, tab Dữ liệu và Điều khiển, TUT-04/05, thẻ Bền thành, Focus, Lightstep) đã chuyển sang `[Should]` từ v1.9. **Không cắt** Aura Tiền tuyến, gold chỉ huy, XP, cổng cấp tower, Cuồng nộ và save atomic. Online chỉ bị cắt khi vẫn trễ sau mốc B2.

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
* Commit `auth.cfg`, khóa quản trị hoặc mật khẩu backend lên kho chứa code.
* Push code khi phần Output của Godot vẫn còn báo lỗi màu đỏ.
* Thay đổi tên file hoặc di chuyển vị trí file bằng Windows Explorer thay vì trình quản lý của Godot.
* Thêm mã liên quan đến tài liệu SRS trong comment của code vì tài liệu này có thể bị thay đổi thường xuyên

Nếu có bất kỳ thắc mắc nào liên quan đến cấu trúc dự án, ranh giới quyền quản lý file hay các yêu cầu của tài liệu SRS, hãy chủ động thảo luận và hỏi ý kiến nhóm trước khi tự mình đưa ra quyết định.