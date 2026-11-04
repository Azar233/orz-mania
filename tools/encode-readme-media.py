from pathlib import Path
from PIL import Image
import argparse

def encode(source: Path, output: Path, *, compact=False):
    paths=sorted(source.glob('*.bmp'))
    times=[int(v) for v in (source/'times.txt').read_text().splitlines()]
    if len(paths)!=len(times) or len(paths)<70: raise ValueError('Native recording is incomplete')
    if compact:
        indices=[round(i*(len(paths)-1)/74) for i in range(75)]
        paths=[paths[i] for i in indices]; times=[times[i] for i in indices]
    sheet=Image.new('RGB',(1280,720))
    for i in range(16):
        with Image.open(paths[i*(len(paths)-1)//15]) as frame:
            sheet.paste(frame.convert('RGB').resize((320,180)),((i%4)*320,(i//4)*180))
    palette=sheet.quantize(colors=128 if compact else 256,method=Image.Quantize.MEDIANCUT)
    frames=[]
    for path in paths:
        with Image.open(path) as frame:
            frames.append(frame.convert('RGB').quantize(palette=palette,dither=Image.Dither.NONE))
    durations=[max(10,round((times[i+1]-times[i])/10)*10) for i in range(len(times)-1)]+[50]
    frames[0].save(output,save_all=True,append_images=frames[1:],duration=durations,loop=0,optimize=True,disposal=1)
    with Image.open(output) as result:
        if result.n_frames<60 or result.size!=(960,540): raise ValueError('Invalid GIF output')
        print(f'{output}: {result.n_frames} frames, {output.stat().st_size/1024/1024:.2f} MiB')

if __name__=='__main__':
    parser=argparse.ArgumentParser(description='Encode native --readme-media captures; requires Pillow.')
    parser.add_argument('--input',type=Path,default=Path('artifacts/readme-media'))
    parser.add_argument('--output',type=Path,default=Path('docs/media'))
    args=parser.parse_args(); args.output.mkdir(parents=True,exist_ok=True)
    for name in ['gameplay','library']: encode(args.input/name,args.output/(name+'.gif'),compact=name=='library')
    for source,target in [('menu-0','settings'),('menu-3','bindings'),('menu-4','display'),('pause','pause')]:
        with Image.open(args.input/(source+'.bmp')) as frame:
            frame.convert('RGB').save(args.output/(target+'.png'),optimize=True)
        print(args.output/(target+'.png'))
