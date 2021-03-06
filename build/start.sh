#!/usr/bin/env bash

_PASSWORD=${CFPASSWORD:-'Adm1n$'}
_DEFAULT_HOST=${DATASOURCE_HOST:-''}

setConfig () {
  curl --silent -H "X-CF-AdminPassword: ${_PASSWORD}" \
  --data "method=callAPI&wsdl=true&apiComponent=$1&apiMethod=$2&apiArguments=$3" \
  http://127.0.0.1/CFIDE/cfadmin-agent/Gateway.cfc
}

buildDatasource () {
  _DS_TYPE=${DATASOURCE_TYPE:-'setMySQL5'}
  _DS_HOST=${DATASOURCE_HOST:-$_DEFAULT_HOST}
  _DS_USER=${DATASOURCE_USER:-'root'}
  _DS_PASS=${DATASOURCE_PASSWORD:-''}
  _DS_DB=${DATASOURCE_DB:-$DATASOURCE_NAME}

  _ARGS="{"
  _ARGS+="\"host\":\"$_DS_HOST\","
  _ARGS+="\"username\":\"$_DS_USER\","
  _ARGS+="\"password\":\"$_DS_PASS\","
  _ARGS+="\"name\":\"$DATASOURCE_NAME\","
  _ARGS+="\"database\":\"$_DS_DB\""
  if [ ! -z $DATASOURCE_ARGS ]; then
    _ARGS+=",\"args\":\"$DATASOURCE_ARGS\""
  fi
  _ARGS+='}'

  echo ''
  echo "Set datasource: $DATASOURCE_NAME"
  setConfig datasource $_DS_TYPE $_ARGS
  echo ''
}

setJsonVar () {
  if [ ! -z "$2" ] && [ "$2" != "null" ]; then
    eval "${1}=\$$2"
  fi
}

setSN () {
  LICENSE_PATH="/opt/coldfusion10/cfusion/lib/license.properties"
  echo ''
  echo "Set Serial number ..."
  echo ''
  cat $LICENSE_PATH | \
  sed -e '/code=/ s/^#*/#/' | \
  sed -e "s/^sn=.*$/sn=$1/" \
  > $LICENSE_PATH
}

setParameters () {
  COLDFUSION_STATUS=`service coldfusion status`
  if [ "$COLDFUSION_STATUS" != "Server is running" ]; then

    echo "Server is not running. Wait..."
    sleep 3
    setParameters

  else

    # Set datasource
    if [ ! -z $DATASOURCE_NAME ]; then
      buildDatasource
    fi

    # set datasources
    if [ ! -z "$DATASOURCES" ]; then
      while read -r _DS
      do
        setJsonVar DATASOURCE_TYPE `echo $_DS | jq 'fromjson | .type'`
        setJsonVar DATASOURCE_HOST `echo $_DS | jq 'fromjson | .host'`
        setJsonVar DATASOURCE_USER `echo $_DS | jq 'fromjson | .username'`
        setJsonVar DATASOURCE_PASSWORD `echo $_DS | jq 'fromjson | .password'`
        setJsonVar DATASOURCE_DB `echo $_DS | jq 'fromjson | .database'`
        _DSNAME=`echo $_DS | jq 'fromjson | .name'`
        if [ "$_DSNAME" != "null" ]; then
          eval "DATASOURCE_NAME=\$$_DSNAME"
        else
          DATASOURCE_NAME=$DATASOURCE_DB
        fi

        buildDatasource
      done < <(echo $DATASOURCES | jq '.[] | tojson')
    fi

    # Set mail server
    if [ ! -z $SMTP_PORT_25_TCP_ADDR ]; then
      echo ''
      echo "Set Mail Server: $SMTP_PORT_25_TCP_ADDR"
      setConfig mail setMailServer "{\"server\": \"$SMTP_PORT_25_TCP_ADDR\"}"
      echo ''
    fi

  fi
}

# Set serial number
if [ ! -z $SERIAL ]; then
  setSN $SERIAL
fi

# Start
/sbin/my_init &
echo "Waiting coldfusion start..."
setParameters

wait
