; ============================================================
; 左手单手输入工具 - AutoHotkey v2
; 方案：单击输出原键，双击输出对称键
; 功能：一键切换 + 透明预览窗口 + 光标跟随
; ============================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

; ===== 配置区域 =====
global DOUBLE_CLICK_TIME := 220        ; 双击判定时间（毫秒）
global SYMMETRY_HOTKEY := "Alt+R"   ; 切换单手模式的热键
global TRANSPARENCY := 220              ; 窗口透明度（0=全透, 255=不透）

; ===== 全局变量 =====
global SymmetryActive := false
global KeyStates := Map()  ; keyName → {pressTime, consumed}
global PreviewGui := 0
global KeyPreviewControls := Map()  ; 物理键 → 预览控件
global KeyPreviewColors := Map()    ; 物理键 → 默认颜色
global PreviewX := 0
global PreviewY := 0
global PreviewPosInitialized := false
global KeyMapping := Map(
    ; 数字行
    "1", "0", "2", "9", "3", "8", "4", "7", "5", "6",
    "6", "5", "7", "4", "8", "3", "9", "2", "0", "1",
    ; 上排
    "q", "p", "w", "o", "e", "i", "r", "u", "t", "y",
    "y", "t", "u", "r", "i", "e", "o", "w", "p", "q",
    ; 中排
    "a", "Backspace", "s", "l", "d", "k", "f", "j", "g", "h",
    "h", "g", "j", "f", "k", "d", "l", "s", "'", "a",
    ; 下排（B 不映射，V↔N  C↔M  X→Del  Z→Enter）
    "z", "Enter", "x", "Delete", "c", "m", "v", "n",
    "n", "v", "m", "c", "Delete", "x", "Enter", "z"
)

; ===== 配置文件持久化 =====
global CONFIG_PATH := A_ScriptDir . "\LeftHandSymmetry.ini"

LoadConfig() {
    global DOUBLE_CLICK_TIME, TRANSPARENCY, PreviewX, PreviewY, PreviewPosInitialized
    if !FileExist(CONFIG_PATH)
        return
    DOUBLE_CLICK_TIME := Integer(IniRead(CONFIG_PATH, "Settings", "DoubleClickTime", DOUBLE_CLICK_TIME))
    TRANSPARENCY := Integer(IniRead(CONFIG_PATH, "Settings", "Transparency", TRANSPARENCY))
    PreviewX := Integer(IniRead(CONFIG_PATH, "Settings", "PreviewX", ""))
    PreviewY := Integer(IniRead(CONFIG_PATH, "Settings", "PreviewY", ""))
    posInit := IniRead(CONFIG_PATH, "Settings", "PreviewPosInitialized", "0")
    if (posInit = "1" && PreviewX != "" && PreviewY != "")
        PreviewPosInitialized := true
}

SaveConfig() {
    global DOUBLE_CLICK_TIME, TRANSPARENCY, PreviewX, PreviewY, PreviewPosInitialized
    IniWrite DOUBLE_CLICK_TIME, CONFIG_PATH, "Settings", "DoubleClickTime"
    IniWrite TRANSPARENCY, CONFIG_PATH, "Settings", "Transparency"
    IniWrite (PreviewPosInitialized ? "1" : "0"), CONFIG_PATH, "Settings", "PreviewPosInitialized"
    if (PreviewPosInitialized) {
        IniWrite PreviewX, CONFIG_PATH, "Settings", "PreviewX"
        IniWrite PreviewY, CONFIG_PATH, "Settings", "PreviewY"
    }
}

; ===== 初始化 =====
LoadConfig()
CreatePreviewWindow()

; ===== 托盘菜单 =====
try
    A_TrayMenu.Delete("&Pause Script")
catch
try
    A_TrayMenu.Delete("&Suspend Hotkeys")
catch
A_TrayMenu.Add()
A_TrayMenu.Add("切换单手模式", ToggleSymmetry)
A_TrayMenu.Add("显示预览窗口", TogglePreview)
A_TrayMenu.Add("设置双击时间...", SetDoubleClickTime)
A_TrayMenu.Add()
A_TrayMenu.Add("退出", QuitScript)
A_TrayMenu.Default := "切换单手模式"

; 初始托盘提示
TrayTip "左手单手输入工具已启动", "按 " SYMMETRY_HOTKEY " 切换单手模式`n单击=原键 双击=对称键", 3

