package orz_mania

import std.collection.ArrayList

func verifySongGrouping(a: App): Unit {
    let first=Chart(); first.path="Songs\\set-A\\easy.osu"; first.artist="DJ"; first.title="Flower Dance"; first.creator="Author A"; first.audio="Songs/set-A/song.mp3"
    let other=Chart(); other.path="Songs/set-B/easy.osu"; other.artist=first.artist; other.title=first.title; other.audio="Songs/set-B/song.mp3"
    let guest=Chart(); guest.path="Songs/set-A/hard.osu"; guest.artist=first.artist; guest.title=first.title; guest.creator="Guest"; guest.audio=first.audio
    let different=Chart(); different.path="Songs/set-A/another.osu"; different.artist=first.artist; different.title="Another song"
    let samples=ArrayList<Chart>(); for (chart in [first,other,guest,different]) { samples.add(chart) }
    let groups=groupCharts(samples)
    require(groups.size == 3 && groups[1].charts.size == 2 && groups[1].charts[1] == 2,"Same-title charts in different sets remain separate; guest difficulties stay together")
    require(samples[groups[0].charts[0]].title == "Another song","Groups are sorted by title rather than import order")
    require(previewIdentity(first) == previewIdentity(guest) && previewIdentity(first) != previewIdentity(other),"Same audio stays continuous; equal filenames in different sets switch")
    guest.audio="Songs/set-A/song110.mp3"
    require(songGroupKey(first) == songGroupKey(guest) && previewIdentity(first) != previewIdentity(guest),"Pre-rendered rate variants share a drawer but switch the audio")
    var flowers: Int64=0; var count: Int64=0
    for (group in groupCharts(a.charts)) {
        let key=songGroupKey(a.charts[group.charts[0]])
        if (a.charts[group.charts[0]].title == "Flower Dance") { flowers++ }
        for (i in group.charts) { require(songGroupKey(a.charts[i]) == key,"A real drawer must contain only one set/song identity"); count++ }
    }
    require(count == a.charts.size,"Grouping retains every chart exactly once")
    println("PASS grouping: same-title set isolation / guest difficulties / mixed-song folder / path separators / audio identity / complete membership; Flower Dance drawers=${flowers}")
}
