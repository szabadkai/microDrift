```markdown
# PRD: Project Micro-Drift

**Vision:** A high-intensity, top-down 2.5D combat racer combining the technical drifting of *Absolute Drift*, the elimination-style local multiplayer of *Micro Machines*, and the "Art of Rally" minimalist toy aesthetic.

---

## 1. Executive Summary
*Micro-Drift* is a physics-based local multiplayer racing game. Players control RC-style cars across household environments. Success is defined by mastering momentum-based drifting, strategic use of "household" power-ups, and surviving the "Elimination Camera."

## 2. Core Gameplay Mechanics

### 2.1 Physics & Handling
*   **Momentum Drifting:** A friction-slip model where steering and throttle control determine the drift angle.
*   **Drift-to-Boost:** Drifting builds a "Charge Meter." Releasing the drift initiates a forward speed impulse (Blue/Orange spark tiers).
*   **Downforce:** Artificial gravity scaling to ensure small vehicles remain grounded during high-speed maneuvers on uneven surfaces (tables, ramps).

### 2.2 Combat & Power-ups
*   **Household Arsenal:**
    *   **Elastic Band:** Straight-fire projectile causing a 180-spin.
    *   **The Marble:** Dropped physics hazard that creates high-impulse collisions.
    *   **AA Battery:** Instant torque multiplier for 1.5s.
*   **Pickup System:** Rotating "Gift Box" nodes placed at high-risk/high-reward locations on the track.

### 2.3 The Elimination Loop
*   **Shared Camera:** A dynamic camera that bounds all players.
*   **Edge Elimination:** Players forced off the screen by the lead player or environmental hazards are eliminated.
*   **Round System:** Last player standing wins the point. First to 5 points wins the match.

---

## 3. Aesthetic & Technical Direction

### 3.1 Visuals (Art of Rally Style)
*   **Perspective:** `Camera3D` with low FOV (20-30°) for a "macro lens" toy look.
*   **Environments:** High-saturation, clean minimalist textures. Household objects (pencils, cereal) act as obstacles.
*   **Post-Processing:**
    *   **Tilt-Shift:** Edge-blur to emphasize small scale.
    *   **Cel-Shading:** Subtle outlines for object readability.
    *   **VFX:** "Poof" smoke particles and comic-style "ZAP!" labels for hits.

### 3.2 Technical Stack (Godot 4.x)
*   **Engine:** Godot 4 (Forward+ Renderer).
*   **Physics:** Godot Jolt plugin (for superior high-speed collision stability).
*   **Vehicle Node:** `VehicleBody3D` base with custom friction scripting.
*   **Input:** Multi-controller support via Godot `Input` mapping.

---

## 4. Engineering Requirements

### 4.1 Vehicle Controller Logic
```gdscript
# Core attributes for drift-handling
velocity_based_friction = clamp(current_speed / max_speed, 0.2, 1.0)
if handbrake_pressed:
    rear_wheels.friction_slip = 0.5 * velocity_based_friction
```

### 4.2 Dynamic Camera System
*   Calculate the `AABB` (Axis-Aligned Bounding Box) of all active `Player` positions.
*   Interpolate `camera.position` to the center of the AABB.
*   Adjust `camera.size` or `camera.position.y` based on AABB distance to keep all players in frame until elimination threshold.

---

## 5. Development Roadmap

### Phase 1: Mechanics Prototype (The "Feel")
*   Implement `VehicleBody3D` with drift/friction curves.
*   Develop the Drift-to-Boost charging logic.

### Phase 2: Multiplayer & Combat
*   Dynamic bounding-box camera system.
*   Elimination triggers and round-reset logic.
*   Basic projectile system (Elastic Band).

### Phase 3: Content & Polish
*   Three prototype tracks: "Kitchen Chaos," "Workshop Way," "Garden Path."
*   Integration of Tilt-Shift and Cel-shading post-processing.
*   SFX (High-pitched RC motors, plastic thuds).

---

## 6. Key Success Metrics
*   **Input Latency:** Sub-16ms response for steering.
*   **Game Pace:** Average round duration of 30–45 seconds.
*   **Readability:** 100% clarity of player position during 4-player zoomed-out scenarios.
```