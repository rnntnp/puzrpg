const fs=require('fs'),path=require('path');
const root=__dirname;
const {readPsd,initializeCanvas}=require('./_verify_js/node_modules/ag-psd');
const sharp=require('C:/Users/jaynap/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
initializeCanvas(()=>{throw Error('Unexpected canvas path');},(width,height)=>({width,height,data:new Uint8ClampedArray(width*height*4)}));
async function main(){
 const p=readPsd(fs.readFileSync(path.join(root,'axolotl_verified_v3.psd')),{useImageData:true,skipThumbnail:true});
 const report=[];
 for(let i=0;i<p.children.length;i++){
  const layer=p.children[i],d=layer.imageData;
  const file=['03_base_colors_v2.png','02_shading_v2.png','01_line_art_v2.png'][i];
  const original=await sharp(path.join(root,file)).ensureAlpha().raw().toBuffer();
  const actual=Buffer.from(d.data.buffer,d.data.byteOffset,d.data.byteLength);
  if(!actual.equals(original))throw Error('Independent roundtrip mismatch '+layer.name);
  let alpha0=0,opaque=0,nonzeroHidden=0;
  for(let j=0;j<d.width*d.height;j++){const a=actual[j*4+3];if(a===0){alpha0++;if(actual[j*4]||actual[j*4+1]||actual[j*4+2])nonzeroHidden++;}if(a===255)opaque++;}
  report.push({name:layer.name,blend:layer.blendMode,opacity:layer.opacity,width:d.width,height:d.height,alpha0,opaque,nonzeroHidden,exactMatch:true});
 }
 const composites=p.children.map(l=>({input:Buffer.from(l.imageData.data.buffer,l.imageData.data.byteOffset,l.imageData.data.byteLength),raw:{width:l.imageData.width,height:l.imageData.height,channels:4},left:l.left,top:l.top}));
 const rgba=await sharp({create:{width:p.width,height:p.height,channels:4,background:'#00000000'}}).composite(composites).raw().toBuffer();
 await sharp(rgba,{raw:{width:p.width,height:p.height,channels:4}}).png().toFile(path.join(root,'independent_psd_export.png'));
 const source=await sharp('C:/Users/jaynap/AppData/Local/Temp/codex-clipboard-80e43b8e-b538-415a-b0d7-5aa1769aef42.png').ensureAlpha().raw().toBuffer();
 let cachedClear=0,cachedError=0;
 for(let i=0;i<p.width*p.height;i++){
  if(p.imageData.data[i*4+3]===0)cachedClear++;
  if(p.imageData.data[i*4+3]!==rgba[i*4+3])throw Error('Merged preview alpha mismatch');
  if(rgba[i*4+3])for(let c=0;c<3;c++)cachedError=Math.max(cachedError,Math.abs(p.imageData.data[i*4+c]-source[i*4+c]));
 }
 if(cachedError>1)throw Error('Merged preview color mismatch '+cachedError);
 let max=0,sum=0,count=0;
 for(let i=0;i<p.width*p.height;i++)if(rgba[i*4+3]){count++;for(let c=0;c<3;c++){const error=Math.abs(rgba[i*4+c]-source[i*4+c]);max=Math.max(max,error);sum+=error;}}
 const result={layers:report,comparison:{maxDifference:max,meanDifference:sum/(count*3),count},mergedPreview:{transparentPixels:cachedClear,maxDifference:cachedError}};
 if(max>1)throw Error('Composite differs: '+JSON.stringify(result));
 fs.writeFileSync(path.join(root,'independent_verification.json'),JSON.stringify(result,null,2));
 console.log(JSON.stringify(result));
}
main().catch(e=>{console.error(e);process.exit(1)});
