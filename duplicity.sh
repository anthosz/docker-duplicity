#!/bin/bash
## VARIABLES ##
REDCOLOR="\\033[1;31m"
WHITECOLOR="\\033[0;02m"
BLUECOLOR='\e[0;36m'
GREENCOLOR="\e[0;32m"
YELLOWCOLOR="\\033[1;33m"
ORANGECOLOR='\e[0;33m'
OBJECT_NUMBER=0

if [[ -f ./env ]]; then source ./env; else exit 1; fi
COMMON_DUPLICITY_PARAMETERS="--no-compression --asynchronous-upload --allow-source-mismatch"
if [ ! -z "${PROJECT_NAME}" ]; then COMMON_DUPLICITY_PARAMETERS="${COMMON_DUPLICITY_PARAMETERS} --name=${PROJECT_NAME}"; fi
if [[ -d "${METADATA_DIRECTORY}" ]]; then COMMON_DUPLICITY_PARAMETERS="${COMMON_DUPLICITY_PARAMETERS} --archive-dir=${METADATA_DIRECTORY}"; fi
if [ ! -z "${INCLUDE_FILELIST}" ]; then
  if [[ -f ${INCLUDE_FILELIST} ]]; then
    echo -e "${GREENCOLOR}Usage of ${INCLUDE_FILELIST} enabled...${WHITECOLOR}"
    COMMON_DUPLICITY_PARAMETERS="${COMMON_DUPLICITY_PARAMETERS} --include-filelist=${INCLUDE_FILELIST}"
  else
    echo -e "${REDCOLOR}${INCLUDE_FILELIST} doesn't exist... Exiting...${WHITECOLOR}"; exit 1
  fi
fi

## FUNCTIONS ##
function trust_key {
  echo -e "trust\n5\ny\nquit" | gpg --no-tty --command-fd 0 --edit-key ${1}
  if [[ $? -eq 0 ]]; then echo -e "${GREENCOLOR}${1} trusted!${WHITECOLOR}" ; else echo -e "${REDCOLOR}Unable to trust ${1}${WHITECOLOR}"; exit 1; fi
}
function import_private_key {
  echo -ne "${YELLOWCOLOR}Importing secret key in progress... ${WHITECOLOR}"
  echo -e "${1}" | gpg --batch --import
  check_rc $?
  echo -ne "${YELLOWCOLOR}Getting private id in progress... ${WHITECOLOR}"
  PRIV_ID=(`echo -e "${1}" | gpg --batch --import 2>&1 | egrep -o "[A-F0-9]{8,16}"`)
  check_rc $?
  echo -ne "${YELLOWCOLOR}Trusting private id in progress... ${WHITECOLOR}"
  trust_key "${PRIV_ID}"
  check_rc $?
  echo "export ENCRYPT_DUPLICITY_PARAMETERS=\"--encrypt-sign-key=${PRIV_ID} ${ENCRYPT_KEYS}\"" >> ./env.dup
  echo "export PASSPHRASE=\"${2}\"" >> ./env.dup
  source ./env.dup
}
function check_rc {
  if [[ $? -ne 0 ]]; then echo -e "${REDCOLOR}FAIL... Exiting...${WHITECOLOR}"; exit 1; else echo -e "${GREENCOLOR}OK${WHITECOLOR}" ; fi 
}

