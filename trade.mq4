//+------------------------------------------------------------------+
//|                                                       Trader.mq5 |
//|                        Copyright 2014, MetaQuotes Software Corp. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2014, MetaQuotes Software Corp."
#property link      "http://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

#include <stdlib.mqh>
#include <stderror.mqh> 
#include <LinkedList.mqh>
// ------------------------------------------------------------------------------------------------
// VARIABLES EXTERNAS
// ------------------------------------------------------------------------------------------------

#define MAGIC_NUMBER 1245678
// Configuration
input int user_slippage = 2; 
input int user_tp = 60;
input int user_sl = 60;
input int use_tp_sl = 1;
input double profit_lock = 0.90;
// Money Management
input int money_management = 1;
input double min_lots = 0.01;
input double risk=0.01;
int progression = 0; // 0=none | 1:ascending | 2:martingale
// Indicator
int g_jaw = 13;
int g_teeth = 8;
int g_lips = 5;
int g_jaw_shift = 8;
int g_teeth_shift = 5;
int g_lips_shift = 3;
int g_shift = 1;
input string ma_period="144, 288, 10, 20, 34, 58";
#define MAX_ORDER_COUNT 4
#define DEBUG_ONLY yes
// ------------------------------------------------------------------------------------------------
// VARIABLES GLOBALES
// ------------------------------------------------------------------------------------------------
string key = "My Trader";
// Definimos 1 variable para guardar los tickets
// indicadores
// Cuenta
class CAccountMgr
{
public:
   double balance;
   double equity;
   double margin;
   double max_potential_loss;
   double next_lots;
   double update();
   int test();
   int ActualizarOrdenes();
   int get_history_info();
} g_account;

int g_slippage=0;
// OrderReliable
int retry_attempts = 10; 
double sleep_time = 4.0;
double sleep_maximum	= 25.0;  // in seconds
string OrderReliable_Fname = "OrderReliable fname unset";
static int _OR_err = 0;
string OrderReliableVersion = "V2_1_1"; 
double g_ma[6]={0,0,0,0,0,0};
datetime g_startime=0;
int g_ma_period[6];

class CMarketSignal
{
public:
   int near;
   int mediam;
   int far;
   int medfar;
   double price;
   int stat;
   int signal;
   int signal_near;
   int signal_mediam;
   int signal_medfar;
   int signal_price;
   datetime time;

   CMarketSignal():
      near(0),
      mediam(0),
      far(0),
      price(0),
      stat(0),
      signal(0),
      signal_near(0),
      signal_mediam(0),
      signal_medfar(0),
      signal_price(0),
      time(0)
   {}
   
   int update();
} g_mkt_signal;

int CMarketSignal::update(void)
{
   if (Time[0] > time )
   {
      time = Time[0];
      for (int i = 0; i < 6; i++)
         g_ma[i] = iMA(NULL, 0, g_ma_period[i], 0, MODE_SMMA, PRICE_MEDIAN, 0);

      ////////////////////////////////////////////////////////
      int dd = (int)((g_ma[0] - g_ma[1]) / _Point);
      if (dd > 0)
      {
         if (far > 0)
         {
            if (dd > far)
            {
               // enhanced
            }
         }
         else if (far < 0)
         {
            signal = 1;
         }
         far = dd;
      }
      else if (dd < 0)
      {
          if (far > 0)
         {
            signal = -1;
         }
         else if (far < 0)
         {
            if (dd < far)
            {
               // enhanced
            }
         }
         far = dd;
     
      }
      else
      {
         // nothing
      }
      ////////////////////////////////////////////////////////
      dd = (int)((g_ma[2] - g_ma[3]) / _Point);
      if (dd > 0)
      {
         if (near > 0)
         {
            if (dd > near)
            {
               // enhanced
            }
         }
         else if (near < 0)
         {
            signal_near = 1;
         }
         near = dd;
      }
      else if (dd < 0)
      {
          if (near > 0)
         {
            signal_near = -1;
         }
         else if (near < 0)
         {
            if (dd < near)
            {
               // enhanced
            }
         }
         near = dd;
     
      }
      else
      {
         // nothing
      }
      ////////////////////////////////////////////////////////
      dd = (int)((g_ma[4] - g_ma[5]) / _Point);
      if (dd > 0)
      {
         if (mediam > 0)
         {
            if (dd > mediam)
            {
               // enhanced
            }
         }
         else if (mediam < 0)
         {
            signal_mediam = 1;
         }
         mediam = dd;
      }
      else if (dd < 0)
      {
          if (mediam > 0)
         {
            signal_mediam = -1;
         }
         else if (mediam < 0)
         {
            if (dd < mediam)
            {
               // enhanced
            }
         }
         mediam = dd;
     
      }
      else
      {
         // nothing
      }
      ////////////////////////////////////////////////////////
      dd = (int)((g_ma[4] - g_ma[1]) / _Point);
      if (dd > 0)
      {
         if (medfar > 0)
         {
            if (dd > medfar)
            {
               // enhanced
            }
         }
         else if (medfar < 0)
         {
            signal_medfar = 1;
         }
         medfar = dd;
      }
      else if (dd < 0)
      {
          if (medfar > 0)
         {
            signal_medfar = -1;
         }
         else if (medfar < 0)
         {
            if (dd < medfar)
            {
               // enhanced
            }
         }
         medfar = dd;
     
      }
      else
      {
         // nothing
      }
   }

   ////////////////////////////////////////////////////////
   if (Close[0] > price) 
   {
      if (Close[0] > g_ma[1] + 10 * _Point && price <= g_ma[1] + 10 * _Point)
      {
         signal_price = 288;
      }
      else signal_price = 1;
   }
   else if (Close[0] < price)
   {
      if (Close[0] < g_ma[1] - 10 * _Point && price >= g_ma[1] + 10 * _Point)
      {
         signal_price = -288;
      }
      else signal_price = -1;
   }
   price = Close[0];
 
   return signal;
}

class COrder: public CObject
{
   void __init()
   {
      ticket = 0;
      lots = 0;
      price = 0;
      profit = 0;
      open_time = 0;
      direction = 0;
      max_profit = 0;
      close_profit = 0;
   }
public:
   
