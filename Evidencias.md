# Churro para ver que todos los elf en bin tienen el 16th byte a 0):
( for ff in /bin/*; do if [ -f "$ff" ] && file ${ff} | grep -q 'ELF 64-bit'; then head -c "16" ${ff} | tail -c 1 | od -An -t x1; fi done; ) | grep -v 00
