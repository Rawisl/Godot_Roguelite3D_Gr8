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
- Gói Free dùng bản sao lưu thủ công. SQL trong repo dùng để dựng schema; lưu bản dump dữ liệu dev và demo ngoài repo, có kiểm soát truy cập.
- Gói Free tạm dừng sau 1 tuần không hoạt động. Trước buổi demo mở dashboard và bấm Restore project.

## Leaderboard and account save API

### Demo preparation

1. Check Database, Egress, and Auth usage for both projects in the Supabase dashboard. Confirm demo is active.
2. Export a logical backup using the Supabase CLI backup and restore workflow, including application data and the Auth records required by their user IDs. Keep the dump in team-controlled storage. Verify a restore on an isolated local instance by checking accounts, saves, and leaderboard rows.
3. In a disposable checkout set `GameConfig.online_enabled = false` for the offline demo. Launch with a fresh profile and play through RunEnd. Repeat on the online build with the network disconnected and confirm local progress persists.

Client integration uses `AccountApi.pull_save()`, `AccountApi.push_save()`, `AuthService.fetch_leaderboard()` and the existing save-gated submission service. Sync pauses until RunEnd when requested mid-run. On a tied revision from another device with different data, sync backs up local progress and applies cloud progress. A backup failure leaves the two saves in place.

Apply `005_leaderboard_tolerance.sql`, `006_saves.sql`, then
`007_validate_online_data.sql` on **both dev and demo**. These migrations are
transactional and safe to rerun. Existing deployed files remain unchanged.

All requests use the publishable `apikey` header. Authenticated requests also use
`Authorization: Bearer <access_token>`. `AuthService.rest()` supplies these headers and
uses `GameConfig.sync_timeout` (10 seconds); never log the token.

| Method and path | Request | Response |
|---|---|---|
| `POST /rest/v1/rpc/leaderboard_top` | `{"version":"1.0.0","top_n":50}` | Up to 50 rows: `{rank, display_name, waves_cleared, run_elapsed}`; public access |
| `POST /rest/v1/rpc/leaderboard_my_rank` | `{"version":"1.0.0"}` | The authenticated player's ranked row, or `[]`; guests receive `[]` |
| `PATCH /rest/v1/leaderboard?user_id=eq.<own_id>` | `{waves_cleared, run_elapsed, run_seed, game_version}` | Best row with `Prefer: return=representation`; if absent, insert with `POST /rest/v1/leaderboard` |
| `GET /rest/v1/saves?user_id=eq.<own_id>&select=revision,device_id,updated_at,data` | No body | Own save as a one-element array, or `[]` |
| `PATCH /rest/v1/saves?user_id=eq.<own_id>` | `{revision, device_id, data}` | Updated row with `Prefer: return=representation`; if absent, insert using the next endpoint |
| `POST /rest/v1/saves` | `{user_id, revision, device_id, data}` | New own save with `Prefer: return=representation` |

Ranking sorts by waves descending, elapsed time ascending, then server submission time
ascending. UUID is the final deterministic tie breaker. The server accepts
`run_elapsed + 1 >= 15 * waves_cleared` with a finite, nonnegative elapsed time.
`GameConfig.game_version` identifies the ranking
version; each account still stores one best row, which resets when its version changes.
Clients cannot supply leaderboard names or timestamps.

Save reads and writes require authentication and are restricted to the owning account by
RLS. Clients cannot change ownership or server timestamps. An update must have a revision
strictly greater than the stored value. Writes use PATCH then INSERT so clients do not
need UPDATE permission on `user_id`; simultaneous first inserts return a conflict.

Migration 007 rejects negative revisions, non-object saves, payloads above 1 MiB in
JSONB text form, and negative, fractional or overflowing progression counts. The storage
limit is a technical guard, not a gameplay balance value. Counts must fit Godot's signed
64-bit integer; lifetime prestige and max wave have no additional invented gameplay cap.
Known meta upgrade maxima mirror `data/config/meta_shop/`: FORT_HP 5, GOLD_PCT 4,
CMD_HP 3 and EMG_REPAIR 3. Changing those resources requires a new server migration too.
Profile/meta/flags must be objects, known profile counts must be numeric, and tutorial_done
must be boolean when present. Unknown nested fields remain compatible; run_flag is excluded.
The new checks are `NOT VALID` to preserve existing rows during deployment, while all
new inserts and updates are checked immediately. Existing invalid rows require explicit
repair before an administrator runs `VALIDATE CONSTRAINT`; deployment does not delete them.

