# Model và Animation – Endless War

Bảng tra cứu model đã đóng gói sẵn trong `contents/assets/` để TV1, TV2, TV3 gắn vào entity. TV5 quản lý file này.

## Cách dùng

1. Instance scene model vào node `Model` của entity. Không scale node gốc của model, kích thước đã chỉnh sẵn theo mét trong SRS.
2. Lấy `AnimationPlayer` theo đường dẫn ở bảng dưới, gọi clip theo dạng `library/Clip`:

```gdscript
@onready var anim: AnimationPlayer = $Model/GruntModel/Skeleton_Minion/AnimationPlayer
anim.play("move/Running_A")
```

3. Gắn hitbox, VFX vào vũ khí qua Unique Name, ví dụ `%RightHandSlot`.
4. Animation gameplay chạy theo time scale (TIME-04): chỉnh `anim.speed_scale` theo `TimeManager`, không dùng thời gian thực.
5. **Hướng mặt:** model KayKit quay mặt về **+Z** (local), ngược với quy ước -Z của Godot (`look_at`, `-basis.z`). Khi xoay model theo hướng di chuyển, cộng thêm `PI` vào góc Y, hoặc dùng `basis.z` làm hướng trước thay cho `-basis.z`.
6. **Root motion:** các clip Dodge có chuyển động gắn sẵn ở xương `root` (Dodge_Backward lùi 0.65 m, Dodge_Forward tiến 0.25 m). Cách xử lý: **chỉ trong lúc dodge** mới đặt `anim.root_motion_track = NodePath("Rig_Medium/Skeleton3D:root")`, script tự di chuyển nhân vật `dodge_distance` trong thời lượng clip, sau đó `anim.play("general/Idle_A", 0.1)`, chờ hết 0.1 s rồi trả về `anim.root_motion_track = NodePath()`. ⚠️ Không bật thường trực: `root_motion_track` khóa cả vị trí lẫn góc xoay của xương `root`, mà cú xoay của `Melee_2H_Attack_Spin` / `Spinning` nằm ở góc xoay của xương này, bật thường trực thì đòn 3 chỉ giơ kiếm mà không xoay. Mẫu chạy được: `tests/test_commander_anim.tscn`.

## Danh sách model

### Nhân vật

| Model | Scene | Dùng cho (SRS) | Scale | Cao | Material | AnimationPlayer | Vũ khí | Library |
|---|---|---|---|---|---|---|---|---|
| CommanderModel | `characters/commander/commander_model.tscn` | Chỉ huy (Kiếm) | 0.75 | ~1.8 m | commander_material | `Knight/AnimationPlayer` | `%RightHandSlot` (kiếm 2 tay) | general, melee, move, advance, simulation |
| GruntModel | `characters/enemy and boss/grunt_model.tscn` | Grunt | 0.75 | ~1.8 m | skeleton_material_B | `Skeleton_Minion/AnimationPlayer` | `%RightHandSlot` (blade) | general, melee, move |
| ArcherModel | `characters/enemy and boss/archer_model.tscn` | Archer | 0.75 | ~1.8 m | skeleton_material_B | `Skeleton_Rogue/AnimationPlayer` | `%RightHandSlot` (crossbow) | general, move, ranged |
| BruteModel | `characters/enemy and boss/brute_model.tscn` | Brute | 0.95 | ~2.3 m | skeleton_material_B | `Skeleton_Warrior/AnimationPlayer` | `%RightHandSlot` (rìu), `%LeftHandSlot` (khiên) | general, melee, move |
| BossBulwarkModel | `characters/enemy and boss/boss_bulwark_model.tscn` | Boss Bulwark | 0.75 | ~3.7 m | skeleton_material_A | `Skeleton_Golem/AnimationPlayer` | `%BoneAttachment3D` (chùy) | general, melee, move (Rig_Large) |
| BossBarrageModel | `characters/enemy and boss/boss_barrage_model.tscn` | Boss Barrage | 0.75 | ~1.8 m | skeleton_material_A | `Necromancer/AnimationPlayer` | `BoneAttachment3D` (gậy, chưa Unique Name) | general, move, ranged |

