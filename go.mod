module github.com/SSU-DCN/podmigration-operator

go 1.15

// require (
// 	github.com/emicklei/go-restful v2.9.5+incompatible
// 	github.com/go-logr/logr v0.1.0
// 	github.com/onsi/ginkgo v1.11.0
// 	github.com/onsi/gomega v1.8.1
// 	k8s.io/api v0.17.2
// 	k8s.io/apimachinery v0.17.2
// 	k8s.io/client-go v0.17.2
// 	sigs.k8s.io/controller-runtime v0.5.0
// )
require (
	github.com/emicklei/go-restful v2.9.5+incompatible
	github.com/go-logr/logr v0.1.0
	github.com/onsi/ginkgo v1.12.1
	github.com/onsi/gomega v1.10.1
	github.com/spf13/cobra v0.0.5
	k8s.io/api v0.18.6
	k8s.io/apimachinery v0.18.6
	k8s.io/client-go v0.18.6
	sigs.k8s.io/controller-runtime v0.6.3
)

//replace k8s.io/api => ../kubernetes/staging/src/k8s.io/api

//replace k8s.io/apimachinery => ../kubernetes/staging/src/k8s.io/apimachinery

//replace k8s.io/client-go => ../kubernetes/staging/src/k8s.io/client-go
