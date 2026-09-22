import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Simple one-click launcher for each installed coding agent.
// Does not change ~/.config/omarchy/defaults/agent.
Panel {
  id: root
  moduleName: "hippie.agent-launch"
  ipcTarget: "hippie.agent-launch"
  manageIpc: false

  property var agents: []
  property string defaultAgent: ""
  property int cursorIndex: 0
  property bool cursorActive: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  // Resolved URLs are percent-encoded; argv needs the plain path.
  readonly property string pluginDir: decodeURIComponent(Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, ""))
  readonly property var installedAgents: {
    var out = []
    for (var i = 0; i < agents.length; i++)
      if (agents[i].installed) out.push(agents[i])
    return out
  }

  // Required: without these the bar slot collapses to 0px and the icon vanishes.
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!listProc.running) listProc.running = true
    if (!defaultProc.running) defaultProc.running = true
  }

  function clampCursor() {
    cursorIndex = Math.max(0, Math.min(cursorIndex, Math.max(0, installedAgents.length - 1)))
  }

  // Park the hidden cursor on the default agent so the first j/k reveals it
  // there, like the stock power panel does with the active profile.
  function resetCursor() {
    if (cursorActive) return
    cursorIndex = 0
    for (var i = 0; i < installedAgents.length; i++)
      if (installedAgents[i].id === defaultAgent) cursorIndex = i
  }

  function moveCursor(dy) {
    if (installedAgents.length === 0) return
    if (!cursorActive) { cursorActive = true; return }
    cursorIndex += dy
    clampCursor()
  }

  function launchAt(index) {
    if (index < 0 || index >= installedAgents.length) return
    // Login shell like bar.run/omarchy-agent: same PATH, and cwd stays the
    // shell's so launch-agent's $HOME -> ~/Work rule applies.
    Util.execArgv([pluginDir + "/bin/launch-agent", installedAgents[index].id])
    root.close()
  }

  function launchSelected() {
    if (!cursorActive) return
    clampCursor()
    launchAt(cursorIndex)
  }

  onInstalledAgentsChanged: { clampCursor(); resetCursor() }
  onDefaultAgentChanged: resetCursor()

  onOpenedChanged: {
    if (opened) {
      cursorActive = false
      resetCursor()
      refresh()
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }
  }

  Component.onCompleted: refresh()

  Process {
    id: listProc
    command: [root.pluginDir + "/bin/list-agents"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var lines = String(text || "").split("\n")
        var next = []
        for (var i = 0; i < lines.length; i++) {
          var line = lines[i].trim()
          if (!line) continue
          var parts = line.split("|")
          if (parts.length < 3) continue
          next.push({
            id: parts[0],
            label: parts[1],
            installed: parts[2] === "1"
          })
        }
        root.agents = next
      }
    }
  }

  Process {
    id: defaultProc
    command: ["omarchy-default-agent"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.defaultAgent = String(text || "").trim()
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(); return "ok" }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "AI"
    labelVisible: true
    hasVisualContent: true
    horizontalMargin: 8.75
    verticalPadding: 8.75
    tooltipText: root.opened ? "" : "Launch an agent"
    onPressed: function(buttonCode) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) root.moveCursor(dy)
      }
      onActivateRequested: root.launchSelected()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        Column {
          width: parent.width
          spacing: Style.space(2)

          Text {
            text: "Launch agent"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            textFormat: Text.PlainText
          }

          Text {
            visible: root.defaultAgent !== ""
            text: "Default stays " + root.defaultAgent
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            textFormat: Text.PlainText
          }
        }

        PanelSeparator { foreground: root.foreground }

        Column {
          width: parent.width
          spacing: Style.space(4)

          Repeater {
            model: root.installedAgents

            Button {
              required property var modelData
              required property int index
              width: column.width
              text: modelData.label
              fontSize: Style.font.body
              foreground: root.foreground
              fontFamily: root.fontFamily
              horizontalPadding: Style.spacing.controlPaddingX
              verticalPadding: Style.spacing.controlPaddingY + Style.space(4)
              bordered: true
              active: root.defaultAgent === modelData.id
              hasCursor: root.cursorActive && root.cursorIndex === index
              onClicked: root.launchAt(index)
              onHovered: function(h) {
                if (h) {
                  root.cursorActive = true
                  root.cursorIndex = index
                }
              }
            }
          }

          Text {
            visible: root.installedAgents.length === 0
            width: parent.width
            wrapMode: Text.WordWrap
            text: "No agents found on PATH."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            textFormat: Text.PlainText
          }
        }

        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          text: "Click to open, or j/k then Enter. Esc to close."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          textFormat: Text.PlainText
        }
      }
    }
  }
}
