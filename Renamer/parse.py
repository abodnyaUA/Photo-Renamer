#!/usr/bin/python
import ccl_bplist
import time
import datetime
def parse():
    f = open("date", "rb")
    parsed = ccl_bplist.load(f)
    unixtime = time.mktime(parsed.timetuple())
    return unixtime
