#!/usr/bin/env node
// Helper for b-desktop-test. One JSON object on stdout. Exit: 0 ok, 1 usage/error, 2 timeout, 3 an ERROR line was seen.
//   start  <story> [--log <path>]       create a run id + the flag file that the add-in's TestProbe reads
//   stop                                 delete the flag file
//   wait   <run> <case> [--timeout s]    wait for "[ATEST] run=<run> case=<case> DONE" (or ERROR), print that case's lines
//   lines  <run> [<case>]                print the [ATEST] lines of this run only (never other runs or other log lines)
//   fixture <src> [--confirmed]          copy a test model to %TEMP%\AddinTest\<run>\ and print SHA-256 (original is never opened)
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';

const BASE = path.join(process.env.LOCALAPPDATA || path.join(os.homedir(), 'AppData', 'Local'), 'AddinTest');
const FLAG = path.join(BASE, 'atest.json');
const out = (o, code = 0) => { console.log(JSON.stringify(o)); process.exit(code); };
const [cmd, ...rest] = process.argv.slice(2);
const VALUE_OPTS = new Set(['--log', '--timeout']);
const opt = (n, d) => { const i = rest.indexOf(n); return i >= 0 ? rest[i + 1] : d; };
const pos = rest.filter((a, i) => !a.startsWith('--') && !VALUE_OPTS.has(rest[i - 1]));
const readFlag = () => { try { return JSON.parse(fs.readFileSync(FLAG, 'utf8')); } catch { return null; } };
const logOf = () => (readFlag() || {}).log || path.join(BASE, 'atest.log');
const tokens = (line) => line.split(/\s+/);

function linesOf(run, caseId) {
  let text = '';
  try { text = fs.readFileSync(logOf(), 'utf8'); } catch { return []; }
  const result = [];
  for (const raw of text.split(/\r?\n/)) {
    const at = raw.indexOf('[ATEST]');
    if (at < 0) continue;
    const line = raw.slice(at);
    const t = tokens(line);
    if (!t.includes('run=' + run)) continue;
    if (caseId && !t.includes('case=' + caseId)) continue;
    result.push(line);
  }
  return result;
}

if (cmd === 'start') {
  const story = pos[0];
  if (!story) out({ error: 'usage: start <story> [--log path]' }, 1);
  fs.mkdirSync(BASE, { recursive: true });
  const run = crypto.randomBytes(3).toString('hex');
  const log = opt('--log', path.join(BASE, 'atest.log'));
  fs.mkdirSync(path.dirname(log), { recursive: true });
  fs.writeFileSync(FLAG, JSON.stringify({ run, story, log, started: new Date().toISOString() }));
  out({ run, story, log, flag: FLAG });
} else if (cmd === 'stop') {
  try { fs.unlinkSync(FLAG); } catch { /* already gone */ }
  out({ stopped: true });
} else if (cmd === 'lines') {
  if (!pos[0]) out({ error: 'usage: lines <run> [<case>]' }, 1);
  out({ run: pos[0], lines: linesOf(pos[0], pos[1]) });
} else if (cmd === 'wait') {
  const run = pos[0];
  const caseId = pos[1];
  const timeoutMs = Number(opt('--timeout', '60')) * 1000;
  if (!run || !caseId) out({ error: 'usage: wait <run> <case> [--timeout s]' }, 1);
  const t0 = Date.now();
  const tick = () => {
    const ls = linesOf(run, caseId);
    if (ls.some(l => tokens(l).includes('ERROR'))) out({ status: 'ERROR', lines: ls }, 3);
    if (ls.some(l => tokens(l).includes('DONE'))) out({ status: 'DONE', lines: ls }, 0);
    if (Date.now() - t0 > timeoutMs) out({ status: 'TIMEOUT', lines: ls }, 2);
    setTimeout(tick, 500);
  };
  tick();
} else if (cmd === 'fixture') {
  const src = pos[0];
  if (!src) out({ error: 'usage: fixture <src> [--confirmed]' }, 1);
  const abs = path.resolve(src);
  let allowed = rest.includes('--confirmed');
  if (!allowed) {
    try {
      const cfg = JSON.parse(fs.readFileSync(path.join(process.cwd(), '.harness', 'addin-story.json'), 'utf8'));
      const list = [].concat(cfg.testFixtures && cfg.testFixtures !== 'none' ? cfg.testFixtures : []);
      const norm = (p) => path.resolve(String(p)).toLowerCase();
      allowed = list.some(f => norm(abs) === norm(f) || norm(abs).startsWith(norm(f) + path.sep));
    } catch { /* no config -> not allowed */ }
  }
  if (!allowed) out({ error: 'not under testFixtures and not --confirmed by the user' }, 1);
  if (!fs.existsSync(abs) || !fs.statSync(abs).isFile()) out({ error: 'file not found: ' + abs }, 1);
  const run = (readFlag() || {}).run || crypto.randomBytes(3).toString('hex');
  const dir = path.join(os.tmpdir(), 'AddinTest', run);
  fs.mkdirSync(dir, { recursive: true });
  const dst = path.join(dir, path.basename(abs));
  fs.copyFileSync(abs, dst);
  const sha = (f) => crypto.createHash('sha256').update(fs.readFileSync(f)).digest('hex');
  out({ original: abs, copy: dst, sha256: sha(abs), copySha256: sha(dst) });
} else {
  out({ error: 'usage: atest.mjs start|stop|wait|lines|fixture ...' }, 1);
}
