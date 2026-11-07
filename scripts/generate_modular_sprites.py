#!/usr/bin/env python3
"""Original pixel drawings for the modular NPC kit (not edits of uploaded art).

Every PNG uses the same 48x64 cell, 5 columns and 8 rows as the legacy reader.
Red stores a palette index, alpha stores coverage; colors live in AppearanceData.
Pillow is needed only to regenerate this source art, never to run the game.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets' / 'modular_npcs'
CELL = (48, 64)
OPTIONS = {
    'body': ['regular', 'round', 'angular'],
    'hair': ['cropped', 'wavy', 'long', 'braid', 'bun', 'beard', 'bald'],
    'clothing': ['tunic', 'workshirt', 'dress', 'vest', 'coat', 'robe', 'armor', 'finery'],
    'accessory': ['none', 'pouch', 'apron', 'scarf', 'satchel', 'medallion', 'pauldron', 'toolbelt'],
    'hat': ['none', 'cap', 'straw', 'hood', 'helmet', 'crested_helmet', 'crown', 'tiara', 'beret', 'headscarf'],
}


def ink(index):
    return (index, 0, 0, 255)


def pose(layer, kind, direction, column, running):
    im = Image.new('RGBA', CELL)
    # The left side is the exact mirror of the right side, including props.
    if direction == 'left':
        return pose(layer, kind, 'right', column, running).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    d = ImageDraw.Draw(im)
    side = direction == 'right'
    back = direction == 'up'
    step = [0, -3, -1, 3, 1][column] * (1.4 if running else 1)
    step = round(step)
    bob = -1 if column in (2, 4) else 0
    hx, hy = (25 if side else 24), 17 + bob
    shoulder, waist = 31 + bob, 45 + bob

    def box(xy, color):
        d.rectangle(tuple(round(v) for v in xy), fill=ink(color))

    def poly(xy, color, outline=None):
        points = [(round(x), round(y)) for x, y in xy]
        d.polygon(points, fill=ink(color))
        if outline:
            d.line(points + [points[0]], fill=ink(outline), width=1)

    def oval(xy, color, outline=None):
        d.ellipse(tuple(round(v) for v in xy), fill=ink(color), outline=ink(outline) if outline else None)

    def line(xy, color, width=1):
        d.line([(round(x), round(y)) for x, y in xy], fill=ink(color), width=width)

    if layer == 'body':
        # Two planted contacts, alternating lifted trailing feet. Soles stay at 60.
        for x, gait in [(18 if not side else 21, step), (28 if not side else 27, -step)]:
            dx = gait if side else round(gait * .45)
            lift = max(0, -gait)
            poly([(x-3, 44), (x+4, 44), (x+4+dx, 56-lift), (x-3+dx, 56-lift)], 14, 1)
            box((x-3+dx, 55-lift, x+5+dx, 60-lift), 1)
            box((x-2+dx, 55-lift, x+4+dx, 58-lift), 15)
            box((x-2+dx, 55-lift, x+1+dx, 56-lift), 16)
        poly([(16, shoulder-2), (31, shoulder-2), (33, 46), (14, 46)], 2, 1)
        box((21, 25+bob, 27, 32+bob), 2)
        box((23, 26+bob, 27, 30+bob), 3)
        for x, gait in [(13, -step), (34, step)]:
            swing = round(gait*.6) if side else 0
            oval((x-3+swing, 34+bob, x+3+swing, 46+bob-abs(gait)//2), 2, 1)
            oval((x-2+swing, 40+bob-abs(gait)//2, x+3+swing, 46+bob-abs(gait)//2), 3, 1)
            box((x-1+swing, 41+bob-abs(gait)//2, x+1+swing, 42+bob-abs(gait)//2), 4)
        width = {'round': 11, 'regular': 10, 'angular': 9}[kind]
        oval((hx-width, hy-11, hx+width, hy+12), 2, 1)
        oval((hx-width+2, hy-9, hx+width-1, hy+8), 3)
        oval((hx-width+3, hy-9, hx+width-3, hy-1), 4)
        oval((hx-width-2, hy+1, hx-width+2, hy+6), 3, 1)
        if not side:
            oval((hx+width-2, hy+1, hx+width+2, hy+6), 3, 1)
        if not back:
            if side:
                box((hx+5, hy-1, hx+7, hy+3), 1)
                box((hx+6, hy-1, hx+7, hy), 20)
                poly([(hx+width-1,hy+2), (hx+width+2,hy+5), (hx+width-1,hy+6)], 3, 1)
                line([(hx+4, hy+8), (hx+7, hy+8)], 2)
            else:
                for x in [hx-5, hx+4]:
                    box((x-1, hy, x+1, hy+4), 1)
                    box((x, hy, x+1, hy+1), 20)
                box((hx, hy+5, hx+1, hy+6), 2)
                line([(hx-2, hy+9), (hx+2, hy+9)], 2)
                box((hx-8, hy+6, hx-6, hy+7), 24)
                box((hx+6, hy+6, hx+8, hy+7), 24)
            if kind == 'angular':
                line([(hx-5,hy-3), (hx-2,hy-2)], 2)
                if not side:line([(hx+3,hy-2), (hx+6,hy-3)], 2)
            if kind == 'round':
                for x,y in [(hx-6,hy+4),(hx-4,hy+5),(hx+6,hy+5)]:box((x,y,x,y),2)
    elif layer == 'clothing':
        long = kind in ['robe', 'dress', 'finery', 'coat']
        bottom = 53+bob if long else 47+bob
        width = 11 if long else 9
        poly([(16, shoulder-2), (31, shoulder-2), (24+width, bottom), (24-width, bottom)], 8, 1)
        poly([(17, shoulder), (24, shoulder+2), (23, bottom-2), (15, bottom-2)], 9)
        poly([(24, shoulder+2), (30, shoulder), (31, bottom-2), (24, bottom-2)], 10)
        line([(16,bottom-1),(31,bottom-1)], 11)
        # Shoulders and sleeves leave the animated hands exposed.
        for x,gait in [(13,-step),(34,step)]:
            swing = round(gait*.6) if side else 0
            poly([(x-3+swing,shoulder+1),(x+3+swing,shoulder+2),(x+3+swing,39+bob-abs(gait)//2),(x-2+swing,39+bob-abs(gait)//2)], 9 if x<24 else 8,1)
            line([(x-2+swing,38+bob-abs(gait)//2),(x+2+swing,38+bob-abs(gait)//2)], 10)
        if not back:
            poly([(19,shoulder-1),(24,shoulder+5),(29,shoulder-1),(24,shoulder+1)], 11,1)
            line([(24,shoulder+6),(24,bottom-4)], 8)
        if kind in ['workshirt','tunic','vest']:
            box((15,43+bob,33,45+bob),14)
            box((24,43+bob,27,46+bob),12)
            box((25,44+bob,26,45+bob),1)
        if kind == 'workshirt':
            box((16,34+bob,18,39+bob),10)
            line([(28,34+bob),(29,40+bob)],8)
        if kind == 'vest':
            poly([(18,shoulder),(22,shoulder+3),(21,43+bob),(17,43+bob)],14,1)
            poly([(28,shoulder),(25,shoulder+3),(27,43+bob),(31,43+bob)],15,1)
        if kind in ['robe','dress']:
            for x in [17,22,28,32]:line([(24+(x-24)*.5,46+bob),(x,bottom-2)],8)
            line([(14,bottom-2),(34,bottom-2)],12)
        if kind == 'coat':
            line([(18,shoulder),(21,bottom-2)],14,2)
            line([(28,shoulder),(27,bottom-2)],14,2)
            for y in [36,41,46]:box((25,y+bob,26,y+1+bob),12)
        if kind == 'armor':
            poly([(17,shoulder),(30,shoulder),(31,42+bob),(25,46+bob),(17,42+bob)],17,1)
            poly([(18,shoulder+1),(23,shoulder+3),(23,43+bob),(18,40+bob)],18)
            poly([(24,shoulder+3),(29,shoulder+1),(29,40+bob),(24,43+bob)],19)
            line([(18,35+bob),(29,35+bob)],17)
            line([(17,42+bob),(30,42+bob)],1)
            box((22,33+bob,25,40+bob),12)
            box((20,35+bob,27,37+bob),12)
        if kind == 'finery':
            poly([(16,shoulder),(20,shoulder+2),(19,bottom),(13,bottom)],11,1)
            poly([(31,shoulder),(27,shoulder+2),(29,bottom),(35,bottom)],12,1)
            line([(15,bottom-2),(33,bottom-2)],13,2)
            for x in [16,21,27,32]:
                poly([(x,bottom-7),(x+2,bottom-5),(x,bottom-3),(x-2,bottom-5)],13)
            oval((22,shoulder+2,26,shoulder+6),13,1)
    elif layer == 'hair':
        if kind == 'bald':
            if back:line([(hx-8,hy+3),(hx-6,hy+8),(hx+6,hy+8),(hx+8,hy+3)],5,2)
        else:
            oval((hx-11,hy-13,hx+10,hy+2 if not back else hy+10),5,1)
            oval((hx-9,hy-12,hx+8,hy-3),6)
            line([(hx-7,hy-9),(hx-3,hy-11),(hx+3,hy-10)],7,2)
            if not back:
                poly([(hx-10,hy-3),(hx-4,hy-7),(hx+7,hy-6),(hx+9,hy-2),(hx+5,hy-2),(hx+2,hy-4),(hx-5,hy-1)],6,1)
            if kind in ['long','braid','bun','wavy']:
                for x in ([hx-10] if side else [hx-10,hx+8]):
                    poly([(x,hy-3),(x+3,hy-1),(x+4,hy+12),(x+1,hy+17),(x-2,hy+10)],5,1)
                    line([(x+1,hy+1),(x+2,hy+11),(x,hy+14)],6,2)
            if back and kind in ['long','wavy']:
                poly([(hx-9,hy),(hx+9,hy),(hx+11,hy+19),(hx+5,hy+21),(hx+1,hy+18),(hx-6,hy+21),(hx-11,hy+17)],5,1)
                for x in [hx-6,hx,hx+6]:line([(x,hy+2),(x+1,hy+15),(x-1,hy+18)],6,2)
            if kind == 'braid':
                x=hx if back else (hx-8 if not side else hx-9)
                for y in range(hy+7,hy+23,3):
                    oval((x-2,y,x+3,y+5),6 if y%2 else 5,1)
                box((x-2,hy+23,x+3,hy+24),12)
            if kind == 'bun':
                oval((hx-5 if back else hx-13,hy-11,hx+5 if back else hx-3,hy),5,1)
                oval((hx-4 if back else hx-12,hy-10,hx+2 if back else hx-6,hy-4),7)
            if kind == 'wavy':
                for x in range(hx-10,hx+9,5):oval((x,hy-12,x+5,hy-6),6,1)
            if kind == 'beard' and not back:
                poly([(hx-8,hy+6),(hx-5,hy+10),(hx+5,hy+10),(hx+8,hy+6),(hx+7,hy+17),(hx,hy+21),(hx-7,hy+17)],5,1)
                poly([(hx-5,hy+11),(hx+4,hy+11),(hx+2,hy+18),(hx-2,hy+19)],6)
                line([(hx-5,hy+9),(hx,hy+8),(hx+5,hy+9)],7)
    elif layer == 'accessory':
        if kind == 'pouch':
            oval((28,43+bob,36,51+bob),14,1);box((29,43+bob,34,45+bob),16);box((32,46+bob,33,47+bob),12)
        if kind == 'apron':
            poly([(19,33+bob),(28,33+bob),(31,51+bob),(16,51+bob)],14,1)
            poly([(20,34+bob),(26,34+bob),(28,49+bob),(18,49+bob)],15)
            box((20,42+bob,27,46+bob),14);line([(20,42+bob),(27,42+bob)],16)
        if kind == 'scarf':
            poly([(16,29+bob),(24,31+bob),(32,29+bob),(30,34+bob),(24,35+bob),(17,33+bob)],11,1)
            line([(18,31+bob),(24,33+bob),(30,31+bob)],13)
            poly([(18,33+bob),(22,34+bob),(20-step//2,43+bob),(17-step//2,41+bob)],12,1)
        if kind == 'satchel':
            line([(16,30+bob),(30,46+bob)],1,3);line([(17,30+bob),(31,46+bob)],16)
            box((28,42+bob,37,52+bob),1);box((29,43+bob,36,51+bob),15);box((29,43+bob,36,46+bob),16);box((32,46+bob,33,48+bob),12)
        if kind == 'medallion':
            line([(18,30+bob),(24,39+bob),(30,30+bob)],13)
            oval((21,37+bob,27,43+bob),11,1);oval((23,38+bob,25,41+bob),13)
        if kind == 'pauldron':
            for x in [12,30]:
                oval((x-2,29+bob,x+6,35+bob),17,1);line([(x,30+bob),(x+4,30+bob)],19)
        if kind == 'toolbelt':
            box((14,43+bob,34,46+bob),14)
            line([(31,43+bob),(33,53+bob)],16,2)
            box((29,42+bob,35,45+bob),17);box((30,42+bob,34,43+bob),19)
            box((16,46+bob,21,51+bob),15)
    elif layer == 'hat':
        if kind == 'cap':
            oval((hx-11,hy-15,hx+10,hy-3),8,1)
            poly([(hx-10,hy-5),(hx+10,hy-5),(hx+12,hy-1),(hx-11,hy-2)],9,1)
            line([(hx-7,hy-11),(hx-2,hy-13),(hx+4,hy-12)],10)
        if kind == 'beret':
            oval((hx-13,hy-15,hx+12,hy-5),8,1)
            oval((hx-10,hy-14,hx+7,hy-8),9)
            box((hx-9,hy-7,hx+9,hy-5),14);box((hx+4,hy-16,hx+5,hy-14),1)
        if kind == 'straw':
            poly([(hx-9,hy-7),(hx-7,hy-16),(hx+5,hy-16),(hx+10,hy-6)],15,1)
            poly([(hx-15,hy-6),(hx-11,hy-9),(hx+12,hy-9),(hx+16,hy-5),(hx+11,hy-2),(hx-12,hy-2)],16,1)
            line([(hx-7,hy-9),(hx+8,hy-9)],12,2)
            for x in range(hx-9,hx+9,4):line([(x,hy-14),(x+1,hy-10)],14)
        if kind in ['hood','headscarf']:
            oval((hx-13,hy-16,hx+12,hy+10),8,1)
            if not back:
                # Transparent face opening, revealing the body and chosen hair.
                d.ellipse((hx-8,hy-5,hx+8,hy+9),fill=(0,0,0,0))
                line([(hx-8,hy-5),(hx-10,hy+4),(hx-8,hy+10)],10,2)
                line([(hx+8,hy-5),(hx+10,hy+4),(hx+8,hy+10)],9,2)
            if kind=='headscarf':
                line([(hx-9,hy-6),(hx+9,hy-6)],12,2)
                poly([(hx+9,hy+6),(hx+15,hy+12),(hx+9,hy+16)],9,1)
        if kind in ['helmet','crested_helmet']:
            oval((hx-12,hy-15,hx+11,hy+2),17,1)
            poly([(hx-10,hy-9),(hx-6,hy-13),(hx-1,hy-14),(hx-1,hy-2),(hx-10,hy-2)],18)
            line([(hx,hy-14),(hx,hy-1)],19,2)
            box((hx-13,hy-3,hx+12,hy),1);box((hx-11,hy-3,hx+10,hy-2),19)
            if not back:
                for x in [hx-11,hx+8]:box((x,hy+1,x+3,hy+8),17)
            if kind=='crested_helmet':
                poly([(hx-4,hy-16),(hx+5,hy-18),(hx+9,hy-13),(hx+4,hy-10),(hx+1,hy-15)],12,1)
        if kind == 'crown':
            poly([(hx-11,hy-3),(hx-12,hy-12),(hx-6,hy-8),(hx-1,hy-16),(hx+4,hy-8),(hx+10,hy-12),(hx+11,hy-3)],12,1)
            line([(hx-10,hy-4),(hx+9,hy-4)],13,2)
            poly([(hx-2,hy-8),(hx,hy-10),(hx+2,hy-8),(hx,hy-6)],10,1)
        if kind == 'tiara':
            line([(hx-10,hy-5),(hx-5,hy-8),(hx,hy-4),(hx+5,hy-8),(hx+10,hy-5)],13,2)
            oval((hx-2,hy-7,hx+2,hy-3),12,1)
    return im


def main():
    files=[]
    for layer,options in OPTIONS.items():
        directory=OUT/layer;directory.mkdir(parents=True,exist_ok=True)
        for kind in options:
            sheet=Image.new('RGBA',(CELL[0]*5,CELL[1]*8))
            for row in range(8):
                direction=['down','up','right','left'][row%4]
                for column in range(5):
                    frame=pose(layer,kind,direction,column,row>=4)
                    sheet.paste(frame,(column*CELL[0],row*CELL[1]))
            path=directory/(kind+'.png');sheet.save(path,optimize=True)
            files.append({'layer':layer,'option':kind,'path':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    (OUT/'manifest.json').write_text(json.dumps({'version':1,'cell':CELL,'columns':5,'rows':8,'sole_y':60,'encoding':'red=palette index 0..31, alpha=coverage','creator':'Original project pixel drawings; scripts/generate_modular_sprites.py','files':files},indent=2)+'\n')
    print(f'{len(files)} modular sheets generated')


if __name__=='__main__':
    main()
