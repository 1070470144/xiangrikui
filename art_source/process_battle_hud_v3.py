"""Derive runtime artwork from manifest, preserving raw source and alpha geometry."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageEnhance, ImageOps

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "art_source/manifests/battle_hud_v3.json"

def project_path(path):
    return ROOT / path.removeprefix("res://")

def fitted_source(asset):
    source = project_path(asset["output"]["path"])
    raw = source.with_name(source.name + ".raw.png")
    selected = raw if raw.exists() else source
    image = Image.open(selected).convert("RGBA")
    alpha = image.getchannel("A")
    if alpha.getextrema()[0] == 255:
        raise ValueError(f"{asset['id']}: opaque background must not publish")
    bbox = alpha.point(lambda p: 255 if p >= 12 else 0).getbbox()
    if not bbox:
        raise ValueError("Empty generated asset")
    cropped = image.crop(bbox)
    target = tuple(asset["runtime"]["size"])
    # Trim transparent source padding, then uniformly fit: never squeeze a square.
    if asset["kind"] == "button":
        # Uniformly scale corners, stretch only the quiet middle and straight rims.
        sx=min(220,cropped.width//3); sy=min(180,cropped.height//3)
        scale=min((target[0]-8)*0.18/sx,(target[1]-8)*0.18/sy)
        dx=round(sx*scale); dy=round(sy*scale)
        fitted=Image.new("RGBA",(target[0]-8,target[1]-8),(0,0,0,0))
        xs=[0,sx,cropped.width-sx,cropped.width]; ys=[0,sy,cropped.height-sy,cropped.height]
        xd=[0,dx,fitted.width-dx,fitted.width]; yd=[0,dy,fitted.height-dy,fitted.height]
        for row in range(3):
            for col in range(3):
                tile=cropped.crop((xs[col],ys[row],xs[col+1],ys[row+1]))
                tile=tile.resize((xd[col+1]-xd[col],yd[row+1]-yd[row]),Image.Resampling.LANCZOS)
                fitted.alpha_composite(tile,(xd[col],yd[row]))
    else:
        fitted = ImageOps.contain(cropped, (target[0]-8, target[1]-8), Image.Resampling.LANCZOS)
    result = Image.new("RGBA", target, (0,0,0,0))
    result.alpha_composite(fitted, ((target[0]-fitted.width)//2, (target[1]-fitted.height)//2))
    return result, {"source":str(selected.relative_to(ROOT)),"source_size":list(image.size),"alpha_bbox":list(bbox),"fitted_size":list(fitted.size),"runtime_size":list(target),"scale_method":"alpha bbox; button corners uniformly scale to <=18% edge span with quiet-center nine-slice expansion, bezel uniform contain; source immutable"}

def tint(image, brightness, saturation):
    rgb = ImageEnhance.Color(image.convert("RGB")).enhance(saturation)
    rgb = ImageEnhance.Brightness(rgb).enhance(brightness).convert("RGBA")
    rgb.putalpha(image.getchannel("A"))
    return rgb

def derive():
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    images, records = {}, []
    for asset in manifest["assets"]:
        if not asset["generation"]["enabled"]:
            continue
        master, record = fitted_source(asset)
        runtime = asset["runtime"]
        if "path_pattern" in runtime:
            states={"normal":master,"hover":tint(master,1.10,1.02),"pressed":tint(master,0.82,0.90),"disabled":tint(master,0.57,0.25)}
            hashes=[]
            for state in asset["states"]:
                derived=states[state]
                hashes.append(hashlib.sha256(derived.getchannel("A").tobytes()).hexdigest())
                images[project_path(runtime["path_pattern"].replace("{state}",state))]=derived
            if len(set(hashes)) != 1: raise ValueError("State alpha geometry differs")
            record["states_alpha_sha256"]=hashes[0]
        else:
            images[project_path(runtime["path"])]=master
            # Opening remains transparent so live radar is the sole content.
            record["center_alpha"]=master.getpixel((master.width//2,master.height//2))[3]
            if record["center_alpha"]>32: raise ValueError("Tactical bezel center obstructs radar")
        records.append({"asset_id":asset["id"],**record})
    return images,records

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--check",action="store_true")
    args=parser.parse_args()
    images,records=derive()
    for path,image in images.items():
        if args.check:
            if not path.exists() or Image.open(path).convert("RGBA").tobytes()!=image.tobytes(): raise ValueError(f"Stale derivative: {path}")
        else:
            path.parent.mkdir(parents=True,exist_ok=True)
            image.save(path,optimize=True)
    if not args.check:
        report=ROOT/"art_source/generated/mm_tools/battle_hud_v3/derivation_report.json"
        report.write_text(json.dumps({"manifest":"res://art_source/manifests/battle_hud_v3.json","derivatives":records},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("BATTLE HUD V3 DERIVATIVES VERIFIED" if args.check else "BATTLE HUD V3 DERIVATIVES WRITTEN")

if __name__=="__main__":main()
