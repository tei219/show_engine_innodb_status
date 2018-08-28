# show_engine_innodb_status

    mysql -e "show engine innodb status " | awk -f parse.awk 
