import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: cardRoot
    property string btnIcon: ""
    property string title: ""
    property string value: ""
    property color btnColor: "#58a6ff"
    property color valueColor: "white"
    
    Layout.fillWidth: true
    Layout.fillHeight: true
    
    radius: 30
    color: "#161b22"
    border.color: "#21262d"
    border.width: 1
    clip: true // Importante para que el contenido no sobresalga de las esquinas redondeadas

    // Efecto de brillo sutil (Corregido para que no se vea en las esquinas)
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 1 // Pequeño margen para que no toque el borde redondeado
        height: 1
        color: Qt.rgba(1, 1, 1, 0.08)
        visible: parent.radius > 0
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 25
        spacing: 15

        RowLayout {
            Layout.fillWidth: true
            
            Rectangle {
                width: 50
                height: 50
                radius: 15
                color: Qt.rgba(cardRoot.btnColor.r, cardRoot.btnColor.g, cardRoot.btnColor.b, 0.1)
                
                Text {
                    anchors.centerIn: parent
                    text: cardRoot.btnIcon
                    font.pixelSize: 28
                }
            }
            
            Text {
                text: cardRoot.title
                color: "#8b949e"
                font.pixelSize: 14
                font.bold: true
                font.letterSpacing: 2
                Layout.leftMargin: 10
            }
            
            Item { Layout.fillWidth: true }
        }

        Item { Layout.fillHeight: true }

        Text {
            text: cardRoot.value
            color: cardRoot.valueColor
            font.pixelSize: 32
            font.weight: Font.DemiBold
        }
    }
    
    // Área interactiva
    MouseArea {
        id: mArea
        anchors.fill: parent
        hoverEnabled: true
        onPressed: cardRoot.scale = 0.97
        onReleased: cardRoot.scale = 1.0
    }
    
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
}
