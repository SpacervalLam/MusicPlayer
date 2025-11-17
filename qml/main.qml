import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Controls 2.15
import QtQuick.Effects
import "components"

ApplicationWindow {
    id: root
    width: Screen.width
    height: Screen.height
    visible: true
    title: ""


    // 添加置顶标志确保窗口始终在最上层
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowSystemMenuHint

    // 窗口透明度
    color: "transparent"

    // 背景图片组件 - 支持静态图片和GIF动图
    Loader {
        id: backgroundLoader
        anchors.fill: parent
        active: playerBackend.backgroundImage !== ""
        
        // 根据文件扩展名选择加载的组件
        sourceComponent: {
            if (!playerBackend.backgroundImage) return null
            var filePath = playerBackend.backgroundImage.toLowerCase()
            if (filePath.endsWith('.gif')) {
                return animatedBackgroundComponent
            } else {
                return staticBackgroundComponent
            }
        }
        
        // 静态图片组件
        Component {
            id: staticBackgroundComponent
            Image {
                anchors.fill: parent
                source: "file:///" + playerBackend.backgroundImage
                fillMode: Image.PreserveAspectCrop
                opacity: root.isDocked ? 0.45 : 1.0
                
                // 添加暗色遮罩以确保UI可见性
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#00000088" }
                        GradientStop { position: 0.6; color: "#00000066" }
                        GradientStop { position: 1.0; color: "#00000044" }
                    }
                    opacity: 0.9
                }
            }
        }
        
        // GIF动图组件
        Component {
            id: animatedBackgroundComponent
            AnimatedImage {
                anchors.fill: parent
                source: "file:///" + playerBackend.backgroundImage
                fillMode: AnimatedImage.PreserveAspectCrop
                opacity: root.isDocked ? 0.45 : 1.0
                playing: true  // 自动播放
                paused: false  // 不暂停
                
                // 添加暗色遮罩以确保UI可见性
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#00000088" }
                        GradientStop { position: 0.6; color: "#00000066" }
                        GradientStop { position: 1.0; color: "#00000044" }
                    }
                    opacity: 0.9
                }
            }
        }
    }

    // 全局鼠标位置变量
    property int globalMouseX: 0
    property int globalMouseY: 0

    // 全局鼠标监听器 - 用于边缘检测
    MouseArea {
        id: globalMouseArea
        anchors.fill: parent
        hoverEnabled: true
        // 这个MouseArea覆盖整个屏幕，用于检测全局鼠标位置
        onPositionChanged: {
            root.globalMouseX = mouse.x
            root.globalMouseY = mouse.y
        }
        // 透明且不拦截事件
        acceptedButtons: Qt.NoButton
    }

    // 收纳功能属性
    property bool isMinimized: false
    property bool isDocked: false
    property bool isHidden: false  // 完全隐藏状态
    property bool shouldAutoHide: false  // 是否应该自动隐藏（仅在用户主动收纳时为true）
    property int dockedWidth: 120
    property int normalWidth: Screen.width

    // 动画属性
    property real targetWidth: normalWidth
    property real targetX: 0
    property real targetOpacity: 1.0

    property int dockDuration: 80
    // 过冲比例（用于第一段动画的轻微放大）
    property real overshootFactor: 1.04

    // 延迟隐藏定时器（仅在用户主动收纳时才触发0.03秒自动隐藏）
    Timer {
        id: hideTimer
        interval: 200  // 默认0.2秒（用于鼠标离开窗口时的隐藏）
        repeat: false
        onTriggered: {
            // 仅在收纳模式且未已经隐藏 并且 鼠标不在窗口内 时才真正隐藏
            if (root.isDocked && !root.isHidden && !mainMouseArea.containsMouse) {
                hideWindow()
            }
        }
    }

    // 用户主动收纳时的快速隐藏定时器
    Timer {
        id: quickHideTimer
        interval: 30  // 0.03秒快速隐藏
        repeat: false
        onTriggered: {
            if (root.isDocked && !root.isHidden && !mainMouseArea.containsMouse) {
                hideWindow()
            }
            root.shouldAutoHide = false  // 重置标志
        }
    }

    // 边缘检测延迟定时器 - 鼠标在边缘停留0.3秒后才呼出
    Timer {
        id: edgeDelayTimer
        interval: 300  // 0.3秒延迟
        repeat: false
        onTriggered: {
            // 确保鼠标仍在边缘区域才呼出
            if (playerBackend.globalMouseX >= Screen.width - 6) {
                showDockFromEdge()
            }
        }
    }

    // 边缘检测定时器 - 检测鼠标在屏幕右侧（当窗口处于完全隐藏状态时唤出） 
    Timer {
        id: edgeCheckTimer
        interval: 40  // 更灵敏：每40ms检查一次
        running: true
        repeat: true
        onTriggered: {
            // 更新全局鼠标位置
            playerBackend.updateGlobalMousePosition()

            if (root.isHidden) {
                // 使用PlayerBackend的全局鼠标位置
                if (playerBackend.globalMouseX >= Screen.width - 6) {  // 6像素的边缘区域
                    // 启动延迟定时器，而不是立即呼出
                    if (!edgeDelayTimer.running) {
                        edgeDelayTimer.start()
                    }
                } else {
                    // 鼠标离开边缘区域，取消延迟定时器
                    edgeDelayTimer.stop()
                }
            } else {
                // 窗口可见时，确保延迟定时器停止
                edgeDelayTimer.stop()
            }
        }
    }

    // 隐藏窗口函数 - 带动画
    function hideWindow() {
        root.isHidden = true
        targetOpacity = 0.0
        // 启动隐藏动画（动画结束会把 visible 设为 false）
        hideAnimation.start()
    }

    // 从边缘唤出收纳窗口（只恢复到窄的 dock 模式，不展开，不触发快速隐藏）
    function showDockFromEdge() {
        root.isHidden = false
        root.isDocked = true
        root.shouldAutoHide = false  // 边缘呼出不触发快速隐藏
        targetWidth = root.dockedWidth
        targetX = Screen.width - root.dockedWidth
        targetOpacity = 1.0
        // 确保窗口可见
        root.visible = true
        dockAnimation.start()
        // 使用正常的隐藏定时器（0.2秒）
        hideTimer.restart()
    }

    // 显示窗口函数 - 带动画（一般从隐藏唤醒或程序触发） 
    function showWindow() {
        root.isHidden = false
        root.visible = true
        targetOpacity = 1.0
        if (root.isDocked) {
            targetWidth = root.dockedWidth
            targetX = Screen.width - root.dockedWidth
        } else {
            targetWidth = root.normalWidth
            targetX = 0
        }
        dockAnimation.start()
        hideTimer.restart()
    }

    // ESC键事件监听
    Connections {
        target: playerBackend
        function onEscapeKeyPressed() {
            // 在展开模式下按ESC键触发收纳
            if (!root.isDocked) {
                dockToRight()
            }
        }
    }

    // 主窗口鼠标事件监听（保留原逻辑并增强稳定性）
    MouseArea {
        id: mainMouseArea
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        focus: true
        // 确保可以接收键盘事件
        Keys.enabled: true

        acceptedButtons: Qt.LeftButton | Qt.RightButton

        // 组件加载完成后获取焦点
        Component.onCompleted: {
            forceActiveFocus()
        }

        // 在dock模式下，最右侧18像素区域不拦截鼠标事件
        onMouseXChanged: {
            if (root.isDocked && !root.isHidden && mouseX >= root.width - 18) {
                // 在穿透区域内，不拦截鼠标事件
                mouse.accepted = false
            }
        }

        onMouseYChanged: {
            if (root.isDocked && !root.isHidden && mouseX >= root.width - 18) {
                // 在穿透区域内，不拦截鼠标事件
                mouse.accepted = false
            }
        }

        Keys.onPressed: {
            console.log("Key pressed in QML:", event.key, event.text)
            if (event.key === Qt.Key_Escape) {
                console.log("ESC key pressed in QML")
                // 在展开模式下按ESC键触发收纳
                if (!root.isDocked) {
                    dockToRight()
                }
                event.accepted = true
            }
        }

        Keys.onReleased: {
            if (event.key === Qt.Key_F2) {
                if (root.isHidden) showDockFromEdge(); else expandToFullScreen();
            }
        }

        onPositionChanged: {
            // 在收纳模式下，检查鼠标是否在最右侧18像素的穿透区域
            if (root.isDocked && !root.isHidden) {
                // 如果鼠标在最右侧18像素区域内，不处理事件，让其穿透
                if (mouse.x >= root.width - 18) {
                    return  // 直接返回，不重置定时器
                }
                // 当鼠标在组件内部持续移动时，重置计时，保证只有"持续不在"才隐藏
                hideTimer.restart()
            }
        }

        onClicked: function(mouse) {
            // 在收纳模式下，检查鼠标是否在最右侧18像素的穿透区域
            if (root.isDocked && !root.isHidden && mouse.x >= root.width - 18) {
                // 在穿透区域内，不接受点击事件，让其穿透到下层
                return
            }
            
            if (mouse.button === Qt.RightButton) {
                // 在收纳模式下完全禁用右键菜单
                if (!root.isDocked) {
                    contextMenu.popup()
                }
            } else if (mouse.button === Qt.LeftButton) {
                // 在收纳模式下，点击窗口任意部位展开到全屏（排除穿透区域）
                if (root.isDocked && !root.isHidden) {
                    expandToFullScreen()
                }
                // 在展开模式下，点击窗口右侧120像素宽度内的位置触发收纳
                else if (!root.isDocked && mouse.x >= root.width - 120) {
                    dockToRight()
                }
            }
        }

        onExited: {
            // 鼠标离开窗口时，在收纳模式下启动隐藏定时器（不触发快速隐藏）
            if (root.isDocked && !root.isHidden) {
                root.shouldAutoHide = false  // 鼠标离开不触发快速隐藏
                hideTimer.restart()
            }
        }

        onEntered: {
            // 鼠标进入窗口时，取消隐藏定时器
            if (root.isDocked && !root.isHidden) {
                hideTimer.stop()
            }
        }
    }

    // 收纳/展开功能 - 带动画
    function toggleDock() {
        if (root.isDocked) {
            // 展开到全屏
            expandToFullScreen()
        } else {
            // 收纳到右侧
            dockToRight()
        }
    }

    // 展开到全屏函数
    function expandToFullScreen() {
        root.isDocked = false
        root.isHidden = false
        root.visible = true
        targetWidth = normalWidth
        targetX = 0
        targetOpacity = 1.0
        dockAnimation.start()
        hideTimer.stop()
    }

    // 收纳到右侧函数（用户主动收纳时触发0.03秒快速隐藏）
    function dockToRight() {
        root.isDocked = true
        root.isHidden = false
        root.visible = true
        targetWidth = dockedWidth
        targetX = Screen.width - dockedWidth
        targetOpacity = 1.0
        dockAnimation.start()
        // 用户主动收纳，设置快速隐藏标志并启动0.03秒隐藏定时器
        root.shouldAutoHide = true
        quickHideTimer.restart()
    }

    // --- 收纳/展开动画：先轻微过冲再回弹，使缩放更自然 ---
    SequentialAnimation {
        id: dockAnimation
        // 第一段：轻微放大/移动（过冲）+ opacity 到目标
        ParallelAnimation {
            NumberAnimation { target: root; property: "width"; to: targetWidth * root.overshootFactor; duration: root.dockDuration * 0.55; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "x"; to: targetX - (targetWidth * (root.overshootFactor - 1.0)); duration: root.dockDuration * 0.55; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "opacity"; to: targetOpacity; duration: root.dockDuration * 0.55; easing.type: Easing.OutCubic }
        }
        // 第二段：回弹到实际目标（缓动）
        ParallelAnimation {
            NumberAnimation { target: root; property: "width"; to: targetWidth; duration: root.dockDuration * 0.45; easing.type: Easing.OutBack }
            NumberAnimation { target: root; property: "x"; to: targetX; duration: root.dockDuration * 0.45; easing.type: Easing.OutBack }
        }
    }

    // 隐藏动画（淡出并缩到 0，然后 visible=false）
    SequentialAnimation {
        id: hideAnimation

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "opacity"
                to: 0.0
                duration: 100  // 加速3倍：300/3 = 100
                easing.type: Easing.InCubic
            }

            NumberAnimation {
                target: root
                property: "width"
                to: 0
                duration: 100  // 加速3倍：300/3 = 100
                easing.type: Easing.InCubic
            }

            NumberAnimation {
                target: root
                property: "x"
                to: Screen.width
                duration: 100  // 加速3倍：300/3 = 100
                easing.type: Easing.InCubic
            }
        }

        PropertyAction {
            target: root
            property: "visible"
            value: false
        }
    }

    // 显示动画（从 invisible -> visible -> 到 dockedWidth）
    SequentialAnimation {
        id: showAnimation

        PropertyAction {
            target: root
            property: "visible"
            value: true
        }

        ParallelAnimation {
            NumberAnimation { target: root; property: "width"; to: dockedWidth; duration: 100; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "opacity"; to: 1.0; duration: 100; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "x"; to: Screen.width - dockedWidth; duration: 100; easing.type: Easing.OutCubic }
        }
    }

    // 窗口定位
    x: 0
    y: 0

    // 桌面嵌入效果 - 模糊背景
    Rectangle {
        id: backgroundLayer
        anchors.fill: parent
        color: "#0a0a0a"
        opacity: 0.85

        // 渐变叠加层（去掉黄色调，使用纯蓝黑配色）
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0a0f1c40" }
            GradientStop { position: 0.5; color: "#0d192540" }
            GradientStop { position: 1.0; color: "#06112040" }
        }

        // 边框发光效果（更精细）
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            color: "transparent"
            border.color: "#4a9eff33"
            border.width: 1.6
            radius: 24

            // 外发光效果（柔光）
            Rectangle {
                anchors.fill: parent
                anchors.margins: -4
                color: "transparent"
                border.color: "#4a9eff10"
                border.width: 1
                radius: 28
            }
        }
    }

    // 主内容区域
    Rectangle {
        id: mainContent
        anchors.fill: parent
        anchors.margins: 6
        color: "transparent"
        radius: 22
        clip: true

        // 视觉：给主容器添加轻微内阴影模拟凹面（使用半透明渐变）
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: parent.radius
            border.color: "#ffffff06"
            border.width: 1
        }

        // 标题栏 - 无拖拽功能，添加收纳控制
        Rectangle {
            id: titleBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 56
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 12

                Text {
                    text: " "
                    color: "#ffffff"
                    font.pixelSize: 16
                    font.family: "Segoe UI, sans-serif"
                    font.weight: Font.DemiBold
                    opacity: 0.95
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }
            }
        }

        // 主内容区域 - 根据dock状态动态调整布局
        Item {
            anchors.fill: parent
            
            // 全屏模式布局
            RowLayout {
                anchors.fill: parent
                anchors.topMargin: 80
                anchors.margins: 28
                spacing: 24
                visible: !root.isDocked

                // LEFT: playlist - 全屏模式下自适应
                ColumnLayout {
                    Layout.preferredWidth: parent.width * 0.45
                    Layout.fillHeight: true
                    spacing: 12

                    Column {
                        spacing: 6
                        Text {
                            text: "Playlist";
                            font.pixelSize: 20;
                            color: "#eaf6ff";
                            opacity: 0.95;
                            font.family: "Segoe UI, sans-serif"
                            font.weight: Font.DemiBold
                        }
                        Rectangle {
                            width: 56
                            height: 3
                            color: "#4a9eff"
                            radius: 2
                            opacity: 0.95
                        }
                    }

                    Rectangle {
                        id: listBg
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "transparent"
                        radius: 14
                        border.color: "transparent"
                        border.width: 0

                        ListView {
                            id: playlistView
                            anchors.fill: parent
                            anchors.margins: 8
                            model: playlistModel
                            spacing: 10
                            clip: true
                            delegate: Item {
                                width: ListView.view.width
                                height: 72
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: playerBackend.playIndex(index)
                                    hoverEnabled: true

                                    Rectangle {
                                        anchors.fill: parent
                                        color: parent.containsMouse ? "#4a9eff10" : "transparent"
                                        radius: 12
                                        border.color: parent.containsMouse ? "#4a9eff22" : "transparent"
                                        border.width: parent.containsMouse ? 1 : 0

                                        Behavior on color {
                                            ColorAnimation { duration: 67; easing.type: Easing.OutCubic }  // 加速3倍：200/3 ≈ 67
                                        }
                                        Behavior on border.color {
                                            ColorAnimation { duration: 67; easing.type: Easing.OutCubic }  // 加速3倍：200/3 ≈ 67
                                        }

                                        // 播放指示器（更精细）
                                        Rectangle {
                                            visible: playerBackend.currentIndex === index
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 5
                                            height: 36
                                            color: "#4a9eff"
                                            radius: 3

                                            // 发光效果（柔和）
                                            Rectangle {
                                                anchors.fill: parent
                                                anchors.margins: -6
                                                color: "transparent"
                                                border.color: "#4a9eff44"
                                                border.width: 1
                                                radius: 6
                                            }
                                        }
                                    }
                                }
                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 18
                                    anchors.right: parent.right
                                    anchors.rightMargin: 18
                                    spacing: 14

                                    // 序号（现代化风格）
                                    Text {
                                        text: index + 1;
                                        color: "#e8f8ff";
                                        font.pixelSize: 20;
                                        font.family: "SF Pro Display, Segoe UI, system-ui, sans-serif"
                                        font.weight: Font.DemiBold
                                        opacity: 0.9
                                        width: 36
                                        horizontalAlignment: Text.AlignRight
                                    }

                                    // 歌曲信息（更紧凑、更现代）
                                    Column {
                                        spacing: 2
                                        width: parent.width - 40 - parent.spacing
                                        Text {
                                            text: model.title || model.name || "Unknown Title";
                                            color: "#ffffff";
                                            font.pixelSize: 16;
                                            elide: Text.ElideRight;
                                            font.family: "SF Pro Display, Segoe UI, system-ui, sans-serif"
                                            font.weight: Font.DemiBold
                                            width: parent.width
                                        }
                                        Text {
                                            text: model.artist || "Unknown Artist";
                                            color: "#cfeffd";
                                            font.pixelSize: 12;
                                            opacity: 0.75;
                                            font.family: "Segoe UI, sans-serif"
                                            font.weight: Font.Light
                                        }
                                    }
                                }
                            }
                            ScrollBar.vertical: ScrollBar {
                                policy: ScrollBar.AlwaysOff
                            }
                        }
                    }
                }

                // RIGHT: player card + bottom area - 全屏模式下自适应
                ColumnLayout {
                    Layout.preferredWidth: parent.width * 0.5
                    Layout.fillHeight: true
                    spacing: 18

                    // Enhanced Player Card - 收纳模式下简化
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 320  // 使用固定高度避免递归
                        color: "transparent"
                        radius: 24
                        border.color: "transparent"
                        border.width: 0
                        clip: true

                        // 轻微的外发光效果（仅在展开时显示）
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -6
                            radius: parent.radius + 6
                            color: "transparent"
                            border.color: "#4a9eff10"
                            border.width: 2
                            visible: !root.isDocked
                        }

                        // PlayerCard 加载（全屏模式）
                        Loader {
                            id: playerCardLoader
                            anchors.fill: parent
                            anchors.margins: 24
                            source: "qrc:/qml/PlayerCard.qml"
                            
                            // 平滑淡入动画
                            Behavior on opacity {
                                NumberAnimation { duration: 220; easing.type: Easing.InOutQuad }
                            }
                            
                            opacity: 1.0
                        }
                        
                        // 独立的音量滑块组件
        VolumeSlider {
            id: globalVolumeSlider
            visible: false
            z: 1000
            
            // 简化的定位逻辑 - 直接使用固定位置相对于音量按钮
            x: playerCardLoader.x + playerCardLoader.width - 125  // 左移少许
            y: playerCardLoader.y + playerCardLoader.height - 90  // 下移少许
        }
                        
                        // 连接PlayerCard的音量按钮点击事件
                        Connections {
                            target: playerCardLoader.item
                            function onVolumeButtonClicked() {
                                globalVolumeSlider.visible = !globalVolumeSlider.visible
                            }
                        }
                    }

                    // Enhanced Visualizer - 收纳模式下可能隐藏或缩小
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 120
                        color: "transparent"
                        radius: 20
                        border.width: 0
                        clip: true

                        // Visualizer centered and scaled
                        Item {
                            anchors.centerIn: parent
                            width: parent.width
                            height: parent.height
                            
                            Loader {
                                id: visualizerLoader
                                anchors.centerIn: parent
                                width: parent.width * 0.8
                                height: parent.height * 0.8
                                source: "qrc:/qml/components/Visualizer.qml"
                                
                                // 绑定频谱数据到 Visualizer
                                onLoaded: {
                                    item.spectrum = playerBackend.spectrum || []
                                    item.audioLevel = playerBackend.audioLevel || 0.0
                                    item.isPlaying = playerBackend.playing || false
                                }
                                
                                // 实时更新频谱数据
                                Connections {
                                    target: playerBackend
                                    function onSpectrumChanged() {
                                        if (visualizerLoader.item) {
                                            visualizerLoader.item.spectrum = playerBackend.spectrum || []
                                        }
                                    }
                                }
                            }
                        }

                        // 歌词显示区域 - 叠加在可视化组件上
                        Column {
                            anchors.centerIn: parent
                            anchors.margins: 20
                            spacing: 8
                            
                            Text {
                                id: currentLyricsText
                                text: playerBackend.currentLyrics || ""
                                font.pixelSize: 18
                                font.bold: true
                                color: "#ffffff"
                                width: parent.width
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
                                style: Text.Outline
                                styleColor: "#00000080"
                            }
                            
                            Text {
                                id: nextLyricsText
                                text: playerBackend.nextLyrics || ""
                                font.pixelSize: 14
                                color: "#cccccc"
                                width: parent.width
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
                                style: Text.Outline
                                styleColor: "#00000060"
                            }
                        }
                    }
                }
            }
            
            // Dock模式布局 - 显示Mini播放器
            Rectangle {
                anchors.fill: parent
                anchors.margins: 8
                color: "transparent"
                visible: root.isDocked
                
                // PlayerCardMini 加载（dock模式）
                Loader {
                    id: playerCardMiniLoader
                    anchors.fill: parent
                    source: "qrc:/qml/PlayerCardMini.qml"
                    
                    // 平滑淡入动画
                    Behavior on opacity {
                        NumberAnimation { duration: 220; easing.type: Easing.InOutQuad }
                    }
                    
                    opacity: 1.0
                    
                    // 连接展开请求信号并传递 playerBackend
                    onLoaded: {
                        item.expandRequested.connect(expandToFullScreen)
                        // 传递 playerBackend 给 PlayerCardMini
                        if (item.hasOwnProperty("playerBackend")) {
                            item.playerBackend = playerBackend
                        }
                    }
                }
            }
        }

        // 音乐文件夹选择提示对话框
        Dialog {
            id: musicFolderPrompt
            title: "欢迎使用音乐播放器"
            width: 400
            height: 200
            modal: true
            
            Rectangle {
                anchors.fill: parent
                color: "#1a1a2e"
                radius: 12
                border.color: "#4a9eff33"
                border.width: 1
                
                Column {
                    anchors.centerIn: parent
                    spacing: 20
                    
                    Text {
                        text: "🎵 欢迎使用音乐播放器！"
                        font.pixelSize: 18
                        font.bold: true
                        color: "#ffffff"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    
                    Text {
                        text: "请选择您的音乐文件夹以开始播放"
                        font.pixelSize: 14
                        color: "#cccccc"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                    
                    Row {
                        spacing: 15
                        anchors.horizontalCenter: parent.horizontalCenter
                        
                        Button {
                            text: "选择音乐文件夹"
                            font.pixelSize: 14
                            background: Rectangle {
                                color: "#4a9eff"
                                radius: 6
                            }
                            onClicked: {
                                musicFolderPrompt.close()
                                folderDialog.open()
                            }
                        }
                        
                        Button {
                            text: "稍后设置"
                            font.pixelSize: 14
                            background: Rectangle {
                                color: "#666666"
                                radius: 6
                            }
                            onClicked: {
                                musicFolderPrompt.close()
                            }
                        }
                    }
                }
            }
        }

        FolderDialog {
            id: folderDialog
            title: "Select Music Folder"
            onAccepted: {
                playerBackend.importFolder(folderDialog.selectedFolder.toString().replace("file:///", ""))
            }
        }

        // 背景图片文件选择对话框
        FileDialog {
            id: backgroundImageDialog
            title: "选择背景图片"
            nameFilters: ["图片文件 (*.png *.jpg *.jpeg *.bmp *.gif)", "所有文件 (*.*)"]
            onAccepted: {
                var imagePath = selectedFile.toString().replace("file:///", "")
                playerBackend.setBackgroundImage(imagePath)
            }
        }

        // 键盘事件监听 - 用于显示隐藏的窗口
        Item {
            focus: true
            Keys.onPressed: {
                if (event.key === Qt.Key_F2 && root.isHidden) {
                    showDockFromEdge()
                }
            }
        }
    }

    // 连接PlayerBackend的音乐文件夹需求信号
    Connections {
        target: playerBackend
        function onMusicFolderNeeded() {
            musicFolderPrompt.open()
        }
    }

    // 右键菜单
    Menu {
        id: contextMenu

        MenuItem {
            text: "📁 添加音乐文件夹..."
            visible: !root.isDocked || playerBackend.musicFolder === ""
            onTriggered: {
                folderDialog.open()
            }
        }

        MenuSeparator { 
            visible: !root.isDocked 
        }

        MenuItem {
            text: "   设置背景图片..."
            visible: !root.isDocked
            onTriggered: {
                backgroundImageDialog.open()
            }
        }

        MenuItem {
            text: "   重置背景图片"
            visible: !root.isDocked
            enabled: playerBackend.backgroundImage !== ""
            onTriggered: {
                playerBackend.resetBackgroundImage()
            }
        }

        MenuSeparator { 
            visible: !root.isDocked 
        }

        MenuItem {
            text: root.isDocked ? "   展开到全屏" : "   收纳到右侧"
            onTriggered: {
                toggleDock()
            }
        }
    }
}
