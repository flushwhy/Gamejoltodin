#+feature dynamic-literals
package gamejolt

import "core:encoding/json"
import "core:strconv"
import "core:strings"
import "core:thread"

// -----------------------------------------------------------------------
//  Session Lifecycle
// -----------------------------------------------------------------------

// Creates and returns a new session. The caller owns this and should
// call gj_destroy when done. No allocations happen inside the library
// beyond what you explicitly trigger via API calls.
gj_init :: proc(
    game_id:     string,
    private_key: string,
) -> GJ_Session {
    s: GJ_Session
    ok1 := _copy_to_buf(s.game_id[:],     game_id)
    ok2 := _copy_to_buf(s.private_key[:], private_key)
    when ODIN_DEBUG {
        assert(ok1, "gj_init: game_id exceeds 63-character buffer — it will be truncated and auth will fail")
        assert(ok2, "gj_init: private_key exceeds 63-character buffer — it will be truncated and auth will fail")
    }
    return s
}

gj_destroy :: proc(session: ^GJ_Session) {
    session^ = {}
}

// -----------------------------------------------------------------------
//  Auth
// -----------------------------------------------------------------------

// Authenticates a player. Must be called before any user-specific API.
// Credentials are cached in the session for all subsequent calls.
gj_login :: proc(
    session:  ^GJ_Session,
    username: string,
    token:    string,
    allocator := context.allocator,
) -> (user: GJ_User, err: GJ_Error) {
    if session._login_in_flight do return {}, .Request_In_Flight
    session._login_in_flight = true
    defer session._login_in_flight = false

    params := map[string]string{
        "username"   = username,
        "user_token" = token,
    }
    defer delete(params)

    response, req_err := _gj_request(session, "/users/auth", params, context.temp_allocator)
    if req_err != .None do return {}, req_err

    // Fetch full user data
    fetch_params := map[string]string{
        "username" = username,
    }
    defer delete(fetch_params)

    user_response, user_err := _gj_request(session, "/users", fetch_params, context.temp_allocator)
    if user_err != .None do return {}, user_err

    users_val, has_users := user_response["users"]
    if !has_users do return {}, .Invalid_Response

    users_arr, ok := users_val.(json.Array)
    if !ok || len(users_arr) == 0 do return {}, .Invalid_Response

    user_obj, ok2 := users_arr[0].(json.Object)
    if !ok2 do return {}, .Invalid_Response

    user = _parse_user(user_obj, allocator)

    // Cache credentials in session
    _copy_to_buf(session.username[:], username)
    _copy_to_buf(session.token[:], token)
    session.is_authed = true

    return user, .None
}

// Async convenience — Odin layer only, not exported to C ABI
gj_login_async :: proc(
    session:  ^GJ_Session,
    username: string,
    token:    string,
    callback: proc(GJ_User, GJ_Error),
) {
    Args :: struct {
        session:  ^GJ_Session,
        username: string,
        token:    string,
        cb:       proc(GJ_User, GJ_Error),
    }
    args := new(Args)
    // Clone strings so the thread owns its own copies — safe even if the
    // caller's stack frame ends before the thread runs (was a use-after-free).
    args^ = {
        session  = session,
        username = strings.clone(username),
        token    = strings.clone(token),
        cb       = callback,
    }

    thread.run_with_poly_data(args, proc(a: ^Args) {
        user, err := gj_login(a.session, a.username, a.token)
        a.cb(user, err)
        delete(a.username)
        delete(a.token)
        free(a)
    }, context)
}

// -----------------------------------------------------------------------
//  Sessions
// -----------------------------------------------------------------------

gj_session_open :: proc(session: ^GJ_Session) -> GJ_Error {
    if !session.is_authed          do return .Not_Authenticated
    if session._session_open_in_flight do return .Request_In_Flight
    session._session_open_in_flight = true
    defer session._session_open_in_flight = false

    params := map[string]string{
        "username"   = _buf_to_str(session.username[:]),
        "user_token" = _buf_to_str(session.token[:]),
    }
    defer delete(params)

    _, err := _gj_request(session, "/sessions/open", params)
    return err
}

gj_session_close :: proc(session: ^GJ_Session) -> GJ_Error {
    if !session.is_authed do return .Not_Authenticated

    params := map[string]string{
        "username"   = _buf_to_str(session.username[:]),
        "user_token" = _buf_to_str(session.token[:]),
    }
    defer delete(params)

    _, err := _gj_request(session, "/sessions/close", params)
    return err
}

