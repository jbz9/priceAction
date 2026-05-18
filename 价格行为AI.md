导师我们一起分步完成，帮助我去完成。

# ES 5分钟交易系统设计蓝图
## 1. 已确定参数
+ **交易品种**：ES (S&P 500 E-mini Futures)
+ **交易周期**：5分钟 (5min)
+ **核心模式**：优先聚焦 **H2**（后续拓展：L2，以及第2种：Failed Breakout at Range Edge）

## 2. 设计前提与原则
+ **多头优先**：鉴于 ES 品种的天然多头属性，首期只设计 **H2 买入逻辑**。L2（卖出）仅在后续特定大周期背景下作为补充。
+ **高质量过滤**：EA 的核心目的是**识别并过滤低质量交易**，而非一味追求历史数据的完美拟合（Curve-fitting）。
+ 交易时间：美盘时间

## 3. 设计模块（分步实施）
### 界定 ES 的高质量 H2 触发逻辑，以及背景过滤
       确定模式： Strong Trend Pullback H2 ， 高质量趋势恢复  

在5分钟周期确定：

EMA20：

      1、ema向上定义： 使用ATR 标准化 ,再平滑 ,阈值使用0.15。注：**1 小时图**上计算 acceleration （防止L趋势已经衰竭 → EMA还在上方且斜率还是正的→ 系统误判为强趋势 → H2入场 → 被套），或采用更好方案

```plain
EMA20 向上 =
  smoothed_slope > 0.15

其中：
  slope        = (EMA20[0] - EMA20[5]) / ATR14[0]
  smoothed_slope = (slope[0] + slope[1] + slope[2]) / 3
```

          2、1小时过滤：过滤掉5分钟是强趋势，但1H还是AIS。【主过滤 - 必须通过】 ✅ 5min EMA20 slope > 0.15（已定义） ✅ 1H EMA20 slope > 0（方向过滤） 【辅助过滤 - 必须通过】 ✅ 1H 最近回调幅度 < 前段上涨的 50% ✅ 1H 不处于大交易区间中段 （range width > 3×ATR 且价格在区间 30%–70% 位置）  

  	结构定义：①定义强趋势，什么趋势是强趋势，强趋势是否是 Always In Long（AIL）  ，H2的成功率高。

