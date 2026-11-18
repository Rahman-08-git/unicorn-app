;=====================================================================
;  ScreenSnip - a Win+Shift+S replacement (AutoHotkey v2)
;
;  Win+Shift+S  -> screen freezes, drag to select an area
;                  (single click = whole monitor, Esc / right-click = cancel)
;  Popup        -> Ctrl+C copy   |   Ctrl+S save   |   Esc discard
;  Tray icon    -> Take screenshot, Open folder, Settings, Exit
;
;  Settings are stored in ScreenSnip.ini next to this script.
;=====================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook true
Persistent
DetectHiddenWindows true
CoordMode "Mouse", "Screen"
SetWinDelay -1

; Work in real (physical) pixels on every monitor, whatever its scaling.
DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

;---------------------------------------------------------------------
; Globals
;---------------------------------------------------------------------
global APP         := "ScreenSnip"
global INI         := A_ScriptDir "\ScreenSnip.ini"
global STARTUP_LNK := A_Startup "\ScreenSnip.lnk"

; Dark theme palette
global C := {
    bg:          "1C1C1C",
    surface:     "2A2A2A",
    surface2:    "3A3A3A",
    hover:       "353535",
    text:        "F2F2F2",
    muted:       "9D9D9D",
    accent:      "0A84FF",
    accentHover: "3D9BFF",
    good:        "4CD964",
    danger:      "FF6B6B"
}

global Cfg     := LoadConfig()
global S       := {capturing: false, full: 0, vx: 0, vy: 0, vw: 0, vh: 0
                 , frozen: "", dim: "", border: "", label: "", sizeText: ""
                 , borderShown: false, popup: "", shot: "", settings: ""}
global Buttons := Map()
global hCross  := DllCall("LoadCursor", "ptr", 0, "ptr", 32515, "ptr")  ; IDC_CROSS
global hHand   := DllCall("LoadCursor", "ptr", 0, "ptr", 32649, "ptr")  ; IDC_HAND

; GDI+ (used to write PNG files)
DllCall("LoadLibrary", "str", "gdiplus", "ptr")
global gdipToken := 0
gdipSI := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
NumPut("UInt", 1, gdipSI)
DllCall("gdiplus\GdiplusStartup", "ptr*", &gdipToken, "ptr", gdipSI, "ptr", 0)
OnExit((*) => DllCall("gdiplus\GdiplusShutdown", "ptr", gdipToken))

OnMessage(0x0020, OnSetCursor)    ; WM_SETCURSOR
OnMessage(0x0201, OnLButtonDown)  ; WM_LBUTTONDOWN (drag the popup)

;---------------------------------------------------------------------
; Hotkeys
;---------------------------------------------------------------------
Hotkey "#+s", StartCapture

HotIf (*) => S.capturing
Hotkey "*LButton", DragSelect
Hotkey "*RButton", (*) => EndCapture()
Hotkey "Esc", (*) => EndCapture()
HotIf

HotIf (*) => S.popup && WinActive("ahk_id " S.popup.Hwnd)
Hotkey "^c", DoCopy
Hotkey "^s", DoSave
Hotkey "Esc", (*) => ClosePopup()
HotIf

;---------------------------------------------------------------------
; Tray menu
;---------------------------------------------------------------------
A_IconTip := APP "  ·  Win+Shift+S"
A_TrayMenu.Delete()
A_TrayMenu.Add("Take screenshot", (*) => SetTimer(StartCapture, -250))
A_TrayMenu.Add("Open screenshots folder", OpenFolder)
A_TrayMenu.Add("Settings...", (*) => ShowSettings())
A_TrayMenu.Add()
A_TrayMenu.Add("Exit", (*) => ExitApp())
A_TrayMenu.Default := "Take screenshot"

Toast(APP " is running  ·  Win+Shift+S")
return

