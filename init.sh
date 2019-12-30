#!/bin/bash
## VARIABLES ##
PUB_GPG_FILE="gpg.pub"
REDCOLOR="\\033[1;31m"
WHITECOLOR="\\033[0;02m"
BLUECOLOR='\e[0;36m'

## FUNCTIONS ##
function trust_key {
  echo -e "trust\n5\ny\nquit" | gpg --no-tty --command-fd 0 --edit-key ${1}
  if [[ $? -eq 0 ]]; then echo "${1} trusted!" ; else "Unable to trust ${1}"; exit 1; fi
}
function check_rc {
  if [[ $? -ne 0 ]]; then echo "${REDCOLOR}FAIL... Exiting... ${WHITECOLOR}"; exit 1; fi 
}

## MAIN ##
  echo '-----BEGIN PGP PUBLIC KEY BLOCK-----

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
sQ==
=DPQA
-----END PGP PUBLIC KEY BLOCK-----' > ${PUB_GPG_FILE}
check_rc $?
PUB_ID=(`gpg --import ${PUB_GPG_FILE} 2>&1 | egrep -o "[A-F0-9]{8,16}"`)
check_rc $?
for KEY in ${PUB_ID[@]}
do
  trust_key ${KEY}
  ENCRYPT_KEYS="${ENCRYPT_KEYS} --encrypt-key=${PUB_ID}"
done
echo "export ENCRYPT_KEYS=\"${ENCRYPT_KEYS}\"" > ./env