```plain
# ================================================================
# ES 5min — Strong Bull Trend Filter v0.5
# Purpose: 判断5分钟图是否处于强多头趋势
# ================================================================

Strong_Bull_Trend_5m =
    Direction_Up_5m
    AND Price_Acceptance_Above_EMA20
    AND Bull_Bar_Quality_OK
    AND Swing_Structure_Long_OK
    AND No_Bear_Reversal_Pressure


# [1] Direction_Up_5m
# EMA20方向，ATR标准化斜率
# 注：全部使用已收盘K线，避免使用当前未收盘bar

slope(i) =
    (EMA20[i] - EMA20[i+5]) / ATR14[i]

smoothed_slope =
    average(slope[1], slope[2], slope[3])

Direction_Up_5m =
    smoothed_slope > 0.15


# [2] Price_Acceptance_Above_EMA20
# 价格是否被持续接受在EMA20上方

Price_Acceptance_Above_EMA20 =
    count(close > EMA20, last 12 closed bars) >= 8
    AND max_consecutive(close < EMA20, last 12 closed bars) < 3


# [3] Bull_Bar_Quality_OK
# 多头K线数量 + 强势多头K线数量

Bull_Close(i) =
    close[i] > open[i]

Strong_Bull_Bar(i) =
    close[i] > open[i]
    AND close[i] >= low[i] + 0.70 * range[i]
    AND body[i] >= 0.40 * ATR14[i]

Bull_Bar_Quality_OK =
    count(Bull_Close, last 12 closed bars) >= 7
    AND count(Strong_Bull_Bar, last 12 closed bars) >= 3


# [4] Swing_Structure_Long_OK
# 结构要求：Higher High + 前一个主要多头防守低点未被有效跌破
# 摆动点搜索窗口：最近50根已收盘K线

ValidSwingHigh(i) =
    2-bar PivotHigh(i)
    AND distance_from_previous_ValidSwingLow >= 0.75 * ATR14[i]
    AND bars_from_previous_swing >= 3

ValidSwingLow(i) =
    2-bar PivotLow(i)
    AND distance_from_previous_ValidSwingHigh >= 0.75 * ATR14[i]
    AND bars_from_previous_swing >= 3

2-bar PivotHigh(i) =
    high[i] > high[i-1]
    AND high[i] > high[i-2]
    AND high[i] > high[i+1]
    AND high[i] > high[i+2]

2-bar PivotLow(i) =
    low[i] < low[i-1]
    AND low[i] < low[i-2]
    AND low[i] < low[i+1]
    AND low[i] < low[i+2]

MajorSwingLow(i) =
    ValidSwingLow(i)
    AND max_high_after_this_low_within_20_bars - low[i] >= 1.25 * ATR14[i]

Higher_High_OK =
    most_recent_ValidSwingHigh(last 50 bars)
    >
    previous_ValidSwingHigh(last 50 bars) + 0.25 * ATR14

No_Clear_Break_Of_MajorLow =
    most_recent_ValidSwingLow(last 50 bars)
    >=
    previous_MajorSwingLow(last 50 bars) - 0.25 * ATR14

Swing_Structure_Long_OK =
    Higher_High_OK
    AND No_Clear_Break_Of_MajorLow


# [5] No_Bear_Reversal_Pressure
# 排除连续强空头反转压力

Strong_Bear_Bar(i) =
    close[i] < open[i]
    AND close[i] <= low[i] + 0.30 * range[i]
    AND body[i] >= 0.40 * ATR14[i]

Bear_Reversal_Pressure =
    any_consecutive_3(Strong_Bear_Bar, last 5 closed bars)

Strong_Bear_Reversal =
    any_consecutive_3(Strong_Bear_Bar, last 5 closed bars)
    AND newest_bar_of_that_3_bar_sequence close < EMA20

No_Bear_Reversal_Pressure =
    NOT Bear_Reversal_Pressure
    AND NOT Strong_Bear_Reversal


# ================================================================
# H2 Context Filter
# Purpose: 强趋势成立后，再判断当前回调是否适合寻找H2
# ================================================================

Strong_Trend_Pullback_Context_5m =
    Strong_Bull_Trend_5m
    AND Healthy_Pullback_OK


Healthy_Pullback_OK =
    Pullback_Ratio < 0.50
    AND Current_PB_Low > Leg_Start
    AND NOT any_consecutive_3(Strong_Bear_Bar, current pullback)

Leg_Start =
    most_recent MajorSwingLow(last 50 bars)

Leg_High =
    highest high after Leg_Start

Current_PB_Low =
    lowest low from Leg_High to current closed bar

Pullback_Ratio =
    (Leg_High - Current_PB_Low)
    /
    (Leg_High - Leg_Start)
```



                   ②先定义H1结构，H1需要合理，如果H1不合理，那么H2也不会合理

                    ③再定义H2结构，合理的H2	

- [ ] 步骤二：入场K线、跟随K线

