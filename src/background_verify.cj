package orz_mania

import sdl.*
import std.fs.File

func verifyBackgroundOpacity(a: App,w: SdlWindow): Unit {
    let saved=File.readFrom("settings.cfg"); let fps=a.customFPS; let preset=a.framePreset
    try {
        a.menuOpen=true; a.menuPage=4
        require(backgroundAlpha(0) == 0 && backgroundAlpha(100) == 255 && backgroundAlpha(50) == 127,"Background visibility maps monotonically to alpha endpoints")
        a.backgroundOpacity=0; changeDisplay(a,4,-1); require(a.backgroundOpacity == 0,"Background lower bound")
        a.backgroundOpacity=100; changeDisplay(a,4,1); require(a.backgroundOpacity == 100,"Background upper bound")
        let minus=backgroundStepRect(false)
        let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,minus.x+16.0,minus.y+16.0))
        require(a.backgroundOpacity == 95 && a.menuFocus == 4,"Background step button shares its drawing bounds")
        let rect=backgroundValueRect()
        let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,rect.x+10.0,rect.y+10.0))
        require(a.displayEditing && a.displayOpacity,"Background field opens the percentage editor")
        a.displayInput="73"; let _=handle(a,w,UiEvent.KeyDown(Key.Enter,false))
        require(a.backgroundOpacity == 73 && !a.displayEditing && a.customFPS == fps && a.framePreset == preset,"Percentage input does not change FPS settings")
        editBackgroundOpacity(a); a.displayInput="101"; let _=handle(a,w,UiEvent.KeyDown(Key.Enter,false))
        require(a.displayEditing && a.backgroundOpacity == 73,"Out-of-range background values are rejected")
        let _=handle(a,w,UiEvent.KeyDown(Key.Escape,false))
        require(!a.displayEditing && !a.displayOpacity && a.menuOpen && a.backgroundOpacity == 73,"Escape cancels background editing without closing the menu or leaving a stale editor target")
        saveSettings(a); a.backgroundOpacity=0; loadSettings(a)
        require(a.backgroundOpacity == 73,"Background preference survives restart")
        let config=String.fromUtf8(File.readFrom("settings.cfg"))
        for (invalid in ["-1","101","bad"]) {
            File.writeTo("settings.cfg",config.replace("backgroundOpacity=73","backgroundOpacity="+invalid).toArray()); loadSettings(a)
            require(a.backgroundOpacity == 30 && a.customFPS == fps,"Invalid optional setting defaults independently")
        }
        File.writeTo("settings.cfg",config.replace("backgroundOpacity=73\n","").toArray()); loadSettings(a)
        require(a.backgroundOpacity == 30,"Old configurations use the new 30% default")
        a.menuPage=4; a.menuFocus=3
        let _=handle(a,w,UiEvent.KeyDown(Key.Down,false)); require(a.menuFocus == 4,"Keyboard navigation reaches background visibility")
        a.backgroundOpacity=90; let _=handle(a,w,UiEvent.KeyDown(Key.Home,false))
        require(a.backgroundOpacity == 30,"Home restores default visibility")
        editCustomFPS(a); require(!a.displayOpacity,"FPS editor clears the percentage target")
        let _=handle(a,w,UiEvent.KeyDown(Key.Escape,false))
        println("PASS background visibility: alpha endpoints / bounds / mouse and keyboard / numeric entry and cancellation / FPS isolation / persistence / invalid and legacy fallback")
    } finally {
        File.writeTo("settings.cfg",saved); loadSettings(a); a.menuOpen=false; a.displayEditing=false; a.displayOpacity=false; a.displayMessage=""
    }
}
