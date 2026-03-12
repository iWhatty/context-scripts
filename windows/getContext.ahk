#Requires AutoHotkey v2.0

; Clipboard restore support:
; If clipboard content already exists, we preserve it before writing context.
; After the user presses Ctrl+V once, we restore the previous clipboard content.
; Note: this only catches keyboard paste (Ctrl+V), not right-click Paste from menus.
#SingleInstance Force
Persistent


SetWorkingDir(A_ScriptDir)

if !A_IsAdmin {
    Run('*RunAs "' . A_ScriptFullPath . '"')
    ExitApp
}



previousClipboard := ""
clipboardRestorePending := false

CONFIG_PATH := A_ScriptDir "\config.ini"
gConfig := LoadConfig(CONFIG_PATH)

try {
    Hotkey(gConfig["hotkey"], RunContextGrabber)
} catch as err {
    MsgBox("Failed to register hotkey '" . gConfig["hotkey"] . "'.`n`n" . err.Message, "get-context", "Iconx")
    ExitApp
}

TrayTip ("get-context`nHotkey: " . gConfig["hotkey"])
return

RunContextGrabber(*) {
    global gConfig, previousClipboard, clipboardRestorePending

    folderPath := GetActiveExplorerPath()
    if !folderPath {
        Notify("Active window is not File Explorer or no folder path was found.")
        return
    }

    if !DirExist(folderPath) {
        Notify("Current Explorer location is not a normal folder.`n`n" folderPath)
        return
    }

    result := CollectFiles(folderPath, gConfig)
    output := BuildContext(folderPath, result["files"], result["skipped"], result["stopReason"])

    wroteClipboard := false
    wroteFile := false
    outputPath := folderPath "\\" gConfig["outputFile"]

    mode := StrLower(gConfig["outputMode"])

    try {
        if (mode = "clipboard" || mode = "both") {
            previousClipboard := HasClipboardTextOrData() ? ClipboardAll() : ""
            clipboardRestorePending := (previousClipboard != "")
            if clipboardRestorePending
                Hotkey("^v", RestoreClipboardAfterPaste, "On")

            A_Clipboard := output
            ClipWait(1)
            wroteClipboard := true
        }
    } catch as err {
        clipboardRestorePending := false
        previousClipboard := ""
        try Hotkey("^v", RestoreClipboardAfterPaste, "Off")
        Notify("Failed to copy context to clipboard.`n`n" err.Message)
        return
    }

    try {
        if (mode = "file" || mode = "both") {
            FileDelete(outputPath)
            FileAppend(output, outputPath, "UTF-8")
            wroteFile := true
        }
    } catch as err {
        Notify("Failed to write output file.`n`n" outputPath "`n`n" err.Message)
        return
    }

    msg := "Context ready: " . result["files"].Length . " file(s)"
    if result["stopReason"]
        msg .= "`n" result["stopReason"]
    if wroteClipboard && wroteFile
        msg .= "`nCopied to clipboard and wrote " . gConfig["outputFile"]
    else if wroteClipboard
        msg .= clipboardRestorePending
            ? "`nCopied to clipboard (previous clipboard will be restored after Ctrl+V)"
            : "`nCopied to clipboard"
    else if wroteFile
        msg .= "`nWrote " . gConfig["outputFile"]

    Notify(msg)
}

LoadConfig(configPath) {
    cfg := Map()

    cfg["hotkey"] := IniReadOrDefault(configPath, "hotkey", "value", "^!c")

    extRaw := IniReadOrDefault(configPath, "extensions", "list", "js,ts,jsx,tsx,py,kt,java,rs,go,cs,html,css,xml,json,md")
    cfg["extensions"] := ParseCsvToSet(extRaw, true)

    ignoreDirsRaw := IniReadOrDefault(configPath, "ignore_dirs", "list", ".git,node_modules,dist,build,out,target,.next,coverage,venv,.venv,__pycache__,.idea,.vscode,.gradle")
    cfg["ignoreDirs"] := ParseCsvToSet(ignoreDirsRaw, false)

    ignoreSuffixesRaw := IniReadOrDefault(configPath, "ignore_suffixes", "list", ".min.js,.map,.lock,.log")
    cfg["ignoreSuffixes"] := ParseCsvToArray(ignoreSuffixesRaw, false)

    cfg["outputMode"] := StrLower(IniReadOrDefault(configPath, "output", "mode", "both"))
    cfg["outputFile"] := IniReadOrDefault(configPath, "output", "output_file", "context.txt")

    recursiveRaw := StrLower(IniReadOrDefault(configPath, "scan", "recursive", "true"))
    cfg["recursive"] := (recursiveRaw = "true" || recursiveRaw = "1" || recursiveRaw = "yes")

    maxFilesRaw := IniReadOrDefault(configPath, "scan", "max_files", "200")
    cfg["maxFiles"] := Integer(maxFilesRaw)
    if (cfg["maxFiles"] < 1)
        cfg["maxFiles"] := 200

    return cfg
}

