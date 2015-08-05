# mlvagrant

Scripts for bootstrapping a local MarkLogic cluster for development purposes using [Vagrant](https://www.vagrantup.com/) and [VirtualBox](https://www.virtualbox.org/).

By default these scripts create 3 'chef/centos-6.5' Vagrant vms, running in VirtualBox. The names and ips will be recorded in /etc/hosts of host and vms. MarkLogic (including dependencies) will be installed on all three vms, and bootstrapped to form a cluster. MLCP, Zip/Unzip, Nodejs, Gulp, Forever, and Git will be installed, and configured. A bare git repository will be prepared in /space/projects. All automatically with just a few commands.

Each VM takes roughly 2.5Gb. The VM template, together with 3 VMs will take about 10Gb of disk space. In addition, each VM that is launched will claim 2Gb of RAM, and 2 CPU cores. Make sure you have sufficient resources!

Credits to [@peetkes](https://github.com/peetkes) and [@miguelrgonzalez](https://github.com/miguelrgonzalez) for giving me a head start with this.

## Getting started

You first need to download and install prerequisites and mlvagrant itself:

- Download and install [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
- Download and install [Vagrant](https://www.vagrantup.com/downloads.html)
- Create /space/software (`sudo mkdir -p /space/software`)
  - **For Windows**: (`c:\space\software`)
- Download [MarkLogic 8.0-3 for CentOS](http://developer.marklogic.com/products) (login required)
- Download [MLCP 1.3-3 binaries](http://developer.marklogic.com/download/binaries/mlcp/mlcp-1.3-3-bin.zip)
- Move MarkLogic rpm, and MLCP zip to /space/software (no need to unzip MLCP!)
- Download mlvagrant (`git clone https://github.com/grtjn/mlvagrant.git`)
- Create /opt/vagrant (`sudo mkdir -p /opt/vagrant`)
  - **For Windows**: (`c:\opt\vagrant`)
- Copy mlvagrant/opt/vagrant to /opt/vagrant

Above steps need to taken only ones. For every project you wish to create VMs, you simply take these steps:

- Create a new project folder with a short name without spaces ('vgtest' for instance)
- Copy mlvagrant/project/Vagrantfile to that folder
- Open a Terminal or command-line in that folder
- Run:
  - `vagrant plugin install vagrant-hostmanager`
  - `vagrant up --no-provision` (may take a while depending on bandwidth, particularly first time)
  - `vagrant provision` (may take a while, enter sudo password when asked, to allow changing /etc/hosts)

That is all that is necessary to create a fully-prepared 3-node MarkLogic cluster running on CentOS 6.5 VMs. It takes the name of the project folder as prefix for the host names, to make running projects in parallel easier. If you ran the above in a folder called 'vgtest', it will have created three nodes with the names:

- vgtest-ml1 (cluster master)
- vgtest-ml2
- vgtest-ml3

To gain ssh access to the first, you do:

- `vagrant ssh vgtest-ml1`

To take one host down you do:

- `vagrant halt vgtest-ml2`

To take down all you do:

- `vagrant halt`

To destroy all VMs (maybe to recreate them from scratch):

- `vagrant destroy`

## Pushing project code with git

A local git repository with a post-receive hook is initialized for you, together with a user-account for it. All you need to do to push any git repository onto the server is (assuming project name 'vgtest'):

- `git remote add vm vgtest@vgtest-ml1:/space/projects/vgtest.git`
- `git push vm`

The name of the user is derived from the folder name. The password is initialized to equal the user name, but can be changed if desired through:

- `vagrant ssh vgtest-ml1`
- `sudo passwd vgtest`

## Customizing bootstrap

The Vagrantfile contains five variables:

- `ml_version`, defaults to '8.0-3'
- `nr_hosts`, defaults to 3
- `ml_memory`, defaults to 2048
- `ml_cpus`, defaults to 2
- `ml_dr`, defaults to false

The minimum number of hosts is 1, the maximum is limited mostly by the local resources you have available. Each vm will take 2.5Gb of disk space, and by default (also in the Vagrantfile) takes 2Gb of ram, and 2 CPU cores.

Note: although you can technically create a cluster of just 2 nodes, 3 nodes is required for proper fail-over. The cluster needs a quorum to vote if a host should be excluded.

The vagrant file makes use of a project.properties file in which you can override the variables used in the Vagrantfile.

