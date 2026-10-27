package gamejolt

import "base:runtime"
import "core:strings"

// -----------------------------------------------------------------------
//  C-compatible flat structs
//  No Odin slices or strings — fixed-size byte arrays throughout.
// -----------------------------------------------------------------------

GJ_User_C :: struct {
    id:           i32,
    username:     [64]u8,
    avatar_url:   [256]u8,
    status:       [32]u8,
}

GJ_Trophy_C :: struct {
    id:          i32,
    difficulty:  i32,   // 0=Bronze 1=Silver 2=Gold 3=Platinum
    achieved:    b8,
    title:       [128]u8,
    description: [256]u8,
    image_url:   [256]u8,
}

GJ_Score_C :: struct {
    sort:       i32,
    score:      [128]u8,
    user:       [64]u8,
    guest:      [64]u8,
    extra_data: [256]u8,
}

GJ_Score_Table_C :: struct {
    id:          i32,
    primary:     b8,
    name:        [128]u8,
    description: [256]u8,
}

GJ_DataKey_C :: struct {
    key: [256]u8,
}


// Convert the stable C ABI session to a short-lived native session for one call.
@(private)
_session_from_c :: proc(c: GJ_Session_C) -> GJ_Session {
    // Copy the by-value parameter into an addressable local before slicing arrays.
    c_copy := c
    return GJ_Session{
        game_id = strings.clone(_buf_to_str(c_copy.game_id[:])),
        private_key = strings.clone(_buf_to_str(c_copy.private_key[:])),
        username = strings.clone(_buf_to_str(c_copy.username[:])),
        token = strings.clone(_buf_to_str(c_copy.token[:])),
        is_authed = bool(c.is_authed),
        _login_in_flight = bool(c._login_in_flight),
        _session_open_in_flight = bool(c._session_open_in_flight),
        _trophies_in_flight = bool(c._trophies_in_flight),
        _scores_in_flight = bool(c._scores_in_flight),
        _scores_submit_in_flight = bool(c._scores_submit_in_flight),
        _data_in_flight = bool(c._data_in_flight),
        _user_data_in_flight = bool(c._user_data_in_flight),
    }
}

@(private)
_session_sync_to_c :: proc(c: ^GJ_Session_C, native: ^GJ_Session) {
    _copy_to_buf(c.game_id[:], native.game_id)
    _copy_to_buf(c.private_key[:], native.private_key)
    _copy_to_buf(c.username[:], native.username)
    _copy_to_buf(c.token[:], native.token)
    c.is_authed = b8(native.is_authed)
    c._login_in_flight = b8(native._login_in_flight)
    c._session_open_in_flight = b8(native._session_open_in_flight)
    c._trophies_in_flight = b8(native._trophies_in_flight)
    c._scores_in_flight = b8(native._scores_in_flight)
    c._scores_submit_in_flight = b8(native._scores_submit_in_flight)
    c._data_in_flight = b8(native._data_in_flight)
    c._user_data_in_flight = b8(native._user_data_in_flight)
    gj_destroy(native)
}

// -----------------------------------------------------------------------
//  Helpers — copy Odin strings into fixed C buffers safely.
//  Returns false when src does not fit and is truncated; callers must check it.
// -----------------------------------------------------------------------

@(private)
_copy_to_buf :: proc(dst: []u8, src: string) -> bool {
    if len(src) >= len(dst) {
        n := len(dst) - 1
        copy(dst[:n], transmute([]u8)src[:n])
        dst[n] = 0
        return false  // truncated
    }
    copy(dst[:len(src)], transmute([]u8)src)
    dst[len(src)] = 0
    return true
}

@(private)
_user_to_c :: proc(u: GJ_User) -> (c: GJ_User_C, ok: bool) {
    c.id = i32(u.id)
    ok = _copy_to_buf(c.username[:], u.username)
    ok = _copy_to_buf(c.avatar_url[:], u.avatar_url) && ok
    ok = _copy_to_buf(c.status[:], u.status) && ok
    return c, ok
}

