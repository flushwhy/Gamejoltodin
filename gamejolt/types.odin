package gamejolt

// -----------------------------------------------------------------------
//  Errors
// -----------------------------------------------------------------------

GJ_Error :: enum {
    None,
    Network_Failed,       // HTTP transport failed
    Auth_Failed,          // API returned success: false
    Invalid_Response,     // Could not parse JSON
    Bad_Credentials,      // Wrong game ID, key, username, or token
    Request_In_Flight,    // Same request already pending (caller should retry)
    Not_Authenticated,    // gj_login has not been called yet
    Missing_Config,       // game_id or private_key is empty
    Rate_Limited,         // Too many requests
    Unknown,
}

// -----------------------------------------------------------------------
//  Session — caller owned, no global state
// -----------------------------------------------------------------------

GJ_Session :: struct {
    // Config — set at init, never changed
    game_id:     [64]u8,
    private_key: [64]u8,

    // Auth state — set after gj_login
    username:    [64]u8,
    token:       [64]u8,
    is_authed:   b8,

    // Internal in-flight guards — one per endpoint group
    // Prevents duplicate requests from rapid calls
    _login_in_flight:        b8,
    _session_open_in_flight: b8,
    _trophies_in_flight:     b8,
    _scores_in_flight:       b8,
    _scores_submit_in_flight: b8,
    _data_in_flight:         b8,
    _user_data_in_flight:    b8,
}

// -----------------------------------------------------------------------
//  User
// -----------------------------------------------------------------------

GJ_User :: struct {
    id:                    int,
    username:              string,
    avatar_url:            string,
    status:                string,
    signed_up:             string,
    signed_up_timestamp:   int,
    last_logged_in:        string,
    last_logged_timestamp: int,
}

// -----------------------------------------------------------------------
//  Trophies
// -----------------------------------------------------------------------

GJ_Trophy_Difficulty :: enum {
    Bronze,
    Silver,
    Gold,
    Platinum,
}

GJ_Trophy :: struct {
    id:          int,
    title:       string,
    description: string,
    difficulty:  GJ_Trophy_Difficulty,
    image_url:   string,
    achieved:    bool,
}

// -----------------------------------------------------------------------
//  Scores
// -----------------------------------------------------------------------

GJ_Score :: struct {
    score:      string,
    sort:       int,
    user:       string,
    guest:      string,
    stored:     string,
    extra_data: string,
    user_id:    int,
}

GJ_Score_Table :: struct {
    id:          int,
    name:        string,
    description: string,
    primary:     bool,
}

// -----------------------------------------------------------------------
//  Data Store
// -----------------------------------------------------------------------

GJ_Data_Key :: struct {
    key: string,
}
