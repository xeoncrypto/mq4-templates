class AStream : public IStream
{
protected:
   string _symbol;
   ENUM_TIMEFRAMES _timeframe;
   double _shift;
   InstrumentInfo *_instrument;
   int _references;

   AStream(const string symbol, const ENUM_TIMEFRAMES timeframe)
   {
      _references = 1;
      _shift = 0.0;
      _symbol = symbol;
      _timeframe = timeframe;
      _instrument = new InstrumentInfo(_symbol);
   }

   ~AStream()
   {
      delete _instrument;
   }
public:
   void SetShift(const double shift)
   {
      _shift = shift;
   }

   void AddRef()
   {
      ++_references;
   }

   void Release()
   {
      --_references;
      if (_references == 0)
         delete &this;
   }
};

enum PriceType
{
   PriceClose = PRICE_CLOSE, // Close
   PriceOpen = PRICE_OPEN, // Open
   PriceHigh = PRICE_HIGH, // High
   PriceLow = PRICE_LOW, // Low
   PriceMedian = PRICE_MEDIAN, // Median
   PriceTypical = PRICE_TYPICAL, // Typical
   PriceWeighted = PRICE_WEIGHTED, // Weighted
   PriceMedianBody, // Median (body)
   PriceAverage, // Average
   PriceTrendBiased, // Trend biased
   PriceVolume, // Volume
};

class PriceStream : public AStream
{
   PriceType _price;
public:
   PriceStream(const string symbol, const ENUM_TIMEFRAMES timeframe, const PriceType price)
      :AStream(symbol, timeframe)
   {
      _price = price;
   }

   bool GetValue(const int period, double &val)
   {
      switch (_price)
      {
         case PriceClose:
            val = iClose(_symbol, _timeframe, period);
            break;
         case PriceOpen:
            val = iOpen(_symbol, _timeframe, period);
            break;
         case PriceHigh:
            val = iHigh(_symbol, _timeframe, period);
            break;
         case PriceLow:
            val = iLow(_symbol, _timeframe, period);
            break;
         case PriceMedian:
            val = (iHigh(_symbol, _timeframe, period) + iLow(_symbol, _timeframe, period)) / 2.0;
            break;
         case PriceTypical:
            val = (iHigh(_symbol, _timeframe, period) + iLow(_symbol, _timeframe, period) + iClose(_symbol, _timeframe, period)) / 3.0;
            break;
         case PriceWeighted:
            val = (iHigh(_symbol, _timeframe, period) + iLow(_symbol, _timeframe, period) + iClose(_symbol, _timeframe, period) * 2) / 4.0;
            break;
         case PriceMedianBody:
            val = (iOpen(_symbol, _timeframe, period) + iClose(_symbol, _timeframe, period)) / 2.0;
            break;
         case PriceAverage:
            val = (iHigh(_symbol, _timeframe, period) + iLow(_symbol, _timeframe, period) + iClose(_symbol, _timeframe, period) + iOpen(_symbol, _timeframe, period)) / 4.0;
            break;
         case PriceTrendBiased:
            {
               double close = iClose(_symbol, _timeframe, period);
               if (iOpen(_symbol, _timeframe, period) > iClose(_symbol, _timeframe, period))
                  val = (iHigh(_symbol, _timeframe, period) + close) / 2.0;
               else
                  val = (iLow(_symbol, _timeframe, period) + close) / 2.0;
            }
            break;
         case PriceVolume:
            val = iVolume(_symbol, _timeframe, period);
            break;
      }
      val += _shift * _instrument.GetPipSize();
      return true;
   }
};

class LongSARStream : public AStream
{
   double _step;
   double _max;
public:
   LongSARStream(const string symbol, const ENUM_TIMEFRAMES timeframe, const double step, const double max)
      :AStream(symbol, timeframe)
   {
      _step = step;
      _max = max;
   }

   bool GetValue(const int period, double &val)
   {
      double close = iClose(_symbol, _timeframe, period);
      val = iSAR(_symbol, _timeframe, _step, _max, period) + _shift * _instrument.GetPipSize();
      if (val > close)
         return false;
      return true;
   }
};

class ShortSARStream : public AStream
{
   double _step;
   double _max;
public:
   ShortSARStream(const string symbol, const ENUM_TIMEFRAMES timeframe, const double step, const double max)
      :AStream(symbol, timeframe)
   {
      _step = step;
      _max = max;
   }

   bool GetValue(const int period, double &val)
   {
      double close = iClose(_symbol, _timeframe, period);
      val = iSAR(_symbol, _timeframe, _step, _max, period) + _shift * _instrument.GetPipSize();
      if (val < close)
         return false;
      return true;
   }
};

class LongFractalStream : public AStream
{
public:
   LongFractalStream(const string symbol, const ENUM_TIMEFRAMES timeframe)
      :AStream(symbol, timeframe)
   {
   }

