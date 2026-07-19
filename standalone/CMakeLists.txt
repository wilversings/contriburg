# VERSION must be kept in sync with metadata.json's KPlugin.Version - it
# feeds CPACK_PACKAGE_VERSION below, so the NSIS installer's file
# name/"Add or Remove Programs" entry matches the Plasmoid's own version.
cmake_minimum_required(VERSION 3.16)
project(contriburg-standalone VERSION 1.0.0 LANGUAGES CXX)

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

# --- Windows installer (CPack + NSIS) -------------------------------------
# Bundles the Qt runtime via windeployqt, then packages the install tree
# (see standalone/README.md's "Packaging for Windows" section, which this
# automates) into a single Contriburg-Setup.exe. Linux/macOS builds skip
# this block entirely - there's no NSIS generator for them, and the repo's
# only supported non-Windows path to run the standalone build is `qml -a
# widget standalone/Main.qml` (see README) or a manual `cmake --install`.
if(WIN32)
    get_filename_component(QT6_ROOT_DIR "${Qt6_DIR}/../../.." ABSOLUTE)
    find_program(WINDEPLOYQT_EXECUTABLE NAMES windeployqt HINTS "${QT6_ROOT_DIR}/bin")
    if(WINDEPLOYQT_EXECUTABLE)
        # CMAKE_INSTALL_PREFIX must stay escaped (\${...}) so it's resolved
        # by the generated cmake_install.cmake at install/package time, not
        # baked in here at configure time - CPack overrides it to a staging
        # directory when it runs this script to build the package, and a
        # configure-time value would silently deploy into the wrong tree.
        # --qmldir points at the whole install root (not just standalone/)
        # so windeployqt also scans ../contents/ui/Scene3D.qml's QtQuick3D
        # import, same requirement as the manual command in README.md.
        install(CODE "
            execute_process(COMMAND \"${WINDEPLOYQT_EXECUTABLE}\" --qmldir \"\${CMAKE_INSTALL_PREFIX}\" \"\${CMAKE_INSTALL_PREFIX}/contriburg-standalone.exe\")
        ")
    else()
        message(WARNING "windeployqt not found next to the Qt6 install - the packaged installer will be missing Qt runtime DLLs")
    endif()

    set(CPACK_GENERATOR "NSIS")
    set(CPACK_PACKAGE_NAME "Contriburg")
    set(CPACK_PACKAGE_VENDOR "Marius Aiordachioaei")
    set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "A 3D skyline built from your GitHub contribution graph")
    set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
    set(CPACK_PACKAGE_INSTALL_DIRECTORY "Contriburg")
    set(CPACK_PACKAGE_FILE_NAME "Contriburg-${PROJECT_VERSION}-Setup")
    # Registers contriburg-standalone.exe for both Start Menu and desktop
    # shortcuts - see CPack's NSIS generator docs for this variable pair.
    set(CPACK_PACKAGE_EXECUTABLES "contriburg-standalone" "Contriburg")
    set(CPACK_CREATE_DESKTOP_LINKS "contriburg-standalone")
    set(CPACK_NSIS_MUI_ICON "${CMAKE_CURRENT_SOURCE_DIR}/assets/icon.ico")
    set(CPACK_NSIS_MUI_UNIICON "${CMAKE_CURRENT_SOURCE_DIR}/assets/icon.ico")
    set(CPACK_NSIS_INSTALLED_ICON_NAME "contriburg-standalone.exe")
    set(CPACK_NSIS_DISPLAY_NAME "Contriburg")
    set(CPACK_NSIS_PACKAGE_NAME "Contriburg")
    set(CPACK_NSIS_ENABLE_UNINSTALL_BEFORE_INSTALL ON)
    set(CPACK_NSIS_MODIFY_PATH OFF)
    set(CPACK_NSIS_URL_INFO_ABOUT "https://github.com/wilversings/contriburg")
    set(CPACK_NSIS_CONTACT "https://github.com/wilversings/contriburg/issues")
    include(CPack)
endif()
