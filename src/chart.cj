package orz_mania

import std.collection.{ArrayList}
import std.fs.{File, exists}
import std.convert.*
import std.math.{abs,sqrt}

func require(ok: Bool, message: String): Unit {
    if (!ok) { throw IllegalArgumentException(message) }
}
func number(s: String): Int64 { Int64.parse(s.trimAscii()) }
func safeAsset(base: String, name: String): String {
    let p = name.replace("\\", "/")
    require(!p.isEmpty() && !p.startsWith("/") && !p.contains(":"), "Invalid asset path")
    for (part in p.split("/")) { require(part != "..", "Asset escapes beatmap folder") }
    base + "/" + p
}
class Note {
    let lane: Int64
    let time: Int64
    let end: Int64
    var broken=false
    var headError: Int64 = 0
    var state: Int64 = 0 // 0 pending, 1 held, 2 judged
    init(lane: Int64, time: Int64, end: Int64) { this.lane=lane; this.time=time; this.end=end }
}
class Chart {
    var playbackRate: Int64=100
    var scoreKey=""
    var path = ""
    var title = "Untitled"
    var artist = "Unknown"
    var creator = "Unknown"
    var version = "Unknown"
    var audio = ""
    var background = ""
    var keys: Int64 = 4
    var od: Float64 = 5.0
    var mode: Int64 = 0
    var duration: Int64 = 0
    var holds: Int64 = 0
    let notes = ArrayList<Note>()
    init() {}
}
func parseChart(text: String, path: String): Chart {
    let c = Chart(); c.path = path
    let pieces = path.replace("\\", "/").split("/")
    let base = String.join(pieces[..pieces.size-1], delimiter: "/")
    var section = ""
    var last: Int64 = -1
    for (raw in text.split("\n")) {
        let line = raw.trimAscii()
        if (line.isEmpty() || line.startsWith("//")) { continue }
        if (line.startsWith("[")) { section=line; continue }
        if (section == "[HitObjects]") {
            let f=line.split(",")
            require(f.size >= 5, "Malformed hit object")
            let x=number(f[0]); let t=number(f[2]); let kind=number(f[3])
            require(x >= 0 && x <= 512 && t >= 0 && t >= last, "Invalid or unsorted hit object")
            require(c.keys >= 1 && c.keys <= 9, "Only 1K-9K mania is supported")
            var end=t
            if ((kind & 128) != 0) {
                require(f.size >= 6, "Missing hold end")
                end=number(f[5].split(":")[0]); require(end > t, "Hold must end after start"); c.holds++
            } else { require((kind & 1) != 0, "Unsupported hit object (mania only)") }
            c.notes.add(Note(min(c.keys-1,x*c.keys/512),t,end)); c.duration=max(c.duration,end); last=t
            continue
        }
        if (section == "[Events]" && line.startsWith("0,0,")) {
            let f=line.split("\"")
            if (f.size >= 3) { c.background=safeAsset(base,f[1]) }
        }
        let f=line.split(":")
        if (f.size < 2) { continue }
        let key=f[0].trimAscii(); let value=String.join(f[1..], delimiter: ":").trimAscii()
        if (section == "[General]") {
            if (key == "Mode") { c.mode=number(value) }
            if (key == "AudioFilename") { c.audio=safeAsset(base,value) }
        }
        if (section == "[Metadata]") {
            match (key) {
                case "Title" => c.title=value
                case "Artist" => c.artist=value
                case "Creator" => c.creator=value
                case "Version" => c.version=value
                case _ => ()
            }
        }
        if (section == "[Difficulty]") {
            if (key == "CircleSize") {
                let keys=Float64.parse(value)
                require(keys >= 1.0 && keys <= 9.0 && keys == Float64(Int64(keys)), "Invalid key count")
                c.keys=Int64(keys)
            }
            if (key == "OverallDifficulty") { c.od=Float64.parse(value) }
        }
    }
    require(c.mode == 3, "Not an osu!mania chart (Mode must be 3)")
    require(c.keys >= 1 && c.keys <= 9 && c.od >= 0.0 && c.od <= 10.0, "Invalid difficulty")
    require(c.notes.size > 0 && !c.audio.isEmpty(), "Chart has no notes or audio")
    c
}
func loadChart(path: String): Chart {
    let bytes=File.readFrom(path); require(bytes.size <= 16000000, "Beatmap exceeds 16 MB")
    let chart=parseChart(String.fromUtf8(bytes),path)
    chart.scoreKey=chartScoreKey(bytes)
    chart
}
func loadCatalog(): ArrayList<Chart> {
    let charts=ArrayList<Chart>()
    if (!exists("Songs/catalog.txt")) { return charts }
    for (raw in String.fromUtf8(File.readFrom("Songs/catalog.txt")).split("\n")) {
        let path=raw.trimAscii()
        if (path.isEmpty()) { continue }
        try {
            let chart=loadChart(path)
            charts.add(chart)
        } catch (ex: Exception) { println("Skipped ${path}: ${ex.message}") }
    }
    charts
}
func bindings(keys: Int64): Array<Int64> {
    match (keys) {
        case 1 => [32]
        case 2 => [70,74]
        case 3 => [70,32,74]
        case 4 => [68,70,74,75]
        case 5 => [68,70,32,74,75]
        case 6 => [83,68,70,74,75,76]
        case 7 => [83,68,70,32,74,75,76]
        case 8 => [65,83,68,70,74,75,76,59]
        case _ => [65,83,68,70,32,74,75,76,59]
    }
}
// ScoreV1: separate score and accuracy weights; cached once, never allocated per judgement.
let HIT_VALUES: Array<Int64>=[320,300,200,100,50,0]
let ACC_VALUES: Array<Int64>=[300,300,200,100,50,0]
let BONUS_VALUES: Array<Int64>=[32,32,16,8,4,0]
let BONUS_CHANGES: Array<Int64>=[2,1,-8,-24,-44,0]
let BONUS_ROOTS=Array<Float64>(101,{i => sqrt(Float64(i))})
let HIT_LABELS=["PERFECT","GREAT","GOOD","OK","MEH","MISS"]
class Play {
    var assisted=false
    let keyOverlay=KeyOverlay()
    let chart: Chart
    var combo: Int64 = 0
    var maxCombo: Int64 = 0
    var bonus: Int64=100
    var scoreUnits: Float64=0.0
    let windows: Array<Int64>
    var earned: Int64 = 0
    var judged: Int64 = 0
    var score: Int64 = 0
    let counts = Array<Int64>(6, repeat: 0)
    let down = Array<Bool>(9, repeat: false)
    let hitAt=Array<Int64>(9,repeat: -9999)
    var judge = "READY"
    var judgeAt: Int64 = -9999
    var error: Int64 = 0
    let offsets=ArrayList<Int64>()
    var cursor: Int64 = 0
    init(chart: Chart) {
        this.chart=chart; assisted=chart.playbackRate != 100
        windows=[16,Int64(64.0-chart.od*3.0),Int64(97.0-chart.od*3.0),Int64(127.0-chart.od*3.0),Int64(151.0-chart.od*3.0),Int64(188.0-chart.od*3.0)]
        for (n in chart.notes) { n.state=0; n.headError=0; n.broken=false }
    }
    func window(): Int64 { windows[5] }
    func grade(delta: Int64): Int64 {
        let d=abs(delta)
        for (g in 0..5) { if (d <= windows[g]) { return g } }
        5
    }
    func holdGrade(n: Note,tailError: Int64): Int64 {
        if (n.broken) { return 4 }
        let head=Float64(abs(n.headError)); let combined=head+Float64(abs(tailError))
        if (head <= Float64(windows[0])*1.2 && combined <= Float64(windows[0])*2.4) { return 0 }
        if (head <= Float64(windows[1])*1.1 && combined <= Float64(windows[1])*2.2) { return 1 }
        if (head <= Float64(windows[2]) && combined <= Float64(windows[2])*2.0) { return 2 }
        if (head <= Float64(windows[3]) && combined <= Float64(windows[3])*2.0) { return 3 }
        4
    }
    func award(g: Int64, now: Int64): Unit {
        counts[g]++; judged++; earned+=ACC_VALUES[g]
        bonus=if (g == 5) { 0 } else { max(0,min(100,bonus+BONUS_CHANGES[g])) }
        scoreUnits+=Float64(HIT_VALUES[g])+Float64(BONUS_VALUES[g])*BONUS_ROOTS[bonus]
        score=min(1000000,Int64(scoreUnits*500000.0/(320.0*Float64(chart.notes.size))+0.5))
        if (g == 5) { combo=0 } else { combo++; maxCombo=max(maxCombo,combo) }
        judge=HIT_LABELS[g]; judgeAt=now
    }
    func press(lane: Int64, now: Int64): Unit {
        if (lane < 0 || lane >= chart.keys || down[lane]) { return }
        update(now,false)
        down[lane]=true; keyOverlay.press(lane,now)
        for (i in cursor..chart.notes.size) {
            let n=chart.notes[i]
            if (n.time > now+window()) { break }
            if (n.lane != lane || n.state == 2) { continue }
            // Re-grabbing a broken hold does not recover its head precision.
            if (n.state == 1) { return }
            error=now-n.time; n.headError=error; offsets.add(error)
            if (grade(error) < 5) { hitAt[lane]=now }
            if (offsets.size > 40) { offsets.remove(at: 0) }
            if (n.end > n.time) { n.state=1; n.broken=grade(error) == 5 }
            else { n.state=2; award(grade(error),now) }
            return
        }
    }
    func release(lane: Int64, now: Int64): Unit {
        if (lane < 0 || lane >= chart.keys || !down[lane]) { return }
        update(now,false)
        down[lane]=false; keyOverlay.release(lane,now)
        for (i in cursor..chart.notes.size) {
            let n=chart.notes[i]
            if (n.time > now+window()) { break }
            if (n.lane == lane && n.state == 1) {
                let delta=now-n.end
                if (delta < -windows[4]) { n.broken=true }
                else { n.state=2; award(if (delta > windows[3]) { 5 } else { holdGrade(n,delta) },now) }
                return
            }
        }
    }
    func update(now: Int64, autoplay: Bool): Unit {
        if (autoplay) { assisted=true }
        for (i in cursor..chart.notes.size) {
            let n=chart.notes[i]
            if (n.time > now+window()) { break }
            if (n.state == 2) { continue }
            if (autoplay && now >= n.time) {
                if (n.state == 0) {
                    keyOverlay.pulse(n.lane,n.time,max(n.time+65,n.end)); hitAt[n.lane]=n.time
                    n.headError=0; n.broken=false; n.state=1; down[n.lane]=n.end > n.time
                }
                if (now >= n.end) { n.state=2; award(0,now); down[n.lane]=false }
                continue
            }
            if (n.state == 0 && now > n.time+windows[3]) {
                if (n.end > n.time) { n.state=1; n.broken=true; n.headError=window()+1 }
                else { n.state=2; award(5,now) }
            }
            // A held tail waits for release; at the late OK boundary resolve it once.
            if (n.state == 1 && now > n.end+windows[3]) {
                n.state=2
                award(if (down[n.lane]) { holdGrade(n,windows[3]) } else { 5 },now)
            }
        }
        while (cursor < chart.notes.size && chart.notes[cursor].state == 2) { cursor++ }
        keyOverlay.advance(now)
    }
    func accuracy(): Int64 { if (judged == 0) { 10000 } else { earned*10000/(300*judged) } }

}
func percent(value: Int64): String { "${value/100}.${if (value%100 < 10) { "0" } else { "" }}${value%100}%" }




