# WEKA-GCP Cluster Toolkit integration

An external module for deploying a WEKA file system with [Google Cloud's Cluster toolkit](https://cloud.google.com/cluster-toolkit/docs/overview).

## License and Support
This repository is licensed for use under a [3-Clause BSD Open Source license](./LICENSE) so that you can use this resource to experiment with deploying your own complex high performance computing infrastructure on Google Cloud. Fluid Numerics offers expert support to help you design, deploy, and manage performant and cost-effective infrastructure on Google Cloud to support high performance computing and AI/ML workloads. Learn more at https://www.fluidnumerics.com/services or reach out to support@fluidnumerics.com .

## Overview
WEKA provides a terraform module for deploying a [parallel WEKA filesystem on Google Cloud Platform](https://github.com/weka/terraform-gcp-weka). This repository is meant to provide a clean integration with [Google Cloud's Cluster Toolkit](https://cloud.google.com/cluster-toolkit/docs/overview). Specifically, we aim to provide a minimal terraform module for deploying a WEKA filesystem in a dedicated backend architecture. Additionally, we provide example cluster toolkit deployments that integrate WEKA with [Slurm-GCP](https://github.com/) following [WEKA's best practices](https://docs.weka.io/v/4.2/best-practice-guides/weka-and-slurm-integration).


## Example

### Summary
In this section, we walk through a simple example deployment that is included in this repository

> [!IMPORTANT]
> Before proceeding, you need to have the following components installed on your workstation:
>
> - [`gcloud` CLI](https://cloud.google.com/sdk/docs/install)
> - [Google Cloud Cluster Toolkit](https://cloud.google.com/cluster-toolkit/docs/overview)
> - [`terraform`](https://developer.hashicorp.com/terraform/install)
> - [`packer`](https://developer.hashicorp.com/packer/install)
>
> Additionally, you will need :
> 
> - A download token from [get.weka.io](https://get.weka.io)
> - A [Google Cloud project with active billing](https://developers.google.com/workspace/guides/create-project)

The Cluster Toolkit allows you to define complex architecture for high performance computing and AI/ML applications on Google Cloud in a single "blueprint" file in YAML syntax. This example uses the bluprint defined in [`aiml-slurmgcp6-weka4.yaml`](./example/aiml-slurmgcp6-weka4.yaml). This blueprint is used to create

- A virtual machine image built on top of the Slurm-GCP Rocky Linux 8 VM image that includes the WEKA agent software and adjustments described in [WEKA's Slurm integration guide](https://docs.weka.io/v/4.2/best-practice-guides/weka-and-slurm-integration)
- Networking infrastructure for VM image baking and cluster deployment
- A WEKA parallel filesystem consisting of six c2-standard-8 instances with each equipped with 2x 375GB NVME Local SSD's and four NIC's.
- Slurm controller (c2-standard-4) and login node (c2-standard-4) with WEKA filesystem mounted to `/home`
- Heterogeneous Slurm partition with VM instances equipped with A100 (a2-highgpu) and L4 (g2-standard) GPUs configured with Slurm [features](https://slurm.schedmd.com/sbatch.html#OPT_constraint) and additional memory set aside for the WEKA agent

Note that in this deployment, all Slurm instances have a single NIC and mount WEKA using UDP mode. If you would like to work with DPDK mounts and would like assistance, [please open an issue](https://github.com/FluidNumerics/weka-gcp-hpc-toolkit/issues/new).

### Walkthrough
1. Clone this repository and navigate to the `example/` directory

```
git clone https://github.com/FluidNumerics/weka-gcp-hpc-toolkit ~/weka-gcp-hpc-toolkit
cd ~/weka-gcp-hpc-toolkit/example
```

2. Edit the provided `aiml-slurmgcp6-weka4.yaml` blueprint file to specify the `project_id` and `get_weka_io_token`. The `project_id` is the Google Cloud project ID you wish to deploy your cluster to. The `get_weka_io_token` is your download token for the WEKA software obtained from [get.weka.io](https://get.weka.io). You may also wish to change the `region` and `zone`, but it is not required.

3. Use the Google Cloud Cluster toolkit to create the terraform infrastructure-as-code. This will create a subdirectory called `aiml-slurm6-weka4` that houses the [Packer](https://www.packer.io/) files for creating the VM image and [Terraform](https://www.terraform.io/) infrastructure-as-code for all of the other resources. This subdirectory will also contain a set of instructions `aiml-slurm6-weka4/instructions.txt` that provide an advanced set of steps for manually deploying the infrastructure.

> [!NOTE]
> The binary for the cluster toolkit may be called `gcluster` (newest), `ghpc`, or `hpc-toolkit`, depending on the version of the cluster toolkit you are using.

```
gcluster create aiml-slurmgcp6-weka4.yaml
```

4. Deploy the `primary` infrastructure that is needed to support the VM image baking process.

```
terraform -chdir=aiml-slurm6-weka4/primary init
terraform -chdir=aiml-slurm6-weka4/primary validate
terraform -chdir=aiml-slurm6-weka4/primary apply
gcluster export-outputs aiml-slurm6-weka4/primary
```

5. Create the VM image that will be used for your Slurm-GCP instances with the WEKA agent pre-installed.

```
gcluster import-inputs aiml-slurm6-weka4/packer
cd aiml-slurm6-weka4/packer/weka-enabled-image
packer init .
packer validate .
packer build .
cd -
```

6. Deploy the WEKA filesystem and Slurm-GCP cluster

```
gcluster import-inputs aiml-slurm6-weka4/cluster
terraform -chdir=aiml-slurm6-weka4/cluster init
terraform -chdir=aiml-slurm6-weka4/cluster validate
terraform -chdir=aiml-slurm6-weka4/cluster apply
```

Once complete, you will have a WEKA filesystem and autoscaling Slurm-GCP cluster in your Google Cloud project.

### Destroying resources
When you no longer need your resources, you can use the `gcluster` cli to delete all infrastructure

```
cd ~/weka-gcp-hpc-toolkit/example
gcluster destroy aiml-slurm6-weka4
```

If, instead, you prefer to destroy resources manually, keep in mind that all infrastructure should be destroyed in reverse order of creation:

```
terraform -chdir=aiml-slurm6-weka4/cluster destroy
terraform -chdir=aiml-slurm6-weka4/primary destroy
```


## Further Reading

- [Cluster toolkit Github](https://github.com/GoogleCloudPlatform/cluster-toolkit)
- [Slurm-GCP Controller](https://github.com/GoogleCloudPlatform/cluster-toolkit/tree/main/community/modules/scheduler/schedmd-slurm-gcp-v6-controller)
- [Slurm-GCP Login Node](https://github.com/GoogleCloudPlatform/cluster-toolkit/tree/main/community/modules/scheduler/schedmd-slurm-gcp-v6-login)
- [Slurm-GCP Compute Nodeset](https://github.com/GoogleCloudPlatform/cluster-toolkit/tree/main/community/modules/compute/schedmd-slurm-gcp-v6-nodeset)
- [Slurm-GCP Partition](https://github.com/GoogleCloudPlatform/cluster-toolkit/tree/main/community/modules/compute/schedmd-slurm-gcp-v6-partition)
- [WEKA and Slurm Integration Guide](https://docs.weka.io/v/4.2/best-practice-guides/weka-and-slurm-integration)
- [WEKA documentation](https://docs.weka.io)