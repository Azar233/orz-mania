package orz_mania

import sdl.*
import std.fs.{Directory,exists}

// Rasterize each Windows icon size from vector paths, never from a resized PNG.
func prepareAppIcons(source: String,output: String,preview!: Bool=false): Unit {
    if (!exists(output)) { Directory.create(output,recursive: true) }
    let sizes=if (preview) { [512,1254] } else { [16,24,32,48,64,128,256] }
    for (size in sizes) {
        try (surface=Surface.load(source,options: ImageLoadOptions(width: Int32(size),height: Int32(size),maxPixels: if (preview) { 2000000 } else { 65536 }))) {
            require(surface.size().w == Float32(size) && surface.size().h == Float32(size),"SVG icon dimensions differ")
            surface.savePng(output+"/app-icon-${size}.png")
        }
    }
    println(if (preview) { "PASS SVG review renders at 512/1254px" } else { "PASS SVG rasterization at 16/24/32/48/64/128/256px" })
}
