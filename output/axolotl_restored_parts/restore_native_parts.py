from pathlib import Path
import sys,json,math
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'_tools'))
from PIL import Image,ImageDraw,ImageFont,ImageFilter
import numpy as np
from scipy.ndimage import distance_transform_edt,binary_dilation,binary_erosion,binary_closing,binary_opening,binary_fill_holes,gaussian_filter,label,map_coordinates
from scipy.optimize import differential_evolution
from psd_tools import PSDImage
from psd_tools.api.layers import PixelLayer,Group
from psd_tools.constants import Resource,Compression,BlendMode
from psd_tools.psd.image_resources import ImageResource

OLD=ROOT.parent/'axolotl_parts'
original=PSDImage.open('C:/Users/jaynap/Dropbox/axolotl_verified_v3.psd')
partsdoc=PSDImage.open(OLD/'axolotl_gills_tail_parts.psd')
W,H=original.size
yy,xx=np.mgrid[:H,:W]
profile=original.image_resources.get_data(Resource.ICC_PROFILE)
names=['Gill_L_Upper','Gill_L_Middle','Gill_L_Lower','Gill_R_Upper','Gill_R_Middle','Gill_R_Lower','Tail_Root','Tail_Middle','Tail_Tip']
parts={n:Image.open(OLD/'parts_png'/(n+'.png')).convert('RGBA') for n in names+['Body']}
arr={n:np.array(im) for n,im in parts.items()}
atlas=Image.open(ROOT/'restored_atlas_source.png').convert('RGBA')
boxes={
 'Gill_L_Upper':(297,160,460,339),
 'Gill_L_Middle':(211,248,381,408),
 'Gill_L_Lower':(127,309,340,485),
 'Gill_R_Upper':(594,173,745,350),
 'Gill_R_Middle':(655,276,812,422),
 'Gill_R_Lower':(686,346,859,495),
 'Tail_Root':(272,742,455,889),
 'Tail_Middle':(178,774,341,935),
 'Tail_Tip':(63,846,220,983),
}
tail_region=(xx<(409-(yy-852)*0.105))&(yy>852)
body=arr['Body']
tail_visible=body.copy();tail_visible[~tail_region]=0
front=body.copy();front[tail_region]=0
front_opaque=front[:,:,3]>0
# Drawing order: all fins behind the head/robe; tail skin beneath its ornaments.
order=['Gill_L_Lower','Gill_L_Middle','Gill_L_Upper','Gill_R_Lower','Gill_R_Middle','Gill_R_Upper','Tail_Base','Tail_Tip','Tail_Middle','Tail_Root','Body_Front']
patches={}
repairs={}
clean_masks={}
source_whole=np.array(original.composite(force=True))
outside_distance=distance_transform_edt(source_whole[:,:,3]>80)
fit_report={}

def clean_bounds(image):
 a=np.array(image);mask=a[:,:,3]>10
 ys,xs=np.where(mask)
 return image.crop((int(xs.min()),int(ys.min()),int(xs.max())+1,int(ys.max())+1))

def nearest_rgb(source,predicate):
 distance,indices=distance_transform_edt(~predicate,return_indices=True)
 return source[indices[0],indices[1],:3],distance

