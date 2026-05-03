import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import "screens"
import "components"
import "splash"

Window {
    id: root
    width: 1280
    height: 720
    visible: true
    title: qsTr("HiluxOS - Infotainment System")
    color: "#0d1117"

    property bool systemReady: false

    // Lógica de Eventos
    Connections {
        target: bridge
        function onEventReceived(event, data) {
            if (event === "radio:frequency_changed") {
                radioScreenItem.frequency = data.frequency
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // 1. Área de Contenido (Screens)
        StackView {
            id: stackView
            Layout.fillWidth: true
            Layout.fillHeight: true
            initialItem: homeScreen
            visible: systemReady
            clip: true

            // TRANSICIÓN DEFINITIVA: Secuencial, limpia y sin superposiciones
            pushEnter: Transition {
                SequentialAnimation {
                    // Forzamos estado inicial invisible e desplazado
                    PropertyAction { property: "opacity"; value: 0 }
                    PropertyAction { property: "x"; value: 100 }
                    
                    // Pausa para dejar que la pantalla anterior se vaya
                    PauseAnimation { duration: 450 }
                    
                    // Entrada suave
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 600; easing.type: Easing.OutCubic }
                        NumberAnimation { property: "x"; from: 100; to: 0; duration: 700; easing.type: Easing.OutQuint }
                    }
                }
            }
            
            pushExit: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 400; easing.type: Easing.InQuad }
                    NumberAnimation { property: "x"; from: 0; to: -100; duration: 400; easing.type: Easing.InQuad }
                }
            }
            
            popEnter: Transition {
                SequentialAnimation {
                    PropertyAction { property: "opacity"; value: 0 }
                    PropertyAction { property: "x"; value: -100 }
                    
                    PauseAnimation { duration: 450 }
                    
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 600; easing.type: Easing.OutCubic }
                        NumberAnimation { property: "x"; from: -100; to: 0; duration: 700; easing.type: Easing.OutQuint }
                    }
                }
            }
            
            popExit: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 400; easing.type: Easing.InQuad }
                    NumberAnimation { property: "x"; from: 0; to: 100; duration: 400; easing.type: Easing.InQuad }
                }
            }
        }

        // 2. Barra de Control Inferior (Persistente)
        BottomBar {
            id: bottomBar
            Layout.fillWidth: true
            visible: systemReady
        }
    }

    Component {
        id: homeScreen
        Home { 
            objectName: "homeScreen"
            onOpenRadio: stackView.push(radioScreen) 
        }
    }

    Component {
        id: radioScreen
        Radio { 
            id: radioScreenItem
            objectName: "radioScreen"
        }
    }

    SplashScreen {
        id: splashScreen
        anchors.fill: parent
        onFinished: {
            root.systemReady = true
            startFadeOut()
        }
    }
}
