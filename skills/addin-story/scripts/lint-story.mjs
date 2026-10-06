#!/usr/bin/env node
// Lint a ticket .md produced by redmine-us-writer(-verified) before addin-story consumes it.
// Usage: node lint-story.mjs <file.md> [--json]
// Exit: 0 = ok (verified format, no errors) | 1 = blocking errors | 2 = legacy format (contract must be upgraded)
import { readFileSync } from 'node:fs';

const file = process.argv[2];
const asJson = process.argv.includes('--json');
if (!file) { console.error('Usage: node lint-story.mjs <file.md> [--json]'); process.exit(64); }

const text = readFileSync(file, 'utf8').replace(/^\uFEFF/, '');
const lines = text.split(/\r?\n/);
const errors = [], warnings = [], info = {};

// ---------- headings & sections ----------
const headings = [];
lines.forEach((l, i) => { const m = /^(#{1,6})\s+(.*)$/.exec(l); if (m) headings.push({ i, level: m[1].length, title: m[2].trim() }); });
const sectionRange = (re) => {
  const h = headings.find(x => re.test(x.title));
  if (!h) return null;
  const next = headings.find(x => x.i > h.i && x.level <= h.level);
  return { start: h.i, end: next ? next.i : lines.length, title: h.title };
};
const contract = sectionRange(/Hợp đồng kiểm thử|Accept case|Acceptance criteria|Tiêu chí chấp nhận/i);

// ---------- header fields ----------
const typeLine = lines.find(l => /^\s*-\s*Loại\s*:/i.test(l)) || '';
const typeRaw = typeLine.replace(/^\s*-\s*Loại\s*:\s*/i, '');
const type = /^\s*bug/i.test(typeRaw) ? 'BUG' : /^\s*(impl|implementation)/i.test(typeRaw) ? 'IMPL'
  : /^\s*task/i.test(typeRaw) ? 'TASK' : /^\s*(us|user story)/i.test(typeRaw) ? 'US' : 'UNKNOWN';
const idMatch = /^#\s*\[#?(\d+)\]/.exec(lines.find(l => /^#\s/.test(l)) || '');
info.id = idMatch ? idMatch[1] : null;
info.type = type;
if (type === 'UNKNOWN') errors.push('Không xác định được loại ticket (thiếu dòng "- Loại: Bug/Task/US/Implementation").');
if (!info.id) warnings.push('Không đọc được ID ticket từ tiêu đề "# [#ID] ...".');

// ---------- tables ----------
const splitRow = (l) => l.trim().replace(/^\|/, '').replace(/\|$/, '').split('|').map(c => c.trim());
const tables = [];
for (let i = 0; i < lines.length; i++) {
  if (/^\s*\|/.test(lines[i]) && i + 1 < lines.length && /^\s*\|\s*:?-{2,}/.test(lines[i + 1])) {
    const header = splitRow(lines[i]); const rows = []; let j = i + 2;
    while (j < lines.length && /^\s*\|/.test(lines[j])) { rows.push({ line: j + 1, cells: splitRow(lines[j]) }); j++; }
    tables.push({ line: i + 1, header, rows }); i = j - 1;
  }
}
const col = (header, re) => header.findIndex(h => re.test(h.replace(/\*/g, '')));
const caseTable = tables.find(t => col(t.header, /^(ID|#|Mã)$/i) >= 0 && col(t.header, /Kết quả đúng|Expected/i) >= 0);
const traceTable = tables.find(t => /Yêu cầu|^R$/i.test(t.header[0]) && t.header.some(h => /Case/i.test(h)));

// ---------- requirement ids R<n> (defined outside the contract section) ----------
const definedR = new Set();
lines.forEach((l, i) => {
  if (contract && i >= contract.start && i < contract.end) return;
  const m = /^\s*(?:[-*]\s*|\d+\.\s*)?(?:\*\*)?\[?(R\d+)\]?(?:\*\*)?\s*[:.)\-–—|]/.exec(l) || /^\s*\|\s*\**(R\d+)\**\s*\|/.exec(l)
    || /^#{2,6}\s+(R\d+)\b/.exec(l);
  if (m) definedR.add(m[1]);
});
if (traceTable) traceTable.rows.forEach(r => { const m = /R\d+/.exec(r.cells[0]); if (m) definedR.add(m[0]); });

// ---------- format detection ----------
const h = caseTable ? caseTable.header : [];
const idx = caseTable ? {
  id: col(h, /^(ID|#|Mã)$/i), r: col(h, /^R$|^Yêu cầu$/i), kind: col(h, /^Loại$/i), level: col(h, /^Cấp$/i),
  input: col(h, /Đầu vào|Điều kiện/i), action: col(h, /Thao tác/i), expected: col(h, /Kết quả đúng/i),
  wrong: col(h, /Kết quả sai/i), evidence: col(h, /Bằng chứng/i), verifier: col(h, /Xác nhận/i),
} : {};
const verified = !!caseTable && [idx.r, idx.level, idx.evidence, idx.verifier].every(x => x >= 0);
info.format = !caseTable ? 'none' : verified ? 'verified' : 'legacy';
if (!contract) warnings.push('Không thấy mục "Hợp đồng kiểm thử".');
if (!caseTable) errors.push('Không có bảng accept case (cần cột ID và "Kết quả đúng").');
if (caseTable && !verified) {
  const miss = [['R', idx.r], ['Cấp', idx.level], ['Bằng chứng bắt buộc', idx.evidence], ['Xác nhận bởi', idx.verifier]]
    .filter(([, v]) => v < 0).map(([n]) => n);
  warnings.push(`Định dạng writer cũ: bảng case thiếu cột ${miss.join(', ')}. Lead phải nâng cấp hợp đồng (đánh dấu [Bổ sung bởi lead]) và đưa vào gate duyệt.`);
}

// ---------- case checks ----------
const VAGUE = /(?<!\p{L})(nhanh|hợp lý|ổn định|phù hợp|tối ưu|mượt|chính xác|đẹp)(?!\p{L})/iu;
const GENERIC_INPUT = /dữ liệu (hợp lệ|thật|bất kỳ)|^\s*$|^\.\.\.$/i;
const SELF_VERIFY = /dev agent|người làm|agent viết code|tự xác nhận|implementer/i;
const cases = [];
const caseR = new Map();
if (caseTable) {
  for (const row of caseTable.rows) {
    const c = (k) => (idx[k] >= 0 ? (row.cells[idx[k]] || '') : '');
    const id = (/AC-?\d+/i.exec(c('id')) || [])[0];
    if (!id) continue;
    const kind = c('kind');
    const blank = /Bỏ trống|Không áp dụng/i.test(kind) || /^Không áp dụng/i.test(c('expected'));
    const level = (/\b([ABE])\b/.exec(c('level')) || [])[1] || null;
    const critical = /\[?Critical\]?/i.test(row.cells.join(' '));
    const rs = (c('r').match(/R\d+/g) || []);
    cases.push({ id, kind, level, critical, blank, r: rs, verifier: c('verifier'), line: row.line });
    if (blank) { warnings.push(`${id} (dòng ${row.line}) bỏ trống trong ticket gốc — không lập task, nêu lại ở gate.`); continue; }
    rs.forEach(r => { if (!caseR.has(r)) caseR.set(r, []); caseR.get(r).push(id); });
    if (!c('expected')) errors.push(`${id}: thiếu "Kết quả đúng".`);
    if (GENERIC_INPUT.test(c('input'))) warnings.push(`${id}: đầu vào không cụ thể ("${c('input') || 'trống'}").`);
    if (VAGUE.test(c('expected'))) warnings.push(`${id}: kết quả đúng có từ mơ hồ ("${(VAGUE.exec(c('expected')) || [])[0]}") — cần ngưỡng/giá trị.`);
    if (verified) {
      if (!rs.length) errors.push(`${id}: không trỏ về R nào.`);
      rs.filter(r => definedR.size && !definedR.has(r)).forEach(r => errors.push(`${id}: trỏ về ${r} không tồn tại.`));
      if (!level) errors.push(`${id}: thiếu Cấp A/B/E.`);
      if (!c('evidence')) errors.push(`${id}: thiếu "Bằng chứng bắt buộc".`);
      if (!c('verifier')) errors.push(`${id}: thiếu "Xác nhận bởi".`);
      else if (SELF_VERIFY.test(c('verifier'))) errors.push(`${id}: người xác nhận là chính bên làm ("${c('verifier')}").`);
      if (!/nguồn/i.test(c('expected'))) warnings.push(`${id}: "Kết quả đúng" không ghi nguồn độc lập.`);
      if (critical && !/người|human|QA|BA|PO|lead/i.test(c('verifier'))) errors.push(`${id}: [Critical] nhưng không do người xác nhận.`);
    }
  }
}
if (verified) {
  if (!definedR.size) errors.push('Không tìm thấy mã yêu cầu R1, R2... ngoài bảng case.');
  [...definedR].filter(r => !caseR.has(r)).forEach(r => errors.push(`${r} chưa có case nào phủ.`));
  if (type === 'TASK' || type === 'IMPL') {
    for (const [r, ids] of caseR) {
      const kinds = cases.filter(x => ids.includes(x.id)).map(x => x.kind).join(' ');
      if (!/Biên|Lỗi|negative/i.test(kinds)) warnings.push(`${r}: chưa có case biên hoặc lỗi.`);
    }
  }
  if (!cases.some(x => /hồi quy/i.test(x.kind))) warnings.push('Không có case "Không hồi quy".');
}
if (type === 'BUG' && !cases.some(x => /Tái hiện/i.test(x.kind)))
  errors.push('Bug nhưng không có case "Tái hiện lỗi gốc" (phải FAIL trước khi sửa).');
if (!/Quy tắc thực thi và kiểm chứng/i.test(text) && verified)
  warnings.push('Thiếu mục "Quy tắc thực thi và kiểm chứng cho dev agent".');

const live = cases.filter(x => !x.blank);
info.requirements = [...definedR].sort((a, b) => +a.slice(1) - +b.slice(1));
info.cases = live.length;
info.levelA = live.filter(x => x.level === 'A').length;
info.levelB = live.filter(x => x.level === 'B').length;
info.levelE = live.filter(x => x.level === 'E').length;
info.unleveled = live.filter(x => !x.level).length;
info.critical = live.filter(x => x.critical).length;
info.assumptions = (text.match(/\[Giả định\]/g) || []).length;
info.unknowns = (text.match(/UNKNOWN|Chờ người xác nhận|chưa có trong ticket/gi) || []).length;

const status = errors.length ? 'error' : info.format === 'verified' ? 'ok' : 'legacy';
if (asJson) {
  console.log(JSON.stringify({ file, status, info, errors, warnings, cases: live }, null, 2));
} else {
  console.log(`File: ${file}\nStatus: ${status} | format=${info.format} | type=${info.type} | id=${info.id}`);
  console.log(`R: ${info.requirements.join(', ') || '-'} | cases=${info.cases} (A=${info.levelA}, E=${info.levelE}, B=${info.levelB}, chưa phân cấp=${info.unleveled}, Critical=${info.critical}) | [Giả định]=${info.assumptions}`);
  if (errors.length) console.log('\nLỖI (chặn):\n' + errors.map(e => ' - ' + e).join('\n'));
  if (warnings.length) console.log('\nCẢNH BÁO:\n' + warnings.map(e => ' - ' + e).join('\n'));
}
process.exit(status === 'error' ? 1 : status === 'legacy' ? 2 : 0);
