package orz_mania

import sdl.*
import sdl.system.PerformanceClock
import std.collection.ArrayList
import std.fs.{File,Directory,exists}
import std.runtime.{getAllocatedHeapSize,getThreadCount,getNativeThreadCount}

// Cold/warm repeated scrolling; records stages without screenshots or saving settings.
func scrollCheck(a: App,w: SdlWindow,art: Art,args: Array<String>): Unit {
    if (!exists("artifacts")) { Directory.create("artifacts",recursive: true) }
    let label=if (args.size > 1) { args[1] } else { "current" }
    require(label == "before" || label == "after" || label == "current","Invalid scroll sample label")
    a.back(); rebuildLibrary(a); a.framePreset=5; a.vsync=false
    let pacer=FramePacer(); pacer.applySync(a,w.renderer)
    let lines=ArrayList<String>(); lines.add("stage,frame_ms,work_ms,preview_ms,draw_ms,present_ms,loads")
    for (stage in ["cold","warm"]) {
        for (frame in 0..480) {
            let start=PerformanceClock.ticksNanoseconds()
            while (let Some(e) <- w.pollEvent()) {
                match (e) { case UiEvent.Quit | UiEvent.WindowCloseRequested => throw IllegalArgumentException("Scroll check interrupted") case _ => () }
            }
            let cycle=(frame/12)%(max(1,a.rows.size-1)*2)
            let row=if (cycle < a.rows.size) { cycle } else { (a.rows.size-1)*2-cycle }
            selectLibraryRow(a,row); a.tick(Int64(w.ticks()))
            let logicEnd=PerformanceClock.ticksNanoseconds()
            let oldLoads=art.loads
            a.preview(async: true)
            let previewEnd=PerformanceClock.ticksNanoseconds()
            draw(a,w.renderer,art)
            let drawEnd=PerformanceClock.ticksNanoseconds()
            w.renderer.present()
            let presentEnd=PerformanceClock.ticksNanoseconds()
            pacer.finish(a,start)
            lines.add("${stage},${Float64(PerformanceClock.ticksNanoseconds()-start)/1000000.0},${Float64(presentEnd-start)/1000000.0},${Float64(previewEnd-logicEnd)/1000000.0},${Float64(drawEnd-previewEnd)/1000000.0},${Float64(presentEnd-drawEnd)/1000000.0},${art.loads-oldLoads}")
        }
    }
    File.writeTo("artifacts/scroll-${label}.csv",String.join(lines.toArray(),delimiter: "\n").toArray())
    require(art.errors == 0,"Scrolling resources must load without errors")
    println("PASS scroll sample ${label}: frames=960, textures=${art.textures.size}, loads=${art.loads}, heap=${getAllocatedHeapSize()}, renderer=${w.renderer.driverName()}")
    verifyScrollLoading(a,w,art)
    a.back()
}

// Reproducible real-window workload. No user settings are saved by this mode.
func benchmark(a: App,w: SdlWindow,art: Art,args: Array<String>): Unit {
    if (!exists("artifacts")) { Directory.create("artifacts",recursive: true) }
    let fps=if (args.size > 1) { number(args[1]) } else { 240 }
    require(fps >= 30 && fps <= 2000,"Benchmark FPS out of range")
    let predecode=args.size > 4 && args[4] == "predecode"
    let marathon=args.size > 2 && args[2] == "marathon"
    if (args.size > 3 && args[3] == "1440p") { w.setSize(2560,1440) }
    a.framePreset=7; a.customFPS=fps; a.vsync=false; a.autoplay=true
    for (i in 0..a.charts.size) {
        if ((marathon && a.charts[i].duration > a.charts[a.selected].duration) || (!marathon && a.charts[i].title == "Grin" && a.charts[i].version == "Piano Concerto")) { a.selected=i }
    }
    resetLibraryMotion(a)
    println("BENCH renderer=${w.renderer.driverName()}, fps=${fps}, marathon=${marathon}, predecode=${predecode}")
    let pacer=FramePacer(); pacer.applySync(a,w.renderer)
    var csv="stage,frame_ms,work_ms,tick_ms,draw_ms,present_ms\n"
    for (stage in ["library","gameplay"]) {
        File.writeTo("artifacts/bench-stage.txt","loading".toArray())
        if (stage == "gameplay") {
            a.start(Int64(w.ticks()))
            if (predecode) { a.music.open(a.charts[a.selected].audio,predecode: true) }
            if (a.canSkipIntro()) { a.skipIntro() }
        }
        else { a.preview() }
        let begin=PerformanceClock.ticksNanoseconds()
        let samples=ArrayList<Float64>(); let work=ArrayList<Float64>()
        let ticks=ArrayList<Float64>(); let draws=ArrayList<Float64>(); let presents=ArrayList<Float64>()
        var measuring=false
        while (PerformanceClock.ticksNanoseconds()-begin < 10000000000) {
            let start=PerformanceClock.ticksNanoseconds()
            while (let Some(e) <- w.pollEvent()) {
                match (e) { case UiEvent.Quit | UiEvent.WindowCloseRequested => throw IllegalArgumentException("Benchmark interrupted") case _ => () }
            }
            a.tick(Int64(w.ticks()))
            let tickEnd=PerformanceClock.ticksNanoseconds()
            draw(a,w.renderer,art)
            let drawEnd=PerformanceClock.ticksNanoseconds()
            w.renderer.present()
            let presentEnd=PerformanceClock.ticksNanoseconds()
            let busy=presentEnd-start
            pacer.finish(a,start)
            if (start-begin >= 2000000000) {
                if (!measuring) { File.writeTo("artifacts/bench-stage.txt",stage.toArray()); measuring=true }
                samples.add(Float64(PerformanceClock.ticksNanoseconds()-start)/1000000.0)
                work.add(Float64(busy)/1000000.0)
                ticks.add(Float64(tickEnd-start)/1000000.0)
                draws.add(Float64(drawEnd-tickEnd)/1000000.0)
                presents.add(Float64(presentEnd-drawEnd)/1000000.0)
            }
        }
        File.writeTo("artifacts/bench-stage.txt","loading".toArray())
        println("BENCH ${stage}: chart=${a.charts[a.selected].version}, notes=${a.charts[a.selected].notes.size}, allocatedHeap=${getAllocatedHeapSize()}, cjThreads=${getThreadCount()}, runtimeNativeThreads=${getNativeThreadCount()}, textures=${art.textures.size}, output=${w.sizeInPixels().w}x${w.sizeInPixels().h}")
        for (i in 0..samples.size) { csv+="${stage},${samples[i]},${work[i]},${ticks[i]},${draws[i]},${presents[i]}\n" }
    }
    File.writeTo("artifacts/bench-frames.csv",csv.toArray())
    a.back()
}
