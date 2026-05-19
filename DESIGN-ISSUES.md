# EMA PA - Brooks 设计问题待讨论

**版本：v1.2 | 日期：2025-05 | 品种：ES | 周期：5min | 状态：草稿**

> 本文档列出经 Al Brooks 价格行为视角审视后发现的设计问题。
> 按优先级分层，每条都需要你的确认后再动代码。

---

## 一、高优先（影响信号质量）

### B1. `pbLookback` 默认值 10 根 K 线偏宽

| 项 | 当前 | 建议 |
|---|---|---|
| `pbLookback` 默认 | 10 | 3-4 |

**现状**：`priorTouchBuy` 判定"最近 N 根 K 内任意一根触及 EMA21"。10 根前触及过、之后走了 9 根远离 EMA 的 K——这已不是"对 EMA 的紧凑回调"。

**Brooks 视角**：H1/H2 回调经典形态是"1-3 根 K 的浅回调"。超过 4-5 根 K 的回调通常已经形成新的 leg，不应再视为"回调反弹"而给信号。

**风险**：减小此值会**减少信号数量**，可能过滤掉一些二腿回调（two-leg pullback）。

**改动量**：1 个数字。

---

### B2. 入场价 vs TP 计算基准的 R 距离不一致

**现状**：

```plain
触发条件: close > high[1]  → 实际入场 ≈ close
TP 计算:  entryBuy = high[1], R = high[1] - SL
TP1 = high[1] + R
```

**问题**：实际入场价（close）往往 > high[1]，但 TP 基于 high[1] 算——导致 R 距离"虚标"，1R 可能在入场时已经接近甚至已被穿越。

**两个修复路径**：

| 路径 | 改动 | 优劣 |
|---|---|---|
| A. 改成挂止损单语义 | `close > high[1]` → `high > high[1]`（模拟 buy stop 挂单）| 更贴 Brooks H1/H2 进场方式；但需配合 `barstate.isconfirmed` 防重绘 |
| B. TP 基于实际入场价 | `entryBuy = high[1]` → `entryBuy = close` | 与当前触发逻辑一致，R 距离更真实；但 R 变大，TP 更远 |

**建议**：路径 B（保守，不改信号触发逻辑）。

---

### B3. 缺少 always-in 方向 / leg 计数

**现状**：方向过滤只用 `ema1 > ema2` + `slopeFilter`。

**Brooks 核心**：

+ always-in 方向（多/空/unclear 三态）是做任何 trade 的前提
+ leg 计数：H1 > H2 > H3，H3 之后 trade range 概率飙升
+ spike & channel vs trading range vs 强 trend day 区分

**缺少影响**：当前系统可能在 leg 5 的回调里仍然给信号（实际此处 H5，胜率极低）。

**实施规模**：大改（新增 leg 计数器 + spike/channel/TR 三态检测）。建议作为 v2.0 迭代。

---

## 二、中优先（trade management 缺失）

### B4. 没有 BE 移动（1R 锁损）

**Brooks scalp 经典**：当 `high >= entry + 1R` 时，把 SL 移到 entry（或 entry - 1 tick）——"free trade"。

**现状**：SL 一直停在 signal bar low，不会移动。

**实施量**：约 4 行新代码（在持仓中检测 high >= TP1，把 activeBuySL := entryBuy）。

---

### B5. 没有 failure trade 检测

**Brooks**："signal bar + entry bar + 第二根 K 跌破 entry bar low → failure → exit"。

**现状**：必须等价格触及 SL low 才出场。failure trade 可能在 SL 之前就应该离场。

**实施量**：中等（新增"entry bar 后第 2-3 根 K 跌破 entry bar low"检测）。

---

### B6. 没有 partial exit（1R 平半 / 2R 平剩）

**Brooks scalp/swing 混合**：1R 平一半仓位，剩余挂 BE 止损等 2R。

**现状**：indicator 不能真正平仓，但可以用不同标签/颜色提示"1R 已达"。

**实施量**：小（检测 high >= TP1 后画一个标签"1R hit"）。

---

## 三、低优先（边界优化）

### B7. `avoidNarrowMiddle` 门槛偏松

**现状**：

```plain
avoidNarrowMiddle = not (not rangeWideEnough and isRangeMiddle)
                  = rangeWideEnough or not isRangeMiddle
```

含义：只在**区间狭窄时**才避开 middle。区间宽时即使在 middle 也照样进。

**Brooks 视角**：trading range 的 middle 永远是低胜率区域——不该按区间宽窄区别对待。

**建议**：改为 `avoidNarrowMiddle = not isRangeMiddle`（无论宽窄都避开 middle）。

**代价**：会**显著减少信号数量**。

---

### B8. SL 距离对 5min ES 可能偏小

**现状**：默认用 signal bar low——通常只有 1-3 points（ES 5min），被 noise 打掉概率高。

**Brooks**：5min ES 常用 4-8 points 的 SL。

**建议**：加 `minSLAtrMul` input（默认 0.8），SL 取 `math.max(buySLPrice, entryBuy - minSLAtrMul * atr)`。

**代价**：新增 1 个 input，改变部分信号的 R 距离计算。

---

## 四、swingBuyStop 包含当前 entry bar

**现状**：`swingBuyStop = ta.lowest(low, swingStopLookback)` 包含当前 bar 的 low。

**问题**：如果 entry bar 本身有长下影，会把 SL 拉远（不合理）。

**建议**：`swingBuyStop = ta.lowest(low, swingStopLookback)[1]`（截止前一根 K）。

**影响**：仅在 `stopMode = "Swing Pivot"` 时生效。

---

## 五、行动建议

| 编号 | 改动量 | 推荐纳入版本 |
|---|---|---|
| B1 | 1 个数字 | v1.3（确认后立即改） |
| B2 | 2 行 | v1.3（选 A 或 B 后立即改） |
| B3 | 大 | v2.0（需设计文档） |
| B4 | 4 行 | v1.3（确认后立即改） |
| B5 | 中 | v1.4 |
| B6 | 小 | v1.3 |
| B7 | 1 行 | v1.3（确认后立即改） |
| B8 | 3 行 | v1.3（确认后立即改） |
| 四 | 1 行 | v1.3 |

---

> 请逐条回复 "做" / "不做" / "再讨论"，我按你的决定批量执行。
