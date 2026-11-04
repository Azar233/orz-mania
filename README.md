# orz!mania

<p align="center">
  <img src="assets/branding/icon.svg" width="160" alt="orz!mania 樱花机器人图标">
</p>

<p align="center">
  基于仓颉与 SDL3 的轻量化多轨下落式音游。<br>
  导入 osu!mania 谱面，选曲、试听，然后跟随节奏落键。
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

从本地歌曲包的 EXF.mp3 约 **01:46–01:51** 截取五秒，在原生 SDL 窗口中实时自动演示；使用默认 DFJK 与 1500 px/s 滚速。GIF 展示实际运行画面，不是完整曲目或真人游玩成绩，也不包含声音。

![EXF 实际运行 GIF：密集四轨音符、判定心跳与右侧按键轨迹](docs/media/gameplay.gif)

**选曲与滚动**

同一首歌的谱面以抽屉收纳，歌曲条平滑滚动、错位叠放；切歌循环试听，同曲切难度保持连续播放。超长歌名在左栏内缓慢往返显示。

![选曲 GIF：上下滚动歌曲条、背景切换与选中效果](docs/media/library.gif)

- 支持 **1K–9K**、单键与长按、六档判定、连击和准确率。
- 各键数独立绑定；支持判定偏移、200–2500 px/s 滚速、Enter 跳过长前奏。
- 窗口可缩放，支持高 DPI、帧率限制、垂直同步和中英文切换。
- 选曲图片解码与试听加载异步处理；缩略图、大背景分别使用有界缓存。

## 轻量化设计

- **原生桌面路径**：仓颉处理游戏与界面逻辑，SDL3 直接承担窗口、绘制和音频，不引入浏览器 UI 运行时。
- **按需使用资源**：曲库仅绘制可见条目；歌曲条小封面与全屏背景分开缓存，分别限制为32张256×192、4张2560×1440以内，不随浏览曲目无限增长。
- **压缩音频播放**：保留压缩音频，播放时解码，避免默认把整首长曲展开成 PCM 驻留内存。
- **让加载避开滚动帧**：图片解码、缩放与试听文件加载各使用一个仓颉异步任务，合并当前需求并丢弃过期结果；GPU纹理上传留在SDL主线程。
- **减少重复工作**：复用素材与绘制缓冲，歌名宽度只在内容变化时测量；短歌名不启用滚动，稳定视口不重复打开图片和音频。
- **按设备调整**：滚速、帧率上限、VSync和高DPI独立控制；支持已有.osz曲库，不依赖本机安装osu!或读取其数据库。

轻量化是当前实现的取舍与优化方向，不代表固定内存上限或所有设备上的零卡顿。可用后文的滚动采样命令检查自己的运行环境。

## 运行

需要 **Windows x64** 和 **仓颉 SDK 1.0.5**。SDL 绑定源码、Windows 原生依赖及对应许可随仓库提供；SDK 单独安装。

```powershell
git clone https://github.com/Azar233/orz-mania.git
cd orz-mania
cjpm run
```

若尚未加载 SDK 环境：

```powershell
$env:CANGJIE_HOME = 'C:\path\to\cangjie'
. "$env:CANGJIE_HOME/envsetup.ps1"
cjpm run
```

也可运行 `run.cmd`：已有本机构建时直接启动，否则先构建。构建会从 SVG 生成各尺寸应用图标，并准备 SDL 与仓颉运行库。

**仓库不附带歌曲。** 首次启动在 **Esc → 曲库** 导入自己的歌曲包，然后展开歌曲、选择谱面，按 Enter 或双击开始。

## 导入与操作

支持 `.osz`、`.osu`、单首歌曲目录及 Songs 目录；也可直接拖入窗口。导入的音频、背景和谱面保存在本地 `Songs/`，不会加入 Git。

```powershell
powershell -ExecutionPolicy Bypass -File tools/import-songs.ps1 -Source 'D:\Maps\song.osz'
```

仅加载有效的 **Mode:3 原生 osu!mania 谱面**。已在项目 Songs 内的路径只刷新索引；外部来源重复导入会新建目录，避免覆盖原文件。项目不读取本机 osu! 数据库，也不计算、同步或展示星级。

| 操作 | 用途 |
| --- | --- |
| ↑ / ↓、滚轮 | 浏览歌曲与展开的谱面 |
| 点击歌曲、← / → | 展开或收起同曲谱面 |
| Enter / 双击谱面 | 开始游玩 |
| D F J K | 默认 4K 按键，可重新绑定 |
| Enter（长前奏期间） | 跳至首个音符前约两秒 |
| Esc（游玩中） | 暂停；再次按 Esc 继续 |
| Retry / R（暂停中） | 重新开始本曲 |
| Quit / Q（暂停中） | 返回选曲 |
| I / O（选曲中） | 导入文件夹 / 谱面文件 |

