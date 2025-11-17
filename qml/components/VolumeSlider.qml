import QtQuick
import QtQuick.Controls

Item {
    id: volumeSlider
    
    // 组件属性
    width: 120
    height: 40
    visible: false
    z: 10
    
    Rectangle {
        id: volumeTrack
        width: parent.width - 20
        height: 4
        anchors.centerIn: parent
        color: "#ffffff30"
        radius: 2
        
        Rectangle {
            id: volumeFill
            width: volumeTrack.width * playerBackend.volume
            height: parent.height
            color: "#4a9eff"
            radius: 2
        }
        
        Rectangle {
            id: volumeHandle
            width: 16
            height: 16
            radius: 8
            color: "#ffffff"
            anchors.verticalCenter: parent.verticalCenter
            x: volumeTrack.width * playerBackend.volume - width/2
            
            Rectangle {
                anchors.fill: parent
                anchors.margins: -4
                color: "transparent"
                border.color: "#4a9eff40"
                border.width: 2
                radius: parent.radius + 4
            }
            
            Rectangle {
                width: 6
                height: 6
                radius: 3
                color: "#4a9eff"
                anchors.centerIn: parent
            }
        }
    }
    
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        
        onClicked: {
            var relativeX = mouse.x - volumeTrack.x
            var newValue = Math.max(0, Math.min(1, relativeX / volumeTrack.width))
            playerBackend.setVolume(newValue)
        }
        
        onPositionChanged: {
            if (pressed) {
                var relativeX = mouse.x - volumeTrack.x
                var newValue = Math.max(0, Math.min(1, relativeX / volumeTrack.width))
                playerBackend.setVolume(newValue)
            }
        }
        
        onEntered: {
            volumeHandle.scale = 1.2
        }
        
        onExited: {
            volumeHandle.scale = 1.0
        }
    }
    
    Behavior on scale {
        PropertyAnimation {
            duration: 150
            easing.type: Easing.OutQuad
        }
    }
}