#!/bin/sh

stop() {
    echo " Stopping."
    rm -rf $TMP_DIR
    exit 0
}
trap stop SIGINT

# creates the spark bar graphs
# $1 = file in $TMP_DIR/
# $2 = value (hashrate in Mhash/s or shares)
graph() {
    echo $2 >> $TMP_DIR/$1 # append latest API response to file
    if [[ `cat $TMP_DIR/$1 | wc -l | awk '{print $1}'` -gt `expr $WIDTH-$LABELS-1` ]]; then
        mv $TMP_DIR/$1 $TMP_DIR/$1-old
        touch $TMP_DIR/$1
        sed '1d' $TMP_DIR/$1-old >> $TMP_DIR/$1 # ??
        rm $TMP_DIR/$1-old
    fi
    DATA=`cat $TMP_DIR/$1 | tr '\n' ' '`
    echo $DATA | spark
    printf "$2" # no new line (print units after function call)
}

main() {
    clear

    JSON=`curl --silent https://mining.bitcoin.cz/accounts/profile/json/$API_KEY`

    mkdir $TMP_DIR
    cat $CONFIG_FILE | while read -r LINE || [ -n "$LINE" ]; do
        if [[ "$LINE" != "" && "$LINE" != "$API_KEY" \
            && "$LINE" != "newline" ]]; then

            # touch worker data files
            if [[ "$LINE" == "last_share" || "$LINE" == "score" \
                || "$LINE" == "alive" || "$LINE" == "worker_hashrate" \
                || "$LINE" == "worker_shares" ]]; then
                DATA=`echo $JSON | jq -r '.workers' | jq -r .[].$LINE`
                i=0
                
                for ENTRY in $DATA; do
                    WORKER=`echo $JSON | jq -r '.workers | keys['$i']'`
                    touch "$TMP_DIR/$WORKER-$LINE"
                    i=`expr $i + 1`
                done
            # touch non-worker data files
            else
                touch $TMP_DIR/$LINE
            fi

        fi
    done

    while [[ 1 ]]; do
        JSON=`curl --silent https://mining.bitcoin.cz/accounts/profile/json/$API_KEY`

        printf "###########\n#  SPool  #   [^C] to stop.\n###########\n"

        cat $CONFIG_FILE | while read -r LINE || [ -n "$LINE" ]; do
            case $LINE in
                # general info
                "hashrate"*) # total hashrate
                    printf "hashrate: "
                    HASHRATE=`echo $JSON | jq -r .$LINE`
                    graph "hashrate" $HASHRATE
                    printf " Mhash/s\n"
                ;;
                "username"|"rating"|"confirmed_nmc_reward"|"send_threshold"| \
                "nmc_send_threshold"|"confirmed_reward"|"wallet"| \
                "unconfirmed_nmc_reward"|"unconfirmed_reward"| \
                "estimated_reward"*) # general key/value
                    DATA=`echo $JSON | jq -r .$LINE`
                    printf "$LINE: $DATA\n"
                ;;

                # worker info
                "last_share"|"score"|"alive"*)
                    INFO=`echo $JSON | jq -r '.workers' | jq -r .[].$LINE`
                    printf "$LINE\n"

                    i=0
                    for ENTRY in $INFO; do
                        WORKER=`echo $JSON | jq -r '.workers | keys['$i']'`
                        printf "$WORKER: $ENTRY\n"
                        i=`expr $i + 1`
                    done
                ;;
                "worker_hashrate"|"worker_shares"*)
                    NAME=`echo $LINE | cut -d'_' -f 2`
                    DATA=`echo $JSON | jq -r '.workers' | jq -r .[].$NAME`

                    printf "$LINE\n"

                    i=0
                    for ENTRY in $DATA; do
                        WORKER=`echo $JSON | jq -r '.workers | keys['$i']'`
                        printf "$WORKER\n"
                        i=`expr $i + 1`

                        if [[ "$LINE" = "worker_hashrate" ]]; then
                            printf "hashrate: "
                            graph "$WORKER-worker_hashrate" $ENTRY
                            printf " Mhash/s\n"
                        else
                            printf "shares:   "
                            graph "$WORKER-worker_shares" $ENTRY
                            printf " shares\n"
                        fi
                    done
                ;;
                $API_KEY*)
                ;;
                "newline"*)
                    printf "\n";
                ;;
                *)
                    printf "\033[31mUnknown option: $LINE.\033[0m"
                ;;
            esac
        done
        sleep $SLEEP_TIME
        clear
    done
}

CONFIG_FILE="config"
TMP_DIR="tmp"
API_KEY=`head -n 1 $CONFIG_FILE`
SLEEP_TIME=5m

WIDTH=`tput cols`
LABELS=10

main