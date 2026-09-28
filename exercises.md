# Phiếu Phản Ánh — K4 Level 3A, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Vũ Quốc Bảo  
> Mã học viên: 2A202602829

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Giả sử tôi deploy lên Railway mà quên set `AGENT_API_KEY` trên dashboard. Nếu
code có mặc định `"changeme"` thì app vẫn chạy bình thường, `/health` vẫn trả 200,
nhìn vào tôi tưởng mọi thứ ổn. Nhưng lúc này khóa thật chính là `"changeme"`, mà
chữ này nằm công khai trong repo GitHub, nên ai đọc code cũng gọi được `/ask` và
tiêu tiền của tôi. Tôi chỉ biết khi thấy chi phí tăng vọt.

Vì không có mặc định, app báo lỗi `agent_api_key Field required` và dừng ngay lúc
khởi động. Bản deploy bị báo lỗi trong vài phút, tôi mở log ra là thấy thiếu biến
gì và sửa luôn, trước khi có ai kịp gọi vào. Tôi còn thêm `${AGENT_API_KEY:?...}`
trong `docker-compose.yml` để compose không chịu chạy nếu `.env` thiếu khóa.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

Đây là một dòng log tôi lấy từ `docker compose logs agent` sau khi gọi `/ask`:

```json
{"event": "ask_completed", "level": "info", "timestamp": "2026-09-28T09:09:27.959431+00:00", "user_id": "scale-1790586566", "tokens_in": 248, "tokens_out": 46, "cost_usd": 6.48e-05}
```

Việc thứ nhất là lọc và cộng số theo từng trường. Vì mỗi dòng có sẵn `user_id` và
`cost_usd`, tôi có thể lọc các dòng `ask_completed` rồi cộng tiền theo từng user để
biết ai tiêu nhiều nhất trong ngày. Với `print("đã trả lời xong")` thì chỉ có một
câu chữ, không có con số nào để tính.

Việc thứ hai là lần theo một request qua nhiều container. Ở câu 9 tôi chạy 3
container, và nhờ lọc theo `user_id` rồi xếp theo `timestamp`, tôi biết chính xác
lượt hỏi nào rơi vào container nào. Trường `level` cũng giúp đặt cảnh báo kiểu
"có nhiều dòng `error` trong 5 phút thì báo cho tôi", điều mà một dòng `print` trơn
không làm được.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 1.73 GB |
| Multi-stage | 271 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

Bản multi-stage nhỏ hơn khoảng 6 lần, chênh gần 1.46 GB. Tôi xem `docker history`
thì thấy phần lớn nằm ở base image `python:3.11` bản đầy đủ. Nó cài sẵn cả bộ đồ
nghề để biên dịch như gcc, make và rất nhiều thư viện dev, riêng một layer đã
khoảng 694 MB. Tôi thử gõ `which gcc` thì bản single có gcc, còn bản multi thì
không. Ngoài ra bản single còn giữ lại 17 MB cache của pip vì không dùng
`--no-cache-dir`.

Với bản multi-stage, stage builder lo cài thư viện rồi bị bỏ đi, stage cuối chỉ
lấy đúng thư viện đã cài và dùng base `slim` gọn nhẹ. Ở lab này thư viện nào cũng
có bản cài sẵn nên không cần biên dịch, vì vậy phần giảm chủ yếu đến từ việc đổi
sang `slim`. Nếu phải biên dịch thì multi-stage càng có lợi, vì compiler chỉ nằm ở
builder và không lọt vào image cuối.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

Tôi thêm một dòng comment vào cuối `app/main.py` rồi build lại. Với Dockerfile của
tôi, build lại chỉ mất 2,9 giây. Các bước `COPY requirements.txt`, `pip install` và
`COPY --from=builder` đều hiện `CACHED`, chỉ có `COPY app` và `COPY utils` là chạy
lại. `utils` không đổi gì mà vẫn chạy lại, vì Docker bỏ cache từ bước đầu tiên có
thay đổi trở xuống.

