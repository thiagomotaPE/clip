#Requires AutoHotkey v2.0
#SingleInstance Force

; ===================== JSON CLASS =====================
class JSON {
    static Load(str) {
        pos := 1
        return JSON._ParseValue(str, &pos)
    }

    static _SkipWS(str, &pos) {
        while (pos <= StrLen(str) && InStr(" `t`n`r", SubStr(str, pos, 1)))
            pos++
    }

    static _ParseValue(str, &pos) {
        JSON._SkipWS(str, &pos)
        ch := SubStr(str, pos, 1)
        if (ch = "{")
            return JSON._ParseObject(str, &pos)
        else if (ch = "[")
            return JSON._ParseArray(str, &pos)
        else if (ch = '"')
            return JSON._ParseString(str, &pos)
        else if (ch = "t") {
            pos += 4
            return true
        } else if (ch = "f") {
            pos += 5
            return false
        } else if (ch = "n") {
            pos += 4
            return ""
        } else
            return JSON._ParseNumber(str, &pos)
    }

    static _ParseObject(str, &pos) {
        obj := Map()
        pos++
        JSON._SkipWS(str, &pos)
        if (SubStr(str, pos, 1) = "}") {
            pos++
            return obj
        }
        loop {
            JSON._SkipWS(str, &pos)
            key := JSON._ParseString(str, &pos)
            JSON._SkipWS(str, &pos)
            pos++
            JSON._SkipWS(str, &pos)
            val := JSON._ParseValue(str, &pos)
            obj[key] := val
            JSON._SkipWS(str, &pos)
            ch := SubStr(str, pos, 1)
            pos++
            if (ch = "}")
                break
        }
        return obj
    }

    static _ParseArray(str, &pos) {
        arr := []
        pos++
        JSON._SkipWS(str, &pos)
        if (SubStr(str, pos, 1) = "]") {
            pos++
            return arr
        }
        loop {
            val := JSON._ParseValue(str, &pos)
            arr.Push(val)
            JSON._SkipWS(str, &pos)
            ch := SubStr(str, pos, 1)
            pos++
            if (ch = "]")
                break
        }
        return arr
    }

    static _ParseString(str, &pos) {
        pos++
        result := ""
        while (pos <= StrLen(str)) {
            ch := SubStr(str, pos, 1)
            if (ch = '"') {
                pos++
                return result
            } else if (ch = "\") {
                nextCh := SubStr(str, pos+1, 1)
                switch nextCh {
                    case "n": result .= "`n"
                    case "r": result .= "`r"
                    case "t": result .= "`t"
                    case '"': result .= '"'
                    case "\": result .= "\"
                    case "/": result .= "/"
                    default:  result .= nextCh
                }
                pos += 2
            } else {
                result .= ch
                pos++
            }
        }
        return result
    }

    static _ParseNumber(str, &pos) {
        start := pos
        while (pos <= StrLen(str) && InStr("0123456789-+.eE", SubStr(str, pos, 1)))
            pos++
        return SubStr(str, start, pos - start) + 0
    }

    static Dump(obj, indent := "", curIndent := "") {
        if (obj is Map) {
            if (obj.Count = 0)
                return "{}"
            items := []
            for k, v in obj
                items.Push('"' JSON._Escape(k) '":' JSON.Dump(v, indent, curIndent . indent))
            return "{" . JSON._Join(items, ",") . "}"
        } else if (obj is Array) {
            if (obj.Length = 0)
                return "[]"
            items := []
            for v in obj
                items.Push(JSON.Dump(v, indent, curIndent . indent))
            return "[" . JSON._Join(items, ",") . "]"
        } else if (obj is String) {
            return '"' JSON._Escape(obj) '"'
        } else if (obj is Integer || obj is Float) {
            return String(obj)
        } else if (obj = true) {
            return "true"
        } else if (obj = false) {
            return "false"
        } else {
            return "null"
        }
    }

    static _Join(arr, sep) {
        result := ""
        for i, v in arr {
            if (i > 1)
                result .= sep
            result .= v
        }
        return result
    }

