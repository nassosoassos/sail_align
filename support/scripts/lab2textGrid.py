
import sys

"""
This script converts an alignment from lab 
format to textGrid format.

Input: lab_file: Path to lab file
Output: Outputs textGrid file to stfout. 
"""

if __name__=="__main__":
    lab_file = sys.argv[1]

    with open(lab_file) as f:
        lines = f.readlines()

    sys.stdout.write("File type = \"ooTextFile\"\n")
    sys.stdout.write("Object class = \"TextGrid\"\n")

    start_times = []
    end_times = []
    labels = []  
    for ln in lines:
        ln = ln.rstrip('\r\n')
        ln_info = ln.split()
        if len(ln_info) > 0:
            start_times.append(ln_info.pop(0))
            end_times.append(ln_info.pop(0))
            labels.append(" ".join(ln_info))

    n_segments = len(start_times)
    sys.stdout.write("xmin = {}\n".format(start_times[0]))
    sys.stdout.write("xmax = {}\n".format(end_times[-1]))
    sys.stdout.write("tiers? <exists>\n")
    sys.stdout.write("size = 1\n")
    sys.stdout.write("item []:\n")
    sys.stdout.write("item [1]:\n")
    sys.stdout.write("class = \"IntervalTier\"\n")
    sys.stdout.write("name = \"phono\"\n")
    sys.stdout.write("xmin = {}\n".format(start_times[0]))
    sys.stdout.write("xmax = {}\n".format(end_times[-1]))
    sys.stdout.write("intervals: size = {}\n".format(str(n_segments)))

    for count in range(n_segments):
        sys.stdout.write("intervals [{}]\n".format(str(count+1)))
        sys.stdout.write("xmin = {}\n".format(start_times[count]))
        sys.stdout.write("xmax = {}\n".format(end_times[count]))
        sys.stdout.write("text = \"{}\"\n".format(labels[count]))
