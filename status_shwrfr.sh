#!/bin/bash

. ./govc_env

date > /tmp/$$
echo " "  >> /tmp/$$
govc datacenter.info >> /tmp/$$
echo " "  >> /tmp/$$
govc metric.ls host/*  | grep cpu. | xargs govc metric.sample host/* >> /tmp/$$
echo " "  >> /tmp/$$
govc metric.ls host/*  | grep mem. | xargs govc metric.sample host/* >> /tmp/$$
echo " "  >> /tmp/$$
govc datastore.info >> /tmp/$$

#awk 'BEGIN{print "<table>"} {print "<tr>";for(i=1;i<=NF;i++)print "<td>" $i"</td>";print "</tr>"} END{print "</table>"}' /tmp/$$ > /etc/nginx/html/status.html
#awk 'BEGIN{print "<table>"} {print "<tr>";for(i=1;i<=NF;i++)print "<td>" $i"</td>";print "</tr>"} END{print "</table>"}' /tmp/$$ > /etc/nginx/html/status.html
cat /tmp/$$ | sed 's/$/<br>/' > /etc/nginx/html/status.html

rm /tmp/$$

chown nobody /etc/nginx/html/status.html

