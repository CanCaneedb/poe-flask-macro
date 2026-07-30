#Requires AutoHotkey v2.0
#SingleInstance Force

; === 自动请求管理员权限 ===
if not A_IsAdmin {
    try {
        Run '*RunAs "' . A_ScriptFullPath . '"'
    }
    ExitApp
}
; ==========================

CoordMode("Pixel", "Client") 
CoordMode("Mouse", "Client")

; ==========================================
; 全局变量与核心环境
; ==========================================
SetTitleMatchMode("RegEx")
global AppTitle := "药剂大师 v3.2.1"
global ConfigFile := A_ScriptDir . "\config.ini"
global GameExe := "ahk_exe i)PathOfExile.*\.exe"

global IsRunning := false
global RunningConfig := []           
global LastTriggers := [0, 0, 0, 0, 0] 
global GroupMemory := Map("1", 0, "2", 0) 

global LastMPThresholdTrigger := 0
global LastHPTriggerSlot := 0

; 顶部状态显示 GUI
global TopStatusGui := ""

global ColorHP := 0xA2101A
global ColorMP := 0x116AB2
global ColorBar := 0xF9D799    
global ColorTolerance := 30    
global BrightnessThresh := 50  

global TriggerKey := IniRead(ConfigFile, "KeyLink", "TriggerKey", "A")
global LinkKey := IniRead(ConfigFile, "KeyLink", "LinkKey", "B")
global LinkDelay := Integer(IniRead(ConfigFile, "KeyLink", "LinkDelay", "50"))

global CustomHotkey := IniRead(ConfigFile, "CustomLoop", "Hotkey", "F7")
global CustomInterval := IniRead(ConfigFile, "CustomLoop", "Interval", "10000")
global CustomEnabled := IniRead(ConfigFile, "CustomLoop", "Enabled", 0)

global isCapturing := false
global captureKeyBtn := ""
global captureKeyType := ""
global captureDefaultKey := ""

global ResDB := Map(
    "1", Map( 
        "HP", {x: 89, y: 948},
        "MP", {x: 1800, y: 975},
        "Slot", Map( 
            1, {barX: 313, barY: 1075, chgX: 325, chgY: 1057},
            2, {barX: 359, barY: 1075, chgX: 373, chgY: 1057},
            3, {barX: 405, barY: 1075, chgX: 420, chgY: 1057},
            4, {barX: 451, barY: 1075, chgX: 466, chgY: 1057},
            5, {barX: 496, barY: 1075, chgX: 512, chgY: 1057}
        )
    ),
    "2", Map( 
        "HP", {x: 80, y: 784},
        "MP", {x: 1499, y: 804},
        "Slot", Map(
            1, {barX: 261, barY: 895, chgX: 274, chgY: 882},
            2, {barX: 299, barY: 895, chgX: 312, chgY: 882},
            3, {barX: 337, barY: 895, chgX: 351, chgY: 882},
            4, {barX: 376, barY: 895, chgX: 389, chgY: 882},
            5, {barX: 414, barY: 895, chgX: 427, chgY: 882}
        )
    ),
    "3", Map( 
        "HP", {x: 0, y: 0},
        "MP", {x: 0, y: 0},
        "Slot", Map(
            1, {barX: 0, barY: 0, chgX: 0, chgY: 0},
            2, {barX: 0, barY: 0, chgX: 0, chgY: 0},
            3, {barX: 0, barY: 0, chgX: 0, chgY: 0},
            4, {barX: 0, barY: 0, chgX: 0, chgY: 0},
            5, {barX: 0, barY: 0, chgX: 0, chgY: 0}
        )
    )
    ,"4", Map(
        "HP", {x: 119, y: 1264},
        "MP", {x: 2400, y: 1300},
        "Slot", Map(
            1, {barX: 417, barY: 1434, chgX: 433, chgY: 1409},
            2, {barX: 478, barY: 1434, chgX: 497, chgY: 1409},
            3, {barX: 540, barY: 1434, chgX: 560, chgY: 1409},
            4, {barX: 601, barY: 1434, chgX: 621, chgY: 1409},
            5, {barX: 659, barY: 1434, chgX: 683, chgY: 1409}
        )
    )
)


; ========== 按键捕获与热键注册模块 ===========
; 通用按键捕获函数
CaptureKey(btnObj, keyType, defaultKey) {
    global isCapturing, captureKeyBtn, captureKeyType, captureDefaultKey
    if isCapturing
        return
    KeyWait("LButton")
    isCapturing := true
    captureKeyBtn := btnObj
    captureKeyType := keyType
    captureDefaultKey := defaultKey
    btnObj.Text := "请按下按键 (ESC 取消)"
    SetTimer(WatchKeyInput, 20)
}