for i,name in enumerate(names):
 col=i%3;row=i//3
 cell=atlas.crop((round(col*atlas.width/3),round(row*atlas.height/3),round((col+1)*atlas.width/3),round((row+1)*atlas.height/3)))
 full=clean_bounds(cell)
 x0,y0,x1,y1=boxes[name]
 # Match the generated completion to the surviving outside contour.
 source=arr[name]
 target=(source[:,:,3]>80)&(outside_distance<3.5)
 sy,sx=np.where(target)
 if len(sx)>800:
  select=np.linspace(0,len(sx)-1,800).astype(int);sx=sx[select];sy=sy[select]
 ga=np.array(full)[:,:,3]>100
 edge=ga&~binary_erosion(ga)
 distance=distance_transform_edt(~edge)
 fw,fh=full.size
 initial=np.array([x0,y0,x1-x0,y1-y0],float)
 def loss(v):
  gx=(sx-v[0])/v[2]*(fw-1);gy=(sy-v[1])/v[3]*(fh-1)
  d=map_coordinates(distance,[gy,gx],order=1,mode='constant',cval=100)*(v[2]/fw+v[3]/fh)/2
  prior=np.mean(((v-initial)/np.array([35,35,50,50]))**2)
  return np.mean(np.minimum(d,30)**2)+prior*1.4
 if len(sx)>10:
  fit=differential_evolution(loss,[(x0-30,x0+30),(y0-30,y0+30),((x1-x0)*.72,(x1-x0)*1.28),((y1-y0)*.72,(y1-y0)*1.28)],seed=11,popsize=7,maxiter=45,polish=True)
  x0,y0,ww,hh=np.rint(fit.x).astype(int);x1=x0+ww;y1=y0+hh
  fit_report[name]={'box':[int(x0),int(y0),int(x1),int(y1)],'score':float(fit.fun)}
 full=full.resize((x1-x0,y1-y0),Image.Resampling.LANCZOS)
 placed=Image.new('RGBA',(W,H));placed.paste(full,(x0,y0))
 generated=np.array(placed)
 occluder=front_opaque.copy()
 for other in names:
  if order.index(other)>order.index(name):occluder|=arr[other][:,:,3]>0
 source=arr[name]
 opaque=source[:,:,3]>0
 allowed=occluder|opaque
 generated[~allowed]=0
 # Color-match only newly reconstructed pixels near the original cut boundary.
 pink=(source[:,:,3]>200)&(source[:,:,0]>145)&(source[:,:,0].astype(int)>source[:,:,1].astype(int)+35)
 near,dist=nearest_rgb(source,pink)
 blend=np.clip((14-dist)/14,0,1)*0.85
 is_pink=(generated[:,:,0]>120)&(generated[:,:,0].astype(int)>generated[:,:,1].astype(int)+30)
 for c in range(3):generated[:,:,c]=np.where(is_pink,np.rint(generated[:,:,c]*(1-blend)+near[:,:,c]*blend),generated[:,:,c]).astype(np.uint8)
 # A short concealed overlap bridges the painted cut edge into the restored root.
 bridge=binary_dilation(source[:,:,3]>180,iterations=7)&occluder
 bridge&=dist<18
 generated[bridge,:3]=near[bridge]
 generated[bridge,3]=255
 generated[generated[:,:,3]==0]=0
 patches[name]=generated
 # Repaint the concealed joining strip above the retained paint layers.
 # This removes old clipped-edge fragments rather than leaving a stitched seam.
 support=(source[:,:,3]>20)|(generated[:,:,3]>20)
 support=binary_fill_holes(binary_closing(support,iterations=3))
 touch=binary_dilation(source[:,:,3]>20,iterations=2)&binary_dilation(occluder,iterations=2)
 band=binary_dilation(touch,iterations=6)&support
 band&=distance_transform_edt(support)>3
 repair=np.zeros_like(source)
 for c in range(3):repair[:,:,c]=np.rint(gaussian_filter(near[:,:,c].astype(float),2.2)).astype(np.uint8)
 repair[:,:,3]=band.astype(np.uint8)*255
 repair[~band]=0
 repairs[name]=repair

# Warp the generated bare-tail underpainting to the existing tail's visible curve.
tailgen=np.array(clean_bounds(Image.open(ROOT/'restored_tail_source.png').convert('RGBA')))
gh,gw=tailgen.shape[:2]
tailpaint=np.zeros((H,W,4),np.uint8)
anchors_x=np.array([45,80,140,210,280,350,412,450])
anchors_top=np.array([970,954,934,909,884,858,828,814])
anchors_bottom=np.array([980,1001,1019,1028,1020,1001,984,979])
for x in range(45,451):
 gx=min(gw-1,max(0,round((x-45)/(450-45)*(gw-1))))
 active=np.where(tailgen[:,gx,3]>30)[0]
 if not len(active):continue
 top=float(np.interp(x,anchors_x,anchors_top));bottom=float(np.interp(x,anchors_x,anchors_bottom))
 ys=np.arange(max(0,math.floor(top)),min(H,math.ceil(bottom)+1))
 gy=active[0]+(ys-top)/max(1,bottom-top)*(active[-1]-active[0])
 for c in range(4):tailpaint[ys,x,c]=np.clip(np.interp(gy,np.arange(gh),tailgen[:,gx,c]),0,255).astype(np.uint8)
