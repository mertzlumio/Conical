# Contest: A Multiplayer Pong-Inspired Game

Welcome to **Contest**, a minimal multiplayer Pong-like game built using **Love2D** and **Lua**.  
Two players can join over the network and battle in a fast-paced, physics-driven match.  
The game uses an authoritative server for reliable game state and UDP networking for low-latency gameplay.

---

## 🛠️ Requirements
- **Love2D** (version 11.4 or later recommended)  
  [Download Love2D here](https://love2d.org/)

- LuaSocket (comes bundled with Love2D)

- dkjson: https://github.com/LuaDist/dkjson
---

## 📦 Installation

1. Install **Love2D** for your OS:
   - **Linux:**  
     ```bash
     sudo apt install love
     ```
   - **Windows / macOS:**  
     Download from the [official Love2D website](https://love2d.org/).

2. Clone this repository:
   ```bash
   git clone https://github.com/mertzlumio/Conical.git
   ```
Start the Server:
     ```bash
     cd server
     love .
     ```
Start the Client(s):
     ```bash
     cd client
     love .
     ```
er the ip of the server, good to go!
