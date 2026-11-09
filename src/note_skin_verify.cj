package orz_mania

import sdl.*
import std.fs.{File,exists}

func verifyNoteSkins(a: App,w: SdlWindow,art: Art): Unit {
    let saved=File.readFrom("settings.cfg"); let auto=a.autoplay; let now=a.now
    let originalJ=JUDGE_IMAGES.clone(); let originalScore=SCORE_IMAGES.clone()
    try {
        verifyDiamondPixels(a,w,art)
        a.back(); a.menuOpen=true; a.menuPage=0; a.noteSkin=0
        let rect=noteSkinValueRect()
        require(rect.w == settingValueRect(426.0).w && rect.h == 32.0 && rect.y+rect.h <= 576.0,"Skin selector uses shared sizing inside the existing panel")
        for (expected in [1,2,3,0]) {
            let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,rect.x+rect.w/2.0,rect.y+rect.h/2.0))
            require(a.noteSkin == expected && a.menuFocus == 7,"Mouse cycles all three note skins")
        }
        let _=handle(a,w,UiEvent.KeyDown(Key.Left,false)); require(a.noteSkin == 3,"Left cycles backwards")
        let _=handle(a,w,UiEvent.KeyDown(Key.Enter,false)); require(a.noteSkin == 0 && a.menuOpen,"Enter cycles skin without closing the menu")
        a.menuFocus=4; moveSettingsFocus(a,1); require(a.menuFocus == 7,"Skin follows Language in focus order")
        moveSettingsFocus(a,-1); require(a.menuFocus == 4,"Skin keyboard navigation is reversible")
        a.noteSkin=3; saveSettings(a); a.noteSkin=0; loadSettings(a)
        require(a.noteSkin == 3,"Note skin persists independently of score rules")
        for (english in [false,true]) {
            a.english=english
            let labels=if (english) { ["Circle","Diamond","Bar","Arrows"] } else { ["圆形","菱形","砖形","箭头"] }
            for (skin in 0..4) { a.noteSkin=skin; require(noteSkinName(a) == labels[skin],"Every skin name follows the selected language") }
        }
        let config=String.fromUtf8(saved)
        for (bad in ["-1","4","nan"]) {
            File.writeTo("settings.cfg",(config+"\nnoteSkin="+bad+"\n").toArray()); loadSettings(a)
            require(a.noteSkin == 0,"Invalid optional skin falls back to Circle")
        }
        var legacy=""
        for (row in config.split("\n")) { if (!row.startsWith("noteSkin=")) { legacy+=row+"\n" } }
        File.writeTo("settings.cfg",legacy.toArray()); a.noteSkin=2; loadSettings(a)
        require(a.noteSkin == 0,"Legacy settings default to Circle")
        a.menuOpen=false; a.autoplay=true
        require(!exists("assets/notes/diamond") && !exists("assets/notes/bars"),"Old imported R skin copies are removed")
        require(noteLayout(0,4).width == 416.0,"Circle preserves its existing field width")
        require(noteLayout(1,4).widths[0] == 68.0*NOTE_LAYOUT_SCALE && noteLayout(2,4).widths[0] == 68.0*NOTE_LAYOUT_SCALE,"New variants use the bundled skin family's column width")
        require(noteSpriteKind(0,4,false) == 0 && noteSpriteKind(1,4,false) == 1 && noteSpriteKind(3,4,true) == 2,"Shared family mapping: outer pink, inner white, pastel hold head")
        for (skin in 0..4) {
            a.noteSkin=skin; prepareNoteSkin(a,art)
            for (keys in 1..10) {
                let c=Chart(); c.keys=keys; c.duration=2500
                c.notes.add(Note(0,500,500)); c.notes.add(Note(keys-1,1000,2000)); c.notes.add(Note(0,1600,1600))
                let p=Play(c); p.update(1100,true); a.now=1100
                require(p.hitAt[keys-1] == 1000,"Autoplay drives the same hit effect clock")
                for (lane in 0..keys) {
                    require(arrowDirection(lane,keys) >= 0 && arrowDirection(lane,keys) < 4,"Arrow mapping covers 1K-9K")
                    require(noteSpriteKind(lane,keys,false) >= 0 && noteSpriteKind(lane,keys,true) == 2,"Family note mapping covers every lane")
                }
                drawPlay(a,p,w.renderer,art)
                require(p.judged == 1 && p.counts[0] == 1 && p.chart.notes[1].state == 1,"Skin rendering cannot change hit or hold judgement")
            }
        }
        for (skin in 0..4) {
            for (path in SKIN_NOTES[skin]) { require(art.texture(path).isSome(),"In-project note resource exists") }
            for (path in SKIN_KEYS[skin]) { require(art.texture(path).isSome(),"In-project receptor resource exists") }
            let body=art.texture(SKIN_BODIES[skin]).getOrThrow()
            require(body.width == 128.0 && body.height == 65.0,"Long source sprites use bounded compact GPU textures")
        }
        for (path in ARROW_HOLDS) { require(art.texture(path).isSome(),"Arrow hold heads exist") }
        for (i in 0..4) { require(arrowDirection(i,4) == i,"4K arrows follow left/down/up/right") }
        let reads=art.diskChecks; let loads=art.loads
        let c=Chart(); c.notes.add(Note(0,1000,2000)); c.duration=2000
        let play=Play(c); play.press(0,1000); a.now=1100
        require(play.hitAt[0] == 1000,"Manual hit starts the hit effect clock")
        for (_ in 0..30) { drawPlay(a,play,w.renderer,art) }
        require(art.diskChecks == reads && art.loads == loads,"Repeated skin rendering does not read or reload images")
        for (i in 0..JUDGE_IMAGES.size) { require(JUDGE_IMAGES[i] == originalJ[i],"Judgement images remain shared") }
        for (i in 0..SCORE_IMAGES.size) { require(SCORE_IMAGES[i] == originalScore[i],"Score images remain shared") }
        require(art.errors == 0,"All note skin resources render successfully")
        println("PASS note skins: mouse / keyboard / shared controls / persistence / invalid and legacy fallback / 1K-9K taps and holds / manual and autoplay pulse / shared score art / cached rendering")
    } finally {
        a.back(); a.autoplay=auto; a.now=now
        File.writeTo("settings.cfg",saved); loadSettings(a)
    }
}

