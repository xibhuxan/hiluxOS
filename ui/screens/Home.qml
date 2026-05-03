import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: homeRoot
    objectName: "home"
    
    signal openRadio()
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 30
        spacing: 25

        // Bienvenida / Resumen rápido
        RowLayout {
            Layout.fillWidth: true
            
            ColumnLayout {
                spacing: 5
                Text { 
                    text: "TOYOTA HILUX '99" 
                    color: "white" 
                    font.pixelSize: 28 
                    font.weight: Font.DemiBold
                }
                Text { 
                    text: "Buenos días. El sistema está listo." 
                    color: "#8b949e" 
                    font.pixelSize: 16 
                }
            }
            
            Item { Layout.fillWidth: true }
            
            // Widget de temperatura/clima
            RowLayout {
                spacing: 20
                Text { text: "☀️ 24°C"; color: "white"; font.pixelSize: 24; font.bold: true }
            }
        }

        // Dashboard de tarjetas
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 3
            rows: 2
            columnSpacing: 25
            rowSpacing: 25

            DashboardCard {
                btnIcon: "🚗"
                title: "ESTADO"
                value: "READY"
                btnColor: "#58a6ff"
            }

            DashboardCard {
                btnIcon: "📻"
                title: "RADIO"
                value: "104.5 MHz"
                btnColor: "#d2a8ff"
                MouseArea {
                    anchors.fill: parent
                    onClicked: homeRoot.openRadio()
                }
            }

            DashboardCard {
                btnIcon: "📶"
                title: "TELÉFONO"
                value: "SIN CONEXIÓN"
                btnColor: "#339af0"
            }

            DashboardCard {
                btnIcon: "🚀"
                title: "VELOCIDAD"
                value: "0 km/h"
                btnColor: "#f0883e"
                valueColor: "#f0883e"
            }

            DashboardCard {
                btnIcon: "🔘"
                title: "FRENO"
                value: "ACTIVO"
                btnColor: "#ff7b72"
            }

            DashboardCard {
                btnIcon: "⚙️"
                title: "AJUSTES"
                value: "CONFIGURAR"
                btnColor: "#8b949e"
            }
        }
    }
}
