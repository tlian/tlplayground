#!/usr/bin/env python

# Copyright:: 2017, Salesforce, All Rights Reserved.

import subprocess
import argparse
import sys
import exceptions
import json
from time import sleep

def parse_arg():
    """
       Parse command line argument
    """
    parser = argparse.ArgumentParser(
                                     description='Add a machine to maas server.')
    parser.add_argument('path_to_csv_file',
                        help='path to csv file')
    parser.add_argument('path_to_apikey',
                        nargs='?',
                        const=1,
                        type=str,
                        default='/home/ubuntu/apikey',
                        help='path to MAAS apikey')
    args = parser.parse_args()

    if not args.path_to_csv_file.endswith(".csv"):
        raise parser.error("csv file ends witht .csv")

    return args


class MaasUtil():
    """
       Main class
    """
    def __init__(self, path_to_csv_file,
                 path_to_apikey="/home/ubuntu/apikey",
                 maas_url=None,
                 login_profile_name='cloginprofile'):
        if not path_to_csv_file.endswith(".csv"):
            exceptions.NameError("CSV file must end with .csv")
        self.path_to_csv_file = path_to_csv_file
        self.path_to_apikey = path_to_apikey
        self.maas_url = maas_url
        self.login_profile_name = login_profile_name
        if self._maas_login():
            exceptions.RuntimeError('Maas Login failed!')

    def _run_cmd(self, cmd, echo=False):
        """ 
           Run cmd
        """
        if echo:
            print cmd
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        out, err = proc.communicate()
        rc = proc.returncode

        return rc, out, err

    def _prep_sysdata(self):
        """
           Read csv file of systems info and prep a python dict of systems.
        """
        systems = []
        with open(self.path_to_csv_file, "r") as f:
            sysdata = f.readlines()

        header = sysdata.pop(0)
        header = header.split(',')

        for asys in sysdata:
            asystem = {}
            keys = asys.split(',')
            for name,key in zip(header, keys):
                asystem[name.strip()] = key.strip()
            systems.append(asystem)

        return systems

    def _maas_login(self):
        """
           Login to MAAS server.
        """
        maas_url = self.maas_url if self.maas_url else "http://localhost:5240/MAAS/api/2.0/"

        with open(self.path_to_apikey, "r") as f:
            apikey = f.readline().strip()

        if not len(apikey.split(':')) == 3:
            print "apikey is comprised of 3 strings deliminated by colon ':' Aborting!"
            sys.exit()

        cmd = ['maas',
               'login',
               self.login_profile_name,
               maas_url,
               apikey
              ]
        rv, out, err = self._run_cmd(cmd)

        return rv

    def _macN_macA(self, macnum):
        """
           Convert MAC number to MAC address
           param:: macnum
        """
        return ':'.join(s.encode('hex') for s in macnum.decode('hex'))

    def get_nodes(self):
        """ 
        List nodes 
        return: a list of all nodes visible to user
        """
        cmd = ['maas',
                self.login_profile_name,
                'nodes',
                'read'
              ]
        rc, out, err = self._run_cmd(cmd)
        nodes = json.loads(out)
        return nodes

    def _get_system_id(self, hostname):
        """
        Get system_id of a server (hostname in MAAS)
        return: system_id
        """
        nodes = self.get_nodes()
        for n in nodes:
            if n["hostname"] == hostname:
                return n["system_id"]
        return None

    def _get_nodes_by_hostname(self):
        """
        Create a list that contains all servers by hostname.
        return: all servers by hostname only
        """
        nodes_by_hostname = []
        nodes = self.get_nodes()
        for n in nodes:
            nodes_by_hostname.append(n["hostname"])
        return nodes_by_hostname

    def _map_nodes_to_systemid(self):
        """
        Map each node -> system_id
        Return a dictionary of 
            {"hostname": "system_id"}
        """
        nodes_with_system_id = {}
        nodes = self.get_nodes()
        for n in nodes:
           nodes_with_system_id[n["hostname"]] = n["system_id"]
        return nodes_with_system_id

    def _map_node_to_interfaces(self):
        """
        Map each node -> ent interfaces
        return: a dictionary of 
                {"node_hostname": [{}, {}, ...]}
        """
        nodes_with_interfaces = {}
        nodes = self.get_nodes()
        for n in nodes:
            nodes_with_interfaces[n["hostname"]] = n["interface_set"]
        return nodes_with_interfaces

    def _map_ethX_to_mac_of_host(self, hostname):
        """
        Return a dictionary of mapping ethX -> mac_address of a machine.
            {"ethX": "01:02:03:04:05:06"}
        """
        ethX_with_mac = {}
        for itf in self._map_node_to_interfaces()[hostname]:
            ethX_with_mac[itf["name"]] = itf["mac_address"]
        return ethX_with_mac

    def get_interfaces(self, system_id):
        """
        List all interfaces attached to a machine.
        param:: system_id: system id of a machine.
        """
        cmd = ['maas',
               self.login_profile_name,
               'interfaces',
               'read',
               system_id
              ]
        rc, out, err = self._run_cmd(cmd)
        interfaces = json.loads(out)
        return interfaces

    def _get_ethX_id(self, system_id, ethX):
        """ 
        Get the id of an eth interface.
        return: the ID of an ethX. None if not found
        """
        interfaces = self.get_interfaces(system_id)
        for itf in interfaces:
            if itf["name"] == ethX:
                return interfaces[interfaces.index(itf)]["id"]
        return None

    def add_machines(self):
        """ Add new machines to MAAS server """
        systems = self._prep_sysdata()
        cmd = ['maas',
               self.login_profile_name,
               'machines',
               'create'
              ]

        # extract required parameters off each system
        for s in systems:
            del cmd[4:]
            cmd.append('hostname=' + s.get('server_name', ''))
            if s['lo_mac'] == 'n/a':
                 print "SKIPPING LO_MAC OF N/A: ", s.get('serialnumber')
                 continue
            cmd.append('mac_addresses=' + self._macN_macA(s['lo_mac']))
            cmd.append('architecture=' + s.get('architecture', 'amd64'))
            cmd.append('subarchitecture=' + s.get('subarchitecture', 'generic'))
            cmd.append('domain=' + s.get('domain', 'maas'))
            cmd.append('power_type=' + s.get('power_type', 'manual'))
            for n in range(1, 7):
                try:
                    cmd.append('mac_addresses=' + self._macN_macA(s['nic' + str(n) + 'mac']))
                except:
                    continue
            # Try adding a new machine
            try:
                rc, out, err = self._run_cmd(cmd)
                if rc:
                    print err
                print out
            except:
                continue

    def mark_machine_broken(self, hostname):
        """
        Mark a machine broken.
        """
        cmd = ['maas',
               self.login_profile_name,
               'machine',
               'mark-broken',
               self._map_nodes_to_systemid()[hostname]
              ]
        rc, out, err = self._run_cmd(cmd)
        sleep(5)
        return (rc, out, err)

    def create_bond(self, *args, **kwargs):
        """ 
        Create bond.
        param:: *args: (required)  eth interface names 
        param:: **kwargs: other keyword arguments      
                (required) system_id, name, mac_address
                (optional) tags, vlan, bond_mode, bond_miimon,
                           bond_downdelay, bond_updelay, bond_lacp_rate,
                           bond_xmit_hash_policy, mtu
        system_id: Machine system_id in MAAS
        name: Name of the bond to be created
        mac_address: One of the mac_address of eth interfaces to be bonded
        Example:
           create_bond('eth1', 'eth3',
                       system_id="abcd", name="testbond",
                       mac_address="01:02:03:04:05:06")
        """
        system_id = kwargs["system_id"]
        cmd = ['maas',
               self.login_profile_name,
               'interfaces',
               'create-bond',
               system_id
              ]   
        for key, value in kwargs.iteritems():
            if not key == "system_id":
                cmd.append(key + '=' + value)
        for eth in args:
            cmd.append('parents=' + str(self._get_ethX_id(system_id, eth)))
        rc, out, err = self._run_cmd(cmd)

        return (rc, out, err)

    def create_default_bonds(self):
        """
        This method is to create 2 default bonds on each host.
        ONLY call it for such need.
        "HB" bond       "PROD" bond
        (eth1 + eth3)   (eth2 + eth4)
        """
        for host in self._get_nodes_by_hostname():
            # Get system_id and mac_address
            system_id = self._map_nodes_to_systemid()[host]
            try:
                eth1_mac = self._map_ethX_to_mac_of_host(host)['eth1']
                eth2_mac = self._map_ethX_to_mac_of_host(host)['eth2']
            except KeyError, e:
                print "Skipping Warning: %s does NOT have %s " % (host, e)
                continue
            # For each host, creat 2 bond: hb_bond and prod_bond
            rc, out, err = self.create_bond('eth1', 'eth3', system_id=system_id,
                                          name="hb_bond", mac_address=eth1_mac)
            print (host, json.loads(out))
            rc, out, err = self.create_bond('eth2', 'eth4', system_id=system_id,
                                          name="prod_bond", mac_address=eth2_mac)
            print (host, json.loads(out))


if __name__ == "__main__":
    args = parse_arg()
    mu = MaasUtil(args.path_to_csv_file, args.path_to_apikey)
    # Add all machines in CSV file
    mu.add_machines()
    # Create default bonds
    # Machines has to be in "Ready" or "Broken" state to create bond
    # Temporary workaround: mark it "Broken"
    for host in mu._get_nodes_by_hostname():
        mu.mark_machine_broken(host)
    mu.create_default_bonds()

