from pathlib import Path
import sys,json,math
ROOT=Path(__file__).resolve().parent
OLD=ROOT.parent/'axolotl_restored_parts'
sys.path.insert(0,str(OLD/'_tools'))
import numpy as np
from PIL import Image,ImageDraw,ImageFont
from scipy.ndimage import gaussian_filter,distance_transform_edt,binary_fill_holes,binary_opening,binary_closing,label
from psd_tools import PSDImage
from psd_tools.api.layers import PixelLayer,Group
from psd_tools.constants import Compression,BlendMode,Resource
from psd_tools.psd.image_resources import ImageResource
man=json.loads((OLD/'parts_manifest.json').read_text())
W,H=man['canvas'];names=[i['name'] for i in man['parts']]
source=PSDImage.open(man['source'])
doc=PSDImage.new('RGBA',(W,H),(0,0,0,0),depth=8)
profile=source.image_resources.get_data(Resource.ICC_PROFILE)
if profile:doc.image_resources[Resource.ICC_PROFILE]=ImageResource(key=Resource.ICC_PROFILE,data=profile)
def add(parent,im,name):
 if isinstance(im,np.ndarray):im=Image.fromarray(im)
 box=im.getbbox()
 if box:
  return PixelLayer.frompil(im.crop(box),parent,name=name,left=box[0],top=box[1],compression=Compression.RLE)
backup=Group.new(doc,name='Original source - hidden',open_folder=False)
for l in source:
 c=PixelLayer.frompil(l.topil().convert('RGBA'),backup,name=l.name,left=l.left,top=l.top,compression=Compression.RLE)
 c.clipping=l.clipping;c.visible=l.visible
backup.visible=False
out=ROOT/'parts_png';out.mkdir(exist_ok=True)
for n in names:
 im=Image.open(OLD/'parts_png'/(n+'.png')).convert('RGBA')
 g=Group.new(doc,name=n,open_folder=False);g.blend_mode=BlendMode.NORMAL
 if n=='Body_Front':add(g,im,'Original body');continue
 box=im.getbbox();x0,y0,x1,y1=box;x0-=15;y0-=15;x1+=15;y1+=15
 a=np.array(im.crop((x0,y0,x1,y1)))
 mask=a[:,:,3]>100
 labs,k=label(mask);counts=np.bincount(labs.ravel());counts[0]=0;mask=labs==counts.argmax()
 mask=binary_fill_holes(binary_closing(mask,iterations=3))
 if n=='Gill_L_Middle':
  extra=Image.new('L',(x1-x0,y1-y0));ed=ImageDraw.Draw(extra)
  ed.ellipse((228-x0,333-y0,293-x0,390-y0),fill=255)
  mask |= np.array(extra)>0

 # Round the little stumps left by cutting overlapping source outlines.
 mask=gaussian_filter(mask.astype(float),2.1)>.5
 mask=binary_opening(mask,iterations=2)
 inside=distance_transform_edt(mask)
 # Exclude all ink and gray antialias fragments from the color donor.
 r=a[:,:,0].astype(float);gr=a[:,:,1].astype(float);bl=a[:,:,2].astype(float)
 pink=(a[:,:,3]>240)&(r>195)&((r-gr>38) if n!='Tail_Base' else (gr>160))
 pink &= (r>bl+5) if n!='Tail_Base' else True
 dist,idx=distance_transform_edt(~pink,return_indices=True)
 color=a[idx[0],idx[1],:3].astype(float)
 # Blend only the narrow former cut edges into nearby existing paint.
 for c in range(3):
  smooth=gaussian_filter(color[:,:,c],2.5)
  blend=np.clip(dist/4,0,1)
  color[:,:,c]=color[:,:,c]*(1-blend)+smooth*blend
 # Remove the last pink/gray cut-edge residue across the former occlusion line.
 original_path=OLD.parent/'axolotl_parts'/'parts_png'/(n+'.png')
 if original_path.exists():
  orig=np.array(Image.open(original_path).convert('RGBA').crop((x0,y0,x1,y1)))[:,:,3]>100
  edge_dist=np.minimum(distance_transform_edt(orig),distance_transform_edt(~orig))
  boundary_distance=np.maximum(distance_transform_edt(orig),distance_transform_edt(~orig))
  seam_weight=np.clip((8-boundary_distance)/5,0,1)*(inside>8)
 else:seam_weight=np.zeros_like(inside)
 for c in range(3):
  local=gaussian_filter(color[:,:,c],3.2)
  color[:,:,c]=gaussian_filter(color[:,:,c]*(1-seam_weight)+local*seam_weight,.65)
 # Single uninterrupted outline, with supersampled antialiasing.

 alpha=gaussian_filter(mask.astype(float),.55)
 alpha[alpha<.015]=0;alpha[alpha>.985]=1
 ink=1-np.clip((inside-4.0)/1.5,0,1)
 fill=np.zeros_like(a);fill[:,:,:3]=np.clip(color,0,255).astype(np.uint8);fill[:,:,3]=np.rint(alpha*255).astype(np.uint8);fill[fill[:,:,3]==0]=0
 line=np.zeros_like(a);line[:,:,3]=np.rint(alpha*ink*255).astype(np.uint8)
 for pixels,labelname in [(fill,'Color - completed hidden surface'),(line,'Line art - continuous contour')]:
  full=Image.new('RGBA',(W,H));full.paste(Image.fromarray(pixels),(x0,y0));add(g,full,labelname)
