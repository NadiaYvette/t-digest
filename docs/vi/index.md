# t-digest — Cấu trúc dữ liệu ước lượng phân vị theo luồng

## Tổng quan

**t-digest** là một cấu trúc dữ liệu xác suất được thiết kế để ước lượng hiệu quả các phân vị (percentile) từ luồng dữ liệu. Thuật toán này do Ted Dunning phát minh, cho phép xử lý dữ liệu tuần tự theo phương thức trực tuyến mà không cần lưu trữ toàn bộ dữ liệu trong bộ nhớ, đồng thời vẫn cung cấp ước lượng phân vị chính xác.

Đặc tính nổi bật nhất của t-digest là độ chính xác đặc biệt cao tại các đuôi (tail) của phân phối. Mặc dù độ chính xác gần trung vị có thể hơi thấp, nhưng khi ước lượng các phân vị cực đoan như phân vị thứ 99 hay 99.9, t-digest đạt được độ chính xác rất cao. Đây là tính chất vô cùng quan trọng trong các ứng dụng thực tế như giám sát SLA và phân tích độ trễ.

Về mặt nội bộ, t-digest tập hợp các điểm dữ liệu thành các cụm gọi là "centroid" (trọng tâm). Lượng bộ nhớ sử dụng được kiểm soát bởi tham số nén δ, hoạt động với bộ nhớ giới hạn O(δ) không phụ thuộc vào tổng số điểm dữ liệu đầu vào.

## Các đặc tính chính

- **Xử lý theo luồng / trực tuyến** — Có thể thêm từng điểm dữ liệu một, không cần lưu toàn bộ dữ liệu trong bộ nhớ
- **Bộ nhớ giới hạn O(δ)** — Lượng bộ nhớ sử dụng chỉ phụ thuộc vào tham số nén δ, không phụ thuộc vào lượng dữ liệu
- **Độ chính xác tại đuôi** — Đạt độ chính xác đặc biệt cao tại hai đầu của phân phối (gần 0% và 100%)
- **Có thể hợp nhất** — Nhiều t-digest có thể được kết hợp lại, phù hợp cho hệ thống phân tán

## Khái niệm hàm tỷ lệ

Cốt lõi của t-digest là "hàm tỷ lệ" (scale function). Hàm tỷ lệ kiểm soát kích thước tối đa mà một centroid có thể đạt được tại mỗi vị trí trong phân phối. Ở vùng trung tâm của phân phối, centroid được phép lớn hơn (chứa nhiều điểm dữ liệu hơn); ở vùng đuôi, chỉ cho phép các centroid nhỏ. Nhờ cơ chế này, nhiều centroid hơn được phân bổ tại vùng đuôi, từ đó nâng cao độ chính xác ước lượng tại đuôi.

## Ví dụ sử dụng (mã giả)

```
# Tạo t-digest (tham số nén δ = 100)
td = TDigest.new(delta: 100)

# Thêm từng điểm dữ liệu
td.add(1.0)
td.add(2.5)
td.add(3.7)
td.add(100.0)
td.add(0.01)

# Xử lý khối lượng dữ liệu lớn không thành vấn đề
for value in data_stream:
    td.add(value)

# Truy vấn phân vị
median    = td.quantile(0.5)    # Trung vị
p99       = td.quantile(0.99)   # Phân vị thứ 99
p999      = td.quantile(0.999)  # Phân vị thứ 99.9

# Truy vấn ngược: lấy giá trị CDF của một giá trị
cdf_value = td.cdf(42.0)        # Tỷ lệ dữ liệu nhỏ hơn hoặc bằng 42.0
```

## Bước tiếp theo

Xem hướng dẫn [Bắt đầu nhanh](getting-started.md) để tìm hiểu cách xây dựng và chạy các bản triển khai bằng từng ngôn ngữ.
