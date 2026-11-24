# Công cụ sinh số liệu cân bằng

`generate.py` đọc `balance/balance.xlsx` và ghi lại các file `.tres` trong `data/`. Bảng là nguồn chuẩn của số liệu; file `.tres` sinh ra có dòng đầu `; AUTO-GENERATED ...` và **không sửa tay**, vì lần chạy sau sẽ ghi đè.

## Chạy

Cần Python 3.13 trở lên và `openpyxl` (`pip install openpyxl`). Không cần Godot.

```
python tools/balance/generate.py            # sinh lại các file
python tools/balance/generate.py --check    # chỉ kiểm tra, thoát mã 1 nếu có file sẽ đổi
```

Chạy lại với cùng bảng cho ra cùng nội dung, nên lần chạy thứ hai không làm `git status` đổi thêm.

## Kiểm tra trước khi ghi

Toàn bộ bảng được kiểm tra trước. Gặp ô trống hoặc số âm ở bất kỳ sheet nào, công cụ in dạng `sheet!ô` (ví dụ `towers!D5: empty cell`) và thoát mà không ghi file nào. Sai kiểu (số lẻ ở trường kiểu int, chuỗi enum không có trong `common/enums.gd`) cũng dừng toàn bộ. Giá trị enum dạng số phải là số nguyên thuộc enum; bool, số lẻ, NaN/inf và số ngoài miền đều bị từ chối. Các sheet character/skills/towers/enemies/weapons kiểm đủ cột bắt buộc trước khi đọc dòng và từ chối khóa dòng trùng, kể cả trùng sau khi áp dụng alias; lỗi ghi tọa độ dòng trùng và dòng đầu tiên.

Dòng trống hoàn toàn (kể cả dòng cuối còn định dạng), sheet không có dòng dữ liệu và header trống hoặc trùng đều là lỗi có tọa độ; header trống không làm cụt bảng. Hai sheet wave phải đủ liên tục `1..GameConfig.victory_wave`; `wave_rewards` có đúng một dòng mỗi wave. `enemy_id` phải tồn tại trong `enemies` hoặc catalog boss, `count` là số nguyên ≥ 1, `is_escort` là TRUE/FALSE. Các dòng cùng wave phải khớp `spawn_duration`, `hp_mult`, `dmg_mult`, `speed_mult`; thời lượng ≥ `GameConfig.lbd_min_seconds_per_wave`. Mỗi wave có tối đa `GameConfig.wave_max_enemy_types` loại kể cả boss. Hai giới hạn này và `victory_wave`, `boss_wave_interval` được đọc từ `autoload/game_config.gd`. Các hệ số cùng wave được so sánh với sai số tương đối/tuyệt đối `1e-9` để chấp nhận sai số tính toán Excel. Wave chia hết cho `boss_wave_interval` phải có đúng một boss và ít nhất một quân hộ tống. ID boss lấy từ trường `id` của catalog `BossData` (kể cả lớp con như `CentipedeBossData`) trong `data/bosses/`; id boss không cần dòng trong sheet `enemies`, không từ tên file hoặc chuỗi tên boss cố định. Các ô được kiểm độc lập: lỗi hệ số/ID không chặn kiểm tra count, cờ escort hoặc cấu trúc boss; mỗi lỗi ô chỉ được ghi một lần cho cùng điều kiện.

Mọi nội dung được dựng trong bộ nhớ trước. Công cụ ghi tất cả file tạm `.tmp` và bản sao nội dung cũ cùng thư mục đích, rồi dùng `os.replace`. Lỗi OS khi thay file sẽ khôi phục những file đã thay và xóa file mới; nếu hệ điều hành chặn cả khôi phục, công cụ báo đường dẫn bản sao còn giữ lại. Đây là rollback khi có lỗi ghi, không phải giao dịch nhiều file chống mất điện hay dừng tiến trình đột ngột.

## Sheet và file sinh ra

