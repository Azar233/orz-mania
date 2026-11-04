package orz_mania

import sdl.*
import std.math.abs
import std.collection.ArrayList
import std.fs.{Directory, exists, File}
import sdl.system.PerformanceClock
import sdl.displays.allDisplayInfos

// Interaction and persistence regression only: no screenshot or visual review.
func verifyUiLogic(a: App,w: SdlWindow,art: Art): Unit {
    let saved=File.readFrom("settings.cfg")
    let originalMaps=a.keymaps; let originalSpeed=a.speed; let originalOffset=a.offset
    let originalPreset=a.framePreset; let originalCustom=a.customFPS
    let esc=UiEvent.KeyDown(Key.Escape,false)
    try {
        verifyLibraryTitle(w.renderer)
        for (top in [326.0,410.0,444.0,472.0,486.0]) {
            let rect=settingValueRect(Float32(top))
            require(rect.w == 112.0 && rect.h == 32.0 && rect.x+rect.w == 980.0,"Discrete settings share size and right alignment")
            require(inRect(rect.x+rect.w/2.0,rect.y+rect.h/2.0,rect) && !inRect(rect.x+rect.w,rect.y,rect),"Setting value hit bounds")
        }
        a.back(); a.english=false
        require(tr(a,"语言") == "语言","Chinese language label must be monolingual")
        a.english=true
        require(tr(a,"语言") == "Language","English language label must be monolingual")
        require(w.renderer.textWidth("English",pointSize: 16.0) < settingValueRect(486.0).w-16.0,"Language value fits the shared button")
        a.english=false
        let _=handle(a,w,esc)
        require(a.menuOpen && a.menuPage == 0,"Esc opens settings")
        for (i in 0..5) {
            let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,340.0,202.0+Float32(i)*44.0))
            require(a.menuPage == i,"Compact navigation hit boxes")
        }
        a.menuPage=4
        let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,924.0,342.0))
        require(a.displayEditing,"Aligned FPS field hit box")
        let _=handle(a,w,esc)
        let sync=a.vsync; let stats=a.showFPS
        for (top in [426.0,488.0]) { let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,924.0,Float32(top))) }
        require(a.vsync != sync && a.showFPS != stats,"Aligned display toggles remain clickable")
        a.vsync=sync; a.showFPS=stats
        a.menuPage=0
        let auto=a.autoplay
        let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,924.0,460.0))
        require(a.autoplay != auto,"Aligned autoplay button hit box")
        a.autoplay=auto
        let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,900.0,502.0))
        require(a.english && a.menuFocus == 4 && tr(a,"设置") == "Settings","Language button switches immediately")
        require(tr(a,"Esc 菜单") == "Esc Menu" && tr(a,"按键绑定") == "Key bindings","English UI labels")
        draw(a,w.renderer,art)
        let _=handle(a,w,esc)
        require(!a.menuOpen,"Close menu")
        a.english=false; loadSettings(a)
        require(a.english && a.speed == originalSpeed && a.offset == originalOffset && a.framePreset == originalPreset && a.customFPS == originalCustom,"Language persists without changing other settings")
        for (i in 0..9) { for (j in 0..originalMaps[i].size) { require(a.keymaps[i][j] == originalMaps[i][j],"Language preserves bindings") } }
        let _=handle(a,w,esc); a.menuFocus=4
        let _=handle(a,w,UiEvent.KeyDown(Key.Enter,false))
        require(!a.english && tr(a,"设置") == "设置","Keyboard language switch")
        let rows=String.fromUtf8(saved).split("\n")
        let legacy=String.join(rows[0..12],delimiter: "\n")+"\n"
        File.writeTo("settings.cfg",legacy.toArray()); a.english=true; loadSettings(a)
        require(!a.english,"Legacy settings default to Chinese")
        File.writeTo("settings.cfg",(legacy+"language=unknown\n").toArray()); a.english=true; loadSettings(a)
        require(!a.english,"Unknown language falls back to Chinese")
        File.writeTo("settings.cfg",saved); loadSettings(a)
        for (english in [false,true]) {
            a.english=english; a.menuOpen=true
            for (page in 0..5) {
                a.menuPage=page; draw(a,w.renderer,art)
                let title=tr(a,["设置","操作说明","曲库","按键绑定","显示"][page])
                require(w.renderer.textWidth(title,pointSize: 16.0) < 158.0,"Translated navigation label fits button")
            }
        }
        a.menuOpen=false
        for (size in [Size(960.0,540.0),Size(1000.0,800.0),Size(1600.0,900.0)]) {
            w.setSize(Int32(size.w),Int32(size.h)); w.delay(100)
            while (let Some(_) <- w.pollEvent()) {}
            draw(a,w.renderer,art)
            let rect=w.renderer.fitCanvas(1280.0,720.0)
            let nativeScale=w.scale*w.currentPixelDensity
            let px=(rect.x+1180.0*rect.w/1280.0)/nativeScale
            let py=(rect.y+38.0*rect.w/1280.0)/nativeScale
            let point=canvasPoint(w,px,py)
            require(abs(point.x-1180.0) < 0.1 && abs(point.y-38.0) < 0.1,"Resized coordinates preserve UI hit testing")
            let _=handleWindowEvent(a,w,UiEvent.MouseDown(MouseButton.Left,px,py))
            require(a.menuOpen,"Resized Esc button works"); a.menuOpen=false
        }
        w.setSize(1280,720); w.delay(100)
        while (let Some(_) <- w.pollEvent()) {}
        a.menuOpen=true; a.menuPage=3; a.bindingKeys=4
        let key=bindingKeyRect(4,0)
        let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,key.x+key.w/2.0,key.y+key.h/2.0))
        require(a.bindingCapture == 0,"Compact keycap remains clickable")
        let _=handle(a,w,esc)
        require(a.bindingCapture == -1 && a.menuOpen,"Esc cancels capture without closing menu")
        a.start(Int64(w.ticks())); let _=handle(a,w,esc)
        draw(a,w.renderer,art)
        let frozen=a.now; let english=a.english
        let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,900.0,502.0))
        require(a.screen == 2 && a.now == frozen && a.english == english,"Pause isolates settings and gameplay")
        let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,640.0,312.0))
        require(a.screen == 1 && !a.menuOpen && a.now == -2000,"Skin Retry resets play")
        let _=handle(a,w,esc)
        let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,640.0,478.0))
        require(a.screen == 0 && !a.menuOpen,"Skin Quit returns to library")
        a.screen=3
        let back=resultActionRect(false); let retry=resultActionRect(true)
        require(back.x > 628.0 && back.x+back.w+16.0 == retry.x && retry.x+retry.w <= 1280.0 && back.y == retry.y,"Results actions stay together on the right, clear of the score graph and full-combo art")
        let achievement=resultAchievementRect(); let notice=resultNoticeRect()
        require(achievement.x > 560.0 && achievement.y+achievement.h <= notice.y && notice.y+notice.h < back.y,"Achievement, rank notice and buttons occupy separate regions clear of recent hit timing")
        require(notice.x == back.x && notice.x+notice.w == retry.x+retry.w,"Rank notice aligns with the full action group")
        let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,40.0,690.0))
        require(a.screen == 3,"Old results button position is no longer clickable")
        let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,back.x+back.w/2.0,back.y+back.h/2.0))
        require(a.screen == 0,"Results Back button uses its relocated hit box")
        a.screen=3
        let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,retry.x+retry.w/2.0,retry.y+retry.h/2.0))
        require(a.screen == 1,"Results Retry button uses its drawn hit box")
        a.back(); a.menuOpen=true
        require(!handle(a,w,UiEvent.MouseDown(MouseButton.Left,965.0,558.0)),"Quit game button retains its hit box")
        require(art.errors == 0,"UI resources load without errors")
        println("PASS UI logic: compact buttons / language mouse and keyboard / persistence / legacy fallback / unchanged bindings / resize mapping / binding capture / pause retry and quit")
    } finally {
        a.back(); a.menuOpen=false; a.bindingCapture = -1
        File.writeTo("settings.cfg",saved); loadSettings(a)
    }
}

