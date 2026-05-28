# 🐨 Koala Tycoon: Project Manifest
**Last Updated: May 3, 2026**

### 🏆 Current Milestone: Tutorial & AI Stability (Phase 2 - COMPLETED)
We have successfully implemented the "Rescue KK" tutorial and refined the NPC AI into a stable, "real-feeling" behavior loop.

### 🛠️ Core Technical Pillars (Lessons Learned)

PRIMARY: The local folder is the absolute Source of Truth for all scripts/files.
- **The Protocol (Local-First Scripts)**: All script and code modifications must be done *exclusively* in the local files. The AI must never write script code directly to Roblox Studio via MCP.
- **The Sync (User Copy-Paste)**: The user will copy and paste the updated script contents from the local folder into Roblox Studio.
- **The Exception (Non-Script Objects via MCP)**: The AI will use the Roblox Studio MCP tools (like running Luau code) to inspect, place, and configure non-script objects (Parts, ProximityPrompts, Attributes, Tags, folder structures). This allows the AI to reference the game state as a source of truth without editing script code in Studio.
- **The Verification**: Always verify that the local codebase has been modified before notifying the user of needed copy-paste operations.

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

#### 7. Decoupled "Event-Bus" Architecture
- **The Rule**: **No-Require**. Game logic `ModuleScripts` must NOT require other logic modules directly.
- **The System**: Use `ServerStorage.Signals` (BindableEvents/Functions) for all cross-system communication.
- **Benefits**: This ensures "Feature Isolation." If the Shop system crashes, the Quest system keeps running because it only cares about signals, not direct memory pointers.
- **Standard Signals**: 
    - `RequestTransaction`: Safely handles currency via the Economy layer.
    - `AwardTool`: Decoupled item granting.
    - `UpdateQuest`: Decoupled UI updates.
    - `ForcePickup`: Decoupled interaction/carry logic.

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
1.  **AI writes local scripts**: The AI writes/updates scripts only in the local directory. It explains precisely what it changed, so the human can copy/paste it into Studio.
2.  **AI handles object manipulation via MCP**: The AI uses the Roblox Studio MCP tools to inspect the game tree, place models/parts, configure ProximityPrompts, and check current world state properties.
3.  **Surgical Changes**: Fix one feature/bug at a time. Never delete, rewrite, or leave out unrelated code, imports, or local declarations.
4.  **No Regression Search**: Before modifying functions or scripts, the AI must search the codebase for references to those symbols or systems to ensure no external dependencies are broken.
5.  **Health Checks**: If a system fails, use the MCP tools to inspect the Explorer hierarchy and check if instances exist and have correct attributes/properties.

### 📅 Next Session Goals
1.
2. **Happiness System**: Expand the "Hunger" loop into a full "Happiness" meter that impacts the tycoon's income.
3. **The Store**: Implement the leaf-collection store loop.


NewKK is the model we're using for normal Koalas.  
