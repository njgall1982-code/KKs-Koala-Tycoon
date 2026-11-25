# 🐨 KK's Koala Tycoon: Master Game Plan & Roadmap

This document is the single consolidated source of truth for the game vision, development roadmap, and completed milestones for **KK's Koala Tycoon**.

---

## 📊 Milestone Tracker & Progress Overview

| Phase | System / Milestone | Status | Description |
| :--- | :--- | :--- | :--- |
| **Phase 1** | **The Tutorial ("The Handyman's Debt")** | **COMPLETED** | Broken fence repair, leaf gathering, feeder stocking, releasing KK. |
| **Phase 2** | **The Rescue Forest & Gacha System** | **COMPLETED** | Milk bottle economy, forest teleportation, wild joey gacha roll (90/8/2%), rarity visuals. |
| **Phase 3** | **Lifecycle & Growth Mechanics** | **COMPLETED** | 5-stage growth (Newborn to Adult), Cuddle 1.5x boost, Outfit & accessory system. |
| **Phase 4** | **Economy, Happiness & Revenue Engine** | **COMPLETED** | Revenue calculation: Happiness meter, Rarity tier bonus, Outfit/style multiplier, and Zookeeper Computer Terminal. |
| **Phase 5** | **Zoo Management & Staff NPCs** | **PLANNED (Next Up)** | Cleaners, automated feeders, vet clinic, guest concession stands. |
| **Phase 6** | **Expansions & Conservation Release** | **PLANNED** | Releasing adults for Conservation Credits, Night Forest, Rescue Center. |

---

## 🌟 Detailed Phase Breakdown

### Phase 1: The Tutorial ("The Handyman's Debt") — [COMPLETED]
* **Narrative Intro:** Player begins in a rundown sanctuary corner where KK the koala is trapped in a transport crate.
* **Core Loops Taught:**
  1. **Repair:** Use Wooden Hammer tool to fix broken exhibit fence.
  2. **Gather & Feed:** Pick up eucalyptus leaves and place them into the food trough.
  3. **Release:** Open the crate to welcome KK into his new home.
* **Reward:** Grants the sanctuary deed, initial starting budget, and begins the tycoon mode.

---

### Phase 2: The Rescue Forest & Gacha Mechanics — [COMPLETED]
Instead of buying koalas from a static menu, players rescue wild babies in the wild.
* **The Bottle Economy:**
  * Players buy **Milk Bottles** from the Zoo Supply Station.
  * Scaling cost formula based on current owned koala population.
  * Cooldown timer between purchases to prevent spamming.
* **The Forest Rescue Loop:**
  1. Teleport via vehicle pad to the Rescue Forest map.
  2. Locate wild baby joeys wandering in the forest.
  3. Use Milk Bottle to rescue the joey and trigger the **Gacha Rarity Roll**:
     * **Cute (90%):** Standard natural textures.
     * **Super Cute (8%):** Unique gold tint / sparkle particles.
     * **Legendary (2%):** Neon/glow fur highlights, crown/flower accessories, heart particle trails.
  4. Returns the koala in a Crated Koala tool to place into their zoo exhibit.

---

### Phase 3: Lifecycle & Growth Mechanics — [COMPLETED]
Koalas grow and evolve over time in the player's zoo.

| Stage | Scale | Movement & Behavior |
| :--- | :--- | :--- |
| **1. Newborn** | 0.2x | Stationary; can be picked up and cuddled. |
| **2. 6 Month** | 0.4x | Stationary; plays clinging animation. |
| **3. 1 Year** | 0.7x | Waddler: walks on ground, restricted from climbing trees. |
| **4. 2 Year** | 0.9x | Climber: climbs lower sections of eucalyptus trees. |
| **5. Adult** | 1.0x | Master: full tree climbing, maximum visitor appeal and revenue. |

* **Cuddle Multiplier:** Interacting with a koala activates a **1.5x Growth Speed Boost** for 3 minutes.
* *(Design Simplification)*: Removed the complex "must be within 15 studs of an adult" requirement to keep growth clear and rewarding for players.
* **Outfits & Accessory Integration:**
  * Outfits equip cleanly to the head bone and scale dynamically with koala growth.
  * Supported by the Outfit Shop and Command Bar registration utilities.

---

### Phase 4: Economy, Happiness & Revenue Engine — [COMPLETED]
Connecting animal welfare, rarity, custom outfits, and office analytics directly to tycoon income.

* **1. Multi-Factor Revenue Formula:**
  $$\text{Income} = \text{BaseRate}(\text{Age}) \times \text{RarityMult} \times \text{OutfitMult} \times \text{HappinessMult} \times \text{CrowdBonus}$$
  * **Age Progression:** Newborn (\$10) $\rightarrow$ 1 Year (\$18) $\rightarrow$ 2 Year (\$28) $\rightarrow$ Adult (\$42) base per 5s cycle.
  * **Rarity Multipliers:** Cute (1.0x), Extra Cute (2.0x), Ultra Cute (4.5x).
  * **Outfit Multipliers & Rarity Tiers:** Outfits configured by rarity (Common +10%, Uncommon +20%, Rare +35-45%, Epic +60-70%) plus +20% dual outfit combo synergy.
  * **Happiness Meter (0-100%):** Evaluated from exhibit food level (60%), cuddle recency (25%), and social grouping (15%). Scaled from 0x (starving) to 1.35x (ecstatic).
  * **Crowd Attraction:** Synergistic bonuses for 4+ (+10%) and 7+ (+25%) koalas per exhibit.
* **2. Zookeeper Operations Terminal:**
  * Interactive computer in the Head Vet office with tiered unlock.
  * **Executive Overview:** Total cash flow/min, park-wide average happiness, total animal population.
  * **Exhibit Telemetry Drill-Down:** Per-exhibit unlock ($250) revealing individual koala stats, outfits, happiness, and live cash contribution.
  * Persistent DataStore integration for player terminal and telemetry unlocks.

---

### Phase 5: Zoo Management & Staff NPCs — [PLANNED]
Automating chores as the zoo scales up in size.
* **Cleaners (NPCs):** Pathfind to trash and muck in exhibits to maintain 100% cleanliness.
* **Feeders (NPCs):** Automatically transfer eucalyptus leaves from central storage to exhibit bins.
* **Vets & Clinic:** Sick or fatigued koalas are admitted to the clinic for recovery.
* **Visitor Concessions:** Eucalyptus Cafe, Koala Cola stands, Bathrooms, and Plushie Gift Shops.

---

### Phase 6: Expansions & Conservation Release — [PLANNED]
* **The Release Mechanic:**
  * Players can release fully-grown Adult koalas back into the wild.
  * Releasing grants **"Conservation Credits"** and frees up exhibit capacity for new rescue runs.
  * Creates a continuous hunting loop for rare and legendary variants.
* **Special Zones:**
  * **The Night Forest:** Nocturnal zone featuring glowing eucalyptus and nocturnal wild koalas with higher rare spawn rates.
  * **The Sanctuary Rescue Center:** Global trading and conservation hub.

---

## 📚 Related Documentation & Specs
* [Monetization Strategy & Ideas](file:///c:/Users/njgal_ottfjhb/OneDrive/Desktop/AI%20Coding/Roblox/KKs%20Koala%20Tycoon/monetization_ideas.md): Catalog of GamePasses, Dev Products, terminal unlocks, and Robux monetization plans.
* [Project Manifest](file:///c:/Users/njgal_ottfjhb/OneDrive/Desktop/AI%20Coding/Roblox/KKs%20Koala%20Tycoon/project_manifest.md): Architecture breakdown and service dependencies.
