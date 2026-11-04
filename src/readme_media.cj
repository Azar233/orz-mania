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
func readmeClip(a: App,w: SdlWindow,art: Art,name: String,scroll: Bool): Unit {
    let dir="artifacts/readme-media/"+name
    if (!exists(dir)) { Directory.create(dir,recursive: true) }
    let times=ArrayList<String>()
    let pacer=FramePacer(); pacer.applySync(a,w.renderer)
    let start=Int64(w.ticks()); var captured: Int64=0; var lastStep: Int64 = -1
    while (Int64(w.ticks())-start < 5000) {
        let frame=PerformanceClock.ticksNanoseconds()
        while (let Some(event) <- w.pollEvent()) {
            match (event) { case UiEvent.Quit | UiEvent.WindowCloseRequested => throw IllegalArgumentException("Media capture interrupted") case _ => () }
        }
        let elapsed=Int64(w.ticks())-start
        if (scroll) {
            let step=elapsed/350
            if (step != lastStep) {
                let span=min(6,max(1,a.rows.size-1))
                let phase=step%(span*2)
                selectLibraryRow(a,if (phase <= span) { phase } else { span*2-phase })
                lastStep=step
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
    require(captured >= 70,"Too few native frames captured")
    println("MEDIA ${name}: ${captured} real-time frames")
}
func captureReadmeMedia(a: App,w: SdlWindow,art: Art): Unit {
    if (!exists("artifacts/readme-media")) { Directory.create("artifacts/readme-media",recursive: true) }
    w.setSize(960,540); w.delay(100)
    while (let Some(_) <- w.pollEvent()) {}
    a.english=false; a.framePreset=5; a.vsync=false; a.showFPS=false
    a.back(); rebuildLibrary(a); selectLibraryRow(a,0); resetLibraryMotion(a)
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
    a.selected=target; a.speed=1.5; a.offset=0; a.keymaps[3]=bindings(4); a.autoplay=true
    a.start(Int64(w.ticks())); let p=a.play.getOrThrow()
    let excerpt: Int64=106000
    for (note in p.chart.notes) { if (note.time < excerpt) { note.state=2 } }
    while (p.cursor < p.chart.notes.size && p.chart.notes[p.cursor].state == 2) { p.cursor++ }
    a.music.play(); a.music.seek(excerpt)
    a.timeline.reset(a.music.position(),PerformanceClock.ticksNanoseconds()); a.now=a.music.position()
    readmeClip(a,w,art,"gameplay",false)
    require(p.judged > 40 && p.counts[5] == 0,"EXF real-time autoplay excerpt failed")
    a.pause(Int64(w.ticks())); draw(a,w.renderer,art); readmeFrame(w,"artifacts/readme-media/pause.bmp")
    a.back(); a.menuOpen=true; a.autoplay=false
    for (page in [0,3,4]) {
        a.menuPage=page; a.menuFocus=0; a.bindingKeys=4
        draw(a,w.renderer,art); readmeFrame(w,"artifacts/readme-media/menu-${page}.bmp")
    }
    require(art.errors == 0,"README media has missing assets")
    println("PASS README native media / current UI / EXF excerpt / no settings saved")
}