   bool GetValue(const int period, double &val)
   {
      val = iFractals(_symbol, _timeframe, MODE_LOWER, period + 1);
      if (val <= 0)
         return false;
      val += _shift * _instrument.GetPipSize();
      return true;
   }
};

class ShortFractalStream : public AStream
{
public:
   ShortFractalStream(const string symbol, const ENUM_TIMEFRAMES timeframe)
      :AStream(symbol, timeframe)
   {
   }

   bool GetValue(const int period, double &val)
   {
      val = iFractals(_symbol, _timeframe, MODE_UPPER, period + 1);
      if (val <= 0)
         return false;
      val += _shift * _instrument.GetPipSize();
      return true;
   }
};

class CustomStream : public AStream
{
public:
   double _stream[];

   CustomStream(const string symbol, const ENUM_TIMEFRAMES timeframe)
      :AStream(symbol, timeframe)
   {
   }

   int RegisterStream(int id, color clr, int width, ENUM_LINE_STYLE style)
   {
      SetIndexBuffer(id, _stream);
      SetIndexStyle(id, DRAW_LINE, style, width, clr);
      return id + 1;
   }

   bool GetValue(const int period, double &val)
   {
      val = _stream[period];
      return _stream[period] != EMPTY_VALUE;
   }
};

class CustomIndicatorStream : public AStream
{
   int _streamIndex;
public:
   CustomIndicatorStream(const string symbol, const ENUM_TIMEFRAMES timeframe, const int streamIndex)
      :AStream(symbol, timeframe)
   {
      _streamIndex = streamIndex;
   }

   bool GetValue(const int period, double &val)
   {
      val = iCustom(_instrument.GetSymbol(), _timeframe, "2 bar supply and demand", true, _streamIndex, period);
      if (val <= 0)
         return false;
      val += _shift * _instrument.GetPipSize();
      return true;
   }
};

class RangeStream : public IStream
{
   string _symbol;
   ENUM_TIMEFRAMES _timeframe;
public:
   RangeStream(const string symbol, const ENUM_TIMEFRAMES timeframe)
   {
      _symbol = symbol;
      _timeframe = timeframe;
   }

   virtual bool GetValue(const int period, double &val)
   {
      val = iHigh(_symbol, _timeframe, 0) - iLow(_symbol, _timeframe, 0);
      return true;
   }
};

class MoveStream : public IStream
{
   string _symbol;
   ENUM_TIMEFRAMES _baseTimeframe;
   ENUM_TIMEFRAMES _moveTimeframe;
public:
   MoveStream(const string symbol, const ENUM_TIMEFRAMES baseTimeframe, const ENUM_TIMEFRAMES moveTimeframe)
   {
      _symbol = symbol;
      _baseTimeframe = baseTimeframe;
      _moveTimeframe = moveTimeframe;
   }

   virtual bool GetValue(const int period, double &val)
   {
      int startIndex = iBarShift(_symbol, _baseTimeframe, iTime(_symbol, _moveTimeframe, period));
      int endIndex = period == 0 ? 0 : iBarShift(_symbol, _baseTimeframe, iTime(_symbol, _moveTimeframe, period - 1));
      val = 0;
      for (int i = startIndex; i >= endIndex; --i)
      {
         val += MathAbs(iClose(_symbol, _baseTimeframe, i) - iOpen(_symbol, _baseTimeframe, i));
      }

      return true;
   }
};

class MeanDevStream : public IStream
{
   IStream *_source;
   int _length;
   IStream *_avg;
public:
   MeanDevStream(IStream *source, const int length, const MATypes maType)
   {
      _source = source;
      _length = length;
      _avg = AveragesStreamFactory::Create(_source, _length, maType);
   }

   ~MeanDevStream()
   {
      delete _avg;
   }

   bool GetValue(const int period, double &val)
   {
      double avg;
      if (!_avg.GetValue(period, avg))
         return false;
      double summ = 0;
      for (int i = 0; i < _length; i++)
      {
         double price;
         if (!_source.GetValue(period + i, price))
            return false;
         summ += MathAbs(price - avg);
      }
      val = summ / _length;
      return true;
   }
};

class StochasticStream : public AStream
{
   int _kPeriods;
   int _dPeriods;
   int _slowing;
   int _stream;
public:
   StochasticStream(const string symbol, const ENUM_TIMEFRAMES timeframe, int kPeriods, int dPeriods, int slowing, int stream)
      :AStream(symbol, timeframe)
   {
      _kPeriods = kPeriods;
      _dPeriods = dPeriods;
      _slowing = slowing;
      _stream = stream;
   }

   bool GetValue(const int period, double &val)
   {
      val = iStochastic(_symbol, _timeframe, _kPeriods, _dPeriods, _slowing, MODE_SMA, 0, _stream, period);
      return true;
   }
};