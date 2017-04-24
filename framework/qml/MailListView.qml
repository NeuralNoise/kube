/*
  Copyright (C) 2016 Michael Bohlender, <michael.bohlender@kdemail.net>

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program; if not, write to the Free Software Foundation, Inc.,
  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
*/

import QtQuick 2.7
import QtQuick.Controls 2.0
import QtQuick.Controls 1.4 as Controls
import QtQuick.Layouts 1.1

import org.kube.framework 1.0 as Kube

Item {
    id: root
    //InterfaceProperties
    property string filterString
    //Private properties
    property variant parentFolder: null
    property bool isDraft : false
    property bool isImportant : false
    property bool isTrash : false
    property bool isUnread : false

    Kube.Listener {
        filter: Kube.Messages.folderSelection
        onMessageReceived: {
            parentFolder = message.folder
            Kube.Fabric.postMessage(Kube.Messages.mailSelection, {"mail":null})
        }
    }

    Kube.MailController {
        id: mailController
        unread: root.isUnread
        trash: root.isTrash
        important: root.isImportant
        draft: root.isDraft
        operateOnThreads: mailListModel.isThreaded
    }

    Kube.Listener {
        id: controllerListener
        filter: Kube.Messages.mailSelection
        onMessageReceived: {
            mailController.mail = message.mail
        }
    }

    Shortcut {
        sequence: StandardKey.Delete
        onActivated: mailController.moveToTrashAction.execute()
        enabled: mailController.moveToTrashAction.enabled
    }
    Shortcut {
        sequence: StandardKey.MoveToNextLine
        onActivated: root.currentIndex++
    }
    Shortcut {
        sequence: StandardKey.MoveToPreviousLine
        onActivated: root.currentIndex--
    }

    Kube.Label {
        anchors.centerIn: parent
        visible: listView.count === 0
        //TODO depending on whether we synchronized already or not the label should change.
        text: "Nothing here..."
    }

    ListView {
        id: listView

        anchors.fill: parent
        focus: true
        clip: true

        ScrollBar.vertical: ScrollBar{
            id: scrollbar
        }

        //BEGIN keyboard nav
        Keys.onDownPressed: {
            incrementCurrentIndex()
        }
        Keys.onUpPressed: {
            decrementCurrentIndex()
        }
        //END keyboard nav

        onCurrentItemChanged: {
            Kube.Fabric.postMessage(Kube.Messages.mailSelection, {"mail":currentItem.currentData.mail})
            root.isDraft = currentItem.currentData.draft;
            root.isTrash = currentItem.currentData.trash;
            root.isImportant = currentItem.currentData.important;
            root.isUnread = currentItem.currentData.unread;
        }

        model: Kube.MailListModel {
            id: mailListModel
            parentFolder: root.parentFolder
            filter: root.filterString
        }

        delegate: Item {
            id: origin

            property variant currentData: model

            width: delegateRoot.width
            height: delegateRoot.height

            Item {
                id: delegateRoot

                property variant mail : model.domainObject

                width: scrollbar.visible ? listView.width - scrollbar.width : listView.width
                height: Kube.Units.gridUnit * 5

                states: [
                State {
                    name: "dnd"
                    when: mouseArea.drag.active

                    PropertyChanges {target: mouseArea; cursorShape: Qt.ClosedHandCursor}
                    PropertyChanges {target: delegateRoot; x: x; y:y}
                    PropertyChanges {target: delegateRoot; parent: root}

                    PropertyChanges {target: delegateRoot; opacity: 0.7}
                    PropertyChanges {target: background; color: Kube.Colors.highlightColor}
                    PropertyChanges {target: subject; color: Kube.Colors.highlightedTextColor}
                    PropertyChanges {target: sender; color: Kube.Colors.highlightedTextColor}
                    PropertyChanges {target: date; color: Kube.Colors.highlightedTextColor}
                    PropertyChanges {target: threadCounter; color: Kube.Colors.highlightedTextColor}
                },
                State {
                    name: "selected"
                    when: listView.currentIndex == index && !mouseArea.drag.active

                    PropertyChanges {target: background; color: Kube.Colors.highlightColor}
                    PropertyChanges {target: subject; color: Kube.Colors.highlightedTextColor}
                    PropertyChanges {target: sender; color: Kube.Colors.highlightedTextColor}
                    PropertyChanges {target: threadCounter; color: Kube.Colors.highlightedTextColor}
                    PropertyChanges {target: date; visible: false}
                    PropertyChanges {target: buttons; visible: true}
                },
                State {
                    name: "hovered"
                    when: ( mouseArea.containsMouse || buttons.containsMouse ) && !mouseArea.drag.active

                    PropertyChanges {target: background; color: Kube.Colors.highlightColor; opacity: 0.6}
                    PropertyChanges {target: subject; color: Kube.Colors.highlightedTextColor}
                    PropertyChanges {target: sender; color: Kube.Colors.highlightedTextColor}
                    PropertyChanges {target: date; color: Kube.Colors.highlightedTextColor}
                    PropertyChanges {target: threadCounter; color: Kube.Colors.highlightedTextColor}
                }
                ]

                Drag.active: mouseArea.drag.active
                Drag.hotSpot.x: mouseArea.mouseX
                Drag.hotSpot.y: mouseArea.mouseY
                Drag.source: delegateRoot

                MouseArea {
                    id: mouseArea

                    anchors.fill: parent

                    hoverEnabled: true
                    drag.target: parent

                    onClicked: {
                        listView.currentIndex = index
                    }
                    onReleased: parent.Drag.drop()
                }

                Rectangle {
                    id: background

                    anchors.fill: parent

                    color: Kube.Colors.viewBackgroundColor

                    border.color: Kube.Colors.backgroundColor
                    border.width: 1
                }

                Item {
                    id: content

                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                        left: parent.left
                        right: parent.right
                        margins: Kube.Units.smallSpacing
                    }

                    Column {
                        anchors {
                            verticalCenter: parent.verticalCenter
                            left: parent.left
                            leftMargin: Kube.Units.largeSpacing
                        }

                        Kube.Label{
                            id: subject

                            width: content.width - Kube.Units.gridUnit * 3

                            text: model.subject
                            color: model.unread ? Kube.Colors.highlightColor : Kube.Colors.textColor
                            maximumLineCount: 2
                            wrapMode: Text.WrapAnywhere
                            elide: Text.ElideRight
                        }

                        Kube.Label {
                            id: sender

                            text: model.senderName
                            font.italic: true
                            width: delegateRoot.width - Kube.Units.gridUnit * 3
                            elide: Text.ElideRight
                        }
                    }

                    Kube.Label {
                        id: date

                        anchors {
                            right: parent.right
                            bottom: parent.bottom
                        }
                        text: Qt.formatDateTime(model.date, "dd MMM yyyy")
                        font.italic: true
                        color: Kube.Colors.disabledTextColor
                        font.pointSize: 9
                    }

                    Kube.Label {
                        id: threadCounter

                        anchors {
                            right: parent.right
                        }
                        text: model.threadSize
                        color: model.unread ?  Kube.Colors.highlightColor  : Kube.Colors.disabledTextColor
                        visible: model.threadSize > 1
                    }
                }

                Row {
                    id: buttons

                    property bool containsMouse: importantButton.hovered || deleteButton.hovered || unreadButton.hovered || readButton.hovered

                    anchors {
                        right: parent.right
                        bottom: parent.bottom
                        margins: Kube.Units.smallSpacing
                    }

                    visible: false
                    spacing: Kube.Units.smallSpacing
                    opacity: 0.7

                    Kube.Button {
                        id: readButton
                        text: "r"
                        enabled: mailController.markAsReadAction.enabled
                        visible: enabled
                        onClicked: {
                            mailController.markAsReadAction.execute()
                        }
                    }
                    Kube.Button {
                        id: unreadButton
                        text: "u"
                        enabled: mailController.markAsUnreadAction.enabled
                        visible: enabled
                        onClicked: {
                            mailController.markAsUnreadAction.execute()
                        }
                    }

                    Kube.Button {
                        id: importantButton
                        text: "i"
                        enabled: mailController.toggleImportantAction.enabled
                        visible: enabled
                        onClicked: {
                            mailController.toggleImportantAction.execute()
                        }
                    }

                    Kube.Button {
                        id: deleteButton
                        text: "d"
                        enabled: mailController.moveToTrashAction.enabled
                        visible: enabled
                        onClicked: {
                            mailController.moveToTrashAction.execute()
                        }
                    }

                    Kube.Button {
                        id: restoreButton
                        text: "re"
                        enabled: mailController.restoreFromTrashAction.enabled
                        visible: enabled
                        onClicked: {
                            mailController.restoreFromTrashAction.execute()
                        }
                    }
                }
            }
        }
    }
}