WatchKeyInput() {
    global isCapturing, captureKeyBtn, captureKeyType, captureDefaultKey
    if !isCapturing {
        SetTimer(WatchKeyInput, 0)
        return
    }
    if GetKeyState("Escape", "P") {
        EndCaptureKey(captureKeyBtn, captureKeyType, captureDefaultKey)
        return
    }
    keyList := GetAllValidKeys()
    for key in keyList {
        if GetKeyState(key, "P") {
            EndCaptureKey(captureKeyBtn, captureKeyType, key)
            return
        }
    }
}

EndCaptureKey(btnObj, keyType, newKey) {
    global isCapturing, ConfigFile, TriggerKey, LinkKey, CustomHotkey
    KeyWait(newKey, "U")
    isCapturing := false
    SetTimer(WatchKeyInput, 0)
    if (newKey = "")
        newKey := keyType = "Trigger" ? TriggerKey : (keyType = "Link" ? LinkKey : CustomHotkey)
    if (keyType = "Trigger") {
        try Hotkey("~" . GetHotkeyName(TriggerKey), "Off")
        try Hotkey("~" . GetHotkeyName(newKey), OnTriggerKeyPress, "On")
        TriggerKey := newKey
        IniWrite(TriggerKey, ConfigFile, "KeyLink", "TriggerKey")
    } else if (keyType = "Link") {
        LinkKey := newKey
        IniWrite(LinkKey, ConfigFile, "KeyLink", "LinkKey")
    } else if (keyType = "Custom") {
        CustomHotkey := newKey
        IniWrite(CustomHotkey, ConfigFile, "CustomLoop", "Hotkey")
    }
    btnObj.Text := newKey = "Space" ? "空格" : newKey
}

