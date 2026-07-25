# 左手单手输入工具

基于 AutoHotkey v2 的左手单手输入方案——**单击原键，双击对称键**。

## 快速开始

1. 下载安装 [AutoHotkey v2](https://www.autohotkey.com/download/)
2. 双击 `LeftHandSymmetry.ahk` 运行
3. 按 **Alt+R** 切换单手模式

## 使用方法

| 操作 | 效果 |
|---|---|
| 按 **Alt+R** | 开启/关闭单手模式 |
| 单击任意键 | 输出原键（正常打字） |
| 快速双击同一键（220ms 内） | 输出对称键（如双击 `a` → `Backspace`） |
| 右键托盘图标 | 切换模式 / 显示预览 / 设置双击时间 / 退出 |

## 预览窗口

开启单手模式后，屏幕右下角显示半透明预览窗口：

- 显示 **4行×5列** 左手键盘布局（含数字行）
- 蓝色大字显示映射目标键
- 顶部显示 **指位序号**（5=小拇指 → 2=食指）
- 敲击按键时对应位置高亮（橙色，500ms 后恢复）
- 支持 **鼠标左键拖动** 到任意位置
- **右键菜单**：调整透明度（50%/70%/90%）
- 窗口置顶、不抢焦点

## 对称映射规则

### 完整映射表

```
数字行:  1↔0  2↔9  3↔8  4↔7  5↔6
上排:    q↔p  w↔o  e↔i  r↔u  t↔y
中排:    a→Backspace  s↔l  d↔k  f↔j  g↔h
下排:    z→Enter  x→Delete  c↔m  v↔n  (b 不映射)
```

### 特殊键说明

| 物理键 | 单击 | 双击 |
|--------|------|------|
| `a` | a | Backspace（退格） |
| `z` | z | Enter（回车） |
| `x` | x | Delete（删除） |
| `b` | b | b（不映射，保持原样） |

## 配置说明

脚本顶部可调整的参数：

| 参数 | 默认值 | 说明 |
|---|---|---|
| `DOUBLE_CLICK_TIME` | 220 | 双击判定时间（毫秒），越小越灵敏 |
| `SYMMETRY_HOTKEY` | Alt+R | 切换单手模式的热键 |
| `TRANSPARENCY` | 220 | 窗口透明度（0=全透, 255=不透） |

也可通过托盘菜单的"设置双击时间"实时调整。

## 组合键兼容

开启单手模式时，按住 **Ctrl/Alt/Shift/Win** 时按键正常穿透，不影响组合键使用。

## 冲突规避

与 pet 工具（Space/CapsLock 模式）自动兼容——Space 按下或 CapsLock 激活时，单手模式自动让 pet 接管。

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
