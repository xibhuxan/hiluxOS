import QtQuick
import QtQuick.Controls

Button {
    id: control
    property string btnIcon: ""
    property color btnColor: "#58a6ff"
    
    background: Rectangle {
        color: control.pressed ? Qt.darker(control.btnColor, 1.2) : 
               control.hovered ? Qt.lighter(control.btnColor, 1.1) : control.btnColor
        radius: 28
    }

    contentItem: Item {
        implicitWidth: rowContent.implicitWidth
        implicitHeight: rowContent.implicitHeight

        Row {
            id: rowContent
            anchors.centerIn: parent
            spacing: 15
            
            Text {
                text: control.btnIcon
                font.pixelSize: 48
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                text: control.text
                color: "white"
                font.pixelSize: 24
                font.bold: true
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
