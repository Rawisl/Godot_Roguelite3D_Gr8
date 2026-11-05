# Hướng dẫn làm việc nhóm

Tài liệu này dành cho 5 thành viên của dự án Chiến Tuyến Vô Tận (Endless War), sử dụng Godot 4 với đồ họa 3D và góc máy orthographic isometric. Vui lòng đọc kỹ toàn bộ nội dung trước khi bắt đầu viết code. Mọi yêu cầu chức năng đều nằm trong tài liệu **SRS-EW v2.0** (`SRS_Endless_War_v2.0.md`). Việc ai làm gì, thư mục nào của ai, lịch từng tuần và các mốc tích hợp nằm ở `PHAN_CONG.md` (bản bảng tính của nhóm là `Bang_phan_cong_v2.0.xlsx`).

---

## 1. Nguyên tắc cốt lõi

1. **Mỗi người quản lý một thư mục riêng biệt.** Chỉ chỉnh sửa file trong phạm vi công việc của mình. Nếu cần thay đổi file của người khác, bạn được phép sửa trực tiếp trong Pull Request của mình, chỉ cần tag tên người sở hữu để họ biết. Việc tag chỉ để thông báo, không cần họ approve hay review mới được merge.
2. **Tách biệt dữ liệu khỏi code.** Các chỉ số như máu, giá tiền, tầm bắn, thời gian hồi chiêu phải được lưu trong file Resource `.tres` tại thư mục `data/`. Tuyệt đối không hard-code các giá trị này trực tiếp vào script, tuân theo yêu cầu từ mục 2.5 và 6.1 của SRS. Số liệu skill của chỉ huy (SKL) nằm trong `data/skills/`.
3. **Sử dụng `EventBus` để giao tiếp.** Các hệ thống không được gọi trực tiếp node của nhau. Ví dụ, HUD chỉ nhận tín hiệu thay vì đọc trực tiếp dữ liệu từ node gameplay theo yêu cầu UI-04.
4. **Sử dụng hàm `tr("khoa")` cho mọi văn bản hiển thị.** Các khóa này được khai báo trong file `data/locale/strings.csv`. Tuyệt đối không viết cứng tiếng Việt trực tiếp vào scene hoặc script, tuân thủ yêu cầu LOC-01 và LOC-05.
5. **Không đẩy code trực tiếp lên nhánh `main`.** Mọi thay đổi đều phải được thực hiện trên nhánh phụ và đưa qua quá trình Pull Request.
6. **Đảm bảo game chạy ổn định trước khi push code.** Nhấn F5 không xuất hiện lỗi đỏ và nhấn F6 tại scene đang làm việc không bị báo lỗi thiếu file.

---

## 2. Quyền sở hữu thư mục và file dùng chung

Mỗi thư mục có một người sở hữu. Bảng người, vai và thư mục sở hữu nằm ở `PHAN_CONG.md` (mục 2) và được cập nhật cùng bảng phân công mỗi khi nhóm đổi người. Hai điểm cần nhớ:

* `SkillData` là Resource do người sở hữu `systems/reward/` định nghĩa schema (`common/skill_data.gd`), còn số liệu từng skill trong `data/skills/` do người sở hữu `systems/skill/` điền (và từ v2.0 được sinh từ bảng cân bằng). Cờ `hit_by_commander` nằm trong `DamageInfo` và `HealthComponent` (file dùng chung).
* Từ v2.0, số liệu cân bằng của nhân vật, skill, tower, vũ khí, quân, kịch bản wave và thưởng theo wave được **sinh từ `balance/balance.xlsx`** bằng công cụ trong `tools/balance/`. File `.tres` sinh ra có dòng chú thích đầu file, **không sửa tay**; muốn đổi số thì sửa bảng rồi chạy lại công cụ. `GameConfig`, `FortressStats`, `BossData`, `ScaleConfig`, `WaveTable`, `GridData` và `ShopItem` vẫn sửa tay.

