sudo yum install openswan -y
sudo echo "net.ipv4.ip_forward = 1" > /etc/sysctl.conf
sudo echo "net.ipv4.conf.all.accept_redirects = 0" > /etc/sysctl.conf
sudo echo "net.ipv4.conf.all.send_redirects = 0" > /etc/sysctl.conf
sudo sysctl -p
sudo echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sudo echo "net.ipv4.conf.all.send_redirects = 0" >> /etc/sysctl.conf
sudo echo "net.ipv4.conf.default.send_redirects = 0" >> /etc/sysctl.conf
sudo echo "net.ipv4.tcp_max_syn_backlog = 1280" >> /etc/sysctl.conf
sudo echo "net.ipv4.icmp_echo_ignore_broadcasts = 1" >> /etc/sysctl.conf
sudo echo "net.ipv4.conf.all.accept_source_route = 0" >> /etc/sysctl.conf
sudo echo "net.ipv4.conf.all.accept_redirects = 0" >> /etc/sysctl.conf
sudo echo "net.ipv4.conf.all.secure_redirects = 0" >> /etc/sysctl.conf
sudo echo "net.ipv4.conf.all.log_martians = 1" >> /etc/sysctl.conf
sudo echo "net.ipv4.conf.default.accept_source_route = 0" >> /etc/sysctl.conf
sudo echo "net.ipv4.conf.default.accept_redirects = 0" >> /etc/sysctl.conf
sudo echo "net.ipv4.conf.default.secure_redirects = 0" >> /etc/sysctl.conf
sudo echo "net.ipv4.icmp_echo_ignore_broadcasts = 1" >> /etc/sysctl.conf
sudo echo "net.ipv4.icmp_ignore_bogus_error_responses = 1" >> /etc/sysctl.conf
sudo echo "net.ipv4.tcp_syncookies = 1" >> /etc/sysctl.conf
sudo echo "net.ipv4.conf.all.rp_filter = 1" >> /etc/sysctl.conf
sudo echo "net.ipv4.conf.default.rp_filter = 1" >> /etc/sysctl.conf
sudo echo "net.ipv4.tcp_mtu_probing = 1" >> /etc/sysctl.conf
sudo sysctl -p