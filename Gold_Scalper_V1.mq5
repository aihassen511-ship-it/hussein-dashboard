//+------------------------------------------------------------------+
//|                                       Gold_Scalper_V1.mq5        |
//|                        Copyright 2026, AI Assistant                |
//|                                             https://www.mql5.com   |
//+------------------------------------------------------------------+
//| TIME ZONE INFO (Makkah/Saudi Arabia)                               |
//| Makkah is UTC+3 (no DST)                                           |
//| London is UTC+0 (winter) or UTC+1 (summer)                         |
//|                                                                    |
//| BEST TRADING TIME FOR GOLD:                                        |
//| London-NY Overlap: 08:00-11:00 London Time                         |
//|                    = 11:00-14:00 Makkah Time                       |
//|                    = 11:00 صباحاً - 2:00 ظهراً مكة                 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, AI Assistant"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Input Parameters                                                   |
//+------------------------------------------------------------------+
input group "=== Risk Management ==="
input double   RiskPercent       = 1.0;        // Risk per trade (%)
input double   RRRatio           = 1.5;        // Risk:Reward Ratio
input int      MaxOrders         = 3;          // Max open orders
input double   MaxDailyLoss      = 3.0;        // Max daily loss (%)
input bool     UseTrailingStop   = true;       // Use trailing stop
input int      TrailingStart     = 10;         // Trailing start (pips)

input group "=== EMA Settings ==="
input int      EMAFast           = 9;          // EMA Fast period
input int      EMASlow           = 21;         // EMA Slow period
input int      EMATrend          = 50;         // EMA Trend period

input group "=== RSI Settings ==="
input int      RSIPeriod         = 14;         // RSI period
input int      RSIOverbought     = 70;         // RSI overbought
input int      RSIOversold       = 30;         // RSI oversold
input int      RSIMinLong        = 40;         // RSI min for long
input int      RSIMaxLong        = 65;         // RSI max for long
input int      RSIMinShort       = 35;         // RSI min for short
input int      RSIMaxShort       = 60;         // RSI max for short

input group "=== ATR Settings ==="
input int      ATRPeriod         = 14;         // ATR period
input double   ATRMultiplierSL   = 1.5;        // ATR multiplier for SL
input double   ATRMultiplierTP   = 2.25;       // ATR multiplier for TP

input group "=== Time Filter (Makkah Time) ==="
input bool     UseTimeFilter     = true;       // Use time filter
input int      StartHour         = 11;         // Trading start hour (Makkah Time)
                                               // London 8:00 = Makkah 11:00
                                               // London-NY Overlap: 11:00-14:00 Makkah
input int      EndHour           = 14;         // Trading end hour (Makkah Time)
                                               // London 11:00 = Makkah 14:00
input bool     FridayTrading     = false;      // Allow Friday trading (Jumuah)

//+------------------------------------------------------------------+
//| Global Variables                                                   |
//+------------------------------------------------------------------+
int    g_magicNumber = 123456;
double g_dailyLoss = 0;
datetime g_lastDay = 0;
int    g_orderCount = 0;