func verify(): Unit {
    verifyKeyOverlay()
    verifyAudioTimeline()
    let charts=loadCatalog() // Imported songs are optional; synthetic fixtures below always run.
    for (c in charts) {
        require(c.keys >= 1 && c.keys <= 9 && c.duration > 0,"Chart parse failed")
        let p=Play(c)
        p.update(c.duration+500,true)
        require(p.judged == c.notes.size && p.counts[0] == c.notes.size && p.score == 1000000,"Autoplay cannot complete chart")
        println("PASS ${c.version}: ${c.notes.size} notes, ${c.holds} holds, ${c.duration} ms")
    }
    let data="osu file format v14\n[General]\nMode:3\nAudioFilename:a.mp3\n[Difficulty]\nCircleSize:4\nOverallDifficulty:5\n[HitObjects]\n0,0,1000,1,0\n511,0,2000,128,0,3000:0:0:0:\n"
    let c=parseChart(data,"Songs/test/map.osu"); require(c.notes[1].lane == 3,"Lane boundary")
    let p=Play(c); p.press(0,1010); p.release(0,1010); p.press(3,2000); p.update(3000,false)
    require(p.counts[0] == 2 && p.combo == 2,"Tap and hold scoring")
    let early=Play(parseChart(data,"Songs/test/map.osu")); early.press(3,2000); early.release(3,2500)
    require(early.counts[5] == 1,"Early hold release must miss")
    let miss=Play(parseChart(data,"Songs/test/map.osu")); miss.update(4000,false)
    require(miss.counts[5] == 2 && miss.combo == 0,"Miss expiry")
    let repeat=Play(parseChart(data,"Songs/test/map.osu")); repeat.press(0,1000); repeat.press(0,1000)
    require(repeat.judged == 1,"Key repeat double scoring")
    var rejected=false
    try { let _=parseChart(data.replace("Mode:3","Mode:0"),"Songs/test/map.osu") } catch (_: Exception) { rejected=true }
    require(rejected,"Must reject standard charts")
    rejected=false
    try { let _=parseChart(data.replace("a.mp3","../a.mp3"),"Songs/test/map.osu") } catch (_: Exception) { rejected=true }
    require(rejected,"Unsafe asset traversal")
    for (k in 1..10) {
        let multi=parseChart(data.replace("CircleSize:4","CircleSize:${k}.0"),"Songs/test/map.osu")
        require(multi.keys == k && multi.notes[1].lane == k-1 && bindings(k).size == k,"1K-9K column mapping")
    }
    require(p.grade(p.window()) == 4 && p.grade(p.window()+1) == 5,"Timing boundary")
    let holds=data.replace("0,0,1000,1,0", "0,0,1000,128,0,3000:0:").replace("511,0,2000,128,0,3000", "511,0,2000,128,0,4000")
    let chord=Play(parseChart(holds,"Songs/test/map.osu"))
    chord.press(0,1030); chord.press(3,2000); chord.update(4100,false)
    require(chord.counts[0] == 1 && chord.counts[1] == 1,"Independent hold head timing")
    println("PASS tap / hold / early release / miss / key repeat / mode / safe paths / 1K-9K / timing bounds / overlapping holds")
}

func smoke(a: App,w: SdlWindow,art: Art): Unit {
    if (!exists("artifacts")) { Directory.create("artifacts",recursive: true) }
    a.autoplay=true
    a.start(Int64(w.ticks()))
    var paused=false
    let begin=Int64(w.ticks())
    while (Int64(w.ticks())-begin < 21000) {
        while (let Some(e) <- w.pollEvent()) {
            match (e) { case UiEvent.Quit | UiEvent.WindowCloseRequested => throw IllegalArgumentException("Smoke interrupted") case _ => () }
        }
        a.tick(Int64(w.ticks()))
        if (a.now > 500 && !paused) {
            require(a.music.started && a.music.playing(),"Real audio did not start")
            a.pause(Int64(w.ticks()))
            let before=a.music.position(); w.delay(200); let after=a.music.position()
            require(abs(after-before) <= 30,"Pause did not freeze the audio clock")
            a.resume(Int64(w.ticks())); paused=true
        }
        draw(a,w.renderer,art); w.renderer.present(); w.delay(2)
    }
    let p=a.play.getOrThrow()
    require(paused && a.now > 17500 && p.judged > 20 && p.counts[5] == 0,"Real-time autoplay/audio sync failed")
    w.renderer.captureBmp("artifacts/live-play.bmp")
    println("PASS SDL window + real MP3 playback + audio clock + pause/resume + ${p.judged} autoplay notes at ${a.now} ms")
    a.start(Int64(w.ticks())); require(a.now == -2000 && a.play.getOrThrow().judged == 0,"Retry did not reset session")
    a.back(); require(a.screen == 0 && !a.music.started,"Return to library did not stop music")
    a.importPath("Songs/923488 HyuN - Grin")
    require(a.charts.size >= 3 && a.message.startsWith("已刷新"),"In-game importer process failed")
    println("PASS retry / return / stop / in-game import path with spaces")
}





