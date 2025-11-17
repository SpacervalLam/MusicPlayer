import QtQuick 2.15
import QtQuick.Controls 2.15

Item {
    id: root
    // size should be provided by parent or by explicit width/height
    width: barCount * (barWidth + spacing) - spacing
    height: 160

    property int barCount: 60
    property real audioLevel: 0.0    // 0.0 .. 1.0 (bind to playerBackend.audioLevel)
    property bool isPlaying: false   // bind to playerBackend.isPlaying
    property var spectrum: []   // bind: spectrum: playerBackend.spectrum

    // visual tuning
    property real barWidth: 4
    property real spacing: 2
    property real minBarHeight: 4
    property real maxBarHeight: 27

    // Remove anchors.centerIn: parent to let parent container handle centering

    // subtle background glow (behind all bars)
    Rectangle {
        anchors.fill: parent
        color: "transparent"
    }

    Instantiator {
        id: spectrumInstantiator
        model: Math.floor(barCount / 2)
        
        delegate: Item {
            id: spectrumItem
            width: root.barWidth
            height: root.height
            
            Item {
                id: leftBarItem
                width: root.barWidth
                height: root.height
                x: (root.width / 2) - ((index + 1) * (root.barWidth + root.spacing))

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.92
                    height: parent.height * 0.9
                    y: parent.height - (leftBarVisual.height + 4)
                    color: "#00000022"
                    radius: width / 2
                    opacity: 0.18
                    visible: leftBarVisual.height > root.minBarHeight + 2
                    z: 0
                }

                Rectangle {
                    id: leftBarVisual
                    width: parent.width
                    height: root.minBarHeight + (root.maxBarHeight - root.minBarHeight)
                            * (root.spectrum.length > index ? root.spectrum[index] : 0)
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    radius: width / 2
                    z: 1

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#ffffff" }
                        GradientStop { position: 1.0; color: "#f0f4f7" }
                    }

                    border.width: 1
                    border.color: "#0000000a"

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        color: "transparent"
                        radius: parent.radius - 1
                        opacity: 0.08
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#ffffffaa" }
                            GradientStop { position: 1.0; color: "#ffffff00" }
                        }
                        z: 2
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 1.6
                        height: parent.height * 1.2
                        visible: root.isPlaying && audioLevel > 0.02
                        color: "transparent"
                        border.width: 0
                        radius: width / 2
                        opacity: Math.min(0.8, audioLevel * 1.4)
                        z: 0

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            radius: parent.radius
                            border.width: 0
                            opacity: parent.opacity * 0.45
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#ffffff33" }
                                GradientStop { position: 1.0; color: "#ffffff00" }
                            }
                        }
                    }
                }
            }

            Item {
                id: rightBarItem
                width: root.barWidth
                height: root.height
                x: (root.width / 2) + (index * (root.barWidth + root.spacing)) + root.spacing

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.92
                    height: parent.height * 0.9
                    y: parent.height - (rightBarVisual.height + 4)
                    color: "#00000022"
                    radius: width / 2
                    opacity: 0.18
                    visible: rightBarVisual.height > root.minBarHeight + 2
                    z: 0
                }

                Rectangle {
                    id: rightBarVisual
                    width: parent.width
                    height: root.minBarHeight + (root.maxBarHeight - root.minBarHeight)
                            * (root.spectrum.length > index ? root.spectrum[index] : 0)
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    radius: width / 2
                    z: 1

                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#ffffff" }
                        GradientStop { position: 1.0; color: "#f0f4f7" }
                    }

                    border.width: 1
                    border.color: "#0000000a"

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        color: "transparent"
                        radius: parent.radius - 1
                        opacity: 0.08
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#ffffffaa" }
                            GradientStop { position: 1.0; color: "#ffffff00" }
                        }
                        z: 2
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 1.6
                        height: parent.height * 1.2
                        visible: root.isPlaying && audioLevel > 0.02
                        color: "transparent"
                        border.width: 0
                        radius: width / 2
                        opacity: Math.min(0.8, audioLevel * 1.4)
                        z: 0

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            radius: parent.radius
                            border.width: 0
                            opacity: parent.opacity * 0.45
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#ffffff33" }
                                GradientStop { position: 1.0; color: "#ffffff00" }
                            }
                        }
                    }
                }
            }
        }
        
        onObjectAdded: function(index, object) {
            object.parent = root
        }
    }

    Rectangle {
        id: centerBar
        width: root.barWidth
        height: root.minBarHeight + (root.maxBarHeight - root.minBarHeight)
                * (root.spectrum.length > 0 ? root.spectrum[0] : 0)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 0
        radius: width / 2
        z: 1

        gradient: Gradient {
            GradientStop { position: 0.0; color: "#ffffff" }
            GradientStop { position: 1.0; color: "#f0f4f7" }
        }

        border.width: 1
        border.color: "#0000000a"

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            color: "transparent"
            radius: parent.radius - 1
            opacity: 0.08
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#ffffffaa" }
                GradientStop { position: 1.0; color: "#ffffff00" }
            }
            z: 2
        }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 1.6
            height: parent.height * 1.2
            visible: root.isPlaying && audioLevel > 0.02
            color: "transparent"
            border.width: 0
            radius: width / 2
            opacity: Math.min(0.8, audioLevel * 1.4)
            z: 0

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: parent.radius
                border.width: 0
                opacity: parent.opacity * 0.45
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#ffffff33" }
                    GradientStop { position: 1.0; color: "#ffffff00" }
                }
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width * 0.92
            height: parent.height * 0.9
            y: parent.height - (centerBar.height + 4)
            color: "#00000022"
            radius: width / 2
            opacity: 0.18
            visible: centerBar.height > root.minBarHeight + 2
            z: 0
        }
    }

    Connections {
        target: (typeof playerBackend !== 'undefined') ? playerBackend : null
        function onSpectrumChanged() {
            root.spectrum = playerBackend.spectrum || []
        }
        function onIsPlayingChanged() {
            root.isPlaying = !!playerBackend.isPlaying
        }
    }

    function resetBars() {
        centerBar.height = root.minBarHeight
        
        for (var i = 0; i < spectrumInstantiator.count; ++i) {
            var item = spectrumInstantiator.objectAt(i)
            if (item) {
                var leftBar = item.leftBarItem.children.find(child => child.id === "leftBarVisual")
                if (leftBar) leftBar.height = root.minBarHeight
                
                var rightBar = item.rightBarItem.children.find(child => child.id === "rightBarVisual")
                if (rightBar) rightBar.height = root.minBarHeight
            }
        }
    }

    onIsPlayingChanged: {
        if (!root.isPlaying) {
            resetBars()
        }
    }
}
