#!/bin/bash

result=0
diff -u <(USER=nobody DOMAIN=example.com ./templater.sh examples/vhost-php.tpl.conf) examples/vhost-php.conf > /dev/null
result=$((result+$?))
diff -u <(./templater.sh examples/load-vars-from-file.tmpl --file examples/vars.txt) examples/load-vars-from-file.txt > /dev/null
result=$((result+$?))
diff -u <(./templater.sh examples/load-vars-from-file.tmpl --file examples/vars.txt) examples/load-vars-from-file.txt > /dev/null
result=$((result+$?))
diff -u <(TEST1="TEST 1" TEST2="TEST 2" ./templater.sh examples/dir.tmpl) examples/dir.txt > /dev/null
result=$((result+$?))

if [[ $result -eq 0 ]]; then
    echo OK
else
    echo Differences found
    exit 1
fi
