package orz_mania

import std.collection.{ArrayList,HashMap}
import std.convert.*
import std.fs.{File,FileInfo,Directory,exists,remove}
import std.time.DateTime

let LOCAL_SCORE_LIMIT: Int64=20
let SCORE_FILE_HEADER="orz-mania-local-scores-v1"
foreign {
    func SDL_murmur3_32(data: CPointer<Unit>,length: UIntNative,seed: UInt32): UInt32
    func MoveFileExW(from: CPointer<UInt16>,to: CPointer<UInt16>,flags: UInt32): Int32
}
// Content identity, not an anti-cheat signature. Paths and import folder names are excluded.
func chartScoreKey(bytes: Array<UInt8>): String {
    let count=UIntNative(bytes.size)
    let pinned=unsafe { acquireArrayRawData(bytes) }
    let first=unsafe { SDL_murmur3_32(CPointer<Unit>(pinned.pointer),count,UInt32(0)) }
    let second=unsafe { SDL_murmur3_32(CPointer<Unit>(pinned.pointer),count,UInt32(0x9e3779b9)) }
    unsafe { releaseArrayRawData(pinned) }
    "v1:${bytes.size}:${first}:${second}"
}
func scorePathWide(value: String): Array<UInt16> {
    let result=ArrayList<UInt16>()
    for (rune in value.runes()) {
        let code=UInt32(rune)
        if (code < 65536) { result.add(UInt16(code)) }
        else { result.add(UInt16(55296+(code-65536)/1024)); result.add(UInt16(56320+(code-65536)%1024)) }
    }
    result.add(0); result.toArray()
}
// Reuse the same-volume Windows replacement pattern used by the local Firebreak project.
func writeScoreFile(path: String,value: String): Unit {
    let parts=path.replace("\\","/").split("/")
    if (parts.size > 1) {
        let parent=String.join(parts[0..parts.size-1],delimiter: "/")
        if (!exists(parent)) { Directory.create(parent,recursive: true) }
    }
    let pending=path+".writing"
    require(!exists(pending),"Unfinished score save exists: "+pending)
    try {
        File.writeTo(pending,value.toArray())
        let source=scorePathWide(pending); let target=scorePathWide(path)
        let a=unsafe { acquireArrayRawData(source) }; let b=unsafe { acquireArrayRawData(target) }
        let ok=unsafe { MoveFileExW(a.pointer,b.pointer,UInt32(9)) }
        unsafe { releaseArrayRawData(b); releaseArrayRawData(a) }
        require(ok != 0,"Cannot replace score file; original preserved")
    } finally { if (exists(pending)) { remove(pending) } }
}
class LocalScore {
    let score: Int64
    let accuracy: Int64
    let combo: Int64
    let misses: Int64
    let total: Int64
    let date: String
    let scoreText: String
    let accuracyText: String
    let detail: String
    let dateText: String
    init(score: Int64,accuracy: Int64,combo: Int64,misses: Int64,total: Int64,date: String) {
        require(score >= 0 && score <= 1000000 && accuracy >= 0 && accuracy <= 10000 && score/100 == accuracy,"Invalid score or accuracy")
        require(total > 0 && total <= 1000000 && combo >= 0 && combo <= total && misses >= 0 && misses <= total,"Invalid score counts")
        require(!date.isEmpty() && date.size <= 80 && !date.contains("\t") && !date.contains("\n") && !date.contains("\r"),"Invalid score date")
        this.score=score; this.accuracy=accuracy; this.combo=combo; this.misses=misses; this.total=total; this.date=date
        scoreText=score.toString(); accuracyText=percent(accuracy); detail=accuracyText+" · ${combo}x"
        dateText=date[0..min(date.size,16)].replace("T"," ")
    }
    func row(key: String): String { "${key}\t${score}\t${accuracy}\t${combo}\t${misses}\t${total}\t${date}" }
}
func betterScore(score: Int64,accuracy: Int64,combo: Int64,other: LocalScore): Bool {
    scoreOrder(score,accuracy,combo,other.score,other.accuracy,other.combo)
}
func scoreOrder(score: Int64,accuracy: Int64,combo: Int64,otherScore: Int64,otherAccuracy: Int64,otherCombo: Int64): Bool {
    score > otherScore || (score == otherScore && (accuracy > otherAccuracy || (accuracy == otherAccuracy && combo > otherCombo)))
}
func insertLocalScore(rows: ArrayList<LocalScore>,value: LocalScore,newest!: Bool=false): Unit {
    var at: Int64=0
    while (at < rows.size) {
        let old=rows[at]
        if (betterScore(value.score,value.accuracy,value.combo,old)) { break }
        if (newest && !betterScore(old.score,old.accuracy,old.combo,value)) { break }
        at++
    }
    rows.add(value)
    var cursor=rows.size-1
    while (cursor > at) { rows[cursor]=rows[cursor-1]; cursor-- }
    rows[at]=value
    if (rows.size > LOCAL_SCORE_LIMIT) { rows.remove(at: rows.size-1) }
}
class LocalScores {
    let path: String
    let charts=HashMap<String,ArrayList<LocalScore>>()
    let empty=ArrayList<LocalScore>()
    var writable=true
    var status=""
    var revision: Int64=0
    var saves: Int64=0
    var reads: Int64=0
    var lastRank: Int64=0
    var loadedIdentity=""
    init(path!: String="data/local-scores-v1.tsv") {
        this.path=path
        if (!exists(path)) { return }
        try {
            require(FileInfo(path).size <= 16000000,"Score file exceeds 16 MB")
            let bytes=File.readFrom(path); reads++
            loadedIdentity=chartScoreKey(bytes)
            let lines=String.fromUtf8(bytes).split("\n")
            require(!lines.isEmpty() && lines[0].trimAscii() == SCORE_FILE_HEADER,"Unknown score file version")
            require(lines.size <= 50002,"Too many score records")
            for (line in lines[1..]) {
                if (line.trimAscii().isEmpty()) { continue }
                let fields=line.trimAscii().split("\t")
                require(fields.size == 7,"Invalid score row")
                let key=fields[0]; let identity=key.split(":")
                require(identity.size == 4 && identity[0] == "v1" && key.size <= 96,"Invalid chart identity")
                require(number(identity[1]) > 0 && number(identity[1]) <= 16000000,"Invalid chart length")
                let _=UInt32.parse(identity[2]); let _=UInt32.parse(identity[3])
                let value=LocalScore(number(fields[1]),number(fields[2]),number(fields[3]),number(fields[4]),number(fields[5]),fields[6])
                if (!charts.contains(key)) { charts[key]=ArrayList<LocalScore>() }
                insertLocalScore(charts[key],value)
            }
        } catch (ex: Exception) {
            writable=false; status="成绩文件异常，已保留原文件"; println("Local scores: ${ex.message}")
        }
    }
    func forChart(key: String): ArrayList<LocalScore> { if (charts.contains(key)) { charts[key] } else { empty } }
    func record(p: Play): Bool {
        if (!writable || p.chart.playbackRate != 100 || p.assisted || p.chart.scoreKey.isEmpty() || p.judged != p.chart.notes.size) { return false }
        try {
            let key=p.chart.scoreKey
            lastRank=1
            for (old in forChart(key)) { if (scoreOrder(old.score,old.accuracy,old.combo,p.score,p.accuracy(),p.maxCombo)) { lastRank++ } }
            if (lastRank > LOCAL_SCORE_LIMIT) { status="未进入前20"; return false }
            if (exists(path)) {
                require(FileInfo(path).size <= 16000000,"Score file exceeds 16 MB")
                let current=File.readFrom(path); reads++
                require(chartScoreKey(current) == loadedIdentity,"Score file changed externally; refusing to overwrite")
            } else { require(loadedIdentity.isEmpty(),"Score file was removed externally") }
            let rows=ArrayList<LocalScore>()
            for (old in forChart(key)) { rows.add(old) }
            insertLocalScore(rows,LocalScore(p.score,p.accuracy(),p.maxCombo,p.counts[5],p.chart.notes.size,DateTime.now().toString()),newest: true)
            let lines=ArrayList<String>(); lines.add(SCORE_FILE_HEADER)
            for ((other,values) in charts) { if (other != key) { for (value in values) { lines.add(value.row(other)) } } }
            for (value in rows) { lines.add(value.row(key)) }
            let payload=String.join(lines.toArray(),delimiter: "\n")+"\n"
            require(payload.size <= 16000000 && lines.size <= 50001,"Score storage limit reached")
            writeScoreFile(path,payload)
            loadedIdentity=chartScoreKey(payload.toArray())
            charts[key]=rows; revision++; saves++; status=""
            return true
        } catch (ex: Exception) { status="成绩暂未保存"; println("Local scores: ${ex.message}"); return false }
    }
}
class LiveRanking {
    let history: ArrayList<LocalScore>
    let visible=ArrayList<Int64>() // -1 is this run; other values index the saved history.
    var judged: Int64 = -1
    var score: Int64 = -1
    var first: Int64=0
    var position: Int64=1
    var scoreText="0"
    var accuracyText="100.00%"
    var detail="100.00% · 0x"
    var updates: Int64=0
    init(history: ArrayList<LocalScore>) { this.history=history }
    func update(p: Play): Unit {
        if (judged == p.judged && score == p.score) { return }
        judged=p.judged; score=p.score; updates++
        var insertion: Int64=0
        let accuracy=p.accuracy()
        while (insertion < history.size && scoreOrder(history[insertion].score,history[insertion].accuracy,history[insertion].combo,
            p.score,accuracy,p.maxCombo)) { insertion++ }
        position=insertion+1
        first=max(0,min(history.size+1-4,insertion-1)); visible.clear()
        for (index in first..min(history.size+1,first+4)) { visible.add(if (index == insertion) { -1 } else if (index < insertion) { index } else { index-1 }) }
        scoreText=p.score.toString(); accuracyText=percent(p.accuracy()); detail=accuracyText+" · ${p.maxCombo}x"
    }
}
