compartment_id = "ocid1.compartment.ADD_YOUR_COMPARTMENT_ID_HERE"

#No longer have to input compartment_ID if you hard code it here. 
#Do Terraform apply -auto-approve, or follow syntax below

# 1. VMs with default names
# terraform apply -var="vm_count=5"

# 2. VMs with custom names  
# terraform apply -var='vm_names=["web1","db1","app1"]'

# 3. Both together
# terraform apply -var="vm_count=5" -var='vm_names=["web1","db2","app1","cache1","cache2"]'
