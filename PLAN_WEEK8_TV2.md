# Sprint Plan & Implementation Report - Week 8 (TV2: @Ender-Via)

## 1. Project Context & Constraints
- **Role:** TV2 (@Ender-Via / Kiet) - Enemy, Boss, Spawning, Navigation, Combat logic.
- **Sprint Target:**
  - `W8-KT1`: Crowd mechanics & attack slot cleanup (`avoid_radius`, 12 attacking / 8 waiting on Fortress, slot freed on death/knockback >3m, slot audit every 2s, release aggro on `recall_completed`).
  - `W8-KT2`: Bulwark Framework: Spawn on Wave 5, Stomp attack (telegraph ring 3m, 1.0s wind-up, 45 BLAST damage, screen shake 0.6, 3m knockback & 1.5s stun on commander); no friendly fire on enemy allies; Dodge i-frame evades damage & knockback; Deploying has knockback immunity; Bulwark moves to `boss_melee_point` at Fortress without taking melee slots; 1-parameter signature `get_resist(dmg_type)`.
  - `W8-KT3`: API contract alignment with TV3 (Manh) and TV4 (Khang) for `REWARD_PICK` state flow and XP/pending picks.
- **Strict Guidelines:**
  - No document citations or SRS IDs in project files or comments.
  - Minimal English comments only.
  - Zero Vietnamese in project files.
  - No hardcoded parameters; use resources and configurations.
  - 100% mouse-driven interactive test UI without key hijacking.

---

## 2. Summary of Completed Deliverables

### A. W8-KT1: Crowd & Attack Slots
- Added `avoid_radius` to `EnemyData` and configured resources:
  - Grunt: `0.5`
  - Archer: `0.5`
  - Brute: `0.9`
  - Bulwark: `1.6`
- Connected `EventBus.recall_completed` in `Enemy` to drop commander aggro and resume standard lane march.
- Implemented slot audit every 2.0s in `MeleeSlotSet` verifying distance <= 3.0m and ensuring units target the slot owner.

### B. W8-KT2: Bulwark Framework
- `Bulwark` class derived from `Enemy`:
  - Enters `boss` group.
  - Stomp attack: 1.0s wind-up telegraph (`telegraph_started`), 45 BLAST damage, 3.0m radius, 3.0m knockback, 1.5s stun, 0.6 screen shake (`screen_shake_requested`).
  - Dodge i-frame evasion check on Commander (`is_dodging`).
  - Knockback immunity check on Commander (`is_deploying`).
  - Anti-friendly-fire: excludes allied enemies from Stomp damage.
  - Dedicated Fortress routing: navigates directly to `boss_melee_point` without occupying `MeleeSlotSet` slots.
  - Standardized 1-parameter `get_resist(dmg_type: Enums.DamageType) -> float` forwarding to `BossData.get_resist(dmg_type, current_phase)`.
  - Signal `EventBus.boss_defeated` emitted on defeat.

### C. W8-KT3: Wave Flow & Reward State Alignment
- Wave 5 boss combat transitions: `BOSS_COMBAT` state, `EventBus.boss_spawned` emission, wave scaling applied to Bulwark.
- `REWARD_PICK` pause flow: `advance_from_summary()` checks `pending_picks` via `XpTracker`, requests pause via `TimeManager.REASON_REWARD_PICK`, and transitions to `PREP` only when all pending cards are picked.

### D. Testing & Playtest Suite
- **Automated Test Runner (`tests/test_bulwark_and_crd_runner.tscn`):** 55 unit tests across 13 test groups passing with 0 failures.
- **Attack Slot Test Runner (`tests/test_attack_slot_runner.tscn`):** 75 unit tests passing with 0 failures.
- **Interactive Playtest (`tests/test_playtest_bulwark_and_crowd.tscn`):**
  - **Zero Key Hijacking:** Deleted all `_unhandled_input` key captures so WASD, Space (dodge), and mouse combat are 100% dedicated to Commander control.
  - **Zero Auto-Spawning:** `wave_manager.set_physics_process(false)` and `spawn_queue.clear()` prevent background waves from spawning automatically.
  - **Mouse-Click Controls:** Complete side-panel UI with buttons for spawning Bulwark, triggering Stomp, switching phase, testing damage types, spawning Fortress crowds (12 attacking / 8 waiting), testing knockbacks, and testing card reward transitions.
