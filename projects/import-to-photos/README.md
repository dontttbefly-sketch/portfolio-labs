# Import To Photos

一个纯本地 macOS 小工具，用来把指定文件夹里的图片导入系统 **Photos Library**。它会在成功导入的原图文件上写入本地标记，下一次运行时自动跳过已导入过的照片，从而避免重复导入，同时保留原文件在原目录中。

## 核心特性

- **纯本地代码运行**：使用 Swift、AppKit 和 Photos.framework，不依赖智能体、不联网、不上传到第三方服务。
- **导入到系统照片库**：调用 macOS Photos API，把图片加入当前用户的 Photos library。
- **避免重复导入**：成功导入后写入扩展属性 `local.import-to-photos.uploaded`，下次运行自动跳过。
- **保留原文件**：不会移动、删除或重命名原图片，只添加 Finder 默认不可见的本地标记。
- **支持 dry-run**：可以先查看哪些图片会导入、哪些图片会跳过。
- **可定制默认导入目录**：通过 `DefaultImportFolder.txt` 固定一个默认文件夹，也可以拖拽文件夹到 app 或从命令行传入路径。
- **带桌面快捷方式脚本**：可以创建 macOS Finder alias 并贴自定义图标。

## 支持的图片类型

当前扫描以下扩展名：

```text
jpg, jpeg, png, heic, heif, gif, tif, tiff, bmp, webp,
dng, cr2, cr3, nef, arw, raf, rw2, orf
```

扫描会跳过隐藏文件、`.app` bundle、`.photoslibrary`、`.iconset` 以及工具自身目录，避免把构建产物或图标素材导入照片库。

## 工作原理

1. 程序递归扫描输入文件夹中的受支持图片。
2. 对每张图片检查扩展属性：

   ```text
   local.import-to-photos.uploaded
   ```

3. 没有标记的图片会被导入 Photos。
4. Photos 返回导入成功后，程序才会在原图文件上写入标记。
5. 导入失败的图片不会被标记，下一次运行仍会再次尝试。
6. 如果图片导入成功但写入标记失败，程序会在完成弹窗里列出“已导入但未标记”的文件，提醒后续可能重复导入。

标记值是一个小型 JSON，例如：

```json
{
  "version": 1,
  "importedAt": "2026-05-15T12:34:56Z",
  "appIdentifier": "local.import-to-photos"
}
```

重复判断只看标记是否存在，不会计算文件哈希，也不会查询 Photos library。

## 系统要求

- macOS 12 或更新版本
- Apple Swift 编译器
- 当前用户允许该 app 添加项目到 Photos

查看 Swift 版本：

```sh
swiftc --version
```

## 构建

进入项目目录后运行：

```sh
./ImportToPhotos/build.sh
```

构建结果：

```text
ImportToPhotos/ImportToPhotos.app
```

构建脚本会：

- 编译主程序 `ImportToPhotos.swift`
- 编译并运行 `make_icon.swift` 生成 `.icns`
- 把 `Info.plist`、图标和可选的 `DefaultImportFolder.txt` 放入 app bundle

构建完成后建议签名：

```sh
codesign --force --deep --sign - ImportToPhotos/ImportToPhotos.app
```

验证签名：

```sh
codesign --verify --deep --strict ImportToPhotos/ImportToPhotos.app
```

## 配置默认导入目录

如果希望双击 app 时固定导入某个文件夹，在 `ImportToPhotos/` 下创建：

```text
DefaultImportFolder.txt
```

内容写入一个绝对路径，例如：

```text
/Users/you/Pictures/Incoming
```

仓库里提供了模板：

```text
ImportToPhotos/DefaultImportFolder.example.txt
```

真实的 `DefaultImportFolder.txt` 通常包含个人路径，因此被 `.gitignore` 忽略，不建议提交到公开仓库。

如果没有配置默认目录，app 会使用自身所在位置推导导入目录；也可以直接从命令行传入路径。

## 使用方式

### 双击 app

双击：

```text
ImportToPhotos/ImportToPhotos.app
```

首次运行时，macOS 可能会弹出 Photos 权限提示。允许后即可导入。

### 命令行导入文件夹

```sh
./ImportToPhotos/ImportToPhotos.app/Contents/MacOS/ImportToPhotos /path/to/folder
```

### 导入单张图片

