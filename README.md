# Ambient Dashboard — Übersicht Widget

深色氛围副屏组件，显示时钟、正在播放的音乐专辑封面，以及系统状态。

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
- 打开 系统设置 → 隐私与安全 → 完全磁盘访问权限
- 添加 Übersicht（或终端，如果手动测试脚本）

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