;=====================================================================
; Config
;=====================================================================
LoadConfig() {
    cfg := {}
    cfg.dir        := IniRead(INI, "General", "SaveDir", EnvGet("USERPROFILE") "\Pictures\Screenshots")
    cfg.prefix     := IniRead(INI, "General", "FilePrefix", "Screenshot")
    cfg.copyOnSave := Integer(IniRead(INI, "General", "CopyOnSave", "0"))
    cfg.startup    := FileExist(STARTUP_LNK) ? 1 : 0
    return cfg
}

SaveConfig() {
    IniWrite Cfg.dir,        INI, "General", "SaveDir"
    IniWrite Cfg.prefix,     INI, "General", "FilePrefix"
    IniWrite Cfg.copyOnSave, INI, "General", "CopyOnSave"
}

SetStartup(on) {
    try FileDelete STARTUP_LNK
    if !on
        return
    if A_IsCompiled
        FileCreateShortcut A_ScriptFullPath, STARTUP_LNK, A_ScriptDir
    else
        FileCreateShortcut A_AhkPath, STARTUP_LNK, A_ScriptDir, '"' A_ScriptFullPath '"'
}

OpenFolder(*) {
    if !DirExist(Cfg.dir)
        try DirCreate Cfg.dir
    if DirExist(Cfg.dir)
        Run Cfg.dir
}

;=====================================================================
; Capture overlay
;=====================================================================
StartCapture(*) {
    if S.capturing
        return
    ClosePopup()

    ; Freeze the whole virtual desktop (all monitors)
    S.vx := SysGet(76), S.vy := SysGet(77), S.vw := SysGet(78), S.vh := SysGet(79)
    S.full := CaptureRect(S.vx, S.vy, S.vw, S.vh)

    opts := "+AlwaysOnTop -Caption +ToolWindow -DPIScale"

    S.frozen := Gui(opts)
    S.frozen.MarginX := S.frozen.MarginY := 0
    S.frozen.Add("Picture", "x0 y0 w" S.vw " h" S.vh, "HBITMAP:*" S.full)

    S.dim := Gui(opts " +Owner" S.frozen.Hwnd)
    S.dim.BackColor := "000000"
    WinSetTransparent 125, S.dim

    S.border := Gui(opts " +Owner" S.dim.Hwnd)
    S.border.BackColor := C.accent

    S.label := Gui("+AlwaysOnTop -Caption +ToolWindow +Owner" S.border.Hwnd)
    S.label.BackColor := "111111"
    S.label.MarginX := 8, S.label.MarginY := 4
    S.label.SetFont("s9 c" C.text, "Segoe UI")
    S.sizeText := S.label.Add("Text", "w110 Center", "0 × 0")
    S.label.Show("Hide AutoSize")

    pos := "x" S.vx " y" S.vy " w" S.vw " h" S.vh
    S.frozen.Show("NA " pos)
    S.dim.Show("NA " pos)
    WinMove S.vx, S.vy, S.vw, S.vh, S.frozen
    WinMove S.vx, S.vy, S.vw, S.vh, S.dim
    S.borderShown := false
    S.capturing := true
    try WinActivate S.dim
}

DragSelect(*) {
    MouseGetPos &sx, &sy
    lx := sx, ly := sy
    UpdateSel(sx, sy, sx, sy)
    while GetKeyState("LButton", "P") {
        if !S.capturing
            return
        MouseGetPos &mx, &my
        if (mx != lx || my != ly) {
            UpdateSel(sx, sy, mx, my)
            lx := mx, ly := my
        }
        Sleep 8
    }
    if !S.capturing
        return

    MouseGetPos &mx, &my
    x := Min(sx, mx), y := Min(sy, my), w := Abs(mx - sx), h := Abs(my - sy)
    if (w < 5 || h < 5) {           ; plain click -> whole monitor under cursor
        m := MonitorAt(mx, my)
        x := m.l, y := m.t, w := m.r - m.l, h := m.b - m.t
    }
    shot := CropBitmap(S.full, x - S.vx, y - S.vy, w, h)
    EndCapture()
    ShowPopup(shot, x, y, w, h)
}

