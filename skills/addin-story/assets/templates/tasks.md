---
us: <ID>
status: draft
approved_by:
updated: <YYYY-MM-DD>
---
# Tasks — <ID>

## Bảng truy vết (mọi R và mọi case cấp A/B phải xuất hiện)
| R | Case | Task | Test / bằng chứng |
|---|---|---|---|

## Danh sách task (lát dọc: mỗi task cho ra một hành vi quan sát được, ≤ ~400 dòng đổi)

### T1: <hành vi người dùng thấy được>
- **Mục tiêu:**
- **Phủ:** R1 · AC-01, AC-02
- **File sở hữu (chỉ task này được sửa):**
- **Test cần viết trước (cấp A):** <tên test → case → giá trị kỳ vọng + nguồn>
- **Cổng test (nếu task đổi model):** <entry chính + entry bước + file hợp đồng; prompt id>
- **Bằng chứng cấp B cần thu:** <case → model/DWG, thao tác, giá trị, dung sai>
- **Hoàn thành khi:** build mọi solution xanh · case E chạy qua cổng test và MATCH (có report) · test mới pass (đã từng FAIL) · test cũ không hỏng · không vi phạm rule chặn
- **Phụ thuộc:** — | **Song song với:** — | **Rủi ro:** low
- **Trạng thái:** todo | in-progress | ready-to-push | in-review | done
- **Eval:** <eval-T1-n.md → verdict>