   int ticket;
   // Definimos 1 variable para guardar los lotes
   double lots;
   // Definimos 1 variable para guardar las valores de apertura de las ordenes
   double price;
   // Definimos 1 variable para guardar los beneficios
   double profit;
   // Definimos 1 variable para guardar los tiempos
   datetime open_time;
   int direction;
   double max_profit;
   double close_profit;
   COrder() { __init(); }
   COrder(int order_ticket) 
   {
      __init();
      ticket = order_ticket;
   }
   virtual int Compare(const CObject *node,const int mode=0) const
   {
      COrder *t = (COrder *)node;
      if (open_time > t.open_time) return 1;
      if (open_time < t.open_time) return -1;
      return 0;
   }
   // ------------------------------------------------------------------------------------------------
   // CALCULA TAKE PROFIT
   // ------------------------------------------------------------------------------------------------
   int CalculaTakeProfit()
   { 
      int aux_take_profit;      
  
      aux_take_profit=(int)MathRound(CalculaValorPip(lots)*user_tp);  

      return(aux_take_profit);
   }

   // ------------------------------------------------------------------------------------------------
   // CALCULA STOP LOSS
   // ------------------------------------------------------------------------------------------------
   int CalculaStopLoss()
   { 
      int aux_stop_loss;      
  
      aux_stop_loss=-1*(int)MathRound(CalculaValorPip(lots)*user_sl);
    
      return(aux_stop_loss);
   }
};


class COrderList: public CLinkedList
{
public:
   // Cantidad de ordenes;
   double last_order_profit;
   double last_order_lots;
   datetime last_order_time;
   COrderList():
      last_order_profit(0),
      last_order_lots(0),
      last_order_time(0)
   {}
 
   COrder *find(int ticket)
   {
      CLinkedNode *t = begin();
      for ( ; t != end(); t = (CLinkedNode *)t.Next())
      {
            COrder * p = (COrder *)t.object;
            if (p.ticket == ticket) return p;
      }
      return NULL;
   }
   int count()
   {
      int n = 0;
      CLinkedNode *t = begin();
      for ( ; t != end(); t = (CLinkedNode *)t.Next())
      {
         n++;
      }
      return n;
   }

} g_orderlist;

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  if(IsTradeAllowed() == false) 
  {
    Comment("Copyright ? 2014, Steven Yi\nTrade not allowed.");
    return;
  }

  // Actualizamos el estado actual
  InicializarVariables();

  g_account.update();

  if (use_tp_sl==0)
    Comment(StringConcatenate("MyTrader v1.0 started " + TimeToString(g_startime, TIME_DATE|TIME_SECONDS) +  ".\nNext order lots: ",g_account.next_lots));
  else if (use_tp_sl==1)  
    Comment(StringConcatenate("MyTrader v1.0 started " + TimeToString(g_startime, TIME_DATE|TIME_SECONDS) +  ".\nNext order lots: ",g_account.next_lots,"\nTake profit ($): ",g_account.next_lots*10*user_tp,"\nStop loss ($): ",g_account.next_lots*10*user_sl));
    
  Robot();
}

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void FileTest()
  {
//--- incorrect file opening method
   string terminal_data_path=TerminalInfoString(TERMINAL_DATA_PATH);
   string filename=terminal_data_path+"\\MQL4\\Files\\"+"fractals.csv";
   int filehandle=FileOpen(filename,FILE_WRITE|FILE_CSV);
   if(filehandle<0)
     {
      Print("Failed to open the file by the absolute path ");
      Print("Error code ",GetLastError());
     }
 
//--- correct way of working in the "file sandbox"
   ResetLastError();
   filehandle=FileOpen("fractals.csv",FILE_WRITE|FILE_CSV);
   if(filehandle!=INVALID_HANDLE)
     {
      FileWrite(filehandle,TimeCurrent(),Symbol(),PERIOD_CURRENT);
      FileClose(filehandle);
      Print("FileOpen OK");
     }
   else Print("Operation FileOpen failed, error ",GetLastError());
//--- another example with the creation of an enclosed directory in MQL4\Files\
   string subfolder="Research";
   filehandle=FileOpen(subfolder+"\\fractals.txt",FILE_WRITE|FILE_CSV);
      if(filehandle!=INVALID_HANDLE)
     {
      FileWrite(filehandle,TimeCurrent(),Symbol(),PERIOD_CURRENT);
      FileClose(filehandle);
      Print("The file most be created in the folder "+terminal_data_path+"\\"+subfolder);
     }
   else Print("File open failed, error ",GetLastError());
  }
  

// ------------------------------------------------------------------------------------------------
// INICIALIZAR VARIABLES
// ------------------------------------------------------------------------------------------------
void InicializarVariables()
{
  // Reseteamos contadores de ordenes de compa y venta
  
  if (MarketInfo(Symbol(),MODE_DIGITS)==4)
  {
    g_slippage = user_slippage;
  }
  else if (MarketInfo(Symbol(),MODE_DIGITS)==5)
  {
    g_slippage = 10*user_slippage;
  }
  
}

int CAccountMgr::get_history_info()
{
  g_orderlist.last_order_lots = 0;
  g_orderlist.last_order_profit = 0;

  bool encontrada=false;
  if (OrdersHistoryTotal()>0)
  {
    int i=1;
    while (i<=10 && encontrada==FALSE)
    { 
      int n = OrdersHistoryTotal()-i;
      if(OrderSelect(n,SELECT_BY_POS,MODE_HISTORY)==TRUE)
      {
        if (OrderMagicNumber()==MAGIC_NUMBER)
        {
          encontrada=TRUE;
          g_orderlist.last_order_profit=OrderProfit();
          g_orderlist.last_order_lots=OrderLots();
        }
      }
      i++;
    }
  }
   return 0;
}