    static _Escape(s) {
        s := StrReplace(s, "\", "\\")
        s := StrReplace(s, '"', '\"')
        s := StrReplace(s, "`n", "\n")
        s := StrReplace(s, "`r", "\r")
        s := StrReplace(s, "`t", "\t")
        return s
    }
}

; ===================== CONFIGURATION =====================
dataFile            := A_ScriptDir "\scripts.json"
historyFile         := A_ScriptDir "\history.json"
HistoryMaxSize      := 50

; Colors
ColorBg             := "1E1E1E"
ColorBgEdit         := "2D2D2D"
ColorText           := "FFFFFF"
ColorAccent         := "0A84FF"
ColorSub            := "AAAAAA"

; State
IsSearchBarActive   := false
SuggestionsActive   := false
gSuggestions        := ""

; History
SearchHistory       := []
SearchHistoryIndex  := 0

; Load history on startup
LoadHistory()

; Load triggers on startup
LoadTriggers()

; ===================== HOTKEYS =====================
!Space::ShowSearchBar()

#HotIf WinActive("ahk_class AutoHotkeyGUI") && IsSearchBarActive
Enter::ProcessSearch()
Up::NavigateHistory(-1)
Down::NavigateHistory(1)
#HotIf

; ===================== SEARCH BAR =====================
ShowSearchBar() {
    global gSearch, editInput, ColorBg, ColorBgEdit, ColorText, ColorSub, IsSearchBarActive

    if (IsSearchBarActive) {
        CloseSearchBar()
        return
    }

    gSearch := Gui("+AlwaysOnTop -Caption +Border", "Scripts")
    gSearch.BackColor := ColorBg
    gSearch.MarginX := 15
    gSearch.MarginY := 12

    gSearch.SetFont("s16 cFFFFFF", "Segoe UI")
    editInput := gSearch.Add("Edit", "w690 h36 Background" ColorBgEdit " c" ColorText " -E0x200")
    editInput.SetFont("s16", "Segoe UI")

    gSearch.SetFont("s12 c" ColorSub, "Segoe UI")
    gSearch.Add("Text", "w680", "script name  •  all  •  create  •  update <name>  •  delete <name>")

    editInput.OnEvent("Change", (*) => UpdateSuggestions())
    gSearch.OnEvent("Close", (*) => CloseSearchBar())
    gSearch.OnEvent("Escape", (*) => CloseSearchBar())

    screenW := A_ScreenWidth
    screenH := A_ScreenHeight
    gSearch.Show("w720 x" (screenW/2 - 360) " y" (screenH/3))
    SetRoundedCorners(gSearch.Hwnd)

    editInput.Focus()
    IsSearchBarActive := true
}

CloseSearchBar() {
    global gSearch, IsSearchBarActive
    CloseSuggestions()
    IsSearchBarActive := false
    gSearch.Destroy()
}

ProcessSearch() {
    global gSearch, editInput, IsSearchBarActive, SearchHistory, SearchHistoryIndex, HistoryMaxSize
    text := Trim(editInput.Value)
    IsSearchBarActive := false
    gSearch.Destroy()

    if (text = "")
        return

    ; Save to history
    SearchHistory.Push(text)
    if (SearchHistory.Length > HistoryMaxSize)
        SearchHistory.RemoveAt(1)
    SearchHistoryIndex := SearchHistory.Length + 1
    SaveHistory()

    lower := StrLower(text)

    if (lower = "all")
        ShowAll()
    else if (lower = "create")
        OpenEditor("create")
    else if (SubStr(lower, 1, 7) = "update ")
        OpenEditor("update", Trim(SubStr(text, 8)))
    else if (SubStr(lower, 1, 7) = "delete ")
        DeleteScript(Trim(SubStr(text, 8)))
    else
        CopyScript(text)
}

; ===================== HISTORY =====================
LoadHistory() {
    global historyFile, SearchHistory, SearchHistoryIndex
    if !FileExist(historyFile)
        return
    try {
        content := FileRead(historyFile, "UTF-8")
        if (Trim(content) = "")
            return
        loaded := JSON.Load(content)
        if (loaded is Array) {
            SearchHistory := loaded
            SearchHistoryIndex := SearchHistory.Length + 1
        }
    } catch {
        return
    }
}

SaveHistory() {
    global historyFile, SearchHistory
    if FileExist(historyFile)
        FileDelete(historyFile)
    FileAppend(JSON.Dump(SearchHistory, "  "), historyFile, "UTF-8")
}

NavigateHistory(direction) {
    global editInput, SearchHistory, SearchHistoryIndex

    if (SearchHistory.Length = 0)
        return

    SearchHistoryIndex += direction

    if (SearchHistoryIndex < 1)
        SearchHistoryIndex := 1

    if (SearchHistoryIndex > SearchHistory.Length) {
        SearchHistoryIndex := SearchHistory.Length + 1
        editInput.Value := ""
        return
    }

    editInput.Value := SearchHistory[SearchHistoryIndex]
}

; ===================== AUTOCOMPLETE =====================
UpdateSuggestions() {
    global editInput, gSearch, gSuggestions, SuggestionsActive
    global ColorBg, ColorBgEdit, ColorText, ColorSub

    text := Trim(editInput.Value)

    if (text = "") {
        CloseSuggestions()
        return
    }

    lower := StrLower(text)

    ; Skip suggestions for special commands
    if (lower = "all" || lower = "create" || SubStr(lower, 1, 7) = "update " || SubStr(lower, 1, 7) = "delete ") {
        CloseSuggestions()
        return
    }

    ; Find matching scripts
    data := LoadData()
    matches := []
    for name, info in data {
        if InStr(StrLower(name), lower)
            matches.Push({name: name, desc: info["description"]})
    }

    if (matches.Length = 0) {
        CloseSuggestions()
        return
    }

    CloseSuggestions()

    gSearch.GetPos(&gx, &gy, &gw, &gh)

    gSuggestions := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" gSearch.Hwnd)
    gSuggestions.BackColor := ColorBg
    gSuggestions.MarginX := 0
    gSuggestions.MarginY := 0

    for i, match in matches {
        if (i > 6)
            break
        row := gSuggestions.Add("Text", "x0 w718 h38 +0x200 Background" ColorBgEdit, "  " match.name)
        row.SetFont("s12 c" ColorText, "Segoe UI")
        capName := match.name
        row.OnEvent("Click", (ctrl, *) => SelectSuggestion(capName))
    }

    gSuggestions.Show("w720 x" gx " y" (gy + gh + 2) " NoActivate")
    SetRoundedCorners(gSuggestions.Hwnd)
    SuggestionsActive := true
}

CloseSuggestions() {
    global gSuggestions, SuggestionsActive
    if (SuggestionsActive && gSuggestions != "") {
        try gSuggestions.Destroy()
        SuggestionsActive := false
        gSuggestions := ""
    }
}

SelectSuggestion(name) {
    global editInput
    editInput.Value := name
    editInput.Focus()
    CloseSuggestions()
    ProcessSearch()
}

; ===================== ACTIONS =====================
CopyScript(name) {
    data := LoadData()
    if data.Has(name) {
        A_Clipboard := data[name]["content"]
        ShowToast("✓ Copied: " name)
    } else {
        ShowToast("✗ Not found: " name)
    }
}

ShowAll() {
    global ColorBg, ColorBgEdit, ColorText

    data := LoadData()
    g := Gui("+AlwaysOnTop", "All Scripts")
    g.BackColor := ColorBg
    g.MarginX := 15
    g.MarginY := 12
    g.OnEvent("Escape", (*) => g.Destroy())

    if (data.Count = 0) {
        g.SetFont("s11 c" ColorText, "Segoe UI")
        g.Add("Text",, "No scripts saved yet.")
    } else {
        g.SetFont("s14 c" ColorText, "Segoe UI")
        lv := g.Add("ListView", "w1000 h600 Background" ColorBgEdit " c" ColorText, ["Name", "Description", "Trigger"])
        lv.SetFont("s14", "Segoe UI")
        for name, info in data {
			trigger := info.Has("trigger") ? info["trigger"] : ""
			lv.Add(, name, info["description"], trigger)
		}
        lv.ModifyCol(1, 150)
        lv.ModifyCol(2, 726)
		lv.ModifyCol(3, 120)
    }

    g.Show("w1030")
    SetDarkTitleBar(g.Hwnd)
}

OpenEditor(mode, name := "") {
    global gEdit, ColorBg, ColorBgEdit, ColorText, ColorSub

    data := LoadData()

    if (mode = "update") {
        if !data.Has(name) {
            ShowToast("✗ Script '" name "' not found")
            return
        }
        currentName    := name
        currentDesc    := data[name]["description"]
        currentContent := data[name]["content"]
		currentTrigger := data[name].Has("trigger") ? data[name]["trigger"] : ""
        title          := "Update Script"
    } else {
        currentName    := ""
        currentDesc    := ""
        currentContent := ""
		currentTrigger := ""
        title          := "Create Script"
    }

    gEdit := Gui("+AlwaysOnTop", title)
    gEdit.BackColor := ColorBg
    gEdit.MarginX := 18
    gEdit.MarginY := 14
    gEdit.OnEvent("Escape", (*) => gEdit.Destroy())

    gEdit.SetFont("s10 c" ColorSub, "Segoe UI")
    gEdit.Add("Text",, "NAME")
    gEdit.SetFont("s12 c" ColorText, "Segoe UI")
    nameEdit := gEdit.Add("Edit", "w450 Background" ColorBgEdit " c" ColorText " -E0x200", currentName)

    gEdit.SetFont("s10 c" ColorSub, "Segoe UI")
    gEdit.Add("Text", "y+10", "DESCRIPTION")
    gEdit.SetFont("s12 c" ColorText, "Segoe UI")
    descEdit := gEdit.Add("Edit", "w450 Background" ColorBgEdit " c" ColorText " -E0x200", currentDesc)

    gEdit.SetFont("s10 c" ColorSub, "Segoe UI")
    gEdit.Add("Text", "y+10", "CONTENT")
    gEdit.SetFont("s11 c" ColorText, "Segoe UI")
    contentEdit := gEdit.Add("Edit", "w450 h220 Multi Background" ColorBgEdit " c" ColorText " -E0x200", currentContent)

    gEdit.SetFont("s10 c" ColorSub, "Segoe UI")
    gEdit.Add("Text", "y+10", "TRIGGER (optional, e.g: @@)")
    gEdit.SetFont("s12 c" ColorText, "Segoe UI")
    triggerEdit := gEdit.Add("Edit", "w450 Background" ColorBgEdit " c" ColorText " -E0x200", currentTrigger)

    btnSave   := gEdit.Add("Button", "w120 y+15", "Save")
    btnCancel := gEdit.Add("Button", "w120 x+10", "Cancel")

    btnSave.OnEvent("Click", (*) => SaveScript(mode, name, nameEdit.Value, descEdit.Value, contentEdit.Value, triggerEdit.Value))
    btnCancel.OnEvent("Click", (*) => gEdit.Destroy())

    gEdit.Show("w486")
    SetDarkTitleBar(gEdit.Hwnd)
    nameEdit.Focus()
}

SaveScript(mode, oldName, newName, desc, content, trigger := "") {
    global gEdit
    newName := Trim(newName)
	trigger := Trim(trigger)
	
    if (newName = "") {
        ShowToast("✗ Name cannot be empty")
        return
    }

    data := LoadData()

    if (mode = "update" && data.Has(oldName)) {
        oldTrigger := data[oldName].Has("trigger") ? data[oldName]["trigger"] : ""
        if (oldTrigger != "")
			UnregisterTrigger(oldTrigger)
        if (oldName != newName)
            data.Delete(oldName)
    }

    entry := Map()
    entry["description"] := desc
    entry["content"]     := content
	entry["trigger"]     := trigger
    data[newName]        := entry

    SaveData(data)
	
	if (trigger != "")
        RegisterTrigger(trigger, content)

    gEdit.Destroy()
    ShowToast("✓ Saved: " newName)
}

DeleteScript(name) {
    data := LoadData()
    if data.Has(name) {
        if (MsgBox("Are you sure you want to delete '" name "'?", "Confirm", "YesNo Icon!") = "Yes") {
            if (data[name].Has("trigger") && data[name]["trigger"] != "")
				UnregisterTrigger(data[name]["trigger"])
			data.Delete(name)
            SaveData(data)
            ShowToast("🗑 Deleted: " name)
        }
    } else {
        ShowToast("✗ Not found: " name)
    }
}

; ===================== TRIGGERS =====================
RegisterTrigger(trigger, content) {
    fn := (hs) => (A_Clipboard := content, Send("^v"))
    Hotstring(":C:" trigger, fn)
}

UnregisterTrigger(trigger) {
    try Hotstring(":C:" trigger, (*) => "", "Off")
}

LoadTriggers() {
    data := LoadData()
    for name, info in data {
        if (info.Has("trigger") && info["trigger"] != "")
            RegisterTrigger(info["trigger"], info["content"])
    }
}

; ===================== DATA =====================
LoadData() {
    global dataFile
    if !FileExist(dataFile)
        return Map()
    try {
        content := FileRead(dataFile, "UTF-8")
        if (Trim(content) = "")
            return Map()
        return JSON.Load(content)
    } catch {
        return Map()
    }
}

SaveData(data) {
    global dataFile
    if FileExist(dataFile)
        FileDelete(dataFile)
    FileAppend(JSON.Dump(data, "  "), dataFile, "UTF-8")
}

; ===================== WINDOWS API =====================
SetDarkTitleBar(hwnd) {
    val := 1
    DllCall("dwmapi\DwmSetWindowAttribute",
        "Ptr", hwnd,
        "UInt", 20,
        "Ptr*", &val,
        "UInt", 4)
}

SetRoundedCorners(hwnd) {
    DllCall("dwmapi\DwmSetWindowAttribute",
        "Ptr", hwnd,
        "UInt", 33,
        "Int*", 2,
        "UInt", 4)
}

; ===================== UI HELPERS =====================
ShowToast(msg) {
    global ColorBg
    g := Gui("+AlwaysOnTop -Caption +ToolWindow")
    g.BackColor := ColorBg
    g.MarginX := 20
    g.MarginY := 12
    g.SetFont("s11 cFFFFFF", "Segoe UI")
    g.Add("Text",, msg)
    screenW := A_ScreenWidth
    screenH := A_ScreenHeight
    g.Show("AutoSize x" (screenW/2 - 100) " y" (screenH - 120) " NoActivate")
    SetTimer(() => g.Destroy(), -1500)
}