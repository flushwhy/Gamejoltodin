# Odin GameJolt Wrapper

An Odin wrapper for the GameJolt API v1.2, exposing a flat C ABI/header interface. This library is designed to be easily integrated into game engines and frameworks supporting C bindings (e.g., Godot, Raylib, Love2D, etc.).

## Project Structure

- `gamejolt/` - Odin source code for the GameJolt client.
  - `gamejolt.odin` - Main API logic (Odin-facing API, HTTP request handling, session state).
  - `c_api.odin` - C ABI wrapper exports and structure translations.
  - `types.odin` - Data types and C-compatible structures.
  - `utils.odin` - High-level gameplay utilities (user avatars, pictures, trophy checks, score formatting, data increments).
  - `internal.odin` - Request signing, libcurl integration, and parsing utilities.
- `gamejolt.h` - Flat C ABI header file for engine integration.
- `build.bat` - Compilation script for Windows (produces `bin/gamejolt.dll`).
- `build.sh` - Compilation script for Linux & macOS (produces `bin/libgamejolt.so` / `bin/libgamejolt.dylib`).

## Design & C ABI Guidelines

To ensure perfect ABI compatibility and safety:
1. **Opaque/Flat Sessions:** `GJ_Session` is defined as a flat struct with fixed character buffers (`[64]u8` arrays) instead of Odin strings. No dynamic allocations occur during initialization or session destruction.
2. **Boolean Alignment:** All boolean fields and flags use `b8` (8-bit boolean) to match the 1-byte size of C's standard `bool` in `<stdbool.h>`.
3. **No Dynamic Pointers:** Strings returned to C are copied into fixed-size byte buffers provided in the structures or caller-supplied output buffers.
4. **Caller-Provided Buffers:** All array and string queries (`gj_trophies_fetch_c`, `gj_scores_fetch_c`, `gj_data_get_user_picture_c`, etc.) accept an output buffer and capacity, returning total count.

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

## API Overview

### Core API
- **Session Lifecycle:** `gj_init_c`, `gj_destroy_c`
- **Authentication:** `gj_login_c`
- **Session Heartbeats:** `gj_session_open_c`, `gj_session_ping_c`, `gj_session_close_c`
- **Trophies:** `gj_trophies_fetch_c`, `gj_trophy_unlock_c`
- **Scores:** `gj_scores_submit_c`, `gj_scores_submit_guest_c`, `gj_scores_fetch_c`, `gj_scores_tables_c`, `gj_scores_rank_c`
- **Data Store:** `gj_data_set_c`, `gj_data_get_c`, `gj_data_remove_c`, `gj_data_keys_c`

### Utilities Layer
- **User Picture & Avatars:**
  - `gj_data_get_user_picture_c` / `gj_data_get_user_picture`: Checks user data store (`"user_picture"`), falls back to GameJolt avatar URL.
  - `gj_data_set_user_picture_c` / `gj_data_set_user_picture`: Saves picture data/URL in user data store.
  - `gj_get_user_avatar_url_c` / `gj_get_user_avatar_url`: Fetches user profile avatar directly from GameJolt.
  - `gj_get_current_user_c` / `gj_get_current_user`: Re-fetches the active user profile.
- **Convenience Helpers:**
  - `gj_is_logged_in_c` / `gj_is_logged_in`: Check if session is authenticated.
  - `gj_session_username_c` / `gj_session_username`: Access cached session username.
  - `gj_has_trophy_c` / `gj_has_trophy`: Quickly test if a trophy is earned.
  - `gj_data_get_int_c` / `gj_data_set_int_c`: Read/write typed integers to data store.
  - `gj_data_increment_c` / `gj_data_increment`: Increment numerical stats directly.
  - `gj_score_format_c` / `gj_score_format`: Formats integer scores with thousand separators (e.g. `1,250,000`).

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
        printf("Logged in user: %s (ID: %d)\n", user.username, user.id);
        
        // Open session
        gj_session_open_c(&session);
        gj_session_ping_c(&session, true);
        
        // Get user picture (data-store or avatar URL fallback)
        char pic_url[256] = {0};
        gj_data_get_user_picture_c(&session, pic_url, sizeof(pic_url));
        printf("User Picture: %s\n", pic_url);

        // Check a trophy
        bool unlocked = false;
        gj_has_trophy_c(&session, 12345, &unlocked);
        printf("Trophy 12345 unlocked: %s\n", unlocked ? "yes" : "no");

        // Format a score
        char formatted_score[64] = {0};
        gj_score_format_c(5000000, formatted_score, sizeof(formatted_score));
        printf("Formatted score: %s\n", formatted_score);
        
        // Close session
        gj_session_close_c(&session);
    } else {
        printf("Login failed with error code: %d\n", err);
    }
    
    // 3. Destroy session
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
        fmt.printf("Logged in user: %s (ID: %d)\n", user.username, user.id)
        
        // Utility: Fetch picture or avatar fallback
        pic, _ := gamejolt.gj_data_get_user_picture(&session)
        defer delete(pic)
        fmt.printf("User picture: %s\n", pic)

        // Utility: Check if a trophy has been earned
        has_it, _ := gamejolt.gj_has_trophy(&session, 12345)
        fmt.printf("Trophy 12345 unlocked: %v\n", has_it)

        // Utility: Increment a death counter in data-store
        deaths, _ := gamejolt.gj_data_increment(&session, "deaths", 1, user = true)
        fmt.printf("Current deaths: %d\n", deaths)
    } else {
        fmt.printfln("Login failed: %v", err)
    }
}
```

