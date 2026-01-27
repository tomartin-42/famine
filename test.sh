#!/bin/bash

[[ ! -e ./famine ]] && { echo "Que tal si compilas amigo" && exit 1; }

declare -a test_dirs=( /tmp/test{,2,3} )
trace="tomartin & carce-bo"

for dir in "${test_dirs[@]}"; do
	if [[ ! -d $dir ]]; then
		mkdir -p $dir
	else
		rm -f $dir/*
	fi
done

# Lanzamos 1 vez famine con /tmp/test poblado
cp /usr/bin/cat /usr/bin/ls /tmp/test/

./famine || { echo "Famine no ha retornado 0" && exit 1; }

! strings /tmp/test/ls | grep -q "${trace}"  && { echo "El paciente 0 no infecta" && exit 1; }
! strings /tmp/test/cat | grep -q "${trace}"  && { echo "El paciente 0 no itera correctamente todos los ficheros" && exit 1; }

# Movemos los binarios infectados a test3 para que no se reinfecten. Cuando tengamos
# el flag que indica que un binario ya está infectado y lo gestionemos podremos quitar eso
mv /tmp/test/* /tmp/test3/

cp /usr/bin/cat /usr/bin/ls /tmp/test2/

# Ejecutamos el ls infectado (dejo la traza para que se vea que salta el ls)
/tmp/test3/ls || { echo "El binario infectado no ha retornado 0" && exit 1; }

! strings /tmp/test2/ls | grep -q "${trace}"  && { echo "El binario infectado no infecta" && exit 1; }
! strings /tmp/test2/cat | grep -q "${trace}"  && { echo "El binario infectado no itera correctamente todos los ficheros" && exit 1; }

