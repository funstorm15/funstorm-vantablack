import QtQuick 2.0
import SddmComponents 2.0

Rectangle {
  id: root
  width: 640
  height: 480
  color: "#000000"

  // lastUser is empty until someone has logged in through SDDM once, so fall
  // back to the first real user instead of sending an empty username to PAM.
  property string currentUser: {
    if (userModel.lastUser)
      return userModel.lastUser
    if (userModel.count > 0) {
      var name = userModel.data(userModel.index(0, 0), Qt.UserRole + 1)
      if (name)
        return name.toString()
    }
    return ""
  }
  property bool loginFailed: false
  property bool loggingIn: false
  property int sessionIndex: {
    for (var i = 0; i < sessionModel.rowCount(); i++) {
      var name = (sessionModel.data(sessionModel.index(i, 0), Qt.DisplayRole) || "").toString()
      if (name.indexOf("uwsm") !== -1)
        return i
    }
    // FunStorm/KDE: remembered session first, else Plasma (Wayland)
    if (sessionModel.lastIndex >= 0 && sessionModel.lastIndex < sessionModel.rowCount())
      return sessionModel.lastIndex
    for (var j = 0; j < sessionModel.rowCount(); j++) {
      var n = (sessionModel.data(sessionModel.index(j, 0), Qt.DisplayRole) || "").toString()
      if (n.indexOf("Plasma") !== -1 && n.indexOf("X11") === -1)
        return j
    }
    return 0
  }

  Connections {
    target: sddm
    function onLoginFailed() {
      root.loggingIn = false
      root.loginFailed = true
      password.text = ""
      password.focus = true
    }
    function onLoginSucceeded() {
      root.loggingIn = false
      root.loginFailed = false
    }
  }

  Column {
    anchors.centerIn: parent
    spacing: 40

    Image {
      id: logo
      source: "logo.png"
      width: Math.min(sourceSize.width, root.width * 0.8)
      height: sourceSize.width > 0 ? Math.round(width * sourceSize.height / sourceSize.width) : 0
      fillMode: Image.PreserveAspectFit
      anchors.horizontalCenter: parent.horizontalCenter
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 15

      Image {
        source: root.loginFailed ? "lock-failed.png" : "lock.png"
        width: 34
        height: 38
        fillMode: Image.PreserveAspectFit
        anchors.verticalCenter: parent.verticalCenter
      }

      Item {
        width: entry.width
        height: entry.height

        Image {
          id: entry
          source: root.loginFailed ? "entry-failed.png" : "entry.png"
          anchors.centerIn: parent
        }

        Row {
          anchors.left: parent.left
          anchors.leftMargin: 20
          anchors.verticalCenter: parent.verticalCenter
          spacing: 5

          Repeater {
            model: Math.min(password.text.length, 21)

            Image {
              source: "bullet.png"
              width: 7
              height: 7
            }
          }
        }

        TextInput {
          id: password
          anchors.fill: parent
          anchors.leftMargin: 20
          anchors.rightMargin: 20
          verticalAlignment: TextInput.AlignVCenter
          echoMode: TextInput.Password
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 24
          font.letterSpacing: 5
          passwordCharacter: "\u2022"
          color: "transparent"
          selectionColor: "transparent"
          selectedTextColor: "transparent"
          cursorDelegate: Item {}
          focus: true

          onTextChanged: root.loginFailed = false

          Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              event.accepted = true
              if (root.loggingIn)
                return
              root.loggingIn = true
              sddm.login(root.currentUser, password.text, root.sessionIndex)
            }
          }
        }
      }
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.loginFailed ? "Wrong password" : (root.loggingIn ? "Logging in\u2026" : " ")
      color: root.loginFailed ? "#ececec" : "#7a7a7a"
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 16
    }

  }

  Component.onCompleted: password.forceActiveFocus()
}
