import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore

// En un panel muestra el dock; sobre el escritorio muestra el HUD del sistema.
PlasmoidItem {
    id: root
    readonly property bool desk: Plasmoid.formFactor === PlasmaCore.Types.Planar
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: desk ? PlasmaCore.Types.NoBackground : PlasmaCore.Types.DefaultBackground

    fullRepresentation: Item {
        readonly property int w: view.item ? view.item.implicitWidth : 16
        Layout.minimumWidth: w
        Layout.preferredWidth: w
        Layout.maximumWidth: root.desk ? -1 : w
        Layout.minimumHeight: root.desk && view.item ? view.item.implicitHeight : 0
        Layout.preferredHeight: root.desk && view.item ? view.item.implicitHeight : -1

        Loader {
            id: view
            anchors.fill: parent
            source: root.desk ? "Hud.qml" : "Dock.qml"
        }
        Connections {
            target: root.desk ? null : view.item
            ignoreUnknownSignals: true
            function onLaunchersEdited(list) { Plasmoid.configuration.launchers = list; }
        }
        Binding {
            target: view.item
            property: "city"
            value: Plasmoid.configuration.city
            when: root.desk && view.status === Loader.Ready
        }
        Binding {
            target: view.item
            property: "latitude"
            value: Plasmoid.configuration.latitude
            when: root.desk && view.status === Loader.Ready
        }
        Binding {
            target: view.item
            property: "longitude"
            value: Plasmoid.configuration.longitude
            when: root.desk && view.status === Loader.Ready
        }
        Binding {
            target: view.item
            property: "screenGeometry"
            value: Plasmoid.containment.screenGeometry
            when: !root.desk && view.status === Loader.Ready
        }
        Binding {
            target: view.item
            property: "launchers"
            value: Plasmoid.configuration.launchers
            when: !root.desk && view.status === Loader.Ready
        }
    }
}
