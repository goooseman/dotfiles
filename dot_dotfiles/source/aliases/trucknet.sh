alias trucknet-prepare-demo=./server/lib/fakeDataSeeder/dev-prepare-demo-env.sh
alias trucknet-nginx-logs="kubectl -n kube-ingress logs --selector=app=ingress-nginx -f --tail 10"