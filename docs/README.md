# Sơ đồ luồng

| Hình | Nguồn sửa (Mermaid) | Nội dung |
|---|---|---|
| [`flow-overview.png`](flow-overview.png) / [`.svg`](flow-overview.svg) | [`flow-overview.mmd`](flow-overview.mmd) | Toàn luồng: Redmine → writer → duyệt → addin-story / addin-batch → test B → MR |
| [`flow-story.png`](flow-story.png) / [`.svg`](flow-story.svg) | [`flow-story.mmd`](flow-story.mmd) | Chi tiết các phase của `addin-story` |

Quy ước màu: xanh = skill · cam = cổng người duyệt · tím = agent con · xám = hệ thống ngoài.

## Cải tiến sơ đồ
1. Sửa file `.mmd` (văn bản thuần, đọc được diff khi review). Xem thử nhanh tại <https://mermaid.live>.
2. Sinh lại ảnh (cần Node.js; lần đầu `npx` tải mermaid-cli):
   ```
   npx -y @mermaid-js/mermaid-cli -i docs/flow-overview.mmd -o docs/flow-overview.svg -b white
   npx -y @mermaid-js/mermaid-cli -i docs/flow-overview.mmd -o docs/flow-overview.png -b white -s 2
   ```
   Làm tương tự với `flow-story`. Nếu mermaid-cli không tìm thấy trình duyệt, tạo `puppeteer.json`
   `{"executablePath":"<đường dẫn chrome.exe hoặc msedge.exe>","args":["--no-sandbox"]}` và thêm `-p puppeteer.json`.
3. Commit cả `.mmd` lẫn `.png`/`.svg` cùng một lần; khi đổi hành vi skill nhớ sửa sơ đồ trong cùng PR.