doc._merged_alpha=True
doc._record.layer_and_mask_information.layer_info.layer_count=-len(doc._record.layer_and_mask_information.layer_info.layer_records)
dest=ROOT/'axolotl_restored_v2.psd';doc.save(dest,encoding='utf8')
p=PSDImage.open(dest);render={}
for g in p:
 if g.name in names:
  im=g.composite(viewport=(0,0,W,H),force=True);a=np.array(im);a[a[:,:,3]==0]=0
  render[g.name]=Image.fromarray(a);render[g.name].save(out/(g.name+'.png'))
p.composite(force=True).save(ROOT/'psd_export.png')
# The spread view deliberately exposes every restored root.
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',19)
parts=[n for n in names if n!='Body_Front'];parts.sort(key=lambda n:['Gill_L_Upper','Gill_L_Middle','Gill_L_Lower','Gill_R_Upper','Gill_R_Middle','Gill_R_Lower','Tail_Root','Tail_Middle','Tail_Tip','Tail_Base'].index(n))
sheet=Image.new('RGB',(1000,1320),(235,239,244));d=ImageDraw.Draw(sheet)
for i,n in enumerate(parts):
 im=render[n].crop(render[n].getbbox());im.thumbnail((290,260),Image.Resampling.LANCZOS)
 x=i%3*333+(333-im.width)//2;y=i//3*330+20+(260-im.height)//2
 sheet.paste(im,(x,y),im);d.text((i%3*333+15,i//3*330+292),n,font=font,fill=(20,25,35))
sheet.save(ROOT/'parts_exposed.png')
pivots={i['name']:tuple(i['pivot']) for i in man['parts']}
frames=[];spread=[]
for f in range(24):
 canvas=Image.new('RGBA',(W,H),(235,239,244,255))
 for i,n in enumerate(names):
  im=render[n]
  if n not in ['Body_Front','Tail_Base']:im=im.rotate(8*math.sin(f*2*math.pi/24+i*.35),resample=Image.Resampling.BICUBIC,center=pivots[n])
  canvas=Image.alpha_composite(canvas,im)
 frames.append(canvas.resize((543,724),Image.Resampling.LANCZOS).convert('RGB'))
 # All separate parts rotate while fully exposed: no head/neighbor hides defects.
 canvas=Image.new('RGBA',(1000,1320),(235,239,244,255));d=ImageDraw.Draw(canvas)
 for i,n in enumerate(parts):
  im=render[n].crop(render[n].getbbox());im.thumbnail((250,215),Image.Resampling.LANCZOS)
  im=im.rotate(12*math.sin(f*2*math.pi/24+i*.35),resample=Image.Resampling.BICUBIC,expand=True)
  canvas.alpha_composite(im,(i%3*333+(333-im.width)//2,i//3*330+20+(260-im.height)//2))
  d.text((i%3*333+15,i//3*330+292),n,font=font,fill=(20,25,35))
 spread.append(canvas.convert('RGB'))
frames[0].save(ROOT/'motion_v2.gif',save_all=True,append_images=frames[1:],duration=80,loop=0)
spread[0].save(ROOT/'exposed_motion_v2.gif',save_all=True,append_images=spread[1:],duration=80,loop=0)
contact=Image.new('RGB',(1086,1448))
for i,f in enumerate([0,6,12,18]):contact.paste(frames[f],(i%2*543,i//2*724))
contact.save(ROOT/'motion_contact.png')
canvas=Image.new('RGBA',(W,H));checks={}
for n in names:
 a=np.array(render[n]);mask=a[:,:,3]>100
 checks[n]={'transparent_pixels':int((a[:,:,3]==0).sum()),'internal_holes':int((binary_fill_holes(mask)&~mask).sum())}
 canvas=Image.alpha_composite(canvas,render[n])
a=np.array(canvas);b=np.array(p.composite(force=True));d=np.abs(a.astype(int)-b.astype(int));valid=(a[:,:,3]>0)|(b[:,:,3]>0)
checks['export_comparison']={'max_alpha':int(d[:,:,3].max()),'max_rgb':int(d[:,:,:3][valid].max())}
assert d[:,:,3].max()<=1 and d[:,:,:3][valid].max()<=2
(ROOT/'validation.json').write_text(json.dumps(checks,indent=2))
man['note']='v2: continuous separate outlines, cut-mark cleanup, expanded-motion and exposed-part inspections. Pivots provisional.'
(ROOT/'parts_manifest.json').write_text(json.dumps(man,indent=2))
print(json.dumps(checks))
