#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../preview.sh"

setup() {
    TEST_DIR="$(mktemp -d)"
    echo "hello world" > "$TEST_DIR/sample.txt"
    mkdir -p "$TEST_DIR/mydir"
    touch "$TEST_DIR/mydir/a.txt"
    touch "$TEST_DIR/mydir/b.txt"
}

teardown() {
    rm -rf "$TEST_DIR"
}

@test "text file preview works" {
    run bash "$SCRIPT" "$TEST_DIR/sample.txt"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "hello world"
}

@test "directory preview works" {
    run bash "$SCRIPT" "$TEST_DIR/mydir"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "a.txt"
    echo "$output" | grep -q "b.txt"
}

@test "HOME keyword shows home directory listing" {
    run bash "$SCRIPT" HOME
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}
