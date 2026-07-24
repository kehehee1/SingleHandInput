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
global PREVIEW_WIN_WIDTH := 120         ; 预览窗口宽度
global PREVIEW_WIN_HEIGHT := 70         ; 预览窗口高度
global OFFSET_X := 20                   ; 光标偏移量（向右）
global OFFSET_Y := 30                   ; 光标偏移量（向下）
global TRANSPARENCY := 220              ; 窗口透明度（0=全透, 255=不透）

; ===== 全局变量 =====
global SymmetryActive := false
global LastKey := ""
global LastPressTime := 0
global PreviewGui := 0
global ctrlMapped := 0
global ctrlOriginal := 0

; ===== 对称键映射表 =====
global KeyMapping := Map(
    ; 上排
    "q", "p", "w", "o", "e", "i", "r", "u", "t", "y",
    "y", "t", "u", "r", "i", "e", "o", "w", "p", "q",
    ; 中排
    "a", "'", "s", "l", "d", "k", "f", "j", "g", "h",
    "h", "g", "j", "f", "k", "d", "l", "s", "'", "a",
    ; 下排（B 不映射，V↔N  C↔M  X↔,  Z↔.）
    "z", ".", "x", ",", "c", "m", "v", "n",
    "n", "v", "m", "c", ",", "x", ".", "z"
)

; ===== 初始化 =====
CreatePreviewWindow()
UpdatePosition()
SetTimer(UpdatePosition, 100)   ; 每100ms刷新窗口位置

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
    } else {
        HidePreview()
        A_TrayMenu.Rename("关闭单手模式", "切换单手模式")
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
    global PreviewGui, ctrlMapped, ctrlOriginal

    PreviewGui := Gui("+AlwaysOnTop +ToolWindow -Caption +Border +Owner", "KeyPreview")
    PreviewGui.BackColor := "F0F0F0"
    WinSetTransparent(TRANSPARENCY, PreviewGui.Hwnd)

    ; 映射键（大字，粗体）
    PreviewGui.SetFont("s16 bold", "Segoe UI")
    ctrlMapped := PreviewGui.Add("Text", "x10 y5 w100 h30 Center BackgroundTrans cBlue", "")

    ; 原始键（小字）
    PreviewGui.SetFont("s9", "Segoe UI")
    ctrlOriginal := PreviewGui.Add("Text", "x10 y38 w100 h20 Center BackgroundTrans cGray", "")

    ; 状态标签
    PreviewGui.SetFont("s7", "Segoe UI")
    PreviewGui.Add("Text", "x10 y55 w100 h12 Center BackgroundTrans cGray", "单手模式")

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
    global ctrlMapped, ctrlOriginal

    if (!ctrlMapped || !ctrlOriginal)
        return

    if (mappedKey != "") {
        ctrlMapped.Text := mappedKey
        ctrlMapped.SetFont("cBlue")
        ctrlOriginal.Text := "← " originalKey
    } else {
        ctrlMapped.Text := originalKey
        ctrlMapped.SetFont("cBlack")
        ctrlOriginal.Text := ""
    }

    if (PreviewGui)
        PreviewGui.Show("NA")
}

; 根据光标/插入符位置更新窗口位置
UpdatePosition() {
    global PreviewGui
    if (!PreviewGui || !SymmetryActive)
        return

    ; 尝试获取文本插入符位置
    CoordMode("Caret", "Screen")
    caretX := 0, caretY := 0
    try {
        DllCall("GetCaretPos", "Int*", &caretX, "Int*", &caretY)
    }

    ; 如果获取失败，使用鼠标位置
    if (caretX = 0 && caretY = 0) {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&caretX, &caretY)
    }

    ; 计算窗口位置
    winX := caretX + OFFSET_X
    winY := caretY + OFFSET_Y

    ; 边界检测
    try {
        MonitorGetWorkArea(,, &monRight, &monBottom)
        if (winX + PREVIEW_WIN_WIDTH > monRight)
            winX := monRight - PREVIEW_WIN_WIDTH - 10
        if (winY + PREVIEW_WIN_HEIGHT > monBottom)
            winY := monBottom - PREVIEW_WIN_HEIGHT - 10
    }

    PreviewGui.Move(winX, winY)
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
