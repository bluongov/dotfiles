import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";
import { ComplexityPolicy, LUNA, SOL } from "./policy.mjs";

const host = "/home/bluongo/.nvm/versions/node/v24.15.0/lib/node_modules/@earendil-works/pi-coding-agent";
const requireHost = createRequire(`${host}/package.json`);
const { createJiti } = requireHost("jiti");
const alias = Object.fromEntries(["pi-coding-agent", "pi-ai", "pi-agent-core", "pi-tui"].map(name => {
  const full = `@earendil-works/${name}`;
  return [full, name === "pi-coding-agent" ? `${host}/dist/index.js` : `${host}/node_modules/${full}/dist/${name === "pi-ai" ? "compat" : "index"}.js`];
}));
for (const name of ["typebox", "typebox/compile", "typebox/value"]) alias[name] = requireHost.resolve(name);
const jiti = createJiti(import.meta.url, { alias });
const { createSelectiveExtension, requestTimeAuthContext } = await jiti.import("./index.ts");

test("Copilot nested streams use request-time auth; other providers keep overrides", () => {
  const calls=[];
  const registry={streamSimple:(model,_context,options)=>{calls.push({model,options});return "stream";}};
  const ctx=requestTimeAuthContext({modelRegistry:registry,cwd:"/tmp"});
  const options={apiKey:"test-resolved-token",reasoning:"high",headers:{"x-test":"yes"}};
  assert.equal(ctx.modelRegistry.streamSimple({provider:"github-copilot"},{},options),"stream");
  assert.equal(calls[0].options.apiKey,undefined);
  assert.equal(calls[0].options.reasoning,"high");
  assert.deepEqual(calls[0].options.headers,options.headers);
  ctx.modelRegistry.streamSimple({provider:"custom-provider"},{},options);
  assert.equal(calls[1].options.apiKey,"test-resolved-token");
});

test("simple tasks and orchestration polling stay unreviewed", () => {
  const p = new ComplexityPolicy();
  for (let i = 0; i < 100; i++) p.recordTool(`poll-${i}`, "subagent", {action:"status"});
  for (let i = 0; i < 24; i++) p.recordTool(`read-${i}`, "read");
  p.recordTool("container", "codemode");
  assert.equal(p.desired(), null);
  p.recordTool("read-24", "read");
  assert.equal(p.desired(), LUNA);
});
test("nested tool ids are counted once", () => {
  const p = new ComplexityPolicy();
  p.recordTool("parent/1", "read"); p.recordTool("parent/1", "read");
  assert.equal(p.tools, 1);
});
test("three delegates enable Luna; eight escalate to Sol", () => {
  const p = new ComplexityPolicy();
  for (let i = 0; i < 3; i++) p.recordTool(String(i), "subagent", {agent:"scout"});
  assert.equal(p.desired(), LUNA);
  for (let i = 3; i < 8; i++) p.recordTool(String(i), "subagent", {agent:"scout"});
  assert.equal(p.desired(), SOL);
});
test("workflow child starts are deduplicated", () => {
  const p = new ComplexityPolicy();
  p.recordChild("root", "a"); p.recordChild("root", "a");
  p.recordChild("root", "b"); p.recordChild("root", "c");
  assert.equal(p.delegates, 3);
  assert.equal(p.desired(), LUNA);
});
test("length alone does not escalate Luna to Sol", () => {
  const p = new ComplexityPolicy();
  for (let i = 0; i < 60; i++) p.recordTool(String(i), "read");
  assert.equal(p.desired(), LUNA);
  p.failures = 3;
  assert.equal(p.desired(), SOL);
});
test("manual modes override heuristics; a new task resets automatic counts", () => {
  const p = new ComplexityPolicy();
  p.delegates = 8; p.mode = "off"; assert.equal(p.desired(), null);
  p.mode = "luna"; assert.equal(p.desired(), LUNA);
  p.mode = "sol"; p.resetTask(); assert.equal(p.desired(), SOL);
  p.mode = "auto"; assert.equal(p.desired(), null);
});
test("workflow starts do not double-count legacy planned arrays", () => {
  const p = new ComplexityPolicy();
  p.recordTool("dispatch", "subagent", {workflow:true,tasks:[{agent:"scout"},{agent:"scout"},{agent:"scout"},{agent:"scout"}]});
  for (let i=0;i<4;i++) p.recordChild("root",String(i));
  assert.equal(p.delegates, 4);
  assert.equal(p.desired(), LUNA);
});

function fixture(failModels = false) {
  const handlers = new Map(), commands = new Map(), tools = new Map(), listeners = new Map();
  const state = {enabled:false, model:null, calls:[], notices:[], messages:[], boundaryEnabled:[]};
  const pi = {
    on(name, handler) { const list=handlers.get(name)??[]; list.push(handler); handlers.set(name,list); return () => {}; },
    registerCommand(name, command) { commands.set(name, command); },
    registerTool(tool) { tools.set(tool.name, tool); },
    sendMessage(message) { state.messages.push(message); },
    events: {
      on(name, handler) { listeners.set(name,handler); return () => listeners.delete(name); },
      emit(name, event) { listeners.get(name)?.(event); },
    },
  };
  const upstream = api => {
    api.on("agent_end", () => { state.boundaryEnabled.push(state.enabled); });
    api.registerCommand("subagents-watchdog", {handler:async (args) => {
    state.calls.push(args);
    if (args === "session on") state.enabled=true;
    if (args === "session off") state.enabled=false;
    if (args.startsWith("session model ") && failModels) {
      api.sendMessage({content:"Subagent watchdog session model\n\nModel unavailable."});
      return;
    }
    if (args.startsWith("session model ")) state.model=args.slice(14);
    api.sendMessage({content:args.startsWith("session model ") ? "Subagent watchdog session model: selected." : "Subagent watchdog session override: selected."});
    }});
  };
  createSelectiveExtension(upstream)(pi);
  const ctx={cwd:"/tmp",ui:{notify:(text)=>state.notices.push(text),setStatus:()=>{}}};
  const emit = async (name,event={}) => { for(const handler of handlers.get(name)??[]) await handler(event,ctx); };
  return {pi,state,commands,tools,ctx,emit};
}

