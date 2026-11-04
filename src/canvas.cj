package orz_mania

import sdl.*

// Public game handlers use canvas coordinates; only native events need conversion.
func canvasPoint(w: SdlWindow,x: Float32,y: Float32): Point {
    let rect=w.renderer.fitCanvas(1280.0,720.0)
    let nativeScale=w.scale*w.currentPixelDensity
    let scale=rect.w/1280.0
    Point((x*nativeScale-rect.x)/scale,(y*nativeScale-rect.y)/scale)
}
func handleWindowEvent(a: App,w: SdlWindow,event: UiEvent): Bool {
    let mapped=match (event) {
        case UiEvent.MouseMove(x,y) => let p=canvasPoint(w,x,y); UiEvent.MouseMove(p.x,p.y)
        case UiEvent.MouseDown(b,x,y) =>
            let p=canvasPoint(w,x,y)
            if (p.x < 0.0 || p.x >= 1280.0 || p.y < 0.0 || p.y >= 720.0) { return true }
            UiEvent.MouseDown(b,p.x,p.y)
        case UiEvent.MouseUp(b,x,y) => let p=canvasPoint(w,x,y); UiEvent.MouseUp(b,p.x,p.y)
        case UiEvent.MouseWheel(dx,dy,x,y) => let p=canvasPoint(w,x,y); UiEvent.MouseWheel(dx,dy,p.x,p.y)
        case _ => event
    }
    handle(a,w,mapped)
}
