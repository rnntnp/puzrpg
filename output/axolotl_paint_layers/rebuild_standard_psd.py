from pathlib import Path
import sys, json
ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / '_verify_lib'))
from PIL import Image, ImageCms
import numpy as np
from psd_tools import PSDImage
from psd_tools.api.layers import PixelLayer
from psd_tools.constants import Resource, Compression
from psd_tools.psd.image_resources import ImageResource

entries = [
    ('Base Color', '03_base_colors_v2.png'),
    ('Shading', '02_shading_v2.png'),
    ('Line Art', '01_line_art_v2.png'),
]
images = [Image.open(ROOT / filename).convert('RGBA') for _, filename in entries]
doc = PSDImage.new('RGBA', images[0].size, color=(0, 0, 0, 0), depth=8)
profile = ImageCms.ImageCmsProfile(ImageCms.createProfile('sRGB')).tobytes()
doc.image_resources[Resource.ICC_PROFILE] = ImageResource(key=Resource.ICC_PROFILE, data=profile)
for (name, _), im in zip(entries, images):
    layer = PixelLayer.frompil(im, doc, name=name, compression=Compression.RLE)
    layer.opacity = 255
    layer.visible = True
doc._merged_alpha = True
doc._record.layer_and_mask_information.layer_info.layer_count = -len(images)
doc.save(ROOT / 'axolotl_verified_v3.psd')

# Read the saved file, export actual layer pixels, reload these PNGs, composite.
loaded = PSDImage.open(ROOT / 'axolotl_verified_v3.psd')
export_dir = ROOT / 'verified_exports'
export_dir.mkdir(exist_ok=True)
composite = Image.new('RGBA', doc.size, (0,0,0,0))
report = {'layers': []}
for i, (layer, expected) in enumerate(zip(loaded, images)):
    actual = layer.topil().convert('RGBA')
    actual.save(export_dir / f'{i+1}_{layer.name.replace(" ", "_")}.png', icc_profile=profile)
    roundtrip = Image.open(export_dir / f'{i+1}_{layer.name.replace(" ", "_")}.png').convert('RGBA')
    composite = Image.alpha_composite(composite, roundtrip)
    a = np.asarray(actual)
    assert np.array_equal(a, np.asarray(expected)), layer.name
    report['layers'].append({'name':layer.name,'pixel_roundtrip_exact':True,'alpha_range':[int(a[:,:,3].min()),int(a[:,:,3].max())], 'channel_ids':[int(c.id) for c in layer._record.channel_info], 'has_mask':layer.has_mask()})
composite.save(ROOT / 'verified_psd_export.png', icc_profile=profile)
loaded.composite(force=True).save(ROOT / 'verified_library_export.png', icc_profile=profile)

original = Image.open('C:/Users/jaynap/AppData/Local/Temp/codex-clipboard-80e43b8e-b538-415a-b0d7-5aa1769aef42.png').convert('RGBA')
a=np.asarray(composite); b=np.asarray(original)
foreground=a[:,:,3]>0
diff=np.abs(a[:,:,:3].astype(np.int16)-b[:,:,:3].astype(np.int16))
report['comparison']={'character_pixels':int(foreground.sum()), 'max_channel_difference':int(diff[foreground].max()), 'mean_channel_difference':float(diff[foreground].mean()),'pixels_with_difference_over_1':int(np.any(diff>1,axis=2)[foreground].sum())}
assert report['comparison']['max_channel_difference'] <= 1

# White-backed line preview and a source/PSD export comparison for visual QA.
white=Image.new('RGBA',doc.size,'white')
Image.alpha_composite(white, images[-1]).convert('RGB').save(ROOT/'verified_line_on_white.png')
left=original.convert('RGB')
right=Image.alpha_composite(white,composite).convert('RGB')
comparison=Image.new('RGB',(doc.width*2,doc.height),'white')
comparison.paste(left,(0,0));comparison.paste(right,(doc.width,0))
comparison.save(ROOT/'verified_source_vs_export.png')
report['size']=list(doc.size)
(ROOT/'verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(report,ensure_ascii=True))
