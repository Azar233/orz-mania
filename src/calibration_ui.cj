package orz_mania

import sdl.*

func drawCalibration(a: App,r: Renderer): Unit {
    let g=a.calibration.getOrThrow(); let model=g.samples
    box(r,226.0,116.0,828.0,476.0,Color.rgb(24,20,31),radius: 4.0)
    text(r,tr(a,"偏移校准"),254.0,136.0,26.0)
    for (i in 0..2) {
        let rect=calibrationModeRect(i)
        menuButton(a,r,if (i == 0) { "目押" } else { "音押" },rect.x,rect.y,rect.w,rect.h,active: g.visual == (i == 0))
    }
    text(r,tr(a,if (g.visual) { "标记到达横线时按键。" } else { "跟随节拍按键，可隐藏音符专注听音。" }),254.0,190.0,15.0)
    text(r,tr(a,"空格、当前绑定键或点击轨道采样；Enter 开始 / 停止，Esc 返回。"),254.0,216.0,12.0,color: MUTED)
    let lane=calibrationLaneRect()
    r.fill(lane,Color.rgba(5,4,9,170))
    r.line(lane.x+15.0,470.0,lane.x+lane.w-15.0,470.0,PINK)
    if (g.showNotes) {
        let time=g.cueTime()
        let first=if (time >= 0) { time/CALIBRATION_PERIOD } else { -((-time+CALIBRATION_PERIOD-1)/CALIBRATION_PERIOD) }
        r.pushClip(lane)
        for (beat in first-1..first+4) {
            let y=470.0-Float32(beat*CALIBRATION_PERIOD-time)*0.145
            if (y >= lane.y-20.0 && y < lane.y+lane.h+20.0) {
                r.fillRoundedRect(Rect(lane.x+lane.w/2.0-28.0,y-9.0,56.0,18.0),4.0,PINK)
            }
        }
        r.popClip()
    } else { centeredText(r,tr(a,"音符已隐藏"),lane,13.0,MUTED) }
    text(r,tr(a,"建议判定偏移"),514.0,254.0,18.0)
    let draft=g.draftAudio
    let suggested=if (g.running && model.count > 0) { model.suggestion } else { draft }
    text(r,"${suggested} ms",514.0,285.0,32.0,color: PINK)
    text(r,if (a.english) { "Samples ${model.inliers} / ${model.count}   ·   spread ±${model.spread} ms" }
        else { "有效 ${model.inliers} / ${model.count} 次   ·   波动 ±${model.spread} ms" },514.0,338.0,13.0,color: MUTED)
    let status=if (!g.message.isEmpty()) { g.message }
        else if (!g.canStart()) { if (g.visual) { "请显示音符后开始" } else { "请开启节拍音后开始" } }
        else if (!g.running) { "点击开始，至少采样 8 次" }
        else if (g.position < model.warmUntil) { "准备中，请先跟随节奏" }
        else if (model.ready()) { "建议值已稳定，可以应用" }
        else { "继续采样，建议至少 12 次" }
    text(r,tr(a,status),514.0,362.0,13.0,color: if (model.ready()) { PINK } else { MUTED })
    r.fill(Rect(516.0,403.0,464.0,2.0),WHITE.withAlpha(50))
    r.fill(Rect(748.0,394.0,1.0,20.0),MUTED)
    for (i in 0..model.count) {
        let x=748.0+Float32(max(-150,min(150,model.values[i])))*1.4
        r.fill(Rect(x,398.0,1.0,12.0),WHITE.withAlpha(100))
    }
    if (model.count > 0) {
        let x=748.0+Float32(max(-150,min(150,model.suggestion)))*1.4
        r.fill(Rect(x,394.0,2.0,20.0),PINK)
    }
    let minus=calibrationStepRect(false); let plus=calibrationStepRect(true)
    menuButton(a,r,"−",minus.x,minus.y,minus.w,minus.h)
    box(r,554.0,448.0,112.0,32.0,Color.rgb(38,32,47),radius: 4.0)
    centeredText(r,"${draft} ms",Rect(554.0,448.0,112.0,32.0),16.0,WHITE)
    menuButton(a,r,"+",plus.x,plus.y,plus.w,plus.h)
    let notes=calibrationToggleRect(false); let sound=calibrationToggleRect(true)
    menuButton(a,r,if (g.showNotes) { "音符 ON" } else { "音符 OFF" },notes.x,notes.y,notes.w,notes.h,active: g.showNotes)
    menuButton(a,r,if (g.sound) { "声音 ON" } else { "声音 OFF" },sound.x,sound.y,sound.w,sound.h,active: g.sound)
    text(r,tr(a,if (g.visual) { "目押优先调整判定，保持下落位置。" } else { "参考节奏固定；建议值只在应用后生效。" }),514.0,496.0,12.0,color: MUTED)
    let labels=["重置","开始","应用","返回"]
    for (i in 0..4) {
        let rect=calibrationActionRect(i)
        menuButton(a,r,if (i == 1 && g.running) { "停止" } else { labels[i] },rect.x,rect.y,rect.w,rect.h,
            active: (i == 1 && g.running) || (i == 2 && g.canApply()),enabled: if (i == 2) { g.canApply() } else if (i == 1 && !g.running) { g.canStart() } else { true })
    }
}
