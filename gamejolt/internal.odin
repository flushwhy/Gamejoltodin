package gamejolt

import "base:runtime"
import "core:crypto/legacy/md5"
import "core:encoding/json"
import "core:fmt"
import "core:slice"
import "core:strconv"
import "core:strings"
import "vendor:curl"

// -----------------------------------------------------------------------
//  Constants
// -----------------------------------------------------------------------

@(private)
BASE_URL :: "https://api.gamejolt.com/api/game/v1_2"

// -----------------------------------------------------------------------
//  Signature Generation
//
//  Game Jolt API v1.2 spec:
//  1. Build the full raw (unencoded) URL with all params
//  2. Append the private key
//  3. MD5 hash the result
// -----------------------------------------------------------------------

@(private)
_gj_sign :: proc(url: string, private_key: string, allocator := context.allocator) -> string {
    to_hash := strings.concatenate({url, private_key}, context.temp_allocator)

    ctx: md5.Context
    md5.init(&ctx)
    md5.update(&ctx, transmute([]byte)to_hash)
    hash: [16]byte
    md5.final(&ctx, hash[:])

    // Convert [16]byte to lowercase hex string
    sb := strings.builder_make(allocator)
    for b in hash {
        fmt.sbprintf(&sb, "%02x", b)
    }
    return strings.to_string(sb)
}

// -----------------------------------------------------------------------
//  URL Builder
//
//  Builds the signed URL from an endpoint and param map.
//  Params are sorted alphabetically before signing (required by API spec).
//  game_id and format=json are injected automatically.
// -----------------------------------------------------------------------

@(private)
_gj_build_url :: proc(
    session:  ^GJ_Session,
    endpoint: string,
    params:   map[string]string,
    allocator := context.allocator,
) -> string {
    // Merge caller params with mandatory params
    all_params := make(map[string]string, len(params) + 2, context.temp_allocator)
    for k, v in params {
        all_params[k] = v
    }
    all_params["game_id"] = _buf_to_str(session.game_id[:])
    all_params["format"]  = "json"

    // Sort keys alphabetically — required for consistent signing
    keys := make([dynamic]string, 0, len(all_params), context.temp_allocator)
    for k in all_params {
        append(&keys, k)
    }
    slice.sort(keys[:])

    // Build raw (unencoded) param string for signing
    raw_sb := strings.builder_make(context.temp_allocator)
    for key, i in keys {
        if i > 0 do strings.write_string(&raw_sb, "&")
        strings.write_string(&raw_sb, key)
        strings.write_string(&raw_sb, "=")
        strings.write_string(&raw_sb, all_params[key])
    }
    raw_params := strings.to_string(raw_sb)
    raw_url    := strings.concatenate({BASE_URL, endpoint, "?", raw_params}, context.temp_allocator)

    // Sign the raw URL
    signature := _gj_sign(raw_url, _buf_to_str(session.private_key[:]), context.temp_allocator)

    // Build final URL with signature appended
    final_sb := strings.builder_make(allocator)
    strings.write_string(&final_sb, raw_url)
    strings.write_string(&final_sb, "&signature=")
    strings.write_string(&final_sb, signature)

    return strings.to_string(final_sb)
}

// -----------------------------------------------------------------------
//  HTTP GET via libcurl
//
//  Performs a blocking GET request and returns the response body.
//  All errors are mapped to GJ_Error values.
// -----------------------------------------------------------------------

@(private)
_Response_Buffer :: struct {
    data: [dynamic]byte,
}

@(private)
_curl_write_callback :: proc "c" (
    ptr:      rawptr,
    size:     uint,
    nmemb:    uint,
    userdata: rawptr,
) -> uint {
    context = runtime.default_context()
    buf    := (^_Response_Buffer)(userdata)
    total  := size * nmemb
    bytes  := slice.from_ptr((^byte)(ptr), int(total))
    append(&buf.data, ..bytes)
    return total
}

