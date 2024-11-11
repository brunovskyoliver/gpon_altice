#!/usr/bin/expect -f

set switch_username "brunovsky"
set switch_password "BEh3fTneY06Y82q"
set server_ip "172.29.5.30"
set log_dir "logs"
set current_time [timestamp -format {%Y%m%d_%H%M%S}]

exec mkdir -p $log_dir
set switch_file [open "switches.txt" r]
set switches [split [read $switch_file] "\n"]
close $switch_file

foreach switch_ip $switches {
    set log_file "$log_dir/$switch_ip.log"
    set log_handle [open $log_file a]
    puts $log_handle "\n\nScript zacal v case: $current_time\n"
    spawn ssh -o StrictHostKeyChecking=no $switch_username@$switch_ip
    expect {
        "$switch_username@$switch_ip's password:" {
            send "$switch_password\r"
            exp_continue
        }
        "ssh: connect to host $switch_ip port 22: Network is unreachable" {
            puts $log_handle "neporadilo sa spojit s $switch_ip."
            close $log_handle
            continue
        }
    }
    expect {
        -re {/cli>} {
            send_log $log_file
            send "backup-manager/create --description=$current_time\r"
        }
        timeout {
            puts $log_handle "timeout $switch_ip."
            close $log_handle
            continue
        }
    }
    expect {
        -re {Backup file name: (\S+\.db)} {
            set backup_file $expect_out(1,string)
            puts $log_handle "backup vytvoreny v: $backup_file\n"
            send "backup-manager/export --local-file=$backup_file --server-ip=$server_ip\r"
        }
        timeout {
            puts $log_handle "timeout $switch_ip."
            close $log_handle
            continue
        }
    }
    expect {
        -re {/cli>} {
            send "backup-manager/remove --local-file=$backup_file\r"
        }
        timeout {
            puts $log_handle "timeout $switch_ip."
            close $log_handle
            continue
        }
    }
    expect {
        -re {/cli>} {
            puts $log_handle "backup exportovany do: $server_ip.\n"
        }
        timeout {
            puts $log_handle "timeout $switch_ip."
        }
    }
    send "\x04"
    expect eof
    close $log_handle
}
