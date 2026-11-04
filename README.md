# Ambient Dashboard — Übersicht Widget

深色氛围副屏组件，显示时钟、正在播放的音乐专辑封面，以及系统状态。

| | |
|---|---|
| 状态 | v0.1.0 — 2026-03 完成，按个人使用需求实现，**不再主动开发** |
| 环境 | macOS + [Übersicht](https://tracesof.net/uebersicht/) |
| 依赖 | 无（纯 bash + AppleScript + 系统自带 `python3`） |
| 许可 | MIT |


## 预览内容

- 🕐 **大字时钟** — 秒级更新，带呼吸感冒号动画
- 🎵 **Now Playing** — 专辑封面 + 歌名 + 歌手 + 专辑名 + 音频可视化条
  - 支持 Apple Music / Spotify
- 📊 **系统状态** — CPU / 内存 / 磁盘（带进度条）/ 网络收发量

---

## 安装步骤

### 1. 安装 Übersicht
https://tracesof.net/uebersicht/

### 2. 复制组件文件夹
```bash
cp -r ambient-dashboard \
  ~/Library/Application\ Support/Übersicht/widgets/
```

### 3. 给脚本添加执行权限
```bash
chmod +x \
  ~/Library/Application\ Support/Übersicht/widgets/ambient-dashboard/get-data.sh
```

### 4. 授权脚本权限（首次）

- **完全磁盘访问权限**：系统设置 → 隐私与安全 → 完全磁盘访问权限 → 添加 Übersicht
  （读取 Music 专辑封面缓存需要）
- **自动化权限**：首次刷新时系统会弹窗询问「Übersicht 想要控制 System Events / Music」，
  必须点允许。没有这一步，音乐区会一直是空的（`osascript` 返回空字符串）。
  漏点了可以到 系统设置 → 隐私与安全 → 自动化 里补勾。

### 5. 刷新组件
在菜单栏 Übersicht 图标 → Refresh All Widgets

### 6. 定位到副屏
右键组件 → Edit Position，拖拽到副屏合适位置

---

## 自定义配置

打开 `ambient-dashboard.jsx`，修改顶部 CONFIG 区：

```js
const CONFIG = {
  width: "1920px",   // 副屏分辨率宽
  height: "1080px",  // 副屏分辨率高
  clockRefresh: 5000,  // 时钟刷新间隔(ms)
  statsRefresh: 8000,  // 系统状态刷新间隔(ms)
};
```

---

## 颜色主题

在 `ambient-dashboard.jsx` 的 StatBar 调用处可修改各指标颜色：

| 指标 | 默认颜色 |
|------|---------|
| CPU  | 蓝色 `#4fc3f7` |
| 内存 | 绿色 `#81c784` |
| 磁盘 | 橙色 `#ffb74d` |
| 网络 | 紫色 `#ce93d8` |

---

## 故障排查

**专辑封面不显示？**
- 确保 Music.app 正在播放（Spotify 目前不支持封面抓取，仅显示文字信息）
- 手动运行脚本测试：`bash ~/Library/Application\ Support/Übersicht/widgets/ambient-dashboard/get-data.sh`

**CPU 数据一直为 0？**
- `top -l 2` 需要采样两次才有数据，脚本已处理，首次加载稍慢属正常

**组件不在副屏上？**
- 在 Übersicht 偏好设置中确认 "Display" 设置对应副屏编号

---

## 已知限制

- **Spotify 不抓封面**：Spotify 的 AppleScript 接口不暴露 artwork 数据，只能显示歌名/歌手/专辑文字。
- **`timeout` 依赖已移除**：macOS 不自带 `timeout`（那是 GNU coreutils）。脚本内置 `TO()` 包装，
  优先用 `timeout`，其次 `gtimeout`，都没有就直接执行，因此在原生 macOS 上也能跑。
- **临时文件**：历史曲线、内存采样、封面缓存在 `${TMPDIR}/uebersicht-ambient/` 下，
  不再写到 `/tmp` 固定文件名，避免多个实例互相覆盖。
- 只测过单显示器 + 一块副屏；多屏不同缩放比例下卡片位置需要手动拖。

## 许可

MIT，见 [LICENSE](LICENSE)。
