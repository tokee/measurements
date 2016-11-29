#!/bin/bash

#
# Takes a log containing lines as
# 20140122-131155 177
# and generates a graph bucketed by hour
#
# Use it as you see fit
# Toke Eskildsen, te@ekot.dk, 2014
#

# Maximum height of the y-axis (milliseconds)
if [ "." == ".$YMAX" ]; then
    YMAX=6000
fi

# http://jfly.iam.u-tokyo.ac.jp/color/
# Only lt 1-6
LINETYPES="set linetype 1 lc rgb \"#0072B2\""$'\n'"set linetype 2 lc rgb \"#CC79A7\""$'\n'"set linetype 3 lc rgb \"#009E73\""$'\n'"set linetype 4 lc rgb \"#D55E00\""$'\n'"set linetype 5 lc rgb \"#E69F00\""$'\n'"set linetype 6 lc rgb \"#56B4E9\""$'\n'"set linetype 7 lc rgb \"#0000ff\""$'\n'"set linetype 8 lc rgb \"#000000\""$'\n'"set linetype 9 lc rgb \"#ccccff\""$'\n'"set linetype 10 lc rgb \"#3333ff\""

#Input: Log designation regexp [timesuffix] [divisor]
collectRegexp() {
    local LOG="$1"
    local DESIGNATION="$2"
    local REGEXP="$3"
    local TIME_SUFFIX="$4"
    local DIVISOR="$4"
    if [ ! -n "$DIVISOR" ]; then
        DIVISOR="1"
    fi

#    echo "*** regexp=$REGEXP timeSuffix=$TIME_SUFFIX" 1>&2
    local TMP=`mktemp`
    # TODO: Generalize the 'error'-skipping
    grep "$REGEXP" "$LOG" | grep -v "error" | cut -d\  -f2 | sort -n > $TMP
    local COUNT=`cat $TMP | wc -l`
    if [ "$COUNT" -gt 0 ]; then
        local MIN=`head -n 1 $TMP`
        local P025=`head -n $((COUNT*25/100)) $TMP | tail -n 1`
        if [ "." == ".$P015" ]; then
            P025=$MIN
        fi
        local MEDIAN=`head -n $((COUNT*50/100)) $TMP | tail -n 1`
        if [ "." == ".$MEDIAN" ]; then
            MEDIAN=$P025
        fi
        local P075=`head -n $((COUNT*75/100)) $TMP | tail -n 1`
        if [ "." == ".$P075" ]; then
            P075=$MEDIAN
        fi
        local P095=`head -n $((COUNT*95/100)) $TMP | tail -n 1`
        if [ "." == ".$P095" ]; then
            P095=$P075
        fi
        local MAX=`tail -n 1 $TMP`

# http://stackoverflow.com/questions/2702564/how-can-i-quickly-sum-all-numbers-in-a-file
        local SUM=`awk '{ sum += $1 } END { print sum }' $TMP`
#        echo "*** $DESIGNATION$TIME_SUFFIX $MIN $P025 $MEDIAN $P075 $P095 $MAX $COUNT $SUM" 1>&2
        echo "$DESIGNATION$TIME_SUFFIX $MIN $P025 $MEDIAN $P075 $P095 $MAX $COUNT $SUM"
    fi
    rm $TMP
}

# Input an apache log in the format
# 80.62.116.108 - - [07/Jan/2014:21:42:14 +0100] "GET /projekter/mindre/self/tn_20040908_1949_2_Cykelstol.jpg HTTP/1.1" 200 22082 "http://ekot.dk/projekter/mindre/" "Mozilla/5.0 (iPhone; CPU iPhone OS 7_0_2 like Mac OS X) AppleWebKit/537.51.1 (KHTML, like Gecko) Version/7.0 Mobile/11A501 Safari/9537.53"
# or
# 80.62.116.108 - - [07/Jan/2014:21:42:14 +0100] "GET /projekter/mindre/self/tn_20040908_1949_2_Cykelstol.jpg HTTP/1.1" 200 22082 "http://ekot.dk/projekter/mindre/" "Mozilla/5.0 (iPhone; CPU iPhone OS 7_0_2 like Mac OS X) AppleWebKit/537.51.1 (KHTML, like Gecko) Version/7.0 Mobile/11A501 Safari/9537.53" 123456
# where the last entry is response time in microseconds
# Output: timestamp bytes [respose_time]
apache2csv() {
    # Grep time, bytes and [response time], convert date to pseudo-date for month-processing,
    # convert month names to numbers, remove tags
    # TODO: Handle lines with - as returned bytes
    less "$1" | sed -e 's/\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\) [^ ]\+ [^ ]\+ \[\(.*\)\] \"\([A-Z]\+\) \([^"]\+\) \(HTTP\/[^"]\+\)" \([0-9]\+\) \([-0-9]\+\) \"[^"]\+\" \"[^"]\+\" \?\([0-9]*\)\?$/<ts>___t\2t___<\/ts><bytes>\7<\/bytes><ms>\8<\/ms>/' -e 's/___t\([0-9][0-9]\)\/\([A-Z][a-z][a-z]\)\/\([0-9][0-9][0-9][0-9]\):\([0-9][0-9]\):\([0-9][0-9]\):\([0-9][0-9]\) .[0-9][0-9][0-9][0-9]t___/\3__\2__\1-\4\5\6/g' -e 's/__Jan__/01/g' -e 's/__Feb__/02/g' -e 's/__Mar__/03/g' -e 's/__Apr__/04/g' -e 's/__May__/05/g' -e 's/__Jun__/06/g' -e 's/__Jul__/07/g' -e 's/__Aug__/08/g' -e 's/__Sep__/09/g' -e 's/__Oct__/10/g' -e 's/__Nov__/11/g' -e 's/__Dec__/12/g' -e 's/<[^>]\+>\([^<]*\)<\/[^>]\+>/\1 /g'
} 

