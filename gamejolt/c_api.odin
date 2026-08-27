package gamejolt

import "base:runtime"

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

// -----------------------------------------------------------------------
//  Helpers — copy Odin strings into fixed C buffers safely.
//  Returns false if src was too long and was silently truncated.
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
_user_to_c :: proc(u: GJ_User) -> GJ_User_C {
    c: GJ_User_C
    c.id = i32(u.id)
    _copy_to_buf(c.username[:],   u.username)
    _copy_to_buf(c.avatar_url[:], u.avatar_url)
    _copy_to_buf(c.status[:],     u.status)
    return c
}

@(private)
_trophy_to_c :: proc(t: GJ_Trophy) -> GJ_Trophy_C {
    c: GJ_Trophy_C
    c.id         = i32(t.id)
    c.achieved   = b8(t.achieved)
    c.difficulty = i32(t.difficulty)
    _copy_to_buf(c.title[:],       t.title)
    _copy_to_buf(c.description[:], t.description)
    _copy_to_buf(c.image_url[:],   t.image_url)
    return c
}

@(private)
_score_to_c :: proc(s: GJ_Score) -> GJ_Score_C {
    c: GJ_Score_C
    c.sort = i32(s.sort)
    _copy_to_buf(c.score[:],      s.score)
    _copy_to_buf(c.user[:],       s.user)
    _copy_to_buf(c.guest[:],      s.guest)
    _copy_to_buf(c.extra_data[:], s.extra_data)
    return c
}

@(private)
_score_table_to_c :: proc(t: GJ_Score_Table) -> GJ_Score_Table_C {
    c: GJ_Score_Table_C
    c.id      = i32(t.id)
    c.primary = b8(t.primary)
    _copy_to_buf(c.name[:],        t.name)
    _copy_to_buf(c.description[:], t.description)
    return c
}

// -----------------------------------------------------------------------
//  C ABI exports — Session lifecycle
// -----------------------------------------------------------------------

@(export)
gj_init_c :: proc "c" (
    game_id:     cstring,
    private_key: cstring,
) -> GJ_Session {
    context = runtime.default_context()
    return gj_init(string(game_id), string(private_key))
}

@(export)
gj_destroy_c :: proc "c" (session: ^GJ_Session) {
    context = runtime.default_context()
    gj_destroy(session)
}

// -----------------------------------------------------------------------
//  C ABI exports — Auth
// -----------------------------------------------------------------------

@(export)
gj_login_c :: proc "c" (
    session:  ^GJ_Session,
    username: cstring,
    token:    cstring,
    out_user: ^GJ_User_C,
) -> i32 {
    context = runtime.default_context()
    user, err := gj_login(session, string(username), string(token))
    if err != .None do return i32(err)
    if out_user != nil do out_user^ = _user_to_c(user)
    return 0
}

// -----------------------------------------------------------------------
//  C ABI exports — Sessions
// -----------------------------------------------------------------------

@(export)
gj_session_open_c :: proc "c" (session: ^GJ_Session) -> i32 {
    context = runtime.default_context()
    return i32(gj_session_open(session))
}

@(export)
gj_session_close_c :: proc "c" (session: ^GJ_Session) -> i32 {
    context = runtime.default_context()
    return i32(gj_session_close(session))
}

@(export)
gj_session_ping_c :: proc "c" (session: ^GJ_Session, active: b8) -> i32 {
    context = runtime.default_context()
    return i32(gj_session_ping(session, bool(active)))
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
    session:       ^GJ_Session,
    achieved_only: b8,
    out_buf:       [^]GJ_Trophy_C,
    capacity:      i32,
    out_count:     ^i32,
) -> i32 {
    context = runtime.default_context()
    trophies, err := gj_trophies_fetch(session, bool(achieved_only))
    if err != .None do return i32(err)
    defer gj_trophies_delete(trophies)

    if out_count != nil do out_count^ = i32(len(trophies))
    if out_buf != nil {
        count := min(len(trophies), int(capacity))
        for i in 0..<count {
            out_buf[i] = _trophy_to_c(trophies[i])
        }
    }
    return 0
}

@(export)
gj_trophy_unlock_c :: proc "c" (session: ^GJ_Session, trophy_id: i32) -> i32 {
    context = runtime.default_context()
    return i32(gj_trophy_unlock(session, int(trophy_id)))
}

// -----------------------------------------------------------------------
//  C ABI exports — Scores
// -----------------------------------------------------------------------

