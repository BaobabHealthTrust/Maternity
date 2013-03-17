#!/bin/bash

usage(){
  echo "Usage: $0 ENVIRONMENT SITE"
  echo
  echo "ENVIRONMENT should be: development|test|production"
  echo "Available SITES:"
  ls -1 db/data
} 

ENV=$1
SITE=$2

if [ -z "$ENV" ] || [ -z "$SITE" ] ; then
  usage
  exit
fi

set -x # turns on stacktrace mode which gives useful debug information

if [ ! -x config/database.yml ] ; then
   cp config/database.yml.example config/database.yml
fi


USERNAME=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['username']"`
PASSWORD=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['password']"`
DATABASE=`ruby -ryaml -e "puts YAML::load_file('config/database.yml')['${ENV}']['database']"`
echo "REACHED POINT"

mysql --user=$USERNAME --password=$PASSWORD $DATABASE < db/migrate/concepts.sql
mysql --user=$USERNAME --password=$PASSWORD $DATABASE < db/migrate/create_site_wards.sql
mysql --user=$USERNAME --password=$PASSWORD $DATABASE < db/create_dde_server_connection.sql
mysql --user=$USERNAME --password=$PASSWORD $DATABASE < db/serial_number.sql
mysql --user=$USERNAME --password=$PASSWORD $DATABASE < db/relationship_type.sql
mysql --user=$USERNAME --password=$PASSWORD $DATABASE < db/birth_report.sql
mysql --user=$USERNAME --password=$PASSWORD $DATABASE < db/custom.sql
