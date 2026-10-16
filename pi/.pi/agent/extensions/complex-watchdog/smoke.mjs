import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { createRequire } from 'node:module';
import { createHash } from 'node:crypto';
import { createAgentSession, DefaultResourceLoader, SessionManager } from '/home/bluongo/.nvm/versions/node/v24.15.0/lib/node_modules/@earendil-works/pi-coding-agent/dist/index.js';
const host='/home/bluongo/.nvm/versions/node/v24.15.0/lib/node_modules/@earendil-works/pi-coding-agent';
const requireHost=createRequire(`${host}/package.json`);
const {createJiti}=requireHost('jiti');
const aliases={
  '@earendil-works/pi-coding-agent':`${host}/dist/index.js`,
  '@earendil-works/pi-ai':`${host}/node_modules/@earendil-works/pi-ai/dist/compat.js`,
  '@earendil-works/pi-agent-core':`${host}/node_modules/@earendil-works/pi-agent-core/dist/index.js`,
  '@earendil-works/pi-tui':`${host}/node_modules/@earendil-works/pi-tui/dist/index.js`,
};
for(const name of ['typebox','typebox/compile','typebox/value']) aliases[name]=requireHost.resolve(name);
const jiti=createJiti(import.meta.url,{alias:aliases});
const {requestTimeAuthContext}=await jiti.import('/home/bluongo/.pi/agent/extensions/complex-watchdog/index.ts');
const {createMainWatchdogReview}=await jiti.import('/home/bluongo/.pi/agent/npm/node_modules/pi-subagents/src/watchdog/review.js');
const {resolveWatchdogConfigStrict}=await jiti.import('/home/bluongo/.pi/agent/npm/node_modules/pi-subagents/src/watchdog/settings.js');
const cwd=fs.mkdtempSync(path.join(os.tmpdir(),'pi-complex-watchdog-smoke-'));
fs.writeFileSync(path.join(cwd,'demo.js'),'export function add(a, b) { return a - b; }\n');
const settingsPath='/home/bluongo/.pi/agent/settings.json';
const digest=()=>createHash('sha256').update(fs.readFileSync(settingsPath)).digest('hex');
const before=digest();
const errors=[],warnings=[];
let reviewResult;
const loader=new DefaultResourceLoader({
  cwd,agentDir:'/home/bluongo/.pi/agent',noExtensions:true,
  additionalExtensionPaths:['/home/bluongo/.pi/agent/extensions/complex-watchdog/index.ts'],
  extensionFactories:[pi=>pi.registerCommand('watchdog-smoke',{
    description:'Disposable read-only watchdog smoke test',
    handler:async (_args,ctx)=>{
      const config=resolveWatchdogConfigStrict(cwd);
      reviewResult=await createMainWatchdogReview(()=>requestTimeAuthContext(ctx))({
        config,reviewId:1,epoch:0,hasScope:true,allowClarification:false,
        signal:AbortSignal.timeout(90000),
        delta:'SMOKE TEST SCENARIO: The intended API is add(a,b), which must return the arithmetic sum. The simulated parent has implemented demo.js as export function add(a,b) { return a - b; } and claims the addition implementation is complete. Inspect this file and report any concrete correctness problem. No tests were executed. This disposable fixture is separate from the real user workspace.',
        emitWarning:warning=>{warnings.push(warning);return true;},
      });
    },
  })],
});
await loader.reload();
assert.deepEqual(loader.getExtensions().errors,[]);
const {session}=await createAgentSession({cwd,resourceLoader:loader,sessionManager:SessionManager.inMemory(cwd)});
try{
  await session.bindExtensions({mode:'print',onError:event=>errors.push(event)});
  await session.prompt('/complex-watchdog luna');
  await session.prompt('/subagents-watchdog check');
  await session.prompt('/complex-watchdog sol');
  await session.prompt('/subagents-watchdog check');
  const checks=session.messages.filter(m=>m.role==='custom'&&typeof m.content==='string'&&m.content.includes('config check')).map(m=>m.content);
  console.log('Model/auth checks:',checks.map(text=>text.split('\n').filter(line=>line.includes('model:')||line==='Config: ok')));
  assert.ok(checks.some(text=>text.includes('github-copilot/gpt-6-luna auth ok')));
  assert.ok(checks.some(text=>text.includes('github-copilot/gpt-6.1-sol auth ok')));
  await session.prompt('/complex-watchdog auto');
  if(process.env.PI_WATCHDOG_LIVE_SMOKE==='1'){
    await session.prompt('/watchdog-smoke');
    assert.equal(reviewResult.stopReason,'stop',JSON.stringify(reviewResult));
    assert.ok(warnings.length>0,'Luna should identify the deliberate arithmetic bug');
    console.log('Live Luna findings:',warnings.map(w=>({severity:w.severity,summary:w.summary})));
  }
  assert.deepEqual(errors,[]);
  assert.equal(digest(),before,'session commands must not modify persistent settings');
  assert.equal(fs.readFileSync(path.join(cwd,'demo.js'),'utf8'),'export function add(a, b) { return a - b; }\n','review must not edit the fixture');
  console.log('Smoke test passed. Fixture:',cwd);
}finally{
  await session.abort();
  await session.extensionRunner.emit({type:'session_shutdown',reason:'quit'});
  session.dispose();
}
