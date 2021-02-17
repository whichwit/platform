echo $(tr -dc A-Za-z0-9 </dev/urandom | head -c 13 ; echo '') >> VOID
git add .
git commit -m "$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13 ; echo '')" && git push
