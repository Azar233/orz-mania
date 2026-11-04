package orz_mania

import sdl.*
import std.math.abs

func calibrationClamp(value: Int64): Int64 { max(-300,min(300,value)) }
func calibrationRound(value: Int64): Int64 { if (value < 0) { -((-value+2)/5)*5 } else { (value+2)/5*5 } }
func calibrationMedian(values: Array<Int64>,count: Int64): Int64 {
    for (i in 1..count) {
        let value=values[i]; var at=i
        while (at > 0 && values[at-1] > value) { values[at]=values[at-1]; at-- }; values[at]=value
    }
    if (count%2 == 1) { values[count/2] } else { (values[count/2-1]+values[count/2])/2 }
}
class OffsetSamples {
    let values=Array<Int64>(32,repeat: 0)
    let sorted=Array<Int64>(32,repeat: 0)
    let deviation=Array<Int64>(32,repeat: 0)
    var count: Int64=0
    var cursor: Int64=0
    var inliers: Int64=0
    var spread: Int64=0
    var suggestion: Int64=0
    var lastBeat: Int64 = -1
    var lastTap: Int64 = -10000
    var warmUntil: Int64=1500
    var visual=false
    var referenceAudio: Int64=0
    var referenceVisual: Int64=0
    func reset(visual: Bool,audio: Int64,video: Int64,now!: Int64=0): Unit {
        this.visual=visual; referenceAudio=audio; referenceVisual=video
        count=0; cursor=0; inliers=0; spread=0; lastBeat = -1; lastTap = -10000; warmUntil=now+1500
        suggestion=if (visual) { video } else { audio }
    }
    func ready(): Bool { inliers >= 8 && spread <= 25 }
    func add(position: Int64): Bool {
        if (position < warmUntil || position-lastTap < 300) { return false }
        let cue=position+if (visual) { referenceAudio+referenceVisual } else { 0 }
        let beat=(cue+CALIBRATION_PERIOD/2)/CALIBRATION_PERIOD
        let error=cue-beat*CALIBRATION_PERIOD
        if (beat == lastBeat || abs(error) > 300) { return false }
        lastBeat=beat; lastTap=position
        values[cursor]=if (visual) { error } else { -error }
        cursor=(cursor+1)%32; count=min(32,count+1)
        for (i in 0..count) { sorted[i]=values[i] }
        let median=calibrationMedian(sorted,count)
        for (i in 0..count) { deviation[i]=abs(values[i]-median) }
        spread=calibrationMedian(deviation,count)
        let threshold=max(15,spread*3)
        inliers=0
        for (i in 0..count) { if (abs(values[i]-median) <= threshold) { sorted[inliers]=values[i]; inliers++ } }
        suggestion=calibrationClamp(calibrationRound(calibrationMedian(sorted,inliers)))
        true
    }
}
class OffsetCalibration <: Resource {
    let audio: CalibrationAudio
    let samples=OffsetSamples()
    let resumePreview: Bool
    var visual=false
    var showNotes=false
    var sound=true
    var running=false
    var hasChanges=false
    var draftAudio: Int64
    var draftVisual: Int64
    var position: Int64=0
    var message=""
    var closed=false
    init(a: App) {
        draftAudio=a.offset; draftVisual=a.visualOffset
        resumePreview=a.music.playing(); audio=CalibrationAudio(a.music)
        if (resumePreview) { a.music.pause() }
        samples.reset(false,draftAudio,draftVisual)
    }
    func canStart(): Bool { if (visual) { showNotes } else { sound } }
    func canApply(): Bool { hasChanges && (!running || samples.count == 0 || samples.ready()) }
    func start(): Unit {
        if (!canStart()) { return }
        audio.start(sound); position=0; running=true; message=""
        samples.reset(visual,draftAudio,draftVisual)
    }
    func stop(): Unit { audio.stop(); running=false }
    func tick(): Unit {
        if (!running) { return }
        try { position=audio.position() }
        catch (ex: Exception) { stop(); message="校准音频不可用"; println(ex.message) }
    }
    func tap(): Unit {
        if (!running) { return }
        tick()
        if (running && samples.add(position) && samples.ready()) {
            if (visual) { draftVisual=samples.suggestion } else { draftAudio=samples.suggestion }
            hasChanges=true
        }
    }
    func mode(visual: Bool): Unit {
        stop(); this.visual=visual; showNotes=visual; sound = !visual; position=0; message=""
        samples.reset(visual,draftAudio,draftVisual)
    }
    func adjust(delta: Int64): Unit {
        if (visual) { draftVisual=calibrationClamp(draftVisual+delta) } else { draftAudio=calibrationClamp(draftAudio+delta) }
        hasChanges=true
        samples.reset(visual,draftAudio,draftVisual,now: position)
    }
    func cueTime(): Int64 { position+if (visual) { samples.referenceAudio+samples.referenceVisual } else { 0 } }
    public func close(): Unit { if (closed) { return }; audio.close(); running=false; closed=true }
    public func isClosed(): Bool { closed }
}
func calibrationEntryRect(): Rect { Rect(740.0,272.0,112.0,32.0) }
func calibrationModeRect(index: Int64): Rect { Rect(740.0+Float32(index)*128.0,138.0,112.0,32.0) }
func calibrationActionRect(index: Int64): Rect { Rect(308.0+Float32(index)*172.0,540.0,156.0,36.0) }
func calibrationLaneRect(): Rect { Rect(294.0,242.0,180.0,270.0) }
func calibrationStepRect(increase: Bool): Rect { Rect(if (increase) { 674.0 } else { 514.0 },448.0,32.0,32.0) }
func calibrationToggleRect(sound: Bool): Rect { Rect(if (sound) { 868.0 } else { 740.0 },448.0,112.0,32.0) }
func openCalibration(a: App): Unit {
    if (a.screen == 1 || a.screen == 2 || a.dialog.isSome() || a.calibration.isSome()) { return }
    try {
        a.calibration=Some(OffsetCalibration(a)); a.menuOpen=true; a.menuDrag = -1; a.bindingCapture = -1
    } catch (ex: Exception) { a.message="校准音频不可用"; println(ex.message) }
}
func closeCalibration(a: App,resume!: Bool=true): Unit {
    if (let Some(guide) <- a.calibration) {
        let restart=resume && guide.resumePreview && a.screen == 0 && a.music.started
        guide.close(); a.calibration=None
        if (restart) { a.music.resume() }
    }
}
func calibrationKey(a: App,key: Key): Bool {
    match (key) { case Key.Space => return true case _ => () }
    let scan=bindingScancode(codeOf(key))
    for (code in a.keymaps[a.bindingKeys-1]) { if (bindingScancode(code) == scan) { return true } }
    false
}
func handleCalibration(a: App,event: UiEvent): Bool {
    let g=a.calibration.getOrThrow()
    match (event) {
        case UiEvent.KeyDown(Key.Escape,_) => closeCalibration(a)
        case UiEvent.KeyDown(_,true) => ()
        case UiEvent.KeyDown(Key.Enter,_) => if (g.running) { g.stop() } else { g.start() }
        case UiEvent.KeyDown(Key.Left,_) => g.adjust(-5)
        case UiEvent.KeyDown(Key.Right,_) => g.adjust(5)
        case UiEvent.KeyDown(key,_) => if (calibrationKey(a,key)) { g.tap() }
        case UiEvent.MouseDown(MouseButton.Left,x,y) =>
            for (i in 0..2) { if (inRect(x,y,calibrationModeRect(i))) { g.mode(i == 0); return true } }
            for (i in 0..4) { if (inRect(x,y,calibrationActionRect(i))) {
                match (i) {
                    case 0 => g.adjust(-(if (g.visual) { g.draftVisual } else { g.draftAudio }))
                    case 1 => if (g.running) { g.stop() } else { g.start() }
                    case 2 => if (g.canApply()) { a.offset=g.draftAudio; a.visualOffset=g.draftVisual; saveSettings(a); closeCalibration(a) }
                    case _ => closeCalibration(a)
                }
                return true
            } }
            if (inRect(x,y,calibrationStepRect(false))) { g.adjust(-5) }
            else if (inRect(x,y,calibrationStepRect(true))) { g.adjust(5) }
            else if (inRect(x,y,calibrationToggleRect(false))) { g.showNotes = !g.showNotes; if (!g.canStart()) { g.stop() } }
            else if (inRect(x,y,calibrationToggleRect(true))) { g.sound = !g.sound; g.audio.setSound(g.sound); if (!g.canStart()) { g.stop() } }
            else if (inRect(x,y,calibrationLaneRect())) { g.tap() }
        case _ => ()
    }
    true
}
