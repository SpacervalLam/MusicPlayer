import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    radius: 14
    color: "#40FFFFFF"      // 半透明玻璃背景
    border.width: 0

    // 添加 playerBackend 属性
    property var playerBackend

    // 点击展开信号
    signal expandRequested()

    // 简化的阴影效果（使用Rectangle模拟）
    Rectangle {
        anchors.fill: parent
        anchors.margins: -2
        radius: root.radius
        color: "#10000000"
        z: -1
    }

    // 垂直布局：歌曲名称在上方，唱片在下方
    ColumnLayout {
        id: mainColumn
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // 歌名显示在唱片上方
        Text {
            id: songName
            text: (playerBackend && playerBackend.title) ? playerBackend.title : "No Track Playing"
            font.pixelSize: 15
            color: "white"
            horizontalAlignment: Text.AlignLeft
            Layout.fillWidth: true
            Layout.minimumWidth: 100
            Layout.preferredHeight: 20
            
            // 添加黑色描边效果
            style: Text.Outline
            styleColor: "black"
            
            // 使用简单的阴影效果（通过多个偏移的文本模拟）
            Text {
                id: shadow1
                anchors.fill: songName
                text: songName.text
                font: songName.font
                color: "black"
                opacity: 0.5
                x: 1
                y: 1
                z: songName.z - 1
            }
            
            Text {
                id: shadow2
                anchors.fill: songName
                text: songName.text
                font: songName.font
                color: "black"
                opacity: 0.3
                x: 2
                y: 2
                z: songName.z - 2
            }

            // 滚动动画
            PropertyAnimation on x {
                id: scrollAnim
                running: false
                loops: Animation.Infinite
                duration: 6000  // 增加滚动时间，让用户有足够时间阅读
                from: 0
                to: -songName.width - 100  // 滚动完全离开视野
                easing.type: Easing.Linear
            }

            Component.onCompleted: {
                checkWidth()
            }

            onWidthChanged: {
                checkWidth()
            }

            onTextChanged: {
                checkWidth()
            }

            function checkWidth() {
                // 计算可用宽度（减去左右边距）
                var availableWidth = root.width - 20
                if (availableWidth < 50) availableWidth = 50
                
                // 不使用截断，直接滚动显示完整内容
                if (songName.implicitWidth > availableWidth) {
                    if (!scrollAnim.running) {
                        scrollAnim.from = 0
                        scrollAnim.to = -songName.width - 100  // 确保完全离开视野
                        scrollAnim.running = true
                    }
                } else {
                    scrollAnim.running = false
                    x = 0
                }
            }
        }

        // 唱片区域
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 140

            // ---------------------------
            // 旋转唱片（简化显示，不使用裁剪）
            // 圆盘：直径 140px（radius = 70），显示完整的圆形
            // ---------------------------
            Rectangle {
                id: disc
                width: 140
                height: 140
                radius: width / 2
                anchors.right: parent.right
                anchors.rightMargin: -70  // 唱片中心线贴合右边
                anchors.verticalCenter: parent.verticalCenter
                color: "transparent"
                border.color: "#55FFFFFF"
                border.width: 3
                z: 5

                // 唱片主体
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "#2a2a2a"  // 深色背景，模拟唱片
                    border.color: "#55FFFFFF"
                    border.width: 3

                    // 简单方案：直接显示封面图片 + 覆盖黑色圆环
                Image {
                    id: coverImage
                    anchors.centerIn: parent
                    width: 120
                    height: 120
                    source: (playerBackend && playerBackend.cover) ? playerBackend.cover : "qrc:/assets/default_cover.svg"
                    smooth: true
                    cache: true
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop

                    // 旋转：以图像中心为原点
                    transform: Rotation {
                        id: rot
                        origin.x: coverImage.width / 2
                        origin.y: coverImage.height / 2
                        angle: 0
                    }
                }
                
                // 精确计算的黑色圆环：外半径=半对角线，内半径=半边长
                Rectangle {
                    anchors.centerIn: parent
                    width: 169.71  // 2 * 半对角线长度 ≈ 169.71
                    height: 169.71
                    radius: width / 2
                    color: "transparent"
                    border.color: "#2a2a2a"  // 黑色圆环
                    border.width: 24.85  // 外半径(84.85) - 内半径(60) ≈ 24.85
                }

                    // 中心小圆孔（唱片中央的小黑点，装饰用）
                    Rectangle {
                        width: 14
                        height: 14
                        radius: 7
                        color: "#202020"
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        z: 4
                        border.color: "#404040"
                        border.width: 1
                    }
                }

                // 旋转动画：匀速，4.5秒一圈
                NumberAnimation {
                    target: rot
                    property: "angle"
                    id: spinAnim
                    from: 0
                    to: 360
                    duration: 4500  // 4.5秒一圈
                    loops: Animation.Infinite
                    running: true  // 持续旋转
                    
                    // 添加调试信息
                    onRunningChanged: {
                        console.log("唱片旋转动画状态:", running)
                    }
                }
            }
        }
    }

    // 点击展开功能（保留）
    MouseArea {
        anchors.fill: parent
        onClicked: {
            // 发送展开请求信号
            root.expandRequested()
        }
    }
}
