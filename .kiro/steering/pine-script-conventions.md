---
inclusion: always
---

# pine-script-conventions — 本仓库 Pine 编辑约束

> 仓库级 steering，**始终自动加载**（适用于所有对话场景）。
> 完整 4-phase 工作流（含心智模拟模板等）在用户级 skill `pine-script-expert` 中，必要时 activate 它。
> 本文件是**强制要勾的清单**，不是教学。

## Pine 版本

- 默认 **v6**，兼容 **v5**
- 改既有文件保留其原版本；不主动升级版本号，除非用户要求

## 文件骨架（不许打乱顺序）

```
1. 文件头 + 版本号 + 变更日志（含本次 BugN 描述）
2. indicator() / strategy() / library() 声明
3. inputs（按业务 group=，每个 input 带 tooltip=）
4. 常量 + 通用 helper 函数
5. 数据获取（含 request.security，全部 lookahead_off）
6. 中间指标计算
7. 上下文判断（趋势 / 相位 / 回调 / 时段）
8. 状态机 / 信号识别
9. 风险 + 入场 + 持仓管理
10. 可视化（plot / plotshape / bgcolor）
11. alertcondition
12. 信息面板 / 调试输出
```

## 命名

- `camelCase`
- 布尔变量加 `is` / `has` / `should` / `can` 前缀
- bar 索引变量统一以 `BarIdx` 结尾
- ATR 倍数门槛命名 `xxxAtrMul`，**不允许裸数字**

## 生产就绪 Checklist（每次交付必须逐条勾）

- [ ] 编译通过（v5/v6 缩进、多行 `and/or` 表达式都过）
- [ ] **不重绘**：信号逻辑只读 `[1]` 或更早；没有 `lookahead=barmerge.lookahead_on`
- [ ] **无未来泄漏**：所有 `[i]`、`ta.*` 都核对过
- [ ] **Y 轴安全**：远端水平线被 toggle 包住或仅在持仓期画
- [ ] **对象上限显式**：`max_bars_back` / `max_labels_count` / `max_lines_count` / `max_polylines_count`
- [ ] **时区显式**：`hour()`、`session.regular` 等带 `"America/New_York"`（或用户指定）
- [ ] **tick 精度**：用 `syminfo.mintick`，禁止写死 `0.25` / `0.01` 等
- [ ] **状态机完整**：每个 state 既有 enter 又有 exit，不能永久卡死
- [ ] **告警齐全**：每个对外信号有 `alertcondition`，`message=` 含上下文
- [ ] **input 规范**：分组、tooltip、合理 default / step / minval / maxval
- [ ] **strategy 专项**：commission / slippage / process_orders_on_close / pyramiding 全部显式
- [ ] **变更日志**：文件头 `// vX.Y 修复（YYYY-MM）：- BugN: <根因> → <修复>`

## 反模式黑名单（看到必须拒绝或大声警告）

1. `request.security(..., lookahead=barmerge.lookahead_on)` 喂给信号
2. `bar_index == storedBarIdx` 渲染历史标记 → 改用不可变 detection 布尔（如 `h2Detected`）+ `offset=-1`
3. 状态机有 enter 没 exit
4. `plot()` 远离当前价的常量（拉爆 Y 轴）
5. `strategy.entry` 不带 `qty`，或 `strategy()` 不写 commission / slippage
6. 信号逻辑被 `if barstate.islast` 包住
7. 函数体内 `:=` 改外层 `var`（v5/v6 不允许，编译前就要警告）
8. session 字符串硬编码、不带时区参数
9. 信号逻辑用 `close`（当前可能未收盘）而不是 `close[1]`
10. `var int xxxBarIdx = 0` 然后直接和 `bar_index` 比较——区分不开"未设置"和"bar 0"
11. 多行表达式续行缩进列数是 **4 的倍数**（4/8/12/16/20/24/28…）→ Pine 解析器视为新代码块起始，报 `Syntax error at input 'end of line without line continuation'`。安全做法：单行书写，或续行用非 4 倍数缩进（如 2/6/9/10 空格）

## 交付时必须输出（每一项都不许省）

1. **生产就绪 Checklist**（上面那张，逐条勾）
2. **心智模拟**：3~5 个代表性场景的逐根 bar 推演，标注每个 `var` 在该 bar 进入前 / 离开后的值，以及画图结果。至少覆盖：1 个正常路径 + 1 个边界 / 拒绝路径 + 1 个之前出过 bug 的路径（如有）
3. **TradingView 验证清单**：用户能在 TV 客户端逐条点验的动作（symbol、timeframe、日期、期望标记、反例时段）
4. **已知风险 / 未覆盖**：仅靠静态分析无法判断的事项，明确写出来——禁止伪装完美

## 自修循环

- 上限 **3 轮**
- 第 3 轮仍未收敛 → **停**，把没解决的、试过什么、为什么没成 一并交给用户
- **不准静默交付半成品**

## 红线

1. 没跑完心智模拟不得声称"已完成"
2. 不得超过 3 轮自修循环
3. TradingView 验证步骤必须是真能点验的具体动作，不许编造
4. 不确定的事必须显式列入"已知风险"
