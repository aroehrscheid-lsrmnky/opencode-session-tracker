import QtQuick
import Quickshell.Wayland
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs.Ui

Item {
    id: root
    property var shell
    property var manifest
    property bool opened: false

    function open(payloadJson) { root.opened = true }
    function close() {
        if (!root.opened) return
        root.opened = false
        if (shell && manifest && typeof shell.hide === 'function') shell.hide(manifest.id)
    }

    PanelWindow {
        id: panelWin
        visible: root.opened
        WlrLayershell.namespace: "opencode-sessions-panel"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.6)
            MouseArea { anchors.fill: parent; onClicked: root.close() }
        }

        Rectangle {
            id: card
            width: 1280
            height: 820
            radius: 12
            color: "#1e1e1e"
            anchors.centerIn: parent

            property string home: Quickshell.env("HOME")
            property string pluginDir: home + "/.config/omarchy/plugins/io.github.aroehrscheid-lsrmnky.opencode-sessions"
            property string cachePath: home + "/.cache/opencode-sessions/sessions.json"
            property string bookmarksPath: home + "/.cache/opencode-sessions/bookmarks.json"
            property string libraryPath: pluginDir + "/prompts.json"
            property var sessions: []
            property int activeSessionIndex: 0
            property var library: []
            property var bookmarks: []
            property bool sessionsCollapsed: false
            property bool bookmarkFilter: false
            property bool libPickerOpen: false
            property int viewMode: 0
            property string promptSearchText: ""
            property string librarySearchText: ""
            property var promptSearchInput: null
            property string sessionSearchText: ""
            property int mainTab: 0
            property string tagFilter: ""
            property string draftText: ""
            property string systemPromptText: ""
            property string libDraft: ""
            property string statusMsg: ""
            property int answerFontSize: 13
            property string answerFontFamily: "JetBrains Mono"
            property string selectedPromptAnswer: ""
            property int selectedPromptIndex: -1
            property int selectedPromptSession: 0
            property string selectedPromptText: ""
            readonly property real leftPaneWidth: Math.max(360, (contentArea.width - 8) * 0.42)
            property int answerPos: 0
            property int answerCount: 0
            property bool keyInjectionsOpen: false
            property var skills: []
            property var skillStyles: ({})
            property string skillSearchText: ""
            property string composeSkillSearchText: ""
            property var emojiPalette: ["💡", "🛠️", "⚡", "🧩", "🐛", "🎨", "📦", "🗂️", "🔧", "🧭", "🧪", "📐", "🚀", "🔒", "🤖", "🌱", "🔍", "📚", "✅", "⚙️", "🎯", "🔥"]
            property var colorPalette: ["#3a6df0", "#2f9e6f", "#c46b2f", "#8e44ad", "#16a2b8", "#c0392b", "#b8952f", "#e05555", "#555f6e", "#2fa84f", "#1f6feb", "#d29922", "#db6d28", "#a371f7", "#f778ba", "#39c5cf", "#56d364", "#ff7b72", "#8b949e", "#7ee787", "#ffa657", "#d2a8ff", "#e85d4a", "#4a9eda"]
            property var selectedSkills: []
            property bool cleanupOn: false
            property bool recordOn: false
            property string agentMode: "build"
            property bool sending: false
            property int trainingCount: 0
            property string trainingText: ""
            property string skillsPath: home + "/.cache/opencode-sessions/skills.json"
            property string skillStylesPath: home + "/.cache/opencode-sessions/skill_styles.json"
            property string trainingPath: home + "/.cache/opencode-sessions/training.jsonl"
            property string exporterPath: home + "/documents/opencode-session-tracker/exporter.py"
            property var keyInjections: [
                {label: "Code Review", text: "Review this code for bugs, performance issues, and best practices. Be thorough but concise."},
                {label: "Debug Helper", text: "Help me debug this issue. Ask clarifying questions if needed, then provide step-by-step debugging approach."},
                {label: "Doc Writer", text: "Write clear documentation for this code/function. Include purpose, parameters, return values, and examples."},
                {label: "Refactor Guide", text: "Suggest refactoring improvements for readability, maintainability, and performance. Show before/after."},
                {label: "Test Generator", text: "Generate comprehensive unit tests for this code. Cover edge cases, happy path, and error conditions."},
                {label: "Security Audit", text: "Analyze this code for security vulnerabilities. Check for injection, auth bypass, data exposure, etc."}
            ]

            onSessionsChanged: {
                if (activeSessionIndex >= sessions.length)
                    activeSessionIndex = Math.max(0, sessions.length - 1)
            }

            Component.onCompleted: skillsProc.running = true

            function setStatus(msg) {
                statusMsg = msg
                statusTimer.restart()
            }

            function savePrompt() {
                if (draftText.trim() === "") {
                    setStatus("Nothing to save")
                    return
                }
                saveProc.running = true
            }

            function showAnswer(promptIndex, answerText, sessionIndex) {
                if (sessionIndex !== undefined && sessionIndex !== activeSessionIndex)
                    activeSessionIndex = sessionIndex
                selectedPromptSession = activeSessionIndex
                var s = sessions[activeSessionIndex]
                var txt = ""
                if (s && s.recent_prompts && s.recent_prompts[promptIndex])
                    txt = String(s.recent_prompts[promptIndex].prompt || "")
                selectedPromptIndex = promptIndex
                selectedPromptText = txt
                selectedPromptAnswer = answerText || "⏳ No answer yet…"
                mainTab = 1
                updateAnswerPos()
            }

            function updateAnswerPos() {
                var list = filteredPrompts()
                answerCount = list.length
                answerPos = 0
                for (var i = 0; i < list.length; i++) {
                    if (list[i].originalIndex === selectedPromptIndex && list[i].sessionIndex === selectedPromptSession) { answerPos = i + 1; break }
                }
            }

            function openAnswer() {
                var list = filteredPrompts()
                if (list.length === 0) {
                    setStatus("No prompts in this session")
                    return
                }
                var pos = 0
                for (var i = 0; i < list.length; i++) {
                    if (list[i].originalIndex === selectedPromptIndex && list[i].sessionIndex === selectedPromptSession) { pos = i; break }
                }
                showAnswer(list[pos].originalIndex, list[pos].answer, list[pos].sessionIndex)
            }

            function navigateAnswer(delta) {
                var list = filteredPrompts()
                if (list.length === 0) return
                var pos = -1
                for (var i = 0; i < list.length; i++) {
                    if (list[i].originalIndex === selectedPromptIndex && list[i].sessionIndex === selectedPromptSession) { pos = i; break }
                }
                if (pos === -1) pos = delta > 0 ? 0 : list.length - 1
                else pos += delta
                pos = Math.max(0, Math.min(list.length - 1, pos))
                var p = list[pos]
                if (p.sessionIndex !== activeSessionIndex) activeSessionIndex = p.sessionIndex
                selectedPromptSession = p.sessionIndex
                selectedPromptIndex = p.originalIndex
                selectedPromptText = String(p.prompt || "")
                selectedPromptAnswer = p.answer || "⏳ No answer yet…"
                answerPos = pos + 1
                answerCount = list.length
                mainTab = 1
            }

            function showSessions() {
                mainTab = 0
                updateAnswerPos()
            }

            function showEditor() {
                viewMode = 0
                mainTab = 0
                selectedPromptIndex = -1
                selectedPromptAnswer = ""
                selectedPromptText = ""
            }

            function selectSession(i) {
                activeSessionIndex = i
                if (mainTab === 1) {
                    mainTab = 0
                    selectedPromptIndex = -1
                    selectedPromptAnswer = ""
                    selectedPromptText = ""
                }
            }

            function reloadCurrentAnswer() {
                if (selectedPromptIndex >= 0) {
                    var s = sessions[activeSessionIndex]
                    if (s && s.recent_prompts && s.recent_prompts[selectedPromptIndex]) {
                        var p = s.recent_prompts[selectedPromptIndex]
                        selectedPromptAnswer = p.answer || "⏳ No answer yet…"
                        setStatus("Answer refreshed")
                    }
                }
            }

            function isBookmarked(id) {
                return bookmarks.indexOf(id) !== -1
            }

            function toggleBookmark(id) {
                var arr = bookmarks.slice()
                var i = arr.indexOf(id)
                if (i >= 0) arr.splice(i, 1)
                else arr.push(id)
                bookmarks = arr
                bmView.setText(JSON.stringify(arr))
                setStatus(arr.indexOf(id) >= 0 ? "Session bookmarked" : "Bookmark removed")
            }

            function toggleBookmarkFilter() {
                bookmarkFilter = !bookmarkFilter
                if (bookmarkFilter && sessions.length > 0 && sessions[activeSessionIndex] && !isBookmarked(sessions[activeSessionIndex].id)) {
                    for (var i = 0; i < sessions.length; i++) {
                        if (isBookmarked(sessions[i].id)) {
                            activeSessionIndex = i
                            break
                        }
                    }
                }
                setStatus(bookmarkFilter ? ("Bookmarked only (" + sessionList().length + ")") : "Showing all sessions")
            }

            function sessionList() {
                var arr = []
                var q = sessionSearchText.toLowerCase()
                for (var i = 0; i < sessions.length; i++) {
                    if (bookmarkFilter && bookmarks.indexOf(sessions[i].id) === -1) continue
                    if (q !== "" && !String(sessions[i].title).toLowerCase().includes(q)) continue
                    arr.push(Object.assign({}, sessions[i], {originalIndex: i}))
                }
                return arr
            }

            function insertIntoDraft(txt) {
                if (!txt) return
                if (draftText.length > 0 && !draftText.endsWith("\n")) draftText += "\n"
                draftText += txt
            }

            function injectSystem(txt) {
                if (!txt) return
                if (systemPromptText.length > 0 && !systemPromptText.endsWith("\n")) systemPromptText += "\n"
                systemPromptText += txt
                if (!txt.endsWith("\n")) systemPromptText += "\n"
                setStatus("Injected: " + (txt.length > 30 ? txt.substring(0, 30) + "..." : txt))
            }

            function sessionEntries(idx) {
                var s = sessions[idx]
                if (!s || !s.recent_prompts) return []
                return s.recent_prompts.map((p, i) => Object.assign({}, p, {originalIndex: i, sessionIndex: idx}))
            }

            function filteredPrompts() {
                var q = promptSearchText.toLowerCase().trim()
                var entries = []
                if (q === "") {
                    entries = sessionEntries(activeSessionIndex)
                } else {
                    for (var i = 0; i < sessions.length; i++) entries = entries.concat(sessionEntries(i))
                }
                return entries.filter(p => {
                    return String(p.prompt).toLowerCase().includes(q)
                }).sort((a, b) => Number(b.time_created) - Number(a.time_created))
            }

            function libraryTags() {
                var tags = []
                for (var i = 0; i < library.length; i++) {
                    var itemTags = library[i].tags || []
                    for (var j = 0; j < itemTags.length; j++) {
                        if (tags.indexOf(itemTags[j]) === -1) tags.push(itemTags[j])
                    }
                }
                return tags
            }

            function filteredLibrary() {
                var q = librarySearchText.toLowerCase()
                return library.filter(p => {
                    var txt = String(p.text || "").toLowerCase().includes(q)
                    var tag = !tagFilter || (p.tags || []).indexOf(tagFilter) !== -1
                    return txt && tag
                })
            }

            function skillStyle(name) {
                return skillStyles[name] || {}
            }

            function skillHash(name) {
                var h = 0
                for (var i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) % 100000
                return h
            }

            function skillEmoji(name) {
                var st = skillStyles[name]
                if (st && st.emoji) return st.emoji
                return emojiPalette[skillHash(name) % emojiPalette.length]
            }

            function skillColor(name) {
                var st = skillStyles[name]
                if (st && st.color) return st.color
                return colorPalette[skillHash(name) % colorPalette.length]
            }

            function setSkillStyle(name, key, value) {
                var st = {}
                var cur = skillStyles[name]
                if (cur) { for (var k in cur) st[k] = cur[k] }
                st[key] = value
                var next = {}
                for (var nm in skillStyles) next[nm] = skillStyles[nm]
                next[name] = st
                skillStyles = next
                skillStylesView.setText(JSON.stringify(skillStyles, null, 2))
            }

            function filteredSkills() {
                var q = skillSearchText.toLowerCase().trim()
                if (q === "") return skills
                return skills.filter(sk => {
                    return String(sk.name).toLowerCase().includes(q) || String(sk.description || "").toLowerCase().includes(q)
                })
            }

            function filteredComposeSkills() {
                var q = composeSkillSearchText.toLowerCase().trim()
                if (q === "") return skills
                return skills.filter(sk => String(sk.name).toLowerCase().includes(q))
            }

            function skillSelected(name) {
                return selectedSkills.indexOf(name) !== -1
            }

            function toggleSkill(name) {
                var a = selectedSkills.slice()
                var i = a.indexOf(name)
                if (i >= 0) a.splice(i, 1)
                else a.push(name)
                selectedSkills = a
            }

            function skillsDirective() {
                if (selectedSkills.length === 0) return ""
                return "Use these skills: " + selectedSkills.join(", ") + "."
            }

            function composeRaw() {
                var parts = []
                var sd = skillsDirective()
                if (sd !== "") parts.push(sd)
                if (systemPromptText.trim() !== "") parts.push(systemPromptText.trim())
                if (draftText.trim() !== "") parts.push(draftText.trim())
                return parts.join("\n\n")
            }

            function currentCwd() {
                var s = sessions[activeSessionIndex]
                if (s && s.cwd && s.cwd !== "") return s.cwd
                return home
            }

            function sendPayload(newSession) {
                if (sending) return
                var raw = composeRaw()
                if (raw === "") {
                    setStatus("Nothing to send")
                    return
                }
                sending = true
                if (cleanupOn) {
                    refineProc.newSession = newSession
                    setStatus("Cleaning up prompt via BODI…")
                    refineProc.running = true
                } else {
                    finishSend(raw, newSession, false)
                }
            }

            function finishSend(payload, newSession, cleaned) {
                var s = sessions[activeSessionIndex]
                var job = {
                    session_id: newSession ? null : (s ? s.id : null),
                    cwd: currentCwd(),
                    agent: agentMode,
                    cleanup: cleaned,
                    cleanup_model: cleaned ? "ornith" : "",
                    selected_skills: selectedSkills,
                    system_prompt: systemPromptText,
                    user_prompt: draftText,
                    raw_payload: composeRaw(),
                    payload: payload,
                    record: recordOn
                }
                sendJobView.setText(JSON.stringify(job))
                sendProc.jobPath = home + "/.cache/opencode-sessions/send_job.json"
                setStatus(sending ? "Sending…" : "Sending…")
                sendProc.running = true
            }

            function copyPrompt(txt) {
                Quickshell.clipboardText = String(txt || "")
                setStatus("Prompt copied to clipboard")
            }

            Timer {
                id: statusTimer
                interval: 4000
                onTriggered: card.statusMsg = ""
            }

            FileView {
                id: cacheView
                path: card.cachePath
                watchChanges: true
                printErrors: false
                onFileChanged: reload()
                onLoaded: {
                    try {
                        var d = JSON.parse(String(text() || ""))
                        card.sessions = d.sessions || []
                    } catch (e) {}
                }
            }

            FileView {
                id: libView
                path: card.libraryPath
                watchChanges: true
                printErrors: false
                onFileChanged: reload()
                onLoaded: {
                    try {
                        var d = JSON.parse(String(text() || ""))
                        card.library = d.library || []
                    } catch (e) {
                        card.library = []
                    }
                }
            }

            FileView {
                id: bmView
                path: card.bookmarksPath
                watchChanges: true
                printErrors: false
                onFileChanged: reload()
                onLoaded: {
                    try {
                        card.bookmarks = JSON.parse(String(text() || "[]"))
                    } catch (e) {
                        card.bookmarks = []
                    }
                }
            }

            FileView {
                id: skillsView
                path: card.skillsPath
                watchChanges: true
                printErrors: false
                onFileChanged: reload()
                onLoaded: {
                    try {
                        card.skills = JSON.parse(String(text() || "{}")).skills || []
                    } catch (e) {
                        card.skills = []
                    }
                }
            }

            FileView {
                id: skillStylesView
                path: card.skillStylesPath
                watchChanges: true
                printErrors: false
                onFileChanged: reload()
                onLoaded: {
                    try {
                        card.skillStyles = JSON.parse(String(text() || "{}")) || {}
                    } catch (e) {
                        card.skillStyles = {}
                    }
                }
            }

            FileView {
                id: trainingView
                path: card.trainingPath
                watchChanges: true
                printErrors: false
                onFileChanged: reload()
                onLoaded: {
                    var t = String(text() || "").trim()
                    card.trainingText = t
                    card.trainingCount = t === "" ? 0 : t.split("\n").length
                }
            }

            FileView {
                id: sendJobView
                path: card.home + "/.cache/opencode-sessions/send_job.json"
                printErrors: false
            }

            Process {
                id: saveProc
                command: ["python3", card.pluginDir + "/scripts/save_prompt.py", card.draftText]
                onExited: (exitCode, exitStatus) => {
                    if (exitCode === 0) {
                        card.setStatus("Saved to library")
                        libView.reload()
                    } else {
                        card.setStatus("Save failed (exit " + exitCode + ")")
                    }
                }
            }

            Process {
                id: exportJsonProc
                command: ["python3", card.pluginDir + "/scripts/export_library.py"]
                stdout: SplitParser {
                    onRead: function(line) {
                        if (String(line).trim() !== "") card.setStatus("Exported: " + String(line).trim())
                    }
                }
            }

            Process {
                id: exportMdProc
                command: ["python3", card.pluginDir + "/scripts/export_library_md.py"]
                stdout: SplitParser {
                    onRead: function(line) {
                        if (String(line).trim() !== "") card.setStatus("Exported: " + String(line).trim())
                    }
                }
            }

            Process {
                id: importDialog
                command: ["python3", "-c", "import tkinter.filedialog as fd; print(fd.askopenfilename(), flush=True)"]
                stdout: SplitParser {
                    onRead: function(line) {
                        var p = String(line).trim()
                        if (p === "") return
                        importFile.command = ["python3", card.pluginDir + "/scripts/import_library.py", p]
                        importFile.running = true
                    }
                }
            }

            Process {
                id: importFile
                stdout: SplitParser {
                    onRead: function(line) {
                        if (String(line).trim() !== "") card.setStatus(String(line).trim())
                    }
                }
                onExited: libView.reload()
            }

            Process {
                id: skillsProc
                command: ["python3", card.pluginDir + "/scripts/list_skills.py"]
                onExited: skillsView.reload()
            }

            Process {
                id: refineProc
                property string buf: ""
                property bool newSession: false
                command: ["python3", card.pluginDir + "/scripts/refine_prompt.py"]
                stdinEnabled: true
                onStarted: write(JSON.stringify({
                    skills: card.selectedSkills,
                    system: card.systemPromptText,
                    user: card.draftText,
                    model: "ornith"
                }) + "\n")
                stdout: SplitParser {
                    onRead: function(line) { refineProc.buf += String(line) + "\n" }
                }
                onExited: (exitCode, exitStatus) => {
                    var out = refineProc.buf.trim()
                    refineProc.buf = ""
                    if (exitCode === 0 && out !== "" && out.indexOf("ERROR") !== 0) {
                        card.finishSend(out, refineProc.newSession, true)
                    } else {
                        card.sending = false
                        card.setStatus("Clean-up failed (exit " + exitCode + ")")
                    }
                }
            }

            Process {
                id: sendProc
                property string jobPath: ""
                command: jobPath === "" ? [] : ["python3", card.pluginDir + "/scripts/send_prompt.py", jobPath]
                stdout: SplitParser {
                    onRead: function(line) {
                        var t = String(line).trim()
                        if (t !== "") card.setStatus(t)
                    }
                }
                onExited: (exitCode, exitStatus) => {
                    card.sending = false
                    card.setStatus(exitCode === 0 ? (card.recordOn ? "Sent (recorded)" : "Sent") : ("Send failed (exit " + exitCode + ")"))
                    exporterProc.running = true
                    if (card.recordOn) trainingView.reload()
                }
            }

            Process {
                id: exporterProc
                command: ["python3", card.exporterPath]
                onExited: cacheView.reload()
            }

            Process {
                id: exportDatasetProc
                command: ["python3", card.pluginDir + "/scripts/export_dataset.py"]
                stdout: SplitParser {
                    onRead: function(line) {
                        if (String(line).trim() !== "") card.setStatus(String(line).trim())
                    }
                }
            }

            Shortcut { sequence: "Escape"; onActivated: root.close() }
            Shortcut { sequence: "Ctrl+F"; onActivated: { if (card.viewMode === 1) librarySearchField.forceActiveFocus(); else if (card.viewMode === 0 && card.promptSearchInput) card.promptSearchInput.forceActiveFocus() } }
            Shortcut { sequence: "Ctrl+W"; onActivated: card.draftText = "" }
            Shortcut { sequence: "Ctrl+S"; onActivated: card.savePrompt() }
            Shortcut { sequence: "Ctrl+E"; onActivated: card.showEditor() }
            Shortcut { sequence: "Ctrl+1"; onActivated: { card.viewMode = 0; card.mainTab = 0 } }
            Shortcut { sequence: "Ctrl+2"; onActivated: { card.viewMode = 0; card.openAnswer() } }
            Shortcut { sequence: "Ctrl+3"; onActivated: card.viewMode = 1 }
            Shortcut { sequence: "Ctrl+4"; onActivated: card.viewMode = 2 }
            Shortcut { sequence: "Ctrl+5"; onActivated: card.viewMode = 3 }
            Shortcut { sequence: "Ctrl+6"; onActivated: card.viewMode = 4 }
            Shortcut { sequence: "Ctrl+Return"; onActivated: card.sendPayload(false) }
            Shortcut { sequence: "Ctrl+Shift+Right"; onActivated: card.navigateAnswer(1) }
            Shortcut { sequence: "Ctrl+Shift+Left"; onActivated: card.navigateAnswer(-1) }
            Shortcut { sequence: "Ctrl+Shift+Up"; onActivated: card.openAnswer() }

            Column {
                id: headerCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                spacing: 8

                Text {
                    text: "OpenCode Session Tracker"
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                }

                Item {
                    id: topTabRow
                    width: headerCol.width
                    height: 28

                    Row {
                        id: topTabs
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Repeater {
                            model: ["Main", "Library", "Skills", "Stats", "Dataset"]
                            delegate: Rectangle {
                                width: 100
                                height: 28
                                radius: 6
                                color: card.viewMode === index ? "#3a6df0" : "#252525"
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: "white"
                                    font.pixelSize: 12
                                }
                                MouseArea { anchors.fill: parent; onClicked: card.viewMode = index }
                            }
                        }
                    }

                    TextField {
                        id: librarySearchField
                        visible: card.viewMode === 1
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 240
                        height: 28
                        placeholderText: "Search library..."
                        onTextChanged: card.librarySearchText = text
                        background: Rectangle { color: "#252525"; radius: 6 }
                        color: "white"
                    }
                }

                Item {
                    id: subTabRow
                    visible: card.viewMode === 0 || card.viewMode === 2
                    width: headerCol.width
                    height: 24

                    Item {
                        id: leftColEdge
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: card.leftPaneWidth
                    }

                    Row {
                        id: subTabs
                        visible: card.viewMode === 0
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        Repeater {
                            model: ["Sessions", "Answers"]
                            delegate: Rectangle {
                                height: 24
                                radius: 12
                                width: subLabel.implicitWidth + 20
                                color: card.mainTab === index ? "#3a6df0" : "#252525"
                                Text {
                                    id: subLabel
                                    anchors.centerIn: parent
                                    text: modelData
                                    color: "white"
                                    font.pixelSize: 11
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        if (index === 1) card.openAnswer()
                                        else card.showSessions()
                                    }
                                }
                            }
                        }

                        Item { width: 4; height: 1 }

                        Rectangle {
                            height: 24
                            radius: 12
                            width: bmFilterLabel.implicitWidth + 16
                            color: card.bookmarkFilter ? "#3a6df0" : "#252525"
                            Text {
                                id: bmFilterLabel
                                anchors.centerIn: parent
                                text: "\u2605 Bookmarked"
                                color: "white"
                                font.pixelSize: 11
                            }
                            MouseArea { anchors.fill: parent; onClicked: card.toggleBookmarkFilter() }
                        }
                    }

                    Text {
                        visible: card.viewMode === 2
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Skill Appearance  (" + card.skills.length + ")"
                        color: "#ccc"
                        font.pixelSize: 12
                    }

                    Text {
                        visible: card.viewMode === 0
                        anchors.left: leftColEdge.right
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Skills" + (card.selectedSkills.length > 0 ? "  (" + card.selectedSkills.length + " selected)" : "")
                        color: "#aaa"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }

                    TextField {
                        id: sessionSearchField
                        visible: card.viewMode === 0
                        anchors.right: leftColEdge.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 200
                        height: 24
                        placeholderText: "Search session titles..."
                        onTextChanged: card.sessionSearchText = text
                        background: Rectangle { color: "#252525"; radius: 6 }
                        color: "white"
                        font.pixelSize: 11
                    }

                    TextField {
                        id: skillSearchField
                        visible: card.viewMode === 2
                        anchors.right: leftColEdge.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 200
                        height: 24
                        placeholderText: "Search skills..."
                        onTextChanged: card.skillSearchText = text
                        background: Rectangle { color: "#252525"; radius: 6 }
                        color: "white"
                        font.pixelSize: 11
                    }

                    TextField {
                        id: composeSkillSearchField
                        visible: card.viewMode === 0
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        width: 200
                        height: 24
                        placeholderText: "Search skills to toggle..."
                        onTextChanged: card.composeSkillSearchText = text
                        background: Rectangle { color: "#252525"; radius: 6 }
                        color: "white"
                        font.pixelSize: 11
                    }
                }
            }

            Item {
                id: contentArea
                anchors.top: headerCol.bottom
                anchors.topMargin: 4
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 28

                Loader {
                    anchors.fill: parent
                    active: card.viewMode === 0
                    sourceComponent: sessionsView
                }
                Loader {
                    anchors.fill: parent
                    active: card.viewMode === 1
                    sourceComponent: libraryView
                }
                Loader {
                    anchors.fill: parent
                    active: card.viewMode === 2
                    sourceComponent: skillsEditView
                }
                Loader {
                    anchors.fill: parent
                    active: card.viewMode === 3
                    sourceComponent: statsView
                }
                Loader {
                    anchors.fill: parent
                    active: card.viewMode === 4
                    sourceComponent: datasetView
                }
            }

            Text {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 7
                anchors.horizontalCenter: parent.horizontalCenter
                text: card.statusMsg
                visible: card.statusMsg !== ""
                color: "#8ab4f8"
                font.pixelSize: 12
            }