// Status is "active" or "idle"
gj_session_ping :: proc(session: ^GJ_Session, active: bool = true) -> GJ_Error {
    if !session.is_authed do return .Not_Authenticated

    params := map[string]string{
        "username"   = _buf_to_str(session.username[:]),
        "user_token" = _buf_to_str(session.token[:]),
        "status"     = active ? "active" : "idle",
    }
    defer delete(params)

    _, err := _gj_request(session, "/sessions/ping", params)
    return err
}

// -----------------------------------------------------------------------
//  Trophies
// -----------------------------------------------------------------------

gj_trophies_fetch :: proc(
    session:       ^GJ_Session,
    achieved_only: bool = false,
    allocator    := context.allocator,
) -> (trophies: []GJ_Trophy, err: GJ_Error) {
    if !session.is_authed         do return nil, .Not_Authenticated
    if session._trophies_in_flight do return nil, .Request_In_Flight
    session._trophies_in_flight = true
    defer session._trophies_in_flight = false

    params := map[string]string{
        "username"   = _buf_to_str(session.username[:]),
        "user_token" = _buf_to_str(session.token[:]),
        "achieved"   = achieved_only ? "true" : "false",
    }
    defer delete(params)

    response, req_err := _gj_request(session, "/trophies", params, context.temp_allocator)
    if req_err != .None do return nil, req_err

    trophies_val, ok := response["trophies"]
    if !ok do return nil, .Invalid_Response

    trophies_arr, ok2 := trophies_val.(json.Array)
    if !ok2 do return nil, .Invalid_Response

    result := make([]GJ_Trophy, len(trophies_arr), allocator)
    for entry, i in trophies_arr {
        obj, ok3 := entry.(json.Object)
        if !ok3 do continue
        result[i] = _parse_trophy(obj, allocator)
    }

    return result, .None
}

// Unlocks (achieves) a trophy for the currently authenticated user.
gj_trophy_unlock :: proc(session: ^GJ_Session, trophy_id: int) -> GJ_Error {
    if !session.is_authed do return .Not_Authenticated

    params := map[string]string{
        "username"   = _buf_to_str(session.username[:]),
        "user_token" = _buf_to_str(session.token[:]),
        "trophy_id"  = _int_to_str(trophy_id),
    }
    defer delete(params)

    _, err := _gj_request(session, "/trophies/add-achieved", params)
    return err
}

// -----------------------------------------------------------------------
//  Scores
// -----------------------------------------------------------------------

gj_scores_fetch :: proc(
    session:   ^GJ_Session,
    table_id:  int  = 0,
    limit:     int  = 10,
    user_only: bool = false,
    allocator := context.allocator,
) -> (scores: []GJ_Score, err: GJ_Error) {
    if session._scores_in_flight do return nil, .Request_In_Flight
    session._scores_in_flight = true
    defer session._scores_in_flight = false

    params := make(map[string]string, 8, context.temp_allocator)
    if table_id != 0 do params["table_id"] = _int_to_str(table_id)
    if limit    >  0 do params["limit"]    = _int_to_str(limit)
    if user_only && session.is_authed {
        params["username"]   = _buf_to_str(session.username[:])
        params["user_token"] = _buf_to_str(session.token[:])
    }

    response, req_err := _gj_request(session, "/scores", params, context.temp_allocator)
    if req_err != .None do return nil, req_err

    scores_val, ok := response["scores"]
    if !ok do return nil, .Invalid_Response

    scores_arr, ok2 := scores_val.(json.Array)
    if !ok2 do return nil, .Invalid_Response

    result := make([]GJ_Score, len(scores_arr), allocator)
    for entry, i in scores_arr {
        obj, ok3 := entry.(json.Object)
        if !ok3 do continue
        result[i] = _parse_score(obj, allocator)
    }

    return result, .None
}

gj_scores_tables :: proc(
    session:  ^GJ_Session,
    allocator := context.allocator,
) -> (tables: []GJ_Score_Table, err: GJ_Error) {
    response, req_err := _gj_request(session, "/scores/tables", {}, context.temp_allocator)
    if req_err != .None do return nil, req_err

    tables_val, ok := response["tables"]
    if !ok do return nil, .Invalid_Response

    tables_arr, ok2 := tables_val.(json.Array)
    if !ok2 do return nil, .Invalid_Response

    result := make([]GJ_Score_Table, len(tables_arr), allocator)
    for entry, i in tables_arr {
        obj, ok3 := entry.(json.Object)
        if !ok3 do continue
        result[i] = _parse_score_table(obj, allocator)
    }

    return result, .None
}

