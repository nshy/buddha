#!/bin/bash

mysql -u budharu -p123budharu123 <<END
create database buddhadb;
use buddhadb;
set autocommit=0;
begin;
source buddhadb.dump;
commit;
END
