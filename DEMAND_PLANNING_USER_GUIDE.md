# Demand Planning Quick Reference

## For Planners & Managers

### Reading the Demand Planning Metrics Card

```
📊 Demand Planning Metrics
├─ Demand Variability: Low (CV: 0.25)
├─ 95% Confidence Interval (Next Month)
│  ├─ Lower: 450.00 m³ (worst case)
│  └─ Upper: 590.00 m³ (best case)
├─ Safety Stock Buffer: 85.00 m³
│  └─ Keep 85.00 m³ extra to handle demand spikes
└─ Reorder Point: 250.00 m³
   └─ Place next order when inventory reaches 250.00 m³
```

### Interpretation Guide

#### Demand Variability (CV)
- **Green (CV < 0.30)**: ✅ Stable demand
  - Can operate with lower safety stock
  - Forecasts are reliable
  - **Action**: Reduce buffer inventory

- **Yellow (CV 0.30-0.60)**: ⚠️ Moderate variability
  - Balance between service and cost
  - Forecasts are reasonably reliable
  - **Action**: Maintain current safety stock

- **Red (CV > 0.60)**: ⛔ High volatility
  - Demand is unpredictable
  - Need larger safety buffer
  - **Action**: Increase safety stock, investigate causes

#### Confidence Interval
- **Lower Bound**: Plan for worst-case scenario
  - Minimum inventory to maintain
  - Plan for slow months
  - Conservative planning

- **Upper Bound**: Plan for best-case scenario
  - Capacity needed for peak demand
  - Resource allocation planning
  - Growth planning

#### Safety Stock
- **What it means**: Extra inventory to buffer demand spikes
- **Example**: If Safety Stock = 85 m³
  - Keep minimum 85 m³ in reserve
  - Don't let inventory drop below this level
  - Prevents emergency orders

#### Reorder Point
- **What it means**: Automatic order trigger
- **Example**: If Reorder Point = 250 m³
  - When inventory hits 250 m³, place next order immediately
  - Ensures new stock arrives before depletion (7-day lead time)
  - Prevents stockouts

---

## Decision Framework

### Scenario 1: High Variability (CV > 0.60)
**Problem**: Demand is unpredictable
**Decisions**:
1. ✅ Increase safety stock
2. ✅ Lower reorder point (order more often)
3. ✅ Investigate causes:
   - Seasonal patterns?
   - External events?
   - Data quality issues?
4. ✅ Improve forecast accuracy

### Scenario 2: Low Variability (CV < 0.30)
**Problem**: Over-optimized (unlikely)
**Decisions**:
1. ✅ Reduce safety stock (free up capital)
2. ✅ Increase reorder point (order less frequently)
3. ✅ Consider JIT (Just-in-Time) ordering
4. ✅ Optimize warehouse space usage

### Scenario 3: Forecast Outside Confidence Interval
**Problem**: Actual demand ≠ predicted range
**Decisions**:
1. ✅ Check data quality
2. ✅ Investigate external factors (events, holidays)
3. ✅ Update assumptions (lead time, service level)
4. ✅ Retrain model with new data

---

## Monthly Decision Checklist

### Week 1 of Month:
- [ ] Review forecast accuracy (Actual vs. Forecast)
- [ ] Check model MAPE (target: < 15%)
- [ ] Identify anomalies or unexpected patterns
- [ ] Adjust next month's safety stock if needed

### Week 2 of Month:
- [ ] Monitor current inventory levels
- [ ] Place orders at reorder point
- [ ] Track lead times (are they still 7 days?)

### Week 3 of Month:
- [ ] Review demand variability trends
- [ ] Identify seasonal patterns
- [ ] Plan for next quarter

### Week 4 of Month:
- [ ] Forecast next 3 months
- [ ] Budget for safety stock costs
- [ ] Communicate forecasts to operations team

---

## Cost-Benefit Analysis