IniReadOrDefault(path, section, key, defaultValue) {
    try {
        return IniRead(path, section, key, defaultValue)
    } catch {
        return defaultValue
    }
}

ParseCsvToArray(raw, dotPrefix) {
    arr := []
    for part in StrSplit(raw, ",") {
        item := Trim(part)
        if !item
            continue
        if dotPrefix && SubStr(item, 1, 1) != "."
            item := "." item
        arr.Push(item)
    }
    return arr
}

ParseCsvToSet(raw, dotPrefix) {
    set := Map()
    for item in ParseCsvToArray(raw, dotPrefix) {
        set[StrLower(item)] := true
    }
    return set
}

GetActiveExplorerPath() {
    hwnd := WinActive("A")
    if !hwnd
        return ""

    className := WinGetClass("ahk_id " hwnd)
    if (className != "CabinetWClass" && className != "ExploreWClass")
        return ""

    shell := ComObject("Shell.Application")
    for window in shell.Windows {
        try {
            if (window.HWND = hwnd) {
                path := window.Document.Folder.Self.Path
                return path ? path : ""
            }
        } catch {
            continue
        }
    }
    return ""
}

CollectFiles(rootPath, cfg) {
    result := Map()
    result["files"] := []
    result["skipped"] := []
    result["stopReason"] := ""

    WalkFolder(rootPath, rootPath, cfg, result)
    SortByRelativePath(result["files"])
    SortByRelativePath(result["skipped"])
    return result
}

WalkFolder(currentPath, rootPath, cfg, result) {
    if (result["files"].Length >= cfg["maxFiles"]) {
        result["stopReason"] := "Stopped after " . cfg["maxFiles"] . " files."
        return
    }

    loopMode := cfg["recursive"] ? "FD" : "F"
    pattern := cfg["recursive"] ? currentPath . "\*" : currentPath . "\*"

    Loop Files pattern, loopMode {
        if (result["files"].Length >= cfg["maxFiles"]) {
            result["stopReason"] := "Stopped after " . cfg["maxFiles"] . " files."
            return
        }

        if InStr(A_LoopFileAttrib, "D") {
            dirName := A_LoopFileName
            if ShouldSkipDir(dirName, cfg)
                continue

            if cfg["recursive"] {
                WalkFolder(A_LoopFileFullPath, rootPath, cfg, result)
            }
            continue
        }

        fileName := A_LoopFileName
        if ShouldSkipFile(fileName, cfg)
            continue

        ext := GetExtension(fileName)
        if !cfg["extensions"].Has(StrLower(ext))
            continue

        relPath := MakeRelativePath(rootPath, A_LoopFileFullPath)
        content := ReadFileText(A_LoopFileFullPath)

        if (content = "") {
            result["skipped"].Push(Map(
                "relativePath", relPath,
                "reason", "Failed to read file or file was empty"
            ))
            continue
        }

        result["files"].Push(Map(
            "fullPath", A_LoopFileFullPath,
            "relativePath", relPath,
            "ext", ext,
            "content", content
        ))
    }
}

ShouldSkipDir(dirName, cfg) {
    return cfg["ignoreDirs"].Has(StrLower(dirName))
}

ShouldSkipFile(fileName, cfg) {
    lowerName := StrLower(fileName)
    for suffix in cfg["ignoreSuffixes"] {
        if EndsWith(lowerName, StrLower(suffix))
            return true
    }
    return false
}

GetExtension(fileName) {
    SplitPath(fileName, , , &ext)
    return ext ? "." ext : ""
}