@(private)
_trophy_to_c :: proc(t: GJ_Trophy) -> (c: GJ_Trophy_C, ok: bool) {
    c.id         = i32(t.id)
    c.achieved   = b8(t.achieved)
    c.difficulty = i32(t.difficulty)
    ok = _copy_to_buf(c.title[:], t.title)
    ok = _copy_to_buf(c.description[:], t.description) && ok
    ok = _copy_to_buf(c.image_url[:], t.image_url) && ok
    return c, ok
}

@(private)
_score_to_c :: proc(s: GJ_Score) -> (c: GJ_Score_C, ok: bool) {
    c.sort = i32(s.sort)
    ok = _copy_to_buf(c.score[:], s.score)
    ok = _copy_to_buf(c.user[:], s.user) && ok
    ok = _copy_to_buf(c.guest[:], s.guest) && ok
    ok = _copy_to_buf(c.extra_data[:], s.extra_data) && ok
    return c, ok
}

@(private)
_score_table_to_c :: proc(t: GJ_Score_Table) -> (c: GJ_Score_Table_C, ok: bool) {
    c.id      = i32(t.id)
    c.primary = b8(t.primary)
    ok = _copy_to_buf(c.name[:], t.name)
    ok = _copy_to_buf(c.description[:], t.description) && ok
    return c, ok
}

// -----------------------------------------------------------------------
//  C ABI exports — Session lifecycle
// -----------------------------------------------------------------------

@(export)
gj_init_c :: proc "c" (game_id: cstring, private_key: cstring) -> GJ_Session_C {
    context = runtime.default_context()
    // The C session stores credentials in 64-byte fields, including the NUL.
    // Reject null or oversized inputs instead of silently truncating them.
    if game_id == nil || private_key == nil do return {}
    game_id_str := string(game_id)
    private_key_str := string(private_key)
    if len(game_id_str) >= 64 || len(private_key_str) >= 64 do return {}

    native := gj_init(game_id_str, private_key_str)
    c: GJ_Session_C
    _session_sync_to_c(&c, &native)
    return c
}

@(export)
gj_destroy_c :: proc "c" (session: ^GJ_Session_C) {
    context = runtime.default_context()
    if session == nil do return
    session^ = {}
}

// -----------------------------------------------------------------------
//  C ABI exports — Auth
// -----------------------------------------------------------------------

@(export)
gj_login_c :: proc "c" (
    session:  ^GJ_Session_C,
    username: cstring,
    token:    cstring,
    out_user: ^GJ_User_C,
) -> i32 {
    context = runtime.default_context()
    if session == nil do return i32(GJ_Error.Missing_Config)
    // username/token are cached in the C session's 64-byte fields.
    if username == nil || token == nil do return i32(GJ_Error.Bad_Credentials)
    username_str := string(username)
    token_str := string(token)
    if len(username_str) >= 64 || len(token_str) >= 64 do return i32(GJ_Error.Bad_Credentials)
    native := _session_from_c(session^)
    defer _session_sync_to_c(session, &native)
    user, err := gj_login(&native, username_str, token_str)
    if err != .None do return i32(err)
    // The native API returns caller-owned strings; the C result is a copy.
    defer {
        delete(user.username)
        delete(user.avatar_url)
        delete(user.status)
        delete(user.signed_up)
        delete(user.last_logged_in)
    }
    if out_user != nil {
        c_user, ok := _user_to_c(user)
        if !ok do return i32(GJ_Error.Buffer_Too_Small)
        out_user^ = c_user
    }
    return 0
}

// -----------------------------------------------------------------------
//  C ABI exports — Sessions
// -----------------------------------------------------------------------

@(export)
gj_session_open_c :: proc "c" (session: ^GJ_Session_C) -> i32 {
    context = runtime.default_context()
    if session == nil do return i32(GJ_Error.Missing_Config)
    native := _session_from_c(session^)
    defer _session_sync_to_c(session, &native)
    return i32(gj_session_open(&native))
}

