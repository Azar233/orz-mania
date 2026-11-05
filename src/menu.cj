package orz_mania

import sdl.*
import sdl.dialogs.*
import std.fs.{File, exists}
import std.convert.*

let SPEED_MIN: Int64=200
let SPEED_MAX: Int64=2500
let SPEED_STEP: Int64=50

func loadSettings(a: App): Unit {
    if (!exists("settings.cfg")) { return }
    try {
        let bytes=File.readFrom("settings.cfg")
        require(bytes.size <= 1024,"Settings file is too large")
        let rows=String.fromUtf8(bytes).split("\n")
        require(rows.size >= 3,"Invalid settings")
        let speed=Float64.parse(rows[0].trimAscii())
        let offset=Int64.parse(rows[1].trimAscii())
        let volume=Float64.parse(rows[2].trimAscii())
        require(speed >= Float64(SPEED_MIN)/1000.0 && speed <= Float64(SPEED_MAX)/1000.0 && offset >= -300 && offset <= 300 && volume >= 0.0 && volume <= 1.0,"Settings out of range")
        let keymaps=Array<Array<Int64>>(9,{i => bindings(i+1)})
        if (rows.size >= 12) {
            for (i in 0..9) {
                let fields=rows[i+3].trimAscii().split(",")
                require(fields.size == i+1,"Invalid binding count")
                let keys=Array<Int64>(fields.size,{j => Int64.parse(fields[j])})
                require(validBindings(keys),"Invalid or duplicate bindings")
                keymaps[i]=keys
            }
        }
        var preset: Int64=0; var custom: Int64=240; var sync=false; var stats=false
        if (rows.size > 12 && rows[12].trimAscii().startsWith("display=")) {
            try {
                let fields=rows[12].trimAscii().replace("display=","").split(",")
                require(fields.size == 4,"Invalid display settings")
                preset=Int64.parse(fields[0]); custom=Int64.parse(fields[1])
                let v=Int64.parse(fields[2]); let f=Int64.parse(fields[3])
                require(preset >= 0 && preset < 8 && custom >= 30 && custom <= 2000 && v >= 0 && v <= 1 && f >= 0 && f <= 1,"Display settings out of range")
                sync=v == 1; stats=f == 1
            } catch (_: Exception) { preset=0; custom=240; sync=false; stats=false }
        }
        a.framePreset=preset; a.customFPS=custom; a.vsync=sync; a.showFPS=stats
        a.english=false; a.visualOffset=0; a.rate=100; a.backgroundOpacity=30
        for (row in rows) {
            if (row.trimAscii().startsWith("backgroundOpacity=")) {
                try { let value=Int64.parse(row.trimAscii().replace("backgroundOpacity=","")); require(value >= 0 && value <= 100,"Invalid background visibility"); a.backgroundOpacity=value }
                catch (_: Exception) { a.backgroundOpacity=30 }
            }
            if (row.trimAscii().startsWith("rate=")) {
                try { let value=Int64.parse(row.trimAscii().replace("rate=","")); require(value >= 50 && value <= 200 && value%5 == 0,"Invalid rate"); a.rate=value }
                catch (_: Exception) { a.rate=100 }
            }
            if (row.trimAscii().startsWith("visualOffset=")) {
                try { let value=Int64.parse(row.trimAscii().replace("visualOffset=","")); require(value >= -300 && value <= 300,"Visual offset out of range"); a.visualOffset=value }
                catch (_: Exception) { a.visualOffset=0 }
            }
            if (row.trimAscii().startsWith("language=")) { a.english=row.trimAscii() == "language=en" }
        }
        a.speed=Float32(speed); a.offset=offset; a.music.setVolume(Float32(volume)); a.keymaps=keymaps
    } catch (ex: Exception) { a.message="设置文件无效，已使用默认值"; println(ex.message) }
}
func saveSettings(a: App): Unit {
    try {
        var value="${a.speed}\n${a.offset}\n${a.music.volume}\n"
        for (keys in a.keymaps) {
            value+=String.join(Array<String>(keys.size,{i => keys[i].toString()}),delimiter: ",")+"\n"
        }
        value+="display=${a.framePreset},${a.customFPS},${if (a.vsync) { 1 } else { 0 }},${if (a.showFPS) { 1 } else { 0 }}\n"
        value+="language=${if (a.english) { "en" } else { "zh" }}\n"
        value+="rate=${a.rate}\n"
        value+="visualOffset=${a.visualOffset}\n"
        value+="backgroundOpacity=${a.backgroundOpacity}\n"
        File.writeTo("settings.cfg",value.toArray())
    } catch (ex: Exception) { a.message="无法保存设置："+ex.message; println(a.message) }
}
func openMenu(a: App,ticks: Int64): Unit {
    setSearchHover(a,false); a.searchFocused=false; a.searchComposition=""
    a.brandHover=false
    a.bindingCapture = -1; a.bindingMessage=""; a.rateEditing=false; a.rateMessage=""
    if (!a.charts.isEmpty()) { a.bindingKeys=a.charts[a.selected].keys }
    if (a.screen == 1) { a.pause(ticks) }
    else { a.menuOpen=true; a.menuPage=0; a.menuFocus=0 }
}
func closeMenu(a: App,ticks: Int64): Unit {
    a.bindingCapture = -1; a.displayEditing=false; a.rateEditing=false
    saveSettings(a)
    if (a.screen == 2) { a.resume(ticks) }
    else { a.menuOpen=false; a.menuDrag = -1 }
}
func inRect(x: Float32,y: Float32,left: Float32,top: Float32,w: Float32,h: Float32): Bool {
    x >= left && x < left+w && y >= top && y < top+h
}
// Discrete setting values share one right-aligned size in Settings and Display.
func settingValueRect(top: Float32): Rect { Rect(868.0,top,112.0,32.0) }
func menuActionRect(quit: Bool): Rect { Rect(254.0,if (quit) { 540.0 } else { 496.0 },174.0,36.0) }
func inRect(x: Float32,y: Float32,rect: Rect): Bool { inRect(x,y,rect.x,rect.y,rect.w,rect.h) }
func centeredSettingLabel(a: App,r: Renderer,label: String,top: Float32,active: Bool): Unit {
    text(r,tr(a,label),492.0,top+(settingValueRect(top).h-r.textHeight(pointSize: 17.0))/2.0,
        17.0,color: if (active) { PINK } else { WHITE })
}
func settingValueButton(a: App,r: Renderer,label: String,top: Float32,active!: Bool=false): Unit {
    let rect=settingValueRect(top)
    menuButton(a,r,label,rect.x,rect.y,rect.w,rect.h,active: active)
}
func changeSetting(a: App,row: Int64,delta: Int64): Unit {
    match (row) {
        case 0 => a.speed=Float32(max(SPEED_MIN,min(SPEED_MAX,Int64(a.speed*1000.0+0.5)+delta*SPEED_STEP)))/1000.0
        case 1 => a.offset=max(-300,min(300,a.offset+delta*5))
        case 2 => a.music.setVolume(Float32(max(0,min(100,Int64(a.music.volume*100.0+0.5)+delta*5)))/100.0)
        case 3 => if (a.screen == 0) { a.autoplay = !a.autoplay }
        case 4 => a.english = !a.english
        case 6 => changeRate(a,delta)
        case _ => ()
    }
}
func dragSetting(a: App,x: Float32): Unit {
    let t=max(Float32(0.0),min(Float32(1.0),(x-524.0)/418.0))
    match (a.menuDrag) {
        case 0 => a.speed=Float32(SPEED_MIN+Int64(t*Float32((SPEED_MAX-SPEED_MIN)/SPEED_STEP)+0.5)*SPEED_STEP)/1000.0
        case 1 => a.offset = -300+Int64(t*120.0+0.5)*5
        case 2 => a.music.setVolume(Float32(Int64(t*100.0+0.5))/100.0)
        case _ => ()
    }
}
func libraryAction(a: App,w: SdlWindow,action: Int64): Unit {
    if (a.screen != 0) { a.back(); a.menuOpen=true; a.menuPage=2; return }
    if (a.dialog.isSome()) { return }
    match (action) {
        case 0 => a.dialog=Some(FileDialogs.openFolder(window: Some(w)))
        case 1 => a.dialog=Some(FileDialogs.openFile(options: FileDialogOptions(filters: [FileDialogFilter("osu! beatmap","osz;osu")]),window: Some(w)))
        case _ => a.importPath("Songs")
    }
}
func pauseActionRect(retry: Bool): Rect { Rect(441.0,if (retry) { 250.0 } else { 420.0 },398.0,116.0) }
func handlePause(a: App,w: SdlWindow,event: UiEvent): Bool {
    match (event) {
        case UiEvent.KeyDown(key,repeat) =>
            if (repeat) { return true }
            match (key) {
                case Key.Escape => closeMenu(a,Int64(w.ticks()))
                case Key.Up => a.menuFocus=0
                case Key.Down => a.menuFocus=1
                case Key.Enter => if (a.menuFocus == 0) { a.start(Int64(w.ticks())) } else { a.back() }
                case Key.Letter(82) => a.start(Int64(w.ticks()))
                case Key.Letter(81) => a.back()
                case _ => ()
            }
        case UiEvent.MouseMove(x,y) =>
            if (inRect(x,y,pauseActionRect(true))) { a.menuFocus=0 }
            else if (inRect(x,y,pauseActionRect(false))) { a.menuFocus=1 }
        case UiEvent.MouseDown(MouseButton.Left,x,y) =>
            if (inRect(x,y,pauseActionRect(true))) { a.start(Int64(w.ticks())) }
            else if (inRect(x,y,pauseActionRect(false))) { a.back() }
        case _ => ()
    }
    true
}
func handleMenu(a: App,w: SdlWindow,event: UiEvent): Bool {
    if (a.screen == 2) { return handlePause(a,w,event) }
    if (a.calibration.isSome()) { return handleCalibration(a,event) }
    if (a.rateEditing) { return handleRateEntry(a,event) }
    if (a.displayEditing) { return handleDisplayEntry(a,event) }
    if (a.bindingCapture >= 0) {
        match (event) {
            case UiEvent.KeyDown(Key.Escape,_) => a.bindingCapture = -1; a.bindingMessage=""; a.rateEditing=false; a.rateMessage=""; return true
            case UiEvent.KeyDown(key,repeat) => if (!repeat) { captureBinding(a,key) }; return true
            case _ => ()
        }
    }
    let ticks=Int64(w.ticks())
    match (event) {
        case UiEvent.MouseUp(MouseButton.Left,_,_) => a.menuDrag = -1
        case UiEvent.MouseMove(x,_) => if (a.menuDrag >= 0) { dragSetting(a,x) }
        case UiEvent.DropFile(path,_,_) => if (a.screen == 0) { a.importPath(path); a.menuPage=2 }
        case UiEvent.KeyDown(key,repeat) =>
            if (repeat) { return true }
            match (key) {
                case Key.Escape => closeMenu(a,ticks)
                case Key.Tab => a.menuPage=(a.menuPage+1)%5; a.menuFocus=0; a.menuDrag = -1; a.bindingCapture = -1
                case Key.Up => if (a.menuPage == 0) { moveSettingsFocus(a,-1) } else { a.menuFocus=max(0,a.menuFocus-1) }
                case Key.Down => if (a.menuPage == 0) { moveSettingsFocus(a,1) } else { a.menuFocus=min(if (a.menuPage == 3) { a.bindingKeys-1 } else if (a.menuPage == 2) { 2 } else if (a.menuPage == 4) { 4 } else { 3 },a.menuFocus+1) }
                case Key.Left => if (a.menuPage == 4) { changeDisplay(a,a.menuFocus,-1) } else if (a.menuPage == 0) { changeSetting(a,a.menuFocus,-1) } else if (a.menuPage == 3) { a.menuFocus=max(0,a.menuFocus-1) }
                case Key.Right => if (a.menuPage == 4) { changeDisplay(a,a.menuFocus,1) } else if (a.menuPage == 0) { changeSetting(a,a.menuFocus,1) } else if (a.menuPage == 3) { a.menuFocus=min(a.bindingKeys-1,a.menuFocus+1) }
                case Key.PageUp => if (a.menuPage == 0) { changeSetting(a,1,1) }
                case Key.PageDown => if (a.menuPage == 0) { changeSetting(a,1,-1) }
                case Key.Home => if (a.menuPage == 4 && a.menuFocus == 4) { a.backgroundOpacity=30 } else if (a.menuPage == 0) { if (a.menuFocus == 1) { a.offset=0 } else if (a.menuFocus == 6) { a.rate=100 } }
                case Key.Enter =>
                    if (a.menuPage == 0 && a.menuFocus == 6) { editRate(a) }
                    else if (a.menuPage == 0 && (a.menuFocus == 1 || a.menuFocus == 5)) { openCalibration(a) }
                    else if (a.menuPage == 4) { if (a.menuFocus == 1) { editCustomFPS(a) } else if (a.menuFocus == 4) { editBackgroundOpacity(a) } else { changeDisplay(a,a.menuFocus,1) } }
                    else if (a.menuPage == 3) { a.bindingCapture=min(a.bindingKeys-1,a.menuFocus) }
                    else if (a.menuPage == 2) { libraryAction(a,w,a.menuFocus) }
                    else if (a.menuPage == 0 && a.menuFocus >= 3) { changeSetting(a,a.menuFocus,1) }
                    else { closeMenu(a,ticks) }
                case _ => ()
            }
        case UiEvent.MouseDown(MouseButton.Left,x,y) =>
            for (i in 0..5) {
                if (inRect(x,y,254.0,184.0+Float32(i)*44.0,174.0,36.0)) {
                    a.menuPage=i; a.menuFocus=0; a.menuDrag = -1; a.bindingCapture = -1; return true
                }
            }
            if (inRect(x,y,menuActionRect(false))) { closeMenu(a,ticks); return true }
            if (inRect(x,y,menuActionRect(true))) { return false }
            if (a.screen != 0 && inRect(x,y,254.0,414.0,174.0,36.0)) {
                a.back(); a.menuOpen=true; a.menuPage=2; return true
            }
            if (a.menuPage == 4) {
                for (i in 0..8) {
                    let rect=fpsPresetRect(i)
                    if (inRect(x,y,rect.x,rect.y,rect.w,rect.h)) { a.framePreset=i; a.menuFocus=0; a.displayMessage="" }
                }
                if (inRect(x,y,settingValueRect(326.0))) { a.menuFocus=1; editCustomFPS(a) }
                if (inRect(x,y,backgroundValueRect())) { a.menuFocus=4; editBackgroundOpacity(a) }
                for (increase in [false,true]) { if (inRect(x,y,backgroundStepRect(increase))) { a.menuFocus=4; changeDisplay(a,4,if (increase) { 1 } else { -1 }) } }
                for (i in 0..2) { if (inRect(x,y,settingValueRect(410.0+Float32(i)*62.0))) { a.menuFocus=i+2; changeDisplay(a,i+2,1) } }
            } else if (a.menuPage == 0) {
                if (inRect(x,y,calibrationEntryRect())) { a.menuFocus=5; openCalibration(a); return true }
                if (inRect(x,y,rateValueRect())) { a.menuFocus=6; editRate(a); return true }
                for (increase in [false,true]) { if (inRect(x,y,rateStepRect(increase))) { a.menuFocus=6; changeRate(a,if (increase) { 1 } else { -1 }); return true } }
                for (i in 0..3) {
                    let cy=238.0+Float32(i)*82.0
                    if (inRect(x,y,488.0,cy-14.0,30.0,28.0)) { a.menuFocus=i; changeSetting(a,i,-1) }
                    else if (inRect(x,y,950.0,cy-14.0,30.0,28.0)) { a.menuFocus=i; changeSetting(a,i,1) }
                    else if (inRect(x,y,519.0,cy-15.0,428.0,30.0)) {
                        a.menuFocus=i; a.menuDrag=i; dragSetting(a,x)
                    }
                }
                if (inRect(x,y,settingValueRect(426.0))) { a.menuFocus=3; changeSetting(a,3,1) }
                if (inRect(x,y,settingValueRect(498.0))) { a.menuFocus=4; changeSetting(a,4,1) }
            } else if (a.menuPage == 3) {
                for (i in 0..9) {
                    let rect=bindingModeRect(i)
                    if (inRect(x,y,rect.x,rect.y,rect.w,rect.h)) {
                        a.bindingKeys=i+1; a.menuFocus=0; a.bindingCapture = -1; a.bindingMessage=""; a.rateEditing=false; a.rateMessage=""
                    }
                }
                for (i in 0..a.bindingKeys) {
                    let rect=bindingKeyRect(a.bindingKeys,i)
                    if (inRect(x,y,rect.x,rect.y,rect.w,rect.h)) {
                        a.bindingCapture=i; a.menuFocus=i; a.bindingMessage=""; break
                    }
                }
                if (inRect(x,y,bindingResetRect())) {
                    a.keymaps[a.bindingKeys-1]=bindings(a.bindingKeys); a.bindingCapture = -1; a.bindingMessage="已恢复默认"
                }
            } else if (a.menuPage == 2) {
                for (i in 0..3) {
                    if (inRect(x,y,492.0,218.0+Float32(i)*66.0,488.0,46.0)) { libraryAction(a,w,i); break }
                }
            }
        case _ => ()
    }
    true
}
func menuButton(a: App,r: Renderer,label: String,x: Float32,y: Float32,w: Float32,h: Float32,active!: Bool=false,enabled!: Bool=true): Unit {
    box(r,x,y,w,h,if (active) { Color.rgb(72,42,65) } else { Color.rgb(38,32,47) },radius: 4.0)
    centeredText(r,tr(a,label),Rect(x,y,w,h),16.0,if (!enabled) { MUTED.withAlpha(100) } else if (active) { PINK } else { WHITE })
}
func drawMenu(a: App,r: Renderer,art: Art): Unit {
    if (a.screen == 2) {
        art.image("assets/skin/pause-retry.png",pauseActionRect(true),alpha: if (a.menuFocus == 0) { 255 } else { 195 })
        art.image("assets/skin/pause-back.png",pauseActionRect(false),alpha: if (a.menuFocus == 1) { 255 } else { 195 })
        return
    }
    if (a.calibration.isSome()) { drawCalibration(a,r); return }
    box(r,226.0,116.0,828.0,476.0,Color.rgb(24,20,31),radius: 4.0)
    drawBrandIcon(art,254.0,134.0,30.0)
    text(r,"orz!mania",292.0,136.0,23.0)
    r.fill(Rect(454.0,136.0,1.0,440.0),Color.rgb(53,43,61))
    let tabs=["设置","操作说明","曲库","按键绑定","显示"]
    for (i in 0..5) { menuButton(a,r,tabs[i],254.0,184.0+Float32(i)*44.0,174.0,36.0,active: a.menuPage == i) }
    if (a.screen != 0) { menuButton(a,r,"返回选曲",254.0,414.0,174.0,36.0) }
    for (quit in [false,true]) {
        let rect=menuActionRect(quit)
        menuButton(a,r,if (quit) { "退出游戏" } else { "关闭菜单" },rect.x,rect.y,rect.w,rect.h,active: !quit)
    }
    text(r,tr(a,tabs[a.menuPage]),492.0,140.0,26.0)
    if (a.menuPage == 0) {
        let labels=["下落速度","判定延迟","音乐音量"]
        let values=["${Int64(a.speed*1000.0+0.5)} px/s","${a.offset} ms","${Int64(a.music.volume*100.0+0.5)}%"]
        let fractions: Array<Float32>=[(a.speed-Float32(SPEED_MIN)/1000.0)/(Float32(SPEED_MAX-SPEED_MIN)/1000.0),Float32(a.offset+300)/600.0,a.music.volume]
        for (i in 0..3) {
            let cy=238.0+Float32(i)*82.0
            text(r,tr(a,labels[i]),492.0,cy-43.0,18.0,color: if (a.menuFocus == i) { PINK } else { WHITE })
            centeredText(r,values[i],settingValueRect(cy-48.0),16.0,PINK)
            text(r,"-",497.0,cy-14.0,21.0,color: MUTED)
            text(r,"+",958.0,cy-14.0,21.0,color: MUTED)
            r.fill(Rect(524.0,cy-2.0,418.0,4.0),Color.rgb(67,52,75))
            r.fill(Rect(524.0,cy-2.0,418.0*fractions[i],4.0),PINK)
            r.fillCircle(524.0+418.0*fractions[i],cy,7.0,PINK)
        }
        let calibrationRect=calibrationEntryRect()
        menuButton(a,r,"校准",calibrationRect.x,calibrationRect.y,calibrationRect.w,calibrationRect.h,active: a.menuFocus == 5)
        text(r,tr(a,"负值：谱面落后音乐；正值：谱面领先音乐。每步 5 ms。"),492.0,342.0,12.0,color: MUTED)
        centeredSettingLabel(a,r,"自动演示",426.0,a.menuFocus == 3)
        if (a.screen != 0) { text(r,tr(a,"在选曲界面切换"),650.0,434.0,12.0,color: MUTED) }
        settingValueButton(a,r,if (a.autoplay) { "ON" } else { "OFF" },426.0,active: a.autoplay)
        drawRateSetting(a,r)
        centeredSettingLabel(a,r,"语言",498.0,a.menuFocus == 4)
        settingValueButton(a,r,if (a.english) { "English" } else { "中文" },498.0,active: a.menuFocus == 4)
    } else if (a.menuPage == 1) {
        let left=["选曲 / 开始","游玩","暂停 / 菜单","滚速与延迟","导入歌曲","菜单键盘操作"]
        let right=["Enter 或双击谱面开始；歌曲卡片展开/收起。",if (a.english) { "4K: "+bindingText(a,4)+"; hold until the tail." } else { "4K："+bindingText(a,4)+"；长按保持到尾部。" },"Esc 暂停；前奏期间按 Enter 可跳过。","在设置中拖动滑块，或用 - / + 微调。","在曲库页导入文件夹、.osz 或 .osu。","Tab 换页；↑ ↓ 选择；← → 调整。"]
        for (i in 0..left.size) {
            let y=204.0+Float32(i)*48.0
            text(r,tr(a,left[i]),492.0,y,14.0,color: PINK)
            text(r,tr(a,right[i]),492.0,y+20.0,14.0,color: WHITE)
        }
    } else if (a.menuPage == 4) {
        drawDisplaySettings(a,r)
    } else if (a.menuPage == 3) {
        drawBindings(a,r)
    } else {
        if (a.screen != 0) {
            text(r,tr(a,"结束当前游玩后，即可管理曲库。"),492.0,192.0,16.0,color: MUTED)
            menuButton(a,r,"返回选曲",492.0,218.0,488.0,46.0)
        } else {
            let actions=["导入歌曲文件夹","导入 .osz / .osu","刷新曲库"]
            for (i in 0..3) { menuButton(a,r,actions[i],492.0,218.0+Float32(i)*66.0,488.0,46.0,active: a.menuFocus == i) }
            text(r,tr(a,"也可以将歌曲文件或文件夹拖入窗口。"),492.0,465.0,14.0,color: MUTED)
        }
        r.pushClip(Rect(490.0,495.0,490.0,44.0)); text(r,tr(a,a.message),492.0,500.0,13.0,color: PINK); r.popClip()
    }
}
