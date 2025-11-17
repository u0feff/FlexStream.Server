#!/bin/sh
#
# usage: certlink.sh filename [filename ...]

for CERTFILE in "$@"; do
  # Убедиться, что файл существует и это сертификат
  test -f "$CERTFILE" || continue
  HASH=$(openssl x509 -noout -hash -in "$CERTFILE")
  test -n "$HASH" || continue

  # использовать для ссылки наименьший итератор
  for ITER in 0 1 2 3 4 5 6 7 8 9; do
    test -f "${HASH}.${ITER}" && continue
    ln -s "$CERTFILE" "${HASH}.${ITER}"
    test -L "${HASH}.${ITER}" && break
  done
done