ReadFileText(filePath) {
    try {
        return FileRead(filePath, "UTF-8")
    } catch {
        try {
            return FileRead(filePath)
        } catch {
            return ""
        }
    }
}

MakeRelativePath(rootPath, fullPath) {
    rootNorm := NormalizeSlashes(rootPath)
    fullNorm := NormalizeSlashes(fullPath)

    if InStr(fullNorm, rootNorm "\") = 1
        return SubStr(fullNorm, StrLen(rootNorm) + 2)
    if (fullNorm = rootNorm)
        return "."
    return fullNorm
}

NormalizeSlashes(p) {
    return StrReplace(RTrim(p, "\/"), "/", "\")
}

EndsWith(haystack, needle) {
    if (StrLen(needle) > StrLen(haystack))
        return false
    return SubStr(haystack, -StrLen(needle) + 1) = needle
}

BuildContext(rootPath, files, skipped, stopReason) {
    count := files.Length

    out := "# Project Context`r`n`r`n"
    out .= "Root: " . rootPath . "`r`n"
    out .= "Files: " . count . "`r`n`r`n"
    
    if (count = 0) {
        out .= "No matching files found.`r`n"
        if stopReason
            out .= "`r`n" . stopReason . "`r`n"
        return EnsureTrailingNewline(out)
    }
    
    out .= "## File List`r`n"
    for file in files
        out .= "- " . file["relativePath"] . "`r`n"
    
    if (skipped.Length > 0) {
        out .= "`r`n## Skipped`r`n"
        maxSkipped := Min(10, skipped.Length)
        Loop maxSkipped {
            entry := skipped[A_Index]
            out .= "- " . entry["relativePath"] . ": " . entry["reason"] . "`r`n"
        }
        if (skipped.Length > maxSkipped)
            out .= "- ... and " . (skipped.Length - maxSkipped) . " more`r`n"
    }
    
    if stopReason
        out .= "`r`nStop: " . stopReason . "`r`n"
    
    out .= "`r`n---`r`n`r`n"
    
    fence := Chr(96) . Chr(96) . Chr(96)

    for file in files {
        lang := FenceLanguage(file["ext"])
        out .= "## File: " . file["relativePath"] . "`r`n`r`n"
        out .= fence . lang . "`r`n"
        out .= file["content"]
        if !EndsWith(file["content"], "`n")
            out .= "`r`n"
        out .= fence . "`r`n`r`n"
    }

    return EnsureTrailingNewline(out)
}

FenceLanguage(ext) {
    static langMap := ""

    if !IsObject(langMap) {
        langMap := Map(
            ".js", "js",
            ".ts", "ts",
            ".jsx", "jsx",
            ".tsx", "tsx",
            ".py", "python",
            ".kt", "kotlin",
            ".java", "java",
            ".rs", "rust",
            ".go", "go",
            ".cs", "csharp",
            ".html", "html",
            ".css", "css",
            ".xml", "xml",
            ".json", "json",
            ".md", "markdown"
        )
    }

    lowerExt := StrLower(ext)
    return langMap.Has(lowerExt) ? langMap[lowerExt] : ""
}

EnsureTrailingNewline(text) {
    return EndsWith(text, "`n") ? text : text "`r`n"
}

SortByRelativePath(arr) {
    if (arr.Length < 2)
        return

    loop (arr.Length - 1) {
        swapped := false
        loop (arr.Length - A_Index) {
            i := A_Index
            a := arr[i]
            b := arr[i + 1]
            if (StrCompare(StrLower(a["relativePath"]), StrLower(b["relativePath"])) > 0) {
                arr[i] := b
                arr[i + 1] := a
                swapped := true
            }
        }
        if !swapped
            break
    }
}

HasClipboardTextOrData() {
    static probe := Map()
    try {
        probe := ClipboardAll()
        return probe.Size > 0
    } catch {
        return false
    }
}

RestoreClipboardAfterPaste(*) {
    global previousClipboard, clipboardRestorePending

    Hotkey("^v", RestoreClipboardAfterPaste, "Off")

    Send("^v")
    Sleep(150)

    if clipboardRestorePending {
        try A_Clipboard := previousClipboard
    }

    previousClipboard := ""
    clipboardRestorePending := false
}

Notify(message) {
    TrayTip("get-context", message, 2)
}
