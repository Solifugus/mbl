add_library(mbl
    lexer/token.cpp
    lexer/lexer.cpp
)

target_include_directories(mbl
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}
)

# Set library properties
set_target_properties(mbl PROPERTIES
    VERSION ${PROJECT_VERSION}
    SOVERSION ${PROJECT_VERSION_MAJOR}
)

# Install rules
install(TARGETS mbl
    LIBRARY DESTINATION lib
    ARCHIVE DESTINATION lib
    RUNTIME DESTINATION bin
)

install(
    DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/
    DESTINATION include/mbl
    FILES_MATCHING PATTERN "*.hpp"
)

# Add compiler warnings
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(mbl PRIVATE -Wall -Wextra -Wpedantic)
endif() 