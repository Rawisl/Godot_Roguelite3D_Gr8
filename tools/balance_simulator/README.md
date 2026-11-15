# Công cụ mô phỏng cân bằng giá tower

`simulate.py` so giá tích lũy của 4 loại tower (36 cấp mỗi loại) với số gold ước tính kiếm được tới wave thắng, rồi gợi ý một đường giá. Công cụ **chỉ đọc** `balance/balance.xlsx` và `autoload/game_config.gd`, không bao giờ ghi vào bảng: số đề xuất được in ra dạng khối TSV để tự dán vào sheet `towers`.

## Chạy

Cần Python 3.13 trở lên và `openpyxl` (`pip install openpyxl`). Không cần Godot.

```
python -I tools/balance_simulator/simulate.py                       # chạy với bảng hiện tại và đường đề xuất mặc định
python -I tools/balance_simulator/simulate.py --growth 1.09 --set cannon.base=60 --set arrow.growth_from=25:1.10
python -I tools/balance_simulator/simulate.py --tsv cost.tsv         # ghi thêm cột build_cost đề xuất ra file
python -I tools/balance_simulator/simulate.py --target-gold 12000    # điền sẵn mốc gold ở wave thắng
python -I tools/balance_simulator/simulate.py --check-js             # mở trang bằng Edge/Chrome headless, kiểm JS khớp Python
python -I tools/balance_simulator/simulate.py --self-test            # tự kiểm, không đọc bảng
```

Mã thoát: 0 là chạy xong (kể cả khi mục tiêu M hiện FAIL, đó chỉ là thông tin), 1 là bảng hoặc game_config có lỗi (in từng lỗi dạng `sheet!ô: ...`), 2 là tham số sai.

## Tham số

| Tham số | Mặc định | Ý nghĩa |
| --- | --- | --- |
| `--xlsx PATH` | `balance/balance.xlsx` | Bảng cân bằng |
| `--game-config PATH` | `autoload/game_config.gd` | Nguồn hằng số GameConfig |
| `--out PATH` | `endless_war_balance_report.html` trong thư mục tạm | File HTML; đường dẫn đầy đủ được in ra khi xong |
| `--growth FLOAT` | `1.2` | Hệ số tăng giá mỗi cấp của đường đề xuất |
| `--growth-from LEVEL:FACTOR` | `14:1.1` và `24:1.05` (lặp được) | Từ cấp `LEVEL` trở đi giá tăng `FACTOR` mỗi cấp thay vì `--growth`, tới khi gặp mốc kế tiếp. Có `--growth-from` thì danh sách mặc định bị thay hẳn. `LEVEL` là số nguyên từ 2 tới `tower_max_level`, `FACTOR` > 0, không trùng `LEVEL` |
| `--round-to INT` | `5` | Làm tròn giá mỗi cấp tới bội số này (cấp 1 giữ đúng như bảng) |
| `--set TYPE.KEY=VALUE` | xem bảng núm theo loại (lặp được) | Ghi đè theo loại; KEY là `base`, `growth` hoặc `growth_from` |
| `--layout SPEC` | `arrow=3,cannon=1,barricade=1,heal_station=1` | Bố cục "6 công trình" |
| `--starters SPEC` | `arrow=1,cannon=1` | Số trụ cấp 1 có sẵn, trừ khỏi giá bố cục |
| `--avg-cmd-ratio` | `0.4` | Tỷ lệ quân có cờ chỉ huy, kịch bản trung bình |
| `--strong-cmd-ratio` | `0.6` | Như trên, kịch bản mạnh |
| `--strong-gold-pct` | `0.16` | Tổng gold cộng thêm của kịch bản mạnh (nâng cấp meta vàng ở mức tối đa) |
| `--boss-ids LIST` | `bulwark` | enemy_id được coi là boss trong sheet `waves` |
| `--target-gold INT` | không (> 0) | Mốc gold muốn có ở wave thắng, chỉ để so sánh (không đổi công thức thu nhập); điền sẵn ô `target_gold` trên trang |
| `--tsv PATH` | không | Ghi cột build_cost đề xuất ra file TSV |
| `--check-js` | tắt | Sau khi ghi trang, mở bằng Edge hoặc Chrome headless và kiểm huy hiệu engine check: `engine check: pass` (mã 0), lỗi đầu tiên (mã 1), hoặc `skipped` (mã 0) khi máy không có trình duyệt |
| `--self-test` | tắt | Chạy các kiểm tra nội bộ rồi thoát |

