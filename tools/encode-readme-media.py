from pathlib import Path
from PIL import Image
import argparse

def encode(source: Path, output: Path, size=None):
    times=[int(v) for v in (source/'times.txt').read_text().splitlines()]
    paths=[source/f'{i:03d}.bmp' for i in range(len(times))]
    if len(paths)<70 or any(not p.is_file() for p in paths): raise ValueError('Native recording is incomplete')
    # Build one shared palette from full-resolution native pixels, avoiding averaged thumbnail colors.
    # Keep all captured frames; a stable palette also avoids per-frame color flicker while scrolling.
    with Image.open(paths[0]) as first:
        native_size=first.size
        width,height=size or native_size
    sheet=Image.new('RGB',(width*4,height*4))
    for i in range(16):
        with Image.open(paths[i*(len(paths)-1)//15]) as frame:
            if frame.size!=native_size: raise ValueError('Native frame size changed')
            sheet.paste(frame.convert('RGB').resize((width,height),Image.Resampling.LANCZOS),((i%4)*width,(i//4)*height))
    accents=[(32,116,76),(155,48,60),(9,70,133),(255,173,201),(249,240,246)]
    palette=sheet.quantize(colors=256-len(accents),method=Image.Quantize.MEDIANCUT)
    # Append HUD colors into reserved slots; never replace colors selected from the recording.
    palette.putpalette(palette.getpalette()[:(256-len(accents))*3]+[
        channel for color in accents for channel in color])
    frames=[]
    for path in paths:
        with Image.open(path) as frame:
            frames.append(frame.convert('RGB').resize((width,height),Image.Resampling.LANCZOS).quantize(palette=palette,dither=Image.Dither.FLOYDSTEINBERG))
    durations=[max(10,round((times[i+1]-times[i])/10)*10) for i in range(len(times)-1)]+[50]
    frames[0].save(output,save_all=True,append_images=frames[1:],duration=durations,loop=0,optimize=True,disposal=1)
    with Image.open(output) as result:
        # Pillow merges identical hold frames; validate playback time rather than an arbitrary unique-frame count.
        actual_duration=0
        for i in range(result.n_frames):
            result.seek(i); actual_duration+=result.info.get('duration',0)
        if result.n_frames<2 or result.size!=(width,height) or actual_duration!=sum(durations) or result.info.get('loop')!=0:
            raise ValueError('Invalid GIF output or timing')
        print(f'{output}: {result.n_frames} frames, {output.stat().st_size/1024/1024:.2f} MiB')

if __name__=='__main__':
    parser=argparse.ArgumentParser(description='Encode native --readme-media captures; requires Pillow.')
    parser.add_argument('--input',type=Path,default=Path('artifacts/readme-media'))
    parser.add_argument('--output',type=Path,default=Path('docs/media'))
    parser.add_argument('--practice',action='store_true',help='Encode the slow and fast runtime practice excerpts only.')
    parser.add_argument('--skins',action='store_true',help='Encode four skin excerpts at 640x360 and refresh settings/pause.')
    args=parser.parse_args(); args.output.mkdir(parents=True,exist_ok=True)
    if args.practice and args.skins: parser.error('Choose one capture set')
    names=['skin-circle','skin-diamond','skin-bar','skin-arrows'] if args.skins else (['practice-slow','practice-fast'] if args.practice else ['gameplay','library'])
    for name in names:
        encode(args.input/name,args.output/(name+'.gif'),size=(640,360) if args.skins else None)
    screenshots=[('menu-0','settings'),('pause','pause')] if args.skins else ([] if args.practice else [('menu-0','settings'),('menu-3','bindings'),('menu-4','display'),('pause','pause'),('calibration','calibration')])
    for source,target in screenshots:
        with Image.open(args.input/(source+'.bmp')) as frame:
            frame.convert('RGB').save(args.output/(target+'.png'),optimize=True)
        print(args.output/(target+'.png'))
