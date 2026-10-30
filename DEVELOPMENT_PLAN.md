# Operation Last Stand — Development Plan

## 1. Project Overview & Target Specification

**Operation Last Stand** is a single-player tactical 3D First-Person Shooter (FPS) set in an abandoned military underground research bunker. The player must navigate the claustrophobic corridors, clear out hostile soldier patrols, manage their ammunition, and eliminate all threats to secure the facility.

### Technical Target Specifications
* **Engine:** Godot Engine 4.x (GDScript only, no C#).
* **Renderer:** **Compatibility** (`gl_compatibility`) for high frame rates and compatibility with low-end Windows hardware (integrated GPUs, older hardware).
* **Physics Engine:** Jolt Physics / Default Godot 3D Physics (smooth kinematic player and raycast collision).
* **Visual Style:** Clean low-poly / modular geometry using Godot's built-in CSG primitives, PBR standard materials, and real-time point/spot lights.
* **Architecture Pattern:** Component-based entity design with decoupled Event-Bus / Global Game State, strictly avoiding hard node couplings.

---

## 2. Project Architecture & Organization

The project follows a modular, feature-oriented structure where scenes and their associated logic are grouped together, supplemented by reusable components and shared autoloads.

```
res://
├── assets/
│   ├── audio/
│   │   ├── sfx/                # Sound effects (gunshot, reload, hit, footstep, alert)
│   │   └── music/              # Background ambient drone and combat audio
│   └── materials/              # Prototype materials (concrete, dark metal, hazard stripe, crate)
│
├── scenes/
│   ├── player/
│   │   ├── player.tscn         # CharacterBody3D FPS controller with Camera3D and WeaponMount
│   │   └── player.gd           # First-person movement, mouse look, jump, weapon hookup
│   │
│   ├── weapons/
│   │   ├── pistol.tscn         # Weapon scene (MeshInstance3D primitive, RayCast3D, audio, timer)
│   │   ├── pistol.gd           # Semi-automatic shooting, ammo management, recoil
│   │   └── bullet_decal.tscn   # Impact spark/decal scene for hit surfaces
│   │
│   ├── enemies/
│   │   ├── enemy_soldier.tscn  # CharacterBody3D with NavigationAgent3D and RayCast3D sight
│   │   ├── enemy_soldier.gd    # State machine (Patrol / Chase / Attack)
│   │   └── enemy_spawner.tscn  # Level spawner / marker for enemy placement
│   │
│   ├── levels/
│   │   ├── facility_level.tscn # Main level with NavigationRegion3D, lighting, and WorldEnvironment
│   │   ├── facility_level.gd   # Level logic, enemy registry, mission trigger
│   │   └── props/              # Reusable environmental props (crates, blast doors, light fixtures)
│   │
│   └── ui/
│       ├── hud.tscn            # Reticle/crosshair, health bar, ammo display, remaining enemies
│       ├── hud.gd              # HUD signal listener
│       ├── pause_menu.tscn     # Pause overlay (Resume, Restart, Quit)
│       ├── victory_screen.tscn # Mission Complete UI
│       └── game_over_screen.tscn # Mission Failed UI
│
├── scripts/
│   ├── autoload/
│   │   ├── game_manager.gd     # Game state machine (PLAYING, PAUSED, VICTORY, GAME_OVER)
│   │   └── sound_manager.gd    # Centralized audio pooling and playback
│   │
│   └── components/
│       ├── health_component.gd # Reusable Health node for Player and Enemies (takes damage, emits signals)
│       └── hitbox_component.gd # Area3D or collision wrapper that directs damage to HealthComponent
│
└── DEVELOPMENT_PLAN.md
```

### Purpose of Core Folders & Scenes

1. **`assets/`**:
   - Stores raw visual and audio resources.
   - `materials/`: Preconfigured `StandardMaterial3D` resources with roughness, metallic, and albedo settings to establish an abandoned military theme without external textures.
   - `audio/`: Placeholder and synthesized sound assets for gunshots, impacts, footfalls, and UI.

2. **`scenes/player/`**:
   - `player.tscn`: A `CharacterBody3D` with a capsule collision shape, a `Head` Node3D holding the `Camera3D`, and a `WeaponHolder` Node3D.
   - Decoupled from weapons: weapons are child nodes or plugged into the weapon socket.

3. **`scenes/weapons/`**:
   - Standalone weapon scenes. The pistol operates via `RayCast3D` hitscan for immediate, accurate, and performant shooting.
   - Communicates ammunition count and firing state through signals.

4. **`scenes/enemies/`**:
   - Enemy AI soldier scene using `CharacterBody3D` + `NavigationAgent3D`.
   - Utilizes basic state logic (`IDLE`, `PATROL`, `CHASE`, `ATTACK`) driven by line-of-sight raycasting.

5. **`scenes/levels/`**:
   - `facility_level.tscn`: The single 3D level built with CSG (Constructive Solid Geometry) shapes baked into a `NavigationRegion3D`.
   - Optimized with static lighting, baked navmesh, and clean room-corridor flow.

6. **`scenes/ui/`**:
   - CanvasLayer scenes for the HUD (always active during gameplay) and state overlay menus (pause, game over, victory).

7. **`scripts/autoload/`**:
   - Singletons registered in `project.godot`.
   - `GameManager`: Holds global game state, enemy counters, objective state, and scene reload routines.

8. **`scripts/components/`**:
   - Component-based architecture. Both player and enemies share the exact same `HealthComponent`, ensuring damage dealing and receiving behavior is uniform, bug-free, and easy to unit test.

---

## 3. Incremental Milestone Roadmap

### Milestone 1: Core Configuration & First-Person Controller
* **Objective:** Establish the low-end Compatibility rendering configuration, input bindings, and a responsive FPS character controller.
* **Deliverables:**
  - Update `project.godot` to Compatibility renderer (`gl_compatibility`) and configure input actions (`move_forward`, `move_back`, `move_left`, `move_right`, `jump`, `sprint`, `fire`, `reload`, `pause`).
  - Create `scenes/player/player.tscn` (`CharacterBody3D` with CapsuleShape3D, Camera3D, smooth mouse look with pitch limits, acceleration/deceleration, sprinting, and head-bobbing).
  - Create a temporary testing sandbox room (`scenes/levels/test_gym.tscn`) with a floor and test obstacles.
* **Testing Guide:**
  - Launch `test_gym.tscn`.
  - Verify mouse capture on click, smooth look rotation, WASD movement, jump, sprint, and collision against static blocks.

---

### Milestone 2: Abandoned Facility Level Blockout & Navigation
* **Objective:** Construct the 3D game level using built-in primitives and bake a 3D navigation mesh.
* **Deliverables:**
  - Build `scenes/levels/facility_level.tscn` using CSG boxes, cylinders, and stairs:
    - Entry airlock / starting room.
    - Central command hub / generator room.
    - Connecting industrial corridors with tactical cover obstacles (crates, barriers).
    - Barracks / armory sector.
  - Apply distinct military prototype materials (grey concrete, weathered metal, hazard yellow borders).
  - Add `NavigationRegion3D` and bake navigation mesh for AI traversal.
  - Set up low-cost ambient lighting (`DirectionalLight3D` with subdued tones, point lights with reasonable ranges, and a dark atmospheric `WorldEnvironment`).
* **Testing Guide:**
  - Walk through the entire facility level using the player controller.
  - Verify zero clipping, smooth stair climbing, consistent frame rates, and valid baked navmesh.

---

### Milestone 3: Pistol Weapon & Hitscan Shooting System
* **Objective:** Implement a responsive first-person pistol with raycast hitscan, ammo tracking, reload mechanics, and visual/audio feedback.
* **Deliverables:**
  - Create `scenes/weapons/pistol.tscn` attached to the player's camera rig:
    - Built-in primitive mesh model (receiver, barrel, grip).
    - RayCast3D aligned with the center of the viewport.
    - Muzzle flash indicator (`OmniLight3D` + small mesh flash for a brief tick).
    - Firing cooldown timer and reload timer.
  - Firing logic: Semi-automatic, magazine capacity (e.g., 12 rounds), reserve ammo (e.g., 36 rounds).
  - Impact effect: `scenes/weapons/bullet_decal.tscn` placed at raycast collision point with normal alignment.
* **Testing Guide:**
  - Left-click to fire; verify cooldown, ammo decrease, muzzle flash, and hitscan impact sparks on level walls.
  - Press 'R' to reload; verify reload timer and magazine replenishment. Empty magazine prevents firing.

---

### Milestone 4: Health & Damage Component Architecture
* **Objective:** Build a reusable, modular health and damage interface shared across all living entities.
* **Deliverables:**
  - Create `scripts/components/health_component.gd`:
    - Exported `max_health`, `current_health`.
    - Signals: `health_changed(current, max)`, `damaged(amount)`, `died()`.
    - Methods: `take_damage(amount: float)`, `heal(amount: float)`.
  - Attach `HealthComponent` to Player.
  - Wire weapon hitscan to detect whether hit collider has or belongs to a `HealthComponent` (or implements `take_damage`).
  - Add damage flinch / red screen vignette flash indicator on player when taking damage.
* **Testing Guide:**
  - Create a dummy target block with `HealthComponent`.
  - Shoot target; verify target receives damage and triggers `died` signal when health hits 0.
  - Verify player takes damage via debug trigger and emits expected signals.

---

### Milestone 5: Enemy Soldier AI with Navigation & Combat
* **Objective:** Implement functional enemy soldier agents that patrol, detect the player, pursue using navigation, and fire back.
* **Deliverables:**
  - Create `scenes/enemies/enemy_soldier.tscn`:
    - Distinct primitive model (red/tactical grey capsule with visor/weapon).
    - `CharacterBody3D`, `CollisionShape3D`, `NavigationAgent3D`.
    - `HealthComponent` attached.
    - Vision cone detection via `RayCast3D` checking for unobstructed line of sight to player.
  - AI State Machine (`scripts/enemies/enemy_soldier.gd`):
    - **IDLE / PATROL:** Moves between patrol markers or idle watches.
    - **CHASE:** Moves toward player's position using `NavigationAgent3D`.
    - **ATTACK:** Stops at shooting distance, faces player, and fires burst shots with cooldown and spread.
    - **DEATH:** Collision disabled, play death dissolve or fall over, notify manager.
* **Testing Guide:**
  - Place 2-3 enemies in `facility_level.tscn`.
  - Observe enemies moving along navmesh, spotting player, pursuing, and shooting.
  - Shoot enemies until health reaches 0; verify death behavior and cleanup.

---

### Milestone 6: Game Loop, Objectives & State Management
* **Objective:** Tie together the core mission loop: eliminate all enemies to win, death triggers game over.
* **Deliverables:**
  - Create `scripts/autoload/game_manager.gd`:
    - Tracks total active enemies in level.
    - Listens to enemy death events (`enemy_killed`).
    - Tracks player alive/dead status.
    - Signals: `enemy_count_changed(remaining)`, `victory_achieved`, `game_over`.
  - Level integration: Automatically registers all `EnemySoldier` instances on level start.
* **Testing Guide:**
  - Start level with 3 enemies; verify counter says "3 remaining".
  - Kill enemies one by one; verify counter updates.
  - When last enemy dies, `victory_achieved` is triggered.
  - When player dies, `game_over` is triggered.

---

### Milestone 7: HUD, Victory, Game Over & Pause Menus
* **Objective:** Provide a polished, intuitive UI for gameplay feedback and menu flow.
* **Deliverables:**
  - `scenes/ui/hud.tscn`:
    - Minimalist reticle / crosshair.
    - Health bar & percentage text.
    - Current ammo / reserve ammo counter.
    - Enemies remaining tracker ("Hostiles: X").
  - `scenes/ui/victory_screen.tscn`:
    - "Mission Accomplished — Facility Secured".
    - Buttons: "Play Again", "Quit to Desktop".
  - `scenes/ui/game_over_screen.tscn`:
    - "K.I.A. — Mission Failed".
    - Buttons: "Retry", "Quit to Desktop".
  - `scenes/ui/pause_menu.tscn`:
    - Triggered by `Escape` / `pause`.
    - Releases mouse cursor, pauses game tree (`get_tree().paused = true`), allows resume or restart.
* **Testing Guide:**
  - Test UI updates live during combat (ammo decrements, health bar drops on damage).
  - Test winning the mission; verify Victory screen appears with mouse cursor freed.
  - Test player death; verify Game Over screen appears.
  - Test pause menu during play.

---

### Milestone 8: Audio, Polish & Low-End Optimization (COMPLETED)
* **Objective:** Polish player feel (game-feel), integrate audio feedback, and optimize performance for low-end hardware.
* **Deliverables:**
  - Audio implementation:
    - Procedural & lightweight PCM WAV audio for pistol shots, reloading, hitmarker ticks, footstep variations, enemy alert & hurt vocals, subterranean bunker drone ambience, UI buttons, victory fanfare, and defeat sting.
  - Weapon feel & FX:
    - Dynamic weapon sway based on mouse velocity.
    - Procedural recoil position and rotational punch with smooth exponential recovery.
    - High-speed visual bullet tracer spawning along hitscan trajectory.
    - Hit impact decals and spark particle flashes on geometry.
  - Enemy feedback & animation:
    - Procedural opposing leg swing walking animation during patrol and chase.
    - Dynamic torso bobbing synchronized with strides.
    - Flinch and stagger reaction on bullet impact with smooth recovery.
    - Menacing visor glow pulsation during alert, chase, and combat states.
  - Atmosphere & Lighting:
    - Volumetric depth fog and underground industrial bunker color palette.
    - Procedural flickering corridor light simulating decaying facility infrastructure.
    - Looping subterranean background drone (`bunker_ambience.wav`).
  - UI Polish:
    - Four-point tactical diagonal hitmarker overlay appearing with high-frequency audio tick upon hostile impact.

---

### Milestone 9: Standalone Windows Desktop Export (COMPLETED)
* **Objective:** Package the entire project into a self-contained, standalone Windows build ready for distribution and testing outside the Godot editor.
* **Deliverables:**
  - `export_presets.cfg`: Configured for "Windows Desktop" using the Compatibility renderer (`gl_compatibility`).
  - Standalone binary directory `build/OperationLastStand/`:
    - `OperationLastStand.exe`: Standalone 64-bit Windows executable.
    - `OperationLastStand.pck`: Packed binary package containing all compiled scripts, scenes, audio samples, shaders, and materials.
    - `OperationLastStand_console.exe`: Companion diagnostic launcher with console logging enabled.
    - `README.txt`: Instructions for players and system requirements.
* **Verification & Testing:**
  - Standalone package tested directly outside the Godot editor.
  - Auto-detection of ANGLE Direct3D 11 / OpenGL ES 3.0 Compatibility verified on Intel HD Graphics.
  - Full game loop verified: Main Menu -> Facility Level -> Combat -> Hitmarkers -> Victory / Game Over -> Retry.

---

## 4. Coding Standards & Conventions

1. **Language:** GDScript 2.0 (Godot 4.x).
2. **Static Typing:** Use explicit type hints for variables, parameters, and return types (e.g., `var speed: float = 5.0`, `func take_damage(amount: float) -> void:`).
3. **Naming Conventions:**
   - Files and folders: `snake_case.gd`, `snake_case.tscn`.
   - Classes and Custom Types: `PascalCase`.
   - Functions and Variables: `snake_case`.
   - Constants and Enums: `UPPER_SNAKE_CASE`.
   - Private methods/variables: prefixed with `_` (e.g., `_update_hud()`).
4. **Node Decoupling:**
   - "Call down, signal up". Parent nodes may invoke methods on direct children; children must emit signals rather than calling `get_parent()` or hardcoded node paths.
5. **No External Asset Dependencies:**
   - All 3D visuals are built using Godot's native CSG and primitive mesh tools with standard materials, keeping the project 100% self-contained and reproducible.

