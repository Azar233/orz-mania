package orz_mania

import sdl.{Renderer,Rect,Color,Pen}
import std.collection.ArrayList

class KeyStroke {
    let lane: Int64
    let start: Int64
    var end: ?Int64
    let counted: Bool
    init(lane: Int64,start: Int64,end!: ?Int64=None,counted!: Bool=true) { this.lane=lane; this.start=start; this.end=end; this.counted=counted }
}
class KeyOverlay {
    let strokes=ArrayList<KeyStroke>()
    let active=Array<?KeyStroke>(9,{_ => Option<KeyStroke>.None})
    let counts=Array<Int64>(9,repeat: 0)
    var peak: Int64=0
    func kps(now: Int64): Int64 {
        var count: Int64=0
        var i=strokes.size
        while (i > 0) {
            i--; let s=strokes[i]
            if (s.start <= now-1000) { break }
            if (s.counted && s.start <= now) { count++ }
        }
        count
    }
    func total(): Int64 { var value: Int64=0; for (count in counts) { value+=count }; value }
    func press(lane: Int64,now: Int64,count!: Bool=true): Unit {
        if (lane < 0 || lane >= 9 || active[lane].isSome()) { return }
        let stroke=KeyStroke(lane,now,counted: count)
        active[lane]=Some(stroke); strokes.add(stroke)
        if (count) { counts[lane]++ }
        peak=max(peak,kps(now))
    }
    func release(lane: Int64,now: Int64): Unit {
        if (lane < 0 || lane >= 9) { return }
        if (let Some(s) <- active[lane]) { s.end=Some(max(s.start,now)); active[lane]=Option<KeyStroke>.None }
    }
    func pulse(lane: Int64,start: Int64,end: Int64): Unit {
        strokes.add(KeyStroke(lane,start,end: Some(end))); counts[lane]++
        peak=max(peak,kps(start))
    }
    func held(lane: Int64,now: Int64): Bool {
        for (s in strokes) {
            if (s.lane == lane && s.start <= now && (s.end.isNone() || s.end.getOrThrow() > now)) { return true }
        }
        false
    }
    func advance(now: Int64): Unit {
        // Keep only visible recent history; long held keys retain their original start.
        var i=0
        while (i < strokes.size) {
            let s=strokes[i]
            if (let Some(end) <- s.end) {
                if (end < now-5000) { strokes.remove(at: i); continue }
            }
            i++
        }
    }
}
func drawKeyOverlay(a: App,p: Play,r: Renderer): Unit {
    let keys=p.chart.keys
    let width: Float32=if (keys > 6) { 232.0 } else { 200.0 }
    let x: Float32=1256.0-width
    let top: Float32=410.0; let bottom: Float32=548.0
    let gap: Float32=4.0
    let lane=(width-Float32(keys-1)*gap)/Float32(keys)
    let overlay=p.keyOverlay
    r.pushClip(Rect(x,top,width,bottom-top))
    for (i in 0..keys) {
        let left=x+Float32(i)*(lane+gap)
        r.fill(Rect(left,top,lane,bottom-top),WHITE.withAlpha(3))
    }
    // Released segments travel upwards, while held segments stay connected to the key.
    for (s in overlay.strokes) {
        let end=if (let Some(value) <- s.end) { min(value,a.now) } else { a.now }
        if (s.start > a.now || end < a.now-3000) { continue }
        let y=bottom-Float32(a.now-end)*0.046
        let height=max(Float32(3.0),Float32(end-s.start)*0.046)
        r.fill(Rect(x+Float32(s.lane)*(lane+gap)+2.0,y-height,lane-4.0,height),
            WHITE.withAlpha(85))
    }
    r.popClip()
    for (i in 0..keys) {
        let rect=Rect(x+Float32(i)*(lane+gap),bottom+4.0,lane,38.0)
        let down=overlay.held(i,a.now)
        r.fill(rect,Color.rgba(235,237,245,if (down) { 75 } else { 18 }))
        r.strokeRect(rect,Pen(color: WHITE.withAlpha(if (down) { 130 } else { 40 }),width: 1.0))
        let color=WHITE.withAlpha(if (down) { 235 } else { 155 })
        let name=compactBindingName(a.keymaps[keys-1][i]).replace("Space","SP").replace("Shift","Sh").replace("Ctrl","C")
        let font=min(Float32(15.0),max(Float32(8.0),18.0*(lane-6.0)/max(Float32(1.0),r.textWidth(name,pointSize: 18.0))))
        r.pushClip(rect)
        centeredBindingText(a,r,name,rect,bottom+7.0,font,color)
        centeredBindingText(a,r,overlay.counts[i].toString(),rect,bottom+26.0,Float32(9.0),color.withAlpha(170))
        r.popClip()
    }
    text(r,"${overlay.kps(a.now)} KPS",x,bottom+54.0,13.0,color: WHITE.withAlpha(175))
    text(r,"${overlay.peak} max",x+77.0,bottom+56.0,10.0,color: MUTED)
    let total=overlay.total().toString()
    text(r,total,x+width-r.textWidth(total,pointSize: 10.0),bottom+56.0,10.0,color: WHITE.withAlpha(130))
}
