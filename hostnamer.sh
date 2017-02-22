#!/bin/sh

echo "$1.courses.ebi.ac.uk" > /etc/hostname

var1="127.0.1.1		$1		$1.courses.ebi.ac.uk"
sed -i "1s/.*/$var1/" /etc/hosts
