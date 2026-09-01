<div align="center">
  <img src="./banner.png" width="200" height="200" alt="Notinhas banner" />
  <h1>Notinhas</h1>
  <p><strong>Công cụ bàn giao hình ảnh trên macOS — chụp vùng, ghim đánh số, sao chép brief cho developer.</strong></p>
  <p>
    <a href="./README.md">🇺🇸 English</a> •
    <a href="./README.vi.md">🇻🇳 Tiếng Việt</a> •
    <a href="./README.zh-CN.md">🇨🇳 简体中文</a>
  </p>
</div>

## Tính năng

- Chụp vùng, chú thích với ghim/số và ghi chú ngắn
- Xuất clipboard sẵn sàng cho developer và AI agent
- Lịch sử capture, Quick Access, phím tắt tùy chỉnh
- Cấu hình TOML tại `~/.config/cue/config.toml`
- Nhật ký chẩn đoán cục bộ (không telemetry)

## Cài đặt

Yêu cầu **macOS 26.0+**.

1. Tải [Releases](https://github.com/mourato/Cue/releases) — `Cue-v<version>.dmg`
2. Kéo `Cue.app` vào `/Applications`
3. Cấp quyền Screen Recording và Accessibility khi được hỏi

Nâng cấp từ Snapzy: xem [docs/MIGRATION.md](docs/MIGRATION.md).

```bash
curl -fsSL https://raw.githubusercontent.com/mourato/Cue/main/install.sh | bash
```

## Tự động hóa

URL scheme: `cue://` (ví dụ `cue://capture/area`). Liên kết `snapzy://` **không** được hỗ trợ.

## Phát triển

```bash
git clone https://github.com/mourato/Cue.git
cd Notinhas
./scripts/build_and_run.sh
```

## Tài liệu

- [Bản đồ tài liệu](docs/README.md)
- [Di chuyển từ Snapzy](docs/MIGRATION.md)
- [Bảo mật](SECURITY.md)

## Giấy phép

BSD 3-Clause — xem [LICENSE](LICENSE).