// ------------------------------------------------------------------------------------------------
// ACTUALIZAR ORDENES
// ------------------------------------------------------------------------------------------------
int CAccountMgr::ActualizarOrdenes()
{

   get_history_info();

  int ordenes=0;
  max_potential_loss = 0;
  
  for (CLinkedNode *node = g_orderlist.begin(); node != g_orderlist.end(); node = (CLinkedNode *)node.Next())
  {
      ((COrder*)node.object).open_time = 0;
  }
  // Ordenes de compra
  for(int i=0; i<OrdersTotal(); i++)
  {
    if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) == true)
    {
      int ticket = OrderTicket();
      double lots = OrderLots();
      double price = OrderOpenPrice();
      datetime open_time = OrderOpenTime();
      double profit = OrderProfit();
      int direction = OrderType();
      double loss = OrderStopLoss();
      if (loss > 0)
      {
         if (direction == OP_BUY)
            loss = price - loss;
         else
            loss = loss - price;
      }
      else 
      {
         if (MarketInfo(OrderSymbol(), MODE_DIGITS) == 5) loss = user_sl * 10;
         else loss = user_sl;
         loss = MarketInfo(OrderSymbol(), MODE_POINT) * loss;
      }
      
      loss = MarketInfo(OrderSymbol(), MODE_LOTSIZE) * lots * loss;
      if (loss > 0)
      {
         string account_currency = AccountCurrency();
         string order_currency = StringSubstr(OrderSymbol(), 3, 3);
         double rate = GetCurrencyRate_4(order_currency, account_currency);
         if (rate > 0) loss = loss * rate;
         max_potential_loss += loss;
      }

      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MAGIC_NUMBER)
      {
        COrder *p = g_orderlist.find(ticket);
        if (p == NULL)
        {
            p = new COrder(ticket);
            g_orderlist.append(p);
        }
        p.lots = lots;
        p.price = price;
        p.open_time = open_time;
        p.profit = profit;
        if (direction==OP_BUY) p.direction=1;
        if (direction==OP_SELL) p.direction=2;
        if (open_time > g_orderlist.last_order_time) g_orderlist.last_order_time = open_time;
        ordenes++;
      }
    }
  }
  
  for (CLinkedNode *node = g_orderlist.begin(); node != g_orderlist.end(); node = (CLinkedNode *)node.Next())
  {
      if (((COrder*)node.object).open_time == 0)
      {
           CLinkedNode *p = node.Prev();
           delete (COrder *)node.pop();
           node = p;
      }
  }
  
  return ordenes;
}

int CAccountMgr::test()
{
  double a_balance=AccountBalance();
  double a_equity=AccountEquity();
  double a_margin=AccountMargin();
  int a_leverage = AccountLeverage();
  int a_so = AccountStopoutMode();
  int a_sl = AccountStopoutLevel();
  Print("balance: " + DoubleToStr(a_balance) + " equity: " + DoubleToStr(a_equity) + " margin: " + DoubleToStr(a_margin) + " leverage: " + IntegerToString(a_leverage) + " so_mode: " + IntegerToString(a_so) + " so_level: " + IntegerToString(a_sl));
  return 0;
}
// ------------------------------------------------------------------------------------------------
// CALCULAR VOLUMEN
// ------------------------------------------------------------------------------------------------
double CAccountMgr::update()
{ 
  balance=AccountBalance();
  equity=AccountEquity();
  margin=AccountMargin();

  ActualizarOrdenes();
  
  double aux=0;
  int n;
  
  if (money_management==0)
  {
    aux=min_lots;
  }
  else
  {    
    double usable_margin = balance - margin - max_potential_loss;
    if (progression==0) 
    {
      double lot_price = Ask * MarketInfo(_Symbol, MODE_LOTSIZE) / AccountLeverage();
      string account_currency = AccountCurrency();
      string order_currency = StringSubstr(_Symbol, 3, 3);
      double rate = GetCurrencyRate_4(order_currency, account_currency);
      if (rate > 0) lot_price = lot_price * rate;

      double loss_rate = user_sl * 10 * _Point * AccountLeverage() / Bid;
      usable_margin = (usable_margin / (1 + loss_rate)) * risk;
      
      aux= usable_margin/lot_price;
      n = (int)MathFloor(aux/min_lots);
      
      aux = n*min_lots;                   
    }  
  
    if (progression==1)
    {
      if (g_orderlist.last_order_profit<0)
      {
        aux = g_orderlist.last_order_lots+min_lots;
      }
      else 
      {
        aux = g_orderlist.last_order_lots-min_lots;
      }  
    }        
    
    if (progression==2)
    {
      if (g_orderlist.last_order_profit<0)
      {
        aux = g_orderlist.last_order_lots*2;
      }
      else 
      {
         double lot_price = Ask * MarketInfo(_Symbol, MODE_LOTSIZE) / AccountLeverage();
         string account_currency = AccountCurrency();
         string order_currency = StringSubstr(_Symbol, 3, 3);
         double rate = GetCurrencyRate_4(order_currency, account_currency);
         if (rate > 0) lot_price = lot_price * rate;

         double loss_rate = user_sl * _Point * AccountLeverage() / Bid;
         usable_margin = (usable_margin / (1 + loss_rate)) * risk;
      
         aux= usable_margin/lot_price;
         n = (int)MathFloor(aux/min_lots);
      
         aux = n*min_lots;                   
      }  
    }     
    
    if (aux<min_lots)
        aux=0;
     
    else if (aux>MarketInfo(Symbol(),MODE_MAXLOT))
      aux=MarketInfo(Symbol(),MODE_MAXLOT);
      
    if (aux<MarketInfo(Symbol(),MODE_MINLOT))
      aux=0;
  }
  
  next_lots = NormalizeDouble(aux, 2);
  
  return(next_lots);
}

// ------------------------------------------------------------------------------------------------
// CALCULA VALOR PIP
// ------------------------------------------------------------------------------------------------
double CalculaValorPip(double lotes)
{ 
   double aux_mm_valor=0;
   
   double aux_mm_tick_value = MarketInfo(Symbol(), MODE_TICKVALUE);
   double aux_mm_tick_size = MarketInfo(Symbol(), MODE_TICKSIZE);
   int aux_mm_digits = (int)MarketInfo(Symbol(),MODE_DIGITS);   
   double aux_mm_veces_lots = 1/lotes;
   
   switch (aux_mm_digits)
   {
      case 5:
         aux_mm_valor=aux_mm_tick_value*10;
         break;
      case 4:
         aux_mm_valor = aux_mm_tick_value;
         break;   
      case 3:
         aux_mm_valor=aux_mm_tick_value*10;
         break;
      case 2:
         aux_mm_valor = aux_mm_tick_value;
         break;
   }
   
   aux_mm_valor = aux_mm_valor/aux_mm_veces_lots;
   
   return(aux_mm_valor);
}

// ------------------------------------------------------------------------------------------------
// CALCULA SIGNAL
// ------------------------------------------------------------------------------------------------

