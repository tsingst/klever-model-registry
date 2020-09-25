#!/bin/bash

# kubebernets 1.14.8 is test ok.

# Stop if there are error.
set -e

WORKDIR=klever
mkdir $WORKDIR

# Set it as k8s master ip.
export MASTER_IP="192.168.64.8"

# Set harbor NodePort port.
export HARBOR_PORT=30022

# Set klever-model-registry NodePort port.
export KLEVER_MODEL_REGISTRY_PORT=30100

# 
# Go to manifests directory, it is workdir.
CRTDIR=$(pwd)
cd $CRTDIR/$WORKDIR

#
# Install istio, please reference https://istio.io/v1.2/docs/setup/kubernetes/install/helm/
#
git clone git@github.com:istio/istio.git
cd $CRTDIR/istio; 
git checkout 1.2.2; 
cd $CRTDIR
kubectl create namespace istio-system
helm template istio-init istio/install/kubernetes/helm/istio-init --namespace istio-system | kubectl apply -f -
kubectl get crds | grep 'istio.io\|certmanager.k8s.io' | wc -l
# If syntax errors in gateway templates with go1.14
# Please reference https://github.com/istio/istio/issues/22366
helm template istio istio/install/kubernetes/helm/istio --namespace istio-system | kubectl apply -f -

#
# Install harbor
#
kubectl create namespace harbor-system
helm install harbor harbor --version=v1.4.2 \
    --repo https://helm.goharbor.io \
    --set expose.nodePort.ports.http.nodePort=$HARBOR_PORT \
    --set expose.type=nodePort \
    --set expose.tls.enabled=false \
    --set trivy.enabled=false \
    --set notary.enabled=false \
    --set persistence.enabled=false \
    --set trivy.ignoreUnfixed=true \
    --set trivy.insecure=true \
    --set externalURL=http://$MASTER_IP:$HARBOR_PORT \
    --set core.image.tag=v2.1.0-tech-preview \
    --set harborAdminPassword="ORMBtest12345" \
    --namespace harbor-system

#
# Install seldon, please reference https://docs.seldon.io/projects/seldon-core/en/latest/charts/seldon-core-operator.html
#
git clone https://github.com/kleveross/seldon-core.git
kubectl create namespace seldon-system
helm install seldon-core seldon-core/helm-charts/seldon-core-operator \
    --set usageMetrics.enabled=true \
    --set istio.enabled=true \
    --set istio.gateway=istio-system/kleveross-gateway \
    --set ambassador.enabled=false \
    --set executor.enabled=false \
    --set defaultUserID=0 \
    --set image.registry=ghcr.io \
    --set image.repository=kleveross/seldon-core-operator \
    --set image.tag=0.1.0 \
    --namespace seldon-system

#
# Install Klever
#
git clone https://github.com/kleveross/klever-model-registry.git
kubectl create namespace kleveross-system

# Install Klever-modeljob-operator
helm install klever-modeljob-operator klever-model-registry/manifests/modeljob-operator \
    --namespace=kleveross-system

# Install Klever-model-registry
helm install klever-model-registry klever-model-registry/manifests/model-registry \
    --set externalAddress=$MASTER_IP:$KLEVER_MODEL_REGISTRY_PORT \
    --set service.nodePort=$KLEVER_MODEL_REGISTRY_PORT \
    --namespace=kleveross-system 
