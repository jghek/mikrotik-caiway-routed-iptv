# RouterOS 6.45.7, CCR1009-7G-1C-1S+

# Uitgebreide configuratie voor CAIWAY routed-IPTV voor Mikrotik RouterOS (Extra package: NTP Server)
# Bij CAIWAY zit internet op VLAN 100. Je kunt hier met DHCP een IP adres opvragen.
# De IPTV zit op VLAN 101. Je kunt hier ook met DHCP een VLAN opvragen, maar dit vereist de juiste optie (optie 60).
#
# Zelf maak ik gebruik van:
# VLAN 10  : 10.218.0.1/16    - Mijn netwerk voor kinderen en gasten. Gebruikt OpenDNS servers om ongewenste inhoud te filteren en een /16 reeks om veel DHCP leases aan te kunnen.
# VLAN 1218: 192.168.218.1/24 - Mijn thuis netwerk.
# VLAN 1251: 192.168.251.1/24 - Mijn IPTV LAN. Hierbinnen zitten de AMINO tv boxes. Mochten ze gehackt worden, dan zitten ze niet in mijn thuis LAN.

# Het maken van de L2 segmenten (bridges). IGMP snooping moet aan staan op ons IPTV LAN.
/interface bridge add name=bridge10
/interface bridge add fast-forward=no name=bridge1218 protocol-mode=none
/interface bridge add arp=proxy-arp fast-forward=no igmp-snooping=yes name=bridge1251 protocol-mode=none

# Geen STP pakketten naar de provider
/interface ethernet set [ find default-name=combo1 ] loop-protect=off

# Aanmaken van VLANs op de interfaces.

# Internet
/interface vlan add arp=proxy-arp interface=combo1 loop-protect=off name=combo1.100 vlan-id=100

# IPTV
/interface vlan add interface=combo1 loop-protect=off name=combo1.101 vlan-id=101

# Over ether7 gaan meerdere vlans naar mijn switch.
/interface vlan add interface=ether7 name=ether7.10 vlan-id=10
/interface vlan add interface=ether7 name=ether7.1218 vlan-id=1218

# DHCP client optie. Nodig om een IP adres te krijgen van de CAIWAY IPTV DHCP.
/ip dhcp-client option add code=60 name=IPTV_RG value="'IPTV_RG'"

# DHCP server optie. Deze levert de mikrotik aan de ANIMO boxes.
/ip dhcp-server option add code=60 name=option60-vendorclass value="'IPTV_RG'"
/ip dhcp-server option add code=28 name=option28-broadcast value="'192.168.251.255'"
/ip dhcp-server option sets add name=IPTV options=option60-vendorclass,option28-broadcast

# Adres ranges (pools) die de DHCP servers mogen uitgeven.
/ip pool add name=dhcp-1218 ranges=192.168.218.32-192.168.218.254
/ip pool add name=dhcp-10 ranges=10.218.1.1-10.218.255.254
/ip pool add name=dhcp-1251 ranges=192.168.251.32-192.168.251.254

# Opzetten van de DHCP servers
/ip dhcp-server add address-pool=dhcp-10 disabled=no interface=bridge10 lease-time=1h30m name=dhcp-server-10
/ip dhcp-server add address-pool=dhcp-1218 disabled=no interface=bridge1218 lease-time=1h30m name=dhcp-server-1218
/ip dhcp-server add address-pool=dhcp-1251 dhcp-option-set=IPTV disabled=no interface=bridge1251 name=dhcp-server-1251

# BGP routering uit.
/routing bgp instance set default disabled=yes

# interfaces koppelen aan L2 segmenten (bridges).
/interface bridge port add bridge=bridge1251 interface=ether4
/interface bridge port add bridge=bridge1251 interface=ether5
/interface bridge port add bridge=bridge10 interface=ether7.10
/interface bridge port add bridge=bridge1218 interface=ether7.1218

# IP adressen koppelen aan L2 segmenten (bridges).
/ip address add address=10.218.0.1/16 interface=bridge10 network=10.218.0.0
/ip address add address=192.168.218.1/24 interface=bridge1218 network=192.168.218.0
/ip address add address=192.168.251.1/24 interface=bridge1251 network=192.168.251.0

# Via CAIWAY heb je geen fixed ip-adres. Mikrotik geeft je een gratis (en geintregeerde DDNS service). Top!
# gebruik '/ip cloud print' om te achterhalen wat jouw gekoppelde domeinnaam is. Iets als: <serie-nummer>.sn.mynetname.net
# Als je zelf een domeinnaam hebt de je wilt gebruiken, dan kun je het beste een CNAME record aanmaken die verwijst naar de mikrotik ddns naam.
/ip cloud set ddns-enabled=yes

