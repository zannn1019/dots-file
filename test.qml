import QtQuick
import Quickshell

Item {
    Component.onCompleted: {
        function debugLog(message, title = "Debug Log") {
            let strMsg = message;
            if (typeof message === "object") {
                try {
                    strMsg = JSON.stringify(message, null, 2);
                } catch (e) {
                    console.log("caught error");
                    strMsg = String(message);
                }
            } else {
                strMsg = String(message);
            }
            console.log("strMsg is:", strMsg, typeof strMsg);
            try {
                Quickshell.execDetached(["notify-send", "-a", "QML Debug", title, strMsg]);
            } catch (e) {
                console.log("Error running execDetached:", e);
            }
            console.log("[" + title + "]", strMsg);
        }

        console.log("Running object that stringifies to undefined");
        debugLog(Qt, "Test undefined");
        Qt.quit();
    }
}
