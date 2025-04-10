s/\\/\\\\/g
s/"/\\"/g
s/^\(.*\)$/\t"\1\\n"/g
1s/^/#define STRINGIFIED_SCRIPT/
$!s/$/ \\/
