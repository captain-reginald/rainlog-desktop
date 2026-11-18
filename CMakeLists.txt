cmake_minimum_required(VERSION 3.21)

project(rainlog-desktop
  VERSION 1.0.1
  DESCRIPTION "Rain Log Desktop client"
  LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

set(RAINLOG_VERSION_SUFFIX "" CACHE STRING "Appended to the reported version, e.g. -dev1")

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Quick)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_resources(RAINLOG_ICON_SOURCES packaging/app_icon.qrc)

if(WIN32)
  enable_language(RC)
  set(RAINLOG_WINDOWS_RESOURCE packaging/windows/rainlog-desktop.rc)
else()
  set(RAINLOG_WINDOWS_RESOURCE)
endif()

qt_add_executable(rainlog-desktop
  src/main.cpp
  src/installer.cpp
  src/installer.h
  src/config.cpp
  src/config.h
  src/store.cpp
  src/store.h
  src/themesource.cpp
  src/themesource.h
  src/apphost.h
  ${RAINLOG_WINDOWS_RESOURCE}
  ${RAINLOG_ICON_SOURCES}
)

set_source_files_properties(shared/ui/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(rainlog-desktop
  URI RainLog
  VERSION 1.0
  QML_FILES
    qml/Main.qml
    shared/ui/Theme.qml
    shared/ui/RainLogContent.qml
    shared/ui/Button.qml
    shared/ui/TextField.qml
    shared/ui/Toggle.qml
    shared/ui/ToggleSwitch.qml
    shared/ui/Dropdown.qml
    shared/ui/PanelSeparator.qml
    shared/ui/PanelSectionHeader.qml
    shared/ui/Tooltip.qml
    shared/model/Model.js
)

target_link_libraries(rainlog-desktop PRIVATE Qt6::Core Qt6::Gui Qt6::Quick)

target_compile_definitions(rainlog-desktop PRIVATE
  RAINLOG_VERSION="${PROJECT_VERSION}${RAINLOG_VERSION_SUFFIX}"
)

set_target_properties(rainlog-desktop PROPERTIES
  WIN32_EXECUTABLE TRUE
)

if(WIN32)
  # Let the resource compiler find the icon relative to the source root.
  target_include_directories(rainlog-desktop PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
endif()

include(GNUInstallDirs)

install(TARGETS rainlog-desktop
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

if(WIN32)
  install(FILES packaging/fonts/JetBrainsMonoNerdFont-Regular.ttf
                packaging/fonts/JetBrainsMonoNerdFont-Bold.ttf
                packaging/fonts/JetBrainsMono-OFL.txt
    DESTINATION ${CMAKE_INSTALL_BINDIR})
  install(FILES README.md LICENSE
    DESTINATION ${CMAKE_INSTALL_BINDIR})
else()
  install(FILES packaging/rainlog-desktop.desktop
    DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)

  install(FILES packaging/rainlog-desktop.svg
    DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps)
  install(FILES packaging/rainlog-desktop.png
    DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/512x512/apps)
  install(FILES packaging/io.github.captainreginald.rainlog.metainfo.xml
    DESTINATION ${CMAKE_INSTALL_DATADIR}/metainfo)

  install(FILES LICENSE
    DESTINATION ${CMAKE_INSTALL_DATADIR}/licenses/rainlog-desktop)
endif()