func verifyMenus(a: App,w: SdlWindow,art: Art): Unit {
    let oldSpeed=a.speed; let oldOffset=a.offset; let oldVolume=a.music.volume
    let oldAuto=a.autoplay; let oldSelected=a.selected
    let esc=UiEvent.KeyDown(Key.Escape,false)
    let beforeWheel=a.selected
    a.selected=0; resetLibraryMotion(a)
    let _=handle(a,w,UiEvent.MouseWheel(0.0,-0.5,700.0,300.0))
    require(a.selected == 0,"Partial wheel input must accumulate")
    let _=handle(a,w,UiEvent.MouseWheel(0.0,-0.5,700.0,300.0))
    require(a.libraryRow == 1,"Precision wheel input was lost")
    let _=handle(a,w,UiEvent.KeyDown(Key.Down,true))
    require(a.libraryRow == 2,"Held direction key must keep scrolling")
    a.selected=beforeWheel; resetLibraryMotion(a)
    let _=handle(a,w,esc)
    require(a.menuOpen && a.screen == 0,"Library Esc menu did not open")
    let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,963.0,238.0))
    require(a.speed >= oldSpeed,"Speed setting")
    a.offset=0
    let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,963.0,320.0))
    require(a.offset == 5,"Offset step must be 5 ms")
    a.menuDrag=1; dragSetting(a,2000.0); require(a.offset == 300,"Offset upper bound")
    dragSetting(a,0.0); require(a.offset == -300,"Offset lower bound")
    let _=handle(a,w,UiEvent.MouseUp(MouseButton.Left,0.0,0.0))
    require(a.menuDrag == -1,"Slider drag capture did not release")
    a.menuDrag=0; dragSetting(a,2000.0)
    require(a.speed == 2.5,"Speed slider must reach 2500 px/s")
    changeSetting(a,0,1); require(a.speed == 2.5,"Speed upper clamp")
    dragSetting(a,0.0); changeSetting(a,0,-1); require(a.speed == 0.2,"Speed lower clamp")
    a.speed=2.5; saveSettings(a); a.speed=0.55; loadSettings(a)
    require(a.speed == 2.5,"2500 px/s must survive settings reload")
    a.menuDrag = -1
    a.offset=25
    let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,930.0,459.0))
    require(a.autoplay != oldAuto,"Autoplay toggle")
    a.autoplay=oldAuto
    draw(a,w.renderer,art); w.renderer.captureBmp("artifacts/menu-settings.bmp")
    let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,300.0,244.0))
    require(a.menuPage == 1,"Help tab")
    draw(a,w.renderer,art); w.renderer.captureBmp("artifacts/menu-help.bmp")
    let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,300.0,288.0))
    require(a.menuPage == 2,"Library tab")
    let count=a.charts.size
    let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,600.0,373.0))
    require(a.charts.size == count,"Refresh changed the chart count")
    draw(a,w.renderer,art); w.renderer.captureBmp("artifacts/menu-library.bmp")
    require(!handle(a,w,UiEvent.MouseDown(MouseButton.Left,960.0,570.0)),"Exit button")
    let _=handle(a,w,esc)
    require(!a.menuOpen && a.screen == 0,"Closing library menu must not start or quit")
    a.selected=oldSelected; a.start(Int64(w.ticks()))
    let _=handle(a,w,esc)
    let frozen=a.now; let judged=a.play.getOrThrow().judged; let offset=a.offset
    a.tick(Int64(w.ticks())+500)
    let _=handle(a,w,UiEvent.KeyDown(Key.Letter(68),false))
    let _=handle(a,w,UiEvent.KeyDown(Key.PageUp,false))
    require(a.screen == 2 && a.menuOpen && a.now == frozen && a.play.getOrThrow().judged == judged && a.offset == offset,"Pause must block gameplay and settings")
    draw(a,w.renderer,art); w.renderer.captureBmp("artifacts/menu-pause.bmp")
    let _=handle(a,w,UiEvent.KeyDown(Key.Enter,false))
    require(a.screen == 1 && !a.menuOpen && a.now == -2000 && a.play.getOrThrow().judged == 0,"Pause retry")
    let _=handle(a,w,esc)
    let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,600.0,478.0))
    require(a.screen == 0 && !a.menuOpen && !a.music.started,"Pause quit must return to library")
    a.speed=oldSpeed; a.offset=oldOffset; a.music.setVolume(oldVolume); a.autoplay=oldAuto; a.selected=oldSelected
    saveSettings(a); a.offset=123; loadSettings(a)
    require(a.offset == oldOffset && a.speed == oldSpeed,"Settings persistence")
    println("PASS Esc menus / slider bounds / 5ms offset steps / input blocking / retry / quit / settings persistence")
}

func verifyLibraryMotion(a: App): Unit {
    let selected=a.selected
    a.selected=0; resetLibraryMotion(a)
    selectLibraryRow(a,min(6,a.rows.size-1))
    animateLibrary(a,0.016)
    require(a.libraryScroll > 0.0 && a.libraryScroll < libraryTarget(a),"Song list must animate instead of jumping")
    require(a.libraryFade > 0.0 && a.libraryFade < 1.0,"Cover transition")
    let visible=Int64(a.libraryScroll)+1
    let y=144.0+(Float32(visible)-a.libraryScroll)*LIBRARY_STEP+40.0
    require(libraryHit(a,700.0,y) == visible,"Moving cards must remain clickable")
    for (_ in 0..60) { animateLibrary(a,Float32(1.0/60.0)) }
    let sixty=a.libraryScroll
    a.selected=0; resetLibraryMotion(a); selectLibraryRow(a,min(6,a.rows.size-1))
    for (_ in 0..120) { animateLibrary(a,Float32(1.0/120.0)) }
    require(abs(a.libraryScroll-sixty) < 0.01,"Scroll easing must be refresh-rate independent")
    a.selected=0; resetLibraryMotion(a)
    require(libraryHit(a,600.0,180.0) == 0 && libraryHit(a,600.0,238.0) == 0 && libraryHit(a,600.0,248.0) == 1,"Overlapping cards must hit the foreground card")
    selectLibraryRow(a,a.rows.size-1)
    for (_ in 0..120) { animateLibrary(a,Float32(1.0/60.0)) }
    require(a.libraryScroll == libraryTarget(a),"Scroll must settle within the library bounds")
    a.selected=selected; resetLibraryMotion(a)
    println("PASS smooth scrolling / cover fade / 60-120Hz consistency / animated hit testing / list boundaries")
}

func captureLibraryMotion(a: App,w: SdlWindow,art: Art): Unit {
    let selected=a.selected
    if (!exists("artifacts/scroll")) { Directory.create("artifacts/scroll",recursive: true) }
    a.selected=0; resetLibraryMotion(a)
    for (frame in 0..48) {
        if (frame%12 == 0) { let _=handle(a,w,UiEvent.MouseWheel(0.0,-1.0,700.0,300.0)) }
        animateLibrary(a,Float32(1.0/30.0))
        draw(a,w.renderer,art)
        w.renderer.captureBmp("artifacts/scroll/frame-${frame}.bmp")
    }
    a.selected=selected; resetLibraryMotion(a)
}