; ===== 热键：切换单手模式 =====
Hotkey("!r", ToggleSymmetry)
ToggleSymmetry(*) {
    global SymmetryActive, KeyStates
    SymmetryActive := !SymmetryActive
    ; 清空按键状态，取消未完成的定时器
    KeyStates := Map()
    if (SymmetryActive) {
        ShowPreview()
        try
            A_TrayMenu.Rename("切换单手模式", "关闭单手模式")
        catch
            {}
        TraySetIcon(A_AhkPath, 1)  ; 彩色图标：开启
    } else {
        HidePreview()
        try
            A_TrayMenu.Rename("关闭单手模式", "切换单手模式")
        catch
            {}
        TraySetIcon(A_AhkPath, 2)  ; 灰色图标：关闭
    }
}

; 判断是否处于单手模式（供 HotIf 使用）
IsSymmetryActive() {
    global SymmetryActive
    if !SymmetryActive
        return false
    ; 与 pet 工具冲突规避：Space/CapsLock 按下时让 pet 接管
    if GetKeyState("Space", "P")
        return false
    if GetKeyState("CapsLock", "T")
        return false
    ; 组合键时跳过（使用逻辑状态检测，兼容 Ditto 等软件发送的模拟按键）
    if GetKeyState("Ctrl") || GetKeyState("Alt") || GetKeyState("Shift")
        return false
    if GetKeyState("LWin") || GetKeyState("RWin")
        return false
    return true
}

; ===== 键盘钩子 =====
#HotIf IsSymmetryActive()
HotIf "IsSymmetryActive()"

#InputLevel 1
for originalKey, mappedKey in KeyMapping {
    fn := KeyHandler.Bind(originalKey)
    Hotkey("*" originalKey, fn)
}
#InputLevel 0

KeyHandler(keyName, *) {
    global KeyStates

    ; 与 pet 工具冲突规避：长按 Space 时跳过处理，让 pet 接管
    if GetKeyState("Space", "P")
        return

    currentTime := A_TickCount
    state := KeyStates.Get(keyName, 0)

    ; 判断是否为双击（同一键且在时间阈值内）
    if (state && (currentTime - state.pressTime) <= DOUBLE_CLICK_TIME) {
        ; 双击：输出对称键，标记已消费防止超时回调输出原键
        mappedKey := KeyMapping[keyName]
        SendInput("{Blind}{" mappedKey "}")
        UpdatePreview(keyName, mappedKey)
        state.consumed := true
        return
    }

    ; 第一次按下：记录并启动超时定时器
    KeyStates[keyName] := {pressTime: currentTime, consumed: false}
    SetTimer(() => SingleKeyTimeout(keyName), -DOUBLE_CLICK_TIME)
}

; 超时后输出原键（单击）
SingleKeyTimeout(keyName) {
    global KeyStates, SymmetryActive
    ; 如果模式已关闭，忽略残留定时器
    if (!SymmetryActive)
        return
    ; 与 pet 工具冲突规避：长按 Space 时跳过处理
    if GetKeyState("Space", "P")
        return
    state := KeyStates.Get(keyName, 0)
    ; 已被双击消费或状态已清除，不输出原键
    if (!state || state.consumed || !state.pressTime)
        return
    SendInput("{Blind}{" keyName "}")
    UpdatePreview(keyName, "")
    KeyStates.Delete(keyName)
}

HotIf()
#HotIf

