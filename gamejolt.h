/**
 * gamejolt.h
 * C ABI header for the GameJolt Odin library.
 * Include this in your engine integration (Godot, Raylib, Love2D, etc.)
 *
 * Error codes (i32) returned by all functions:
 *   0  = success
 *   1  = network_failed
 *   2  = auth_failed
 *   3  = invalid_response
 *   4  = bad_credentials
 *   5  = request_in_flight  (retry later)
 *   6  = not_authenticated  (call gj_login_c first)
 *   7  = missing_config     (game_id or private_key empty / truncated)
 *   8  = rate_limited
 *
 * Array-returning functions use a caller-provided buffer pattern:
 *   - Pass out_buf=NULL / capacity=0 to query the total count only.
 *   - Pass a buffer + capacity to fill up to `capacity` entries.
 *   - out_count always receives the TOTAL number available (not capped).
 *
 * Runtime dependency: libcurl.dll must be on PATH or next to gamejolt.dll.
 */

#pragma once

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* -----------------------------------------------------------------------
   Structs
   ----------------------------------------------------------------------- */

typedef struct {
    char  game_id[64];
    char  private_key[64];
    char  username[64];
    char  token[64];
    bool  is_authed;
    /* --- internal in-flight flags: DO NOT read or write these --- */
    bool  _login_in_flight;
    bool  _session_open_in_flight;
    bool  _trophies_in_flight;
    bool  _scores_in_flight;
    bool  _scores_submit_in_flight;
    bool  _data_in_flight;
    bool  _user_data_in_flight;
} GJ_Session;

typedef struct {
    int32_t id;
    char    username[64];
    char    avatar_url[256];
    char    status[32];
} GJ_User_C;

typedef struct {
    int32_t id;
    int32_t difficulty;   /* 0=Bronze 1=Silver 2=Gold 3=Platinum */
    bool    achieved;
    char    title[128];
    char    description[256];
    char    image_url[256];
} GJ_Trophy_C;

typedef struct {
    int32_t sort;
    char    score[128];
    char    user[64];
    char    guest[64];
    char    extra_data[256];
} GJ_Score_C;

typedef struct {
    int32_t id;
    bool    primary;
    char    name[128];
    char    description[256];
} GJ_Score_Table_C;

typedef struct {
    char key[256];
} GJ_DataKey_C;

/* -----------------------------------------------------------------------
   Session lifecycle
   ----------------------------------------------------------------------- */

GJ_Session gj_init_c(const char* game_id, const char* private_key);
void       gj_destroy_c(GJ_Session* session);

/* -----------------------------------------------------------------------
   Auth
   ----------------------------------------------------------------------- */

/* Returns 0 on success. out_user may be NULL if you don't need user info. */
int32_t gj_login_c(
    GJ_Session* session,
    const char* username,
    const char* token,
    GJ_User_C*  out_user   /* may be NULL */
);

/* -----------------------------------------------------------------------
   Sessions
   ----------------------------------------------------------------------- */

int32_t gj_session_open_c(GJ_Session* session);
int32_t gj_session_close_c(GJ_Session* session);
int32_t gj_session_ping_c(GJ_Session* session, bool active);

/* -----------------------------------------------------------------------
   Trophies
   ----------------------------------------------------------------------- */

/* Fetch trophies into a caller-provided buffer.
   achieved_only = true  → only trophies already earned.
   out_count receives the total available count regardless of capacity. */
int32_t gj_trophies_fetch_c(
    GJ_Session*  session,
    bool         achieved_only,
    GJ_Trophy_C* out_buf,    /* may be NULL to query count only */
    int32_t      capacity,
    int32_t*     out_count   /* may be NULL */
);

/* Unlock (achieve) a trophy for the authenticated user. */
int32_t gj_trophy_unlock_c(GJ_Session* session, int32_t trophy_id);

/* -----------------------------------------------------------------------
   Scores
   ----------------------------------------------------------------------- */

/* Fetch scores into a caller-provided buffer.
   table_id = 0 → primary table. limit = 0 → server default (10).
   user_only requires the user to be authenticated. */
