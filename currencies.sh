#!/bin/bash
PATH="/bin:/usr/bin:/usr/local/bin"


# variables
CONF="${HOME}/.crypto/currencies"
FILE="/tmp/crypto_currencies"
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
  # get currencies without default currencies
  CRC="$(grep -vE "^\#|^[ \t]*$" ${CONF} | sed 's/  */ /g' | tr ' ' '\n' | sort -u)"
  for i in ${DEFAULT_CRC}; do
    CRC="$(echo "${CRC}" | grep -v "^${i}$")"
  done

  # add default currencies
  CURRENCIES="${DEFAULT_CRC} ${CRC}"

  # run through all currencies
  for i in ${CURRENCIES}; do
    # reset variables
    VALUE=""

    # get value from cmc
    CMC="${i}"
    cmc
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
      fi
      OUTPUT+=" | ${SYMBOL}: ${WORTH}"

    else
      if tty -s; then
        echo -e "\n${i}: unknown"
      fi
      OUTPUT+=" | ${i}: unknown"
    fi
  done


  # get usd to chf exchange rate
  CALL="$(${CURL} ${RATE_URL})"
  if echo "${CALL}" | http_check; then
    USD_RATE="$(echo "${CALL}" | mjson | grep "\"CHF\": " | awk '{print $2}' | sed_clean)"

    if [[ ! -z "${USD_RATE}" ]]; then
      format_output ${USD_RATE}
      USD="${FULL}"
      echo "${USD}" > ${FILE}_usd

    else
      USD="0"
    fi

    if tty -s; then
      echo -e "\nUSD: ${USD}"
    fi
    OUTPUT+=" | USD: ${USD}"
  fi


  # prepare file
  if [[ ! -z "${OUTPUT}" ]]; then
    echo "${OUTPUT}" > ${FILE}
  fi
fi


# output
if ! tty -s; then
  if [[ ! -f "${NOCRYPTO}" ]]; then
    cat ${FILE}
  fi
fi


# finish up
if tty -s; then
  echo
fi
exit 0
