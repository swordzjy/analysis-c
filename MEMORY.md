# MEMORY.md - 项目记忆

## 2025-05-29 项目启动
- 创始人虹影提出需求：维生素分析仪App
- 确定Flutter跨平台方案（iOS/Android/Web）
- 核心功能：文字输入 + 拍照识别 → 维生素分析
- 隐私优先：数据本地处理，不上传服务器

## 技术决策
- Flutter 3.32.0 stable
- 支持平台：android, ios, web, macos, windows, linux
- 项目名：vitamin_analyzer
- 包结构：screens, models, services, widgets, utils

## 待办事项
- [ ] 完成产品PRD文档
- [ ] 设计UI/UX原型
- [ ] 搭建Flutter项目结构
- [ ] 集成图像识别API
- [ ] 构建营养数据库
- [ ] 开发分析结果页面
- [ ] 测试与优化

## 风险记录
- 图像识别准确率需要验证
- 营养数据来源需确认（USDA/中国食物成分表）
- Web端相机权限处理
- 多语言支持（后续版本）

## 关键决策
- **隐私优先**：用户照片不存储，仅用于实时分析
- **离线优先**：营养数据库本地化，支持无网络使用
- **MVP范围**：先支持中文食物，后续扩展