@(export)
gj_session_close_c :: proc "c" (session: ^GJ_Session_C) -> i32 {
    context = runtime.default_context()
    if session == nil do return i32(GJ_Error.Missing_Config)
    native := _session_from_c(session^)
    defer _session_sync_to_c(session, &native)
    return i32(gj_session_close(&native))
}

@(export)
gj_session_ping_c :: proc "c" (session: ^GJ_Session_C, active: b8) -> i32 {
    context = runtime.default_context()
    if session == nil do return i32(GJ_Error.Missing_Config)
    native := _session_from_c(session^)
    defer _session_sync_to_c(session, &native)
    return i32(gj_session_ping(&native, bool(active)))
}

// -----------------------------------------------------------------------
//  C ABI exports — Trophies
//
//  gj_trophies_fetch_c uses a caller-provided buffer pattern:
//    - Pass out_buf=NULL / capacity=0 to query the total count only.
//    - Pass a buffer + capacity to fill up to `capacity` entries.
//    - out_count always receives the TOTAL number available (not capped).
// -----------------------------------------------------------------------

@(export)
gj_trophies_fetch_c :: proc "c" (
    session:       ^GJ_Session_C,
    achieved_only: b8,
    out_buf:       [^]GJ_Trophy_C,
    capacity:      i32,
    out_count:     ^i32,
) -> i32 {
    context = runtime.default_context()
    if session == nil do return i32(GJ_Error.Missing_Config)
    if capacity < 0 || (out_buf == nil && capacity != 0) do return i32(GJ_Error.Unknown)
    native := _session_from_c(session^)
    defer _session_sync_to_c(session, &native)
    trophies, err := gj_trophies_fetch(&native, bool(achieved_only))
    if err != .None do return i32(err)
    defer gj_trophies_delete(trophies)

    if out_count != nil do out_count^ = i32(len(trophies))
    if out_buf != nil {
        count := min(len(trophies), int(capacity))
        for i in 0..<count {
            c_trophy, ok := _trophy_to_c(trophies[i])
            if !ok do return i32(GJ_Error.Buffer_Too_Small)
            out_buf[i] = c_trophy
        }
    }
    return 0
}

@(export)
gj_trophy_unlock_c :: proc "c" (session: ^GJ_Session_C, trophy_id: i32) -> i32 {
    context = runtime.default_context()
    if session == nil do return i32(GJ_Error.Missing_Config)
    native := _session_from_c(session^)
    defer _session_sync_to_c(session, &native)
    return i32(gj_trophy_unlock(&native, int(trophy_id)))
}

// -----------------------------------------------------------------------
//  C ABI exports — Scores
// -----------------------------------------------------------------------

@(export)
gj_scores_fetch_c :: proc "c" (
    session:   ^GJ_Session_C,
    table_id:  i32,
    limit:     i32,
    user_only: b8,
    out_buf:   [^]GJ_Score_C,
    capacity:  i32,
    out_count: ^i32,
) -> i32 {
    context = runtime.default_context()
    if session == nil do return i32(GJ_Error.Missing_Config)
    if capacity < 0 || (out_buf == nil && capacity != 0) do return i32(GJ_Error.Unknown)
    native := _session_from_c(session^)
    defer _session_sync_to_c(session, &native)
    scores, err := gj_scores_fetch(&native, int(table_id), int(limit), bool(user_only))
    if err != .None do return i32(err)
    defer gj_scores_delete(scores)

    if out_count != nil do out_count^ = i32(len(scores))
    if out_buf != nil {
        count := min(len(scores), int(capacity))
        for i in 0..<count {
            c_score, ok := _score_to_c(scores[i])
            if !ok do return i32(GJ_Error.Buffer_Too_Small)
            out_buf[i] = c_score
        }
    }
    return 0
}

