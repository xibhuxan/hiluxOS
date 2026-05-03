import QtQuick
import QtQuick.Controls
import QtMultimedia
import QtQuick.Layouts

Rectangle {
    id: splashRoot
    anchors.fill: parent
    color: "#000000"
    z: 100 

    property string videoSource: "file:../../assets/video/splash.mp4"
    property bool hasVideo: false
    
    signal finished()

    // Temporizador de carga (4.5 segundos)
    Timer {
        id: fallbackTimer
        interval: 4500
        running: true
        onTriggered: splashRoot.finished()
    }

    // INTERFAZ DE CARGA CINEMÁTICA
    ColumnLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -40 // Elevamos todo el conjunto un poco sobre el centro real
        visible: !splashRoot.hasVideo
        spacing: 0 // Usaremos Items de espaciado para control total

        // Contenedor para la imagen
        Item {
            Layout.preferredWidth: 600
            Layout.preferredHeight: 380 // Reducido para que el texto suba
            Layout.alignment: Qt.AlignHCenter
            
            Image {
                id: vehicleImage
                source: "../../assets/images/hilux_99.png"
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                opacity: 0
                
                transform: Translate {
                    id: vehicleTranslate
                    y: 30
                }

                ParallelAnimation {
                    running: true
                    NumberAnimation {
                        target: vehicleImage
                        property: "opacity"
                        from: 0; to: 1; duration: 2500; easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: vehicleTranslate
                        property: "y"
                        from: 30; to: 0; duration: 2500; easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Item { Layout.preferredHeight: 5 } // Espacio mínimo entre imagen y logo

        // Logo con efecto "Glow"
        Text {
            id: logoText
            text: "HILUX OS"
            color: "white"
            font.pixelSize: 54
            font.letterSpacing: 15
            font.weight: Font.ExtraLight
            Layout.alignment: Qt.AlignHCenter
            opacity: 0

            SequentialAnimation on opacity {
                running: true
                PauseAnimation { duration: 800 } 
                NumberAnimation { from: 0; to: 1; duration: 2000; easing.type: Easing.InOutQuad }
                
                SequentialAnimation {
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.7; duration: 2000; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 0.7; to: 1.0; duration: 2000; easing.type: Easing.InOutQuad }
                }
            }
        }

        Item { Layout.preferredHeight: 25 } // Espacio antes de la barra

        // Barra de carga ultra-fina
        Rectangle {
            id: progressContainer
            Layout.preferredWidth: 350
            Layout.preferredHeight: 2
            color: "#1a1a1a"
            radius: 1
            Layout.alignment: Qt.AlignHCenter

            Rectangle {
                id: progressBar
                width: 0
                height: parent.height
                color: "#58a6ff"
                
                NumberAnimation on width {
                    from: 0; to: 350; duration: 4000; easing.type: Easing.InOutQuart
                }
            }
        }

        Item { Layout.preferredHeight: 15 } // Espacio antes del Established

        Text {
            text: "ESTABLISHED 1999"
            color: "#444444"
            font.pixelSize: 12
            font.letterSpacing: 6
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }
    }

    // Animación de salida (Fade out)
    NumberAnimation {
        id: fadeOut
        target: splashRoot
        property: "opacity"
        to: 0
        duration: 1200
        easing.type: Easing.InOutQuad
        onStopped: splashRoot.visible = false
    }

    function startFadeOut() {
        fallbackTimer.stop()
        fadeOut.start()
    }
}
