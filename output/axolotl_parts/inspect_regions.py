from PIL import Image
import numpy as np
from collections import deque
from pathlib import Path
r=Path(__file__).parent
a=np.array(Image.open(r/'source_preview.png'))
h,w=a.shape[:2]
ok=(a[:,:,3]>100)&(a[:,:,:3].max(axis=2)>170)
seen=np.zeros((h,w),np.uint8)
seeds=[('head',500,400),('tail',300,980),('Gill_L_Upper',365,230),('Gill_L_Middle',273,308),('Gill_L_Lower',217,395),('Gill_R_Upper',666,240),('Gill_R_Middle',756,334),('Gill_R_Lower',792,432),('Tail_Tip',126,925),('Tail_Middle',251,865),('Tail_Root',337,813)]
regions={}
for name,x,y in seeds:
 seen[:]=0
 q=deque([(x,y)]);seen[y,x]=1
 while q:
  xx,yy=q.popleft()
  for nx,ny in ((xx-1,yy),(xx+1,yy),(xx,yy-1),(xx,yy+1)):
   if 0<=nx<w and 0<=ny<h and not seen[ny,nx] and ok[ny,nx]:seen[ny,nx]=1;q.append((nx,ny))
 ys,xs=np.where(seen)
 regions[name]=seen.copy()
 print(name,int(seen.sum()),[int(xs.min()),int(ys.min()),int(xs.max()),int(ys.max())])
np.savez_compressed(r/'regions.npz',**regions)
