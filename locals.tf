locals {
  # Common tags to be assigned to all resources
  common_tags = {
    owner   = "hari"
    se-region = "EP"
    purpose = "customer_demo_env, ttl is set to -1 since i am new and only as i am ramping up, i will tune it once i understand my needs better" 
    ttl = "-1"
    terraform = true
    hc-internet-facing = false    
  }
}