# Like above but only for the timestamp
apache2time() {
    # Grep time, bytes and [response time], convert date to pseudo-date for month-processing,
    # convert month names to numbers, remove tags
    # TODO: Handle lines with - as returned bytes
    less "$1" | sed -e 's/\([0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\) [^ ]\+ [^ ]\+ \[\(.*\)\] \"\([A-Z]\+\) \([^"]\+\) \(HTTP\/[^"]\+\)" \([0-9]\+\) \([-0-9]\+\) \"[^"]\+\" \"[^"]\+\"/<ts>___t\2t___<\/ts>/' -e 's/___t\([0-9][0-9]\)\/\([A-Z][a-z][a-z]\)\/\([0-9][0-9][0-9][0-9]\):\([0-9][0-9]\):\([0-9][0-9]\):\([0-9][0-9]\) .[0-9][0-9][0-9][0-9]t___/\3__\2__\1-\4\5\6/g' -e 's/__Jan__/01/g' -e 's/__Feb__/02/g' -e 's/__Mar__/03/g' -e 's/__Apr__/04/g' -e 's/__May__/05/g' -e 's/__Jun__/06/g' -e 's/__Jul__/07/g' -e 's/__Aug__/08/g' -e 's/__Sep__/09/g' -e 's/__Oct__/10/g' -e 's/__Nov__/11/g' -e 's/__Dec__/12/g' -e 's/<[^>]\+>\([^<]*\)<\/[^>]\+>/\1 /g' | grep -o "[0-9]\{8,8\}-[0-9]\{6,6\}"
} 

# Input a log4j line with ms
# INFO  [RMI TCP Connection(2)-127.0.0.1] [2014-02-19 15:19:53,219] [suggestqueries] Completed addSuggestion(dansk latin ordbog, 49) in 486.32ms
# INFO  [RMI TCP Connection(2)-127.0.0.1] [2014-02-19 15:19:53,219] [suggestqueries] Completed addSuggestion(dansk latin ordbog, 49) in 486ms
# INFO  [RMI TCP Connection(2)-127.0.0.1] [2014-02-19 15:19:53,219] [suggestqueries] Completed addSuggestion(dansk latin ordbog, 49) in 486ms foobar
# Output: timestamp milliseconds
log4j2csv() {
    # \7 containg ms granularity
    cat "$1" | sed 's/.*\([[0-9][0-9][0-9][0-9]\)-\([0-9][0-9]\)-\([0-9][0-9]\) \([0-9][0-9]\):\([0-9][0-9]\):\([0-9][0-9]\),\([0-9][0-9][0-9]\).\+ \([0-9]\+\)\(\.[0-9]\+\)\?ms/\1\2\3-\4\5\6 \8/'
}

# Input a log4j line and output only timestamps
# INFO  [RMI TCP Connection(2)-127.0.0.1] [2014-02-19 15:19:53,219] [suggestqueries] Completed addSuggestion(dansk latin ordbog, 49)
# Output: timestamp
log4j2csvTime() {
    # \7 containg ms granularity
    cat "$1" | sed 's/.*\([[0-9][0-9][0-9][0-9]\)-\([0-9][0-9]\)-\([0-9][0-9]\) \([0-9][0-9]\):\([0-9][0-9]\):\([0-9][0-9]\),\([0-9][0-9][0-9]\).\+/\1\2\3-\4\5\6/'
}

# Bucket by hours in the day (24 hour clock)
# Input: Log
bucket24() {
    local LOG=$1
    
    local TMP=`mktemp`
    echo "# hour min 0.25 median 0.75 0.95 max count sum log=$LOG"
    for H in `seq 0 23`; do
        if [ $H -le 9 ]; then
            local H="0$H"
        fi
        local REGEXP="[0-9]\{8,8\}-${H}[0-9][0-9]\([0-9][0-9]\)\? "
        collectRegexp "$LOG" "$H" "$REGEXP"
    done
    rm $TMP
}

