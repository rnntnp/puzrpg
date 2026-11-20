"""Cut the supplied drawing without generation; render the same rigid rig used by Godot."""
from pathlib import Path
import argparse
import json
import math
import shutil
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageChops, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/characters/axolotl_cutout'
W, H = 1086, 1448


def build(source):
    OUT.mkdir(parents=True, exist_ok=True)
    for folder in ('parts', 'rig_parts', 'preview'):
        (OUT / folder).mkdir(exist_ok=True)
    shutil.copyfile(source, OUT / 'source.png')
    original = Image.open(source).convert('RGBA')
    assert original.size == (W, H), original.size
    # Each outline is a selection mask, never a newly drawn character pixel.
    specs = [
        ('head', (529, 609), 'root', [(435,236),(460,229),(559,229),(615,246),(651,272),(682,302),(717,346),(739,400),(748,448),(735,492),(697,536),(578,581),(589,602),(551,602),(543,649),(501,610),(461,612),(455,594),(385,589),(313,568),(265,525),(249,483),(255,430),(284,367),(315,324),(365,281)]),
        ('gill_l_top', (352, 291), 'head', [(280,94),(390,94),(439,238),(366,282),(340,298),(292,247)]),
        ('gill_l_mid', (292, 360), 'head', [(172,208),(245,205),(292,259),(333,303),(316,326),(288,372),(236,365),(193,320)]),
        ('gill_l_low', (256, 452), 'head', [(141,350),(195,348),(245,369),(286,380),(256,434),(251,478),(190,461),(152,418)]),
        ('gill_r_top', (620, 272), 'head', [(558,231),(586,183),(606,102),(660,101),(690,145),(708,192),(690,239),(653,278)]),
        ('gill_r_mid', (701, 344), 'head', [(665,284),(712,227),(742,195),(791,195),(817,228),(815,276),(788,318),(750,344),(718,352)]),
        ('gill_r_low', (741, 427), 'head', [(720,364),(773,351),(825,334),(850,352),(852,389),(826,429),(788,451),(742,459)]),
        ('tail', (415, 842), 'root', [(403,777),(432,821),(411,890),(404,985),(351,1013),(235,1034),(113,1026),(43,988),(43,951),(86,887),(156,834),(239,803),(332,804),(378,789)]),
        ('arm_front', (470, 638), 'root', [(450,605),(501,609),(515,672),(513,698),(535,856),(509,851),(519,881),(510,911),(486,912),(466,927),(443,912),(423,916),(410,893),(414,859),(425,838),(376,828),(400,758),(436,675)]),
        ('staff_arm', (599, 647), 'root', [(592,605),(619,647),(661,694),(701,720),(730,715),(753,689),(770,661),(784,625),(813,596),(826,574),(828,547),(833,532),(829,508),(843,480),(867,474),(866,461),(900,441),(947,442),(978,463),(988,492),(984,531),(971,549),(967,574),(947,592),(901,593),(884,611),(853,623),(833,645),(810,677),(792,692),(781,724),(762,741),(769,761),(751,790),(733,804),(716,832),(697,820),(677,776),(644,727),(617,678)]),
        ('boot_l', (506, 984), 'root', [(466,979),(542,966),(551,1003),(551,1045),(568,1075),(554,1090),(490,1092),(475,1044)]),
        ('boot_r', (645, 966), 'root', [(605,963),(683,940),(699,1018),(720,1047),(715,1067),(653,1077),(636,1068),(616,1008)]),
    ]
    masks = {}
    occupied = Image.new('L', original.size)
    for name, pivot, parent, polygon in specs:
        m = Image.new('L', original.size)
        ImageDraw.Draw(m).polygon(polygon, fill=255)
        # No duplicate source pixels: every opaque pixel has exactly one owner.
        m = ImageChops.subtract(m, occupied)
        masks[name] = m
        occupied = ImageChops.lighter(occupied, m)
    # Give the torso only its anatomical region, then grow the part masks into
    # small unselected contour slivers. This keeps stray head/staff outlines
    # from remaining attached to the torso when the rig moves.
    body_region = Image.new('L', original.size)
    ImageDraw.Draw(body_region).polygon([(455,600),(595,600),(621,677),
        (669,776),(727,864),(762,942),(687,973),(555,989),(409,1021),
        (392,1007),(411,850),(382,827)], fill=255)
    masks['body'] = ImageChops.subtract(body_region, occupied)
    occupied = ImageChops.lighter(occupied, masks['body'])
    for _ in range(12):
        for name in masks:
            extension = ImageChops.subtract(masks[name].filter(ImageFilter.MaxFilter(5)), occupied)
            masks[name] = ImageChops.lighter(masks[name], extension)
            occupied = ImageChops.lighter(occupied, extension)
    remaining = ImageChops.multiply(ImageChops.invert(occupied), original.getchannel('A'))
    assert remaining.getbbox() is None, 'Unassigned source pixels'
    specs.append(('body', (543, 813), 'root', []))
    # Keep the connected anatomical piece, reassign disconnected contour slivers
    # to the nearest intact piece. These are original pixels, not paint fills.
    seeds = {'head': (500,400), 'body': (580,800), 'tail': (220,900),
             'arm_front': (465,780), 'staff_arm': (910,500),
             'boot_l': (512,1040), 'boot_r': (660,1020),
             'gill_l_top': (350,210), 'gill_l_mid': (240,280),
             'gill_l_low': (200,410), 'gill_r_top': (650,190),
             'gill_r_mid': (760,270), 'gill_r_low': (790,400)}
    alpha = np.asarray(original.getchannel('A'))
    rgb = np.asarray(original)
    labels = np.zeros((H,W), dtype=np.uint8)
    names = list(masks)
    for index, name in enumerate(names, 1):
        binary = (np.asarray(masks[name]) > 0) & (alpha > 0)
        if name.startswith('boot'):
            binary &= (rgb[:,:,0] < 95) & (rgb[:,:,1] < 95)
        component = Image.fromarray(binary.astype('uint8') * 255).copy()
        ImageDraw.floodfill(component, seeds[name], 128)
        labels[np.asarray(component) == 128] = index
    for _ in range(100):
        if not np.any((labels == 0) & (alpha > 0)):
            break
        grown = labels.copy()
        for axis, shift in ((0,1),(0,-1),(1,1),(1,-1)):
            near = np.roll(labels, shift, axis)
            take = (grown == 0) & (near > 0)
            grown[take] = near[take]
        labels = grown
    missing_y, missing_x = np.where((labels == 0) & (alpha > 0))
    if len(missing_x):
        # Preserve even far-away, faint source marks by assigning the nearest
        # anatomical pivot, without adding or dropping a source pixel.
        seed_points = np.array([seeds[name] for name in names])
        for x,y in zip(missing_x, missing_y):
            labels[y,x] = int(np.argmin(((seed_points - [x,y])**2).sum(axis=1))) + 1
    masks = {name: Image.fromarray((labels == i).astype('uint8') * 255)
             for i,name in enumerate(names,1)}
    z_order = ['tail', 'boot_l', 'boot_r', 'body', 'staff_arm', 'arm_front',
               'gill_l_top', 'gill_l_mid', 'gill_l_low',
               'gill_r_top', 'gill_r_mid', 'gill_r_low', 'head']
    rig = {'canvas': [W, H], 'root': [543, 1065], 'period': 3.2, 'parts': []}
    layers = {}
    for name, pivot, parent, _ in specs:
        layer = original.copy()
        layer.putalpha(ImageChops.multiply(original.getchannel('A'), masks[name]))
        bounds = layer.getbbox()
        assert bounds, name
        cropped = layer.crop(bounds)
        cropped.save(OUT / 'parts' / (name + '.png'))
        layers[name] = layer
        rig['parts'].append({'name': name, 'parent': parent, 'pivot': list(pivot),
                             'bounds': list(bounds), 'z': z_order.index(name)})
    (OUT / 'rig.json').write_text(json.dumps(rig, indent=2), encoding='utf-8')
    reconstructed = Image.new('RGBA', original.size)
    for name in z_order:
        reconstructed.alpha_composite(layers[name])
    # Alpha-compositing disjoint masks must preserve every original pixel exactly.
    assert reconstructed.tobytes() == original.tobytes(), 'Neutral reconstruction differs'
    reconstructed.save(OUT / 'preview' / 'assembled.png')
    sheet = Image.new('RGB', (1200, 1000), '#e6e8ee')
    d = ImageDraw.Draw(sheet)
    for i, part in enumerate(rig['parts']):
        x, y = (i % 4) * 300, (i // 4) * 250
        p = Image.open(OUT / 'parts' / (part['name'] + '.png'))
        p.thumbnail((270, 215), Image.Resampling.LANCZOS)
        sheet.paste(p, (x + (300-p.width)//2, y+24+(215-p.height)//2), p)
        d.text((x+12,y+8), part['name'], fill='#17202b')
    sheet.save(OUT / 'preview' / 'parts_sheet.png')
    # A small overlap made ONLY from neighboring original pixels conceals the
    # cut seams; isolated PNGs and neutral reconstruction remain disjoint.
    animated_layers = {}
    for name in layers:
        overlap = masks[name].filter(ImageFilter.MaxFilter(9))
        layer = original.copy()
        layer.putalpha(ImageChops.multiply(original.getchannel('A'), overlap))
        animated_layers[name] = layer
        bounds = layer.getbbox()
        layer.crop(bounds).save(OUT / 'rig_parts' / (name + '.png'))
        next(p for p in rig['parts'] if p['name'] == name)['render_bounds'] = list(bounds)
    (OUT / 'rig.json').write_text(json.dumps(rig, indent=2), encoding='utf-8')
    frames = [render(rig, animated_layers, i / 64) for i in range(64)]
    frames[0].save(OUT / 'preview' / 'idle.gif', save_all=True, append_images=frames[1:],
                   duration=50, loop=0, disposal=2, optimize=False)
    contact = Image.new('RGB', (1600, 700), '#e6e8ee')
    for j, i in enumerate((0,16,32,48)):
        frame = frames[i].copy()
        frame.thumbnail((400,650))
        contact.paste(frame, (j*400,30))
        ImageDraw.Draw(contact).text((j*400+16,12), f'{i*0.05:.2f}s', fill='#17202b')
    contact.save(OUT / 'preview' / 'motion_check.png')
    gif = Image.open(OUT / 'preview' / 'idle.gif')
    assert gif.n_frames == 64 and gif.info['loop'] == 0
    report = {'source_size': [W,H], 'part_count': len(specs),
              'neutral_reconstruction_pixel_exact': True, 'gif_frames': gif.n_frames,
              'gif_duration_ms': 3200, 'gif_loop': 0,
              'generated_character_pixels': 0}
    (OUT / 'preview' / 'validation.json').write_text(json.dumps(report, indent=2))
    print(json.dumps(report))


def motion(name, phase):
    s = math.sin(phase)
    if name == 'head': return 1.1*s
    if name.startswith('gill_'):
        delay = 0.0 if name.endswith('top') else (0.35 if name.endswith('mid') else 0.7)
        return 12.0*math.sin(phase+0.7-delay) * (-1 if '_l_' in name else 1)
    if name == 'tail': return 2.1*math.sin(phase-0.6)
    if name == 'arm_front': return 0.9*math.sin(phase+0.3)
    if name == 'staff_arm': return 0.8*math.sin(phase-0.4)
    return 0.0


def render(rig, layers, t):
    phase = t * math.tau
    bob = -3*(1-math.cos(phase))
    canvas = Image.new('RGBA', (W,H), '#e6e8ee')
    head_pivot = next(p['pivot'] for p in rig['parts'] if p['name']=='head')
    for p in sorted(rig['parts'], key=lambda p:p['z']):
        layer = layers[p['name']]
        layer = layer.rotate(motion(p['name'], phase), Image.Resampling.BICUBIC, center=p['pivot'])
        if p['parent'] == 'head':
            layer = layer.rotate(motion('head',phase), Image.Resampling.BICUBIC, center=head_pivot)
        dy = 0 if p['name'].startswith('boot') else bob
        canvas.alpha_composite(layer, (0,round(dy)))
    return canvas.resize((543,724),Image.Resampling.LANCZOS).convert('RGB')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path)
    build(parser.parse_args().source)
