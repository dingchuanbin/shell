#!/bin/bash
tmpfile=$$
mkfifo $tmpfile
exec 4<>$tmpfile
rm $tmpfile
threadnum=4
list=(1 2 3 4 5 6 7 8 9 10 11 12)


for ((i=1;i<=${threadnum};i++))
    do
        echo >&4
    done


for item in ${list[*]}
    do
        read -u4
        {
        echo $item
        sleep 2
        echo >&4
        }&
     done
wait
exec 4<>$-