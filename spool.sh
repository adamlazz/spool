#!/bin/bash

stop() {
    echo " Stopping."
    rm -rf "$TMP_DIR" # remove data file directory
    exit 0
}
trap stop SIGINT

# creates the spark bar graphs
# $1 = file in $TMP_DIR/
# $2 = value (hashrate in Mhash/s or shares)
graph() {
    echo "$2" >> "$TMP_DIR/$1" # append latest API response to file

    # if label and sparkline are wider than the terminal width
    if [[ `cat "$TMP_DIR/$1" | wc -l | awk '{print $1}'` -gt $(($WIDTH-$LABELS-1)) ]]; then
        mv "$TMP_DIR/$1" "$TMP_DIR/$1-old"
        touch "$TMP_DIR/$1"
        sed '1d' "$TMP_DIR/$1-old" >> "$TMP_DIR/$1" # remove top line
        rm "$TMP_DIR/$1-old"
    fi
    data=`cat "$TMP_DIR/$1" | tr '\n' ' '`
    echo "$data" | spark
    printf "$2" # no new line (print units after function call)
}
just_graph() {
    data=`cat "$TMP_DIR/$1" | tr '\n' ' '`
    echo "$data" | spark
    printf "$2" # no new line (print units after function call)
}

main() {
    json=`curl --silent https://mining.bitcoin.cz/accounts/profile/json/$API_KEY`

    hashrate_time_elapsed=$HASHRATE_REFRESH_TIME

    mkdir "$TMP_DIR" # create data file directory

    # create data files
    cat "$CONFIG_FILE" | while read -r line || [ -n "$line" ]; do
        if [[ "$line" != "" && "$line" != "$API_KEY" \
            && "$line" != "newline" ]]; then

            # touch worker data files
            if [[ "$line" == "last_share" || "$line" == "score" \
                || "$line" == "alive" || "$line" == "worker_hashrate" \
                || "$line" == "worker_shares" ]]; then

                # determine how many workers exist
                data=`echo $json | jq -r '.workers' | jq -r .[].$line`

                # create a file for each worker
                i=0
                for entry in $data; do
                    worker=`echo $json | jq -r '.workers | keys['$i']'`
                    touch "$TMP_DIR/$worker-$line"
                    (( i++ ))
                done

            # touch non-worker data files
            else
                touch $TMP_DIR/$line
            fi
        fi
    done

    while [ 1 ]; do
        json=`curl --silent https://mining.bitcoin.cz/accounts/profile/json/$API_KEY`
        clear

        printf "###########\n#  SPool  #   [Ctrl+C] to stop.\n###########\n"

        if [ $hashrate_time_elapsed -ge $HASHRATE_REFRESH_TIME ]; then
            refresh_hashrate=1
            hashrate_time_elapsed=0
        fi

        # read config file
        cat $CONFIG_FILE | while read -r line || [ -n "$line" ]; do
            case $line in
                # non-worker info
                "hashrate"*) # total hashrate
                    printf "hashrate: "
                    if [ $refresh_hashrate -eq 1 ]; then
                        HASHRATE=`echo $json | jq -r .$line`
                        graph "hashrate" $HASHRATE
                    else
                        HASHRATE=`echo $json | jq -r .$line`
                        just_graph "hashrate" $HASHRATE
                    fi
                    printf " Mhash/s\n"
                ;;
                "username"|"rating"|"confirmed_nmc_reward"|"send_threshold"| \
                "nmc_send_threshold"|"confirmed_reward"|"wallet"| \
                "unconfirmed_nmc_reward"|"unconfirmed_reward"| \
                "estimated_reward"*) # general key/value
                    data=`echo $json | jq -r .$line`
                    printf "$line: $data\n"
                ;;

                # worker info
                "last_share"|"score"|"alive"*) # general key/value
                    info=`echo $json | jq -r '.workers' | jq -r .[].$line`
                    printf "$line\n"

                    i=0
                    for entry in $info; do
                        worker=`echo $json | jq -r '.workers | keys['$i']'`
                        printf "$worker: $entry\n"
                        (( i++ ))
                    done
                ;;
                "worker_hashrate"|"worker_shares"*)
                    name=`echo $line | cut -d'_' -f 2`
                    data=`echo $json | jq -r '.workers' | jq -r .[].$name`

                    printf "$line\n"

                    i=0
                    for entry in $data; do
                        worker=`echo $json | jq -r '.workers | keys['$i']'`
                        printf "$worker\n"
                        (( i++ ))
                        if [ "$line" == "worker_hashrate" ]; then
                            printf "hashrate: "
                            if [ $refresh_hashrate -eq 1 ]; then
                                graph "$worker-worker_hashrate" $entry
                            else
                                just_graph "$worker-worker_hashrate" $entry
                            fi
                            printf " Mhash/s\n"
                        else
                            printf "shares:   "
                            graph "$worker-worker_shares" $entry
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
                    printf "\033[31mUnknown option: $line.\033[0m"
                ;;
            esac
        done
        sleep $SLEEP_TIME

        if [ $refresh_hashrate -eq 1 ]; then
            refresh_hashrate=0
        fi

        hashrate_time_elapsed=$(( $hashrate_time_elapsed + $SLEEP_TIME ))
    done
}

CONFIG_FILE="config"
TMP_DIR="tmp" # data file directory
API_KEY=`head -n 1 $CONFIG_FILE`
HASHRATE_REFRESH_TIME=3600 # hashrate API refresh time (1hr)
SLEEP_TIME=300 # API refresh time (5min)

WIDTH=`tput cols`
LABELS=10 # spaces before sparklines begin

if [ -e $CONFIG_FILE ]; then
    main
else
    echo "\033[31m$CONFIG_FILE does not exist.\033[0m"
fi

exit 0