GetAllValidKeys() {
    keyList := ["MButton", "XButton1", "XButton2", "WheelUp", "WheelDown", "Space", "Enter", "Tab", "BackSpace", "Delete", "Insert", "Home", "End", "PgUp", "PgDn", "Up", "Down", "Left", "Right", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12"]
    Loop 26
        keyList.Push(Chr(A_Index + 96))
    Loop 10
        keyList.Push(String(A_Index - 1))
    Loop 10
        keyList.Push("Numpad" . (A_Index - 1))
    numpadSymbols := ["NumpadDot", "NumpadDiv", "NumpadMult", "NumpadAdd", "NumpadSub", "NumpadEnter"]
    for symbol in numpadSymbols
        keyList.Push(symbol)
    punctuation := ["`[", "`]", "`;", "'", "\", ",", ".", "/", "-", "="]
    for p in punctuation
        keyList.Push(p)
    return keyList
}

GetHotkeyName(key) {
    specialKeys := Map("Space", "Space", "Enter", "Enter", "Tab", "Tab", "BackSpace", "BackSpace", "Delete", "Delete", "Insert", "Insert", "Home", "Home", "End", "End", "PgUp", "PgUp", "PgDn", "PgDn", "Up", "Up", "Down", "Down", "Left", "Left", "Right", "Right")
    if specialKeys.Has(key)
        return specialKeys[key]
    return key
}

; ==========================================
; 初始化与 UI 构建
; ==========================================
global StrategyList := ["⏹️ 关闭", "❤️ A. 生命阈值触发", "💧 B. 法力阈值触发", "⏱️ C. 固定周期触发", "👁️ D. 状态检测 (自动)", "🔄 E. 编组轮换 (无缝)"]
global SlotCtrls := Map()
Loop 5
    SlotCtrls[A_Index] := Map("Strategy", [], "Health", [], "HealthCooldown", [], "Mana", [], "Periodic", [], "GroupOnly", [], "CustomCoord", [])

global SavedSettings := Map()
global GlobalStartHotkey := "F6"

Init() {
    LoadSavedSettings()
    RegisterStartHotkey()
    BuildMainGui()
    RegisterTriggerHotkey(false)
}

LoadSavedSettings() {
    global SavedSettings, ConfigFile
    SavedSettings["Res"] := IniRead(ConfigFile, "Global", "Resolution", 1)
    SavedSettings["StartHotkey"] := IniRead(ConfigFile, "Global", "StartHotkey", "F6")
    SavedSettings["CustomHotkey"] := IniRead(ConfigFile, "CustomLoop", "Hotkey", "F7")
    SavedSettings["CustomInterval"] := IniRead(ConfigFile, "CustomLoop", "Interval", "10000")
    SavedSettings["CustomEnabled"] := IniRead(ConfigFile, "CustomLoop", "Enabled", 0)
    SavedSettings["LinkDelay"] := IniRead(ConfigFile, "KeyLink", "LinkDelay", "50")
    Loop 5 {
        SavedSettings["Strategy" . A_Index] := IniRead(ConfigFile, "Slot" . A_Index, "Strategy", 1)
        SavedSettings["Interval" . A_Index] := IniRead(ConfigFile, "Slot" . A_Index, "Interval", "5000")
        SavedSettings["Group" . A_Index] := IniRead(ConfigFile, "Slot" . A_Index, "Group", 1)
        SavedSettings["HPCooldown" . A_Index] := IniRead(ConfigFile, "Slot" . A_Index, "HPCooldown", "2000")
    }
}

RegisterStartHotkey() {
    global GlobalStartHotkey, SavedSettings
    GlobalStartHotkey := SavedSettings["StartHotkey"]
    try {
        Hotkey(GetHotkeyName(GlobalStartHotkey), ToggleEngine)
    } catch {
        GlobalStartHotkey := "F6"
        Hotkey(GetHotkeyName(GlobalStartHotkey), ToggleEngine)
    }
}

RegisterTriggerHotkey(enable := true) {
    global TriggerKey
    try {
        Hotkey("~" . GetHotkeyName(TriggerKey), OnTriggerKeyPress, enable ? "On" : "Off")
    } catch {
        ; ignore
    }
}

BuildMainGui() {
    global MainGui, UIStatusText, UIBtnToggle, ResDDL, UIHotkeyBtn, TriggerKeyBtn, LinkKeyBtn, CustomHotkeyBtn, CustomIntervalEdit, CustomEnabledCB, LinkDelayEdit
    MainGui := Gui("+Theme", AppTitle)
    if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
        DllCall("dwmapi\DwmSetWindowAttribute", "ptr", MainGui.hwnd, "int", 19, "int*", 1, "int", 4) ||
        DllCall("dwmapi\DwmSetWindowAttribute", "ptr", MainGui.hwnd, "int", 20, "int*", 1, "int", 4)
    }
    MainGui.BackColor := "0x18181B"
    MainGui.SetFont("s10 cWhite", "Microsoft YaHei UI")
    MainGui.OnEvent("Close", (*) => ExitApp())
    MainGui.OnEvent("Size", OnGuiSize)

    InitTrayMenu()

    ; 顶部控制卡片
    MainGui.Add("Text", "x15 y15 w600 h85 Background27272A")
    MainGui.SetFont("s12 bold")
    UIStatusText := MainGui.Add("Text", "x30 y45 w130 c00A2FF Background27272A", "状态：已停止 ⏸️")

    MainGui.SetFont("s10 bold")
    UIBtnToggle := MainGui.Add("Button", "x165 y37 w200 h40", "▶ 启动 (" . FormatHotkeyUI(GlobalStartHotkey) . ")")
    UIBtnToggle.OnEvent("Click", ToggleEngine)

    MainGui.SetFont("s10 norm")
    MainGui.Add("Text", "x385 y30 cWhite Background27272A", "🖥️ 分辨率:")
    ResDDL := MainGui.Add("DropDownList", "x465 y26 w135 vResDDL +AltSubmit Choose" . SavedSettings["Res"], ["1920x1080(全屏)", "1600x900(窗口)", "自定义分辨率", "2560x1440(2K)"])
    ResDDL.OnEvent("Change", OnResChange)

    MainGui.Add("Text", "x385 y64 cWhite Background27272A", "⌨️ 快捷键:")
    UIHotkeyBtn := MainGui.Add("Button", "x465 y60 w135 h25", FormatHotkeyUI(GlobalStartHotkey))
    UIHotkeyBtn.OnEvent("Click", StartCapture)

    ; 自定义循环触发设置
    MainGui.Add("Text", "x15 y105 w600 h60 Background27272A")
    MainGui.SetFont("s11 bold")
    MainGui.Add("Text", "x30 y120 w150 cWhite Background27272A", "🔄 自定义循环触发")
    MainGui.SetFont("s10 norm")
    MainGui.Add("Text", "x190 y120 w80 cWhite Background27272A", "快捷键:")
    CustomHotkeyBtn := MainGui.Add("Button", "x270 y118 w100 h25", CustomHotkey == "Space" ? "空格" : CustomHotkey)
    CustomHotkeyBtn.OnEvent("Click", StartCaptureCustomHotkey)

    MainGui.Add("Text", "x390 y120 w80 cWhite Background27272A", "间隔 (ms):")
    CustomIntervalEdit := MainGui.Add("Edit", "x470 y118 w100 h25 Background333333 cWhite vCustomInterval", SavedSettings["CustomInterval"])

    CustomEnabledCB := MainGui.Add("CheckBox", "x30 y145 w150 cWhite Background27272A vCustomEnabled Checked" . SavedSettings["CustomEnabled"], "启用循环触发")

    ; 按键联动设置
    MainGui.Add("Text", "x15 y170 w600 h50 Background27272A")
    MainGui.SetFont("s11 bold")
    MainGui.Add("Text", "x30 y185 w120 cWhite Background27272A", "🔗 按键联动设置")
    MainGui.SetFont("s10 norm")
    MainGui.Add("Text", "x160 y185 w80 cWhite Background27272A", "触发键:")
    TriggerKeyBtn := MainGui.Add("Button", "x240 y183 w100 h25", TriggerKey == "Space" ? "空格" : TriggerKey)
    TriggerKeyBtn.OnEvent("Click", StartCaptureTriggerKey)

    MainGui.Add("Text", "x360 y185 w80 cWhite Background27272A", "联动键:")
    LinkKeyBtn := MainGui.Add("Button", "x440 y183 w100 h25", LinkKey == "Space" ? "空格" : LinkKey)
    LinkKeyBtn.OnEvent("Click", StartCaptureLinkKey)

    MainGui.Add("Text", "x160 y205 w80 cWhite Background27272A", "延迟 (ms):")
    LinkDelayEdit := MainGui.Add("Edit", "x240 y203 w80 h25 Background333333 cWhite vLinkDelay", SavedSettings["LinkDelay"])
    MainGui.Add("Text", "x330 y205 w230 cGray Background27272A", "正值：联动键先，负值：触发键先")

    ; 槽位设置
    Loop 5 {
        idx := A_Index
        rowY := 230 + (idx - 1) * 60
        MainGui.Add("Text", "x15 y" . rowY . " w600 h50 Background27272A")
        MainGui.SetFont("s11 bold")
        MainGui.Add("Text", "x30 y" . (rowY + 15) . " w70 cWhite Background27272A", "🧪 槽位 " . idx)
        MainGui.SetFont("s10 norm")
        ddl := MainGui.Add("DropDownList", "x100 y" . (rowY + 12) . " w170 vStrategy" . idx . " +AltSubmit Choose" . SavedSettings["Strategy" . idx], StrategyList)
        SlotCtrls[idx]["Strategy"] := ddl
        BuildRowDynamicUI(MainGui, idx, rowY)
        ddl.OnEvent("Change", SwitchStrategyUI.Bind(idx))
        SwitchStrategyUI(idx, ddl)
    }

    MainGui.Show("w630 h540")
    OnResChange(ResDDL)
}

InitTrayMenu() {
    global TrayStatusText, TrayToggleText
    TrayStatusText := "当前状态：已停止 ⏸️"
    TrayToggleText := "▶ 启动托管 (" . FormatHotkeyUI(GlobalStartHotkey) . ")"
    A_TrayMenu.Delete()
    A_TrayMenu.Add(TrayStatusText, (*) => "")
    A_TrayMenu.Disable(TrayStatusText)
    A_TrayMenu.Add()
    A_TrayMenu.Add(TrayToggleText, ToggleEngine)
    A_TrayMenu.Add()
    A_TrayMenu.Add("显示主界面", RestoreGui)
    A_TrayMenu.Default := "显示主界面"
    A_TrayMenu.ClickCount := 1
    A_TrayMenu.Add("彻底退出程序", (*) => ExitApp())
}

RestoreGui(*) {
    MainGui.Restore()
    MainGui.Show()
}

OnGuiSize(guiObj, MinMax, Width, Height) {
    if (MinMax == -1)
        guiObj.Hide()
}

StartCapture(*) {
    global isCapturing, UIHotkeyBtn
    if isCapturing
        return
    KeyWait("LButton")
    isCapturing := true
    UIHotkeyBtn.Text := "请按下按键 (ESC 取消)"
    SetTimer(WatchHotkeyInput, 20)
}

StartCaptureTriggerKey(*) {
    CaptureKey(TriggerKeyBtn, "Trigger", TriggerKey)
}

StartCaptureLinkKey(*) {
    CaptureKey(LinkKeyBtn, "Link", LinkKey)
}

StartCaptureCustomHotkey(*) {
    CaptureKey(CustomHotkeyBtn, "Custom", CustomHotkey)
}

WatchHotkeyInput() {
    global isCapturing, GlobalStartHotkey
    if !isCapturing {
        SetTimer(WatchHotkeyInput, 0)
        return
    }
    if GetKeyState("Escape", "P") {
        EndCapture(GlobalStartHotkey)
        return
    }
    keyList := GetAllValidKeys()
    for key in keyList {
        if GetKeyState(key, "P") {
            EndCapture(key)
            return
        }
    }
}

EndCapture(newKey) {
    global isCapturing, UIHotkeyBtn, GlobalStartHotkey, ConfigFile
    isCapturing := false
    SetTimer(WatchHotkeyInput, 0)
    if (newKey = "")
        newKey := GlobalStartHotkey
    try {
        if (GlobalStartHotkey != "")
            try Hotkey(GetHotkeyName(GlobalStartHotkey), "Off")
        Hotkey(GetHotkeyName(newKey), ToggleEngine)
        Hotkey(GetHotkeyName(newKey), "On")
        GlobalStartHotkey := newKey
        IniWrite(GlobalStartHotkey, ConfigFile, "Global", "StartHotkey")
    } catch {
        MsgBox("无效的快捷键组合，已恢复默认 (F6)。", "错误", "Iconx")
        GlobalStartHotkey := "F6"
        try Hotkey(GetHotkeyName(GlobalStartHotkey), ToggleEngine, "On")
        IniWrite(GlobalStartHotkey, ConfigFile, "Global", "StartHotkey")
    }
    UIHotkeyBtn.Text := FormatHotkeyUI(GlobalStartHotkey)
    UpdateUIHotkeyText()
}
FormatHotkeyUI(hk) {
    if !hk
        return "无"
    res := StrUpper(hk)
    res := StrReplace(res, "^", "Ctrl + ")
    res := StrReplace(res, "!", "Alt + ")
    res := StrReplace(res, "+", "Shift + ")
    res := StrReplace(res, "SPACE", "空格")
    return res
}

UpdateUIHotkeyText() {
    global UIBtnToggle, GlobalStartHotkey, TrayToggleText, IsRunning
    display := FormatHotkeyUI(GlobalStartHotkey)
    oldTrayText := TrayToggleText
    if (IsRunning) {
        UIBtnToggle.Text := "⏹ 停止 (" . display . ")"
        TrayToggleText := "⏹ 停止托管 (" . display . ")"
    } else {
        UIBtnToggle.Text := "▶ 启动 (" . display . ")"
        TrayToggleText := "▶ 启动托管 (" . display . ")"
    }
    try A_TrayMenu.Rename(oldTrayText, TrayToggleText)
}

BuildRowDynamicUI(guiObj, idx, baseY) {
    global SlotCtrls, SavedSettings
    ctrlY := baseY + 12
    labelX := 290
    labelW := 90
    inputX := 390
    inputW := 130
    hlth := SlotCtrls[idx]["Health"]
    hlth.Push(guiObj.Add("Text", "x" . labelX . " y" . (ctrlY+3) . " w" . (labelW + inputW) . " cWhite Background27272A", "❤️ 固定 60% 触发"))
    hc := SlotCtrls[idx]["HealthCooldown"]
    hc.Push(guiObj.Add("Text", "x" . labelX . " y" . (ctrlY+3) . " w" . labelW . " Right cWhite Background27272A", "⏳ 冷却 (ms):"))
    hc.Push(guiObj.Add("Edit", "x" . inputX . " y" . ctrlY . " w" . inputW . " Background333333 cWhite vHPCooldown" . idx, SavedSettings["HPCooldown" . idx]))
    mana := SlotCtrls[idx]["Mana"]
    mana.Push(guiObj.Add("Text", "x" . labelX . " y" . (ctrlY+3) . " w" . (labelW + inputW) . " cWhite Background27272A", "💧 固定 50% 触发，2 秒内置 CD"))
    pt := SlotCtrls[idx]["Periodic"]
    pt.Push(guiObj.Add("Text", "x" . labelX . " y" . (ctrlY+3) . " w" . labelW . " Right cWhite Background27272A", "⏱️ 间隔 (毫秒):"))
    pt.Push(guiObj.Add("Edit", "x" . inputX . " y" . ctrlY . " w" . inputW . " Background333333 cWhite vInterval" . idx, SavedSettings["Interval" . idx]))
    go := SlotCtrls[idx]["GroupOnly"]
    go.Push(guiObj.Add("Text", "x" . labelX . " y" . (ctrlY+3) . " w" . labelW . " Right cWhite Background27272A", "🔗 编组分配:"))
    go.Push(guiObj.Add("DropDownList", "x" . inputX . " y" . ctrlY . " w" . inputW . " vGroup" . idx . " +AltSubmit Choose" . SavedSettings["Group" . idx], ["A", "B"]))
}

SwitchStrategyUI(idx, ctrlObj, *) {
    global SlotCtrls
    selText := ctrlObj.Text
    for groupName, ctrlArray in SlotCtrls[idx] {
        if (groupName != "CustomCoord" && groupName != "Strategy")
            for ctrl in ctrlArray
                ctrl.Visible := false
    }
    if InStr(selText, "生命") {
        ShowGroup(idx, "Health")
        ShowGroup(idx, "HealthCooldown")
    } else if InStr(selText, "法力")
        ShowGroup(idx, "Mana")
    else if InStr(selText, "固定周期")
        ShowGroup(idx, "Periodic")
    else if InStr(selText, "编组轮换")
        ShowGroup(idx, "GroupOnly")
}

OnResChange(ctrlObj, *) {
    ; 目前仅保存设置以供下一次启动使用
}

ShowGroup(idx, groupName) {
    for ctrl in SlotCtrls[idx][groupName]
        ctrl.Visible := true
}

AutoSaveConfig() {
    global MainGui, ConfigFile, TriggerKey, LinkKey, CustomHotkey, LinkDelay
    savedObj := MainGui.Submit(false)
    IniWrite(savedObj.ResDDL, ConfigFile, "Global", "Resolution")
    IniWrite(savedObj.CustomInterval, ConfigFile, "CustomLoop", "Interval")
    IniWrite(savedObj.CustomEnabled ? 1 : 0, ConfigFile, "CustomLoop", "Enabled")
    IniWrite(LinkDelay, ConfigFile, "KeyLink", "LinkDelay")
    Loop 5 {
        propName := "Strategy" . A_Index
        IniWrite(savedObj.%propName%, ConfigFile, "Slot" . A_Index, "Strategy")
        propName := "Interval" . A_Index
        IniWrite(savedObj.%propName%, ConfigFile, "Slot" . A_Index, "Interval")
        propName := "Group" . A_Index
        IniWrite(savedObj.%propName%, ConfigFile, "Slot" . A_Index, "Group")
        propName := "HPCooldown" . A_Index
        IniWrite(savedObj.%propName%, ConfigFile, "Slot" . A_Index, "HPCooldown")
    }
    IniWrite(TriggerKey, ConfigFile, "KeyLink", "TriggerKey")
    IniWrite(LinkKey, ConfigFile, "KeyLink", "LinkKey")
    IniWrite(CustomHotkey, ConfigFile, "CustomLoop", "Hotkey")
}

SetControlsEnabled(state) {
    global ResDDL, UIHotkeyBtn, SlotCtrls, TriggerKeyBtn, LinkKeyBtn, CustomHotkeyBtn, CustomIntervalEdit, CustomEnabledCB, LinkDelayEdit
    ResDDL.Enabled := state
    UIHotkeyBtn.Enabled := state
    TriggerKeyBtn.Enabled := state
    LinkKeyBtn.Enabled := state
    CustomHotkeyBtn.Enabled := state
    CustomIntervalEdit.Enabled := state
    CustomEnabledCB.Enabled := state
    LinkDelayEdit.Enabled := state
    Loop 5 {
        idx := A_Index
        if SlotCtrls[idx].Has("Strategy")
            SlotCtrls[idx]["Strategy"].Enabled := state
        for groupName, ctrlArray in SlotCtrls[idx] {
            if (groupName = "Strategy")
                continue
            if IsObject(ctrlArray)
                for ctrl in ctrlArray
                    ctrl.Enabled := state
        }
    }
}

ToggleEngine(*) {
    global IsRunning, UIStatusText, UIBtnToggle, GlobalStartHotkey, TrayStatusText, TrayToggleText, TriggerKey, CustomEnabled, CustomInterval, LinkDelay, TopStatusGui
    IsRunning := !IsRunning
    display := FormatHotkeyUI(GlobalStartHotkey)
    if (IsRunning) {
        if !WinExist(GameExe) {
            MsgBox("未检测到游戏进程，请确认游戏正在运行！", "警告")
            IsRunning := false
            return
        }
        SetControlsEnabled(false)
        AutoSaveConfig()
        ParseRunningConfig()
        RegisterTriggerHotkey(true)
        form := MainGui.Submit(false)
        CustomEnabled := form.CustomEnabled
        try {
            CustomInterval := Integer(form.CustomInterval)
        } catch {
            CustomInterval := 10000
        }
        try {
            LinkDelay := Integer(form.LinkDelay)
        } catch {
            LinkDelay := 50
        }
        ; 创建顶部状态显示
        TopStatusGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "TopStatus")
        TopStatusGui.BackColor := "27272A"
        TopStatusGui.SetFont("s5 bold c00FF00", "Microsoft YaHei UI")
        TopStatusGui.Add("Text", "x10 y5 w300", "🟢 药剂大师运行中")
        TopStatusGui.Show("xCenter y0 NoActivate")
        if (CustomEnabled && CustomInterval > 0) {
            SetTimer(CustomLoop, CustomInterval)
        }
        UIStatusText.Value := "状态：运行中 🟢"
        UIStatusText.SetFont("c00FF00")
        UIBtnToggle.Text := "⏹ 停止 (" . display . ")"
        A_TrayMenu.Rename(TrayStatusText, "当前状态：运行中 🟢")
        TrayStatusText := "当前状态：运行中 🟢"
        A_TrayMenu.Rename(TrayToggleText, "⏹ 停止托管 (" . display . ")")
        TrayToggleText := "⏹ 停止托管 (" . display . ")"
        SetTimer(EngineLoop, 100)
    } else {
        SetControlsEnabled(true)
        SetTimer(EngineLoop, 0)
        SetTimer(CustomLoop, 0)
        RegisterTriggerHotkey(false)
        ; 销毁顶部状态显示
        if (TopStatusGui) {
            TopStatusGui.Destroy()
            TopStatusGui := ""
        }
        UIStatusText.Value := "状态：已停止 ⏸️"
        UIStatusText.SetFont("c00A2FF")
        UIBtnToggle.Text := "▶ 启动 (" . display . ")"
        A_TrayMenu.Rename(TrayStatusText, "当前状态：已停止 ⏸️")
        TrayStatusText := "当前状态：已停止 ⏸️"
        A_TrayMenu.Rename(TrayToggleText, "▶ 启动托管 (" . display . ")")
        TrayToggleText := "▶ 启动托管 (" . display . ")"
    }
}

