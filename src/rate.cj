package orz_mania

import sdl.*
import std.convert.*

// Integer percentages make 1.00x and score eligibility exact.
func rateText(rate: Int64): String { "${rate/100}.${if (rate%100 < 10) { "0" } else { "" }}${rate%100}×" }
func rateTime(source: Int64,rate: Int64): Int64 { if (source < 0) { source } else { (source*100+rate/2)/rate } }
func rateSource(time: Int64,rate: Int64): Int64 { (max(0,time)*rate+50)/100 }
func rateChart(source: Chart,rate: Int64): Chart {
    require(rate >= 50 && rate <= 200 && rate%5 == 0,"Invalid playback rate")
    if (rate == 100) { return source }
    let c=Chart()
    c.scoreKey=source.scoreKey; c.path=source.path; c.title=source.title; c.artist=source.artist
    c.creator=source.creator; c.version=source.version; c.audio=source.audio; c.background=source.background
    c.keys=source.keys; c.od=source.od; c.mode=source.mode; c.holds=source.holds
    c.playbackRate=rate; c.duration=rateTime(source.duration,rate)
    for (n in source.notes) {
        let start=rateTime(n.time,rate)
        let end=if (n.end > n.time) { max(start+1,rateTime(n.end,rate)) } else { start }
        c.notes.add(Note(n.lane,start,end)); c.duration=max(c.duration,end)
    }
    c
}
func rateValueRect(): Rect { settingValueRect(462.0) }
func rateBadgeRect(autoplay: Bool): Rect { Rect(1201.0,if (autoplay) { 181.0 } else { 116.0 },62.0,55.0) }
func rateBadgeColor(rate: Int64): Color { if (rate < 100) { Color.rgb(32,116,76) } else { Color.rgb(155,48,60) } }
func drawRateBadge(a: App,r: Renderer): Unit {
    if (a.activeRate == 100) { return }
    let rect=rateBadgeRect(a.autoplay)
    drawModBadge(r,rect,rateBadgeColor(a.activeRate),a.activeRateText,tr(a,"倍速"))
}
func rateStepRect(increase: Bool): Rect { Rect(if (increase) { 988.0 } else { 828.0 },462.0,32.0,32.0) }
func changeRate(a: App,delta: Int64): Unit { a.rate=max(50,min(200,a.rate+delta*5)) }
func editRate(a: App): Unit { a.rateEditing=true; a.rateFresh=true; a.rateInput=rateText(a.rate).replace("×",""); a.rateMessage="" }
func moveSettingsFocus(a: App,direction: Int64): Unit {
    let order: Array<Int64>=[0,1,5,2,3,6,4]
    for (i in 0..order.size) { if (order[i] == a.menuFocus) { a.menuFocus=order[max(0,min(order.size-1,i+direction))]; return } }
}
func handleRateEntry(a: App,event: UiEvent): Bool {
    match (event) {
        case UiEvent.KeyDown(Key.Escape,_) => a.rateEditing=false; a.rateMessage=""
        case UiEvent.KeyDown(Key.Home,_) => a.rate=100; a.rateEditing=false; a.rateMessage=""
        case UiEvent.KeyDown(Key.Enter,_) =>
            try {
                let value=Float64.parse(a.rateInput)
                require(value >= 0.5 && value <= 2.0,"Rate out of range")
                a.rate=Int64(value*20.0+0.5)*5; a.rateEditing=false; a.rateMessage=""
            } catch (_: Exception) { a.rateMessage="请输入 0.50–2.00" }
        case UiEvent.KeyDown(Key.Backspace,_) =>
            if (a.rateFresh) { a.rateInput=""; a.rateFresh=false }
            else if (!a.rateInput.isEmpty()) { a.rateInput=a.rateInput[..a.rateInput.size-1] }
        case UiEvent.KeyDown(key,false) =>
            let raw=codeOf(key); let code=if (raw == 1055) { 46 } else { raw }
            if ((code >= 48 && code <= 57) || code == 46) {
                if (a.rateFresh) { a.rateInput=""; a.rateFresh=false }
                if (a.rateInput.size < 5) { a.rateInput+=String.fromUtf8([UInt8(code)]) }
            }
        case _ => ()
    }
    true
}
func drawRateSetting(a: App,r: Renderer): Unit {
    centeredSettingLabel(a,r,"游玩倍速",462.0,a.menuFocus == 6)
    let rect=rateValueRect()
    box(r,rect.x,rect.y,rect.w,rect.h,Color.rgb(38,32,47),radius: 4.0)
    centeredText(r,if (a.rateEditing) { a.rateInput+" |" } else { rateText(a.rate) },rect,16.0,if (a.rateEditing || a.rate != 100) { PINK } else { WHITE })
    for (increase in [false,true]) {
        let step=rateStepRect(increase)
        menuButton(a,r,if (increase) { "+" } else { "−" },step.x,step.y,step.w,step.h)
    }
    if (!a.rateMessage.isEmpty()) { text(r,tr(a,a.rateMessage),650.0,469.0,12.0,color: PINK) }
}
