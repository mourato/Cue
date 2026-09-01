<div align="center">
  <img src="./banner.png" width="200" height="200" alt="Notinhas 横幅" />
  <h1>Notinhas</h1>
  <p><strong>macOS 视觉交付工具 — 区域截图、编号标注、复制开发者简报。</strong></p>
  <p>
    <a href="./README.md">🇺🇸 English</a> •
    <a href="./README.vi.md">🇻🇳 Tiếng Việt</a> •
    <a href="./README.zh-CN.md">🇨🇳 简体中文</a>
  </p>
</div>

## 功能

- 区域截图与编号图钉/矩形注释
- 一键复制带注释的图片与结构化说明
- 捕获历史、Quick Access、可配置快捷键
- TOML 配置：`~/.config/cue/config.toml`
- 本地诊断日志（无遥测）

## 安装

需要 **macOS 26.0+**。

1. 从 [Releases](https://github.com/mourato/Cue/releases) 下载 `Cue-v<version>.dmg`
2. 将 `Cue.app` 拖入 `/Applications`
3. 在系统设置中授予屏幕录制和辅助功能权限

从 Snapzy 升级请参阅 [docs/MIGRATION.md](docs/MIGRATION.md)。

```bash
curl -fsSL https://raw.githubusercontent.com/mourato/Cue/main/install.sh | bash
```

## 自动化

URL scheme：`cue://`（例如 `cue://capture/area`）。旧版 `snapzy://` **不会**被处理。

## 开发

```bash
git clone https://github.com/mourato/Cue.git
cd Notinhas
./scripts/build_and_run.sh
```

## 文档

- [文档索引](docs/README.md)
- [从 Snapzy 迁移](docs/MIGRATION.md)
- [安全策略](SECURITY.md)

## 许可证

BSD 3-Clause — 见 [LICENSE](LICENSE)。
