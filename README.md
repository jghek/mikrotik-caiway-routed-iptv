# Mikrotik configuratie voor CAIWAY via Glasvezel Buitenaf
Deze basis-configuratie gebruik ik op een [CCR1009-7G-1C-1S+ Mikrotik Cloud Core Router](https://mikrotik.com/product/CCR1009-7G-1C-1SplusPC), op RouterOS 6.45.7. Naar verwachting gaat dit ook prima werken met goedkopere modellen. Eén verschil is wel dat dit model geen switch chip kent en daarom mogelijk enkele tweaks nodig heeft om het geheel efficient aan het werk te krijgen.

## Waarschuwing!
Dit is niet simpel. De standaard Genexis router is vrij beperkt, maar de meeste dingen kun je er prima mee doen. Als je deze router wilt vervangen, kun je dat doen omdat jouw netwerkconfiguratie wat meer vereist (tunnels, meerdere lokale netwerken, dual/fallback isp), of omdat dubbel NAT gewoon jeukt en je het net erg vind dat je vrienden je een beetje raar vinden. Je dient wel het één en ander van netwerken te begrijpen. Anders niet aan beginnen.

# Wat levert CAIWAY
CAIWAY levert een [GENEXIS Platinum 7840](https://nl.hardware.info/routers.9/genexis-genexis-platinum-7840.534715) router. Deze zit op de glas aangesloten met een [Genexis SFP module (1Gb/s)](https://en.wikipedia.org/wiki/Small_form-factor_pluggable_transceiver). Deze SFP zit verstopt op de achterkant achter een klepje met een blauwe garantie sticker. Op de verbinding leveren ze twee VLANs:

| VLAN | Techniek | Beschrijving |
| --- | --- | --- |
| 100 | DHCP | Internet |
| 101 | DHCP (optie 60 vereist) | IPTV |

Misschien is er nog één voor telefonie, maar dat gebruik ik niet.

# Aansluiten
De Genexis SFP module werkte niet in de Mikrotik. Ik heb het opgelost door de SPF in een HP1920-24G (mijn LAN switch met 4 SFP slots) en een SFP direct attach kabel van de switch naar de mikrotik te leggen. Op de switch dien je dan wel beide aansluitingen te configureren om VLAN 100 en 101 tagged te gebruiken. In plaats van een switch is een mediaconvertor (SFP<->RJ45) ook mogelijk. Deze direct attach SFP kabel is aangesloten op de SFP/Combo1 poort. Mocht de Mikrotik later wel de SFP gaan ondersteunen, dan kan ik hem rechtstreeks plaatsen zonder configuratie aanpassingen. Verder gebruik ik ether7 als de verbinding naar mijn HP switch, later wil ik dit doen via de SFP+ poort (10Gb/s) als ik een switch heb die dit aan kan (en het zinvol is). De AMINO STBs zijn aangesloten op ether4 en ether5.

# Netwerkinrichting
In deze configuratie ga ik uit van de volgende inrichting:

| VLAN | Netwerk | Beschrijving |
| --- | --- | --- |
| 10 | 10.218.0.1/16 | Mijn netwerk voor kinderen en gasten. Gebruikt OpenDNS servers om ongewenste inhoud te filteren en een /16 reeks om veel DHCP leases aan te kunnen. |
| 1218 | 192.168.218.1/24 | Mijn thuis netwerk. |
| 1251 | 192.168.251.1/24 | Mijn IPTV LAN. Hierbinnen zitten de AMINO tv boxes. Mochten ze gehackt worden, dan zitten ze niet in mijn thuis LAN. |

# Overige bijzonderheden
Bij upgrade naar een nieuwe RouterOS heb ik er voor gekozen ook de NTP Server package te installeren. Hiermee is de router ook een NTP Server. In de configuratie zitten er verwijzingen naar.

# De configuratie
Hieronder volgt de configuratie met uitleg. Je kunt de config ook zonder commentaar [openen](basic-191118.rsc).

```
# Het maken van de L2 segmenten (bridges). IGMP snooping moet aan staan op ons IPTV LAN.
/interface bridge add name=bridge10
/interface bridge add fast-forward=no name=bridge1218 protocol-mode=none
/interface bridge add arp=proxy-arp fast-forward=no igmp-snooping=yes name=bridge1251 protocol-mode=none

# Geen STP (spanning-tree) pakketten naar de provider
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

# AMINO boxes
/interface bridge port add bridge=bridge1251 interface=ether4
/interface bridge port add bridge=bridge1251 interface=ether5

# VLANs naar de switch
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

# DHCP Clients: Op welke L2 segmenten gaan we via DHCP een IP adres opvragen en met welke opties?
/ip dhcp-client add dhcp-options=hostname,clientid disabled=no interface=combo1.100
/ip dhcp-client add default-route-distance=210 dhcp-options=IPTV_RG,hostname,clientid disabled=no interface=combo1.101 use-peer-dns=no use-peer-ntp=no

# DHCP Server voor gasten gebruikt OpenDNS adressen.
/ip dhcp-server network add address=10.218.0.0/16 dns-server=208.67.222.123,208.67.220.123 domain=guest.local gateway=10.218.0.1 ntp-server=10.218.0.1 netmask=24
/ip dhcp-server network add address=192.168.218.0/24 dns-server=192.168.218.1 domain=hek.local gateway=192.168.218.1 ntp-server=192.168.218.1 netmask=24
/ip dhcp-server network add address=192.168.251.0/24 dhcp-option-set=IPTV dns-server=192.168.251.1 domain=iptv.local gateway=192.168.251.1 ntp-server=192.168.251.1 netmask=24

# Onze router zal DNS request beantwoorden en fungeert daarmee als interne DNS server.
/ip dns set allow-remote-requests=yes cache-max-ttl=1d servers=8.8.8.8,8.8.4.4

# Deze reeksen mogen niet op internet voorkomen, omdat het private ranges zijn of test reeksen.
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
/ip firewall nat add action=masquerade chain=srcnat comment="IPTV" dst-address=213.75.112.0/21 out-interface=combo1.101
/ip firewall nat add action=masquerade chain=srcnat comment="IPTV" dst-address=217.166.0.0/16 out-interface=combo1.101
/ip firewall nat add action=masquerade chain=srcnat src-address=10.218.0.0/16
/ip firewall nat add action=masquerade chain=srcnat src-address=192.168.218.0/24
/ip firewall nat add action=masquerade chain=srcnat src-address=192.168.251.0/24

# IGMP Proxy tussen 1251 en combo1.101, de kern van de IPTV routed configuratie. Hiermee geen IGMP (tv beeld) pakketten via VLAN101 naar CAIWAY.
/routing igmp-proxy set quick-leave=yes
/routing igmp-proxy interface add alternative-subnets=0.0.0.0/0 interface=combo1.101 upstream=yes
/routing igmp-proxy interface add interface=bridge1251

# NTP Settings. Hiervoor is het NTP Package nodig op de Mikrotik.
/system clock set time-zone-name=Europe/Amsterdam
/system ntp client set enabled=yes primary-ntp=193.78.240.12 secondary-ntp=130.89.0.19
/system ntp server set enabled=yes manycast=no
```
