# 音乐播放器 (Music Player)

一个基于 Qt/QML 和 C++ 开发的现代化音乐播放器应用程序。

## 功能特性

- 🎵 支持多种音频格式播放
- 🎨 现代化的用户界面设计
- 📱 响应式布局，支持不同屏幕尺寸
- 🎼 播放列表管理
- 🎛️ 音量控制和均衡器
- 🎪 音频可视化效果
- ⏯️ 播放控制（播放/暂停/上一首/下一首）
- 🔄 单曲/列表循环播放和随机播放模式

## 技术栈

- **前端**: QML/Qt Quick
- **后端**: C++/Qt
- **构建系统**: CMake
- **音频处理**: FFmpeg
- **音频可视化**: KissFFT

## 构建要求

- Qt 6.2 或更高版本
- CMake 3.16 或更高版本
- C++17 兼容的编译器
- FFmpeg 开发库

## 构建步骤

1. 克隆仓库：
```bash
git clone <repository-url>
cd player
```

2. 创建构建目录：
```bash
mkdir build
cd build
```

3. 配置项目：
```bash
cmake ..
```

4. 编译：
```bash
cmake --build .
```

5. 运行：
```bash
./Debug/app.exe  # Windows Debug版本
# 或
./app.exe        # Release版本
```

## 开发说明

- 使用 Qt Creator 或 Visual Studio 进行开发
- QML文件支持热重载，便于界面调试
- C++后端提供音频播放和数据处理功能
- 使用 CMake 管理项目依赖和构建过程

## 许可证

本项目采用 MIT 许可证。详见 LICENSE 文件。

## 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目。