int CalculaSignal(int jaw, int jaw_shift, int teeth, int teeth_shift, int lips, int lips_shift, int aux_shift)
{
  int aux=0;   
  
  double j1=iAlligator(Symbol(),0,jaw,jaw_shift,teeth,teeth_shift,lips,lips_shift,MODE_SMA,PRICE_MEDIAN,MODE_GATORJAW,aux_shift);
  double j2=iAlligator(Symbol(),0,jaw,jaw_shift,teeth,teeth_shift,lips,lips_shift,MODE_SMA,PRICE_MEDIAN,MODE_GATORJAW,aux_shift+1);
  double t1=iAlligator(Symbol(),0,jaw,jaw_shift,teeth,teeth_shift,lips,lips_shift,MODE_SMA,PRICE_MEDIAN,MODE_GATORTEETH,aux_shift);
  double t2=iAlligator(Symbol(),0,jaw,jaw_shift,teeth,teeth_shift,lips,lips_shift,MODE_SMA,PRICE_MEDIAN,MODE_GATORTEETH,aux_shift+1);
  double l1=iAlligator(Symbol(),0,jaw,jaw_shift,teeth,teeth_shift,lips,lips_shift,MODE_SMA,PRICE_MEDIAN,MODE_GATORLIPS,aux_shift);
  double l2=iAlligator(Symbol(),0,jaw,jaw_shift,teeth,teeth_shift,lips,lips_shift,MODE_SMA,PRICE_MEDIAN,MODE_GATORLIPS,aux_shift+1);
  

  // Valores de retorno
  // 1. Compra
  // 2. Venta
  if (l1>t1 && l1>j1 && t1>j1 && (l2<j2 || l2<t2 || j2>t2)) aux=1;
  if (j1>t1 && j1>l1 && t1>l1 && (l2>j2 || l2>t2 || j2<t2)) aux=2;
   
  return(aux);  
}

int do_user_tp_long(COrder& order)
{
    bool cerrada = false;
    // CASO 1.1 >>> Tenemos el beneficio y  activamos el profit lock
    if (order.profit > order.CalculaTakeProfit() && order.max_profit==0)
    {
      order.max_profit = order.profit;
      order.close_profit = profit_lock*order.profit; 
    } 
    // CASO 1.2 >>> Segun va aumentando el beneficio actualizamos el profit lock
    if (order.max_profit>0)
    {
      if (order.profit>order.max_profit)
      {      
        order.max_profit = order.profit;
        order.close_profit = profit_lock*order.profit;
      }
    }   
    // CASO 1.3 >>> Cuando el beneficio caiga por debajo de profit lock cerramos las ordenes
    if (order.max_profit>0 && order.close_profit>0 && order.max_profit>order.close_profit && order.profit<order.close_profit) 
    {
      cerrada=OrderCloseReliable(order.ticket,order.lots,MarketInfo(Symbol(),MODE_BID),g_slippage,Blue);
    }
    return 0;
}
int do_user_tp_short(COrder &order)
{
   bool cerrada = false;
    // CASO 1.1 >>> Tenemos el beneficio y  activamos el profit lock
    if (order.profit > order.CalculaTakeProfit() && order.max_profit==0)
    {
      order.max_profit = order.profit;
      order.close_profit = profit_lock*order.profit;      
    } 
    // CASO 1.2 >>> Segun va aumentando el beneficio actualizamos el profit lock
    if (order.max_profit>0)
    {
      if (order.profit>order.max_profit)
      {      
        order.max_profit = order.profit;
        order.close_profit = profit_lock*order.profit; 
      }
    }   
    // CASO 1.3 >>> Cuando el beneficio caiga por debajo de profit lock cerramos las ordenes
    if (order.max_profit>0 && order.close_profit>0 && order.max_profit>order.close_profit && order.profit<order.close_profit) 
    {
      cerrada=OrderCloseReliable(order.ticket,order.lots,MarketInfo(Symbol(),MODE_ASK),g_slippage,Red);
    }
    return 0;
}

bool do_user_sl(COrder& order)
{
    bool cerrada=FALSE;  
    if (order.profit <= order.CalculaStopLoss())
    {
      if (order.direction == 1)
         cerrada=OrderCloseReliable(order.ticket,order.lots,MarketInfo(Symbol(),MODE_BID),g_slippage,Blue);
      else
         cerrada=OrderCloseReliable(order.ticket,order.lots,MarketInfo(Symbol(),MODE_ASK),g_slippage,Blue);
    }
    return cerrada;
}

// close order based on signal
int signal_tp_sl(COrder& order)
{
   bool cerrada = false;
  // **************************************************
  // ORDERS>0 AND DIRECTION=1 AND USE_TP_SL=0
  // **************************************************
  if ( order.direction==1)
  {
    if (g_mkt_signal.signal_near==-1 || g_mkt_signal.signal_price == -288)
    {
      cerrada=OrderCloseReliable(order.ticket,order.lots,MarketInfo(Symbol(),MODE_BID),g_slippage,Blue);
    }  
  }

  // **************************************************
  // ORDERS>0 AND DIRECTION=2 AND USE_TP_SL=0
  // **************************************************
  if (order.direction==2)
  {
    if (g_mkt_signal.signal_near==1 || g_mkt_signal.signal_price == 288)
    {
      cerrada=OrderCloseReliable(order.ticket,order.lots,MarketInfo(Symbol(),MODE_ASK),g_slippage,Red);
    }
  }
  return 0;
}

int do_user_tp_sl(COrder& order)
{
         int ret = 0;
         if (order.direction==1)
         {
            ret = do_user_tp_long(order);    
            // CASO 2 >>> Tenemos "size" pips de perdida
         }
    
         // **************************************************
         // ORDERS>0 AND DIRECTION=2 AND USE_TP_SL=1
         // **************************************************
         if (order.direction==2)
         {
            ret = do_user_tp_short(order);
      
            // CASO 2 >>> Tenemos "size" pips de perdida
         }

         ret = do_user_sl(order);
         
         return ret;
}

