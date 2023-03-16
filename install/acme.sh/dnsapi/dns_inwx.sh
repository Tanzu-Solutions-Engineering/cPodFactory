#!/usr/bin/bash

#
#INWX_User="username"
#
#INWX_Password="password"

INWX_Api="https://api.domrobot.com/xmlrpc/"

########  Public functions #####################

#Usage: add  _acme-challenge.www.domain.com   "XKrxpRBosdIKFzxW_CT3KLZNf6q0HG9i01zxXp5CPBs"
dns_inwx_add() {
  fulldomain=$1
  txtvalue=$2

  INWX_User="${INWX_User:-$(_readaccountconf_mutable INWX_User)}"
  INWX_Password="${INWX_Password:-$(_readaccountconf_mutable INWX_Password)}"
  if [ -z "$INWX_User" ] || [ -z "$INWX_Password" ]; then
    INWX_User=""
    INWX_Password=""
    _err "You don't specify inwx user and password yet."
    _err "Please create you key and try again."
    return 1
  fi

  #save the api key and email to the account conf file.
  _saveaccountconf_mutable INWX_User "$INWX_User"
  _saveaccountconf_mutable INWX_Password "$INWX_Password"

  _debug "First detect the root zone"
  if ! _get_root "$fulldomain"; then
    _err "invalid domain"
    return 1
  fi
  _debug _sub_domain "$_sub_domain"
  _debug _domain "$_domain"
  _debug "Getting txt records"

  xml_content=$(printf '<?xml version="1.0" encoding="UTF-8"?>
  <methodCall>
  <methodName>nameserver.info</methodName>
  <params>
   <param>
    <value>
     <struct>
      <member>
       <name>domain</name>
       <value>
        <string>%s</string>
       </value>
      </member>
      <member>
       <name>type</name>
       <value>
        <string>TXT</string>
       </value>
      </member>
      <member>
       <name>name</name>
       <value>
        <string>%s</string>
       </value>
      </member>
     </struct>
    </value>
   </param>
  </params>
  </methodCall>' "$_domain" "$_sub_domain")
  response="$(_post "$xml_content" "$INWX_Api" "" "POST")"

  if ! printf "%s" "$response" | grep "Command completed successfully" >/dev/null; then
    _err "Error could net get txt records"
    return 1
  fi

  if ! printf "%s" "$response" | grep "count" >/dev/null; then
    _info "Adding record"
    _inwx_add_record "$_domain" "$_sub_domain" "$txtvalue"
  else
    _record_id=$(printf '%s' "$response" | _egrep_o '.*(<member><name>record){1}(.*)([0-9]+){1}' | _egrep_o '<name>id<\/name><value><int>[0-9]+' | _egrep_o '[0-9]+')
    _info "Updating record"
    _inwx_update_record "$_record_id" "$txtvalue"
  fi

}

#fulldomain txtvalue
dns_inwx_rm() {

  fulldomain=$1
  txtvalue=$2

  INWX_User="${INWX_User:-$(_readaccountconf_mutable INWX_User)}"
  INWX_Password="${INWX_Password:-$(_readaccountconf_mutable INWX_Password)}"
  if [ -z "$INWX_User" ] || [ -z "$INWX_Password" ]; then
    INWX_User=""
    INWX_Password=""
    _err "You don't specify inwx user and password yet."
    _err "Please create you key and try again."
    return 1
  fi

  #save the api key and email to the account conf file.
  _saveaccountconf_mutable INWX_User "$INWX_User"
  _saveaccountconf_mutable INWX_Password "$INWX_Password"

  _debug "First detect the root zone"
  if ! _get_root "$fulldomain"; then
    _err "invalid domain"
    return 1
  fi
  _debug _sub_domain "$_sub_domain"
  _debug _domain "$_domain"

  _debug "Getting txt records"

  xml_content=$(printf '<?xml version="1.0" encoding="UTF-8"?>
  <methodCall>
  <methodName>nameserver.info</methodName>
  <params>
   <param>
    <value>
     <struct>
      <member>
       <name>domain</name>
       <value>
        <string>%s</string>
       </value>
      </member>
      <member>
       <name>type</name>
       <value>
        <string>TXT</string>
       </value>
      </member>
      <member>
       <name>name</name>
       <value>
        <string>%s</string>
       </value>
      </member>
     </struct>
    </value>
   </param>
  </params>
  </methodCall>' "$_domain" "$_sub_domain")
  response="$(_post "$xml_content" "$INWX_Api" "" "POST")"

  if ! printf "%s" "$response" | grep "Command completed successfully" >/dev/null; then
    _err "Error could not get txt records"
    return 1
  fi

  if ! printf "%s" "$response" | grep "count" >/dev/null; then
    _info "Do not need to delete record"
  else
    _record_id=$(printf '%s' "$response" | _egrep_o '.*(<member><name>record){1}(.*)([0-9]+){1}' | _egrep_o '<name>id<\/name><value><int>[0-9]+' | _egrep_o '[0-9]+')
    _info "Deleting record"
    _inwx_delete_record "$_record_id"
  fi

}

####################  Private functions below ##################################

_inwx_login() {

  xml_content=$(printf '<?xml version="1.0" encoding="UTF-8"?>
  <methodCall>
  <methodName>account.login</methodName>
  <params>
   <param>
    <value>
     <struct>
      <member>
       <name>user</name>
       <value>
        <string>%s</string>
       </value>
      </member>
      <member>
       <name>pass</name>
       <value>
        <string>%s</string>
       </value>
      </member>
     </struct>
    </value>
   </param>
  </params>
  </methodCall>' $INWX_User $INWX_Password)

  response="$(_post "$xml_content" "$INWX_Api" "" "POST")"

  printf "Cookie: %s" "$(grep "domrobot=" "$HTTP_HEADER" | grep "^Set-Cookie:" | _tail_n 1 | _egrep_o 'domrobot=[^;]*;' | tr -d ';')"

}

_get_root() {
  domain=$1
  _debug "get root"

  domain=$1
  i=2
  p=1

  _H1=$(_inwx_login)
  export _H1
  xml_content='<?xml version="1.0" encoding="UTF-8"?>
  <methodCall>
  <methodName>nameserver.list</methodName>
  </methodCall>'

  response="$(_post "$xml_content" "$INWX_Api" "" "POST")"
  while true; do
    h=$(printf "%s" "$domain" | cut -d . -f $i-100)
    _debug h "$h"
    if [ -z "$h" ]; then
      #not valid
      return 1
    fi

    if _contains "$response" "$h"; then
      _sub_domain=$(printf "%s" "$domain" | cut -d . -f 1-$p)
      _domain="$h"
      return 0
    fi
    p=$i
    i=$(_math "$i" + 1)
  done
  return 1

}

_inwx_delete_record() {
  record_id=$1
  xml_content=$(printf '<?xml version="1.0" encoding="UTF-8"?>
  <methodCall>
  <methodName>nameserver.deleteRecord</methodName>
  <params>
   <param>
    <value>
     <struct>
      <member>
       <name>id</name>
       <value>
        <int>%s</int>
       </value>
      </member>
     </struct>
    </value>
   </param>
  </params>
  </methodCall>' "$record_id")

  response="$(_post "$xml_content" "$INWX_Api" "" "POST")"

  if ! printf "%s" "$response" | grep "Command completed successfully" >/dev/null; then
    _err "Error"
    return 1
  fi
  return 0

}

_inwx_update_record() {
  record_id=$1
  txtval=$2
  xml_content=$(printf '<?xml version="1.0" encoding="UTF-8"?>
  <methodCall>
  <methodName>nameserver.updateRecord</methodName>
  <params>
   <param>
    <value>
     <struct>
      <member>
       <name>content</name>
       <value>
        <string>%s</string>
       </value>
      </member>
      <member>
       <name>id</name>
       <value>
        <int>%s</int>
       </value>
      </member>
     </struct>
    </value>
   </param>
  </params>
  </methodCall>' "$txtval" "$record_id")

  response="$(_post "$xml_content" "$INWX_Api" "" "POST")"

  if ! printf "%s" "$response" | grep "Command completed successfully" >/dev/null; then
    _err "Error"
    return 1
  fi
  return 0

}

_inwx_add_record() {

  domain=$1
  sub_domain=$2
  txtval=$3

  xml_content=$(printf '<?xml version="1.0" encoding="UTF-8"?>
  <methodCall>
  <methodName>nameserver.createRecord</methodName>
  <params>
   <param>
    <value>
     <struct>
      <member>
       <name>domain</name>
       <value>
        <string>%s</string>
       </value>
      </member>
      <member>
       <name>type</name>
       <value>
        <string>TXT</string>
       </value>
      </member>
      <member>
       <name>content</name>
       <value>
        <string>%s</string>
       </value>
      </member>
      <member>
       <name>name</name>
       <value>
        <string>%s</string>
       </value>
      </member>
     </struct>
    </value>
   </param>
  </params>
  </methodCall>' "$domain" "$txtval" "$sub_domain")

  response="$(_post "$xml_content" "$INWX_Api" "" "POST")"

  if ! printf "%s" "$response" | grep "Command completed successfully" >/dev/null; then
    _err "Error"
    return 1
  fi
  return 0
}
