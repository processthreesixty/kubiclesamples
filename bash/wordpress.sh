helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install my-wordpress bitnami/wordpress --set wordpressPassword=my-password --set mysqlRootPassword=my-root-password --set mysqlPassword=my-mysql-password