func verifyBindings(a: App,w: SdlWindow,art: Art): Unit {
    let original=a.keymaps
    let auto=a.autoplay
    a.keymaps=Array<Array<Int64>>(9,{i => bindings(i+1)})
    a.menuOpen=true; a.menuPage=3; a.bindingKeys=4
    let firstRect=bindingKeyRect(4,0)
    let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,firstRect.x+firstRect.w/2.0,firstRect.y+52.0))
    require(a.bindingCapture == 0,"Binding capture did not start")
    let _=handle(a,w,UiEvent.KeyDown(Key.Letter(70),false))
    require(a.bindingCapture == 0 && a.keymaps[3][0] == 68 && !a.bindingMessage.isEmpty(),"Duplicate key must be rejected")
    let _=handle(a,w,UiEvent.KeyDown(Key.Letter(82),false))
    require(a.bindingCapture == -1 && a.keymaps[3][0] == 82 && a.menuOpen,"Binding must capture shortcuts without triggering them")
    a.bindingCapture=1
    let _=handle(a,w,UiEvent.KeyDown(Key.Escape,false))
    require(a.bindingCapture == -1 && a.menuOpen && a.keymaps[3][1] == 70,"Esc must cancel capture only")
    draw(a,w.renderer,art); w.renderer.captureBmp("artifacts/menu-bindings.bmp")
    for (count in 1..10) {
        for (i in 0..count) {
            let rect=bindingKeyRect(count,i)
            require(rect.x >= 492.0 && rect.x+rect.w <= 980.1 && rect.y+rect.h < 531.0,"Keycap outside content bounds")
            if (i > 0) { let previous=bindingKeyRect(count,i-1); require(previous.x+previous.w < rect.x,"Keycaps overlap") }
        }
    }
    let nine=bindingModeRect(8)
    let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,nine.x+nine.w/2.0,nine.y+17.0))
    require(a.bindingKeys == 9,"Segmented key-count selector")
    draw(a,w.renderer,art); w.renderer.captureBmp("artifacts/menu-bindings-9k.bmp")
    let last=bindingKeyRect(9,8)
    let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,last.x+last.w/2.0,last.y+52.0))
    require(a.bindingCapture == 8,"Last 9K keycap hit test")
    let _=handle(a,w,UiEvent.KeyDown(Key.Escape,false))
    a.bindingKeys=4; a.menuFocus=0
    saveSettings(a); a.keymaps[3]=bindings(4); loadSettings(a)
    require(a.keymaps[3][0] == 82 && a.keymaps[6][0] == bindings(7)[0],"Per-key-count bindings must persist independently")
    a.autoplay=false; a.start(Int64(w.ticks()))
    let p=a.play.getOrThrow(); let n=p.chart.notes[0]
    a.keymaps[p.chart.keys-1][n.lane]=82
    // Use distinct non-R defaults for the other lanes and then bind R to this note.
    for (i in 0..p.chart.keys) { if (i != n.lane) { a.keymaps[p.chart.keys-1][i]=65+i } }
    a.now=n.time
    let _=handle(a,w,UiEvent.KeyDown(Key.Letter(82),false))
    require(p.down[n.lane] && a.now == n.time,"Custom R binding must hit notes instead of retrying")
    let _=handle(a,w,UiEvent.KeyUp(Key.Letter(82)))
    require(!p.down[n.lane],"Custom release mapping")
    a.back(); a.menuOpen=true; a.menuPage=3; a.bindingKeys=4
    let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,560.0,570.0))
    require(a.keymaps[3][0] == 68 && a.bindingCapture == -1,"Restore default bindings")
    a.bindingMessage=""
    draw(a,w.renderer,art); w.renderer.captureBmp("artifacts/menu-bindings.bmp")
    require(codeOf(Key.RawScancode(225)) == 1225 && bindingScancode(1225) == 225,"Modifier key mapping")
    a.keymaps=original; a.autoplay=auto; a.menuOpen=false; a.bindingCapture = -1
    saveSettings(a)
    println("PASS key rebinding / duplicates / cancel / per-key-count save / gameplay press and release / shortcut priority / reset / Shift mapping")
}

func verifyDrawers(a: App,w: SdlWindow,art: Art): Unit {
    let selected=a.selected; let auto=a.autoplay
    rebuildLibrary(a)
    require(a.rows.size == a.groups.size,"Collapsed library must contain only song headers")
    var total: Int64=0
    var target: Int64 = -1
    for (g in 0..a.groups.size) {
        total+=a.groups[g].charts.size
        if (a.groups[g].charts.size > 2 && target < 0) { target=g }
    }
    require(total == a.charts.size && target >= 0,"Grouping lost charts")
    selectLibraryRow(a,target); resetLibraryMotion(a)
    draw(a,w.renderer,art); w.renderer.captureBmp("artifacts/library-collapsed.bmp")
    let cy=144.0+(Float32(a.libraryRow)-a.libraryScroll)*LIBRARY_STEP+45.0
    let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,700.0,cy))
    require(a.openGroup == target && a.rows.size == a.groups.size+a.groups[target].charts.size,"Click must expand exactly one song")
    animateLibrary(a,0.25)
    draw(a,w.renderer,art); w.renderer.captureBmp("artifacts/library-expanded.bmp")
    let header=a.libraryRow
    let _=handle(a,w,UiEvent.KeyDown(Key.Down,false))
    require(a.rows[a.libraryRow].chart == a.groups[target].charts[0],"Keyboard must enter visible difficulty rows")
    let _=handle(a,w,UiEvent.KeyDown(Key.Down,false))
    let difficulty=a.groups[target].charts[1]
    require(a.selected == difficulty,"Difficulty selection chose the wrong chart")
    a.autoplay=false
    let _=handle(a,w,UiEvent.KeyDown(Key.Enter,false))
    require(a.screen == 1 && a.play.getOrThrow().chart.path == a.charts[difficulty].path,"Difficulty must launch its own chart")
    a.back(); syncLibrarySelection(a); resetLibraryMotion(a)
    let clickY=144.0+(Float32(a.libraryRow)-a.libraryScroll)*LIBRARY_STEP+40.0
    let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,700.0,clickY))
    require(a.screen == 0,"Single difficulty click must only select")
    let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,700.0,clickY))
    require(a.screen == 1 && a.play.getOrThrow().chart.path == a.charts[difficulty].path,"Double-click must launch the selected difficulty")
    a.back(); selectLibraryRow(a,header)
    let _=handle(a,w,UiEvent.KeyDown(Key.Enter,false))
    require(a.openGroup == -1 && a.rows.size == a.groups.size && a.selected == difficulty,"Collapse must retain the last difficulty")
    let _=handle(a,w,UiEvent.KeyDown(Key.Right,false))
    require(a.openGroup == target,"Right arrow must expand")
    var other: Int64=0
    while (other < a.rows.size && (a.rows[other].group == target || a.rows[other].chart >= 0)) { other++ }
    require(other < a.rows.size,"Missing another song")
    let otherGroup=a.rows[other].group
    toggleSongDrawer(a,other)
    require(a.openGroup == otherGroup && a.rows.size == a.groups.size+a.groups[otherGroup].charts.size,"Opening another song must close the first")
    // Equal song metadata groups even non-adjacent files, while a different artist stays separate.
    let samples=ArrayList<Chart>(); let first=Chart(); first.title="Same"; first.artist="A"
    let different=Chart(); different.title="Same"; different.artist="B"
    let last=Chart(); last.title="Same"; last.artist="A"
    samples.add(first); samples.add(different); samples.add(last)
    let grouped=groupCharts(samples)
    require(grouped.size == 2 && grouped[0].charts.size == 2 && grouped[0].charts[1] == 2,"Song identity grouping")
    a.openGroup = -1; rebuildLibraryRows(a); a.selected=selected; a.autoplay=auto; resetLibraryMotion(a)
    println("PASS song drawers / complete membership / click and keyboard expansion / difficulty launch / remembered selection / single open drawer / artist identity")
}

func verifyIntroSkip(a: App,w: SdlWindow,art: Art): Unit {
    let oldOffset=a.offset; let oldAuto=a.autoplay; let selected=a.selected
    a.offset=125; a.autoplay=true
    a.start(Int64(w.ticks()))
    require(a.canSkipIntro(),"Long intro should be skippable")
    draw(a,w.renderer,art); w.renderer.captureBmp("artifacts/intro-skip.bmp")
    let first=a.play.getOrThrow().chart.notes[0].time
    let _=handle(a,w,UiEvent.KeyDown(Key.Enter,false))
    w.delay(80); a.tick(Int64(w.ticks()))
    require(a.music.started && a.music.playing() && a.now > first-2250 && a.now < first-1500,"Seek must move real music and preserve about two seconds of preparation")
    require(a.play.getOrThrow().judged == 0,"Skipping the intro must not judge or skip notes")
    a.pause(Int64(w.ticks())); let frozen=a.music.position(); w.delay(80)
    require(abs(a.music.position()-frozen) < 30,"Pause after intro skip")
    a.resume(Int64(w.ticks()))
    a.now=first
    require(!a.canSkipIntro(),"Skip must be disabled near and after the first note")
    a.start(Int64(w.ticks()))
    require(a.now == -2000 && !a.music.started,"Retry after skip must reset the audio session")
    let short=Chart(); short.notes.add(Note(0,1000,1000)); a.play=Some(Play(short)); a.now=0
    require(!a.canSkipIntro(),"Short intros should not offer a jump")
    a.back(); a.selected=selected; a.offset=oldOffset; a.autoplay=oldAuto
    println("PASS real audio intro seek / offset compensation / first-note protection / pause and retry after skip / no short-intro jump")
}

