package main

import (
	"context"
	"flag"
	"log"
	"time"

	crdV1 "k8s.io/apiextensions-apiserver/pkg/apis/apiextensions/v1"
	crdClientset "k8s.io/apiextensions-apiserver/pkg/client/clientset/clientset"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/rest"
)

func main() {
	// This program is intended to be used as the init-container for any program
	// that needs to wait for CRDs.
	// Currently its hardcoded to watch for machinedpeloyments, machinepools, and clusters
	// but this can be parameterized.
	var sleepDuration int

	//Latch flags.
	flag.IntVar(&sleepDuration, "sleep-duration", 1800, "time in seconds to sleep for")
	flag.Parse()

	config, err := rest.InClusterConfig()
	if err != nil {
		log.Fatalf("error occured when connecting to the api-server: %v", err)
	}
	crdClientSet, err := crdClientset.NewForConfig(config)
	if err != nil {
		log.Fatalf("error occured when connecting to the api-server: %v", err)
	}

	// TODO: Take this in from the CLI
	resources := []string{"machinedeployments", "machinepools", "clusters"}
	for {
		var allEstablished bool = true
		for _, resource := range resources {
			crd, err := crdClientSet.ApiextensionsV1().CustomResourceDefinitions().Get(context.Background(), resource, metav1.GetOptions{})
			if err != nil {
				// Error occured, sleep and retry.
				allEstablished = allEstablished && false
				break
			}

			// CRD found, verify that it has Condition Established, fail otherwise.
			for _, condition := range crd.Status.Conditions {
				switch condition.Type {
				case crdV1.Established:
					if condition.Status != crdV1.ConditionTrue {
						allEstablished = allEstablished && false
						break
					}
				}
			}
		}
		if allEstablished {
			break
		}
		time.Sleep(time.Duration(sleepDuration) * time.Second)
	}
	log.Printf("Success! CRDs detected.")
}
