#1 - use eks_authorize file to get eks creds 
2 - install consul on EKS - 
    helm install AWS hashicorp/consul -f eks.yaml --timeout 10m --version "0.32.1" (basic YAML config would do - this is a server only infra) 
    
3 - install CTS first 
  Follow Learn docs 

4 - If using acl tokens, configure that appropriately for CTS as well as all the clients. 

4 - For TLS, install tls certs for CTS, and all clients (NGINX)
  FOllow learn docs

5 - Install nginx servers on both client machines. 

6 - Grab tokens for correct tfcb workspace (or use local TF and provide appropraite permissions) 

7 - make sure right security groups are applied. 



