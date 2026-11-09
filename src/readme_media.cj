package orz_mania

import sdl.*
import sdl.system.PerformanceClock
import std.fs.{Directory,exists,File}
import std.collection.ArrayList

func readmeFrame(w: SdlWindow,path: String): Unit {
    w.renderer.setScale(1.0); w.renderer.resetViewport()
    w.renderer.captureBmp(path)
}
// Native real-time frames for the README only; no user preferences are saved.
func readmeClip(a: App,w: SdlWindow,art: Art,name: String,scroll: Bool,durationMs!: Int64=5000): Unit {
    let dir="artifacts/readme-media/"+name
    if (!exists(dir)) { Directory.create(dir,recursive: true) }
    let times=ArrayList<String>()
    let pacer=FramePacer(); pacer.applySync(a,w.renderer)
    let start=Int64(w.ticks()); var captured: Int64=0; var lastStep: Int64 = -1
    var typed: Int64=0; var searchStarted=false; var searchCleared=false
    while (Int64(w.ticks())-start < durationMs) {
        let frame=PerformanceClock.ticksNanoseconds()
        while (let Some(event) <- w.pollEvent()) {
            match (event) { case UiEvent.Quit | UiEvent.WindowCloseRequested => throw IllegalArgumentException("Media capture interrupted") case _ => () }
        }
        let elapsed=Int64(w.ticks())-start
        if (scroll && elapsed < 3000) {
            let step=elapsed/350
            if (step != lastStep) {
                let span=min(6,max(1,a.rows.size-1))
                let phase=step%(span*2)
                selectLibraryRow(a,if (phase <= span) { phase } else { span*2-phase })
                lastStep=step
            }
        }
        if (scroll && elapsed >= 3000 && !searchCleared) {
            if (!searchStarted) {
                let rect=librarySearchRect()
                let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,rect.x+20.0,rect.y+18.0)); searchStarted=true
            }
            let wanted=min(6,(elapsed-3000)/160+1)
            while (typed < wanted) { let _=handle(a,w,UiEvent.TextInput("flower"[typed..typed+1])); typed++ }
            if (elapsed >= 4500) {
                let rect=librarySearchClearRect()
                let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,rect.x+10.0,rect.y+18.0))
                a.searchFocused=false; setSearchHover(a,false); selectLibraryRow(a,0); searchCleared=true
            }
        }
        a.tick(Int64(w.ticks()))
        if (scroll) { a.preview(async: true) }
        draw(a,w.renderer,art)
        if (elapsed >= captured*50) {
            let number=if (captured < 10) { "00${captured}" } else if (captured < 100) { "0${captured}" } else { captured.toString() }
            readmeFrame(w,dir+"/"+number+".bmp")
            times.add(elapsed.toString()); captured++
        }
        w.renderer.present(); pacer.finish(a,frame)
    }
    File.writeTo(dir+"/times.txt",String.join(times.toArray(),delimiter: "\n").toArray())
    require(captured >= durationMs/50*7/10,"Too few native frames captured")
    println("MEDIA ${name}: ${captured} real-time frames")
}

