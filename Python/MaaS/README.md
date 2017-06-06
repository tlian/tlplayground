# MAAS UTIL
## Description
Python utility to hit MAAS api leveraging MAAS CLI on a MAAS server.
This utility is to run on a MAAS server to

    - Add/Register new machines
    - Create eth bonds
    - Mark a machine "broken"
    - etc.,


## Usage
####Example 1

Run the script as the following on the MAAS server.

    python maasutil.py [path-to-file.cvs] [path-to-apikey]

path-to-apikey is set default to /home/ubuntu/apikey if not provided.

####Example 2
```python
>>> from maasutil import MaasUtil

>>> mu = MaasUtil("test.csv", "apikey")

>>> nodes = mu.get_nodes()

>>> # See individual node

>>> nodes[0]

>>> mu._map_nodes_to_systemid()

{u'ATL1P06c5vm04': u'y437wc', u'ATL1P06c5vm02': u'rhpx67', u'ATL1P06c5vm03': u'rd4ncq', u'ATL1P06c5vm01': u'cabkra', u'falam': u'tbdyec', u'ubuntu-xenial': u'fcxser'}

>>> # Get all nic interfaces attached to 'system_id'

>>> mu.get_interfaces('y437wc')

>>> # Add all machine provided in CSV file

>>> mu.add_machines()

>>> mu.mark_machine_broken("ATL1P06c5vm04")
```
