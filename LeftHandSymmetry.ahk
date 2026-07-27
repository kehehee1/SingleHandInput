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
global lastKey := ""    ; 上次按下的键（用于双击判定）
global lastTime := 0     ; 上次按键的时间戳
global PreviewGui := 0
global KeyPreviewControls := Map()  ; 物理键 → 预览控件
global KeyPreviewColors := Map()    ; 物理键 → 默认颜色
global PreviewX := 0
global PreviewY := 0
global PreviewPosInitialized := false
global PreviewVisible := false  ; 预览窗显隐状态，持久化到配置
global PreviewMode := "full"    ; 预览模式：full=全键盘, mapped=仅映射键
global KeyMapping := Map()
global lastHighlightedKey := ""  ; 上次高亮的键（用于去闪烁）
global KeyPreviewCtrlToKey := Map()  ; 控件 → 物理键（反向查找）
global KeyPreviewHwndToKey := Map()  ; 控件Hwnd → 物理键
global KeyPreviewSubControls := Map()  ; 物理键 → 映射键标签控件（用于悬浮放大）
global lastHoveredKey := ""  ; 鼠标悬浮的键

; ===== 默认映射（单向：左→右）=====
SetDefaultKeyMapping() {
    global KeyMapping
    KeyMapping := Map(
        ; 数字行（左→右）
        "1", "0", "2", "9", "3", "8", "4", "7", "5", "6",
        ; 上排（左→右）
        "q", "p", "w", "o", "e", "i", "r", "u", "t", "y",
        ; 中排（左→右）
        "a", "Backspace", "s", "l", "d", "k", "f", "j", "g", "h",
        ; 下排（B 不映射，X→Del  Z→Enter  C→M  V→N）
        "z", "Enter", "x", "Delete", "c", "m", "v", "n"
    )
}

; ===== 配置文件持久化 =====
global CONFIG_PATH := A_ScriptDir . "\LeftHandSymmetry.ini"

LoadConfig() {
    global DOUBLE_CLICK_TIME, TRANSPARENCY, PreviewX, PreviewY, PreviewPosInitialized, PreviewVisible, KeyMapping
    if !FileExist(CONFIG_PATH)
        return
    DOUBLE_CLICK_TIME := Integer(IniRead(CONFIG_PATH, "Settings", "DoubleClickTime", DOUBLE_CLICK_TIME))
    TRANSPARENCY := Integer(IniRead(CONFIG_PATH, "Settings", "Transparency", TRANSPARENCY))
    try
        PreviewX := Integer(IniRead(CONFIG_PATH, "Settings", "PreviewX", ""))
    catch
        PreviewX := 0
    try
        PreviewY := Integer(IniRead(CONFIG_PATH, "Settings", "PreviewY", ""))
    catch
        PreviewY := 0
    posInit := IniRead(CONFIG_PATH, "Settings", "PreviewPosInitialized", "0")
    if (posInit = "1" && PreviewX != "" && PreviewY != "")
        PreviewPosInitialized := true
    PreviewVisible := (IniRead(CONFIG_PATH, "Settings", "PreviewVisible", "0") = "1")

    ; 加载自定义按键映射
    try
        mappingStr := IniRead(CONFIG_PATH, "KeyMapping")
    catch
        mappingStr := ""
    if (mappingStr != "") {
        KeyMapping := Map()
        Loop Parse, mappingStr, "`n"
        {
            if A_LoopField = ""
                continue
            eqPos := InStr(A_LoopField, "=")
            if (eqPos > 0) {
                srcKey := SubStr(A_LoopField, 1, eqPos - 1)
                tgtKey := SubStr(A_LoopField, eqPos + 1)
                KeyMapping[srcKey] := tgtKey
            }
        }
    }
    ; 加载预览模式
    try
        PreviewMode := IniRead(CONFIG_PATH, "Settings", "PreviewMode", "full")
    catch
        PreviewMode := "full"
}