Collision gợi ý: capsule r 0.4 m, cao 1.8 m cho chỉ huy, Grunt, Archer. Brute khoảng r 0.6 m, cao 2.3 m (SRS avoid_radius 0.9 m).

### Tower

| Model | Scene | Dùng cho (SRS) | Kích thước | Material | Node cấp |
|---|---|---|---|---|---|
| ArrowTowerModel | `towers/arrow_tower_model.tscn` | Tower Arrow | chân 1.6 m, cao ~4 m | tower_material | `%Level1`, `%Level2`, `%Level3` |
| CannonTowerModel | `towers/cannon_tower_model.tscn` | Tower Cannon | chân 1.6 m, cao ~3.9 m | tower_material | `%Level1`, `%Level2`, `%Level3` |
| BarricadeTowerModel | `towers/barricade_tower_model.tscn` | Barricade | rộng 1.5 đến 1.7 m, cao 0.8 đến 1 m | fortress_material | `%Level1`, `%Level2`, `%Level3` |
| FortressModel | `fortress/fortress_model.tscn` | Fortress | 5 × 4 × 16 m | fortress_material | `Visual/` chứa Gate, Keep, tường, tháp |

Nâng cấp tower: bật `visible` của cấp mới, tắt các cấp còn lại. Công trình chưa có animation, hiệu ứng dựng 0.5 s (3.6.4) sẽ bổ sung sau.

## Bảng animation

Cột **Clip** ghi tên clip đã chọn theo dạng `library/Clip`, ô trống là TV5 chưa chọn. Danh sách clip có sẵn ở cuối file. Thời lượng ghi theo giây ở tốc độ x1.

### Chỉ huy (CommanderModel)

| Trạng thái | SRS | Clip | Loop | Thời lượng | Ghi chú |
|---|---|---|---|---|---|
| Idle | 3.5 | general/Idle_A | Có | | |
| Di chuyển | 3.5 | move/Walking_A hoặc move/Running_A | Có | | |
| Đánh đòn 1 | CMB, combo 3 đòn | melee/Melee_1H_Attack_Chop | Không | 1.07 | Hitbox chỉ bật ở khung active (CMB-02) |
| Đánh đòn 2 | CMB | melee/Melee_1H_Attack_Slice_Diagonal | Không | 1.00 | Combo reset sau 0.6 s |
| Đánh đòn 3 | CMB | melee/Melee_2H_Attack_Spin | Không | 2.40 | Có knockback 1.5 m. Chọn `Spin` có chủ đích vì clip đủ cả chuỗi lấy đà → xoay → về thế. `Melee_2H_Attack_Spinning` (0.67 s) chỉ là đoạn xoay ở giữa, dùng riêng sẽ thiếu lấy đà và hồi. Nếu đòn 3 cần nhanh hơn thì tăng `speed_scale` cho riêng clip này. Dodge hủy được phần recovery (SRS 3.5) |
| Dodge | 3.5, Space | advance/Dodge_Forward, advance/Dodge_Backward | Không | 0.40 | Có root motion, xem mục Cách dùng 6. Dodge_Backward dùng khi lùi ngược hướng nhìn |
| Skill (Battle Cry) | skill_animation_time 0.5 s | simulation/Cheering | Không | 1.67 | Khóa di chuyển, clip phải dài khoảng 0.5 s hoặc chỉnh speed |
| Bị đánh | 3.5 | general/Hit_A | Không | | |
| Stunned | 3.5 | | Có | | |
| Recalling | Recall, channel 0.6 s hoặc 3 s | | Có | | Đứng yên |
| Deploying | Deploy, 0.6 s | | Không | | Hạ xuống deploy_point |
| Chết | 3.5 | general/Death_A | Không | | |

### Grunt (GruntModel)

