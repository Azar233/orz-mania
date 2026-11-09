package orz_mania

// The bundled Pink Elements skin.ini uses ColumnWidth 68 and HitPosition 467 for 4K.
// Circle retains its existing layout; the other forms share this family's source scale.
let NOTE_LAYOUT_SCALE: Float32=720.0/512.0
class NoteLayout {
    let widths: Array<Float32>
    let offsets: Array<Float32>
    let width: Float32
    let left: Float32
    let maxColumn: Float32
    let hitY: Float32
    let heightBasis: Float32
    init(skin: Int64,keys: Int64) {
        let column=if (skin == 0) { min(Float32(696.0),Float32(keys)*104.0)/Float32(keys) }
            else { min(Float32(696.0),Float32(keys)*68.0*NOTE_LAYOUT_SCALE)/Float32(keys) }
        widths=Array<Float32>(keys,repeat: column)
        offsets=Array<Float32>(keys,{i => Float32(i)*column})
        width=Float32(keys)*column; left=535.0-width/2.0; maxColumn=column
        hitY=if (skin == 0) { 667.0 } else { 467.0*NOTE_LAYOUT_SCALE }
        heightBasis=column-6.0
    }
}
let NOTE_LAYOUTS=Array<Array<NoteLayout>>(4,{skin => Array<NoteLayout>(9,{i => NoteLayout(skin,i+1)})})
func noteLayout(skin: Int64,keys: Int64): NoteLayout { NOTE_LAYOUTS[skin][keys-1] }
