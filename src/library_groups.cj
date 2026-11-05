package orz_mania

import std.collection.{ArrayList, HashMap}
import std.sort.sort

class SongGroup {
    let charts=ArrayList<Int64>()
    var remembered: Int64
    var sortKey=""
    var matches: Int64=0
    init(index: Int64) { charts.add(index); remembered=index }
}
class LibraryRow {
    let group: Int64
    let chart: Int64 // -1 is the song drawer header
    init(group: Int64,chart: Int64) { this.group=group; this.chart=chart }
}
func songGroupKey(c: Chart): String {
    let parts=c.path.replace("\\","/").split("/")
    String.join(parts[..parts.size-1],delimiter: "/")+"\n"+c.artist+"\n"+c.title
}
// Full audio paths distinguish same-title sets and pre-rendered rate variants without per-frame allocation.
func previewIdentity(c: Chart): String { c.audio }
func groupCharts(charts: ArrayList<Chart>): ArrayList<SongGroup> {
    let groups=ArrayList<SongGroup>(); let bySong=HashMap<String,Int64>()
    for (i in 0..charts.size) {
        let key=songGroupKey(charts[i])
        if (bySong.contains(key)) { groups[bySong[key]].charts.add(i) }
        else { bySong[key]=groups.size; groups.add(SongGroup(i)) }
    }
    for (group in groups) {
        let c=charts[group.charts[0]]
        group.sortKey=c.title.trimAscii().toAsciiLower()+"\n"+c.artist.toAsciiLower()+"\n"+c.creator.toAsciiLower()+"\n"+c.path.replace("\\","/")
    }
    let ordered=groups.toArray()
    sort<SongGroup,String>(ordered,key: {group => group.sortKey})
    ArrayList<SongGroup>(ordered)
}
func rebuildLibrary(a: App): Unit {
    a.groups=groupCharts(a.charts); a.openGroup = -1
    a.searchIndex.clear()
    for (c in a.charts) { a.searchIndex.add((c.title+"\n"+c.artist+"\n"+c.creator+"\n"+c.version).toAsciiLower()) }
    a.searchNormalized="\u{0001}"; filterLibrary(a,a.searchQuery)
}
func rebuildLibraryRows(a: App): Unit {
    a.rows.clear()
    a.visibleSongs=0; a.visibleCharts=0
    for (g in 0..a.groups.size) {
        let group=a.groups[g]; group.matches=0; var first: Int64 = -1
        for (chart in a.groups[g].charts) { if (a.searchMatches[chart]) {
            group.matches++; if (first < 0) { first=chart }
        } }
        if (first < 0) { continue }
        if (!a.searchMatches[group.remembered]) { group.remembered=first }
        a.visibleSongs++; a.visibleCharts+=group.matches
        a.rows.add(LibraryRow(g,-1))
        if (a.openGroup == g) { for (chart in a.groups[g].charts) { if (a.searchMatches[chart]) { a.rows.add(LibraryRow(g,chart)) } } }
    }
}
func syncLibrarySelection(a: App): Unit {
    if (a.charts.isEmpty()) { a.libraryRow=0; return }
    for (i in 0..a.rows.size) {
        let row=a.rows[i]
        if (row.chart == a.selected) { a.libraryRow=i; a.groups[row.group].remembered=a.selected; return }
    }
    for (i in 0..a.rows.size) {
        let row=a.rows[i]
        if (row.chart >= 0) { continue }
        for (chart in a.groups[row.group].charts) {
            if (chart == a.selected) { a.libraryRow=i; a.groups[row.group].remembered=a.selected; return }
        }
    }
}
func selectLibraryRow(a: App,index: Int64): Unit {
    if (a.rows.isEmpty()) { return }
    a.libraryRow=max(0,min(a.rows.size-1,index))
    let row=a.rows[a.libraryRow]
    a.selected=if (row.chart >= 0) { row.chart } else { a.groups[row.group].remembered }
    if (row.chart >= 0) { a.groups[row.group].remembered=row.chart }
}
func toggleSongDrawer(a: App,index: Int64): Unit {
    if (index < 0 || index >= a.rows.size) { return }
    let group=a.rows[index].group
    selectLibraryRow(a,index)
    a.openGroup=if (a.openGroup == group) { -1 } else { group }
    a.drawerFade=0.0
    rebuildLibraryRows(a)
    for (i in 0..a.rows.size) {
        if (a.rows[i].group == group && a.rows[i].chart < 0) {
            let shift=Float32(i-index)
            a.libraryScroll=max(Float32(0.0),a.libraryScroll+shift)
            a.libraryFocus+=shift
            a.libraryRow=i; a.libraryHover = -1; break
        }
    }
}