| Sheet | File | Ghi chú |
| --- | --- | --- |
| `character` | `data/config/commander_stats.tres` | Mỗi dòng là một field của `CharacterStats`. Chuỗi enum như `SLASH` đổi sang số theo `common/enums.gd`. |
| `skills` | `data/skills/<id>.tres` | Skill chủ động, bị động và thẻ stat. Mỗi key thành một `PackedFloat32Array` theo cấp, xếp theo tên key. Giá trị `heal_rate_base` của thẻ `heal_station` trong bảng là lượng cộng thêm, được sinh vào `heal_rate_add`. |
| `towers` | `data/towers/<id>.tres` và `<id>_l1..l36.tres` | Mỗi loại phải có đủ cấp `1..GameConfig.tower_max_level` ngay ở generator. Mỗi dòng bảng là một file cấp. File cấp mới không có `uid` và được tham chiếu bằng path. |
| `enemies` | `data/enemies/<id>.tres` | Sinh chỉ số và đủ 15 trường trait theo schema `EnemyData`. Cột mới chưa có export sẽ bị bỏ qua kèm cảnh báo. |
| `weapons` | `data/weapons/<id>.tres` | Chỉ sinh khi đã có `common/weapon_data.gd`. `sword` trong bảng thành `sword_base`. Cột `effect_id` và `key` `range_mult` là field, các `key` còn lại vào `params` (`key = effect_id` bị từ chối). |
| `waves` | `data/waves/wave_script.tres` | Mảng entry phẳng: wave, enemy ID, count, escort; bốn mảng hệ số dùng phần tử `w - 1` cho wave `w`. Không có sub-resource. |
| `wave_rewards` | `data/waves/wave_rewards.tres` | `gold_mult`, `xp_mult` là `PackedFloat32Array`; `mithril_reward` là `PackedInt32Array`, phần tử `w - 1` cho wave `w`. |

## Schema và alias tương thích

`aliases.json` cạnh generator khai báo ánh xạ ID weapon và key skill. Hiện giữ `sword -> sword_base` và `heal_station.heal_rate_base -> heal_rate_add` để tương thích dữ liệu đã có, không đổi workbook. Alias dẫn tới trùng khóa cũng là lỗi.

Parser đọc khai báo export có kiểu, chú thích cuối dòng, annotation trên dòng riêng và `:=` với literal/constructor có kiểu xác định. Các hằng số GameConfig dùng cho validation phải là literal số dương; biểu thức tính toán không được thực thi. Khai báo không hỗ trợ báo lỗi file/dòng và yêu cầu kiểu tường minh, không bỏ qua âm thầm. Đây là parser schema có giới hạn, không phải trình phân tích toàn bộ GDScript. Enum được đọc khi cần, không đọc ở thời điểm import; thành viên ngầm định tiếp tục từ giá trị tường minh trước đó.

## Giữ lại những gì có sẵn

Trước khi ghi, công cụ đọc file `.tres` cũ và giữ nguyên `uid` ở đầu file, `id` và `uid` của `ext_resource`, và mọi field không nằm trong bảng (icon, `name_key`, `projectile_scene`, `allowed_zones`, `anim_*`, `target_rules`, `model`, `vfx`...). Field xuất hiện theo đúng thứ tự khai báo trong script `.gd`. Số nguyên in không có `.0`; file dùng LF và có newline cuối.

Skill, tower và quân phải có sẵn file `.tres` (vì cần icon, scene, luật mục tiêu); thiếu file thì công cụ cảnh báo và bỏ qua mục đó. Với quân mới, tạo trước một EnemyData `data/enemies/<id>.tres` hợp lệ có `id` và `display_name_key`, rồi chạy công cụ để điền số. Vũ khí và file cấp tower thì được tạo mới nếu chưa có.

