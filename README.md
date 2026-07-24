# 左手单手输入工具

基于 AutoHotkey v2 的左手单手输入方案——**单击原键，双击对称键**。

## 快速开始

1. 下载安装 [AutoHotkey v2](https://www.autohotkey.com/download/)
2. 双击 `LeftHandSymmetry.ahk` 运行
3. 托盘出现绿色图标，表示已启动

## 使用方法

| 操作 | 效果 |
|---|---|
| 按 **CapsLock** | 开启/关闭单手模式 |
| 单击任意字母键 | 输出原键（正常打字） |
| 快速双击同一字母键 | 输出对称键（如双击 `a` → `p`） |
| 右键托盘图标 | 切换模式 / 设置双击时间 / 退出 |

## 预览窗口

激活单手模式后，屏幕会出现一个半透明小窗口：
- **大字**（蓝色）= 当前输出的键（双击时为对称键）
- **小字**（灰色）= 原始按键提示
- 窗口自动跟随光标位置，不遮挡输入区域

## 对称映射规则

键盘左右对称，双击左半键 → 输出右半对称键，反之亦然。

```
Q↔P  W↔O  E↔I  R↔U  T↔Y
A↔'  S↔L  D↔K  F↔J  G↔H
Z↔/  X↔.  C↔,  V↔M  B↔N
```

## 配置说明

脚本顶部可调整的参数：

| 参数 | 默认值 | 说明 |
|---|---|---|
| `DOUBLE_CLICK_TIME` | 220 | 双击判定时间（毫秒），越小越灵敏 |
| `SYMMETRY_HOTKEY` | CapsLock | 切换热键 |
| `PREVIEW_WIN_WIDTH` | 120 | 预览窗口宽度 |
| `PREVIEW_WIN_HEIGHT` | 70 | 预览窗口高度 |
| `OFFSET_X` / `OFFSET_Y` | 20 / 30 | 窗口距光标偏移 |
| `TRANSPARENCY` | 220 | 透明度（0=全透, 255=不透） |

也可通过托盘菜单的"设置双击时间"实时调整。

## 编译为独立 exe

安装 AutoHotkey 后，使用自带的 `Ahk2Exe` 工具：

```
Ahk2Exe.exe /in LeftHandSymmetry.ahk /out LeftHandSymmetry.exe
```

编译后无需安装 AHK 即可运行。

## 系统要求

- Windows 10 / 11
- AutoHotkey v2.0 或更高版本

## 许可

GPLv3
