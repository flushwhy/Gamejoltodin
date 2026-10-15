# Game Jolt API for Odin and C

An **Odin-first** client for the Game Jolt API v1.2, with a small C ABI for C projects and engines. The Game Jolt implementation lives in Odin; the C interface translates inputs and outputs and delegates to that same implementation.

The project has two supported audiences:

- **Odin developers** get a native API using Odin strings, types, allocators, slices, and error returns.
- **C developers** get a stable, documented C header with explicit-width types, predictable struct layouts, caller-owned output buffers, and error codes.

The C ABI is an adapter—not a second implementation and not a wrapper around a separate C Game Jolt library. C-compatible layouts and fixed buffers belong at the ABI boundary, not in the native Odin API.

## Architecture

```text
Odin application ──> Native Odin API ──> Game Jolt HTTP / signing / JSON
C application    ──> C ABI adapter   ──> same Odin implementation
```

The design goal is to make the C boundary small and auditable. The adapter should validate pointers, capacities, and scalar inputs; convert C strings and structs; call the native implementation; and translate results back to C-compatible values. It should never duplicate endpoint behavior.

A static ABI helps keep the interface predictable, but it does not by itself prevent memory bugs. The implementation must still define ownership and lifetimes clearly, and the adapter must avoid exposing Odin-managed memory to C callers without an explicit contract.

## Project goals

1. Keep the native Odin API idiomatic and independent of C layout constraints.
2. Keep HTTP requests, authentication, signing, parsing, and endpoint logic in Odin.
3. Keep fixed-size buffers and C-compatible structs in the C adapter.
4. Test the Odin API and C ABI independently, including invalid inputs and output-capacity handling.
5. Provide a complete Odin example game using leaderboards, scores, trophies, and player data. [DapperO](https://github.com/flushwhy/DapperO) is the intended example project.

## Project Structure

- `gamejolt/` - Odin source code for the GameJolt client.
  - `gamejolt.odin` - Main API logic (Odin-facing API, HTTP request handling, session state).
  - `c_api.odin` - C ABI wrapper exports and structure translations.
  - `types.odin` - Data types and C-compatible structures.
  - `utils.odin` - High-level gameplay utilities (user avatars, pictures, trophy checks, score formatting, data increments).
  - `utils.odin` - High-level gameplay utilities (user avatars, pictures, trophy checks, score formatting, data increments).
  - `internal.odin` - Request signing, libcurl integration, and parsing utilities.
- `gamejolt.h` - Flat C ABI header file for engine integration.
- `build.bat` - Compilation script for Windows (produces `bin/gamejolt.dll`).
- `build.sh` - Compilation script for Linux & macOS (produces `bin/libgamejolt.so` / `bin/libgamejolt.dylib`).

## C ABI Guidelines

These rules apply to the C adapter and public C header—not to the native Odin API:

1. **C-compatible representations:** Export only C-compatible scalar types, structs, and pointers. Keep Odin strings, slices, maps, and dynamic arrays internal.
2. **Explicit ownership:** Any output buffer supplied by C remains caller-owned. Do not return pointers to temporary or Odin-managed memory unless an explicit allocation/free contract is part of the API.
3. **Validate the boundary:** Check required pointers, non-negative capacities, and valid enum/range values before dereferencing or converting them. Never assume a non-null pointer is valid memory.
4. **No silent truncation:** String-to-buffer conversion must report truncation or return an appropriate error; do not silently turn a successful API call into incomplete data.
5. **Stable ABI:** Use explicit-width integer types in the C header and test struct sizes/layouts on supported targets. Treat changes to exported signatures and struct layouts as compatibility changes.
6. **One implementation:** Exported C functions delegate to native Odin procedures; endpoint logic must not be reimplemented in the adapter.


---

## Build Instructions

### Prerequisites
- [Odin Compiler](https://odin-lang.org/)
- `libcurl` development headers and runtime:
  - **Windows**: `libcurl.lib` / `libcurl.dll` (included with Odin or installed on system PATH).
  - **Linux (Ubuntu/Debian)**: `sudo apt install libcurl4-openssl-dev build-essential`
  - **macOS**: `brew install curl` (or default system libcurl)

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

## Testing

Run all tests (Odin unit tests + C ABI integration tests) using the automated test runner:

**Windows:**
```cmd
run_tests.bat
```

**Linux / macOS:**
```bash
chmod +x run_tests.sh
./run_tests.sh
```

Or run tests individually:

### 1. Odin Unit Tests
Runs the built-in memory-tracked unit test suite (URL builders, crypto signatures, JSON parsing, memory cleanup, and utilities):
```cmd
odin test gamejolt -extra-linker-flags:"C:\odin\vendor\curl\lib\libcurl.lib"
```

### 2. C ABI Integration Tests
Compiles and executes the C integration test suite (`tests/test_c_api.c`) to verify struct alignment, header compatibility, and DLL exports:
```cmd
gcc -I. tests/test_c_api.c bin/gamejolt.lib -o bin/test_c_api.exe
.\bin\test_c_api.exe
```

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


