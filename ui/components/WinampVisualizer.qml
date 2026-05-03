import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: winampRoot
    width: parent.width
    height: 120
    
    property bool active: false

    Row {
        anchors.centerIn: parent
        spacing: 4

        Repeater {
            model: 24
            Rectangle {
                id: bar
                width: 12
                height: 20
                radius: 2
                
                // Degradado Winamp Clásico (Verde -> Amarillo -> Rojo)
                color: index < 15 ? "#00FF00" : (index < 20 ? "#FFFF00" : "#FF0000")
                opacity: 0.8

                SequentialAnimation on height {
                    running: winampRoot.active
                    loops: Animation.Infinite
                    NumberAnimation { 
                        from: 10 + Math.random()*20
                        to: 30 + Math.random()*70
                        duration: 150 + Math.random()*150
                        easing.type: Easing.InOutQuad 
                    }
                    NumberAnimation { 
                        from: 30 + Math.random()*70
                        to: 10 + Math.random()*20
                        duration: 150 + Math.random()*150
                        easing.type: Easing.InOutQuad 
                    }
                }
                
                // Cuando está parado, volvemos a altura mínima
                Behavior on height { NumberAnimation { duration: 500 } }
                height: winampRoot.active ? 20 : 5
            }
        }
    }
}