OnTriggerKeyPress(*) {
    global LinkKey, LinkDelay, GameExe, TriggerKey, LinkDelayEdit
    if !WinActive(GameExe)
        return
    
    ; 每次触发时直接从编辑框获取最新延迟值
    try {
        currentDelay := Integer(LinkDelayEdit.Value)
    } catch {
        currentDelay := LinkDelay
    }
    
    ExecuteLinkAction(currentDelay)
}

; 执行联动动作（支持负延迟）
ExecuteLinkAction(delay) {
    global LinkKey, TriggerKey
    
    sendLinkKey := LinkKey = "Space" ? "{Space}" : "{" . LinkKey . "}"
    sendTriggerKey := TriggerKey = "Space" ? "{Space}" : "{" . TriggerKey . "}"
    
    if (delay >= 0) {
        ; 正值：先触发联动键，延迟后再触发触发键
        Send(sendLinkKey)
        Sleep(Abs(delay))
        Send(sendTriggerKey)
    } else {
        ; 负值：先触发触发键，延迟后再触发联动键
        Send(sendTriggerKey)
        Sleep(Abs(delay))
        Send(sendLinkKey)
    }
}

ParseRunningConfig() {
    global MainGui, RunningConfig, ResDB
    RunningConfig := []
    form := MainGui.Submit(false)
    resKey := String(form.ResDDL)
    Loop 5 {
        idx := A_Index
        stratValue := Integer(form.% "Strategy" . idx %)
        cfg := {}
        cfg.Slot := String(idx)
        cfg.Type := stratValue
        if (stratValue == 1)
            continue
        if (stratValue == 2) {
            cfg.X := ResDB[resKey]["HP"].x
            cfg.Y := ResDB[resKey]["HP"].y
            cfg.Cooldown := Integer(form.% "HPCooldown" . idx %)
            if (cfg.Cooldown <= 0)
                cfg.Cooldown := 2000
        } else if (stratValue == 3) {
            cfg.X := ResDB[resKey]["MP"].x
            cfg.Y := ResDB[resKey]["MP"].y
        } else if (stratValue == 4) {
            cfg.Interval := Integer(form.% "Interval" . idx %)
        } else if (stratValue == 5 || stratValue == 6) {
            cfg.BarX := ResDB[resKey]["Slot"][idx].barX
            cfg.BarY := ResDB[resKey]["Slot"][idx].barY
            cfg.ChgX := ResDB[resKey]["Slot"][idx].chgX
            cfg.ChgY := ResDB[resKey]["Slot"][idx].chgY
            if (stratValue == 6) {
                grpIdx := Integer(form.% "Group" . idx %)
                cfg.GroupID := String(grpIdx)
            }
        }
        RunningConfig.Push(cfg)
    }
}

