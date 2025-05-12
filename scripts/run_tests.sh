#!/bin/bash
#
# Test runner script for video-face-swap
#
# Usage:
#   ./run_tests.sh [options]
#
# Options:
#   --unit         Run unit tests only
#   --integration  Run integration tests only
#   --performance  Run performance tests only
#   --all          Run all tests (default)
#   --ci           Run tests in CI mode (no interactive elements)
#   --coverage     Generate coverage report
#   --help         Show this help message

# Set default values
RUN_UNIT=0
RUN_INTEGRATION=0
RUN_PERFORMANCE=0
CI_MODE=0
COVERAGE=0

# Process command line arguments
if [ $# -eq 0 ]; then
    # Default is to run all tests
    RUN_UNIT=1
    RUN_INTEGRATION=1
    RUN_PERFORMANCE=1
else
    while [ "$1" != "" ]; do
        case $1 in
            --unit)
                RUN_UNIT=1
                ;;
            --integration)
                RUN_INTEGRATION=1
                ;;
            --performance)
                RUN_PERFORMANCE=1
                ;;
            --all)
                RUN_UNIT=1
                RUN_INTEGRATION=1
                RUN_PERFORMANCE=1
                ;;
            --ci)
                CI_MODE=1
                ;;
            --coverage)
                COVERAGE=1
                ;;
            --help)
                echo "Usage: ./run_tests.sh [options]"
                echo ""
                echo "Options:"
                echo "  --unit         Run unit tests only"
                echo "  --integration  Run integration tests only"
                echo "  --performance  Run performance tests only"
                echo "  --all          Run all tests (default)"
                echo "  --ci           Run tests in CI mode (no interactive elements)"
                echo "  --coverage     Generate coverage report"
                echo "  --help         Show this help message"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information."
                exit 1
                ;;
        esac
        shift
    done
fi

# Prepare test command
TEST_CMD="python -m pytest"

# Add test paths based on options
TEST_PATHS=""
if [ $RUN_UNIT -eq 1 ]; then
    TEST_PATHS="tests/unit"
fi

if [ $RUN_INTEGRATION -eq 1 ]; then
    if [ -n "$TEST_PATHS" ]; then
        TEST_PATHS="$TEST_PATHS tests/integration"
    else
        TEST_PATHS="tests/integration"
    fi
fi

if [ $RUN_PERFORMANCE -eq 1 ]; then
    if [ -n "$TEST_PATHS" ]; then
        TEST_PATHS="$TEST_PATHS tests/performance"
    else
        TEST_PATHS="tests/performance"
    fi
fi

# Add coverage if requested
if [ $COVERAGE -eq 1 ]; then
    TEST_CMD="$TEST_CMD --cov=api --cov-report=term --cov-report=html"
fi

# Add CI mode options
if [ $CI_MODE -eq 1 ]; then
    TEST_CMD="$TEST_CMD -xvs"
else
    TEST_CMD="$TEST_CMD -v"
fi

# Run the tests
echo "Running tests: $TEST_CMD $TEST_PATHS"
$TEST_CMD $TEST_PATHS

# Check the test result
RESULT=$?
if [ $RESULT -ne 0 ]; then
    echo "Tests failed with exit code $RESULT"
    exit $RESULT
fi

# Show coverage report path if coverage was enabled
if [ $COVERAGE -eq 1 ]; then
    echo "Coverage report available at: htmlcov/index.html"
fi

echo "All tests passed!"
exit 0
