<h3 align="center">
    <img src="https://i.ibb.co/ZpFPVcK7/honeybee.png" alt="bzzz" border="0"><br/>
    <code>BeeHive</code>
</h3>

Mono repository for my (yet to scale) homelab cluster, built using <i><b>Bee</b></i>link mini PCs. Trying to use GitOps methodologies and tools such as [Flux ↗](https://fluxcd.io/), [Git(ea) ↗](https://about.gitea.com/) and [Talos ↗](https://www.talos.dev/).

## 🖥️ Hardware

| Device | OS Disk Size | Data Disk Size | Ram | OS | Function |
|:-------|:-------------|:---------------|:---:|:--:|:--------:|
| Beelink SER5 | 128GiB | / | 16GiB | ProxMox VE | <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/proxmox-light.png" width="16" height="16"> Hypervisor |
| NAS | 256GiB | 4+2 TiB | 16GiB | TrueNAS Scale | <img src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/truenas.png" width="16" height="16"> Storage Backend |
| Ubiquiti USG | 2GiB | / | 512MiB | EdgeOS | <img src="https://raw.githubusercontent.com/aci686/Network-Icons-SVG/refs/heads/master/generic-router-colour.svg" width="16" height="16"> Gateway |
| Mikrotik hEX PoE | 16MiB | / | 128MiB | RouterOS | <img src="https://raw.githubusercontent.com/aci686/Network-Icons-SVG/refs/heads/master/generic-switch-l3-colour.svg" width="16" height="16"> Switch |
| Ubiquiti U6W | / | / | / | / | 🛜 Access Point |
| Ubiquiti U6 Pro | / | / | / | / | 🛜 Access Point |

## 🖥️ Virtual Resources

### TALOS Cluster

|  Name  | OS Disk Size | Ram | Function |
|:-------|:-------------|:---:|:--------:|
|talos-cp-101|32GiB|8GiB|<img src="https://raw.githubusercontent.com/kubernetes/kubernetes/refs/heads/master/logo/logo.png" width="16" height="16"> K8s control-plane|
|talos-wp-102|32GiB|8GiB|<img src="https://raw.githubusercontent.com/kubernetes/kubernetes/refs/heads/master/logo/logo.png" width="16" height="16"> K8s worker node|

## 📁 Structure

The project repository is structured as follow:

- ☸️ `kubernetes`: this directory is the Flux baseline and reflects the cluster desired state.
- 🛠️ `infrastructure`: this directory contains the assets to provision and support the infrastructure using code.

The project structure is still in development and may be subject to changes or additions.

## Acknowledgments

- Kubernetes icons by [Kubernetes ↗](https://github.com/kubernetes)
- Router and Switch icon by [aci686/Network-Icons-SVG ↗](https://github.com/aci686/Network-Icons-SVG)

Thanks to [imgios ↗](https://github.com/imgios) and its fantastic [pi3s repo↗](https://github.com/imgios/pi3s) that I peeked a bit 👀