int make_orders(CMarketSignal& signal)
{
    int ticket = -1;
  
    // ----------
    // COMPRA
    // ----------
    if (g_mkt_signal.signal == 1)
    {
      double price = Close[0];
      if(price > g_ma[1] && price < g_ma[0] && g_ma[0] > (g_ma[1] + g_slippage *_Point))
      {
         ticket = OrderSendReliable(Symbol(),OP_BUY, g_account.next_lots,MarketInfo(Symbol(),MODE_ASK),g_slippage,0,0,key,MAGIC_NUMBER,0,Blue);
         g_account.test();
      }
    } 
    // ----------
    // VENTA
    // ----------
    if (g_mkt_signal.signal == -1)
    {
      double price = Close[0];
      if(price < g_ma[1] && price > g_ma[0] && g_ma[1] > (g_ma[0] + g_slippage *_Point))
      {
         ticket = OrderSendReliable(Symbol(),OP_SELL,g_account.next_lots,MarketInfo(Symbol(),MODE_BID),g_slippage,0,0,key,MAGIC_NUMBER,0,Red);
         g_account.test();
      }        
    }
    
    return ticket;
}
// ------------------------------------------------------------------------------------------------
// ROBOT
// ------------------------------------------------------------------------------------------------
void Robot()
{
  g_mkt_signal.update();
  
  if (g_account.next_lots > 0 && g_orderlist.count() < MAX_ORDER_COUNT && TimeCurrent() - g_orderlist.last_order_time > 300)
  {
      make_orders(g_mkt_signal);
  }
  
  for (CLinkedNode *node = g_orderlist.begin(); node != g_orderlist.end(); node = (CLinkedNode *)node.Next())
  {
      COrder *order = (COrder *)node.object;
      // **************************************************
      // ORDERS>0 AND DIRECTION=1 AND USE_TP_SL=1
      // **************************************************
      if (use_tp_sl==0)
      {
         signal_tp_sl(order);
      }
      else
      {
         do_user_tp_sl(order);
      }
  }
}


