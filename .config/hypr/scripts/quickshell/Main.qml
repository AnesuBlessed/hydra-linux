import QtQuick
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "WindowRegistry.js" as Registry

import "notifications" as Notifs

PanelWindow {
    id: masterWindow
    color: "transparent"

    Caching { id: paths }

    IpcHandler {
        target: "main"

        function forceReload() {
            Quickshell.reload(true)
        }

        function handleCommand(cmd: string, targetWidget: string, arg: string) {
            cmd = cmd || "";
            targetWidget = targetWidget || "";
            arg = arg || "";

            let isClosing = (masterWindow.currentActive !== "hidden" && !masterWindow.isVisible);
            let effectivelyActive = isClosing ? "hidden" : masterWindow.currentActive;

            if (cmd === "close") {
                switchWidget("hidden", "");
            } else if (cmd === "toggle" || cmd === "open") {
                delayedClear.stop();

                if (targetWidget === effectivelyActive) {
                    let currentItem = widgetStack.currentItem;

                    if (arg !== "" && currentItem && currentItem.activeMode !== undefined && currentItem.activeMode !== arg) {
                        currentItem.activeMode = arg;
                    } else if (cmd === "toggle") {
                        switchWidget("hidden", "");
                    }
                } else if (getLayout(targetWidget)) {
                    switchWidget(targetWidget, arg);
                }
            } else if (getLayout(cmd)) {
                let legacyArg = targetWidget;
                delayedClear.stop();

                if (cmd === effectivelyActive) {
                    let currentItem = widgetStack.currentItem;
                    if (legacyArg !== "" && currentItem && currentItem.activeMode !== undefined && currentItem.activeMode !== legacyArg) {
                        currentItem.activeMode = legacyArg;
                    } else {
                        switchWidget("hidden", "");
                    }
                } else {
                    switchWidget(cmd, legacyArg);
                }
            }
        }
    }

    WlrLayershell.namespace: "qs-master"
    WlrLayershell.layer: WlrLayer.Overlay

    exclusionMode: ExclusionMode.Ignore
    focusable: true

    implicitWidth: masterWindow.screen.width
    implicitHeight: masterWindow.screen.height

    visible: isVisible

    mask: Region { item: topBarHole; intersection: Intersection.Xor }

    Item {
        id: topBarHole
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 48

        anchors.leftMargin: (masterWindow.currentActive !== "hidden" && masterWindow.animX < 10 && masterWindow.animY < height) ? masterWindow.animW : 0
        anchors.rightMargin: (masterWindow.currentActive !== "hidden" && (masterWindow.animX + masterWindow.animW) > (parent.width - 10) && masterWindow.animY < height) ? masterWindow.animW : 0

        Behavior on anchors.leftMargin {
            enabled: masterWindow.currentActive !== "hidden"
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
        Behavior on anchors.rightMargin {
            enabled: masterWindow.currentActive !== "hidden"
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: masterWindow.isVisible
        onClicked: switchWidget("hidden", "")
    }

    property string currentActive: "hidden"

    onCurrentActiveChanged: {
        GlobalSettingsWatcher.currentActiveWidget = currentActive;
    }

    property bool isVisible: false
    property string activeArg: ""
    property bool disableMorph: false

    property int morphDuration: 230
    property int morphDurationSwitch: 210
    property int exitDuration: 160

    property real animW: 1
    property real animH: 1
    property real animX: 0
    property real animY: 0

    property real targetW: 1
    property real targetH: 1

    property real globalUiScale: GlobalSettingsWatcher.uiScale
    // Sampled once from Hyprland by GlobalSettingsWatcher. Feeds the layout
    // calculator so the reserved window matches the popups' own Scaler.
    property real dpiScale: GlobalSettingsWatcher.dpiScale

    // =========================================================
    // --- DAEMON: NOTIFICATION HANDLING
    // =========================================================
    ListModel { id: globalNotificationHistory }
    ListModel { id: activePopupsModel }

    property var liveNotifs: ({})
    property int _popupCounter: 0

    // --- NEW: Startup Grace Period Flag & Timer ---
    property bool isStartup: true
    Timer {
        interval: 500
        running: true
        onTriggered: masterWindow.isStartup = false
    }

    function removePopup(uid) {
        for (let i = 0; i < activePopupsModel.count; i++) {
            if (activePopupsModel.get(i).uid === uid) {
                activePopupsModel.remove(i);
                break;
            }
        }
    } 

    NotificationServer {
        id: globalNotificationServer
        bodySupported: true
        actionsSupported: true
        imageSupported: true

        onNotification: (n) => {
            n.tracked = true;

            let extractedActions = [];
            if (n.actions) {
                for (let i = 0; i < n.actions.length; i++) {
                    extractedActions.push({
                        "id": n.actions[i].identifier || "",
                        "text": n.actions[i].text || n.actions[i].name || "Action"
                    });
                }
            }

            masterWindow._popupCounter++;
            let currentUid = masterWindow._popupCounter;

            // Always store the live object so the history center can interact with it
            masterWindow.liveNotifs[currentUid] = n;

            let notifData = {
                "appName":     n.appName  !== "" ? n.appName  : "System",
                "summary":     n.summary  !== "" ? n.summary  : "No Title",
                "body":        n.body     !== "" ? n.body     : "",
                "iconPath":    n.appIcon  !== "" ? n.appIcon  : "",
                "actionsJson": JSON.stringify(extractedActions),
                "uid":         currentUid,
                "notif":       n
            };

            // Always silently add to the history list
            globalNotificationHistory.insert(0, notifData);

            // --- CHANGED: Only trigger the visual popup if we are past the startup phase ---
            if (!masterWindow.isStartup) {
                activePopupsModel.append(notifData);
                osdPopups.storeNotif(currentUid, n);
            }
        }
    }

    property var notifModel: globalNotificationHistory

    Notifs.NotificationPopups {
        id: osdPopups
        popupModel: activePopupsModel
        uiScale: masterWindow.globalUiScale
        onRemoveRequested: (uid) => masterWindow.removePopup(uid)
    }
    onGlobalUiScaleChanged: { handleNativeScreenChange(); }

    // uiScale is owned by GlobalSettingsWatcher (a singleton) rather than a
    // third independent `cat` + inotifywait pair reading the same file.

    // =========================================================
    // --- LAYOUT CACHE
    // =========================================================
    property var    _layoutCache:    ({})
    property string _layoutCacheKey: ""

    function getLayout(name) {
        let key = name + "|" + masterWindow.width + "|" + masterWindow.height + "|" + masterWindow.globalUiScale + "|" + masterWindow.dpiScale;
        if (_layoutCacheKey === key) return _layoutCache[key];
        let result = Registry.getLayout(name, 0, 0, masterWindow.width, masterWindow.height, masterWindow.globalUiScale, masterWindow.dpiScale);
        _layoutCache = {};
        _layoutCache[key] = result;
        _layoutCacheKey = key;
        return result;
    }

    Connections {
        target: masterWindow
        function onWidthChanged()  { _layoutCacheKey = ""; handleNativeScreenChange(); }
        function onHeightChanged() { _layoutCacheKey = ""; handleNativeScreenChange(); }
    }

    // dpiScale is a root property (not on masterWindow), so its change handler
    // lives here. Without this the layout cache would be keyed on a stale
    // dpiScale and every popup would be reserved at the wrong size.
    Connections {
        target: masterWindow
        function onDpiScaleChanged() { _layoutCacheKey = ""; }
    }

    function handleNativeScreenChange() {
        if (masterWindow.currentActive === "hidden") return;

        let t = getLayout(masterWindow.currentActive);
        if (!t) return;

        let currentItem = widgetStack.currentItem;
        let finalW = (currentItem && currentItem.targetMasterWidth  !== undefined) ? currentItem.targetMasterWidth  : t.w;
        let finalH = (currentItem && currentItem.targetMasterHeight !== undefined) ? currentItem.targetMasterHeight : t.h;
        let finalX = t.rx;
        if (currentItem && currentItem.targetMasterWidth !== undefined && finalW !== t.w) {
            finalX = Math.floor((masterWindow.width / 2) - (finalW / 2));
        }

        masterWindow.animX = finalX;
        masterWindow.animY = t.ry;
        masterWindow.animW = finalW;
        masterWindow.animH = finalH;
        masterWindow.targetW = finalW;
        masterWindow.targetH = finalH;
    }

    onIsVisibleChanged: {
        if (isVisible) widgetStack.forceActiveFocus();
    }

    // =========================================================
    // --- ANIMATED BOUNDING BOX
    // =========================================================
    Item {
        x: masterWindow.animX
        y: masterWindow.animY
        width:  masterWindow.animW
        height: masterWindow.animH
        clip: true

        Behavior on x {
            enabled: !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            enabled: !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
        Behavior on width {
            enabled: !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            enabled: !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }

        opacity: masterWindow.isVisible ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation {
                duration: 160
                easing.type: masterWindow.isVisible ? Easing.OutCubic : Easing.InCubic
            }
        }

        MouseArea { anchors.fill: parent }

        Item {
            anchors.fill: parent

            StackView {
                id: widgetStack
                anchors.fill: parent
                focus: true

                Keys.onEscapePressed: (event) => {
                    switchWidget("hidden", "");
                    event.accepted = true;
                }

                onCurrentItemChanged: {
                    if (currentItem) currentItem.forceActiveFocus();
                }

                replaceEnter: Transition {
                    ParallelAnimation {
                        NumberAnimation {
                            property: "opacity"
                            from: 0.0; to: 1.0
                            duration: masterWindow.morphDurationSwitch
                            easing.type: Easing.OutQuint
                        }
                        NumberAnimation {
                            property: "scale"
                            from: 0.98; to: 1.0
                            duration: masterWindow.morphDurationSwitch
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                replaceExit: Transition {
                    ParallelAnimation {
                        NumberAnimation {
                            property: "opacity"
                            from: 1.0; to: 0.0
                            duration: masterWindow.morphDurationSwitch
                            easing.type: Easing.InQuint
                        }
                        NumberAnimation {
                            property: "scale"
                            from: 1.0; to: 0.98
                            duration: masterWindow.morphDurationSwitch
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }

    // =========================================================
    // --- WIDGET SWITCHING
    // =========================================================
    function switchWidget(newWidget, arg) {
        delayedClear.stop();

        if (newWidget === "hidden") {
            if (currentActive !== "hidden") {
                masterWindow.currentActive = "hidden";
                masterWindow.morphDuration = masterWindow.exitDuration;
                masterWindow.disableMorph = false;

                masterWindow.animW = 1;
                masterWindow.animH = 1;
                masterWindow.isVisible = false;

                delayedClear.start();
            }
        } else {
            if (currentActive === "hidden" || !masterWindow.isVisible) {
                masterWindow.morphDuration = 230;
                masterWindow.disableMorph = false;

                let t = getLayout(newWidget);
                masterWindow.animX = t.rx;
                masterWindow.animY = t.ry;
                masterWindow.animW = t.w;
                masterWindow.animH = t.h;
                masterWindow.targetW = t.w;
                masterWindow.targetH = t.h;
            } else {
                masterWindow.morphDuration = masterWindow.morphDurationSwitch;
                masterWindow.disableMorph = false;
            }

            Qt.callLater(() => executeSwitch(newWidget, arg, false));
        }
    }

    function executeSwitch(newWidget, arg, immediate) {
        masterWindow.currentActive = newWidget;
        masterWindow.activeArg = arg;

        let t = getLayout(newWidget);
        masterWindow.animX = t.rx;
        masterWindow.animY = t.ry;
        masterWindow.animW = t.w;
        masterWindow.animH = t.h;
        masterWindow.targetW = t.w;
        masterWindow.targetH = t.h;

        let props = {};
        if (newWidget === "wallpaper" && arg !== "") props["widgetArg"] = arg;
        if (newWidget === "network" && arg !== "") props["activeMode"] = arg;
        if (newWidget === "battery") { props["notifModel"] = globalNotificationHistory; props["liveNotifs"] = masterWindow.liveNotifs; }

        if (immediate) {
            widgetStack.replace(t.comp, props, StackView.Immediate);
        } else {
            widgetStack.replace(t.comp, props);
        }

        let currentItem = widgetStack.currentItem;
        if (currentItem) {
            if (currentItem.targetMasterWidth !== undefined) {
                let dynW = currentItem.targetMasterWidth;
                masterWindow.animW = dynW;
                masterWindow.targetW = dynW;
                masterWindow.animX = Math.floor((masterWindow.width / 2) - (dynW / 2));
            }
            if (currentItem.targetMasterHeight !== undefined) {
                masterWindow.animH = currentItem.targetMasterHeight;
                masterWindow.targetH = currentItem.targetMasterHeight;
            }
        }

        masterWindow.isVisible = true;
    }

    // Popups gate their pollers and infinite animations on their root `visible`.
    // Nothing else ever set it, so those bindings were permanently true and the
    // gating was a no-op. Master owns the flag; this propagates it onto the
    // live StackView item so a closing popup stops polling immediately rather
    // than running on until it is destroyed.
    Connections {
        target: masterWindow
        function onIsVisibleChanged() {
            if (typeof widgetStack !== "undefined" && widgetStack.currentItem) {
                widgetStack.currentItem.visible = masterWindow.isVisible;
            }
        }
    }

    Timer {
        id: delayedClear
        interval: 200
        onTriggered: {
            masterWindow.currentActive = "hidden";
            if (widgetStack.currentItem) widgetStack.currentItem.visible = false;
            widgetStack.clear();
            masterWindow.disableMorph = false;
        }
    }
}
