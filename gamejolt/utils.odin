#+feature dynamic-literals
package gamejolt

import "core:encoding/json"
import "core:fmt"
import "core:strconv"
import "core:strings"
import "core:thread"

// -----------------------------------------------------------------------
//  Utils — convenience layer on top of the core GameJolt API.
//
//  These helpers do NOT change any C-ABI signatures. They are purely
//  Odin-to-Odin helpers that compose the lower-level procs for common
//  gameplay patterns.
// -----------------------------------------------------------------------


// -----------------------------------------------------------------------
//  Session helpers
// -----------------------------------------------------------------------

// Returns true if the session has been initialised AND the user has
// successfully logged in. Safe to call at any point.
gj_is_logged_in :: proc(session: ^GJ_Session) -> bool {
    return session != nil && bool(session.is_authed)
}

// Returns the cached username string from the session (no network call).
// Returns "" if not yet authenticated.
gj_session_username :: proc(session: ^GJ_Session) -> string {
    if !gj_is_logged_in(session) do return ""
    return _buf_to_str(session.username[:])
}

// -----------------------------------------------------------------------
//  User & Profile helpers
// -----------------------------------------------------------------------

// Fetches the current user profile from GameJolt.
// Useful to refresh user data (status, avatar, etc.) without re-authenticating.
gj_get_current_user :: proc(
    session:   ^GJ_Session,
    allocator := context.allocator,
) -> (user: GJ_User, err: GJ_Error) {
    if !gj_is_logged_in(session) do return {}, .Not_Authenticated

    params := map[string]string{
        "username" = _buf_to_str(session.username[:]),
    }
    defer delete(params)

    response, req_err := _gj_request(session, "/users", params, context.temp_allocator)
    if req_err != .None do return {}, req_err

    users_val, ok := response["users"]
    if !ok do return {}, .Invalid_Response

    users_arr, ok2 := users_val.(json.Array)
    if !ok2 || len(users_arr) == 0 do return {}, .Invalid_Response

    user_obj, ok3 := users_arr[0].(json.Object)
    if !ok3 do return {}, .Invalid_Response

    return _parse_user(user_obj, allocator), .None
}

// Fetches the avatar URL for the currently logged-in user.
// Allocates with the provided allocator; caller must call delete() when done.
gj_get_user_avatar_url :: proc(
    session:   ^GJ_Session,
    allocator := context.allocator,
) -> (url: string, err: GJ_Error) {
    user, uerr := gj_get_current_user(session, context.temp_allocator)
    if uerr != .None do return "", uerr
    return strings.clone(user.avatar_url, allocator), .None
}

// Retrieves the user picture.
// First inspects the user-scoped data store under "user_picture".
// If not found or empty, falls back to the user's GameJolt avatar URL.
gj_data_get_user_picture :: proc(
    session:   ^GJ_Session,
    allocator := context.allocator,
) -> (picture_or_url: string, err: GJ_Error) {
    if !gj_is_logged_in(session) do return "", .Not_Authenticated

    // 1. Check user data-store
    custom, custom_err := gj_data_get(session, "user_picture", true, allocator)
    if custom_err == .None && len(custom) > 0 {
        return custom, .None
    }
    if len(custom) > 0 do delete(custom, allocator)

    // 2. Fallback to profile avatar
    return gj_get_user_avatar_url(session, allocator)
}

// Sets a custom user picture (or picture URL/data) in the user-scoped data store.
gj_data_set_user_picture :: proc(
    session:      ^GJ_Session,
    picture_data: string,
) -> GJ_Error {
    if !gj_is_logged_in(session) do return .Not_Authenticated
    return gj_data_set(session, "user_picture", picture_data, true)
}

// -----------------------------------------------------------------------
//  Data-store helpers
// -----------------------------------------------------------------------

// Reads a data-store key. If the key is missing or empty, default_val is returned.
// Allocates with allocator; caller must delete the result.
gj_data_get_or_default :: proc(
    session:     ^GJ_Session,
    key:         string,
    default_val: string,
    user:        bool      = false,
    allocator  := context.allocator,
) -> string {
    val, err := gj_data_get(session, key, user, allocator)
    if err != .None || val == "" {
        if val != "" do delete(val, allocator)
        return strings.clone(default_val, allocator)
    }
    return val
}

// Reads an integer from the data store. Returns default_val if missing or unparseable.
gj_data_get_int :: proc(
    session:     ^GJ_Session,
    key:         string,
    default_val: int  = 0,
    user:        bool = false,
) -> (val: int, err: GJ_Error) {
    raw, get_err := gj_data_get(session, key, user, context.temp_allocator)
    if get_err != .None do return default_val, get_err
    if raw == "" do return default_val, .None

    parsed, ok := strconv.parse_int(raw)
    if !ok do return default_val, .Invalid_Response
    return parsed, .None
}