test("adapter enables once at threshold and resets on new real input", async () => {
  const f=fixture(); await f.emit("session_start");
  for(let i=0;i<24;i++) await f.emit("tool_execution_start",{toolCallId:String(i),toolName:"read",args:{}});
  assert.equal(f.state.enabled,false);
  await f.emit("tool_execution_start",{toolCallId:"24",toolName:"read",args:{}});
  assert.equal(f.state.enabled,true); assert.equal(f.state.model,`${LUNA}:high`);
  await f.emit("tool_execution_start",{toolCallId:"25",toolName:"read",args:{}});
  assert.equal(f.state.calls.filter(s=>s==="session on").length,1);
  await f.emit("input",{source:"extension",text:"Subagent updates above."});
  assert.equal(f.state.enabled,true);
  await f.emit("input",{source:"interactive",text:"Explain this one line."});
  assert.equal(f.state.enabled,false);
  assert.deepEqual(f.state.messages,[]);
});
test("adapter counts workflow children and supports explicit Sol/off", async () => {
  const f=fixture(); await f.emit("session_start");
  f.pi.events.emit("subagent:async-started",{id:"root",mode:"workflow"});
  for(const childId of ["a","b","c"]) f.pi.events.emit("subagent:child-status",{runId:"root",childId,status:"started"});
  await f.emit("agent_end"); assert.equal(f.state.enabled,true);
  assert.deepEqual(f.state.boundaryEnabled,[true]);
  await f.commands.get("complex-watchdog").handler("sol",f.ctx);
  assert.equal(f.state.model,`${SOL}:high`);
  await f.commands.get("complex-watchdog").handler("off",f.ctx);
  assert.equal(f.state.enabled,false);
  await f.emit("session_shutdown");
});
test("invalid controls fail closed", async () => {
  const f=fixture(); await f.emit("session_start");
  await assert.rejects(f.commands.get("complex-watchdog").handler("invalid",f.ctx),/Use status/);
  assert.equal(f.state.enabled,false);
});
test("adapter reports model selection failure instead of claiming it enabled", async () => {
  const f=fixture(true); await f.emit("session_start");
  await assert.rejects(f.commands.get("complex-watchdog").handler("luna",f.ctx),/Model unavailable/);
  assert.equal(f.state.enabled,false);
  assert.equal(f.state.model,null);
  assert.ok(f.state.notices.some(text=>text.includes("Model unavailable")));
});

const { MainWatchdogRuntime } = await jiti.import("/home/bluongo/.pi/agent/npm/node_modules/pi-subagents/src/watchdog/runtime.js");
const { resolveWatchdogConfig } = await jiti.import("/home/bluongo/.pi/agent/npm/node_modules/pi-subagents/src/watchdog/settings.js");
function runtimeFixture(change = false) {
  const configResult = resolveWatchdogConfig("/tmp");
  configResult.config.enabled = true;
  configResult.config.main.enabled = true;
  configResult.config.lsp.enabled = false;
  let changed = false, calls = 0;
  const runtime = new MainWatchdogRuntime({
    resolveConfig: () => configResult,
    reviewChangesOnly: true,
    repoChangeSignature: () => change ? {root:"/tmp",key:changed?"after":"before",changedPaths:changed?["demo.js"]:[]} : undefined,
    displayClarification: () => {},
    review: async () => { calls++; return {warnings:[]}; },
  });
  const ctx = {cwd:"/tmp"};
  runtime.bindSession(ctx);
  runtime.handleBeforeAgentStart({prompt:"Inspect this difficult multi-agent task."},ctx);
  return {runtime,ctx,calls:()=>calls,setChanged:()=>{changed=true;}};
}
test("real upstream runtime reviews orchestration evidence without a repo diff", async () => {
  const f=runtimeFixture();
  assert.equal(f.runtime.getSnapshot().config.clarification,true);
  f.runtime.handleTurnEnd({
    type:"turn_end",
    message:{role:"assistant",content:[{type:"toolCall",id:"delegate-1",name:"subagent",arguments:{agent:"scout",task:"Inspect correctness"}}]},
    toolResults:[{role:"toolResult",toolCallId:"delegate-1",toolName:"subagent",content:[{type:"text",text:"Found a missing input check."}],isError:false}],
  },f.ctx);
  await f.runtime.handleAgentEnd({},f.ctx);
  assert.equal(f.calls(),1);
  f.runtime.dispose();
});
test("real upstream runtime reviews modified code at the boundary", async () => {
  const f=runtimeFixture(true); f.setChanged();
  f.runtime.handleTurnEnd({
    type:"turn_end",
    message:{role:"assistant",content:[{type:"toolCall",id:"write-1",name:"write",arguments:{path:"demo.js",content:"function demo() {}"}}]},
    toolResults:[{role:"toolResult",toolCallId:"write-1",toolName:"write",content:[{type:"text",text:"Wrote demo.js"}],isError:false}],
  },f.ctx);
  await f.runtime.handleAgentEnd({},f.ctx);
  assert.equal(f.calls(),1);
  f.runtime.dispose();
});