暂停界面保留原皮肤的 Retry / Quit 素材，只显示这两个操作。

![当前暂停界面：皮肤 Retry 与 Quit](docs/media/pause.png)

## 判定与计分

以下是 **当前项目实际实现**，不是 osu!mania 官方判定的完整复刻。时间单位为毫秒；`OD` 读取谱面 `OverallDifficulty`，范围 0–10。误差为当前游戏时间减去音符时间，评级使用其绝对值；公式转换到整数毫秒时向下取整，按表格从上向下匹配。

| 判定 | 最大绝对误差 | OD 5 示例 | 权重 |
| --- | --- | --- | --- |
| PERFECT | 16 | ≤16 ms | 320 |
| GREAT | floor(64 − 3 × OD) | >16 且 ≤49 ms | 300 |
| GOOD | floor(97 − 3 × OD) | >49 且 ≤82 ms | 200 |
| OK | floor(127 − 3 × OD) | >82 且 ≤112 ms | 100 |
| MEH | floor(188 − 3 × OD) | >112 且 ≤173 ms | 50 |
| MISS | 超出命中窗口，或音符超时未命中 | >173 ms / 漏键 | 0 |

**长按规则**：头部在命中窗口内按下后进入保持状态；在尾部前剩余 **超过 100ms** 时松开记 MISS，剩余 **不超过 100ms** 时松开可完成，持续按住到尾部也会自动完成。长按只算一个对象，在完成时按头部命中精度结算一次；目前没有独立的松键精度评级，也没有中途 tick 计分。

- **准确率**：已判定权重总和 ÷（320 × 已判定对象数），显示到百分数小数点后两位，按整数运算截断。
- **分数**：权重总和 × 1,000,000 ÷（320 × 谱面对象总数），整数截断，满分 1,000,000。
- **连击**：非 MISS 对象完成后加一；MISS 清零。长按在尾部结算时增加连击。
- **时间偏移**：支持 ±300ms、每步 5ms。负值让谱面落后音乐，正值让谱面领先音乐。视觉滚速不改变判定窗口。

## 设置

**Esc → 设置**：滚速、判定偏移、音量、自动演示、中文 / English。关闭菜单后保存到本地 `settings.cfg`；该文件不上传。

![当前设置页：统一参数布局、语言切换](docs/media/settings.png)

**按键绑定**：1K–9K 独立配置，点击键帽后录入；重复绑定会被拒绝，Esc 取消录入，可恢复当前键数默认值。

![当前按键绑定页](docs/media/bindings.png)

**显示**：60 / 120 / 144 / 165 / 240 / 360 FPS、不限帧或自定义 30–2000 FPS；独立切换 VSync 和 FPS / 帧耗时显示。实际刷新仍受显示器、系统与驱动影响。

![当前显示设置页](docs/media/display.png)

菜单键盘操作：Tab 换页，↑ / ↓ 选择，← / → 调整；自定义 FPS 输入后 Enter 确认、Esc 取消。

## 开发与验证

```powershell
powershell -ExecutionPolicy Bypass -File tools/build.ps1 -Verify
powershell -ExecutionPolicy Bypass -File tools/verify-import.ps1
```

`-Verify` 使用内置谱面片段检查按键、长按、提前释放、重叠长条、时间边界等逻辑；有本地曲库时也检查导入谱面的自动判定结果。

准备好本地曲库并保存设置后，可执行受影响的交互回归：

```powershell
./target/release/bin/main.exe --ui-check
./target/release/bin/main.exe --scroll-check current
```

滚动检查需要至少三首歌曲，以验证上下遍历、图片缓存、试听切换和资源释放；测试不会生成截图。临时记录写入被 Git 忽略的 `artifacts/`。

README 展示素材来自 `--readme-media` 原生录制，之后用 Python + Pillow 编码：

```powershell
./target/release/bin/main.exe --readme-media
python tools/encode-readme-media.py
```

该录制入口需要本地已有上面指定的 EXF 谱面。UI 修改请遵循 [项目约定](AGENTS.md) 与 [UI 规范](docs/UI_GUIDELINES.md)。

## 当前范围与素材

目前使用恒定滚速；尚不支持 TimingPoints 变速、hit samples、视频、故事板、Mods、标准模式转谱、失败血条、成绩存档或在线服务。

歌曲、音频、完整背景和 osu! 本地数据库不随仓库分发。README 的短时无声 GIF 使用用户本地歌曲包运行画面，音乐、谱面和画作权利仍归原作者；皮肤与依赖各自保留原作者和许可说明，详见 [THIRD_PARTY.md](THIRD_PARTY.md)。

项目图标按用户提供的 PNG 重绘为 SVG。当前原创代码尚未声明统一开源许可证；仓库可公开浏览不等于所有代码与素材获得任意再分发授权。
