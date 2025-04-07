include(FetchContent)
FetchContent_Declare(
    googletest
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG v1.14.0
)
FetchContent_MakeAvailable(googletest)

enable_testing()

add_executable(lexer_test
    lexer/lexer_test.cpp
)

target_link_libraries(lexer_test
    PRIVATE
        mbl
        GTest::GTest
        GTest::Main
)

add_test(
    NAME lexer_test
    COMMAND lexer_test
)

# Set test properties
set_tests_properties(lexer_test PROPERTIES
    TIMEOUT 30  # Maximum test duration in seconds
    WILL_FAIL FALSE
) 