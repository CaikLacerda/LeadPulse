const { chromium } = require('playwright');
const fs=require('fs');const assert=require('assert/strict');
const root=require('path').resolve(__dirname, '../../..');
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.BROWSER_EXECUTABLE,args:['--no-sandbox','--disable-dev-shm-usage']});
 const page=await browser.newPage({viewport:{width:1440,height:900},reducedMotion:'reduce',colorScheme:'light'});
 const consoleErrors=[];page.on('pageerror',e=>consoleErrors.push(e.message));page.on('console',m=>{if(m.type()==='error')consoleErrors.push(m.text())});
 const results=[];
 for(const width of [390,768,1024,1440,1920]){
  await page.setViewportSize({width,height:width===390?844:900});
  for(const [name,path] of [['landing','/'],['login','/users/sign_in'],['cadastro','/users/sign_up']]){
   await page.goto((process.env.PUBLIC_UI_URL || 'http://127.0.0.1:3107')+path,{waitUntil:'networkidle'});
   await page.addScriptTag({path:require.resolve('axe-core/axe.min.js')});
   const axe=await page.evaluate(async()=>{const r=await axe.run(document,{runOnly:{type:'tag',values:['wcag2a','wcag2aa','wcag21aa','best-practice']}});return {violations:r.violations.map(v=>({id:v.id,impact:v.impact,description:v.description,nodes:v.nodes.map(n=>({target:n.target,summary:n.failureSummary}))})),incomplete:r.incomplete.map(v=>v.id)}});
   results.push({name,width,...axe});
  }
 }
 fs.writeFileSync(root+'/docs/redesign-publico/acessibilidade.json',JSON.stringify({axeVersion:require('axe-core/package.json').version,results,consoleErrors},null,2));
 await page.setViewportSize({width:390,height:844});
 await page.goto((process.env.PUBLIC_UI_URL || 'http://127.0.0.1:3107')+'/',{waitUntil:'networkidle'});
 const menu=page.locator('.site-header__toggle');await menu.focus();await page.keyboard.press('Enter');assert.equal(await menu.getAttribute('aria-expanded'),'true');
 await page.keyboard.press('Tab');assert.match(await page.locator(':focus').textContent(),/Início/);await page.keyboard.press('Escape');assert.equal(await menu.getAttribute('aria-expanded'),'false');assert.equal(await menu.evaluate(e=>e===document.activeElement),true);
 await menu.click();await page.locator('.site-mobile-menu__link').filter({hasText:'Recursos'}).click();assert.equal(await menu.getAttribute('aria-expanded'),'false');
 await page.goto((process.env.PUBLIC_UI_URL || 'http://127.0.0.1:3107')+'/users/sign_in',{waitUntil:'networkidle'});
 const password=page.locator('#user_password');await password.fill('ui-check-only');const toggle=page.getByRole('button',{name:'Mostrar senha'});await toggle.focus();await page.keyboard.press('Enter');assert.equal(await password.getAttribute('type'),'text');assert.equal(await toggle.getAttribute('aria-pressed'),'true');await page.keyboard.press('Space');assert.equal(await password.getAttribute('type'),'password');
 await page.getByRole('checkbox').check();assert.equal(await page.getByRole('checkbox').isChecked(),true);
 await page.getByRole('link',{name:'Esqueceu a senha?'}).click();await page.getByRole('heading',{name:'Recuperar acesso',exact:true}).waitFor();assert.equal(await page.locator('h1').textContent(),'Recuperar acesso');
 for(const [text,path] of [['Termos','/termos'],['Privacidade','/privacidade']]){
  const response=await page.goto((process.env.PUBLIC_UI_URL || 'http://127.0.0.1:3107')+path);assert.equal(response.status(),200);assert.equal(await page.locator('h1').count(),1);
 }
 await page.goto((process.env.PUBLIC_UI_URL || 'http://127.0.0.1:3107')+'/users/sign_up',{waitUntil:'networkidle'});
 await page.locator('#user_email').fill('public-ui-invalid@example.test');await page.locator('#user_password').fill('123');await page.locator('#user_password_confirmation').fill('456');
 await page.getByRole('button',{name:'Criar conta',exact:true}).click();await page.locator('#user_name_error').waitFor();assert.equal(await page.locator('#user_name').getAttribute('aria-invalid'),'true');assert.match(await page.locator('#user_password').getAttribute('aria-describedby'),/password_hint user_password_error/);
 await page.screenshot({path:root+'/docs/redesign-publico/screenshots/depois/cadastro-erros-390.jpg',type:'jpeg',quality:85,fullPage:true});
 fs.writeFileSync(root+'/docs/redesign-publico/acessibilidade.json',JSON.stringify({axeVersion:require('axe-core/package.json').version,results,interactions:'menu keyboard/Escape, anchor, password toggle keyboard, checkbox, reset link, legal links, server validation: passed',consoleErrors},null,2));
 await browser.close();console.log(JSON.stringify({audits:results.length,violations:results.flatMap(r=>r.violations).length,consoleErrors}));
})().catch(e=>{console.error(e);process.exit(1)});
