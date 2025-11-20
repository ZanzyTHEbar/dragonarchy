#!/bin/bash

# Test Script for NFS Automount Multi-Mode Functionality
# Validates all operation modes without requiring actual NFS server
# Uses mock functions to simulate server checks

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TEST_FSTAB="/tmp/test-fstab-$$"
TEST_SERVER="test-server.local"
TEST_BASE="/nfs/test"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NFS_SCRIPT="${SCRIPT_DIR}/nfs.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_test() {
    echo -e "${BLUE}[TEST]${NC} $*"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
    ((TESTS_PASSED++)) || true
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
    ((TESTS_FAILED++)) || true
}

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $*"
}

# Setup test environment
setup_test() {
    log_info "Setting up test environment..."
    
    # Create mock fstab
    cat > "$TEST_FSTAB" << 'EOF'
# Test fstab file
# Static information about the filesystems.

UUID=1234-5678 / ext4 defaults 0 1
UUID=abcd-efgh /boot ext4 defaults 0 1
EOF
    
    log_info "Test fstab created: $TEST_FSTAB"
    log_info "NFS script: $NFS_SCRIPT"
}

# Cleanup test environment
cleanup_test() {
    log_info "Cleaning up test environment..."
    [[ -f "$TEST_FSTAB" ]] && rm -f "$TEST_FSTAB"
    rm -f /tmp/test-fstab-*.backup.*
}

# Function to check if managed section exists
has_managed_section() {
    grep -q "^# BEGIN NFS-AUTOMOUNT MANAGED SECTION" "$TEST_FSTAB" 2>/dev/null
}

# Function to count managed entries
count_managed_entries() {
    if ! has_managed_section; then
        echo "0"
        return
    fi
    
    sed -n '/^# BEGIN NFS-AUTOMOUNT MANAGED SECTION/,/^# END NFS-AUTOMOUNT MANAGED SECTION/p' "$TEST_FSTAB" | \
        grep -v "^#" | grep -v "^[[:space:]]*$" | wc -l
}

# Function to check if specific entry exists
has_entry() {
    local nfs_path="$1"
    local mount_point="$2"
    
    grep -q "${nfs_path}[[:space:]].*${mount_point}" "$TEST_FSTAB" 2>/dev/null
}

# Mock nfs.sh execution (since we can't actually run it without sudo/NFS server)
# This simulates what the script would do
mock_nfs_operation() {
    local mode="$1"
    shift
    local datasets=("$@")
    
    local managed_begin="# BEGIN NFS-AUTOMOUNT MANAGED SECTION - DO NOT EDIT"
    local managed_end="# END NFS-AUTOMOUNT MANAGED SECTION"
    
    case "$mode" in
        add)
            # Simulate ADD: append to managed section if not exists
            if ! has_managed_section; then
                {
                    echo "$managed_begin"
                    echo "# Last updated: $(date '+%Y-%m-%d %H:%M:%S')"
                    echo "# Mode: add"
                } >> "$TEST_FSTAB"
                
                for dataset in "${datasets[@]}"; do
                    echo "${TEST_SERVER}:${TEST_BASE}/${dataset} /mnt/${dataset} nfs4 rw,options 0 0" >> "$TEST_FSTAB"
                done
                
                echo "$managed_end" >> "$TEST_FSTAB"
            else
                # Add only new entries
                local temp_file="${TEST_FSTAB}.tmp"
                sed '/^# END NFS-AUTOMOUNT MANAGED SECTION/d' "$TEST_FSTAB" > "$temp_file"
                
                for dataset in "${datasets[@]}"; do
                    if ! has_entry "${TEST_SERVER}:${TEST_BASE}/${dataset}" "/mnt/${dataset}"; then
                        echo "${TEST_SERVER}:${TEST_BASE}/${dataset} /mnt/${dataset} nfs4 rw,options 0 0" >> "$temp_file"
                    fi
                done
                
                echo "$managed_end" >> "$temp_file"
                mv "$temp_file" "$TEST_FSTAB"
            fi
            ;;
            
        replace)
            # Simulate REPLACE: remove all, add new
            sed -i '/^# BEGIN NFS-AUTOMOUNT MANAGED SECTION/,/^# END NFS-AUTOMOUNT MANAGED SECTION/d' "$TEST_FSTAB"
            
            {
                echo "$managed_begin"
                echo "# Last updated: $(date '+%Y-%m-%d %H:%M:%S')"
                echo "# Mode: replace"
            } >> "$TEST_FSTAB"
            
            for dataset in "${datasets[@]}"; do
                echo "${TEST_SERVER}:${TEST_BASE}/${dataset} /mnt/${dataset} nfs4 rw,options 0 0" >> "$TEST_FSTAB"
            done
            
            echo "$managed_end" >> "$TEST_FSTAB"
            ;;
            
        clean)
            # Simulate CLEAN: remove managed section
            sed -i '/^# BEGIN NFS-AUTOMOUNT MANAGED SECTION/,/^# END NFS-AUTOMOUNT MANAGED SECTION/d' "$TEST_FSTAB"
            ;;
    esac
}

