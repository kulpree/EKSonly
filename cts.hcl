#general
log_level = "INFO"
port = 8558
syslog {}
license_path = "/home/ubuntu/"
buffer_period {
  enabled = true
  min = "5s"
  max = "20s"
}

#Consul connection
consul {
  address = "xxx.us-east-1.elb.amazonaws.com:443"
  token = "ff491022-xxx"
  tls {
  enabled = true
  verify = true
  ca_cert = "/home/ubuntu/consul-agent-ca.pem"
  cert = "/home/ubuntu/dc1-client-consul-1.pem"
  key = "/home/ubuntu/dc1-client-consul-1-key.pem"
  server_name = "localhost"
}
}

task {
 name        = "reinvent-demo-ELB"
 description = "Add instance to ELB"
 source      = "github.com/ramramhariram/underlay"
 services    = "[nginx-1, nginx-2]"
 variable_files = "/home/ubuntu/elb_name.tfvars"
}


#TF CLOUD driver details
driver "terraform-cloud" {
  hostname     = "https://app.terraform.io"
  organization = "hsankaran"
  token        = "xx"
}

