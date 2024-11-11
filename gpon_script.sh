#!/usr/bin/expect -f

set switch_username "brunovsky"
set switch_password "BEh3fTneY06Y82q"
set log_dir "logs"
set current_time [timestamp -format {%Y-%m-%d %H:%M:%S}]

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
            continue
        }
    }
    close $log_handle
    expect {
        -re {/cli>} {
            log_file -a $log_file
            send "remote-eq/discovery/reboot-all\r"
        }
        timeout {
            continue
        }
    }
    expect {
        "Are you sure? (yes,no)" {
            send "no\r"
            exp_continue
        }
    }
    send "\x04"
    expect eof
    log_file
}
