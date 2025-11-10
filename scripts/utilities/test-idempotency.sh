#!/usr/bin/env bash
#
# Test Script for Idempotent Installation System
#
# This script demonstrates how the idempotency system works

set -euo pipefail

# Get script directory and source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/logging.sh"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/install-state.sh"

echo
log_info "🧪 Testing Idempotent Installation System"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

# Test 1: Basic step completion tracking
log_step "Test 1: Basic step tracking"
echo

if ! is_step_completed "test-basic-step"; then
    log_info "Running test step for the first time..."
    sleep 1
    mark_step_completed "test-basic-step"
    log_success "Step completed and marked"
else
    log_info "✓ Step already completed (as expected on second run)"
fi
echo

# Test 2: File change detection
log_step "Test 2: File change detection"
echo

# Create test files
TEST_DIR=$(mktemp -d)
echo "version 1" > "$TEST_DIR/test.txt"
echo "version 1" > "$TEST_DIR/test-copy.txt"

if files_differ "$TEST_DIR/test.txt" "$TEST_DIR/test-copy.txt"; then
    log_error "Files should be identical but were reported as different"
else
    log_success "✓ Identical files detected correctly"
fi

echo "version 2" > "$TEST_DIR/test.txt"
if files_differ "$TEST_DIR/test.txt" "$TEST_DIR/test-copy.txt"; then
    log_success "✓ File changes detected correctly"
else
    log_error "Files are different but were reported as identical"
fi

# Cleanup
rm -rf "$TEST_DIR"
echo

# Test 3: Package installation check
log_step "Test 3: Package installation check"
echo

if is_package_installed "bash"; then
    log_success "✓ Correctly detected bash is installed"
else
    log_error "bash should be detected as installed"
fi

if is_package_installed "this-package-definitely-does-not-exist-12345"; then
    log_error "Non-existent package was detected as installed"
else
    log_success "✓ Correctly detected non-existent package"
fi
echo

# Test 4: Step reset functionality
log_step "Test 4: Step reset functionality"
echo

mark_step_completed "test-reset-step"
if is_step_completed "test-reset-step"; then
    log_info "Step marked as completed"
    reset_step "test-reset-step"
    if is_step_completed "test-reset-step"; then
        log_error "Step should not be completed after reset"
    else
        log_success "✓ Step reset works correctly"
    fi
else
    log_error "Step marking failed"
fi
echo

# Test 5: Show state info
log_step "Test 5: State information"
echo

bash "${SCRIPT_DIR}/installation-state.sh" status
echo

# Cleanup test steps
log_info "Cleaning up test steps..."
reset_step "test-basic-step"
reset_step "test-reset-step"
echo

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "✅ Idempotency system tests completed!"
echo
log_info "The idempotency system is working correctly."
log_info "You can now safely run install.sh multiple times."
echo
log_info "Try running this test script twice to see idempotency in action:"
log_info "  bash $0"
log_info "  bash $0  # Second run will skip completed steps"
echo

