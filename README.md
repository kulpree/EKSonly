# Repeated EKS automated deployment
This module is for deploying 1 or more EKS clusters automtically using count

# Note: 
There are two optional modules referred to herewithin - one is to install Consul on the EKS cluster and another to deploy Hashicups and register it with Consul SM.

# Pre-reqs: 

1 - AWS account with admin access (doormat accounts do work) 

2 - Check Provider.tf for AWS provider requirements. 

3 - TF version used - 1.5.3 

4 - EKS version used - Latest by default, although version could be hardcoded in the aws_eks_cluster module. 


# Warnings: 
The security related resources inside this module may not be production grade, please review and update as needed if using in Production. 

# To use the module 

1 - Check tfvars files for all the variables, the count variable is the most important as this dictates how many EKS clusters and its associated components will be deployed. 

2 - Locals.tf files has some common tags, update as necessary. 

3 - Once deployed, use the command in 'notes-impcommands' to pull the eks creds into your local kube config. 


# OPTIONAL MODULE 1: 
To verify if your EKS deployment is good, you may optionally use the module below to install Consul and confirm. Deploy Consul on Kubernetes cluster
(NOTE - These optional modules may have additional pre-reqs, warnings, please refer to that module's readme for further info)

# Deploy Consul on Kubernetes cluster 
1. Clone this repo
```
git clone https://github.com/ramramhariram/Consul-Envoyextensions-Propertyoverride.git
```

2. Nagivate to the correct folder. 

```
cd Consul-Envoyextensions-Propertyoverride
```

3. If you have multiple clusters, ensure you are in the current kubernetes cluster context 


4. Add Consul Ent license as a K8s secret - 

```
export CONSUL_LICENSE=<ADD_YOUR_LICENSE_HERE>
```

```
kubectl create secret generic license --from-literal=key=$CONSUL_LICENSE
```
5 - Ensure you have the correct consul-k8s cli version. Or the correct helm repo if using helm. 
  
  https://developer.hashicorp.com/consul/docs/k8s/installation/install-cli#install-a-previous-version (while it says previous version, you can use these instructions to install newer/RC versions too)

  To install consul - 

  ```
  consul-k8s install --config-file 1.16-servers.yaml -set chart.version=1.2.0
  ```
  Note - Whether you use consul-k8s or helm, it is always a good practise to set the chart version, especially when working with RC or dev releases.  
  Note - documentation on how to install a specific consul-k8s version of cli (brew may not work in some cases) - 

6 - If you want to ensure the correct version of consul was installed (app version) or if you run into any issues with the install , run the following command to confirm.

  ```
  consul-k8s status
  ```
  

7 - Confirm that consul was installed properly.  You can do kubectl get pods to ensure all the required pods are running. Like this - 

  ```
  kubectl get pods -n consul
  ```

  ```
  NAME                                          READY   STATUS    RESTARTS   AGE
  consul-connect-injector-7dff465dd9-srlj6      1/1     Running   0          2d
  consul-mesh-gateway-6bfd4c9779-29vjn          1/1     Running   0          2d
  consul-mesh-gateway-6bfd4c9779-6vv7h          1/1     Running   0          2d
  consul-mesh-gateway-6bfd4c9779-hkfs5          1/1     Running   0          2d
  consul-server-0                               1/1     Running   0          2d
  consul-server-1                               1/1     Running   0          2d
  consul-server-2                               1/1     Running   0          2d
  consul-webhook-cert-manager-594bd484d-qg74k   1/1     Running   0          2d
  hari@hari-C02FQABCMD6R 1.16 %
  ```

  Note: I installed consul in the Kubernetes 'consul' namespace - this is usually default and recommended in all Hashicorp tutorials. Ensure you use the correct namespace when confirming your kubernetes resources for consul. 

  You could also do kubectl get services to find the consul UI service and login to it. 

  ```
  kubectl get services -n consul
  ```

  ```
  NAME                      TYPE           CLUSTER-IP       EXTERNAL-IP                                                               PORT(S)                                                                            AGE
  consul-connect-injector   ClusterIP      172.20.108.249   <none>                                                                    443/TCP                                                                            2d
  consul-dns                ClusterIP      172.20.232.104   <none>                                                                    53/TCP,53/UDP                                                                      2d
  consul-expose-servers     LoadBalancer   172.20.16.28     a3c2511965bce49dab61714510895ed6-573732255.us-east-1.elb.amazonaws.com    8501:31315/TCP,8301:30386/TCP,8300:31611/TCP,8502:31056/TCP                        2d
  consul-mesh-gateway       LoadBalancer   172.20.153.3     a15b798ce94984c0dbcac72a42564a92-902760553.us-east-1.elb.amazonaws.com    443:30773/TCP                                                                      2d
  consul-server             ClusterIP      None             <none>                                                                    8501/TCP,8502/TCP,8301/TCP,8301/UDP,8302/TCP,8302/UDP,8300/TCP,8600/TCP,8600/UDP   2d
  consul-ui                 LoadBalancer   172.20.211.48    a7c20168155c74ebf9f518248487ead4-1227175163.us-east-1.elb.amazonaws.com   443:30515/TCP                                                                      2d
  hari@hari-C02FQABCMD6R 1.16 %
  ```

 Note: use this to get the bootstrap token if you want to see everything in the consul ui - 

 ```
 export CONSUL_HTTP_TOKEN=$(kubectl get --namespace consul secrets/consul-bootstrap-acl-token --template={{.data.token}} | base64 -d)
 ```

 And then to get the actual value of the token for use

 ```
 echo $CONSUL_HTTP_TOKEN 
 ```
 Disclaimer: This is for dev/test environments, not an official recommendation for Production. 

  You should be able to login to your UI with this boostrap token to view everything. Now time to set up a few services for our service mesh deployment. 


# OPTIONAL MODULE 2: Deploy Hashicups and register it with Consul on Kubernetes 

(NOTE - These optional modules may have additional pre-reqs, warnings, please refer to that module's readme for further info)


  1 - Clone this repo 

  ```
  git clone https://github.com/hashicorp-education/learn-consul-service-mesh-deploy.git
  ```

  And from that folder, apply just the hashicups configurations as follows - 

  ```
  k apply -f learn-consul-service-mesh-deploy/hashicups
  ```
  The above command should install the application into the default K8s namespace. You can also deploy into a specific namespace if you so choose. 

  2 - Confirm the services are live by running kubectl get services like - 


  ```
  kubectl get pods
  ```

  ```
  hari@hari-C02FQABCMD6R 1.16 % 
  NAME                            READY   STATUS    RESTARTS   AGE
  frontend-f74f5f4d4-69zf7        2/2     Running   0          2d3h
  nginx-7548559b87-6nls9          2/2     Running   0          2d3h
  payments-5d4fdd6c76-xshrr       2/2     Running   0          2d3h
  postgres-58c9cff4d9-5n28p       2/2     Running   0          2d3h
  products-api-7889bb5479-zwkbz   2/2     Running   0          2d3h
  public-api-79f78675f6-2pc4w     3/3     Running   0          2d3h
  hari@hari-C02FQABCMD6R 1.16 
  ```

  Or check all the services like this - 

  ```
  kubectl get services
  ```

  ```
  % 
  NAME           TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
  frontend       ClusterIP   172.20.211.247   <none>        3000/TCP   2d3h
  kubernetes     ClusterIP   172.20.0.1       <none>        443/TCP    2d5h
  nginx          ClusterIP   172.20.200.91    <none>        80/TCP     2d3h
  payments       ClusterIP   172.20.156.214   <none>        1800/TCP   2d3h
  postgres       ClusterIP   172.20.124.227   <none>        5432/TCP   2d3h
  products-api   ClusterIP   172.20.159.26    <none>        9090/TCP   2d3h
  public-api     ClusterIP   172.20.107.182   <none>        8080/TCP   2d3h
  hari@hari-C02FQABCMD6R 1.16 %

  ```


