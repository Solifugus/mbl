#!/bin/bash

# MBL Test Runner
# Runs all integration tests and reports results

echo "🧪 MBL v1.0.0 Test Suite"
echo "========================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Find MBL binary
MBL_BINARY=""
if [[ -x "./mbl" ]]; then
    MBL_BINARY="./mbl"
elif [[ -x "/opt/mbl/bin/mbl" ]]; then
    MBL_BINARY="/opt/mbl/bin/mbl"
elif command -v mbl &> /dev/null; then
    MBL_BINARY="mbl"
else
    echo -e "${RED}❌ MBL binary not found${NC}"
    exit 1
fi

echo -e "${GREEN}Using MBL binary: $MBL_BINARY${NC}"
echo ""

# Counters
TOTAL=0
PASSED=0
FAILED=0

# Function to run a test
run_test() {
    local test_file="$1"
    local test_name=$(basename "$test_file" .mbl)

    TOTAL=$((TOTAL + 1))

    if $MBL_BINARY "$test_file" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $test_name"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}✗${NC} $test_name"
        FAILED=$((FAILED + 1))
    fi
}

# Run overview test
echo -e "${BLUE}Overview Test:${NC}"
if [[ -f "tests/integration/test_overview.mbl" ]]; then
    run_test "tests/integration/test_overview.mbl"
fi
echo ""

# Run basic types tests
echo -e "${BLUE}01. Basic Types:${NC}"
for test in tests/integration/01_basic_types/*.mbl; do
    if [[ -f "$test" ]]; then
        run_test "$test"
    fi
done
echo ""

# Run data structures tests
echo -e "${BLUE}02. Data Structures:${NC}"
for test in tests/integration/02_data_structures/*.mbl; do
    if [[ -f "$test" ]]; then
        run_test "$test"
    fi
done
echo ""

# Run control flow tests
echo -e "${BLUE}03. Control Flow:${NC}"
for test in tests/integration/03_control_flow/*.mbl; do
    if [[ -f "$test" ]]; then
        run_test "$test"
    fi
done
echo ""

# Run function tests
echo -e "${BLUE}04. Functions:${NC}"
for test in tests/integration/04_functions/*.mbl; do
    if [[ -f "$test" ]]; then
        run_test "$test"
    fi
done
echo ""

# Summary
echo "========================"
echo -e "${BLUE}Test Results:${NC}"
echo -e "  Total:  $TOTAL"
echo -e "  ${GREEN}Passed: $PASSED${NC}"
if [[ $FAILED -gt 0 ]]; then
    echo -e "  ${RED}Failed: $FAILED${NC}"
else
    echo -e "  ${GREEN}Failed: $FAILED${NC}"
fi
echo ""

# Exit code
if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠️  Some tests failed${NC}"
    exit 1
fi