const { chromium } = require('playwright');
const fs = require('fs');
const root = require('path').resolve(__dirname, '../../..');
const phase = process.argv[2] || 'depois';
const sizes = phase === 'antes' ? [[390,844],[1024,768],[1440,900]] : [[390,844],[768,1024],[1024,768],[1440,900],[1920,1080]];
(async () => {
 const browser = await chromium.launch({ executablePath:process.env.BROWSER_EXECUTABLE,headless:true,args:['--no-sandbox','--disable-dev-shm-usage'] });
 const output = `${root}/docs/redesign-publico/screenshots/${phase}`;
 fs.mkdirSync(output,{recursive:true});
 const report=[];
 for(const [width,height] of sizes) {
  const page = await browser.newPage({viewport:{width,height},deviceScaleFactor:1,colorScheme:'light',reducedMotion:'reduce'});
  let errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  for(const [name,path] of [['login','/users/sign_in'],['cadastro','/users/sign_up'],['landing','/']]) {
   errors=[];
   const response=await page.goto((process.env.PUBLIC_UI_URL || 'http://127.0.0.1:3107')+path,{waitUntil:'networkidle'});
   await page.evaluate(()=>document.fonts.ready);
   await page.evaluate(async()=>{for(let y=0;y<document.documentElement.scrollHeight;y+=650){window.scrollTo(0,y);await new Promise(r=>setTimeout(r,35))}window.scrollTo(0,0)});
   await page.waitForFunction(()=>[...document.images].every(i=>i.complete || i.offsetParent === null));
   await page.screenshot({path:`${output}/${name}-${width}.jpg`,type:'jpeg',quality:85,fullPage:true});
   if(width===1440) await page.screenshot({path:`${output}/${name}-1440-viewport.jpg`,type:'jpeg',quality:85});
   const layout=await page.evaluate(()=>({overflow:document.documentElement.scrollWidth>innerWidth,height:document.documentElement.scrollHeight,form:document.querySelector('form.auth-form')?.getBoundingClientRect().toJSON(),heroImage:document.querySelector('.landing-hero img')?.getBoundingClientRect().toJSON()}));
   report.push({name,width,status:response.status(),...layout,errors:[...errors]});
  }
  await page.close();
 }
 fs.writeFileSync(`${root}/docs/redesign-publico/${phase}.json`,JSON.stringify(report,null,2));
 await browser.close();
 console.log(JSON.stringify(report.map(({name,width,status,overflow,errors})=>({name,width,status,overflow,errors}))));
})().catch(e=>{console.error(e);process.exit(1)});