### Cost of Safety Stock
```
Monthly Cost = Safety Stock (m³) × Unit Cost ($/m³) × Storage Cost Rate
Example: 85 m³ × $2/m³ × 12% annual = ~$20/month
```

### Cost of Stockout
```
Lost Sales Cost = Stockout Quantity × Lost Profit per Unit
Brand Damage = Customer dissatisfaction (hard to quantify)
```

### Optimal Service Level
- **95% Service Level**: Most common
  - Acceptable for most businesses
  - Balances cost and service

- **90% Service Level**: Cost-focused
  - Lower safety stock needed
  - Acceptable stockouts up to 10% of time
  - Good for non-critical items

- **99% Service Level**: Service-focused
  - High safety stock needed
  - Essential for critical items
  - Higher carrying costs

---

## Common Questions

### Q: Why do I have a reorder point of 250 m³ when forecast is 520 m³?
**A**: Reorder point accounts for 7-day lead time + safety buffer
- You need inventory for orders arriving in next 7 days
- ~250 m³ covers that period + buffer
- By time new stock arrives, inventory is lower

### Q: My confidence interval is 450-590 m³, but I only have 400 m³ capacity
**A**: You have a stockout risk
- **Options**:
  1. Increase safety stock (will exceed capacity) → Not viable
  2. Reduce lead time (faster delivery)
  3. Reduce service level (accept more stockouts)
  4. Increase frequency of small orders
  5. Expand storage capacity

### Q: CV is 0.72, that's high. What should I do?
**A**: Investigate causes first:
1. Is there a seasonal pattern? (Add seasonal component to model)
2. Are there external events? (Adjust forecasts manually)
3. Is data quality poor? (Clean data, remove outliers)
4. Real high variability? (Accept higher safety stock costs)

### Q: Can I reduce my safety stock?
**A**: Only if you can accept higher stockout risk
- Reducing by 10% = 1-2% increase in stockout probability
- Cost savings: ~$2-3/month
- Value: Not usually worth it

---

## Key Metrics to Track

### Monthly Dashboard

| Metric | Target | Red Flag |
|--------|--------|----------|
| MAPE | < 15% | > 25% |
| Stockout Rate | < 5% | > 10% |
| Demand Variability (CV) | < 0.40 | > 0.70 |
| Service Level | 95% | < 90% |
| Inventory Turnover | 4-6x/year | < 2x/year |
| Safety Stock Utilization | 80-95% | < 50% or 100%+ |

---

## Integration with Operations

### When to Order:
```
Trigger: Current Inventory ≤ Reorder Point
Action: Place order for (Upper Bound - Current Level)
Timeline: Must arrive before Current Inventory depletes
```

### When to Investigate:
```
Trigger 1: Actual > Upper Confidence Bound (good luck!)
Trigger 2: Actual < Lower Confidence Bound (shortage)
Trigger 3: Demand Variability increases > 0.15 points
Action: Root cause analysis + Forecast adjustment
```

### When to Replan:
```
Frequency: Monthly (after first week)
Review: 3-month rolling forecast
Adjust: Safety stock, reorder point, service level
Communicate: Changes to warehouse, procurement, sales
```

---

## Advanced: Reducing Variability

### Strategy 1: Demand Smoothing
- Offer discounts for bulk orders
- Encourage customers to order in advance
- Result: Flatter demand curve

### Strategy 2: Supply Flexibility
- Increase order frequency (reduce safety stock)
- Negotiate flexible lead times
- Use multiple suppliers
- Result: Can react faster to changes

### Strategy 3: Data Intelligence
- Track cause of variability
- Separate predictable from random variation
- Model seasonal patterns separately
- Result: Better forecasts, lower CV needed

### Strategy 4: Process Optimization
- Reduce lead time (faster delivery = lower CV impact)
- Improve data quality (better forecasts)
- Coordinate across districts
- Result: More efficient operations

---

**Remember**: The goal is not zero stockouts or zero inventory cost. The goal is to balance **service** and **cost** for your business.

