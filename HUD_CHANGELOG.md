# Ghi chú bản thử HUD cho lần cập nhật SRS

Branch `codex/compact-combat-hud`. Các thay đổi dưới đây mô tả hành vi của bản thử.

| Phần | Hành vi trong bản thử | Đối chiếu SRS v2.0 |
| --- | --- | --- |
| Xây trụ | Trong PREP, B chọn ô có vòng xây gần con trỏ nhất trong khung hình và mở danh sách. Bấm trực tiếp vào ô cũng mở danh sách. Người chơi chọn loại trụ mới thực hiện giao dịch. Mỗi dòng hiện icon, tên và giá. Rê chuột để xem chỉ số hoặc lý do khóa. | INP-01, mục 4.1.3, PNL-01 |
| Bảng ngữ cảnh | Xây, trụ, trạm hồi lực, Thành, nhân vật và vũ khí dùng chung vị trí sát mép phải với chuyển động trượt 0,22 giây. Khung xem trước đợt quái tạm nhường chỗ khi mở bảng. Danh sách vũ khí cuộn dọc. Hộp xác nhận giao dịch trong PREP cũng mở bên phải. | Mục 4.1.3, HUD-25, PNL-01 tới PNL-04, PNL-14, PNL-15 |
| Chỉ huy | V hoặc bấm thanh máu chỉ huy để mở. Sinh lực và kinh nghiệm có thanh riêng kèm số. Cấp khởi đầu 0 hiển thị “Tân binh” trong bảng và trên HUD. Từ cấp 1 hiển thị số cấp thực. Đường cong XP và HP vẫn lấy từ gameplay. | HUD-15, INP-01 |
| Kỹ năng và vũ khí | HUD có ba ô chủ động với phím và hồi chiêu. Kỹ năng bị động và ô trang bị nằm trong bảng nhân vật. Đổi vũ khí trong PREP. Bỏ mũi tên thu gọn. V và B được liệt kê trong Cài đặt → Gameplay. | HUD-16, HUD-21, HUD-24, ACC-07 |
| Máu thấp | Chỉ huy và Thành báo ngay cạnh thanh HP bằng viền và nhãn nguy cấp. | ALR-01, ALR-02, HUD-01 |
| Trụ bị phá | Bỏ thông báo nổi cho một trụ và thông báo gộp nhiều trụ. Ô đổ nát vẫn cho xem giá xây lại khi chọn. | ALR-07, PNL-01 |

Các bảng ngữ cảnh và xác nhận giao dịch neo giữa cạnh phải, mặt bảng nối sát biên khung chơi. Các bảng thông tin có nút × ở đầu bảng. Bảng Thành chia riêng máu, Mithril và lượt sửa khẩn cấp, mỗi dòng căn giá trị sang phải. Lý do khóa sửa chữa dùng dòng phụ.

B mở hoặc đóng bảng xây trong PREP. Chọn lại đúng ô đất, trụ, trạm hoặc Thành đang xem cũng đóng bảng. Bảng trụ hiển thị máu và ba chỉ số tấn công, chi tiết cấp kế nằm trong tooltip nâng cấp. Trạm hồi lực hiển thị kho máu bằng thanh xanh cùng tốc độ hồi và cấp trạm. Ba nút tốc độ nằm chung trong khung vàng và Mithril.

Các nút thao tác dùng chung có trạng thái rê, nhấn và khóa. Nâng cấp dùng nền xanh bạc hà và mũi tên lên, bán dùng nền sẫm viền màu san hô và dấu trừ. Sửa Thành dùng dấu cộng, dọn đổ nát dùng dấu ×.

Thu gọn bảy bảng sát mép phải xuống 370 đơn vị ở khung thiết kế 1920 × 1080. Danh sách kiếm cuộn dọc với tên ở dòng riêng, trạng thái và tầm đánh ở dòng kế. Hàng tự tăng chiều cao theo mô tả.

Bảng chọn vũ khí chuyển ra giữa màn hình với sáu ô kiếm, làm mờ hậu cảnh và tạm dừng game. Trong PREP có thể trang bị liên tục trước khi thoát bằng × hoặc Esc. Xác nhận bán và thông báo lượt chơi gián đoạn tách số vàng, danh vọng thành hàng riêng. Nút nâng cấp và bán dùng phông đậm hỗ trợ tiếng Việt.
