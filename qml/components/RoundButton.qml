import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    
    property alias text: buttonText.text
    property int size: 48
    property bool highlighted: false
    
    width: size
    height: size
    radius: size / 2
    
    color: highlighted ? "#ffffff40" : "#ffffff25"
    border.color: highlighted ? "#ffffff60" : "#ffffff40"
    border.width: 2
    
    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: parent.radius - 2
        color: "#ffffff10"
        
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#ffffff30" }
            GradientStop { position: 1.0; color: "#ffffff10" }
        }
    }
    
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        
        onEntered: {
            parent.color = highlighted ? "#ffffff50" : "#ffffff35"
            parent.scale = 1.05
        }
        
        onExited: {
            parent.color = highlighted ? "#ffffff40" : "#ffffff25"
            parent.scale = 1.0
        }
        
        onClicked: root.clicked()
    }
    
    Text {
        id: buttonText
        anchors.centerIn: parent
        color: "#ffffff"
        font.pixelSize: size * 0.4
        font.family: "Microsoft YaHei, sans-serif"
        font.bold: highlighted
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    
    Behavior on scale {
        NumberAnimation { duration: 50; easing.type: Easing.OutQuad }
    }
    
    signal clicked()
}