; ===== 预览窗口 =====
CreatePreviewWindow() {
    global PreviewGui, KeyPreviewControls, KeyPreviewColors

    ; 指位颜色映射（彩虹色：5→红, 4→橙, 3→绿, 2→蓝）
    fingerColors := Map(5, "cE04040", 4, "cE08020", 3, "c109010", 2, "c1040C0")

    PreviewGui := Gui("+AlwaysOnTop +ToolWindow -Caption +Border +Owner", "KeyPreview")
    PreviewGui.BackColor := "F0F0F0"
    WinSetTransparent(TRANSPARENCY, PreviewGui.Hwnd)

    ; 预览键位（4行5列，显示映射目标键）
    previewKeys := [
        ["0", "9", "8", "7", "6"],  ; 数字行映射
        ["p", "o", "i", "u", "y"],
        ["BS", "l", "k", "j", "h"],
        ["Ent", "Del", "m", "n", "b"]
    ]
    ; 物理键（对应预览位置）
    physicalKeys := [
        ["1", "2", "3", "4", "5"],  ; 数字行物理键
        ["q", "w", "e", "r", "t"],
        ["a", "s", "d", "f", "g"],
        ["z", "x", "c", "v", "b"]
    ]
    ; 指位（每行每列对应的指位序号）
    fingerPositions := [
        [5, 4, 3, 2, 2],  ; 数字行
        [5, 4, 3, 2, 2],  ; 上排
        [5, 4, 3, 2, 2],  ; 中排
        [5, 3, 2, 2, 2]   ; 下排
    ]
    ; 上排/中排指位序号（小拇指→食指 5→2）
    fingerNums := [5, 4, 3, 2, 2]
    ; 下排指位（z对应5, x对应3, cvb对应2）
    bottomFingerNums := [5, 3, 2, 2, 2]

    cellW := 35, cellH := 28, startX := 10, startY := 8

    ; 第一行：指位序号（上排/中排共用）
    PreviewGui.SetFont("s8", "Consolas")
    Loop 5 {
        col := A_Index - 1
        x := startX + col * cellW
        f := fingerNums[col + 1]
        color := fingerColors[f]
        PreviewGui.Add("Text", "x" x " y" startY " w" cellW " h16 Center c" color, f)
    }

    ; 按键行
    PreviewGui.SetFont("s14 bold", "Consolas")
    Loop 4 {
        row := A_Index - 1
        Loop 5 {
            col := A_Index - 1
            x := startX + col * cellW
            ; 下排按键前插入指位行
            if (row = 3) {
                ; 下排指位提示
                PreviewGui.SetFont("s8", "Consolas")
                fx := startX + col * cellW
                fy := startY + 18 + 3 * cellH
                f := bottomFingerNums[col + 1]
                color := fingerColors[f]
                PreviewGui.Add("Text", "x" fx " y" fy " w" cellW " h14 Center c" color, f)
                PreviewGui.SetFont("s14 bold", "Consolas")
            }
            y := startY + 18 + row * cellH + (row >= 3 ? 16 : 0)
            key := previewKeys[row + 1][col + 1]
            phyKey := physicalKeys[row + 1][col + 1]
            f := fingerPositions[row + 1][col + 1]
            color := fingerColors[f]
            ctrl := PreviewGui.Add("Text", "x" x " y" y " w" cellW " h" cellH " Center c" color, key)
            KeyPreviewControls[phyKey] := ctrl
            KeyPreviewColors[phyKey] := color
        }
    }

    PreviewGui.Show("Hide")

    ; 支持鼠标左键拖动窗口
    OnMessage(0x0201, OnPreviewLButtonDown)  ; WM_LBUTTONDOWN
    ; 右键弹出菜单
    OnMessage(0x0205, OnPreviewRButtonUp)    ; WM_RBUTTONUP
    ; 拖动结束后保存位置
    OnMessage(0x0232, OnPreviewMoveEnd)      ; WM_EXITSIZEMOVE
}

ShowPreview() {
    global PreviewGui, PreviewX, PreviewY, PreviewPosInitialized
    if (PreviewGui) {
        if !PreviewPosInitialized {
            ; 首次显示：右下角
            MonitorGetWorkArea(1, &workL, &workT, &workR, &workB)
            PreviewX := workR - 200 - 20
            PreviewY := workB - 140 - 20
            PreviewPosInitialized := true
        }
        PreviewGui.Show("NA x" PreviewX " y" PreviewY)
        try
            A_TrayMenu.Rename("显示预览窗口", "隐藏预览窗口")
        catch
            {}
    }
}

HidePreview(*) {
    global PreviewGui
    if (PreviewGui) {
        PreviewGui.Hide()
        try
            A_TrayMenu.Rename("隐藏预览窗口", "显示预览窗口")
        catch
            {}
    }
}

; ===== 预览窗口交互 =====

; 左键按下：拖动窗口
OnPreviewLButtonDown(wParam, lParam, msg, hwnd) {
    global PreviewGui
    if (PreviewGui && hwnd) {
        parentHwnd := DllCall("GetAncestor", "ptr", hwnd, "uint", 2, "ptr")
        if (parentHwnd = PreviewGui.Hwnd)
            PostMessage(0xA1, 2, 0,, parentHwnd)  ; WM_NCLBUTTONDOWN, HTCAPTION
    }
}