EngineLoop() {
    Critical
    global GameExe, RunningConfig, LastTriggers, GroupMemory, LastMPThresholdTrigger, LastHPTriggerSlot
    global CustomEnabledCB, CustomIntervalEdit, CustomEnabled, CustomInterval
    
    ; 运行时监测自定义循环触发设置变化
    try {
        newEnabled := CustomEnabledCB.Value
        newInterval := Integer(CustomIntervalEdit.Value)
        if (newEnabled != CustomEnabled || newInterval != CustomInterval) {
            CustomEnabled := newEnabled
            CustomInterval := newInterval
            SetTimer(CustomLoop, 0)
            if (CustomEnabled && CustomInterval > 0)
                SetTimer(CustomLoop, CustomInterval)
        }
    }
    
    if !WinActive(GameExe)
        return
    GroupActive := Map("1", false, "2", false)
    for cfg in RunningConfig {
        if (cfg.Type == 6) {
            if ((A_TickCount < GroupMemory[cfg.GroupID]) || CheckYellowBar(cfg.BarX, cfg.BarY))
                GroupActive[cfg.GroupID] := true
        }
    }
    ; 生命阈值触发：多槽位轮流触发，每次只触发一个槽位
    hpCandidates := []
    for cfg in RunningConfig {
        if (cfg.Type != 2)
            continue
        idx := Integer(cfg.Slot)
        if (A_TickCount - LastTriggers[idx] < cfg.Cooldown)
            continue
        if (!CheckColorMatch(cfg.X, cfg.Y, ColorHP))
            hpCandidates.Push({Slot: idx, Cooldown: cfg.Cooldown})
    }
    if (hpCandidates.Length) {
        selected := hpCandidates[1]
        if (LastHPTriggerSlot) {
            nextIndex := 1
            Loop hpCandidates.Length {
                if (hpCandidates[A_Index].Slot = LastHPTriggerSlot) {
                    nextIndex := A_Index + 1
                    break
                }
            }
            if (nextIndex > hpCandidates.Length)
                nextIndex := 1
            selected := hpCandidates[nextIndex]
        }
        ExecutePress(selected.Slot)
        LastHPTriggerSlot := selected.Slot
        LastTriggers[selected.Slot] := A_TickCount + selected.Cooldown
    }

    for cfg in RunningConfig {
        idx := Integer(cfg.Slot)
        if (A_TickCount - LastTriggers[idx] < 300)
            continue
        if (cfg.Type == 3) {
            if (!CheckColorMatch(cfg.X, cfg.Y, ColorMP)) {
                if (A_TickCount - LastMPThresholdTrigger < 2000)
                    continue
                ExecutePress(idx)
                LastMPThresholdTrigger := A_TickCount
                LastTriggers[idx] := A_TickCount + 200
            }
        } else if (cfg.Type == 4) {
            if (A_TickCount - LastTriggers[idx] >= cfg.Interval) {
                ExecutePress(idx)
                LastTriggers[idx] := A_TickCount
            }
        } else if (cfg.Type == 5) {
            if (!CheckYellowBar(cfg.BarX, cfg.BarY) && CheckCharge(cfg.ChgX, cfg.ChgY)) {
                ExecutePress(idx)
                LastTriggers[idx] := A_TickCount + 500
            }
        } else if (cfg.Type == 6) {
            if (!GroupActive[cfg.GroupID]) {
                if (CheckCharge(cfg.ChgX, cfg.ChgY)) {
                    ExecutePress(idx)
                    LastTriggers[idx] := A_TickCount + 500
                    GroupMemory[cfg.GroupID] := A_TickCount + 500
                    GroupActive[cfg.GroupID] := true
                }
            }
        }
    }
}

