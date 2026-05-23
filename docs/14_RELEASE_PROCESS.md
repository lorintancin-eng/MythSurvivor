# 14 通用发布流程

> 状态：`[骨架 + 完整流程]`
> 配套模板：[templates/RELEASE_NOTES_TEMPLATE.md](templates/RELEASE_NOTES_TEMPLATE.md)

---

## 1. 发布类型

| 类型 | 适用场景 | 触发条件 |
|---|---|---|
| 大版本 (v0.x) | 完成 ROADMAP 中一整个 v0.x 计划 | 用户确认所有 v0.x 任务完成 |
| 小补丁 (v0.x.y) | 已发版本的 bugfix | 严重 bug 修复 |
| 公开发布 (v1.0+) | 走向玩家 | 完成 v0.9 + 用户决策 |
| 预发布 (alpha / beta) | 内部 / 友测试 | 重要里程碑 |

## 2. 发布前置门禁

每次发布必须满足（详见 [11_ACCEPTANCE_CHECKLIST.md](11_ACCEPTANCE_CHECKLIST.md) §5.1）：

- [ ] 该版本所有任务 ✅ 完成
- [ ] 通用 DoD 全部通过
- [ ] 版本专属 QA 清单全部通过
- [ ] 控制台无红色错误
- [ ] ROADMAP 已更新该版本状态
- [ ] release notes 已撰写
- [ ] git 工作区干净
- [ ] **用户明确授权**

## 3. 发布步骤（标准流程）

### Step 1：发布前最终验证

```bash
# 1. 确认在 main 分支
git status

# 2. 确认 main 与 origin 同步
git fetch origin
git log --oneline origin/main..main  # 应为空
git log --oneline main..origin/main  # 应为空

# 3. 跑 smoke test（编辑器打开项目 + F5 启动）
```

### Step 2：撰写 / 完善 release notes

文档位置：`docs/archive/v0.x/RELEASE_NOTES_V0_X.md`

模板见 [templates/RELEASE_NOTES_TEMPLATE.md](templates/RELEASE_NOTES_TEMPLATE.md)。

必含：
- 版本目标
- 功能范围（用户可读）
- 已执行验证
- 已知问题
- 升级注意事项

### Step 3：创建 git tag

```bash
git tag -a v0.x.0 -m "Release v0.x: 版本简短描述"
git push origin v0.x.0
```

Tag 命名：`v` + 语义化版本（`v0.2.0`, `v0.3.1`）。

### Step 4：创建 GitHub Release

```bash
gh release create v0.x.0 \
  --title "v0.x: 标题" \
  --notes-file docs/archive/v0.x/RELEASE_NOTES_V0_X.md
```

可选：附带导出的游戏包（zip / 平台 build）。

### Step 5：发布后善后

- [ ] 更新 [09_ROADMAP.md](09_ROADMAP.md)：v0.x → ✅
- [ ] 更新 [10_TASK_BACKLOG.md](10_TASK_BACKLOG.md)：归档已完成任务
- [ ] 把版本相关临时文档移到 `archive/v0.x/`
- [ ] 通知用户（如适用）

## 4. Hotfix 发布流程

```
发现严重 bug
   ↓
创建 hotfix 分支（基于受影响的 tag，不基于 main）
   ↓
修复 + reviewer
   ↓
关键回归
   ↓
合 main + tag v0.x.y+1
   ↓
撰写 hotfix 简要 release notes
```

## 5. 取消 / 回滚发布

### 5.1 发布前取消
- 直接停止流程
- 已写的 release notes 标 `[CANCELLED]` 归档

### 5.2 发布后回滚
- **避免**：尽量发新 hotfix 而不是回滚 tag
- 必须回滚时：
  ```bash
  gh release delete v0.x.0    # 删除 GitHub Release
  git tag -d v0.x.0           # 本地删除
  git push origin :v0.x.0     # 远端删除
  ```
- 必须创建 ADR 记录回滚原因

## 6. 版本号决策树

```
本次改动是否新功能？
├── 是 → 是否破坏向后兼容？
│        ├── 是 → MAJOR +1（v1 阶段后）
│        └── 否 → MINOR +1（v0.x → v0.(x+1)）
└── 否（bugfix） → PATCH +1（v0.x.y → v0.x.(y+1)）
```

## 7. 发布检查清单（精简）

发布日打印此清单逐项打勾：

```
□ main 与 origin 同步
□ git status 干净
□ 编辑器无错误
□ 通玩 5 分钟单局通过
□ release notes 写完
□ tag 已创建
□ tag 已 push
□ GitHub Release 已创建
□ ROADMAP 已更新
□ TASK_BACKLOG 已更新
□ 用户已确认完成
```

## 8. 历史发布记录

| 版本 | 日期 | 备注 |
|---|---|---|
| v0.1.0-mvp | （早期） | MVP |
| v0.2 | 未正式发布 | 功能完成，用户暂缓 |

## 9. 变更日志

| 日期 | 版本 | 变更 |
|---|---|---|
| 2026-05-23 | 0.1 | 首次建立 |
