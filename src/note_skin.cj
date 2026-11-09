package orz_mania

import sdl.*

let NOTE_FOLDERS=["orbs","diamonds","bars","arrows"]
let NOTE_SKIN_LABELS=["圆形","菱形","砖形","箭头"]
let ARROW_DIRECTIONS=["left","down","up","right"]
let ARROW_HOLDS=Array<String>(4,{i => "assets/skin/mania/arrows/"+ARROW_DIRECTIONS[i]+"-h.png"})
func arrowDirection(lane: Int64,keys: Int64): Int64 {
    if (keys == 1) { 1 } else if (keys == 2) { if (lane == 0) { 0 } else { 3 } }
    else if (keys == 3) { if (lane == 2) { 3 } else { lane } } else { lane%4 }
}
let SKIN_NOTES=Array<Array<String>>(4,{skin => if (skin == 3) { Array<String>(4,{i => "assets/skin/mania/arrows/"+ARROW_DIRECTIONS[i]+".png"}) } else { Array<String>(3,{i => "assets/skin/mania/"+NOTE_FOLDERS[skin]+"/note${i+1}.png"}) } })
let SKIN_KEYS=Array<Array<String>>(4,{skin => if (skin == 3) { Array<String>(8,{i => "assets/skin/mania/arrows/"+(if (i < 4) { "k_" } else { "kd_" })+ARROW_DIRECTIONS[i%4]+".png"}) } else { ["assets/skin/mania/"+NOTE_FOLDERS[skin]+"/key.png","assets/skin/mania/"+NOTE_FOLDERS[skin]+"/key_down.png"] } })
let SKIN_BODIES=Array<String>(4,{skin => "assets/skin/mania/"+NOTE_FOLDERS[skin]+"/mania-noteL.png"})
func noteSkinValueRect(): Rect { settingValueRect(540.0) }
func noteSkinName(a: App): String { tr(a,NOTE_SKIN_LABELS[a.noteSkin]) }
func noteSpriteSource(skin: Int64): Rect { if (skin == 3) { Rect(0.0,0.0,150.0,150.0) } else if (skin == 2) { Rect(0.0,0.0,138.0,138.0) } else { Rect(6.0,6.0,138.0,138.0) } }
func noteSpriteKind(lane: Int64,keys: Int64,hold: Bool): Int64 { if (hold) { 2 } else if (lane == 0 || lane == keys-1) { 0 } else { 1 } }
func prepareNoteSkin(a: App,art: Art): Unit {
    if (art.noteSkinReady == a.noteSkin) { return }
    let skin=a.noteSkin
    for (path in SKIN_NOTES[skin]) { let _=art.texture(path) }
    for (path in SKIN_KEYS[skin]) { let _=art.texture(path) }
    if (skin == 3) { for (path in ARROW_HOLDS) { let _=art.texture(path) } }
    let body=SKIN_BODIES[skin]
    if (!art.textures.contains(body)) {
        art.diskChecks++
        // The native sprites are almost 20,000px tall. Keep the original 64px cap and one
        // uniform body row, without scaling away the cap or uploading an oversized texture.
        try (source=Surface.load(body)) {
            require(source.size().w == 128.0 && source.size().h > 384.0,"Invalid note body sprite")
            try (strip=Surface.create(128,65)) {
                for (y in 0..65) { for (x in 0..128) {
                    strip.writePixel(Int32(x),Int32(y),source.readPixel(Int32(x),Int32(if (y < 64) { y+96 } else { 384 })))
                } }
                art.textures[body]=art.r.textureFromSurface(strip); art.loads++
            }
        }
    }
    art.noteSkinReady=skin
}
func drawNoteSkinSetting(a: App,r: Renderer,art: Art): Unit {
    prepareNoteSkin(a,art)
    centeredSettingLabel(a,r,"音符皮肤",540.0,a.menuFocus == 7)
    settingValueButton(a,r,noteSkinName(a),540.0,active: a.menuFocus == 7)
}
func drawDiamond(art: Art,cx: Float32,cy: Float32,size: Float32,alpha!: Int64=255): Unit {
    art.image(SKIN_NOTES[1][0],Rect(cx-size/2.0,cy-size/2.0,size,size),alpha: alpha,source: Some(noteSpriteSource(1)))
}
func drawSkinnedReceptor(a: App,p: Play,art: Art,index: Int64,x: Float32,y: Float32,width: Float32): Unit {
    let size=width-6.0; let age=a.now-p.hitAt[index]
    let pressed=p.down[index] || (a.autoplay && age >= 0 && age < 65)
    let key=if (a.noteSkin == 3) { arrowDirection(index,p.chart.keys)+if (pressed) { 4 } else { 0 } } else { if (pressed) { 1 } else { 0 } }
    art.image(SKIN_KEYS[a.noteSkin][key],Rect(x+3.0,y-size/2.0,size,size),source: Some(Rect(0.0,14.0,75.0,108.0)))
    if (age >= 0 && age < 150) {
        let pulse=size*(1.0+Float32(age)/500.0)
        let image=if (a.noteSkin == 3) { ARROW_HOLDS[arrowDirection(index,p.chart.keys)] } else { SKIN_NOTES[a.noteSkin][2] }
        art.image(image,Rect(x+(width-pulse)/2.0,y-pulse/2.0,pulse,pulse),alpha: 100*(150-age)/150,source: Some(noteSpriteSource(a.noteSkin)))
    }
}
func drawSkinnedNote(a: App,n: Note,art: Art,x: Float32,y: Float32,tail: Float32,width: Float32,keys: Int64): Unit {
    let size=width-6.0; let skin=a.noteSkin
    if (n.end > n.time && y > tail) {
        let top=max(-size,tail); let bottom=min(Float32(720.0),y)
        if (bottom > top) { art.image(SKIN_BODIES[skin],Rect(x+3.0,top,size,bottom-top),source: Some(Rect(0.0,64.0,128.0,1.0))) }
        if (tail > -size && tail < 720.0+size) {
            art.image(SKIN_BODIES[skin],Rect(x+3.0,tail-size/2.0,size,size/2.0),source: Some(Rect(0.0,0.0,128.0,64.0)))
        }
    }
    if (y > -size && y < 720.0+size) {
        let image=if (skin == 3) { if (n.end > n.time) { ARROW_HOLDS[arrowDirection(n.lane,keys)] } else { SKIN_NOTES[skin][arrowDirection(n.lane,keys)] } } else { SKIN_NOTES[skin][noteSpriteKind(n.lane,keys,n.end > n.time)] }
        art.image(image,Rect(x+3.0,y-size/2.0,size,size),source: Some(noteSpriteSource(skin)))
    }
}
