import QtQuick
import Quickshell.Wayland
import QtQuick.Controls
import Quickshell
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
        visible: root.opened
        WlrLayershell.namespace: "opencode-sessions-panel"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.6)
            // Close on a click outside the card, but never on a click that lands
            // on the card and merely misses an interactive item: this MouseArea
            // sits under the card, so such clicks arrive here too. Compare the
            // point against the centred card rect and only dismiss when outside.
            MouseArea {
                anchors.fill: parent
                onClicked: function (mouse) {
                    var halfW = card.width / 2
                    var halfH = card.height / 2
                    var cx = parent.width / 2
                    var cy = parent.height / 2
                    var insideCard = Math.abs(mouse.x - cx) <= halfW
                                  && Math.abs(mouse.y - cy) <= halfH
                    if (!insideCard) root.close()
                }
            }
        }

        Rectangle {
            id: card
            width: 1280
            height: 820
            radius: 12
            color: "#1e1e1e"
            anchors.centerIn: parent

            readonly property string home: Quickshell.env("HOME")
            readonly property string pluginDir: home + "/.config/omarchy/plugins/io.github.aroehrscheid-lsrmnky.opencode-sessions"
            readonly property string settingsPath: home + "/.config/opencode-sessions/settings.json"
            readonly property string agentsMdPath: home + "/.config/opencode/AGENTS.md"
            property var settings: ({})
            readonly property string dataDir: (settings.dataDir && settings.dataDir.length > 0) ? settings.dataDir : home + "/.config/opencode-sessions"
            readonly property string cacheDir: (settings.cacheDir && settings.cacheDir.length > 0) ? settings.cacheDir : home + "/.cache/opencode-sessions"
            readonly property string cachePath: cacheDir + "/sessions.json"
            readonly property string bookmarksPath: dataDir + "/bookmarks.json"
            readonly property string libraryPath: dataDir + "/prompts.json"
            readonly property string directivesPath: dataDir + "/directives.json"
            property var sessions: []
            property int activeSessionIndex: 0
            property var library: []
            property string libraryNewText: ""
            property var bookmarks: []
            property bool sessionsCollapsed: false
            property bool bookmarkFilter: false
            property bool libPickerOpen: false
            property int viewMode: 0
            property string promptSearchText: ""
            property var promptSearchInput: null
            property string sessionSearchText: ""
            property int mainTab: 0
            property string tagFilter: ""
            property string draftText: ""
            property string directiveText: ""
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
            property var directives: []
            property string selectedDirectiveId: ""
            property string directiveNewTitle: ""
            property string directiveNewBody: ""
            property string directiveSearchText: ""
            property string directiveTagFilter: ""
            property string skillNewName: ""
            property string skillNewDesc: ""
            property var skills: []
            property var skillStyles: ({})
            property string skillSearchText: ""
            property string composeSkillSearchText: ""
            readonly property var emojiPalette: ["💡", "🛠️", "⚡", "🧩", "🐛", "🎨", "📦", "🗂️", "🔧", "🧭", "🧪", "📐", "🚀", "🔒", "🤖", "🌱", "🔍", "📚", "✅", "⚙️", "🎯", "🔥"]
            readonly property var colorPalette: ["#3a6df0", "#2f9e6f", "#c46b2f", "#8e44ad", "#16a2b8", "#c0392b", "#b8952f", "#e05555", "#555f6e", "#2fa84f", "#1f6feb", "#d29922", "#db6d28", "#a371f7", "#f778ba", "#39c5cf", "#56d364", "#ff7b72", "#8b949e", "#7ee787", "#ffa657", "#d2a8ff", "#e85d4a", "#4a9eda"]
            property var selectedSkills: []
            property bool cleanupOn: false
            property bool recordOn: false
            property string agentMode: "build"
            property bool sending: false
            property int trainingCount: 0
            property string trainingText: ""
            property var sysPromptSources: []
            property string sysPromptTarget: agentsMdPath
            property string sysPromptDraft: ""
            property bool sysPromptDirty: false
            property var settingsChecks: []
            property string settingsLog: ""
            property string settingsDraftData: ""
            property string settingsDraftCache: ""
            property string settingsDraftExporter: ""
            property string settingsDraftDb: ""
            readonly property string skillsPath: cacheDir + "/skills.json"
            readonly property string skillStylesPath: dataDir + "/skill_styles.json"
            readonly property string trainingPath: dataDir + "/training.jsonl"
            readonly property string exporterPath: (settings.exporterPath && settings.exporterPath.length > 0) ? settings.exporterPath : pluginDir + "/exporter.py"
            readonly property string dbPath: (settings.dbPath && settings.dbPath.length > 0) ? settings.dbPath : home + "/.local/share/opencode/opencode.db"

            onSessionsChanged: {
                if (activeSessionIndex >= sessions.length)
                    activeSessionIndex = Math.max(0, sessions.length - 1)
            }

            Component.onCompleted: {
                initStoreProc.running = true
                skillsProc.running = true
                loadSettingsDrafts()
                sysPromptProc.running = true
                detectProc.running = true
            }

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

            function directiveTextFor(id) {
                if (!id) return ""
                for (var i = 0; i < directives.length; i++) {
                    if (directives[i].id === id) return String(directives[i].text || "")
                }
                return ""
            }

            function selectedDirectiveTitle() {
                for (var i = 0; i < directives.length; i++) {
                    if (directives[i].id === selectedDirectiveId) return String(directives[i].title || directives[i].text || "")
                }
                return ""
            }

            function selectDirective(id) {
                if (selectedDirectiveId === id) id = ""
                selectedDirectiveId = id
                directiveText = directiveTextFor(id)
                dirView.setText(JSON.stringify({ directives: directives, selectedId: selectedDirectiveId }, null, 2))
                setStatus(id === "" ? "Directive cleared" : "Directive: " + selectedDirectiveTitle())
            }

            function directiveTags() {
                var tags = []
                for (var i = 0; i < directives.length; i++) {
                    var itemTags = directives[i].tags || []
                    for (var j = 0; j < itemTags.length; j++) {
                        if (tags.indexOf(itemTags[j]) === -1) tags.push(itemTags[j])
                    }
                }
                return tags
            }

            function filteredDirectives() {
                return directives.filter(d => {
                    return !directiveTagFilter || (d.tags || []).indexOf(directiveTagFilter) !== -1
                })
            }

            function filteredComposeDirectives() {
                var q = directiveSearchText.toLowerCase().trim()
                return directives.filter(d => {
                    return q === "" || String(d.title || "").toLowerCase().includes(q) || String(d.text || "").toLowerCase().includes(q)
                })
            }

            function updateDirectiveItem(id, newTitle, newText) {
                var next = []
                for (var i = 0; i < directives.length; i++) {
                    var it = directives[i]
                    if (it.id === id) {
                        next.push({
                            id: it.id,
                            title: newTitle,
                            text: newText,
                            created_at: it.created_at,
                            tags: extractTags(newTitle + " " + newText)
                        })
                    } else {
                        next.push(it)
                    }
                }
                directives = next
                if (selectedDirectiveId === id) directiveText = newText
                dirView.setText(JSON.stringify({ directives: next, selectedId: selectedDirectiveId }, null, 2))
                setStatus("Directive updated")
            }

            function deleteDirectiveItem(id) {
                var next = []
                for (var i = 0; i < directives.length; i++) {
                    if (directives[i].id !== id) next.push(directives[i])
                }
                directives = next
                var sel = selectedDirectiveId === id ? "" : selectedDirectiveId
                selectedDirectiveId = sel
                if (sel === "") directiveText = ""
                dirView.setText(JSON.stringify({ directives: next, selectedId: sel }, null, 2))
                setStatus("Directive deleted")
            }

            function addDirective() {
                if (directiveNewTitle.trim() === "" && directiveNewBody.trim() === "") {
                    setStatus("Nothing to add")
                    return
                }
                if (dirAddProc.running) return
                dirAddProc.running = true
            }

            function addSkill() {
                var n = skillNewName.trim()
                var d = skillNewDesc.trim()
                if (n === "" && d === "") {
                    setStatus("Nothing to add")
                    return
                }
                if (n === "") {
                    setStatus("A skill needs a name")
                    return
                }
                if (skillAddProc.running) return
                skillAddProc.running = true
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
                return library.filter(p => {
                    var tag = !tagFilter || (p.tags || []).indexOf(tagFilter) !== -1
                    return tag
                })
            }

            function extractTags(txt) {
                var out = []
                var re = /#(\w+)/g
                var m
                while ((m = re.exec(String(txt || ""))) !== null) {
                    if (out.indexOf(m[1]) === -1) out.push(m[1])
                }
                return out
            }

            function updateLibraryItem(id, newText) {
                var next = []
                for (var i = 0; i < library.length; i++) {
                    var it = library[i]
                    if (it.id === id) {
                        next.push({
                            id: it.id,
                            text: newText,
                            created_at: it.created_at,
                            tags: extractTags(newText),
                            favourite: !!it.favourite
                        })
                    } else {
                        next.push(it)
                    }
                }
                library = next
                libView.setText(JSON.stringify({ library: next }, null, 2))
                setStatus("Library item updated")
            }

            function deleteLibraryItem(id) {
                var next = []
                for (var i = 0; i < library.length; i++) {
                    if (library[i].id !== id) next.push(library[i])
                }
                library = next
                libView.setText(JSON.stringify({ library: next }, null, 2))
                setStatus("Library item deleted")
            }

            function addPromptToLibrary() {
                if (libraryNewText.trim() === "") {
                    setStatus("Nothing to add")
                    return
                }
                if (libAddProc.running) return
                libAddProc.running = true
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
                if (directiveText.trim() !== "") parts.push(directiveText.trim())
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
                    directive: directiveText,
                    directive_id: selectedDirectiveId,
                    directive_title: selectedDirectiveTitle(),
                    user_prompt: draftText,
                    raw_payload: composeRaw(),
                    payload: payload,
                    record: recordOn
                }
                sendJobView.setText(JSON.stringify(job))
                sendProc.jobPath = card.cacheDir + "/send_job.json"
                setStatus("Sending…")
                sendProc.running = true
            }

            function copyPrompt(txt) {
                Quickshell.clipboardText = String(txt || "")
                setStatus("Prompt copied to clipboard")
            }

            // ---------- Settings ----------
            function loadSettingsDrafts() {
                settingsDraftData = settings.dataDir || ""
                settingsDraftCache = settings.cacheDir || ""
                settingsDraftExporter = settings.exporterPath || ""
                settingsDraftDb = settings.dbPath || ""
            }

            function saveSettingsFrom(data, cache, exporter, db) {
                var obj = {
                    dataDir: String(data || ""),
                    cacheDir: String(cache || ""),
                    exporterPath: String(exporter || ""),
                    dbPath: String(db || "")
                }
                settingsLog = "Saving…"
                saveSettingsProc.command = ["python3", pluginDir + "/scripts/save_settings.py", JSON.stringify(obj)]
                saveSettingsProc.running = true
            }

            function saveSettings() {
                saveSettingsFrom(settingsDraftData, settingsDraftCache, settingsDraftExporter, settingsDraftDb)
            }

            function settingsDefaults() {
                settingsDraftData = ""
                settingsDraftCache = ""
                settingsDraftExporter = ""
                settingsDraftDb = ""
                saveSettingsProc.command = ["python3", pluginDir + "/scripts/save_settings.py", "{}"]
                settingsLog = "Resetting to defaults…"
                saveSettingsProc.running = true
            }

            function runDetect() {
                settingsLog = "Checking…"
                detectProc.running = true
            }

            function runRepair() {
                settingsLog = "Repairing…"
                repairProc.running = true
            }

            function openFolder(p) {
                if (!p) return
                openFolderProc.command = ["xdg-open", p]
                openFolderProc.running = true
            }

            function loadSysPromptSources() {
                sysPromptProc.running = true
            }

            function selectSystemPrompt(path) {
                if (!path) return
                sysPromptTarget = path
                setStatus("Opened " + path)
            }

            function setSysPromptDraft(txt) {
                sysPromptDraft = txt
                sysPromptDirty = false
            }

            function saveSystemPromptText(txt) {
                if (sysPromptTarget === "") return
                sysPromptFile.setText(String(txt || ""))
                sysPromptDirty = false
                setStatus("Saved " + sysPromptTarget)
            }

            onViewModeChanged: {
                if (viewMode === 1 && sysPromptSources.length === 0)
                    sysPromptProc.running = true
                if (viewMode === 7) {
                    loadSettingsDrafts()
                    detectProc.running = true
                }
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
                id: dirView
                path: card.directivesPath
                watchChanges: true
                printErrors: false
                onFileChanged: reload()
                onLoaded: {
                    try {
                        var d = JSON.parse(String(text() || "{}"))
                        card.directives = d.directives || []
                        card.selectedDirectiveId = d.selectedId || ""
                        card.directiveText = card.directiveTextFor(card.selectedDirectiveId)
                    } catch (e) {
                        card.directives = []
                        card.selectedDirectiveId = ""
                        card.directiveText = ""
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
                path: card.cacheDir + "/send_job.json"
                printErrors: false
            }

            FileView {
                id: settingsFile
                path: card.settingsPath
                watchChanges: true
                printErrors: false
                onFileChanged: reload()
                onLoaded: {
                    try {
                        var d = JSON.parse(String(text() || "{}"))
                        card.settings = (d && typeof d === "object") ? d : {}
                    } catch (e) {
                        card.settings = {}
                    }
                    card.loadSettingsDrafts()
                }
            }

            FileView {
                id: sysPromptFile
                path: card.sysPromptTarget
                watchChanges: true
                printErrors: false
                onFileChanged: reload()
                onLoaded: card.setSysPromptDraft(String(text() || ""))
            }

            Process {
                id: initStoreProc
                command: ["python3", card.pluginDir + "/scripts/init_store.py"]
                onExited: (exitCode, exitStatus) => {
                    libView.reload()
                    dirView.reload()
                    bmView.reload()
                    skillStylesView.reload()
                    trainingView.reload()
                }
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
                id: libAddProc
                command: ["python3", card.pluginDir + "/scripts/save_prompt.py", card.libraryNewText]
                onExited: (exitCode, exitStatus) => {
                    if (exitCode === 0) {
                        card.libraryNewText = ""
                        card.setStatus("Added to library")
                        libView.reload()
                    } else {
                        card.setStatus("Add failed (exit " + exitCode + ")")
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
                id: dirAddProc
                command: ["python3", card.pluginDir + "/scripts/save_directive.py", card.directiveNewTitle, card.directiveNewBody]
                onExited: (exitCode, exitStatus) => {
                    if (exitCode === 0) {
                        card.directiveNewTitle = ""
                        card.directiveNewBody = ""
                        card.setStatus("Directive added")
                        dirView.reload()
                    } else {
                        card.setStatus("Add failed (exit " + exitCode + ")")
                    }
                }
            }

            Process {
                id: skillAddProc
                property string buf: ""
                command: ["python3", card.pluginDir + "/scripts/add_skill.py", card.skillNewName, card.skillNewDesc]
                stdout: SplitParser { onRead: function (line) { skillAddProc.buf += line + "\n" } }
                stderr: SplitParser { onRead: function (line) { skillAddProc.buf += line + "\n" } }
                onExited: (exitCode, exitStatus) => {
                    var note = String(skillAddProc.buf || "").trim().split("\n").pop()
                    if (exitCode === 0) {
                        card.skillNewName = ""
                        card.skillNewDesc = ""
                        card.setStatus("Skill added")
                    } else {
                        card.setStatus(note ? String(note).replace(/^ERROR:\s*/, "") : "Add failed (exit " + exitCode + ")")
                    }
                    skillAddProc.buf = ""
                    skillsView.reload()
                }
            }

            Process {
                id: dirExportJsonProc
                command: ["python3", card.pluginDir + "/scripts/export_directives.py"]
                stdout: SplitParser {
                    onRead: function(line) {
                        if (String(line).trim() !== "") card.setStatus("Exported: " + String(line).trim())
                    }
                }
            }

            Process {
                id: dirExportMdProc
                command: ["python3", card.pluginDir + "/scripts/export_directives_md.py"]
                stdout: SplitParser {
                    onRead: function(line) {
                        if (String(line).trim() !== "") card.setStatus("Exported: " + String(line).trim())
                    }
                }
            }

            Process {
                id: dirImportDialog
                command: ["python3", "-c", "import tkinter.filedialog as fd; print(fd.askopenfilename(), flush=True)"]
                stdout: SplitParser {
                    onRead: function(line) {
                        var p = String(line).trim()
                        if (p === "") return
                        dirImportFile.command = ["python3", card.pluginDir + "/scripts/import_directives.py", p]
                        dirImportFile.running = true
                    }
                }
            }

            Process {
                id: dirImportFile
                stdout: SplitParser {
                    onRead: function(line) {
                        if (String(line).trim() !== "") card.setStatus(String(line).trim())
                    }
                }
                onExited: dirView.reload()
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
                    directive: card.directiveText,
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

            Process {
                id: saveSettingsProc
                property string buf: ""
                stdout: SplitParser {
                    onRead: function(line) {
                        if (String(line).trim() !== "") { saveSettingsProc.buf += line + "\n"; card.settingsLog = String(line).trim() }
                    }
                }
                stderr: SplitParser {
                    onRead: function(line) {
                        if (String(line).trim() !== "") { saveSettingsProc.buf += line + "\n"; card.settingsLog = String(line).trim() }
                    }
                }
                onExited: (exitCode, exitStatus) => {
                    saveSettingsProc.buf = ""
                    settingsFile.reload()
                    detectProc.running = true
                }
            }

            Process {
                id: detectProc
                property string buf: ""
                command: ["python3", card.pluginDir + "/scripts/detect_paths.py"]
                stdout: SplitParser { onRead: function(line) { detectProc.buf += line + "\n" } }
                onExited: (exitCode, exitStatus) => {
                    try {
                        var d = JSON.parse(detectProc.buf)
                        card.settingsChecks = d.checks || []
                        card.settingsLog = d.ok ? "All checks passed." : "Some checks need attention."
                    } catch (e) {
                        card.settingsChecks = []
                        card.settingsLog = "Could not read path report."
                    }
                    detectProc.buf = ""
                }
            }

            Process {
                id: repairProc
                property string buf: ""
                command: ["python3", card.pluginDir + "/scripts/repair_setup.py"]
                stdout: SplitParser {
                    onRead: function(line) {
                        if (String(line).trim() !== "") { repairProc.buf += line + "\n"; card.settingsLog = String(line).trim(); card.setStatus(String(line).trim()) }
                    }
                }
                stderr: SplitParser {
                    onRead: function(line) {
                        if (String(line).trim() !== "") { repairProc.buf += line + "\n"; card.settingsLog = String(line).trim() }
                    }
                }
                onExited: (exitCode, exitStatus) => {
                    repairProc.buf = ""
                    detectProc.running = true
                }
            }

            Process {
                id: openFolderProc
                stderr: SplitParser {
                    onRead: function(line) {
                        if (String(line).trim() !== "") card.setStatus(String(line).trim())
                    }
                }
            }

            Process {
                id: sysPromptProc
                property string buf: ""
                command: ["python3", card.pluginDir + "/scripts/list_system_prompts.py", card.currentCwd()]
                stdout: SplitParser { onRead: function(line) { sysPromptProc.buf += line + "\n" } }
                onExited: (exitCode, exitStatus) => {
                    try {
                        var d = JSON.parse(sysPromptProc.buf)
                        card.sysPromptSources = d.sources || []
                        if (card.sysPromptTarget === "" && card.sysPromptSources.length > 0)
                            card.selectSystemPrompt(card.sysPromptSources[0].path)
                    } catch (e) {
                        card.sysPromptSources = []
                    }
                    sysPromptProc.buf = ""
                }
            }

            Shortcut { sequence: "Escape"; onActivated: root.close() }
            Shortcut { sequence: "Ctrl+F"; onActivated: { if (card.viewMode === 0 && card.promptSearchInput) card.promptSearchInput.forceActiveFocus() } }
            Shortcut { sequence: "Ctrl+W"; onActivated: card.draftText = "" }
            Shortcut { sequence: "Ctrl+S"; onActivated: card.savePrompt() }
            Shortcut { sequence: "Ctrl+E"; onActivated: card.showEditor() }
            Shortcut { sequence: "Ctrl+1"; onActivated: { card.viewMode = 0; card.mainTab = 0 } }
            Shortcut { sequence: "Ctrl+2"; onActivated: card.viewMode = 1 }
            Shortcut { sequence: "Ctrl+3"; onActivated: card.viewMode = 2 }
            Shortcut { sequence: "Ctrl+4"; onActivated: card.viewMode = 3 }
            Shortcut { sequence: "Ctrl+5"; onActivated: card.viewMode = 4 }
            Shortcut { sequence: "Ctrl+6"; onActivated: card.viewMode = 5 }
            Shortcut { sequence: "Ctrl+7"; onActivated: card.viewMode = 6 }
            Shortcut { sequence: "Ctrl+8"; onActivated: card.viewMode = 7 }
            Shortcut { sequence: "Ctrl+9"; onActivated: card.viewMode = 8 }
            Shortcut { sequence: "Alt+1"; onActivated: { card.viewMode = 0; card.mainTab = 0 } }
            Shortcut { sequence: "Alt+2"; onActivated: { card.viewMode = 0; card.openAnswer() } }
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
                    width: headerCol.width
                    height: 28

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Repeater {
                            model: ["Main", "System Prompt", "Skills", "Directives", "Library", "Stats", "Data", "Settings", "How-To"]
                            delegate: Rectangle {
                                width: 108
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

                }

                Item {
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

                    TextField {
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

                Loader { anchors.fill: parent; active: card.viewMode === 0; sourceComponent: sessionsView }
                Loader { anchors.fill: parent; active: card.viewMode === 1; sourceComponent: systemPromptView }
                Loader { anchors.fill: parent; active: card.viewMode === 2; sourceComponent: skillsEditView }
                Loader { anchors.fill: parent; active: card.viewMode === 3; sourceComponent: directivesView }
                Loader { anchors.fill: parent; active: card.viewMode === 4; sourceComponent: libraryView }
                Loader { anchors.fill: parent; active: card.viewMode === 5; sourceComponent: statsView }
                Loader { anchors.fill: parent; active: card.viewMode === 6; sourceComponent: datasetView }
                Loader { anchors.fill: parent; active: card.viewMode === 7; sourceComponent: settingsView }
                Loader { anchors.fill: parent; active: card.viewMode === 8; sourceComponent: howToView }
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

                                FlatButton { text: "Refresh"; onClicked: card.reloadCurrentAnswer() }
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

                        // ---------- System Prompts (jump) ----------
                        Rectangle {
                            id: systemPromptsPane
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 44
                            radius: 8
                            color: sysMouse.containsMouse ? "#242424" : "#1b1b1b"
                            border.width: 1
                            border.color: "#2a2a2a"

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "System Prompt"
                                    color: "#aaa"
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "edit the merged AGENTS.md OpenCode loads"
                                    color: "#666"
                                    font.pixelSize: 10
                                }
                            }

                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Open \u2192"
                                color: sysMouse.containsMouse ? "#8ab4f8" : "#555"
                                font.pixelSize: 10
                            }

                            MouseArea {
                                id: sysMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: card.viewMode = 1
                            }
                        }

                        // ---------- Skills ----------
                        Rectangle {
                            id: skillsPane
                            anchors.top: systemPromptsPane.bottom
                            anchors.topMargin: 6
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 100
                            radius: 8
                            color: "#202020"

                            Column {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 4

                                Item {
                                    width: parent.width
                                    height: 22

                                    Text {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Skills"
                                        color: "#aaa"
                                        font.pixelSize: 11
                                        font.weight: Font.Medium
                                    }

                                    TextField {
                                        id: composeSkillSearchField
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.min(220, parent.width - 60)
                                        height: 22
                                        placeholderText: "Search skills to toggle..."
                                        onTextChanged: card.composeSkillSearchText = text
                                        background: Rectangle { color: "#252525"; radius: 6 }
                                        color: "white"
                                        font.pixelSize: 11
                                    }
                                }

                                ScrollView {
                                    id: skillsScroll
                                    width: parent.width
                                    height: parent.height - 22 - 4
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

                        // ---------- Directives ----------
                        Rectangle {
                            id: directivesPane
                            anchors.top: skillsPane.bottom
                            anchors.topMargin: 6
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 224
                            radius: 8
                            color: "#202020"

                            Column {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 4

                                Item {
                                    width: parent.width
                                    height: 22

                                    Row {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 6

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: "Directives"
                                            color: "#aaa"
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                        }

                                        Rectangle {
                                            height: 20
                                            radius: 4
                                            color: "#252525"
                                            width: dirSelLabel.implicitWidth + 10
                                            Text {
                                                id: dirSelLabel
                                                anchors.centerIn: parent
                                                text: card.selectedDirectiveId === "" ? "none selected" : card.selectedDirectiveTitle()
                                                color: card.selectedDirectiveId === "" ? "#777" : "#8ab4f8"
                                                font.pixelSize: 10
                                            }
                                        }
                                    }

                                    TextField {
                                        id: composeDirectiveSearchField
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 200
                                        height: 22
                                        placeholderText: "Search directives to toggle..."
                                        onTextChanged: card.directiveSearchText = text
                                        background: Rectangle { color: "#252525"; radius: 6 }
                                        color: "white"
                                        font.pixelSize: 11
                                    }
                                }

                                ScrollView {
                                    id: dirChipScroll
                                    width: parent.width
                                    height: 56
                                    clip: true
                                    contentWidth: availableWidth

                                    Flow {
                                        width: dirChipScroll.availableWidth
                                        spacing: 4

                                        Repeater {
                                            model: card.filteredComposeDirectives()
                                            delegate: Rectangle {
                                                property bool dirOn: card.selectedDirectiveId === modelData.id
                                                height: 24
                                                radius: 6
                                                width: Math.max(104, Math.min(160, Math.floor((dirChipScroll.availableWidth - 4) / 2)))
                                                color: dirOn ? "#3a6df0" : "#1a1a1a"
                                                border.width: 1
                                                border.color: dirOn ? "#8ab4f8" : "#333"

                                                Text {
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 7
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: parent.width - 18
                                                    elide: Text.ElideRight
                                                    text: (dirOn ? "✓ " : "") + (modelData.title || modelData.text || "directive")
                                                    color: dirOn ? "#fff" : "#ccc"
                                                    font.pixelSize: 10
                                                }

                                                MouseArea { anchors.fill: parent; onClicked: card.selectDirective(modelData.id) }
                                            }
                                        }
                                    }
                                }

                                ScrollView {
                                    id: dirBoxScroll
                                    width: parent.width
                                    height: parent.height - 112
                                    clip: true

                                    TextArea {
                                        id: dirBox
                                        width: dirBoxScroll.availableWidth
                                        wrapMode: TextArea.Wrap
                                        background: Item {}
                                        color: "#ddd"
                                        font.pixelSize: 11
                                        selectByMouse: true
                                        enabled: card.selectedDirectiveId !== ""
                                        text: card.directiveText
                                        onTextChanged: {
                                            if (text !== card.directiveText) card.directiveText = text
                                        }
                                        placeholderText: card.selectedDirectiveId === "" ? "Select a directive above…" : "Directive text…"
                                    }
                                }
                            }
                        }

                        // User Prompt (with library)
                        Item {
                            anchors.top: directivesPane.bottom
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

                                            FlatButton {
                                                text: "Copy"
                                                onClicked: {
                                                    Quickshell.clipboardText = card.draftText + (card.directiveText !== "" ? ("\n\n[Directive]: " + card.directiveText) : "")
                                                    card.setStatus("Copied system + user prompt")
                                                }
                                            }
                                            FlatButton { text: "Save to Library"; onClicked: card.savePrompt() }
                                            FlatButton { text: "Clear"; onClicked: card.draftText = "" }
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

                        FlatButton { text: "Export JSON"; onClicked: exportJsonProc.running = true }
                        FlatButton { text: "Export MD"; onClicked: exportMdProc.running = true }
                        FlatButton { text: "Import"; onClicked: importDialog.running = true }
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

                    ScrollView {
                        id: libScroll
                        anchors.top: tagFlow.bottom
                        anchors.topMargin: 8
                        anchors.bottom: libComposer.top
                        anchors.bottomMargin: 8
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        clip: true
                        contentWidth: availableWidth

                        Flow {
                            id: libGrid
                            width: libScroll.availableWidth
                            spacing: 6

                            Repeater {
                                id: libRepeater
                                model: card.filteredLibrary()
                                delegate: Rectangle {
                                    id: libCard
                                    property bool dirty: false
                                    property bool deleteArmed: false

                                    width: Math.floor((libScroll.availableWidth - 6) / 2)
                                    height: 180
                                    radius: 8
                                    color: "#202020"
                                    border.width: 1
                                    border.color: libCard.dirty ? "#3a6df0" : "#2e2e2e"

                                    Column {
                                        id: libCardCol
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.margins: 8
                                        spacing: 4

                                        ScrollView {
                                            id: libEditScroll
                                            width: parent.width
                                            height: 96
                                            clip: true

                                            TextArea {
                                                id: libEditEditor
                                                width: libEditScroll.availableWidth
                                                wrapMode: TextArea.Wrap
                                                background: Item {}
                                                color: "#ddd"
                                                font.pixelSize: 11
                                                selectByMouse: true
                                                text: modelData.text
                                                onTextChanged: libCard.dirty = (text !== modelData.text)
                                            }
                                        }

                                        Flow {
                                            width: parent.width
                                            height: 14
                                            clip: true
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

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 8
                                        spacing: 6

                                        FlatButton {
                                            text: "Save"
                                            enabled: libCard.dirty
                                            onClicked: card.updateLibraryItem(modelData.id, libEditEditor.text)
                                        }

                                        FlatButton {
                                            visible: libCard.dirty
                                            text: "Revert"
                                            onClicked: {
                                                libEditEditor.text = modelData.text
                                                libCard.dirty = false
                                            }
                                        }

                                        FlatButton {
                                            text: libCard.deleteArmed ? "Confirm?" : "Delete"
                                            onClicked: {
                                                if (libCard.deleteArmed) {
                                                    card.deleteLibraryItem(modelData.id)
                                                } else {
                                                    libCard.deleteArmed = true
                                                    delDisarm.restart()
                                                }
                                            }
                                        }
                                    }

                                    Timer {
                                        id: delDisarm
                                        interval: 4000
                                        onTriggered: libCard.deleteArmed = false
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: libComposer
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.bottom: parent.bottom
                        height: 34
                        radius: 6
                        color: "#252525"

                        TextField {
                            id: libNewField
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.right: libAddBtn.left
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            height: 24
                            placeholderText: "New prompt… (#tags extracted — Enter to add)"
                            text: card.libraryNewText
                            onTextChanged: card.libraryNewText = text
                            onAccepted: card.addPromptToLibrary()
                            background: Rectangle { color: "#1a1a1a"; radius: 6 }
                            color: "white"
                            font.pixelSize: 12
                        }

                        FlatButton {
                            id: libAddBtn
                            text: "Add"

                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: card.addPromptToLibrary()
                        }

                        Connections {
                            target: card
                            function onLibraryNewTextChanged() {
                                if (libNewField.text !== card.libraryNewText)
                                    libNewField.text = card.libraryNewText
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
                id: directivesView

                Item {
                    anchors.fill: parent

                    Row {
                        id: dirToolbar
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 8

                        Text {
                            text: "Directives"
                            color: "#ccc"
                            font.pixelSize: 14
                            height: 28
                            verticalAlignment: Text.AlignVCenter
                        }

                        FlatButton { text: "Export JSON"; onClicked: dirExportJsonProc.running = true }
                        FlatButton { text: "Export MD"; onClicked: dirExportMdProc.running = true }
                        FlatButton { text: "Import"; onClicked: dirImportDialog.running = true }
                    }

                    Flow {
                        id: dirTagFlow
                        anchors.top: dirToolbar.bottom
                        anchors.topMargin: 8
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 6

                        Repeater {
                            model: card.directiveTags()
                            delegate: Rectangle {
                                height: 24
                                radius: 12
                                width: dirTagLabel.implicitWidth + 16
                                color: card.directiveTagFilter === modelData ? "#3a6df0" : "#252525"
                                Text {
                                    id: dirTagLabel
                                    anchors.centerIn: parent
                                    text: "#" + modelData
                                    color: "white"
                                    font.pixelSize: 11
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: card.directiveTagFilter = card.directiveTagFilter === modelData ? "" : modelData
                                }
                            }
                        }
                    }

                    ScrollView {
                        id: dirScroll
                        anchors.top: dirTagFlow.bottom
                        anchors.topMargin: 8
                        anchors.bottom: dirComposer.top
                        anchors.bottomMargin: 8
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        clip: true
                        contentWidth: availableWidth

                        Flow {
                            id: dirGrid
                            width: dirScroll.availableWidth
                            spacing: 6

                            Repeater {
                                id: dirRepeater
                                model: card.filteredDirectives()
                                delegate: Rectangle {
                                    id: dirCard
                                    property bool dirty: false
                                    property bool deleteArmed: false
                                    property bool selected: card.selectedDirectiveId === modelData.id

                                    width: Math.floor((dirScroll.availableWidth - 6) / 2)
                                    height: 210
                                    radius: 8
                                    color: "#202020"
                                    border.width: 1
                                    border.color: dirCard.selected ? "#8ab4f8" : (dirCard.dirty ? "#3a6df0" : "#2e2e2e")

                                    Column {
                                        id: dirCardCol
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.margins: 8
                                        spacing: 4

                                        TextField {
                                            id: dirTitleField
                                            width: parent.width
                                            height: 30
                                            placeholderText: "Title"
                                            text: modelData.title || ""
                                            onTextChanged: dirCard.dirty = (text !== (modelData.title || "") || dirBodyEditor.text !== (modelData.text || ""))
                                            background: Rectangle { color: "#1a1a1a"; radius: 4 }
                                            color: "white"
                                            font.pixelSize: 12
                                            verticalAlignment: TextInput.AlignVCenter
                                            leftPadding: 7
                                            rightPadding: 7
                                        }

                                        ScrollView {
                                            id: dirEditScroll
                                            width: parent.width
                                            height: 84
                                            clip: true

                                            TextArea {
                                                id: dirBodyEditor
                                                width: dirEditScroll.availableWidth
                                                wrapMode: TextArea.Wrap
                                                background: Item {}
                                                color: "#ddd"
                                                font.pixelSize: 11
                                                selectByMouse: true
                                                text: modelData.text || ""
                                                onTextChanged: dirCard.dirty = (dirTitleField.text !== (modelData.title || "") || text !== (modelData.text || ""))
                                            }
                                        }

                                        Flow {
                                            width: parent.width
                                            height: 14
                                            clip: true
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

                                    Row {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 8
                                        spacing: 6

                                        FlatButton {
                                            text: dirCard.selected ? "Selected" : "Select"
                                            onClicked: card.selectDirective(modelData.id)
                                        }

                                        FlatButton {
                                            text: "Save"
                                            enabled: dirCard.dirty
                                            onClicked: card.updateDirectiveItem(modelData.id, dirTitleField.text, dirBodyEditor.text)
                                        }

                                        FlatButton {
                                            visible: dirCard.dirty
                                            text: "Revert"
                                            onClicked: {
                                                dirTitleField.text = modelData.title || ""
                                                dirBodyEditor.text = modelData.text || ""
                                                dirCard.dirty = false
                                            }
                                        }

                                        FlatButton {
                                            text: dirCard.deleteArmed ? "Confirm?" : "Delete"
                                            onClicked: {
                                                if (dirCard.deleteArmed) {
                                                    card.deleteDirectiveItem(modelData.id)
                                                } else {
                                                    dirCard.deleteArmed = true
                                                    dirDelDisarm.restart()
                                                }
                                            }
                                        }
                                    }

                                    Timer {
                                        id: dirDelDisarm
                                        interval: 4000
                                        onTriggered: dirCard.deleteArmed = false
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: dirComposer
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.bottom: parent.bottom
                        height: 34
                        radius: 6
                        color: "#252525"

                        TextField {
                            id: dirNewTitleField
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 220
                            height: 24
                            placeholderText: "New directive title…"
                            text: card.directiveNewTitle
                            onTextChanged: card.directiveNewTitle = text
                            background: Rectangle { color: "#1a1a1a"; radius: 6 }
                            color: "white"
                            font.pixelSize: 12
                        }

                        TextField {
                            id: dirNewBodyField
                            anchors.left: dirNewTitleField.right
                            anchors.leftMargin: 6
                            anchors.right: dirAddBtn.left
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            height: 24
                            placeholderText: "Body… (#tags extracted — Enter to add)"
                            text: card.directiveNewBody
                            onTextChanged: card.directiveNewBody = text
                            onAccepted: card.addDirective()
                            background: Rectangle { color: "#1a1a1a"; radius: 6 }
                            color: "white"
                            font.pixelSize: 12
                        }

                        FlatButton {
                            id: dirAddBtn
                            text: "Add"

                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: card.addDirective()
                        }

                        Connections {
                            target: card
                            function onDirectiveNewTitleChanged() {
                                if (dirNewTitleField.text !== card.directiveNewTitle)
                                    dirNewTitleField.text = card.directiveNewTitle
                            }
                            function onDirectiveNewBodyChanged() {
                                if (dirNewBodyField.text !== card.directiveNewBody)
                                    dirNewBodyField.text = card.directiveNewBody
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: dirRepeater.count === 0
                        text: card.directives.length === 0
                            ? "No directives yet — add one below"
                            : "No directives match the current filter"
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
                        anchors.bottom: skillComposer.top
                        clip: true
                        contentWidth: availableWidth

                        Flow {
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

                    // Add-a-skill row, mirroring the Library and Directives composers.
                    Rectangle {
                        id: skillComposer
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6
                        height: 34
                        radius: 6
                        color: "#252525"

                        TextField {
                            id: skillNameField
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            width: 200
                            anchors.verticalCenter: parent.verticalCenter
                            height: 24
                            placeholderText: "New skill name…"
                            text: card.skillNewName
                            onTextChanged: card.skillNewName = text
                            onAccepted: card.addSkill()
                            background: Rectangle { color: "#1a1a1a"; radius: 6 }
                            color: "white"
                            font.pixelSize: 12
                        }

                        TextField {
                            id: skillDescField
                            anchors.left: skillNameField.right
                            anchors.leftMargin: 6
                            anchors.right: skillAddBtn.left
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            height: 24
                            placeholderText: "What it does (Enter to add)"
                            text: card.skillNewDesc
                            onTextChanged: card.skillNewDesc = text
                            onAccepted: card.addSkill()
                            background: Rectangle { color: "#1a1a1a"; radius: 6 }
                            color: "white"
                            font.pixelSize: 12
                        }

                        FlatButton {
                            id: skillAddBtn
                            text: "Add"
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            onClicked: card.addSkill()
                        }

                        Connections {
                            target: card
                            function onSkillNewNameChanged() {
                                if (skillNameField.text !== card.skillNewName)
                                    skillNameField.text = card.skillNewName
                            }
                            function onSkillNewDescChanged() {
                                if (skillDescField.text !== card.skillNewDesc)
                                    skillDescField.text = card.skillNewDesc
                            }
                        }
                    }
                }
            }

            Component {
                id: statsView

                Item {
                    anchors.fill: parent

                    Rectangle {
                        id: statsPanel
                        anchors.centerIn: parent
                        width: Math.min(720, parent.width - 80)
                        height: statsCol.implicitHeight + 48
                        radius: 10
                        color: "#202020"
                        border.width: 1
                        border.color: "#2e2e2e"

                        Column {
                            id: statsCol
                            anchors.centerIn: parent
                            width: parent.width - 48
                            spacing: 10

                            Text {
                                text: "Stats"
                                color: "#ccc"
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }

                            Rectangle { width: parent.width; height: 1; color: "#2e2e2e" }

                            Row {
                                spacing: 12
                                width: parent.width
                                Text { text: "Sessions"; color: "#aaa"; font.pixelSize: 13; width: 180 }
                                Text { text: card.sessions.length; color: "white"; font.pixelSize: 13; font.bold: true }
                            }

                            Row {
                                spacing: 12
                                width: parent.width
                                Text { text: "Library items"; color: "#aaa"; font.pixelSize: 13; width: 180 }
                                Text { text: card.library.length; color: "white"; font.pixelSize: 13; font.bold: true }
                            }

                            Row {
                                spacing: 12
                                width: parent.width
                                Text { text: "Prompts (last 30d)"; color: "#aaa"; font.pixelSize: 13; width: 180 }
                                Text {
                                    text: card.sessions.reduce((a, s) =>
                                        a + s.recent_prompts.filter(p => (Date.now() - p.time_created) < 30 * 24 * 3600 * 1000).length, 0)
                                    color: "white"
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                            }

                            Row {
                                spacing: 12
                                width: parent.width
                                Text { text: "Active session"; color: "#aaa"; font.pixelSize: 13; width: 180 }
                                Text {
                                    width: parent.width - 180
                                    text: card.sessions[card.activeSessionIndex] ? card.sessions[card.activeSessionIndex].title : "—"
                                    color: "white"
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }

            Component {
                id: systemPromptView

                Item {
                    anchors.fill: parent

                    Rectangle {
                        id: spList
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 300
                        color: "#1b1b1b"
                        radius: 8

                        Column {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            Text { text: "Instruction Sources"; color: "#ccc"; font.pixelSize: 13 }

                            ListView {
                                width: parent.width
                                height: parent.height - 30
                                clip: true
                                model: card.sysPromptSources
                                spacing: 4
                                delegate: Rectangle {
                                    width: ListView.view.width
                                    height: 42
                                    radius: 6
                                    color: card.sysPromptTarget === modelData.path ? "#3a6df0" : (spHover.containsMouse ? "#242424" : "#202020")

                                    Column {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        anchors.right: parent.right
                                        anchors.rightMargin: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 1

                                        Text { text: modelData.label; color: "white"; font.pixelSize: 11 }
                                        Text {
                                            width: parent.width
                                            text: modelData.exists ? modelData.path : modelData.path + "  (missing)"
                                            color: modelData.exists ? "#888" : "#c98"
                                            font.pixelSize: 9
                                            elide: Text.ElideMiddle
                                        }
                                    }

                                    MouseArea { id: spHover; anchors.fill: parent; hoverEnabled: true; onClicked: card.selectSystemPrompt(modelData.path) }
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.left: spList.right
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        color: "#1b1b1b"
                        radius: 8

                        Column {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            Row {
                                spacing: 8
                                Text {
                                    width: Math.min(560, spList.parent.width - 320)
                                    text: card.sysPromptTarget === "" ? "No file selected" : card.sysPromptTarget
                                    color: "#aaa"; font.pixelSize: 11; elide: Text.ElideMiddle
                                }
                                Text { visible: card.sysPromptDirty; text: "unsaved"; color: "#e0a"; font.pixelSize: 10 }
                            }

                            ScrollView {
                                width: parent.width
                                height: parent.height - 70

                                TextArea {
                                    id: promptArea
                                    text: ""
                                    color: "#ddd"
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 11
                                    wrapMode: TextEdit.Wrap
                                    selectByMouse: true
                                    onTextChanged: card.sysPromptDirty = true
                                    background: Rectangle { color: "#141414"; radius: 6 }
                                }
                            }

                            Row {
                                spacing: 8
                                FlatButton {
                                    text: "Save"
                                    onClicked: card.saveSystemPromptText(promptArea.text)
                                }
                                FlatButton {
                                    text: "Reload"
                                    onClicked: sysPromptFile.reload()
                                }
                            }
                        }
                    }

                    Connections {
                        target: card
                        function onSysPromptDraftChanged() {
                            promptArea.text = card.sysPromptDraft
                            card.sysPromptDirty = false
                        }
                    }
                }
            }

            Component {
                id: settingsView

                Item {
                    anchors.fill: parent

                    ScrollView {
                        id: settingsScroll
                        anchors.fill: parent
                        anchors.margins: 20
                        contentWidth: availableWidth

                        Column {
                            id: settingsCol
                            width: Math.min(940, settingsScroll.availableWidth)
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 16

                            // ---------- Title ----------
                            Column {
                                width: parent.width
                                spacing: 2

                                Text {
                                    text: "Settings"
                                    color: "#ccc"
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    width: parent.width
                                    text: "Where the panel stores things. Leave a field empty to use its default."
                                    color: "#777"
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                }
                            }

                            // ---------- Status ----------
                            Rectangle {
                                width: parent.width
                                height: checksCol.implicitHeight + 32
                                color: "#202020"
                                radius: 10
                                border.width: 1
                                border.color: "#2e2e2e"

                                Column {
                                    id: checksCol
                                    anchors.left: parent.left
                                    anchors.leftMargin: 16
                                    anchors.right: parent.right
                                    anchors.rightMargin: 16
                                    anchors.top: parent.top
                                    anchors.topMargin: 16
                                    spacing: 6

                                    Text {
                                        text: "Status"
                                        color: "#aaa"
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                    }

                                    Repeater {
                                        model: card.settingsChecks
                                        delegate: Row {
                                            width: checksCol.width
                                            spacing: 8

                                            Text {
                                                width: 14
                                                text: modelData.ok ? "\u2713" : "\u2717"
                                                color: modelData.ok ? "#6fcf97" : "#e06c6c"
                                                font.pixelSize: 11
                                            }
                                            Text {
                                                width: 140
                                                text: modelData.label
                                                color: "#ccc"
                                                font.pixelSize: 11
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                width: Math.max(120, checksCol.width - 14 - 8 - 140 - 8 - (modelData.ok ? 0 : 200))
                                                text: modelData.path
                                                color: "#888"
                                                font.pixelSize: 10
                                                elide: Text.ElideMiddle
                                            }
                                            Text {
                                                width: 200
                                                visible: !modelData.ok
                                                text: modelData.ok ? "" : modelData.hint
                                                color: "#c98"
                                                font.pixelSize: 10
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }

                            // ---------- Paths ----------
                            Column {
                                width: parent.width
                                spacing: 8

                                Text {
                                    text: "Paths"
                                    color: "#aaa"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }

                                // data
                                Row {
                                    width: settingsCol.width
                                    spacing: 10

                                    Text { width: 150; text: "Data folder"; color: "#aaa"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                                    TextField {
                                        id: fData
                                        width: Math.max(200, settingsCol.width - 150 - 10 - 80)
                                        height: 26
                                        color: "white"
                                        font.pixelSize: 11
                                        placeholderText: card.dataDir
                                        background: Rectangle { color: "#1a1a1a"; radius: 6 }
                                        onTextChanged: card.settingsDraftData = text
                                    }
                                    FlatButton {
                                        text: "Open"
                                        anchors.verticalCenter: parent.verticalCenter
                                        onClicked: card.openFolder(fData.text || card.dataDir)
                                    }
                                }

                                // cache
                                Row {
                                    width: settingsCol.width
                                    spacing: 10

                                    Text { width: 150; text: "Cache folder"; color: "#aaa"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                                    TextField {
                                        id: fCache
                                        width: Math.max(200, settingsCol.width - 150 - 10 - 80)
                                        height: 26
                                        color: "white"
                                        font.pixelSize: 11
                                        placeholderText: card.cacheDir
                                        background: Rectangle { color: "#1a1a1a"; radius: 6 }
                                        onTextChanged: card.settingsDraftCache = text
                                    }
                                    FlatButton {
                                        text: "Open"
                                        anchors.verticalCenter: parent.verticalCenter
                                        onClicked: card.openFolder(fCache.text || card.cacheDir)
                                    }
                                }

                                // exporter / database
                                Row {
                                    width: settingsCol.width
                                    spacing: 10

                                    Text { width: 150; text: "Exporter"; color: "#aaa"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                                    TextField {
                                        id: fExp
                                        width: Math.max(200, settingsCol.width - 150 - 10 - 80)
                                        height: 26
                                        color: "white"
                                        font.pixelSize: 11
                                        placeholderText: card.exporterPath
                                        background: Rectangle { color: "#1a1a1a"; radius: 6 }
                                        onTextChanged: card.settingsDraftExporter = text
                                    }
                                    FlatButton {
                                        text: "Open"
                                        anchors.verticalCenter: parent.verticalCenter
                                        onClicked: card.openFolder(fExp.text || card.exporterPath)
                                    }
                                }

                                Row {
                                    width: settingsCol.width
                                    spacing: 10

                                    Text { width: 150; text: "OpenCode database"; color: "#aaa"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                                    TextField {
                                        id: fDb
                                        width: Math.max(200, settingsCol.width - 150 - 10 - 80)
                                        height: 26
                                        color: "white"
                                        font.pixelSize: 11
                                        placeholderText: card.dbPath
                                        background: Rectangle { color: "#1a1a1a"; radius: 6 }
                                        onTextChanged: card.settingsDraftDb = text
                                    }
                                    FlatButton {
                                        text: "Open"
                                        anchors.verticalCenter: parent.verticalCenter
                                        onClicked: card.openFolder(fDb.text || card.dbPath)
                                    }
                                }
                            }

                            // ---------- Actions ----------
                            Rectangle {
                                width: parent.width
                                height: actionRow.implicitHeight + 20
                                color: "#202020"
                                radius: 10
                                border.width: 1
                                border.color: "#2e2e2e"

                                Row {
                                    id: actionRow
                                    anchors.left: parent.left
                                    anchors.leftMargin: 16
                                    anchors.right: parent.right
                                    anchors.rightMargin: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8

                                    FlatButton {
                                        text: "Save"
                                        onClicked: card.saveSettingsFrom(fData.text, fCache.text, fExp.text, fDb.text)
                                    }
                                    FlatButton {
                                        text: "Reset to defaults"
                                        onClicked: {
                                            fData.text = ""; fCache.text = ""; fExp.text = ""; fDb.text = ""
                                            card.settingsDefaults()
                                        }
                                    }
                                    FlatButton { text: "Detect"; onClicked: card.runDetect() }
                                    FlatButton { text: "Repair"; onClicked: card.runRepair() }
                                }
                            }

                            Text {
                                width: parent.width
                                text: card.settingsLog
                                color: "#8ab4f8"
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }
                        }
                    }

                    Component.onCompleted: {
                        fData.text = card.settingsDraftData
                        fCache.text = card.settingsDraftCache
                        fExp.text = card.settingsDraftExporter
                        fDb.text = card.settingsDraftDb
                    }
                }
            }

            Component {
                id: howToView

                Item {
                    anchors.fill: parent

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 20
                        radius: 10
                        color: "#202020"
                        border.width: 1
                        border.color: "#2e2e2e"

                        ScrollView {
                            id: howScroll
                            anchors.fill: parent
                            anchors.margins: 24
                            contentWidth: availableWidth

                            Column {
                                width: Math.min(860, howScroll.availableWidth)
                                spacing: 18

                                Text {
                                    text: "How-To"
                                    color: "#ccc"
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                }

                                Rectangle { width: parent.width; height: 1; color: "#2e2e2e" }

                                // ---------- Tabs ----------
                                Column {
                                    width: parent.width
                                    spacing: 4
                                    Text { text: "Tabs"; color: "#ccc"; font.pixelSize: 13; font.weight: Font.DemiBold }
                                    Text {
                                        width: parent.width
                                        text: "1 Main  ·  2 System Prompt  ·  3 Skills  ·  4 Directives  ·  5 Library  ·  6 Stats  ·  7 Data  ·  8 Settings  ·  9 How-To"
                                        color: "#bbb"; font.pixelSize: 12; wrapMode: Text.WordWrap
                                    }
                                }

                                // ---------- Keyboard ----------
                                Column {
                                    width: parent.width
                                    spacing: 4
                                    Text { text: "Keyboard"; color: "#ccc"; font.pixelSize: 13; font.weight: Font.DemiBold }
                                    Text {
                                        width: parent.width
                                        text: "Ctrl+1..9 — jump to a tab\n" +
                                              "Alt+1 — Sessions    Alt+2 — Answers\n" +
                                              "Ctrl+F search  ·  Ctrl+W clear draft  ·  Ctrl+S save prompt  ·  Ctrl+E editor\n" +
                                              "Ctrl+Return send  ·  Ctrl+Shift+Left/Right move answer  ·  Esc close\n" +
                                              "Click outside the panel closes it; clicks inside never dismiss it."
                                        color: "#bbb"; font.pixelSize: 12; wrapMode: Text.WordWrap
                                    }
                                }

                                Rectangle { width: parent.width; height: 1; color: "#2e2e2e" }

                                // ---------- Recording + Data ----------
                                Column {
                                    width: parent.width
                                    spacing: 6

                                    Text { text: "Recording and the Data page"; color: "#ccc"; font.pixelSize: 13; font.weight: Font.DemiBold }

                                    Text {
                                        width: parent.width
                                        text: "● Record is a toggle in the send bar. While it is off, sending a prompt still works — nothing is stored. While it is on, every prompt you actually send is appended to the dataset as one record, together with the directive and skills that were attached and the session it went to."
                                        color: "#bbb"; font.pixelSize: 12; wrapMode: Text.WordWrap
                                    }

                                    Text {
                                        width: parent.width
                                        text: "The Data page shows those records. It is a read-only view of the dataset file — the plugin never deletes your data — and the count at the top is the number of records captured so far. Recording is independent of saving to the Library, which is a separate curated collection."
                                        color: "#bbb"; font.pixelSize: 12; wrapMode: Text.WordWrap
                                    }

                                    Text {
                                        width: parent.width
                                        text: "Export (ShareGPT + Alpaca) writes the whole dataset to two JSON files: ShareGPT uses the conversation messages, Alpaca uses an instruction/input/output shape. Use it to move the dataset elsewhere or to feed a fine-tuning tool. Refresh re-reads the file after an external change."
                                        color: "#bbb"; font.pixelSize: 12; wrapMode: Text.WordWrap
                                    }
                                }

                                Rectangle { width: parent.width; height: 1; color: "#2e2e2e" }

                                // ---------- System Prompt ----------
                                Column {
                                    width: parent.width
                                    spacing: 4
                                    Text { text: "System Prompt"; color: "#ccc"; font.pixelSize: 13; font.weight: Font.DemiBold }
                                    Text {
                                        width: parent.width
                                        text: "Edits the instruction files OpenCode merges into its system prompt. The left rail lists every source it reads: the global ~/.config/opencode/AGENTS.md, instructions[] entries in opencode.json, per-agent files, and the project AGENTS.md. Pick one on the left and edit it on the right; Save writes the file back."
                                        color: "#bbb"; font.pixelSize: 12; wrapMode: Text.WordWrap
                                    }
                                }

                                // ---------- Settings ----------
                                Column {
                                    width: parent.width
                                    spacing: 4
                                    Text { text: "Settings"; color: "#ccc"; font.pixelSize: 13; font.weight: Font.DemiBold }
                                    Text {
                                        width: parent.width
                                        text: "Choose where user data and cache live, point at the exporter and the OpenCode database, then Save. Leaving a field empty restores its default. Detect re-checks every path; Repair creates missing folders, seeds the stores and reinstalls the export timer. Changing a folder moves the existing files across instead of stranding them."
                                        color: "#bbb"; font.pixelSize: 12; wrapMode: Text.WordWrap
                                    }
                                }
                            }
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
                        anchors.margins: 20
                        spacing: 12

                        Row {
                            spacing: 12

                            Text { text: "Data"; color: "#ccc"; font.pixelSize: 14; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                height: 20
                                radius: 10
                                width: dsCount.implicitWidth + 16
                                color: "#252525"
                                Text { id: dsCount; anchors.centerIn: parent; text: card.trainingCount + " record" + (card.trainingCount === 1 ? "" : "s"); color: "#8ab4f8"; font.pixelSize: 11 }
                            }

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                height: 20
                                radius: 10
                                width: dsState.implicitWidth + 16
                                color: card.recordOn ? "#1f3a2a" : "#252525"
                                Text {
                                    id: dsState
                                    anchors.centerIn: parent
                                    text: card.recordOn ? "● Recording on" : "○ Recording off"
                                    color: card.recordOn ? "#6fcf97" : "#888"
                                    font.pixelSize: 11
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            text: "One record is appended each time you send a prompt while Record is on. Use it to build a dataset from real usage, then export it for fine-tuning. The How-To tab explains this in full."
                            color: "#888"
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                        }

                        Row {
                            spacing: 8
                            FlatButton { text: "Export (ShareGPT + Alpaca)"; onClicked: exportDatasetProc.running = true }
                            FlatButton { text: "Refresh"; onClicked: trainingView.reload() }
                        }

                        Rectangle {
                            width: parent.width
                            height: parent.height - 118
                            radius: 10
                            color: "#202020"
                            border.width: 1
                            border.color: "#2e2e2e"

                            ScrollView {
                                id: datasetScroll
                                anchors.fill: parent
                                anchors.margins: 12
                                clip: true
                                contentWidth: availableWidth

                                Text {
                                    width: datasetScroll.availableWidth
                                    text: card.trainingText !== "" ? card.trainingText : "No records yet. Turn on Record in the send bar and send a prompt."
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