# Bucket by regexp across time
# Input: Log regexp [time_suffix]
bucketRegexp() {
    local LOG="$1"
    local REGEXP="$2"
    local TIME_SUFFIX="$3"

#    echo "*** bucketRegexp: regexp=$REGEXP timeSuffix=$TIME_SUFFIX" 1>&2
    if [ ! -f "$LOG" ]; then
        echo "No log at $LOG"
        exit 1
    fi
    if [ ! -n "$REGEXP" ]; then
        echo "No regexp provided"
        exit 1
    fi
    
    echo "# hour min 0.25 median 0.75 0.95 max count sum log=$LOG"
    # Get unique hours
    local BUCKETS=`cat "$LOG" | grep -o "$REGEXP" | sort | uniq`

    for B in $BUCKETS; do
        collectRegexp "$LOG" "$B" "$B" "$TIME_SUFFIX"
    done
}

# Instead of the measurements themselves, only the count of unique entries
# within the bucket is extracted
# Input: Log regexp [time_suffix] [divisor]
bucketRegexpCount() {
    local LOG="$1"
    local REGEXP="$2"
    local TIME_SUFFIX="$3"
    local DIVISOR="$4"
    if [ ! -n "$DIVISOR" ]; then
        DIVISOR="1"
    fi

    if [ ! -f "$LOG" ]; then
        echo "No log at $LOG"
        exit 1
    fi
    if [ ! -n "$REGEXP" ]; then
        echo "No regexp provided"
        exit 1
    fi
    
    echo "# timestamp count log=$LOG"
    # Get unique hours
    local BUCKETS=`cat "$LOG" | grep -o "$REGEXP" | sort | uniq`
    for B in $BUCKETS; do
        local COUNT=`cat "$LOG" | grep -c "$B"`
        echo "$B$TIME_SUFFIX $((COUNT/DIVISOR))"
    done
}

# Bucket by hours across days
# Input: Log
bucketHour() {
    bucketRegexp "$1" "^[0-9]\{8,8\}-[0-9][0-9]"
}

# Bucket by minutes across days
# Input: Log
bucketMinute() {
    bucketRegexp "$1" "^[0-9]\{8,8\}-[0-9][0-9][0-9][0-9]"
}

# Bucket by 10 minutes across days, timing is in occurrences/min
# Input: Log
bucket10Minute() {
    bucketRegexp "$1" "^[0-9]\{8,8\}-[0-9][0-9][0-9]" "0"
}

# Input: Log
# Output: Counts expressed as occurrences/min within the bucket
bucketHourCount() {
    bucketRegexpCount "$1" "^[0-9]\{8,8\}-[0-9][0-9]" "" "60"
}

# Input: Log
# Output: Counts expressed as occurrences/min within the bucket
bucketMinuteCount() {
    bucketRegexpCount "$1" "^[0-9]\{8,8\}-[0-9][0-9][0-9][0-9]"
}

# Input: Log
# Output: Counts expressed as occurrences/min within the bucket
bucket10MinuteCount() {
    bucketRegexpCount "$1" "^[0-9]\{8,8\}-[0-9][0-9][0-9]" "0" "10"
}

# Takes a data file consisting of numbers only, iterates them sequentially
# and puts them in fixed size buckets with percentiles. Use this to get
# an overview of change through samples when there are no timestamps.
# Input: datafile bucketsize
bucketX() {
    local LOG="$1"
    local SIZE=$2
    if [ ! -n $SIZE ]; then
        echo "Usage: bucketX datafile bucket_size" 1>&2
        exit 2
    fi
    echo "bucket# 0.25 median 0.75 0.95 max count sum log=$LOG"
    local TCOUNT=1
    local COUNT=0
    local BUCKET=`mktemp`
    while read line
    do
        echo "dummy $line" >> $BUCKET
        local COUNT=$((COUNT+1))
        if [ $COUNT -eq $SIZE ]; then
            local COUNT=0
            collectRegexp $BUCKET "$TCOUNT" ".*" "" 
            echo -n "" > $BUCKET
            local TCOUNT=$((TCOUNT+1))
        fi
    done < "$LOG"
    collectRegexp $BUCKET "$TCOUNT" ".*" "" 
    rm $BUCKET
}

