package orz_mania

import sdl.*

let LOCAL_RANK_LABELS=Array<String>(21,{i => "#${i+1}"})
func localScoreRect(): Rect { Rect(62.0,505.0,338.0,194.0) }
func syncScorePanel(a: App): Unit {
    if (a.charts.isEmpty()) { return }
    let key=a.charts[a.selected].scoreKey
    if (a.scoreChart != key) { a.scoreChart=key; a.scorePage=0; a.scoreWheel=0.0 }
    let count=a.localScores.forChart(key).size
    a.scorePage=max(0,min(max(0,count-4),a.scorePage))
}
func drawLocalScores(a: App,r: Renderer): Unit {
    syncScorePanel(a)
    let rect=localScoreRect(); let rows=a.localScores.forChart(a.scoreChart)
    r.pushClip(rect)
    text(r,tr(a,"本地排行"),64.0,507.0,13.0,color: MUTED)
    if (!a.localScores.status.isEmpty()) { text(r,tr(a,a.localScores.status),191.0,507.0,10.0,color: PINK) }
    if (rows.isEmpty()) {
        text(r,tr(a,"暂无本地成绩"),64.0,544.0,14.0,color: MUTED)
    } else {
        if (a.localScores.status.isEmpty()) { text(r,"${a.scorePage+1}–${min(rows.size,a.scorePage+4)} / ${rows.size}",319.0,508.0,11.0,color: MUTED) }
        for (index in a.scorePage..min(rows.size,a.scorePage+4)) {
            let row=rows[index]; let top=531.0+Float32(index-a.scorePage)*40.0
            text(r,LOCAL_RANK_LABELS[index],65.0,top+2.0,13.0,color: if (index == 0) { PINK } else { MUTED })
            text(r,row.scoreText,105.0,top,17.0)
            text(r,row.detail,249.0,top+3.0,11.0,color: WHITE.withAlpha(190))
            text(r,row.dateText,105.0,top+22.0,10.0,color: MUTED)
            r.fill(Rect(64.0,top+37.0,334.0,1.0),WHITE.withAlpha(22))
        }
    }
    r.popClip()
}
func liveScoreRect(keys: Int64,rows: Int64): Rect {
    let laneWidth=min(Float32(696.0),Float32(keys)*104.0)
    Rect(16.0,124.0,min(Float32(250.0),535.0-laneWidth/2.0-30.0),24.0+Float32(rows)*38.0)
}
func rankingHintAlpha(elapsed: Int64): Int64 {
    if (elapsed <= 1000) { return 175 }
    if (elapsed >= 1600) { return 0 }
    175*(1600-elapsed)/600
}
func drawLiveScores(a: App,p: Play,r: Renderer): Unit {
    if (!a.showRanking) { return }
    if (let Some(view) <- a.liveRanking) {
        view.update(p)
        let rect=liveScoreRect(p.chart.keys,view.visible.size)
        r.fill(rect,Color.rgba(12,10,18,115))
        text(r,tr(a,"本地排行"),rect.x+7.0,rect.y+4.0,12.0,color: MUTED)
        let hint=rankingHintAlpha(a.uiTick-a.rankingHintStart)
        if (hint > 0 && (a.autoplay || laneOf(a,p,Key.Tab) < 0)) {
            text(r,"Tab",rect.x+rect.w-29.0,rect.y+6.0,9.0,color: MUTED.withAlpha(hint))
        }
        r.pushClip(rect)
        for (slot in 0..view.visible.size) {
            let index=view.visible[slot]; let top=rect.y+24.0+Float32(slot)*38.0
            let current=index < 0
            if (current) { r.fill(Rect(rect.x,top,rect.w,37.0),PINK.withAlpha(24)) }
            let score=if (current) { view.scoreText } else { view.history[index].scoreText }
            let accuracy=if (current) { view.accuracyText } else { view.history[index].accuracyText }
            let title=if (current) { tr(a,if (a.rankedRun && !p.assisted) { "本次游玩" } else { "自动演示" }) }
                else { view.history[index].dateText }
            let color=if (current) { PINK } else { WHITE.withAlpha(210) }
            text(r,LOCAL_RANK_LABELS[view.first+slot],rect.x+7.0,top+2.0,11.0,color: color)
            text(r,title,rect.x+38.0,top+2.0,11.0,color: color)
            text(r,score,rect.x+38.0,top+19.0,12.0,color: color)
            let wide=rect.w >= 220.0
            let detail=if (wide) { if (current) { view.detail } else { view.history[index].detail } } else { accuracy }
            text(r,detail,rect.x+rect.w-if (wide) { Float32(132.0) } else { Float32(57.0) },top+20.0,10.0,color: WHITE.withAlpha(175))
        }
        r.popClip()
    }
}
func drawScoreNotice(a: App,r: Renderer): Unit {
    if (!a.completionHandled) { return }
    let label=if (a.scoreSaved) {
        if (a.english) { "Local rank #${a.localScores.lastRank}" } else { "本地第 ${a.localScores.lastRank} 名" }
    } else if (!a.rankedRun) { tr(a,"自动演示不计入排行") }
    else { tr(a,a.localScores.status) }
    if (label.isEmpty()) { return }
    let rect=resultNoticeRect()
    let size=max(Float32(11.0),min(Float32(15.0),15.0*(rect.w-20.0)/max(Float32(1.0),r.textWidth(label,pointSize: 15.0))))
    r.fill(rect,Color.rgba(38,32,47,95))
    r.pushClip(rect)
    centeredText(r,label,rect,size,PINK)
    r.popClip()
}