### Núm theo từng loại (`--set TYPE.KEY=VALUE`)

`TYPE` là `tower_id` trong sheet `towers`: `arrow`, `cannon`, `barricade`, `heal_station`. Mỗi `--set` đổi một núm của một loại; lặp lại `--set` để đổi nhiều núm. Núm không được đặt thì lấy mặc định bên dưới (hằng số `DEFAULT_SET` đầu file `simulate.py`); `--set` một khóa chỉ thay mặc định của đúng khóa đó, các khóa khác của loại đó giữ mặc định.

| KEY | Mặc định | Ý nghĩa |
| --- | --- | --- |
| `base` | `arrow` 20, `cannon` 50, `barricade` 80, `heal_station` 120 (loại không có trong danh sách: giá cấp 1 trong sheet) | Giá cấp 1 của đường đề xuất; các cấp sau tính từ số này. Đổi `base` là đổi luôn giá xây cấp 1 khi dán vào sheet |
| `growth` | `cannon` 1.12, `barricade` 1.04, `heal_station` 1.05; `arrow` theo `--growth` (1.2) | Hệ số nhân giá mỗi cấp: giá cấp n = `base × growth^(n−1)` khi không có `growth_from` |
| `growth_from` | `cannon` 14:1.075, 18:1.1, 25:1.05; `barricade` 13:1.06, 25:1.1; `heal_station` 13:1.07; `arrow` theo `--growth-from` (14:1.1, 24:1.05) | `LEVEL:FACTOR`, lặp được. Từ cấp `LEVEL` giá tăng `FACTOR` mỗi cấp thay cho `growth`; danh sách của một loại thay hẳn danh sách toàn cục cho loại đó |

Giá trước khi làm tròn nối tiếp nhau: p(1) = `base`, p(n) = p(n−1) × g(n), với g(n) là `FACTOR` của mốc `growth_from` có `LEVEL` lớn nhất không vượt quá n, hoặc `growth` nếu chưa có mốc nào. Đường giá liền mạch, không có cấp nào nhảy riêng. Giá mỗi cấp sau đó được làm tròn theo `--round-to` (không nhỏ hơn chính `--round-to`); cấp 1 giữ đúng `base`. Giá trị phải lớn hơn 0, sai tên loại, sai khóa (`tier_mult` không còn), sai dạng `LEVEL:FACTOR` hoặc không phải số thì công cụ dừng với mã 2.

```
python -I tools/balance_simulator/simulate.py --set arrow.base=60 --set arrow.growth=1.09
python -I tools/balance_simulator/simulate.py --growth 1.08 --growth-from 25:1.10 --set cannon.growth_from=20:1.12 --set cannon.growth_from=30:1.05
```

## Dữ liệu đọc từ đâu