```plain
# ================================================================
# ES 5min — 步骤二：入场K线 & 跟随K线 v0.2
# 前提：Valid_H2_Long_Setup = TRUE
# ================================================================


# [1] 入场触发

Entry_Price =
    high[H2_bar] + 1 tick

Entry_Order =
    Buy Stop @ Entry_Price
    有效期：H2_bar 收盘后的下一根bar

Signal_Expiry =
    若下一根bar结束仍未触发：
        撤单
        H2信号失效
        不追入


# [2] Entry Bar 定义

Entry_Bar =
    H2_bar 后下一根bar
    且该bar high >= Entry_Price

如果下一根bar没有触发 Entry_Price：
    无 Entry_Bar
    setup 失效


# [3] Entry Bar 质量分类
# 注意：这是成交后的质量评估，不是成交前过滤

Entry_Bar_Quality_OK =
    Entry_Bar_Size_OK
    AND NOT Entry_Bar_Overextended
    AND NOT Entry_Bar_Bearish_Close


Entry_Bar_Size_OK =
    range(Entry_Bar) <= 2.0 * ATR14

Entry_Bar_Overextended =
    low[Entry_Bar] > EMA20[Entry_Bar] + 1.5 * ATR14

Entry_Bar_Bearish_Close =
    close[Entry_Bar] < low[Entry_Bar] + 0.30 * range(Entry_Bar)


Strong_Entry_Bar =
    close[Entry_Bar] > open[Entry_Bar]
    AND close[Entry_Bar] >= low[Entry_Bar] + 0.70 * range(Entry_Bar)
    AND close[Entry_Bar] > Entry_Price
    AND range(Entry_Bar) <= 1.5 * ATR14


Weak_Entry_Bar =
    Entry_Bar 已触发
    AND (
        Entry_Bar_Quality_OK = FALSE
        OR close[Entry_Bar] < Entry_Price
        OR close[Entry_Bar] < low[Entry_Bar] + 0.50 * range(Entry_Bar)
    )


# [4] 跟随K线评估

Follow_Bar =
    Entry_Bar 之后的第一根已收盘bar


Strong_Follow_Through =
    close[Follow_Bar] > Entry_Price
    AND close[Follow_Bar] > open[Follow_Bar]
    AND close[Follow_Bar] >= low[Follow_Bar] + 0.60 * range(Follow_Bar)
    AND close[Follow_Bar] >= close[Entry_Bar]


Weak_Follow_Through =
    close[Follow_Bar] > Entry_Price
    AND (
        close[Follow_Bar] < low[Follow_Bar] + 0.50 * range(Follow_Bar)
        OR close[Follow_Bar] < open[Follow_Bar]
        OR close[Follow_Bar] < close[Entry_Bar]
    )


Failed_Follow_Through =
    close[Follow_Bar] <= Entry_Price
    OR low[Follow_Bar] < low[H2_bar]
    OR Strong_Bear_Bar(Follow_Bar)


# [5] 步骤二结果分类

High_Quality_Entry =
    Entry_Bar 已触发
    AND Entry_Bar_Quality_OK
    AND (
        Strong_Entry_Bar
        OR Strong_Follow_Through
    )
    AND NOT Failed_Follow_Through


Acceptable_Entry =
    Entry_Bar 已触发
    AND Entry_Bar_Quality_OK
    AND Weak_Follow_Through
    AND NOT Failed_Follow_Through


Low_Quality_Entry =
    Weak_Entry_Bar
    OR Failed_Follow_Through


# [6] 行为原则

IF High_Quality_Entry:
    正常持仓
    进入步骤三：止损、止盈、移动止损

IF Acceptable_Entry:
    持仓但进入 Defensive_Mode
    后续不再加仓
    步骤三中考虑更快保本或缩短目标

IF Low_Quality_Entry:
    不再视为高质量H2
    若尚未成交：撤单
    若已成交：进入防守处理
```

- [ ] 步骤三：止损和止盈

