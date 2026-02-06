#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../actions/toggle-state.sh"

setup() {
    export STATE_FILE="/tmp/cmdk_env_toggle_bats_test_$$"
    rm -f "$STATE_FILE"
}

teardown() {
    rm -f "$STATE_FILE"
}

@test "init on sets state to on" {
    run bash "$SCRIPT" init on
    [ "$status" -eq 0 ]
    [ "$output" = "on" ]
}

@test "init off sets state to off" {
    run bash "$SCRIPT" init off
    [ "$status" -eq 0 ]
    [ "$output" = "off" ]
}

@test "toggle flips state from off to on" {
    bash "$SCRIPT" init off
    run bash "$SCRIPT" toggle
    [ "$status" -eq 0 ]
    [ "$output" = "on" ]
}

@test "toggle flips state from on to off" {
    bash "$SCRIPT" init on
    run bash "$SCRIPT" toggle
    [ "$status" -eq 0 ]
    [ "$output" = "off" ]
}

@test "get returns current state" {
    bash "$SCRIPT" init on
    run bash "$SCRIPT" get
    [ "$status" -eq 0 ]
    [ "$output" = "on" ]
}

@test "cleanup removes state file" {
    bash "$SCRIPT" init on
    run bash "$SCRIPT" cleanup
    [ "$status" -eq 0 ]
    [ ! -f "$STATE_FILE" ]
}

@test "invalid command exits with error" {
    run bash "$SCRIPT" nonsense
    [ "$status" -eq 1 ]
}
