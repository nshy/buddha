#!/bin/bash

mysql -u budharu -p123budharu123 buddhadb2 <<END
drop database buddhadb2;
create database buddhadb2;
use buddhadb2;
set autocommit=0;
begin;
source tmp/dump.txt;
commit;
END
