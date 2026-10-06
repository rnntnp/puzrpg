from pathlib import Path
import sys, json
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'_tools'))
from PIL import Image,ImageFilter,ImageDraw,ImageFont,ImageCms
import numpy as np
from psd_tools import PSDImage
from psd_tools.api.layers import PixelLayer,Group
from psd_tools.constants import Compression,Resource,BlendMode
from psd_tools.psd.image_resources import ImageResource

SOURCE=Path('C:/Users/jaynap/Dropbox/axolotl_verified_v3.psd')
source=PSDImage.open(SOURCE)
size=source.size;w,h=size
source_flat=source.composite(force=True).convert('RGBA')
flat=np.asarray(source_flat)
regions=np.load(ROOT/'regions.npz')

def dilate(m,r):
    # Circular dilation, confined to the existing painted source.
    out=np.zeros_like(m,dtype=bool)
    for dy in range(-r,r+1):
        for dx in range(-r,r+1):
            if dx*dx+dy*dy>r*r:continue
            ya=max(0,dy);yb=min(h,h+dy);xa=max(0,dx);xb=min(w,w+dx)
            out[ya:yb,xa:xb]|=m[ya-dy:yb-dy,xa-dx:xb-dx]
    return out

head_guard=dilate(regions['head'].astype(bool),10)
yy,xx=np.mgrid[:h,:w]
robe=(flat[:,:,1].astype(int)>flat[:,:,0].astype(int)+35)&(flat[:,:,2].astype(int)>flat[:,:,0].astype(int)+35)&(yy>600)&(xx>350)&(xx<760)&(flat[:,:,3]>100)
robe_guard=dilate(robe,10)
names=['Gill_L_Upper','Gill_L_Middle','Gill_L_Lower','Gill_R_Upper','Gill_R_Middle','Gill_R_Lower','Tail_Root','Tail_Middle','Tail_Tip']
distances=[]
for name in names:
    region=regions[name].astype(bool)
    ry,rx=np.where(region)
    x0=max(0,int(rx.min())-16);x1=min(w,int(rx.max())+17)
    y0=max(0,int(ry.min())-16);y1=min(h,int(ry.max())+17)
    local=Image.fromarray(region[y0:y1,x0:x1].astype(np.uint8)*255)
    dist=np.full((h,w),255,np.uint8);patch=dist[y0:y1,x0:x1]
    for radius in range(17):
        patch[(np.asarray(local)>0)&(patch==255)]=radius
        local=local.filter(ImageFilter.MaxFilter(3))
    distances.append(dist)
nearest=np.argmin(np.stack(distances),axis=0)
minimum=np.min(np.stack(distances),axis=0)
masks={};claimed=np.zeros((h,w),bool)
for idx,name in enumerate(names):
    interior=regions[name].astype(bool)
    ring=dilate(interior,13)
    # Keep the original black outline, excluding the foreground head/robe line.
    other_interiors=np.zeros((h,w),bool)
    for other in names:
        if other!=name:other_interiors|=regions[other].astype(bool)
    mask=(nearest==idx)&(minimum<=16)&~other_interiors&(flat[:,:,3]>0)
    if name.startswith('Tail'):mask&=~regions['tail'].astype(bool)
    mask&=~(head_guard if name.startswith('Gill') else robe_guard)
    mask|=interior
    mask&=~claimed
    masks[name]=mask;claimed|=mask
masks['Body']=~claimed

visible=[l for l in source if l.visible]
assert [l.name for l in visible]==['Base Color','Shading','Line Art']
original_arrays=[np.array(l.topil().convert('RGBA')) for l in visible]
profile=source.image_resources.get_data(Resource.ICC_PROFILE)
if not profile:profile=ImageCms.ImageCmsProfile(ImageCms.createProfile('sRGB')).tobytes()
doc=PSDImage.new('RGBA',size,(0,0,0,0),depth=8)
doc.image_resources[Resource.ICC_PROFILE]=ImageResource(key=Resource.ICC_PROFILE,data=profile)

# Preserve the user's five original layers as an explicitly hidden backup.
backup=Group.new(doc,name='SOURCE_BACKUP_hidden',open_folder=False)
for layer in source:
    dest=PixelLayer.frompil(layer.topil().convert('RGBA'),backup,name=layer.name,compression=Compression.RLE)
    dest.visible=layer.visible
    dest.clipping=layer.clipping
backup.visible=False

