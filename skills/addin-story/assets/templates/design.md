---
us: <ID>
type: US | TASK | IMPL | BUG
status: draft            # agent chỉ được ghi draft | in-review; approved do người đặt (hoặc bảo agent đặt kèm tên)
approved_by:
updated: <YYYY-MM-DD>
risk: low | medium | high
platform: <Revit 2024 (deploy: 2022–2025) | AutoCAD 2024>
source: <đường dẫn .md của writer + link Redmine>
---
# Thiết kế — <ID> <Tiêu đề>

## 1. Tóm tắt giải pháp
<3–5 câu. Không lặp lại ticket.>

## 2. Ngữ cảnh dự án đã áp dụng
- File quy tắc đã đọc: <AGENTS.md, docs/rules/xxx.md, known-issues…>
- Rule chặn/cao liên quan: <ID rule — 1 dòng mỗi rule>
- Version: compile <năm> · deploy <các năm> → khoá API theo bản thấp nhất <năm>
- Project file đôi / nhiều solution: <danh sách cần cập nhật cùng lúc>
- Known-issue trùng vùng code: <mục hoặc "không">

## 3. Ánh xạ yêu cầu → thành phần
| R | Case (AC) | Module / file | Thay đổi | Layer |
|---|---|---|---|---|

## 4. Tái sử dụng
| Năng lực cần | Layer | Thành phần có sẵn (path) | Quyết định: reuse / extend / new | Lý do |
|---|---|---|---|---|

## 5. Thiết kế
### Tách business / host
| Mối quan tâm | Business (L2/L3) | Host API (L1/L0, generic) |
|---|---|---|
### Kiểu mới / đổi
| Kiểu | Layer | Loại | Trách nhiệm (1 dòng) | new/changed |
|---|---|---|---|---|
### Luồng chính
```mermaid
sequenceDiagram
```

## 6. Host API
| Mục | Quyết định |
|---|---|
| Transaction / undo name | |
| Thread / context (command, modal, modeless → ExternalEvent/dispatcher, LockDocument) | |
| Hiệu năng (collector/selection filter, không transaction/regenerate trong vòng lặp) | |
| Id & lưu trữ (UniqueId/Handle khi lưu ra ngoài phiên) | |
| Đơn vị / toạ độ / dung sai | |
| Version lock (API cấm dùng) | |
| Idempotent khi chạy lại (không tạo trùng) | |

## 7a. Cổng test (quy ước test-entries — xem references/test-entries.md)
| Cổng | Tên | Gọi | ReadOnly | Prompt id (mức, lựa chọn, mặc định) |
|---|---|---|---|---|
| Chính | `feature.action` | `Execute` | không | |
| Phụ | `feature.action.validate` / `.plan` / `.apply` | từng bước | validate, plan: có | |
- File hợp đồng: `docs/specs/test-entries/<feature.action>.yaml` · các bước tách: Validate / Plan / Apply, mỗi bước 1 việc.
- Lệnh ribbon chỉ dựng request và gọi cùng use case: <đúng | ngoại lệ + lý do>.

## 7. Bề mặt tự động hoá (MCP / command / API)
<Nếu dự án có rule "capability mới phải có tool" → tên tool, READ/WRITE, preview/dry-run, validation dùng chung với UI.
Nếu không áp dụng → "N/A – <lý do>" + người phải duyệt theo rule dự án.>

## 8. Chiến lược kiểm chứng (bám test-contract.md, không đổi nghĩa case)
| Case | Cấp | Cách kiểm | Test / script | Oracle (nguồn) |
|---|---|---|---|---|
- Logic thuần tách khỏi host để nâng case từ B lên A: <đề xuất hoặc "không">

## 9. Phương án đã loại
| Phương án | Lý do loại |
|---|---|

## 10. Rủi ro, giả định, quyết định cần người chốt
- UNKNOWN – NEED HUMAN DECISION: <câu hỏi> – người quyết định: <vai trò>
- [Giả định] …
