cmake_minimum_required(VERSION 3.16)
project(qt_music_player_cpp)

set(CMAKE_CXX_STANDARD 17)

# --- 关键设置：启用自动 moc/rcc/uic ---
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# 找 Qt 所需模块
find_package(Qt6 REQUIRED COMPONENTS
    Quick
    Qml
    Multimedia
    Widgets
    QuickControls2
    QuickLayouts
    QuickDialogs2
    Core
    QuickTemplates2
)

qt_add_executable(app
    src/main.cpp
    src/playerbackend.cpp
    src/playerbackend.h
    src/playlistmodel.cpp
    src/playlistmodel.h
    src/resources.qrc
)

# 链接 Qt 库
target_link_libraries(app PRIVATE
    Qt6::Quick
    Qt6::Qml
    Qt6::Multimedia
    Qt6::Widgets
    Qt6::QuickControls2
    Qt6::QuickLayouts
    Qt6::QuickDialogs2
    Qt6::Core
    Qt6::QuickTemplates2
)



# QML
qt_add_qml_module(app
    URI MusicPlayer
    VERSION 1.0
    QML_FILES
        qml/main.qml
)
