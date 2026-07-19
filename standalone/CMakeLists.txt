cmake_minimum_required(VERSION 3.16)
project(contriburg-standalone LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Widgets)

qt_standard_project_setup()

# A plain executable, not qt_add_qml_module(): Main.qml/SettingsWindow.qml
# stay loose files loaded from disk at runtime (see main.cpp), same as the
# Plasmoid itself - no QML compile step, just a small native host so
# QApplication (required by the tray icon) and the transparent-window
# QSurfaceFormat can be set up before the QML engine starts.
qt_add_executable(contriburg-standalone main.cpp)

target_link_libraries(contriburg-standalone PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Widgets
)

# Keeps Main.qml's "../contents/ui/Scene3D.qml" and
# "../contents/ui/DataFetcher.js" imports working unmodified: the deployed
# tree mirrors the repo layout (standalone/ and contents/ as siblings of the
# executable) instead of flattening everything next to it. Copies specific
# files/dirs rather than copy_directory(source dir) - the source dir here is
# also this CMakeLists.txt's own parent, and an in-tree build/ subdirectory
# would otherwise get walked into recursively.
add_custom_command(TARGET contriburg-standalone POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory
        $<TARGET_FILE_DIR:contriburg-standalone>/standalone
    COMMAND ${CMAKE_COMMAND} -E copy
        ${CMAKE_CURRENT_SOURCE_DIR}/Main.qml
        ${CMAKE_CURRENT_SOURCE_DIR}/SettingsWindow.qml
        $<TARGET_FILE_DIR:contriburg-standalone>/standalone/
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        ${CMAKE_CURRENT_SOURCE_DIR}/../contents $<TARGET_FILE_DIR:contriburg-standalone>/contents
)

install(TARGETS contriburg-standalone DESTINATION .)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/Main.qml ${CMAKE_CURRENT_SOURCE_DIR}/SettingsWindow.qml
    DESTINATION standalone)
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../contents DESTINATION .)