SaveConfig() {
    global DOUBLE_CLICK_TIME, TRANSPARENCY, PreviewX, PreviewY, PreviewPosInitialized, PreviewVisible, PreviewMode, KeyMapping

    file := FileOpen(CONFIG_PATH, "w", "UTF-8")
    if !file
        return

    file.WriteLine("[Settings]")
    file.WriteLine("DoubleClickTime=" . DOUBLE_CLICK_TIME)
    file.WriteLine("Transparency=" . TRANSPARENCY)
    file.WriteLine("PreviewPosInitialized=" . (PreviewPosInitialized ? "1" : "0"))
    file.WriteLine("PreviewVisible=" . (PreviewVisible ? "1" : "0"))
    file.WriteLine("PreviewMode=" . PreviewMode)
    if (PreviewPosInitialized) {
        file.WriteLine("PreviewX=" . PreviewX)
        file.WriteLine("PreviewY=" . PreviewY)
    }
    file.WriteLine("")

    file.WriteLine("[KeyMapping]")
    file.WriteLine("; 左手单手输入工具 - 按键映射配置")
    file.WriteLine("; 格式：原始键=目标键（双击原始键时发送目标键）")
    file.WriteLine("; 例如：a=l 表示双击 a 发送 l（单次 a 仍透传原键）")
    file.WriteLine("; 目标键可用键名：Backspace, Enter, Delete, Tab, Esc, Space 等")
    file.WriteLine("")
    for srcKey, tgtKey in KeyMapping {
        file.WriteLine(srcKey . "=" . tgtKey)
    }

    file.Close()
}

; ===== 初始化 =====
LoadConfig()
; 如果 INI 没有 [KeyMapping] 节，使用默认映射并立即写入
if (KeyMapping.Count = 0) {
    SetDefaultKeyMapping()
    SaveConfig()
}
CreatePreviewWindow()
; 初始托盘图标：灰色（模式关闭状态）
TraySetIcon(A_AhkPath, 2)

; ===== 托盘菜单 =====
; 先清空所有菜单项，再添加自定义菜单
A_TrayMenu.Delete()
A_TrayMenu.Add()
A_TrayMenu.Add("切换单手模式", ToggleSymmetry)
A_TrayMenu.Add("显示预览窗口", TogglePreview)
A_TrayMenu.Add("切换预览模式", TogglePreviewMode)
A_TrayMenu.Add("设置双击时间...", SetDoubleClickTime)
A_TrayMenu.Add()
A_TrayMenu.Add("打开配置", OpenConfig)
A_TrayMenu.Add("重置默认映射", ResetKeyMapping)
A_TrayMenu.Add("重新加载配置", ReloadConfig)
A_TrayMenu.Add()
A_TrayMenu.Add("打开脚本", OpenScript)
A_TrayMenu.Add("重启", RestartScript)
A_TrayMenu.Add()
A_TrayMenu.Add("退出", QuitScript)
A_TrayMenu.Default := "切换单手模式"

; 初始托盘提示
TrayTip "左手单手输入工具已启动", "按 " SYMMETRY_HOTKEY " 切换单手模式`n单击=原键 双击=对称键", 1
SetTimer(DismissTrayTip, -2000)

; ===== 热键：切换单手模式 =====
Hotkey("!r", ToggleSymmetry)
ToggleSymmetry(*) {
    global SymmetryActive, lastKey, lastTime, PreviewVisible
    SymmetryActive := !SymmetryActive
    ; 清空按键状态
    lastKey := ""
    lastTime := 0
    if (SymmetryActive) {
        ; 启用模式：根据配置决定是否显示预览窗
        if (PreviewVisible) {
            ShowPreview()
        }
        try
            A_TrayMenu.Rename("切换单手模式", "关闭单手模式")
        catch
            {}
        TraySetIcon(A_AhkPath, 1)  ; 彩色图标：开启
        TrayTip "单手模式已激活", "单击=原键 双击=对称键", 1
        SetTimer(DismissTrayTip, -2000)
    } else {
        ; 关闭模式：始终隐藏预览窗（不修改配置，只隐藏界面）
        HidePreview(false)
        try
            A_TrayMenu.Rename("关闭单手模式", "切换单手模式")
        catch
            {}
        TraySetIcon(A_AhkPath, 2)  ; 灰色图标：关闭
    }
}