## MAIN ##
if [[ ! -z ${PRIVATE_KEY_SOURCE} ]]
then
  if [[ -f ./env.dup ]]
  then
    source ./env.dup
  else
    case "${PRIVATE_KEY_SOURCE}" in
    'ASM')
      echo -ne "${YELLOWCOLOR}${PRIVATE_KEY_SOURCE} Getting secret id in progress... ${WHITECOLOR}"
      SECRET_ID=`curl -s http://172.17.0.1:51678/v1/metadata | sed -r "s@^\{\"Cluster\":\"@@" | egrep -o "^[^\"]+"`
      check_rc $?
      echo -ne "${YELLOWCOLOR}${PRIVATE_KEY_SOURCE} Getting secret value in progress... ${WHITECOLOR}"
      SECRET=`aws secretsmanager get-secret-value --secret-id ${SECRET_ID} | egrep -o -- "-----BEGIN PGP[^\"]+" | sed -r -e 's/\\$//' -e "s@\\\n@\n@g"`
      check_rc $?
      echo -ne "${YELLOWCOLOR}${PRIVATE_KEY_SOURCE} Getting passphrase in progress... ${WHITECOLOR}"
      export PASSPHRASE=$(aws secretsmanager get-secret-value --secret-id "${SECRET_ID}" | egrep -o "\\\"PASHPHRASE\\\\\": \\\\\"[^\\]+" | sed -r "s/.*\"//")
      check_rc $?
      import_private_key "${SECRET}" "${PASSPHRASE}"
      ;;
    'VAULT')
      if [[ -z ${VAULT_ADDR} ]]; then echo -e "${REDCOLOR}Vault address not specified... Exiting...${WHITECOLOR}"; exit 1; fi
      echo -ne "${YELLOWCOLOR}${PRIVATE_KEY_SOURCE} Getting token in progress... ${WHITECOLOR}"
      VAULT_TOKEN=`vault write -field=token auth/approle/login role_id="${VAULT_ROLE_ID}" secret_id="${VAULT_SECRET_ID}"`
      check_rc $?
      echo -ne "${YELLOWCOLOR}${PRIVATE_KEY_SOURCE} Getting secret value in progress... ${WHITECOLOR}"
      SECRET=`VAULT_TOKEN=${VAULT_TOKEN} vault kv get -field=key kv2/duplicity/gpg`
      check_rc $?
      echo -ne "${YELLOWCOLOR}${PRIVATE_KEY_SOURCE} Getting passphrase in progress... ${WHITECOLOR}"
      export PASSPHRASE=`VAULT_TOKEN=${VAULT_TOKEN} vault kv get -field=pass kv2/duplicity/gpg`
      check_rc $?
      import_private_key "${SECRET}" "${PASSPHRASE}"
      ;;
    *)
      echo -e "${REDCOLOR}Please specify a source for private key.\nCurrently available:\n - ASM${WHITECOLOR}"
      exit 1
      ;;
    esac
  fi
  if [ ! -z "${ENCRYPT_DUPLICITY_PARAMETERS}" ]; then COMMON_DUPLICITY_PARAMETERS="${ENCRYPT_DUPLICITY_PARAMETERS} ${COMMON_DUPLICITY_PARAMETERS}"; fi
else
  echo -e "${ORANGECOLOR}No PRIVATE_KEY_SOURCE specified: encryption disabled.${WHITECOLOR}"
  COMMON_DUPLICITY_PARAMETERS="--no-encryption ${COMMON_DUPLICITY_PARAMETERS}"
fi
case $1 in
  'backup' )
    if [[ ! -d "${SOURCE_DIRECTORY}" ]]; then echo -e "${REDCOLOR}Source path not found... Exiting...${WHITECOLOR}"; exit 1; fi
    echo -e "${YELLOWCOLOR}Backup in progress...${WHITECOLOR}"
    duplicity --full-if-older-than "${FULL_BACKUP_INTERVAL}" ${COMMON_DUPLICITY_PARAMETERS} "${SOURCE_DIRECTORY}" "${TARGET}"
    echo -e "${YELLOWCOLOR}Cleanup old backup in progress...${WHITECOLOR}"
    duplicity remove-older-than "${FULL_RETENTION_INTERVAL}" --force ${COMMON_DUPLICITY_PARAMETERS} "${TARGET}"
    duplicity remove-all-inc-of-but-n-full "${INCR_RETENTION_FULL}" --force ${COMMON_DUPLICITY_PARAMETERS} "${TARGET}"
  ;;
  'restore' )
    if [[ ! -d "${TARGET}" ]]; then echo -e "${REDCOLOR}Target path not found... Exiting...${WHITECOLOR}"; exit 1; fi
    if [ -z "${2}" ]; then echo -e "${REDCOLOR}Please specify a restore time (like 2d for 2 days ago)... Exiting...${WHITECOLOR}"; exit 1; fi
    echo -e "${ORANGECOLOR}/!\ Launching restoration in 30 seconds... /!\${WHITECOLOR}"
    echo -e "${BLUECOLOR} - SOURCE: ${SOURCE_DIRECTORY}${WHITECOLOR}"
    echo -e "${BLUECOLOR} - TARGET: ${TARGET}${WHITECOLOR}"
    sleep 30
    duplicity restore -t ${2} ${COMMON_DUPLICITY_PARAMETERS} "${SOURCE_DIRECTORY}" "${TARGET}"
  ;;
  'list' )
    if [ -z "${2}" ]; then echo -e "${REDCOLOR}Please specify a time (like 2d for 2 days ago)... Exiting...${WHITECOLOR}"; exit 1; fi
    duplicity list-current-files -t "${2}" ${COMMON_DUPLICITY_PARAMETERS} "${TARGET}";
  ;;
  * )
    duplicity collection-status ${COMMON_DUPLICITY_PARAMETERS} "${TARGET}"
  ;;
esac
