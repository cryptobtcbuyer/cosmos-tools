#!/bin/bash

curl -s https://raw.githubusercontent.com/Staketab/node-tools/main/logo.sh | bash

RED="\033[31m"
YELLOW="\033[33m"
GREEN="\033[32m"
NORMAL="\033[0m"
RPC=${1}
BINARY=${2}
CONFIG_FOLDER=${3}
SERVICE_NAME=${4}
BLOCKS=${5}
SERVERIP="$(curl ifconfig.me)"

line() {
  echo "-------------------------------------------------------------------"
}
stopService() {
  line
  echo -e "$YELLOW Stopping service...$NORMAL"
  sudo systemctl stop ${SERVICE_NAME}
}
backupQuestion() {
  line
  echo -e "$GREEN BACKUP OPTION.$NORMAL"
  line
  echo -e "$RED 1$NORMAL -$YELLOW If you want to create backup and delete DATA folder.$NORMAL"
  echo -e "$RED 2$NORMAL -$YELLOW If you don't want to do backup (! This point deletes the DATA folder anyway ).$NORMAL"
  line
  read -p "Your answer: " ANSWERS
  if [ "$ANSWERS" == "1" ]; then
    backup
  elif [ "$ANSWERS" == "2" ]; then
    echo -e "$YELLOW The BACKUP setting is skipped. Сontinue...$NORMAL"
    stopService
    remove
  else
    echo -e "$YELLOW The BACKUP setting is skipped. Сontinue...$NORMAL"
    echo -e "$RED Process stopped...$NORMAL"
    exit 1
  fi
}
remove() {
  cp -r $HOME/${CONFIG_FOLDER}/data/priv_validator_state.json $HOME/${CONFIG_FOLDER}/priv_validator_state.json
  if [ -e $HOME/${CONFIG_FOLDER}/priv_validator_state.json ]; then
    echo -e "$YELLOW Resetting chain data...$NORMAL"
    ${BINARY} tendermint unsafe-reset-all --home $HOME/${CONFIG_FOLDER} --keep-addr-book
  else
    echo -e "$RED Process stopped...$NORMAL"
    exit 1
  fi
}
backup() {
  stopService
  mkdir -p $HOME/${CONFIG_FOLDER}/data_before_statesync
  echo -e "$YELLOW Creating backup...$NORMAL"
  cp -r $HOME/${CONFIG_FOLDER}/data $HOME/${CONFIG_FOLDER}/data_before_statesync
  remove
}
copyJson() {
  mv $HOME/${CONFIG_FOLDER}/priv_validator_state.json $HOME/${CONFIG_FOLDER}/data/priv_validator_state.json
}
statesync() {
  line
  LATEST_HEIGHT=$(curl -s ${RPC}/block | jq -r .result.block.header.height)
  TRUST_HEIGHT=$((LATEST_HEIGHT - ${BLOCKS}))
  TRUST_HASH=$(curl -s "${RPC}/block?height=$TRUST_HEIGHT" | jq -r .result.block_id.hash)
  echo -e "$YELLOW RPC SERVERS:$NORMAL$RED ${RPC},${RPC}$NORMAL"
  echo -e "$YELLOW TRUST_HEIGHT:$NORMAL$RED ${TRUST_HEIGHT}$NORMAL"
  echo -e "$YELLOW TRUST_HASH:$NORMAL$RED ${TRUST_HASH}$NORMAL"
  line
  sleep 3

  sed -i.bak -E 's#^(rpc_servers[[:space:]]+=[[:space:]]+).*$#\1"'$RPC','$RPC'"#' $HOME/${CONFIG_FOLDER}/config/config.toml
  sed -i.bak -E 's#^(trust_height[[:space:]]+=[[:space:]]+).*$#\1"'$TRUST_HEIGHT'"#' $HOME/${CONFIG_FOLDER}/config/config.toml
  sed -i.bak -E 's#^(trust_hash[[:space:]]+=[[:space:]]+).*$#\1"'$TRUST_HASH'"#' $HOME/${CONFIG_FOLDER}/config/config.toml
  #sed -i.bak -E 's#^(trust_period[[:space:]]+=[[:space:]]+).*$#\1"'$TRUST_PERIOD'"#' $HOME/.${CONFIG_FOLDER}/config/config.toml

  # STATESYNC enabled
  sed -i.bak -E 's#^(enable[[:space:]]+=[[:space:]]+).*$#\1'true'#' $HOME/${CONFIG_FOLDER}/config/config.toml
}

start() {
  backupQuestion
  statesync
  copyJson
  echo -e "$YELLOW Restarting...$NORMAL"
  sudo systemctl restart ${SERVICE_NAME}
  echo -e "$YELLOW Checking logs...$NORMAL"
  sleep 3
  sudo journalctl -u ${SERVICE_NAME} -f --line 1000 | grep 'module=statesync'
}

start