;
; ===== 键盘钩子（~ 前缀让按键自然透传，内部判断双击逻辑）=====
#InputLevel 1
for originalKey, mappedKey in KeyMapping {
    fn := KeyHandler.Bind(originalKey)
    Hotkey("~$*" originalKey, fn)
}
#InputLevel 0

KeyHandler(keyName, *) {
    global SymmetryActive, lastKey, lastTime

    ; 与 pet 工具冲突规避：Space 长按模式让 pet 接管
    if GetKeyState("Space", "P") {
        return
    }
    ; 与 pet 工具冲突规避：CapsLock 模式让 pet 接管
    if GetKeyState("CapsLock", "T") {
        return
    }

    ; 如果模式已关闭，直接返回（按键已通过 ~ 前缀自然透传）
    if !SymmetryActive {
        return
    }

    ; 组合键时跳过（Ctrl/Alt/Win 组合键透传，Shift 保留以支持双击映射大写）
    if GetKeyState("Ctrl") || GetKeyState("Alt") {
        return
    }
    if GetKeyState("LWin") || GetKeyState("RWin") {
        return
    }

    currentTime := A_TickCount

    ; 相同键且在阈值内 → 双击：退格两次（移除两次透传的字符）+ 输出对称键
    if (keyName = lastKey && (currentTime - lastTime) <= DOUBLE_CLICK_TIME) {
        mappedKey := KeyMapping[keyName]
        SendInput("{Blind}{Backspace 2}{" mappedKey "}")
        UpdatePreview(keyName, mappedKey)
        lastKey := ""
        lastTime := 0
        return
    }

    ; 单击（或不同键）：按键已通过 ~ 前缀自然透传，只需记录
    UpdatePreview(keyName, "")
    lastKey := keyName
    lastTime := currentTime
}

