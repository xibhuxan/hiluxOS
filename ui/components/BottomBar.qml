import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: bottomBarRoot
    height: 80
    color: "#0d1117"
    
    // Línea superior sutil
    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: "#161b22"
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 0

        // Grupo Izquierdo: Navegación
        RowLayout {
            spacing: 15
            BarButton { btnIcon: "⬅"; onClicked: stackView.pop() }
            BarButton { btnIcon: "🏠"; onClicked: if(stackView.depth > 1) stackView.pop(null) }
        }

        Item { Layout.fillWidth: true }

        // Grupo Central: Accesos rápidos
        RowLayout {
            spacing: 30
            BarButton { btnIcon: "📻"; onClicked: if(stackView.currentItem.objectName !== "radio") stackView.push(radioScreen) }
            BarButton { btnIcon: "🎵" }
            BarButton { btnIcon: "📞" }
            BarButton { btnIcon: "⚙️" }
        }

        Item { Layout.fillWidth: true }

        // Grupo Derecho: Volumen y Estado
        RowLayout {
            spacing: 20
            
            RowLayout {
                spacing: 15
                Text { text: "🔈"; color: "#8b949e"; font.pixelSize: 20 }
                
                Slider {
                    id: volSlider
                    width: 150
                    from: 0
                    to: 100
                    value: 50
                    // Sincronización bidireccional simple
                    onPositionChanged: {
                        if (pressed) {
                            bridge.setVolume(value)
                        }
                    }
                    
                    background: Rectangle {
                        x: volSlider.leftPadding
                        y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                        implicitWidth: 120
                        implicitHeight: 6
                        width: volSlider.availableWidth
                        height: implicitHeight
                        radius: 3
                        color: "#161b22"

                        Rectangle {
                            width: volSlider.visualPosition * parent.width
                            height: parent.height
                            color: "#58a6ff"
                            radius: 3
                        }
                    }

                    handle: Rectangle {
                        x: volSlider.leftPadding + volSlider.visualPosition * (volSlider.availableWidth - width)
                        y: volSlider.topPadding + volSlider.availableHeight / 2 - height / 2
                        implicitWidth: 20
                        implicitHeight: 20
                        radius: 10
                        color: "white"
                        border.color: "#58a6ff"
                        border.width: volSlider.pressed ? 2 : 0
                    }
                }
                
                Text { 
                    text: new Date().toLocaleTimeString(Qt.locale(), "HH:mm")
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true 
                    
                    Timer {
                        interval: 10000
                        running: true
                        repeat: true
                        onTriggered: parent.text = new Date().toLocaleTimeString(Qt.locale(), "HH:mm")
                    }
                }
            }
        }
    }

    component BarButton : Button {
        property string btnIcon: ""
        implicitWidth: 60
        implicitHeight: 60
        
        background: Rectangle {
            color: parent.pressed ? "#161b22" : "transparent"
            radius: 12
        }
        
        contentItem: Text {
            text: parent.btnIcon
            color: parent.pressed ? "#58a6ff" : "white"
            font.pixelSize: 28
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
