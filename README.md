# Contest Engine: A Multiplayer Pong-Inspired Game

Welcome to **Contest Engine**, a minimal multiplayer Pong-like game built using **Love2D** and **Lua**.  
Two players can join over the network and battle in a fast-paced, physics-driven match.  
The game uses an authoritative server for reliable game state and UDP networking for low-latency gameplay.

---

## 🚀 Features
- Local multiplayer over network using **UDP sockets**
- Simple ball and paddle physics using Love2D's built-in physics engine
- Visual effects like starfields
- Auto game restart after each match
- JSON-based client-server communication using `dkjson`

---

## 🛠️ Requirements
- **Love2D** (version 11.4 or later recommended)  
  [Download Love2D here](https://love2d.org/)

- LuaSocket (comes bundled with Love2D)

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
   git clone https://github.com/your-username/your-repo.git
   
Start the Server:

cd server
love .


Start the Client(s):

cd client
love .

Enter the ip of the server, good to go!
