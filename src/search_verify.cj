package orz_mania

import sdl.*
import sdl.system.PerformanceClock
import std.collection.ArrayList

func verifyLibrarySearch(a: App,w: SdlWindow): Unit {
    let catalog=a.charts; let selected=a.selected; let query=a.searchQuery
    try {
        a.back(); filterLibrary(a,"")
        var indexBytes: Int64=0
        for (value in a.searchIndex) { indexBytes+=value.size }
        let start=PerformanceClock.ticksNanoseconds()
        for (_ in 0..20) { for (term in ["a","al","flower","dj dance","expert",""]) { filterLibrary(a,term) } }
        let averageUs=Float64(PerformanceClock.ticksNanoseconds()-start)/120.0/1000.0
        println("SEARCH sample: charts=${a.charts.size}, cachedTextBytes=${indexBytes}, queryAverageUs=${averageUs}, updates=120")
        let fixtures=ArrayList<Chart>()
        for ((title,artist,creator,version) in [("zeta","B","MapperZ","Easy"),("alpha","A","作者甲","Hard"),("Beta","A","MapperB","Expert"),("ALPHA","B","M2","Extreme")]) {
            let c=Chart(); c.title=title; c.artist=artist; c.creator=creator; c.version=version
            c.path="Songs/search-${fixtures.size}/map.osu"; c.audio=c.path+".mp3"
            fixtures.add(c)
        }
        a.charts=fixtures; a.selected=0; a.searchQuery=""; rebuildLibrary(a)
        require(a.groups[0].charts[0] == 1 && a.groups[1].charts[0] == 3 && a.groups[2].charts[0] == 2,"Title sorting ignores ASCII case and uses stable metadata ties")
        filterLibrary(a,"ALPHA")
        require(a.visibleSongs == 2 && a.visibleCharts == 2 && a.selected == 1,"Search is case insensitive and selects a matching chart")
        filterLibrary(a,"alpha 作者")
        require(a.rows.size == 1 && a.selected == 1,"Keywords can match title and mapper together")
        toggleSongDrawer(a,0)
        require(a.rows.size == 2 && a.rows[1].chart == 1,"Filtered drawers open only matching difficulties")
        filterLibrary(a,"expert"); let scans=a.searchPasses
        for (_ in 0..1000) { filterLibrary(a,"EXPERT"); a.tick(Int64(w.ticks())); let _=libraryLayers(a) }
        require(a.searchPasses == scans && a.selected == 2,"Idle frames and unchanged normalized input do not rescan metadata")
        filterLibrary(a,"no-such-song")
        require(a.rows.isEmpty() && a.visibleSongs == 0 && a.visibleCharts == 0,"No results clears the visible library")
        a.start(Int64(w.ticks())); a.preview(async: true)
        require(a.screen == 0 && a.play.isNone() && !a.music.started,"No results cannot start or preview a stale selection")
        filterLibrary(a,""); require(a.rows.size == 4,"Clearing restores all songs")
        let rect=librarySearchRect()
        let scansBeforeHover=a.searchPasses
        let _=handle(a,w,UiEvent.MouseMove(rect.x+20.0,rect.y+18.0))
        require(a.searchHover && a.searchTextCursor.isSome() && a.searchPasses == scansBeforeHover,"Hover activates a cached native text cursor without searching")
        require(searchCaretVisible(0) && searchCaretVisible(499) && !searchCaretVisible(500) && !searchCaretVisible(999) && searchCaretVisible(1000),"Caret blink uses a bounded one-second clock cycle")
        let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,rect.x+10.0,rect.y+10.0))
        require(a.searchFocused && a.searchCaretStart == a.uiTick,"Search focuses text entry with a visible initial caret")
        let _=handle(a,w,UiEvent.KeyDown(Key.Letter(73),false))
        require(a.dialog.isNone(),"Typing I must not open the import dialog")
        let beforeIme=a.searchPasses
        let _=handle(a,w,UiEvent.TextEditing("作者",0,2))
        let _=handle(a,w,UiEvent.KeyDown(Key.Enter,false))
        require(a.searchFocused && a.searchPasses == beforeIme,"IME candidates do not filter or start gameplay")
        let _=handle(a,w,UiEvent.TextInput("作者"))
        require(a.visibleCharts == 1 && a.selected == 1 && a.searchCaretStart == a.uiTick,"Committed Chinese text filters normally and resets the caret")
        let _=handle(a,w,UiEvent.KeyDown(Key.Backspace,false))
        require(a.searchQuery == "作" && searchBackspace("A😀中") == "A😀" && searchBackspace("A😀") == "A","Backspace preserves UTF-8 codepoint boundaries")
        let _=handle(a,w,UiEvent.KeyDown(Key.Enter,false))
        require(!a.searchFocused && a.screen == 0,"Enter finishes editing without launching a chart")
        let clear=librarySearchClearRect()
        let _=handle(a,w,UiEvent.MouseDown(MouseButton.Left,clear.x+10.0,clear.y+10.0))
        require(a.searchQuery.isEmpty() && a.rows.size == 4,"Clear button restores the library")
        let _=handle(a,w,UiEvent.KeyDown(Key.Escape,false))
        require(!a.searchFocused && !a.menuOpen,"Escape leaves search before opening a menu")
        let _=handle(a,w,UiEvent.MouseMove(200.0,100.0))
        require(!a.searchHover && a.searchArrowCursor.isSome(),"Pointer exit restores the native arrow")
        let _=handle(a,w,UiEvent.MouseMove(rect.x+20.0,rect.y+18.0))
        openMenu(a,Int64(w.ticks()))
        require(!a.searchHover && !a.searchFocused,"Opening the menu restores the arrow and clears search focus")
        a.menuOpen=false
        let old=a.searchQuery; filterLibrary(a,String.fromUtf8(Array<UInt8>(513,repeat: 65)))
        require(a.searchQuery == old,"Overlong input is bounded")
        println("PASS library search: title order / cached matching / keyword AND / Chinese IME / Unicode deletion / no idle rescans / filtered selection and drawers / clear / empty results / shortcut isolation / length bound")
    } finally {
        a.charts=catalog; a.selected=selected; a.searchQuery=query; a.searchFocused=false; a.searchComposition=""
        closeSearchCursors(a)
        rebuildLibrary(a)
    }
}
