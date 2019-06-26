#!/bin/bash
PATH="/bin:/usr/bin:/usr/local/bin"


# variables
CONF="${HOME}/.crypto/wallets"
FILE="/tmp/crypto_wallets"
NEWFILE="${FILE}_$(date '+%s%N'))"
if [[ ! -f "${CONF}" ]]; then
  echo -e "\n${CONF} is missing. Not running.\n"
  echo -e "File format:\ncurrency=\"wallet1 wallet2 wallet3\"\n"
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
if tty -s || [[ "${SECS}" -eq "0" ]] || [[ "${SECS}" -eq "30" ]]; then
  # wallet functions

  function BTC_wallet() {
    WALLETS="$(echo "${LINE}" | sed 's/ /|/g')"
    URL="https://blockchain.info/de/multiaddr?active="
    URL_END=""
    BALANCE="final_balance"
    CMC="bitcoin"
  }
  function ETH_wallet() {
    WALLETS="$(echo "${LINE}" | sed 's/ /,/g')"
    URL="https://api.etherscan.io/api?module=account&action=balancemulti&address="
    URL_END="&tag=latest&apikey=YourApiKeyToken"
    BALANCE="balance"
    CALC="/ 1000000000"
    CMC="ethereum"
  }
  function NAV_wallet() {
    WALLETS="$(echo "${LINE}" | sed 's/ /|/g')"
    URL="https://chainz.cryptoid.info/nav/api.dws?key=00f012ed149f&q=multiaddr&n=0&active="
    URL_END=""
    BALANCE="final_balance"
    CALC="/ 100000000"
    CMC="nav-coin"
  }


  # run through all wallets
  for i in $(awk -F'=' '{print $1}' ${CONF} | grep -v "^#"); do
    # get variables
    LINE="$(grep "^${i}=" ${CONF} | awk -F'"' '{print $2}')"
    ${i}_wallet


    # start output
    if tty -s; then
      echo -e "\n${i}:"
    fi

    # get wallet contents
    OUTPUT="0"
    for c in ${WALLETS}; do
      CALL="$(${CURL} ${URL}${c}${URL_END})"

      # get output if call was successful
      if echo "${CALL}" | http_check; then
         VALUE="$(echo "${CALL}" | mjson | grep "\"${BALANCE}\":" | sed_clean | remove_empty | awk '{print $NF}')"

        if [[ ! -z "${VALUE}" ]]; then
          for c in ${VALUE}; do
            OUTPUT+="+($(echo "${c}" | calc))"
          done
        fi
      fi
    done

    # finish output
    if [[ "${OUTPUT}" != "0" ]]; then
      TOTAL="$(echo "(${OUTPUT}) ${CALC}" | calc)"

      # get currency price
      cmc
      WORTH="0"
      if echo "${CALL}" | http_check; then
        CURRENCY_PRICE="$(echo "${CALL}" | grep "\"${CMC_PRICE}\": " | awk '{print $2}' | sed_clean)"
        WORTH="$(echo "${CURRENCY_PRICE} * ${TOTAL}" | calc)"
        if [[ ! -z "${WORTH}" ]]; then
          echo "${WORTH}" >> ${NEWFILE}
          format_output ${WORTH}
          WORTH="${FULL}"
        fi
      fi

      # get and format currency
      format_output ${TOTAL}

      if tty -s; then
        echo "${i} ${FULL}" | output_format
        echo "USD: ${WORTH}"
      fi

    else
      if tty -s; then
        echo "Empty" | output_format
      fi
    fi
  done


  # get total output
  if [[ -s "${NEWFILE}" ]]; then
    # overwrite output file
    mv ${NEWFILE} ${FILE}

    # get total bitcoin amount
    USD_TOTAL="$(cat ${FILE} | tr '\n' '+' | sed 's/+$/\n/' | calc)"

    # get and format usd
    format_output ${USD_TOTAL}

    # output
    echo "${FULL}" > ${FILE}_usd
  fi
fi


# output
if tty -s; then
  echo -e "\n\nWallets:"
  if [[ ! -z "${FULL}" ]]; then
    echo -e "USD ${FULL}" | output_format

  else
    echo "None" | output_format
    echo
  fi

else
  if [[ ! -f "${NOCRYPTO}" ]]; then
    echo -n " | Wallets: "

    if [[ -s "${FILE}_usd" ]]; then
      echo -n "$(cat ${FILE}_usd)"
    else
      echo -n "0"
    fi
  fi
fi


# finish up
if tty -s; then
  echo
fi
exit 0
