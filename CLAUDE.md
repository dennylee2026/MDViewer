# CLAUDE.md — MDViewer 开发规范

## Commit 规范

- 严格遵守 Conventional Commits：`feat` / `fix` / `chore` / `docs` / `refactor` / `test`
- scope 统一用 `mdviewer`，例如 `feat(mdviewer): add dark theme`
- 每次 commit 前自查格式，不符合则停下来修正后再提交

## README.md 维护规则

- 项目创建时生成初始版本，包含：项目名称、一句话描述、截图占位、安装方式、使用方法
- 每当新增功能或用法变化时，同步更新 README.md
- 保持简洁，面向「clone 下来能立刻理解怎么构建和使用」的标准来写

## CHANGELOG.md 维护规则

- 遵循 [Keep a Changelog](https://keepachangelog.com) 格式
- 每次功能完成或 bug 修复后，在 `[Unreleased]` 区追加记录
- 当我说「发版」时，将 `[Unreleased]` 归入新版本号（语义化版本），注明日期
- 条目分类：`Added` / `Changed` / `Fixed` / `Removed`

## 分支与同步

- 功能开发在 `dev` 分支，完成后我会说「合并到 main」
- 每次完成一个阶段性工作，主动提醒我是否要 push
- push 前确保 README 和 CHANGELOG 已更新

## 跨设备开发提示

- 如果本地落后于远程，先提醒我 pull 再继续
- commit 粒度：一个功能点或一个修复 = 一次 commit

## docs/roadmap.md 维护规则

- 这是项目的开发计划文件，记录待开发功能和优先级
- 每次完成 roadmap 中的条目后，标记为 ✅ 并注明完成日期
- 不要擅自调整优先级或删除条目
- 开始新任务前先读一遍 roadmap，优先做高优先条目
- 如果我给的指令和 roadmap 冲突，以当前指令为准