UpdateSel(x1, y1, x2, y2) {
    try {
        W := S.vw, H := S.vh
        l := Min(x1, x2) - S.vx, t := Min(y1, y2) - S.vy
        r := Max(x1, x2) - S.vx, b := Max(y1, y2) - S.vy

        ; Dim everything except the selection (polygon with a hole)
        WinSetRegion Format("0-0 {1}-0 {1}-{2} 0-{2} 0-0 {3}-{4} {5}-{4} {5}-{6} {3}-{6} {3}-{4}"
            , W, H, l, t, r, b), S.dim

        ; 2px accent ring around the selection
        bw := 2
        WinSetRegion Format("{1}-{2} {3}-{2} {3}-{4} {1}-{4} {1}-{2} {5}-{6} {7}-{6} {7}-{8} {5}-{8} {5}-{6}"
            , l - bw, t - bw, r + bw, b + bw, l, t, r, b), S.border
        if !S.borderShown {
            S.border.Show("NA x" S.vx " y" S.vy " w" W " h" H)
            WinMove S.vx, S.vy, W, H, S.border
            S.borderShown := true
        }

        ; Size label above the selection (or inside it near the top edge)
        S.sizeText.Value := (r - l) " × " (b - t)
        rc := WinRect(S.label.Hwnd)
        lx := S.vx + l
        ly := S.vy + t - rc.h - 6
        if (ly < MonitorAt(S.vx + l, S.vy + t).t)
            ly := S.vy + t + 6
        ShowAt(S.label, lx, ly)
    }
}

EndCapture() {
    S.capturing := false
    for name in ["label", "border", "dim", "frozen"] {
        if S.%name% {
            try S.%name%.Destroy()
            S.%name% := ""
        }
    }
    S.borderShown := false
    if S.full {
        DllCall("DeleteObject", "ptr", S.full)
        S.full := 0
    }
}