gj_scores_submit :: proc(
    session:   ^GJ_Session,
    score_str: string,
    sort:      int,
    table_id:  int    = 0,
    extra:     string = "",
) -> GJ_Error {
    if !session.is_authed             do return .Not_Authenticated
    if session._scores_submit_in_flight do return .Request_In_Flight
    session._scores_submit_in_flight = true
    defer session._scores_submit_in_flight = false

    params := make(map[string]string, 8, context.temp_allocator)
    params["username"]   = _buf_to_str(session.username[:])
    params["user_token"] = _buf_to_str(session.token[:])
    params["score"]      = score_str
    params["sort"]       = _int_to_str(sort)
    if table_id != 0 do params["table_id"]  = _int_to_str(table_id)
    if extra    != "" do params["extra_data"] = extra

    _, err := _gj_request(session, "/scores/add", params)
    return err
}

gj_scores_submit_guest :: proc(
    session:    ^GJ_Session,
    guest_name: string,
    score_str:  string,
    sort:       int,
    table_id:   int = 0,
) -> GJ_Error {
    params := make(map[string]string, 6, context.temp_allocator)
    params["guest"] = guest_name
    params["score"] = score_str
    params["sort"]  = _int_to_str(sort)
    if table_id != 0 do params["table_id"] = _int_to_str(table_id)

    _, err := _gj_request(session, "/scores/add", params)
    return err
}

gj_scores_rank :: proc(
    session:  ^GJ_Session,
    sort:     int,
    table_id: int = 0,
) -> (rank: int, err: GJ_Error) {
    params := make(map[string]string, 4, context.temp_allocator)
    params["sort"] = _int_to_str(sort)
    if table_id != 0 do params["table_id"] = _int_to_str(table_id)

    response, req_err := _gj_request(session, "/scores/get-rank", params)
    if req_err != .None do return 0, req_err

    return _json_int(response, "rank"), .None
}

// -----------------------------------------------------------------------
//  Data Store
//
//  user=false → global store (all players)
//  user=true  → user-scoped store (requires authentication)
// -----------------------------------------------------------------------

gj_data_set :: proc(
    session: ^GJ_Session,
    key:     string,
    data:    string,
    user:    bool = false,
) -> GJ_Error {
    if user && !session.is_authed do return .Not_Authenticated
    guard := user ? &session._user_data_in_flight : &session._data_in_flight
    if guard^ do return .Request_In_Flight
    guard^ = true
    defer guard^ = false

    params := make(map[string]string, 6, context.temp_allocator)
    params["key"]  = key
    params["data"] = data
    if user {
        params["username"]   = _buf_to_str(session.username[:])
        params["user_token"] = _buf_to_str(session.token[:])
    }

    _, err := _gj_request(session, "/data-store/set", params)
    return err
}

gj_data_get :: proc(
    session:  ^GJ_Session,
    key:      string,
    user:     bool = false,
    allocator := context.allocator,
) -> (data: string, err: GJ_Error) {
    if user && !session.is_authed do return "", .Not_Authenticated

    params := make(map[string]string, 4, context.temp_allocator)
    params["key"] = key
    if user {
        params["username"]   = _buf_to_str(session.username[:])
        params["user_token"] = _buf_to_str(session.token[:])
    }

    response, req_err := _gj_request(session, "/data-store", params, context.temp_allocator)
    if req_err != .None do return "", req_err

    raw := _json_string(response, "data")
    return strings.clone(raw, allocator), .None
}

gj_data_remove :: proc(
    session: ^GJ_Session,
    key:     string,
    user:    bool = false,
) -> GJ_Error {
    if user && !session.is_authed do return .Not_Authenticated

    params := make(map[string]string, 4, context.temp_allocator)
    params["key"] = key
    if user {
        params["username"]   = _buf_to_str(session.username[:])
        params["user_token"] = _buf_to_str(session.token[:])
    }

    _, err := _gj_request(session, "/data-store/remove", params)
    return err
}

gj_data_keys :: proc(
    session:  ^GJ_Session,
    user:     bool = false,
    allocator := context.allocator,
) -> (keys: []string, err: GJ_Error) {
    if user && !session.is_authed do return nil, .Not_Authenticated

    params := make(map[string]string, 4, context.temp_allocator)
    if user {
        params["username"]   = _buf_to_str(session.username[:])
        params["user_token"] = _buf_to_str(session.token[:])
    }

    response, req_err := _gj_request(session, "/data-store/get-keys", params, context.temp_allocator)
    if req_err != .None do return nil, req_err

    keys_val, ok := response["keys"]
    if !ok do return nil, .Invalid_Response

    keys_arr, ok2 := keys_val.(json.Array)
    if !ok2 do return nil, .Invalid_Response

    result := make([]string, len(keys_arr), allocator)
    for entry, i in keys_arr {
        obj, ok3 := entry.(json.Object)
        if !ok3 do continue
        result[i] = strings.clone(_json_string(obj, "key"), allocator)
    }

    return result, .None
}

