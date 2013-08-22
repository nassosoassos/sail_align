#!/usr/bin/python

import sys

if __name__=="__main__":
    lab_file = sys.stdin
    textgrid_file = sys.stdout

    print >> textgrid_file, "File type = \"ooTextFile\""
    print >> textgrid_file, "Object class = \"TextGrid\"\n"

    start_times = []
    end_times = []
    labels = []  
    for ln in lab_file:
        ln = ln.rstrip('\r\n')
        ln_info = ln.split()
        if len(ln_info) > 0:
            start_times.append(ln_info.pop(0))
            end_times.append(ln_info.pop(0))
            labels.append(" ".join(ln_info))

    n_segments = len(start_times)
    print >> textgrid_file, "xmin = {}".format(start_times[0])
    print >> textgrid_file, "xmax = {}".format(end_times[-1])
    print >> textgrid_file, "tiers? <exists>"
    print >> textgrid_file, "size = 1"
    print >> textgrid_file, "item []:"
    print >> textgrid_file, "item [1]:"
    print >> textgrid_file, "class = \"IntervalTier\""
    print >> textgrid_file, "name = \"phono\""
    print >> textgrid_file, "xmin = {}".format(start_times[0])
    print >> textgrid_file, "xmax = {}".format(end_times[-1])
    print >> textgrid_file, "intervals: size = {}".format(str(n_segments))

    for count in range(n_segments):
        print >> textgrid_file, "intervals [{}]".format(str(count+1))
        print >> textgrid_file, "xmin = {}".format(start_times[count])
        print >> textgrid_file, "xmax = {}".format(end_times[count])
        print >> textgrid_file, "text = \"{}\"".format(labels[count])






    

