import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: cardRoot
    property string icon: ""
    property string title: ""
    property string value: ""
    property color cardColor: "#161b22"
    property color valueColor: "#8b949e"

    color: cardRoot.cardColor
    radius: 24

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 10

        Text {
            visible: cardRoot.icon !== ""
            text: cardRoot.icon
            font.pixelSize: 48
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            text: cardRoot.title
            color: "#8b949e"
            font.pixelSize: 18
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        Text {
            text: cardRoot.value
            color: cardRoot.valueColor
            font.pixelSize: 24
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
