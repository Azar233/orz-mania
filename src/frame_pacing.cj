package orz_mania

import sdl.*
import sdl.system.PerformanceClock
import std.convert.*

let FPS_PRESETS: Array<Int64>=[0,60,120,144,165,240,360,-1]
func frameLimit(a: App): Int64 { if (a.framePreset == 7) { a.customFPS } else { FPS_PRESETS[a.framePreset] } }
func frameWait(elapsed: UInt64,limit: Int64): UInt64 {
    if (limit <= 0) { return 0 }
    let budget=UInt64(1000000000)/UInt64(limit)
    if (elapsed < budget) { budget-elapsed } else { 0 }
}
class FramePacer {
    var appliedSync: Int64 = -1
    var sampleStart: UInt64=0
    var samples: Int64=0
    var fps: Float64=0.0
    var milliseconds: Float64=0.0
    func applySync(a: App,r: Renderer): Unit {
        let wanted: Int64=if (a.vsync) { 1 } else { 0 }
        if (wanted == appliedSync) { return }
        try {
            r.setVSync(Int32(wanted))
            require(r.vsync() == Int32(wanted),"Renderer did not accept requested VSync mode")
            appliedSync=wanted; a.displayMessage=""
        } catch (ex: Exception) {
            // Do not report an enabled mode if the backend rejects it.
            a.vsync=false; appliedSync=0
            a.displayMessage="当前渲染设备无法切换此同步模式"
            println("VSync: ${ex.message}")
            r.setVSync(0)
        }
        sampleStart=0; samples=0
    }
    func finish(a: App,start: UInt64): Unit {
        let before=PerformanceClock.ticksNanoseconds()
        let wait=frameWait(before-start,frameLimit(a))
        if (wait > 0) { PerformanceClock.delayPrecise(wait) }
        let end=PerformanceClock.ticksNanoseconds()
        if (sampleStart == 0) { sampleStart=start }
        samples++
        let elapsed=end-sampleStart
        if (elapsed >= 250000000) {
            fps=Float64(samples)*1000000000.0/Float64(elapsed)
            milliseconds=Float64(elapsed)/Float64(samples)/1000000.0
            sampleStart=end; samples=0
        }
    }
    func drawStats(r: Renderer): Unit {
        let ms=Int64(milliseconds*100.0+0.5)
        text(r,"${Int64(fps+0.5)} FPS / ${ms/100}.${if (ms%100 < 10) { "0" } else { "" }}${ms%100} ms",4.0,697.0,11.0,color: WHITE.withAlpha(160))
    }
}
func fpsPresetRect(index: Int64): Rect { Rect(492.0+Float32(index%4)*123.0,218.0+Float32(index/4)*40.0,115.0,32.0) }
func changeDisplay(a: App,row: Int64,delta: Int64): Unit {
    a.displayMessage=""
    match (row) {
        case 0 => a.framePreset=(a.framePreset+delta+8)%8
        case 1 => a.customFPS=max(30,min(2000,a.customFPS+delta*10)); a.framePreset=7
        case 2 => a.vsync = !a.vsync
        case 3 => a.showFPS = !a.showFPS
        case 4 => a.backgroundOpacity=max(0,min(100,a.backgroundOpacity+delta*5))
        case _ => ()
    }
}
func editCustomFPS(a: App): Unit { a.displayOpacity=false; a.displayEditing=true; a.displayFresh=true; a.displayInput=a.customFPS.toString(); a.displayMessage="" }
func backgroundValueRect(): Rect { settingValueRect(548.0) }
func backgroundStepRect(increase: Bool): Rect { Rect(if (increase) { 988.0 } else { 828.0 },548.0,32.0,32.0) }
func backgroundAlpha(percent: Int64): Int64 { max(0,min(100,percent))*255/100 }
func editBackgroundOpacity(a: App): Unit { a.displayOpacity=true; a.displayEditing=true; a.displayFresh=true; a.displayInput=a.backgroundOpacity.toString(); a.displayMessage="" }
func handleDisplayEntry(a: App,event: UiEvent): Bool {
    match (event) {
        case UiEvent.KeyDown(Key.Escape,_) => a.displayEditing=false; a.displayMessage=""
        case UiEvent.KeyDown(Key.Home,_) => if (a.displayOpacity) { a.backgroundOpacity=30; a.displayEditing=false; a.displayMessage="" }
        case UiEvent.KeyDown(Key.Enter,_) =>
            try {
                let value=Int64.parse(a.displayInput)
                if (a.displayOpacity) { require(value >= 0 && value <= 100,"Visibility must be 0–100"); a.backgroundOpacity=value }
                else { require(value >= 30 && value <= 2000,"FPS must be between 30 and 2000"); a.customFPS=value; a.framePreset=7 }
                a.displayEditing=false; a.displayMessage=""
            } catch (_: Exception) { a.displayMessage=if (a.displayOpacity) { "请输入 0–100" } else { "请输入 30–2000 之间的整数" } }
        case UiEvent.KeyDown(Key.Backspace,_) =>
            if (a.displayFresh) { a.displayInput="" } else if (!a.displayInput.isEmpty()) { a.displayInput=a.displayInput[0..a.displayInput.size-1] }
            a.displayFresh=false
        case UiEvent.KeyDown(Key.Digit(code),_) =>
            if (a.displayFresh) { a.displayInput=""; a.displayFresh=false }
            if (a.displayInput.size < (if (a.displayOpacity) { 3 } else { 4 })) { a.displayInput+=String.fromUtf8([UInt8(code)]) }
        case _ => ()
    }
    if (!a.displayEditing) { a.displayOpacity=false }
    true
}
func drawDisplaySettings(a: App,r: Renderer): Unit {
    text(r,tr(a,"帧率上限"),492.0,188.0,17.0,color: if (a.menuFocus == 0) { PINK } else { WHITE })
    let labels=["不限制","60","120","144","165","240","360","自定义"]
    for (i in 0..8) {
        let rect=fpsPresetRect(i)
        box(r,rect.x,rect.y,rect.w,rect.h,if (a.framePreset == i) { Color.rgb(72,42,65) } else { Color.rgb(38,32,47) },radius: 4.0)
        centeredText(r,tr(a,labels[i]),rect,14.0,if (a.framePreset == i) { PINK } else { WHITE })
    }
    centeredSettingLabel(a,r,"自定义 FPS",326.0,a.menuFocus == 1)
    let rect=settingValueRect(326.0)
    box(r,rect.x,rect.y,rect.w,rect.h,Color.rgb(38,32,47),radius: 4.0)
    let fpsEditing=a.displayEditing && !a.displayOpacity
    centeredText(r,if (fpsEditing) { a.displayInput+" |" } else { a.customFPS.toString() },rect,16.0,if (fpsEditing) { PINK } else { WHITE })
    text(r,tr(a,if (a.displayMessage.isEmpty() || a.displayOpacity) { "点击数值输入，Enter 确认，Esc 取消 · 30–2000" } else { a.displayMessage }),492.0,371.0,12.0,color: MUTED)
    let labels2=["垂直同步","显示 FPS / 帧耗时"]
    let enabled=[a.vsync,a.showFPS]
    for (i in 0..2) {
        let y=410.0+Float32(i)*62.0
        centeredSettingLabel(a,r,labels2[i],y,a.menuFocus == i+2)
        settingValueButton(a,r,if (enabled[i]) { "ON" } else { "OFF" },y,active: enabled[i])
    }
    text(r,tr(a,"同步跟随显示器；同时限帧时取实际较低帧率。"),492.0,515.0,12.0,color: MUTED)
    centeredSettingLabel(a,r,"游玩背景可见度",548.0,a.menuFocus == 4)
    let background=backgroundValueRect(); let editing=a.displayEditing && a.displayOpacity
    box(r,background.x,background.y,background.w,background.h,Color.rgb(38,32,47),radius: 4.0)
    centeredText(r,if (editing) { a.displayInput+" |" } else { "${a.backgroundOpacity}%" },background,16.0,if (editing) { PINK } else { WHITE })
    for (increase in [false,true]) { let step=backgroundStepRect(increase); menuButton(a,r,if (increase) { "+" } else { "−" },step.x,step.y,step.w,step.h) }
    if (a.displayOpacity && !a.displayMessage.isEmpty()) { text(r,tr(a,a.displayMessage),710.0,556.0,12.0,color: PINK) }
}
