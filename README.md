# Odin GameJolt Wrapper

An Odin wrapper for the GameJolt API v1.2, exposing a flat C ABI/header interface. This library is designed to be easily integrated into game engines and frameworks supporting C bindings (e.g., Godot, Raylib, Love2D, etc.).

## Project Structure

- `gamejolt/` - Odin source code for the GameJolt client.
  - `gamejolt.odin` - Main API logic (Odin-facing API, HTTP request handling, session state).
  - `c_api.odin` - C ABI wrapper exports and structure translations.
  - `types.odin` - Data types and C-compatible structures.
  - `internal.odin` - Request signing, libcurl integration, and parsing utilities.
- `gamejolt.h` - Flat C ABI header file for engine integration.
- `build.bat` - Compilation script for Windows (produces `bin/gamejolt.dll`).
- `build.sh` - Compilation script for Linux & macOS (produces `bin/libgamejolt.so` / `bin/libgamejolt.dylib`).

## Design & C ABI Guidelines

To ensure perfect ABI compatibility and safety:
1. **Opaque/Flat Sessions:** `GJ_Session` is defined as a flat struct with fixed character buffers (`[64]u8` arrays) instead of Odin strings. No dynamic allocations occur during initialization or session destruction.
2. **Boolean Alignment:** All boolean fields and flags use `b8` (8-bit boolean) to match the 1-byte size of C's standard `bool` in `<stdbool.h>`.
3. **No Dynamic Pointers:** Strings returned to C are copied into fixed-size byte buffers provided in the structures.
All core logic is written in Odin, leveraging its safety and performance; only the thin C‑ABI layer converts data to plain C types for external consumption.
---

## Build Instructions

### Prerequisites
- [Odin Compiler](https://odin-lang.org/)
- `libcurl` development library (installed on your system PATH or environment)
- **Runtime dependency**: Ensure `libcurl.dll` is available on the system PATH or placed alongside `gamejolt.dll`.

### Windows
Run `build.bat` in a command prompt or PowerShell:
```cmd
build.bat
```
This produces `bin/gamejolt.dll` and `bin/gamejolt.lib`.

### macOS / Linux
Run `build.sh` in your terminal:
```bash
chmod +x build.sh
./build.sh
```
This produces `bin/libgamejolt.dylib` (macOS) or `bin/libgamejolt.so` (Linux).

---

## Usage Examples

### C Example
Include `gamejolt.h` and link against `gamejolt.lib` / `gamejolt.dll`:

```c
#include <stdio.h>
#include "gamejolt.h"

int main() {
    // 1. Initialize session
    GJ_Session session = gj_init_c("YOUR_GAME_ID", "YOUR_PRIVATE_KEY");
    
    // 2. Login the user
    GJ_User_C user = {0};
    int32_t err = gj_login_c(&session, "username", "token", &user);
    if (err == 0) {
        printf("Logged in user ID: %d, Username: %s\n", user.id, user.username);
        
        // Open session
        gj_session_open_c(&session);
        
        // Ping session
        gj_session_ping_c(&session, true);
        
        // Close session when done
        gj_session_close_c(&session);
    } else {
        printf("Login failed with error code: %d\n", err);
    }
    
    // 3. Destroy session (cleans up state)
    gj_destroy_c(&session);
    return 0;
}
```

### Odin Example (Direct)
You can also use the Odin package directly from other Odin code:

```odin
package main

import "core:fmt"
import "gamejolt"

main :: proc() {
    session := gamejolt.gj_init("YOUR_GAME_ID", "YOUR_PRIVATE_KEY")
    defer gamejolt.gj_destroy(&session)
    
    user, err := gamejolt.gj_login(&session, "username", "token")
    if err == .None {
        fmt.printf("Logged in user ID: %d\n", user.id)
    } else {
        fmt.printfln("Login failed: %v", err)
    }
}
```