Tôi làm y hệt với bản cũ, bản có `COPY . .` đứng trước `pip install`, thì build lại
mất 91,9 giây. Chỉ sửa một dòng code nhưng `COPY . .` thay đổi, kéo theo
`pip install` phải tải và cài lại toàn bộ thư viện, riêng bước đó đã mất khoảng
85 giây. Chỉ vì đổi thứ tự hai dòng mà chậm hơn khoảng 30 lần, nên tôi luôn đặt
phần ít thay đổi như thư viện lên trước, phần hay sửa như code xuống sau.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

Đầu tiên, code của tôi hoặc một thư viện nào đó có lỗ hổng cho phép người ngoài
chạy lệnh trên server. Nếu container chạy bằng root thì các lệnh đó cũng chạy với
quyền root. Kẻ tấn công có thể cài thêm công cụ, sửa code để cài cửa hậu, đọc hết
dữ liệu trong container. Root trong container thật ra cũng là root đối với nhân
Linux của máy host, chỉ bị ngăn lại bằng vài lớp cách ly. Chỉ cần cấu hình hơi lỏng,
ví dụ mount thư mục của host vào container, hoặc nhân Linux có lỗi, là kẻ tấn công
thoát ra ngoài và thành root trên cả máy host.

Lệnh `USER appuser` cắt chuỗi này ngay từ bước thứ hai. Lỗ hổng vẫn còn đó, nhưng
lệnh của kẻ tấn công chỉ chạy bằng một user thường. Tôi kiểm tra bằng lệnh `id`
trong container thì ra `uid=10001(appuser)`. User này không cài thêm được gì,
không đọc được file của root, và phần lớn cách thoát khỏi container đều cần quyền
root nên không dùng được. Tôi còn để code trong `/app` thuộc về root, nên appuser
chỉ đọc được chứ không sửa được. Tôi thử `touch /app/app/hack.py` thì bị từ chối.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

Tối đa là 20 request trong 2 giây. Người dùng gửi 10 request vào giây 59 của phút
10:00, vừa đủ hạn mức của phút đó. Sang 10:01:00 bộ đếm reset về 0, họ gửi tiếp 10
request nữa ngay trong giây 00 hoặc 01. Tính ra 20 request trong khoảng 2 giây mà
vẫn không vi phạm luật nào, gấp đôi hạn mức.

Cửa sổ trượt của tôi không có kẽ hở này. Mỗi lần có request mới, nó đếm lại số
request trong đúng 60 giây vừa qua, nên 10 request lúc 10:00:59 vẫn còn được tính
tới tận 10:01:59. Vì vậy trong bất kỳ khoảng 60 giây nào cũng không lọt quá 10
request.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

Rate limit đếm số lần gọi trong một phút, còn cost guard đếm số tiền đã tiêu trong
cả tháng. Một cái chống gọi quá nhanh, một cái chống tiêu quá nhiều tiền.

Rate limit cho qua nhưng cost guard chặn: một người gọi rất đều, chỉ 5 lần mỗi
phút, không bao giờ chạm hạn mức 10. Nhưng họ hỏi liên tục cả ngày với lịch sử hội
thoại dài, nên mỗi request càng lúc càng tốn nhiều token. Tôi thấy rõ điều này
trong log ở câu 9: cùng một user mà `tokens_in` tăng từ 3 lên 248 khi lịch sử dài
ra. Tới lúc tổng tiền trong tháng vượt 10 USD thì cost guard trả 402, dù họ chưa
từng gọi quá nhanh.

Cost guard cho qua nhưng rate limit chặn: một người spam 15 câu "hi" trong vài
giây. Mỗi câu chỉ tốn một phần rất nhỏ của một xu nên ngân sách vẫn còn gần như
nguyên, nhưng tới request thứ 11 là bị 429. Tôi đã thử và nhận đúng 429 kèm header
`Retry-After: 60`.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