# Takes a data file consisting on "X Y" data pairs, buckets the data in
# ranges 1-9, 10-99, 100-999 etc. and calculates percentiles for each
# bucket.
# Input: datafile [max-exp]
# MAXEXP: If set, forces the maximum exponential on x
bucketXYlog() {
    local DIGITS=1
    local PRE="1"
    local POST="9"
    local REGEXP="^"
    if [ "." == ".$MAXEXP" ]; then
        local MAXEXP=9
        local FORCE="false"
    else
        local FORCE=true
    fi
    
    local COUNT=1
    while [ $COUNT -le $MAXEXP ]; do
        local REGEXP="${REGEXP}[0-9]"
        local DESIGNATION="${PRE}-${POST}"
        local DESIGNATION="10^$DIGITS"
        local PERCENTILES=`collectRegexp $1 "$DESIGNATION" "$REGEXP "`
        
        if [ "." == ".$PERCENTILES" ]; then
            if [ $FORCE == false ]; then
                break
            fi
        else
            echo "$DIGITS $PERCENTILES"
        fi
        local DIGITS=$((DIGITS+1))
        local PRE="${PRE}0"
        local POST="${POST}9"
        COUNT=$(( COUNT+1 ))
    done
}

# Takes a data file consisting of numbers only, iterates them sequentially
# and puts them buckets based on ranges, outputting the number of elements
# in each bucket. Use this to get an overview of how numbers are grouped.
# Input: datafile bucketsize
bucketRanges() {
    local LOG="$1"
    local SIZE="$2"
    if [ "." == ".$SIZE" ]; then
        echo "Usage: bucketRanges datafile bucket_size" 1>&2
        exit 2
    fi

    local SORTED=`mktemp`
    cat "$LOG" | sort -n > $SORTED
    local MAX=`tail -n 1 $SORTED`
    local COUNT=0

    local END=$SIZE
    while read line
    do
        while [ "$line" -ge "$END" ]; do
            if [ ! 0 -eq $COUNT ]; then
                echo "$END $COUNT"
            fi
            local COUNT=0
            END=$((END + SIZE))
        done
        local COUNT=$((COUNT+1))
    done < "$SORTED"
    if [ ! 0 -eq $COUNT ]; then
        echo "$END $COUNT"
    fi

    rm $SORTED
}

