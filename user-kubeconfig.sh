#!/bin/sh
 
clusterurl=$( oc project | awk '{ print $NF }' | sed -e 's/\"//g' -e 's/\.$//' )
clustername=$( echo $clusterurl | sed 's/https:\/\///')
 
## Create a key and csr
openssl req -nodes -newkey rsa:4096 -keyout /tmp/nsmetrics.key -subj "/O=system:nsmetrics/CN=nsmetrics" -out /tmp/nsmetrics.csr
  
## Submit csr to cluster
cat << EOF | oc create -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: nsmetrics-user-access
spec:
  signerName: kubernetes.io/kube-apiserver-client
  groups:
  - system:authenticated
  - nsmetrics
  request: $(cat /tmp/nsmetrics.csr | base64 -w0 )
  usages:
  - client auth
EOF
 
csrname=$(oc get csr nsmetrics-user-access | grep nsmetrics )
 
if [[ -z $csrname ]] ; then
	  echo "ERROR: Could not find csr"
	    exit 8
    fi
     
    ## Approve the CSR
    oc adm certificate approve nsmetrics-user-access
     
    ## Grab the cert
    oc get csr nsmetrics-user-access -o jsonpath='{ .status.certificate}' | base64 -d > /tmp/nsmetrics.crt
     
    ## Create a kubeconfig
     
    cat << EOF > /tmp/kubeconfig
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tDQpNSUlHaERDQ0JXeWdBd0lCQWdJS1lSTzk0Z0FBQUFBQ
    server: $clusterurl
  name: $clustername
contexts:
- context:
    cluster: $clustername
    user: nsmetrics
  name: nsmetrics
current-context: nsmetrics
kind: Config
preferences: {}
users:
- name: nsmetrics
  user:
    client-certificate-data: $( cat /tmp/nsmetrics.crt | base64 -w 0 )
    client-key-data: $( cat /tmp/nsmetrics.key | base64 -w 0 )
EOF
 
## test it
echo "Testing to see whoami"
oc whoami  --kubeconfig=/tmp/kubeconfig --context=nsmetrics