| HTTP / database code | Meaning |
|---|---|
| `400` / `23514` | Save or score violates a server check |
| `401` or `403` / `42501` | Missing/invalid session or insufficient permission |
| `409` / `PT409` | Save revision is equal to or older than the stored revision |
| `409` / `23505` | Concurrent first insert; pull the save before retrying |
| `404` / `PGRST202` or `PGRST205` | RPC/table migration missing, or schema cache not refreshed |
| status `0` / `OFFLINE` | Network failure or timeout; retain pending work |

`AuthService.fetch_leaderboard(top_n)` returns `{ok, rows, own}` and uses one public RPC
plus one own-rank RPC for signed-in players. `submit_score()` flushes the in-memory queue.
It receives run results through `EventBus.run_ended`, accepts all three ending types only
after a new run starts at wave 1, excludes recovered/interrupted runs, and waits for
`save_completed`. SaveManager records which RunEnd summary was successfully written;
an unrelated later save failure cannot revoke that confirmation. Network/timeouts,
authentication failures, 408, 429, malformed successful responses and 5xx retain pending
scores and stop the batch. Other 4xx responses discard the rejected score and continue
with remaining saved scores. Retry happens on a later run end or meta purchase. Queued
scores belong to their originating account and are cleared when the session is discarded.
Recovery code must not emit `run_started` while settling an interrupted run; if it emits
`run_ended`, include `interrupted: true` in its summary.
`RunState.start_run()` writes the start flag and emits `run_started` once. Direct main
launches call it after scene readiness. RunLoading must initialize RunConfig first, then
call the same method; do not emit a second start signal when integrating its full flow.
Week 11 work verifies this against the completed RunEnd/recovery flow rather than adding
another submission listener.

### AccountApi handover to SyncService

`systems/auth/account_api.gd` exposes:

- `pull_save() -> {ok, revision, device_id, updated_at, data}`. A missing row returns
  revision `0`, empty strings and empty data. Failures include `error`.
- `push_save(revision, device_id, data) -> {ok, conflict, revision}`. The caller supplies
  the already incremented local revision and persistent device ID from the save envelope.
  A conflict leaves cloud data untouched; `revision` on failure is the attempted revision,
  so call `pull_save()` to obtain the authoritative cloud revision.
- `AccountApi.data_for_sync(save_data)` deep-copies only `profile`, `meta`, and `flags`.
  `flags.tutorial_done` remains alongside `profile`; `run_flag` is excluded.

SyncService owns revision comparison, conflict backup (`save.conflict.bak`), resolution,
retry of cloud saves and the GUEST/SYNCED/SYNCING/OFFLINE/ERROR UI states. AccountApi does
not update local files or emit sync state. Keep the CloudSaveRepository TODO for that work.
The unrelated heal/weapon UI TODOs remain outside this task.

### Verification

Press F6 on `tests/test_auth_service.tscn` with the dev project restored and migrations
001 through 007 applied. It creates two temporary accounts and deletes them afterward;
it checks save round trips/revisions/RLS/tutorial flags, tolerance and ranking order.
An unreachable backend reports an explicit skip, which does not verify server behavior.
Press F6 on `tests/test_leaderboard_submit_runner.tscn` for offline eligibility/retry tests
and `tests/test_leaderboard_account.tscn` for UI checks. F5 should start `main.tscn`
without errors.
For demo, run the same scene with `-- --demo` after the Godot arguments. Temporary account
tests require email confirmation disabled for their duration; restore the demo's desired
authentication configuration after both accounts have been deleted.

Migration 007 was confirmed on dev and demo on 2026-11-15: the expanded network suite
passed 86 checks on each, including direct AuthService.submit_score(), invalid save
payloads, anonymous/cross-account save access, 148.9-second rejection and negative time.
Both temporary accounts were deleted on each project. Offline submission/account checks
passed 51, leaderboard/account UI 17, save repository 68 and save hooks 72, all with zero
failed checks. Headless main started without errors. The submission runner's BOOT warning
and save repository's teardown leaks were eliminated; the repository runner intentionally
still exercises and logs a failed-write error.
The final dev rerun passed 90 checks after retaining rename-trigger and unique-index
regressions in the standard suite. Demo's last completed run passed 86 checks before
those four additional assertions were retained.

PR handover: notify Kiệt (`@kiezroth`) for `autoload/game_config.gd` and Khang (`@WhoKeng`)
for the leaderboard adapter and the AccountApi contract consumed by the week 11 SyncService.
This feature branch depends on PR #187 until its save metadata changes reach main.