@(export)
gj_scores_fetch_c :: proc "c" (
    session:   ^GJ_Session,
    table_id:  i32,
    limit:     i32,
    user_only: b8,
    out_buf:   [^]GJ_Score_C,
    capacity:  i32,
    out_count: ^i32,
) -> i32 {
    context = runtime.default_context()
    scores, err := gj_scores_fetch(session, int(table_id), int(limit), bool(user_only))
    if err != .None do return i32(err)
    defer gj_scores_delete(scores)

    if out_count != nil do out_count^ = i32(len(scores))
    if out_buf != nil {
        count := min(len(scores), int(capacity))
        for i in 0..<count {
            out_buf[i] = _score_to_c(scores[i])
        }
    }
    return 0
}

@(export)
gj_scores_tables_c :: proc "c" (
    session:   ^GJ_Session,
    out_buf:   [^]GJ_Score_Table_C,
    capacity:  i32,
    out_count: ^i32,
) -> i32 {
    context = runtime.default_context()
    tables, err := gj_scores_tables(session)
    if err != .None do return i32(err)
    defer gj_score_tables_delete(tables)

    if out_count != nil do out_count^ = i32(len(tables))
    if out_buf != nil {
        count := min(len(tables), int(capacity))
        for i in 0..<count {
            out_buf[i] = _score_table_to_c(tables[i])
        }
    }
    return 0
}

@(export)
gj_scores_submit_c :: proc "c" (
    session:   ^GJ_Session,
    score_str: cstring,
    sort:      i32,
    table_id:  i32,
    extra:     cstring,
) -> i32 {
    context = runtime.default_context()
    return i32(gj_scores_submit(session, string(score_str), int(sort), int(table_id), string(extra)))
}

@(export)
gj_scores_submit_guest_c :: proc "c" (
    session:    ^GJ_Session,
    guest_name: cstring,
    score_str:  cstring,
    sort:       i32,
    table_id:   i32,
) -> i32 {
    context = runtime.default_context()
    return i32(gj_scores_submit_guest(session, string(guest_name), string(score_str), int(sort), int(table_id)))
}

@(export)
gj_scores_rank_c :: proc "c" (
    session:  ^GJ_Session,
    sort:     i32,
    table_id: i32,
    out_rank: ^i32,
) -> i32 {
    context = runtime.default_context()
    rank, err := gj_scores_rank(session, int(sort), int(table_id))
    if err != .None do return i32(err)
    if out_rank != nil do out_rank^ = i32(rank)
    return 0
}

// -----------------------------------------------------------------------
//  C ABI exports — Data Store
// -----------------------------------------------------------------------

@(export)
gj_data_set_c :: proc "c" (
    session: ^GJ_Session,
    key:     cstring,
    data:    cstring,
    user:    b8,
) -> i32 {
    context = runtime.default_context()
    return i32(gj_data_set(session, string(key), string(data), bool(user)))
}

@(export)
gj_data_remove_c :: proc "c" (
    session: ^GJ_Session,
    key:     cstring,
    user:    b8,
) -> i32 {
    context = runtime.default_context()
    return i32(gj_data_remove(session, string(key), bool(user)))
}

// Reads a data-store value into a caller-provided buffer (null-terminated).
@(export)
gj_data_get_c :: proc "c" (
    session:  ^GJ_Session,
    key:      cstring,
    user:     b8,
    out_buf:  [^]u8,
    capacity: i32,
) -> i32 {
    context = runtime.default_context()
    data, err := gj_data_get(session, string(key), bool(user))
    if err != .None do return i32(err)
    defer delete(data)
    if out_buf != nil && capacity > 0 {
        _copy_to_buf(out_buf[:capacity], data)
    }
    return 0
}

// Lists data-store keys into a caller-provided buffer.
@(export)
gj_data_keys_c :: proc "c" (
    session:   ^GJ_Session,
    user:      b8,
    out_buf:   [^]GJ_DataKey_C,
    capacity:  i32,
    out_count: ^i32,
) -> i32 {
    context = runtime.default_context()
    keys, err := gj_data_keys(session, bool(user))
    if err != .None do return i32(err)
    defer gj_data_keys_delete(keys)

    if out_count != nil do out_count^ = i32(len(keys))
    if out_buf != nil {
        count := min(len(keys), int(capacity))
        for i in 0..<count {
            _copy_to_buf(out_buf[i].key[:], keys[i])
        }
    }
    return 0
}
