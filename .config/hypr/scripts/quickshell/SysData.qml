pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    
    Caching { id: paths }
    
    // --- Centralized Properties ---
    property int cpu: 0
    property int ramPercent: 0
    property real ramGb: 0.0
    property int temp: 0
    property real netRx: 0
    property real netTx: 0
    property int cores: 4
    
    // --- Lifecycle Management ---
    property int subscribers: 0
    // A tick arriving while a sample is still being collected used to kill
    // sys_fetcher.sh mid-run (it sleeps 0.5s), so onStreamFinished never
    // fired and the panel froze on stale numbers. Wait for the run to land.
    property bool fetchBusy: false

    function subscribe() {
        subscribers++;
        if (subscribers === 1) {
            fetchTimer.restart();
            fetchProc.running = false;
            fetchProc.running = true; // Fetch immediately on first open
        }
    }

    function unsubscribe() {
        subscribers = Math.max(0, subscribers - 1);
        if (subscribers === 0) {
            fetchTimer.stop();
            fetchProc.running = false;
        }
    }

    Timer {
        id: fetchTimer
        interval: 2000
        repeat: true
        running: root.subscribers > 0
        onTriggered: {
            if (!root.fetchBusy) {
                fetchProc.running = false;
                fetchProc.running = true;
            }
        }
    }

    Process {
        id: fetchProc
        running: false
        onRunningChanged: {
            root.fetchBusy = running;
        }
        onExited: {
            root.fetchBusy = false;
        }
        // Safely delegates path expansion directly to bash, preventing QML parsing issues
        // Passes dynamic sysdata cache dir in case the script needs it
        command: ["bash", "-c", "bash ~/.config/hypr/scripts/quickshell/watchers/sys_fetcher.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.fetchBusy = false;
                let text = this.text ? this.text.trim() : "";
                if (!text) return;

                let p = text.split("|");
                if (p.length >= 6) {
                    let cpu = parseInt(p[0]), ram = parseInt(p[1]);
                    let ramGb = parseFloat(p[2]), temp = parseInt(p[3]);
                    let rx = parseFloat(p[4]), tx = parseFloat(p[5]);
                    // A failed read yields empty fields; keep the last good value
                    // rather than poisoning every consumer with NaN.
                    if (!isNaN(cpu)) root.cpu = cpu;
                    if (!isNaN(ram)) root.ramPercent = ram;
                    if (!isNaN(ramGb)) root.ramGb = ramGb;
                    if (!isNaN(temp)) root.temp = temp;
                    if (!isNaN(rx)) root.netRx = rx;
                    if (!isNaN(tx)) root.netTx = tx;
                    if (p.length >= 7) {
                        let c = parseInt(p[6]);
                        if (!isNaN(c) && c > 0) root.cores = c;
                    }
                }
            }
        }
    }
}