Các file dùng chung dưới đây dễ gây xung đột cho cả nhóm. Thay đổi nhỏ gắn liền với tính năng đang làm (một dòng Autoload, một signal, một action InputMap) được phép nằm chung Pull Request của tính năng đó, miễn là ghi rõ trong mô tả và tag người sở hữu. Chỉ tách thành Pull Request riêng, merge ngay, khi thay đổi lớn hoặc không thuộc tính năng nào:

| File | Lý do |
| --- | --- |
| `project.godot` | Quản lý Autoload, InputMap, Layer Names, Localization. Nếu vô tình sửa nhầm sẽ gây xung đột cho toàn bộ nhóm. |
| `autoload/event_bus.gd` | Danh sách signal toàn hệ thống. Việc thêm một signal mới tương đương với một Pull Request nhỏ. |
| `common/health_component.gd` | Thành phần được dùng chung bởi Commander, Enemy, Tower và Fortress. |
| `main.tscn` | Cây node gốc, chỉ thêm container khi thật sự cần thiết. |
| `README.md`, `CONTRIBUTING.md`, `PHAN_CONG.md` | Tài liệu dự án của nhóm. Sửa `PHAN_CONG.md` cùng lúc với `Bang_phan_cong_v2.0.xlsx`. |

Bạn có quyền tạo thư mục con mới bên trong thư mục cá nhân, nhưng hãy nhớ thêm file `.gdkeep`. Nếu muốn tạo thư mục mới ở cấp phân cấp cao nhất, hãy thảo luận và xin ý kiến của cả nhóm trước.

---

## 3. Cấu trúc thư mục và nội dung lưu trữ

