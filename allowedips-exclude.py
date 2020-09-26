#!/usr/bin/env python3

from ipaddress import ip_network

start = '10.100.0.0/16'

exclude = ['10.100.0.254', '10.100.2.2']

result = [ip_network(start)]

for x in exclude:
    new = []
    for y in result:
        if y.overlaps(ip_network(x)):
            new.extend(y.address_exclude(ip_network(x)))
        else:
            new.append(y)
    result = new
    
print(','.join(str(x) for x in sorted(result)))