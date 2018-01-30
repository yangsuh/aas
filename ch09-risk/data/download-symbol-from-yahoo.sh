#!/bin/bash

# Client script to pull Yahoo Finance historical data, off of its new cookie
# authenticated site. Start/End Date args can be any GNU readable dates.
# Script requires: GNU date, head, curl and bash shell

symbol=$1
startDate=$2
endDate=$3
outputFile=$4

startEpoch=$(date -d "$startDate" '+%s')
endEpoch=$(date -d "$endDate" '+%s')

cookieJar=$(mktemp)
function cleanup() {
    rm $cookieJar
}
trap cleanup EXIT

function parseCrumb() {
    tr "}" "\n" \
        | grep CrumbStore \
        | cut -d ":" -f 3 \
        | sed 's+"++g'
}

function extractCrumb() {
    crumbUrl="https://finance.yahoo.com/quote/$symbol?p=$symbol"
    curl -s --cookie-jar $cookieJar $crumbUrl \
        | parseCrumb
}

crumb=$(extractCrumb)
if [ "$crumb" == "" ]
then
    echo "skip $symbol because of empty crumb"
else
    echo "download $symbol ..."
    baseUrl="https://query1.finance.yahoo.com/v7/finance/download/"
    args="$symbol?period1=$startEpoch&period2=$endEpoch&interval=1d&events=history"
    crumbArg="&crumb=$crumb"
    sheetUrl="$baseUrl$args$crumbArg"

    tmpFile=$(mktemp)
    function cleanupTempFile() {
        rm $tmpFile
    }
    trap cleanupTempFile EXIT

    curl -s --write-out "HTTPSTATUS:%{http_code}" --cookie $cookieJar --fail "$sheetUrl" > $tmpFile

    # extract the status
    HTTP_STATUS=$(cat $tmpFile | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

    if [ ! $HTTP_STATUS -eq 200  ]; then
        echo "skip $symbol because of http status($HTTP_STATUS) != 200"
    else
        # remove http_status line
        head -n -1 $tmpFile > $outputFile
    fi
fi