```
res://
  autoload/        Chứa script và scene tự động nạp khi mở game ở dạng singleton. Chỉ đặt các file đã được khai báo trong Project Settings.
  common/          Chứa các lớp Resource và Component dùng chung cho dự án.
  data/            Chứa dữ liệu cân bằng game. Tuyệt đối không đặt file code tại đây.
    towers/        Chứa dữ liệu TowerData và TowerLevelData của Arrow, Cannon, Barricade và Trạm hồi lực (mỗi loại 36 cấp, 3 bậc model) dưới dạng đuôi .tres. Sinh từ bảng cân bằng.
    enemies/       Chứa dữ liệu EnemyData của 10 loại quân (Grunt, Archer, Brute và 7 loại mới) dưới dạng đuôi .tres. Sinh từ bảng cân bằng. Bulwark là BossData trong bosses/.
    bosses/        Chứa dữ liệu BossData dưới dạng đuôi .tres.
    waves/         WaveTable và ScaleConfig (từ wave 31, sửa tay); WaveScript (kịch bản wave 1-30) và WaveRewardTable (gold_mult, xp_mult, mithril_reward), hai file này sinh từ bảng cân bằng.
    weapons/       WeaponData của kiếm gốc và 5 vũ khí. Sinh từ bảng cân bằng.
    config/        Cấu hình chung của game như fortress_stats.tres, scale_config.tres.
    skills/        Chứa dữ liệu SkillData (Whirlwind, Sword Wave, Firebomb, 4 bị động gồm Sharpness, Armored, Lifesteal và Trạm hồi lực, 2 thẻ stat Thể lực và Tinh thông) dưới dạng đuôi .tres. Sinh từ bảng cân bằng.
    locale/        Chứa file strings.csv quản lý chuỗi tiếng Việt với khóa được phân loại theo ngữ cảnh.
  entities/        Lưu trữ các thực thể trong game. Mỗi loại thực thể có một thư mục riêng chứa scene .tscn và script .gd tương ứng.
    commander/     Chứa nhân vật của người chơi.
    enemy/         Chứa scene gốc enemy.tscn cùng các biến thể kế thừa như grunt, archer, brute, bulwark.
    tower/         Chứa scene gốc tower.tscn cùng các biến thể kế thừa arrow, cannon, barricade, heal_station.
    fortress/      Chứa thực thể thành chính.
    projectile/    Chứa đạn tấn công của người chơi và của địch.
  systems/         Chứa logic của các hệ thống không gắn liền với một thực thể cụ thể nào.
    time/          Quản lý thời gian x1, x2, x3 và chức năng Pause.
    nav/           Hệ thống thang xử lý tình trạng kẹt quân.
    wave/          Quản lý trạng thái và bộ sinh quân của từng đợt.
    run/           Quản lý tiến trình RunConfig, RunState, RunLoading và việc kết thúc Run.
    build/         Hệ thống quản lý vị trí, xây dựng, nâng cấp và bán tháp.
    economy/       Quản lý vàng, Mithril (sửa thành) và hệ thống điểm uy tín.
    hazard/        Hazard Trial: phòng thử thách trong PREP, chọn nhóm quái, kết quả và thưởng.
    save/          Hệ thống lưu trữ, đọc dữ liệu và khôi phục tiến trình chơi, gồm SaveRepository và LocalSaveRepository.
    tutorial/      Tutorial một lần theo tài khoản: hướng dẫn xây hai trụ đầu.
    camera/        CameraRig: Frontline bám nhân vật, Commander và PREP dịch bằng WASD trong camera_bounds, BOSS_INTRO, khung cố định của Hazard Trial.
    sync/          SyncService: kéo và đẩy profile, meta, flags với backend, không chặn UI.
    skill/         SkillRunner (phím 1-3, ô, cooldown) và StatBlock của chỉ huy.
    xp/            XpTracker: XP theo cờ hit_by_commander, cấp Chỉ huy, lượt chọn chờ.
    reward/        RewardOfferGenerator (hàm thuần, test bằng GUT) và apply_pick cho màn REWARD_PICK.
  levels/          Quản lý bản đồ game.
    corridor/      Gồm level.tscn (người phụ trách Level) và slots_layout.tscn (người phụ trách Slot); xem PHAN_CONG.md mục 2.
  ui/              Quản lý mọi giao diện hiển thị trên màn hình.
    hud/           Chứa file hud.tscn và thư mục con parts/ lưu trữ từng phần riêng biệt của HUD.
    panels/        Quản lý các Panel như Build, Tower, Priority, Fortress, Vũ khí và Wave preview.
    screens/       Quản lý các màn hình (gồm RewardPick), hộp thoại, bảng cài đặt Settings và các tab.
    theme/         Giao diện Theme dùng chung toàn cục.
  contents/        Chứa asset thô như model 3D, sprite, texture.
  art/             Chứa các hiệu ứng hình ảnh, shader và VFX được làm riêng cho game.
  audio/           Quản lý nhạc nền dưới dạng đuôi .ogg và hiệu ứng âm thanh dưới dạng đuôi .wav.
  tests/           Thư mục chứa scene hoặc script phục vụ mục đích kiểm thử.
  backend/         Mã và cấu hình phía máy chủ (BaaS): bảng dữ liệu, phân quyền, hướng dẫn API. Chỉ chứa khóa công khai, không bao giờ chứa khóa quản trị.
  balance/         balance.xlsx: nguồn gốc duy nhất của số liệu cân bằng (nhân vật, skill, tower 36 cấp, vũ khí, quân, kịch bản wave 1-30, thưởng theo wave).
  tools/balance/   Script Python (openpyxl) đọc balance.xlsx và sinh lại các .tres ở data/. Chạy bằng một lệnh, không cần Godot.
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
* **Tùy chỉnh InputMap:** Hãy thiết lập phím bằng Physical Keycode. Phím số 1, 2, 3 là skill chủ động (SKL-05). Tua tốc độ, nút Bắt đầu wave và nút Rời phòng Hazard Trial không có phím tắt (chỉ nút HUD). Phím E có hai action tách riêng: `heal_channel` (giữ để hồi máu ở Trạm hồi lực, chỉ ở COMBAT và BOSS_COMBAT) và `hazard_enter` (vào Tháp Hazard Trial, chỉ ở PREP). Phím C là `camera_recenter`. WASD chỉ có một nghĩa trong mỗi ngữ cảnh: di chuyển nhân vật ở Frontline và trong Hazard Trial, dịch camera ở Commander và PREP (CAM-10). Không còn phím G (gọi wave sớm) và phím M (di chuyển tower). Mọi action dùng phím vật lý theo INP-09.
* **Xử lý thời gian:** Mọi logic gameplay phải sử dụng thời gian trong game thông qua hệ thống `TimeManager`. Tuyệt đối không dùng hàm `Time.get_ticks_msec()` cho thời gian hồi chiêu hoặc timer liên quan đến gameplay, vì sẽ gây sai sót logic khi người chơi tua nhanh thời gian bằng tốc độ x2 hoặc x3.
* **Sát thương và XP:** Mọi nguồn sát thương, kể cả skill và vùng cháy theo tick, phải đi qua `HealthComponent` với `DamageInfo` có `damage_type` và `source` để cờ `hit_by_commander` hoạt động (XP-03, CMB-10). Không trừ máu trực tiếp.
* **Ngẫu nhiên có seed:** Mọi RNG gameplay (sinh wave, thẻ REWARD_PICK) dùng `run_seed` theo RWP-05 và SPN-05. Không gọi `randi()` toàn cục trong logic gameplay để test và replay tái hiện được.
* **Lưu và mạng:** Mọi đọc ghi tiến trình đi qua `SaveRepository` (ACCT-01), không gọi thẳng `FileAccess` cho save. Các lệnh gọi mạng chạy bất đồng bộ, không chặn UI quá 100 ms và mất mạng không được làm chậm RunEnd hay cửa hàng (ACP-08). Token đăng nhập lưu ở `auth.cfg` riêng, không bao giờ nằm trong `endlesswar_save.json`.
* **Bí mật:** Không commit `auth.cfg`, khóa quản trị hay mật khẩu của backend. Trong repo chỉ có khóa công khai của dự án BaaS. Thêm `auth.cfg` vào `.gitignore`.
* **Số liệu cân bằng:** không sửa tay `.tres` do công cụ sinh; sửa `balance/balance.xlsx` rồi chạy `tools/balance/` và chạy runner `tests/test_balance_config_runner.tscn`.
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
* Mỗi Pull Request cần ít nhất một thành viên khác xem xét duyệt lỗi. Nếu có thay đổi ở file dùng chung hoặc thư mục của người khác như đã nêu ở mục 2 và `PHAN_CONG.md`, gắn tên người sở hữu vào mô tả để thông báo, không cần họ approve.
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

Các nhóm công việc có tính phụ thuộc lẫn nhau cần thống nhất giao thức chung (chữ ký hàm, tín hiệu, định dạng dữ liệu) trước khi bắt tay vào code. Danh sách phụ thuộc giữa các task nằm ở cột 'Cần xong trước' của từng task và mục 'Điểm cần nhớ khi ghép các phần' trong `PHAN_CONG.md`.

Nếu cần thêm signal mới vào hệ thống EventBus, hãy tạo một Pull Request chuyên biệt chỉ chứa duy nhất dòng code thêm signal đó. Cần ghi chú thật rõ ràng về tên tín hiệu, các tham số đi kèm, đối tượng phát tín hiệu và đối tượng nhận tín hiệu.

---

## 9. Mốc thời gian dự án theo SRS 7.3

Chi tiết từng người, từng tuần và các mốc tích hợp cuối tuần nằm ở `PHAN_CONG.md`. Các ngày cố định: **29/11** đóng băng gameplay, **6/12** đóng băng toàn bộ tính năng, **14/12** đóng băng bản nộp, 15 và 16/12 dự phòng, **17/12** diễn tập. Tuần 13 chỉ test, sửa lỗi, báo cáo và video.

Các mục `[Should]` chỉ làm khi MVP xong sớm. Nếu tiến độ trễ hơn mốc B1 (15/11) quá 2 ngày hoặc một người nghỉ cả tuần, nhóm dừng toàn bộ hạng mục không bắt buộc và cắt theo thứ tự ở Phụ lục C mục 17 của SRS: Firebomb, edge-pan và look-ahead camera, HLT-12, bảng xếp hạng, rồi đồng bộ tài khoản. **Không cắt** Aura Tiền tuyến, gold chỉ huy, XP, cổng bậc tower, Cuồng nộ và save atomic. Online chỉ bị cắt khi vẫn trễ sau mốc B2.

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