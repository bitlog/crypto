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
CONF="${CONFDIR}/exchanges"
FILE="${WORKDIR}/crypto_exchanges"
NEWFILE="${FILE}_$(date '+%s%N'))"
if [[ ! -f "${CONF}" ]]; then
  echo -e "\n${CONF} is missing. Not running.\n"
  echo -e "File format:\nexchange_name=\"api_key secret_key\"\n"
  exit 1
fi


# get seconds
SECS="$(date '+%S' | sed 's/^0//')"

# run only in terminal, cron or at specific times
if tty -s || [[ "${CRON}" != "0" ]] || [[ "${SECS}" -eq "15" ]] || [[ "${SECS}" -eq "45" ]]; then
  # exchange functions

  function exchange_currency() {
    if echo "${CALL}" | http_check; then
      COIN="$(echo "${CALL}" | mjson)"
      VALUE="$(echo "${COIN}" | grep "\"${JSON_VALUE}\": " | awk '{print $2}' | sed_clean)"
      WORTH="$(echo "${AMT} * ${VALUE}" | calc)"
    fi
  }


  function Binance_prep() {
    NONCE="timestamp=$(date +%s%N | cut -c1-13)"

    BASE_URL="https://api.binance.com/api/v3"
    CALL_URL="/account"
    SECRET="signature=$(echo -n "${NONCE}" | sha256_hmac "${SECRET_KEY}")"

    CALL="$(${CURL} "${BASE_URL}${CALL_URL}?${NONCE}&${SECRET}" -H "X-MBX-APIKEY: ${API_KEY}")"
  }
  function Binance_amounts() {
    AMOUNTS="$(echo "${OUTPUT}" | grep -E "\"asset\": |\"free\": " | amount_format | amount_rev)"
  }
  function Binance_calc() {
    CALL="$(${CURL} "${BASE_URL}/ticker/price?symbol=${1}BTC")"
    JSON_VALUE="price"
  }


  function BitMEX_prep() {
    METHOD="GET"
    NONCE="$(date -d '+5 seconds' '+%s')"

    BASE_URL="https://www.bitmex.com"
    CALL_URL="/api/v1/user/wallet"
    SECRET="$(echo -n "${METHOD}${CALL_URL}${NONCE}" | sha256_hmac "${SECRET_KEY}")"

    CALL="$(${CURL} "${BASE_URL}${CALL_URL}" -X ${METHOD} -H "api-expires: ${NONCE}" -H "api-key: ${API_KEY}" -H "api-signature: ${SECRET}")"
  }
  function BitMEX_amounts() {
    AMOUNTS="$(echo "${OUTPUT}" | grep -E "\"currency\": |\"amount\": " | amount_format)"
  }


  function Bittrex_prep() {
    NONCE="$(date '+%s%N' | cut -b1-13)"

    BASE_URL="https://bittrex.com"
    CALL_URL="${BASE_URL}/api/v1.1/account/getbalances?apikey=${API_KEY}&nonce=${NONCE}"
    SECRET="$(echo -n "${CALL_URL}" | sha512_hmac "${SECRET_KEY}")"

    CALL="$(${CURL} "${CALL_URL}" -H "apisign: ${SECRET}")"
  }
  function Bittrex_amounts() {
    AMOUNTS="$(echo "${OUTPUT}" | grep -E "\"Currency\": |\"Balance\": " | amount_format)"
  }
  function Bittrex_calc() {
    CALL="$(${CURL} "${BASE_URL}/api/v1.1/public/getticker?market=BTC-${1}")"
    JSON_VALUE="Bid"
  }


  # run through all exchanges
  for i in $(awk -F'=' '{print $1}' ${CONF} | grep -v "^#"); do
    # get variables
    LINE="$(grep "^${i}=" ${CONF} | awk -F'"' '{print $2}')"

    # prep line variables
    API_KEY="$(echo "${LINE}" | awk '{print $1}')"
    SECRET_KEY="$(echo "${LINE}" | awk '{print $2}')"

    # get account values
    ${i}_prep

    # get output if call was successful
    if echo "${CALL}" | http_check; then
      OUTPUT="$(echo "${CALL}" | mjson)"

      if [[ ! -z "${OUTPUT}" ]]; then
        # get total amount of cryptocurrencies in account
        ${i}_amounts

        # output amounts
        if tty -s; then
          echo -e "\n${i}:"

          # check if amount is not empty
          if [[ -z "${AMOUNTS}" ]]; then
            echo "Empty" | output_format
          fi
        fi


        # calculate total of amounts
        for c in $(echo "${AMOUNTS}" | awk '{print $1}'); do
          AMT="$(echo "${AMOUNTS}" | grep "^${c} " | awk '{print $2}')"
          WORTH=""

          # get btc directly
          if [[ "${c}" == "BTC" ]]; then
            echo "${AMT}" >> ${NEWFILE}

          # get usdt directly
          elif [[ "${c}" == "USD" ]] || [[ "${c}" == "USDT" ]]; then
            echo "${AMT}" >> ${NEWFILE}_usdt

          # convert sat into btc
          elif [[ "${c}" == "XBt" ]]; then
            WORTH="$(echo "${AMT} / 100000000" | calc)"

          # get bittrex credits
          elif [[ "${c}" == "BTXCRD" ]]; then
            WORTH="0"

          # calculate all others
          else
            ${i}_calc ${c}
            exchange_currency
          fi

          # output into file for total calucalations
          if [[ ! -z "${WORTH}" ]]; then
            echo "${WORTH}" >> ${NEWFILE}
            format_output ${WORTH}
            WORTH="${FULL}"
          fi

          if [[ ! -z "${AMT}" ]]; then
            # output
            format_output ${AMT}
            OUTPUT="${FULL}"
            if [[ ! -z "${WORTH}" ]]; then
              OUTPUT+=" (BTC ${WORTH})"
            fi

            # output if in terminal
            if tty -s; then
              echo "${c} ${OUTPUT}" | output_format
            fi
          fi
        done
      fi
    fi
  done


  # get total output
  if [[ -s "${NEWFILE}" ]]; then
    # overwrite usdt output file
    if [[ -f "${NEWFILE}_usdt" ]]; then
      mv ${NEWFILE}_usdt ${FILE}_usdt
      USDT_TOTAL="$(cat ${FILE}_usdt | newline_calc | calc)"
    else
      rm -rf ${FILE}_usdt
    fi

    # overwrite output file
    mv ${NEWFILE} ${FILE}

    # get total bitcoin amount
    BTC_TOTAL="$(cat ${FILE} | newline_calc | calc)"

    # get and format btc
    format_output ${BTC_TOTAL}
    echo "${FULL}" > ${FILE}_btc
    BTC="${FULL}"


    # get bitcoin price
    if [[ ! -z "${BTC_TOTAL}" ]]; then
      CALL="$(${CURL} "${CMC_URL}/bitcoin/")"
      if echo "${CALL}" | http_check; then
        BTC_PRICE="$(echo "${CALL}" | grep "\"${CMC_PRICE}\": " | awk '{print $2}' | sed_clean)"

        if [[ ! -z "${BTC_PRICE}" ]]; then
          # calculate total usd
          CALCLINE="(${BTC_PRICE} * ${BTC_TOTAL})"
          if [[ ! -z "${USDT_TOTAL}" ]]; then
            CALCLINE+=" + ${USDT_TOTAL}"
          fi
          USD_TOTAL="$(echo "${CALCLINE}" | calc)"

          # get and format btc
          format_output ${USD_TOTAL}
          BTC_PRICE="${FULL}"

          # get and format usd
          format_output ${USD_TOTAL}
          echo "${FULL}" > ${FILE}_usd
        fi
      fi
    fi
  fi
fi


# output
if tty -s; then
  echo -e "\n\nExchanges:"
  if [[ ! -z "${BTC}" ]]; then
    echo -e "BTC ${BTC}" | output_format
    if [[ ! -z "${FULL}" ]]; then
      echo -e "USD ${FULL}" | output_format
    fi

  else
    echo "None" | output_format
    echo
  fi

elif [[ "${CRON}" == "0" ]]; then
  if [[ ! -f "${NOCRYPTO}" ]]; then
    echo -n " | Exchanges: "

    if [[ -s "${FILE}_usd" ]]; then
      echo -n "$(cat ${FILE}_usd)"
      if [[ -s "${FILE}_btc" ]]; then
        echo -n " ($(cat ${FILE}_btc)B)"
      fi
    else
      echo -n "0"
    fi
  fi

else
  cron_run_portfolio
fi


# finish up
if tty -s; then
  echo
fi
exit 0
