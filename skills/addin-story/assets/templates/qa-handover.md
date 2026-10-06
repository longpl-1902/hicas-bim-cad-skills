---
us: <ID>
status: draft
approved_by:
updated: <YYYY-MM-DD>
---
# Bàn giao — <ID> <Tiêu đề>

- Nhánh / commit local: <branch @ hash, hoặc "chưa commit">
- Build: <lệnh từng solution → exit code>
- Test: <lệnh → n pass / fail / skip>
- Eval độc lập: <eval-T<n>-k.md → verdict, cho từng task>

## Kết quả theo case (mẫu báo cáo của writer)
| Case | R | Cấp | Trạng thái | Bằng chứng (lệnh / output / file evidence / commit) | Xác nhận bởi |
|---|---|---|---|---|---|
> Trạng thái chỉ được là: Pass có bằng chứng · Fail · Chờ xác nhận · Chưa chạy được (lý do).
> Cấp B và [Critical] không bao giờ là Pass khi chưa có người xác nhận.
> Cấp E: máy đã chạy qua cổng test — ghi đường dẫn report vào cột bằng chứng; người chỉ xác nhận kết quả, không cần kịch bản tay.
> Bằng chứng máy (HicasTest, nếu có): `MATCH / MISMATCH / NOT-RUN / ERROR` chỉ là bằng chứng, không phải Pass;
> trạng thái tối đa là "Chờ xác nhận — có bằng chứng máy".
> Trong giai đoạn đo độ chính xác: **chạy kịch bản tay trước**, ghi kết quả, rồi mới mở báo cáo máy;
> điền `human_verdict` / `disagreement_cause` vào `b-auto-ledger.csv`.

## Kịch bản test tay cho case cấp B / [Critical]
### AC-xx — <tên>
1. Mở <model .rvt / bản vẽ .dwg + phiên bản host>
2. <nút ribbon / lệnh> → <thao tác, giá trị nhập>
3. Kỳ vọng: <giá trị + đơn vị + dung sai> (nguồn: …)
4. Bằng chứng cần thu: <ảnh / bảng dump / file log + đường dẫn lưu>
5. Ghi kết quả: Pass / Fail + người + ngày
6. Báo cáo máy: <đường dẫn report-*.md theo từng năm host, hoặc "chưa chạy">

Tự động hoá (tuỳ chọn — để b-auto-run khỏi phải đoán):
- Host/năm: <Revit 2024, 2026 | AutoCAD 2025>
- Fixture: <tests/fixtures/... .rvt/.dwg — chỉ file test/golden>
- Lệnh: <CustomCtrl_%CustomCtrl_%Tab%Panel%Nút | lệnh AutoCAD + giá trị trả lời prompt>
- Hộp thoại: <"tiêu đề" → nút, …>

## Thay đổi theo yêu cầu
| R | File | Nội dung |
|---|---|---|

## Giả định đã dùng · điểm chưa làm · đề xuất thay đổi test
-

## Vùng có thể hồi quy
-

## Bản nháp comment Redmine (chưa gửi)
```
<nội dung ngắn: đã làm gì, cách kiểm tra, case chờ người xác nhận>
```