```sh
./ImportToPhotos/ImportToPhotos.app/Contents/MacOS/ImportToPhotos /path/to/image.png
```

### dry-run 预览

```sh
./ImportToPhotos/ImportToPhotos.app/Contents/MacOS/ImportToPhotos --dry-run /path/to/folder
```

输出示例：

```text
Found 3 supported image(s).
New images: 2
Skipped marked images: 1

New:
NEW /path/to/a.png
NEW /path/to/b.png

Skipped:
SKIPPED /path/to/c.png
```

dry-run 不会导入 Photos，也不会写入标记。

## 查看和重置已上传标记

查看某个文件是否已标记：

```sh
xattr -p local.import-to-photos.uploaded /path/to/image.png
```

列出文件的全部扩展属性：

```sh
xattr -l /path/to/image.png
```

删除标记，让它下次可以重新导入：

```sh
xattr -d local.import-to-photos.uploaded /path/to/image.png
```

批量删除某个文件夹下所有 PNG 的标记示例：

```sh
for file in /path/to/folder/*.png; do
  xattr -d local.import-to-photos.uploaded "$file" 2>/dev/null || true
done
```

## 桌面快捷方式

本仓库包含 `create_desktop_alias.swift`，可用于创建 Finder alias。一个典型流程是：

```sh
swiftc ImportToPhotos/create_desktop_alias.swift -o ImportToPhotos/.build/create_desktop_alias
ImportToPhotos/.build/create_desktop_alias \
  "$(pwd)/ImportToPhotos/ImportToPhotos.app" \
  "$HOME/Desktop/导入到照片"
```

如果想给快捷方式贴自定义图标，可以使用 `sips`、`DeRez`、`Rez` 和 `SetFile`。这些是 macOS 自带工具或开发者工具，适合本地使用，不是运行导入功能的必要步骤。

## 测试

构建 app：

```sh
./ImportToPhotos/build.sh
```

运行标记行为回归测试：

```sh
./ImportToPhotos/test_marker_behavior.sh
```

这个测试会：

- 创建临时目录
- 复制一张测试图片成两个文件
- 给其中一个文件写入 `local.import-to-photos.uploaded`
- 运行 `--dry-run`
- 验证未标记文件显示为 `NEW`，已标记文件显示为 `SKIPPED`

## 隐私与安全

- 程序不会联网。
- 程序不会上传图片到任何第三方服务。
- 程序不会删除、移动或重命名原图。
- 公开仓库不应提交真实照片、个人默认路径或构建产物。
- Photos 权限由 macOS 管理；如果权限被拒绝，请在系统设置中允许该 app 添加照片。

## 常见问题

### 为什么图片还在文件夹里？

这是设计行为。工具只负责把图片导入 Photos library，不负责清理源文件。

### 为什么第二次点击没有再次导入？

第一次导入成功后，源文件被写入了 `local.import-to-photos.uploaded` 标记。第二次运行会跳过这些文件。

### 我想重新导入某张照片怎么办？

删除该文件的扩展属性：

```sh
xattr -d local.import-to-photos.uploaded /path/to/image.png
```

### 复制一份照片会不会被跳过？

只有复制出来的新文件也带有扩展属性时才会跳过。当前版本不做文件内容哈希判断。

### 旧版本已经导入过的照片会自动识别吗？

不会。旧版本没有写入 `local.import-to-photos.uploaded` 标记。升级后第一次成功导入，才会开始使用新标记避免后续重复。

## 项目结构

```text
.
├── ImportThisFolderToPhotos.command
├── ImportToPhotos
│   ├── ImportToPhotos.swift
│   ├── Info.plist
│   ├── build.sh
│   ├── make_icon.swift
│   ├── create_desktop_alias.swift
│   ├── test_marker_behavior.sh
│   ├── DefaultImportFolder.example.txt
│   └── README.md
└── README.md
```

## 开发说明

主要逻辑集中在 `ImportToPhotos.swift`：

- `collectImages`：扫描图片并跳过工具自身目录
- `partitionUploadedImages`：根据扩展属性拆分新图片和已上传图片
- `importImages`：逐张导入 Photos，并在成功后写入标记
- `--dry-run` 分支：只输出待导入和跳过列表，不产生副作用

图标由 `make_icon.swift` 使用 CoreGraphics 生成，构建时会产出 `ImportToPhotos.icns` 和 `.iconset`，这些属于生成产物，默认不提交。

