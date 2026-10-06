const fs=require('fs'),path=require('path');
const sharp=require('C:/Users/jaynap/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const out=__dirname;
const source='C:/Users/jaynap/AppData/Local/Temp/codex-clipboard-80e43b8e-b538-415a-b0d7-5aa1769aef42.png';
const cat=(...v)=>Buffer.concat(v),str=s=>Buffer.from(s,'ascii');
const s16=n=>{let b=Buffer.alloc(2);b.writeInt16BE(n);return b;};
const u32=n=>{let b=Buffer.alloc(4);b.writeUInt32BE(n);return b;};
function planes(d,n){return [0,1,2,3].map(c=>{let a=Buffer.alloc(n);for(let i=0;i<n;i++)a[i]=d[4*i+c];return a;});}
function unicode(s){const b=Buffer.alloc(s.length*2);for(let i=0;i<s.length;i++)b.writeUInt16BE(s.charCodeAt(i),i*2);return cat(u32(s.length),b);}
function writePSD(w,h,layers,merged){
 const records=[],pixels=[];
 // PSD layer records are stored bottom to top.
 for(const l of [...layers].reverse()){
  const p=planes(l.data,w*h);let name=cat(Buffer.from([l.ascii.length]),str(l.ascii));name=cat(name,Buffer.alloc((4-name.length%4)%4));
  const un=unicode(l.name),extra=cat(u32(0),u32(0),name,str('8BIMluni'),u32(un.length),un,Buffer.alloc(un.length%2));
  records.push(cat(u32(0),u32(0),u32(h),u32(w),s16(4),...p.map((a,c)=>cat(s16(c===3?-1:c),u32(a.length+2))),str('8BIMnorm'),Buffer.from([255,0,l.hidden?2:0,0]),u32(extra.length),extra));
  pixels.push(...p.map(a=>cat(s16(0),a)));
 }
 let info=cat(s16(-layers.length),...records,...pixels);if(info.length%2)info=cat(info,Buffer.alloc(1));
 let lm=cat(u32(info.length),info,u32(0));
 fs.writeFileSync(path.join(out,'axolotl_line_color_shading_v2.psd'),cat(str('8BPS'),s16(1),Buffer.alloc(6),s16(4),u32(h),u32(w),s16(8),s16(3),u32(0),u32(0),u32(lm.length),lm,s16(0),...planes(merged,w*h)));
}
async function main(){
 const {data:src,info}=await sharp(source).ensureAlpha().raw().toBuffer({resolveWithObject:true});
 const w=info.width,h=info.height,n=w*h,q=new Int32Array(n),mask=new Uint8Array(n),seen=new Uint8Array(n);
 // Extract the central character from the paper, preserving its source pixels.
 const white=i=>{let r=src[4*i],g=src[4*i+1],b=src[4*i+2];return Math.min(r,g,b)>200&&Math.max(r,g,b)-Math.min(r,g,b)<35;};
 let head=0,tail=0;
 const add=i=>{if(i>=0&&i<n&&!seen[i]&&white(i)){seen[i]=1;q[tail++]=i;}};
 for(let y=140;y<=1110;y++){add(y*w+25);add(y*w+999);}for(let x=25;x<=999;x++){add(140*w+x);add(1110*w+x);}
 while(head<tail){const i=q[head++],x=i%w,y=(i/w)|0;if(x>25)add(i-1);if(x<999)add(i+1);if(y>140)add(i-w);if(y<1110)add(i+w);}
 for(let y=140;y<=1110;y++)for(let x=25;x<=999;x++){const i=y*w+x;if(!seen[i])mask[i]=1;}
 seen.fill(0);let largest=[];
 for(let i=0;i<n;i++)if(mask[i]&&!seen[i]){head=0;tail=1;q[0]=i;seen[i]=1;while(head<tail){let j=q[head++];for(const k of [j-1,j+1,j-w,j+w])if(k>=0&&k<n&&mask[k]&&!seen[k]){seen[k]=1;q[tail++]=k;}}if(tail>largest.length)largest=Array.from(q.subarray(0,tail));}
 mask.fill(0);for(const i of largest)mask[i]=1;
 const palette=[[255,219,222],[245,111,163],[38,147,165],[255,198,65],[9,198,224],[137,94,74],[53,52,67],[255,183,197]];
 const labels=new Int16Array(n);labels.fill(-1);seen.fill(0);
 const dark=i=>Math.max(src[4*i],src[4*i+1],src[4*i+2])<175&&Math.max(src[4*i],src[4*i+1],src[4*i+2])-Math.min(src[4*i],src[4*i+1],src[4*i+2])<100;
 const choose=(r,g,b)=>{let best=0,score=Infinity;for(let k=0;k<palette.length;k++){let c=palette[k],d=(r-c[0])**2+(g-c[1])**2+(b-c[2])**2;if(d<score){score=d;best=k;}}return best;};
 // Closed colored regions yield one material color each, independent of lighting.
 for(const i of largest)if(!seen[i]&&!dark(i)){
  head=0;tail=1;q[0]=i;seen[i]=1;let rr=0,gg=0,bb=0;
  while(head<tail){let j=q[head++];rr+=src[j*4];gg+=src[j*4+1];bb+=src[j*4+2];for(const k of [j-1,j+1,j-w,j+w])if(k>=0&&k<n&&mask[k]&&!seen[k]&&!dark(k)){seen[k]=1;q[tail++]=k;}}
  let label=choose(rr/tail,gg/tail,bb/tail);for(let k=0;k<tail;k++)labels[q[k]]=label;
 }
 // Boots are intentionally dark material, not a solid block of linework.
 for(const i of largest){let x=i%w,y=(i/w)|0;if((y>988&&x>463&&x<570)||(y>951&&x>603&&x<726))labels[i]=6;}
 head=0;tail=0;for(const i of largest)if(labels[i]>=0)q[tail++]=i;
 while(head<tail){const j=q[head++];for(const k of [j-1,j+1,j-w,j+w])if(k>=0&&k<n&&mask[k]&&labels[k]<0){labels[k]=labels[j];q[tail++]=k;}}
 const inside=(x,y,p)=>{let v=false;for(let i=0,j=p.length-1;i<p.length;j=i++){const [xi,yi]=p[i],[xj,yj]=p[j];if((yi>y)!=(yj>y)&&x<(xj-xi)*(y-yi)/(yj-yi)+xi)v=!v;}return v;};
 const face=[[253,475],[266,401],[291,363],[360,291],[447,243],[518,229],[600,240],[675,282],[725,351],[744,427],[740,474],[711,518],[642,558],[588,580],[581,621],[453,613],[451,595],[381,590],[310,569],[272,541],[256,509]];
 const tailSkin=[[48,967],[131,934],[231,896],[399,839],[416,865],[399,992],[293,1021],[174,1027],[89,1007]];
 const tailFins=[[[68,860],[128,879],[174,849],[192,858],[181,914],[198,949],[184,967],[132,956],[83,979],[70,970],[77,930],[66,883]],[[180,830],[220,822],[246,834],[276,800],[296,808],[300,844],[322,852],[309,875],[307,904],[283,912],[252,902],[221,930],[203,927],[204,892]],[[275,783],[303,776],[335,782],[368,746],[385,749],[393,772],[381,815],[412,838],[406,854],[359,850],[334,880],[319,882],[307,850],[290,825],[276,802]]];
 const leftHand=[[420,831],[500,850],[510,878],[507,901],[495,908],[481,901],[474,914],[459,916],[449,899],[438,910],[426,905],[418,888],[417,862]];
 const rightHand=[[703,722],[723,719],[744,731],[758,748],[756,772],[741,786],[716,784],[698,795],[683,777]];
 for(const i of largest){let x=i%w,y=(i/w)|0;
  if(y<610&&x<855){labels[i]=inside(x,y,face)?0:1;}
  if(y>740&&x<416){if(inside(x,y,tailSkin))labels[i]=0;for(const p of tailFins)if(inside(x,y,p))labels[i]=1;}
  if(inside(x,y,leftHand)||inside(x,y,rightHand))labels[i]=0;
  if(((x-330)/40)**2+((y-477)/40)**2<1||((x-686)/36)**2+((y-442)/37)**2<1)labels[i]=7;
  if(x>720&&y>500&&y<738)labels[i]=5;
  if(x>830&&y<596&&y>470)labels[i]=3;
  if(((x-921)/61)**2+((y-501)/60)**2<1)labels[i]=4;
  if(((x-549)/55)**2+((y-632)/52)**2<1)labels[i]=3;
  if(((x-550)/26)**2+((y-629)/27)**2<1)labels[i]=4;
  if(inside(x,y,[[455,604],[589,616],[664,695],[702,717],[681,778],[756,933],[613,975],[545,983],[404,1013],[399,1005],[415,839],[379,830]]))labels[i]=2;
  if(inside(x,y,leftHand)||inside(x,y,rightHand))labels[i]=0;
  if(((x-549)/55)**2+((y-632)/52)**2<1)labels[i]=3;
  if(((x-550)/26)**2+((y-629)/27)**2<1)labels[i]=4;
 }
 const base=Buffer.alloc(n*4),shade=Buffer.alloc(n*4),line=Buffer.alloc(n*4),merged=Buffer.alloc(n*4);
 for(const i of largest){const o=i*4,c=[src[o],src[o+1],src[o+2]],b=palette[Math.max(labels[i],0)];
  for(let k=0;k<3;k++){base[o+k]=b[k];merged[o+k]=c[k];}base[o+3]=merged[o+3]=255;
  const x=i%w,y=(i/w)|0,eye=((x-397)/25)**2+((y-408)/37)**2<1||((x-615)/25)**2+((y-390)/36)**2<1;
  let a=Math.max(0,Math.min(1,(160-Math.max(...c))/65));
  if(labels[i]===5&&Math.max(...c)-Math.min(...c)>30)a=0;
  if(labels[i]===6){let edge=false;for(const k of [i-2,i+2,i-2*w,i+2*w])if(!mask[k])edge=true;if(!edge)a=0;}
  if(eye&&Math.max(...c)<120)a=1;
  if(Math.max(...c)-Math.min(...c)>65)a=0;
  if(y<605&&x<825)a=Math.max(0,Math.min(1,(195-Math.max(...c))/100));
  const orbRadius=((x-920)/63)**2+((y-501)/62)**2;
  if(orbRadius>0.85&&orbRadius<1.12)a=Math.max(0,Math.min(1,(210-Math.max(...c))/120));
  if(x>690&&y>535&&y<832&&Math.max(...c)>100)a=0;
  const ink=[43,42,56];
  // Uniform ink only. Empty line pixels have zero RGB as well as zero alpha.
  for(let k=0;k<3;k++)a=Math.min(a,c[k]/ink[k],(255-c[k])/(255-ink[k]));
  line[o+3]=Math.floor(Math.max(0,a)*255);a=line[o+3]/255;
  if(a>0)for(let k=0;k<3;k++)line[o+k]=ink[k];
  if(a<1){const under=c.map((v,k)=>(v-a*ink[k])/(1-a));let sa=0;for(let k=0;k<3;k++)sa=Math.max(sa,under[k]<b[k]?(b[k]-under[k])/Math.max(1,b[k]):(under[k]-b[k])/Math.max(1,255-b[k]));
   const ab=Math.min(255,Math.ceil(sa*255));shade[o+3]=ab;if(ab)for(let k=0;k<3;k++)shade[o+k]=Math.max(0,Math.min(255,Math.round(b[k]+(under[k]-b[k])*255/ab)));
  }
 }
 const layers=[{name:'선화',ascii:'01 Line art',data:line},{name:'명암 · 하이라이트',ascii:'02 Shading and highlights',data:shade},{name:'밑색',ascii:'03 Base colors',data:base}];
 writePSD(w,h,layers,merged);
 for(const [name,data] of [['preview_v2',merged],['01_line_art_v2',line],['02_shading_v2',shade],['03_base_colors_v2',base]])await sharp(data,{raw:{width:w,height:h,channels:4}}).png().toFile(path.join(out,name+'.png'));
 await sharp(line,{raw:{width:w,height:h,channels:4}}).flatten({background:'#ffffff'}).png().toFile(path.join(out,'line_check_v2.png'));
 // Independently recomposite the serialized layer pixel buffers and compare.
 let maxError=0,total=0;for(const i of largest){let o=i*4;for(let c=0;c<3;c++){let a=shade[o+3]/255,v=shade[o+c]*a+base[o+c]*(1-a);a=line[o+3]/255;v=line[o+c]*a+v*(1-a);const e=Math.abs(Math.round(v)-src[o+c]);maxError=Math.max(maxError,e);total+=e;}}
 fs.writeFileSync(path.join(out,'README.md'),'# 아홀로틀 페인팅 레이어\n\nPSD 위→아래: 선화 / 명암·하이라이트 / 밑색 / 원본 참고(숨김).\n\n합쳐진 PNG에서 추정 분리한 편집용 파일입니다. 원래 작가의 레이어를 복원한 것은 아닙니다. 선화에는 눈과 표정이 포함되고, 명암에는 하이라이트와 색 변화가 포함됩니다. 명암은 일반(Normal) 합성입니다. 캐릭터 픽셀은 첨부 원본을 사용했으며 배경과 주변 낙서는 제외했습니다. 밑색 경계와 어두운 소재의 경계는 수작업 보정이 필요할 수 있습니다.\n\n이미지 도구: built-in image_gen. 사용 프롬프트 요약: 원본 자세와 형태를 유지한 채 선·명암·광택을 제거하고 소재별 단색 밑색 패스를 투명 배경으로 준비. 생성 결과는 밑색 참고로 사용하고 최종 PSD는 원본 좌표와 픽셀을 기준으로 구성했습니다.\n');
 console.log(JSON.stringify({width:w,height:h,layers:layers.map(l=>l.name),foregroundPixels:largest.length,maxRecompositionError:maxError,meanError:total/(largest.length*3),file:path.join(out,'axolotl_line_color_shading.psd')}));
}
main().catch(e=>{console.error(e);process.exit(1);});
