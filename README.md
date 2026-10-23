# cqifsAssistant / 重外小助手

重外院个人课表与校园生活助手，使用 Flutter + Android 开发。

## 功能

- 强智教务系统登录、图片验证码和课表缓存
- 今日课程、全屏周课表、按天查看
- 自定义课程增删改、课程颜色和课表背景
- 相册图片背景、纯色背景和明暗主题
- 上课提醒、闹钟提醒、作业与日程倒计时、日程图片提醒
- 二期水电平台授权、水表/电表余额与充值入口
- 水电会话静默恢复、低余额预警和用量趋势
- 首页显示水电余额与趋势曲线
- 游客模式：无需登录也可使用本地课表、日程、地图和设置

## 项目结构

```text
.
├── timetable_app/          Flutter Android 应用
├── jw_schedule_spider.py   教务课表导出脚本
├── requirements.txt
├── 水电接口说明.md
└── 重外小助手-说明.md
```

## 构建

环境：

- Flutter 3.47.7
- Dart 3.13.5
- JDK 17
- Android SDK 36

```powershell
cd timetable_app
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

APK 输出：

```text
timetable_app/build/app/outputs/flutter-apk/app-release.apk
```

## 安全与隐私

- 仓库不包含学校账号、密码、Cookie、OpenID 或登录令牌。
- 教务验证码需要用户手动输入。
- 水电平台使用微信网页授权，一次性授权码仅用于本机换取会话。
- 课表和水电数据默认保存在本机。
- 本软件仅用于个人学习与生活辅助，不绕过学校系统的安全验证。

## 下载

最新 APK 请在仓库的 **Releases** 页面下载。
