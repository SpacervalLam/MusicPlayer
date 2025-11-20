import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
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
                
                // 添加暗色遮罩以确保UI可见性 - 使用纯中性黑避免色彩偏移
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#00000066" }
                        GradientStop { position: 0.6; color: "#00000044" }
                        GradientStop { position: 1.0; color: "#00000022" }
                    }
                    opacity: 0.6  // 降低透明度，减少色彩污染
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
                
                // 添加暗色遮罩以确保UI可见性 - 使用纯中性黑避免色彩偏移
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#00000066" }
                        GradientStop { position: 0.6; color: "#00000044" }
                        GradientStop { position: 1.0; color: "#00000022" }
                    }
                    opacity: 0.6  // 降低透明度，减少色彩污染
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

    // 批量删除功能属性
    property bool batchDeleteMode: false
    property var selectedImages: []

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
            // 使用全局鼠标位置判断是否真正离开窗口
            if (root.isDocked && !root.isHidden) {
                var globalX = playerBackend.globalMouseX
                var globalY = playerBackend.globalMouseY
                var windowX = root.x
                var windowY = root.y
                
                // 如果鼠标不在窗口区域内，才真正隐藏
                if (globalX < windowX || globalX > windowX + root.width ||
                    globalY < windowY || globalY > windowY + root.height) {
                    hideWindow()
                }
            }
        }
    }

    // 用户主动收纳时的快速隐藏定时器
    Timer {
        id: quickHideTimer
        interval: 30  // 0.03秒快速隐藏
        repeat: false
        onTriggered: {
            if (root.isDocked && !root.isHidden) {
                var globalX = playerBackend.globalMouseX
                var globalY = playerBackend.globalMouseY
                var windowX = root.x
                var windowY = root.y
                
                // 如果鼠标不在窗口区域内，才真正隐藏
                if (globalX < windowX || globalX > windowX + root.width ||
                    globalY < windowY || globalY > windowY + root.height) {
                    hideWindow()
                }
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

    // 鼠标离开检查定时器 - 延迟检查鼠标是否真正离开窗口
    Timer {
        id: exitCheckTimer
        interval: 100  // 100ms延迟
        repeat: false
        onTriggered: {
            // 延迟检查：使用全局鼠标位置判断是否真正离开窗口
            if (root.isDocked && !root.isHidden) {
                // 检查全局鼠标位置是否在窗口区域内
                var globalX = playerBackend.globalMouseX
                var globalY = playerBackend.globalMouseY
                var windowX = root.x
                var windowY = root.y
                
                // 如果鼠标不在窗口区域内，才启动隐藏定时器
                if (globalX < windowX || globalX > windowX + root.width ||
                    globalY < windowY || globalY > windowY + root.height) {
                    hideTimer.restart()
                }
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
        propagateComposedEvents: true  // 允许事件传播到子组件
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
                console.log("mainContextMenu.visible:", mainContextMenu.visible)
                console.log("backgroundManagerDialog.visible:", backgroundManagerDialog.visible)
                
                var hasOpenDialogs = mainContextMenu.visible || backgroundManagerDialog.visible
                
                // 优先关闭所有打开的对话框和菜单
                if (mainContextMenu.visible) {
            mainContextMenu.close()
                    console.log("Closed context menu")
                }
                if (backgroundManagerDialog.visible) {
                    backgroundManagerDialog.close()
                    console.log("Closed background manager dialog")
                }
                
                // 只有在没有打开对话框的情况下，才执行窗口收纳操作
                if (!hasOpenDialogs && !root.isDocked) {
                    dockToRight()
                    console.log("Docked window due to ESC (no dialogs open)")
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
                    mainContextMenu.popup()
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
            // 立即更新全局鼠标位置，然后启动延迟检查
            if (root.isDocked && !root.isHidden) {
                root.shouldAutoHide = false  // 鼠标离开不触发快速隐藏
                // 立即更新全局鼠标位置
                playerBackend.updateGlobalMousePosition()
                // 延迟100ms再启动隐藏定时器，给鼠标移动到子组件的时间
                exitCheckTimer.restart()
            }
        }

        onEntered: {
            // 鼠标进入窗口时，取消隐藏定时器和离开检查定时器
            if (root.isDocked && !root.isHidden) {
                hideTimer.stop()
                exitCheckTimer.stop()  // 停止离开检查定时器
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
            border.color: "transparent"
            border.width: 0
            radius: 24

            // 外发光效果（柔光）
            Rectangle {
                anchors.fill: parent
                anchors.margins: -4
                color: "transparent"
                border.color: "transparent"
                border.width: 0
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
                            spacing: 15
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
                                        color: parent.containsMouse ? "#4a9eff20" : "transparent"
                                        radius: 12
                                        border.color: parent.containsMouse ? "#4a9eff40" : "transparent"
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
            x: playerCardLoader.x + playerCardLoader.width - 160 
            y: playerCardLoader.y + playerCardLoader.height - 82
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

        // 批量添加背景图片对话框
        FileDialog {
            id: batchBackgroundImageDialog
            title: "批量添加背景图片"
            nameFilters: ["图片文件 (*.png *.jpg *.jpeg *.bmp *.gif)", "所有文件 (*.*)"]
            fileMode: FileDialog.OpenFiles
            onAccepted: {
                var imagePaths = []
                for (var i = 0; i < selectedFiles.length; i++) {
                    var imagePath = selectedFiles[i].toString().replace("file:///", "")
                    imagePaths.push(imagePath)
                }
                playerBackend.addBackgroundImages(imagePaths)
            }
        }

        // 背景图片管理对话框
        Dialog {
            id: backgroundManagerDialog
            width: 1000
            height: 700
            modal: true
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
            visible: !root.isDocked && visible
            
            // 透明背景层，用于点击隐藏右键菜单和退出批量选择模式
            MouseArea {
                anchors.fill: parent
                enabled: contextMenu.visible || batchDeleteMode
                onClicked: {
                    if (contextMenu.visible) {
                        contextMenu.visible = false
                    } else if (batchDeleteMode) {
                        // 退出批量选择模式
                        batchDeleteMode = false
                        selectedImages = []
                    }
                }
            }
            
            // 浅色科技风格背景
            Rectangle {
                anchors.fill: parent
                color: "#f8fafc"
                radius: 20
                
                // 柔和渐变边框
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    color: "transparent"
                    radius: 18
                    border.width: 2
                    border.color: "#e2e8f0"
                    
                    // 柔和发光效果
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -4
                        color: "transparent"
                        radius: 22
                        border.width: 1
                        border.color: "#cbd5e144"
                        
                        // 外层光晕
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -6
                            color: "transparent"
                            radius: 26
                            border.width: 1
                            border.color: "#94a3b822"
                        }
                    }
                }
                
                // 简约网格背景纹理
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    color: "transparent"
                    clip: true
                    
                    // 简洁的网格背景
                    Canvas {
                        id: lightGridPattern
                        anchors.fill: parent
                        
                        property int cellSize: 24
                        property real lineWidth: 0.3
                        property color lineColor: "#e2e8f033"
                        
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.strokeStyle = lineColor
                            ctx.lineWidth = lineWidth
                            
                            // 绘制垂直线
                            for (var x = 0; x <= width; x += cellSize) {
                                ctx.beginPath()
                                ctx.moveTo(x, 0)
                                ctx.lineTo(x, height)
                                ctx.stroke()
                            }
                            
                            // 绘制水平线
                            for (var y = 0; y <= height; y += cellSize) {
                                ctx.beginPath()
                                ctx.moveTo(0, y)
                                ctx.lineTo(width, y)
                                ctx.stroke()
                            }
                        }
                        
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                    }
                }
                
                Column {
                    anchors.fill: parent
                    anchors.margins: 30
                    spacing: 25
                    
                    // 简约科技风格标题栏
                    Rectangle {
                        width: parent.width
                        height: 60
                        color: "transparent"
                        
                        Row {
                            anchors.fill: parent
                            spacing: 20
                            anchors.verticalCenter: parent.verticalCenter
                            
                            // 标题区域
                            Column {
                                spacing: 5
                                
                                Text {
                                    text: "背景图片管理"
                                    font.pixelSize: 24
                                    font.bold: true
                                    color: "#1e293b"
                                    font.family: "Segoe UI"
                                    
                                    // 简洁文字效果
                                    layer.enabled: true
                                    layer.effect: MultiEffect {
                                        colorization: 0.1
                                        colorizationColor: "#64748b"
                                        blur: 0.2
                                        blurMax: 4
                                    }
                                }
                                
                                Rectangle {
                                    width: 200
                                    height: 3
                                    color: "#cff3f3ff"
                                    radius: 2
                                    
                                    // 柔和扫描线
                                    Rectangle {
                                        width: 40
                                        height: 3
                                        color: "#76e0e2ff"
                                        radius: 2
                                        
                                        SequentialAnimation on x {
                                            loops: Animation.Infinite
                                            NumberAnimation { to: 160; duration: 2500; easing.type: Easing.InOutQuad }
                                            NumberAnimation { to: 0; duration: 2500; easing.type: Easing.InOutQuad }
                                        }
                                    }
                                }
                            }
                            
                            // 状态指示器
                            Rectangle {
                                width: 220
                                height: 45
                                color: "#f1f5f9"
                                radius: 22
                                border.color: "#cbd5e1"
                                border.width: 2
                                
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 15
                                    
                                    Rectangle {
                                        width: 12
                                        height: 12
                                        color: playerBackend.backgroundImageList.length > 0 ? "#10b981" : "#ef4444"
                                        radius: 6
                                        
                                        // 柔和脉冲动画
                                        SequentialAnimation on scale {
                                            loops: Animation.Infinite
                                            NumberAnimation { to: 1.2; duration: 1200 }
                                            NumberAnimation { to: 1.0; duration: 1200 }
                                        }
                                    }
                                    
                                    Text {
                                        text: playerBackend.currentBackgroundIndex >= 0 ? 
                                              (playerBackend.currentBackgroundIndex + 1) + "/" + playerBackend.backgroundImageList.length : 
                                              "无背景"
                                        color: "#475569"
                                        font.pixelSize: 14
                                        font.bold: true
                                    }
                                }
                            }
                        }
                    }
                    
                    // 简约科技风格缩略图网格区域
                    Rectangle {
                        width: parent.width
                        height: 380
                        color: "#ffffff"
                        radius: 16
                        border.color: "#e2e8f0"
                        border.width: 2
                        clip: true
                        
                        // 内部柔和边框
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 3
                            color: "transparent"
                            radius: 13
                            border.width: 1
                            border.color: "#f1f5f9"
                        }
                        
                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: 20
                            
                            GridView {
                                id: thumbnailGrid
                                model: playerBackend.backgroundImageList
                                cellWidth: 210  
                                cellHeight: 158 
                                
                                delegate: Rectangle {
                                    width: 210
                                    height: 157
                                    color: "transparent"
                                    
                                    // 简约科技风格卡片
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 6 
                                        color: index === playerBackend.currentBackgroundIndex ? "#f0f9ff" : "#ffffff"
                                        radius: 12
                                        border.color: index === playerBackend.currentBackgroundIndex ? "#0ea5e9" : "#e2e8f0"
                                        border.width: index === playerBackend.currentBackgroundIndex ? 2 : 1
                                        
                                        // 柔和阴影效果
                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.margins: -2
                                            color: "transparent"
                                            radius: 14
                                            border.width: 1
                                            border.color: index === playerBackend.currentBackgroundIndex ? "#0ea5e922" : "transparent"
                                            visible: index === playerBackend.currentBackgroundIndex
                                        }
                                        
                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 8   
                                            spacing: 14  
                                            
                                            // 缩略图容器
                                            Rectangle {
                                                width: 176  // 进一步缩小 (从185调整到176)
                                                height: 99  // 进一步缩小 (从104调整到99)
                                                color: "#f8fafc"
                                                radius: 6
                                                border.color: "#e2e8f0"
                                                border.width: 1
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                clip: true
                                                
                                                Image {
                                                    anchors.fill: parent
                                                    anchors.margins: 3
                                                    source: "file:///" + modelData
                                                    fillMode: Image.PreserveAspectCrop
                                                    asynchronous: true
                                                    cache: true
                                                    
                                                    // 优雅加载动画
                                                    Rectangle {
                                                        anchors.centerIn: parent
                                                        width: 28
                                                        height: 28
                                                        color: "#e2e8f0"
                                                        radius: 14
                                                        visible: parent.status === Image.Loading
                                                        
                                                        // 旋转动画
                                                        RotationAnimation on rotation {
                                                            from: 0
                                                            to: 360
                                                            duration: 1800
                                                            loops: Animation.Infinite
                                                        }
                                                        
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "⚡"
                                                            color: "#94a3b8"
                                                            font.pixelSize: 14
                                                        }
                                                    }
                                                    
                                                    // 错误状态
                                                    Rectangle {
                                                        anchors.fill: parent
                                                        color: "#fef2f2"
                                                        visible: parent.status === Image.Error
                                                        
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "⚠️\n加载失败"
                                                            color: "#ef4444"
                                                            font.pixelSize: 12
                                                            horizontalAlignment: Text.AlignHCenter
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        
                                        // 鼠标交互区域
                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            
                                            onEntered: {
                                                parent.scale = 1.03
                                                parent.color = index === playerBackend.currentBackgroundIndex ? "#e0f2fe" : "#f8fafc"
                                            }
                                            
                                            onExited: {
                                                if (!contextMenu.visible) {
                                                    parent.scale = 1.0
                                                    parent.color = index === playerBackend.currentBackgroundIndex ? "#f0f9ff" : "#ffffff"
                                                }
                                            }
                                            
                                            onClicked: {
                                                // 点击动画 - 使用parent作为动画目标
                                                var clickAnim = Qt.createQmlObject('import QtQuick 2.15; SequentialAnimation { PropertyAnimation { target: parent; property: "scale"; to: 0.95; duration: 100 } PropertyAnimation { target: parent; property: "scale"; to: 1.0; duration: 100 } }', parent, "dynamicClickAnimation")
                                                clickAnim.start()
                                                clickAnim.destroy(1000)
                                                
                                                if (batchDeleteMode) {
                                                    // 批量删除模式：使用图片路径作为唯一标识，避免索引随删除变化
                                                    var key = modelData  // 使用图片路径作为唯一标识，避免索引随删除变化
                                                    var selectedIndex = selectedImages.indexOf(key)
                                                    if (selectedIndex === -1) {
                                                        selectedImages = selectedImages.concat([key])
                                                    } else {
                                                        var newArr = selectedImages.slice()
                                                        newArr.splice(selectedIndex, 1)
                                                        selectedImages = newArr
                                                    }
                                                } else {
                                                    // 普通模式：设置为背景
                                                    playerBackend.setBackgroundByIndex(index)
                                                }
                                            }
                                            
                                            // 右键菜单
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            
                                            onPressed: function(mouse) {
                                                if (mouse.button === Qt.RightButton) {
                                                    // 设置右键菜单的目标图片信息
                                                    contextMenu.targetImagePath = modelData
                                                    contextMenu.targetImageIndex = index
                                                    
                                                    // 计算右键菜单位置（在鼠标附近，但确保不超出屏幕边界）
                                                    var globalPos = mapToItem(backgroundImageManagerDialog.contentItem, mouse.x, mouse.y)
                                                    var menuX = globalPos.x - 100 // 菜单宽度的一半，让菜单中心对齐鼠标
                                                    var menuY = globalPos.y - 60 // 菜单显示在鼠标上方
                                                    
                                                    // 确保菜单不超出对话框边界
                                                    if (menuX < 10) menuX = 10
                                                    if (menuX + 200 > backgroundImageManagerDialog.width - 10) menuX = backgroundImageManagerDialog.width - 210
                                                    if (menuY < 10) menuY = 10
                                                    if (menuY + 75 > backgroundImageManagerDialog.height - 10) menuY = globalPos.y + 10 // 如果上方空间不够，显示在下方
                                                    
                                                    // 设置菜单位置并显示
                                                    contextMenu.parent = backgroundImageManagerDialog.contentItem
                                                    contextMenu.x = menuX
                                                    contextMenu.y = menuY
                                                    contextMenu.visible = true
                                                    
                                                    // 保持缩略图高亮状态
                                                    parent.scale = 1.03
                                                    parent.color = index === playerBackend.currentBackgroundIndex ? "#e0f2fe" : "#f8fafc"
                                                }
                                            }
                                        }
                                        
                                        // 当前背景指示器
                                        Rectangle {
                                            width: 20
                                            height: 20
                                            color: "#0ea5e9"
                                            radius: 10
                                            anchors.top: parent.top
                                            anchors.right: parent.right
                                            anchors.margins: 8
                                            visible: index === playerBackend.currentBackgroundIndex
                                            
                                            // 柔和发光效果
                                            Rectangle {
                                                anchors.fill: parent
                                                anchors.margins: -2
                                                color: "transparent"
                                                radius: 12
                                                border.width: 1
                                                border.color: "#0ea5e944"
                                            }
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: "✓"
                                                color: "#ffffff"
                                                font.pixelSize: 12
                                                font.bold: true
                                            }
                                            
                                            // 柔和脉冲动画
                                            SequentialAnimation on scale {
                                                loops: Animation.Infinite
                                                NumberAnimation { to: 1.15; duration: 1200 }
                                                NumberAnimation { to: 1.0; duration: 1200 }
                                            }
                                        }
                                        
                                        // 批量选择指示器
                                        Rectangle {
                                            id: batchSelector
                                            width: 24
                                            height: 24
                                            color: isItemSelected ? "#ef4444" : "#f1f5f9"
                                            radius: 12
                                            anchors.top: parent.top
                                            anchors.left: parent.left
                                            anchors.margins: 8
                                            visible: batchDeleteMode
                                            
                                            property bool isItemSelected: selectedImages.indexOf(modelData) !== -1
                                            
                                            border.color: isItemSelected ? "#dc2626" : "#cbd5e1"
                                            border.width: 2
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: batchSelector.isItemSelected ? "✓" : ""
                                                color: "#ffffff"
                                                font.pixelSize: 12
                                                font.bold: true
                                            }
                                            
                                            // 选中状态动画
                                            Behavior on color {
                                                ColorAnimation { duration: 200 }
                                            }
                                            
                                            Behavior on scale {
                                                NumberAnimation { duration: 200; easing.type: Easing.OutBack }
                                            }
                                            
                                            // 悬停效果
                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onEntered: {
                                                    if (!batchSelector.isItemSelected) {
                                                        parent.scale = 1.1
                                                        parent.color = "#e2e8f0"
                                                    }
                                                }
                                                onExited: {
                                                    if (!batchSelector.isItemSelected) {
                                                        parent.scale = 1.0
                                                        parent.color = "#f1f5f9"
                                                    }
                                                }
                                            }
                                        }
                                        
                                        Behavior on scale {
                                            NumberAnimation { duration: 200; easing.type: Easing.OutBack }
                                        }
                                        
                                        Behavior on color {
                                            ColorAnimation { duration: 300 }
                                        }
                                    }
                                }
                            }
                        }
                        Column {
                            anchors.centerIn: parent
                            visible: playerBackend.backgroundImageList.length === 0
                            spacing: 20
                            
                            Rectangle {
                                width: 80
                                height: 80
                                color: "#f1f5f9"
                                radius: 40
                                border.color: "#e2e8f0"
                                border.width: 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: "🖼️"
                                    color: "#94a3b8"
                                    font.pixelSize: 40
                                    
                                    // 柔和浮动动画
                                    SequentialAnimation on y {
                                        loops: Animation.Infinite
                                        NumberAnimation { to: -5; duration: 2500; easing.type: Easing.InOutQuad }
                                        NumberAnimation { to: 5; duration: 2500; easing.type: Easing.InOutQuad }
                                    }
                                }
                                
                                // 旋转光环
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -10
                                    color: "transparent"
                                    radius: 50
                                    border.width: 1
                                    border.color: "#e2e8f033"
                                    
                                    RotationAnimation on rotation {
                                        from: 0
                                        to: 360
                                        duration: 12000
                                        loops: Animation.Infinite
                                    }
                                }
                            }
                            
                            Text {
                                text: "还没有背景图片"
                                color: "#475569"
                                font.pixelSize: 18
                                font.bold: true
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            
                            Text {
                                text: "点击下方按钮添加您喜欢的背景图片"
                                color: "#94a3b8"
                                font.pixelSize: 14
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                    
                    // 简约科技风格控制按钮区域
                    Rectangle {
                        width: parent.width
                        height: 80
                        color: "#f8fafc"
                        radius: 16
                        border.color: "#e2e8f0"
                        border.width: 1
                        
                        // 内部柔和边框
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            color: "transparent"
                            radius: 14
                            border.width: 1
                            border.color: "#f1f5f9"
                        }
                        
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 20
                            spacing: 15
                            
                            // 添加背景图片按钮
                            Rectangle {
                                width: 160
                                height: 45
                                color: "#ffffff"
                                radius: 22
                                border.color: "#0ea5e9"
                                border.width: 2
                                
                                // 柔和阴影效果
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: -3
                                    color: "transparent"
                                    radius: 25
                                    border.width: 2
                                    border.color: "#0ea5e922"
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    
                                    onEntered: {
                                        parent.color = "#f0f9ff"
                                        parent.scale = 1.03
                                    }
                                    
                                    onExited: {
                                        parent.color = "#ffffff"
                                        parent.scale = 1.0
                                    }
                                    
                                    onPressed: {
                                        parent.scale = 0.97
                                    }
                                    
                                    onReleased: {
                                        parent.scale = 1.03
                                    }
                                    
                                    onClicked: {
                                        batchBackgroundImageDialog.open()
                                    }
                                }
                                
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 15
                                    
                                    Text {
                                        text: "添加背景"
                                        color: "#0ea5e9"
                                        font.pixelSize: 14
                                        font.bold: true
                                    }
                                }
                                
                                Behavior on color {
                                    ColorAnimation { duration: 200 }
                                }
                                
                                Behavior on scale {
                                    NumberAnimation { duration: 200; easing.type: Easing.OutBack }
                                }
                            }
                            
                            // 批量删除按钮
                            Rectangle {
                                width: 160
                                height: 45
                                color: batchDeleteMode ? "#fee2e2" : "#ffffff"
                                radius: 22
                                border.color: "#ef4444"
                                border.width: 2
                                
                                // 移除外层黑色边框，只保留内层红色边框
                                
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    
                                    onEntered: {
                                        parent.color = batchDeleteMode ? "#fecaca" : "#fef2f2"
                                        parent.scale = 1.03
                                    }
                                    
                                    onExited: {
                                        parent.color = batchDeleteMode ? "#fee2e2" : "#ffffff"
                                        parent.scale = 1.0
                                    }
                                    
                                    onPressed: {
                                        parent.scale = 0.97
                                    }
                                    
                                    onReleased: {
                                        parent.scale = 1.03
                                    }
                                    
                                    onClicked: {
                                            if (batchDeleteMode) {
                                                // 执行批量删除
                                                performBatchDelete()
                                            } else {
                                                // 进入批量选择模式：重新赋空数组以触发绑定
                                                batchDeleteMode = true
                                                selectedImages = []
                                            }
                                        }
                                }
                                
                                Row {
                                    anchors.centerIn: parent
                                    spacing: 15
                                    
                                    Text {
                                        text: batchDeleteMode ? "确认删除" : "批量删除"
                                        color: "#ef4444"
                                        font.pixelSize: 14
                                        font.bold: true
                                    }
                                }
                                
                                Behavior on color {
                                    ColorAnimation { duration: 200 }
                                }
                                
                                Behavior on scale {
                                    NumberAnimation { duration: 200; easing.type: Easing.OutBack }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // 右键菜单 - 浅色调未来感设计
        Rectangle {
            id: contextMenu
            width: 200
            height: 75
            visible: false
            color: "#ffffff"
            radius: 12
            border.color: "#e2e8f0"
            border.width: 1
            z: 1000
            
            property string targetImagePath: ""
            property int targetImageIndex: -1
            property real menuX: 0
            property real menuY: 0
            
            // 柔和阴影效果
            Rectangle {
                anchors.fill: parent
                anchors.margins: -2
                color: "transparent"
                radius: 14
                border.width: 1
                border.color: "#f1f5f9"
            }
            
            // 悬浮阴影
            MultiEffect {
                anchors.fill: parent
                source: contextMenu
                shadowEnabled: true
                shadowBlur: 0.8
                shadowColor: "#10000000"
                shadowVerticalOffset: 6
                shadowHorizontalOffset: 0
                visible: contextMenu.visible
            }
            
            // 菜单标题
            Rectangle {
                id: menuHeader
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 1
                anchors.leftMargin: 1
                anchors.rightMargin: 1
                height: 35
                color: "#f8fafc"
                radius: 11
                border.color: "#e2e8f0"
                border.width: 1
                
                Text {
                    text: "🖼️ 图片操作"
                    color: "#475569"
                    font.pixelSize: 13
                    font.bold: true
                    anchors.centerIn: parent
                }
            }
            
            // 菜单项容器
            Column {
                anchors.top: menuHeader.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 8
                spacing: 4
                
                // 设为背景按钮
                Rectangle {
                    width: parent.width
                    height: 32
                    color: "#ffffff"
                    radius: 8
                    border.color: "#e2e8f0"
                    border.width: 1
                    
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        
                        onEntered: {
                            parent.color = "#f0f9ff"
                            parent.border.color = "#0ea5e9"
                        }
                        
                        onExited: {
                            parent.color = "#ffffff"
                            parent.border.color = "#e2e8f0"
                        }
                        
                        onClicked: {
                            playerBackend.setBackgroundByIndex(contextMenu.targetImageIndex)
                            contextMenu.visible = false
                        }
                    }
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        
                        Text {
                            text: "🎨"
                            font.pixelSize: 14
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Text {
                            text: "设为背景"
                            color: "#0ea5e9"
                            font.pixelSize: 13
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                    
                    Behavior on border.color {
                        ColorAnimation { duration: 150 }
                    }
                }
            }
            
            Behavior on visible {
                NumberAnimation { duration: 200 }
            }
            
            Behavior on opacity {
                NumberAnimation { duration: 150 }
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

    // 执行批量删除函数
    function performBatchDelete() {
        if (!selectedImages || selectedImages.length === 0) {
            batchDeleteMode = false
            return
        }
        
        // 将选中的路径转换为当前 model 的索引（可能有未找到的项，忽略之）
        var indicesToDelete = []
        for (var i = 0; i < selectedImages.length; i++) {
            var idx = playerBackend.backgroundImageList.indexOf(selectedImages[i])
            if (idx !== -1) indicesToDelete.push(idx)
        }
        
        // 从大到小删除以避免索引错位
        indicesToDelete.sort(function(a,b){ return b - a })
        
        for (var j = 0; j < indicesToDelete.length; j++) {
            playerBackend.removeBackgroundImageByIndex(indicesToDelete[j])
        }
        
        // 清空并退出批量模式（重新赋空数组以触发绑定）
        selectedImages = []
        batchDeleteMode = false
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
        id: mainContextMenu
        visible: !root.isDocked && visible

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
            text: "   管理背景图片..."
            visible: !root.isDocked
            onTriggered: {
                backgroundManagerDialog.open()
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

        MenuSeparator {}

        MenuItem {
            text: "   关闭应用"
            onTriggered: {
                Qt.quit()
            }
        }
    }
}