- **Bảng:** sheet `towers` (`tower_id`, `level`, `build_cost`), `enemies` (`enemy_id`, `gold_reward`), `waves` (`wave`, `enemy_id`, `count`), `wave_rewards` (`wave`, `gold_mult`). Cột tìm theo tên header, không theo vị trí.
- **Cột tùy chọn (chỉ số và biểu đồ DPS):** `towers`: `max_hp`, `damage`, `attack_range`, `fire_rate`, `splash_radius`; `enemies`: `base_hp`; `waves`: `spawn_duration`, `hp_mult`. Thiếu cột, hoặc ô sai (không phải số, âm) thì công cụ in `warning` kèm tọa độ ô và tắt phần đó (nhóm `towers` hỏng: tắt chỉ số và cột chỉ số xuất ra; nhóm `enemies`/`waves` hỏng: tắt biểu đồ DPS), phần còn lại vẫn chạy. Ô thiếu hoặc sai kiểu được báo kèm tọa độ ô và công cụ dừng, không ghi file nào.
- **GameConfig:** `victory_wave`, `starting_gold`, `tower_max_level`, `tower_tier2_level`, `tower_tier3_level`, `frontline_gold_mult`, `boss_gold_base`, `clear_mult_normal`, `clear_mult_fast`, `hazard_enemy_count`, `hazard_boss_escorts`. Thiếu khóa nào là lỗi.
- **Núm của công cụ:** các giá trị mặc định trong bảng tham số ở trên.
- **Mục tiêu M1 tới M6:** hằng số `AFFORD_TARGETS`, `M5_MIN_RATIO`, `M6_TARGET` đầu file `simulate.py` (xem mục "Sáu mục tiêu"). Chỉ để so PASS/FAIL, không ảnh hưởng số tính ra.

## Ba kịch bản thu nhập

Gold của mỗi wave gồm quân thường, boss (cộng một lần) và gold Hazard; thu nhập tích lũy là tổng từ đầu run tới hết wave đó.

- `raw`: không cờ chỉ huy, không Hazard, hệ số dọn wave bình thường.
- `average`: một phần quân chết khi có cờ chỉ huy (nhân hệ số tiền tuyến), có Hazard.
- `strong`: nhiều cờ chỉ huy hơn, hệ số dọn wave nhanh, có Hazard, cộng thêm gold từ meta.

Từ đó công cụ tính cấp đồng đều cao nhất của bố cục mà mỗi kịch bản mua nổi ở từng wave (biểu đồ cấp đồng đều) và sáu mục tiêu M1 tới M6 bên dưới, cho cả bảng hiện tại lẫn đường đề xuất.

**Định nghĩa "thu nhập tới wave X":** gold cộng dồn sau phần tổng kết wave X của kịch bản `average` (hoặc `strong` với M5), **đã gồm gold khởi đầu** (`starting_gold`, tức mốc wave 0). Mọi mục tiêu dùng chung đúng số này với biểu đồ tổng gold theo wave.

## Sáu mục tiêu

Giá mua một trụ tới cấp L là tổng giá cấp 1..L (bằng giá xây lại, không trừ gì).

| Mã | Mặc định | Ý nghĩa |
| --- | --- | --- |
| M1 | 1 × arrow cấp 14 tới wave 9 | PASS khi thu nhập `average` tới hết wave đó >= số trụ × giá cộng dồn tới cấp đó |
| M2 | 2 × cannon cấp 13 tới wave 14 | Như M1 |
| M3 | 1 × arrow cấp 25 tới wave 19 | Như M1 |
| M4 | 1 × heal_station cấp 1 tới wave 4 | Như M1 |
| M5 | tỷ lệ >= 1 | Giá bố cục 6 công trình tới cấp bậc 3 (cấp 25, lấy từ GameConfig) trừ trụ khởi đầu, chia thu nhập `strong` tới wave thắng |
| M6 | arrow, 3 trụ, cấp 25, wave 30, tỷ lệ >= 0.8 | Thu nhập `average` tới wave 30 chia (3 × giá cộng dồn arrow tới cấp 25) |

M1 tới M4 còn báo wave đầu tiên mua nổi (hoặc `never (> w30)` nếu tới wave thắng vẫn chưa đủ); cột giá trị của bảng M ghi wave này, còn PASS/FAIL chỉ xét wave hạn chót. M5 và M6 ghi tỷ lệ. Loại trụ, số lượng, cấp, wave và tỷ lệ tối thiểu đều sửa được trên trang. Loại trụ phải có trong sheet `towers`; wave hạn chót lớn hơn wave thắng được tính là wave thắng.

