# 🐨 KK's Koala Tycoon

A high-fidelity Roblox tycoon experience centered around animal rescue, habitat management, and interactive NPC AI. Built with a focus on robust system architecture and "Source of Truth" development workflows.

## 🚀 Key Features

*   **Custom Koala AI & Behavior**: Implemented a state-machine based AI for Koalas, including "Lazy Waddle" movement, climbing logic, and hunger-driven states.
*   **Physics-Locked Climbing System**: Developed a stable climbing mechanic that uses CFrame interpolation combined with temporary physics-locking (anchoring) to prevent "explosive" physics collisions with tree models.
*   **Dynamic Tycoon Economy**: A fully integrated economy where habitat cleanliness and Koala "Happiness" levels directly impact revenue generation.
*   **Constructor Pattern Architecture**: Scripts are built using a "self-healing" constructor pattern—objects like ProximityPrompts and BillboardGuis are dynamically instantiated if missing, ensuring stability across game updates.
*   **Modular Service Layer**: Backend logic is split into dedicated services (HungerService, TycoonService, DataStoreModule) for high maintainability.

## 🛠️ Technical Highlights

### The "Physics Lock" Protocol
One of the primary challenges was moving unanchored NPC models into complex foliage models. I implemented a protocol that:
1.  Anchors the `HumanoidRootPart` during CFrame-based movement.
2.  Performs a safe "Landing" check using Raycasting.
3.  Unanchors and forces a `GettingUp` state to ensure the NPC remains upright after interaction.

### "Source of Truth" Workflow
This project utilizes a professional development workflow where the local filesystem acts as the Source of Truth. Changes are version-controlled via Git and synchronized to the Roblox Studio environment using custom tooling, ensuring a clean history of all logic changes.

## 📋 Systems Overview

*   **Hunger & Revenue**: Koalas drain exhibit food levels by 5% every 60 seconds. Starving koalas stop generating rent, creating a meaningful gameplay loop.
*   **Exhibit Stat Signs**: A glassmorphism-style UI system that displays real-time stats and allows players to rename their habitats.
*   **Rescue Loop**: A dedicated "Rescue Forest" zone with teleportation logic using `TeleportAsync` for seamless world transitions.

## 🛠️ Tech Stack
*   **Language**: Luau (Roblox's derivative of Lua 5.1)
*   **Environment**: Roblox Studio
*   **Version Control**: Git / GitHub Desktop
*   **Methodology**: Service-Oriented Architecture (SOA)

---
*Note: This project is currently in active development. It serves as a demonstration of Luau systems programming, NPC AI implementation, and game state management.*
