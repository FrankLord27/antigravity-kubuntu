import QtCore
import QtQuick
import QtMultimedia
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.taskmanager as TaskManager
import "pal.js" as Pal

// Dock arcade: iconos sobre una repisa neón, zoom al acercar el cursor,
// y una nave que sigue al ratón y dispara al icono al hacer clic.
Item {
    id: dock
    property var launchers: []
    signal launchersEdited(var list)                  // el usuario ancló o desancló una app
    property rect screenGeometry                      // pantalla del panel: solo se listan sus ventanas
    readonly property int lane: 26                      // carril de la nave, bajo la repisa
    readonly property int shelfY: height - lane
    readonly property int big: Math.max(24, Math.min(80, shelfY - 6))
    readonly property int base: Math.round(big * 0.76)
    readonly property int slot: base + 22
    readonly property int pad: 12
    property real mx: -1
    readonly property int hi: mx < pad ? -1 : Math.min(icons.count - 1, Math.floor((mx - pad) / slot))
    implicitWidth: Math.max(1, icons.count) * slot + 2 * pad

    TaskManager.TasksModel {
        id: tasks
        filterByVirtualDesktop: false
        filterByScreen: true
        screenGeometry: dock.screenGeometry
        filterByActivity: false
        groupMode: TaskManager.TasksModel.GroupDisabled
        sortMode: TaskManager.TasksModel.SortManual
        launchInPlace: true
        launcherList: dock.launchers
    }

    SoundEffect { id: pew; source: StandardPaths.writableLocation(StandardPaths.HomeLocation) + "/.local/share/sounds/arcade/wav/pew.wav"; volume: 0.6 }

    // repisa
    Rectangle { y: dock.shelfY; width: parent.width; height: 3; color: Pal.purple }
    Rectangle { y: dock.shelfY + 3; x: 3; width: parent.width - 6; height: 3; color: Pal.lip }
    Rectangle { y: dock.shelfY - 6; width: 3; height: 6; color: Pal.purple }
    Rectangle { y: dock.shelfY - 6; x: parent.width - 3; width: 3; height: 6; color: Pal.purple }

    Repeater {
        id: icons
        model: tasks
        delegate: Item {
            id: cell
            readonly property bool isWindow: model.IsWindow === true
            readonly property bool isActive: model.IsActive === true
            readonly property bool isMinimized: model.IsMinimized === true
            readonly property bool isMaximized: model.IsMaximized === true
            readonly property url launcherUrl: model.LauncherUrlWithoutIcon || ""
            readonly property string title: model.AppName || model.display || ""
            readonly property real k: dock.mx < 0 ? 0 : Math.exp(-Math.pow((dock.mx - (x + dock.slot / 2)) / (dock.slot * 0.8), 2))
            property real size: dock.base + (dock.big - dock.base) * k
            property real hop: 0
            function bounce() { hopAnim.restart(); }
            Behavior on size { NumberAnimation { duration: 90 } }
            x: dock.pad + index * dock.slot
            z: k
            width: dock.slot
            height: dock.height

            SequentialAnimation {
                id: hopAnim
                PauseAnimation { duration: 90 }
                NumberAnimation { target: cell; property: "hop"; to: 12; duration: 110; easing.type: Easing.OutQuad }
                NumberAnimation { target: cell; property: "hop"; to: 0; duration: 340; easing.type: Easing.OutBounce }
            }
            Item {
                id: pic
                width: Math.round(cell.size)
                height: width
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: dock.lane + 3 + cell.hop
                // baja resolución ampliada sin suavizado: todo icono queda pixelado
                layer.enabled: true
                layer.smooth: false
                layer.textureSize: Qt.size(32, 32)
                Kirigami.Icon {
                    anchors.fill: parent
                    source: model.decoration
                    smooth: false
                }
            }
            // corchetes de selección
            Item {
                anchors.centerIn: pic
                width: pic.width + 10
                height: pic.height + 10
                opacity: index === dock.hi ? 1 : 0
                Repeater {
                    model: 4
                    Item {
                        x: index % 2 ? parent.width - 10 : 0
                        y: index > 1 ? parent.height - 10 : 0
                        width: 10; height: 10
                        Rectangle { width: 10; height: 2; y: index > 1 ? 8 : 0; color: Pal.cyan }
                        Rectangle { width: 2; height: 10; x: index % 2 ? 8 : 0; color: Pal.cyan }
                    }
                }
            }
            // luz en la repisa: app abierta / activa
            Rectangle {
                visible: cell.isWindow
                y: dock.shelfY - 1
                width: cell.isActive ? dock.slot - 8 : dock.slot - 30
                height: 7
                anchors.horizontalCenter: parent.horizontalCenter
                color: cell.isActive ? Pal.cyan : Pal.green
                Behavior on width { NumberAnimation { duration: 120 } }
            }
        }
    }

    // nave
    PixSprite {
        id: ship
        rows: Pal.ship
        px: 2
        color: Pal.fg
        x: Math.max(0, Math.min(dock.width - width, dock.mx - width / 2))
        y: dock.shelfY + 7
        opacity: dock.mx >= 0 ? 1 : 0
        Behavior on x { NumberAnimation { duration: 70 } }
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Rectangle { x: 12; y: 18; width: 2; height: 3; color: Pal.orange }
    }
    Rectangle {
        id: laser
        width: 4; height: 16
        color: Pal.cyan
        visible: false
        Rectangle { x: 1; width: 2; height: 10; color: "white" }
    }
    Item {
        id: burst
        property real t: 1
        property color tint: Pal.cyan
        visible: t < 1
        Repeater {
            model: 10
            Rectangle {
                readonly property real a: index * Math.PI * 2 / 10
                width: 6; height: 6
                x: Math.cos(a) * burst.t * (34 + 10 * (index % 3)) - 3
                y: Math.sin(a) * burst.t * (34 + 10 * (index % 3)) - 3
                opacity: 1 - burst.t
                color: index % 3 === 0 ? "white" : (index % 3 === 1 ? burst.tint : Pal.yellow)
            }
        }
    }
    SequentialAnimation {
        id: shot
        property real toY: 0
        PropertyAction { target: laser; property: "visible"; value: true }
        NumberAnimation { target: laser; property: "y"; from: dock.shelfY - 16; to: shot.toY; duration: 90 }
        PropertyAction { target: laser; property: "visible"; value: false }
        NumberAnimation { target: burst; property: "t"; from: 0; to: 1; duration: 380; easing.type: Easing.OutQuad }
    }
    function fire(i, cell) {
        pew.play();
        const cx = cell.x + dock.slot / 2;
        laser.x = cx - 2;
        shot.toY = dock.shelfY - 3 - cell.size / 2;
        burst.x = cx;
        burst.y = shot.toY;
        burst.tint = Pal.neon[i % Pal.neon.length];
        shot.restart();
        cell.bounce();
    }

    // menú contextual de cada icono
    PlasmaExtras.Menu {
        id: menu
        property int row: -1
        property var cell: null
        readonly property bool win: cell !== null && cell.isWindow
        readonly property bool pinned: cell !== null && tasks.launcherPosition(cell.launcherUrl) !== -1
        placement: PlasmaExtras.Menu.TopPosedLeftAlignedPopup
        function show(i, c) {
            row = i;
            cell = c;
            visualParent = c;
            openRelative();
        }
        function index() { return tasks.makeModelIndex(row); }
        function pin(add) {
            if (add)
                tasks.requestAddLauncher(cell.launcherUrl);
            else
                tasks.requestRemoveLauncher(cell.launcherUrl);
            dock.launchersEdited(tasks.launcherList);
        }

        PlasmaExtras.MenuItem { section: true; text: menu.cell ? menu.cell.title : "" }
        PlasmaExtras.MenuItem { text: "Abrir nueva ventana"; icon: "window-new"; onClicked: tasks.requestNewInstance(menu.index()) }
        PlasmaExtras.MenuItem { separator: true; visible: menu.win }
        PlasmaExtras.MenuItem {
            visible: menu.win
            text: menu.cell && menu.cell.isMinimized ? "Restaurar" : "Minimizar"
            icon: "window-minimize"
            onClicked: tasks.requestToggleMinimized(menu.index())
        }
        PlasmaExtras.MenuItem {
            visible: menu.win
            text: menu.cell && menu.cell.isMaximized ? "Restaurar tamaño" : "Maximizar"
            icon: "window-maximize"
            onClicked: tasks.requestToggleMaximized(menu.index())
        }
        PlasmaExtras.MenuItem { separator: true }
        PlasmaExtras.MenuItem { visible: !menu.pinned; text: "Anclar al dock"; icon: "window-pin"; onClicked: menu.pin(true) }
        PlasmaExtras.MenuItem { visible: menu.pinned; text: "Desanclar del dock"; icon: "window-unpin"; onClicked: menu.pin(false) }
        PlasmaExtras.MenuItem { separator: true; visible: menu.win }
        PlasmaExtras.MenuItem { visible: menu.win; text: "Cerrar"; icon: "window-close"; onClicked: tasks.requestClose(menu.index()) }
    }

    PlasmaCore.ToolTipArea {
        anchors.fill: parent
        active: dock.hi >= 0
        mainText: dock.hi >= 0 && icons.itemAt(dock.hi) ? icons.itemAt(dock.hi).title : ""
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onPositionChanged: mouse => dock.mx = mouse.x
            onExited: dock.mx = -1
            onClicked: mouse => {
                const i = dock.hi;
                const cell = icons.itemAt(i);
                if (!cell)
                    return;
                if (mouse.button === Qt.RightButton) {
                    menu.show(i, cell);
                    return;
                }
                const mi = tasks.makeModelIndex(i);
                dock.fire(i, cell);
                if (mouse.button === Qt.MiddleButton)
                    tasks.requestNewInstance(mi);
                else if (cell.isWindow && cell.isActive)
                    tasks.requestToggleMinimized(mi);
                else
                    tasks.requestActivate(mi);
            }
        }
    }
}