@(export)
gj_scores_tables_c :: proc "c" (
    session:   ^GJ_Session_C,
    out_buf:   [^]GJ_Score_Table_C,
    capacity:  i32,
    out_count: ^i32,
) -> i32 {
    context = runtime.default_context()
    if session == nil do return i32(GJ_Error.Missing_Config)
    if capacity < 0 || (out_buf == nil && capacity != 0) do return i32(GJ_Error.Unknown)
    native := _session_from_c(session^)
    defer _session_sync_to_c(session, &native)
    tables, err := gj_scores_tables(&native)
    if err != .None do return i32(err)
    defer gj_score_tables_delete(tables)

    if out_count != nil do out_count^ = i32(len(tables))
    if out_buf != nil {
        count := min(len(tables), int(capacity))
        for i in 0..<count {
            c_table, ok := _score_table_to_c(tables[i])
            if !ok do return i32(GJ_Error.Buffer_Too_Small)
            out_buf[i] = c_table
        }
    }
    return 0
}

@(export)
gj_scores_submit_c :: proc "c" (
    session:   ^GJ_Session_C,
    score_str: cstring,
    sort:      i32,
    table_id:  i32,
    extra:     cstring,
) -> i32 {
    context = runtime.default_context()
    if session == nil do return i32(GJ_Error.Missing_Config)
    native := _session_from_c(session^)
    defer _session_sync_to_c(session, &native)
    return i32(gj_scores_submit(&native, string(score_str), int(sort), int(table_id), string(extra)))
}

@(export)
gj_scores_submit_guest_c :: proc "c" (
    session:    ^GJ_Session_C,
    guest_name: cstring,
    score_str:  cstring,
    sort:       i32,
    table_id:   i32,
) -> i32 {
    context = runtime.default_context()
    if session == nil do return i32(GJ_Error.Missing_Config)
    native := _session_from_c(session^)
    defer _session_sync_to_c(session, &native)
    return i32(gj_scores_submit_guest(&native, string(guest_name), string(score_str), int(sort), int(table_id)))
}

@(export)
gj_scores_rank_c :: proc "c" (
    session:  ^GJ_Session_C,
    sort:     i32,
    table_id: i32,
    out_rank: ^i32,
) -> i32 {
    context = runtime.default_context()
    if session == nil do return i32(GJ_Error.Missing_Config)
    native := _session_from_c(session^)
    defer _session_sync_to_c(session, &native)
    rank, err := gj_scores_rank(&native, int(sort), int(table_id))
    if err != .None do return i32(err)
    if out_rank != nil do out_rank^ = i32(rank)
    return 0
}

// -----------------------------------------------------------------------
//  C ABI exports — Data Store
// -----------------------------------------------------------------------

@(export)
gj_data_set_c :: proc "c" (
    session: ^GJ_Session_C,
    key:     cstring,
    data:    cstring,
    user:    b8,
) -> i32 {
    context = runtime.default_context()
    if session == nil do return i32(GJ_Error.Missing_Config)
    native := _session_from_c(session^)
    defer _session_sync_to_c(session, &native)
    return i32(gj_data_set(&native, string(key), string(data), bool(user)))
}

@(export)
gj_data_remove_c :: proc "c" (
    session: ^GJ_Session_C,
    key:     cstring,
    user:    b8,
) -> i32 {
    context = runtime.default_context()
    if session == nil do return i32(GJ_Error.Missing_Config)
    native := _session_from_c(session^)
    defer _session_sync_to_c(session, &native)
    return i32(gj_data_remove(&native, string(key), bool(user)))
}

// Reads a data-store value into a caller-provided buffer (null-terminated).
@(export)
gj_data_get_c :: proc "c" (
    session:  ^GJ_Session_C,
    key:      cstring,
    user:     b8,
    out_buf:  [^]u8,
    capacity: i32,
) -> i32 {
    context = runtime.default_context()
    if session == nil do return i32(GJ_Error.Missing_Config)
    if out_buf == nil || capacity <= 0 do return i32(GJ_Error.Buffer_Too_Small)
    native := _session_from_c(session^)
    defer _session_sync_to_c(session, &native)
    data, err := gj_data_get(&native, string(key), bool(user))
    if err != .None do return i32(err)
    defer delete(data)
    if out_buf != nil && capacity > 0 {
        if !_copy_to_buf(out_buf[:capacity], data) do return i32(GJ_Error.Buffer_Too_Small)
    }
    return 0
}

