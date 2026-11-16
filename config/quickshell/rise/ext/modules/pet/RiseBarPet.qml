import QtQuick
import qs.ext.services as Services

// rise: the bar pet (BarPet) in rise's bar island (BarSlot loads this by
// URL). The island is 32px tall and the pet is drawn for a 42px bar, so it's
// scaled down; `gapsPx` (the island's free stretches, in its own x) are
// scaled to match.
Item {
    id: host

    property var gapsPx: [[0, width]]
    property var barScreen: null
    readonly property real petScale: height / 40

    onBarScreenChanged: Services.Pet.barScreen = barScreen
    Component.onCompleted: Services.Pet.barScreen = barScreen

    BarPet {
        transformOrigin: Item.TopLeft
        scale: host.petScale
        width: host.width / host.petScale
        height: host.height / host.petScale
        gaps: host.gapsPx.map(g => [g[0] / host.petScale, g[1] / host.petScale])
    }
}
