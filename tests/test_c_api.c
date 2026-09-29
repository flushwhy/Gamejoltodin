#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <stdbool.h>
#include "../gamejolt.h"

static int g_tests_run = 0;
static int g_tests_passed = 0;

#define TEST(name) \
    do { \
        printf("  [RUN] %s...", name); \
        g_tests_run++;

#define PASS() \
        printf(" PASS\n"); \
        g_tests_passed++; \
    } while (0)

void test_struct_sizes(void) {
    TEST("Struct sizes and field layout");

    // Check sizes of C ABI flat structs
    assert(sizeof(GJ_Session) == 64 + 64 + 64 + 64 + 1 + 7);
    assert(sizeof(GJ_User_C) == 4 + 64 + 256 + 32);
    assert(sizeof(GJ_Trophy_C) == 4 + 4 + 1 + 3 + 128 + 256 + 256); // 1 byte bool + 3 byte padding before char[]
    assert(sizeof(GJ_Score_C) == 4 + 128 + 64 + 64 + 256);
    assert(sizeof(GJ_Score_Table_C) == 4 + 1 + 3 + 128 + 256);
    assert(sizeof(GJ_DataKey_C) == 256);

    PASS();
}

void test_session_lifecycle(void) {
    TEST("Session init and destroy");

    const char* game_id = "123456";
    const char* priv_key = "abcdef0123456789";

    GJ_Session session = gj_init_c(game_id, priv_key);

    assert(strcmp(session.game_id, game_id) == 0);
    assert(strcmp(session.private_key, priv_key) == 0);
    assert(session.is_authed == false);
    assert(gj_is_logged_in_c(&session) == false);

    // Destroy
    gj_destroy_c(&session);
    assert(session.game_id[0] == '\0');
    assert(session.private_key[0] == '\0');
    assert(session.is_authed == false);
    assert(gj_is_logged_in_c(&session) == false);

    PASS();
}

void test_unauthenticated_guards(void) {
    TEST("Unauthenticated guards return code 6");

    GJ_Session session = gj_init_c("game", "key");

    // All user-scoped operations must reject with error code 6 (Not_Authenticated)
    assert(gj_session_open_c(&session) == 6);
    assert(gj_session_close_c(&session) == 6);
    assert(gj_session_ping_c(&session, true) == 6);

    char buf[128];
    assert(gj_session_username_c(&session, buf, sizeof(buf)) == 6);
    assert(gj_get_current_user_c(&session, NULL) == 6);
    assert(gj_get_user_avatar_url_c(&session, buf, sizeof(buf)) == 6);
    assert(gj_data_get_user_picture_c(&session, buf, sizeof(buf)) == 6);
    assert(gj_data_set_user_picture_c(&session, "pic_url") == 6);

    bool achieved = false;
    assert(gj_has_trophy_c(&session, 42, &achieved) == 6);
    assert(gj_trophy_unlock_c(&session, 42) == 6);
    assert(gj_trophies_fetch_c(&session, false, NULL, 0, NULL) == 6);

    assert(gj_scores_submit_c(&session, "100", 100, 0, "") == 6);

    // User-scoped data store operations
    assert(gj_data_set_c(&session, "key", "val", true) == 6);
    assert(gj_data_remove_c(&session, "key", true) == 6);
    assert(gj_data_get_c(&session, "key", true, buf, sizeof(buf)) == 6);
    int32_t out_count = 0;
    assert(gj_data_keys_c(&session, true, NULL, 0, &out_count) == 6);

    gj_destroy_c(&session);
    PASS();
}

void test_score_formatting(void) {
    TEST("gj_score_format_c utility");

    char buf[64];

    // Zero
    assert(gj_score_format_c(0, buf, sizeof(buf)) == 0);
    assert(strcmp(buf, "0") == 0);

    // Small numbers
    assert(gj_score_format_c(42, buf, sizeof(buf)) == 0);
    assert(strcmp(buf, "42") == 0);

    assert(gj_score_format_c(999, buf, sizeof(buf)) == 0);
    assert(strcmp(buf, "999") == 0);

    // Thousands
    assert(gj_score_format_c(1000, buf, sizeof(buf)) == 0);
    assert(strcmp(buf, "1,000") == 0);

    assert(gj_score_format_c(12345, buf, sizeof(buf)) == 0);
    assert(strcmp(buf, "12,345") == 0);

    // Millions
    assert(gj_score_format_c(1000000, buf, sizeof(buf)) == 0);
    assert(strcmp(buf, "1,000,000") == 0);

    assert(gj_score_format_c(987654321, buf, sizeof(buf)) == 0);
    assert(strcmp(buf, "987,654,321") == 0);

    // Buffer capacity safety (truncation with null termination)
    char tiny[4];
    assert(gj_score_format_c(12345, tiny, sizeof(tiny)) == 0);
    assert(tiny[3] == '\0');

    PASS();
}

int main(void) {
    printf("=== Running GameJolt C ABI Integration Tests ===\n");

    test_struct_sizes();
    test_session_lifecycle();
    test_unauthenticated_guards();
    test_score_formatting();

    printf("\nResults: %d/%d tests passed successfully!\n", g_tests_passed, g_tests_run);
    return (g_tests_passed == g_tests_run) ? 0 : 1;
}