// Lists data-store keys into a caller-provided buffer.
@(export)
gj_data_keys_c :: proc "c" (
    session:   ^GJ_Session_C,
    user:      b8,
    out_buf:   [^]GJ_DataKey_C,
    capacity:  i32,
    out_count: ^i32,
) -> i32 {
    context = runtime.default_context()
    if session == nil do return i32(GJ_Error.Missing_Config)
    if capacity < 0 || (out_buf == nil && capacity != 0) do return i32(GJ_Error.Unknown)
    native := _session_from_c(session^)
    defer _session_sync_to_c(session, &native)
    keys, err := gj_data_keys(&native, bool(user))
    if err != .None do return i32(err)
    defer gj_data_keys_delete(keys)

    if out_count != nil do out_count^ = i32(len(keys))
    if out_buf != nil {
        count := min(len(keys), int(capacity))
        for i in 0..<count {
            if !_copy_to_buf(out_buf[i].key[:], keys[i]) do return i32(GJ_Error.Buffer_Too_Small)
        }
    }
    return 0
}

// -----------------------------------------------------------------------
//  C ABI exports — Utilities
// -----------------------------------------------------------------------

@(export)
gj_is_logged_in_c :: proc "c" (session: ^GJ_Session_C) -> b8 {
    context = runtime.default_context()
    if session == nil do return false
    native := _session_from_c(session^)
    defer _session_sync_to_c(session, &native)
    return b8(gj_is_logged_in(&native))
}

@(export)
gj_session_username_c :: proc "c" (
    session:  ^GJ_Session_C,
    out_buf:  [^]u8,
    capacity: i32,
) -> i32 {
    context = runtime.default_context()
    if session == nil do return i32(GJ_Error.Missing_Config)
    if out_buf == nil || capacity <= 0 do return i32(GJ_Error.Buffer_Too_Small)
    native := _session_from_c(session^)
    defer _session_sync_to_c(session, &native)
    if !gj_is_logged_in(&native) do return i32(GJ_Error.Not_Authenticated)
    uname := gj_session_username(&native)
    if out_buf != nil && capacity > 0 {
        if !_copy_to_buf(out_buf[:capacity], uname) do return i32(GJ_Error.Buffer_Too_Small)
    }
    return 0
}

@(export)
gj_get_current_user_c :: proc "c" (
    session:  ^GJ_Session_C,
    out_user: ^GJ_User_C,
) -> i32 {
    context = runtime.default_context()
    if session == nil do return i32(GJ_Error.Missing_Config)
    native := _session_from_c(session^)
    defer _session_sync_to_c(session, &native)
    user, err := gj_get_current_user(&native, context.temp_allocator)
    if err != .None do return i32(err)
    if out_user != nil {
        c_user, ok := _user_to_c(user)
        if !ok do return i32(GJ_Error.Buffer_Too_Small)
        out_user^ = c_user
    }
    return 0
}

@(export)
gj_get_user_avatar_url_c :: proc "c" (
    session:  ^GJ_Session_C,
    out_buf:  [^]u8,
    capacity: i32,
) -> i32 {
    context = runtime.default_context()
    if session == nil do return i32(GJ_Error.Missing_Config)
    if out_buf == nil || capacity <= 0 do return i32(GJ_Error.Buffer_Too_Small)
    native := _session_from_c(session^)
    defer _session_sync_to_c(session, &native)
    url, err := gj_get_user_avatar_url(&native, context.temp_allocator)
    if err != .None do return i32(err)
    if out_buf != nil && capacity > 0 {
        if !_copy_to_buf(out_buf[:capacity], url) do return i32(GJ_Error.Buffer_Too_Small)
    }
    return 0
}