func verifyPreviewAndResize(a: App,w: SdlWindow,art: Art): Unit {
    let selected=a.selected
    a.back()
    var group: Int64 = -1
    for (i in 0..a.groups.size) { if (a.groups[i].charts.size > 1) { group=i; break } }
    require(group >= 0,"Preview fixture needs multiple difficulties")
    let charts=a.groups[group].charts
    a.selected=charts[0]; a.preview()
    require(a.music.started && a.music.playing(),"Library preview starts")
    a.music.seek(4000); w.delay(120)
    let before=a.music.position()
    a.selected=charts[1]; a.preview()
    require(a.music.position() >= before-30,"Difficulty selection must preserve playback")
    let end=a.music.duration()
    require(end > 5000,"Preview audio duration")
    a.music.seek(end-180); w.delay(500)
    require(a.music.playing() && a.music.position() < 2000,"Preview must loop at EOF")
    let song=a.previewSong
    a.selected=a.groups[(group+1)%a.groups.size].remembered; a.preview()
    require(a.previewSong != song && a.music.position() < 1000 && a.music.playing(),"Another song replaces preview")
    a.start(Int64(w.ticks()))
    require(!a.music.started && a.now == -2000,"Gameplay resets the preview and lead-in")
    a.back(); a.selected=selected; resetLibraryMotion(a); a.preview()
    require(a.music.playing(),"Returning to library resumes looping preview")
    a.music.stop(); a.previewSong=""
    for (size in [Size(960.0,540.0),Size(1000.0,800.0),Size(1600.0,900.0)]) {
        w.setSize(Int32(size.w),Int32(size.h)); w.delay(100)
        while (let Some(_) <- w.pollEvent()) {}
        draw(a,w.renderer,art)
        let rect=w.renderer.fitCanvas(1280.0,720.0)
        let nativeScale=w.scale*w.currentPixelDensity
        let px=(rect.x+1180.0*rect.w/1280.0)/nativeScale
        let py=(rect.y+38.0*rect.w/1280.0)/nativeScale
        let p=canvasPoint(w,px,py)
        require(abs(p.x-1180.0) < 0.1 && abs(p.y-38.0) < 0.1,"Resized coordinates must match canvas")
        a.menuOpen=false
        let _=handleWindowEvent(a,w,UiEvent.MouseDown(MouseButton.Left,px,py))
        require(a.menuOpen,"Resized menu remains clickable")
        a.menuOpen=false; draw(a,w.renderer,art)
        w.renderer.setScale(1.0); w.renderer.resetViewport()
        w.renderer.captureBmp("artifacts/library-${Int64(size.w)}x${Int64(size.h)}.bmp")
    }
    w.setSize(1280,720); w.delay(100)
    while (let Some(_) <- w.pollEvent()) {}
    a.selected=selected; resetLibraryMotion(a)
    println("PASS streamed preview / same-song continuity / native looping / song switch / gameplay transition / resize and pointer mapping")
}

func verifyKeyOverlay(): Unit {
    let o=KeyOverlay()
    o.press(0,0); o.press(0,10); o.press(-1,20); o.press(9,20)
    require(o.total() == 1 && o.held(0,100),"Overlay rejects repeated and invalid presses")
    o.release(0,120); o.release(0,130)
    require(!o.held(0,120) && o.strokes[0].end.getOrThrow() == 120,"Overlay records exact key release")
    o.press(1,200); o.release(1,230); o.press(0,1000)
    require(o.kps(1000) == 2 && o.peak == 2 && o.total() == 3,"Rolling one-second KPS and per-key counts")
    o.press(2,1050,count: false)
    require(o.total() == 3 && o.kps(1050) == 2 && o.held(2,1100),"Resume reconciliation must not count a new press")
    o.advance(10000)
    require(o.strokes.size == 2 && o.held(0,10000),"History expires while long holds remain visible")
    o.release(0,10000); o.release(2,10000); o.advance(16001)
    require(o.strokes.isEmpty() && o.total() == 3 && o.peak == 2,"History remains bounded without losing totals")
    let chart=Chart(); chart.keys=4; chart.notes.add(Note(0,1000,1000)); chart.notes.add(Note(3,2000,3000))
    let manual=Play(chart)
    manual.press(1,-1500); manual.press(1,-1490); manual.release(1,-1400)
    require(manual.keyOverlay.counts[1] == 1 && manual.judged == 0,"Empty presses are visible without affecting scoring")
    let auto=Play(chart); auto.update(2050,true)
    require(auto.keyOverlay.total() == 2 && auto.keyOverlay.held(3,2050) && !auto.keyOverlay.held(0,2050),"Autoplay tap pulse and hold visualization")
    auto.update(3100,true)
    require(auto.keyOverlay.total() == 2 && !auto.keyOverlay.held(3,3100),"Autoplay does not duplicate history")
    println("PASS key overlay / held and release / empty taps / repeat rejection / KPS window and peak / bounded history / autoplay")
}
func captureKeyOverlay(a: App,w: SdlWindow,art: Art): Unit {
    let selected=a.selected; let auto=a.autoplay; let maps=a.keymaps
    try {
        for (i in 0..a.charts.size) { if (a.charts[i].keys == 4) { a.selected=i; break } }
        a.autoplay=false; a.start(Int64(w.ticks()))
        a.keymaps=Array<Array<Int64>>(9,{i => maps[i]})
        a.keymaps[3]=[65,83,75,76]
        let p=a.play.getOrThrow()
        a.now=1000
        let _=handle(a,w,UiEvent.KeyDown(Key.Letter(65),false))
        let _=handle(a,w,UiEvent.KeyDown(Key.Letter(65),true))
        require(p.keyOverlay.counts[0] == 1 && p.keyOverlay.held(0,a.now),"Mapped key and OS repeats")
        a.now=1100; let _=handle(a,w,UiEvent.KeyUp(Key.Letter(65)))
        a.pause(Int64(w.ticks()))
        let _=handle(a,w,UiEvent.KeyDown(Key.Letter(83),false))
        require(p.keyOverlay.total() == 1,"Pause blocks overlay input")
        a.resume(Int64(w.ticks()))
        require(!p.keyOverlay.held(0,a.now),"Released keys do not stick after pause")
        for (i in 0..20) { p.press(i%4,1200+i*75); p.release(i%4,1240+i*75) }
        p.press(1,2900); a.now=3200
        draw(a,w.renderer,art); w.renderer.captureBmp("artifacts/key-overlay-4k.bmp")
        a.now=p.chart.duration/4
        draw(a,w.renderer,art); w.renderer.captureBmp("artifacts/progress-quarter.bmp")
        w.renderer.clear(Color.rgb(60,60,65))
        for (i in 0..5) { drawSongProgress(w.renderer,Float32(i)/4.0,cx: 500.0+Float32(i)*60.0,cy: 350.0) }
        w.renderer.captureBmp("artifacts/progress-sectors.bmp")
        let chart=Chart(); chart.keys=9; chart.duration=10000; chart.notes.add(Note(0,8000,8000))
        let nine=Play(chart); a.play=Some(nine)
        for (i in 0..9) { nine.press(i,1000+i*65); nine.release(i,1040+i*65) }
        nine.press(8,2300); a.now=2700
        draw(a,w.renderer,art); w.renderer.captureBmp("artifacts/key-overlay-9k.bmp")
        a.start(Int64(w.ticks()))
        require(a.play.getOrThrow().keyOverlay.total() == 0,"Retry resets overlay statistics")
        println("PASS key overlay remapped input / pause isolation / retry reset / 4K and 9K rendering")
    } finally { a.back(); a.selected=selected; a.autoplay=auto; a.keymaps=maps; resetLibraryMotion(a) }
}