// -----------------------------------------------------------------------
//  Memory cleanup helpers
//
//  Call these to free slices returned by the fetch procs.
//  Each one frees all inner strings and then the slice itself.
// -----------------------------------------------------------------------

gj_user_delete :: proc(user: ^GJ_User, allocator := context.allocator) {
    delete(user.username,              allocator)
    delete(user.avatar_url,            allocator)
    delete(user.status,                allocator)
    delete(user.signed_up,             allocator)
    delete(user.last_logged_in,        allocator)
    user^ = {}
}

gj_trophies_delete :: proc(trophies: []GJ_Trophy, allocator := context.allocator) {
    for &t in trophies {
        delete(t.title,       allocator)
        delete(t.description, allocator)
        delete(t.image_url,   allocator)
    }
    delete(trophies, allocator)
}

gj_scores_delete :: proc(scores: []GJ_Score, allocator := context.allocator) {
    for &s in scores {
        delete(s.score,      allocator)
        delete(s.user,       allocator)
        delete(s.guest,      allocator)
        delete(s.stored,     allocator)
        delete(s.extra_data, allocator)
    }
    delete(scores, allocator)
}

gj_score_tables_delete :: proc(tables: []GJ_Score_Table, allocator := context.allocator) {
    for &t in tables {
        delete(t.name,        allocator)
        delete(t.description, allocator)
    }
    delete(tables, allocator)
}

gj_data_keys_delete :: proc(keys: []string, allocator := context.allocator) {
    for k in keys {
        delete(k, allocator)
    }
    delete(keys, allocator)
}

// -----------------------------------------------------------------------
//  Private parse helpers
// -----------------------------------------------------------------------

@(private)
_parse_user :: proc(obj: json.Object, allocator := context.allocator) -> GJ_User {
    return GJ_User{
        id                    = _json_int(obj,      "id"),
        username              = strings.clone(_json_string(obj, "username"),   allocator),
        avatar_url            = strings.clone(_json_string(obj, "avatar_url"), allocator),
        status                = strings.clone(_json_string(obj, "status"),     allocator),
        signed_up             = strings.clone(_json_string(obj, "signed_up"),  allocator),
        signed_up_timestamp   = _json_int(obj, "signed_up_timestamp"),
        last_logged_in        = strings.clone(_json_string(obj, "last_logged_in"), allocator),
        last_logged_timestamp = _json_int(obj, "last_logged_in_timestamp"),
    }
}

@(private)
_parse_trophy :: proc(obj: json.Object, allocator := context.allocator) -> GJ_Trophy {
    diff_str := _json_string(obj, "difficulty")
    difficulty: GJ_Trophy_Difficulty
    switch diff_str {
    case "Bronze":   difficulty = .Bronze
    case "Silver":   difficulty = .Silver
    case "Gold":     difficulty = .Gold
    case "Platinum": difficulty = .Platinum
    }

    return GJ_Trophy{
        id          = _json_int(obj,  "id"),
        title       = strings.clone(_json_string(obj, "title"),       allocator),
        description = strings.clone(_json_string(obj, "description"), allocator),
        difficulty  = difficulty,
        image_url   = strings.clone(_json_string(obj, "image_url"),   allocator),
        achieved    = _json_string(obj, "achieved") != "false",
    }
}

@(private)
_parse_score :: proc(obj: json.Object, allocator := context.allocator) -> GJ_Score {
    return GJ_Score{
        score      = strings.clone(_json_string(obj, "score"),      allocator),
        sort       = _json_int(obj,  "sort"),
        user       = strings.clone(_json_string(obj, "user"),       allocator),
        guest      = strings.clone(_json_string(obj, "guest"),      allocator),
        stored     = strings.clone(_json_string(obj, "stored"),     allocator),
        extra_data = strings.clone(_json_string(obj, "extra_data"), allocator),
        user_id    = _json_int(obj,  "user_id"),
    }
}

@(private)
_parse_score_table :: proc(obj: json.Object, allocator := context.allocator) -> GJ_Score_Table {
    return GJ_Score_Table{
        id          = _json_int(obj,  "id"),
        name        = strings.clone(_json_string(obj, "name"),        allocator),
        description = strings.clone(_json_string(obj, "description"), allocator),
        primary     = _json_bool_str(obj, "primary"),
    }
}

@(private)
_int_to_str :: proc(n: int, allocator := context.temp_allocator) -> string {
    buf: [32]u8
    s := strconv.write_int(buf[:], i64(n), 10)
    return strings.clone(s, allocator)
}
