package orz_mania

import sdl.*
import std.fs.{File,exists,remove}

// Deterministic timing/input checks plus the native mixer clock; no screenshots.
func verifyCalibration(a: App,w: SdlWindow): Unit {
    let samples=OffsetSamples()
    samples.reset(false,120,80)
    require(!samples.add(750) && !samples.add(1870),"Warmup and distant taps are excluded")
    for (beat in 3..11) {
        require(samples.add(beat*750+45),"One tap per beat is accepted")
        require(!samples.add(beat*750+46),"Repeat taps cannot bias the estimate")
    }
    require(samples.ready() && samples.suggestion == -45 && samples.count == 8,"Late audio taps need a negative judgement offset, independent of old offsets")
    require(samples.add(11*750-240) && samples.suggestion == -45 && samples.inliers == 8,"An isolated outlier does not pull the median")
    samples.reset(false,0,0)
    for (beat in 3..43) { let _=samples.add(beat*750-63) }
    require(samples.count == 32 && samples.ready() && samples.suggestion == 65,"Early taps give a positive offset; sample storage is bounded and rounds to 5ms")
    samples.reset(true,-45,20)
    for (beat in 3..15) { let _=samples.add(beat*750+45-20+70) }
    require(samples.ready() && samples.suggestion == -95,"Visual taps estimate a new judgement offset from the fixed visual reference")
    require(visualJudgementOffset(-999,-500) == -300 && visualJudgementOffset(999,500) == 300,"Linked correction keeps judgement and visual offsets within supported bounds")
    samples.reset(false,0,0)
    for (beat in 3..15) { let _=samples.add(beat*750+if (beat%2 == 0) { 90 } else { -90 }) }
    require(!samples.ready(),"Unstable alternating inputs are not ready to apply")
    require(calibrationClamp(999) == 300 && calibrationClamp(-999) == -300 && calibrationRound(-17) == -15,"Manual bounds and signed rounding")
    let wave=calibrationWave()
    require(wave.size == 1152044 && String.fromUtf8(wave[0..4]) == "RIFF" && String.fromUtf8(wave[8..12]) == "WAVE","Generated loop has a complete bounded WAV payload")
    require(wave[44] == 0 && wave[100] != 0,"Generated beat has a smooth onset and audible PCM data")
    let existed=exists("settings.cfg")
    let saved=if (existed) { File.readFrom("settings.cfg") } else { Array<UInt8>() }
    let offset=a.offset; let visual=a.visualOffset; let now=a.now; let english=a.english
    try {
        a.back(); a.offset = -35; a.visualOffset=25; a.now=5000
        require(visualNoteTime(a) == 5025 && a.now == 5000 && a.offset == -35,"Visual offset does not change judgement time")
        a.preview(); let wasPlaying=a.music.playing()
        a.menuOpen=true; a.menuPage=0
        let entry=calibrationEntryRect()
        let _=handleMenu(a,w,UiEvent.MouseDown(MouseButton.Left,entry.x+2.0,entry.y+2.0))
        require(a.calibration.isSome(),"Settings button opens the guide")
        let g=a.calibration.getOrThrow()
        require(g.visual && g.showNotes && !g.sound,"Guide opens in visual-first mode")
        let requests=a.music.previewLoads; a.preview(async: true)
        require(a.music.previewLoads == requests && !a.music.playing(),"Guide pauses preview and suppresses new preview jobs")
        g.mode(true); require(g.showNotes && !g.sound && !g.running,"Visual mode defaults to visible notes and muted sound")
        g.start(); w.delay(100); g.tick(); let first=g.position
        w.delay(100); g.tick()
        require(g.running && first > 0 && g.position > first,"Muted native audio clock advances monotonically")
        require(unsafe { MIX_SetTrackPlaybackPosition(g.audio.track,MIX_TrackMSToFrames(g.audio.track,11900)) },"Seek near loop boundary")
        g.tick(); let beforeLoop=g.position
        w.delay(220); g.tick()
        require(g.position > beforeLoop && g.audio.loopBase == CALIBRATION_LOOP,"Loop wrap keeps the calibration clock continuous")
        g.start(); w.delay(100); g.tick()
        g.samples.warmUntil=0
        let before=g.samples.count
        let _=handleCalibration(a,UiEvent.KeyDown(Key.Space,true))
        require(g.samples.count == before,"Repeated key events are ignored")
        let _=handleCalibration(a,UiEvent.KeyDown(Key.Space,false))
        require(g.samples.count == before+1,"Space input reaches the sampler")
        g.samples.reset(true,g.draftAudio,g.draftVisual,now: g.position); g.samples.warmUntil=0
        let lane=calibrationLaneRect()
        let _=handleCalibration(a,UiEvent.MouseDown(MouseButton.Left,lane.x+10.0,lane.y+10.0))
        require(g.samples.count == 1 && a.offset == -35 && a.visualOffset == 25,"Mouse sampling also leaves live settings untouched")
        g.hasChanges=true
        require(!g.canApply(),"Incomplete live samples cannot apply a suggestion")
        let _=handleWindowEvent(a,w,UiEvent.WindowFocusLost)
        require(!g.running,"Focus loss stops calibration")
        g.mode(false); require(!g.showNotes && g.sound && g.samples.count == 0,"Changing mode stops and clears prior samples")
        require(!g.canApply(),"Changing mode clears the previous mode's apply state")
        g.sound=false; g.start(); require(!g.running,"Audio mode cannot start without its primary cue")
        g.adjust(5); require(g.draftAudio == -30 && a.offset == -35,"Manual adjustment changes only the draft")
        let _=handleCalibration(a,UiEvent.KeyDown(Key.Escape,false))
        require(g.isClosed() && a.calibration.isNone() && a.offset == -35 && a.visualOffset == 25,"Cancel releases resources and discards drafts")
        if (wasPlaying) { require(a.music.playing(),"Closing guide resumes the continuous preview") }
        // Reproduce the reported flow: old audio offset, then visual calibration and Apply.
        a.offset = -70; a.visualOffset=20
        openCalibration(a); let apply=a.calibration.getOrThrow()
        apply.adjust(5)
        require(apply.draftAudio == -65 && apply.draftVisual == 65 && a.offset == -70,"Visual manual correction changes judgement while preserving the neutral note reference")
        apply.mode(false); apply.adjust(10); apply.mode(true)
        require(!apply.canApply() && apply.draftAudio == -70 && apply.draftVisual == 70 && apply.cueTime() == 0,"An unsampled visual mode cannot apply the previous audio draft or inherit its reference shift")
        apply.start()
        for (beat in 3..15) { apply.recordTap(beat*750+120) }
        require(apply.canApply() && apply.draftAudio == -120 && apply.draftVisual == 120,"Visual result replaces the old audio offset and maintains the neutral visual timeline")
        for (beat in 20..52) { apply.recordTap(beat*750+50+if (beat%2 == 0) { 90 } else { -90 }) }
        apply.stop(); require(!apply.canApply(),"Stopping an unstable sample set does not re-enable stale suggestions")
        apply.start(); require(!apply.canApply(),"Restart requires new valid samples")
        for (beat in 3..15) { apply.recordTap(beat*750+120) }
        let rect=calibrationActionRect(2)
        let _=handleCalibration(a,UiEvent.MouseDown(MouseButton.Left,rect.x+2.0,rect.y+2.0))
        require(a.calibration.isNone() && a.offset == -120 && a.visualOffset == 120,"Visual Apply updates the main settings value, not only a hidden visual offset")
        let play=Play(parseChart(SCORE_TEST_MAP,"Songs/test/visual-calibration.osu"))
        a.now=1120+a.offset; play.press(0,a.now)
        require(play.error == 0 && play.counts[0] == 1 && visualNoteTime(a) == 1120,"The same visual input now scores PERFECT without moving the neutral reference notes")
        a.offset=0; a.visualOffset=0; loadSettings(a)
        require(a.offset == -120 && a.visualOffset == 120,"Visual-first result survives save/reload")
        openCalibration(a); let audio=a.calibration.getOrThrow(); audio.mode(false); audio.start()
        for (beat in 3..15) { audio.recordTap(beat*750+45) }
        let _=handleCalibration(a,UiEvent.MouseDown(MouseButton.Left,rect.x+2.0,rect.y+2.0))
        require(a.offset == -45 && a.visualOffset == 120,"Explicitly applying optional audio calibration still works")
        File.writeTo("settings.cfg",String.fromUtf8(File.readFrom("settings.cfg")).replace("visualOffset=120","visualOffset=999").toArray())
        loadSettings(a); require(a.offset == -45 && a.visualOffset == 0,"Invalid optional visual setting preserves the valid legacy settings")
        a.screen=2; openCalibration(a)
        require(a.calibration.isNone(),"Gameplay pause retains only the skin Retry/Quit actions")
        a.screen=0; openCalibration(a); let cleanup=a.calibration.getOrThrow()
        a.back(); require(cleanup.isClosed() && a.calibration.isNone(),"Returning to library closes calibration before music teardown")
        a.english=true; require(tr(a,"目押") == "Visual" && tr(a,"应用") == "Apply","Guide labels follow the active language")
        println("PASS calibration: visual-first defaults / visual judgement override and PERFECT input / fixed note reference / mode isolation / restart and stopped unstable samples / signs / bounded offsets and samples / native clock / audio option / cancel and apply / persistence / focus loss / resource cleanup")
    } finally {
        closeCalibration(a,resume: false); a.back()
        if (existed) { File.writeTo("settings.cfg",saved); loadSettings(a) }
        else if (exists("settings.cfg")) { remove("settings.cfg") }
        a.offset=offset; a.visualOffset=visual; a.now=now; a.english=english
    }
}