// Indicator handles
int    g_emaFastHandle, g_emaSlowHandle, g_emaTrendHandle;
int    g_rsiHandle;
int    g_atrHandle;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize indicator handles
   g_emaFastHandle = iMA(NULL, PERIOD_M1, EMAFast, 0, MODE_EMA, PRICE_CLOSE);
   g_emaSlowHandle = iMA(NULL, PERIOD_M1, EMASlow, 0, MODE_EMA, PRICE_CLOSE);
   g_emaTrendHandle = iMA(NULL, PERIOD_M1, EMATrend, 0, MODE_EMA, PRICE_CLOSE);
   g_rsiHandle = iRSI(NULL, PERIOD_M1, RSIPeriod, PRICE_CLOSE);
   g_atrHandle = iATR(NULL, PERIOD_M1, ATRPeriod);
   
   // Check if indicators created successfully
   if(g_emaFastHandle == INVALID_HANDLE || g_emaSlowHandle == INVALID_HANDLE ||
      g_emaTrendHandle == INVALID_HANDLE || g_rsiHandle == INVALID_HANDLE ||
      g_atrHandle == INVALID_HANDLE)
   {
      Print("Error creating indicators");
      return(INIT_FAILED);
   }
   
   Print("Gold Scalper V1 initialized successfully");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   IndicatorRelease(g_emaFastHandle);
   IndicatorRelease(g_emaSlowHandle);
   IndicatorRelease(g_emaTrendHandle);
   IndicatorRelease(g_rsiHandle);
   IndicatorRelease(g_atrHandle);
   
   Print("Gold Scalper V1 deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // Reset daily loss counter
   datetime currentDay = TimeCurrent() / 86400 * 86400;
   if(currentDay != g_lastDay)
   {
      g_dailyLoss = 0;
      g_lastDay = currentDay;
   }
   
   // Check daily loss limit
   if(g_dailyLoss >= MaxDailyLoss * AccountBalance() / 100)
   {
      return; // Stop trading for today
   }
   
   // Update order count
   CountOpenOrders();
   
   // Check if we can open new orders
   if(g_orderCount >= MaxOrders)
      return;
   
   // Check time filter (Makkah Time: 11:00-14:00 = Best London-NY overlap)
   if(UseTimeFilter && !IsTradingTime())
      return;
   
   // Get indicator values
   double emaFast, emaSlow, emaTrend, rsi, atr;
   if(!GetIndicatorValues(emaFast, emaSlow, emaTrend, rsi, atr))
      return;
   
   // Check for buy signal
   if(CheckBuySignal(emaFast, emaSlow, emaTrend, rsi))
   {
      OpenBuyOrder(atr);
   }
   // Check for sell signal
   else if(CheckSellSignal(emaFast, emaSlow, emaTrend, rsi))
   {
      OpenSellOrder(atr);
   }
   
   // Manage open positions
   ManageOpenPositions();
}

