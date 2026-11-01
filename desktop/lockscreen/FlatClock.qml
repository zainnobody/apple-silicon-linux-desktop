/*
    SPDX-License-Identifier: LGPL-2.0-or-later
    Flat clock for the M3 lock screen: the date above, a large time below. No shadow. Based on the Breeze Clock component (LGPL-2.0-or-later).
*/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.clock as PlasmaClock
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: root

    readonly property bool softwareRendering: GraphicsInfo.api === GraphicsInfo.Software
    spacing: 0

    PlasmaComponents3.Label {
        text: Qt.formatDate(timeSource.dateTime, Qt.locale(), Locale.LongFormat)
        textFormat: Text.PlainText
        style: root.softwareRendering ? Text.Outline : Text.Normal
        styleColor: root.softwareRendering ? Kirigami.Theme.backgroundColor : "transparent"
        font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize * 2.2)
        font.weight: Font.DemiBold
        renderType: Text.NativeRendering
        Layout.alignment: Qt.AlignHCenter
    }
    PlasmaComponents3.Label {
        text: Qt.formatTime(timeSource.dateTime, Qt.locale(), Locale.ShortFormat)
        textFormat: Text.PlainText
        style: root.softwareRendering ? Text.Outline : Text.Normal
        styleColor: root.softwareRendering ? Kirigami.Theme.backgroundColor : "transparent"
        font.pointSize: Math.round(Kirigami.Theme.defaultFont.pointSize * 8)
        font.weight: Font.Medium
        font.letterSpacing: -2.0
        renderType: Text.NativeRendering
        Layout.alignment: Qt.AlignHCenter
    }

    PlasmaClock.Clock {
        id: timeSource
        trackSeconds: Qt.locale().timeFormat(Locale.ShortFormat).includes("s")
    }
}
