#!/bin/bash

mkdir cuts 
rm .videos .urls
next=$(cat .next)
newnext=""

download_video_lists(){
    rm .videos
    wget -O .videopage "$1" -q --show-progress
    newnext=$(grep "Next »" .videopage | sed -n  "s/.*\(\/results?sp=[^\"]*\)\".*/\1/p" | xargs echo https://www.youtube.com | sed -e "s/ //g")
    uniq .videopage | sed -n 's/.*\(\"\/watch?v=\w*\"\).*/\1/p' | sed -e "s/\"\/watch?v=//g" -e "s/\"//g" >> .videos
    if [[ ${newnext} != *"results"* ]]; then
        download_video_lists $1
    fi
    rm .videopage
}

do_video(){
    local entry=$1
    mkdir ../cuts/$entry 2>/dev/null
    youtube-dl --write-auto-sub  --id -f 18 $entry
    grep "<c> slime" $entry.*.vtt | sed -r "s/.*(<[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\.[0-9][0-9][0-9]><c> slime<\/c><[0-9][0-9]:[0-9][0-9]:[0-9][0-9].[0-9][0-9][0-9]>).*/\1/g" | grep -v '[abdfghjknopqrtuvwxyz]' | sed -e "s/><c> slime<\/c></,/g" -e "s/[<>]//g" > $entry.times
    cat $entry.times
    local O=0
    while read time; do 
        (( O += 1 )) 
        echo "CLIP!"
        timestamp=$(echo $time | cut -d"," -f 2)  
        end=$(echo $(echo "$timestamp" | cut -d: -f -2):$(echo "$timestamp-0.25" | cut -d: -f 3 | bc -l))
        ffmpeg -ss $end -i $entry.mp4 -ss 00:00:00 -to 00:00:00.5 -async 1 ../cuts/$entry/$O.mp4
    done < $entry.times
    wait
}
sudo mount -t tmpfs -o size=4096m tmpfs workingspace/
count=0
while true; do
    echo $next
    download_video_lists $next
    echo "New Next:" $newnext
    uniq .videos > .uniqvideos
    mv .uniqvideos .videos
    cd workingspace
    while read entry; do
        if [ ! -e ../cuts/$entry/ ]; then
            do_video $entry
        fi
    done < ../.videos
    rm *
    cd -
    #echo $newnext > .next
    #next=$newnext
    sleep 120s
    echo "Round $count done!"
    (( count += 1 ))
done
