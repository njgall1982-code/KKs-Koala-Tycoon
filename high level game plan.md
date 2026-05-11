# KK's Koala Tycoon: Master Game Design Document

This document combines the zoo management systems, the rescue forest adventure, and the detailed growth mechanics into a single comprehensive plan for development in the Antigravity IDE.

## Phase 1: The Tutorial ("The Handyman's Debt") DONE
The game begins with a narrative hook to teach basic mechanics before the tycoon loop starts.
* **The Setting:** A dusty, overgrown corner of an old sanctuary.
* **The Mission:** A lonely Koala named **KK** is stuck in a rusted transport crate.
* **Tasks:**
    1. **Repair:** Use a hammer tool to fix 3 collapsed fence segments.
    2. **Gather:** Pick up eucalyptus leaves and place them in the feeder.
    3. **Release:** Open the crate to let KK into his new home.
* **Reward:** The player receives the deed to the zoo and a small starting budget.

## Phase 2: The Core Gameplay Loop
The transition from worker to owner introduces the primary economic engine.

* **The Tycoon Tree:** Cash unlocks: New Exhibits → Eucalyptus Farms → Clinic → Guest Services.
* **Koala Care:** Happiness Meter (Hunger/Cleanliness). Low happiness = 50% income reduction.

## Phase 3: The Rescue Forest & Gacha Mechanics
Instead of a shop menu, new koalas are found through active exploration.
* **The Bottle Economy:** Purchase "Milk Bottles" (scaling cost based on zoo size). 
* **The Mission:** Teleport to the Forest Map to find wild babies.
* **Rarity Roll (The Feed):**
    * **Cute (90%):** Standard natural textures.
    * **Super Cute (8%):** Unique colors/glow + Sparkle Particles.
    * **Legendary (2%):** Neon/Glowing fur + Heart Trails + Unique accessories.

## Phase 4: Lifecycle & Growth Mechanics
Koalas grow through 5 distinct stages. Growth only occurs when "Needs Satisfaction" is >80%.
1. **Newborn (0.2x):** Must be carried by player or attached to an Adult.
2. **6 Month (0.4x):** Rides on the back of an Adult Koala.
3. **1 Year (0.7x):** Waddles on the ground.
4. **2 Year (0.9x):** Climbs lower tree trunks.
5. **Adult (1.0x):** Full climbing range and maximum income.

## Phase 5: Zoo Management & Staff (NPCs)
As the zoo scales, the player hires NPCs to automate maintenance.
* **Cleaners:** Path-find to trash and "muck" in exhibits.
* **Feeders:** Automatically refill eucalyptus bins from the farms.
* **Vets & Clinic:** Sick koalas are brought to the Clinic for a timed recovery period.
* **Facilities:** Eucalyptus Cafe, Koala Cola stands, Bathrooms, and Gift Shops (Plushies).

## Phase 6: Expansion & Release
* **The Release Mechanic:** Fully grown Adults can be released back to the wild for "Conservation Credits."
* **Special Zones:** The Night Forest (Nocturnal activity, higher prices) and The Rescue Center.





More details on Rescue Forest as a separate area you transport to, and Growth Mechanics.  We can merge the above and below, call out and conflicts

# KK's Koala Tycoon: The Rescue Forest & Growth Mechanics

This document outlines the expansion mechanics for the "Rescue Forest" and the lifecycle of koalas from Newborn to Adult.

## 1. The Rescue Forest (Gacha Adventure)
Instead of buying koalas from a menu, players must embark on rescue missions to find new additions for their zoo.

### The Bottle Economy
* **The Item:** Players must purchase "Milk Bottles" from the Zoo Supply Station.
* **Scaling Cost:** * Costs scale based on current koala population (e.g., $50 for the first few, scaling up to $5,000+ as the zoo grows).
* **Time Delay:** Bottles have a "delivery time" or cooldown to prevent spamming.
* **Premium Bottles (Robux):** Guarantee a higher chance of Super Cute or Legendary rarities.

### The Mission Loop
1. **Travel:** Step on a teleport pad to go to the Forest Map.
2. **Search:** Locate a "Generic Baby" wild koala in the trees.
3. **Feeding (The Roll):** Use the Milk Bottle on the baby. This triggers the rarity reveal:
    * **Cute (90%):** Standard natural textures.
    * **Super Cute (8%):** Unique colors/glow effects.
    * **Legendary (2%):** Particle trails, crowns/flowers, and rare materials.
4. **Transport:** The koala is brought back to the zoo in a transport crate.

---

## 2. The Koala Lifecycle (Growth Tiers)
Koalas grow based on a combination of **Time in Game** and **Needs Satisfaction**. 

| Stage | Age/Time | Behavior & Mechanics | Size |
| :--- | :--- | :--- | :--- |
| **Newborn** | 0-10 Min | **Attached:** Must be carried by the player or an Adult. | 0.2x |
| **6 Month** | 10-20 Min | **Clingy:** Sits on the back of an Adult Koala. | 0.4x |
| **1 Year** | 20-40 Min | **Waddler:** Moves on the ground. Cannot climb yet. | 0.7x |
| **2 Year** | 40-60 Min | **Climber:** Can climb the lower parts of trees. | 0.9x |
| **Adult** | 60+ Min | **Master:** Full climbing range. Generates max income. | 1.0x |

### Growth Requirements
* **Satisfaction Meter:** The growth timer only ticks if Hunger/Social/Cleanliness needs are met.
* **Robux Speed-up:** Players can spend Robux to skip a growth stage instantly.

---

## 3. The Release Mechanic
* **Free Up Space:** Players release Adult koalas to make room for new "Rescue" attempts.
* **Rewards:** Releasing a fully grown Adult grants a large chunk of Cash or "Conservation Credits."
* **Loop:** This encourages players to keep hunting for "Legendary" rarities to replace "Cute" ones.

---

## 4. Technical Setup for Antigravity IDE
* **Modular Scaling:** Use a script to iterate `Model:Scale()` based on the age stage.
* **Weld Logic:** Use `WeldConstraints` to attach Newborns to the "Back" attachment of Adults.
* **Weighted Randomness:** Use a table of percentages (90, 8, 2) to determine rarity on bottle use.