;=====================================================================
; Popup (Copy / Save)
;=====================================================================
ShowPopup(hBmp, sx, sy, sw, sh) {
    ClosePopup()
    S.shot := {hBmp: hBmp, w: sw, h: sh}

    p := Gui("+AlwaysOnTop -Caption +ToolWindow", APP)
    p.BackColor := C.bg

    p.SetFont("s10 bold c" C.text, "Segoe UI")
    p.Add("Text", "x16 y12 w160", "Screenshot")
    p.SetFont("s9 norm c" C.muted)
    p.Add("Text", "x176 y13 w110 Right", sw " × " sh)

    ; Thumbnail (high-quality downscale)
    boxW := 270, boxH := 150
    sc := Min(boxW / sw, boxH / sh, 1)
    tw := Max(1, Round(sw * sc)), th := Max(1, Round(sh * sc))
    dpi := A_ScreenDPI / 96
    thumb := ScaleBitmap(hBmp, sw, sh, Max(1, Round(tw * dpi)), Max(1, Round(th * dpi)))
    p.Add("Picture", "x" (16 + (boxW - tw) // 2) " y40 w" tw " h" th, "HBITMAP:*" thumb)
    DllCall("DeleteObject", "ptr", thumb)

    by := 40 + th + 12
    p.SetFont("s10 norm c" C.text)
    AddButton(p, "x16 y" by " w131 h36", "Copy    Ctrl+C", DoCopy)
    AddButton(p, "x155 y" by " w131 h36", "Save    Ctrl+S", DoSave, C.accent, C.accentHover, "FFFFFF")

    fy := by + 36 + 10
    p.SetFont("s8 c" C.muted)
    p.Add("Text", "x16 y" (fy + 4) " w150", "Esc to discard")
    AddButton(p, "x206 y" fy " w80 h22", "Settings", OpenSettingsFromPopup, C.bg, C.hover, C.muted)

    StyleWindow(p.Hwnd)
    p.Show("Hide w302 h" (fy + 34))

    ; Place it next to the selection, kept inside that monitor's work area
    rc := WinRect(p.Hwnd)
    wa := WorkAreaAt(sx + sw // 2, sy + sh // 2)
    px := sx + sw - rc.w
    py := sy + sh + 10
    if (py + rc.h > wa.b - 8)
        py := sy - rc.h - 10
    if (py < wa.t + 8)
        py := wa.b - rc.h - 16
    px := Max(wa.l + 8, Min(px, wa.r - rc.w - 16))

    S.popup := p
    ShowAt(p, px, py, true)
}

OpenSettingsFromPopup(*) {
    ClosePopup()
    SetTimer(ShowSettings, -10)
}

ClosePopup(*) {
    if S.popup {
        try S.popup.Destroy()
        S.popup := ""
    }
    if S.shot {
        DllCall("DeleteObject", "ptr", S.shot.hBmp)
        S.shot := ""
    }
}

DoCopy(*) {
    if !S.shot
        return
    ok := CopyToClipboard(S.shot)
    ClosePopup()
    Toast(ok ? "Copied to clipboard" : "Couldn't access the clipboard", ok)
}

DoSave(*) {
    if !S.shot
        return
    if !DirExist(Cfg.dir) {
        try DirCreate Cfg.dir
        catch {
            Toast("Save folder not available - check Settings", false)
            return
        }
    }
    base := Cfg.dir "\" (Cfg.prefix != "" ? Cfg.prefix "_" : "") FormatTime(, "yyyy-MM-dd_HH-mm-ss")
    path := base ".png", n := 2
    while FileExist(path)
        path := base "_" (n++) ".png"

    if !SavePng(S.shot.hBmp, path) {
        Toast("Couldn't save the screenshot", false)
        return
    }
    if Cfg.copyOnSave
        CopyToClipboard(S.shot)
    ClosePopup()
    SplitPath path, &name
    Toast("Saved  " name, true, (*) => Run('explorer.exe /select,"' path '"'))
}

;=====================================================================
; Settings window
;=====================================================================
ShowSettings(*) {
    if S.settings {
        try {
            WinActivate S.settings
            return
        }
    }
    g := Gui("+AlwaysOnTop -MinimizeBox -MaximizeBox", APP " Settings")
    S.settings := g
    g.BackColor := C.bg
    g.OnEvent("Close", CloseSettings)
    g.OnEvent("Escape", CloseSettings)

    g.SetFont("s14 bold c" C.text, "Segoe UI")
    g.Add("Text", "x20 y14", "Settings")

    ; Save location
    g.SetFont("s8 bold c" C.muted)
    g.Add("Text", "x20 y58", "SAVE LOCATION")
    g.Add("Text", "x20 y78 w312 h34 Background" C.surface)
    g.SetFont("s10 norm c" C.text)
    edDir := g.Add("Edit", "x22 y85 w308 -E0x200 Background" C.surface, Cfg.dir)
    SendMessage 0xD3, 3, (8 << 16) | 8, edDir   ; EM_SETMARGINS
    AddButton(g, "x340 y78 w90 h34", "Browse...", BrowseDir)

    ; File prefix
    g.SetFont("s8 bold c" C.muted)
    g.Add("Text", "x20 y128", "FILE NAME PREFIX")
    g.Add("Text", "x20 y148 w410 h34 Background" C.surface)
    g.SetFont("s10 norm c" C.text)
    edPrefix := g.Add("Edit", "x22 y155 w406 -E0x200 Background" C.surface, Cfg.prefix)
    SendMessage 0xD3, 3, (8 << 16) | 8, edPrefix
    g.SetFont("s8 c" C.muted)
    g.Add("Text", "x20 y186 w410", "Files are named like  Prefix_2026-11-11_14-30-22.png")

    ; Toggles
    g.SetFont("s10 c" C.text)
    tCopy  := AddToggle(g, 20, 218, "Also copy to clipboard when saving", Cfg.copyOnSave)
    tStart := AddToggle(g, 20, 250, "Start with Windows", Cfg.startup)

    ; Footer buttons
    AddButton(g, "x226 y300 w98 h34", "Cancel", CloseSettings)
    AddButton(g, "x332 y300 w98 h34", "Save", SaveSettings, C.accent, C.accentHover, "FFFFFF")

    StyleWindow(g.Hwnd)
    g.Show("w450 h352")

    BrowseDir(*) {
        g.Opt("+OwnDialogs")
        sel := DirSelect("*" edDir.Value, 3, "Choose where screenshots are saved")
        if (sel != "")
            edDir.Value := sel
    }

    SaveSettings(*) {
        dir := RTrim(Trim(edDir.Value), "\")
        if (dir = "") {
            g.Opt("+OwnDialogs")
            MsgBox "Please choose a save location.", APP, "Icon!"
            return
        }
        if !DirExist(dir) {
            try DirCreate dir
            catch {
                g.Opt("+OwnDialogs")
                MsgBox "Couldn't create that folder:`n" dir, APP, "Icon!"
                return
            }
        }
        Cfg.dir        := dir
        Cfg.prefix     := RegExReplace(Trim(edPrefix.Value), '[\\/:*?"<>|]')
        Cfg.copyOnSave := tCopy.value ? 1 : 0
        Cfg.startup    := tStart.value ? 1 : 0
        SaveConfig()
        SetStartup(Cfg.startup)
        CloseSettings()
        Toast("Settings saved")
    }
}

CloseSettings(*) {
    if S.settings {
        try S.settings.Destroy()
        S.settings := ""
    }
}

;=====================================================================
; UI helpers (flat dark buttons, toggles, toasts, window styling)
;=====================================================================
AddButton(g, opts, text, cb, bg := "", hov := "", fg := "") {
    bg  := bg  != "" ? bg  : C.surface
    hov := hov != "" ? hov : C.surface2
    fg  := fg  != "" ? fg  : C.text
    t := g.Add("Text", opts " 0x200 Center Background" bg " c" fg, text)
    t.OnEvent("Click", cb)
    Buttons[t.Hwnd] := {ctrl: t, bg: bg, hov: hov, cur: bg}
    SetTimer(HoverTick, 40)
    return t
}

HoverTick() {
    if !Buttons.Count {
        SetTimer(HoverTick, 0)
        return
    }
    MouseGetPos , , , &hCtl, 2
    for hwnd, b in Buttons.Clone() {
        if !DllCall("IsWindow", "ptr", hwnd) {
            Buttons.Delete(hwnd)
            continue
        }
        want := (hwnd = hCtl) ? b.hov : b.bg
        if (want != b.cur) {
            b.ctrl.Opt("Background" want)
            b.ctrl.Redraw()
            b.cur := want
        }
    }
}

AddToggle(g, x, y, label, init) {
    st := {value: init ? 1 : 0}
    box := g.Add("Text", Format("x{} y{} w20 h20 0x200 Center Background{}", x, y + 2
        , st.value ? C.accent : C.surface2), st.value ? "✓" : "")
    lbl := g.Add("Text", Format("x{} y{} w380", x + 32, y + 2), label)
    flip(*) {
        st.value := !st.value
        box.Opt("Background" (st.value ? C.accent : C.surface2))
        box.Value := st.value ? "✓" : ""
        box.Redraw()
    }
    box.OnEvent("Click", flip)
    lbl.OnEvent("Click", flip)
    return st
}

Toast(msg, ok := true, onClick := "") {
    t := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")  ; WS_EX_NOACTIVATE
    t.BackColor := C.surface
    t.MarginX := 16, t.MarginY := 10
    t.SetFont("s10 bold c" (ok ? C.good : C.danger), "Segoe UI")
    icon := t.Add("Text", "ym", ok ? "✓" : "✕")
    t.SetFont("s10 norm c" C.text)
    txt := t.Add("Text", "x+10 yp", msg)
    ctrls := [icon, txt]
    if onClick {
        t.SetFont("s8 c" C.muted)
        ctrls.Push(t.Add("Text", "xp y+2", "Click to show in folder"))
        for ctl in ctrls
            ctl.OnEvent("Click", (*) => (onClick(), DestroyGui(t)))
    }
    StyleWindow(t.Hwnd)
    t.Show("Hide AutoSize")
    rc := WinRect(t.Hwnd)
    MouseGetPos &mx, &my
    wa := WorkAreaAt(mx, my)
    ShowAt(t, wa.r - rc.w - 16, wa.b - rc.h - 16)
    SetTimer(() => DestroyGui(t), onClick ? -3500 : -1800)
}

DestroyGui(g) {
    try g.Destroy()
}

StyleWindow(hwnd) {
    ; Dark title bar, Win11 rounded corners, subtle border
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 20, "int*", 1, "int", 4)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 33, "int*", 2, "int", 4)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 34, "int*", 0x3A3A3A, "int", 4)
}

ShowAt(g, x, y, activate := false) {
    ; HWND_TOPMOST, SWP_NOSIZE | SWP_SHOWWINDOW (| SWP_NOACTIVATE)
    DllCall("SetWindowPos", "ptr", g.Hwnd, "ptr", -1, "int", x, "int", y, "int", 0, "int", 0
        , "uint", 0x0001 | 0x0040 | (activate ? 0 : 0x0010))
    if activate
        try WinActivate g
}

WinRect(hwnd) {
    rc := Buffer(16, 0)
    DllCall("GetWindowRect", "ptr", hwnd, "ptr", rc)
    l := NumGet(rc, 0, "int"), t := NumGet(rc, 4, "int")
    return {x: l, y: t, w: NumGet(rc, 8, "int") - l, h: NumGet(rc, 12, "int") - t}
}

MonitorAt(x, y) {
    Loop MonitorGetCount() {
        MonitorGet A_Index, &l, &t, &r, &b
        if (x >= l && x < r && y >= t && y < b)
            return {l: l, t: t, r: r, b: b}
    }
    MonitorGet MonitorGetPrimary(), &l, &t, &r, &b
    return {l: l, t: t, r: r, b: b}
}

WorkAreaAt(x, y) {
    Loop MonitorGetCount() {
        MonitorGet A_Index, &l, &t, &r, &b
        if (x >= l && x < r && y >= t && y < b) {
            MonitorGetWorkArea A_Index, &l, &t, &r, &b
            return {l: l, t: t, r: r, b: b}
        }
    }
    MonitorGetWorkArea MonitorGetPrimary(), &l, &t, &r, &b
    return {l: l, t: t, r: r, b: b}
}

OnSetCursor(wParam, *) {
    if S.capturing {
        DllCall("SetCursor", "ptr", hCross)
        return true
    }
    if Buttons.Has(wParam) {
        DllCall("SetCursor", "ptr", hHand)
        return true
    }
}

OnLButtonDown(wParam, lParam, msg, hwnd) {
    ; Let the popup be dragged by its background / labels
    if S.popup && hwnd = S.popup.Hwnd
        PostMessage 0xA1, 2, , , "ahk_id " hwnd   ; WM_NCLBUTTONDOWN, HTCAPTION
}

;=====================================================================
; Bitmap helpers (GDI / GDI+)
;=====================================================================
CaptureRect(x, y, w, h) {
    hdcScreen := DllCall("GetDC", "ptr", 0, "ptr")
    hdcMem    := DllCall("CreateCompatibleDC", "ptr", hdcScreen, "ptr")
    hBmp      := DllCall("CreateCompatibleBitmap", "ptr", hdcScreen, "int", w, "int", h, "ptr")
    old := DllCall("SelectObject", "ptr", hdcMem, "ptr", hBmp, "ptr")
    DllCall("BitBlt", "ptr", hdcMem, "int", 0, "int", 0, "int", w, "int", h
        , "ptr", hdcScreen, "int", x, "int", y, "uint", 0x00CC0020 | 0x40000000) ; SRCCOPY|CAPTUREBLT
    DllCall("SelectObject", "ptr", hdcMem, "ptr", old)
    DllCall("DeleteDC", "ptr", hdcMem)
    DllCall("ReleaseDC", "ptr", 0, "ptr", hdcScreen)
    return hBmp
}

CropBitmap(hSrc, x, y, w, h) {
    return ScaleBitmap(hSrc, w, h, w, h, x, y)
}

ScaleBitmap(hSrc, sw, sh, dw, dh, sx := 0, sy := 0) {
    hdcScreen := DllCall("GetDC", "ptr", 0, "ptr")
    src := DllCall("CreateCompatibleDC", "ptr", hdcScreen, "ptr")
    dst := DllCall("CreateCompatibleDC", "ptr", hdcScreen, "ptr")
    hBmp := DllCall("CreateCompatibleBitmap", "ptr", hdcScreen, "int", dw, "int", dh, "ptr")
    o1 := DllCall("SelectObject", "ptr", src, "ptr", hSrc, "ptr")
    o2 := DllCall("SelectObject", "ptr", dst, "ptr", hBmp, "ptr")
    if (sw = dw && sh = dh) {
        DllCall("BitBlt", "ptr", dst, "int", 0, "int", 0, "int", dw, "int", dh
            , "ptr", src, "int", sx, "int", sy, "uint", 0x00CC0020)
    } else {
        DllCall("SetStretchBltMode", "ptr", dst, "int", 4)  ; HALFTONE
        DllCall("SetBrushOrgEx", "ptr", dst, "int", 0, "int", 0, "ptr", 0)
        DllCall("StretchBlt", "ptr", dst, "int", 0, "int", 0, "int", dw, "int", dh
            , "ptr", src, "int", sx, "int", sy, "int", sw, "int", sh, "uint", 0x00CC0020)
    }
    DllCall("SelectObject", "ptr", src, "ptr", o1)
    DllCall("SelectObject", "ptr", dst, "ptr", o2)
    DllCall("DeleteDC", "ptr", src)
    DllCall("DeleteDC", "ptr", dst)
    DllCall("ReleaseDC", "ptr", 0, "ptr", hdcScreen)
    return hBmp
}

CopyToClipboard(shot) {
    hCopy := CropBitmap(shot.hBmp, 0, 0, shot.w, shot.h)
    Loop 10 {
        if DllCall("OpenClipboard", "ptr", A_ScriptHwnd)
            break
        if (A_Index = 10) {
            DllCall("DeleteObject", "ptr", hCopy)
            return false
        }
        Sleep 30
    }
    DllCall("EmptyClipboard")
    ok := DllCall("SetClipboardData", "uint", 2, "ptr", hCopy, "ptr")  ; CF_BITMAP (Windows converts to DIB)
    DllCall("CloseClipboard")
    if !ok
        DllCall("DeleteObject", "ptr", hCopy)
    return ok != 0
}

SavePng(hBmp, path) {
    pBitmap := 0
    if DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hBmp, "ptr", 0, "ptr*", &pBitmap)
        return false
    clsid := Buffer(16)
    DllCall("ole32\CLSIDFromString", "wstr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "ptr", clsid) ; PNG encoder
    r := DllCall("gdiplus\GdipSaveImageToFile", "ptr", pBitmap, "wstr", path, "ptr", clsid, "ptr", 0)
    DllCall("gdiplus\GdipDisposeImage", "ptr", pBitmap)
    return r = 0
}