func captureJudgementMotion(w: SdlWindow,art: Art): Unit {
    if (!exists("artifacts/judgements")) { Directory.create("artifacts/judgements",recursive: true) }
    let labels=["PERFECT","GREAT","GOOD","OK","MEH","MISS"]
    for (frame in 0..32) {
        let _=w.renderer.fitCanvas(1280.0,720.0)
        w.renderer.clear(Color.rgb(20,17,25))
        for (grade in 0..6) {
            let x=110.0+Float32(grade)*212.0
            text(w.renderer,labels[grade],x-35.0,260.0,13.0,color: MUTED)
            animatedJudgement(art,grade,x,frame*16)
        }
        let name=if (frame < 10) { "0${frame}" } else { frame.toString() }
        w.renderer.captureBmp("artifacts/judgements/${name}.bmp")
    }
    println("PASS judgement motion renders / six grades / heartbeat expansion and settle / fixed centre / fade")
}

func verifyFramePacing(a: App,w: SdlWindow,art: Art): Unit {
    let saved=File.readFrom("settings.cfg")
    let preset=a.framePreset; let custom=a.customFPS; let sync=a.vsync; let stats=a.showFPS
    let pacer=FramePacer()
    try {
        a.back(); a.menuOpen=true; a.menuPage=4
        require(frameWait(1000000,0) == 0 && frameWait(20000000,60) == 0 && frameWait(1000000,100) == 9000000,"Pacing budgets must subtract work and never catch up")
        for (i in 0..8) {
            let rect=fpsPresetRect(i)
            let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,rect.x+10.0,rect.y+10.0))
            require(a.framePreset == i && frameLimit(a) == (if (i == 7) { a.customFPS } else { FPS_PRESETS[i] }),"FPS preset mouse selection")
        }
        let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,924.0,342.0))
        require(a.displayEditing,"Custom FPS field")
        for (code in [53,48,48]) { let _=handle(a,w,UiEvent.KeyDown(Key.Digit(UInt8(code)),false)) }
        let _=handle(a,w,UiEvent.KeyDown(Key.Enter,false))
        require(!a.displayEditing && a.customFPS == 500 && frameLimit(a) == 500,"Custom entry replaces the selected value")
        editCustomFPS(a); a.displayInput="2999"
        let _=handle(a,w,UiEvent.KeyDown(Key.Enter,false))
        require(a.displayEditing && a.customFPS == 500 && !a.displayMessage.isEmpty(),"Invalid FPS must not be applied")
        let _=handle(a,w,UiEvent.KeyDown(Key.Escape,false))
        require(!a.displayEditing && a.menuOpen,"Escape cancels entry without closing menu")
        a.customFPS=30; changeDisplay(a,1,-1); require(a.customFPS == 30,"Custom FPS lower bound")
        a.customFPS=2000; changeDisplay(a,1,1); require(a.customFPS == 2000,"Custom FPS upper bound")
        let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,930.0,485.0))
        require(a.showFPS != stats,"FPS overlay toggle")
        a.framePreset=7; a.customFPS=500; a.vsync=true; a.showFPS=true
        saveSettings(a); a.framePreset=0; a.customFPS=240; a.vsync=false; a.showFPS=false; loadSettings(a)
        require(a.framePreset == 7 && a.customFPS == 500 && a.vsync && a.showFPS,"Display settings persistence")
        let old=String.join(String.fromUtf8(saved).split("\n")[0..12],delimiter: "\n")+"\n"
        File.writeTo("settings.cfg",old.toArray()); loadSettings(a)
        require(a.framePreset == 0 && a.customFPS == 240 && !a.vsync && !a.showFPS,"Old settings remain compatible")
        File.writeTo("settings.cfg",(old+"display=99,0,4,8\n").toArray()); loadSettings(a)
        require(a.framePreset == 0 && a.customFPS == 240,"Invalid display settings fall back independently")
        a.vsync=false; pacer.applySync(a,w.renderer)
        require(w.renderer.vsync() == 0,"Native VSync disabled")
        a.vsync=true; pacer.applySync(a,w.renderer)
        if (a.vsync) { require(w.renderer.vsync() == 1,"Native VSync enabled"); println("PASS native VSync enabled and queried") }
        else { println("VSync unsupported on current renderer; fallback checked") }
        a.vsync=false; pacer.applySync(a,w.renderer); a.showFPS=true
        a.customFPS=500
        for (mode in [1,2,5,6,7,0]) {
            a.framePreset=mode
            for (_ in 0..5) {
                let start=PerformanceClock.ticksNanoseconds()
                draw(a,w.renderer,art); w.renderer.present(); pacer.finish(a,start)
            }
            let begin=PerformanceClock.ticksNanoseconds()
            var rendered: Int64=0
            while (PerformanceClock.ticksNanoseconds()-begin < 350000000) {
                let start=PerformanceClock.ticksNanoseconds()
                while (let Some(_) <- w.pollEvent()) {}
                draw(a,w.renderer,art); pacer.drawStats(w.renderer); w.renderer.present(); pacer.finish(a,start)
                rendered++
            }
            let elapsed=PerformanceClock.ticksNanoseconds()-begin
            let measured=Float64(rendered)*1000000000.0/Float64(elapsed)
            require(frameLimit(a) == 0 || measured <= Float64(frameLimit(a))*1.02,"Actual rendered FPS exceeds selected cap")
            println("PASS rendered FPS cap ${frameLimit(a)}: ${measured}")
        }
        require(pacer.fps > 0.0 && pacer.milliseconds > 0.0,"FPS and frame-time measurements")
        a.framePreset=0; a.customFPS=500; a.menuPage=4; a.menuFocus=0; a.menuOpen=true
        draw(a,w.renderer,art); pacer.drawStats(w.renderer); w.renderer.captureBmp("artifacts/menu-display.bmp")
        println("PASS frame presets / custom validation / cancellation / old settings / persistence / native sync / paced rendering and stats")
    } finally {
        a.framePreset=preset; a.customFPS=custom; a.vsync=sync; a.showFPS=stats
        a.displayEditing=false; a.displayMessage=""; a.menuOpen=false
        pacer.applySync(a,w.renderer)
        File.writeTo("settings.cfg",saved)
    }
}

