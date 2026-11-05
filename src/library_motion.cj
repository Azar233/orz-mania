package orz_mania

import std.math.{exp, abs}
import std.collection.ArrayList
import sdl.*

let LIBRARY_TITLE_WIDTH: Float32=338.0
let LIBRARY_TITLE_SIZE: Float32=34.0
// Pause at both ends and travel at 36 logical pixels/second; no frame-rate dependency.
func titleScrollOffset(width: Float32,elapsed: Int64): Float32 {
    let distance=max(Float32(0.0),width-LIBRARY_TITLE_WIDTH)
    if (distance <= 0.0) { return 0.0 }
    let travel=max(1,Int64(distance/0.036+0.5))
    let phase=max(0,elapsed)%(1200+travel+1000+travel)
    if (phase < 1200) { return 0.0 }
    if (phase < 1200+travel) { return distance*Float32(phase-1200)/Float32(travel) }
    if (phase < 2200+travel) { return distance }
    distance*(1.0-Float32(phase-2200-travel)/Float32(travel))
}
class LibraryTitle {
    var value=""
    var width: Float32=0.0
    var started: Int64=0
    var measurements: Int64=0
    func offset(title: String,r: Renderer,now: Int64): Float32 {
        if (title != value) {
            value=title; width=r.textWidth(title,pointSize: LIBRARY_TITLE_SIZE)
            started=now; measurements++
        }
        titleScrollOffset(width,now-started)
    }
}

let LIBRARY_STEP: Float32=88.0
let LIBRARY_HEIGHT: Float32=100.0
func libraryListRect(): Rect { Rect(426.0,144.0,822.0,552.0) }
func libraryFullRows(): Int64 { Int64((libraryListRect().h-LIBRARY_HEIGHT)/LIBRARY_STEP)+1 }
func libraryRowY(a: App,index: Int64): Float32 { libraryListRect().y+(Float32(index)-a.libraryScroll)*LIBRARY_STEP }
// Paint the nearest card last, so selection rises above its neighbours.
func libraryLayers(a: App): ArrayList<Int64> {
    let order=a.libraryOrder; order.clear()
    let first=max(0,Int64(a.libraryScroll)-2)
    let candidates=Int64(libraryListRect().h/LIBRARY_STEP)+5
    for (i in first..min(a.rows.size,first+candidates)) {
        var at=0
        while (at < order.size && abs(Float32(order[at])-a.libraryFocus) > abs(Float32(i)-a.libraryFocus)) { at++ }
        order.add(i)
        var cursor=order.size-1
        while (cursor > at) { order[cursor]=order[cursor-1]; cursor-- }
        order[at]=i
    }
    order
}

func libraryTarget(a: App): Float32 { Float32(max(0,min(max(0,a.rows.size-libraryFullRows()),a.libraryRow-1))) }
func resetLibraryMotion(a: App): Unit {
    syncLibrarySelection(a)
    a.libraryScroll=libraryTarget(a); a.libraryFocus=Float32(a.libraryRow)
    a.libraryPrevious=a.selected; a.librarySelected=a.selected; a.libraryFade=1.0
    a.libraryHover = -1; a.wheelRemainder=0.0
}
func animateLibrary(a: App,dt: Float32): Unit {
    let blend=Float32(1.0-exp(-14.0*Float64(max(Float32(0.0),dt))))
    let hover: Float32=if (a.brandHover && !a.menuOpen) { 1.0 } else { 0.0 }
    a.brandHoverAmount+=(hover-a.brandHoverAmount)*blend
    if (abs(a.brandHoverAmount-hover) < 0.001) { a.brandHoverAmount=hover }
    if (a.charts.isEmpty()) { return }
    if (a.librarySelected != a.selected) {
        a.libraryPrevious=a.librarySelected; a.librarySelected=a.selected; a.libraryFade=0.0
    }
    // Exponential easing has the same response at different refresh rates.
    let target=libraryTarget(a)
    a.libraryScroll+=(target-a.libraryScroll)*blend
    a.libraryFocus+=(Float32(a.libraryRow)-a.libraryFocus)*blend
    if (abs(a.libraryScroll-target) < 0.001) { a.libraryScroll=target }
    if (abs(a.libraryFocus-Float32(a.libraryRow)) < 0.001) { a.libraryFocus=Float32(a.libraryRow) }
    a.drawerFade=min(Float32(1.0),a.drawerFade+dt*7.0)
    a.libraryFade=min(Float32(1.0),a.libraryFade+dt*5.0)
}
func libraryEmphasis(a: App,index: Int64): Float32 {
    let focus=max(Float32(0.0),1.0-abs(Float32(index)-a.libraryFocus))
    max(focus,if (a.libraryHover == index) { Float32(0.3) } else { Float32(0.0) })
}
func libraryCardX(a: App,index: Int64): Float32 {
    let distance=min(Float32(3.0),abs(Float32(index)-a.libraryFocus))
    476.0+distance*distance*7.0-libraryEmphasis(a,index)*44.0+if (a.rows[index].chart >= 0) { Float32(22.0) } else { Float32(0.0) }
}
func libraryHit(a: App,x: Float32,y: Float32): Int64 {
    if (!inRect(x,y,libraryListRect()) || x >= 1228.0) { return -1 }
    let order=libraryLayers(a)
    var at=order.size
    while (at > 0) {
        at--
        let index=order[at]; let top=libraryRowY(a,index)
        if (x >= libraryCardX(a,index) && y >= top && y < top+LIBRARY_HEIGHT) { return index }
    }
    -1
}
