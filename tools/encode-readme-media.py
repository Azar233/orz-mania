from pathlib import Path
from PIL import Image
import argparse

def encode(source: Path, output: Path, *, compact=False):
    times=[int(v) for v in (source/'times.txt').read_text().splitlines()]
    paths=[source/f'{i:03d}.bmp' for i in range(len(times))]
    if len(paths)<70 or any(not p.is_file() for p in paths): raise ValueError('Native recording is incomplete')
    if compact:
        indices=[round(i*(len(paths)-1)/74) for i in range(75)]
        paths=[paths[i] for i in indices]; times=[times[i] for i in indices]
    sheet=Image.new('RGB',(1280,720))
    for i in range(16):
        with Image.open(paths[i*(len(paths)-1)//15]) as frame:
            sheet.paste(frame.convert('RGB').resize((320,180)),((i%4)*320,(i//4)*180))
    palette=sheet.quantize(colors=128 if compact else 256,method=Image.Quantize.MEDIANCUT)
    # Preserve small but meaningful native HUD colors instead of losing them among photo-background colors.
    accents=[(32,116,76),(155,48,60),(9,70,133),(255,173,201),(249,240,246)]
    colors=palette.getpalette()
    offset=((128 if compact else 256)-len(accents))*3
    colors[offset:offset+len(accents)*3]=[channel for color in accents for channel in color]
    palette.putpalette(colors)
    frames=[]
    for path in paths:
        with Image.open(path) as frame:
            frames.append(frame.convert('RGB').quantize(palette=palette,dither=Image.Dither.NONE))
    durations=[max(10,round((times[i+1]-times[i])/10)*10) for i in range(len(times)-1)]+[50]
    frames[0].save(output,save_all=True,append_images=frames[1:],duration=durations,loop=0,optimize=True,disposal=1)
    with Image.open(output) as result:
        # Pillow merges identical hold frames; validate playback time rather than an arbitrary unique-frame count.
        actual_duration=0
        for i in range(result.n_frames):
            result.seek(i); actual_duration+=result.info.get('duration',0)
        if result.n_frames<2 or result.size!=(960,540) or actual_duration!=sum(durations) or result.info.get('loop')!=0:
            raise ValueError('Invalid GIF output or timing')
        print(f'{output}: {result.n_frames} frames, {output.stat().st_size/1024/1024:.2f} MiB')

if __name__=='__main__':
    parser=argparse.ArgumentParser(description='Encode native --readme-media captures; requires Pillow.')
    parser.add_argument('--input',type=Path,default=Path('artifacts/readme-media'))
    parser.add_argument('--output',type=Path,default=Path('docs/media'))
    parser.add_argument('--practice',action='store_true',help='Encode the slow and fast runtime practice excerpts only.')
    args=parser.parse_args(); args.output.mkdir(parents=True,exist_ok=True)
    for name in (['practice-slow','practice-fast'] if args.practice else ['gameplay','library']):
        encode(args.input/name,args.output/(name+'.gif'),compact=name=='library')
    screenshots=[] if args.practice else [('menu-0','settings'),('menu-3','bindings'),('menu-4','display'),('pause','pause'),('calibration','calibration')]
    for source,target in screenshots:
        with Image.open(args.input/(source+'.bmp')) as frame:
            frame.convert('RGB').save(args.output/(target+'.png'),optimize=True)
        print(args.output/(target+'.png'))
