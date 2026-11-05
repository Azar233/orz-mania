package orz_mania

import sdl.*
import std.collection.ArrayList
import std.fs.{Directory,File,exists,remove}

let SCORE_TEST_MAP="osu file format v14\n[General]\nMode:3\nAudioFilename:test.mp3\n[Difficulty]\nCircleSize:4\nOverallDifficulty:5\n[HitObjects]\n0,0,1000,1,0\n128,0,1500,1,0\n256,0,2000,128,0,3000:0:0:0:\n"
func scoreTestPlay(error: Int64): Play {
    let chart=parseChart(SCORE_TEST_MAP,"Songs/score-test/map.osu")
    chart.scoreKey=chartScoreKey(SCORE_TEST_MAP.toArray())
    let play=Play(chart)
    play.press(0,1000+error); play.release(0,1000+error)
    play.press(1,1500+error); play.release(1,1500+error)
    play.press(2,2000+error); play.release(2,3000)
    require(play.judged == 3,"Score fixture must complete through manual input")
    play
}
func verifyLocalScoreboard(a: App,w: SdlWindow,art: Art): Unit {
    if (!exists("artifacts")) { Directory.create("artifacts",recursive: true) }
    let directory=Directory.createTemp("artifacts").toString()
    let path=directory+"/本地成绩.tsv"
    let original=a.localScores; let selected=a.selected; let maps=a.keymaps
    let autoplay=a.autoplay; let visible=a.showRanking
    try {
        require(rankingHintAlpha(0) == 175 && rankingHintAlpha(1000) == 175 && rankingHintAlpha(1300) > 0 && rankingHintAlpha(1300) < 175 && rankingHintAlpha(1600) == 0 && rankingHintAlpha(50000) == 0,"Tab hint holds briefly then fades out permanently")
        let best=scoreTestPlay(0); let lower=scoreTestPlay(30); let key=best.chart.scoreKey
        let store=LocalScores(path: path)
        require(!exists(path) && store.writable && store.forChart(key).isEmpty(),"First run starts with an empty board without writing files")
        let pending=Play(parseChart(SCORE_TEST_MAP,"Songs/test/map.osu")); pending.chart.scoreKey=key
        require(!store.record(pending) && !exists(path),"Incomplete runs must not be saved")
        require(store.record(lower) && store.record(best) && store.saves == 2,"Completed manual runs are persisted")
        require(lower.accuracy() == 10000 && lower.score < 1000000,"Stored score is independent of accuracy")
        let legacy=directory+"/legacy.tsv"
        let legacyText="orz-mania-local-scores-v1\n"
        File.writeTo(legacy,legacyText.toArray())
        let oldRules=LocalScores(path: legacy)
        require(!oldRules.writable && !oldRules.record(best) && String.fromUtf8(File.readFrom(legacy)) == legacyText,"Legacy rules cannot be mixed or overwritten")
        let loaded=LocalScores(path: path)
        require(loaded.writable && loaded.forChart(key).size == 2 && loaded.forChart(key)[0].score == 1000000,"Scores survive restart in descending order")
        require(loaded.forChart(key)[1].score == lower.score,"Lower result is retained as history")
        require(chartScoreKey(SCORE_TEST_MAP.toArray()) == key && chartScoreKey(SCORE_TEST_MAP.replace("OverallDifficulty:5","OverallDifficulty:6").toArray()) != key,"Chart content changes isolate records")
        File.writeTo(directory+"/a.osu",SCORE_TEST_MAP.toArray()); File.writeTo(directory+"/b.osu",SCORE_TEST_MAP.toArray())
        require(loadChart(directory+"/a.osu").scoreKey == loadChart(directory+"/b.osu").scoreKey,"Moving or reimporting identical content keeps its identity")
        let difficulty=SCORE_TEST_MAP.replace("OverallDifficulty:5","OverallDifficulty:6")
        File.writeTo(directory+"/other.osu",difficulty.toArray())
        let other=loadChart(directory+"/other.osu"); let otherPlay=Play(other)
        otherPlay.press(0,1000); otherPlay.release(0,1000)
        otherPlay.press(1,1500); otherPlay.release(1,1500)
        otherPlay.press(2,2000); otherPlay.release(2,3000)
        require(store.forChart(other.scoreKey).isEmpty() && store.record(otherPlay),"Another difficulty in the same folder has an independent score board")
        let reloaded=LocalScores(path: path)
        require(reloaded.forChart(key).size == 2 && reloaded.forChart(other.scoreKey).size == 1,"Per-difficulty records remain separate after reload")
        let automatic=Play(parseChart(SCORE_TEST_MAP,"Songs/test/auto.osu")); automatic.chart.scoreKey=key
        automatic.update(4000,true)
        let baseline=String.fromUtf8(File.readFrom(path))
        require(!store.record(automatic) && String.fromUtf8(File.readFrom(path)) == baseline,"Autoplay never enters the stored board")
        for (_ in 0..22) { require(store.record(best),"Repeated manual score save") }
        require(store.forChart(key).size == LOCAL_SCORE_LIMIT && LocalScores(path: path).forChart(key).size == LOCAL_SCORE_LIMIT,"Top-20 bound survives reload")
        require(!store.record(lower) && store.status == "未进入前20","Runs below top 20 do not evict better results")
        require(scoreOrder(900000,9000,30,900000,9000,29),"Equal-score ordering uses combo")
        let tied=ArrayList<LocalScore>()
        insertLocalScore(tied,LocalScore(1000000,10000,3,0,3,"2026-01-01"))
        insertLocalScore(tied,LocalScore(1000000,10000,3,0,3,"2026-02-01"),newest: true)
        require(tied[0].date == "2026-02-01","Newest exact tie is inserted first")
        let retained=String.fromUtf8(File.readFrom(path)); let oldCount=store.forChart(key).size
        File.writeTo(path+".writing","unfinished prior save".toArray())
        require(!store.record(best) && String.fromUtf8(File.readFrom(path)) == retained && store.forChart(key).size == oldCount,"Interrupted save preserves the old file and in-memory board")
        remove(path+".writing")
        let corrupt=directory+"/corrupt.tsv"; File.writeTo(corrupt,"unknown format".toArray())
        let invalid=LocalScores(path: corrupt)
        require(!invalid.writable && !invalid.record(best) && String.fromUtf8(File.readFrom(corrupt)) == "unknown format","Unknown/corrupt storage is never overwritten")
        let concurrent=LocalScores(path: path)
        require(store.record(best),"Original instance can save")
        let latest=String.fromUtf8(File.readFrom(path))
        require(!concurrent.record(best) && String.fromUtf8(File.readFrom(path)) == latest,"External score updates are not silently overwritten")
        let live=LiveRanking(store.forChart(key)); let partial=Play(best.chart)
        live.update(partial); require(live.position == 21 && live.visible.size == 4,"Current low score stays visible below the top 20")
        let updates=live.updates; let reads=store.reads; let saves=store.saves
        for (_ in 0..1000) { live.update(partial) }
        require(live.updates == updates && store.reads == reads && store.saves == saves,"Unchanged frames do no rank rebuild or storage IO")
        partial.press(0,1000); partial.release(0,1000); live.update(partial)
        require(live.updates == updates+1 && live.score == partial.score,"A judgement refreshes the live row")
        let top=LiveRanking(store.forChart(key)); top.update(best)
        require(top.position == 1 && top.visible[0] == -1,"Matching the best final result reaches live rank one")
        for (keys in 1..10) {
            let rect=liveScoreRect(keys,4); let left=535.0-min(Float32(696.0),Float32(keys)*104.0)/2.0
            require(rect.x+rect.w < left && rect.y+rect.h <= 320.0,"Live board must avoid lanes and character region for 1K–9K")
        }
        a.back(); a.localScores=LocalScores(path: directory+"/integration.tsv")
        a.autoplay=false; a.rankedRun=true; a.completionHandled=false
        a.finish(best); a.finish(best)
        require(a.scoreSaved && a.localScores.saves == 1,"Result transition saves exactly once")
        a.completionHandled=false; a.rankedRun=false; a.finish(best)
        require(!a.scoreSaved && a.localScores.saves == 1,"Assisted session flag excludes scores")
        a.completionHandled=false; a.rankedRun=true; a.finish(automatic)
        require(!a.scoreSaved && a.localScores.saves == 1,"Autoplay flag on Play cannot be bypassed by switching modes")
        a.selected=0; resetLibraryMotion(a)
        a.localScores.charts[a.charts[0].scoreKey]=store.forChart(key)
        a.scoreChart=""; syncScorePanel(a)
        require(!showLocalScores(a),"Song header hides local scores")
        let header=a.libraryRow
        let _=handle(a,w,UiEvent.MouseWheel(0.0,-1.0,100.0,560.0))
        require(a.libraryRow == min(a.rows.size-1,header+1),"Hidden score panel does not capture wheel input")
        a.selected=0; syncLibrarySelection(a)
        toggleSongDrawer(a,a.libraryRow)
        selectLibraryRow(a,a.libraryRow+1)
        require(showLocalScores(a),"Selected difficulty exposes its local scores")
        let beforeRow=a.libraryRow
        let _=handle(a,w,UiEvent.MouseWheel(0.0,-0.5,100.0,560.0))
        require(a.scorePage == 0,"Precision wheel accumulates inside the score panel")
        let _=handle(a,w,UiEvent.MouseWheel(0.0,-0.5,100.0,560.0))
        require(a.scorePage == 1 && a.libraryRow == beforeRow,"Score scrolling must not change songs")
        a.scorePage=19; a.selected=1; syncScorePanel(a)
        require(a.scorePage == 0,"Changing difficulty resets the score panel position")
        a.selected=0; a.autoplay=false; a.start(Int64(w.ticks()))
        let attempts=a.localScores.saves
        a.keymaps=Array<Array<Int64>>(9,{i => bindings(i+1)})
        a.keymaps[a.charts[0].keys-1][0]=9
        let shown=a.showRanking
        let _=handle(a,w,UiEvent.KeyDown(Key.Tab,false))
        require(a.showRanking == shown && a.play.getOrThrow().down[0],"A bound Tab must remain a lane key")
        let _=handle(a,w,UiEvent.KeyUp(Key.Tab))
        a.keymaps[a.charts[0].keys-1]=bindings(a.charts[0].keys)
        let _=handle(a,w,UiEvent.KeyDown(Key.Tab,false))
        require(a.showRanking != shown,"Unbound Tab toggles the live board")
        a.showRanking=true
        draw(a,w.renderer,art)
        a.back(); a.menuOpen=false; draw(a,w.renderer,art)
        require(a.localScores.saves == attempts && art.errors == 0,"Aborted runs never save; board resources load")
        println("PASS local scores: persistence / chart identity / top 20 / tie ordering / partial and autoplay exclusion / interrupted and external writes / corrupt-file preservation / event-only live updates / wheel isolation / Tab binding priority / completion exactly once / 1K–9K bounds")
    } finally {
        a.back(); a.localScores=original; a.selected=selected; a.keymaps=maps
        a.autoplay=autoplay; a.showRanking=visible; a.scoreChart=""; a.completionHandled=false
        resetLibraryMotion(a)
    }
}
