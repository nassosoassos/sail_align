#!/usr/bin/python
import sys
import wave
import os

if __name__=="__main__":
    lab_file = sys.argv[1]
    wav_list = sys.argv[2]
    lab_dir = sys.argv[3]
    suffix = sys.argv[4]

    suffix = "." + suffix
    
    wavs = open(wav_list, 'r')
    start_times = []
    end_times = []
    wav_names = []
    s_time = 0
    n_files = 0
    for wv in wavs:
        wv = wv.rstrip('\r\n')
        bname = os.path.splitext(os.path.split(wv)[1])[0]
        audio = wave.open(wv, 'r')
        n_frames = audio.getnframes()
        frame_rate = audio.getframerate()
        duration = n_frames / float(frame_rate)
        start_times.append(s_time)
        wav_names.append(bname)
        s_time += duration
        end_times.append(s_time)
        n_files += 1

    wavs.close()

    lab = open(lab_file, 'r')
    i_file = 0
    c_lab_file = None
    for ln in lab:
        ln = ln.rstrip('\r\n')
        ln_info = ln.split()
        if len(ln_info) == 0:
            break
        st = float(ln_info.pop(0))
        et = float(ln_info.pop(0))
        label = " ".join(ln_info)
        if st >= start_times[i_file] and et <= end_times[i_file]:
            if c_lab_file == None:
                c_lab_file = open(os.path.join(lab_dir,wav_names[i_file]+suffix),'w')
            f_st = st - start_times[i_file]
            f_et = et - start_times[i_file]
            c_lab_file.write("{} {} {}\n".format(str(f_st), str(f_et), label))
        elif i_file < n_files-1 and et > start_times[i_file+1]:
            if st < end_times[i_file]:
                if c_lab_file is None:
                    c_lab_file = open(os.path.join(lab_dir,wav_names[i_file]+suffix),'w')
                f_st = st - start_times[i_file]
                f_et = end_times[i_file] - start_times[i_file]
                c_lab_file.write("{} {} {}\n".format(str(f_st), str(f_et), label))
                c_lab_file.close()
                i_file += 1
                c_lab_file = open(os.path.join(lab_dir, wav_names[i_file] + suffix), 'w')
                f_st = 0
                f_et = et - start_times[i_file]
                c_lab_file.write("{} {} {}\n".format(str(f_st), str(f_et), label))
            else:
                if c_lab_file is not None:
                    c_lab_file.close()
                    c_lab_file = None
                i_file += 1
                if et <= end_times[i_file]:
                    c_lab_file = open(os.path.join(lab_dir, wav_names[i_file] + suffix), 'w')
                    f_st = st - start_times[i_file]
                    f_et = et - start_times[i_file]
                    c_lab_file.write("{} {} {}\n".format(str(f_st), str(f_et), label))
    if c_lab_file is not None:
        c_lab_file.close()
    lab.close()
    

