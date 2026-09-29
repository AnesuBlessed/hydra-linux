pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property color base: "#1e1e2e"
    property color mantle: "#181825"
    property color crust: "#11111b"
    property color text: "#cdd6f4"
    property color subtext0: "#a6adc8"
    property color subtext1: "#bac2de"
    property color surface0: "#313244"
    property color surface1: "#45475a"
    property color surface2: "#585b70"
    property color overlay0: "#6c7086"
    property color overlay1: "#7f849c"
    property color overlay2: "#9399b2"
    property color blue: "#89b4fa"
    property color sapphire: "#74c7ec"
    property color peach: "#fab387"
    property color green: "#a6e3a1"
    property color red: "#f38ba8"
    property color mauve: "#cba6f7"
    property color pink: "#f5c2e7"
    property color yellow: "#f9e2af"
    property color maroon: "#eba0ac"
    property color teal: "#94e2d5"

    Process {
        id: themeReader
        command: ["cat", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_colors.json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(this.text);
                    root.base = parsed.base || root.base;
                    root.mantle = parsed.mantle || root.mantle;
                    root.crust = parsed.crust || root.crust;
                    root.text = parsed.text || root.text;
                    root.subtext0 = parsed.subtext0 || root.subtext0;
                    root.subtext1 = parsed.subtext1 || root.subtext1;
                    root.surface0 = parsed.surface0 || root.surface0;
                    root.surface1 = parsed.surface1 || root.surface1;
                    root.surface2 = parsed.surface2 || root.surface2;
                    root.overlay0 = parsed.overlay0 || root.overlay0;
                    root.overlay1 = parsed.overlay1 || root.overlay1;
                    root.overlay2 = parsed.overlay2 || root.overlay2;
                    root.blue = parsed.blue || root.blue;
                    root.sapphire = parsed.sapphire || root.sapphire;
                    root.peach = parsed.peach || root.peach;
                    root.green = parsed.green || root.green;
                    root.red = parsed.red || root.red;
                    root.mauve = parsed.mauve || root.mauve;
                    root.pink = parsed.pink || root.pink;
                    root.yellow = parsed.yellow || root.yellow;
                    root.maroon = parsed.maroon || root.maroon;
                    root.teal = parsed.teal || root.teal;
                } catch (e) {}
            }
        }
    }

    Process {
        id: themeWatcher
        command: ["bash", "-c", "inotifywait -qq -e close_write,modify ~/.config/hypr/scripts/qs_colors.json || sleep 2"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                themeReader.running = false;
                themeReader.running = true;
                themeWatcher.running = false;
                themeWatcher.running = true;
            }
        }
    }
}
