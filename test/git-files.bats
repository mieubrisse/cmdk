#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../git-files.sh"

setup() {
    TEST_DIR="$(mktemp -d)"
    ORIG_PWD="$PWD"
    cd "$TEST_DIR"
    git init -q
    git config user.email "test@test.com"
    git config user.name "Test"
    # Create an initial commit so HEAD exists
    touch initial.txt
    git add initial.txt
    git commit -q -m "initial"
}

teardown() {
    cd "$ORIG_PWD"
    rm -rf "$TEST_DIR"
}

@test "exits non-zero when not in a git repo" {
    NON_GIT="$(mktemp -d)"
    cd "$NON_GIT"
    run bash "$SCRIPT"
    [ "$status" -ne 0 ]
    rm -rf "$NON_GIT"
}

@test "returns modified files" {
    echo "change" >> initial.txt
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "initial.txt"
}

@test "returns staged files" {
    echo "new content" > staged.txt
    git add staged.txt
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "staged.txt"
}

@test "returns untracked files" {
    touch untracked.txt
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "untracked.txt"
}

@test "output is deduplicated" {
    echo "new" > dup.txt
    git add dup.txt
    echo "more changes" >> dup.txt
    # dup.txt is now both staged and modified
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    count=$(echo "$output" | grep -c "dup.txt")
    [ "$count" -eq 1 ]
}
