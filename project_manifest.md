# 🐨 Koala Tycoon: Project Manifest
**Last Updated: May 3, 2026**

### 🏆 Current Milestone: Tutorial & AI Stability (Phase 2 - COMPLETED)
We have successfully implemented the "Rescue KK" tutorial and refined the NPC AI into a stable, "real-feeling" behavior loop.

### 🛠️ Core Technical Pillars (Lessons Learned)

PRIMARY: We copied the scripts to this folder. We need to keep these in sync. 
- **The Protocol**: I will update the local folder first (Source of Truth) directly in the files here.  
- **The Verification**: User will manually copy and paste scripts into Studio. This has become the only sure way we are making sure it is in sync

#### 1. The "Physics Lock" for Climbing
- **The Problem**: CFraming an unanchored model into a solid part (Tree) creates explosive physics pressure.
- **The Rule**: **Always Anchor** the HumanoidRootPart during manual movement/climbing. Unanchor only upon landing.
- **Landing Safety**: Use `PivotTo` and `Humanoid:ChangeState(GettingUp)` to force an upright posture after a CFrame-heavy movement.

#### 2. The "Constructor" Script Pattern
- **The Rule**: Scripts should never assume a Part or ProximityPrompt exists. They should **create** it if it's missing.
- **Tutorial Safety**: If a tutorial step destroys an object (like a prompt), the "Ongoing" game script should be capable of rebuilding it once the tutorial is finished.

#### 3. Visual Transparency & NPC Tracking
- **The Rule**: NPC visibility in trees/foliage should be maintained by setting Leaf transparency to `0.3` and disabling `CastShadow` on canopy parts.
- **Climb Height**: Keep NPC climbing limits below the thickest part of the leaves (e.g., 5-8 studs).

#### 4. Interaction Conflict Management
- **The Rule**: Never spawn multiple interactive objects (Key, Feeder, Drop Zone) in the same coordinate space. Maintain at least a 5-stud "interaction buffer" to avoid ProximityPrompt overlap.

#### 5. The "Hunger & Revenue" Loop
- **Mechanic**: `HungerService` drains exhibit `FoodLevel` by 5% every 60s. 
- **The Rule**: Starving Koalas don't pay rent. If `FoodLevel` is 0, the exhibit generates $0 income.
- **Refill**: 1 Leaf = 20% Food. Max capacity is 5 (Default) or 20 (Leaf Bag).

#### 6. Exhibit Stat Signs (Info Boards)
- **Standard**: Every exhibit folder must have a part named `SignAnchor`.
- **System**: `ExhibitStatService` attaches a Glassmorphism BillboardGui to this part.
- **Naming**: Players can rename exhibits via the `RenamePrompt` on the board (Server-side safety filtered).

### 🎨 Visual & Aesthetic Standards
*   **World Theme**: Lush park/zoo. Baseplate is always `Material.Grass` (Parsley Green).
*   **Crates**: The "Rusted Transport Crate" should be `Material.CorrodedMetal` with vertical bars.
*   **NPCs**: Friendly, human-looking characters. Avoid "creepy" assets.
*   **Koalas**: Use the custom `KK` model. They should look cute and "cling" to the player.

### 📍 World Layout (Ground Truth)
*   **Spawn**: Central (0, 0, 0).
*   **Vet Shop**: Near spawn with a clear "HEAD VET" label.
*   **Exhibits**: "Tutorial Exhibit" is the starting goal.

### 🧠 Logic & Interaction Rules
*   **Instant Action**: All `ProximityPrompts` should have `HoldDuration = 0`.
*   **Line of Sight**: `RequiresLineOfSight` should be `false` for small items or NPCs in shops.
*   **Tools**: Keys and Hammers should be proper `Tool` objects in the `Backpack`.

---

### 🤝 How We Work Together (AI + Human)
1.  **Human handles Placement**: Move buildings and NPCs manually in Studio. The AI will see the new coordinates.
2.  **AI handles Brains**: The AI writes the scripts for quests, money, and animal behavior.
3.  **Surgical Changes**: Fix one thing at a time. Don't let the AI delete and recreate large parts of your world.
4.  **Health Checks**: If a button stops working, check the "Explorer" to see if the `ProximityPrompt` is still there and enabled.

### 📅 Next Session Goals
1. **The Fur & Finish**: Apply realistic Koala textures and materials without breaking the custom rig.
2. **Happiness System**: Expand the "Hunger" loop into a full "Happiness" meter that impacts the tycoon's income.
3. **The Store**: Implement the leaf-collection store loop.


NewKK is the model we're using for normal Koalas.  