occluder=front_opaque.copy()
for n in ['Tail_Tip','Tail_Middle','Tail_Root']:occluder|=arr[n][:,:,3]>0
allowed=occluder|(tail_visible[:,:,3]>0)
tailpaint[~allowed]=0
tailpink=(tail_visible[:,:,3]>200)&(tail_visible[:,:,0]>180)&(tail_visible[:,:,1]>150)
near,dist=nearest_rgb(tail_visible,tailpink)
blend=np.clip((16-dist)/16,0,1)
is_pink=tailpaint[:,:,0]>140
for c in range(3):tailpaint[:,:,c]=np.where(is_pink,np.rint(tailpaint[:,:,c]*(1-blend)+near[:,:,c]*blend),tailpaint[:,:,c]).astype(np.uint8)
tailpaint[tailpaint[:,:,3]==0]=0
patches['Tail_Base']=tailpaint
support=(tail_visible[:,:,3]>20)|(tailpaint[:,:,3]>20)
support=binary_fill_holes(binary_closing(support,iterations=3))
touch=binary_dilation(tail_visible[:,:,3]>20,iterations=2)&binary_dilation(occluder,iterations=2)
band=binary_dilation(touch,iterations=7)&support&(distance_transform_edt(support)>3)
repair=np.zeros_like(tailpaint)
for c in range(3):repair[:,:,c]=np.rint(gaussian_filter(near[:,:,c].astype(float),3)).astype(np.uint8)
repair[:,:,3]=band.astype(np.uint8)*255;repair[~band]=0
repairs['Tail_Base']=repair

# Finish the hidden silhouettes with explicit native contours.  Their junctions
# follow the original cut endpoints; generated paint supplies the unseen color.
contours={
 'Gill_L_Upper':[[(342,290),(348,320),(365,339),(383,328),(394,306),(425,317),(446,306),(437,288),(429,264),(446,243),(438,278)]],
 'Gill_L_Middle':[[(328,273),(348,277),(344,306),(369,314),(382,335),(369,354),(343,351),(337,382),(317,397),(288,370)]],
 'Gill_L_Lower':[[(279,368),(309,378),(336,393),(332,409),(306,426),(314,449),(293,463),(252,466)],[(218,322),(240,288),(261,292),(267,314),(262,347),(279,366),(239,362)]],
 'Gill_R_Upper':[[(612,252),(599,283),(597,304),(612,316),(640,305),(657,333),(677,335),(692,301)]],
 'Gill_R_Middle':[[(702,301),(680,300),(662,317),(677,340),(663,370),(676,390),(705,378),(737,382)]],
 'Gill_R_Lower':[[(742,386),(725,382),(703,397),(696,416),(707,434),(724,444),(732,477),(750,470)],[(741,387),(751,365),(770,353),(782,365),(788,390)]],
 'Tail_Root':[[(383,772),(406,760),(425,774),(419,801),(439,817),(446,833),(426,850),(407,846),(374,826)]],
 'Tail_Middle':[[(267,808),(289,787),(307,787),(318,806),(310,826),(302,844),(320,842),(335,850),(329,866),(308,875),(295,847)]],
 'Tail_Tip':[[(184,905),(207,897),(221,908),(217,926),(198,936),(190,948)]],
}
def smooth_mask(polygons):
 im=Image.new('L',(W*2,H*2));d=ImageDraw.Draw(im)
 for points in polygons:
  p=np.array(points,float);curve=[]
  for k in range(len(p)):
   p0,p1,p2,p3=p[(k-1)%len(p)],p[k],p[(k+1)%len(p)],p[(k+2)%len(p)]
   for t in np.linspace(0,1,18,endpoint=False):
    q=.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t)
    curve.append((float(q[0]*2),float(q[1]*2)))
  d.polygon(curve,fill=255)
 return np.asarray(im.resize((W,H),Image.Resampling.LANCZOS))>80

