package orz_mania

import sdl.*
import sdl.system.PerformanceClock
import std.collection.ArrayList
import std.fs.{File,Directory,exists}
import std.runtime.{getAllocatedHeapSize,getThreadCount,getNativeThreadCount}

// Same dense source passage and output size for every rate; no screenshots or settings writes.
func benchmarkRate(a: App,w: SdlWindow,art: Art,args: Array<String>): Unit {
    require(args.size >= 2,"Rate percentage is required")
    let rate=number(args[1]); require(rate >= 50 && rate <= 200 && rate%5 == 0,"Invalid benchmark rate")
    if (!exists("artifacts")) { Directory.create("artifacts",recursive: true) }
    if (args.size > 2 && args[2] == "1440p") { w.setSize(2560,1440) }
    var found=false
    for (i in 0..a.charts.size) { if (a.charts[i].version == "Ex-Final v3") { a.selected=i; found=true; break } }
    require(found,"Import Malody 4K Extra Dan v3 / Ex-Final v3 for the rate benchmark")
    a.back(); a.rate=rate; a.framePreset=7; a.customFPS=240; a.vsync=false; a.autoplay=true; a.speed=1.5; a.showRanking=false
    let source=a.charts[a.selected]
    a.start(Int64(w.ticks())); a.music.play(); a.music.seek(109000)
    let position=rateTime(a.music.position(),rate); a.now=position+a.offset
    a.timeline.reset(position,PerformanceClock.ticksNanoseconds()); a.tick(Int64(w.ticks()))
    let pacer=FramePacer(); pacer.applySync(a,w.renderer)
    let lines=ArrayList<String>(); lines.add("stage,frame_ms,work_ms,tick_ms,draw_ms,present_ms")
    let begin=PerformanceClock.ticksNanoseconds(); var measuring=false
    while (PerformanceClock.ticksNanoseconds()-begin < 10000000000) {
        let start=PerformanceClock.ticksNanoseconds()
        while (let Some(e) <- w.pollEvent()) {
            match (e) { case UiEvent.Quit | UiEvent.WindowCloseRequested => throw IllegalArgumentException("Rate benchmark interrupted") case _ => () }
        }
        a.tick(Int64(w.ticks())); let tickEnd=PerformanceClock.ticksNanoseconds()
        draw(a,w.renderer,art); let drawEnd=PerformanceClock.ticksNanoseconds()
        w.renderer.present(); let presentEnd=PerformanceClock.ticksNanoseconds()
        pacer.finish(a,start)
        if (start-begin >= 2000000000) {
            if (!measuring) { File.writeTo("artifacts/bench-stage.txt","gameplay".toArray()); measuring=true }
            lines.add("gameplay,${Float64(PerformanceClock.ticksNanoseconds()-start)/1000000.0},${Float64(presentEnd-start)/1000000.0},${Float64(tickEnd-start)/1000000.0},${Float64(drawEnd-tickEnd)/1000000.0},${Float64(presentEnd-drawEnd)/1000000.0}")
        }
    }
    File.writeTo("artifacts/bench-stage.txt","loading".toArray())
    File.writeTo("artifacts/bench-frames.csv",String.join(lines.toArray(),delimiter: "\n").toArray())
    // Probe conversion after the measured run so an extra temporary chart cannot inflate its memory sample.
    let heap=getAllocatedHeapSize(); let convert=PerformanceClock.ticksNanoseconds()
    let copy=rateChart(source,rate)
    let convertMs=Float64(PerformanceClock.ticksNanoseconds()-convert)/1000000.0
    let heapDelta=Int64(getAllocatedHeapSize())-Int64(heap)
    require(copy.notes.size == source.notes.size,"Converted chart retains all notes")
    println("BENCH rate=${rate}, notes=${source.notes.size}, conversionMs=${convertMs}, conversionHeapDelta=${heapDelta}, allocatedHeap=${getAllocatedHeapSize()}, cjThreads=${getThreadCount()}, runtimeNativeThreads=${getNativeThreadCount()}, renderer=${w.renderer.driverName()}, output=${w.sizeInPixels().w}x${w.sizeInPixels().h}")
    a.back()
}
