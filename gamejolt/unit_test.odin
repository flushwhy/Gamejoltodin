#+feature dynamic-literals
package gamejolt

import "core:encoding/json"
import "core:strings"
import "core:testing"

// -----------------------------------------------------------------------
//  Buffer & String Helpers Tests
// -----------------------------------------------------------------------

@(test)
test_copy_to_buf :: proc(t: ^testing.T) {
    buf: [16]u8

    // Normal fit
    ok := _copy_to_buf(buf[:], "hello")
    testing.expect(t, ok, "Expected ok to be true")
    testing.expect_value(t, string(buf[:5]), "hello")
    testing.expect_value(t, buf[5], 0)

    // Exact fit: 15 chars + 1 null terminator = 16 bytes
    ok = _copy_to_buf(buf[:], "123456789012345")
    testing.expect(t, ok, "Expected exact fit to succeed")
    testing.expect_value(t, buf[15], 0)

    // Truncation: 16+ chars in 16 byte buffer
    ok = _copy_to_buf(buf[:], "1234567890123456789")
    testing.expect(t, !ok, "Expected truncation to report false")
    testing.expect_value(t, buf[15], 0)
    testing.expect_value(t, string(buf[:15]), "123456789012345")
}

@(test)
test_buf_to_str :: proc(t: ^testing.T) {
    buf: [8]u8 = {'t', 'e', 's', 't', 0, 'x', 'y', 'z'}
    s := _buf_to_str(buf[:])
    testing.expect_value(t, s, "test")

    empty_buf: [4]u8 = {0, 0, 0, 0}
    testing.expect_value(t, _buf_to_str(empty_buf[:]), "")
}

@(test)
test_int_to_str :: proc(t: ^testing.T) {
    s0 := _int_to_str(0, context.allocator)
    defer delete(s0)
    testing.expect_value(t, s0, "0")

    s1 := _int_to_str(42, context.allocator)
    defer delete(s1)
    testing.expect_value(t, s1, "42")

    s2 := _int_to_str(-99, context.allocator)
    defer delete(s2)
    testing.expect_value(t, s2, "-99")

    s3 := _int_to_str(1000000, context.allocator)
    defer delete(s3)
    testing.expect_value(t, s3, "1000000")
}

// -----------------------------------------------------------------------
//  Cryptographic Signing Tests
// -----------------------------------------------------------------------

@(test)
test_signature_generation :: proc(t: ^testing.T) {
    // Test known MD5 behavior
    url := "https://api.gamejolt.com/api/game/v1_2/users/auth?game_id=12345&username=test"
    key := "secretkey"
    sig := _gj_sign(url, key, context.temp_allocator)

    // md5(url + key)
    testing.expect(t, len(sig) == 32, "MD5 signature must be 32 hex chars")
    // Repeat to ensure deterministic output
    sig2 := _gj_sign(url, key, context.temp_allocator)
    testing.expect_value(t, sig, sig2)
}

@(test)
test_url_builder :: proc(t: ^testing.T) {
    session: GJ_Session
    _copy_to_buf(session.game_id[:], "99999")
    _copy_to_buf(session.private_key[:], "mock_private_key")

    params := map[string]string{
        "zebra" = "last",
        "apple" = "first",
    }
    defer delete(params)

    url := _gj_build_url(&session, "/trophies", params, context.temp_allocator)

    // Verify mandatory injected params
    testing.expect(t, strings.contains(url, "game_id=99999"), "URL must contain game_id")
    testing.expect(t, strings.contains(url, "format=json"), "URL must contain format=json")

    // Verify alphabetical order: apple must precede zebra
    apple_pos := strings.index(url, "apple=first")
    zebra_pos := strings.index(url, "zebra=last")
    testing.expect(t, apple_pos >= 0, "URL must contain apple param")
    testing.expect(t, zebra_pos >= 0, "URL must contain zebra param")
    testing.expect(t, apple_pos < zebra_pos, "Parameters must be sorted alphabetically")

    // Verify signature parameter appended
    testing.expect(t, strings.contains(url, "&signature="), "URL must append &signature=")
}

// -----------------------------------------------------------------------
//  JSON Response Parsing Tests
// -----------------------------------------------------------------------

@(test)
test_parse_response_success :: proc(t: ^testing.T) {
    body := `{"response":{"success":"true","message":"all good","count":5}}`
    obj, err := _gj_parse_response(body, context.temp_allocator)
    testing.expect_value(t, err, GJ_Error.None)
    testing.expect(t, obj != nil, "Expected parsed response object")
    testing.expect_value(t, _json_string(obj, "message"), "all good")
    testing.expect_value(t, _json_int(obj, "count"), 5)
}

@(test)
test_parse_response_failure :: proc(t: ^testing.T) {
    body := `{"response":{"success":"false","message":"The signature is not valid."}}`
    _, err := _gj_parse_response(body, context.temp_allocator)
    testing.expect_value(t, err, GJ_Error.Auth_Failed)
}

@(test)
test_parse_response_invalid_json :: proc(t: ^testing.T) {
    body := `<html>Not JSON</html>`
    _, err := _gj_parse_response(body, context.temp_allocator)
    testing.expect_value(t, err, GJ_Error.Invalid_Response)
}

