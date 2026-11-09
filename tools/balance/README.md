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

Toàn bộ bảng được kiểm tra trước. Gặp ô trống hoặc số âm ở bất kỳ sheet nào, công cụ in dạng `sheet!ô` (ví dụ `towers!D5: empty cell`) và thoát mà không ghi file nào. Sai kiểu (số lẻ ở trường kiểu int, chuỗi enum không có trong `common/enums.gd`) cũng dừng toàn bộ.

## Sheet và file sinh ra

| Sheet | File | Ghi chú |
| --- | --- | --- |
| `character` | `data/config/commander_stats.tres` | Mỗi dòng là một field của `CharacterStats`. Chuỗi enum như `SLASH` đổi sang số theo `common/enums.gd`. |
| `skills` | `data/skills/<id>.tres` | Chỉ skill `ACTIVE`. Mỗi key thành một `PackedFloat32Array` theo cấp, xếp theo tên key. Cột `dps` của `firebomb` ghi thành key `damage`, là key mà code đọc. |
| `towers` | `data/towers/<id>.tres` và `<id>_l1..l36.tres` | Mỗi dòng bảng là một file cấp. File cấp mới không có `uid` và được tham chiếu bằng path. |
| `enemies` | `data/enemies/<id>.tres` | Chỉ các cột là field của `EnemyData`. Các cột trait chưa có field (stealth, explode, charger, revive...) bị bỏ qua kèm cảnh báo. |
| `weapons` | `data/weapons/<id>.tres` | Chỉ sinh khi đã có `common/weapon_data.gd`. `sword` trong bảng thành `sword_base`. Cột `range_mult` và `effect_id` là field, các cột còn lại vào `params`. |
| `waves`, `wave_rewards` | chưa sinh | Chỉ được kiểm tra ô trống và số âm. |

## Giữ lại những gì có sẵn

Trước khi ghi, công cụ đọc file `.tres` cũ và giữ nguyên `uid` ở đầu file, `id` và `uid` của `ext_resource`, và mọi field không nằm trong bảng (icon, `name_key`, `projectile_scene`, `allowed_zones`, `anim_*`, `target_rules`, `model`, `vfx`...). Field xuất hiện theo đúng thứ tự khai báo trong script `.gd`. Số nguyên in không có `.0`; file dùng LF và có newline cuối.

Skill, tower và quân phải có sẵn file `.tres` (vì cần icon, scene, luật mục tiêu); thiếu file thì công cụ cảnh báo và bỏ qua mục đó. Vũ khí và file cấp tower thì được tạo mới nếu chưa có.

## Khi thêm số liệu mới

1. Sửa `balance/balance.xlsx` (đừng để ô trống hay số âm).
2. Chạy `python tools/balance/generate.py`.
3. Commit bảng cùng các `.tres` thay đổi trong một PR.

Muốn thêm một cột vào sheet, thêm field cùng tên (`@export var`) vào script `.gd` tương ứng trước. Cột không có field sẽ bị bỏ qua (chỉ `enemies` báo cảnh báo; `character` báo lỗi vì mỗi dòng phải là một field).