// Independently played practice excerpts. Speed is changed by the game, never by the GIF encoder.
func capturePracticeMedia(a: App,w: SdlWindow,art: Art): Unit {
    w.setSize(960,540); w.delay(100)
    while (let Some(_) <- w.pollEvent()) {}
    a.english=false; a.framePreset=5; a.vsync=false; a.showFPS=false; a.backgroundOpacity=30
    a.visualOffset=0; a.offset=0; a.speed=1.5; a.keymaps[3]=bindings(4)
    a.back(); filterLibrary(a,"")
    var exf: Int64 = -1; var pupa: Int64 = -1
    for (i in 0..a.charts.size) {
        let c=a.charts[i]
        if (c.version == "Ex-Final v3" && c.audio.endsWith("EXF.mp3")) { exf=i }
        if (c.title.toAsciiLower() == "pupa" && c.version == "Another") { pupa=i }
    }
    require(exf >= 0 && pupa >= 0,"Import EXF and PUPA Another for the README excerpts")
    for ((index,rate,sourceStart,duration,name) in [
        (exf,90,18000,rateTime(30000,90)-rateTime(18000,90),"practice-slow"),
        (pupa,160,0,10000,"practice-fast")
    ]) {
        a.back(); a.selected=index; a.rate=rate; a.autoplay=true
        a.start(Int64(w.ticks())); let p=a.play.getOrThrow()
        let excerpt=rateTime(sourceStart,rate)
        // Earlier objects are omitted from the excerpt, not awarded as synthetic judgements.
        for (note in p.chart.notes) { if (note.time < excerpt) { note.state=2 } }
        while (p.cursor < p.chart.notes.size && p.chart.notes[p.cursor].state == 2) { p.cursor++ }
        a.now=excerpt
        draw(a,w.renderer,art); w.renderer.present(); w.delay(80)
        a.music.play()
        if (sourceStart > 0) { a.music.seek(sourceStart) }
        let sourceBegin=a.music.position(); let position=rateTime(sourceBegin,rate)
        a.timeline.reset(position,PerformanceClock.ticksNanoseconds()); a.now=position
        readmeClip(a,w,art,name,false,durationMs: duration)
        require(p.judged > 10 && p.counts[5] == 0,"Practice excerpt must advance through actual autoplay input")
        println("EXCERPT ${name}: chart=${p.chart.title} / ${p.chart.version}, rate=${rateText(rate)}, source=${sourceBegin}..${a.music.position()} ms, judged=${p.judged}, misses=${p.counts[5]}")
    }
    a.back(); require(art.errors == 0,"Practice media has missing assets")
    println("PASS README practice media / source-time excerpts / native runtime rates / no settings saved")
}
// Compare the same pre-sped chart without applying a second runtime rate.
func captureNoteSkinsMedia(a: App,w: SdlWindow,art: Art): Unit {
    w.setSize(960,540); w.delay(100)
    while (let Some(_) <- w.pollEvent()) {}
    a.english=false; a.framePreset=5; a.vsync=false; a.showFPS=false; a.backgroundOpacity=30
    a.visualOffset=0; a.offset=0; a.speed=1.5; a.showRanking=false; a.keymaps[3]=bindings(4)
    a.back(); filterLibrary(a,"")
    var target: Int64 = -1
    for (i in 0..a.charts.size) {
        let c=a.charts[i]
        if (c.version == "NB4 1.4x" && c.audio.endsWith("Cyber Induction 140.mp3")) { target=i; break }
    }
    require(target >= 0,"Import Cyber Inductance / NB4 1.4x for the skin comparison")
    let names=["skin-circle","skin-diamond","skin-bar","skin-arrows"]
    for (skin in 0..4) {
        a.back(); a.selected=target; a.rate=100; a.noteSkin=skin; a.autoplay=true
        prepareNoteSkin(a,art)
        a.start(Int64(w.ticks())); let p=a.play.getOrThrow()
        a.now=0; draw(a,w.renderer,art); w.renderer.present(); w.delay(80)
        a.music.play()
        let sourceBegin=a.music.position()
        a.timeline.reset(sourceBegin,PerformanceClock.ticksNanoseconds()); a.now=sourceBegin
        readmeClip(a,w,art,names[skin],false,durationMs: 15000)
        require(a.activeRate == 100 && p.judged > 10 && p.counts[5] == 0,"Skin excerpt must use actual original-rate autoplay")
        println("SKIN ${names[skin]}: chart=${p.chart.title} / ${p.chart.version}, runtime=1.00x, source=${sourceBegin}..${a.music.position()} ms, judged=${p.judged}, misses=${p.counts[5]}")
    }
    a.pause(Int64(w.ticks())); draw(a,w.renderer,art); readmeFrame(w,"artifacts/readme-media/pause.bmp")
    a.back(); a.menuOpen=true; a.autoplay=false; a.noteSkin=0
    a.menuPage=0; a.menuFocus=0; draw(a,w.renderer,art); readmeFrame(w,"artifacts/readme-media/menu-0.bmp")
    require(art.errors == 0,"Skin media has missing assets")
    println("PASS README four skins / same chart / first 15 seconds / no settings saved")
}
func captureReadmeMedia(a: App,w: SdlWindow,art: Art): Unit {
    if (!exists("artifacts/readme-media")) { Directory.create("artifacts/readme-media",recursive: true) }
    w.setSize(960,540); w.delay(100)
    while (let Some(_) <- w.pollEvent()) {}
    a.english=false; a.framePreset=5; a.vsync=false; a.showFPS=false; a.backgroundOpacity=30
    a.visualOffset=0; a.offset=0; a.rate=100
    a.back(); filterLibrary(a,""); rebuildLibrary(a); selectLibraryRow(a,0); resetLibraryMotion(a)
    let warm=Int64(w.ticks())
    while (Int64(w.ticks())-warm < 1000) {
        a.tick(Int64(w.ticks())); draw(a,w.renderer,art); w.renderer.present(); w.delay(4)
    }
    readmeClip(a,w,art,"library",true)
    a.music.stop(); a.previewSong=""
    var target: Int64 = -1
    for (i in 0..a.charts.size) {
        if (a.charts[i].version == "Ex-Final v3" && a.charts[i].audio.endsWith("EXF.mp3")) { target=i; break }
    }
    require(target >= 0,"EXF showcase chart is missing")
    a.selected=target; a.speed=1.5; a.offset=0; a.keymaps[3]=bindings(4); a.autoplay=true; a.rate=100
    a.start(Int64(w.ticks())); let p=a.play.getOrThrow()
    let excerpt=rateTime(18000,a.activeRate)
    for (note in p.chart.notes) { if (note.time < excerpt) { note.state=2 } }
    while (p.cursor < p.chart.notes.size && p.chart.notes[p.cursor].state == 2) { p.cursor++ }
    a.music.play(); a.music.seek(rateSource(excerpt,a.activeRate))
    let position=rateTime(a.music.position(),a.activeRate)
    a.timeline.reset(position,PerformanceClock.ticksNanoseconds()); a.now=position
    readmeClip(a,w,art,"gameplay",false,durationMs: 12000)
    require(p.judged > 40 && p.counts[5] == 0,"EXF real-time autoplay excerpt failed")
    a.pause(Int64(w.ticks())); draw(a,w.renderer,art); readmeFrame(w,"artifacts/readme-media/pause.bmp")
    a.back(); a.menuOpen=true; a.autoplay=false
    for (page in [0,3,4]) {
        a.menuPage=page; a.menuFocus=0; a.bindingKeys=4
        draw(a,w.renderer,art); readmeFrame(w,"artifacts/readme-media/menu-${page}.bmp")
    }
    a.menuPage=0; openCalibration(a)
    let guide=a.calibration.getOrThrow(); guide.start()
    let ready=Int64(w.ticks())
    while (Int64(w.ticks())-ready < 1000) {
        a.tick(Int64(w.ticks())); draw(a,w.renderer,art); w.renderer.present(); w.delay(4)
    }
    draw(a,w.renderer,art); readmeFrame(w,"artifacts/readme-media/calibration.bmp")
    closeCalibration(a,resume: false)
    require(art.errors == 0,"README media has missing assets")
    println("PASS README native media / current UI / EXF excerpt / no settings saved")
}
