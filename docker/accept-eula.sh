#!/usr/bin/expect

set timeout -1
set installer [lindex $argv 0]
set directory [lindex $argv 1]

spawn $installer -d $directory
expect "Press Enter to display the license agreements"

send "\r"
set timeout 2

expect {
    "* >*" {send "y\r"}
    timeout { send "q"; sleep 1; exp_continue}
}

expect {
    "* >*" {send "y\r"}
    timeout { send "q"; sleep 1; exp_continue}
}

expect {
    "* >*" {send "y\r"}
    timeout { send "q"; sleep 1; exp_continue}
}

set timeout -1
expect "INFO: Checking PetaLinux installer integrity..."
expect "INFO: PetaLinux SDK has been installed"
#interact
