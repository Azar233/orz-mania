package orz_mania

import sdl.*
import sdl.dialogs.*
import sdl.system.PerformanceClock
import std.process.launch
import std.collection.ArrayList
import std.fs.exists


foreign func SDL_GetKeyboardState(count: CPointer<Int32>): CPointer<Bool>

class App {
    var charts=loadCatalog()
    var selected: Int64=0
    var groups=ArrayList<SongGroup>()
    var rows=ArrayList<LibraryRow>()
    var openGroup: Int64 = -1
    var libraryRow: Int64=0
    var drawerFade: Float32=1.0
    var screen: Int64=0 // 0 library, 1 playing, 2 paused, 3 results
    var play: ?Play=None
    var now: Int64 = -2000
    var leadStart: Int64=0
    var pauseTick: Int64=0
    var endedAt: Int64 = -1
    var endPosition: Int64=0
    var speed: Float32=0.55
    var offset: Int64=0
    var framePreset: Int64=0
    var customFPS: Int64=240
    var vsync=false
    var showFPS=false
    var english=false
    var displayFresh=true
    var displayEditing=false
    var displayInput=""
    var displayMessage=""
    var autoplay=false
    var message=""
    var menuOpen=false
    var menuPage: Int64=0 // settings, help, library, bindings
    var menuFocus: Int64=0
    var menuDrag: Int64 = -1
    var keymaps=Array<Array<Int64>>(9,{i => bindings(i+1)})
    var bindingKeys: Int64=4
    var bindingCapture: Int64 = -1
    var bindingMessage=""
    var libraryScroll: Float32=0.0
    var libraryFocus: Float32=0.0
    var libraryFade: Float32=1.0
    var libraryPrevious: Int64=0
    var librarySelected: Int64=0
    var libraryHover: Int64 = -1
    let libraryOrder=ArrayList<Int64>()
    let libraryTitle=LibraryTitle()
    var wheelRemainder: Float32=0.0
    var uiTick: Int64=0
    var lastClickChart: Int64 = -1
    var lastClickTick: Int64 = -1000
    var skipError=""
    var dialog: ?FileDialogRequest=None
    var previewSong=""
    let timeline=AudioTimeline()
    var music: Music
    init(music: Music) { this.music=music; loadSettings(this); rebuildLibrary(this) }
    func start(ticks: Int64): Unit {
        if (charts.isEmpty()) { return }
        previewSong=""
        music.open(charts[selected].audio)
        play=Some(Play(charts[selected])); screen=1; now = -2000; menuOpen=false; menuDrag = -1
        leadStart=ticks; endedAt = -1; skipError=""; lastClickChart = -1
    }
    func canSkipIntro(): Bool {
        if (screen != 1 || endedAt >= 0) { return false }
        if (let Some(p) <- play) { return p.chart.notes[0].time >= 3000 && now < p.chart.notes[0].time-2500 }
        false
    }
    func skipIntro(): Unit {
        if (!canSkipIntro()) { return }
        if (let Some(p) <- play) {
            let target=max(0,p.chart.notes[0].time-2000-offset)
            try {
                // Play first: MIX_PlayTrack would otherwise reset a seek on a stopped track.
                if (!music.started) { music.play() }
                music.seek(target)
                let position=music.position()
                if (position >= 0) { timeline.reset(position,PerformanceClock.ticksNanoseconds()); now=position+offset }
                skipError=""
            } catch (ex: Exception) { skipError="无法跳过此前奏"; println(ex.message) }
        }
    }
    func importPath(path: String): Unit {
        try {
            let task=launch("powershell.exe",["-NoProfile","-NonInteractive","-ExecutionPolicy","Bypass","-File","tools/import-songs.ps1","-Source",path])
            require(task.wait() == 0,tr(this,"导入失败，检查路径或文件格式"))
            charts=loadCatalog(); selected=0; previewSong=""; rebuildLibrary(this); message=if (english) { "Library refreshed · ${charts.size} mania charts" } else { "已刷新曲库 · ${charts.size} 张可用 mania 谱面" }
        } catch (ex: Exception) { message=ex.message }
    }
    func pause(ticks: Int64): Unit {
        if (screen != 1) { return }
        music.pause(); pauseTick=ticks; screen=2; menuOpen=true; menuPage=0; menuFocus=0

    }
    func resume(ticks: Int64): Unit {
        // Reconcile physical keys: releases while paused never judge notes.
        if (!autoplay) { if (let Some(p) <- play) {
            let state=unsafe { SDL_GetKeyboardState(CPointer<Int32>()) }
            let keys=keymaps[p.chart.keys-1]
            for (i in 0..keys.size) {
                let scan=bindingScancode(keys[i])
                p.down[i]=scan >= 0 && scan < 512 && state.isNotNull() && unsafe { state.read(scan) }
                if (!p.down[i]) { p.release(i,now) }
                else { p.keyOverlay.press(i,now,count: false) }
            }
        }
        }
        if (endedAt >= 0) { endedAt+=ticks-pauseTick }
        if (music.started) { music.resume(); timeline.reset(max(0,now-offset),PerformanceClock.ticksNanoseconds()) } else { leadStart+=ticks-pauseTick }
        screen=1; menuOpen=false; menuDrag = -1
    }
    func preview(async!: Bool=false): Unit {
        if (screen != 0 || charts.isEmpty()) { return }
        let chart=charts[selected]; let song=chart.artist+"\n"+chart.title
        if (previewSong == song) { music.discardPreview(); return }
        try {
            if (async) { if (!music.preparePreview(chart.audio)) { return } }
            else { music.open(chart.audio,predecode: false) }
            music.play(loop: true); previewSong=song
        } catch (ex: Exception) { previewSong=song; message=ex.message; println("Preview: ${ex.message}") }
    }
    func back(): Unit { previewSong=""; music.stop(); screen=0; play=None; menuOpen=false; menuDrag = -1 }
    func tick(ticks: Int64): Unit {
        let dt=if (uiTick == 0) { Float32(0.0) } else { min(Float32(0.05),Float32(max(0,ticks-uiTick))/1000.0) }
        uiTick=ticks
        if (screen == 0) { animateLibrary(this,dt) }
        if (let Some(d) <- dialog) {
            if (d.isDone()) {
                match (d.result()) {
                    case FileDialogSelected(paths, _) => if (paths.size > 0) { importPath(paths[0]) }
                    case FileDialogFailed(error) => message=error
                    case _ => ()
                }
                dialog=None
            }
        }
        if (screen != 1) { return }
        if (!music.started) {
            now=ticks-leadStart-2000
            if (now >= 0) {
                music.play()
                let position=max(0,music.position())
                timeline.reset(position,PerformanceClock.ticksNanoseconds()); now=position+offset
            }
        } else {
            let pos=music.position()
            if (pos >= 0 && music.playing()) { now=timeline.sample(pos,PerformanceClock.ticksNanoseconds())+offset }
            else {
                if (endedAt < 0) { endedAt=ticks; endPosition=now }
                now=endPosition+ticks-endedAt
            }
        }
        if (let Some(p) <- play) {
            p.update(now,autoplay)
            if (now > p.chart.duration+1800) { screen=3; music.stop() }
        }
    }
}
func laneOf(a: App,p: Play, key: Key): Int64 {
    let code=codeOf(key); let keys=a.keymaps[p.chart.keys-1]
    for (i in 0..keys.size) { if (bindingScancode(keys[i]) == bindingScancode(code)) { return i } }
    -1
}
func handle(a: App, w: SdlWindow, event: UiEvent): Bool {
    let ticks=Int64(w.ticks())
    match (event) {
        case UiEvent.Quit | UiEvent.WindowCloseRequested => return false
        case UiEvent.WindowFocusLost => a.pause(ticks); return true
        case _ => ()
    }
    if (a.menuOpen) { return handleMenu(a,w,event) }
    match (event) {
        case UiEvent.Quit | UiEvent.WindowCloseRequested => return false
        case UiEvent.WindowFocusLost => a.pause(ticks)
        case UiEvent.DropFile(path, _, _) => if (a.screen == 0) { a.importPath(path) }
        case UiEvent.KeyUp(key) => if (a.screen == 1 && !a.autoplay) { if (let Some(p) <- a.play) { p.release(laneOf(a,p,key),a.now) } }
        case UiEvent.MouseMove(x,y) => if (a.screen == 0) { a.libraryHover=libraryHit(a,x,y) }
        case UiEvent.MouseWheel(_, y, _, _) =>
            if (a.screen == 0 && !a.charts.isEmpty()) {
                a.wheelRemainder+=y
                let steps=Int64(a.wheelRemainder)
                selectLibraryRow(a,a.libraryRow-steps)
                a.wheelRemainder-=Float32(steps)
            }
        case UiEvent.MouseDown(MouseButton.Left,x,y) =>
            if (a.screen == 3) {
                if (inRect(x,y,resultActionRect(false))) { a.back() }
                else if (inRect(x,y,resultActionRect(true))) { a.start(ticks) }
            } else if (a.screen == 0) {
                if (inRect(x,y,libraryMenuRect())) { openMenu(a,ticks); return true }
                let index=libraryHit(a,x,y)
                if (index >= 0) {
                    if (a.rows[index].chart < 0) { a.lastClickChart = -1; toggleSongDrawer(a,index) }
                    else {
                        let chart=a.rows[index].chart
                        let twice=a.lastClickChart == chart && a.selected == chart && ticks-a.lastClickTick <= 350 && ticks >= a.lastClickTick
                        selectLibraryRow(a,index); a.lastClickChart=chart; a.lastClickTick=ticks
                        if (twice) { a.start(ticks) }
                    }
                }
            }
        case UiEvent.KeyDown(key, repeat) =>
            if (repeat) {
                match (key) {
                    case Key.Up | Key.Down => if (a.screen != 0) { return true }
                    case _ => return true
                }
            }
            match (key) {
                case Key.Enter => if (a.canSkipIntro()) { a.skipIntro(); return true }
                case _ => ()
            }
            if (a.screen == 1 && !a.autoplay) { if (let Some(p) <- a.play) {
                let lane=laneOf(a,p,key)
                if (lane >= 0) { p.press(lane,a.now); return true }
            } }
            match (key) {
                case Key.Escape => openMenu(a,ticks)
                case Key.Enter =>
                    if (a.screen == 2) { a.resume(ticks) }
                    else if (a.screen == 0 && !a.rows.isEmpty() && a.rows[a.libraryRow].chart < 0) { toggleSongDrawer(a,a.libraryRow) }
                    else if (a.screen == 0 || a.screen == 3) { a.start(ticks) }
                case Key.Letter(82) => if (a.screen != 0) { a.start(ticks) } else { a.importPath("Songs") }
                case Key.Up => if (a.screen == 0) { selectLibraryRow(a,a.libraryRow-1) }
                case Key.Down => if (a.screen == 0) { selectLibraryRow(a,a.libraryRow+1) }
                case Key.Right => if (a.screen == 0 && !a.rows.isEmpty()) {
                    let row=a.rows[a.libraryRow]
                    if (row.chart < 0 && a.openGroup != row.group) { toggleSongDrawer(a,a.libraryRow) }
                }
                case Key.Left => if (a.screen == 0 && !a.rows.isEmpty()) {
                    if (a.openGroup == a.rows[a.libraryRow].group) { toggleSongDrawer(a,a.libraryRow) }
                }
                case Key.Letter(73) => if (a.screen == 0 && a.dialog.isNone()) {
                    a.dialog=Some(FileDialogs.openFolder(window: Some(w)))
                }
                case Key.Letter(79) => if (a.screen == 0 && a.dialog.isNone()) {
                    a.dialog=Some(FileDialogs.openFile(options: FileDialogOptions(filters: [FileDialogFilter("osu! beatmap", "osz;osu")]),window: Some(w)))
                }
                case _ => if (a.screen == 1 && !a.autoplay) { if (let Some(p) <- a.play) { p.press(laneOf(a,p,key),a.now) } }
            }
        case _ => ()
    }
    true
}
main(args: Array<String>): Int64 {
    try {
        if (args.size > 0 && (args[0] == "--prepare-icon" || args[0] == "--prepare-icon-preview")) {
            require(args.size == 3,"Icon source and output directory are required")
            prepareAppIcons(args[1],args[2],preview: args[0] == "--prepare-icon-preview"); return 0
        }
        if (args.size > 0 && args[0] == "--verify") { verify(); return 0 }
        if (exists("C:/Windows/Fonts/msyh.ttc")) {
            Fonts.register("orz", "C:/Windows/Fonts/msyh.ttc")
            Fonts.setDefault(Some("orz"))
        }
        try (w=SdlWindow(WindowSpec("orz!mania",1280,720,resizable: true,highDpi: true,vsync: false,supersample: 1))) {
            let iconPath=if (exists("assets/generated/app-icon-256.png")) { "assets/generated/app-icon-256.png" } else { "assets/branding/icon.svg" }
            try (icon=Surface.load(iconPath,options: ImageLoadOptions(width: 256,height: 256))) { w.setIcon(icon) }
            w.setMinimumSize(800,450)
            try (music=Music()) {
                let a=App(music)
                try (art=Art(w.renderer)) {
                    let capture=args.size > 0 && args[0] == "--screenshots"
                    if (args.size > 0 && args[0] == "--benchmark") { benchmark(a,w,art,args); return 0 }
                    if (args.size > 0 && args[0] == "--readme-capture") { captureReadmeShowcase(a,w,art); return 0 }
                    if (args.size > 0 && args[0] == "--readme-media") { captureReadmeMedia(a,w,art); return 0 }
                    if (args.size > 0 && args[0] == "--ui-check") { verifyUiLogic(a,w,art); return 0 }
                    if (args.size > 0 && args[0] == "--scroll-check") { scrollCheck(a,w,art,args); return 0 }
                    if (capture) { screenshots(a,w,art); return 0 }
                    if (args.size > 0 && args[0] == "--motion-check") { motionCheck(a,w,art); return 0 }
                    if (args.size > 0 && args[0] == "--smoke") { smoke(a,w,art); return 0 }
                    let frames=FramePacer()
                    while (true) {
                        let frameStart=PerformanceClock.ticksNanoseconds()
                        a.tick(Int64(w.ticks()))
                        var running=true
                        while (let Some(event) <- w.pollEvent()) {
                            try { if (!handleWindowEvent(a,w,event)) { running=false } }
                            catch (ex: Exception) { a.message=ex.message; a.back(); a.menuOpen=true; a.menuPage=2 }
                        }
                        if (!running) { break }
                        a.preview(async: true)
                        frames.applySync(a,w.renderer)
                        draw(a,w.renderer,art)
                        if (a.showFPS) { frames.drawStats(w.renderer) }
                        w.renderer.present(); frames.finish(a,frameStart)
                    }
                    saveSettings(a)
                }
            }
        }
        return 0
    } catch (ex: Exception) { println("ERROR: ${ex.message}"); return 1 }
}






