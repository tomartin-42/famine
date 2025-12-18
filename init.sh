#/bin/bash

# para imprimir el codigo a inyectar dado un binarillo:
function print_hex_code() {
	[ ! -f "$1" ] && echo "File Not Found" && return 1
	[ ! -x "$1" ] && echo "Wrong permissions at $1" && return 1
	objdump -d "$1" | grep '[0-9a-f]\+:[^$]' | awk -F'\t' '{print $2}' | sed 's/[ ]\+/ /g' | tr -d '\n' | xargs -d' ' -I@ echo -n '\x@'
	echo
}

# Demo de que .text = entrypoint
# readelf -h woody | grep Entry | awk -F':' '{gsub(" ", "", $2); print $2}'
# readelf -S woody | grep .text | awk -F' ' '{print $4}' | sed -E 's/[0]*(.*)/0x\1/g'