int32_t gj_scores_fetch_c(
    GJ_Session* session,
    int32_t     table_id,
    int32_t     limit,
    bool        user_only,
    GJ_Score_C* out_buf,    /* may be NULL to query count only */
    int32_t     capacity,
    int32_t*    out_count   /* may be NULL */
);

/* Fetch score tables into a caller-provided buffer. */
int32_t gj_scores_tables_c(
    GJ_Session*       session,
    GJ_Score_Table_C* out_buf,    /* may be NULL to query count only */
    int32_t           capacity,
    int32_t*          out_count   /* may be NULL */
);

int32_t gj_scores_submit_c(
    GJ_Session* session,
    const char* score_str,
    int32_t     sort,
    int32_t     table_id,   /* 0 = primary table */
    const char* extra       /* may be NULL or "" */
);

int32_t gj_scores_submit_guest_c(
    GJ_Session* session,
    const char* guest_name,
    const char* score_str,
    int32_t     sort,
    int32_t     table_id
);

/* out_rank receives the 1-based rank on success. */
int32_t gj_scores_rank_c(
    GJ_Session* session,
    int32_t     sort,
    int32_t     table_id,
    int32_t*    out_rank
);

/* -----------------------------------------------------------------------
   Data Store
   ----------------------------------------------------------------------- */

/* user=false → global store, user=true → user-scoped store */
int32_t gj_data_set_c(GJ_Session* session, const char* key, const char* data, bool user);
int32_t gj_data_remove_c(GJ_Session* session, const char* key, bool user);

/* Read a value; out_buf receives a null-terminated string up to `capacity` bytes. */
int32_t gj_data_get_c(
    GJ_Session* session,
    const char* key,
    bool        user,
    char*       out_buf,
    int32_t     capacity
);

/* List keys; fills up to `capacity` GJ_DataKey_C entries. */
int32_t gj_data_keys_c(
    GJ_Session*   session,
    bool          user,
    GJ_DataKey_C* out_buf,    /* may be NULL to query count only */
    int32_t       capacity,
    int32_t*      out_count   /* may be NULL */
);

/* -----------------------------------------------------------------------
   Utilities
   ----------------------------------------------------------------------- */

/* Check if the session is currently authenticated. */
bool gj_is_logged_in_c(const GJ_Session* session);

/* Read cached username from session. */
int32_t gj_session_username_c(const GJ_Session* session, char* out_buf, int32_t capacity);

/* Re-fetch current user profile info without logging in again. */
int32_t gj_get_current_user_c(GJ_Session* session, GJ_User_C* out_user);

/* Fetch avatar URL of currently logged-in user. */
int32_t gj_get_user_avatar_url_c(GJ_Session* session, char* out_buf, int32_t capacity);

/* Fetch user picture: checks user data-store "user_picture", falls back to avatar URL. */
int32_t gj_data_get_user_picture_c(GJ_Session* session, char* out_buf, int32_t capacity);

/* Save custom user picture data/URL to user data-store "user_picture". */
int32_t gj_data_set_user_picture_c(GJ_Session* session, const char* picture_data);

/* Read an integer value from the data store. */
int32_t gj_data_get_int_c(
    GJ_Session* session,
    const char* key,
    int32_t     default_val,
    bool        user,
    int32_t*    out_val
);

/* Write an integer value to the data store. */
int32_t gj_data_set_int_c(
    GJ_Session* session,
    const char* key,
    int32_t     value,
    bool        user
);

/* Atomically increment an integer in the data store. */
int32_t gj_data_increment_c(
    GJ_Session* session,
    const char* key,
    int32_t     delta,
    bool        user,
    int32_t*    out_val
);

/* Check if a specific trophy is already unlocked by the user. */
int32_t gj_has_trophy_c(GJ_Session* session, int32_t trophy_id, bool* out_achieved);

/* Format a score sort integer with commas (e.g. 1000000 -> "1,000,000"). */
int32_t gj_score_format_c(int32_t sort, char* out_buf, int32_t capacity);

#ifdef __cplusplus
}
#endif