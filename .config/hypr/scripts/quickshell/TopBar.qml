import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Variants {
    model: Quickshell.screens

    delegate: Component {
        PanelWindow {
            id: barWindow
            property bool pendingReload: false
            
	    Caching { id: paths }


        
            IpcHandler {
                target: "topbar"
                function forceReload() {
                    Quickshell.reload(true) 
                }
                function queueReload() {
                    if (!barWindow.isSettingsOpen) {
                        Quickshell.reload(true)
                    } else {
                        barWindow.pendingReload = true
                    }
                }
                function toggleUpdate() {
                    barWindow.forceUpdateShow = !barWindow.forceUpdateShow
                }
            }

            required property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }

            Scaler {
                id: scaler
                currentWidth: barWindow.width
                // The output height, NOT barWindow.height: the bar's own height
                // is derived from s(), so feeding it back would be a binding loop.
                currentHeight: (modelData && modelData.height) ? modelData.height : 1080
            }

            function s(val) {
                return scaler.s(val);
            }

            property int barHeight: s(48)

            height: barHeight
            margins { top: s(8); bottom: 0; left: s(4); right: s(4) }
            exclusiveZone: barHeight 
            color: "transparent"

            // --- RESPONSIVE TIERS ---
            // "Logical" width is the available width divided by the active scale,
            // so these thresholds are independent of resolution AND of the user's
            // uiScale setting. The scaler already shrinks everything on small
            // panels; the tiers exist for the cases it cannot cover, namely a
            // cranked-up uiScale or an unusually narrow window.
            //
            // Thresholds are derived from the measured content budget in design
            // units (all widths here are s() values):
            //   left 470 + right 559 + centre 296 + gaps 16 + margins 8 = 1349
            //     -> enough for a perfectly centred clock
            //   + media at its 180-unit column, no overflow:
            //   FULL     470+559+296+330+24 = 1679
            //   COMPACT  media column 180 -> 100, tighter spacing               1579
            //   MINIMAL  media text dropped (thumb only) + no wifi/bt/power/bat % 1240
            //   TIGHT    no media box, no tray                                   660
            // Thresholds carry headroom above each budget so the bar never
            // actually overflows before it sheds a widget.
            property real logicalWidth: barWindow.width / scaler.baseScale
            property int densityTier: {
                if (logicalWidth >= 1600) return 0;
                if (logicalWidth >= 1300) return 1;
                if (logicalWidth >= 1050) return 2;
                return 3;
            }
            // T0 FULL, T1 COMPACT, T2 MINIMAL, T3 TIGHT
            property bool showFullText: densityTier < 2
            property bool showLabels: densityTier < 3
            property bool showExtras: densityTier < 3

            MatugenColors {
                id: mocha
            }

            property real barAlpha: 0.45

            property bool showHelpIcon: GlobalSettingsWatcher.topbarHelpIcon
            property bool isRecording: false
            
            property bool updateAvailable: false
            property bool forceUpdateShow: false
            property bool isUpdateVisible: updateAvailable || forceUpdateShow
            
            property int workspaceCount: GlobalSettingsWatcher.workspaceCount
            
            property string activeWidget: GlobalSettingsWatcher.currentActiveWidget
            property bool isSettingsOpen: activeWidget === "settings"

            property real settingsSlideProgress: isSettingsOpen ? 1.0 : 0.0
            Behavior on settingsSlideProgress { 
                enabled: barWindow.startupCascadeFinished
                NumberAnimation { duration: 600; easing.type: Easing.OutExpo } 
            }

            onIsSettingsOpenChanged: {
                if (!barWindow.isSettingsOpen && barWindow.pendingReload) {
                    barWindow.pendingReload = false;
                    Quickshell.reload(true);
                }
            }

            Process {
                id: recPoller
                command: ["bash", "-c", "if [ -s " + paths.getCacheDir("recording") + "/rec_pid ] && kill -0 $(cat " + paths.getCacheDir("recording") + "/rec_pid) 2>/dev/null; then echo '1'; else echo '0'; fi"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        barWindow.isRecording = (this.text.trim() === "1");
                    }
                }
            }

            Timer {
                interval: 2000
                running: true
                repeat: true
                onTriggered: {
                    recPoller.running = false;
                    recPoller.running = true;
                }
            }

            Process {
                id: updatePoller
                command: ["bash", "-c", "if [ -f " + paths.getCacheDir("updater") + "/update_pending ]; then echo '1'; else echo '0'; fi"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        barWindow.updateAvailable = (this.text.trim() === "1");
                    }
                }
            }

            Timer {
                interval: 30000
                running: true
                repeat: true
                onTriggered: {
                    updatePoller.running = false;
                    updatePoller.running = true;
                }
            }
	                
            // topbarHelpIcon and workspaceCount come from the settings singleton
            // instead of a fourth `cat` + inotifywait pair on the same file.
            Connections {
                target: GlobalSettingsWatcher
                function onSettingsChanged() {
                    let s = GlobalSettingsWatcher.rawSettings;
                    if (!s) return;
                    if (s.topbarHelpIcon !== undefined && barWindow.showHelpIcon !== s.topbarHelpIcon) {
                        barWindow.showHelpIcon = s.topbarHelpIcon;
                    }
                    if (s.workspaceCount !== undefined && barWindow.workspaceCount !== s.workspaceCount) {
                        barWindow.workspaceCount = s.workspaceCount;
                        // Restart the daemon so it re-reads workspaceCount.
                        wsDaemon.running = false;
                        wsDaemon.running = true;
                    }
                }
            }
            
            property bool isDesktop: false
            property string ethStatus: "Ethernet"

            Process {
                id: chassisDetector
                running: true
                command: ["bash", "-c", "if ls /sys/class/power_supply/BAT* 1> /dev/null 2>&1; then echo 'laptop'; else echo 'desktop'; fi"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        barWindow.isDesktop = (this.text.trim() === "desktop");
                    }
                }
            }

            property bool isStartupReady: false
            Timer { interval: 10; running: true; onTriggered: barWindow.isStartupReady = true }
            
            property bool startupCascadeFinished: false
            Timer { interval: 1000; running: true; onTriggered: barWindow.startupCascadeFinished = true }
            
            property bool fastPollerLoaded: false
            property bool isDataReady: fastPollerLoaded
            Timer { interval: 600; running: true; onTriggered: barWindow.isDataReady = true }
            
            property string timeStr: ""
            property string fullDateStr: ""
            property int typeInIndex: 0
            property string dateStr: fullDateStr.substring(0, typeInIndex)

            property string weatherIcon: ""
            property string weatherTemp: "--°"
            property string weatherHex: mocha.yellow
            
            property string wifiStatus: "Off"
            property string wifiIcon: "󰤮"
            property string wifiSsid: ""
            
            property string btStatus: "Off"
            property string btIcon: "󰂲"
            property string btDevice: ""
            
            property string volPercent: "0%"
            property string volIcon: "󰕾"
            property bool isMuted: false
            
            property string batPercent: "100%"
            property string powerProfile: "balanced"
            property string batIcon: "󰁹"
            property string batStatus: "Unknown"
            
            property string kbLayout: "us"
            
            ListModel { 
                id: workspacesModel 
                property int activeIndex: 0
            }
            
            property var musicData: { "status": "Stopped", "title": "", "artUrl": "", "timeStr": "" }

            property string displayTitle: ""
            property string displayTime: ""
            property string displayArtUrl: ""

            onMusicDataChanged: {
                if (musicData && musicData.status !== "Stopped" && musicData.title !== "") {
                    displayTitle = musicData.title;
                    displayTime = musicData.timeStr;
                    displayArtUrl = musicData.artUrl;
                }
            }

            onDisplayArtUrlChanged: {
                if (displayArtUrl && displayArtUrl.indexOf("placeholder_blank.png") !== -1) {
                    artRetryTimer.retryCount = 0;
                    artRetryTimer.running = true;
                } else {
                    artRetryTimer.running = false;
                }
            }

            property bool isMediaActive: barWindow.musicData.status !== "Stopped" && barWindow.musicData.title !== ""
            property bool isWifiOn: barWindow.wifiStatus.toLowerCase() === "enabled" || barWindow.wifiStatus.toLowerCase() === "on"
            property bool isBtOn: barWindow.btStatus.toLowerCase() === "enabled" || barWindow.btStatus.toLowerCase() === "on"
            property bool showEthernet: barWindow.ethStatus === "Connected" || (barWindow.isDesktop && !barWindow.isWifiOn)
            
            property bool isSoundActive: !barWindow.isMuted && parseInt(barWindow.volPercent) > 0
            property int batCap: parseInt(barWindow.batPercent) || 0
            property bool isCharging: barWindow.batStatus === "Charging" || barWindow.batStatus === "Full"
            
            property color batDynamicColor: {
                if (isCharging) return mocha.green;
                if (batCap <= 20) return mocha.red;
                return mocha.text; 
            }

            function syncWorkspaces() {
                let activeId = (Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id) ? Hyprland.focusedWorkspace.id : 1;
                let occupiedMap = {};
                if (Hyprland.workspaces && Hyprland.workspaces.values) {
                    for (let i = 0; i < Hyprland.workspaces.values.length; i++) {
                        let w = Hyprland.workspaces.values[i];
                        occupiedMap[w.id] = true;
                        if (w.active || w.focused) activeId = w.id;
                    }
                }
                let totalCount = barWindow.workspaceCount || 7;
                while (workspacesModel.count < totalCount) {
                    workspacesModel.append({ "wsId": "", "wsState": "", "wsTip": "" });
                }
                while (workspacesModel.count > totalCount) {
                    workspacesModel.remove(workspacesModel.count - 1);
                }
                let newActive = -1;
                for (let i = 1; i <= totalCount; i++) {
                    let idx = i - 1;
                    let isAct = (i === activeId);
                    let isOcc = (occupiedMap[i] === true);
                    let st = isAct ? "active" : (isOcc ? "occupied" : "empty");
                    if (isAct) newActive = idx;
                    if (workspacesModel.get(idx).wsState !== st) {
                        workspacesModel.setProperty(idx, "wsState", st);
                    }
                    if (workspacesModel.get(idx).wsId !== i.toString()) {
                        workspacesModel.setProperty(idx, "wsId", i.toString());
                    }
                    let tip = isAct ? "Active Workspace" : (isOcc ? "Workspace " + i : "Empty");
                    if (workspacesModel.get(idx).wsTip !== tip) {
                        workspacesModel.setProperty(idx, "wsTip", tip);
                    }
                }
                if (newActive !== -1 && workspacesModel.activeIndex !== newActive) {
                    workspacesModel.activeIndex = newActive;
                }
            }

            Connections {
                target: Hyprland
                function onRawEvent(event) {
                    let n = event.name;
                    if (n === "workspace" || n === "focusedmon" || n === "createworkspace" || 
                        n === "destroyworkspace" || n === "openwindow" || n === "closewindow" || 
                        n === "movewindow") {
                        barWindow.syncWorkspaces();
                    } else if (n === "activelayout") {
                        let parts = event.data.split(",");
                        if (parts.length > 1) {
                            let code = parts[1].trim().substring(0, 2).toLowerCase();
                            if (code !== "") barWindow.kbLayout = code;
                        }
                    }
                }
                function onFocusedWorkspaceChanged() {
                    barWindow.syncWorkspaces();
                }
            }

            Component.onCompleted: {
                Hyprland.refreshWorkspaces();
                Hyprland.refreshMonitors();
                barWindow.syncWorkspaces();
            }

            Process {
                id: musicForceRefresh
                running: true
                command: ["bash", "-c", "bash ~/.config/hypr/scripts/quickshell/music/music_info.sh | tee " + paths.getRunDir("music") + "/music_info.json"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try { barWindow.musicData = JSON.parse(txt); } catch(e) {
                                console.warn("TopBar: failed to parse music JSON:", e);
                            }
                        }
                    }
                }
            }

            Timer {
                interval: 1000
                running: barWindow.musicData !== null && barWindow.musicData.status === "Playing"
                repeat: true
                onTriggered: {
                    if (!barWindow.musicData || barWindow.musicData.status !== "Playing") return;
                    if (!barWindow.musicData.timeStr || barWindow.musicData.timeStr === "") return;

                    let parts = barWindow.musicData.timeStr.split(" / ");
                    if (parts.length !== 2) return;

                    let posParts = parts[0].split(":").map(Number);
                    let lenParts = parts[1].split(":").map(Number);

                    let posSecs = (posParts.length === 3) 
                        ? (posParts[0] * 3600 + posParts[1] * 60 + posParts[2]) 
                        : (posParts[0] * 60 + posParts[1]);

                    let lenSecs = (lenParts.length === 3) 
                        ? (lenParts[0] * 3600 + lenParts[1] * 60 + lenParts[2]) 
                        : (lenParts[0] * 60 + lenParts[1]);

                    if (isNaN(posSecs) || isNaN(lenSecs)) return;

                    posSecs++;
                    if (posSecs > lenSecs) posSecs = lenSecs;

                    let newPosStr = "";
                    if (posParts.length === 3) {
                        let h = Math.floor(posSecs / 3600);
                        let m = Math.floor((posSecs % 3600) / 60);
                        let s = posSecs % 60;
                        newPosStr = h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
                    } else {
                        let m = Math.floor(posSecs / 60);
                        let s = posSecs % 60;
                        newPosStr = (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
                    }

                    let newData = Object.assign({}, barWindow.musicData);
                    newData.timeStr = newPosStr + " / " + parts[1];
                    newData.positionStr = newPosStr;
                    if (lenSecs > 0) newData.percent = (posSecs / lenSecs) * 100;
                    
                    barWindow.musicData = newData;
                }
            }

            Process {
                id: mprisWatcher
                running: true
                command: ["bash", "-c", "dbus-monitor --session \"type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.mpris.MediaPlayer2.Player'\" \"type='signal',interface='org.mpris.MediaPlayer2.Player',member='Seeked'\" 2>/dev/null | grep -m 1 'member=' > /dev/null || sleep 2"]
                onExited: {
                    musicForceRefresh.running = false;
                    musicForceRefresh.running = true;
                    running = false;
                    running = true;
                }
            }

            Timer {
                id: artRetryTimer
                interval: 500
                repeat: true
                property int retryCount: 0
                running: false
                onTriggered: {
                    retryCount++;
                    if (retryCount >= 6) {
                        running = false;
                    } else {
                        musicForceRefresh.running = false;
                        musicForceRefresh.running = true;
                    }
                }
            }

            // --- NATIVE AUDIO (PIPEWIRE) ---
            PwObjectTracker {
                id: audioTracker
                objects: [Pipewire.defaultAudioSink]
            }

            property var audioSink: Pipewire.defaultAudioSink

            Connections {
                target: audioSink ? audioSink.audio : null
                function onVolumeChanged() {
                    let v = Math.round((audioSink.audio.volume || 0) * 100);
                    barWindow.volPercent = v + "%";
                    if (barWindow.isMuted) {
                        barWindow.volIcon = "󰖁";
                    } else if (v <= 1) {
                        barWindow.volIcon = "󰕿";
                    } else if (v < 50) {
                        barWindow.volIcon = "󰖀";
                    } else {
                        barWindow.volIcon = "󰕾";
                    }
                }
                function onMutedChanged() {
                    let m = audioSink.audio.muted || false;
                    barWindow.isMuted = m;
                    if (m) {
                        barWindow.volIcon = "󰖁";
                    } else {
                        let v = Math.round((audioSink.audio.volume || 0) * 100);
                        if (v <= 1) barWindow.volIcon = "󰕿";
                        else if (v < 50) barWindow.volIcon = "󰖀";
                        else barWindow.volIcon = "󰕾";
                    }
                }
            }

            // --- NATIVE BATTERY (UPOWER) ---
            Connections {
                target: UPower.displayDevice
                function onPercentageChanged() {
                    let dev = UPower.displayDevice;
                    if (!dev || !dev.isPresent) return;
                    let p = Math.round(dev.percentage * 100);
                    barWindow.batPercent = p + "%";
                    let chg = (dev.state === UPowerDeviceState.Charging);
                    barWindow.batStatus = chg ? "Charging" : "Discharging";
                    if (chg) {
                        if (p >= 90) barWindow.batIcon = "󰂅";
                        else if (p >= 70) barWindow.batIcon = "󰂊";
                        else if (p >= 50) barWindow.batIcon = "󰂉";
                        else if (p >= 30) barWindow.batIcon = "󰂈";
                        else barWindow.batIcon = "󰢜";
                    } else {
                        if (p >= 90) barWindow.batIcon = "󰁹";
                        else if (p >= 80) barWindow.batIcon = "󰂂";
                        else if (p >= 70) barWindow.batIcon = "󰂁";
                        else if (p >= 60) barWindow.batIcon = "󰂀";
                        else if (p >= 50) barWindow.batIcon = "󰁿";
                        else if (p >= 40) barWindow.batIcon = "󰁾";
                        else if (p >= 30) barWindow.batIcon = "󰁽";
                        else if (p >= 20) barWindow.batIcon = "󰁼";
                        else barWindow.batIcon = "󰁻";
                    }
                }
            }

            // Initial Keyboard fetch (only runs once on startup)
            Process {
                id: kbPoller; running: true
                command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/kb_fetch.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "" && barWindow.kbLayout !== txt) barWindow.kbLayout = txt;
                        barWindow.fastPollerLoaded = true;
                    }
                }
            }

            // --- NETWORK (TIMED POLLER, NO PERSISTENT SUBSHELL) ---
            Process {
                id: networkPoller; running: true
                command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/network_fetch.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let data = JSON.parse(txt);
                                if (barWindow.wifiStatus !== data.status) barWindow.wifiStatus = data.status;
                                if (barWindow.wifiIcon !== data.icon) barWindow.wifiIcon = data.icon;
                                if (barWindow.wifiSsid !== data.ssid) barWindow.wifiSsid = data.ssid;
                                if (barWindow.ethStatus !== data.eth_status) barWindow.ethStatus = data.eth_status;
                            } catch(e) {}
                        }
                    }
                }
            }
            Timer {
                interval: 8000
                running: true
                repeat: true
                onTriggered: {
                    networkPoller.running = false;
                    networkPoller.running = true;
                }
            }

            // --- BLUETOOTH (TIMED POLLER, NO PERSISTENT SUBSHELL) ---
            Process {
                id: btPoller; running: true
                command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/watchers/bt_fetch.sh"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "") {
                            try {
                                let data = JSON.parse(txt);
                                if (barWindow.btStatus !== data.status) barWindow.btStatus = data.status;
                                if (barWindow.btIcon !== data.icon) barWindow.btIcon = data.icon;
                                if (barWindow.btDevice !== data.connected) barWindow.btDevice = data.connected;
                            } catch(e) {}
                        }
                    }
                }
            }
            Timer {
                interval: 10000
                running: true
                repeat: true
                onTriggered: {
                    btPoller.running = false;
                    btPoller.running = true;
                }
            }

            // --- POWER PROFILE (TIMED POLLER, NO PERSISTENT SUBSHELL) ---
            Process {
                id: powerProfileFetcher; running: true
                command: ["bash", "-c", "powerprofilesctl get 2>/dev/null || echo \"balanced\""]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let txt = this.text.trim();
                        if (txt !== "" && barWindow.powerProfile !== txt) {
                            barWindow.powerProfile = txt;
                            Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/turbo_inhibitor.sh", "sync"]);
                        }
                    }
                }
            }
            Timer {
                interval: 10000
                running: true
                repeat: true
                onTriggered: {
                    powerProfileFetcher.running = false;
                    powerProfileFetcher.running = true;
                }
            }

            Process {
                id: weatherPoller
                command: ["bash", "-c", "~/.config/hypr/scripts/quickshell/calendar/weather.sh --current-all"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let parts = this.text.trim().split("|");
                        if (parts.length >= 3) {
                            barWindow.weatherIcon = parts[0];
                            barWindow.weatherTemp = parts[1];
                            barWindow.weatherHex = parts[2] || mocha.yellow;
                        }
                    }
                }
            }
            Timer { interval: 150000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { weatherPoller.running = false; weatherPoller.running = true; } }


            Timer {
                interval: 1000; running: true; repeat: true; triggeredOnStart: true
                onTriggered: {
                    let d = new Date();
                    barWindow.timeStr = Qt.formatDateTime(d, "HH:mm:ss");
                    barWindow.fullDateStr = Qt.formatDateTime(d, "dddd, MMMM dd");
                    if (barWindow.typeInIndex >= barWindow.fullDateStr.length) {
                        barWindow.typeInIndex = barWindow.fullDateStr.length;
                    }
                }
            }

            Timer {
                id: typewriterTimer
                interval: 40
                running: barWindow.isStartupReady && barWindow.typeInIndex < barWindow.fullDateStr.length
                repeat: true
                onTriggered: barWindow.typeInIndex += 1
            }

            Item {
                anchors.fill: parent

                Rectangle {
                    id: leftContent
                    y: (parent.height - barWindow.barHeight) / 2
                    height: barWindow.barHeight

                    color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, barWindow.barAlpha)
                    radius: barWindow.s(14)
                    border.width: 1
                    border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
                    clip: true
                    
                    property bool showLayout: true
                    
                    opacity: (showLayout && !barWindow.isSettingsOpen) ? 1 : 0
                    enabled: !barWindow.isSettingsOpen
                    
                    property real targetX: (showLayout && !barWindow.isSettingsOpen) ? 0 : barWindow.s(-200)
                    x: targetX
                    Behavior on x { NumberAnimation { duration: 600; easing.type: Easing.OutExpo } }
                    Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                    
                    Timer {
                        running: barWindow.isStartupReady
                        interval: 10
                        onTriggered: leftContent.showLayout = true
                    }

                    width: leftLayout.implicitWidth + barWindow.s(16)

                    Row {
                        id: leftLayout
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: barWindow.s(8)
                        spacing: barWindow.s(4)
                        
                        property int pillHeight: barWindow.s(34)

                        Rectangle {
                            property bool isHovered: helpMouse.containsMouse
                            color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : "transparent"
                            radius: barWindow.s(10)
                            
                            property real targetWidth: barWindow.showHelpIcon ? barWindow.s(34) : 0
                            width: targetWidth
                            height: parent.pillHeight
                            visible: targetWidth > 0 || opacity > 0
                            opacity: barWindow.showHelpIcon ? 1.0 : 0.0
                            clip: true
                            
                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                            Behavior on opacity { NumberAnimation { duration: 300 } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                            
                            Text {
                                anchors.centerIn: parent
                                text: "󰋗"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(22)
                                color: parent.isHovered ? mocha.teal : mocha.text
                                Behavior on color { ColorAnimation { duration: 200 } }
                                scale: parent.isHovered ? 1.15 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                            }
                            MouseArea {
                                id: helpMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle guide"])
                            }
                        }

                        Rectangle {
                            property bool isHovered: searchMouse.containsMouse
                            color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : "transparent"
                            radius: barWindow.s(10)
                            height: parent.pillHeight; width: barWindow.s(34)
                            
                            Behavior on color { ColorAnimation { duration: 200 } }
                            
                            Text {
                                anchors.centerIn: parent
                                text: "󰍉"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(22)
                                color: parent.isHovered ? mocha.blue : mocha.text
                                Behavior on color { ColorAnimation { duration: 200 } }
                                scale: parent.isHovered ? 1.15 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                            }
                            MouseArea {
                                id: searchMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle applauncher"])
                            }
                        }

                        Rectangle {
                            property bool isHovered: settingsMouse.containsMouse
                            color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : "transparent"
                            radius: barWindow.s(10)
                            height: parent.pillHeight; width: barWindow.s(34)
                            
                            Behavior on color { ColorAnimation { duration: 200 } }
                            
                            Text {
                                anchors.centerIn: parent
                                text: ""
                                font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(22)
                                color: parent.isHovered ? mocha.blue : mocha.text
                                Behavior on color { ColorAnimation { duration: 200 } }
                                scale: parent.isHovered ? 1.15 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                            }
                            MouseArea {
                                id: settingsMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle settings"])
                            }
                        }

                        Rectangle {
                            id: updateButton
                            property bool isHovered: updateMouse.containsMouse
                            color: isHovered ? Qt.rgba(mocha.green.r, mocha.green.g, mocha.green.b, 0.15) : "transparent"
                            radius: barWindow.s(10)
                            
                            width: barWindow.isUpdateVisible ? barWindow.s(34) : 0
                            height: parent.pillHeight
                            
                            visible: width > 0 || opacity > 0
                            opacity: barWindow.isUpdateVisible ? 1.0 : 0.0
                            clip: false 
                            
                            Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                            Behavior on opacity { NumberAnimation { duration: 300 } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                            
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width
                                height: parent.height
                                radius: parent.radius
                                color: mocha.green
                                z: -1
                                
                                SequentialAnimation on scale {
                                    running: barWindow.isUpdateVisible && !updateButton.isHovered
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 1.0; to: 1.3; duration: 2000; easing.type: Easing.OutCubic }
                                }
                                SequentialAnimation on opacity {
                                    running: barWindow.isUpdateVisible && !updateButton.isHovered
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 0.15; to: 0.0; duration: 2000; easing.type: Easing.OutCubic }
                                }
                            }
                            
                            Text {
                                anchors.centerIn: parent
                                text: "󰚰"
                                font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(22)
                                color: parent.isHovered ? mocha.text : mocha.green
                                Behavior on color { ColorAnimation { duration: 200 } }
                                
                                rotation: parent.isHovered ? 360 : 0
                                Behavior on rotation {
                                    NumberAnimation { 
                                        duration: 600
                                        easing.type: Easing.OutBack
                                    }
                                }

                                scale: parent.isHovered ? 1.15 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                            }

                            MouseArea {
                                id: updateMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    barWindow.updateAvailable = false;
                                    barWindow.forceUpdateShow = false;
                                    Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle updater"]);
                                }
                            }
                        }
                    }
                }
                
                Rectangle {
                    id: workspacesBox
                    color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, barWindow.barAlpha)
                    radius: barWindow.s(14); border.width: 1; border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)
                    height: barWindow.barHeight
                    y: (parent.height - barWindow.barHeight) / 2
                    clip: true
                    
                    width: workspacesModel.count > 0 ? wsLayout.implicitWidth + barWindow.s(20) : 0
                    
                    property real defaultX: (barWindow.isSettingsOpen ? 0 : leftContent.width) + barWindow.s(4)
                    property real settingsX: sysUsageBox.settingsX - width - (width > 0 ? barWindow.s(4) : 0)
                                        
                    x: defaultX + (settingsX - defaultX) * barWindow.settingsSlideProgress

                    property bool limitActive: (barWindow.isSettingsOpen && barWindow.isMediaActive) || barWindow.densityTier >= 3

                    visible: width > 0 || opacity > 0
                    opacity: workspacesModel.count > 0 ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 300 } }

                    Rectangle {
                        id: activeHighlight
                        y: (workspacesBox.height - barWindow.s(32)) / 2
                        height: barWindow.s(32)
                        radius: barWindow.s(10)
                        color: mocha.mauve
                        z: 0

                        property int prevIdx: 0
                        property int curIdx: workspacesModel.activeIndex

                        onCurIdxChanged: {
                            if (curIdx > prevIdx) {
                                rightAnim.duration = 140; leftAnim.duration = 200;
                            } else if (curIdx < prevIdx) {
                                leftAnim.duration = 140; rightAnim.duration = 200;
                            }
                            prevIdx = curIdx;
                        }

                        property int clampedIdx: Math.max(0, Math.min(curIdx, workspacesBox.limitActive ? 5 : workspacesModel.count - 1))
                        property var targetChild: (wsRepeater && wsRepeater.count > clampedIdx) ? wsRepeater.itemAt(clampedIdx) : null
                        property real targetLeft: wsLayout.x + (targetChild ? targetChild.x : (clampedIdx * (barWindow.s(32) + barWindow.s(6))))
                        property real targetRight: targetLeft + (targetChild ? targetChild.width : barWindow.s(32))

                        property real actualLeft: targetLeft
                        property real actualRight: targetRight

                        Behavior on actualLeft { NumberAnimation { id: leftAnim; duration: 180; easing.type: Easing.OutExpo } }
                        Behavior on actualRight { NumberAnimation { id: rightAnim; duration: 180; easing.type: Easing.OutExpo } }

                        x: actualLeft
                        width: actualRight - actualLeft
                        opacity: workspacesModel.count > 0 ? 1 : 0
                    }

                    Row {
                        id: wsLayout
                        anchors.centerIn: parent
                        spacing: barWindow.s(6)
                        
                        Repeater {
                            id: wsRepeater
                            model: workspacesModel
                            delegate: Rectangle {
                                id: wsPill
                                
                                property bool isLimited: workspacesBox.limitActive && index >= 6
                                visible: !isLimited
                                
                                property bool isHovered: wsPillMouse.containsMouse
                                
                                property string stateLabel: model.wsState
                                property string wsName: model.wsId
                                property string wsTip: model.wsTip || ""
                                
                                property real targetWidth: barWindow.s(32)
                                width: targetWidth
                                Behavior on targetWidth { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                                
                                height: barWindow.s(32); radius: barWindow.s(10)
                                
                                color: isHovered ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.1) : (stateLabel === "occupied" ? Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.15) : "transparent")

                                scale: isHovered && stateLabel !== "active" ? 1.08 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                                
                                property bool initAnimTrigger: false
                                opacity: initAnimTrigger ? 1 : 0
                                transform: Translate {
                                    y: wsPill.initAnimTrigger ? 0 : barWindow.s(15)
                                    Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } }
                                }

                                Component.onCompleted: {
                                    if (!barWindow.startupCascadeFinished) {
                                        animTimer.interval = index * 60;
                                        animTimer.start();
                                    } else {
                                        initAnimTrigger = true;
                                    }
                                }

                                Timer {
                                    id: animTimer
                                    running: false
                                    repeat: false
                                    onTriggered: wsPill.initAnimTrigger = true
                                }
                                
                                Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 250 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: wsName
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: barWindow.s(14)
                                    font.weight: stateLabel === "active" ? Font.Black : (stateLabel === "occupied" ? Font.Bold : Font.Medium)

                                    color: index === workspacesModel.activeIndex ? mocha.crust : (isHovered ? mocha.text : (stateLabel === "occupied" ? mocha.text : mocha.overlay0))

                                    Behavior on color { ColorAnimation { duration: 250 } }

                                    // Focused window title, supplied by workspaces.sh.
                                    Accessible.role: Accessible.StaticText
                                    Accessible.name: wsName + (wsTip && wsTip !== "Empty" ? " — " + wsTip : "")
                                }
                                MouseArea {
                                    id: wsPillMouse
                                    hoverEnabled: true
                                    anchors.fill: parent
                                    onClicked: {
                                        workspacesModel.activeIndex = index;
                                        let num = parseInt(wsName);
                                        let target = isNaN(num) ? (wsName || (index + 1)) : num;
                                        Quickshell.execDetached(["sh", "-c", "hyprctl dispatch 'hl.dsp.focus({ workspace = " + target + " })' 2>/dev/null || hyprctl dispatch workspace '" + target + "'"]);
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: sysUsageBox
                    color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, barWindow.barAlpha)
                    radius: barWindow.s(14)
                    border.width: 1
                    border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)
                    height: barWindow.barHeight
                    y: (parent.height - barWindow.barHeight) / 2
                    clip: true

                    property bool showUsage: barWindow.densityTier < 3
                    width: showUsage ? sysUsageLayout.implicitWidth + barWindow.s(16) : 0
                    Behavior on width { NumberAnimation { duration: 350; easing.type: Easing.OutQuint } }

                    property real defaultX: workspacesBox.defaultX + workspacesBox.width + (workspacesBox.width > 0 ? barWindow.s(4) : 0)
                    property real settingsX: mediaBox.settingsX - width - (width > 0 ? barWindow.s(4) : 0)

                    x: defaultX + (settingsX - defaultX) * barWindow.settingsSlideProgress

                    visible: width > 0 || opacity > 0
                    opacity: showUsage ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 300 } }

                    Component.onCompleted: SysData.subscribe()
                    Component.onDestruction: SysData.unsubscribe()

                    Row {
                        id: sysUsageLayout
                        anchors.centerIn: parent
                        spacing: barWindow.s(6)

                        // --- CPU & CORES PILL ---
                        Rectangle {
                            id: cpuPill
                            property bool isHovered: cpuMouse.containsMouse
                            radius: barWindow.s(10)
                            height: barWindow.s(32)
                            color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.35)
                            border.width: 1
                            border.color: isHovered ? Qt.rgba(cpuAccentColor.r, cpuAccentColor.g, cpuAccentColor.b, 0.4) : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06)
                            clip: true

                            width: barWindow.s(barWindow.showFullText ? 104 : 76)
                            scale: isHovered ? 1.05 : 1.0
                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }
                            Behavior on color { ColorAnimation { duration: 200 } }

                            property color cpuAccentColor: {
                                if (SysData.cpu >= 85) return mocha.red;
                                if (SysData.cpu >= 60) return mocha.peach;
                                return mocha.sapphire;
                            }

                            Row {
                                id: cpuRow
                                anchors.centerIn: parent
                                spacing: barWindow.s(6)

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: ""
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: barWindow.s(16)
                                    color: cpuPill.cpuAccentColor
                                    Behavior on color { ColorAnimation { duration: 300 } }
                                }

                                Text {
                                    id: cpuText
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: barWindow.s(barWindow.showFullText ? 66 : 38)
                                    horizontalAlignment: Text.AlignHCenter
                                    text: {
                                        let coresPrefix = (barWindow.showFullText && SysData.cores > 0) ? (SysData.cores + "C ") : "";
                                        return coresPrefix + SysData.cpu + "%";
                                    }
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: barWindow.s(12)
                                    font.weight: Font.Bold
                                    color: mocha.text
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                            }

                            MouseArea {
                                id: cpuMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached(["kitty", "-e", "btop"]);
                                }
                            }
                        }

                        // --- RAM USAGE PILL ---
                        Rectangle {
                            id: ramPill
                            property bool isHovered: ramMouse.containsMouse
                            property bool showAsPercent: false
                            radius: barWindow.s(10)
                            height: barWindow.s(32)
                            color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.35)
                            border.width: 1
                            border.color: isHovered ? Qt.rgba(ramAccentColor.r, ramAccentColor.g, ramAccentColor.b, 0.4) : Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.06)
                            clip: true

                            width: barWindow.s(90)
                            scale: isHovered ? 1.05 : 1.0
                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutExpo } }
                            Behavior on color { ColorAnimation { duration: 200 } }

                            property color ramAccentColor: {
                                if (SysData.ramPercent >= 85) return mocha.red;
                                if (SysData.ramPercent >= 70) return mocha.peach;
                                return mocha.teal;
                            }

                            Row {
                                id: ramRow
                                anchors.centerIn: parent
                                spacing: barWindow.s(6)

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰍛"
                                    font.family: "Iosevka Nerd Font"
                                    font.pixelSize: barWindow.s(16)
                                    color: ramPill.ramAccentColor
                                    Behavior on color { ColorAnimation { duration: 300 } }
                                }

                                Text {
                                    id: ramText
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: barWindow.s(50)
                                    horizontalAlignment: Text.AlignHCenter
                                    text: ramPill.showAsPercent ? (SysData.ramPercent + "%") : (SysData.ramGb.toFixed(1) + "G")
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: barWindow.s(12)
                                    font.weight: Font.Bold
                                    color: mocha.text
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                            }

                            MouseArea {
                                id: ramMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ramPill.showAsPercent = !ramPill.showAsPercent;
                                }
                                onDoubleClicked: {
                                    Quickshell.execDetached(["kitty", "-e", "btop"]);
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: mediaBox
                    color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, barWindow.barAlpha)
                    radius: barWindow.s(14); border.width: 1; border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.05)
                    y: (parent.height - barWindow.barHeight) / 2
                    height: barWindow.barHeight
                    clip: true 
                    
                    width: barWindow.isMediaActive ? innerMediaLayout.implicitWidth + barWindow.s(24) : 0
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

                    property real defaultX: sysUsageBox.defaultX + sysUsageBox.width + (sysUsageBox.width > 0 ? barWindow.s(4) : 0)
                    property real settingsX: centerBox.settingsX - width - (width > 0 ? barWindow.s(4) : 0)

                    x: defaultX + (settingsX - defaultX) * barWindow.settingsSlideProgress

                    visible: width > 0 || opacity > 0
                    opacity: barWindow.isMediaActive ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 400 } }
                    
                    Item {
                        id: mediaLayoutContainer
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: barWindow.s(12)
                        height: parent.height
                        width: innerMediaLayout.implicitWidth
                        
                        opacity: barWindow.isMediaActive ? 1.0 : 0.0
                        transform: Translate { 
                            x: barWindow.isMediaActive ? 0 : barWindow.s(-20) 
                            Behavior on x { NumberAnimation { duration: 700; easing.type: Easing.OutQuint } }
                        }
                        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

                        Row {
                            id: innerMediaLayout
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: barWindow.densityTier >= 1 ? barWindow.s(8) : barWindow.s(16)
                            
                                MouseArea {
                                    id: mediaInfoMouse
                                    width: showFullText ? infoLayout.width : barWindow.s(32)
                                    height: innerMediaLayout.height
                                    hoverEnabled: true
                                    onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle music"])

                                    Row {
                                        id: infoLayout
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: barWindow.s(10)

                                        scale: mediaInfoMouse.containsMouse ? 1.02 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                                        Rectangle {
                                            width: barWindow.s(32); height: barWindow.s(32); radius: barWindow.s(8); color: mocha.surface1
                                            border.width: barWindow.musicData.status === "Playing" ? 1 : 0
                                            border.color: mocha.mauve
                                            clip: true
                                            Image {
                                                anchors.fill: parent;
                                                source: barWindow.displayArtUrl || "";
                                                fillMode: Image.PreserveAspectCrop
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                color: Qt.rgba(mocha.mauve.r, mocha.mauve.g, mocha.mauve.b, 0.2)
                                            }
                                        }
                                    Column {
                                        // Below FULL the title/artist column is dropped
                                        // entirely rather than just elided: the
                                        // album-art thumbnail still identifies the track
                                        // and this reclaims ~240 design units, which
                                        // is what keeps MINIMAL from overflowing.
                                        visible: barWindow.showFullText
                                        spacing: -2
                                        anchors.verticalCenter: parent.verticalCenter
                                        property real maxColWidth: barWindow.densityTier >= 1 ? barWindow.s(100) : barWindow.s(180)
                                        width: maxColWidth 
                                        
                                        Text { 
                                            visible: barWindow.showLabels
                                            text: barWindow.displayTitle; 
                                            font.family: "JetBrains Mono"; 
                                            font.weight: Font.Black; 
                                            font.pixelSize: barWindow.s(13); 
                                            color: mocha.text;
                                            width: parent.width
                                            elide: Text.ElideRight; 
                                        }
                                        Text { 
                                            text: barWindow.displayTime; 
                                            font.family: "JetBrains Mono"; 
                                            font.weight: Font.Black; 
                                            font.pixelSize: barWindow.s(10); 
                                            color: mocha.subtext0;
                                            width: parent.width
                                            elide: Text.ElideRight;
                                        }
                                    }
                                }
                            }

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: barWindow.densityTier >= 1 ? barWindow.s(4) : barWindow.s(8)
                                Item { 
                                    width: barWindow.s(24); height: barWindow.s(24); 
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { 
                                        anchors.centerIn: parent; text: "󰒮"; font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(26); 
                                        color: prevMouse.containsMouse ? mocha.text : mocha.overlay2; 
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        scale: prevMouse.containsMouse ? 1.1 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                    }
                                    MouseArea { id: prevMouse; hoverEnabled: true; anchors.fill: parent; onClicked: { Quickshell.execDetached(["playerctl", "previous"]); musicForceRefresh.running = true; } } 
                                }
                                Item { 
                                    width: barWindow.s(28); height: barWindow.s(28); 
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { 
                                        anchors.centerIn: parent; text: barWindow.musicData.status === "Playing" ? "󰏤" : "󰐊"; font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(30); 
                                        color: playMouse.containsMouse ? mocha.green : mocha.text; 
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        scale: playMouse.containsMouse ? 1.15 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                    }
                                    MouseArea { id: playMouse; hoverEnabled: true; anchors.fill: parent; onClicked: { Quickshell.execDetached(["playerctl", "play-pause"]); musicForceRefresh.running = true; } } 
                                }
                                Item { 
                                    width: barWindow.s(24); height: barWindow.s(24); 
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { 
                                        anchors.centerIn: parent; text: "󰒭"; font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(26); 
                                        color: nextMouse.containsMouse ? mocha.text : mocha.overlay2; 
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        scale: nextMouse.containsMouse ? 1.1 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }
                                    }
                                    MouseArea { id: nextMouse; hoverEnabled: true; anchors.fill: parent; onClicked: { Quickshell.execDetached(["playerctl", "next"]); musicForceRefresh.running = true; } } 
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: centerBox
                    property bool isHovered: centerMouse.containsMouse
                    color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.95) : Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, barWindow.barAlpha)
                    radius: barWindow.s(14); border.width: 1; border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, isHovered ? 0.15 : 0.05)
                    
                    y: (parent.height - barWindow.barHeight) / 2
                    height: barWindow.barHeight
                    
                    width: centerLayout.implicitWidth + barWindow.s(36)
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
                    
                    property real pureCenter: (parent.width - width) / 2
                    property real minCenterDefaultX: mediaBox.defaultX + mediaBox.width + (mediaBox.width > 0 ? barWindow.s(4) : 0)
                    property real maxCenterDefaultX: barWindow.width - rightContent.width - width - barWindow.s(4)
                    property real settingsX: maxCenterDefaultX
                    property real defaultX: Math.min(Math.max(minCenterDefaultX, pureCenter), maxCenterDefaultX)
                    
                    x: defaultX + (settingsX - defaultX) * barWindow.settingsSlideProgress
                    
                    property bool showLayout: true
                    opacity: 1
                    transform: Translate {
                        y: centerBox.showLayout ? 0 : barWindow.s(-30)
                        Behavior on y { NumberAnimation { duration: 800; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                    }

                    Timer {
                        running: barWindow.isStartupReady
                        interval: 150
                        onTriggered: centerBox.showLayout = true
                    }

                    Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

                    scale: isHovered ? 1.03 : 1.0
                    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }
                    Behavior on color { ColorAnimation { duration: 250 } }
                    
                    MouseArea {
                        id: centerMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle calendar"])
                    }

                    RowLayout {
                        id: centerLayout
                        anchors.centerIn: parent
                        spacing: barWindow.s(24)

                        ColumnLayout {
                            spacing: -2
                            Text { text: barWindow.timeStr; Layout.alignment: Qt.AlignLeft; font.family: "JetBrains Mono"; font.pixelSize: barWindow.s(16); font.weight: Font.Black; color: mocha.blue }
                            Text { text: barWindow.dateStr; Layout.alignment: Qt.AlignLeft; font.family: "JetBrains Mono"; font.pixelSize: barWindow.s(11); font.weight: Font.Bold; color: mocha.subtext0 }
                        }

                        RowLayout {
                            spacing: barWindow.s(8)
                            Text { 
                                text: barWindow.weatherIcon; 
                                Layout.alignment: Qt.AlignVCenter;
                                font.family: "Iosevka Nerd Font"; 
                                font.pixelSize: barWindow.s(24); 
                                color: barWindow.weatherHex ? barWindow.weatherHex : mocha.peach
                            }
                            Text { 
                                text: barWindow.weatherTemp; 
                                Layout.alignment: Qt.AlignVCenter;
                                font.family: "JetBrains Mono"; 
                                font.pixelSize: barWindow.s(17); 
                                font.weight: Font.Black; 
                                color: mocha.peach 
                            }
                        }
                    }
                }

                Row {
                    id: rightContent
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: barWindow.s(4)
                    
                    property bool showLayout: true
                    opacity: 1
                    transform: Translate {
                        x: rightContent.showLayout ? 0 : barWindow.s(30)
                        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
                    }
                    
                    Timer {
                        running: barWindow.isStartupReady && barWindow.isDataReady
                        interval: 250
                        onTriggered: rightContent.showLayout = true
                    }

                    Behavior on opacity { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

                    Rectangle {
                        height: barWindow.barHeight
                        radius: barWindow.s(14)
                        border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
                        border.width: 1
                        color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, barWindow.barAlpha)
                        
                        property real targetWidth: (barWindow.showExtras && trayRepeater.count > 0) ? trayLayout.width + barWindow.s(24) : 0
                        width: targetWidth
                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutExpo } }
                        
                        visible: targetWidth > 0
                        opacity: targetWidth > 0 ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 300 } }

                        Row {
                            id: trayLayout
                            anchors.centerIn: parent
                            spacing: barWindow.s(10)

                            Repeater {
                                id: trayRepeater
                                model: SystemTray.items
                                delegate: Image {
                                    id: trayIcon
                                    source: modelData.icon || ""
                                    fillMode: Image.PreserveAspectFit
                                    
                                    sourceSize: Qt.size(barWindow.s(18), barWindow.s(18))
                                    width: barWindow.s(18)
                                    height: barWindow.s(18)
                                    anchors.verticalCenter: parent.verticalCenter
                                    
                                    property bool isHovered: trayMouse.containsMouse
                                    property bool initAnimTrigger: false
                                    opacity: initAnimTrigger ? (isHovered ? 1.0 : 0.8) : 0.0
                                    scale: initAnimTrigger ? (isHovered ? 1.15 : 1.0) : 0.0

                                    Component.onCompleted: {
                                        if (!barWindow.startupCascadeFinished) {
                                            trayAnimTimer.interval = index * 50;
                                            trayAnimTimer.start();
                                        } else {
                                            initAnimTrigger = true;
                                        }
                                    }
                                    Timer {
                                        id: trayAnimTimer
                                        running: false
                                        repeat: false
                                        onTriggered: trayIcon.initAnimTrigger = true
                                    }

                                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                                    QsMenuAnchor {
                                        id: menuAnchor
                                        anchor.window: barWindow
                                        anchor.item: trayIcon
                                        menu: modelData.menu
                                    }

                                    MouseArea {
                                        id: trayMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                        onClicked: mouse => {
                                            if (mouse.button === Qt.LeftButton) {
                                                if (modelData.isMenuOnly || modelData.onlyMenu) {
                                                    menuAnchor.open();
                                                } else if (typeof modelData.activate === "function") {
                                                    modelData.activate(); 
                                                }
                                            } else if (mouse.button === Qt.MiddleButton) {
                                                if (typeof modelData.secondaryActivate === "function") {
                                                    modelData.secondaryActivate();
                                                }
                                            } else if (mouse.button === Qt.RightButton) {
                                                if (modelData.menu) { 
                                                    menuAnchor.open();
                                                } else if (typeof modelData.contextMenu === "function") {
                                                    modelData.contextMenu(mouse.x, mouse.y);
                                                } else {
                                                    modelData.activate(); 
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        height: barWindow.barHeight
                        radius: barWindow.s(14)
                        border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, 0.08)
                        border.width: 1
                        color: Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, barWindow.barAlpha)
                        clip: true
                        
                        width: sysLayout.implicitWidth + barWindow.s(20)

                        Row {
                            id: sysLayout
                            anchors.centerIn: parent
                            spacing: barWindow.s(8) 

                            property int pillHeight: barWindow.s(34)

                            Rectangle {
                                id: kbPill
                                property bool isHovered: kbMouse.containsMouse
                                color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                                radius: barWindow.s(10); height: sysLayout.pillHeight;
                                clip: true
                                
                                property real targetWidth: kbLayoutRow.implicitWidth + barWindow.s(24)
                                width: targetWidth
                                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }
                                
                                scale: isHovered ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on color { ColorAnimation { duration: 200 } }

                                property bool initAnimTrigger: false
                                Timer { running: rightContent.showLayout && !kbPill.initAnimTrigger; interval: 0; onTriggered: kbPill.initAnimTrigger = true }
                                opacity: initAnimTrigger ? 1 : 0
                                transform: Translate { y: kbPill.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                                Row { 
                                    id: kbLayoutRow
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: barWindow.s(12)
                                    spacing: barWindow.s(8)
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: "󰌌"; font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(16); color: typeof isHovered !== "undefined" && isHovered ? mocha.text : mocha.overlay2 }
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: barWindow.kbLayout; font.family: "JetBrains Mono"; font.pixelSize: barWindow.s(13); font.weight: Font.Black; color: mocha.text }
                                }
                                MouseArea { id: kbMouse; anchors.fill: parent; hoverEnabled: true; onClicked: Quickshell.execDetached(["hyprctl", "switchxkblayout", "main", "next"]) }
                            }

                            Rectangle {
                                id: wifiPill
                                property bool isHovered: wifiMouse.containsMouse
                                radius: barWindow.s(10); height: sysLayout.pillHeight; 
                                color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                                clip: true
                                
                                Rectangle {
                                    anchors.fill: parent
                                    radius: barWindow.s(10)
                                    opacity: barWindow.showEthernet ? (barWindow.ethStatus === "Connected" ? 1.0 : 0.0) : (barWindow.isWifiOn ? 1.0 : 0.0)
                                    Behavior on opacity { NumberAnimation { duration: 300 } }
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: mocha.blue }
                                        GradientStop { position: 1.0; color: Qt.lighter(mocha.blue, 1.3) }
                                    }
                                }

                                property real targetWidth: wifiLayoutRow.implicitWidth + barWindow.s(24)
                                width: targetWidth
                                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }
                                
                                scale: isHovered ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on color { ColorAnimation { duration: 200 } }

                                property bool initAnimTrigger: false
                                Timer { running: rightContent.showLayout && !wifiPill.initAnimTrigger; interval: 50; onTriggered: wifiPill.initAnimTrigger = true }
                                opacity: initAnimTrigger ? 1 : 0
                                transform: Translate { y: wifiPill.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                                Row { 
                                    id: wifiLayoutRow
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: barWindow.s(12)
                                    spacing: barWindow.s(8)
                                    Text { 
                                        anchors.verticalCenter: parent.verticalCenter; 
                                        text: barWindow.showEthernet ? "󰈀" : barWindow.wifiIcon;
                                        font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(16);
                                        color: barWindow.showEthernet ? (barWindow.ethStatus === "Connected" ? mocha.base : mocha.subtext0) : (barWindow.isWifiOn ? mocha.base : mocha.subtext0)
                                    }
                                    Text { 
                                        id: wifiText
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: barWindow.showLabels && text !== ""
                                        text: barWindow.showEthernet ? barWindow.ethStatus : ((barWindow.isWifiOn ? (barWindow.wifiSsid !== "" ? barWindow.wifiSsid : "On") : "Off"))
                                        font.family: "JetBrains Mono"; font.pixelSize: barWindow.s(13); font.weight: Font.Black;
                                        color: barWindow.showEthernet ? (barWindow.ethStatus === "Connected" ? mocha.base : mocha.text) : (barWindow.isWifiOn ? mocha.base : mocha.text);
                                        width: Math.min(implicitWidth, barWindow.s(100)); elide: Text.ElideRight 
                                    }
                                }
                                MouseArea { id: wifiMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle network wifi"]) }
                            }

                            Rectangle {
                                id: btPill
                                property bool isHovered: btMouse.containsMouse
                                radius: barWindow.s(10); height: sysLayout.pillHeight
                                clip: true
                                color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                                
                                Rectangle {
                                    anchors.fill: parent
                                    radius: barWindow.s(10)
                                    opacity: barWindow.isBtOn ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 300 } }
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: mocha.mauve }
                                        GradientStop { position: 1.0; color: Qt.lighter(mocha.mauve, 1.3) }
                                    }
                                }

                                property real targetWidth: barWindow.isDesktop ? 0 : btLayoutRow.implicitWidth + barWindow.s(24)
                                width: targetWidth
                                visible: targetWidth > 0
                                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }

                                scale: isHovered ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on color { ColorAnimation { duration: 200 } }

                                property bool initAnimTrigger: false
                                Timer { running: rightContent.showLayout && !btPill.initAnimTrigger; interval: 100; onTriggered: btPill.initAnimTrigger = true }
                                opacity: initAnimTrigger ? 1 : 0
                                transform: Translate { y: btPill.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                                Row { 
                                    id: btLayoutRow
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: barWindow.s(12)
                                    spacing: barWindow.s(8)
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: barWindow.btIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(16); color: barWindow.isBtOn ? mocha.base : mocha.subtext0 }
                                    Text { 
                                        id: btText
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: barWindow.btDevice
                                        visible: barWindow.showLabels && text !== ""; 
                                        font.family: "JetBrains Mono"; font.pixelSize: barWindow.s(13); font.weight: Font.Black; 
                                        color: barWindow.isBtOn ? mocha.base : mocha.text; 
                                        width: Math.min(implicitWidth, barWindow.s(100)); elide: Text.ElideRight 
                                    }
                                }
                                MouseArea { id: btMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle network bt"]) }
                            }

                            Rectangle {
                                id: volPill
                                property bool isHovered: volMouse.containsMouse
                                color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4)
                                radius: barWindow.s(10); height: sysLayout.pillHeight;
                                clip: true

                                Rectangle {
                                    anchors.fill: parent
                                    radius: barWindow.s(10)
                                    opacity: barWindow.isSoundActive ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 300 } }
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: mocha.peach }
                                        GradientStop { position: 1.0; color: Qt.lighter(mocha.peach, 1.3) }
                                    }
                                }
                                
                                property real targetWidth: volLayoutRow.implicitWidth + barWindow.s(24)
                                width: targetWidth
                                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }
                                
                                scale: isHovered ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on color { ColorAnimation { duration: 200 } }

                                property bool initAnimTrigger: false
                                Timer { running: rightContent.showLayout && !volPill.initAnimTrigger; interval: 150; onTriggered: volPill.initAnimTrigger = true }
                                opacity: initAnimTrigger ? 1 : 0
                                transform: Translate { y: volPill.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                                Row { 
                                    id: volLayoutRow
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: barWindow.s(12)
                                    spacing: barWindow.s(8)
                                    Text { 
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: barWindow.volIcon; font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.s(16); 
                                        color: barWindow.isSoundActive ? mocha.base : mocha.subtext0 
                                    }
                                    Text { 
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: barWindow.showLabels
                                        text: barWindow.volPercent; 
                                        font.family: "JetBrains Mono"; font.pixelSize: barWindow.s(13); font.weight: Font.Black; 
                                        color: barWindow.isSoundActive ? mocha.base : mocha.text; 
                                    }
                                }
                                MouseArea { id: volMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle volume"]) }
                            }

                            Rectangle {
                                id: powerPill
                                property bool isHovered: powerMouse.containsMouse
                                color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4); 
                                radius: barWindow.s(10); height: sysLayout.pillHeight;
                                clip: true

                                Rectangle {
                                    anchors.fill: parent
                                    radius: barWindow.s(10)
                                    opacity: barWindow.powerProfile === "performance" ? 1.0 : (barWindow.powerProfile === "power-saver" ? 0.8 : 0.0)
                                    Behavior on opacity { NumberAnimation { duration: 300 } }
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: barWindow.powerProfile === "performance" ? mocha.mauve : mocha.green; Behavior on color { ColorAnimation { duration: 300 } } }
                                        GradientStop { position: 1.0; color: barWindow.powerProfile === "performance" ? Qt.lighter(mocha.mauve, 1.3) : Qt.lighter(mocha.green, 1.3); Behavior on color { ColorAnimation { duration: 300 } } }
                                    }
                                }
                                
                                property real targetWidth: (barWindow.showLabels ? powerLayoutRow.implicitWidth : barWindow.s(16)) + barWindow.s(24)
                                width: targetWidth
                                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }
                                
                                scale: isHovered ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on color { ColorAnimation { duration: 200 } }

                                property bool initAnimTrigger: false
                                Timer { running: rightContent.showLayout && !powerPill.initAnimTrigger; interval: 200; onTriggered: powerPill.initAnimTrigger = true }
                                opacity: initAnimTrigger ? 1 : 0
                                transform: Translate { y: powerPill.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                                Row { 
                                    id: powerLayoutRow
                                    anchors.centerIn: parent
                                    spacing: barWindow.s(8)
                                    Text { 
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: barWindow.powerProfile === "performance" ? "" : (barWindow.powerProfile === "power-saver" ? "" : "󰾆");
                                        font.family: "Iosevka Nerd Font"; 
                                        font.pixelSize: barWindow.s(16); 
                                        color: (barWindow.powerProfile === "performance" || barWindow.powerProfile === "power-saver") ? mocha.base : mocha.subtext0 
                                        Behavior on color { ColorAnimation { duration: 300 } }
                                    }
                                    Text { 
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: barWindow.powerProfile === "performance" ? "Turbo" : (barWindow.powerProfile === "power-saver" ? "Eco" : "Auto"); 
                                        font.family: "JetBrains Mono"; font.pixelSize: barWindow.s(13); font.weight: Font.Black; 
                                        color: (barWindow.powerProfile === "performance" || barWindow.powerProfile === "power-saver") ? mocha.base : mocha.text 
                                        Behavior on color { ColorAnimation { duration: 300 } }
                                    }
                                }
                                MouseArea {
                                    id: powerMouse; hoverEnabled: true; anchors.fill: parent;
                                    onClicked: {
                                        let nextProfile = (barWindow.powerProfile === "performance") ? "power-saver" : ((barWindow.powerProfile === "power-saver") ? "balanced" : "performance");
                                        barWindow.powerProfile = nextProfile;
                                        Quickshell.execDetached(["powerprofilesctl", "set", nextProfile]);
                                        Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/turbo_inhibitor.sh", nextProfile === "performance" ? "start" : "stop"]);
                                    }
                                }
                            }
                                                            Rectangle {
                                id: batPill
                                property bool isHovered: batMouse.containsMouse
                                color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.6) : Qt.rgba(mocha.surface0.r, mocha.surface0.g, mocha.surface0.b, 0.4); 
                                radius: barWindow.s(10); height: sysLayout.pillHeight;
                                clip: true

                                Rectangle {
                                    anchors.fill: parent
                                    radius: barWindow.s(10)
                                    opacity: 1.0 
                                    Behavior on opacity { NumberAnimation { duration: 300 } }
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: barWindow.isDesktop ? mocha.red : barWindow.batDynamicColor; Behavior on color { ColorAnimation { duration: 300 } } }
                                        GradientStop { position: 1.0; color: barWindow.isDesktop ? Qt.lighter(mocha.red, 1.3) : Qt.lighter(barWindow.batDynamicColor, 1.3); Behavior on color { ColorAnimation { duration: 300 } } }
                                    }
                                }
                                
                                property real targetWidth: barWindow.isDesktop ? barWindow.s(34) : batLayoutRow.implicitWidth + barWindow.s(24)
                                width: targetWidth
                                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutQuint } }
                                
                                scale: isHovered ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on color { ColorAnimation { duration: 200 } }

                                property bool initAnimTrigger: false
                                Timer { running: rightContent.showLayout && !batPill.initAnimTrigger; interval: 250; onTriggered: batPill.initAnimTrigger = true }
                                opacity: initAnimTrigger ? 1 : 0
                                transform: Translate { y: batPill.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 500; easing.type: Easing.OutBack } } }
                                Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                                Row { 
                                    id: batLayoutRow
                                    anchors.centerIn: parent
                                    spacing: barWindow.s(8)
                                    Text { 
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: barWindow.isDesktop ? "" : barWindow.batIcon; 
                                        font.family: "Iosevka Nerd Font"; font.pixelSize: barWindow.isDesktop ? barWindow.s(18) : barWindow.s(16); 
                                        color: mocha.base 
                                        Behavior on color { ColorAnimation { duration: 300 } }
                                    }
                                    Text { 
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: !barWindow.isDesktop && barWindow.showLabels
                                        text: barWindow.batPercent; font.family: "JetBrains Mono"; font.pixelSize: barWindow.s(13); font.weight: Font.Black;
                                        color: mocha.base 
                                        Behavior on color { ColorAnimation { duration: 300 } }
                                    }
                                }
                                MouseArea { id: batMouse; hoverEnabled: true; anchors.fill: parent; onClicked: Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/qs_manager.sh toggle battery"]) }
                            }                       
                 }
            }
            Rectangle {
                        id: recButton
                        property bool isHovered: recMouse.containsMouse
                        
                        color: isHovered ? Qt.rgba(mocha.surface1.r, mocha.surface1.g, mocha.surface1.b, 0.95) : Qt.rgba(mocha.base.r, mocha.base.g, mocha.base.b, barWindow.barAlpha)
                        radius: barWindow.s(14)
                        border.width: 1
                        border.color: Qt.rgba(mocha.text.r, mocha.text.g, mocha.text.b, isHovered ? 0.15 : 0.05)

                        property real targetWidth: barWindow.isRecording ? barWindow.barHeight : 0
                        width: targetWidth
                        height: barWindow.barHeight 

                        visible: targetWidth > 0 || opacity > 0
                        opacity: barWindow.isRecording ? 1.0 : 0.0
                        clip: true

                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                        
                        scale: isHovered ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }
                        Behavior on color { ColorAnimation { duration: 200 } }

                        Text {
                            id: recIcon
                            anchors.centerIn: parent
                            text: "" 
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: barWindow.s(20)
                            color: mocha.red
                            
                            SequentialAnimation on opacity {
                                running: barWindow.isRecording && !recButton.isHovered
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                            }
                            SequentialAnimation on scale {
                                running: barWindow.isRecording && !recButton.isHovered
                                loops: Animation.Infinite
                                NumberAnimation { to: 1.15; duration: 600; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                            }
                        }
                        
                        MouseArea {
                            id: recMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                barWindow.isRecording = false; 
                                Quickshell.execDetached(["bash", "-c", "~/.config/hypr/scripts/screenshot.sh"]); 
                            }
                        }
                    }
                }
            }
        }
    }
}