; 右键按下：弹出上下文菜单
OnPreviewRButtonUp(wParam, lParam, msg, hwnd) {
    global PreviewGui
    if (PreviewGui && hwnd) {
        ; 检查 hwnd 是否属于预览窗口（包括子控件）
        parentHwnd := DllCall("GetAncestor", "ptr", hwnd, "uint", 2, "ptr")
        if (parentHwnd = PreviewGui.Hwnd)
            ShowPreviewContextMenu()
    }
}

; 拖动结束：保存位置
OnPreviewMoveEnd(wParam, lParam, msg, hwnd) {
    global PreviewGui, PreviewX, PreviewY, PreviewPosInitialized
    if (PreviewGui && hwnd) {
        parentHwnd := DllCall("GetAncestor", "ptr", hwnd, "uint", 2, "ptr")
        if (parentHwnd = PreviewGui.Hwnd) {
            PreviewGui.GetPos(&PreviewX, &PreviewY)
            PreviewPosInitialized := true
            SaveConfig()
        }
    }
}

; 预览窗口右键菜单
ShowPreviewContextMenu(*) {
    previewMenu := Menu()
    previewMenu.Add("透明度 50%", SetTransparency50)
    previewMenu.Add("透明度 70%", SetTransparency70)
    previewMenu.Add("透明度 90%", SetTransparency90)
    previewMenu.Add()
    previewMenu.Add("关闭预览", HidePreview)
    previewMenu.Show()
}

; 设置透明度
SetTransparency(alpha) {
    global PreviewGui, TRANSPARENCY
    TRANSPARENCY := alpha
    SaveConfig()
    if (PreviewGui)
        WinSetTransparent(alpha, PreviewGui.Hwnd)
}

; 透明度快捷回调（菜单专用）
SetTransparency50(*) {
    SetTransparency(128)
}
SetTransparency70(*) {
    SetTransparency(178)
}
SetTransparency90(*) {
    SetTransparency(230)
}

; 托盘菜单：切换预览窗口
TogglePreview(*) {
    global PreviewGui
    if (PreviewGui && PreviewGui.Hwnd) {
        if DllCall("IsWindowVisible", "ptr", PreviewGui.Hwnd)
            HidePreview()
        else
            ShowPreview()
    }
}

UpdatePreview(originalKey, mappedKey) {
    global PreviewGui, KeyPreviewControls, KeyPreviewColors

    if (!PreviewGui)
        return

    ; 重置所有控件颜色为各自的指位颜色
    for phyKey, ctrl in KeyPreviewControls {
        color := KeyPreviewColors.Has(phyKey) ? KeyPreviewColors[phyKey] : "c0078D7"
        ctrl.SetFont("c" color)
    }

    ; 高亮按下的物理键对应的预览控件（金色，避免与彩虹色冲突）
    if (KeyPreviewControls.Has(originalKey)) {
        ctrl := KeyPreviewControls[originalKey]
        ctrl.SetFont("cFFD700")
        SetTimer(ResetHighlight.Bind(originalKey), -500)
    }

    PreviewGui.Show("NA")
}

; 500ms 后恢复高亮
ResetHighlight(keyName) {
    global KeyPreviewControls, KeyPreviewColors
    if (KeyPreviewControls.Has(keyName)) {
        ctrl := KeyPreviewControls[keyName]
        color := KeyPreviewColors.Has(keyName) ? KeyPreviewColors[keyName] : "c0078D7"
        ctrl.SetFont("c" color)
    }
}



; ===== 设置对话框 =====
SetDoubleClickTime(*) {
    result := InputBox(
        "请输入双击判定时间（毫秒）`n推荐范围：150-300`n当前值：" DOUBLE_CLICK_TIME,
        "设置双击时间",
        "w300 h150"
    )
    if (result.Result = "OK" && result.Value ~= "^\d+$") {
        global DOUBLE_CLICK_TIME
        DOUBLE_CLICK_TIME := Integer(result.Value)
        SaveConfig()
        TrayTip "已更新", "双击时间 = " DOUBLE_CLICK_TIME "ms", 1
    }
}

; ===== 退出清理 =====
QuitScript(*) {
    global PreviewGui
    SaveConfig()
    if (PreviewGui)
        PreviewGui.Destroy()
    ExitApp()
}

OnExit(QuitScript)
