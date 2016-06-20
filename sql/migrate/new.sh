#!/bin/bash

#NOW=$(date +"%Y-%m-%d-%s")
NOW=$(date +"%c (%z)")

if [ "$1" == '' ]; then
	echo 'Usage: ./new.sh NAME'
	echo './new.sh add_column will create file like 1421506558-new_column.sql'
else
	F=$(date +%s)-$1.sql
	touch $F
	echo "-- $F created at $NOW" >> $F
	echo "" >> $F
	echo "$F created, run mcedit $F"
fi
