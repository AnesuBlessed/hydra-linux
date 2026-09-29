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

    function readSettings() {
        try {
            if (scaleReader.collected && scaleReader.collected.text &&
                    scaleReader.collected.text.trim().length > 0 &&
                    scaleReader.collected.text.trim() !== "{}") {
                _raw = JSON.parse(scaleReader.collected.text);
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
                root.uiScale = (function () {
                    try {
                        let v = JSON.parse(this.text).uiScale;
                        return (v !== undefined && !isNaN(v)) ? v : root.uiScale;
                    } catch (e) { return root.uiScale; }
                })();
                root.readSettings();
            }
        }
    }

    Process {
        id: scaleWatcher
        command: ["bash", "-c", "while [ ! -f " + root.settingsFile + " ]; do sleep 1; done; inotifywait -qq -e modify,close_write " + root.settingsFile + " 2>/dev/null || sleep 2"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                scaleReader.running = false;
                scaleReader.running = true;
                scaleWatcher.running = false;
                scaleWatcher.running = true;
            }
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
