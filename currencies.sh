#!/bin/bash
PATH="/bin:/usr/bin:/usr/local/bin"


# variables
CONF="${HOME}/.crypto/currencies"
FILE="/tmp/crypto_currencies"
NEWFILE="${FILE}_$(date '+%s%N'))"
if [[ ! -f "${CONF}" ]]; then
  echo -e "\n${CONF} is missing. Not running.\n"
  echo -e "File format:\ncurrency1 currency2 currency3\ncurrency4\n"
  exit 1
fi


# source global functions
if [[ -f "$(dirname ${0})/crypto_functions" ]]; then
  . $(dirname ${0})/crypto_functions

elif [[ -f "/opt/crypto_functions" ]]; then
  . /opt/crypto_functions

else
  echo -e "\nError: crypto_functions can't be sourced.\n"
  exit 1
fi


# get seconds
SECS="$(date '+%S' | sed 's/^0//')"

# run only in terminal or at specific times
if tty -s || [[ "${SECS}" -eq "15" ]] || [[ "${SECS}" -eq "45" ]]; then
  # wallet functions

  function cmc() {
    CMC_URL="https://api.coinmarketcap.com/v1/ticker"

    CALL="$(${CURL} ${CMC_URL}/${CMC}/)"
  }

  # run through all wallets
  for i in $(grep -vE "^\#|^[ \t]*$" ${CONF} | sed 's/  */ /g' | tr ' ' '\n' | sort -u); do
    # reset variables
    VALUE=""

    # get value from cmc
    CALL="$(${CURL} "${CMC_URL}/${i}/")"
    if echo "${CALL}" | http_check; then
      SYMBOL="$(echo "${CALL}" | grep "\"${CMC_SYMBOL}\": " | awk '{print $2}' | sed_clean)"
      VALUE="$(echo "${CALL}" | grep "\"${CMC_PRICE}\": " | awk '{print $2}' | sed_clean)"
    fi

    # format value
    if [[ ! -z "${VALUE}" ]]; then
      format_output ${VALUE}
      WORTH="${FULL}"

    else
      WORTH="0"
    fi

    if [[ ! -z "${VALUE}" ]]; then
      if tty -s; then
        echo -e "\n${SYMBOL}: ${WORTH}"

      else
        echo -n " | ${SYMBOL}: ${WORTH}"
      fi

    else
      if tty -s; then
        echo -e "\n${i}: unknown"

      else
        echo -n " | ${i}: unknown"
      fi
    fi
  done
fi


# finish up
if tty -s; then
  echo
fi
exit 0
