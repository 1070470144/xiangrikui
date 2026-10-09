"""Resume canonical Sprite-gen extraction independently for completed repair videos."""
import concurrent.futures
from pathlib import Path
from root_boss_redesign import OUT, engine

def process(folder):
    if not (folder/'clip.mp4').exists() or (folder/'frames/frames.report.json').exists(): return
    try:
        engine('video-frames','--clip',folder/'clip.mp4','--out-dir',folder/'frames','--key','green')
        print(folder.name,'transparent frames ready',flush=True)
    except RuntimeError as exc:
        (folder/'processing-error.txt').write_text(str(exc),encoding='utf-8')
        print(folder.name,'extraction failed',flush=True)

if __name__=='__main__':
    jobs=list(OUT.glob('*-v5'))+list(OUT.glob('*-v4'))+list(OUT.glob('*-v3'))+[OUT/'enraged_fx']
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool: list(pool.map(process,jobs))