; ===== 预览窗口（虚拟键盘样式）=====
CreatePreviewWindow() {
    global PreviewGui, KeyPreviewControls, KeyPreviewColors, KeyMapping, PreviewMode, KeyPreviewCtrlToKey, lastHoveredKey, KeyPreviewSubControls

    KeyPreviewCtrlToKey := Map()
    lastHoveredKey := ""

    ; 指位颜色映射（已移除：改用统一的蓝色/灰色键帽）

    PreviewGui := Gui("+AlwaysOnTop +ToolWindow -Caption +Border +Owner", "KeyPreview")
    PreviewGui.BackColor := "F0F0F0"
    WinSetTransparent(TRANSPARENCY, PreviewGui.Hwnd)

    ; 键盘布局（左手区域，按行排列，每行居中）
    keyboardLayout := [
        ["``", "1", "2", "3", "4", "5"],
        ["q", "w", "e", "r", "t", "y"],
        ["a", "s", "d", "f", "g", "h"],
        ["z", "x", "c", "v", "b", "n", "m"]
    ]

    cellW := 56, cellH := 52  ; 键帽尺寸
    gapH := 5, gapV := 5      ; 键间距
    paddingX := 12, paddingY := 12

    ; 计算最大列数
    maxCols := 0
    for rowKeys in keyboardLayout {
        if (rowKeys.Length > maxCols)
            maxCols := rowKeys.Length
    }

    ; 窗口宽度
    winW := paddingX * 2 + maxCols * (cellW + gapH) - gapH
    winH := paddingY * 2 + keyboardLayout.Length * (cellH + gapV) - gapV

    PreviewGui.SetFont("s14 bold", "Consolas")

    for rowIdx, rowKeys in keyboardLayout {
        row := rowIdx - 1
        y := paddingY + row * (cellH + gapV)

        ; 该行居中
        rowWidth := rowKeys.Length * (cellW + gapH) - gapH
        startX := paddingX + (winW - paddingX * 2 - rowWidth) // 2

        for colIdx, phyKey in rowKeys {
            x := startX + (colIdx - 1) * (cellW + gapH)

            hasMapping := KeyMapping.Has(phyKey)
            mappedKey := hasMapping ? KeyMapping[phyKey] : ""

            ; 仅映射模式：跳过无映射的键
            if (PreviewMode = "mapped" && !hasMapping)
                continue

            if (hasMapping) {
                ; 有映射：蓝色键帽 + 白色文字，显示原键
                ctrl := PreviewGui.Add("Text",
                    "x" x " y" y " w" cellW " h" cellH " +0x200 +Center cFFFFFF Background4A90D9", phyKey)

                ; 映射键名小标签（在键帽底部）
                displayMapped := mappedKey
                if (mappedKey = "Backspace")
                    displayMapped := "BS"
                else if (mappedKey = "Enter")
                    displayMapped := "Ent"
                else if (mappedKey = "Delete")
                    displayMapped := "Del"
                else if (mappedKey = "Space")
                    displayMapped := "Spc"
                else if (mappedKey = "Escape" || mappedKey = "Esc")
                    displayMapped := "Esc"

                subY := y + cellH - 20
                PreviewGui.SetFont("s12", "Consolas")
                subCtrl := PreviewGui.Add("Text",
                    "x" x " y" subY " w" cellW " h" 20 " +0x200 +Center cB0D4FF Background4A90D9", displayMapped)
                PreviewGui.SetFont("s14 bold", "Consolas")
                KeyPreviewCtrlToKey[subCtrl] := phyKey
                KeyPreviewHwndToKey[subCtrl.Hwnd] := phyKey
                KeyPreviewSubControls[phyKey] := subCtrl
            } else {
                ; 无映射：灰色键帽 + 深色文字
                ctrl := PreviewGui.Add("Text",
                    "x" x " y" y " w" cellW " h" cellH " +0x200 +Center c666666 BackgroundE8E8E8", phyKey)
            }

            KeyPreviewControls[phyKey] := ctrl
            KeyPreviewCtrlToKey[ctrl] := phyKey
            KeyPreviewHwndToKey[ctrl.Hwnd] := phyKey
            KeyPreviewColors[phyKey] := ""
        }
    }

    PreviewGui.Show("Hide")

    ; 支持鼠标左键拖动窗口
    OnMessage(0x0201, OnPreviewLButtonDown)  ; WM_LBUTTONDOWN
    ; 鼠标移动：悬浮高亮
    OnMessage(0x0200, OnPreviewMouseMove)    ; WM_MOUSEMOVE
    ; 右键弹出菜单
    OnMessage(0x0205, OnPreviewRButtonUp)    ; WM_RBUTTONUP
    ; 拖动结束后保存位置
    OnMessage(0x0232, OnPreviewMoveEnd)      ; WM_EXITSIZEMOVE
}

ShowPreview() {
    global PreviewGui, PreviewX, PreviewY, PreviewPosInitialized, PreviewVisible
    if (PreviewGui) {
        if !PreviewPosInitialized {
            ; 首次显示：右下角
            MonitorGetWorkArea(1, &workL, &workT, &workR, &workB)
            PreviewX := workR - 460 - 20
            PreviewY := workB - 250 - 20
            PreviewPosInitialized := true
        }
        PreviewGui.Show("NA x" PreviewX " y" PreviewY)
        PreviewVisible := true
        SaveConfig()
        try
            A_TrayMenu.Rename("显示预览窗口", "隐藏预览窗口")
        catch
            {}
    }
}

HidePreview(saveToConfig := true) {
    global PreviewGui, PreviewVisible
    if (PreviewGui) {
        PreviewGui.Hide()
        if (saveToConfig) {
            PreviewVisible := false
            SaveConfig()
        }
        try
            A_TrayMenu.Rename("隐藏预览窗口", "显示预览窗口")
        catch
            {}
    }
}

