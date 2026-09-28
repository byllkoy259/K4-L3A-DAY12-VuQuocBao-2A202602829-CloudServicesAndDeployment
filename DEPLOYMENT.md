# Thông Tin Deploy — Checkpoint 5

> Điền file này sau khi deploy xong. `pytest tests/test_cp5.py` đọc file này
> để tìm địa chỉ service của bạn và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, tuyệt đối không dán giá trị API key vào đây.**
> Repo này công khai — dán khóa vào là mất khóa.

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Vũ Quốc Bảo |
| Mã học viên | 2A202602829 |
| Repo | https://github.com/byllkoy259/K4-L3A-DAY12-VuQuocBao-2A202602829-CloudServicesAndDeployment |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://day12-agent-5b9x.onrender.com |
| Platform | Render (Blueprint từ `render.yaml`, web service Docker, gói free, region Oregon) |
| Ngày deploy | 2026-09-28 |

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | Render tự gán, app đọc qua `${PORT:-8000}` trong CMD của Dockerfile |
| `AGENT_API_KEY` | ✅ | nhập tay lúc tạo Blueprint (`sync: false`), không nằm trong repo |
| `REDIS_URL` | ✅ | Render Key Value `day12-redis` (Valkey 8), lấy tự động qua `fromService` → `connectionString` (địa chỉ nội bộ) |
| `RATE_LIMIT_PER_MINUTE` | ✅ | 10 (khai báo trong `render.yaml`) |
| `MONTHLY_BUDGET_USD` | ✅ | 10.0 (khai báo trong `render.yaml`) |
| `LOG_LEVEL` | ✅ | INFO (khai báo trong `render.yaml`) |

## Lệnh Kiểm Tra

Thay `<URL>` bằng Public URL ở trên:

```bash
# 1. Liveness — mong đợi 200 {"status":"ok"}
curl -i <URL>/health

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
curl -i <URL>/ready

# 3. Không có API key — mong đợi 401
curl -i -X POST <URL>/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"Hello"}'

# 4. Có API key — mong đợi 200 kèm câu trả lời
curl -i -X POST <URL>/ask \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $AGENT_API_KEY" \
  -H "X-User-Id: sv-test" \
  -d '{"question":"Deploy là gì?"}'

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST <URL>/ask \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $AGENT_API_KEY" \
    -H "X-User-Id: sv-test" \
    -d '{"question":"test"}'
done; echo
```

## Kết Quả Chạy Thật

Output khi gọi vào `https://day12-agent-5b9x.onrender.com` ngày 2026-09-28:

```
# 1. GET /health
HTTP/1.1 200 OK
{"status":"ok","service":"day12-agent","version":"1.0.0"}

# 2. GET /ready
HTTP/1.1 200 OK
{"status":"ready","redis":true}

# 3. POST /ask không có API key
HTTP/1.1 401 Unauthorized
{"detail":"invalid or missing API key"}

# 4. POST /ask có API key (X-User-Id: sv-test)
HTTP/1.1 200 OK
{"answer":"Câu hỏi hay. Deploy là gì thường được giải quyết bằng cách chuẩn hóa môi trường chạy: cùng một image chạy giống nhau ở laptop và trên cloud.","user_id":"sv-test","history_length":0,"cost_usd":2.145e-05,"tokens":{"in":3,"out":35}}

# 5. Rate limit — 15 lần liên tiếp (cùng user sv-test)
200 200 200 200 200 200 200 200 200 429 429 429 429 429 429
```

Ở lệnh 5 chỉ có 9 lần 200 vì request của lệnh 4 (cùng `sv-test`, chạy ngay trước)
đã chiếm 1 lượt trong cửa sổ 60 giây — tổng cộng đúng 10 request được cho qua,
khớp `RATE_LIMIT_PER_MINUTE=10`, từ request thứ 11 trở đi bị chặn bằng 429.

## Ảnh Chụp Màn Hình

Đặt ảnh trong thư mục `screenshots/`:

- `screenshots/dashboard.png` — trang quản lý service trên platform
- `screenshots/health.png` — kết quả gọi `/health` từ trình duyệt hoặc curl