```plain
# ================================================================
# ES 5min — 步骤三：止损 & 止盈 v0.2
# 原则：止损、目标、R:R 在入场前完成；成交后再管理
# ================================================================


# ================================================================
# [1] 入场前风险定义
# ================================================================

Entry_Price =
    high[H2_bar] + 1 tick

Initial_Stop =
    low[H2_bar] - 1 tick

Stop_Distance =
    Entry_Price - Initial_Stop


# [1.1] 最大止损过滤

Max_Stop_OK =
    Stop_Distance <= 1.5 * ATR14

如果 Max_Stop_OK = FALSE：
    取消本次交易


# [1.2] 最小止损过滤
# 防止止损太窄，被ES正常噪音扫掉

Min_Stop_OK =
    Stop_Distance >= 0.35 * ATR14

如果 Min_Stop_OK = FALSE：
    取消本次交易
    或将止损改为 Current_PB_Low - 1 tick 后重新计算


# [1.3] 结构止损检查

Structure_Stop_OK =
    Initial_Stop <= Current_PB_Low
    OR abs(Initial_Stop - Current_PB_Low) <= 0.25 * ATR14

说明：
    理想状态下，H2_bar low 接近当前回调低点。
    如果 H2_bar low 远高于 Current_PB_Low，
    说明止损可能太浅，结构保护不足。


# ================================================================
# [2] 止盈定义
# ================================================================

Risk_R =
    Stop_Distance

Scalp_Target =
    Entry_Price + 1.0 * Risk_R

Swing_Target_Primary =
    Leg_High

Swing_Target_Extended =
    Current_PB_Low + (Leg_High - Leg_Start)


# [2.1] 前高空间检查

Leg_High_Too_Close =
    Leg_High - Entry_Price < 0.5 * ATR14

Swing_RR_OK =
    (Swing_Target_Primary - Entry_Price) / Risk_R >= 1.5

如果 Leg_High_Too_Close 或 Swing_RR_OK = FALSE：
    Trade_Mode = Scalp_Only
否则：
    Trade_Mode = Scalp_Plus_Swing


# [2.2] Scalp 目标有效性

Scalp_Target_OK =
    Risk_R <= 1.5 * ATR14
    AND Risk_R >= 0.35 * ATR14

说明：
    因为 Scalp_Target 本身定义为 1R，
    所以不需要再检查 RR 是否 >= 1。
    真正要检查的是这个 R 是否合理。


# ================================================================
# [3] 入场前检查清单
# ================================================================

Pre_Entry_OK =
    Valid_H2_Long_Setup
    AND Max_Stop_OK
    AND Min_Stop_OK
    AND Structure_Stop_OK
    AND Scalp_Target_OK

如果 Pre_Entry_OK = FALSE：
    不挂 Buy Stop

如果 Pre_Entry_OK = TRUE：
    挂 Buy Stop @ Entry_Price
    仅下一根bar有效


# ================================================================
# [4] 仓位分配
# ================================================================

如果 Trade_Mode = Scalp_Plus_Swing：
    Scalp_Portion = 50%
    Swing_Portion = 50%

如果 Trade_Mode = Scalp_Only：
    Scalp_Portion = 100%
    Swing_Portion = 0%


# ================================================================
# [5] 出场规则
# ================================================================

Initial Protective Stop:
    Stop = Initial_Stop


# [5.1] Scalp 部分

如果价格触及 Scalp_Target：
    平掉 Scalp_Portion


# [5.2] Swing 部分

如果 Swing_Portion > 0：

    阶段 1 — 入场后确认：
        IF Strong_Follow_Through:
            Swing_Stop = Entry_Price - 1 tick

    阶段 2 — 价格收盘突破 Leg_High：
        Swing_Stop =
            max(
                Entry_Price - 1 tick,
                Leg_High - 0.25 * ATR14,
                most_recent_2bar_low - 1 tick
            )

    阶段 3 — 趋势继续：
        Swing_Stop =
            max(
                Swing_Stop,
                most_recent ValidSwingLow(last 10 bars) - 1 tick
            )

    如果价格触及 Swing_Target_Extended：
        平掉全部 Swing_Portion


# ================================================================
# [6] 防守退出
# ================================================================

Defensive_Exit =
    Failed_Follow_Through
    OR close < Current_PB_Low
    OR close < EMA20 且出现 Strong_Bear_Bar
    OR 入场后 6 根bar内仍未达到 +0.5R

如果 Defensive_Exit：
    平掉剩余仓位
    本次交易结束


# ================================================================
# [7] 完整生命周期
# ================================================================

Reasonable_H2 收盘
    ↓
计算 Entry_Price / Initial_Stop / Stop_Distance
    ↓
Pre_Entry_OK ?
    否 → 不挂单
    是 → Buy Stop @ H2 high + 1 tick，仅下一根bar有效
    ↓
下一根bar触发？
    否 → 撤单，信号失效
    是 → 入场
    ↓
评估 Entry Bar / Follow Bar
    ↓
到达 Scalp_Target → 平 Scalp 部分
    ↓
Swing 部分：
    保本 → 突破前高锁利 → ValidSwingLow 跟踪
    ↓
到达 Extended Target 或 Defensive_Exit
    ↓
交易结束
```

