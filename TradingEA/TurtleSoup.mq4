//+------------------------------------------------------------------+
//|                                                   TurtleSoup.mq4 |
//|                        Copyright 2021, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2021, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#define isZero(x) (fabs(x) < 0.000000001)
#define isEqual(x,y) (fabs(x-y) < 0.000000001)
#define isBigger(x,y) (x-y >= 0.000000001)
#define isSmaller(x,y) (x-y <= -0.000000001)

extern int MAGICNO = 5;
input double   RISK = 0.01;
input double   NOTIONAL_BALANCE = 2000;
input int BASE_TERM_FOR_BREAKOUT = 20;

input ENUM_TIMEFRAMES BREAKOUT_TIMEFRAME = PERIOD_D1;
input ENUM_TIMEFRAMES TRAILING_STOP_TIMEFRAME = PERIOD_M5;

bool IsPositionExist = false;
int CURRENT_CMD = OP_BUY; // 0 : Buy  1 : Sell
int CURRENT_POSITION_TICKET_NUMBER = 0;
double R_VALUE = 0;
double TARGET_BUY_PRICE, TARGET_SELL_PRICE, TARGET_STOPLOSS_PRICE;
double TRADABLE_UNIT_SIZE;
bool SETUP_CONDITION_MADE = false;
int currentDate = 0;
int lastCheckedTime=0;
double ORDER_OPEN_PRICE = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
    datetime currentTime = TimeCurrent();
    int currentCheckTime = TimeMinute(currentTime);

    if (lastCheckedTime == currentCheckTime) {
        return;
    }
    else {
        lastCheckedTime = currentCheckTime;
    }

    Comment(StringFormat("R Value : %f\nTargetBuy = %f\nTargetSell = %f\nTARGET_STOPLOSS_PRICE = %f\n",
        R_VALUE, TARGET_BUY_PRICE, TARGET_SELL_PRICE, TARGET_STOPLOSS_PRICE));

    if (IsPositionExist) {
        checkStopLoss();
    }
    else {
        MqlDateTime strDate;
        TimeToStruct(currentTime, strDate);

        // Daily Update
        if (strDate.day != currentDate) {
            currentDate = strDate.day;
            checkSetup();
        }

        checkBreakout();
    }
  }
//+------------------------------------------------------------------+

void checkBreakout() {
    if (isZero(TARGET_STOPLOSS_PRICE)) return;

    double currentPrice = Close[0];
    int ticketNum = -1;

    // Buy 포지션에서 돌파하는 경우
    if (!isZero(TARGET_BUY_PRICE)) {
        if (isBigger(currentPrice, TARGET_BUY_PRICE)) {
            R_VALUE = currentPrice - TARGET_STOPLOSS_PRICE;
            TRADABLE_UNIT_SIZE = getUnitSize();
            if (isZero(TRADABLE_UNIT_SIZE)) return;

            ticketNum = OrderSend(NULL, OP_BUY, TRADABLE_UNIT_SIZE, Ask, 3, 0, 0, "", MAGICNO, 0, clrBlue);
            if (ticketNum < 0) {
                Print("OrderSend failed with error #",GetLastError());
            }
            else {
                CURRENT_POSITION_TICKET_NUMBER = ticketNum;
                IsPositionExist = true;
                CURRENT_CMD = OP_BUY;
            }
        }
    }
    // Sell 포지션
    else if (!isZero(TARGET_SELL_PRICE)) {
        if (isSmaller(currentPrice, TARGET_SELL_PRICE)) {
            R_VALUE = TARGET_STOPLOSS_PRICE - currentPrice;
            TRADABLE_UNIT_SIZE = getUnitSize();
            if (isZero(TRADABLE_UNIT_SIZE)) return;

            ticketNum = OrderSend(NULL, OP_SELL, TRADABLE_UNIT_SIZE, Bid, 3, 0, 0, "", MAGICNO, 0, clrBlue);
            if (ticketNum < 0) {
                Print("OrderSend failed with error #",GetLastError());
            }
            else {
                CURRENT_POSITION_TICKET_NUMBER = ticketNum;
                IsPositionExist = true;
                CURRENT_CMD = OP_SELL;
            }
        }
    }
}

