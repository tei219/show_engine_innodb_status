BEGIN {

}

# detect output date and time 
/^.*[0-9] INNODB MONITOR OUTPUT/         { md=$1; mt=$2; s0_mon_datetime=date_convert(md,mt); } 

# detect Per second averages calculated from the last Xx seconds
/^Per second averages calculated from /  { s0_mon_sec=$8; }

# detect section begins
/^SEMAPHORES/                            { section=1;  }
/^TRANSACTIONS/                          { section=2;  }
/^FILE I\/O/                             { section=3;  }
/^INSERT BUFFER AND ADAPTIVE HASH INDEX/ { section=4;  }
/^BUFFER POOL AND MEMORY/                { section=5;  }
/^ROW OPERATIONS/                        { section=6;  }
/^BACKGROUND THREAD/                     { section=7;  }
/^LATEST DETECTED DEADLOCK/              { section=8;  }
/^LATEST FOREIGN KEY ERROR/              { section=9;  }
/^LOG/                                   { section=10; }
/^INDIVIDUAL BUFFER POOL INFO/           { section=11; }

# detect ends
/^END OF INNODB MONITOR OUTPUT/          { section=0;  } 

# process
{
  # if 'debug' given (e.g. awk -v debug=section|99), shows message to stdout.
  if(debug>0) { if(section==debug || debug==99) {print s0_mon_datetime" "s0_mon_sec" "sn" "section" "$0} }

  # SEMAPHORES
  if(section==1) {
    if($0 ~ /^OS WAIT ARRAY INFO: reservation count/) { s1_reserve_N=rid($7); if(NF>7){ s1_signal_N=$10; }}
    if($0 ~ /^OS WAIT ARRAY INFO: signal count/) { s1_signal_N=$7; }
    if($0 ~ /^Mutex spin waits/) { s1_mutex_spin_waits=rid($4); s1_mutex_spin_rounds=rid($6); s1_mutex_spin_oswaits=$9; }
    if($0 ~ /^RW-shared spins/) { s1_rwshared_spins=rid($3); if($5 ~ /[0-9]+/) { s1_rwshared_spins_rounds=rid($5); s1_rwshared_spins_oswaits=$8; }else{ s1_rwshared_spins_oswaits=rid($6); s1_rwexcl_spins=rid($9); s1_rwexcl_spins_oswaits=$12 } }
    if($0 ~ /^RW-excl spins/) { s1_rwexcl_spins=rid($3); s1_rwexcl_spins_rounds=rid($5); s1_rwexcl_spins_oswaits=$8; }
    if($0 ~ /^RW-sx spins/) { s1_rwsx_spins=rid($3); s1_rwsx_spins_rounds=rid($5); s1_rwsx_spins_oswaits=$8; } # appears upper 5.6
    if($0 ~ /^Spin rounds per wait:/) { 
      if(match($0,/([0-9]+\.[0-9]+) mutex/)) {s1_spin_rounds_per_wait_mutex=substr($0,RSTART,RLENGTH); gsub(/ mutex/,"",s1_spin_rounds_per_wait_mutex)}
      if(match($0,/([0-9]+\.[0-9]+) RW-shared/)) {s1_spin_rounds_per_wait_rwshared=substr($0,RSTART,RLENGTH); gsub(/ RW-shared/,"",s1_spin_rounds_per_wait_rwshared)}
      if(match($0,/([0-9]+\.[0-9]+) RW-excl/)) {s1_spin_rounds_per_wait_rwexcl=substr($0,RSTART,RLENGTH); gsub(/ RW-excl/,"",s1_spin_rounds_per_wait_rwexcl)}
      if(match($0,/([0-9]+\.[0-9]+) RW-sx/)) {s1_spin_rounds_per_wait_rwsx=substr($0,RSTART,RLENGTH); gsub(/ RW-sx/,"",s1_spin_rounds_per_wait_rwsx)}
    } # appears upper 5.5
  }

  # TRANSACTIONS
  if(section==2) {
    if($0 ~ /^Trx id counter/) { if(NF>4){ s2_trx_id=$5; }else{ s2_trx_id=$4; } }
    if($0 ~ /^Purge done for /) { if(NF==13){ s2_trx_purged=$8; s2_trx_undo=$13 }else{ s2_trx_purged=$7; s2_trx_undo=$11; } if(match($0,/state: .*/)){ s2_trx_state=substr($0,RSTART,RLENGTH); gsub(/state: /,"",s2_trx_state); }} # state appears upper 5.6
    if($0 ~ /^History list length/) { s2_history_length=$4 }
    if($0 ~ /^Total number of lock structs/) { s2_total_row_locks=$11; }
    if($0 ~ /^---TRANSACTION/) { s2_trx_N+=1; }
    if($0 ~ /^------- TRX HAS BEEN WAITING/) { s2_trx_has_been_watting_N+=1; }
  }

  # FILE I/O
  if(section==3) {
    if($0 ~ /^I\/O thread/) { s3_io_thread_N+=1; s3_thread_no=$3; }
    if($0 ~ /^I\/O thread.*insert buffer thread/) { s3_io_thread_insert_buffer_N+=1; }
    if($0 ~ /^I\/O thread.*log thread/) { s3_io_thread_log_N+=1; }
    if($0 ~ /^I\/O thread.*read thread/) { s3_io_thread_read_N+=1; }
    if($0 ~ /^I\/O thread.*write thread/) { s3_io_thread_write_N+=1; }
    if($0 ~ /^I\/O thread.*state: /) { if(match($0,/state: .*/)){ s3_thread_state[s3_thread_no]=substr($0,RSTART,RLENGTH); gsub(/state: /,"",s3_thread_state[s3_thread_no]) } }
    if($0 ~ /^Pending normal aio reads:/) { 
      if(match($0,/normal aio reads: [0-9]+,*/)){s3_pending_normal_aio_reads=substr($0,RSTART,RLENGTH); gsub(/normal aio reads: /,"",s3_pending_normal_aio_reads); s3_pending_normal_aio_reads=rid(s3_pending_normal_aio_reads) }
      if(match($0,/ aio writes: [0-9]+,*/)){s3_pending_normal_aio_writes=substr($0,RSTART,RLENGTH); gsub(/ aio writes: /,"",s3_pending_normal_aio_writes); s3_pending_normal_aio_writes=rid(s3_pending_normal_aio_writes) } 
    }
    if($0 ~ /^ ibuf aio reads:/) { if (NF==10){ s3_pending_ibuf_aio_reads=rid($4); s3_pending_log_ios=rid($7); s3_pending_sync_ios=$10; } }
    if($0 ~ /^Pending flushes /) { s3_pending_flushes=rid($5); s3_pending_buffer_pool=$8; }
    if($0 ~ /^[0-9]+ OS file reads,/) { s3_os_file_reads=$1; s3_os_file_writes=$5; s3_os_fsyncs=$9; }
    if($0 ~ /^[0-9\.]+ reads\/s,/) { s3_reads_per_sec=$1; s3_avg_bytes_per_read=$3; s3_writes_per_sec=$6; s3_fsyncs_per_sec=$8; }
  }
  
  # INSERT BUFFER AND ADAPTIVE HASH INDEX
  if(section==4) {
    if($0 ~ /^Ibuf:/) { 
      s4_insert_buffer_size=rid($3); s4_insert_buffer_free_list_len=rid($7); s4_insert_buffer_seg_size=rid($10); s4_insert_buffer_merges=rid($11);
    }
    if($0 ~ /^[0-9]+ inserts, [0-9]+ merged recs/) { s4_insert_buffer_merged_insert=$1; s4_insert_buffer_merged_recs=$3; s4_insert_buffer_merges=$6; }
    if($0 ~ /^merged operations:/) { flg_merged_ope=1; flg_discarded_ope=0; }
    if($0 ~ /^discarded operations:/) { flg_discarded_ope=1; flg_merged_ope=0; }
    if($0 ~ /^ insert [0-9]+,/) {
      if(flg_merged_ope==1) { 
        s4_insert_buffer_merged_insert=rid($2); s4_insert_buffer_merged_delete_mark=rid($5); s4_insert_buffer_merged_delete=rid($7); 
      }
      if(flg_discarded_ope==1) { 
        s4_insert_buffer_merged_discard_insert=rid($2); s4_insert_buffer_merged_discard_delete_mark=rid($5); s4_insert_buffer_merged_discard_delete=rid($7); 
      }
    }
    if($0 ~ /^Hash table/) {
      if(NF==9) { 
        s4_insert_buffer_hash_table_size=rid($4); s4_insert_buffer_node_heap_has_buffer=rid($8); s4_insert_buffer_has_hash_table_N+=1; 
      }
      if(NF==12) {
        s4_insert_buffer_hash_table_size=rid($4); s4_insert_buffer_node_heap_has_buffer=rid($11); s4_insert_buffer_used_cell=rid($7); s4_insert_buffer_has_hash_table_N+=1;
      }
    }
    if($0 ~ /^[0-9\.]+ hash searches/) { s4_input_buffer_hash_searches_per_sec=$1; s4_input_buffer_non_hash_searches_per_sec=$4; }
  }
  
  # BUFFER POOL AND MEMORY
  if (section==5) {
    if($0 ~ /^Total memory /) { s5_total_memory=rid($4); s5_addtional_pool=$9; }
    if($0 ~ /^Total large memory/) { s5_total_memory=$5; }
    if($0 ~ /^Dictionary memory/) { s5_dictionary_memory=$4; }
    if($0 ~ /^Buffer pool size /) { s5_buffer_pool_size=$4; }
    if($0 ~ /^Free buffers /) { s5_free_buffers=$3; }
    if($0 ~ /^Database pages /) { s5_database_pages=$3; }
    if($0 ~ /^Modified db pages /) { s5_modified_database_pages=$4; }
    if($0 ~ /^Pending reads /) { s5_pending_reads=$3; }
    if($0 ~ /^Pending writes: /) { s5_pending_writes_lru=rid($4); s5_pending_writes_flush_list=rid($7); s5_pending_writes_single_page=$10; }
    if($0 ~ /^Pages read [0-9]+, created/) { s5_pages_read=rid($3); s5_pages_created=rid($5); s5_pages_written=$7; }
    if($0 ~ /^[0-9\.]+ reads\/s, /) { s5_pages_reads_per_sec=$1; s5_pages_creates_per_sec=$3; s5_pages_writes_per_sec=$5; }
    if($0 ~ /^Old database pages /) { s5_old_database_pages=$4; }
    if($0 ~ /^Pages made young /) { s5_young_page=rid($4); s5_not_young_page=$7; }
    if($0 ~ /^[0-9\.]+ youngs\/s, /) { s5_youngs_per_sec=$1; s5_non_youngs_per_sec=$3; }
    if($0 ~ /^Pages read ahead /) { s5_pages_read_ahead_per_sec=rremove($4,"/s,"); s5_pages_evicted_without_access_per_sec=rremove($8,"/s,"); s5_pages_random_read_ahead_per_sec=rremove($12,"/s"); }
    if($0 ~ /^LRU len: /) { s5_lru_len=rid($3); s5_unzip_lru_len=$6; }
    if($0 ~ /^Buffer pool hit rate /) { 
      s5_buffer_pool_hit_rate=$5; if(s5_buffer_pool_hit_rate==0) { s5_buffer_pool_hit_rate=0; }else{ s5_buffer_pool_hit_rate/=rid($7);} 
      if(NF>7) { 
        s5_young_making_rate=$10; if(s5_young_making_rate==0) { s5_young_making_rate=0; }else{ s5_young_making_rate/=$12; }
        s5_not_young_making_rate=$14; if(s5_not_young_making_rate==0) { s5_not_young_making_rate=0; }else{ s5_not_young_making_rate/=$16; }
      } 
    }
  }

  # ROW OPERATIONS
  if (section==6) {
    if($0 ~ /^[0-9]+ queries inside/) { s6_query_inside_innodb=$1; s6_query_in_queue=$5; }
    if($0 ~ /^[0-9]+ read views /) { s6_read_views_open_inside_innodb=$1; }
    if($0 ~ /^Main thread process /) { s6_main_thread_no=rid($5); s6_main_thread_id=rid($8); s6_main_thread_state=$9; }
    if($0 ~ /^Number of rows inserted /) { s6_inserted_rows=rid($5); s6_updated_rows=rid($7); s6_deleted_rows=rid($9); s6_read_rows=$11; }
    if($0 ~ /^[0-9\.]+ inserts\/s, /) { s6_inserts_per_sec=$1; s6_updates_per_sec=$3; s6_deletes_per_sec=$5; s6_reads_per_sec=$7; }
  }

  # BACKGROUND THREAD
  if (section==7) {
    if($0 ~ /^srv_master_thread loops:/) { 
      if(NF==12) {
        s7_master_thread_loops_1sec=$3; s7_master_thread_loops_sleeps=$5; s7_master_thread_loops_10sec=$7; s7_master_thread_loops_background=$9; s7_master_thread_loops_flush=$11;
      }else{
        s7_master_thread_loops_srv_active=$3; s7_master_thread_loops_srv_shutdown=$5; s7_master_thread_loops_srv_idle=$7;
      }
    }
    if($0 ~ /^srv_master_thread log flush and writes/) { s7_master_thread_log_flush_and_writes=$6; }
  }

  # LATEST DETECTED DEADLOCK
  if (section==8) {
    if($0 ~ /^[0-9-]+ [0-9]+:[0-9]+:[0-9]+/) { s8_latest_detecetd_deadlock_time=date_convert($1,$2); }
    s8_latest_detected_deadlock_text=s8_latest_detected_deadlock_text"\n"$0;
  }

  # LATEST FOREIGN KEY ERROR
  if (section==9) {
    if($0 ~ /^[0-9-]+ [0-9]+:[0-9]+:[0-9]+ /) { s9_latest_foreign_key_error_time=date_convert($1,$2); }
    s9_latest_foreign_key_error_text=s9_latest_foreign_key_error_text"\n"$0;
  }
  
  # LOG
  if (section==10) {
    if($0 ~ /^Log sequence number/) { if(NF==5){ s10_log_sequence_no=$5; }else{ s10_log_sequence_no=$4; } }
    if($0 ~ /^Log flushed up to/) { if(NF==6){ s10_log_flushed_up=$6; }else{ s10_log_flushed_up=$5; } }
    if($0 ~ /^Last checkpoint at/) { if(NF==5){ s10_log_last_checkpoint=$5; }else{ s10_log_last_checkpoint=$4; } }
    if($0 ~ /^[0-9]+ pending log /) { s10_log_pending_log_writes=$1; s10_log_pending_checkpoint_writes=$5; }
    if($0 ~ /^[0-9]+ log i\/o/) { s10_log_io_done=$1; s10_log_io_per_sec=$5; }
    if($0 ~ /^Log buffer assigned up to/) { s10_log_buffer_assigned_up=$6; }
    if($0 ~ /^Log buffer completed up to/) { s10_log_buffer_completed_up=$6; }
    if($0 ~ /^Log written up to/) { s10_log_written_up=$5; }
    if($0 ~ /^Added dirty pages up to/) { s10_log_added_dirty_page_up=$6; }
  }

  # INDIVIDUAL BUFFER POOL INFO
  if (section==11) {
    if($0 ~ /^---BUFFER POOL [0-9]+/) { s11_buffer_pool_no=$3; }
    if($0 ~ /^Buffer pool size/) { s11_buffer_pool_size[s11_buffer_pool_no]=$4; }
    if($0 ~ /^Free buffers/) { s11_buffer_pool_free_buffers[s11_buffer_pool_no]=$3; }
    if($0 ~ /^Database pages/) { s11_buffer_pool_database_pages[s11_buffer_pool_no]=$3; }
    if($0 ~ /^Old database pages/) { s11_buffer_pool_old_database_pages[s11_buffer_pool_no]=$4; }
    if($0 ~ /^Modified db pages/) { s11_buffer_pool_modified_database_pages[s11_buffer_pool_no]=$4; }
    if($0 ~ /^Pending reads/) { s11_buffer_pool_pending_reads[s11_buffer_pool_no]=$3; } 
    if($0 ~ /^Pending writes: LRU/) { s11_buffer_pool_pending_writes_lru[s11_buffer_pool_no]=rid($4); s11_buffer_pool_flush_list[s11_buffer_pool_no]=rid($7); s11_buffer_pool_single_page[s11_buffer_pool_no]=$10; }
    if($0 ~ /^Pages made young /) { s11_buffer_pool_pages_made_young[s11_buffer_pool_no]=rid($4); s11_buffer_pool_pages_made_not_young[s11_buffer_pool_no]=$7; }
    if($0 ~ /^[0-9\.]+ youngs\/s/) { s11_buffer_pool_youngs_per_sec[s11_buffer_pool_no]=rremove($1,"/s,"); s11_buffer_pool_non_youngs_per_sec[s11_buffer_pool_no]=rremove($3,"/s"); }
    if($0 ~ /^Pages read [0-9]+/) { s11_buffer_pool_pages_read[s11_buffer_pool_no]=rid($3); s11_buffer_pool_pages_created[s11_buffer_pool_no]=rid($5); s11_buffer_pool_pages_written[s11_buffer_pool_no]=$7; }
    if($0 ~ /^[0-9\.]+ reads\/s/) { s11_buffer_pool_reads_per_sec[s11_buffer_pool_no]=rremove($1,"/s,"); s11_buffer_pool_creates_per_sec[s11_buffer_pool_no]=rremove($3,"/s,"); s11_buffer_pool_writes_per_sec[s11_buffer_pool_no]=rremove($5,"/s"); }
    if($0 ~ /^Buffer pool hit rate /) {
      s11_buffer_pool_hit_rate[s11_buffer_pool_no]=$5; if(s11_buffer_pool_hit_rate[s11_buffer_pool_no]==0) { s11_buffer_pool_hit_rate[s11_buffer_pool_no]=0; }else{ s11_buffer_pool_hit_rate[s11_buffer_pool_no]/=rid($7);}
      if(NF>7) {
        s11_young_making_rate[s11_buffer_pool_no]=$10; if(s11_young_making_rate[s11_buffer_pool_no]==0) { s11_young_making_rate[s11_buffer_pool_no]=0; }else{ s11_young_making_rate[s11_buffer_pool_no]/=$12; }
        s11_not_young_making_rate[s11_buffer_pool_no]=$14; if(s11_not_young_making_rate[s11_buffer_pool_no]==0) { s11_not_young_making_rate[s11_buffer_pool_no]=0; }else{ s11_not_young_making_rate[s11_buffer_pool_no]/=$16; }
      }
    }
    if($0 ~ /^Pages read ahead /) { s11_buffer_pool_pages_read_ahead_per_sec[s11_buffer_pool_no]=rremove($4,"/s,"); s11_buffer_pool_pages_evicted_without_access_per_sec[s11_buffer_pool_no]=rremove(rid($8),"/s");}
    if($0 ~ /^LRU len:/) { s11_buffer_pool_lru_len[s11_buffer_pool_no]=rid($3); s11_buffer_pool_unzip_lru_len[s11_buffer_pool_no]=$6;}
    if($0 ~ /^I\/O sum\[/) { s11_buffer_pool_io_sum[s11_buffer_pool_no]=rremove($2,"sum\\["); s11_buffer_pool_io_sum[s11_buffer_pool_no]=rremove(s11_buffer_pool_io_sum[s11_buffer_pool_no],"\\]:.*$"); }
  }
}


END {
  # shows summary:
  print "s0_mon_datetime: "s0_mon_datetime
  print "s0_mon_sec: "s0_mon_sec
  print "s1_reserve_N: "s1_reserve_N
  print "s1_signal_N: "s1_signal_N
  print "s1_mutex_spin_waits: "s1_mutex_spin_waits
  print "s1_mutex_spin_rounds: "s1_mutex_spin_rounds
  print "s1_mutex_spin_oswaits: "s1_mutex_spin_oswaits
  print "s1_rwshared_spins: "s1_rwshared_spins
  print "s1_rwshared_spins_rounds: "s1_rwshared_spins_rounds
  print "s1_rwshared_spins_waits: "s1_rwshared_spins_oswaits
  print "s1_rwexcl_spins: "s1_rwexcl_spins
  print "s1_rwexcl_spins_rounds: "s1_rwexcl_spins_rounds
  print "s1_rwexcl_spins_waits: "s1_rwexcl_spins_oswaits
  print "s1_rwsx_spins: "s1_rwsx_spins
  print "s1_rwsx_spins_rounds: "s1_rwsx_spins_rounds
  print "s1_rwsx_spins_waits: "s1_rwsx_spins_oswaits
  print "s1_spin_rounds_per_wait_mutex: "s1_spin_rounds_per_wait_mutex
  print "s1_spin_rounds_per_wait_rwshared: "s1_spin_rounds_per_wait_rwshared
  print "s1_spin_rounds_per_wait_rwexcl: "s1_spin_rounds_per_wait_rwexcl
  print "s1_spin_rounds_per_wait_rwsx: "s1_spin_rounds_per_wait_rwsx
  print "s2_trx_id: "s2_trx_id
  print "s2_trx_purged: "s2_trx_purged
  print "s2_trx_undo: "s2_trx_undo
  print "s2_trx_state: "s2_trx_state
  print "s2_history_length: "s2_history_length
  print "s2_total_row_locks: "s2_total_row_locks
  print "s2_trx_N: "s2_trx_N
  print "s2_trx_has_been_watting_N: "s2_trx_has_been_watting_N
  print "s2_lock_structs: "s2_lock_structs
  print "s2_heap_size: "s2_heap_size
  print "s2_row_locks: "s2_row_locks
  print "s3_io_thread_N: "s3_io_thread_N
  print "s3_thread_no(last): "s3_thread_no
  print "s3_io_thread_insert_buffer_N: "s3_io_thread_insert_buffer_N
  print "s3_io_thread_log_N: "s3_io_thread_log_N
  print "s3_io_thread_read_N: "s3_io_thread_read_N
  print "s3_io_thread_write_N: "s3_io_thread_write_N
  for (n in s3_thread_state) { print "s3_thread_state["n"]: "s3_thread_state[n]; }
  print "s3_pending_normal_aio_reads: "s3_pending_normal_aio_reads
  print "s3_pending_normal_aio_writes: "s3_pending_normal_aio_writes
  print "s3_pending_ibuf_aio_reads: "s3_pending_ibuf_aio_reads
  print "s3_pending_log_ios: "s3_pending_log_ios
  print "s3_pending_sync_ios: "s3_pending_sync_ios
  print "s3_pending_flushes: "s3_pending_flushes
  print "s3_pending_buffer_pool: "s3_pending_buffer_pool
  print "s3_os_file_reads: "s3_os_file_reads
  print "s3_os_file_writes: "s3_os_file_writes
  print "s3_os_fsyncs: "s3_os_fsyncs
  print "s3_reads_per_sec: "s3_reads_per_sec
  print "s3_avg_bytes_per_read: "s3_avg_bytes_per_read
  print "s3_writes_per_sec: "s3_writes_per_sec
  print "s3_fsyncs_per_sec: "s3_fsyncs_per_sec
  print "s4_insert_buffer_size: "s4_insert_buffer_size
  print "s4_insert_buffer_free_list_len: "s4_insert_buffer_free_list_len
  print "s4_insert_buffer_seg_size: "s4_insert_buffer_seg_size
  print "s4_insert_buffer_merges: "s4_insert_buffer_merges
  print "s4_insert_buffer_merged_insert: "s4_insert_buffer_merged_insert
  print "s4_insert_buffer_merged_recs: "s4_insert_buffer_merged_recs
  print "s4_insert_buffer_merges: "s4_insert_buffer_merges
  print "s4_insert_buffer_merged_insert: "s4_insert_buffer_merged_insert
  print "s4_insert_buffer_merged_delete_mark: "s4_insert_buffer_merged_delete_mark
  print "s4_insert_buffer_merged_delete: "s4_insert_buffer_merged_delete
  print "s4_insert_buffer_merged_discard_insert: "s4_insert_buffer_merged_discard_insert
  print "s4_insert_buffer_merged_discard_delete_mark: "s4_insert_buffer_merged_discard_delete_mark
  print "s4_insert_buffer_merged_discard_delete: "s4_insert_buffer_merged_discard_delete
  print "s4_insert_buffer_hash_table_size: "s4_insert_buffer_hash_table_size
  print "s4_insert_buffer_node_heap_has_buffer: "s4_insert_buffer_node_heap_has_buffer
  print "s4_insert_buffer_has_hash_table_N: "s4_insert_buffer_has_hash_table_N
  print "s4_insert_buffer_used_cell: "s4_insert_buffer_used_cell
  print "s4_input_buffer_hash_searches_per_sec: "s4_input_buffer_hash_searches_per_sec
  print "s4_input_buffer_non_hash_searches_per_sec: "s4_input_buffer_non_hash_searches_per_sec
  print "s5_total_memory: "s5_total_memory
  print "s5_addtional_pool: "s5_addtional_pool
  print "s5_dictionary_memory: "s5_dictionary_memory
  print "s5_buffer_pool_size: "s5_buffer_pool_size
  print "s5_free_buffers: "s5_free_buffers
  print "s5_database_pages: "s5_database_pages
  print "s5_modified_database_pages: "s5_modified_database_pages
  print "s5_pending_reads: "s5_pending_reads
  print "s5_pending_writes_lru: "s5_pending_writes_lru
  print "s5_pending_writes_flush_list: "s5_pending_writes_flush_list
  print "s5_pending_writes_single_page: "s5_pending_writes_single_page
  print "s5_pages_read: "s5_pages_read
  print "s5_pages_created: "s5_pages_created
  print "s5_pages_written: "s5_pages_written
  print "s5_pages_reads_per_sec: "s5_pages_reads_per_sec
  print "s5_pages_creates_per_sec: "s5_pages_creates_per_sec
  print "s5_pages_writes_per_sec: "s5_pages_writes_per_sec
  print "s5_old_database_pages: "s5_old_database_pages
  print "s5_young_page: "s5_young_page
  print "s5_not_young_page: "s5_not_young_page
  print "s5_youngs_per_sec: "s5_youngs_per_sec
  print "s5_non_youngs_per_sec: "s5_non_youngs_per_sec
  print "s5_pages_read_ahead_per_sec: "s5_pages_read_ahead_per_sec
  print "s5_pages_evicted_without_access_per_sec: "s5_pages_evicted_without_access_per_sec
  print "s5_pages_random_read_ahead_per_sec: "s5_pages_random_read_ahead_per_sec
  print "s5_lru_len: "s5_lru_len
  print "s5_unzip_lru_len: "s5_unzip_lru_len
  print "s5_buffer_pool_hit_rate: "s5_buffer_pool_hit_rate
  print "s5_young_making_rate: "s5_young_making_rate
  print "s5_not_young_making_rate: "s5_not_young_making_rate
  print "s6_query_inside_innodb: "s6_query_inside_innodb
  print "s6_query_in_queue: "s6_query_in_queue
  print "s6_read_views_open_inside_innodb: "s6_read_views_open_inside_innodb
  print "s6_main_thread_no: "s6_main_thread_no
  print "s6_main_thread_id: "s6_main_thread_id
  print "s6_main_thread_state: "s6_main_thread_state
  print "s6_inserted_rows: "s6_inserted_rows
  print "s6_updated_rows: "s6_updated_rows
  print "s6_deleted_rows: "s6_deleted_rows
  print "s6_read_rows: "s6_read_rows
  print "s6_inserts_per_sec: "s6_inserts_per_sec
  print "s6_updates_per_sec: "s6_updates_per_sec
  print "s6_deletes_per_sec: "s6_deletes_per_sec
  print "s6_reads_per_sec: "s6_reads_per_sec
  print "s7_master_thread_loops_1sec: "s7_master_thread_loops_1sec
  print "s7_master_thread_loops_sleeps: "s7_master_thread_loops_sleeps
  print "s7_master_thread_loops_10sec: "s7_master_thread_loops_10sec
  print "s7_master_thread_loops_background: "s7_master_thread_loops_background
  print "s7_master_thread_loops_flush: "s7_master_thread_loops_flush
  print "s7_master_thread_loops_srv_active: "s7_master_thread_loops_srv_active
  print "s7_master_thread_loops_srv_shutdown: "s7_master_thread_loops_srv_shutdown
  print "s7_master_thread_loops_srv_idle: "s7_master_thread_loops_srv_idle
  print "s7_master_thread_log_flush_and_writes: "s7_master_thread_log_flush_and_writes
  print "s8_latest_detecetd_deadlock_time: "s8_latest_detecetd_deadlock_time
  print "s8_latest_detected_deadlock_text: "s8_latest_detected_deadlock_text
  print "s9_latest_foreign_key_error_time: "s9_latest_foreign_key_error_time
  print "s9_latest_foreign_key_error_text: "s9_latest_foreign_key_error_text
  print "s10_log_sequence_no: "s10_log_sequence_no
  print "s10_log_flushed_up: "s10_log_flushed_up
  print "s10_log_last_checkpoint: "s10_log_last_checkpoint
  print "s10_log_pending_log_writes: "s10_log_pending_log_writes
  print "s10_log_pending_checkpoint_writes: "s10_log_pending_checkpoint_writes
  print "s10_log_io_done: "s10_log_io_done
  print "s10_log_io_per_sec: "s10_log_io_per_sec
  print "s10_log_buffer_assigned_up: "s10_log_buffer_assigned_up
  print "s10_log_buffer_completed_up: "s10_log_buffer_completed_up
  print "s10_log_written_up: "s10_log_written_up
  print "s10_log_added_dirty_page_up: "s10_log_added_dirty_page_up
  for (n=0; n<=s11_buffer_pool_no; n++) {
    print "s11_buffer_pool_size["n"]: "s11_buffer_pool_size[n]
    print "s11_buffer_pool_pending_writes_lru["n"]: "s11_buffer_pool_pending_writes_lru[n]
    print "s11_buffer_pool_flush_list["n"]: "s11_buffer_pool_flush_list[n]
    print "s11_buffer_pool_single_page["n"]: "s11_buffer_pool_single_page[n]
    print "s11_buffer_pool_pages_made_young["n"]: "s11_buffer_pool_pages_made_young[n]
    print "s11_buffer_pool_pages_made_not_young["n"]: "s11_buffer_pool_pages_made_not_young[n]
    print "s11_buffer_pool_youngs_per_sec["n"]: "s11_buffer_pool_youngs_per_sec[n]
    print "s11_buffer_pool_non_youngs_per_sec["n"]: "s11_buffer_pool_non_youngs_per_sec[n]
    print "s11_buffer_pool_pages_read["n"]: "s11_buffer_pool_pages_read[n]
    print "s11_buffer_pool_pages_created["n"]: "s11_buffer_pool_pages_created[n]
    print "s11_buffer_pool_pages_written["n"]: "s11_buffer_pool_pages_written[n]
    print "s11_buffer_pool_reads_per_sec["n"]: "s11_buffer_pool_reads_per_sec[n]
    print "s11_buffer_pool_creates_per_sec["n"]: "s11_buffer_pool_creates_per_sec[n]
    print "s11_buffer_pool_writes_per_sec["n"]: "s11_buffer_pool_writes_per_sec[n]
    print "s11_buffer_pool_hit_rate["n"]: "s11_buffer_pool_hit_rate[n]
    print "s11_young_making_rate["n"]: "s11_young_making_rate[n]
    print "s11_not_young_making_rate["n"]: "s11_not_young_making_rate[n]
    print "s11_buffer_pool_pages_read_ahead_per_sec["n"]: "s11_buffer_pool_pages_read_ahead_per_sec[n]
    print "s11_buffer_pool_pages_evicted_without_access_per_sec["n"]: "s11_buffer_pool_pages_evicted_without_access_per_sec[n]
    print "s11_buffer_pool_lru_len["n"]: "s11_buffer_pool_lru_len[n]
    print "s11_buffer_pool_unzip_lru_len["n"]: "s11_buffer_pool_unzip_lru_len[n]
    print "s11_buffer_pool_io_sum["n"]: "s11_buffer_pool_io_sum[n]
  }
}

# remove '[,;]' at end
function rid(s) {
  return rremove(s,"[,;]$");
}

# regexp remove
function rremove(s,p) {
  gsub(p,"",s);
  return s;
}

# datestr converter
function date_convert(md,mt) {
  if (length(md)==6) {
    md="20"md;
    gsub(/:/," ",mt);
    mdt=strftime("%Y/%m/%d %H:%M:%S", mktime(substr(md,1,4)" "substr(md,5,2)" "substr(md,7,2)" "mt));
  } else {
    mdt=md" "mt;
  }
  return mdt;
}
