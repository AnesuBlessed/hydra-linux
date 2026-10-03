import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 120
    color: "transparent"

    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        item: root.showing ? flyout : null
    }

    MatugenColors {
        id: mocha
    }

    PwObjectTracker {
        id: audioTracker
        objects: [Pipewire.defaultAudioSink]
    }

    property var sink: Pipewire.defaultAudioSink

    property real volume: {
        if (!sink || !sink.audio)
            return 0
        return sink.audio.volume
    }

    property bool muted: {
        if (!sink || !sink.audio)
            return false
        return sink.audio.muted
    }

    property bool showing: false
    property bool isStartup: true

    Timer {
        interval: 1000
        running: true
        onTriggered: root.isStartup = false
    }

    function showOsd() {
        if (root.isStartup) return
        showing = true
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 1400
        repeat: false
        onTriggered: root.showing = false
    }

    Connections {
        target: root.sink ? root.sink.audio : null

        function onVolumeChanged() {
            root.showOsd()
        }

        function onMutedChanged() {
            root.showOsd()
        }
    }

    Rectangle {
        id: flyout

        width: 320
        height: 38

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 24

        radius: 19
        color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, 0.85)
        border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.12)
        border.width: 1

        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : 0.92

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        Behavior on scale {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        Text {
            id: icon
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter

            text: {
                if (root.muted) return "󰖁"
                if (root.volume <= 0.01) return "󰕿"
                if (root.volume < 0.5) return "󰖀"
                return "󰕾"
            }

            font.family: "Symbols Nerd Font"
            font.pixelSize: 18
            color: root.muted ? mocha.red : mocha.mauve
        }

        Rectangle {
            anchors.left: icon.right
            anchors.leftMargin: 12
            anchors.right: percentText.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            height: 6
            radius: 3
            color: Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.6)

            Rectangle {
                width: root.muted ? 0 : parent.width * Math.min(root.volume, 1)
                height: parent.height
                radius: 3
                color: mocha.mauve

                Behavior on width {
                    NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
                }
            }
        }

        Text {
            id: percentText
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter

            text: root.muted ? "Muted" : Math.round(root.volume * 100) + "%"
            font.family: "JetBrains Mono"
            font.pixelSize: 12
            font.bold: true
            color: mocha.text
        }
    }
}
