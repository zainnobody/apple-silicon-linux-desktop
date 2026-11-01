/*
    Flat replacement for the Breeze WallpaperFader (distro-pack/desktop). No blur, no colour shader, no shadow.
    The wallpaper is drawn once as it is. The password block, footer and clock fade in and out as in Breeze.
    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.kirigami as Kirigami

Item {
    id: fader
    property Item clock
    property Item mainStack
    property Item footer
    property Item source
    property bool alwaysShowClock: false

    state: "on"

    ShaderEffectSource {
        anchors.fill: parent
        sourceItem: fader.source
        live: true
        hideSource: true
        textureMirroring: ShaderEffectSource.NoMirroring
    }

    states: [
        State {
            name: "on"
            PropertyChanges {
                mainStack.opacity: 1
                footer.opacity: 1
                clock.opacity: 1
            }
        },
        State {
            name: "off"
            PropertyChanges {
                mainStack.opacity: 0
                footer.opacity: 0
                clock.opacity: fader.alwaysShowClock ? 1 : 0
            }
        }
    ]
    transitions: [
        Transition {
            NumberAnimation {
                targets: [fader.mainStack, fader.footer, fader.clock]
                property: "opacity"
                duration: Kirigami.Units.shortDuration
                easing.type: Easing.OutQuad
            }
        }
    ]
}