@(private)
_gj_http_get :: proc(
    url:       string,
    allocator := context.allocator,
) -> (body: string, err: GJ_Error) {
    handle := curl.easy_init()
    if handle == nil do return "", .Network_Failed
    defer curl.easy_cleanup(handle)

    url_cstr := strings.clone_to_cstring(url, context.temp_allocator)

    buf := _Response_Buffer{
        data = make([dynamic]byte, 0, 4096, context.temp_allocator),
    }

    curl.easy_setopt(handle, .URL,            url_cstr)
    curl.easy_setopt(handle, .WRITEFUNCTION,  _curl_write_callback)
    curl.easy_setopt(handle, .WRITEDATA,      &buf)
    curl.easy_setopt(handle, .FOLLOWLOCATION, i64(1))
    curl.easy_setopt(handle, .TIMEOUT,        i64(30))

    res := curl.easy_perform(handle)
    if res != .E_OK {
        return "", .Network_Failed
    }

    http_code: i64
    curl.easy_getinfo(handle, .RESPONSE_CODE, &http_code)
    if http_code < 200 || http_code >= 300 {
        return "", .Network_Failed
    }

    return strings.clone(string(buf.data[:]), allocator), .None
}

// -----------------------------------------------------------------------
//  JSON Response Parser
//
//  Game Jolt wraps all responses in:
//  { "response": { "success": "true", ... } }
//
//  Returns the inner response object or an error.
// -----------------------------------------------------------------------

@(private)
_gj_parse_response :: proc(
    body:      string,
    allocator := context.allocator,
) -> (inner: json.Object, err: GJ_Error) {
    root, json_err := json.parse(transmute([]byte)body, allocator = allocator)
    if json_err != nil do return nil, .Invalid_Response

    root_obj, ok := root.(json.Object)
    if !ok do return nil, .Invalid_Response

    response_val, has_response := root_obj["response"]
    if !has_response do return nil, .Invalid_Response

    response_obj, ok2 := response_val.(json.Object)
    if !ok2 do return nil, .Invalid_Response

    // Check success flag — GJ returns it as a string "true"/"false"
    success_val, has_success := response_obj["success"]
    if !has_success do return nil, .Invalid_Response

    success_str, ok3 := success_val.(json.String)
    if !ok3 || success_str != "true" {
        return nil, .Auth_Failed
    }

    return response_obj, .None
}

// -----------------------------------------------------------------------
//  Main Internal Request Proc
//
//  Combines URL building, HTTP GET, and JSON parsing into one call.
//  This is the only thing individual API procs need to call internally.
// -----------------------------------------------------------------------

@(private)
_gj_request :: proc(
    session:   ^GJ_Session,
    endpoint:  string,
    params:    map[string]string,
    allocator := context.allocator,
) -> (response: json.Object, err: GJ_Error) {
    if session.game_id[0] == 0 || session.private_key[0] == 0 {
        return nil, .Missing_Config
    }

    url  := _gj_build_url(session, endpoint, params, context.temp_allocator)
    body, http_err := _gj_http_get(url, context.temp_allocator)
    if http_err != .None do return nil, http_err

    return _gj_parse_response(body, allocator)
}

// -----------------------------------------------------------------------
//  Small JSON helpers
// -----------------------------------------------------------------------

@(private)
_json_string :: proc(obj: json.Object, key: string) -> string {
    val, ok := obj[key]
    if !ok do return ""
    str, ok2 := val.(json.String)
    if !ok2 do return ""
    return string(str)
}

@(private)
_json_int :: proc(obj: json.Object, key: string) -> int {
    val, ok := obj[key]
    if !ok do return 0
    switch v in val {
    case json.Integer: return int(v)
    case json.Float:   return int(v)
    case json.String:
        // GJ sometimes returns numbers as strings
        n, _ := strconv.parse_int(string(v))
        return n
    case json.Null, bool, json.Array, json.Object:
        return 0
    }
    return 0
}

@(private)
_json_bool_str :: proc(obj: json.Object, key: string) -> bool {
    val, ok := obj[key]
    if !ok do return false
    str, ok2 := val.(json.String)
    if !ok2 do return false
    return string(str) == "true"
}

@(private)
_buf_to_str :: proc(buf: []u8) -> string {
    for b, i in buf {
        if b == 0 {
            return string(buf[:i])
        }
    }
    return string(buf)
}
