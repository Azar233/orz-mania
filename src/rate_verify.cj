package orz_mania

import sdl.*
import sdl.system.PerformanceClock
import std.fs.{File,Directory,exists,remove}
import std.math.abs

foreign func MIX_GetTrackFrequencyRatio(track: CPointer<Unit>): Float32

func verifyRate(a: App,w: SdlWindow): Unit {
    let source=parseChart(SCORE_TEST_MAP,"Songs/test/rate.osu")
    let sourceKey=chartScoreKey(SCORE_TEST_MAP.toArray()); source.scoreKey=sourceKey
    for (rate in [50,75,100,125,150,200]) {
        let c=rateChart(source,rate)
        require(c.playbackRate == rate && c.notes.size == source.notes.size && c.keys == source.keys && c.od == source.od,"Rate retains chart layout and difficulty")
        require(c.notes[0].time == rateTime(1000,rate) && c.notes[2].end == rateTime(3000,rate),"Tap, hold head/tail and duration are scaled together")
        require(source.notes[2].time == 2000 && source.notes[2].end == 3000 && source.playbackRate == 100,"Source timings remain unchanged")
        let p=Play(c)
        require(p.grade(16) == 0 && p.grade(17) == 1 && p.window() == 173,"Judgement windows stay in real milliseconds")
        p.press(0,c.notes[0].time); p.release(0,c.notes[0].time)
        p.press(1,c.notes[1].time); p.release(1,c.notes[1].time)
        p.press(2,c.notes[2].time); p.release(2,c.notes[2].end)
        require(p.score == 1000000 && p.judged == 3 && p.assisted == (rate != 100),"Scaled manual inputs complete normally but rate runs are Mods")
    }
    let saved=File.readFrom("settings.cfg"); let chosen=a.selected; let originalRate=a.rate; let auto=a.autoplay
    let old=a.charts[chosen]; let store=a.localScores
    let dir=Directory.createTemp("artifacts").toString(); let testStore=LocalScores(path: dir+"/rate.tsv")
    try {
        a.back(); a.localScores=testStore; a.autoplay=false
        let fixture=parseChart(SCORE_TEST_MAP.replace(",1000,1",",10000,1").replace(",1500,1",",10500,1").replace(",2000,128",",11000,128").replace("3000:","12000:"),old.path)
        fixture.audio=old.audio; fixture.scoreKey=sourceKey; a.charts[chosen]=fixture
        for (rate in [50,100,200]) {
            a.back(); a.rate=rate; a.start(Int64(w.ticks()))
            require(a.activeRate == rate && a.rankedRun == (rate == 100) && a.liveRanking.isSome() == (rate == 100),"Only 1.00x compares with the local leaderboard")
            require(abs(unsafe { MIX_GetTrackFrequencyRatio(a.music.track) }-Float32(rate)/100.0) < 0.001,"Native mixer ratio matches the chart")
            require(a.canSkipIntro(),"Rate-adjusted long intro can be skipped")
            a.skipIntro(); require(abs(a.now-(a.play.getOrThrow().chart.notes[0].time-2000)) < 80,"Intro seek maps real time back to source audio")
            w.delay(120); a.tick(Int64(w.ticks()))
            let clock=PerformanceClock.ticksNanoseconds(); let before=a.now
            w.delay(400); a.tick(Int64(w.ticks()))
            let elapsed=Int64((PerformanceClock.ticksNanoseconds()-clock)/1000000)
            require(abs((a.now-before)-elapsed) < 90,"Real-time judgement clock stays 1ms per real ms at every rate")
            a.pause(Int64(w.ticks())); let frozen=a.now; w.delay(80); a.tick(Int64(w.ticks()))
            require(a.now == frozen,"Pause freezes the mapped clock")
            a.resume(Int64(w.ticks())); w.delay(100); a.tick(Int64(w.ticks()))
            require(a.now > frozen && a.now-frozen < 220,"Resume does not include paused time")
            a.rate=if (rate == 50) { 200 } else { 50 }; a.start(Int64(w.ticks()))
            require(a.activeRate == rate && a.play.getOrThrow().chart.playbackRate == rate,"Retry snapshots the previous run rate")
            if (rate != 100) {
                let p=a.play.getOrThrow(); p.update(p.chart.duration+2000,false); p.assisted=false
                require(!testStore.record(p),"Storage guard independently rejects rate Mods")
                a.finish(p); require(testStore.saves == 0 && !a.scoreSaved,"Rate runs cannot write local scores")
            }
        }
        a.back(); a.preview()
        require(abs(unsafe { MIX_GetTrackFrequencyRatio(a.music.track) }-1.0) < 0.001,"Returning to preview restores normal audio speed")
        a.menuOpen=true; a.menuPage=0
        let value=rateValueRect()
        let _=handleMenu(a,w,UiEvent.MouseDown(MouseButton.Left,value.x+10.0,value.y+10.0))
        require(a.rateEditing,"Playback rate field opens numeric input")
        a.rateInput="0.75"; let _=handleRateEntry(a,UiEvent.KeyDown(Key.Enter,false))
        require(a.rate == 75 && !a.rateEditing,"Decimal input applies a supported rate")
        editRate(a); a.rateInput="2.01"; let _=handleRateEntry(a,UiEvent.KeyDown(Key.Enter,false))
        require(a.rateEditing && a.rate == 75,"Invalid input cannot change the configured rate")
        let _=handleRateEntry(a,UiEvent.KeyDown(Key.Escape,false))
        editRate(a); let _=handleRateEntry(a,UiEvent.KeyDown(Key.Digit(49),false)); let _=handleRateEntry(a,UiEvent.KeyDown(Key.RawScancode(55),false)); let _=handleRateEntry(a,UiEvent.KeyDown(Key.Digit(53),false)); let _=handleRateEntry(a,UiEvent.KeyDown(Key.Enter,false))
        require(a.rate == 150,"Physical decimal key is accepted")
        editRate(a); let _=handleRateEntry(a,UiEvent.KeyDown(Key.Home,false))
        require(a.rate == 100 && !a.rateEditing,"Home also restores normal speed while editing")
        a.menuFocus=6; let _=handleMenu(a,w,UiEvent.KeyDown(Key.Home,false)); require(a.rate == 100,"Home restores 1.00x")
        a.rate=50; changeRate(a,-1); require(a.rate == 50,"Lower bound")
        a.rate=200; changeRate(a,1); require(a.rate == 200,"Upper bound")
        a.rate=125; saveSettings(a); a.rate=100; loadSettings(a); require(a.rate == 125,"Rate setting persists")
        a.menuFocus=3; moveSettingsFocus(a,1); require(a.menuFocus == 6,"Rate follows Autoplay in keyboard navigation")
        moveSettingsFocus(a,1); require(a.menuFocus == 4,"Language follows playback rate")
        let config=String.fromUtf8(File.readFrom("settings.cfg"))
        for (bad in ["0","201","nan","103"]) {
            File.writeTo("settings.cfg",config.replace("rate=125","rate="+bad).toArray()); loadSettings(a)
            require(a.rate == 100,"Invalid optional rate defaults to 1.00x")
        }
        File.writeTo("settings.cfg",config.replace("rate=125\n","").toArray()); loadSettings(a)
        require(a.rate == 100,"Legacy settings default to 1.00x")
        require(!exists(dir+"/rate.tsv") && fixture.notes[0].time == 10000,"Tests never write scores or mutate source timings")
        println("PASS rate: chart scaling / manual holds / real-ms judgement / native 0.50-2.00x clocks / intro seek / pause resume / frozen Retry / score isolation / preview reset / numeric input / bounds / persistence / legacy fallback")
    } finally {
        a.back(); a.charts[chosen]=old; a.selected=chosen; a.localScores=store; a.autoplay=auto
        File.writeTo("settings.cfg",saved); loadSettings(a); a.rate=originalRate
        remove(dir)
    }
}