// Writes an integer value to the data store.
gj_data_set_int :: proc(
    session: ^GJ_Session,
    key:     string,
    value:   int,
    user:    bool = false,
) -> GJ_Error {
    s := _int_to_str(value, context.temp_allocator)
    return gj_data_set(session, key, s, user)
}

// Atomically increment an integer stored in the data store.
// Reads the current value, adds delta, and writes it back.
// Returns the new value on success.
gj_data_increment :: proc(
    session: ^GJ_Session,
    key:     string,
    delta:   int  = 1,
    user:    bool = false,
) -> (new_val: int, err: GJ_Error) {
    current, _ := gj_data_get_int(session, key, 0, user)
    next := current + delta
    set_err := gj_data_set_int(session, key, next, user)
    if set_err != .None do return 0, set_err
    return next, .None
}

// -----------------------------------------------------------------------
//  Trophy helpers
// -----------------------------------------------------------------------

// Returns a human-readable label for a trophy difficulty.
gj_trophy_difficulty_label :: proc(d: GJ_Trophy_Difficulty) -> string {
    switch d {
    case .Bronze:   return "Bronze"
    case .Silver:   return "Silver"
    case .Gold:     return "Gold"
    case .Platinum: return "Platinum"
    }
    return "Unknown"
}

// Checks if the user has already unlocked a specific trophy.
gj_has_trophy :: proc(
    session:   ^GJ_Session,
    trophy_id: int,
) -> (achieved: bool, err: GJ_Error) {
    trophies, fetch_err := gj_trophies_fetch(session, false, context.temp_allocator)
    if fetch_err != .None do return false, fetch_err
    for t in trophies {
        if t.id == trophy_id {
            return t.achieved, .None
        }
    }
    return false, .None
}

// Returns only the unachieved trophies from a slice.
// Allocates the filtered slice with context.temp_allocator.
gj_trophies_unachieved :: proc(trophies: []GJ_Trophy) -> []GJ_Trophy {
    count := 0
    for t in trophies {
        if !t.achieved do count += 1
    }
    result := make([]GJ_Trophy, count, context.temp_allocator)
    i := 0
    for t in trophies {
        if !t.achieved {
            result[i] = t
            i += 1
        }
    }
    return result
}

// Fetch trophies async and call callback on the results in a background thread.
gj_trophies_fetch_async :: proc(
    session:       ^GJ_Session,
    achieved_only: bool,
    callback:      proc([]GJ_Trophy, GJ_Error),
) {
    Args :: struct {
        session:       ^GJ_Session,
        achieved_only: bool,
        cb:            proc([]GJ_Trophy, GJ_Error),
    }
    args := new(Args)
    args^ = {session, achieved_only, callback}

    thread.run_with_poly_data(args, proc(a: ^Args) {
        trophies, err := gj_trophies_fetch(a.session, a.achieved_only)
        a.cb(trophies, err)
        free(a)
    }, context)
}

// -----------------------------------------------------------------------
//  Score helpers
// -----------------------------------------------------------------------

// Formats a raw integer sort value into a display string.
// e.g. 123456 → "123,456" (thousands-separated).
gj_score_format :: proc(sort: int, allocator := context.allocator) -> string {
    sb := strings.builder_make(allocator)
    s   := _int_to_str(sort, context.temp_allocator)

    digits := len(s)
    for ch, i in s {
        strings.write_rune(&sb, ch)
        remaining := digits - i - 1
        if remaining > 0 && remaining % 3 == 0 {
            strings.write_rune(&sb, ',')
        }
    }
    return strings.to_string(sb)
}

// Returns the best (lowest sort value) score for the current user from
// a slice already returned by gj_scores_fetch.
gj_scores_personal_best :: proc(
    session: ^GJ_Session,
    scores:  []GJ_Score,
) -> (best: ^GJ_Score) {
    uname := gj_session_username(session)
    for &s in scores {
        if s.user == uname {
            if best == nil || s.sort < best.sort {
                best = &s
            }
        }
    }
    return best
}

// Helper to easily fetch the top N scores on a leaderboard table.
gj_scores_get_top :: proc(
    session:   ^GJ_Session,
    count:     int = 10,
    table_id:  int = 0,
    allocator := context.allocator,
) -> (scores: []GJ_Score, err: GJ_Error) {
    return gj_scores_fetch(session, table_id, count, false, allocator)
}

// -----------------------------------------------------------------------
//  Formatting / debug helpers
// -----------------------------------------------------------------------

// Returns a single-line human-readable summary of a session for logging.
gj_session_debug_string :: proc(session: ^GJ_Session) -> string {
    if session == nil do return "<nil session>"
    game_id := _buf_to_str(session.game_id[:])
    if !bool(session.is_authed) {
        return fmt.tprintf("[GJ_Session game=%s NOT_AUTHED]", game_id)
    }
    return fmt.tprintf("[GJ_Session game=%s user=%s]",
        game_id,
        _buf_to_str(session.username[:]),
    )
}

