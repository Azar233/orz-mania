package orz_mania

import sdl.*

func codeOf(key: Key): Int64 {
    match (key) {
        case Key.Letter(c) => Int64(c)
        case Key.Digit(c) => Int64(c)
        case Key.Space => 32
        case Key.Enter => 13
        case Key.Tab => 9
        case Key.Backspace => 8
        case Key.Delete => 127
        case Key.Escape => 27
        case Key.Left => 1080
        case Key.Right => 1079
        case Key.Up => 1082
        case Key.Down => 1081
        case Key.Home => 1074
        case Key.End => 1077
        case Key.PageUp => 1075
        case Key.PageDown => 1078
        case Key.RawScancode(51) => 59
        case Key.RawScancode(scan) => 1000+Int64(scan)
    }
}
func bindingScancode(code: Int64): Int64 {
    if (code >= 1000 && code < 1512) { return code-1000 }
    if (code >= 65 && code <= 90) { return code-65+4 }
    if (code >= 49 && code <= 57) { return code-49+30 }
    match (code) {
        case 48 => 39
        case 32 => 44
        case 59 => 51
        case 13 => 40
        case 9 => 43
        case 8 => 42
        case 127 => 76
        case _ => -1
    }
}
func validBindings(keys: Array<Int64>): Bool {
    for (i in 0..keys.size) {
        let scan=bindingScancode(keys[i])
        if (scan <= 0 || scan >= 512 || scan == 41) { return false }
        for (j in 0..i) { if (bindingScancode(keys[j]) == scan) { return false } }
    }
    true
}
func bindingName(code: Int64): String {
    if ((code >= 48 && code <= 90) || code == 59) { return String.fromUtf8([UInt8(code)]) }
    match (code) {
        case 32 => "Space"
        case 13 => "Enter"
        case 9 => "Tab"
        case 8 => "Backspace"
        case 127 => "Delete"
        case 1080 => "Left"
        case 1079 => "Right"
        case 1082 => "Up"
        case 1081 => "Down"
        case 1074 => "Home"
        case 1077 => "End"
        case 1075 => "Page Up"
        case 1078 => "Page Down"
        case 1224 => "L Ctrl"
        case 1225 => "L Shift"
        case 1226 => "L Alt"
        case 1228 => "R Ctrl"
        case 1229 => "R Shift"
        case 1230 => "R Alt"
        case _ => "Scan ${bindingScancode(code)}"
    }
}
func bindingText(a: App,keys: Int64): String {
    let codes=a.keymaps[keys-1]
    String.join(Array<String>(codes.size,{i => bindingName(codes[i])}),delimiter: " ")
}
func captureBinding(a: App,key: Key): Unit {
    let code=codeOf(key); let row=a.bindingKeys-1; let lane=a.bindingCapture
    let candidate=Array<Int64>(a.keymaps[row].size,{i => a.keymaps[row][i]})
    candidate[lane]=code
    if (!validBindings(candidate)) { a.bindingMessage="该键不可用或与其他轨道重复"; return }
    a.keymaps[row]=candidate; a.bindingCapture = -1; a.bindingMessage=""
}
func bindingModeRect(index: Int64): Rect {
    Rect(496.0+Float32(index)*(480.0/9.0),206.0,480.0/9.0,32.0)
}
func bindingKeyRect(keys: Int64,index: Int64): Rect {
    let gap: Float32=if (keys <= 6) { 12.0 } else { 8.0 }
    let width=min(Float32(96.0),(488.0-Float32(keys-1)*gap)/Float32(keys))
    let total=width*Float32(keys)+gap*Float32(keys-1)
    Rect(492.0+(488.0-total)/2.0+Float32(index)*(width+gap),304.0,width,96.0)
}
func compactBindingName(code: Int64): String {
    match (code) {
        case 8 => "Bksp"
        case 127 => "Del"
        case 1075 => "PgUp"
        case 1078 => "PgDn"
        case _ => bindingName(code).replace(" ","").replace("Scan","#")
    }
}
func centeredBindingText(a: App,r: Renderer,value: String,rect: Rect,y: Float32,size: Float32,color: Color): Unit {
    let label=tr(a,value)
    text(r,label,rect.x+(rect.w-r.textWidth(label,pointSize: size))/2.0,y,size,color: color)
}
func drawBindings(a: App,r: Renderer): Unit {
    box(r,492.0,202.0,488.0,42.0,Color.rgb(33,28,41),radius: 4.0)
    for (i in 0..9) {
        let rect=bindingModeRect(i)
        if (a.bindingKeys == i+1) { box(r,rect.x+2.0,rect.y,rect.w-4.0,rect.h,Color.rgb(72,42,65),radius: 4.0) }
        centeredText(r,"${i+1}K",rect,14.0,if (a.bindingKeys == i+1) { PINK } else { MUTED })
    }
    text(r,tr(a,if (a.bindingCapture >= 0) { "按下新的按键，Esc 取消" } else { "点击按键修改绑定" }),492.0,266.0,13.0,color: MUTED)
    for (i in 0..a.bindingKeys) {
        let rect=bindingKeyRect(a.bindingKeys,i)
        let capture=a.bindingCapture == i
        box(r,rect.x,rect.y,rect.w,rect.h,if (capture) { Color.rgb(63,39,59) } else { Color.rgb(38,32,47) },radius: 4.0)
        if (capture || a.menuFocus == i) {
            r.strokeRoundedRect(rect,4.0,Pen(color: PINK.withAlpha(if (capture) { 255 } else { 85 }),width: 1.0))
        }
        centeredBindingText(a,r,"${i+1}",rect,rect.y+12.0,12.0,MUTED)
        let code=a.keymaps[a.bindingKeys-1][i]
        let value=if (capture) { "…" } else if (rect.w < 80.0) { compactBindingName(code) } else { bindingName(code) }
        var size: Float32=if (value.size == 1) { 28.0 } else { 18.0 }
        let width=r.textWidth(value,pointSize: size)
        if (width > rect.w-12.0) { size=max(Float32(10.0),size*(rect.w-12.0)/width) }
        centeredBindingText(a,r,value,rect,rect.y+64.0-r.textHeight(pointSize: size)/2.0,size,if (capture) { PINK } else { WHITE })
    }
    text(r,tr(a,a.bindingMessage),492.0,462.0,13.0,color: PINK)
    menuButton(a,r,"恢复默认",492.0,540.0,156.0,36.0)
}
