import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Installed coding agents in the stock Agents panel's layout: the agent's
// mark and name, a small launch button, a switch between agents, and the
// last week of local usage. Does not change ~/.config/omarchy/defaults/agent.
Panel {
  id: root
  moduleName: "hippie.agent-launch"
  ipcTarget: "hippie.agent-launch"
  manageIpc: false

  property var agents: []
  property string defaultAgent: ""
  // Parsed bin/agent-usage output: { agents: { id: { days, sessions, ... } } }.
  property var usage: ({ agents: {} })
  // Selection follows the agent id, so a list refresh never swaps what you
  // were reading.
  property string selectedId: ""
  property bool cursorActive: false
  property double nowMs: Date.now()

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color surface: Color.popups.background
  readonly property color track: Style.selectedFillFor(foreground, Color.accent)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  // Resolved URLs are percent-encoded; argv needs the plain path.
  readonly property string pluginDir: decodeURIComponent(Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, ""))

  readonly property var installedAgents: {
    var out = []
    for (var i = 0; i < agents.length; i++)
      if (agents[i].installed) out.push(agents[i])
    return out
  }
  readonly property int agentIndex: {
    for (var i = 0; i < installedAgents.length; i++)
      if (installedAgents[i].id === selectedId) return i
    return 0
  }
  readonly property var agent: installedAgents.length > 0 ? installedAgents[agentIndex] : null
  readonly property var stats: agent && usage.agents ? (usage.agents[agent.id] || null) : null
  readonly property bool showsTokens: !!stats && stats.tokens !== null && stats.tokens !== undefined

  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  function refresh() {
    nowMs = Date.now()
    if (!listProc.running) listProc.running = true
    if (!defaultProc.running) defaultProc.running = true
    if (!usageProc.running) usageProc.running = true
  }

  function selectAgent(index) {
    if (installedAgents.length === 0) return
    var wrapped = ((index % installedAgents.length) + installedAgents.length) % installedAgents.length
    selectedId = installedAgents[wrapped].id
  }

  // Open on the default agent, like the stock panel opens on the first
  // provider; fall back to the first installed one.
  function selectDefault() {
    for (var i = 0; i < installedAgents.length; i++)
      if (installedAgents[i].id === defaultAgent) { selectedId = defaultAgent; return }
    if (installedAgents.length > 0 && agentIndex === 0) selectedId = installedAgents[0].id
  }

  function launchSelected() {
    if (!agent) return
    // Login shell like bar.run/omarchy-agent: same PATH, and cwd stays the
    // shell's so launch-agent's $HOME -> ~/Work rule applies.
    Util.execArgv([pluginDir + "/bin/launch-agent", agent.id])
    root.close()
  }

  function formatCount(n) {
    if (n === undefined || n === null) return "0"
    if (n >= 1e9) return (n / 1e9).toFixed(1) + "B"
    if (n >= 1e6) return (n / 1e6).toFixed(1) + "M"
    if (n >= 1e3) return (n / 1e3).toFixed(1) + "K"
    return String(n)
  }

  function formatAgo(ms) {
    var minutes = Math.floor((nowMs - ms) / 60000)
    if (minutes < 1) return "just now"
    if (minutes < 60) return minutes + "m ago"
    var hours = Math.floor(minutes / 60)
    if (hours < 24) return hours + "h ago"
    return Math.floor(hours / 24) + "d ago"
  }

  function heroMeta() {
    if (!agent) return ""
    if (!stats) return agent.id === defaultAgent ? "Default agent" : "Installed"
    if (!stats.lastUsed) return "Not used yet"
    return "Last used " + formatAgo(stats.lastUsed)
  }

  function dayValue(day) {
    if (!day) return 0
    return Number((showsTokens ? day.tokens : day.sessions) || 0)
  }

  function dayLabel(date, today) {
    if (today) return "Today"
    var parsed = new Date(String(date || "") + "T00:00:00")
    if (isNaN(parsed.getTime())) return String(date || "")
    return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][parsed.getDay()]
  }

  function dayTooltip(day) {
    if (!day) return ""
    var parsed = new Date(String(day.date) + "T00:00:00")
    var label = isNaN(parsed.getTime()) ? String(day.date)
      : dayLabel(day.date, false) + " " + (parsed.getMonth() + 1) + "/" + parsed.getDate()
    var text = label + " · " + day.sessions + (day.sessions === 1 ? " session" : " sessions")
    if (day.tokens !== null && day.tokens !== undefined) text += " · " + formatCount(day.tokens) + " tokens"
    return text
  }

  function weekSummary() {
    if (!stats) return ""
    var text = stats.sessions + (stats.sessions === 1 ? " session" : " sessions") + " this week"
    if (showsTokens) text += " · " + formatCount(stats.tokens) + " tokens"
    return text
  }

  // Marks resolve by convention: assets/<id>-light.svg on light surfaces when
  // it exists, then assets/<id>.svg, then the bar glyph.
  function colorChannelLuminance(value) {
    var channel = Number(value)
    if (!isFinite(channel)) return 0
    return channel <= 0.03928 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4)
  }

  function colorLuminance(color) {
    return 0.2126 * colorChannelLuminance(color.r)
      + 0.7152 * colorChannelLuminance(color.g)
      + 0.0722 * colorChannelLuminance(color.b)
  }

  function iconCandidates(a, surfaceColor) {
    if (!a) return []
    var candidates = []
    if (colorLuminance(surfaceColor || Color.background) >= 0.5)
      candidates.push(Qt.resolvedUrl("assets/" + a.id + "-light.svg"))
    candidates.push(Qt.resolvedUrl("assets/" + a.id + ".svg"))
    return candidates
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onInstalledAgentsChanged: if (selectedId === "") selectDefault()
  onDefaultAgentChanged: selectDefault()

  onOpenedChanged: {
    if (opened) {
      cursorActive = false
      selectedId = ""
      selectDefault()
      if (panelFlick) panelFlick.contentY = 0
      refresh()
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }
  }

  Component.onCompleted: refresh()

  Process {
    id: listProc
    // Login shell, same as launchSelected, so detection sees the PATH launches get.
    command: ["bash", "-lc", 'exec "$@"', "bash", root.pluginDir + "/bin/list-agents"]
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

  Process {
    id: usageProc
    command: [root.pluginDir + "/bin/agent-usage"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var parsed = JSON.parse(String(text || ""))
          if (parsed && parsed.agents) root.usage = parsed
        } catch (e) {
          // Keep the last good snapshot; launching still works without it.
        }
      }
    }
  }

  Timer {
    interval: 30000
    running: root.opened
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(); return "ok" }
  }

  // Same glyph as the stock Agents widget.
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󱚣"
    onPressed: function(buttonCode) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        if (dx !== 0) {
          root.cursorActive = true
          root.selectAgent(root.agentIndex + dx)
        }
        if (dy !== 0)
          panelFlick.contentY = root.clamp(panelFlick.contentY + dy * Style.space(56), 0,
                                           Math.max(0, panelFlick.contentHeight - panelFlick.height))
      }
      onActivateRequested: root.launchSelected()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          // ---------- Hero: agent mark · name · last used · launch ----------
          PanelHero {
            visible: !!root.agent
            width: parent.width
            title: root.agent ? root.agent.label : ""
            meta: root.heroMeta()
            foreground: root.foreground
            fontFamily: root.fontFamily

            iconComponent: Component {
              Item {
                id: heroMark
                property var candidates: root.iconCandidates(root.agent, root.surface)
                property string candidatesKey: candidates.join("\n")
                property int candidateIndex: 0
                onCandidatesKeyChanged: candidateIndex = 0

                width: Style.font.display
                height: Style.font.display

                Image {
                  id: heroMarkImage
                  anchors.fill: parent
                  source: heroMark.candidateIndex < heroMark.candidates.length ? heroMark.candidates[heroMark.candidateIndex] : ""
                  sourceSize.width: Style.font.display * 2
                  sourceSize.height: Style.font.display * 2
                  fillMode: Image.PreserveAspectFit
                  // Advancing source from inside its own status change trips the
                  // binding-loop detector; defer the step one tick.
                  onStatusChanged: if (status === Image.Error && heroMark.candidateIndex < heroMark.candidates.length)
                    Qt.callLater(function() { heroMark.candidateIndex++ })
                }

                Text {
                  textFormat: Text.PlainText
                  anchors.centerIn: parent
                  visible: heroMarkImage.status !== Image.Ready
                  text: button.text
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                }
              }
            }

            trailingControl: Component {
              Button {
                text: "Launch"
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                verticalPadding: Style.spacing.controlPaddingY
                tooltipText: root.agent ? "Open " + root.agent.label + " in a terminal" : ""
                onClicked: root.launchSelected()
              }
            }
          }

          Text {
            visible: root.installedAgents.length === 0
            width: parent.width
            topPadding: Style.space(24)
            text: "No coding agents found on PATH."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }

          // ---------- Agent switch ----------
          Row {
            id: agentSwitch
            visible: root.installedAgents.length > 1
            width: parent.width
            spacing: Style.spacing.md

            readonly property real cellWidth: root.installedAgents.length > 0
              ? (width - spacing * (root.installedAgents.length - 1)) / root.installedAgents.length
              : 0

            Repeater {
              model: root.installedAgents

              Button {
                required property var modelData
                required property int index

                width: agentSwitch.cellWidth
                text: modelData.label
                selected: index === root.agentIndex
                hasCursor: root.cursorActive && index === root.agentIndex
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: {
                  root.cursorActive = true
                  root.selectAgent(index)
                }
                onHovered: function(isHovered) { if (isHovered) root.cursorActive = true }
              }
            }
          }

          // ---------- Usage ----------
          PanelSeparator {
            visible: !!root.agent
            foreground: root.foreground
          }

          Column {
            id: usageSection
            visible: !!root.stats
            width: parent.width
            spacing: Style.spacing.md

            readonly property var days: root.stats ? (root.stats.days || []) : []
            readonly property real peak: {
              var m = 1
              for (var i = 0; i < days.length; i++) m = Math.max(m, root.dayValue(days[i]))
              return m
            }

            PanelSectionHeader {
              width: parent.width
              text: root.showsTokens ? "TOKENS BY DAY" : "SESSIONS BY DAY"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: usageSection.days

              DayRow {
                required property var modelData
                required property int index

                width: usageSection.width
                day: modelData
                ratio: root.dayValue(modelData) / usageSection.peak
                today: index === usageSection.days.length - 1
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            visible: !!root.agent
            width: parent.width
            topPadding: Style.space(2)
            text: root.stats ? root.weekSummary() : "No usage history for this agent"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
          }
        }
      }
    }
  }

  // One row per day: label, bar, value. Today is picked out in full
  // foreground so the week reads as a run-up to right now.
  component DayRow: Item {
    id: dayRow
    property var day: null
    property real ratio: 0
    property bool today: false

    implicitHeight: Math.max(dayLabel.implicitHeight, dayValue.implicitHeight) + Style.spacing.sm

    Text {
      id: dayLabel
      textFormat: Text.PlainText
      text: root.dayLabel(dayRow.day ? dayRow.day.date : "", dayRow.today)
      color: dayRow.today ? root.foreground : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: dayRow.today
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(52)
    }

    Rectangle {
      id: dayTrack
      anchors.left: dayLabel.right
      anchors.right: dayValue.left
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      height: Math.max(Style.space(4), Math.round(Style.spacing.controlHeight * 0.14))
      radius: height / 2
      color: root.track

      Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        radius: parent.radius
        width: parent.width * root.clamp(dayRow.ratio, 0, 1)
        color: dayRow.today ? root.foreground : root.alpha(root.foreground, 0.55)

        Behavior on width {
          NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
      }
    }

    Text {
      id: dayValue
      textFormat: Text.PlainText
      text: root.formatCount(root.dayValue(dayRow.day))
      color: dayRow.today ? root.foreground : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      horizontalAlignment: Text.AlignRight
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(52)
    }

    MouseArea {
      id: dayHover
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
    }

    PanelToolTip {
      visible: dayHover.containsMouse
      text: root.dayTooltip(dayRow.day)
      fontFamily: root.fontFamily
    }
  }
}
