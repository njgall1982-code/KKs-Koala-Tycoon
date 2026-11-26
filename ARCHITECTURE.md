# KK's Koala Tycoon — Architecture

_Last reviewed: Nov 25, 2026. Keep this file current: when you add a service, remote, or signal, update the relevant section._

## 1. Two places, one experience
| Place | Place ID | Local folder | Rojo project | Port |
|---|---|---|---|---|
| Tycoon (start place) | 101119931747763 | repo root | `default.project.json` | 34872 |
| Rescue Forest | 79103142136739 | `RescueForest/` | `RescueForest/default.project.json` | 34873 |

Both live in universe `10115350877` (owner user `7094387362`). Teleport via `TeleportToForest` / `TeleportBackToTycoon`.

## 2. Source of truth & workflow (Rojo)
- **Local files are the source of truth for ALL scripts.** Rojo syncs them into Studio live. Never edit a synced script inside Studio (the next sync overwrites it).
- Rojo only maps **scripts**. GUIs, Tools, Models, RemoteEvents, Workspace objects live in Studio (the published place) and are left alone (`$ignoreUnknownInstances`).
- Start servers from the repo root:
  - Tycoon: `.\tools\rojo\rojo.exe serve default.project.json`
  - Forest: `.\tools\rojo\rojo.exe serve RescueForest\default.project.json --port 34873`
  - In Studio: Rojo plugin → set port → Connect.
- **File naming = script class:** `*.server.lua` → Script, `*.client.lua` → LocalScript, `*.lua` → ModuleScript.
- Adding a script inside an existing GUI/Tool needs a line in the project file (see `StarterGui` / `ServerStorage` entries). Scripts in mapped folders (`Services/`, `Modules/`, `StarterPlayerScripts/`) are picked up automatically.
- Publish from Studio (File → Publish to Roblox) after verifying; local files are not the live game until published.
- Backups: `Backups/` (pre-Rojo snapshots), `Old backups/` (history). Binary `.rbxl` files are git-ignored.

## 3. Folder → Roblox mapping (Tycoon)
| Local | Studio | Contents |
|---|---|---|
| `ServerScriptService/Main.server.lua` | ServerScriptService.Main | Bootstrap: loads and initializes every service in order |
| `ServerScriptService/Services/` | ServerScriptService.Services | Feature services (one concern each, `Initialize()` entry point) |
| `ServerScriptService/Modules/` | ServerScriptService.Modules | Server-only helpers: `KoalaLifecycle`, `KoalaGrowth`, `KoalaVFX` |
| `ReplicatedStorage/Modules/` | ReplicatedStorage.Modules | Shared: `Net`, `Log`, `KoalaConfig`, `GameConstants` |
| `ReplicatedStorage/Config/` | ReplicatedStorage.Config | Data tables: `MusicConfig`, `OutfitShopConfig`, `StaffConfig` |
| `StarterPlayer/StarterPlayerScripts/` | StarterPlayerScripts | Client controllers (world-level UI/logic) |
| `StarterGui Controllers/` | StarterGui.<Gui>.<script> | Client scripts that live inside a specific ScreenGui |
| `ServerStorage/`, `StarterPack/` | Tools | Scripts inside Tools (`TransferCrate`, `Garden Shovel`, `DevWand`) |

## 4. Communication rules
1. **Client ↔ Server = RemoteEvent/RemoteFunction**, only via `Net.Remote("Name")`.
2. **Server ↔ Server (feature to feature) = Signals** (BindableEvent/Function in `ServerStorage.Signals`), only via `Net.Signal("Name")`.
3. **Never use raw strings for remote/signal names.** Add to the registry in [`ReplicatedStorage/Modules/Net.lua`](ReplicatedStorage/Modules/Net.lua) first. A typo throws a clear error; `ValidationService.CheckNet()` audits at startup.
4. **Require policy** (target state; see "Known debt"):
   - OK to `require`: shared data/config (`KoalaConfig`, `GameConstants`, `*Config`), stateless helpers (`Net`, `Log`, `KoalaVFX`).
   - Feature services should talk through **Signals**, not by requiring each other. `Main.server.lua` is the only place that loads all services.
5. **Server is authoritative.** Clients send intent; the server validates (ownership, cost, cooldown) before acting.
6. **Debug output** goes through `Log.debug(tag, fmt, ...)`; off by default. Turn on with `ReplicatedStorage:SetAttribute("DebugLogs", true)`. Keep `print` for meaningful lifecycle messages only.