void checkSetup() {
    // 현재 가격이 신저가, 신고가인지 체크하는 로직
    // 이전의 고가, 저가가 발생한 날과의 날짜 차이 체크하기
    // close 가격이 이전의 고가, 저가 보다 바깥인지 체크하기
    // TARGET 가격을 이전의 고가, 저가로 세팅하고  SL은 새로 만들어진 고가, 저가.
    TARGET_BUY_PRICE = 0;
    TARGET_SELL_PRICE = 0;
    TARGET_STOPLOSS_PRICE = 0;
    TRADABLE_UNIT_SIZE = 0;
    ORDER_OPEN_PRICE = 0;

    int highBarIndex = iHighest(NULL, BREAKOUT_TIMEFRAME, MODE_HIGH, BASE_TERM_FOR_BREAKOUT, 1);
    int lowBarIndex = iLowest(NULL, BREAKOUT_TIMEFRAME, MODE_LOW, BASE_TERM_FOR_BREAKOUT, 1);

    if (highBarIndex == 1) {
        int previousHighIndex = iHighest(NULL, BREAKOUT_TIMEFRAME, MODE_HIGH, BASE_TERM_FOR_BREAKOUT - 1, 2);
        PrintFormat("Cur Date : %d :: New High : 1,  Prev High : %d", currentDate, previousHighIndex);

        if (previousHighIndex - highBarIndex >= 3) {
            double day1Close = iClose(NULL, BREAKOUT_TIMEFRAME, 1);
            double prevHighPrice = iHigh(NULL, BREAKOUT_TIMEFRAME, previousHighIndex);
            if (day1Close >= prevHighPrice) {
                TARGET_BUY_PRICE = -1;
                TARGET_SELL_PRICE = prevHighPrice;
                TARGET_STOPLOSS_PRICE = iHigh(NULL, BREAKOUT_TIMEFRAME, 1);
            }
            else {
                Print("Close should be above previous High");
            }
        }
        else {
            Print("Need gap between High Index");
        }
    }
    else if (lowBarIndex == 1) {
        int previousLowIndex = iLowest(NULL, BREAKOUT_TIMEFRAME, MODE_LOW, BASE_TERM_FOR_BREAKOUT - 1, 2);
        PrintFormat("Cur Date : %d :: New Low : 1,  Prev Low : %d", currentDate, previousLowIndex);

        if (previousLowIndex - lowBarIndex >= 3) {
            double day1Close = iClose(NULL, BREAKOUT_TIMEFRAME, 1);
            double prevLowPrice = iLow(NULL, BREAKOUT_TIMEFRAME, previousLowIndex);
            if (day1Close <= prevLowPrice) {
                TARGET_SELL_PRICE = -1;
                TARGET_BUY_PRICE = prevLowPrice;
                TARGET_STOPLOSS_PRICE = iLow(NULL, BREAKOUT_TIMEFRAME, 1);
            }
            else {
                Print("Close should be below previous Low");
            }
        }
        else {
            Print("Need gap between Low Index");
        }
    }
}

double getUnitSize() {
    double tradableLotSize = 0;

    double tickValue = MarketInfo(NULL, MODE_TICKVALUE);
    double tickSize = MarketInfo(NULL, MODE_TICKSIZE);
    double tradableMinLotSize = MarketInfo(NULL, MODE_MINLOT);

    if (isZero(tickValue) || isZero(tickSize) || isZero(tradableMinLotSize)) {
        Print("getUnitSize:: Cannot get MarketInfo");
    }
    else {
        double DOLLAR_PER_POINT = tickValue / tickSize;
        double dollarVolatility = R_VALUE * DOLLAR_PER_POINT;
        double maxRiskForAccount = NOTIONAL_BALANCE * RISK;
        double maxLotBasedOnDollarVolatility = maxRiskForAccount / dollarVolatility;
        double requiredMinBalance = tradableMinLotSize * dollarVolatility / RISK;

        if (maxLotBasedOnDollarVolatility >= tradableMinLotSize) {
            tradableLotSize = maxLotBasedOnDollarVolatility - MathMod(maxLotBasedOnDollarVolatility, tradableMinLotSize);
        }
        else {
            PrintFormat("You need at least %f for risk management. Find other item.", requiredMinBalance);
        }
    }

    return tradableLotSize;
}

void checkStopLoss() {
    double currentPrice = Close[0];

    if (CURRENT_CMD == OP_BUY) {
        if (isSmaller(currentPrice,TARGET_STOPLOSS_PRICE)) {
            closeOrder();
        }
        else {
            double curLowPrice = 0;
            int lowBarIndex = iLowest(NULL, TRAILING_STOP_TIMEFRAME, MODE_LOW, 10, 1);
            if (lowBarIndex == -1) curLowPrice = -9999999999;
            else curLowPrice = iLow(NULL, TRAILING_STOP_TIMEFRAME, lowBarIndex);

            if (isBigger(curLowPrice, TARGET_STOPLOSS_PRICE)) {
                TARGET_STOPLOSS_PRICE = curLowPrice;
            }
        }
    }
    else if (CURRENT_CMD == OP_SELL) {
        if (isBigger(currentPrice, TARGET_STOPLOSS_PRICE)) {
            closeOrder();
        }
        else {
            double curHighPrice = 0;
            int highBarIndex = iHighest(NULL, TRAILING_STOP_TIMEFRAME, MODE_HIGH, 10, 1);
            if (highBarIndex == -1) curHighPrice = 99999999999999;
            else curHighPrice = iHigh(NULL, TRAILING_STOP_TIMEFRAME, highBarIndex);

            if (isSmaller(curHighPrice, TARGET_STOPLOSS_PRICE)) {
                TARGET_STOPLOSS_PRICE = curHighPrice;
            }
        }
    }
}

void closeOrder() {
    if (OrderSelect(CURRENT_POSITION_TICKET_NUMBER, SELECT_BY_TICKET, MODE_TRADES)) {
        if (CURRENT_CMD == OP_BUY) {
            if (!OrderClose(OrderTicket(), OrderLots(), Bid, 3, White)) {
                PrintFormat("Fail OrderClose : Order ID = ", CURRENT_POSITION_TICKET_NUMBER);
            }
            else {
                IsPositionExist = false;
                datetime currentTime = TimeCurrent();
                MqlDateTime strDate;
                TimeToStruct(currentTime, strDate);
                currentDate = strDate.day;

                checkSetup();
            }
        }
        else {
            if (!OrderClose(OrderTicket(), OrderLots(), Ask, 3, White)) {
                PrintFormat("Fail OrderClose : Order ID = ", CURRENT_POSITION_TICKET_NUMBER);
            }
            else {
                IsPositionExist = false;
                datetime currentTime = TimeCurrent();
                MqlDateTime strDate;
                TimeToStruct(currentTime, strDate);
                currentDate = strDate.day;

                checkSetup();
            }
        }
    }
}