for n in names+['Tail_Base']:
 src=arr[n] if n in names else tail_visible
 if n in names:
  hidden=smooth_mask(contours[n])
  if n=='Gill_L_Upper':hidden|=smooth_mask([[(329,259),(416,233),(440,259),(424,295),(363,316)]])
  pink=(src[:,:,3]>220)&(src[:,:,0]>215)&(src[:,:,0].astype(int)>src[:,:,1].astype(int)+35)
 else:
  hidden=smooth_mask([[(46,970),(80,952),(140,934),(211,907),(279,884),(349,857),(412,829),(444,817),(446,976),(410,987),(350,1001),(280,1020),(210,1028),(140,1019),(80,1001)]])
  pink=(src[:,:,3]>220)&(src[:,:,0]>240)&(src[:,:,1]>185)
 field,dd=nearest_rgb(src,pink)
 donor=patches[n]
 good=(donor[:,:,3]>0)&(donor[:,:,0]>215)&(donor[:,:,1]>(170 if n=='Tail_Base' else 60))
 donor_field,_=nearest_rgb(donor,good)
 color=np.empty((H,W,3),np.uint8)
 weight=np.clip(dd/32,0,.5)
 for c in range(3):
  f=gaussian_filter(field[:,:,c].astype(float),3)
  g=gaussian_filter(donor_field[:,:,c].astype(float),4)
  color[:,:,c]=np.rint(f*(1-weight)+g*weight).astype(np.uint8)
 original_mask=src[:,:,3]>20
 labels,num=label(original_mask)
 if num:
  sizes=np.bincount(labels.ravel());sizes[0]=0
  original_mask=labels==sizes.argmax()
 support=binary_fill_holes(binary_closing(original_mask|hidden,iterations=6))
 support=binary_opening(support,iterations=2)
 support=gaussian_filter(support.astype(float),1.25)>.5
 clean_masks[n]=support

 dist_inside=distance_transform_edt(support)
 ink=support&(dist_inside<=4.2)
 paint=np.zeros((H,W,4),np.uint8);paint[:,:,:3]=color;paint[:,:,3]=support.astype(np.uint8)*255
 paint[ink,:3]=0;paint[~support]=0
 patches[n]=paint
 # The upper finishing patch removes stray cut-line fragments inside the new root.
 finish=binary_dilation(hidden & ~original_mask if n=='Tail_Base' else hidden,iterations=8)&support&(dist_inside>4.2)
 finish &= (src[:,:,3]<200)|((src[:,:,:3].max(axis=2)<160)&(dist_inside>9))
 finish |= (distance_transform_edt(original_mask)<3.5)&(distance_transform_edt(~original_mask)<3.5)&support&(dist_inside>9)
 repair=np.zeros_like(paint);repair[:,:,:3]=color;repair[:,:,3]=finish.astype(np.uint8)*255;repair[~finish]=0
 repairs[n]=repair

doc=PSDImage.new('RGBA',(W,H),(0,0,0,0),depth=8)
if profile:doc.image_resources[Resource.ICC_PROFILE]=ImageResource(key=Resource.ICC_PROFILE,data=profile)
backup=Group.new(doc,name='SOURCE_BACKUP_hidden',open_folder=False)
for layer in original:
 child=PixelLayer.frompil(layer.topil().convert('RGBA'),backup,name=layer.name,compression=Compression.RLE)
 child.visible=layer.visible;child.clipping=layer.clipping
backup.visible=False

def add_image(parent,image,name,clipping=False):
 if isinstance(image,np.ndarray):image=Image.fromarray(image)
 bounds=image.getbbox()
 if not bounds:return
 layer=PixelLayer.frompil(image.crop(bounds),parent,name=name,top=bounds[1],left=bounds[0],compression=Compression.RLE)
 layer.clipping=clipping

