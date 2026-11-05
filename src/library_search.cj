package orz_mania

import sdl.*
import sdl.input.{Cursor,SystemCursor}

func librarySearchRect(): Rect { Rect(454.0,22.0,774.0,36.0) }
func librarySearchClearRect(): Rect { Rect(1190.0,22.0,38.0,36.0) }
func searchCaretVisible(elapsed: Int64): Bool { max(0,elapsed)%1000 < 500 }
func setSearchHover(a: App,hover: Bool): Unit {
    if (a.searchHover == hover) { return }
    if (hover) {
        if (a.searchTextCursor.isNone()) { a.searchTextCursor=Some(Cursor.system(SystemCursor.Text)) }
        a.searchTextCursor.getOrThrow().setActive()
    } else {
        if (a.searchArrowCursor.isNone()) { a.searchArrowCursor=Some(Cursor.system(SystemCursor.Default)) }
        a.searchArrowCursor.getOrThrow().setActive()
    }
    a.searchHover=hover
}
func closeSearchCursors(a: App): Unit {
    if (let Some(cursor) <- a.searchTextCursor) { cursor.close() }; a.searchTextCursor=None
    if (let Some(cursor) <- a.searchArrowCursor) { cursor.close() }; a.searchArrowCursor=None
    a.searchHover=false
}
func filterLibrary(a: App,value: String): Unit {
    let clean=value.replace("\n"," ").replace("\r"," ").replace("\t"," ")
    if (clean.size > 512) { return }
    a.searchQuery=clean
    let query=clean.trimAscii().toAsciiLower()
    if (query == a.searchNormalized) { return }
    a.searchNormalized=query; a.searchPasses++
    let words=query.split(" ")
    a.searchMatches=Array<Bool>(a.charts.size,{i =>
        var matches=true
        for (word in words) { if (!word.isEmpty() && !a.searchIndex[i].contains(word)) { matches=false; break } }
        matches
    })
    a.openGroup = -1; a.lastClickChart = -1
    rebuildLibraryRows(a)
    if (!a.rows.isEmpty() && !a.searchMatches[a.selected]) { selectLibraryRow(a,0) }
    if (a.rows.isEmpty()) { a.music.stop(); a.previewSong="" }
    resetLibraryMotion(a)
}
func searchBackspace(value: String): String {
    if (value.isEmpty()) { return value }
    let bytes=value.toArray(); var end=bytes.size-1
    while (end > 0 && (bytes[end] & 0xC0) == 0x80) { end-- }
    value[..end]
}
func positionSearchIme(w: SdlWindow): Unit {
    let canvas=w.renderer.fitCanvas(1280.0,720.0); let rect=librarySearchRect()
    let scale=canvas.w/1280.0; let nativeScale=w.scale*w.currentPixelDensity
    w.setTextInputArea(Rect((canvas.x+rect.x*scale)/nativeScale,(canvas.y+rect.y*scale)/nativeScale,rect.w*scale/nativeScale,rect.h*scale/nativeScale))
}
func handleLibrarySearch(a: App,w: SdlWindow,event: UiEvent): Bool {
    match (event) {
        case UiEvent.MouseMove(x,y) => setSearchHover(a,inRect(x,y,librarySearchRect()))
        case UiEvent.MouseDown(MouseButton.Left,x,y) =>
            if (inRect(x,y,librarySearchRect())) {
                setSearchHover(a,true); a.searchFocused=true; a.searchCaretStart=a.uiTick; positionSearchIme(w)
                if (inRect(x,y,librarySearchClearRect())) { a.searchComposition=""; filterLibrary(a,"") }
                return true
            }
            setSearchHover(a,false); a.searchFocused=false; a.searchComposition=""
        case UiEvent.TextInput(value) => if (a.searchFocused) { a.searchCaretStart=a.uiTick; a.searchComposition=""; filterLibrary(a,a.searchQuery+value); return true }
        case UiEvent.TextEditing(value,_,_) => if (a.searchFocused) { a.searchCaretStart=a.uiTick; a.searchComposition=if (value.size <= 512) { value } else { "" }; return true }
        case UiEvent.WindowResized(_,_) | UiEvent.WindowPixelSizeChanged(_,_) => if (a.searchFocused) { positionSearchIme(w) }
        case UiEvent.KeyDown(key,_) => if (a.searchFocused) {
            match (key) {
                case Key.Escape => if (!a.searchComposition.isEmpty()) { a.searchComposition="" } else { a.searchFocused=false }
                case Key.Enter => if (a.searchComposition.isEmpty()) { a.searchFocused=false }
                case Key.Backspace => if (a.searchComposition.isEmpty()) { a.searchCaretStart=a.uiTick; filterLibrary(a,searchBackspace(a.searchQuery)) }
                case Key.Up => if (a.searchComposition.isEmpty()) { selectLibraryRow(a,a.libraryRow-1) }
                case Key.Down => if (a.searchComposition.isEmpty()) { selectLibraryRow(a,a.libraryRow+1) }
                case _ => ()
            }
            return true
        }
        case _ => ()
    }
    false
}
func drawLibrarySearch(a: App,r: Renderer): Unit {
    let rect=librarySearchRect()
    box(r,rect.x,rect.y,rect.w,rect.h,if (a.searchFocused) { Color.rgb(43,33,48) } else if (a.searchHover) { Color.rgb(36,29,43) } else { PANEL.withAlpha(200) },radius: 4.0)
    if (a.searchFocused || a.searchHover) { r.strokeRoundedRect(rect,4.0,Pen(color: PINK.withAlpha(if (a.searchFocused) { 120 } else { 55 }),width: 1.0)) }
    r.pushClip(Rect(rect.x+12.0,rect.y,rect.w-60.0,rect.h))
    let empty=a.searchQuery.isEmpty() && a.searchComposition.isEmpty()
    let input=if (a.searchComposition.isEmpty()) { a.searchQuery } else { a.searchQuery+" ["+a.searchComposition+"]" }
    let label=if (empty) { tr(a,"搜索歌名 / 歌手 / 谱师 / 难度") } else { input }
    if (input != a.searchMeasured) { a.searchMeasured=input; a.searchTextWidth=r.textWidth(input,pointSize: 14.0) }
    let offset=if (a.searchFocused) { max(Float32(0.0),a.searchTextWidth-(rect.w-64.0)) } else { Float32(0.0) }
    text(r,label,rect.x+12.0-offset+if (empty && a.searchFocused) { Float32(3.0) } else { Float32(0.0) },rect.y+(rect.h-r.textHeight(pointSize: 14.0))/2.0,14.0,color: if (empty) { MUTED } else { WHITE })
    if (a.searchFocused && searchCaretVisible(a.uiTick-a.searchCaretStart)) { r.fill(Rect(rect.x+13.0+a.searchTextWidth-offset,rect.y+8.0,1.0,20.0),PINK) }
    r.popClip()
    if (!a.searchQuery.isEmpty() || !a.searchComposition.isEmpty()) { centeredText(r,"×",librarySearchClearRect(),18.0,MUTED) }
}
