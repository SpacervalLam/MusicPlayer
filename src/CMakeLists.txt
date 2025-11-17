cmake_minimum_required(VERSION 3.16)

set(SRC_FILES
    main.cpp
    playerbackend.cpp
    playlistmodel.cpp
)

set(HEADERS
    playerbackend.h
    playlistmodel.h
    resources.qrc
)

qt6_add_resources(QRCS resources.qrc)

add_executable(qt_music_player_cpp ${SRC_FILES} ${QRCS})

target_link_libraries(qt_music_player_cpp
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Multimedia
)

# For QML import from resource we expose qml dir in runpath via RESOURCES
# Set deployment rules (optional)
set_target_properties(qt_music_player_cpp PROPERTIES
    MACOSX_BUNDLE TRUE
)