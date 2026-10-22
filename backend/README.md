# Backend (Supabase)

Máy chủ dùng Supabase gói Free: xác thực email và mật khẩu, bảng `profiles`, bảng `leaderboard`, phân quyền theo hàng (Row Level Security).

## Hai dự án

| Dự án | Dùng để | URL |
|---|---|---|
| `endless-war-dev` | Phát triển, chạy test | `https://mtsfrhlqoeqaeywypkyi.supabase.co` |
| `endless-war-demo` | Buổi demo và chấm điểm | `https://bbftrwumsajxiwgshnje.supabase.co` |

Khóa dùng trong game là **publishable key**, công khai theo thiết kế, quyền thật nằm ở các chính sách trong `001_init.sql`.
Giá trị mặc định (dự án dev) nằm trong `autoload/game_config.gd`, nhóm Online. Đổi sang demo bằng cách sửa `backend_url` và `backend_public_key`:

| Dự án | publishable key |
|---|---|
| dev | `sb_publishable_zc4q3uAYk2zWisObvTgL8Q_3G6BDbB3` |
| demo | `sb_publishable_OuqURJWJg373n3vjoHg7OA_rgtNo1dk` |

**Không bao giờ** đưa secret key, service_role key hay mật khẩu database vào repo.

## Dựng một dự án mới

1. Tạo dự án trong Supabase. Ở mục Security: giữ **Enable Data API**, bỏ chọn **Automatically expose new tables**, bật **Enable automatic RLS**.
2. Authentication -> Sign In / Providers: bật **Email**. Khi phát triển nên tắt **Confirm email** (bật thì mỗi tài khoản phải bấm link trong email). Khi cần email thật thì cấu hình SMTP riêng.
3. SQL Editor -> New query, dán lần lượt từng file `.sql` trong thư mục này theo thứ tự số (`001_init.sql`, `002_...`, `003_...`), mỗi file bấm Run. Chạy lại nhiều lần vẫn an toàn.
4. Làm cả hai dự án với cùng các file SQL.

## Kiểm tra

Mở `tests/test_auth_service.tscn` trong Godot rồi nhấn F6. Test đăng ký, đăng nhập, đăng xuất, khôi phục phiên và kiểm tra quyền từng hàng bằng hai tài khoản tạm. Test tự xóa hai tài khoản đó khi xong.

## Quy ước

- Mọi thay đổi cấu trúc bảng thêm vào file SQL mới (`002_...sql`), không sửa file đã chạy trên demo.
- Gói Free không có backup tự động, nên SQL trong thư mục này là nguồn để dựng lại.
- Gói Free tạm dừng sau 1 tuần không hoạt động. Trước buổi demo mở dashboard và bấm Restore project.