// Check geometric occupancy in memory; no screenshots or visual baselines are written.
foreign {
    func SDL_GetWindowFromID(id: UInt32): CPointer<Unit>
    func SDL_GetRenderer(window: CPointer<Unit>): CPointer<Unit>
    func SDL_RenderReadPixels(renderer: CPointer<Unit>,rect: CPointer<Unit>): CPointer<Unit>
    func SDL_ReadSurfacePixel(surface: CPointer<Unit>,x: Int32,y: Int32,r: CPointer<UInt8>,g: CPointer<UInt8>,b: CPointer<UInt8>,a: CPointer<UInt8>): Bool
    func SDL_DestroySurface(surface: CPointer<Unit>): Unit
}
func skinPixelColor(surface: CPointer<Unit>,x: Int32,y: Int32): Color {
    var r: UInt8=0; var g: UInt8=0; var b: UInt8=0; var alpha: UInt8=0
    require(unsafe { SDL_ReadSurfacePixel(surface,x,y,inout r,inout g,inout b,inout alpha) },"Read geometry test pixel")
    Color.rgba(Int64(r),Int64(g),Int64(b),Int64(alpha))
}
func skinPixelRed(surface: CPointer<Unit>,x: Int32,y: Int32): Int64 { Int64(skinPixelColor(surface,x,y).r) }
func verifyDiamondPixels(a: App,w: SdlWindow,art: Art): Unit {
    let r=w.renderer; let originalSkin=a.noteSkin
    for (scale in [Float32(1.0),Float32(1.5)]) {
        r.resetViewport(); r.setScale(scale); r.clear(Color.rgb(0,0,0))
        drawDiamond(art,100.0,100.0,100.0)
        let surface=unsafe { SDL_RenderReadPixels(SDL_GetRenderer(SDL_GetWindowFromID(w.id)),CPointer<Unit>()) }
        require(surface.isNotNull(),"Read diamond geometry")
        try {
            let centre=skinPixelRed(surface,Int32(100.0*scale),Int32(100.0*scale))
            let tip=skinPixelRed(surface,Int32(100.0*scale),Int32(60.0*scale))
            let corner=skinPixelRed(surface,Int32(65.0*scale),Int32(65.0*scale))
            println("DIAMOND geometry scale=${scale}: centre=${centre}, tip=${tip}, outside=${corner}")
            require(centre > 200 && tip > 200 && corner < 20,"Diamond has a visible upper point and transparent outer corners")
        } finally { unsafe { SDL_DestroySurface(surface) } }
    }
    r.resetViewport(); r.setScale(1.0)
    a.noteSkin=1; prepareNoteSkin(a,art); r.clear(Color.rgb(0,0,0))
    drawSkinnedNote(a,Note(0,0,1000),art,50.0,250.0,100.0,100.0,4)
    let holdSurface=unsafe { SDL_RenderReadPixels(SDL_GetRenderer(SDL_GetWindowFromID(w.id)),CPointer<Unit>()) }
    require(holdSurface.isNotNull(),"Read hold geometry")
    try {
        require(skinPixelRed(holdSurface,100,65) >= 150 && skinPixelRed(holdSurface,60,70) < 20 && skinPixelRed(holdSurface,70,130) >= 150,"Diamond hold keeps the native cap shape and transparency")
    } finally { unsafe { SDL_DestroySurface(holdSurface) } }
    a.noteSkin=2; prepareNoteSkin(a,art); r.clear(Color.rgb(0,0,0))
    drawSkinnedNote(a,Note(0,0,0),art,50.0,100.0,100.0,noteLayout(2,4).widths[0],4)
    let barSurface=unsafe { SDL_RenderReadPixels(SDL_GetRenderer(SDL_GetWindowFromID(w.id)),CPointer<Unit>()) }
    require(barSurface.isNotNull(),"Read bar geometry")
    try {
        require(skinPixelRed(barSurface,80,75) > 200 && skinPixelRed(barSurface,80,135) < 20,"Bar renders at the original image aspect and height basis")
    } finally { unsafe { SDL_DestroySurface(barSurface) } }
    for (skin in 0..4) {
        a.noteSkin=skin; prepareNoteSkin(a,art); r.clear(Color.rgb(0,0,0))
        drawSkinnedNote(a,Note(0,0,1000),art,20.0,300.0,100.0,134.0,4)
        let surface=unsafe { SDL_RenderReadPixels(SDL_GetRenderer(SDL_GetWindowFromID(w.id)),CPointer<Unit>()) }
        require(surface.isNotNull(),"Read native hold color")
        try {
            let color=skinPixelColor(surface,87,200)
            try (source=Surface.load(SKIN_BODIES[skin])) {
                let native=source.readPixel(64,384)
                let expected=Int64(native.r)*Int64(native.a)/255
                require(Int64(color.r) >= expected-1 && Int64(color.r) <= expected+1 && color.r == color.g && color.g == color.b,
                    "All hold bodies preserve their source alpha without an extra opacity layer")
                println("NATIVE hold skin=${skin}: RGB=${color.r},${color.g},${color.b}, sourceAlpha=${native.a}")
            }
        } finally { unsafe { SDL_DestroySurface(surface) } }
    }
    a.noteSkin=originalSkin
    println("PASS skin geometry pixels: diamond points / transparent corners / scaled output / pointed hold tail / original bar proportions")
}