Khi Redis mất kết nối, cả 3 container cùng lúc báo health check thất bại, vì endpoint
gộp đi hỏi Redis mà Redis không trả lời. Sau vài lần thử lại, orchestrator kết luận
cả 3 container đều hỏng và restart cả 3 cùng lúc. Lúc này không còn container nào
phục vụ, người dùng gặp lỗi hết. Các container khởi động lại, kiểm tra thấy Redis
vẫn chưa về nên lại bị báo hỏng và restart tiếp. Tôi đã thấy vòng lặp này ở CP2,
khi container bị restart tới 10 lần và mỗi lần phải chờ lâu hơn lần trước. Vì vậy
khi Redis quay lại sau 30 giây, các container có thể vẫn đang nằm chờ restart, và
sự cố kéo dài hơn nhiều so với 30 giây.

Khi tách riêng thì khác hẳn. `/health` không đụng tới Redis nên vẫn trả 200, không
container nào bị restart. Chỉ có `/ready` trả 503, nên load balancer tạm ngừng gửi
request vào. Khi Redis về, `/ready` trả 200 lại và traffic chạy tiếp ngay, không
phải chờ khởi động lại gì cả.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

Tôi chạy 3 container agent phía sau nginx rồi gọi `/ask` 6 lần với cùng một
`X-User-Id`. Xem log thì thấy nginx chia lần lượt các request cho agent-3, agent-2,
agent-1 rồi lặp lại, nhưng `history_length` vẫn tăng đều là 0, 2, 4, 6, 8, 10. Dù
mỗi lượt vào một container khác nhau, container nào cũng thấy đủ lịch sử, vì tất
cả cùng đọc và ghi vào một Redis.

Nếu lịch sử nằm trong dict Python thì mỗi container có một bộ nhớ riêng, và chỉ
nhớ những lượt rơi vào chính nó. Với cách chia lần lượt như trên, tôi sẽ thấy dãy
kiểu 0, 0, 0, 2, 2, 2. Ba lượt đầu vào ba container khác nhau nên container nào
cũng tưởng đây là câu đầu tiên. Tới lượt 4 quay lại agent-3 thì nó chỉ nhớ được
lượt 1. Agent sẽ lúc nhớ lúc quên rất khó hiểu, và chỉ cần một container restart là
phần lịch sử trong đó mất sạch.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

Trên Render tôi không gặp lỗi build hay health check nào. Trở ngại đầu tiên là
tài khoản Railway báo hết hạn dùng thử nên tôi không deploy tiếp được, và tôi
chuyển sang Render bằng Blueprint đọc từ file `render.yaml`.

Lỗi thật sự tôi gặp là cấu hình trên cloud không khớp với cấu hình ở máy. Không
có thông báo lỗi nào cả, tôi chỉ phát hiện khi chụp ảnh dashboard: cột Region ghi
Oregon, trong khi file `render.yaml` ở máy tôi đã sửa thành Singapore. Tôi chạy
`git status` thì thấy `render.yaml` vẫn đang ở trạng thái sửa đổi, chưa commit.
Chạy tiếp `git show origin/main:render.yaml` thì thấy bản trên GitHub vẫn là file
gốc, không có dòng region nào. Nguyên nhân là Render đọc cấu hình từ GitHub chứ
không đọc từ máy tôi, nên nó dùng file gốc và chọn vùng mặc định là Oregon.

Region không đổi được sau khi đã tạo service. Nếu tôi cứ push bản ghi Singapore,
lần đồng bộ Blueprint sau sẽ bị xung đột. Vì app vẫn chạy tốt ở Oregon, tôi sửa
`render.yaml` ghi rõ `region: oregon` cho khớp với thực tế rồi mới commit và
push. Bài học tôi rút ra là với cách deploy từ GitHub, phải push code trước khi
deploy, và sau khi deploy nên kiểm tra lại dashboard xem cloud có chạy đúng cấu
hình mình nghĩ không.
