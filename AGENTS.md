# AGENTS.md - 多Agent协作规范

## 项目架构
```
agents/
├── founder/         # 创始人/产品经理 - 需求决策
├── product/         # 产品Agent - PRD、交互设计
├── dev/             # 开发Agent - 技术实现、代码
└── qa/              # 测试Agent - 质量保障
```

## 协作流程
1. **需求阶段**: founder → product (需求文档)
2. **设计阶段**: product → dev (PRD + 设计稿)
3. **开发阶段**: dev 独立开发，每日同步
4. **测试阶段**: dev → qa (测试用例)
5. **发布阶段**: qa → founder (验收)

## 当前状态
- **项目**: 维生素分析仪 (Vitamin Analyzer)
- **阶段**: 产品定义 → 原型开发
- **目标**: 2周内完成MVP

## 会议机制
- **每日站会**: 各Agent汇报进展
- **需求评审**: 重大变更需founder确认
- **代码审查**: 关键模块交叉review

## 文档规范
- 所有决策记录到 MEMORY.md
- 技术方案记录到 TECH.md
- 产品变更记录到 CHANGELOG.md