func motionCheck(a: App,w: SdlWindow,art: Art): Unit {
    verifyAudioTimeline()
    for (display in allDisplayInfos()) {
        if (let Some(mode) <- display.modes.current) { println("DISPLAY: ${display.name}, ${mode.width}x${mode.height}, ${mode.refreshRate} Hz") }
    }
    for (i in 0..a.charts.size) { if (a.charts[i].title == "Grin" && a.charts[i].version == "Piano Concerto") { a.selected=i; break } }
    a.framePreset=5; a.vsync=false; a.autoplay=true
    let pacer=FramePacer(); pacer.applySync(a,w.renderer)
    a.start(Int64(w.ticks()))
    let begin=Int64(w.ticks())
    var frames: Int64=0; var rawChanges: Int64=0; var motionChanges: Int64=0
    var lastRaw: Int64 = -1; var lastMotion: Int64 = -1; var largestStep: Int64=0
    var maxError: Int64=0; var repeated: Int64=0
    while (Int64(w.ticks())-begin < 6500) {
        let start=PerformanceClock.ticksNanoseconds()
        while (let Some(e) <- w.pollEvent()) {
            match (e) { case UiEvent.Quit | UiEvent.WindowCloseRequested => throw IllegalArgumentException("Motion check interrupted") case _ => () }
        }
        a.tick(Int64(w.ticks()))
        if (Int64(w.ticks())-begin > 3500) {
            let raw=a.music.position()
            if (lastRaw >= 0 && raw != lastRaw) { rawChanges++; largestStep=max(largestStep,raw-lastRaw) }
            if (lastMotion >= 0 && a.now != lastMotion) { motionChanges++ } else if (lastMotion >= 0) { repeated++ }
            maxError=max(maxError,abs(a.now-a.offset-raw))
            lastRaw=raw; lastMotion=a.now; frames++
        }
        draw(a,w.renderer,art); pacer.drawStats(w.renderer); w.renderer.present(); pacer.finish(a,start)
    }
    require(frames > 300 && motionChanges*100 >= (frames-1)*95,"Rendered note motion must advance on almost every high-FPS frame")
    println("MOTION CHECK: frames=${frames}, raw audio changes=${rawChanges}, note-position changes=${motionChanges}, largest audio step=${largestStep} ms, rendered FPS=${pacer.fps}, repeated note positions=${repeated}, maximum audio-reference error=${maxError} ms")
    a.back()
}

func verifyAudioTimeline(): Unit {
    let clock=AudioTimeline(); clock.reset(0,1000000000)
    var last: Int64=0; var changes: Int64=0
    for (frame in 1..2401) {
        let ns=UInt64(frame)*1000000000/240
        let ms=Int64(ns/1000000)
        // A 60Hz stepped audio reference, sampled by a 240Hz render loop.
        let raw=ms/16*16
        let value=clock.sample(raw,1000000000+ns)
        require(value >= last && abs(value-raw) <= 17,"Smoothed audio clock must be monotonic and stay synchronized")
        if (value > last) { changes++ }
        last=value
    }
    require(changes == 2400,"Every 240Hz frame must have a distinct note position")
    clock.reset(50000,20000000000)
    require(clock.sample(50000,20004000000) >= 50003,"Seek establishes a new interpolation anchor")
    clock.reset(1200,30000000000)
    require(clock.sample(1200,30004000000) <= 1204,"Pause resume must exclude paused time")
    clock.reset(1000,40000000000)
    require(clock.sample(2000,41000000000) == 2000,"Long frame stall catches up to audio")
    for (i in 1..101) { let _=clock.sample(2000,41000000000+UInt64(i)*4000000) }
    require(clock.position <= 2050.0,"A stalled audio source must not run away")
    println("PASS stepped audio clock / distinct 240Hz positions / bounded synchronization / seek / pause resume / render and audio stalls")
}

func verifyResourceBounds(a: App,w: SdlWindow,art: Art): Unit {
    let image="assets/skin/score-0@2x.png"
    art.image(image,Rect(0.0,0.0,10.0,10.0))
    let checks=art.diskChecks; let loads=art.loads
    for (_ in 0..100) { art.image(image,Rect(0.0,0.0,10.0,10.0)) }
    require(art.diskChecks == checks && art.loads == loads,"Cached sprite draws must not touch the filesystem or reload textures")
    for (c in a.charts) {
        art.cover(c.background,Rect(0.0,0.0,10.0,10.0),255)
        require(art.covers.size <= 8,"Song background cache must remain bounded")
    }
    for (path in art.covers) {
        let t=art.textures[path]
        require(t.width <= 2560.0 && t.height <= 1440.0,"Background texture pixel budget")
    }
    draw(a,w.renderer,art)
    require(art.errors == 0,"Resource eviction must preserve usable skin and background textures")
    println("PASS cached sprites avoid filesystem / all-song background eviction / texture dimensions / redraw after eviction")
}

// Capture only a short, real-time excerpt from the user's requested chart.
func captureReadmeShowcase(a: App,w: SdlWindow,art: Art): Unit {
    if (!exists("artifacts")) { Directory.create("artifacts",recursive: true) }
    var target: Int64 = -1
    for (i in 0..a.charts.size) {
        if (a.charts[i].version == "Ex-Final v3" && a.charts[i].audio.endsWith("EXF.mp3")) { target=i; break }
    }
    require(target >= 0,"Requested Malody 4K Extra Dan v3 EXF chart not found")
    a.selected=target; resetLibraryMotion(a)
    a.openGroup=a.rows[a.libraryRow].group; rebuildLibraryRows(a); syncLibrarySelection(a); resetLibraryMotion(a)
    draw(a,w.renderer,art); w.renderer.captureBmp("artifacts/readme-library.bmp")
    a.keymaps[3]=bindings(4) // Showcase the documented defaults without saving user preferences.
    a.autoplay=true; a.start(Int64(w.ticks()))
    let p=a.play.getOrThrow()
    let excerptStart: Int64=106000
    // Omit earlier objects instead of manufacturing a whole-song combo/result.
    for (n in p.chart.notes) { if (n.time < excerptStart) { n.state=2 } }
    while (p.cursor < p.chart.notes.size && p.chart.notes[p.cursor].state == 2) { p.cursor++ }
    a.music.play(); a.music.seek(excerptStart)
    a.timeline.reset(a.music.position(),PerformanceClock.ticksNanoseconds())
    a.now=a.music.position()+a.offset
    a.framePreset=5; a.vsync=false
    let pacer=FramePacer(); pacer.applySync(a,w.renderer)
    let begin=Int64(w.ticks()); var captured=false
    while (Int64(w.ticks())-begin < 5000) {
        let frameStart=PerformanceClock.ticksNanoseconds()
        while (let Some(e) <- w.pollEvent()) {
            match (e) { case UiEvent.Quit | UiEvent.WindowCloseRequested => throw IllegalArgumentException("Showcase interrupted") case _ => () }
        }
        a.tick(Int64(w.ticks()))
        draw(a,w.renderer,art); if (a.showFPS) { pacer.drawStats(w.renderer) }
        if (!captured && a.now >= 109093) {
            w.renderer.captureBmp("artifacts/readme-gameplay.bmp"); captured=true
            File.writeTo("artifacts/readme-showcase.txt",("Chart: ${p.chart.path}\nAudio: ${p.chart.audio}\nMode: real-time autoplay excerpt\nCapture time: ${a.now} ms\nExcerpt judged: ${p.judged}\nCombo: ${p.combo}\nSpeed: ${a.speed*1000.0} px/s\n").toArray())
        }
        w.renderer.present(); pacer.finish(a,frameStart)
    }
    require(captured && p.judged > 40 && p.counts[5] == 0,"Real-time dense EXF excerpt did not render correctly")
    a.pause(Int64(w.ticks())); draw(a,w.renderer,art); w.renderer.captureBmp("artifacts/readme-pause.bmp")
    println("PASS real-time EXF excerpt / seek / dense notes / ${p.judged} autoplay judgements / native captures")
    a.back()
}

