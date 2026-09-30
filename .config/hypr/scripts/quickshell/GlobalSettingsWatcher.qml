pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Single source of truth for anything that scales the whole UI.
// Replaces the four independent readers of settings.json that used to
// each spawn their own `cat` + inotifywait pair.
Item {
    id: root
    readonly property string home: Quickshell.env("HOME")
    readonly property string settingsFile: home + "/.config/hypr/settings.json"

    property real uiScale: 1.0
    // Compositor output scale, sampled once at startup. 1.0 when unknown.
    property real dpiScale: 1.0
    // Whole settings.json, republished on every change. Consumers that need
    // their own keys bind here instead of each spawning their own
    // `cat` + inotifywait pair against the same file.
    readonly property var rawSettings: _raw

    property var _raw: ({})
    signal settingsChanged()

    readonly property bool topbarHelpIcon: (_raw && _raw.topbarHelpIcon !== undefined) ? _raw.topbarHelpIcon : true
    readonly property int workspaceCount: (_raw && _raw.workspaceCount !== undefined) ? _raw.workspaceCount : 8
    readonly property bool openGuideAtStartup: (_raw && _raw.openGuideAtStartup !== undefined) ? _raw.openGuideAtStartup : true

    function readSettings(content) {
        try {
            let str = content || (scaleCollector.text ? scaleCollector.text.trim() : "");
            if (str && str.length > 0 && str !== "{}") {
                _raw = JSON.parse(str);
                if (_raw.uiScale !== undefined && !isNaN(_raw.uiScale)) {
                    root.uiScale = _raw.uiScale;
                }
                settingsChanged();
            }
        } catch (e) {
            console.warn("GlobalSettingsWatcher: could not parse settings.json:", e);
        }
    }

    Process {
        id: scaleReader
        command: ["bash", "-c", "cat " + root.settingsFile + " 2>/dev/null || echo '{}'"]
        running: true
        stdout: StdioCollector {
            id: scaleCollector
            onStreamFinished: {
                root.readSettings(this.text);
            }
        }
    }

    Process {
        id: scaleWatcher
        command: ["bash", "-c", "while [ ! -f " + root.settingsFile + " ]; do sleep 1; done; inotifywait -qq -e modify,close_write,move_self " + root.settingsFile + " 2>/dev/null || sleep 2"]
        running: true
        onExited: {
            scaleReader.running = false;
            scaleReader.running = true;
            running = false;
            running = true;
        }
    }

    // Hyprland reports the real output scale (`scale`) per monitor. Taking the
    // maximum matches the previous resolution-derived behaviour on mixed-DPI
    // setups while still correcting for HiDPI. Failures leave dpiScale at 1.0,
    // which reproduces the old formula exactly.
    Process {
        id: dpiReader
        running: true
        command: ["bash", "-c",
            "hyprctl monitors -j 2>/dev/null " +
            "| jq -r '[.[].scale] | max // 1' 2>/dev/null || echo 1"]
        stdout: StdioCollector {
            onStreamFinished: {
                let v = parseFloat(this.text ? this.text.trim() : "");
                if (!isNaN(v) && v > 0) {
                    root.dpiScale = Math.min(Math.max(v, 0.5), 3.0);
                }
            }
        }
    }
}
