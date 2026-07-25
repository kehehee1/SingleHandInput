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
global LastKey := ""
global LastPressTime := 0
global PreviewGui := 0
global KeyPreviewControls := Map()  ; 物理键 → 预览控件

; ===== 对称键映射表 =====
global KeyMapping := Map(
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

; ===== 初始化 =====
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
A_TrayMenu.Add("设置双击时间...", SetDoubleClickTime)
A_TrayMenu.Add()
A_TrayMenu.Add("退出", QuitScript)
A_TrayMenu.Default := "切换单手模式"

; 初始托盘提示
TrayTip "左手单手输入工具已启动", "按 " SYMMETRY_HOTKEY " 切换单手模式`n单击=原键 双击=对称键", 3

; ===== 热键：切换单手模式 =====
Hotkey("!r", ToggleSymmetry)
ToggleSymmetry(*) {
    global SymmetryActive, LastKey, LastPressTime
    SymmetryActive := !SymmetryActive
    ; 清空按键状态，取消未完成的定时器
    LastKey := ""
    LastPressTime := 0
    if (SymmetryActive) {
        ShowPreview()
        A_TrayMenu.Rename("切换单手模式", "关闭单手模式")
        TraySetIcon(A_AhkPath, 1)  ; 彩色图标：开启
    } else {
        HidePreview()
        A_TrayMenu.Rename("关闭单手模式", "切换单手模式")
        TraySetIcon(A_AhkPath, 2)  ; 灰色图标：关闭
    }
}

; 判断是否处于单手模式（供 HotIf 使用）
IsSymmetryActive() {
    global SymmetryActive
    return SymmetryActive
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
    global LastKey, LastPressTime

    currentTime := A_TickCount

    ; 判断是否为双击（同一键且在时间阈值内）
    if (keyName = LastKey && (currentTime - LastPressTime) <= DOUBLE_CLICK_TIME) {
        ; 双击：输出对称键
        mappedKey := KeyMapping[keyName]
        SendInput("{Blind}{" mappedKey "}")
        UpdatePreview(keyName, mappedKey)
        LastKey := ""
        LastPressTime := 0
        return
    }

    ; 第一次按下：记录并启动超时定时器
    LastKey := keyName
    LastPressTime := currentTime
    SetTimer(() => SingleKeyTimeout(keyName), -DOUBLE_CLICK_TIME)
}

; 超时后输出原键（单击）
SingleKeyTimeout(keyName) {
    global LastKey, LastPressTime, SymmetryActive
    ; 如果模式已关闭，忽略残留定时器
    if (!SymmetryActive)
        return
    if (LastKey = keyName && LastPressTime > 0) {
        SendInput("{Blind}{" keyName "}")
        UpdatePreview(keyName, "")
        LastKey := ""
        LastPressTime := 0
    }
}

HotIf()
#HotIf

; ===== 预览窗口 =====
CreatePreviewWindow() {
    global PreviewGui, KeyPreviewControls

    PreviewGui := Gui("+AlwaysOnTop +ToolWindow -Caption +Border +Owner", "KeyPreview")
    PreviewGui.BackColor := "F0F0F0"
    WinSetTransparent(TRANSPARENCY, PreviewGui.Hwnd)

    ; 预览键位（3行5列，显示映射目标键）
    previewKeys := [
        ["p", "o", "i", "u", "y"],
        ["BS", "l", "k", "j", "h"],
        ["Ent", "Del", "m", "n", "b"]
    ]
    ; 物理键（对应预览位置）
    physicalKeys := [
        ["q", "w", "e", "r", "t"],
        ["a", "s", "d", "f", "g"],
        ["z", "x", "c", "v", "b"]
    ]
    ; 指位序号（小拇指→食指 5→2）
    fingerNums := [5, 4, 3, 2, 2]
    ; 下排指位（z对应5, x对应3, cvb对应2）
    bottomFingerNums := [5, 3, 2, 2, 2]

    cellW := 35, cellH := 28, startX := 10, startY := 8

    ; 第一行：指位序号（上排/中排共用）
    PreviewGui.SetFont("s8", "Consolas")
    Loop 5 {
        col := A_Index - 1
        x := startX + col * cellW
        PreviewGui.Add("Text", "x" x " y" startY " w" cellW " h16 Center c808080", fingerNums[col + 1])
    }

    ; 按键行
    PreviewGui.SetFont("s14 bold", "Consolas")
    Loop 3 {
        row := A_Index - 1
        Loop 5 {
            col := A_Index - 1
            x := startX + col * cellW
            ; 下排按键前插入指位行
            if (row = 2) {
                ; 下排指位提示
                PreviewGui.SetFont("s8", "Consolas")
                fx := startX + col * cellW
                fy := startY + 18 + 2 * cellH
                PreviewGui.Add("Text", "x" fx " y" fy " w" cellW " h14 Center c808080", bottomFingerNums[col + 1])
                PreviewGui.SetFont("s14 bold", "Consolas")
            }
            y := startY + 18 + row * cellH + (row >= 2 ? 16 : 0)
            key := previewKeys[row + 1][col + 1]
            phyKey := physicalKeys[row + 1][col + 1]
            ctrl := PreviewGui.Add("Text", "x" x " y" y " w" cellW " h" cellH " Center c0078D7", key)
            KeyPreviewControls[phyKey] := ctrl
        }
    }

    PreviewGui.Show("Hide")
}

ShowPreview() {
    global PreviewGui
    if (PreviewGui) {
        PreviewGui.Show("NA")   ; NA = NoActivate
    }
}

HidePreview() {
    global PreviewGui
    if (PreviewGui) {
        PreviewGui.Hide()
    }
}

UpdatePreview(originalKey, mappedKey) {
    global PreviewGui, KeyPreviewControls

    if (!PreviewGui)
        return

    ; 重置所有控件颜色为默认
    for phyKey, ctrl in KeyPreviewControls {
        ctrl.SetFont("c0078D7")
    }

    ; 高亮按下的物理键对应的预览控件
    if (KeyPreviewControls.Has(originalKey)) {
        ctrl := KeyPreviewControls[originalKey]
        ctrl.SetFont("cFF4400")
        SetTimer(ResetHighlight.Bind(originalKey), -500)
    }

    PreviewGui.Show("NA")
}

; 500ms 后恢复高亮
ResetHighlight(keyName) {
    global KeyPreviewControls
    if (KeyPreviewControls.Has(keyName)) {
        ctrl := KeyPreviewControls[keyName]
        ctrl.SetFont("c0078D7")
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
        TrayTip "已更新", "双击时间 = " DOUBLE_CLICK_TIME "ms", 1
    }
}

; ===== 退出清理 =====
QuitScript(*) {
    global PreviewGui
    if (PreviewGui)
        PreviewGui.Destroy()
    ExitApp()
}

OnExit(QuitScript)