//=============================================================================
//							 OrderSendReliable()
//
//	This is intended to be a drop-in replacement for OrderSend() which, 
//	one hopes, is more resistant to various forms of errors prevalent 
//	with MetaTrader.
//			  
//	RETURN VALUE: 
//
//	Ticket number or -1 under some error conditions.  Check
// final error returned by Metatrader with OrderReliableLastErr().
// This will reset the value from GetLastError(), so in that sense it cannot
// be a total drop-in replacement due to Metatrader flaw. 
//
//	FEATURES:
//
//		 * Re-trying under some error conditions, sleeping a random 
//		   time defined by an exponential probability distribution.
//
//		 * Automatic normalization of Digits
//
//		 * Automatically makes sure that stop levels are more than
//		   the minimum stop distance, as given by the server. If they
//		   are too close, they are adjusted.
//
//		 * Automatically converts stop orders to market orders 
//		   when the stop orders are rejected by the server for 
//		   being to close to market.  NOTE: This intentionally
//       applies only to OP_BUYSTOP and OP_SELLSTOP, 
//       OP_BUYLIMIT and OP_SELLLIMIT are not converted to market
//       orders and so for prices which are too close to current
//       this function is likely to loop a few times and return
//       with the "invalid stops" error message. 
//       Note, the commentary in previous versions erroneously said
//       that limit orders would be converted.  Note also
//       that entering a BUYSTOP or SELLSTOP new order is distinct
//       from setting a stoploss on an outstanding order; use
//       OrderModifyReliable() for that. 
//
//		 * Displays various error messages on the log for debugging.
//
//
//	Matt Kennel, 2006-05-28 and following
//
//=============================================================================
int OrderSendReliable(string symbol, int cmd, double volume, double price,
					  int slippage, double stoploss, double takeprofit,
					  string comment, int magic, datetime expiration = 0, 
					  color arrow_color = CLR_NONE) 
{

	// ------------------------------------------------
	// Check basic conditions see if trade is possible. 
	// ------------------------------------------------
	OrderReliable_Fname = "OrderSendReliable";
	OrderReliablePrint(" attempted " + OrderReliable_CommandString(cmd) + " " + DoubleToStr(volume) + 
						" lots @" + DoubleToStr(price) + " sl:" + DoubleToStr(stoploss) + " tp:" + DoubleToStr(takeprofit)); 
						
	//if (!IsConnected()) 
	//{
	//	OrderReliablePrint("error: IsConnected() == false");
	//	_OR_err = ERR_NO_CONNECTION; 
	//	return(-1);
	//}
	
	if (IsStopped()) 
	{
		OrderReliablePrint("error: IsStopped() == true");
		_OR_err = ERR_COMMON_ERROR; 
		return(-1);
	}
	
	int cnt = 0;
	while(!IsTradeAllowed() && cnt < retry_attempts) 
	{
		OrderReliable_SleepRandomTime(sleep_time, sleep_maximum); 
		cnt++;
	}
	
	if (!IsTradeAllowed()) 
	{
		OrderReliablePrint("error: no operation possible because IsTradeAllowed()==false, even after retries.");
		_OR_err = ERR_TRADE_CONTEXT_BUSY; 

		return(-1);  
	}

	// Normalize all price / stoploss / takeprofit to the proper # of digits.
	int digits = (int)MarketInfo(symbol, MODE_DIGITS);
	if (digits > 0) 
	{
		price = NormalizeDouble(price, digits);
		stoploss = NormalizeDouble(stoploss, digits);
		takeprofit = NormalizeDouble(takeprofit, digits); 
	}
	
	if (stoploss != 0) 
		OrderReliable_EnsureValidStop(symbol, price, stoploss); 

	int err = GetLastError(); // clear the global variable.  
	err = 0; 
	_OR_err = 0; 
	bool exit_loop = false;
	bool limit_to_market = false; 
	
	// limit/stop order. 
	int ticket=-1;

	if ((cmd == OP_BUYSTOP) || (cmd == OP_SELLSTOP) || (cmd == OP_BUYLIMIT) || (cmd == OP_SELLLIMIT)) 
	{
		cnt = 0;
		while (!exit_loop) 
		{
			if (IsTradeAllowed()) 
			{
				ticket = OrderSend(symbol, cmd, volume, price, slippage, stoploss, 
									takeprofit, comment, magic, expiration, arrow_color);
				err = GetLastError();
				_OR_err = err; 
			} 
			else 
			{
				cnt++;
			} 
			
			switch (err) 
			{
				case ERR_NO_ERROR:
					exit_loop = true;
					break;
				
				// retryable errors
				case ERR_SERVER_BUSY:
				case ERR_NO_CONNECTION:
				case ERR_INVALID_PRICE:
				case ERR_OFF_QUOTES:
				case ERR_BROKER_BUSY:
				case ERR_TRADE_CONTEXT_BUSY: 
					cnt++; 
					break;
					
				case ERR_PRICE_CHANGED:
				case ERR_REQUOTE:
					RefreshRates();
					continue;	// we can apparently retry immediately according to MT docs.
					
				case ERR_INVALID_STOPS:
				{
					double servers_min_stop = MarketInfo(symbol, MODE_STOPLEVEL) * MarketInfo(symbol, MODE_POINT); 
					if (cmd == OP_BUYSTOP) 
					{
						// If we are too close to put in a limit/stop order so go to market.
						if (MathAbs(MarketInfo(symbol,MODE_ASK) - price) <= servers_min_stop)	
							limit_to_market = true; 
							
					} 
					else if (cmd == OP_SELLSTOP) 
					{
						// If we are too close to put in a limit/stop order so go to market.
						if (MathAbs(MarketInfo(symbol,MODE_BID) - price) <= servers_min_stop)
							limit_to_market = true; 
					}
					exit_loop = true; 
				}
					break; 
					
				default:
					// an apparently serious error.
					exit_loop = true;
					break; 
					
			}  // end switch 

			if (cnt > retry_attempts) 
				exit_loop = true; 
			 	
			if (exit_loop) 
			{
				if (err != ERR_NO_ERROR) 
				{
					OrderReliablePrint("non-retryable error: " + OrderReliableErrTxt(err)); 
				}
				if (cnt > retry_attempts) 
				{
					OrderReliablePrint("retry attempts maxed at " + IntegerToString(retry_attempts)); 
				}
			}
			 
			if (!exit_loop) 
			{
				OrderReliablePrint("retryable error (" + IntegerToString(cnt) + "/" + IntegerToString(retry_attempts) + 
									"): " + OrderReliableErrTxt(err)); 
				OrderReliable_SleepRandomTime(sleep_time, sleep_maximum); 
				RefreshRates(); 
			}
		}
		 
		// We have now exited from loop. 
		if (err == ERR_NO_ERROR) 
		{
			OrderReliablePrint("apparently successful OP_BUYSTOP or OP_SELLSTOP order placed, details follow.");
			if (OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
			{
			   OrderPrint();
			}
			return(ticket); // SUCCESS! 
		} 
		if (!limit_to_market) 
		{
			OrderReliablePrint("failed to execute stop or limit order after " + IntegerToString(cnt) + " retries");
			OrderReliablePrint("failed trade: " + OrderReliable_CommandString(cmd) + " " + symbol + 
								"@" + DoubleToStr(price) + " tp@" + DoubleToStr(takeprofit) + " sl@" + DoubleToStr(stoploss)); 
			OrderReliablePrint("last error: " + OrderReliableErrTxt(err)); 
			return(-1); 
		}
	}  // end	  
  
	if (limit_to_market) 
	{
		OrderReliablePrint("going from limit order to market order because market is too close.");
		if ((cmd == OP_BUYSTOP) || (cmd == OP_BUYLIMIT)) 
		{
			cmd = OP_BUY;
			price = MarketInfo(symbol,MODE_ASK);
		} 
		else if ((cmd == OP_SELLSTOP) || (cmd == OP_SELLLIMIT)) 
		{
			cmd = OP_SELL;
			price = MarketInfo(symbol,MODE_BID);
		}	
	}
	
	// we now have a market order.
	err = GetLastError(); // so we clear the global variable.  
	err = 0; 
	_OR_err = 0; 
	ticket = -1;

	if ((cmd == OP_BUY) || (cmd == OP_SELL)) 
	{
		cnt = 0;
		while (!exit_loop) 
		{
			if (IsTradeAllowed()) 
			{
				ticket = OrderSend(symbol, cmd, volume, price, slippage, 
									stoploss, takeprofit, comment, magic, 
									expiration, arrow_color);
				err = GetLastError();
				_OR_err = err; 
			} 
			else 
			{
				cnt++;
			} 
			switch (err) 
			{
				case ERR_NO_ERROR:
					exit_loop = true;
					break;
					
				case ERR_SERVER_BUSY:
				case ERR_NO_CONNECTION:
				case ERR_INVALID_PRICE:
				case ERR_OFF_QUOTES:
				case ERR_BROKER_BUSY:
				case ERR_TRADE_CONTEXT_BUSY: 
					cnt++; // a retryable error
					break;
					
				case ERR_PRICE_CHANGED:
				case ERR_REQUOTE:
					RefreshRates();
					continue; // we can apparently retry immediately according to MT docs.
					
				default:
					// an apparently serious, unretryable error.
					exit_loop = true;
					break; 
					
			}  // end switch 

			if (cnt > retry_attempts) 
			 	exit_loop = true; 
			 	
			if (!exit_loop) 
			{
				OrderReliablePrint("retryable error (" + IntegerToString(cnt) + "/" + 
									IntegerToString(retry_attempts) + "): " + OrderReliableErrTxt(err)); 
				OrderReliable_SleepRandomTime(sleep_time,sleep_maximum); 
				RefreshRates(); 
			}
			
			if (exit_loop) 
			{
				if (err != ERR_NO_ERROR) 
				{
					OrderReliablePrint("non-retryable error: " + OrderReliableErrTxt(err)); 
				}
				if (cnt > retry_attempts) 
				{
					OrderReliablePrint("retry attempts maxed at " + IntegerToString(retry_attempts)); 
				}
			}
		}
		
		// we have now exited from loop. 
		if (err == ERR_NO_ERROR) 
		{
			OrderReliablePrint("apparently successful OP_BUY or OP_SELL order placed, details follow.");
			if (OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
			{
			   OrderPrint();
			}
			return(ticket); // SUCCESS! 
		} 
		OrderReliablePrint("failed to execute OP_BUY/OP_SELL, after " + IntegerToString(cnt) + " retries");
		OrderReliablePrint("failed trade: " + OrderReliable_CommandString(cmd) + " " + symbol + 
							"@" + DoubleToStr(price) + " tp@" + DoubleToStr(takeprofit) + " sl@" + DoubleToStr(stoploss)); 
		OrderReliablePrint("last error: " + OrderReliableErrTxt(err)); 
		return(-1); 
	}
	return 0;
}

//=============================================================================
//							 OrderCloseReliable()
//
//	This is intended to be a drop-in replacement for OrderClose() which, 
//	one hopes, is more resistant to various forms of errors prevalent 
//	with MetaTrader.
//			  
//	RETURN VALUE: 
//
//		TRUE if successful, FALSE otherwise
//
//
//	FEATURES:
//
//		 * Re-trying under some error conditions, sleeping a random 
//		   time defined by an exponential probability distribution.
//
//		 * Displays various error messages on the log for debugging.
//
//
//	Derk Wehler, ashwoods155@yahoo.com  	2006-07-19
//
//=============================================================================
bool OrderCloseReliable(int ticket, double lots, double price, 
						int slippage, color arrow_color = CLR_NONE) 
{
	int nOrderType;
	string strSymbol;
	OrderReliable_Fname = "OrderCloseReliable";
	
	OrderReliablePrint(" attempted close of #" + IntegerToString(ticket) + " price:" + DoubleToStr(price) + 
						" lots:" + DoubleToStr(lots) + " slippage:" + IntegerToString(slippage)); 

// collect details of order so that we can use GetMarketInfo later if needed
	if (!OrderSelect(ticket,SELECT_BY_TICKET))
	{
		_OR_err = GetLastError();		
		OrderReliablePrint("error: " + ErrorDescription(_OR_err));
		return(false);
	}
	else
	{
		nOrderType = OrderType();
		strSymbol = OrderSymbol();
	}

	if (nOrderType != OP_BUY && nOrderType != OP_SELL)
	{
		_OR_err = ERR_INVALID_TICKET;
		OrderReliablePrint("error: trying to close ticket #" + IntegerToString(ticket) + ", which is " + OrderReliable_CommandString(nOrderType) + ", not OP_BUY or OP_SELL");
		return(false);
	}

	//if (!IsConnected()) 
	//{
	//	OrderReliablePrint("error: IsConnected() == false");
	//	_OR_err = ERR_NO_CONNECTION; 
	//	return(false);
	//}
	
	if (IsStopped()) 
	{
		OrderReliablePrint("error: IsStopped() == true");
		return(false);
	}

	
	int cnt = 0;
/*	
	Commented out by Paul Hampton-Smith due to a bug in MT4 that sometimes incorrectly returns IsTradeAllowed() = false
	while(!IsTradeAllowed() && cnt < retry_attempts) 
	{
		OrderReliable_SleepRandomTime(sleep_time,sleep_maximum); 
		cnt++;
	}
	if (!IsTradeAllowed()) 
	{
		OrderReliablePrint("error: no operation possible because IsTradeAllowed()==false, even after retries.");
		_OR_err = ERR_TRADE_CONTEXT_BUSY; 
		return(false);  
	}
*/

	int err = GetLastError(); // so we clear the global variable.  
	err = 0; 
	_OR_err = 0; 
	bool exit_loop = false;
	cnt = 0;
	bool result = false;
	
	while (!exit_loop) 
	{
		if (IsTradeAllowed()) 
		{
			result = OrderClose(ticket, lots, price, slippage, arrow_color);
			err = GetLastError();
			_OR_err = err; 
		} 
		else 
			cnt++;

		if (result == true) 
			exit_loop = true;

		switch (err) 
		{
			case ERR_NO_ERROR:
				exit_loop = true;
				break;
				
			case ERR_SERVER_BUSY:
			case ERR_NO_CONNECTION:
			case ERR_INVALID_PRICE:
			case ERR_OFF_QUOTES:
			case ERR_BROKER_BUSY:
			case ERR_TRADE_CONTEXT_BUSY: 
			case ERR_TRADE_TIMEOUT:		// for modify this is a retryable error, I hope. 
				cnt++; 	// a retryable error
				break;
				
			case ERR_PRICE_CHANGED:
			case ERR_REQUOTE:
				continue; 	// we can apparently retry immediately according to MT docs.
				
			default:
				// an apparently serious, unretryable error.
				exit_loop = true;
				break; 
				
		}  // end switch 

		if (cnt > retry_attempts) 
			exit_loop = true; 
			
		if (!exit_loop) 
		{
			OrderReliablePrint("retryable error (" + IntegerToString(cnt) + "/" + IntegerToString(retry_attempts) + 
								"): "  +  OrderReliableErrTxt(err)); 
			OrderReliable_SleepRandomTime(sleep_time,sleep_maximum); 
			// Added by Paul Hampton-Smith to ensure that price is updated for each retry
			if (nOrderType == OP_BUY)  price = NormalizeDouble(MarketInfo(strSymbol,MODE_BID),(int)MarketInfo(strSymbol,MODE_DIGITS));
			if (nOrderType == OP_SELL) price = NormalizeDouble(MarketInfo(strSymbol,MODE_ASK),(int)MarketInfo(strSymbol,MODE_DIGITS));
		}
		
		if (exit_loop) 
		{
			if ((err != ERR_NO_ERROR) && (err != ERR_NO_RESULT)) 
				OrderReliablePrint("non-retryable error: "  + OrderReliableErrTxt(err)); 

			if (cnt > retry_attempts) 
				OrderReliablePrint("retry attempts maxed at " + IntegerToString(retry_attempts)); 
		}
	}  
	
	// we have now exited from loop. 
	if ((result == true) || (err == ERR_NO_ERROR)) 
	{
		OrderReliablePrint("apparently successful close order, updated trade details follow.");
		if (OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
		{
		   OrderPrint();
		}
		return(true); // SUCCESS! 
	} 
	
	OrderReliablePrint("failed to execute close after " + IntegerToString(cnt) + " retries");
	OrderReliablePrint("failed close: Ticket #" + IntegerToString(ticket) + ", Price: " + 
						DoubleToStr(price) + ", Slippage: " + DoubleToStr(slippage)); 
	OrderReliablePrint("last error: " + OrderReliableErrTxt(err)); 
	
	return(false);  
}
 
 

//=============================================================================
//=============================================================================
//								Utility Functions
//=============================================================================
//=============================================================================
string OrderReliableErrTxt(int err) 
{
	return ("" + IntegerToString(err) + ":" + ErrorDescription(err)); 
}


void OrderReliablePrint(string s) 
{
	// Print to log prepended with stuff;
	if (!(IsTesting() || IsOptimization())) Print(OrderReliable_Fname + " " + OrderReliableVersion + ":" + s);
}


string OrderReliable_CommandString(int cmd) 
{
	if (cmd == OP_BUY) 
		return("OP_BUY");

	if (cmd == OP_SELL) 
		return("OP_SELL");

	if (cmd == OP_BUYSTOP) 
		return("OP_BUYSTOP");

	if (cmd == OP_SELLSTOP) 
		return("OP_SELLSTOP");

	if (cmd == OP_BUYLIMIT) 
		return("OP_BUYLIMIT");

	if (cmd == OP_SELLLIMIT) 
		return("OP_SELLLIMIT");

	return("(CMD==" + IntegerToString(cmd) + ")"); 
}


//=============================================================================
//
//						 OrderReliable_EnsureValidStop()
//
// 	Adjust stop loss so that it is legal.
//
//	Matt Kennel 
//
//=============================================================================
void OrderReliable_EnsureValidStop(string symbol, double price, double& sl) 
{
	// Return if no S/L
	if (sl == 0) 
		return;
	
	double servers_min_stop = MarketInfo(symbol, MODE_STOPLEVEL) * MarketInfo(symbol, MODE_POINT); 
	
	if (MathAbs(price - sl) <= servers_min_stop) 
	{
		// we have to adjust the stop.
		if (price > sl)
			sl = price - servers_min_stop;	// we are long
			
		else if (price < sl)
			sl = price + servers_min_stop;	// we are short
			
		else
			OrderReliablePrint("EnsureValidStop: error, passed in price == sl, cannot adjust"); 
			
		sl = NormalizeDouble(sl, (int)MarketInfo(symbol, MODE_DIGITS)); 
	}
}


//=============================================================================
//
//						 OrderReliable_SleepRandomTime()
//
//	This sleeps a random amount of time defined by an exponential 
//	probability distribution. The mean time, in Seconds is given 
//	in 'mean_time'.
//
//	This is the back-off strategy used by Ethernet.  This will 
//	quantize in tenths of seconds, so don't call this with a too 
//	small a number.  This returns immediately if we are backtesting
//	and does not sleep.
//
//	Matt Kennel mbkennelfx@gmail.com.
//
//=============================================================================
void OrderReliable_SleepRandomTime(double mean_time, double max_time) 
{
	if (IsTesting()) 
		return; 	// return immediately if backtesting.

	double tenths = MathCeil(mean_time / 0.1);
	if (tenths <= 0) 
		return; 
	 
	int maxtenths = (int)MathRound(max_time/0.1); 
	double p = 1.0 - 1.0 / tenths; 
	  
	Sleep(100); 	// one tenth of a second PREVIOUS VERSIONS WERE STUPID HERE. 
	
	for(int i=0; i < maxtenths; i++)  
	{
		if (MathRand() > p*32768) 
			break; 
			
		// MathRand() returns in 0..32767
		Sleep(100); 
	}
}

int OnInit()
  {
//--- create timer
//   EventSetTimer(60);
//---
   string result[];
   int i = StringSplit(ma_period, ',', result);
   if (i <= 1)
      i = StringSplit(ma_period, ' ', result);
   if (i > 0)
   {
      ArrayResize(g_ma_period, i);
      for (int j = 0; j < i; j++)
      {
         g_ma_period[j] = StrToInteger(result[j]);
         if (g_ma_period[j] <= 0)
         {
            MessageBox("invalid MA parameter: " + ma_period);
            return INIT_FAILED;
         }
      }
   }
   
   if (ArraySize(g_ma_period) < 6)
   {
      MessageBox("invalid MA parameter: " + ma_period);
      return INIT_FAILED;
   }
   
   ArrayResize(g_ma, ArraySize(g_ma_period));
   for (i = 0; i < ArraySize(g_ma); i++)
      g_ma[i] = iMA(NULL, 0, g_ma_period[i], 0, MODE_SMMA, PRICE_MEDIAN, 0);
      
   for ( ; i < ArraySize(g_ma); i++) g_ma[i] = 0;
   
   g_startime = TimeCurrent();
   g_account.test();
#ifdef DEBUG_ONLY
   if (AccountInfoInteger(ACCOUNT_TRADE_MODE) != ACCOUNT_TRADE_MODE_DEMO)
   {
      MessageBox("Only demo account is allowed!");
      return INIT_FAILED;
   }
#endif
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
//   EventKillTimer();
     while(!g_orderlist.empty())
     {
         COrder *p = (COrder *)g_orderlist.pop();
         delete p;
     }
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester()
  {
//---
   double ret=0.0;
//---

//---
   return(ret);
  }
//+------------------------------------------------------------------+
//| TesterInit function                                              |
//+------------------------------------------------------------------+
void OnTesterInit()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| TesterPass function                                              |
//+------------------------------------------------------------------+
void OnTesterPass()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| TesterDeinit function                                            |
//+------------------------------------------------------------------+
void OnTesterDeinit()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| BookEvent function                                               |
//+------------------------------------------------------------------+
void OnBookEvent(const string &symbol)
  {
//---
   
  }
//+------------------------------------------------------------------+


double GetCurrencyRate(string base, string profit)
{
   string symbol_name;
   string base_name, profit_name;
   
   if (base == profit) return 1;
   
   for(int s=0; s<SymbolsTotal(false); s++)
   {
       symbol_name=SymbolName(s,false);
       base_name = SymbolInfoString(symbol_name, SYMBOL_CURRENCY_BASE);
       profit_name = SymbolInfoString(symbol_name, SYMBOL_CURRENCY_PROFIT);
       if (profit_name != NULL)
       {
         if (base == base_name && profit == profit_name) 
         {
           ResetLastError();
           double d = SymbolInfoDouble(symbol_name, SYMBOL_ASK);
           int err=GetLastError();
           if (err != 0)
           {
               return 0;
           }
           return d;
         }
         if (profit == base_name && base == profit_name)
         {
            ResetLastError();
            double d = SymbolInfoDouble(symbol_name, SYMBOL_ASK);
            int err=GetLastError();
            if (err != 0)
            {
               return 0;
            }
           return 1 / d;
         }
         continue;
       }
   }
   return 0;
}

double GetCurrencyRate_4(string base, string profit)
{
   string symbol_name;
   
   if (base == profit) return 1;
   
   for(int s=0; s<SymbolsTotal(false); s++)
   {
       symbol_name=SymbolName(s,false);
       string query_symbol_name = base + profit;
       string symbol = StringSubstr(symbol_name,0, StringLen(query_symbol_name));
       if ( query_symbol_name == symbol) 
       {
         ResetLastError();
         double d = SymbolInfoDouble(symbol_name, SYMBOL_ASK);
         int err=GetLastError();
         if (err != 0)
         {
            return 0;
         }
         return d;
       }
       query_symbol_name = profit + base;
       symbol = StringSubstr(symbol_name,0, StringLen(query_symbol_name));
       if ( query_symbol_name == symbol)
       {
         ResetLastError();
         double d = SymbolInfoDouble(symbol_name, SYMBOL_ASK);
         int err=GetLastError();
         if (err != 0)
         {
            return 0;
         }
         return 1 / d;
       }
   }
   return 0;
}
