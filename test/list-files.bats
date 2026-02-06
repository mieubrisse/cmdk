#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../list-files.sh"

setup() {
    TEST_DIR="$(mktemp -d)"
    mkdir -p "$TEST_DIR/subdir/nested"
    touch "$TEST_DIR/file1.txt"
    touch "$TEST_DIR/subdir/file2.txt"
    touch "$TEST_DIR/subdir/nested/file3.txt"
    ORIG_PWD="$PWD"
    cd "$TEST_DIR"
}

teardown() {
    cd "$ORIG_PWD"
    rm -rf "$TEST_DIR"
}

@test "exits 0 in a normal directory" {
    run bash "$SCRIPT" -o
    [ "$status" -eq 0 ]
}

@test "-o flag limits depth to 1 level" {
    run bash "$SCRIPT" -o
    [ "$status" -eq 0 ]
    # Should contain top-level file and subdir
    echo "$output" | grep -q "file1.txt"
    echo "$output" | grep -q "subdir"
    # Should NOT contain nested files
    ! echo "$output" | grep -q "file3.txt"
}

@test "-s flag recurses into subdirectories" {
    run bash "$SCRIPT" -s
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "file1.txt"
    echo "$output" | grep -q "file2.txt"
    echo "$output" | grep -q "file3.txt"
}

@test "handles files with spaces in names" {
    touch "$TEST_DIR/file with spaces.txt"
    run bash "$SCRIPT" -o
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "file with spaces.txt"
}

@test "handles files with special characters in names" {
    touch "$TEST_DIR/file[1].txt"
    touch "$TEST_DIR/file(2).txt"
    run bash "$SCRIPT" -o
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'file\[1\].txt'
    echo "$output" | grep -q 'file(2).txt'
}

@test "common exclude dirs are excluded from output" {
    mkdir -p "$TEST_DIR/node_modules/pkg"
    touch "$TEST_DIR/node_modules/pkg/index.js"
    mkdir -p "$TEST_DIR/.git/objects"
    touch "$TEST_DIR/.git/objects/abc"

    run bash "$SCRIPT" -s
    [ "$status" -eq 0 ]
    # The fd output should not include files inside node_modules or .git
    ! echo "$output" | grep -q "node_modules/pkg/index.js"
    ! echo "$output" | grep -q ".git/objects/abc"
    # But the directory names themselves get added back
    echo "$output" | grep -q "node_modules"
    echo "$output" | grep -q ".git"
}