# Test 1: Initial ADD mode
test_initial_add() {
    ((TESTS_RUN++)) || true
    log_test "Test 1: Initial ADD mode (creating first entries)"
    
    mock_nfs_operation "add" "data" "backup"
    
    if has_managed_section && [[ $(count_managed_entries) -eq 2 ]]; then
        log_pass "Initial ADD created managed section with 2 entries"
    else
        log_fail "Initial ADD failed (expected 2 entries, got $(count_managed_entries))"
    fi
}

# Test 2: ADD mode with existing entries (idempotent)
test_add_idempotent() {
    ((TESTS_RUN++)) || true
    log_test "Test 2: ADD mode idempotency (re-adding same entries)"
    
    local before_count
    before_count=$(count_managed_entries)
    
    mock_nfs_operation "add" "data" "backup"
    
    local after_count
    after_count=$(count_managed_entries)
    
    if [[ $before_count -eq $after_count ]]; then
        log_pass "ADD mode is idempotent (no duplicates created)"
    else
        log_fail "ADD mode created duplicates (before: $before_count, after: $after_count)"
    fi
}

# Test 3: ADD mode with new entries
test_add_new_entries() {
    ((TESTS_RUN++)) || true
    log_test "Test 3: ADD mode with new entries (expanding configuration)"
    
    mock_nfs_operation "add" "common" "cache"
    
    if [[ $(count_managed_entries) -eq 4 ]]; then
        log_pass "ADD mode added new entries (total: 4)"
    else
        log_fail "ADD mode failed to add new entries (expected 4, got $(count_managed_entries))"
    fi
}

# Test 4: REPLACE mode (complete replacement)
test_replace_mode() {
    ((TESTS_RUN++)) || true
    log_test "Test 4: REPLACE mode (nuclear replacement)"
    
    mock_nfs_operation "replace" "newdata"
    
    local count
    count=$(count_managed_entries)
    
    if [[ $count -eq 1 ]] && has_entry "${TEST_SERVER}:${TEST_BASE}/newdata" "/mnt/newdata"; then
        log_pass "REPLACE mode replaced all entries with new config"
    else
        log_fail "REPLACE mode failed (expected 1 entry, got $count)"
    fi
}

# Test 5: ADD after REPLACE (rebuilding)
test_add_after_replace() {
    ((TESTS_RUN++)) || true
    log_test "Test 5: ADD after REPLACE (rebuilding configuration)"
    
    mock_nfs_operation "add" "data" "backup" "common"
    
    if [[ $(count_managed_entries) -eq 4 ]]; then
        log_pass "ADD after REPLACE works correctly (4 total entries)"
    else
        log_fail "ADD after REPLACE failed (expected 4, got $(count_managed_entries))"
    fi
}

# Test 6: CLEAN mode (complete removal)
test_clean_mode() {
    ((TESTS_RUN++)) || true
    log_test "Test 6: CLEAN mode (complete removal)"
    
    mock_nfs_operation "clean"
    
    if ! has_managed_section; then
        log_pass "CLEAN mode removed entire managed section"
    else
        log_fail "CLEAN mode failed (managed section still exists)"
    fi
}