@(test)
test_json_helpers :: proc(t: ^testing.T) {
    raw := `{"str":"hello","num":123,"num_str":"456","num_float":78.0,"flag":"true","not_flag":"false"}`
    val, _ := json.parse(transmute([]byte)raw, allocator = context.temp_allocator)
    obj := val.(json.Object)

    testing.expect_value(t, _json_string(obj, "str"), "hello")
    testing.expect_value(t, _json_string(obj, "missing"), "")

    testing.expect_value(t, _json_int(obj, "num"), 123)
    testing.expect_value(t, _json_int(obj, "num_str"), 456)
    testing.expect_value(t, _json_int(obj, "num_float"), 78)
    testing.expect_value(t, _json_int(obj, "missing"), 0)

    testing.expect_value(t, _json_bool_str(obj, "flag"), true)
    testing.expect_value(t, _json_bool_str(obj, "not_flag"), false)
    testing.expect_value(t, _json_bool_str(obj, "missing"), false)
}

// -----------------------------------------------------------------------
//  Session & Utilities Tests
// -----------------------------------------------------------------------

@(test)
test_session_lifecycle :: proc(t: ^testing.T) {
    session := gj_init("game123", "key456")
    testing.expect_value(t, _buf_to_str(session.game_id[:]), "game123")
    testing.expect_value(t, _buf_to_str(session.private_key[:]), "key456")
    testing.expect_value(t, gj_is_logged_in(&session), false)
    testing.expect_value(t, gj_session_username(&session), "")

    // Simulate authenticated state
    _copy_to_buf(session.username[:], "GamerX")
    session.is_authed = true
    testing.expect_value(t, gj_is_logged_in(&session), true)
    testing.expect_value(t, gj_session_username(&session), "GamerX")

    gj_destroy(&session)
    testing.expect_value(t, session.game_id[0], 0)
    testing.expect_value(t, session.is_authed, false)
    testing.expect_value(t, gj_is_logged_in(&session), false)
}

@(test)
test_score_formatting :: proc(t: ^testing.T) {
    testing.expect_value(t, gj_score_format(0, context.temp_allocator), "0")
    testing.expect_value(t, gj_score_format(42, context.temp_allocator), "42")
    testing.expect_value(t, gj_score_format(999, context.temp_allocator), "999")
    testing.expect_value(t, gj_score_format(1000, context.temp_allocator), "1,000")
    testing.expect_value(t, gj_score_format(12345, context.temp_allocator), "12,345")
    testing.expect_value(t, gj_score_format(1000000, context.temp_allocator), "1,000,000")
    testing.expect_value(t, gj_score_format(123456789, context.temp_allocator), "123,456,789")
}

@(test)
test_trophy_helpers :: proc(t: ^testing.T) {
    testing.expect_value(t, gj_trophy_difficulty_label(.Bronze), "Bronze")
    testing.expect_value(t, gj_trophy_difficulty_label(.Silver), "Silver")
    testing.expect_value(t, gj_trophy_difficulty_label(.Gold), "Gold")
    testing.expect_value(t, gj_trophy_difficulty_label(.Platinum), "Platinum")

    trophies := []GJ_Trophy{
        {id = 1, achieved = true, title = "T1"},
        {id = 2, achieved = false, title = "T2"},
        {id = 3, achieved = true, title = "T3"},
        {id = 4, achieved = false, title = "T4"},
    }

    unachieved := gj_trophies_unachieved(trophies)
    testing.expect_value(t, len(unachieved), 2)
    testing.expect_value(t, unachieved[0].id, 2)
    testing.expect_value(t, unachieved[1].id, 4)
}

@(test)
test_scores_personal_best :: proc(t: ^testing.T) {
    session := gj_init("game", "key")
    _copy_to_buf(session.username[:], "PlayerOne")
    session.is_authed = true

    scores := []GJ_Score{
        {user = "OtherPlayer", sort = 10},
        {user = "PlayerOne", sort = 200},
        {user = "PlayerOne", sort = 50},  // Lowest sort = best
        {user = "PlayerOne", sort = 100},
    }

    best := gj_scores_personal_best(&session, scores)
    testing.expect(t, best != nil, "Expected personal best score")
    testing.expect_value(t, best.sort, 50)
}

@(test)
test_memory_cleanup_helpers :: proc(t: ^testing.T) {
    // Test that all delete helpers execute cleanly without leaking or crashing
    user := GJ_User{
        username   = strings.clone("hero"),
        avatar_url = strings.clone("http://example.com/pic.png"),
        status     = strings.clone("Active"),
        signed_up  = strings.clone("Yesterday"),
        last_logged_in = strings.clone("Now"),
    }
    gj_user_delete(&user)
    testing.expect_value(t, user.username, "")

    trophies := make([]GJ_Trophy, 1)
    trophies[0] = GJ_Trophy{
        title       = strings.clone("Champion"),
        description = strings.clone("Won the game"),
        image_url   = strings.clone("http://img.png"),
    }
    gj_trophies_delete(trophies)

    scores := make([]GJ_Score, 1)
    scores[0] = GJ_Score{
        score      = strings.clone("100 pts"),
        user       = strings.clone("hero"),
        guest      = strings.clone(""),
        stored     = strings.clone(""),
        extra_data = strings.clone("data"),
    }
    gj_scores_delete(scores)

    tables := make([]GJ_Score_Table, 1)
    tables[0] = GJ_Score_Table{
        name        = strings.clone("Main Table"),
        description = strings.clone("Desc"),
    }
    gj_score_tables_delete(tables)

    keys := make([]string, 2)
    keys[0] = strings.clone("k1")
    keys[1] = strings.clone("k2")
    gj_data_keys_delete(keys)
}
