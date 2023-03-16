#/usr/bin/env bash
#bdereims@vmware.com

_cpodctl() {
  COMPREPLY=()

  # All possible first values in command line
  local ACTIONS=("delete" "password" "vcsa" "list" "create" "cloudbuilder")

  # declare an associative array for options
  declare -a SERVICES
  for CPOD in $( cd /root/cPodFactory ; ./list_cpod.sh | tail -n +2 | awk '{print $1}' ) ; do
    SERVICES+=( ${CPOD} )
  done 

  declare -a USERS
  for CPOD in $( /root/cPodFactory/list_cpod.sh | tail -n +2 | awk '{print $2}' | sed -e "s/(//" -e "s/)//" | sort | uniq ) ; do
    USERS+=( ${CPOD} )
  done

  # current word being autocompleted
  local cur=${COMP_WORDS[COMP_CWORD]}

  if [[ "$3" == "${ACTIONS[0]}" || "$3" == "${ACTIONS[2]}" || "$3" == "${ACTIONS[5]}" ]] ; then 
    COMPREPLY=( `compgen -W "${SERVICES[*]}" -- $cur` )
  else 
    COMPREPLY=( `compgen -W "${ACTIONS[*]}" -- $cur` )
  fi
}

complete -F _cpodctl cpodctl