### Signals (server-only)
| Signal | Kind | Purpose |
|---|---|---|
| `TransactionRequest` | Function | Spend/charge currency through EconomyService |
| `GrantCurrency` | Event | Award cash |
| `UpdateQuest` | Event | Push quest text to a player (QuestService → client) |
| `AwardTool` | Event | Give a tool (and persist it) |
| `ForcePickup` | Event | Make CarryService pick up a koala/crate |
| `ShowStatus` | Event | Floating status text |
| `CuddleRequest` / `RespawnRequest` / `SleepyEffect` | Event | Koala interaction + VFX plumbing |

### Remotes (client ↔ server)
See the registry table in `Net.lua` (grouped by Economy/shops, Quests, Exhibits, Koalas, Zoo terminal, Teleport/dev). It is the source of truth; don't duplicate it here.

## 5. Server services (init order = `Main.server.lua`)
| Service | Responsibility |
|---|---|
| `EconomyService` | Currency: transactions, grants, status popups |
| `TycoonService` | Player plot setup, tutorial, exhibit repair/reset, vet interaction |
| `QuestService` | Relays `UpdateQuest` signal → `QuestUpdate` remote |
| `RevenueService` | Income per exhibit (happiness/rarity/outfit) + Zoo analytics payload/terminal actions |
| `LeafSpawnerService` / `HungerService` / `FeederVisualService` | Food loop: leaves, hunger drain, feeder visuals |
| `ShopService` / `OutfitShopService` | Tool shop / outfit shop prompts and purchases |
| `ExhibitStatService` / `ExhibitUpgradeService` | Exhibit signs/renaming; exhibit upgrades |
| `CarryService` | Pick up / drop / cuddle koalas, crate welding |
| `KoalaOutfitService` | Unlock/equip/unequip outfits |
| `ZooTerminalService` | Zookeeper computer prompt → analytics UI |
| `StaffService` | Hiring, upkeep billing, guaranteed feeding & staff NPCs (`Downstairs Desk 3`) |
| `DevService` | Dev-only commands (`commands_help.md`); gated by `DEV_IDS` |
| `DataStoreModule` | Save/load player data (cash, koalas, tools, progress) |
| `TeleportToForest` | Send players to the Rescue Forest place |
| `ValidationService` | Startup health checks (assets present, Net registry matches) |

### Koala ownership map (read before touching koala code)
| Module | Owns |
|---|---|
| `KoalaConfig` (shared) | Static data: stages, rarities, stats, names |
| `KoalaLifecycle` (Modules) | Stats/attributes setup (`InitKoala`), growth model swap (`SwapModel`), respawn (`RespawnAt`) |
| `KoalaGrowth` (Modules) | Growth-stage progression over time |
| `KoalaSystem` (Services) | Rig/bone welding (`InitKoala` via `InitKoalaAI` signal), runtime AI, climbing & animation |
| `KoalaCoreManager` | Wires koala signals/remotes (`KoalaAction`, cuddle, respawn, sleepy) |
| `KoalaStatService` | Koala name tags, rename, inspect panel data |
| `KoalaVFX` (Modules) | Auras, hearts, sleepy and crate effects |

## 6. Client controllers
`StarterPlayerScripts`: `ZooAnalyticsController` (terminal UI), `RenameClient` (rename + inspect UI), `InteractionWheelClient`, `OutfitShopController`, `StaffClient`, `MusicController`, `AnnouncementClient`, `DevClient`.
`StarterGui Controllers`: `ShopController`, `QuestClient`, `MoneyClient`, `TeleportClient`, `ManagementLogic`.
- **UI Close Buttons:** Always use plain ASCII `"X"` (never `✕` / `✖`, which render as missing-glyph squares in Roblox `Gotham` fonts).

## 7. Rescue Forest place
Own `Main`, services (`ForestDataService`, `RescueService`, `WildKoalaSpawnerService`, `TeleportBackToTycoon`) and `RescueClient`. Data hand-off to the Tycoon goes through DataStore/teleport data. The place still contains legacy scripts (apple trees, smithy, old `Forest/` and `Shared/` folders) that were not authored here and are not synced by Rojo.

## 8. Known debt (remaining)
1. **Raw-string remotes/signals** still used in ~24 files — migrate to `Net` as each file is touched.
2. **DevService requires** (`DevService` → `TycoonService`, `CarryService`) — acceptable for dev-only commands, or decouple later.
3. **Studio cleanup (optional):** `GiftZooEvent`, `ReplicatedStorage.Modules.KoalaAI`, and `ServerScriptService.Services.TeleportBackToTycoon` are unused in the Tycoon place and can be deleted in Studio Explorer (`$ignoreUnknownInstances` keeps them until removed manually).
4. **`rbxassetid://203785492` load warning** — source not yet located; likely set at runtime or on a spawned model.
5. **Client layout:** `StarterPlayerScripts/` vs `StarterGui Controllers/` have different conventions.
6. **Forest place** keeps its own old copies of `KoalaConfig`/`GameConstants`; verify usage then remove or share.
