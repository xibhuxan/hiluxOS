import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: radioRoot
    objectName: "radio"
    
    property string currentStation: "Selecciona una emisora"
    property bool isPlaying: false
    property var searchResults: []
    property var favorites: [
        {"name": "Rock FM", "url": "http://195.55.74.212/cope/rockfm-64.mp3"},
        {"name": "Los 40", "url": "https://25653.live.streamtheworld.com/LOS40.mp3"},
        {"name": "SomaFM", "url": "http://ice1.somafm.com/groovesalad-128-mp3"}
    ]

    Connections {
        target: bridge
        function onEventReceived(event, data) {
            if (event === "radio:status") {
                radioRoot.currentStation = data.station || radioRoot.currentStation
                radioRoot.isPlaying = data.playing
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        // COLUMNA IZQUIERDA: Favoritos y Búsqueda (Vertical)
        ColumnLayout {
            Layout.preferredWidth: 350
            Layout.fillHeight: true
            spacing: 15

            // Buscador
            TextField {
                id: searchInput
                Layout.fillWidth: true
                placeholderText: "🔍 Buscar emisora mundial..."
                font.pixelSize: 18
                color: "white"
                background: Rectangle {
                    color: "#161b22"
                    radius: 15
                    border.color: searchInput.activeFocus ? "#3498db" : "#21262d"
                }
                onAccepted: {
                    radioRoot.searchResults = bridge.searchRadioStations(text)
                }
            }

            // Lista Vertical
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                
                ListView {
                    id: stationList
                    model: searchInput.text === "" ? radioRoot.favorites : radioRoot.searchResults
                    spacing: 10
                    
                    delegate: ItemDelegate {
                        width: stationList.width
                        height: 70
                        
                        background: Rectangle {
                            color: parent.pressed ? "#1c2128" : "#161b22"
                            radius: 12
                            border.color: radioRoot.currentStation === modelData.name ? "#3498db" : "transparent"
                        }
                        
                        contentItem: ColumnLayout {
                            spacing: 2
                            Text { 
                                text: modelData.name
                                color: "white"
                                font.pixelSize: 18
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text { 
                                text: modelData.country || "Online Stream"
                                color: "#8b949e"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }
                        
                        onClicked: {
                            bridge.playRadioUrl(modelData.url_resolved || modelData.url, modelData.name)
                        }
                    }
                }
            }
        }

        // COLUMNA DERECHA: Visualizador y Reproducción
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#0d1117"
            radius: 30
            border.color: "#161b22"
            clip: true

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width - 40
                spacing: 40

                // Cabecera de la Radio
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 10
                    
                    Text {
                        text: radioRoot.currentStation
                        color: "white"
                        font.pixelSize: 48
                        font.weight: Font.Bold
                        Layout.alignment: Qt.AlignHCenter
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }
                    
                    Rectangle {
                        visible: radioRoot.isPlaying
                        Layout.preferredWidth: 140; Layout.preferredHeight: 32
                        color: Qt.rgba(0.2, 0.8, 0.2, 0.1); radius: 16; border.color: "#2ecc71"
                        Layout.alignment: Qt.AlignHCenter
                        Text { anchors.centerIn: parent; text: "LIVE STREAM"; color: "#2ecc71"; font.pixelSize: 12; font.bold: true }
                    }
                }

                // VISUALIZADOR WINAMP
                WinampVisualizer {
                    id: visualizer
                    active: radioRoot.isPlaying
                    Layout.fillWidth: true
                }

                // Botón de Parada Grande
                Button {
                    Layout.alignment: Qt.AlignHCenter
                    text: radioRoot.isPlaying ? "⏹ DETENER" : "▶ REPRODUCIR"
                    onClicked: {
                        if(radioRoot.isPlaying) bridge.stopInternetRadio()
                    }
                    
                    background: Rectangle {
                        implicitWidth: 200; implicitHeight: 60
                        color: radioRoot.isPlaying ? "#ff4444" : "#2ecc71"
                        radius: 30
                        opacity: parent.pressed ? 0.8 : 1.0
                    }
                    contentItem: Text {
                        text: parent.text; color: "white"
                        font.pixelSize: 18; font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }
}