`data/waves/wave_table.tres` và `data/config/scale_config.tres` vẫn viết tay; công cụ không đọc hoặc ghi hai file này. `WaveScript.get_wave(w)` trả danh sách `{enemy_type: StringName, count: int, is_escort: bool}` mới mỗi lần gọi. Không có entry cho wave (kể cả `w < 1`) thì danh sách rỗng. Mảng entry độc lập với mảng thời lượng: thiếu thời lượng không làm mất entry; thời lượng thiếu dùng `GameConfig.lbd_min_seconds_per_wave`, hệ số thiếu dùng 1.0. Không dùng fallback này thay công thức ScaleConfig cho endless.

Chuỗi `String`/`StringName` được escape trước khi xuất để giữ đúng dấu ngoặc kép, dấu gạch chéo ngược và ký tự điều khiển. CLI chỉ nhận `--check` và `--help`; cờ lạ hoặc viết tắt bị từ chối trước khi đọc bảng hoặc ghi file.

Schema EnemyData đã có đủ 15 cột trait của workbook; generator sinh chúng theo kiểu export. AI chưa xử lý các trait mới: `TODO(endervia)` tại `common/enemy_data.gd` ghi phần còn lại, chưa coi hành vi trait đã hoàn tất.

## Kiểm thử

```powershell
python -m unittest discover -s tools/balance -p test_generate.py -v
python tools/balance/generate.py
python tools/balance/generate.py --check
```

Lệnh cuối phải in `0 files would change`. Test Python bao gồm header/sheet/dòng trống, kiểm tra chéo wave, sai kiểu/ngoài biên, NaN/inf, CLI không ghi khi lỗi, header bắt buộc/khóa dòng trùng, nhánh lỗi của từng generator, enum số và parser schema, escape chuỗi, nội dung output, lỗi staging và rollback sau lỗi thay file giữa chừng. Test tích hợp sao chép input vào thư mục tạm, gọi main không mock read/build/write, sửa một chỉ số, tạo lại WaveScript đã thiếu và chạy --check để xác nhận ghi thật/idempotence. Chạy F6 `tests/test_balance_config_runner.tscn`, `tests/test_wave_reward_table_runner.tscn`, `tests/test_wave_rewards_runner.tscn`, `tests/test_scale_config.tscn`, và F5 `main.tscn` để kiểm tra nạp Resource trong Godot.

Runner BAL khám phá TowerData trong thư mục data/towers (không ghim danh sách ID), yêu cầu có ít nhất bốn loại theo đặc tả và kiểm đủ cấp cùng thứ tự tham chiếu resource từng cấp, resource cho mọi ID trong kịch bản (EnemyData thường trong `data/enemies/`, BossData theo ID trong `data/bosses/`), CharacterStats/SkillData/WeaponData, độ dài mảng, số hữu hạn/không âm và hệ số ở ranh giới với ScaleConfig. Tọa độ thế giới `fall_y_threshold` có thể âm và không thuộc chỉ số sinh từ bảng. Runner không ghim thành phần/hệ số của wave mẫu, tổng số entry hay thưởng Mithril. Getter thưởng đối chiếu mảng đang nạp theo độ chính xác của WaveRewardTable; fallback Mithril theo phần tử cuối có sẵn tới victory_wave. Test xuất text Python dùng fixture độc lập với workbook hiện tại; test lookup WaveScript dùng các entry tổng hợp để kiểm thứ tự và cờ escort.

BL4 về lựa chọn nguồn dữ liệu trong gameplay còn chờ spawner tích hợp WaveScript; `TODO(endervia)` trong runner và ghi chú bàn giao nêu phần này. Workbook đã có số của mười loại quân và kịch bản wave 1-30, boss Bulwark và Skeletal Centipede.

## Khi thêm số liệu mới

1. Sửa `balance/balance.xlsx` (đừng để ô trống hay số âm).
2. Chạy `python tools/balance/generate.py`.
3. Commit bảng cùng các `.tres` thay đổi trong một PR.

Muốn thêm một cột vào sheet, thêm field cùng tên (`@export var`) vào script `.gd` tương ứng trước. Cột không có field sẽ bị bỏ qua (chỉ `enemies` báo cảnh báo; `character` báo lỗi vì mỗi dòng phải là một field).
