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

    // 垂直布局：歌曲名称在上方，唱片和按钮在下方
    ColumnLayout {
        id: mainColumn
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        // 歌名显示在唱片上方
        Text {
            id: songName
            text: (playerBackend && playerBackend.title) ? playerBackend.title : "No Track Playing"
            font.pixelSize: 14
            color: "white"
            horizontalAlignment: Text.AlignLeft
            Layout.fillWidth: true
            Layout.preferredHeight: 18
            
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

        // 唱片和控制按钮区域
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 120

            // 展开功能的MouseArea - 在按钮容器级别，排除唱片和扇形按钮区域
            MouseArea {
                anchors.fill: parent
                // 使用位置判断排除唱片和扇形按钮区域
                onClicked: function(mouse) {
                    // 唱片在此容器中的相对位置
                    var discX = parent.width - 100  // parent.width - 唱片宽度
                    var discY = parent.height / 2 - 50  // anchors.verticalCenter - height/2
                    var discWidth = 100
                    var discHeight = 100
                    
                    // 扇形按钮区域位置（围绕唱片）
                    var sectorCenterX = parent.width / 2
                    var sectorCenterY = parent.height / 2
                    var sectorOuterRadius = 70  // 扇形外径
                    var sectorInnerRadius = 55  // 扇形内径
                    
                    // 计算点击位置到扇形中心的距离
                    var dx = mouse.x - sectorCenterX
                    var dy = mouse.y - sectorCenterY
                    var distance = Math.sqrt(dx * dx + dy * dy)
                    
                    // 计算点击位置的角度（从正右方向开始，顺时针为正）
                    var angle = Math.atan2(dy, dx)
                    if (angle < 0) angle += 2 * Math.PI
                    
                    // 转换为度数（0度在正右方，90度在正下方）
                    var angleDegrees = angle * 180 / Math.PI
                    
                    // 检查点击是否在唱片区域内
                    var clickInDisc = (mouse.x >= discX && mouse.x <= discX + discWidth &&
                                       mouse.y >= discY && mouse.y <= discY + discHeight)
                    
                    // 检查点击是否在扇形按钮区域内
                    var clickInSector = (distance >= sectorInnerRadius && distance <= sectorOuterRadius &&
                                        ((angleDegrees >= 90 && angleDegrees <= 180) ||   // 6点到9点（下一首）
                                         (angleDegrees >= 180 && angleDegrees <= 270)))   // 9点到12点（上一首）
                    
                    // 只有在非唱片区域且非扇形按钮区域点击时才触发展开
                    if (!clickInDisc && !clickInSector) {
                        root.expandRequested()
                    }
                }
            }

            // ---------------------------
            // 扇形控制按钮区域（围绕唱片底部）
            // ---------------------------
            Item {
                id: sectorButtons
                anchors.centerIn: disc
                width: disc.width + 40  // 扇形按钮的外径
                height: disc.height + 40
                z: 6

                // 供两个Canvas共享的扇形点判断函数
                function pointInSector(mouseX, mouseY, innerR, outerR, startDeg, endDeg) {
                    var cx = width / 2;
                    var cy = height / 2;
                    var dx = mouseX - cx;
                    var dy = mouseY - cy;
                    var dist = Math.sqrt(dx*dx + dy*dy);
                    if (dist < innerR || dist > outerR) return false;
                    var angle = Math.atan2(dy, dx);
                    if (angle < 0) angle += 2 * Math.PI;
                    var deg = angle * 180 / Math.PI;
                    // normalize start/end (assume startDeg < endDeg and within [0,360])
                    return (deg >= startDeg && deg <= endDeg);
                }

                // 统一的MouseArea处理所有悬停事件
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    
                    onPositionChanged: {
                        var outerRadius = parent.width / 2;
                        var innerRadius = disc.width / 2 + 5;
                        
                        // 检查下一首按钮悬停状态
                        var nextWasHovered = nextButton.isHovered;
                        nextButton.isHovered = sectorButtons.pointInSector(mouse.x, mouse.y, innerRadius, outerRadius, 90, 180);
                        if (nextWasHovered !== nextButton.isHovered) {
                            nextButton.requestPaint();
                        }
                        
                        // 检查上一首按钮悬停状态
                        var prevWasHovered = prevButton.isHovered;
                        prevButton.isHovered = sectorButtons.pointInSector(mouse.x, mouse.y, innerRadius, outerRadius, 180, 270);
                        if (prevWasHovered !== prevButton.isHovered) {
                            prevButton.requestPaint();
                        }
                    }
                    
                    onExited: { 
                        nextButton.isHovered = false; 
                        prevButton.isHovered = false;
                        nextButton.requestPaint();
                        prevButton.requestPaint();
                    }
                    
                    onClicked: {
                        var outerRadius = parent.width / 2;
                        var innerRadius = disc.width / 2 + 5;
                        
                        if (sectorButtons.pointInSector(mouse.x, mouse.y, innerRadius, outerRadius, 90, 180)) {
                            if (playerBackend) playerBackend.next();
                        } else if (sectorButtons.pointInSector(mouse.x, mouse.y, innerRadius, outerRadius, 180, 270)) {
                            if (playerBackend) playerBackend.previous();
                        }
                    }
                }

                // 下一首按钮（覆盖 6 点钟到 9 点钟）
                Canvas {
                    id: nextButton
                    anchors.fill: parent
                    z: 1  // 与上一首按钮相同的层级，通过事件处理避免冲突
                    
                    property bool isHovered: false
                    
                    onPaint: {
                        var ctx = getContext("2d")
                        var centerX = width / 2
                        var centerY = height / 2
                        var outerRadius = width / 2
                        var innerRadius = disc.width / 2 + 5
                        
                        ctx.clearRect(0, 0, width, height)
                        
                        ctx.beginPath()
                        // 外圆弧：从 6 点 (π/2) → 9 点 (π)
                        ctx.arc(centerX, centerY, outerRadius, 
                                Math.PI * 0.4,   // 6 点
                                Math.PI * 1.0)   // 9 点 (逆时针)
                        // 内圆弧：从 9 点 (π) → 6 点 (π/2) 逆向回去
                        ctx.arc(centerX, centerY, innerRadius, 
                                Math.PI * 1.0, 
                                Math.PI * 0.5, true)
                        ctx.closePath()
                        
                        ctx.fillStyle = isHovered ? "#40FFFFFF" : "#30FFFFFF"
                        ctx.fill()
                        ctx.strokeStyle = "#60FFFFFF"
                        ctx.lineWidth = 1
                        ctx.stroke()
                    }
                    

                    
                    // 图标
                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: parent.height * 0.28
                        text: "▶"
                        font.pixelSize: 16
                        color: "white"
                        style: Text.Outline
                        styleColor: "black"
                        rotation: -90   // 指向上方的箭头，符合扇形方向
                    }
                }

                // 上一首按钮（覆盖 9 点钟到 12 点钟）
                Canvas {
                    id: prevButton
                    anchors.fill: parent
                    z: 1  // 与下一首按钮相同的层级，通过事件处理避免冲突
                    
                    property bool isHovered: false
                    
                    onPaint: {
                        var ctx = getContext("2d")
                        var centerX = width / 2
                        var centerY = height / 2
                        var outerRadius = width / 2
                        var innerRadius = disc.width / 2 + 5
                        
                        ctx.clearRect(0, 0, width, height)
                        
                        ctx.beginPath()
                        // 外圆弧：9 点 (π) → 12 点 (3π/2)
                        ctx.arc(centerX, centerY, outerRadius, 
                                Math.PI * 1.0,        // 9 点
                                Math.PI * 1.6)        // 12 点 (逆时针到 3π/2)
                        // 内圆弧：12 点 → 9 点（逆时针）
                        ctx.arc(centerX, centerY, innerRadius, 
                                Math.PI * 1.5, 
                                Math.PI * 1.0, true)
                        ctx.closePath()
                        
                        ctx.fillStyle = isHovered ? "#40FFFFFF" : "#30FFFFFF"
                        ctx.fill()
                        ctx.strokeStyle = "#60FFFFFF"
                        ctx.lineWidth = 1
                        ctx.stroke()
                    }
                    

                    
                    // 图标
                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: parent.height * -0.28
                        text: "◀"
                        font.pixelSize: 16
                        color: "white"
                        style: Text.Outline
                        styleColor: "black"
                        rotation: 90     // 指向下方，符合扇形方向
                    }
                }
            }

            // ---------------------------
            // 旋转唱片（简化显示，不使用裁剪）
            // 圆盘：直径 100px（radius = 50），适应dock模式
            // ---------------------------
            Rectangle {
                id: disc
                width: 100
                height: 100
                radius: width / 2
                anchors.right: parent.right
                anchors.rightMargin: -50  // 唱片中心线贴合右边
                anchors.verticalCenter: parent.verticalCenter
                color: "transparent"
                border.color: "#55FFFFFF"
                border.width: 2
                z: 100  // 确保在最顶层，高于扇形按钮和展开区域
                
                // 添加缩放动画
                Behavior on scale {
                    NumberAnimation { duration: 150 }
                }

                // 唱片鼠标区域 - 用于检测悬停和点击播放/暂停
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    z: 200  // 确保在所有其他元素之上
                    
                    onEntered: {
                        parent.scale = 1.05  // 悬停时轻微放大
                    }
                    onExited: {
                        parent.scale = 1.0  // 恢复原始大小
                    }
                    onClicked: {
                        if (playerBackend) {
                            playerBackend.togglePlay()  // 点击唱片播放/暂停
                        }
                    }
                    
                    // 阻止事件传播，防止触发展开功能
                    onPressed: {
                        mouse.accepted = true
                    }
                }

                // 唱片主体
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "#2a2a2a"  // 深色背景，模拟唱片
                    border.color: "#55FFFFFF"
                    border.width: 2

                    // 封面图片
                    Image {
                        id: coverImage
                        anchors.centerIn: parent
                        width: 86
                        height: 86
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
                        width: 121.5  // 2 * 半对角线长度 ≈ 121.5
                        height: 121.5
                        radius: width / 2
                        color: "transparent"
                        border.color: "#2a2a2a"  // 黑色圆环
                        border.width: 17.75  // 外半径(60.75) - 内半径(43) ≈ 17.75
                    }

                    // 中心小圆孔（唱片中央的小黑点，装饰用）
                    Rectangle {
                        width: 10
                        height: 10
                        radius: 5
                        color: "#202020"
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        z: 4
                        border.color: "#404040"
                        border.width: 1
                    }
                }

                // 旋转动画：匀速，4.5秒一圈，根据播放状态控制
                NumberAnimation {
                    target: rot
                    property: "angle"
                    id: spinAnim
                    from: 0
                    to: 360
                    duration: 4500  // 4.5秒一圈
                    loops: Animation.Infinite
                    running: playerBackend && playerBackend.isPlaying  // 只有在播放时才旋转
                    
                    // 添加调试信息
                    onRunningChanged: {
                        console.log("唱片旋转动画状态:", running, "播放状态:", playerBackend ? playerBackend.isPlaying : "N/A")
                    }
                }
                
                // 监听播放状态变化
                Connections {
                    target: playerBackend
                    function onIsPlayingChanged() {
                        if (playerBackend.isPlaying) {
                            spinAnim.start()
                        } else {
                            spinAnim.stop()
                        }
                    }
                }
            }
        }
    }
}