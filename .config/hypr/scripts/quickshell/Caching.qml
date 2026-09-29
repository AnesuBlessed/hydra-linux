import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    readonly property string home: Quickshell.env("HOME")
    readonly property string xdgRuntimeDir: Quickshell.env("XDG_RUNTIME_DIR")

    // Persistent data on disk
    readonly property string cacheDir: home + "/.cache/quickshell"
    readonly property string stateDir: home + "/.local/state/quickshell"

    // Ephemeral data in RAM (tmpfs) - fallback to the user cache dir, NOT a
    // shared /tmp. This must stay identical to caching.sh's QS_RUN_DIR logic
    // or every file-based IPC path silently diverges.
    readonly property string runDir: xdgRuntimeDir !== "" ? (xdgRuntimeDir + "/quickshell") : (cacheDir + "/run")
    readonly property string logDir: runDir + "/logs"

    // Directories that exist before any component can ask for them. Previously
    // every get*Dir() call fired a detached `mkdir -p` and returned immediately,
    // so callers writing into the directory in the same tick raced it — which
    // silently killed whole pipelines (e.g. a `exec > $logDir/run.log` redirect
    // failing before the first command ran).
    Process {
        id: dirSetup
        running: true
        command: ["bash", "-c",
            "mkdir -p " + root.cacheDir + " " + root.stateDir + " " + root.runDir + " " + root.logDir + " && chmod 700 " + root.runDir + " " + root.logDir]
    }

    // Per-widget subdirectories are created at most once each. The previous code
    // fired a detached `mkdir -p` on *every* call, which both leaked processes
    // and still raced callers that wrote into the directory in the same tick.
    // Top-level cache/state/run/log dirs are created synchronously-ish by
    // dirSetup above; subdirs get a single lazy creation, and caching.sh already
    // pre-creates the standard ones on every session start.
    property var _ensured: ({})

    function _ensureOnce(path) {
        if (_ensured[path]) return;
        _ensured[path] = true;
        Quickshell.execDetached(["mkdir", "-p", path]);
    }

    function getCacheDir(widgetName) {
        let envPath = Quickshell.env("QS_CACHE_" + widgetName.toUpperCase());
        if (envPath) { _ensureOnce(envPath); return envPath; }
        let p = cacheDir + "/" + widgetName;
        _ensureOnce(p);
        return p;
    }

    function getStateDir(widgetName) {
        let envPath = Quickshell.env("QS_STATE_" + widgetName.toUpperCase());
        if (envPath) { _ensureOnce(envPath); return envPath; }
        let p = stateDir + "/" + widgetName;
        _ensureOnce(p);
        return p;
    }

    function getRunDir(widgetName) {
        let envPath = Quickshell.env("QS_RUN_" + widgetName.toUpperCase());
        if (envPath) { _ensureOnce(envPath); return envPath; }
        let p = runDir + "/" + widgetName;
        _ensureOnce(p);
        return p;
    }

    function getLogDir(widgetName) {
        let envPath = Quickshell.env("QS_LOG_" + widgetName.toUpperCase());
        if (envPath) { _ensureOnce(envPath); return envPath; }
        let p = logDir + "/" + widgetName;
        _ensureOnce(p);
        return p;
    }
}
