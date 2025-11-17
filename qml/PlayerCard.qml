import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"
import QtQuick.Effects

Rectangle {
    id: root
    
    signal volumeButtonClicked()
    
    radius: 16
    color: "#40FFFFFF"
    border.width: 0

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: root.radius
        color: "#10000000"
        z: -1
    }

    
    component ModernIcon: Canvas {
        id: iconRoot
        property color iconColor: "#ffffff"
        property real iconScale: 1.0
        property real iconSize: 24
        property string iconType: "play" // play, pause, prev, next, sequential, loopOne, loopAll, random, volume_low, volume_high, volume_muted
        
        width: iconSize
        height: iconSize
        
        antialiasing: true
        
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            
            ctx.save()
            
            var scale = iconSize / 24
            ctx.scale(scale, scale)
            
            ctx.strokeStyle = "#444444"
            ctx.lineWidth = 3
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            
            if (iconType === "play") {
                ctx.beginPath()
                ctx.moveTo(6, 4)
                ctx.lineTo(6, 20)
                ctx.lineTo(18, 12)
                ctx.closePath()
                ctx.stroke()
            } else if (iconType === "pause") {
                ctx.beginPath()
                ctx.moveTo(7, 6)
                ctx.lineTo(7, 18)
                ctx.moveTo(17, 6)
                ctx.lineTo(17, 18)
                ctx.stroke()
            } else if (iconType === "prev") {
                ctx.beginPath()
                ctx.moveTo(3, 5)
                ctx.lineTo(3, 19)
                ctx.moveTo(5, 12)
                ctx.lineTo(14, 5)
                ctx.lineTo(14, 19)
                ctx.closePath()
                ctx.stroke()
            } else if (iconType === "next") {
                ctx.beginPath()
                ctx.moveTo(19, 5)
                ctx.lineTo(19, 19)
                ctx.moveTo(19, 12)
                ctx.lineTo(8, 19)
                ctx.lineTo(8, 5)
                ctx.closePath()
                ctx.stroke()
            } else if (iconType === "sequential") {
                ctx.beginPath()
                ctx.moveTo(4, 8)
                ctx.lineTo(4, 16)
                ctx.lineTo(8, 16)
                ctx.lineTo(8, 8)
                ctx.closePath()
                ctx.moveTo(10, 6)
                ctx.lineTo(20, 12)
                ctx.lineTo(10, 18)
                ctx.stroke()
            } else if (iconType === "loopOne") {
                ctx.beginPath()
                ctx.arc(12, 12, 7, -Math.PI/4, Math.PI*1.25, false)
                ctx.moveTo(17, 7)
                ctx.lineTo(19, 5)
                ctx.lineTo(21, 7)
                ctx.moveTo(19, 5)
                ctx.lineTo(19, 9)
                ctx.moveTo(7, 17)
                ctx.lineTo(5, 19)
                ctx.lineTo(7, 21)
                ctx.moveTo(5, 19)
                ctx.lineTo(9, 19)
                ctx.stroke()
                
                 ctx.save()
                 ctx.font = "bold 7px Arial"
                 ctx.fillStyle = "#444444"
                 ctx.textAlign = "center"
                 ctx.textBaseline = "middle"
                 ctx.fillText("1", 12, 12)
                 ctx.restore()
            } else if (iconType === "loopAll") {
                ctx.beginPath()
                ctx.arc(12, 12, 7, -Math.PI/4, Math.PI*1.25, false)
                ctx.moveTo(17, 7)
                ctx.lineTo(19, 5)
                ctx.lineTo(21, 7)
                ctx.moveTo(19, 5)
                ctx.lineTo(19, 9)
                ctx.moveTo(7, 17)
                ctx.lineTo(5, 19)
                ctx.lineTo(7, 21)
                ctx.moveTo(5, 19)
                ctx.lineTo(9, 19)
                ctx.stroke()
            } else if (iconType === "random") {
                ctx.beginPath()
                ctx.moveTo(4, 8)
                ctx.lineTo(8, 8)
                ctx.lineTo(12, 12)
                ctx.lineTo(16, 8)
                ctx.lineTo(20, 8)
                ctx.moveTo(4, 16)
                ctx.lineTo(8, 16)
                ctx.lineTo(12, 12)
                ctx.lineTo(16, 16)
                ctx.lineTo(20, 16)
                ctx.moveTo(17, 6)
                ctx.lineTo(20, 8)
                ctx.lineTo(17, 10)
                ctx.moveTo(17, 14)
                ctx.lineTo(20, 16)
                ctx.lineTo(17, 18)
                ctx.stroke()
            } else if (iconType === "volume_low") {
                ctx.beginPath()
                ctx.moveTo(4, 8)
                ctx.lineTo(8, 8)
                ctx.lineTo(12, 4)
                ctx.lineTo(12, 20)
                ctx.lineTo(8, 16)
                ctx.lineTo(4, 16)
                ctx.closePath()
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(15, 10)
                ctx.quadraticCurveTo(17, 12, 15, 14)
                ctx.stroke()
            } else if (iconType === "volume_high") {
                ctx.beginPath()
                ctx.moveTo(4, 8)
                ctx.lineTo(8, 8)
                ctx.lineTo(12, 4)
                ctx.lineTo(12, 20)
                ctx.lineTo(8, 16)
                ctx.lineTo(4, 16)
                ctx.closePath()
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(15, 8)
                ctx.quadraticCurveTo(18, 12, 15, 16)
                ctx.moveTo(17, 6)
                ctx.quadraticCurveTo(20, 12, 17, 18)
                ctx.stroke()
            } else if (iconType === "volume_muted") {
                ctx.beginPath()
                ctx.moveTo(4, 8)
                ctx.lineTo(8, 8)
                ctx.lineTo(12, 4)
                ctx.lineTo(12, 20)
                ctx.lineTo(8, 16)
                ctx.lineTo(4, 16)
                ctx.closePath()
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(14, 10)
                ctx.lineTo(18, 14)
                ctx.moveTo(18, 10)
                ctx.lineTo(14, 14)
                ctx.stroke()
            }
            
            ctx.strokeStyle = iconColor
            ctx.lineWidth = 2
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            
            if (iconType === "play") {
                ctx.beginPath()
                ctx.moveTo(6, 4)
                ctx.lineTo(6, 20)
                ctx.lineTo(18, 12)
                ctx.closePath()
                ctx.stroke()
            } else if (iconType === "pause") {
                ctx.beginPath()
                ctx.moveTo(7, 6)
                ctx.lineTo(7, 18)
                ctx.moveTo(17, 6)
                ctx.lineTo(17, 18)
                ctx.stroke()
            } else if (iconType === "prev") {
                ctx.beginPath()
                ctx.moveTo(3, 5)
                ctx.lineTo(3, 19)
                ctx.moveTo(5, 12)
                ctx.lineTo(14, 5)
                ctx.lineTo(14, 19)
                ctx.closePath()
                ctx.stroke()
            } else if (iconType === "next") {
                ctx.beginPath()
                ctx.moveTo(19, 5)
                ctx.lineTo(19, 19)
                ctx.moveTo(19, 12)
                ctx.lineTo(8, 19)
                ctx.lineTo(8, 5)
                ctx.closePath()
                ctx.stroke()
            } else if (iconType === "sequential") {
                ctx.beginPath()
                ctx.moveTo(4, 8)
                ctx.lineTo(4, 16)
                ctx.lineTo(8, 16)
                ctx.lineTo(8, 8)
                ctx.closePath()
                ctx.moveTo(10, 6)
                ctx.lineTo(20, 12)
                ctx.lineTo(10, 18)
                ctx.stroke()
            } else if (iconType === "loopOne") {
                ctx.beginPath()
                ctx.arc(12, 12, 7, -Math.PI/4, Math.PI*1.25, false)
                ctx.moveTo(17, 7)
                ctx.lineTo(19, 5)
                ctx.lineTo(21, 7)
                ctx.moveTo(19, 5)
                ctx.lineTo(19, 9)
                ctx.moveTo(7, 17)
                ctx.lineTo(5, 19)
                ctx.lineTo(7, 21)
                ctx.moveTo(5, 19)
                ctx.lineTo(9, 19)
                ctx.stroke()
                
                ctx.save()
                ctx.font = "bold 7px Arial"
                ctx.textAlign = "center"
                ctx.textBaseline = "middle"
                
                ctx.strokeStyle = "#444444"
                ctx.lineWidth = 1
                ctx.strokeText("1", 12, 12)
                
                ctx.fillStyle = "#ffffff"
                ctx.fillText("1", 12, 12)
                
                ctx.restore()
            } else if (iconType === "loopAll") {
                ctx.beginPath()
                ctx.arc(12, 12, 7, -Math.PI/4, Math.PI*1.25, false)
                ctx.moveTo(17, 7)
                ctx.lineTo(19, 5)
                ctx.lineTo(21, 7)
                ctx.moveTo(19, 5)
                ctx.lineTo(19, 9)
                ctx.moveTo(7, 17)
                ctx.lineTo(5, 19)
                ctx.lineTo(7, 21)
                ctx.moveTo(5, 19)
                ctx.lineTo(9, 19)
                ctx.stroke()
            } else if (iconType === "random") {
                ctx.beginPath()
                ctx.moveTo(4, 8)
                ctx.lineTo(8, 8)
                ctx.lineTo(12, 12)
                ctx.lineTo(16, 8)
                ctx.lineTo(20, 8)
                ctx.moveTo(4, 16)
                ctx.lineTo(8, 16)
                ctx.lineTo(12, 12)
                ctx.lineTo(16, 16)
                ctx.lineTo(20, 16)
                ctx.moveTo(17, 6)
                ctx.lineTo(20, 8)
                ctx.lineTo(17, 10)
                ctx.moveTo(17, 14)
                ctx.lineTo(20, 16)
                ctx.lineTo(17, 18)
                ctx.stroke()
            } else if (iconType === "volume_low") {
                ctx.beginPath()
                ctx.moveTo(4, 8)
                ctx.lineTo(8, 8)
                ctx.lineTo(12, 4)
                ctx.lineTo(12, 20)
                ctx.lineTo(8, 16)
                ctx.lineTo(4, 16)
                ctx.closePath()
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(15, 10)
                ctx.quadraticCurveTo(17, 12, 15, 14)
                ctx.stroke()
            } else if (iconType === "volume_high") {
                ctx.beginPath()
                ctx.moveTo(4, 8)
                ctx.lineTo(8, 8)
                ctx.lineTo(12, 4)
                ctx.lineTo(12, 20)
                ctx.lineTo(8, 16)
                ctx.lineTo(4, 16)
                ctx.closePath()
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(15, 8)
                ctx.quadraticCurveTo(18, 12, 15, 16)
                ctx.moveTo(17, 6)
                ctx.quadraticCurveTo(20, 12, 17, 18)
                ctx.stroke()
            } else if (iconType === "volume_muted") {
                ctx.beginPath()
                ctx.moveTo(4, 8)
                ctx.lineTo(8, 8)
                ctx.lineTo(12, 4)
                ctx.lineTo(12, 20)
                ctx.lineTo(8, 16)
                ctx.lineTo(4, 16)
                ctx.closePath()
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(14, 10)
                ctx.lineTo(18, 14)
                ctx.moveTo(18, 10)
                ctx.lineTo(14, 14)
                ctx.stroke()
            }
            
            ctx.restore()
        }
    }
    
    RowLayout {
        anchors.fill: parent
        spacing: 32
        
        Rectangle {
            Layout.preferredWidth: 160
            Layout.preferredHeight: 160
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: 20
            
            color: "transparent"
            radius: 16
            border.color: "#ffffff"
            border.width: 1
            
            Rectangle {
                anchors.fill: parent
                anchors.margins: -4
                color: "transparent"
                border.color: "#4a9eff15"
                border.width: 1
                radius: 20
            }
            
            Image {
                id: albumCover
                anchors.fill: parent
                anchors.margins: 12
                source: playerBackend.cover || "qrc:/assets/default_cover.svg"
                fillMode: Image.PreserveAspectFit
                smooth: true
                
                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: albumCover.height / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#00000000" }
                        GradientStop { position: 1.0; color: "#00000020" }
                    }
                }
            }
        }
        
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 20
            
            Column {
                Layout.fillWidth: true
                spacing: 6
                
                Text {
                    text: playerBackend.title || "No Track Playing"
                    font.pixelSize: 20
                    color: "#ffffff"
                    font.family: "Segoe UI, sans-serif"
                    font.weight: Font.Light
                    lineHeight: 1.2
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    style: Text.Outline
                    styleColor: "#888888"
                }
                
                Text {
                    text: playerBackend.artist || "Unknown Artist"
                    font.pixelSize: 14
                    color: "#e9f7ff"
                    font.family: "Segoe UI, sans-serif"
                    font.weight: Font.Light
                    opacity: 0.7
                    Layout.fillWidth: true
                    style: Text.Outline
                    styleColor: "#ffffff"
                }
            }
            
            Column {
                Layout.fillWidth: true
                spacing: 10
                
                Slider {
                    id: progressBar
                    Layout.fillWidth: true
                    Layout.minimumWidth: 500
                    from: 0
                    to: playerBackend.duration || 100
                    value: playerBackend.position
                    
                    background: Rectangle {
                        x: parent.leftPadding
                        y: parent.topPadding + parent.availableHeight / 2 - height / 2
                        implicitWidth: 500
                        implicitHeight: 3
                        width: parent.availableWidth
                        height: implicitHeight
                        radius: 2
                        color: "#ffffff"
                        
                        Rectangle {
                            width: parent.width * (progressBar.value - progressBar.from) / (progressBar.to - progressBar.from)
                            height: parent.height
                            radius: 2
                            color: "#4a9eff"
                            
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -2
                                color: "transparent"
                                border.color: "#4a9eff30"
                                border.width: 1
                                radius: 4
                            }
                        }
                    }
                    
                    handle: Rectangle {
                        x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                        y: parent.topPadding + parent.availableHeight / 2 - height / 2
                        implicitWidth: 14
                        implicitHeight: 14
                        radius: 7
                        color: "#ffffff"
                        border.color: "#4a9eff"
                        border.width: 2
                        
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -4
                            color: "transparent"
                            border.color: "#4a9eff30"
                            border.width: 1
                            radius: 11
                        }
                    }
                    
                    onMoved: playerBackend.setPosition(value)
                }
                
                Row {
                    Layout.fillWidth: true
                    spacing: 15
                    
                    Text {
                        text: formatTime(playerBackend.position)
                        color: "#ffffff"
                        font.pixelSize: 12
                        font.family: "Consolas, monospace"
                        opacity: 0.8
                    }
                    
                    Item { Layout.fillWidth: true }
                    
                    Text {
                        text: formatTime(playerBackend.duration)
                        color: "#ffffff"
                        font.pixelSize: 12
                        font.family: "Consolas, monospace"
                        opacity: 0.8
                    }
                }
            }
            
            // Enhanced control buttons with modern icons
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 20
                
                ModernIcon {
                    iconType: {
                        switch(playerBackend.playMode) {
                            case 1: return "loopOne"
                            case 2: return "loopAll"
                            case 3: return "random"
                            default: return "loopOne"
                        }
                    }
                    iconSize: 32
                    iconColor: "#ffffff"
                    opacity: 0.8
                    anchors.verticalCenter: parent.verticalCenter
                    
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.opacity = 1.0
                        onExited: parent.opacity = 0.8
                        onClicked: playerBackend.togglePlayMode()
                    }
                }
                
                ModernIcon {
                    iconType: "prev"
                    iconSize: 36
                    iconColor: "#ffffff"
                    anchors.verticalCenter: parent.verticalCenter
                    
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.opacity = 0.8
                        onExited: parent.opacity = 1.0
                        onClicked: playerBackend.previous()
                    }
                }
                
                Rectangle {
                    width: 50
                    height: 50
                    radius: 25
                    color: "#4a9eff"
                    anchors.verticalCenter: parent.verticalCenter
                    
                    ModernIcon {
                        anchors.centerIn: parent
                        iconType: playerBackend.isPlaying ? "pause" : "play"
                        iconSize: 24
                        iconColor: "#ffffff"
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.color = "#5aa8ff"
                        onExited: parent.color = "#4a9eff"
                        onClicked: playerBackend.togglePlay()
                    }
                }
                
                ModernIcon {
                    iconType: "next"
                    iconSize: 36
                    iconColor: "#ffffff"
                    anchors.verticalCenter: parent.verticalCenter
                    
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.opacity = 0.8
                        onExited: parent.opacity = 1.0
                        onClicked: playerBackend.next()
                    }
                }
                
                ModernIcon {
                    iconType: playerBackend.isMuted ? "volume_muted" : (playerBackend.volume > 0.5 ? "volume_high" : "volume_low")
                    iconSize: 32
                    iconColor: "#ffffff"
                    opacity: 0.8
                    anchors.verticalCenter: parent.verticalCenter
                    
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.opacity = 1.0
                        onExited: parent.opacity = 0.8
                        onClicked: root.volumeButtonClicked()
                    }
                }
            }
        }
    }
    
    function formatTime(milliseconds) {
        if (!milliseconds || milliseconds <= 0) return "0:00"
        
        var totalSeconds = Math.floor(milliseconds / 1000)
        var minutes = Math.floor(totalSeconds / 60)
        var seconds = totalSeconds % 60
        
        return minutes + ":" + (seconds < 10 ? "0" + seconds : seconds)
    }
}