# Input: Log data [custom]
plotPercentile() {
    local LOG="$1"
    local DATA="$2"
    local CUSTOM="$3"

    OUT=${LOG##*/}
    OUT="${OUT%.*}.png"
    TMPPLOT=`mktemp`
cat > $TMPPLOT << EOF
# 25% 50% 75% 95% mean
set terminal png size 1000, 650
set linetype 1 lc rgb "#ff0000"
set linetype 2 lc rgb "#ff0000"
set linetype 3 lc rgb "#ff0000"
set linetype 4 lc rgb "#ffcccc"
set linetype 5 lc rgb "#ff3333"
set linetype 6 lc rgb "#0000ff"
set linetype 7 lc rgb "#0000ff"
set linetype 8 lc rgb "#0000ff"
set linetype 9 lc rgb "#ccccff"
set linetype 10 lc rgb "#3333ff"

set output "$OUT"

set title "$LOG `date`"
set xlabel 'Hour'
set ylabel 'milliseconds'

set datafile separator " "

#set xrange [ 0 : 24 ]
set yrange [ 0 : $YMAX ]
#set grid ytics lt 0 lw 1 lc rgb "#bbbbbb"
$CUSTOM

plot '$DATA' using 1:7 with lines lw 1 lc 1 title 'Max', \\
     '$DATA' using 1:6 with lines lw 1 lc 8 title 'Percentile (95%)', \\
     '$DATA' using 1:5 with lines lw 1 lc 7 title 'Percentile (75%)', \\
     '$DATA' using 1:4 with lines lw 2 lc 7 title 'Median', \\
     '$DATA' using 1:3 with lines lw 1 lc 7 title 'Percentile (25%)', \\
     '$DATA' using 1:2 with lines lw 1 lc 1 lt 7 title 'Min'
EOF
    gnuplot "$TMPPLOT"
    rm $TMPPLOT
}

# Input: Log data [custom]
plotCount() {
    local LOG="$1"
    local DATA="$2"
    local CUSTOM="$3"

    OUT=${LOG##*/}
    OUT="${OUT%.*}.png"
    TMPPLOT=`mktemp`
cat > $TMPPLOT << EOF
# 25% 50% 75% 95% mean
set terminal png size 1000, 650
set linetype 1 lc rgb "#ff0000"
set linetype 2 lc rgb "#ff0000"
set linetype 3 lc rgb "#ff0000"
set linetype 4 lc rgb "#ffcccc"
set linetype 5 lc rgb "#ff3333"
set linetype 6 lc rgb "#0000ff"
set linetype 7 lc rgb "#0000ff"
set linetype 8 lc rgb "#0000ff"
set linetype 9 lc rgb "#ccccff"
set linetype 10 lc rgb "#3333ff"

set output "$OUT"

set title "$LOG `date`"
set xlabel 'Time'
set ylabel 'occurences'

set datafile separator " "
set style fill solid border -1

#set xrange [ 0 : 24 ]
#set yrange [ 0 : $YMAX ]
#set grid ytics lt 0 lw 1 lc rgb "#bbbbbb"
$CUSTOM

plot '$DATA' using 1:2 with boxes lw 1 lc 1 title 'Count'
EOF

    gnuplot "$TMPPLOT"
    rm $TMPPLOT
}

# Input: Log data [custom]
plotSum() {
    local LOG="$1"
    local DATA="$2"
    local CUSTOM="$3"

    OUT=${LOG##*/}
    OUT="${OUT%.*}.png"
    TMPPLOT=`mktemp`
# http://askubuntu.com/questions/470319/gnuplot-error-while-calchep-process
cat > $TMPPLOT << EOF
# 25% 50% 75% 95% mean
set terminal png size 1000, 650
set linetype 1 lc rgb "#ff0000"
set linetype 2 lc rgb "#ff0000"
set linetype 3 lc rgb "#ff0000"
set linetype 4 lc rgb "#ffcccc"
set linetype 5 lc rgb "#ff3333"
set linetype 6 lc rgb "#0000ff"
set linetype 7 lc rgb "#0000ff"
set linetype 8 lc rgb "#0000ff"
set linetype 9 lc rgb "#ccccff"
set linetype 10 lc rgb "#3333ff"

set output "$OUT"

set title "$LOG `date`"
$CUSTOM
set xlabel 'Time'
set ylabel 'MBytes'

set datafile separator " "
set style fill solid border -1

#set xrange [ 0 : 24 ]
#set yrange [ 0 : $YMAX ]
#set grid ytics lt 0 lw 1 lc rgb "#bbbbbb"

plot '$DATA' using 1:(\$9/1048576) with boxes lw 1 lc 1 title 'Sum (MB)'
EOF

    gnuplot "$TMPPLOT"
    rm $TMPPLOT
}

# Input logfile image [custom]
# "$COUNTER $DESIGNATION $MIN $P025 $MEDIAN $P075 $P095 $MAX $COUNT $SUM"
plotCandle() {
    local DATA=$1
    local IMAGE=$2
    local CUSTOM="$3"
#    local LCOUNT=`cat $DATA | wc -l`
    local LCOUNT=`tail -n 1 $DATA | cut -d\  -f1`

    TMPPLOT=`mktemp`
# http://gnuplot.sourceforge.net/demo_4.3/candlesticks.html
cat > $TMPPLOT << EOF
# 25% 50% 75% 95% mean
set terminal png size 1100, 650
set linetype 1 lc rgb "#ff0000"
set linetype 2 lc rgb "#ff0000"
set linetype 3 lc rgb "#ff0000"
set linetype 4 lc rgb "#ffcccc"
set linetype 5 lc rgb "#ff3333"
set linetype 6 lc rgb "#0000ff"
set linetype 7 lc rgb "#0000ff"
set linetype 8 lc rgb "#0000ff"
set linetype 9 lc rgb "#ccccff"
set linetype 10 lc rgb "#3333ff"

#set xrange [ 0.00000 : 11.0000 ] noreverse nowriteback
#set yrange [ 0.00000 : 10.0000 ] noreverse nowriteback
set output "$IMAGE"
set title "Quartiles for response times with top as 95 percentile, `date`"

set boxwidth 0.6 absolute
set xlabel 'Number of hits'
set ylabel 'HTTP GET response time in milliseconds'
set datafile separator " "

set xrange [ 0.5 : ${LCOUNT}.5 ]
set yrange [ 0 : $YMAX ]
#set grid ytics lt 0 lw 1 lc rgb "#bbbbbb"
$CUSTOM

#http://stackoverflow.com/questions/15404628/how-can-i-generate-box-and-whisker-plots-with-variable-box-width-in-gnuplot
# http://stackoverflow.com/questions/4805930/making-x-axis-tics-from-column-in-data-file-in-gnuplot
# count 25% min 95% 75% label
plot '$DATA' using 1:4:3:7:6 with candlesticks lc 1 lt 3 lw 2 title 'Quartiles' whiskerbars, \\
     ''      using 1:5:5:5:5:xtic(2) with candlesticks lt -1 lw 2 title 'Median'
EOF
    gnuplot "$TMPPLOT"
    rm $TMPPLOT
}

# Input: Log
plot24() {
    LOG="$1"
    TMPDATA=`mktemp`
    bucket24 "$LOG" > $TMPDATA
    plotPercentile "$LOG" "$TMPDATA"
    rm $TMPDATA
}

# Input: Log
plotHour() {
    LOG="$1"
    TMPDATA=`mktemp`
    bucketHour "$LOG" > $TMPDATA
    plotPercentile "$LOG" "$TMPDATA" "set timefmt \"%Y%m%d-%H\""$'\n'"set xdata time"
    rm $TMPDATA
}

# Input: Log
plotMinute() {
    LOG="$1"
    TMPDATA=`mktemp`
    bucketMinute "$LOG" > $TMPDATA
    plotPercentile "$LOG" "$TMPDATA" "set timefmt \"%Y%m%d-%H%M\""$'\n'"set xdata time"
    rm $TMPDATA
}

# Input: Log
plot10Minute() {
    LOG="$1"
    TMPDATA=`mktemp`
    bucket10Minute "$LOG" > $TMPDATA
    plotPercentile "$LOG" "$TMPDATA" "set timefmt \"%Y%m%d-%H%M\""$'\n'"set xdata time"
    rm $TMPDATA
}

# helper for allJoin
fillEmpty() {
    local C1="$1"
    local IN="$2"

    local COLS=`cat $IN | tail -n 1 | wc -w`
    local EMPTY=""
    while [ $COLS -gt 1 ]; do
        EMPTY="$EMPTY -"
        COLS=$((COLS-1))
    done
    
    local EXTRA=`mktemp`
    for C in `cat $C1`; do
        if [ `grep -c "^$C " $IN` -le "0" ]; then
            echo "$C$EMPTY" >> $EXTRA
        fi
    done
    cat $IN $EXTRA | sort
    rm $EXTRA
}

# Input: src dest
fillEmpty2() {
    return
    # TODO: Create this
}

# join where missing values are represented as '-' instead of skipping the line
# input: file1 file2
#
# Optional
# FIX2: If true, the second column of the result will contain the non-'-' value from any of the two input
# Example (FIX2=false): "1 - -" + "1 foo 12" -> "1 - - foo 12"
# Example (FIX2=true):  "1 - -" + "1 foo 12" -> "1 foo - foo 12"
allJoin() {
   local C1=`mktemp`
   cat $1 $2 | grep -o "^[^ ]\+ " | sort | uniq > $C1
   local F1=`mktemp`
   fillEmpty $C1 $1 > $F1
   local F2=`mktemp`
   fillEmpty $C1 $2 > $F2
   if [ ".$FIX2" == ".true" ]; then
       fillEmpty2 $F1 $F2
       fillEmpty2 $F2 $F1
   fi
#   cat $F1 > t_f1
#   cat $F2 > t_f2
   join $F1 $F2
   rm $C1 $F1 $F2
}

# Plotter for bucketXYlog
# Input: Log with "X Y" data
#
# Optionals:
# MAXEXP: If set, forces the maximum exponential on x
# LOGY: If false, disables log y-axis
# YMAX: Self-explanatory
# TITLE: Self-explanatory
# OUT: Output image name (format is always png)
plotXYlog() {
    LOG="$1"
    _=${LOGY:=true}
    if [ "true" == "$LOGY" ]; then
        local LOS="set logscale y"
    else
        local LOS=""
    fi
    if [ ! "." == ".$MAXEXP" ]; then
        local LOS=$'\n'"set xrange [ 0.5 : ${MAXEXP}.5 ]"
    fi

    _=${YMAX:=10000}
    TMPDATA=`mktemp`
    bucketXYlog "$LOG" > $TMPDATA
    local TOUT=${LOG##*/}
    local TOUT="${TOUT%.*}.png"
    _=${OUT:=$TOUT}
    _=${TITLE:="set title \"Quartiles for response times with top as 95 percentile, `cat $LOG | wc -l` samples, `date +%Y-%m-%d`\""}
    plotCandle "$TMPDATA" "$OUT" "set yrange [ 5 : $YMAX ]"$'\n'"$LOS"$'\n'"$TITLE"
    rm $TMPDATA
}

# Input: Multiple logs with "X Y" data
#
# Optionals:
# MAXEXP: If set, forces the maximum exponential on x
# LOGY: If false, disables log y-axis
# YMAX: Self-explanatory
# TITLE: Self-explanatory
# OUT: Output image name (format is always png)
plotXYlogs() {
    local LOGS="$@"
    _=${LOGY:=true}
    if [ "true" == "$LOGY" ]; then
        local LOS="set logscale y"
        _=${YMIN:=1}
    else
        local LOS=""
        _=${YMIN:=0}
    fi
    local TMPDATA=`mktemp`
    local MERGED=`mktemp`
    local MERGEDT=`mktemp`
    local COUNT=0
    local LARGEST=0
    local LARGEST_INDEX=1

    for LOG in $LOGS; do
        # Needs better sed-fu
        bucketXYlog "$LOG" | sed  -e 's/     / - - - - - /g' -e 's/     / - - - - /g' -e 's/    / - - - /g' -e 's/   / - - /g' -e 's/  / - /g' > $TMPDATA
        if [ "0" -eq "$COUNT" ]; then
            cat $TMPDATA > $MERGED
        else
            FIX2=true allJoin $MERGED $TMPDATA > $MERGEDT
            mv $MERGEDT $MERGED
        fi
        local COUNT=$((COUNT+1))

        # Find the data set with the most entries
        LINES=`cat $TMPDATA | wc -l`
        if [ "$LINES" -lt "$LARGEST" ]; then
            LARGEST=$LINES
            LARGEST_INDEX=1
        fi
    done
    rm $TMPDATA

    local NUMPLOTS=$COUNT
#    cat $MERGED

    local OFFSET=0
    local DELTA=9
    local PLOT=""
    local COUNT=0
    for LOG in $LOGS; do
        local SANS=${LOG##*/}
        local LT=$((COUNT+1))
        if [ "." != ".$PLOT" ]; then
            local PLOT="${PLOT}, \\"$'\n'
        fi
#        local DATA_COUNT=`cat "$LOG" | wc -l`
        # median
        local MEDIAN_TEMP=`mktemp`
        cat "$LOG" | grep "^[0-9]" | cut -d\  -f2 > $MEDIAN_TEMP
        local ANALYZED=`collectRegexp $MEDIAN_TEMP "foo" ".*"`
        local DATA_COUNT=`echo "$ANALYZED" | cut -d\  -f8`
        local SUM=`echo "$ANALYZED" | cut -d\  -f9`
        if [ "$DATA_COUNT" -eq "0" ]; then
            local AVG="N/A"
        else
            local AVG=$((SUM/DATA_COUNT))
        fi
        local MEDIAN=`echo "$ANALYZED" | cut -d\  -f4`
        rm $MEDIAN_TEMP
        local PLOT="$PLOT '$MERGED' using ((\$1-1)*$((NUMPLOTS+1))+$COUNT):$((OFFSET+4)):$((OFFSET+3)):$((OFFSET+7)):$((OFFSET+6)) with candlesticks lt $LT lw 2 title 'Quartiles $SANS ($DATA_COUNT queries, $AVG mean, $MEDIAN med)' whiskerbars, \\"$'\n'
        if [ "$NUMPLOTS" -eq "$LT" ]; then
            local PLOT="$PLOT '$MERGED' using ((\$1-1)*$((NUMPLOTS+1))+$COUNT):$((OFFSET+5)):$((OFFSET+5)):$((OFFSET+5)):$((OFFSET+5))"
            if [ "$LT" -eq "$LARGEST_INDEX" ]; then 
                local PLOT="${PLOT}:xtic(2)"
            fi
            local PLOT="$PLOT with candlesticks lt -1 lw 2 title 'Median'"
        else
            local PLOT="$PLOT '$MERGED' using ((\$1-1)*$((NUMPLOTS+1))+$COUNT):$((OFFSET+5)):$((OFFSET+5)):$((OFFSET+5)):$((OFFSET+5))"
            if [ "$LT" -eq "$LARGEST_INDEX" ]; then 
                local PLOT="${PLOT}:xtic(2)"
            fi
            local PLOT="$PLOT with candlesticks lt -1 lw 2 title ''"
       fi
        local OFFSET=$((OFFSET+DELTA))
        local COUNT=$((COUNT+1))
    done

    _=${OUT:="multi_candles.png"}
    _=${TITLE:="Quartiles for response times with top as 95 percentile, `cat $LOGS | wc -l` samples, `date +%Y-%m-%d`"}
    local LCOUNT=`cat $MERGED | wc -l`

    if [ "." == ".$XMAX" ]; then
        XMAX=$((LCOUNT*(NUMPLOTS+1)-1))
    fi

    TMPPLOT=`mktemp`
cat > $TMPPLOT << EOF
set terminal png size 1100, 650
$LINETYPES

set output "$OUT"
set title "$TITLE"

set boxwidth 0.6 absolute
set xlabel 'Number of hits'
set ylabel 'Response time in milliseconds'
set datafile separator " "
$LOS

set xrange [ -0.5 : $XMAX ]
set yrange [ $YMIN : $YMAX ]
#set xtics offset -$(($NUMPLOTS/2-$NUMPLOTS))
$CUSTOM_GP

#http://stackoverflow.com/questions/15404628/how-can-i-generate-box-and-whisker-plots-with-variable-box-width-in-gnuplot
# http://stackoverflow.com/questions/4805930/making-x-axis-tics-from-column-in-data-file-in-gnuplot
# count 25% min 95% 75% label
plot $PLOT
EOF
#cat $TMPPLOT
    gnuplot "$TMPPLOT"
    rm $MERGED $TMPPLOT
}

# Plotter for bucketXYlog
# Input: Log with "X Y" data
plotXlog() {
    LOG="$1"
    TMPDATA=`mktemp`
    bucketXYlog "$LOG" > $TMPDATA
    OUT=${LOG##*/}
    OUT="${OUT%.*}.png"
    TITLE="set title \"Quartiles for response times with top as 95 percentile, `cat $LOG | wc -l` samples, `date +%Y-%m-%d`\""
    if [ "." == ".$PLOT_PARAM" ]; then
        plotCandle "$TMPDATA" "$OUT" "set yrange [ 5 : $YMAX ]"$'\n'"$TITLE"
    else
        plotCandle "$TMPDATA" "$OUT" "$TITLE"$'\n'"$PLOT_PARAM"
    fi
    rm $TMPDATA
}

# Sample: bucket.sh plotX t1 10 500 "set_yrange_[_10_:_]\nset_logscale_y"
# Input: Log bucket_size [ymax] [custom]
plotX() {
    local LOG="$1"
    local SIZE="$2"
    if [ -n $3 ]; then
        YMAX=$3
    fi
    local CUSTOM=`echo "$4" | sed -e 's/_/ /g' -e 's/\\\n/\n/g'`

    TMPDATA=`mktemp`
    bucketX "$LOG" $SIZE > $TMPDATA
    plotPercentile "$LOG" "$TMPDATA" "$CUSTOM"
    rm $TMPDATA
}

# Input: Log
plotHourCount() {
    LOG="$1"
    TMPDATA=`mktemp`
    bucketHourCount "$LOG" > $TMPDATA
    cat $TMPDATA
    plotCount "$LOG" "$TMPDATA" "set timefmt \"%Y%m%d-%H\""$'\n'"set xdata time"
    rm $TMPDATA
}

# Input: Log
plotMinuteCount() {
    LOG="$1"
    TMPDATA=`mktemp`
    bucketMinuteCount "$LOG" > $TMPDATA
    plotCount "$LOG" "$TMPDATA" "set timefmt \"%Y%m%d-%H%M\""$'\n'"set xdata time"
    rm $TMPDATA
}

# Input: Log
plot10MinuteCount() {
    LOG="$1"
    TMPDATA=`mktemp`
    bucket10MinuteCount "$LOG" > $TMPDATA
    plotCount "$LOG" "$TMPDATA" "set timefmt \"%Y%m%d-%H%M\""$'\n'"set xdata time"
    rm $TMPDATA
}

plotHourSum() {
    LOG="$1"
    TMPDATA=`mktemp`
    bucketRegexp "$LOG" "^[0-9]\{8,8\}-[0-9][0-9]" > $TMPDATA
    plotSum "$LOG" "$TMPDATA" "set timefmt \"%Y%m%d-%H\""$'\n'"set xdata time"
    rm $TMPDATA
}

plotDaySum() {
    LOG="$1"
    TMPDATA=`mktemp`
    bucketRegexp "$LOG" "^[0-9]\{8,8\}" > $TMPDATA
    plotSum "$LOG" "$TMPDATA" "set timefmt \"%Y%m%d\""$'\n'"set xdata time"
    rm $TMPDATA
}

plotRanges() {
    LOG="$1"
    SIZE="$2"
    if [ "." == ".$3" ]; then
        MAX=""
    else
        MAX="set xrange [ 0 : $3 ]"
    fi
    if [ "." == ".$4" ]; then
        YPMAX=""
    else
        YPMAX="set yrange [ 0 : $4 ]"
    fi

    TMPDATA=`mktemp`
    bucketRanges "$LOG" "$SIZE" > $TMPDATA
    plotCount "$LOG" "$TMPDATA" "set xlabel 'bucket size $SIZE"$'\n'"$MAX"$'\n'"$YPMAX"
    rm $TMPDATA
}

if [ ! -n "$1" -o ! -n "$2" ]; then
    cat << EOF
Please provide a method and one or more logs.
Valid methods are
  - bucket24
  - bucketHour
  - bucketMinute
  - bucketHourCount
  - bucketMinuteCount

  - plot24
  - plotDaySum
  - plotHour
  - plotHourSum
  - plotHourCount
  - plotMinute
  - plotMinuteCount
  - plot10MinuteCount

Example: bucket plotHour myfirstlog.log anotherlog.log
EOF
    exit 1
fi
method="$1"
shift

if [ $( echo " bucketX bucketXYlog plotX collectRegexp bucketRanges plotRanges plotCandle plotXYlog plotXYlogs allJoin " | grep -o " $method " ) == "$method" ] ; then
    $method $@
    exit
fi

for L in $@; do
    if [ ! -f "$L" ]; then
        echo "No log at $L"
        exit 1
    fi
    $method $L
#    bucket24 $L
#    bucketHour $L
done