# DHCP Clients: kortom, op welke L2 segmenten gaan we via DHCP een IP adres opvragen en met welke opties?
/ip dhcp-client add dhcp-options=hostname,clientid disabled=no interface=combo1.100
/ip dhcp-client add default-route-distance=210 dhcp-options=IPTV_RG,hostname,clientid disabled=no interface=combo1.101 use-peer-dns=no use-peer-ntp=no

# DHCP Server voor gasten gebruikt OpenDNS adressen.
/ip dhcp-server network add address=10.218.0.0/16 dns-server=208.67.222.123,208.67.220.123 domain=guest.local gateway=10.218.0.1 ntp-server=10.218.0.1 netmask=24
/ip dhcp-server network add address=192.168.218.0/24 dns-server=192.168.218.1 domain=hek.local gateway=192.168.218.1 ntp-server=192.168.218.1 netmask=24
/ip dhcp-server network add address=192.168.251.0/24 dhcp-option-set=IPTV dns-server=192.168.251.1 domain=iptv.local gateway=192.168.251.1 ntp-server=192.168.251.1 netmask=24

# Onze router zal DNS request beantwoorden.
/ip dns set allow-remote-requests=yes cache-max-ttl=1d servers=8.8.8.8,8.8.4.4

# Deze reeksen mogen niet op internet voorkomen, omdat het private ranges zijn of test reeksen. We filteren ze.
/ip firewall address-list add address=0.0.0.0/8 comment="Self-Identification [RFC 3330]" list=Unrouted
/ip firewall address-list add address=10.0.0.0/8 comment="Private class A" list=Unrouted
/ip firewall address-list add address=127.0.0.0/8 comment="Loopback [RFC 3330]" list=Unrouted
/ip firewall address-list add address=169.254.0.0/16 comment="Link Local [RFC 3330]" list=Unrouted
/ip firewall address-list add address=172.16.0.0/12 comment="Private class B" list=Unrouted
/ip firewall address-list add address=192.0.2.0/24 comment="Reserved - IANA - TestNet1" list=Unrouted
/ip firewall address-list add address=192.88.99.0/24 comment="6to4 Relay Anycast [RFC 3068]" list=Unrouted
/ip firewall address-list add address=198.18.0.0/15 comment="NIDB Testing" list=Unrouted
/ip firewall address-list add address=198.51.100.0/24 comment="Reserved - IANA - TestNet2" list=Unrouted
/ip firewall address-list add address=203.0.113.0/24 comment="Reserved - IANA - TestNet3" list=Unrouted
/ip firewall address-list add address=192.168.0.0/16 comment="Private class C" list=Unrouted

# De firewall regels
/ip firewall filter add action=accept chain=input in-interface=combo1.100 protocol=icmp
/ip firewall filter add action=accept chain=input connection-state=established,related in-interface=combo1.100
/ip firewall filter add action=drop chain=input in-interface=combo1.100 protocol=tcp
/ip firewall filter add action=drop chain=input in-interface=combo1.100 protocol=udp
/ip firewall filter add action=accept chain=forward disabled=yes in-interface=bridge1252 src-address-list=IoT-Allow-internet
/ip firewall filter add action=drop chain=forward disabled=yes in-interface=bridge1252
/ip firewall filter add action=drop chain=forward comment="Drop to unrouted addresses list" in-interface=combo1.100 src-address-list=Unrouted
/ip firewall filter add action=drop chain=forward comment="Drop all from WAN not DSTNATed" connection-nat-state=!dstnat connection-state=new in-interface=combo1.100

# Deze reeksen zijn overgenomen uit KPN configuraties. Ik weet niet of deze nodig zijn.
/ip firewall nat add action=masquerade chain=srcnat comment="Needed for IPTV" dst-address=213.75.112.0/21 out-interface=combo1.101
/ip firewall nat add action=masquerade chain=srcnat comment="Needed for IPTV" dst-address=217.166.0.0/16 out-interface=combo1.101
/ip firewall nat add action=masquerade chain=srcnat src-address=10.218.0.0/16
/ip firewall nat add action=masquerade chain=srcnat src-address=192.168.218.0/24
/ip firewall nat add action=masquerade chain=srcnat src-address=192.168.251.0/24

# IGMP Routering tussen 1251 en combo1.101
/routing igmp-proxy set quick-leave=yes
/routing igmp-proxy interface add alternative-subnets=0.0.0.0/0 interface=combo1.101 upstream=yes
/routing igmp-proxy interface add interface=bridge1251

# NTP Settings. Hiervoor is het NTP Package nodig op de Mikrotik.
/system clock set time-zone-name=Europe/Amsterdam
/system ntp client set enabled=yes primary-ntp=193.78.240.12 secondary-ntp=130.89.0.19
/system ntp server set enabled=yes manycast=no