## Đầu ra

Một file HTML tự chứa ở thư mục tạm của hệ thống (hoặc `--out`), không nằm trong repo; mở bằng trình duyệt, không cần server, không có CDN hay thư viện ngoài. Python đọc bảng, tính số cho núm từ dòng lệnh rồi nhúng vào `report_template.html` cùng dữ liệu tĩnh (dạng JSON); JavaScript trong trang tính lại mọi thứ mỗi khi đổi núm, bằng đúng công thức của `compute()` trong `simulate.py`.

Trên trang:

- **Thanh mục tiêu** (dính đầu trang khi cuộn): M1 tới M6 (mô tả sinh từ các ngưỡng đang đặt) cột Sheet và Proposed, PASS/FAIL, và dòng target gold (gold của kịch bản chọn ở wave thắng, tỷ lệ so với mốc, hệ số thu nhập cần có).
- **Núm giá** theo từng loại: `mode` (`curve` hoặc `sheet`), `base`, `growth`, các mốc `growth_from`, `round_to`; nút `Apply growth to all types`.
- **Núm thu nhập:** 3 kịch bản (clear normal/fast, `cmd_ratio`, hazard, `gold_pct`), bố cục và số trụ khởi đầu, `target_gold`, kịch bản so với target.
- **Ngưỡng mục tiêu M1 tới M6** (loại trụ, số lượng, cấp, wave; tỷ lệ của M5 và M6), và **chỉ số tower** (mỗi loại × `max_hp`, `damage`, `attack_range`, `fire_rate` có một danh sách đoạn `(from, mult)`, bấm `+ segment` để thêm, `×` để xóa. Chỉ số tính nối tiếp như đường giá, chỉ lấy giá trị cấp 1 của sheet: cấp 1 giữ giá trị sheet, cấp n = chỉ số cấp n−1 × `mult` của đoạn có `from` lớn nhất ≤ n (đoạn sau thay đoạn trước; cấp thấp hơn mọi đoạn nhân 1, tức giữ bằng cấp trước). Chỉ số không có đoạn nào thì giữ nguyên cột sheet. Số nối tiếp không làm tròn giữa chừng; giá trị mỗi cấp được làm tròn khi xuất: `max_hp` tới bội số 5 gần nhất (nhỏ nhất 5), `damage` tới bội số 2 gần nhất (nhỏ nhất 2), `attack_range` và `fire_rate` tới 2 chữ số thập phân; `from` là số nguyên 1..`tower_max_level` (`from` 1 tác dụng như 2 vì cấp 1 luôn là giá trị sheet), `mult` > 0, không trùng `from`. Ví dụ `(10, 1.2)` và `(25, 1.05)` với cấp 1 là 100: cấp 1-9 bằng 100, cấp 10 là 120, cấp 11 là 144, từ cấp 25 mỗi cấp ×1.05. Trạng thái cũ chỉ có một cặp `scale`/`from` vẫn nạp được, thành một đoạn (nay hiểu là hệ số mỗi cấp); chỉ số chưa có cờ CLI nên nút `Copy CLI command` không đụng tới; mô hình DPS với `travel_time`, `splash_targets`, `tower_share`). Phần chỉ số tắt (kèm dòng `warning` ở stderr) nếu bảng thiếu cột.
- **5 biểu đồ:** giá từng cấp, giá cộng dồn, tổng gold theo wave (có điểm target), cấp đồng đều theo wave, DPS cung/cầu. Bấm tên đường ở chú giải để ẩn hoặc hiện; di chuột để đọc số.
- **Cửa sổ tách rời:** nút "Pop out" phía trên mỗi biểu đồ mở biểu đồ đó trong một cửa sổ trình duyệt riêng (cho phép pop-up của trang nếu bị chặn). Cửa sổ tự vẽ lại mỗi khi chỉnh số ở trang chính, đi theo theme và trạng thái chú giải của trang chính (bấm chú giải ở cửa sổ nào cũng được), có tooltip khi di chuột và co giãn theo kích thước cửa sổ. Bấm nút lần nữa thì đưa cửa sổ cũ lên trước; đóng cửa sổ thì nó thôi được cập nhật.
- **Bảng giá và bảng chỉ số** từng loại (bấm để mở), và **khối xuất** TSV: `build_cost` (cột C), từng cột chỉ số (D, E, F, G) và khối gộp C:G khi 5 cột liền nhau, mỗi khối có nút `Copy` và `Download .tsv`, kèm vùng cần dán (ví dụ `towers!C2:C145`).
- Ô nhập sai (không phải số, ngoài khoảng, trùng mốc, wave lớn hơn wave thắng, cấp lớn hơn cấp tối đa...) bị viền đỏ kèm lý do khi rê chuột; kết quả giữ theo giá trị hợp lệ gần nhất.
- `Reset to command line` đưa núm về như lúc chạy lệnh; `Reset to sheet` đặt mọi loại về giá đang có trong sheet. `Copy CLI command` ra lệnh tương ứng với núm hiện tại (kèm dòng `# not covered by flags` cho núm chỉ có trên trang); `Copy link` ra đường dẫn kèm núm trong phần `#k=`. `Theme` chọn auto, light hoặc dark.
- Ngưỡng mục tiêu lưu theo dạng mới; trạng thái cũ (ngưỡng M1 tới M5 kiểu khoảng) vẫn nạp được nhưng phần ngưỡng quay về mặc định. Núm được lưu trong `localStorage` của trình duyệt (khóa `endless_war_balance_sim_v1`); mở lại trang thì còn. Nếu bảng đã đổi so với lúc lưu (khác `fingerprint`), trang hỏi `Load anyway` hoặc `Discard`. Thứ tự ưu tiên khi tải: hash `#k=` trong đường dẫn, rồi `localStorage`, rồi mặc định từ dòng lệnh.
- **Huy hiệu `Engine check`** đầu trang: trang chạy lại 5 bộ núm cố định (có một bộ đổi hết ngưỡng mục tiêu) bằng JS và so từng số với kết quả Python nhúng sẵn. Xanh `5/5 match` là JS và Python khớp tuyệt đối; đỏ kèm đường dẫn khóa lệch đầu tiên thì không tin số trên trang và báo lại.
- Tắt JavaScript thì chỉ còn bảng mục tiêu và khối TSV `build_cost` của núm dòng lệnh.

Khối TSV có một số mỗi dòng, đúng thứ tự dòng của sheet `towers`. Lệnh vẫn in tóm tắt và (với `--tsv`) ghi file TSV như trước.

Giới hạn: máy không có Node nên `--self-test` chỉ kiểm phía Python (công thức, payload, template). Việc JS khớp Python chỉ được chứng minh khi mở trang (huy hiệu) hoặc chạy `--check-js`, và `--self-test` không gọi trình duyệt. Chỉ số tower trên trang (vượt phạm vi "chỉ cân build_cost") chỉ là công cụ thử: sau khi dán nhớ chạy lại các runner tower, vì assert chỉ số trong runner có thể vỡ.

## Quy trình chỉnh giá

1. Chạy công cụ, mở file HTML (kiểm huy hiệu Engine check xanh), xem biểu đồ và thanh mục tiêu.
2. Chỉnh núm ngay trên trang tới khi ưng ý (hoặc dùng `Copy CLI command` để chạy lại bằng dòng lệnh).
3. Dán khối TSV (nút `Copy`) vào đúng vùng của sheet `towers` và lưu bảng.
4. Chạy `python tools/balance/generate.py`, rồi `python tools/balance/generate.py --check`.
5. Chạy các runner liên quan tới tower.