| Trạng thái | SRS | Clip | Loop | Thời lượng | Ghi chú |
|---|---|---|---|---|---|
| Idle / Wait | 3.7 | general/Idle_B | Có | | |
| Di chuyển | 3.7, 3.5 m/s | move/Walking_A hoặc move/Running_A | Có | | |
| Tấn công | 3.7, nhịp 1.0 s | melee/Melee_1H_Attack_Slice_Diagonal | Không | | Clip dài hơn nhịp thì chỉnh speed |
| Bị đánh | 3.7 | general/Hit_B | Không | | |
| Stagger | AI-04, 0.4 s | | Không | | |
| Chết | DEAD | general/Death_B | Không | | |

### Archer (ArcherModel)

| Trạng thái | SRS | Clip | Loop | Thời lượng | Ghi chú |
|---|---|---|---|---|---|
| Idle / Hold | 3.7, dừng khi có mục tiêu | general/Idle_B | Có | | |
| Di chuyển | 3.7, 3.0 m/s | move/Walking_A hoặc move/Running_A | Có | | |
| Ngắm | 3.7 | ranged/Ranged_2H_Aiming | Có | | |
| Bắn | AI-02, nhịp 1.5 s | ranged/Ranged_2H_Shoot | Không | | Đạn sinh ở đầu crossbow |
| Bị đánh | 3.7 | general/Hit_B | Không | | |
| Stagger | AI-04, 0.4 s | | Không | | |
| Chết | DEAD | general/Death_B | Không | | |

### Brute (BruteModel)

| Trạng thái | SRS | Clip | Loop | Thời lượng | Ghi chú |
|---|---|---|---|---|---|
| Idle | 3.7 | general/Idle_B | Có | | |
| Di chuyển | 3.7, 2.0 m/s | move/Walking_B hoặc move/Running_B | Có | | Đi chậm, nên dùng clip Walking |
| Tấn công | 3.7, nhịp 2.0 s | melee/Melee_1H_Attack_Slice_Horizontal | Không | | |
| Bị đánh | 3.7 | | Không | | Miễn knockback và stun, không cần Stagger |
| Chết | DEAD | general/Death_B | Không | | |

### Boss Bulwark (BossBulwarkModel)

| Trạng thái | SRS | Clip | Loop | Thời lượng | Ghi chú |
|---|---|---|---|---|---|
| Idle | 3.11 | | Có | | |
| Di chuyển | 3.11 | | Có | | |
| Stomp wind-up | Stomp, wind-up 1.0 s | | Không | | Hiện vòng đỏ telegraph cùng lúc (FBK-06) |
| Stomp | Stomp, nhịp 2.5 s, AoE 3 m | | Không | | Rung màn hình (FBK-03) |
| Bị đánh | 3.11 | | Không | | |
| Chết | 3.11 | | Không | | |

### Boss Barrage (BossBarrageModel)

| Trạng thái | SRS | Clip | Loop | Thời lượng | Ghi chú |
|---|---|---|---|---|---|
| Idle / Hold | BOSS-41 | | Có | | |
| Di chuyển | BOSS-41 | | Có | | |
| Bắn Shell | Shell, nhịp 3 s | | Không | | Đạn cong 15 m/s, đánh dấu điểm rơi 1.2 s |
| Bị đánh | 3.11 | | Không | | |
| Chết | 3.11 | | Không | | |

## Clip có sẵn

Thời lượng ở tốc độ x1. (L) là clip đã bật loop.

**general** (Rig_Medium): Death_A 0.80, Death_B 2.63, Hit_A 0.67, Hit_B 0.87, Idle_A 1.07 (L), Idle_B 2.13, Interact 1.30, PickUp 1.30, Spawn_Air 1.30, Spawn_Ground 1.30, Throw 1.37, Use_Item 1.60

**move** (Rig_Medium): Jump_Full_Long 2.33, Jump_Full_Short 1.17, Jump_Idle 1.07, Jump_Land 0.67, Jump_Start 0.60, Running_A 0.80 (L), Running_B 0.80 (L), Walking_A 1.07 (L), Walking_B 1.07 (L), Walking_C 1.60 (L)