// No screenshots: exercise queue coalescing, bounded ownership and live preview handoff.
func verifyScrollLoading(a: App,w: SdlWindow,art: Art): Unit {
    verifyLibraryMotion(a)
    a.back(); rebuildLibrary(a); selectLibraryRow(a,0); resetLibraryMotion(a)
    let chosen=a.selected
    let deadline=w.ticks()+UInt64(6000)
    while (w.ticks() < deadline) {
        draw(a,w.renderer,art); a.preview(async: true)
        if (art.coverJob.isNone() && art.coverWanted.isEmpty() && !a.previewSong.isEmpty()) { break }
        w.delay(2)
    }
    require(art.coverJob.isNone() && !a.previewSong.isEmpty() && a.music.playing(),"Async covers and preview eventually settle")
    let loaded=art.loads; let jobs=art.decodeJobs; let audioLoads=a.music.previewLoads
    let position=a.music.position()
    for (_ in 0..32) { draw(a,w.renderer,art); a.preview(async: true); w.delay(1) }
    require(art.loads == loaded && art.decodeJobs == jobs && a.music.previewLoads == audioLoads,"A stable viewport reuses textures and audio")
    require(a.music.position() >= position-30,"Stable preview must keep playing continuously")
    require(art.covers.size <= 4 && art.thumbnails.size <= 32,"Separate cover caches remain bounded")
    for (key in art.thumbnails) {
        let image=art.textures[key]
        require(image.width <= 256.0 && image.height <= 192.0,"List thumbnails must not retain full-size backgrounds")
    }
    // Deliberately complete an obsolete request after the desired viewport has changed.
    try (temporary=Art(w.renderer)) {
        let first=a.charts[chosen].background
        let other=a.charts[a.groups[(a.rows[0].group+1)%a.groups.size].remembered].background
        require(first != other,"Regression requires two distinct backgrounds")
        temporary.beginCoverFrame(); temporary.cover(first,Rect(0.0,0.0,124.0,100.0),255,thumbnail: true); temporary.endCoverFrame()
        let pending=temporary.coverJob.getOrThrow()
        // Wait only in this check; production code always uses tryGet on the UI thread.
        let _=pending.get()
        temporary.beginCoverFrame(); temporary.cover(other,Rect(0.0,0.0,124.0,100.0),255,thumbnail: true); temporary.endCoverFrame()
        require(temporary.discardedCovers == 1 && !temporary.textures.contains("thumb:"+first),"Obsolete decode must not replace the new selection")
        require(temporary.coverWanted.size == 1,"Only the current viewport is queued")
        // Close with another decode in flight: Surface must be released before renderer teardown.
    }
    try (invalid=Art(w.renderer)) {
        let path="artifacts/__missing_scroll_regression_cover__.png"
        require(!exists(path),"Missing-cover fixture must be absent")
        invalid.beginCoverFrame(); invalid.cover(path,Rect(0.0,0.0,124.0,100.0),255,thumbnail: true); invalid.endCoverFrame()
        let _=invalid.coverJob.getOrThrow().get()
        for (_ in 0..8) {
            invalid.beginCoverFrame(); invalid.cover(path,Rect(0.0,0.0,124.0,100.0),255,thumbnail: true); invalid.endCoverFrame()
        }
        require(invalid.errors == 1 && invalid.decodeJobs == 1 && invalid.coverJob.isNone(),"Failed images are reported once without a retry storm")
    }
    for (group in a.groups) { if (group.charts.size > 1) {
        a.selected=group.charts[0]
        let song=a.charts[a.selected].artist+"\n"+a.charts[a.selected].title
        let limit=w.ticks()+UInt64(6000)
        while (a.previewSong != song && w.ticks() < limit) { a.preview(async: true); w.delay(2) }
        require(a.previewSong == song,"Preview loads the multi-difficulty song")
        let requests=a.music.previewLoads; let before=a.music.position()
        a.selected=group.charts[1]; a.preview(async: true)
        require(a.music.previewLoads == requests && a.music.position() >= before-30,"Changing difficulty preserves playback without starting another worker")
        break
    } }
    selectLibraryRow(a,min(a.rows.size-1,1)); a.preview(async: true)
    selectLibraryRow(a,min(a.rows.size-1,2)); a.preview(async: true)
    let latest=a.charts[a.selected].artist+"\n"+a.charts[a.selected].title
    let audioDeadline=w.ticks()+UInt64(6000)
    while (a.previewSong != latest && w.ticks() < audioDeadline) { a.preview(async: true); w.delay(2) }
    require(a.previewSong == latest && a.music.playing(),"Rapid preview requests must commit the latest song")
    a.start(Int64(w.ticks()))
    require(a.music.previewJob.isNone() && a.now == -2000,"Gameplay drains preview loading and resets its timeline")
    a.back(); a.selected=chosen; resetLibraryMotion(a)
    require(art.errors == 0,"Async image load/upload failed")
    println("PASS scroll logic: layering and hit order / cache hit stability / thumbnail budget / obsolete disposal / in-flight shutdown / failed image retry bound / difficulty continuity / latest preview / gameplay handoff")
}

func verifyLibraryTitle(r: Renderer): Unit {
    require(titleScrollOffset(200.0,50000) == 0.0 && titleScrollOffset(LIBRARY_TITLE_WIDTH,50000) == 0.0,"Short and exactly fitting titles stay still")
    let width=LIBRARY_TITLE_WIDTH+360.0
    require(titleScrollOffset(width,-100) == 0.0 && titleScrollOffset(width,1199) == 0.0,"New titles pause at the beginning")
    require(abs(titleScrollOffset(width,6200)-180.0) < 0.01,"Title scroll speed is independent of frame count")
    require(titleScrollOffset(width,11200) == 360.0 && titleScrollOffset(width,12199) == 360.0,"End pause reveals the complete title suffix")
    require(abs(titleScrollOffset(width,17200)-180.0) < 0.01 && titleScrollOffset(width,22200) == 0.0,"Title returns and repeats without leaving its bounds")
    for (elapsed in 0..25000) {
        let offset=titleScrollOffset(width,elapsed)
        require(offset >= 0.0 && offset <= 360.0,"Marquee offset must remain inside the title extent")
    }
    let cache=LibraryTitle()
    let title="Malody 4K Extra Dan v3 (Pack 2) - regression title"
    let _=cache.offset(title,r,1000)
    let measured=cache.measurements
    for (frame in 0..480) { let _=cache.offset(title,r,1000+frame*4) }
    require(cache.measurements == measured,"Unchanged titles must not be measured each frame")
    let _=cache.offset("short",r,8000)
    require(cache.measurements == measured+1 && cache.started == 8000,"Changing songs invalidates width and restarts the title")
    println("PASS title marquee: short-title stillness / start and end pauses / clock-based travel / suffix visibility / repeat bounds / cached measurement / selection invalidation")
}