//+------------------------------------------------------------------+
//| Get indicator values                                               |
//+------------------------------------------------------------------+
bool GetIndicatorValues(double &emaFast, double &emaSlow, double &emaTrend, 
                        double &rsi, double &atr)
{
   if(CopyBuffer(g_emaFastHandle, 0, 0, 1, emaFast) != 1) return false;
   if(CopyBuffer(g_emaSlowHandle, 0, 0, 1, emaSlow) != 1) return false;
   if(CopyBuffer(g_emaTrendHandle, 0, 0, 1, emaTrend) != 1) return false;
   if(CopyBuffer(g_rsiHandle, 0, 0, 1, rsi) != 1) return false;
   if(CopyBuffer(g_atrHandle, 0, 0, 1, atr) != 1) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Check buy signal                                                   |
//+------------------------------------------------------------------+
bool CheckBuySignal(double emaFast, double emaSlow, double emaTrend, double rsi)
{
   // Price must be above EMA 50 (uptrend)
   if(Close[0] <= emaTrend)
      return false;
   
   // EMA 9 > EMA 21 (bullish)
   if(emaFast <= emaSlow)
      return false;
   
   // RSI between 40-65 (not overbought)
   if(rsi < RSIMinLong || rsi > RSIMaxLong)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Check sell signal                                                  |
//+------------------------------------------------------------------+
bool CheckSellSignal(double emaFast, double emaSlow, double emaTrend, double rsi)
{
   // Price must be below EMA 50 (downtrend)
   if(Close[0] >= emaTrend)
      return false;
   
   // EMA 9 < EMA 21 (bearish)
   if(emaFast >= emaSlow)
      return false;
   
   // RSI between 35-60 (not oversold)
   if(rsi < RSIMinShort || rsi > RSIMaxShort)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Open buy order                                                     |
//+------------------------------------------------------------------+
void OpenBuyOrder(double atr)
{
   double price = Ask;
   double sl = NormalizeDouble(price - (atr * ATRMultiplierSL), Digits);
   double tp = NormalizeDouble(price + (atr * ATRMultiplierTP), Digits);
   
   double lotSize = CalculateLotSize(price - sl);
   if(lotSize <= 0) return;
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = Symbol();
   request.volume = lotSize;
   request.type = ORDER_TYPE_BUY;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 10;
   request.magic = g_magicNumber;
   request.comment = "Gold Scalper V1 Buy";
   
   if(!OrderSend(request, result))
   {
      Print("OrderSend error: ", GetLastError());
   }
   else
   {
      Print("Buy order opened: ", result.order);
   }
}

//+------------------------------------------------------------------+
//| Open sell order                                                    |
//+------------------------------------------------------------------+
void OpenSellOrder(double atr)
{
   double price = Bid;
   double sl = NormalizeDouble(price + (atr * ATRMultiplierSL), Digits);
   double tp = NormalizeDouble(price - (atr * ATRMultiplierTP), Digits);
   
   double lotSize = CalculateLotSize(sl - price);
   if(lotSize <= 0) return;
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = Symbol();
   request.volume = lotSize;
   request.type = ORDER_TYPE_SELL;
   request.price = price;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 10;
   request.magic = g_magicNumber;
   request.comment = "Gold Scalper V1 Sell";
   
   if(!OrderSend(request, result))
   {
      Print("OrderSend error: ", GetLastError());
   }
   else
   {
      Print("Sell order opened: ", result.order);
   }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                                   |
//+------------------------------------------------------------------+
double CalculateLotSize(double slDistance)
{
   if(slDistance <= 0) return 0;
   
   double tickValue = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_SIZE);
   double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   
   if(tickValue == 0) return 0;
   
   double riskAmount = AccountBalance() * RiskPercent / 100;
   double slTicks = slDistance / tickSize;
   double lotSize = riskAmount / (slTicks * tickValue);
   
   // Normalize to lot step
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   
   // Apply min/max limits
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| Count open orders                                                  |
//+------------------------------------------------------------------+
void CountOpenOrders()
{
   g_orderCount = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(PositionGetString(POSITION_SYMBOL) == Symbol() &&
         PositionGetInteger(POSITION_MAGIC) == g_magicNumber)
      {
         g_orderCount++;
      }
   }
}

//+------------------------------------------------------------------+
//| Check trading time                                                 |
//+------------------------------------------------------------------+
bool IsTradingTime()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // Check Friday
   if(dt.day_of_week == 5 && !FridayTrading)
      return false;
   
   int currentHour = dt.hour;
   
   // Handle time range
   if(StartHour < EndHour)
   {
      return (currentHour >= StartHour && currentHour < EndHour);
   }
   else
   {
      return (currentHour >= StartHour || currentHour < EndHour);
   }
}

//+------------------------------------------------------------------+
//| Manage open positions                                              |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(PositionGetString(POSITION_SYMBOL) != Symbol() ||
         PositionGetInteger(POSITION_MAGIC) != g_magicNumber)
         continue;
      
      // Update daily loss
      double profit = PositionGetDouble(POSITION_PROFIT);
      if(profit < 0)
         g_dailyLoss += MathAbs(profit);
      
      // Trailing stop
      if(UseTrailingStop)
         ApplyTrailingStop(ticket);
   }
}

//+------------------------------------------------------------------+
//| Apply trailing stop                                                |
//+------------------------------------------------------------------+
void ApplyTrailingStop(ulong ticket)
{
   if(!PositionSelectByTicket(ticket))
      return;
   
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   
   double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   double trailingDistance = TrailingStart * 10 * point; // Convert pips to price
   
   if(posType == POSITION_TYPE_BUY)
   {
      double newSL = Bid - trailingDistance;
      if(Bid - openPrice > trailingDistance && newSL > currentSL)
      {
         ModifyPosition(ticket, newSL, currentTP);
      }
   }
   else if(posType == POSITION_TYPE_SELL)
   {
      double newSL = Ask + trailingDistance;
      if(openPrice - Ask > trailingDistance && (newSL < currentSL || currentSL == 0))
      {
         ModifyPosition(ticket, newSL, currentTP);
      }
   }
}

//+------------------------------------------------------------------+
//| Modify position                                                    |
//+------------------------------------------------------------------+
bool ModifyPosition(ulong ticket, double sl, double tp)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.symbol = Symbol();
   request.sl = sl;
   request.tp = tp;
   
   if(!OrderSend(request, result))
   {
      Print("ModifyPosition error: ", GetLastError());
      return false;
   }
   
   return true;
}
//+------------------------------------------------------------------+
