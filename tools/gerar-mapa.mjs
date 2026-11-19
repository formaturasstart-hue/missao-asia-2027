import fs from 'fs';
import * as topo from 'topojson-client';
import { geoEquirectangular, geoPath } from 'd3-geo';
const K=4; // unidades por grau
const proj=()=>geoEquirectangular().scale(K*180/Math.PI).translate([180*K,90*K]).precision(0.1);
const rd=s=>s.replace(/-?\d+\.\d+/g,m=>(+m).toFixed(1).replace(/\.0$/,''));
const load=f=>JSON.parse(fs.readFileSync('node_modules/world-atlas/'+f));
const l110=load('land-110m.json'), c110=load('countries-110m.json'), l50=load('land-50m.json'), c50=load('countries-50m.json');
const p=geoPath(proj());
const land110=rd(p(topo.feature(l110,l110.objects.land)));
const bord110=rd(p(topo.mesh(c110,c110.objects.countries,(a,b)=>a!==b)));
const box=(lo0,la0,lo1,la1)=>[[(lo0+180)*K,(90-la1)*K],[(lo1+180)*K,(90-la0)*K]];
const BOXES={asia:[95,5,150,50],golfo:[45,18,62,32]};
const det={};
for(const [n,b] of Object.entries(BOXES)){ const pr=proj().clipExtent(box(...b)); const pp=geoPath(pr);
  det[n]={box:b,land:rd(pp(topo.feature(l50,l50.objects.land))),coast:rd(pp(topo.mesh(l50,l50.objects.land))),bord:rd(pp(topo.mesh(c50,c50.objects.countries,(a,b)=>a!==b)))}; }
const out={K,land110,bord110,det};
fs.writeFileSync('map.json',JSON.stringify(out));
console.log('land110',land110.length,'bord110',bord110.length,Object.entries(det).map(([k,v])=>k+':'+v.land.length+'/'+v.bord.length).join(' '),'total',JSON.stringify(out).length);
