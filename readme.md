# KCF (Koregh Core Framework)

A high-performance, modular, and secure framework for Roblox development.

KCF is designed for professional developers who require a scalable architecture. It focuses on Dependency Injection, Memory Safety, State Immutability, and Anti-Exploit Middleware.


---

🚀 Core Philosophy

Modular Architecture: Logic is decoupled into Services orchestrated by a central Kernel.

Security-First: Native schema validation and rate limiting on all network traffic.

Reactive State: Data management with automated client replication and deep-copy protection.

Memory Efficiency: Strict lifecycle management using the Janitor pattern to prevent memory leaks.



---

📂 Project Structure

Framework/
├── Services/           # Place game logic here (e.g., EconomyService, QuestService)
├── ServiceManager      # Orchestrates loading and lifecycle
├── NetworkManager      # Secure communication layer
├── ConfigManager       # Immutable state and replication
├── GuardClause         # Data validation engine
├── Signal              # High-performance internal events
├── Janitor             # Memory cleanup utility
└── ConsoleReporter     # Centralized logging and telemetry


---

🛠️ API Reference

1. Framework Core (Framework.lua)

The central hub that initializes all utilities and injects dependencies into services.

Method	Description

Framework.Init()	Initializes core modules and starts the ServiceManager.
Framework:GetJanitor(player)	Returns a unique Janitor instance assigned to a specific player.



---

2. Service Manager

Handles the lifecycle of all game services.

Stage	Method	Action

I. Load	Load(folder)	Requires all ModuleScripts inside the given folder.
II. Init	InitAll(fm)	Injects the Framework reference into each Service.Init().
III. Start	StartAll()	Spawns Service.Start() logic in isolated threads.



---

3. Config Manager

Manages player data with immutability guarantees. Every Get returns a deep copy, preventing accidental state corruption.

SetPlayer(player, key, value)
Updates internal state and triggers replication if the key is marked for sync.

GetPlayer(player, key)
Returns a protected deep copy of the data.

ImportPlayerData(player, data)
Initializes the player session with external data (e.g., DataStore payload).



---

4. Network Manager

Provides a shielded interface for RemoteEvents.

Connect(name, blueprint, callback, cooldown)

Blueprint: Optional table schema for data validation.

Cooldown: Built-in per-user rate limiting.


FireClient(name, player, ...)
Securely sends data to a specific client.



---

5. Signal (Internal Events)

A pure Luau Observer-pattern implementation, significantly faster than BindableEvents.

Connect(handler) – Subscribes to the event and returns a connection object.

Fire(...) – Dispatches data to all listeners asynchronously.

Wait() – Yields the current thread until the signal fires.



---

🛡️ Example Service Implementation

Create a new ModuleScript inside the Services folder:

local MyService = {}
local _FM -- Framework reference

function MyService.Init(framework)
    _FM = framework
    _FM.Log:SendMessage("MyService", "Initialized!", "Print")
end

function MyService.Start()
    -- Your logic here
    _FM.Network:Connect("PlayerAction", { ID = "string" }, function(player, data)
        print(player.Name .. " performed " .. data.ID)
    end)
end

return MyService


---

📜 License

This framework is licensed under the MIT License.