order=['Gill_L_Lower','Gill_L_Middle','Gill_L_Upper','Gill_R_Lower','Gill_R_Middle','Gill_R_Upper','Body','Tail_Tip','Tail_Middle','Tail_Root']
pivots={'Gill_L_Upper':[353,283],'Gill_L_Middle':[296,355],'Gill_L_Lower':[264,430],'Gill_R_Upper':[677,288],'Gill_R_Middle':[726,363],'Gill_R_Lower':[741,426],'Tail_Tip':[154,953],'Tail_Middle':[258,904],'Tail_Root':[358,852],'Body':[543,700]}
export=ROOT/'parts_png';export.mkdir(exist_ok=True)
meta={'source':str(SOURCE),'canvas':[w,h],'coordinates':'pixels, top-left origin; L/R are screen left/right','parts':[],'note':'Visible artwork separated without redrawing. Hidden attachment artwork is not reconstructed. Pivot positions are initial suggestions, not a rig.'}
for name in order:
    mask=masks[name]
    occupied=mask&(flat[:,:,3]>0)
    ys,xs=np.where(occupied)
    box=(int(xs.min()),int(ys.min()),int(xs.max())+1,int(ys.max())+1)
    group=Group.new(doc,name=name,open_folder=False)
    group.blend_mode=BlendMode.NORMAL
    merged=Image.new('RGBA',size)
    for layer,original in zip(visible,original_arrays):
        pixels=original.copy();pixels[~mask]=0
        img=Image.fromarray(pixels)
        merged=Image.alpha_composite(merged,img)
        child=PixelLayer.frompil(img.crop(box),group,name=layer.name,top=box[1],left=box[0],compression=Compression.RLE)
        child.clipping=layer.clipping
    # Use full-canvas PNGs to keep every part in exactly the original coordinates.
    meta['parts'].append({'name':name,'file':'parts_png/'+name+'.png','bbox':list(box),'pivot':pivots[name],'draw_order':order.index(name)})

doc._merged_alpha=True
doc._record.layer_and_mask_information.layer_info.layer_count=-len(doc._record.layer_and_mask_information.layer_info.layer_records)
dest=ROOT/'axolotl_gills_tail_parts.psd'
doc.save(dest,encoding='utf-8')
(ROOT/'parts_manifest.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2),encoding='utf8')

# Validate the saved PSD, not just the pre-save arrays.
reopened=PSDImage.open(dest)
for group in reopened:
    if group.name in order:
        group.composite(viewport=(0,0,w,h),force=True).save(export/(group.name+'.png'),icc_profile=profile)
render=reopened.composite(force=True).convert('RGBA')
render.save(ROOT/'assembled_from_psd.png',icc_profile=profile)
actual=np.asarray(render);expected=np.asarray(source_flat)
solid=(expected[:,:,3]>0)|(actual[:,:,3]>0)
delta=np.abs(actual.astype(np.int16)-expected.astype(np.int16))
report={'groups':[g.name for g in reopened],'size':list(size),'alpha_max_error':int(delta[:,:,3].max()),'visible_rgb_max_error':int(delta[:,:,:3][solid].max()),'changed_alpha_pixels':int(np.count_nonzero(delta[:,:,3]))}
assert report['alpha_max_error']<=1,report
assert report['visible_rgb_max_error']<=2,report

# Separate check using the exported PNG parts only.
png_composite=Image.new('RGBA',size)
for name in order:png_composite=Image.alpha_composite(png_composite,Image.open(export/(name+'.png')).convert('RGBA'))
png_composite.save(ROOT/'assembled_from_pngs.png',icc_profile=profile)
pa=np.asarray(png_composite);pd=np.abs(pa.astype(np.int16)-expected.astype(np.int16))
report['png_alpha_max_error']=int(pd[:,:,3].max())
report['png_visible_rgb_max_error']=int(pd[:,:,:3][solid].max())
assert report['png_alpha_max_error']<=1 and report['png_visible_rgb_max_error']<=2,report
(ROOT/'verification.json').write_text(json.dumps(report,indent=2),encoding='utf8')

# Nine-part sheet; background only exists in this inspection image.
sheet=Image.new('RGB',(960,960),(242,244,247));draw=ImageDraw.Draw(sheet)
try:font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',21)
except OSError:font=ImageFont.load_default()
for i,name in enumerate(names):
    part=Image.open(export/(name+'.png')).convert('RGBA');box=part.getbbox();part=part.crop(box)
    part.thumbnail((265,245),Image.Resampling.LANCZOS)
    x=(i%3)*320+(320-part.width)//2;y=(i//3)*320+35+(245-part.height)//2
    sheet.paste(part,(x,y),part)
    draw.text(((i%3)*320+22,(i//3)*320+283),name,fill=(36,39,50),font=font)
sheet.save(ROOT/'parts_overview.png')
print(json.dumps(report))
