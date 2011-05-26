from datetime import tzinfo, timedelta, datetime

__all__ = ['UTC', 'GMT1', 'utc', 'gmt1']

_ZERO = timedelta(0)
_HOUR = timedelta(hours=1)

# UTC time
class UTC(tzinfo):
    """UTC time"""

    def utcoffset(self, dt):
        return _ZERO

    def tzname(self, dt):
        return "UTC"

    def dst(self, dt):
        return ZERO

utc = UTC()

# Current DST rules for Central Europe Time
def _last_sunday_on_or_before(dt):
    wd = dt.weekday()
    if wd != 6:
        dt -= timedelta(wd + 1)
    return dt

_DSTSTART = datetime(1, 3, 31, 2)
_DSTEND = datetime(1, 10, 31, 2)

class GMT1(tzinfo):
    """Central Europe Time"""

    def tzname(self, dt):
        if self.dst(dt):
            return "CEST"
        else:
            return "CET"

    def utcoffset(self, dt):
        return timedelta(hours=1) + self.dst(dt)

    def dst(self, dt):
        if dt is None or dt.tzinfo is None:
            return _ZERO
        assert dt.tzinfo is self

        start = _last_sunday_on_or_before(_DSTSTART.replace(year=dt.year))
        end = _last_sunday_on_or_before(_DSTEND.replace(year=dt.year))

        if start <= dt.replace(tzinfo=None) < end:
            return _HOUR
        else:
            return _ZERO

gmt1 = GMT1()
