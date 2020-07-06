#!/usr/bin/env bash

url=$1

if [ -z "$url" ];
    then
        echo "Usage : sh health_check <some_url>"
        exit 1
fi

echo "GET:${url}"

HTTP_RESPONSE=$(curl --silent --stderr - --write-out "HTTPSTATUS:%{http_code}" $url)

# extract the body
HTTP_BODY=$(sed -e 's/HTTPSTATUS\:.*//g' <<< $HTTP_RESPONSE)

# extract the status
HTTP_STATUS=$(tr -d '\n' | sed -e 's/.*HTTPSTATUS://' <<< $HTTP_RESPONSE)

# print the body
# json prettier lib   | replace status code lines with RED ANSI color (e\[31m str e\[0m   | replace 2xx status code with GREEN ANSI color
jq . <<< ${HTTP_BODY} | sed -r 's/(\"status\"\: )(\-?[0-9]+)(\,)/\1\\e\[31m\2\\e\[0m\3/g' | sed -r 's/(\\e\[31m)(2[0-9][0-9])(\\e\[0m\,)/\\e\[32m\2\3/g' | xargs -0 echo -e
echo ""
echo "status code was: $HTTP_STATUS"

if test $HTTP_STATUS -ne 200; then
    exit 1
fi

