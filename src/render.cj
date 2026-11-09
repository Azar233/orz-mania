package orz_mania

import sdl.*
import std.collection.{HashMap,ArrayList}
import std.math.{sin,cos}
import std.fs.{Directory, exists}
import sdl.system.PerformanceClock

let PINK=Color.rgb(255,173,201)
let WHITE=Color.rgb(249,240,246)
let MUTED=Color.rgb(155,144,166)
let PANEL=Color.rgb(28,24,38)
let SCORE_IMAGES=Array<String>(13,{i => "assets/skin/score-${if (i < 10) { i.toString() } else if (i == 10) { "dot" } else if (i == 11) { "percent" } else { "x" }}@2x.png"})
let COMBO_IMAGES=Array<String>(10,{i => "assets/skin/combo-${i}@2x.png"})
let JUDGE_IMAGES=["assets/skin/mania-hit300g.png","assets/skin/mania-hit300.png","assets/skin/mania-hit200.png","assets/skin/mania-hit100.png","assets/skin/mania-hit50.png","assets/skin/mania-hit0.png"]
// Render-only scratch geometry is reused on SDL's main thread.
let PROGRESS_POLYGON=ArrayList<Point>()
let PROGRESS_ARC=Array<Point>(65,{i =>
    let angle=Float64(i)*6.283185307179586/64.0-1.570796326794897
    Point(Float32(cos(angle))*14.0,Float32(sin(angle))*14.0)
})
class CoverRequest {
    let path: String
    let thumbnail: Bool
    let key: String
    init(path: String,thumbnail: Bool) {
        this.path=path; this.thumbnail=thumbnail; key=if (thumbnail) { "thumb:"+path } else { path }
    }
}
class CoverDecoded {
    let surface: ?Surface
    let error: String
    init(surface: ?Surface,error: String) { this.surface=surface; this.error=error }
}
class Art <: Resource {
    let r: Renderer
    var noteSkinReady: Int64 = -1
    let textures=HashMap<String,Texture>()
    var closed=false
    var errors: Int64=0
    var diskChecks: Int64=0
    var loads: Int64=0
    init(r: Renderer) { this.r=r }
    let covers=ArrayList<String>()
    let thumbnails=ArrayList<String>()
    let coverWanted=ArrayList<CoverRequest>()
    let coverFailures=HashMap<String,UInt64>()
    func coverFailed(key: String): Bool {
        coverFailures.contains(key) && PerformanceClock.ticksNanoseconds()-coverFailures[key] < 1000000000
    }
    var coverJob: ?Future<CoverDecoded>=None
    var coverRequest: ?CoverRequest=None
    var libraryLoading=false
    var decodeJobs: Int64=0
    var discardedCovers: Int64=0
    func discardCoverJob(wait!: Bool=false): Unit {
        if (let Some(job) <- coverJob) {
            let result=if (wait) { Some(job.get()) } else { job.tryGet() }
            if (let Some(decoded) <- result) {
                if (let Some(surface) <- decoded.surface) { surface.close() }
                coverJob=None; coverRequest=None
            }
        }
    }
    func beginCoverFrame(): Unit { coverWanted.clear(); libraryLoading=true }
    func coverOrder(key: String,thumbnail: Bool): Unit {
        let order=if (thumbnail) { thumbnails } else { covers }
        var found: Int64 = -1
        for (i in 0..order.size) { if (order[i] == key) { found=i; break } }
        if (found != order.size-1 || found < 0) {
            if (found >= 0) { order.remove(at: found) }; order.add(key)
        }
        while (order.size > (if (thumbnail) { 32 } else { 4 })) {
            let old=order[0]; order.remove(at: 0)
            textures[old].close(); textures.remove(old)
        }
    }
    func endCoverFrame(): Unit {
        libraryLoading=false
        if (let Some(job) <- coverJob) { if (let Some(decoded) <- job.tryGet()) {
            let request=coverRequest.getOrThrow(); coverJob=None; coverRequest=None
            if (let Some(surface) <- decoded.surface) {
                try (image=surface) {
                    var wanted=false
                    for (item in coverWanted) { if (item.key == request.key) { wanted=true; break } }
                    if (wanted) {
                        try {
                            textures[request.key]=r.textureFromSurface(image); loads++
                            coverOrder(request.key,request.thumbnail)
                        } catch (ex: Exception) {
                            coverFailures[request.key]=PerformanceClock.ticksNanoseconds(); errors++
                            println("Background upload skipped: ${request.path}: ${ex.message}")
                        }
                    } else { discardedCovers++ }
                }
            } else {
                coverFailures[request.key]=PerformanceClock.ticksNanoseconds(); errors++; println("Background skipped: ${request.path}: ${decoded.error}")
            }
        } }
        if (coverJob.isSome()) { return }
        for (request in coverWanted) {
            if (textures.contains(request.key) || coverFailed(request.key)) { continue }
            coverRequest=Some(request); decodeJobs++
            // Only decoding/resizing runs on a lightweight worker. GPU access stays here.
            coverJob=Some(spawn {=>
                try {
                    let options=if (request.thumbnail) { ImageLoadOptions(width: 256,height: 192) } else { ImageLoadOptions(width: 2560,height: 1440) }
                    return CoverDecoded(Some(Surface.load(request.path,options: options)),"")
                } catch (ex: Exception) { return CoverDecoded(Option<Surface>.None,ex.message) }
            })
            break
        }
    }
    func libraryCoverTexture(path: String,thumbnail: Bool): ?Texture {
        let key=if (thumbnail) { "thumb:"+path } else { path }
        if (!textures.contains(key)) {
            var queued=false
            for (item in coverWanted) { if (item.key == key) { queued=true; break } }
            if (!queued && !coverFailed(key)) { coverWanted.add(CoverRequest(path,thumbnail)) }
            return None
        }
        coverOrder(key,thumbnail)
        Some(textures[key])
    }
    func texture(path: String,background!: Bool=false): ?Texture {
        if (path.isEmpty()) { return None }
        if (!textures.contains(path)) {
            diskChecks++
            if (!exists(path)) { return None }
            let options=if (background) { ImageLoadOptions(width: 2560,height: 1440) } else { ImageLoadOptions() }
            textures[path]=r.loadTexture(path,options: options); loads++
        }
        if (background) { coverOrder(path,false) }
        Some(textures[path])
    }
    func image(path: String, rect: Rect, alpha!: Int64=255, source!: ?Rect=None): Unit {
        try {
            if (let Some(t) <- texture(path)) {
                r.textureStyled(t,rect,source: source,style: TextureStyle(opacity: Float32(alpha)/255.0))
            }
        } catch (ex: Exception) { errors++; println("Image skipped: ${path}: ${ex.message}") }
    }
    func cover(path: String, rect: Rect, alpha: Int64,thumbnail!: Bool=false): Unit {
        try {
            if (path.isEmpty() || alpha <= 0) { return }
            let candidate=if (libraryLoading) { libraryCoverTexture(path,thumbnail) } else { texture(path,background: true) }
            if (let Some(t) <- candidate) {
                let scale=max(rect.w/t.width,rect.h/t.height)
                let w=rect.w/scale; let h=rect.h/scale
                r.textureStyled(t,rect,source: Some(Rect((t.width-w)/2.0,(t.height-h)/2.0,w,h)),style: TextureStyle(opacity: Float32(alpha)/255.0))
            }
        } catch (ex: Exception) { errors++; println("Background skipped: ${path}: ${ex.message}") }
    }
    public func close(): Unit {
        if (closed) { return }
        // Join before releasing SDL/window resources; even an obsolete decode owns a surface.
        discardCoverJob(wait: true)
        for ((_,t) in textures) { t.close() }; closed=true
    }
    public func isClosed(): Bool { closed }
}
func text(r: Renderer, s: String, x: Float32, y: Float32, size: Float32, color!: Color=WHITE): Unit {
    r.text(s,x,y,color,pointSize: size)
}
func box(r: Renderer, x: Float32,y: Float32,w: Float32,h: Float32,color: Color,radius!: Float32=12.0): Unit {
    r.fillRoundedRect(Rect(x,y,w,h),radius,color)
}
func timeLabel(ms: Int64): String {
    let s=max(0,ms)/1000
    "${s/60}:${if (s%60 < 10) { "0" } else { "" }}${s%60}"
}
// Measure the actual font line box so every shared button has the same alignment.
func centeredText(r: Renderer,label: String,rect: Rect,size: Float32,color: Color): Unit {
    text(r,label,rect.x+(rect.w-r.textWidth(label,pointSize: size))/2.0,
        rect.y+(rect.h-r.textHeight(pointSize: size))/2.0,size,color: color)
}
func drawBrandIcon(art: Art,x: Float32,y: Float32,size: Float32): Unit {
    art.image("assets/branding/icon.svg",Rect(x,y,size,size),source: Some(Rect(0.0,200.0,1054.0,1054.0)))
}
func libraryMenuRect(): Rect { Rect(28.0,18.0,44.0,44.0) }
func resultActionRect(retry: Bool): Rect { Rect(if (retry) { 1108.0 } else { 936.0 },665.0,156.0,36.0) }
func resultAchievementRect(): Rect { Rect(744.0,540.0,520.0,64.0) }
func resultNoticeRect(): Rect { Rect(936.0,616.0,328.0,32.0) }
func header(a: App,r: Renderer,art: Art): Unit {
    let iconSize=36.0*(1.0+0.08*a.brandHoverAmount)
    drawBrandIcon(art,50.0-iconSize/2.0,40.0-iconSize/2.0,iconSize)
    text(r,"orz!mania",78.0,22.0,28.0)
    drawLibrarySearch(a,r)
    r.fill(Rect(32.0,76.0,1216.0,1.0),Color.rgb(51,41,59))
}
func background(a: App,r: Renderer,art: Art,bounds: Rect): Unit {
    r.clear(Color.rgb(7,6,9))
    if (!a.charts.isEmpty()) {
        let image=a.charts[a.selected].background
        if (a.screen == 0) {
            if (a.libraryFade < 1.0 && a.libraryPrevious < a.charts.size) {
                art.cover(a.charts[a.libraryPrevious].background,bounds,Int64(42.0*(1.0-a.libraryFade)))
            }
            art.cover(image,bounds,Int64(42.0*a.libraryFade))
            r.fill(bounds,Color.rgba(16,14,23,165))
        } else {
            if (a.screen == 3) { art.cover(image,bounds,185); r.fill(bounds,Color.rgba(0,0,0,30)) }
            else { art.cover(image,bounds,backgroundAlpha(a.backgroundOpacity)) }
        }
    }
}
// The original skin leaves large transparent margins. Source rectangles preserve its
// painted pixels without stretching the margins into the visible layout.
func skinNumber(art: Art,value: String,x: Float32,y: Float32,height: Float32,
    combo!: Bool=false,align!: Int64=0): Unit {
    let bytes=value.toArray()
    let cell=height*if (combo) { Float32(0.70) } else { Float32(0.83) }
    let width=cell*Float32(bytes.size)
    let start=x-if (align == 1) { width/2.0 } else if (align == 2) { width } else { Float32(0.0) }
    for (i in 0..bytes.size) {
        let ch=bytes[i]
        let index=if (ch == 46) { 10 } else if (ch == 37) { 11 } else if (ch == 120) { 12 } else { Int64(ch)-48 }
        let prefix=if (combo && ch >= 48 && ch <= 57) { "combo" } else { "score" }
        let special=ch == 37 || ch == 120
        let source=if (prefix == "combo") { Rect(0.0,20.0,69.0,90.0) }
            else if (special) { Rect(0.0,25.0,40.0,60.0) } else { Rect(0.0,20.0,50.0,60.0) }
        art.image(if (prefix == "combo") { COMBO_IMAGES[index] } else { SCORE_IMAGES[index] },Rect(start+Float32(i)*cell,y,cell,height),source: Some(source))
    }
}
func paddedScore(score: Int64): String {
    let value=score.toString()
    var result=value
    while (result.size < 8) { result="0"+result }
    result
}
func judgementImage(grade: Int64): String {
    JUDGE_IMAGES[grade]
}
func judgement(art: Art,grade: Int64,cx: Float32,y: Float32,height: Float32,alpha!: Int64=255): Unit {
    let source=match (grade) {
        case 0 | 1 => Rect(199.0,37.0,198.0,39.0)
        case 2 => Rect(225.0,32.0,139.0,35.0)
        case 3 => Rect(238.0,33.0,113.0,34.0)
        case 4 => Rect(251.0,31.0,87.0,36.0)
        case _ => Rect(243.0,31.0,103.0,36.0)
    }
    let width=height*source.w/source.h
    art.image(judgementImage(grade),Rect(cx-width/2.0,y,width,height),alpha: alpha,source: Some(source))
}
// Derive motion from judgement age, so pause freezes it and each award retriggers it.
func animatedJudgement(art: Art,grade: Int64,cx: Float32,age: Int64): Unit {
    if (age < 0 || age >= 480) { return }
    let entry=min(Float32(1.0),Float32(age)/65.0)
    let settle=min(Float32(1.0),max(Float32(0.0),Float32(age-65)/85.0))
    let entryEase=1.0-(1.0-entry)*(1.0-entry)*(1.0-entry)
    let settleEase=1.0-(1.0-settle)*(1.0-settle)*(1.0-settle)
    let scale=if (age < 65) { 0.96+0.14*entryEase } else { 1.10-0.10*settleEase }
    let fade=min(Float32(1.0),max(Float32(0.0),Float32(age-260)/220.0))
    let alpha=Int64((160.0+95.0*min(Float32(1.0),Float32(age)/25.0))*(1.0-fade)*(1.0-fade))
    let height=24.0*scale
    let centreY: Float32=329.0
    judgement(art,grade,cx,centreY-height/2.0,height,alpha: alpha)
}
func drawModBadge(r: Renderer,rect: Rect,color: Color,title: String,subtitle: String): Unit {
    box(r,rect.x,rect.y,rect.w,rect.h,color,radius: 4.0)
    centeredText(r,title,Rect(rect.x,rect.y+4.0,rect.w,28.0),17.0,WHITE)
    centeredText(r,subtitle,Rect(rect.x,rect.y+31.0,rect.w,20.0),11.0,WHITE.withAlpha(210))
}
func autoBadge(a: App,r: Renderer,x: Float32,y: Float32): Unit {
    drawModBadge(r,Rect(x,y,62.0,55.0),Color.rgb(9,70,133),"AUTO",tr(a,"演示"))
}
func drawLibrary(a: App,r: Renderer,art: Art): Unit {
    prepareNoteSkin(a,art)
    header(a,r,art)
    if (a.charts.isEmpty()) {
        text(r,tr(a,"曲库为空，请在菜单中导入歌曲"),62.0,250.0,24.0)
        return
    }
    let c=a.charts[a.selected]
    if (a.rows.isEmpty()) { text(r,tr(a,"没有匹配的谱面"),454.0,164.0,18.0,color: MUTED); return }
    if (a.libraryFade < 1.0 && a.libraryPrevious < a.charts.size) {
        art.cover(a.charts[a.libraryPrevious].background,Rect(62.0,144.0,338.0,220.0),255)
    }
    art.cover(c.background,Rect(62.0,144.0,338.0,220.0),Int64(255.0*a.libraryFade))
    let titleOffset=a.libraryTitle.offset(c.title,r,a.uiTick)
    r.pushClip(Rect(62.0,384.0,LIBRARY_TITLE_WIDTH,52.0))
    text(r,c.title,62.0-titleOffset,390.0,LIBRARY_TITLE_SIZE)
    r.popClip()
    r.pushClip(Rect(64.0,436.0,336.0,28.0))
    text(r,c.artist + "  /  " + c.creator,64.0,436.0,16.0,color: MUTED)
    r.popClip()
    text(r,"${c.keys}K   ·   ${timeLabel(c.duration)}",64.0,475.0,13.0,color: PINK)
    drawLocalScores(a,r)
    text(r,tr(a,"曲库"),454.0,105.0,13.0,color: MUTED)
    text(r,if (a.english) { "${a.visibleSongs} songs / ${a.visibleCharts} charts" } else { "${a.visibleSongs} 首 / ${a.visibleCharts} 谱面" },1062.0,105.0,13.0,color: MUTED)
    let list=libraryListRect()
    r.pushClip(list)
    for (i in libraryLayers(a)) {
        let row=a.rows[i]; let group=a.groups[row.group]
        let chart=a.charts[if (row.chart >= 0) { row.chart } else { group.remembered }]
        let y=libraryRowY(a,i)
        if (y+LIBRARY_HEIGHT <= list.y || y >= list.y+list.h) { continue }
        let alpha=if (row.chart < 0) { Float32(1.0) } else { 0.35+a.drawerFade*0.65 }
        let focus=libraryEmphasis(a,i)
        let x=libraryCardX(a,i); let width=1228.0-x
        r.fill(Rect(x+4.0,y+5.0,width,LIBRARY_HEIGHT),Color.rgba(0,0,0,90))
        r.fill(Rect(x,y,width,LIBRARY_HEIGHT),PANEL.lerp(Color.rgb(65,43,65),focus).withAlpha(Int64(245.0*alpha)))
        art.cover(chart.background,Rect(x,y,124.0,LIBRARY_HEIGHT),Int64((140.0+115.0*focus)*alpha),thumbnail: true)
        r.pushClip(Rect(x+143.0,y+9.0,width-180.0,76.0))
        text(r,if (row.chart < 0) { chart.title } else { chart.version },x+143.0,y+14.0,21.0,color: WHITE.lerp(PINK,focus).withAlpha(Int64(255.0*alpha)))
        text(r,if (row.chart < 0) { if (a.english) { "${chart.artist}   ·   ${group.matches} charts" } else { "${chart.artist}   ·   ${group.matches} 个谱面" } } else { "${chart.keys}K   ·   ${chart.creator}" },x+145.0,y+51.0,13.0,color: MUTED.withAlpha(Int64(255.0*alpha)))
        r.popClip()
        if (row.chart < 0) {
            let cx: Float32=1196.0; let cy=y+45.0
            if (a.openGroup == row.group) {
                r.line(cx-5.0,cy-3.0,cx,cy+2.0,PINK); r.line(cx,cy+2.0,cx+5.0,cy-3.0,PINK)
            } else {
                r.line(cx-3.0,cy-5.0,cx+2.0,cy,PINK); r.line(cx+2.0,cy,cx-3.0,cy+5.0,PINK)
            }
        }
    }
    r.popClip()

}
// Elapsed time sweeps clockwise from twelve o'clock as an opaque dark sector.
func drawSongProgress(r: Renderer,value: Float32,cx!: Float32=1084.0,cy!: Float32=64.0): Unit {
    let progress=max(Float32(0.0),min(Float32(1.0),value))
    r.fillCircle(cx,cy,14.0,Color.rgba(235,235,242,150))
    if (progress >= 1.0) { r.fillCircle(cx,cy,14.0,Color.rgb(7,7,9)) }
    else if (progress > 0.0) {
        let points=PROGRESS_POLYGON; points.clear(); points.add(Point(cx,cy))
        let steps=Int64(progress*64.0)
        for (i in 0..steps+1) { points.add(Point(cx+PROGRESS_ARC[i].x,cy+PROGRESS_ARC[i].y)) }
        let angle=Float64(progress)*6.283185307179586-1.570796326794897
        if (progress*64.0-Float32(steps) > 0.000001) {
            points.add(Point(cx+Float32(cos(angle))*14.0,cy+Float32(sin(angle))*14.0))
        }
        r.fillConvexPolygon(points,Color.rgb(7,7,9))
    }
    r.strokeCircle(cx,cy,14.0,Pen(color: WHITE.withAlpha(220),width: 1.2))
}
func visualNoteTime(a: App): Int64 { a.now+a.visualOffset }
func drawPlay(a: App,p: Play,r: Renderer,art: Art): Unit {
    prepareNoteSkin(a,art)
    let visualNow=visualNoteTime(a)
    let c=p.chart
    let layout=noteLayout(a.noteSkin,c.keys); let width=layout.width
    let centre: Float32=535.0; let left=layout.left
    let hitY=layout.hitY; let diameter=layout.maxColumn-6.0
    r.fill(Rect(left,0.0,width,720.0),Color.rgba(0,0,0,if (a.noteSkin == 0) { 192 } else { 255 }))
    r.fill(Rect(left+width+8.0,300.0,6.0,420.0),Color.rgb(245,245,248))
    drawLiveScores(a,p,r)
    // Character art from the same stage texture as the reference skin.
    let characterWidth=min(Float32(135.0),left-55.0)
    art.image("assets/skin/mania/stage/stageleft.png",
        Rect(58.0,720.0-characterWidth*413.0/149.0,characterWidth,characterWidth*413.0/149.0),
        source: Some(Rect(18.0,349.0,149.0,413.0)))
    skinNumber(art,paddedScore(p.score),1263.0,4.0,36.0,align: 2)
    skinNumber(art,percent(p.accuracy()),1263.0,49.0,23.0,align: 2)
    let progress=min(Float32(1.0),max(Float32(0.0),Float32(a.now)/Float32(c.duration)))
    drawSongProgress(r,progress)
    if (a.autoplay) { autoBadge(a,r,1201.0,116.0) }
    drawRateBadge(a,r)
    for (i in 0..c.keys) {
        let lane=layout.widths[i]; let x=left+layout.offsets[i]
        drawSkinnedReceptor(a,p,art,i,x,hitY,lane)
    }
    r.pushClip(Rect(left,0.0,width,720.0))
    for (i in p.cursor..c.notes.size) {
        let n=c.notes[i]
        let y=hitY-Float32(n.time-visualNow)*a.speed
        if (y < -diameter) { break }
        if (n.state == 2) { continue }
        let cy: Float32=if (n.state == 1) { hitY } else { y }
        drawSkinnedNote(a,n,art,left+layout.offsets[n.lane],cy,hitY-Float32(n.end-visualNow)*a.speed,layout.widths[n.lane],c.keys)
    }
    r.popClip()
    if (p.combo > 0) { skinNumber(art,p.combo.toString(),centre,224.0,69.0,combo: true,align: 1) }
    if (a.now-p.judgeAt < 480 && a.now >= p.judgeAt) {
        let labels=["PERFECT","GREAT","GOOD","OK","MEH","MISS"]
        for (i in 0..labels.size) { if (p.judge == labels[i]) { animatedJudgement(art,i,centre,a.now-p.judgeAt) } }
    }
    if (a.now < 0) { text(r,"READY",centre-45.0,345.0,27.0) }
    else if (a.now < c.notes[0].time-1800) {
        skinNumber(art,"${(c.notes[0].time-a.now)/1000+1}",centre,342.0,43.0,combo: true,align: 1)
    }
    if (a.canSkipIntro()) { text(r,tr(a,if (a.skipError.isEmpty()) { "Enter 跳过前奏" } else { a.skipError }),centre-54.0,397.0,13.0,color: WHITE.withAlpha(150)) }
    drawKeyOverlay(a,p,r)
}
func drawResults(a: App,p: Play,r: Renderer,art: Art): Unit {
    r.fill(Rect(0.0,0.0,1280.0,89.0),Color.rgba(0,0,0,185))
    r.pushClip(Rect(4.0,0.0,965.0,88.0))
    text(r,p.chart.artist + " - " + p.chart.title + " [" + p.chart.version + "]",5.0,0.0,27.0)
    text(r,"Beatmap by " + p.chart.creator,6.0,34.0,18.0)
    r.popClip()
    art.image("assets/skin/ranking-title@2x.png",Rect(1032.0,16.0,232.0,62.0),source: Some(Rect(2382.0,41.0,450.0,120.0)))
    r.fill(Rect(0.0,95.0,560.0,458.0),Color.rgba(0,0,0,45))
    art.image("assets/skin/ranking-panel.png",Rect(0.0,95.0,560.0,458.0),source: Some(Rect(0.0,0.0,600.0,490.0)))
    skinNumber(art,paddedScore(p.score),465.0,125.0,45.0,align: 2)
    // Match the skin's two-column judgement order: 300 / MAX, 200 / 100, 50 / MISS.
    let grades: Array<Int64>=[1,0,2,3,4,5]
    for (i in 0..6) {
        let x=if (i%2 == 0) { Float32(61.0) } else { Float32(361.0) }
        let y=233.0+Float32(i/2)*94.0
        judgement(art,grades[i],x,y+5.0,19.0)
        let value="${p.counts[grades[i]]}x"
        let height=min(Float32(39.0),134.0/(Float32(value.size)*0.83))
        skinNumber(art,value,x+60.0,y-3.0,height)
    }
    skinNumber(art,"${p.maxCombo}x",20.0,506.0,40.0)
    skinNumber(art,percent(p.accuracy()),297.0,506.0,40.0)
    let rank=if (p.accuracy() == 10000) { "X" } else if (p.accuracy() >= 9500) { "S" }
        else if (p.accuracy() >= 9000) { "A" } else if (p.accuracy() >= 8000) { "B" }
        else if (p.accuracy() >= 7000) { "C" } else { "D" }
    art.image("assets/skin/ranking-${rank}@2x.png",Rect(925.0,212.0,340.0,226.0))
    if (a.autoplay) { autoBadge(a,r,1194.0,421.0) }
    art.image("assets/skin/ranking-graph.png",Rect(240.0,577.0,290.0,138.0))
    text(r,tr(a,if (p.offsets.isEmpty()) { if (a.autoplay) { "AUTO PLAY" } else { "暂无击打偏移" } } else { "RECENT HIT TIMING" }),254.0,588.0,11.0,color: WHITE.withAlpha(175))
    if (!p.offsets.isEmpty()) {
        r.line(254.0,651.0,515.0,651.0,WHITE.withAlpha(65))
        for (i in 0..p.offsets.size) {
            let x=254.0+Float32(i)*260.0/Float32(max(1,p.offsets.size-1))
            let y=651.0+Float32(p.offsets[i])*0.25
            r.fillCircle(x,y,2.0,PINK)
        }
    }
    if (p.judged == p.chart.notes.size && p.counts[5] == 0 && p.maxCombo == p.chart.notes.size) {
        art.image("assets/skin/ranking-perfect@2x.png",resultAchievementRect())
    }
    for (retry in [false,true]) {
        let rect=resultActionRect(retry)
        r.fill(rect,Color.rgba(38,32,47,120))
        centeredText(r,tr(a,if (retry) { "再次挑战" } else { "返回" }),rect,16.0,WHITE)
    }
    drawScoreNotice(a,r)
}
func draw(a: App,r: Renderer,art: Art): Unit {
    // Paint the entire native output before fitting the gameplay/UI canvas. This
    // removes letterbox bars without distorting notes or changing pointer mapping.
    if (a.screen == 0) { art.beginCoverFrame() } else { art.discardCoverJob() }
    r.setScale(1.0); r.resetViewport()
    let bounds=r.viewport()
    background(a,r,art,bounds)
    let _=r.fitCanvas(1280.0,720.0)
    if (a.calibration.isSome()) { () }
    else if (a.screen == 0) { drawLibrary(a,r,art) }
    else if (let Some(p) <- a.play) {
        if (a.screen == 3) { drawResults(a,p,r,art) }
        else { drawPlay(a,p,r,art) }
    }
    if (a.screen == 0) { art.endCoverFrame() }
    if (a.menuOpen) {
        r.setScale(1.0); r.resetViewport()
        r.fill(bounds,if (a.screen == 2) { Color.rgba(0,0,0,204) } else { Color.rgba(7,5,13,218) })
        let _=r.fitCanvas(1280.0,720.0)
        drawMenu(a,r,art)
    }
}
func screenshots(a: App,w: SdlWindow,art: Art): Unit {
    if (!exists("artifacts")) { Directory.create("artifacts",recursive: true) }
    for (i in 0..a.charts.size) {
        if (a.charts[i].title == "Grin" && a.charts[i].version == "Piano Concerto") { a.selected=i; break }
    }
    verifyIntroSkip(a,w,art)
    verifyDrawers(a,w,art)
    verifyLibraryMotion(a)
    verifyMenus(a,w,art)
    verifyBindings(a,w,art)
    verifyPreviewAndResize(a,w,art)
    captureKeyOverlay(a,w,art)
    verifyFramePacing(a,w,art)
    resetLibraryMotion(a)
    draw(a,w.renderer,art); w.renderer.captureBmp("artifacts/library.bmp")
    captureLibraryMotion(a,w,art)
    a.autoplay=true; a.start(Int64(w.ticks()))
    let p=a.play.getOrThrow()
    a.now=17200
    for (n in p.chart.notes) {
        if (n.end-n.time >= 700 && n.time > 15000) { a.now=n.time-400; break }
    }
    p.update(a.now,true); p.down[1]=true
    draw(a,w.renderer,art); w.renderer.captureBmp("artifacts/play.bmp")
    a.pause(Int64(w.ticks())); draw(a,w.renderer,art); w.renderer.captureBmp("artifacts/pause.bmp"); a.menuOpen=false
    p.update(p.chart.duration+500,true)
    a.screen=3; draw(a,w.renderer,art); w.renderer.captureBmp("artifacts/results.bmp")
    let selected=a.selected
    for (i in 0..a.charts.size) {
        if (a.charts[i].keys == 7) {
            a.selected=i; a.start(Int64(w.ticks())); a.now=a.play.getOrThrow().chart.notes[0].time+4000
            a.play.getOrThrow().update(a.now,true)
            draw(a,w.renderer,art); w.renderer.captureBmp("artifacts/play-7k.bmp"); break
        }
    }
    // Render a non-perfect session with actual miss judgements to inspect all result cells.
    a.selected=selected; a.start(Int64(w.ticks())); let mixed=a.play.getOrThrow()
    for (i in 0..mixed.chart.notes.size) { mixed.award(i%6,mixed.chart.notes[i].time) }
    a.autoplay=false; a.screen=3
    draw(a,w.renderer,art); w.renderer.captureBmp("artifacts/results-mixed.bmp")
    require(handle(a,w,UiEvent.MouseDown(MouseButton.Left,40.0,690.0)) && a.screen == 0,"Results back button")
    a.screen=3
    require(handle(a,w,UiEvent.MouseDown(MouseButton.Left,1160.0,685.0)) && a.screen == 1,"Results retry button")
    a.back()
    require(art.errors == 0,"Visual assets failed to load")
    verifyResourceBounds(a,w,art)
    captureJudgementMotion(w,art)
    println("PASS visual states: 4K / 7K / pause / perfect and mixed results / result buttons")
}