CustomLoop() {
    global CustomHotkey, CustomEnabled, LinkKey, TriggerKey, LinkDelay, GameExe
    if !WinActive(GameExe)
        return
    
    sendKey := CustomHotkey = "Space" ? "{Space}" : "{" . CustomHotkey . "}"
    Send(sendKey)
    
    ; 如果循环功能的快捷键和按键联动功能的触发键相同，则执行一次联动功能（只触发联动键，不触发触发键）
    if (CustomEnabled && CustomHotkey = TriggerKey) {
        ExecuteLinkOnlyAction(LinkKey)
    }
}

; 仅执行联动键触发（用于循环场景，避免触发键重复）
ExecuteLinkOnlyAction(linkKey) {
    sendLinkKey := linkKey = "Space" ? "{Space}" : "{" . linkKey . "}"
    Send(sendLinkKey)
}

ExecutePress(slotIndex) {
    Send("{" . slotIndex . "}")
    Sleep(Random(30, 80))
}

CheckColorMatch(x, y, targetHex) {
    global ColorTolerance
    c := PixelGetColor(x, y, "RGB")
    r1 := (c >> 16) & 0xFF, g1 := (c >> 8) & 0xFF, b1 := c & 0xFF
    r2 := (targetHex >> 16) & 0xFF, g2 := (targetHex >> 8) & 0xFF, b2 := targetHex & 0xFF
    return (Sqrt((r1 - r2)**2 + (g1 - g2)**2 + (b1 - b2)**2) <= ColorTolerance)
}

CheckYellowBar(x, y) {
    global ColorBar
    return CheckColorMatch(x, y, ColorBar)
}

CheckCharge(x, y) {
    Loop 3 {
        dx := A_Index - 2
        Loop 3 {
            dy := A_Index - 2
            c := PixelGetColor(x + dx, y + dy, "RGB")
            r := (c >> 16) & 0xFF
            g := (c >> 8) & 0xFF
            b := c & 0xFF
            if (g > r + 10 && g > b + 10 && g > 30)
                return true
        }
    }
    return false
}

; 启动入口
Init()