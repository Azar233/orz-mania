# orz!mania

<p align="center">
  <img src="assets/branding/icon.svg" width="160" alt="orz!mania 樱花机器人图标">
</p>

<p align="center">
  基于仓颉与 SDL3 的轻量化多轨下落式音游。
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Cangjie-1.0.5-3277AE?style=flat-square" alt="Cangjie 1.0.5">
  <img src="https://img.shields.io/badge/SDL-3-568B42?style=flat-square" alt="SDL 3">
  <img src="https://img.shields.io/badge/keys-1K--9K-E78BAA?style=flat-square" alt="1K–9K">
  <img src="https://img.shields.io/badge/platform-Windows_x64-555555?style=flat-square" alt="Windows x64">
</p>

<p align="center">
  <a href="#实际画面">实际画面</a> · <a href="#轻量化设计">轻量化设计</a> · <a href="#运行">运行</a> · <a href="#导入与操作">导入与操作</a> · <a href="#判定与计分">判定与计分</a> · <a href="#设置">设置</a> · <a href="#开发与验证">开发与验证</a>
</p>

## 实际画面

**游玩片段 · Malody 4K Extra Dan v3 (Pack 2) / Ex-Final v3**

原生运行画面，约五秒自动演示，4K / 1500 px/s。

![EXF 实际运行 GIF：密集四轨音符、判定心跳与右侧按键轨迹](docs/media/gameplay.gif)

**选曲与滚动**

抽屉式曲库、平滑滚动与循环试听，同曲切换难度保持播放。

![选曲 GIF：上下滚动歌曲条、背景切换与选中效果](docs/media/library.gif)

## 轻量化设计

- **原生绘制**：仓颉 + SDL3，支持 1K–9K、长按与自定义键位。
- **按需加载**：只绘制可见条目，图片缓存有界，音乐使用压缩播放。
- **异步处理**：图片与试听加载避开绘制线程，复用素材和绘制缓冲。
- **自由调节**：滚速、判定偏移、帧率、VSync、高 DPI 与中英文切换。
- **本地成绩**：按谱面保存最佳20条手动完赛记录，选曲查看历史榜，游玩时实时比较排名。

## 运行

需要 **Windows x64** 和已配置环境的 **仓颉 SDK 1.0.5**。SDL 依赖随仓库提供。

```powershell
git clone https://github.com/Azar233/orz-mania.git
cd orz-mania
cjpm run
```

也可运行 `run.cmd`。首次启动后在 **Esc → 曲库** 导入歌曲，选择谱面，按 Enter 或双击开始。

## 导入与操作

支持 `.osz`、`.osu` 和歌曲目录，可通过菜单或拖放导入。歌曲保存在本地 `Songs/`，仓库不附带曲目。

| 操作 | 用途 |
| --- | --- |
| ↑ / ↓、滚轮 | 浏览歌曲与展开的谱面 |
| 点击歌曲、← / → | 展开或收起同曲谱面 |
| Enter / 双击谱面 | 开始游玩 |
| D F J K | 默认 4K 按键，可重新绑定 |
| Enter（长前奏期间） | 跳至首个音符前约两秒 |
| Esc（游玩中） | 暂停；再次按 Esc 继续 |
| Tab（游玩中） | 隐藏 / 显示本地排行；游戏按键绑定优先 |
| Retry / Quit（暂停中） | 重新开始 / 返回选曲 |
| I / O（选曲中） | 导入文件夹 / 谱面文件 |

![当前暂停界面：皮肤 Retry 与 Quit](docs/media/pause.png)

成绩保存在本地 `data/local-scores-v1.tsv`，不随 Git 上传。按分数、准确率、最大连击排序；自动演示与中途退出不入榜，鼠标移到选曲页成绩区域可滚动查看。

## 判定与计分

判定使用绝对时间误差，单位 ms；`OD` 来自谱面，范围 0–10。公式向下取整，按表格从上向下匹配。

| 判定 | 最大绝对误差 | OD 5 示例 | 权重 |
| --- | --- | --- | --- |
| PERFECT | 16 | ≤16 ms | 320 |
| GREAT | floor(64 − 3 × OD) | >16 且 ≤49 ms | 300 |
| GOOD | floor(97 − 3 × OD) | >49 且 ≤82 ms | 200 |
| OK | floor(127 − 3 × OD) | >82 且 ≤112 ms | 100 |
| MEH | floor(188 − 3 × OD) | >112 且 ≤173 ms | 50 |
| MISS | 超出命中窗口，或音符超时未命中 | >173 ms / 漏键 | 0 |

**长按**：提前超过 100ms 松开记 MISS；最后 100ms 内松开或保持到结束，按头部精度结算一次。

- **准确率**：已判定权重总和 ÷（320 × 已判定对象数）。
- **分数**：权重总和 × 1,000,000 ÷（320 × 谱面对象总数），整数截断。
- **连击**：成功判定加一，MISS 清零；长按在尾部结算。

## 设置

**基本设置**：200–2500 px/s 滚速、±300ms 判定偏移、音量、自动演示与语言。

**偏移校准**：设置 → 校准，跟随鼓点音押调整判定偏移，或跟随下落标记目押调整视觉偏移。至少 8 次有效输入后给出稳定建议，点击应用保存；两种偏移独立，均支持 ±300ms 范围与 5ms 微调。

![当前设置页：统一参数布局、语言切换](docs/media/settings.png)

**按键绑定**：1K–9K 独立配置，点击键帽录入，Esc 取消。

![当前按键绑定页](docs/media/bindings.png)

**显示**：预设 / 自定义帧率（30–2000 FPS）、不限帧、VSync 与帧率显示。

![当前显示设置页](docs/media/display.png)

按 Esc 打开菜单，关闭后保存设置。Tab 换页，方向键选择与调整。

## 开发与验证

```powershell
powershell -ExecutionPolicy Bypass -File tools/build.ps1 -Verify
powershell -ExecutionPolicy Bypass -File tools/verify-import.ps1
./target/release/bin/main.exe --ui-check
./target/release/bin/main.exe --score-check
./target/release/bin/main.exe --calibration-check
./target/release/bin/main.exe --scroll-check current
```

交互与滚动检查需先导入至少三首歌曲并保存设置。开发约定见 [AGENTS.md](AGENTS.md) 与 [UI 规范](docs/UI_GUIDELINES.md)。

## 素材

图标由用户提供，皮肤与演示画面保留原作者权利。来源及依赖许可见 [THIRD_PARTY.md](THIRD_PARTY.md)；原创代码暂未声明统一开源许可证。