@(export)
gj_data_get_user_picture_c :: proc "c" (
    session:  ^GJ_Session_C,
    out_buf:  [^]u8,
    capacity: i32,
) -> i32 {
    context = runtime.default_context()
    if session == nil do return i32(GJ_Error.Missing_Config)
    if out_buf == nil || capacity <= 0 do return i32(GJ_Error.Buffer_Too_Small)
    native := _session_from_c(session^)
    defer _session_sync_to_c(session, &native)
    pic, err := gj_data_get_user_picture(&native, context.temp_allocator)
    if err != .None do return i32(err)
    if out_buf != nil && capacity > 0 {
        if !_copy_to_buf(out_buf[:capacity], pic) do return i32(GJ_Error.Buffer_Too_Small)
    }
    return 0
}

@(export)
gj_data_set_user_picture_c :: proc "c" (
    session:      ^GJ_Session_C,
    picture_data: cstring,
) -> i32 {
    context = runtime.default_context()
    if session == nil do return i32(GJ_Error.Missing_Config)
    native := _session_from_c(session^)
    defer _session_sync_to_c(session, &native)
    return i32(gj_data_set_user_picture(&native, string(picture_data)))
}

@(export)
gj_data_get_int_c :: proc "c" (
    session:     ^GJ_Session_C,
    key:         cstring,
    default_val: i32,
    user:        b8,
    out_val:     ^i32,
) -> i32 {
    context = runtime.default_context()
    if session == nil do return i32(GJ_Error.Missing_Config)
    native := _session_from_c(session^)
    defer _session_sync_to_c(session, &native)
    val, err := gj_data_get_int(&native, string(key), int(default_val), bool(user))
    if err != .None do return i32(err)
    if out_val != nil do out_val^ = i32(val)
    return 0
}

@(export)
gj_data_set_int_c :: proc "c" (
    session: ^GJ_Session_C,
    key:     cstring,
    value:   i32,
    user:    b8,
) -> i32 {
    context = runtime.default_context()
    if session == nil do return i32(GJ_Error.Missing_Config)
    native := _session_from_c(session^)
    defer _session_sync_to_c(session, &native)
    return i32(gj_data_set_int(&native, string(key), int(value), bool(user)))
}

@(export)
gj_data_increment_c :: proc "c" (
    session: ^GJ_Session_C,
    key:     cstring,
    delta:   i32,
    user:    b8,
    out_val: ^i32,
) -> i32 {
    context = runtime.default_context()
    if session == nil do return i32(GJ_Error.Missing_Config)
    native := _session_from_c(session^)
    defer _session_sync_to_c(session, &native)
    new_val, err := gj_data_increment(&native, string(key), int(delta), bool(user))
    if err != .None do return i32(err)
    if out_val != nil do out_val^ = i32(new_val)
    return 0
}

@(export)
gj_has_trophy_c :: proc "c" (
    session:      ^GJ_Session_C,
    trophy_id:    i32,
    out_achieved: ^b8,
) -> i32 {
    context = runtime.default_context()
    if session == nil do return i32(GJ_Error.Missing_Config)
    native := _session_from_c(session^)
    defer _session_sync_to_c(session, &native)
    achieved, err := gj_has_trophy(&native, int(trophy_id))
    if err != .None do return i32(err)
    if out_achieved != nil do out_achieved^ = b8(achieved)
    return 0
}

@(export)
gj_score_format_c :: proc "c" (
    sort:     i32,
    out_buf:  [^]u8,
    capacity: i32,
) -> i32 {
    context = runtime.default_context()
    if out_buf == nil || capacity <= 0 do return i32(GJ_Error.Buffer_Too_Small)
    formatted := gj_score_format(int(sort), context.temp_allocator)
    if out_buf != nil && capacity > 0 {
        if !_copy_to_buf(out_buf[:capacity], formatted) do return i32(GJ_Error.Buffer_Too_Small)
    }
    return 0
}