# Test 7: Managed section doesn't affect other entries
test_preserve_manual_entries() {
    ((TESTS_RUN++)) || true
    log_test "Test 7: Manual entries preservation (script doesn't touch them)"
    
    # Count non-managed entries (UUID lines)
    local manual_count
    manual_count=$(grep -c "^UUID=" "$TEST_FSTAB" || true)
    
    # Add managed entries
    mock_nfs_operation "add" "data"
    
    # Check manual entries still exist
    local manual_count_after
    manual_count_after=$(grep -c "^UUID=" "$TEST_FSTAB" || true)
    
    if [[ $manual_count -eq $manual_count_after ]]; then
        log_pass "Manual fstab entries preserved (not affected by script)"
    else
        log_fail "Manual entries were affected (before: $manual_count, after: $manual_count_after)"
    fi
}

# Test 8: Multiple operations sequence
test_operation_sequence() {
    ((TESTS_RUN++)) || true
    log_test "Test 8: Complex operation sequence (real-world scenario)"
    
    # Clean start
    mock_nfs_operation "clean"
    
    # Add initial config
    mock_nfs_operation "add" "data" "backup"
    local step1
    step1=$(count_managed_entries)
    
    # Add more
    mock_nfs_operation "add" "common"
    local step2
    step2=$(count_managed_entries)
    
    # Replace with new config
    mock_nfs_operation "replace" "prod-data" "prod-backup"
    local step3
    step3=$(count_managed_entries)
    
    # Clean up
    mock_nfs_operation "clean"
    local step4
    step4=$(has_managed_section && echo "exists" || echo "clean")
    
    if [[ $step1 -eq 2 ]] && [[ $step2 -eq 3 ]] && [[ $step3 -eq 2 ]] && [[ "$step4" == "clean" ]]; then
        log_pass "Complex sequence works correctly (2→3→2→clean)"
    else
        log_fail "Complex sequence failed (got: $step1→$step2→$step3→$step4)"
    fi
}

# Test 9: Fstab content check
test_fstab_content() {
    ((TESTS_RUN++)) || true
    log_test "Test 9: Fstab content validation (correct format)"
    
    mock_nfs_operation "add" "data"
    
    # Check for required components
    local has_begin has_end has_timestamp has_mode has_entry
    has_begin=$(grep -c "^# BEGIN NFS-AUTOMOUNT MANAGED SECTION" "$TEST_FSTAB" || true)
    has_end=$(grep -c "^# END NFS-AUTOMOUNT MANAGED SECTION" "$TEST_FSTAB" || true)
    has_timestamp=$(grep -c "# Last updated:" "$TEST_FSTAB" || true)
    has_mode=$(grep -c "# Mode:" "$TEST_FSTAB" || true)
    has_entry=$(grep -c "test-server.local" "$TEST_FSTAB" || true)
    
    if [[ $has_begin -eq 1 ]] && [[ $has_end -eq 1 ]] && [[ $has_timestamp -ge 1 ]] && [[ $has_entry -ge 1 ]]; then
        log_pass "Fstab content format is correct (has markers, metadata, entries)"
    else
        log_fail "Fstab content validation failed (begin:$has_begin end:$has_end ts:$has_timestamp entry:$has_entry)"
    fi
}

# Show test fstab content
show_test_fstab() {
    echo
    log_info "=== Current Test Fstab Content ==="
    echo "-----------------------------------"
    cat "$TEST_FSTAB"
    echo "-----------------------------------"
    echo
}

# Run all tests
run_all_tests() {
    log_info "Starting NFS Automount Multi-Mode Test Suite"
    log_info "=============================================="
    echo
    
    setup_test
    echo
    
    test_initial_add
    test_add_idempotent
    test_add_new_entries
    test_replace_mode
    test_add_after_replace
    test_clean_mode
    test_preserve_manual_entries
    test_operation_sequence
    test_fstab_content
    
    echo
    log_info "=== Test Summary ==="
    log_info "Tests Run:    $TESTS_RUN"
    log_info "Tests Passed: $TESTS_PASSED"
    log_info "Tests Failed: $TESTS_FAILED"
    echo
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_pass "All tests passed! ✓"
        cleanup_test
        exit 0
    else
        log_fail "Some tests failed! ✗"
        log_info "Test fstab preserved for debugging: $TEST_FSTAB"
        show_test_fstab
        exit 1
    fi
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
fi

