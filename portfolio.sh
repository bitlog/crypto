#!/bin/bash
PATH="/bin:/usr/bin:/usr/local/bin"


# source global functions
if [[ -f "$(dirname ${0})/crypto_functions" ]]; then
  . $(dirname ${0})/crypto_functions

elif [[ -f "/opt/crypto_functions" ]]; then
  . /opt/crypto_functions

else
  echo -e "\nError: crypto_functions can't be sourced.\n"
  exit 1
fi


# variables
FILE="${WORKDIR}/crypto_"
EXCH_FILE="${FILE}exchanges_usd"
WALL_FILE="${FILE}wallets_usd"
FILE+="portfolio"


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
  echo "${FULL}" > ${FILE}

else
  FULL="0"
fi


# finish up
if tty -s; then
  echo -e "\nPortfolio:"
  echo "USD ${FULL}" | output_format
  echo

elif [[ "${CRON}" == "0" ]]; then
  if [[ ! -f "${NOCRYPTO}" ]]; then
    echo -n " | Portfolio: ${FULL}"
  fi
fi
exit 0