; ===== 切换预览模式 =====
TogglePreviewMode(*) {
    global PreviewMode, PreviewGui, PreviewVisible
    ; 切换模式
    if (PreviewMode = "full")
        PreviewMode := "mapped"
    else
        PreviewMode := "full"
    SaveConfig()
    ; 重建预览窗口
    RebuildPreview()
    ; 更新菜单文本
    modeText := (PreviewMode = "full") ? "全键盘" : "仅映射键"
    TrayTip "预览模式", "已切换为" modeText, 1
    SetTimer(DismissTrayTip, -2000)
}

; ===== 重建预览窗口 =====
RebuildPreview() {
    global PreviewGui, KeyPreviewControls, KeyPreviewColors, PreviewVisible, PreviewX, PreviewY, KeyPreviewCtrlToKey, lastHoveredKey, KeyPreviewSubControls
    ; 保存当前窗口状态
    wasVisible := PreviewVisible
    oldX := PreviewX
    oldY := PreviewY
    ; 销毁旧窗口
    if (PreviewGui) {
        PreviewGui.Destroy()
        PreviewGui := 0
        KeyPreviewControls := Map()
        KeyPreviewColors := Map()
    }
    ; 重建
    CreatePreviewWindow()
    ; 恢复窗口位置
    if (wasVisible && PreviewGui) {
        PreviewGui.Show("NA x" oldX " y" oldY)
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

; 鼠标移动：悬浮高亮
OnPreviewMouseMove(wParam, lParam, msg, hwnd) {
    global PreviewGui, KeyPreviewControls, KeyPreviewSubControls, KeyPreviewHwndToKey, lastHoveredKey, KeyMapping

    if (!PreviewGui)
        return

    ; 检查是否属于预览窗口
    parentHwnd := DllCall("GetAncestor", "ptr", hwnd, "uint", 2, "ptr")
    if (parentHwnd != PreviewGui.Hwnd)
        return

    ; 获取光标在预览窗口客户区的位置
    pt := Buffer(8)
    DllCall("GetCursorPos", "ptr", pt)
    DllCall("ScreenToClient", "ptr", PreviewGui.Hwnd, "ptr", pt)
    clientX := NumGet(pt, 0, "int")
    clientY := NumGet(pt, 4, "int")

    ; 查找光标下的子控件（ChildWindowFromPoint 获取 hwnd）
    ; 打包 POINT 结构：x(低32位) + y(高32位)
    pt64 := (clientY << 32) | (clientX & 0xFFFFFFFF)
    childHwnd := DllCall("ChildWindowFromPoint", "ptr", PreviewGui.Hwnd, "int64", pt64, "ptr")

    if (!childHwnd || !KeyPreviewHwndToKey.Has(childHwnd)) {
        ; 鼠标离开按键区域，恢复上一个悬浮键
        if (lastHoveredKey != "")
            RestoreKeyFont(lastHoveredKey)
        lastHoveredKey := ""
        return
    }

    ; 查找 hwnd 对应的物理键
    keyName := KeyPreviewHwndToKey[childHwnd]
    if (keyName = lastHoveredKey)
        return

    ; 恢复上一个悬浮键
    if (lastHoveredKey != "")
        RestoreKeyFont(lastHoveredKey)

    ; 高亮当前悬浮键（整体放大）
    ctrl := KeyPreviewControls[keyName]
    ctrl.SetFont("s18 bold c00CC00")
    if (KeyPreviewSubControls.Has(keyName)) {
        subCtrl := KeyPreviewSubControls[keyName]
        subCtrl.SetFont("s12 c00CC00")
    }
    lastHoveredKey := keyName
}

; 恢复按键字体到默认样式
RestoreKeyFont(keyName) {
    global KeyPreviewControls, KeyPreviewSubControls, KeyMapping
    if (!KeyPreviewControls.Has(keyName))
        return
    ctrl := KeyPreviewControls[keyName]
    hasMapping := KeyMapping.Has(keyName)
    if (hasMapping)
        ctrl.SetFont("s14 bold cFFFFFF")
    else
        ctrl.SetFont("s14 bold c666666")
    if (KeyPreviewSubControls.Has(keyName)) {
        subCtrl := KeyPreviewSubControls[keyName]
        subCtrl.SetFont("s12 cB0D4FF")
    }
}

; 预览窗口右键菜单
ShowPreviewContextMenu(*) {
    previewMenu := Menu()
    previewMenu.Add("透明度 50%", SetTransparency50)
    previewMenu.Add("透明度 70%", SetTransparency70)
    previewMenu.Add("透明度 90%", SetTransparency90)
    previewMenu.Add()
    previewMenu.Add("关闭预览", (*) => HidePreview())
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
    global PreviewGui, KeyPreviewControls, KeyMapping, lastHighlightedKey

    if (!PreviewGui)
        return

    ; 恢复上次高亮的键
    if (lastHighlightedKey != "" && KeyPreviewControls.Has(lastHighlightedKey)) {
        ctrl := KeyPreviewControls[lastHighlightedKey]
        hasMapping := KeyMapping.Has(lastHighlightedKey)
        if (hasMapping)
            ctrl.SetFont("s14 bold cFFFFFF")
        else
            ctrl.SetFont("s14 bold c666666")
    }

    ; 高亮当前按下的键
    if (KeyPreviewControls.Has(originalKey)) {
        ctrl := KeyPreviewControls[originalKey]
        ctrl.SetFont("s18 bold cFFFF00")
        lastHighlightedKey := originalKey
        SetTimer(ResetHighlight, -500)
    } else {
        lastHighlightedKey := ""
    }
}

; 500ms 后恢复高亮
ResetHighlight(*) {
    global KeyPreviewControls, KeyMapping, lastHighlightedKey
    if (lastHighlightedKey != "" && KeyPreviewControls.Has(lastHighlightedKey)) {
        ctrl := KeyPreviewControls[lastHighlightedKey]
        hasMapping := KeyMapping.Has(lastHighlightedKey)
        if (hasMapping)
            ctrl.SetFont("s14 bold cFFFFFF")
        else
            ctrl.SetFont("s14 bold c666666")
        lastHighlightedKey := ""
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
        SetTimer(DismissTrayTip, -2000)
    }
}

; ===== 打开配置文件 =====
OpenConfig(*) {
    Run(CONFIG_PATH)
}

; ===== 重置为默认映射 =====
ResetKeyMapping(*) {
    global KeyMapping
    result := MsgBox("确定要重置按键映射为默认配置吗？`n自定义的映射将被覆盖。", "重置确认", 0x24)
    if (result != "Yes")
        return
    SetDefaultKeyMapping()
    SaveConfig()
    TrayTip "已重置", "按键映射已恢复为默认配置", 1
    SetTimer(DismissTrayTip, -2000)
}

; ===== 重新加载配置 =====
ReloadConfig(*) {
    global KeyMapping, PreviewGui, KeyPreviewControls, KeyPreviewColors
    if !FileExist(CONFIG_PATH) {
        TrayTip "无配置", "未找到配置文件", 1
        SetTimer(DismissTrayTip, -2000)
        return
    }
    ; 保存旧映射键列表，用于清理热键
    oldKeys := []
    for k, v in KeyMapping
        oldKeys.Push(k)
    ; 重新加载配置
    KeyMapping := Map()
    LoadConfig()
    ; 关闭旧映射中已移除键的热键
    for idx, k in oldKeys {
        if !KeyMapping.Has(k)
            Hotkey("~$*" k, "Off")
    }
    ; 注册新映射的热键
    for originalKey, mappedKey in KeyMapping {
        fn := KeyHandler.Bind(originalKey)
        Hotkey("~$*" originalKey, fn)
    }
    ; 重建预览窗口
    RebuildPreview()
    TrayTip "已重新加载", "配置已从 INI 文件重新加载", 1
    SetTimer(DismissTrayTip, -2000)
}

; ===== 关闭托盘通知 =====
DismissTrayTip(*) {
    TrayTip()
}

; ===== 打开脚本 =====
OpenScript(*) {
    Edit()
}

; ===== 重启脚本 =====
RestartScript(*) {
    Reload()
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
