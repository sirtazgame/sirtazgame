cmake_minimum_required(VERSION 3.16)
project(CleanEdit LANGUAGES CXX OBJCXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_OSX_DEPLOYMENT_TARGET "11.0")

file(GLOB SOURCES "src/*.mm")

add_executable(CleanEdit MACOSX_BUNDLE ${SOURCES})

set_target_properties(CleanEdit PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_SOURCE_DIR}/Info.plist"
    COMPILE_FLAGS "-fobjc-arc"
)

find_library(COCOA_LIB Cocoa)
find_library(JSC_LIB JavaScriptCore)
target_link_libraries(CleanEdit ${COCOA_LIB} ${JSC_LIB})

# Copy resources into the bundle
add_custom_command(TARGET CleanEdit POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${CMAKE_SOURCE_DIR}/Resources/languages"
        "$<TARGET_FILE_DIR:CleanEdit>/../Resources/languages"
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${CMAKE_SOURCE_DIR}/Resources/scripts"
        "$<TARGET_FILE_DIR:CleanEdit>/../Resources/scripts"
)
