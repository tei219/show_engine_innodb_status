# show_engine_innodb_status

    mysql -e "show engine innodb status\G " | awk -f parse.awk 