**melee** (Rig_Medium): Melee_1H_Attack_Chop 1.07, Melee_1H_Attack_Jump_Chop 1.33, Melee_1H_Attack_Slice_Diagonal 1.00, Melee_1H_Attack_Slice_Horizontal 1.37, Melee_1H_Attack_Stab 1.60, Melee_2H_Attack_Chop 1.63, Melee_2H_Attack_Slice 1.10, Melee_2H_Attack_Spin 2.40, Melee_2H_Attack_Spinning 0.67, Melee_2H_Attack_Stab 1.60, Melee_2H_Idle 1.07, Melee_Block 1.07, Melee_Block_Attack 1.07, Melee_Block_Hit 1.07, Melee_Blocking 1.07, Melee_Dualwield_Attack_Chop 1.27, Melee_Dualwield_Attack_Slice 1.17, Melee_Dualwield_Attack_Stab 1.60, Melee_Unarmed_Attack_Kick 0.93, Melee_Unarmed_Attack_Punch_A 1.17, Melee_Unarmed_Idle 1.07

**advance** (Rig_Medium, hiện chỉ gắn cho chỉ huy): Crawling 1.07, Crouching 1.07, Dodge_Backward 0.40, Dodge_Forward 0.40, Dodge_Left 0.40, Dodge_Right 0.40, Running_HoldingBow 0.80, Running_HoldingRifle 0.80, Running_Strafe_Left 0.80, Running_Strafe_Right 0.80, Sneaking 2.13, Walking_Backwards 1.07

**simulation** (Rig_Medium, hiện chỉ gắn cho chỉ huy): Cheering 1.67, Lie_Down 3.00, Lie_Idle 2.67, Lie_StandUp 2.33, Push_Ups 1.03, Sit_Chair_Down 0.80, Sit_Chair_Idle 3.60, Sit_Chair_StandUp 0.80, Sit_Floor_Down 1.00, Sit_Floor_Idle 4.00, Sit_Floor_StandUp 1.13, Sit_Ups 1.73, Waving 2.13

**ranged** (Rig_Medium): Ranged_1H_Aiming 1.07, Ranged_1H_Reload 1.17, Ranged_1H_Shoot 1.07, Ranged_1H_Shooting 1.60, Ranged_2H_Aiming 1.60, Ranged_2H_Reload 1.60, Ranged_2H_Shoot 1.07, Ranged_2H_Shooting 1.07, Ranged_Bow_Aiming_Idle 1.83, Ranged_Bow_Draw 1.33, Ranged_Bow_Draw_Up 1.33, Ranged_Bow_Idle 1.57, Ranged_Bow_Release 1.33, Ranged_Bow_Release_Up 1.37, Ranged_Magic_Raise 2.10, Ranged_Magic_Shoot 0.93, Ranged_Magic_Spellcasting 0.67, Ranged_Magic_Spellcasting_Long 2.53, Ranged_Magic_Summon 4.30

**Bulwark – general** (Rig_Large): Death_A 1.67, Hit_A 0.70, Idle_A 1.97 (L), Idle_B 6.00 (L)

**Bulwark – move** (Rig_Large): Running_A 1.07 (L), Walking_A 1.07 (L)

**Bulwark – melee** (Rig_Large): Melee_1H_Slash 1.57, Melee_1H_Stab 1.40, Melee_2H_Attack 1.33, Melee_2H_Idle 1.57, Melee_2H_Slam 2.83, Melee_Block 1.07, Melee_Block_Attack 1.03, Melee_Block_Hit 0.67, Melee_Blocking 1.07, Melee_Dualwield_Slash 1.03, Melee_Dualwield_SlashCombo 1.60, Melee_Unarmed_Idle 1.07, Melee_Unarmed_Kick 1.70, Melee_Unarmed_Punch 1.23, Melee_Unarmed_Smash 3.47

## Việc còn lại

- [ ] Điền cột Clip, Loop, Thời lượng cho các bảng trên
- [x] Thêm library `Rig_Medium_MovementAdvanced` cho chỉ huy để có Dodge
- [ ] Bật loop cho clip Idle, Di chuyển, Ngắm, Recalling, Stunned trong Advanced Import nếu clip chọn chưa có (L)
- [ ] Bật Unique Name cho `BoneAttachment3D` của Barrage, đổi tên thành `RightHandSlot` cho thống nhất
- [ ] Animation dựng 0.5 s cho tower (3.6.4)
