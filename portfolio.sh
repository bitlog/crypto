#!/bin/bash
PATH="/usr/local/bin:/usr/bin:/bin"


# variables
EXCH_FILE="/tmp/exchanges_usd"
WALL_FILE="/tmp/wallets_usd"


# source global functions
. /opt/crypto_functions


# get exchanges total
EXCHANGES="0"
if [[ -s "${EXCH_FILE}" ]]; then
  EXCHANGES="$(cat ${EXCH_FILE})"
fi


# get wallets total
WALLETS="0"
if [[ -s "${WALL_FILE}" ]]; then
  WALLETS="$(cat ${WALL_FILE})"
fi


# calculate total
if [[ "${EXCHANGES}" != "0" ]] || [[ "${WALLETS}" != "0" ]]; then
  TOTAL="$(echo "${EXCHANGES} + ${WALLETS}" | calc)"
  format_output ${TOTAL}

else
  FULL="0"
fi


# finish up
if tty -s; then
  echo -e "\nPortfolio:"
  echo "USD ${FULL}" | output_format
  echo

else
  echo -n " | Portfolio: ${FULL}\$"
fi
exit 0