for name in order:
 group=Group.new(doc,name=name,open_folder=False);group.blend_mode=BlendMode.NORMAL
 if name in patches:add_image(group,patches[name],'Restored hidden artwork')
 oldname=name if name in names else 'Body'
 old=next(g for g in partsdoc if g.name==oldname)
 for layer in old:
  canvas=Image.new('RGBA',(W,H));canvas.paste(layer.topil().convert('RGBA'),(layer.left,layer.top))
  pix=np.array(canvas)
  if name=='Tail_Base':pix[~tail_region]=0
  elif name=='Body_Front':pix[tail_region]=0
  if name in clean_masks:pix[~clean_masks[name]]=0
  add_image(group,pix,layer.name,layer.clipping)
 if name in repairs:add_image(group,repairs[name],'Restored seam finish')

doc._merged_alpha=True
doc._record.layer_and_mask_information.layer_info.layer_count=-len(doc._record.layer_and_mask_information.layer_info.layer_records)
dest=ROOT/'axolotl_restored_parts.psd'
doc.save(dest,encoding='utf-8')
saved=PSDImage.open(dest)
exports=ROOT/'parts_png';exports.mkdir(exist_ok=True)
rendered={}
for group in saved:
 if group.name in order:
  im=group.composite(viewport=(0,0,W,H),force=True)
  a=np.array(im);a[a[:,:,3]==0]=0;im=Image.fromarray(a)
  im.save(exports/(group.name+'.png'))
  rendered[group.name]=im
saved.composite(force=True).save(ROOT/'assembled_restored.png')
source=np.array(original.composite(force=True));result=np.array(saved.composite(force=True))
mask=(source[:,:,3]>0)|(result[:,:,3]>0)
delta=np.abs(source.astype(np.int16)-result.astype(np.int16))
report={'max_alpha_difference':int(delta[:,:,3].max()),'changed_alpha_pixels':int(np.count_nonzero(delta[:,:,3])),'max_visible_rgb_difference':int(delta[:,:,:3][mask].max()),'changed_rgb_pixels':int(np.any(delta[:,:,:3]>0,axis=2)[mask].sum()),'restored_pixels':{n:int(np.count_nonzero(p[:,:,3])) for n,p in patches.items()}}
(ROOT/'verification.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
(ROOT/'fit_report.json').write_text(json.dumps(fit_report,indent=2),encoding='utf-8')
print(json.dumps(report))

sheet=Image.new('RGB',(1000,1320),(239,242,247));draw=ImageDraw.Draw(sheet)
try:font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',21)
except OSError:font=ImageFont.load_default()
for i,n in enumerate(names+['Tail_Base']):
 part=clean_bounds(rendered[n]);part.thumbnail((290,265),Image.Resampling.LANCZOS)
 x=(i%3)*333+(333-part.width)//2;y=(i//3)*330+20+(260-part.height)//2
 sheet.paste(part,(x,y),part);draw.text(((i%3)*333+15,(i//3)*330+290),n,fill=(30,33,42),font=font)
sheet.save(ROOT/'restored_parts_overview.png')

manifest=json.loads((OLD/'parts_manifest.json').read_text(encoding='utf8'))
pivots={p['name']:p['pivot'] for p in manifest['parts']}
pivots['Tail_Base']=[404,864];pivots['Body_Front']=[543,700]
manifest['parts']=[{'name':n,'file':'parts_png/'+n+'.png','pivot':pivots[n],'draw_order':i} for i,n in enumerate(order)]
manifest['note']='Hidden roots and underlying tail skin restored; original visible paint layers retained. Rotation preview is an inspection, not a game rig.'
(ROOT/'parts_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
# Small-angle movement inspection using the actual PSD exports.
frames=[]
for frame in range(24):
 canvas=Image.new('RGBA',(W,H),(235,239,244,255))
 for i,n in enumerate(order):
  im=rendered[n]
  if n in names:
   angle=4*math.sin(frame*2*math.pi/24+i*.35)
   im=im.rotate(angle,resample=Image.Resampling.BICUBIC,center=tuple(pivots[n]))
  canvas=Image.alpha_composite(canvas,im)
 frames.append(canvas.resize((543,724),Image.Resampling.LANCZOS).convert('RGB'))
frames[0].save(ROOT/'rotation_check.gif',save_all=True,append_images=frames[1:],duration=80,loop=0)