Component {
                id: sessionsView

                Item {
                    anchors.fill: parent

                    // ---------- Left: sessions + prompts ----------
                    Item {
                        id: leftPane
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: card.leftPaneWidth

                        // Sessions toggle bar
                        Rectangle {
                            id: sessionsBar
                            visible: !card.sessionsCollapsed
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 26
                            radius: 6
                            color: "#252525"
                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: "▾ Sessions (" + card.sessions.length + ")"
                                color: "#ccc"
                                font.pixelSize: 12
                            }
                            MouseArea { anchors.fill: parent; onClicked: card.sessionsCollapsed = true }
                        }

                        // Re-expand toggle when sessions are collapsed
                        Rectangle {
                            id: collapsedToggle
                            visible: card.sessionsCollapsed
                            anchors.top: parent.top
                            anchors.left: parent.left
                            width: collapsedLabel.implicitWidth + 16
                            height: 26
                            radius: 6
                            color: "#252525"
                            Text {
                                id: collapsedLabel
                                anchors.centerIn: parent
                                text: "▸ Sessions (" + card.sessions.length + ")"
                                color: "#ccc"
                                font.pixelSize: 12
                            }
                            MouseArea { anchors.fill: parent; onClicked: card.sessionsCollapsed = false }
                        }

                        // Session chips, limited height + clipped
                        Rectangle {
                            id: sessionChipsBox
                            visible: !card.sessionsCollapsed
                            anchors.top: sessionsBar.bottom
                            anchors.topMargin: 6
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: Math.max(72, Math.round(parent.height / 5))
                            radius: 8
                            color: "#202020"

                            ScrollView {
                                id: sessionChipsScroll
                                anchors.fill: parent
                                anchors.margins: 6
                                clip: true
                                contentWidth: availableWidth

                                Flow {
                                    id: sessionFlow
                                    width: sessionChipsScroll.availableWidth
                                    spacing: 4

                                    Repeater {
                                        model: card.sessionList()
                                        delegate: Rectangle {
                                            property int origIdx: modelData.originalIndex
                                            height: 24
                                            radius: 12
                                            color: (origIdx === card.activeSessionIndex) ? "#3a6df0" : "#2a2a2a"
                                            width: Math.min(chipText.implicitWidth + 34, sessionChipsScroll.availableWidth)

                                            Text {
                                                id: chipText
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: 8
                                                width: parent.width - 30
                                                text: modelData.title
                                                color: (origIdx === card.activeSessionIndex) ? "#fff" : "#ccc"
                                                font.pixelSize: 11
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                id: chipStar
                                                anchors.right: parent.right
                                                anchors.rightMargin: 7
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: card.isBookmarked(modelData.id) ? "★" : "☆"
                                                color: card.isBookmarked(modelData.id) ? "#f5c518" : "#666"
                                                font.pixelSize: 12
                                                MouseArea {
                                                    anchors.fill: parent
                                                    anchors.margins: -4
                                                    onClicked: card.toggleBookmark(modelData.id)
                                                }
                                            }

                                            MouseArea {
                                                anchors.left: parent.left
                                                anchors.right: chipStar.left
                                                anchors.top: parent.top
                                                anchors.bottom: parent.bottom
                                                onClicked: card.selectSession(origIdx)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Recent Prompts navigation (below sessions)
                        Rectangle {
                            id: promptListPane
                            visible: !(card.mainTab === 1 && card.selectedPromptIndex >= 0)
                            anchors.top: card.sessionsCollapsed ? collapsedToggle.bottom : sessionChipsBox.bottom
                            anchors.topMargin: 6
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            color: "#252525"
                            radius: 8

                            Row {
                                id: promptsHeader
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 10
                                height: 24
                                spacing: 8

                                Text {
                                    id: recentLabel
                                    height: 24
                                    verticalAlignment: Text.AlignVCenter
                                    text: "Recent Prompts"
                                    color: "#ccc"
                                    font.pixelSize: 14
                                }

                                Item {
                                    width: Math.max(0, promptsHeader.width - recentLabel.width - searchField.width - promptsHeader.spacing * 2)
                                    height: 1
                                }

                                TextField {
                                    id: searchField
                                    width: Math.min(200, Math.max(110, promptsHeader.width - recentLabel.width - promptsHeader.spacing * 2))
                                    height: 22
                                    placeholderText: "Search all sessions... (Ctrl+F)"
                                    onTextChanged: card.promptSearchText = text
                                    Component.onCompleted: card.promptSearchInput = searchField
                                    background: Rectangle { color: "#1e1e1e"; radius: 6 }
                                    color: "white"
                                    font.pixelSize: 11
                                }
                            }

                            ScrollView {
                                id: promptScroll
                                anchors.top: promptsHeader.bottom
                                anchors.topMargin: 8
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 10
                                clip: true

                                Column {
                                    id: promptList
                                    width: promptScroll.availableWidth
                                    spacing: 6

                                    Repeater {
                                        id: promptRepeater
                                        model: card.filteredPrompts()
                                        delegate: Column {
                                            width: promptList.width
                                            spacing: 4

                                            Text {
                                                text: new Date(modelData.time_created).toLocaleString()
                                                color: "#888"
                                                font.pixelSize: 10
                                            }

                                            Text {
                                                visible: modelData.sessionIndex !== card.activeSessionIndex
                                                width: parent.width
                                                elide: Text.ElideRight
                                                text: card.sessions[modelData.sessionIndex] ? "\u21b3 " + card.sessions[modelData.sessionIndex].title : ""
                                                color: "#3a6df0"
                                                font.pixelSize: 10
                                            }

                                            Rectangle {
                                                id: promptCard
                                                property bool hovered: promptMa.containsMouse || copyMa.containsMouse
                                                width: parent.width
                                                height: promptText.implicitHeight + 12
                                                color: hovered ? "#2a2a2a" : "#1e1e1e"
                                                radius: 4

                                                Text {
                                                    id: promptText
                                                    x: 6
                                                    y: 6
                                                    width: parent.width - 40
                                                    text: modelData.prompt
                                                    wrapMode: Text.WordWrap
                                                    color: "#ddd"
                                                    font.pixelSize: 12
                                                }

                                                MouseArea {
                                                    id: promptMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: {
                                                        if (modelData.answer) {
                                                            card.showAnswer(modelData.originalIndex, modelData.answer, modelData.sessionIndex)
                                                        } else {
                                                            card.setStatus("No answer available for this prompt")
                                                        }
                                                    }
                                                }

                                                Rectangle {
                                                    id: copyBtn
                                                    anchors.top: parent.top
                                                    anchors.right: parent.right
                                                    anchors.topMargin: 4
                                                    anchors.rightMargin: 4
                                                    width: 22
                                                    height: 18
                                                    radius: 4
                                                    color: copyMa.containsMouse ? "#3a6df0" : "#2a2a2a"
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "⧉"
                                                        color: "#ccc"
                                                        font.pixelSize: 11
                                                    }
                                                    MouseArea {
                                                        id: copyMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        onClicked: card.copyPrompt(modelData.prompt)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: promptRepeater.count === 0
                                width: parent.width - 20
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                text: card.sessions.length === 0
                                    ? "No sessions yet — waiting for the exporter cache"
                                    : "No prompts match the current filters"
                                color: "#666"
                                font.pixelSize: 13
                            }
                        }

                        // ---------- Answer (left column, replaces the prompt list) ----------
                        Rectangle {
                            id: leftAnswerPane
                            visible: card.mainTab === 1 && card.selectedPromptIndex >= 0
                            anchors.top: card.sessionsCollapsed ? collapsedToggle.bottom : sessionChipsBox.bottom
                            anchors.topMargin: 6
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            color: "#252525"
                            radius: 8

                            Text {
                                id: answerTitle
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.top: parent.top
                                anchors.topMargin: 9
                                text: "Answer  " + card.answerPos + " / " + card.answerCount
                                color: "#ccc"
                                font.pixelSize: 13
                            }

                            Row {
                                id: answerNav
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: answerTitle.verticalCenter
                                spacing: 6

                                Rectangle {
                                    width: 26
                                    height: 22
                                    radius: 4
                                    color: navPrevMa.containsMouse ? "#3a6df0" : "#1e1e1e"
                                    Text { anchors.centerIn: parent; text: "◀"; color: "#ccc"; font.pixelSize: 12 }
                                    MouseArea {
                                        id: navPrevMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: card.navigateAnswer(-1)
                                    }
                                }

                                Rectangle {
                                    width: 26
                                    height: 22
                                    radius: 4
                                    color: navNextMa.containsMouse ? "#3a6df0" : "#1e1e1e"
                                    Text { anchors.centerIn: parent; text: "▶"; color: "#ccc"; font.pixelSize: 12 }
                                    MouseArea {
                                        id: navNextMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: card.navigateAnswer(1)
                                    }
                                }

                                Rectangle {
                                    width: listBtnLabel.implicitWidth + 16
                                    height: 22
                                    radius: 4
                                    color: listBtnMa.containsMouse ? "#3a6df0" : "#1e1e1e"
                                    Text {
                                        id: listBtnLabel
                                        anchors.centerIn: parent
                                        text: "List"
                                        color: "#ccc"
                                        font.pixelSize: 12
                                    }
                                    MouseArea {
                                        id: listBtnMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: card.showSessions()
                                    }
                                }
                            }

                            Row {
                                id: answerFontRow
                                anchors.top: answerTitle.bottom
                                anchors.topMargin: 8
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                spacing: 6

                                ComboBox {
                                    model: ["JetBrains Mono", "Fira Code", "Source Code Pro", "Cascadia Code", "IBM Plex Mono", "Monospace"]
                                    Component.onCompleted: currentIndex = Math.max(0, model.indexOf(card.answerFontFamily))
                                    onActivated: card.answerFontFamily = currentText
                                    background: Rectangle { color: "#1e1e1e"; radius: 4; border.color: "#3a3a3a"; border.width: 1 }
                                }

                                Slider {
                                    width: 90
                                    from: 10; to: 24; value: card.answerFontSize; stepSize: 1
                                    onValueChanged: { card.answerFontSize = Math.round(value); }
                                    background: Rectangle { color: "#1e1e1e"; radius: 4; border.color: "#3a3a3a"; border.width: 1 }
                                }

                                Button {
                                    text: "Refresh"
                                    bordered: true
                                    onClicked: card.reloadCurrentAnswer()
                                }
                            }

                            Rectangle {
                                id: selectedPromptBox
                                anchors.top: answerFontRow.bottom
                                anchors.topMargin: 8
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                height: Math.min(selectedAnswerText.implicitHeight + 12, 88)
                                color: "#1e1e1e"
                                radius: 6

                                Text {
                                    id: selectedAnswerText
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    text: card.selectedPromptText
                                    color: "#8ab4f8"
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 5
                                    elide: Text.ElideRight
                                }
                            }

                            ScrollView {
                                id: leftAnswerScroll
                                anchors.top: selectedPromptBox.bottom
                                anchors.topMargin: 8
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 10
                                clip: true

                                Text {
                                    width: leftAnswerScroll.availableWidth
                                    text: card.selectedPromptAnswer
                                    textFormat: Text.MarkdownText
                                    wrapMode: Text.WordWrap
                                    color: "#ddd"
                                    font.family: card.answerFontFamily
                                    font.pixelSize: card.answerFontSize
                                }
                            }
                        }
                    }
                    // ---------- Right: key injections + system + user prompt ----------
                    Item {
                        id: rightPane
                        anchors.left: leftPane.right
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom

                        // ---------- Send bar ----------
                        Rectangle {
                            id: buttonBar
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 34
                            radius: 8
                            color: "#202020"

                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6

                                Rectangle {
                                    id: agentSeg
                                    width: 108
                                    height: 24
                                    radius: 6
                                    color: "#252525"

                                    Row {
                                        anchors.fill: parent

                                        Rectangle {
                                            width: 54
                                            height: parent.height
                                            radius: 6
                                            color: card.agentMode === "build" ? "#3a6df0" : "#252525"
                                            Text { anchors.centerIn: parent; text: "Build"; color: card.agentMode === "build" ? "#fff" : "#999"; font.pixelSize: 10 }
                                            MouseArea { anchors.fill: parent; onClicked: card.agentMode = "build" }
                                        }

                                        Rectangle {
                                            width: 54
                                            height: parent.height
                                            radius: 6
                                            color: card.agentMode === "plan" ? "#3a6df0" : "#252525"
                                            Text { anchors.centerIn: parent; text: "Plan"; color: card.agentMode === "plan" ? "#fff" : "#999"; font.pixelSize: 10 }
                                            MouseArea { anchors.fill: parent; onClicked: card.agentMode = "plan" }
                                        }
                                    }
                                }

                                Rectangle {
                                    height: 24
                                    radius: 6
                                    width: cleanupLabel.implicitWidth + 16
                                    color: card.cleanupOn ? "#3a6df0" : "#252525"
                                    Text { id: cleanupLabel; anchors.centerIn: parent; text: card.cleanupOn ? "✨ Clean-up: on" : "✨ Clean-up: off"; color: card.cleanupOn ? "#fff" : "#999"; font.pixelSize: 10 }
                                    MouseArea { anchors.fill: parent; onClicked: card.cleanupOn = !card.cleanupOn }
                                }

                                Rectangle {
                                    height: 24
                                    radius: 6
                                    width: recordLabel.implicitWidth + 16
                                    color: card.recordOn ? "#3a6df0" : "#252525"
                                    Text { id: recordLabel; anchors.centerIn: parent; text: card.recordOn ? "● Record" : "○ Record"; color: card.recordOn ? "#fff" : "#999"; font.pixelSize: 10 }
                                    MouseArea { anchors.fill: parent; onClicked: card.recordOn = !card.recordOn }
                                }

                                Rectangle {
                                    height: 24
                                    radius: 6
                                    width: newLabel.implicitWidth + 16
                                    color: newMa.containsMouse && !card.sending ? "#2f61d8" : "#2a2a2a"
                                    opacity: card.sending ? 0.5 : 1
                                    Text { id: newLabel; anchors.centerIn: parent; text: "New Session ▶"; color: "#ccc"; font.pixelSize: 10 }
                                    MouseArea { id: newMa; anchors.fill: parent; hoverEnabled: true; enabled: !card.sending; onClicked: card.sendPayload(true) }
                                }

                                Rectangle {
                                    height: 24
                                    radius: 6
                                    width: sendLabel.implicitWidth + 20
                                    color: sendMa.containsMouse && !card.sending ? "#2f61d8" : "#3a6df0"
                                    opacity: card.sending ? 0.5 : 1
                                    Text { id: sendLabel; anchors.centerIn: parent; text: card.sending ? "Sending…" : "Send"; color: "#fff"; font.pixelSize: 11; font.bold: true }
                                    MouseArea { id: sendMa; anchors.fill: parent; hoverEnabled: true; enabled: !card.sending; onClicked: card.sendPayload(false) }
                                }
                            }
                        }

                        // ---------- Skills ----------
                        Rectangle {
                            id: skillsPane
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 76
                            radius: 8
                            color: "#202020"

                            Column {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 4

                                ScrollView {
                                    id: skillsScroll
                                    width: parent.width
                                    height: parent.height - 12
                                    clip: true
                                    contentWidth: availableWidth

                                    Flow {
                                        width: skillsScroll.availableWidth
                                        spacing: 4

                                        Repeater {
                                            model: card.filteredComposeSkills()
                                            delegate: Rectangle {
                                                property bool skillOn: card.skillSelected(modelData.name)
                                                height: 26
                                                radius: 6
                                                width: Math.max(104, Math.min(152, Math.floor((skillsScroll.availableWidth - 4) / 2)))
                                                color: skillOn ? card.skillColor(modelData.name) : "#1a1a1a"
                                                border.width: 1
                                                border.color: card.skillColor(modelData.name)

                                                Text {
                                                    id: skillLabel
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 7
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: parent.width - 30
                                                    elide: Text.ElideRight
                                                    text: card.skillEmoji(modelData.name) + " " + modelData.name
                                                    color: skillOn ? "#fff" : "#ccc"
                                                    font.pixelSize: 10
                                                }

                                                Text {
                                                    anchors.right: parent.right
                                                    anchors.rightMargin: 7
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    visible: skillOn
                                                    text: "✓"
                                                    color: "#fff"
                                                    font.pixelSize: 11
                                                    font.bold: true
                                                }

                                                MouseArea { anchors.fill: parent; onClicked: card.toggleSkill(modelData.name) }
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: card.skills.length === 0
                                text: "No skills found"
                                color: "#666"
                                font.pixelSize: 11
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: card.skills.length > 0 && card.filteredComposeSkills().length === 0
                                text: "No skills match \"" + card.composeSkillSearchText + "\""
                                color: "#666"
                                font.pixelSize: 11
                            }
                        }

                        // Key Injections toggle
                        Rectangle {
                            id: keyInjToggle
                            anchors.top: skillsPane.bottom
                            anchors.topMargin: 6
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 24
                            radius: 6
                            color: card.keyInjectionsOpen ? "#3a6df0" : "#252525"
                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: (card.keyInjectionsOpen ? "▼" : "▶") + " Key Injections"
                                color: card.keyInjectionsOpen ? "#fff" : "#ccc"
                                font.pixelSize: 11
                            }
                            MouseArea { anchors.fill: parent; onClicked: card.keyInjectionsOpen = !card.keyInjectionsOpen }
                        }

                        // Key Injections list
                        Rectangle {
                            id: keyInjPanel
                            visible: card.keyInjectionsOpen
                            anchors.top: keyInjToggle.bottom
                            anchors.topMargin: 4
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 130
                            radius: 8
                            color: "#202020"

                            ScrollView {
                                id: keyInjScroll
                                anchors.fill: parent
                                anchors.margins: 6
                                clip: true
                                contentWidth: availableWidth

                                Column {
                                    width: keyInjScroll.availableWidth
                                    spacing: 3

                                    Repeater {
                                        model: card.keyInjections
                                        delegate: Rectangle {
                                            width: parent.width
                                            height: 22
                                            radius: 4
                                            color: keyInjMa.containsMouse ? "#333" : "#2a2a2a"

                                            Text {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.leftMargin: 6
                                                anchors.right: parent.right
                                                anchors.rightMargin: 6
                                                text: modelData.label
                                                color: "#ccc"
                                                font.pixelSize: 10
                                                elide: Text.ElideRight
                                            }

                                            MouseArea {
                                                id: keyInjMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: card.injectSystem(modelData.text)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // System Prompt
                        Item {
                            id: systemPromptPane
                            anchors.top: card.keyInjectionsOpen ? keyInjPanel.bottom : keyInjToggle.bottom
                            anchors.topMargin: 6
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: Math.max(80, (parent.height - (card.keyInjectionsOpen ? (keyInjPanel.height + 34) : 30)) * 0.38)

                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: "#202020"

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 4

                                    Text {
                                        text: "System Prompt"
                                        color: "#aaa"
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                    }

                                    ScrollView {
                                        id: systemPromptScroll
                                        width: parent.width
                                        height: parent.height - 20
                                        clip: true

                                        TextArea {
                                            width: systemPromptScroll.availableWidth
                                            wrapMode: TextArea.Wrap
                                            background: Item {}
                                            color: "#ddd"
                                            font.pixelSize: 11
                                            selectByMouse: true
                                            text: card.systemPromptText
                                            onTextChanged: {
                                                if (text !== card.systemPromptText) card.systemPromptText = text
                                            }
                                            placeholderText: "System prompt..."
                                        }
                                    }
                                }
                            }
                        }

                        // User Prompt (with library)
                        Item {
                            id: userPromptPane
                            anchors.top: systemPromptPane.bottom
                            anchors.topMargin: 6
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: buttonBar.top
                            anchors.bottomMargin: 6

                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: "#202020"

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 4

                                    Item {
                                        id: userPromptHeader
                                        width: parent.width
                                        height: 22

                                        Row {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 6

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "User Prompt"
                                                color: "#aaa"
                                                font.pixelSize: 11
                                                font.weight: Font.Medium
                                            }

                                            Rectangle {
                                                height: 20
                                                radius: 4
                                                color: card.libPickerOpen ? "#3a6df0" : "#2a2a2a"
                                                width: libChipLabel.implicitWidth + 10
                                                Text {
                                                    id: libChipLabel
                                                    anchors.centerIn: parent
                                                    text: "Library"
                                                    color: card.libPickerOpen ? "#fff" : "#ccc"
                                                    font.pixelSize: 10
                                                }
                                                MouseArea { anchors.fill: parent; onClicked: card.libPickerOpen = !card.libPickerOpen }
                                            }
                                        }

                                        Row {
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 6

                                            Button {
                                                text: "Copy"
                                                bordered: true
                                                onClicked: {
                                                    Quickshell.clipboardText = card.draftText + (card.systemPromptText !== "" ? ("\n\n[System]: " + card.systemPromptText) : "")
                                                    card.setStatus("Copied system + user prompt")
                                                }
                                            }
                                            Button { text: "Save to Library"; bordered: true; onClicked: card.savePrompt() }
                                            Button { text: "Clear"; bordered: true; onClicked: card.draftText = "" }
                                        }
                                    }

                                    Rectangle {
                                        id: inlineLibPicker
                                        width: parent.width
                                        height: 150
                                        radius: 6
                                        color: "#252525"
                                        visible: card.libPickerOpen

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            spacing: 4

                                            ScrollView {
                                                id: inlineLibScroll
                                                width: parent.width
                                                height: parent.height
                                                clip: true
                                                contentWidth: availableWidth

                                                Column {
                                                    width: inlineLibScroll.availableWidth
                                                    spacing: 2

                                                    Repeater {
                                                        model: card.filteredLibrary()
                                                        delegate: Rectangle {
                                                            width: parent.width
                                                            height: 20
                                                            radius: 3
                                                            color: "#2a2a2a"

                                                            Text {
                                                                anchors.left: parent.left
                                                                anchors.leftMargin: 4
                                                                anchors.right: parent.right
                                                                anchors.rightMargin: 4
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                text: modelData.text || ("Item " + index)
                                                                color: "#ccc"
                                                                font.pixelSize: 10
                                                                elide: Text.ElideRight
                                                            }

                                                            MouseArea {
                                                                anchors.fill: parent
                                                                onClicked: {
                                                                    card.insertIntoDraft(modelData.text || "")
                                                                    card.libPickerOpen = false
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    ScrollView {
                                        id: promptEditorScroll
                                        width: parent.width
                                        height: inlineLibPicker.visible
                                            ? (parent.height - 22 - inlineLibPicker.height - 16)
                                            : (parent.height - 22)
                                        clip: true

                                        TextArea {
                                            id: userEditor
                                            width: promptEditorScroll.availableWidth
                                            wrapMode: TextArea.Wrap
                                            background: Item {}
                                            color: "#ddd"
                                            font.pixelSize: 11
                                            selectByMouse: true
                                            text: card.draftText
                                            onTextChanged: {
                                                if (text !== card.draftText) card.draftText = text
                                            }
                                            placeholderText: "Type a prompt, or click one on the left"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Component {
                id: libraryView

                Item {
                    anchors.fill: parent

                    Row {
                        id: libToolbar
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 8

                        Text {
                            text: "Prompt Library"
                            color: "#ccc"
                            font.pixelSize: 14
                            height: 28
                            verticalAlignment: Text.AlignVCenter
                        }

                        Button { text: "Export JSON"; bordered: true; onClicked: exportJsonProc.running = true }
                        Button { text: "Export MD"; bordered: true; onClicked: exportMdProc.running = true }
                        Button { text: "Import"; bordered: true; onClicked: importDialog.running = true }
                    }

                    Flow {
                        id: tagFlow
                        anchors.top: libToolbar.bottom
                        anchors.topMargin: 8
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 6

                        Repeater {
                            model: card.libraryTags()
                            delegate: Rectangle {
                                height: 24
                                radius: 12
                                width: tagLabel.implicitWidth + 16
                                color: card.tagFilter === modelData ? "#3a6df0" : "#252525"
                                Text {
                                    id: tagLabel
                                    anchors.centerIn: parent
                                    text: "#" + modelData
                                    color: "white"
                                    font.pixelSize: 11
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: card.tagFilter = card.tagFilter === modelData ? "" : modelData
                                }
                            }
                        }
                    }

                    TextArea {
                        id: editorLib
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        height: 110
                        text: card.libDraft
                        onTextChanged: {
                            if (text !== card.libDraft) card.libDraft = text
                        }
                        placeholderText: "Click a library item to load it here"
                        placeholderTextColor: "#888"
                        color: "white"
                        wrapMode: TextArea.Wrap
                        selectByMouse: true
                        background: Rectangle { color: "#1e1e1e"; radius: 6 }
                    }

                    // Fallback placeholder (native one sometimes doesn't render)
                    Text {
                        anchors.top: editorLib.top
                        anchors.topMargin: 8
                        anchors.left: editorLib.left
                        anchors.leftMargin: 10
                        visible: editorLib.text === ""
                        text: "Click a library item to load it here"
                        color: "#888"
                        font.pixelSize: 12
                        z: editorLib.z + 1
                    }

                    ScrollView {
                        id: libScroll
                        anchors.top: tagFlow.bottom
                        anchors.topMargin: 8
                        anchors.bottom: editorLib.top
                        anchors.bottomMargin: 8
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        clip: true

                        Column {
                            id: libList
                            width: libScroll.availableWidth
                            spacing: 6

                            Repeater {
                                id: libRepeater
                                model: card.filteredLibrary()
                                delegate: Rectangle {
                                    width: libList.width
                                    height: libItemCol.implicitHeight + 16
                                    color: "#252525"
                                    radius: 6

                                    Column {
                                        id: libItemCol
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 4

                                        Text {
                                            width: parent.width
                                            text: modelData.text.length > 300 ? modelData.text.slice(0, 300) + "…" : modelData.text
                                            wrapMode: Text.WordWrap
                                            color: "#ddd"
                                            font.pixelSize: 12
                                        }

                                        Flow {
                                            width: parent.width
                                            spacing: 4

                                            Repeater {
                                                model: modelData.tags || []
                                                delegate: Text {
                                                    text: "#" + modelData
                                                    color: "#8ab4f8"
                                                    font.pixelSize: 10
                                                }
                                            }
                                        }

                                        Text {
                                            text: new Date(modelData.created_at).toLocaleString()
                                            color: "#888"
                                            font.pixelSize: 10
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: card.libDraft = modelData.text
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: libRepeater.count === 0
                        text: card.library.length === 0
                            ? "Library is empty — save prompts from the Sessions tab"
                            : "No library items match the current filters"
                        color: "#666"
                        font.pixelSize: 13
                    }
                }
            }

            Component {
                id: skillsEditView

                Item {
                    anchors.fill: parent

                    Row {
                        id: skillsToolbar
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 26
                        spacing: 8

                        Text {
                            text: "Skill Appearance"
                            color: "#ccc"
                            font.pixelSize: 14
                            height: 26
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "pick an emoji + colour — they decorate the toggle chips in the compose pane"
                            color: "#666"
                            font.pixelSize: 11
                        }
                    }

                    ScrollView {
                        id: skillsEditScroll
                        anchors.top: skillsToolbar.bottom
                        anchors.topMargin: 8
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        clip: true
                        contentWidth: availableWidth

                        Flow {
                            id: skillsEditFlow
                            width: skillsEditScroll.availableWidth
                            spacing: 6

                            Repeater {
                                model: card.filteredSkills()

                                delegate: Rectangle {
                                    property string skillName: modelData.name
                                    width: Math.floor((skillsEditScroll.availableWidth - 6) / 2)
                                    height: 92
                                    radius: 8
                                    color: "#202020"
                                    border.width: 1
                                    border.color: "#2e2e2e"

                                    Rectangle {
                                        id: previewBox
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.top: parent.top
                                        anchors.topMargin: 8
                                        width: 54
                                        height: 54
                                        radius: 8
                                        color: card.skillSelected(skillName) ? card.skillColor(skillName) : "#1a1a1a"
                                        border.width: 1
                                        border.color: card.skillColor(skillName)

                                        Text {
                                            anchors.centerIn: parent
                                            text: card.skillEmoji(skillName)
                                            font.pixelSize: 24
                                        }
                                    }

                                    Column {
                                        id: skillEditCol
                                        anchors.left: previewBox.right
                                        anchors.leftMargin: 10
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.top: parent.top
                                        anchors.topMargin: 8
                                        spacing: 5

                                        Text {
                                            width: parent.width
                                            elide: Text.ElideRight
                                            horizontalAlignment: Text.AlignHCenter
                                            text: skillName
                                            color: "#eee"
                                            font.pixelSize: 13
                                            font.family: "JetBrains Mono"
                                        }

                                        Text {
                                            width: parent.width
                                            elide: Text.ElideRight
                                            text: (modelData.description || "").replace(/^> /, "")
                                            color: "#777"
                                            font.pixelSize: 10
                                        }

                                        Flow {
                                            width: parent.width
                                            spacing: 3

                                            Repeater {
                                                model: card.emojiPalette
                                                delegate: Rectangle {
                                                    width: 18
                                                    height: 18
                                                    radius: 4
                                                    color: card.skillStyle(skillName).emoji === modelData ? card.skillColor(skillName) : "#1a1a1a"
                                                    border.width: 1
                                                    border.color: card.skillStyle(skillName).emoji === modelData ? "#fff" : "#333"
                                                    Text { anchors.centerIn: parent; text: modelData; font.pixelSize: 10 }
                                                    MouseArea { anchors.fill: parent; onClicked: card.setSkillStyle(skillName, "emoji", modelData) }
                                                }
                                            }

                                            TextField {
                                                width: 64
                                                height: 18
                                                placeholderText: "emoji"
                                                text: card.skillStyle(skillName).emoji || ""
                                                onTextChanged: {
                                                    if (text !== (card.skillStyle(skillName).emoji || ""))
                                                        card.setSkillStyle(skillName, "emoji", text)
                                                }
                                                background: Rectangle { color: "#1a1a1a"; radius: 4; border.color: "#333"; border.width: 1 }
                                                color: "white"
                                                font.pixelSize: 11
                                                horizontalAlignment: TextInput.AlignHCenter
                                            }
                                        }

                                        Flow {
                                            width: parent.width
                                            spacing: 3

                                            Repeater {
                                                model: card.colorPalette
                                                delegate: Rectangle {
                                                    width: 18
                                                    height: 16
                                                    radius: 4
                                                    color: modelData
                                                    border.width: card.skillStyle(skillName).color === modelData ? 2 : 1
                                                    border.color: card.skillStyle(skillName).color === modelData ? "#fff" : "#000"
                                                    MouseArea { anchors.fill: parent; onClicked: card.setSkillStyle(skillName, "color", modelData) }
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.top: parent.top
                                        anchors.topMargin: 8
                                        visible: card.skillStyle(skillName).emoji !== undefined || card.skillStyle(skillName).color !== undefined
                                        text: "reset"
                                        color: "#e05555"
                                        font.pixelSize: 10
                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -4
                                            onClicked: {
                                                var next = {}
                                                for (var k in card.skillStyles) {
                                                    if (k !== skillName) next[k] = card.skillStyles[k]
                                                }
                                                card.skillStyles = next
                                                skillStylesView.setText(JSON.stringify(next, null, 2))
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: card.skills.length === 0
                                text: "No skills found"
                                color: "#666"
                                font.pixelSize: 11
                            }

                            Text {
                                visible: card.skills.length > 0 && card.filteredSkills().length === 0
                                text: "No skills match \"" + card.skillSearchText + "\""
                                color: "#666"
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }

            Component {
                id: statsView

                Item {
                    anchors.fill: parent

                    Column {
                        x: 4
                        y: 4
                        spacing: 8

                        Text { text: "Stats"; color: "#ccc"; font.pixelSize: 14 }
                        Text { text: "Sessions: " + card.sessions.length; color: "white"; font.pixelSize: 13 }
                        Text { text: "Library items: " + card.library.length; color: "white"; font.pixelSize: 13 }
                        Text {
                            text: "Prompts (last 30d): " + card.sessions.reduce((a, s) =>
                                a + s.recent_prompts.filter(p => (Date.now() - p.time_created) < 30 * 24 * 3600 * 1000).length, 0)
                            color: "white"
                            font.pixelSize: 13
                        }
                        Text {
                            text: "Active session: " + (card.sessions[card.activeSessionIndex] ? card.sessions[card.activeSessionIndex].title : "—")
                            color: "white"
                            font.pixelSize: 13
                        }
                    }
                }
            }

            Component {
                id: datasetView

                Item {
                    anchors.fill: parent

                    Column {
                        anchors.fill: parent
                        spacing: 8

                        Row {
                            spacing: 10

                            Text { text: "Training Dataset"; color: "#ccc"; font.pixelSize: 14 }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: card.trainingCount + " record" + (card.trainingCount === 1 ? "" : "s")
                                color: "#8ab4f8"
                                font.pixelSize: 12
                            }
                        }

                        Row {
                            spacing: 8
                            Button { text: "Export (ShareGPT + Alpaca)"; bordered: true; onClicked: exportDatasetProc.running = true }
                            Button { text: "Refresh"; bordered: true; onClicked: trainingView.reload() }
                        }

                        Text {
                            text: card.recordOn ? "Recording is ON — each sent payload is appended." : "Recording is OFF — enable ○ Record in the send bar to capture payloads."
                            color: card.recordOn ? "#6fcf97" : "#888"
                            font.pixelSize: 11
                        }

                        Rectangle {
                            width: parent.width
                            height: parent.height - 92
                            radius: 8
                            color: "#202020"

                            ScrollView {
                                id: datasetScroll
                                anchors.fill: parent
                                anchors.margins: 8
                                clip: true
                                contentWidth: availableWidth

                                Text {
                                    width: datasetScroll.availableWidth
                                    text: card.trainingText !== "" ? card.trainingText : "No data yet."
                                    color: "#bbb"
                                    font.pixelSize: 10
                                    font.family: "JetBrains Mono"
                                    wrapMode: Text.WrapAnywhere
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
