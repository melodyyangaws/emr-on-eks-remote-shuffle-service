/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// Code generated by lister-gen. DO NOT EDIT.

package v1alpha1

import (
	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/labels"
	"k8s.io/client-go/tools/cache"

	v1alpha1 "github.com/apache/incubator-uniffle/deploy/kubernetes/operator/api/uniffle/v1alpha1"
)

// RemoteShuffleServiceLister helps list RemoteShuffleServices.
// All objects returned here must be treated as read-only.
type RemoteShuffleServiceLister interface {
	// List lists all RemoteShuffleServices in the indexer.
	// Objects returned here must be treated as read-only.
	List(selector labels.Selector) (ret []*v1alpha1.RemoteShuffleService, err error)
	// RemoteShuffleServices returns an object that can list and get RemoteShuffleServices.
	RemoteShuffleServices(namespace string) RemoteShuffleServiceNamespaceLister
	RemoteShuffleServiceListerExpansion
}

// remoteShuffleServiceLister implements the RemoteShuffleServiceLister interface.
type remoteShuffleServiceLister struct {
	indexer cache.Indexer
}

// NewRemoteShuffleServiceLister returns a new RemoteShuffleServiceLister.
func NewRemoteShuffleServiceLister(indexer cache.Indexer) RemoteShuffleServiceLister {
	return &remoteShuffleServiceLister{indexer: indexer}
}

// List lists all RemoteShuffleServices in the indexer.
func (s *remoteShuffleServiceLister) List(selector labels.Selector) (ret []*v1alpha1.RemoteShuffleService, err error) {
	err = cache.ListAll(s.indexer, selector, func(m interface{}) {
		ret = append(ret, m.(*v1alpha1.RemoteShuffleService))
	})
	return ret, err
}

// RemoteShuffleServices returns an object that can list and get RemoteShuffleServices.
func (s *remoteShuffleServiceLister) RemoteShuffleServices(namespace string) RemoteShuffleServiceNamespaceLister {
	return remoteShuffleServiceNamespaceLister{indexer: s.indexer, namespace: namespace}
}

// RemoteShuffleServiceNamespaceLister helps list and get RemoteShuffleServices.
// All objects returned here must be treated as read-only.
type RemoteShuffleServiceNamespaceLister interface {
	// List lists all RemoteShuffleServices in the indexer for a given namespace.
	// Objects returned here must be treated as read-only.
	List(selector labels.Selector) (ret []*v1alpha1.RemoteShuffleService, err error)
	// Get retrieves the RemoteShuffleService from the indexer for a given namespace and name.
	// Objects returned here must be treated as read-only.
	Get(name string) (*v1alpha1.RemoteShuffleService, error)
	RemoteShuffleServiceNamespaceListerExpansion
}

// remoteShuffleServiceNamespaceLister implements the RemoteShuffleServiceNamespaceLister
// interface.
type remoteShuffleServiceNamespaceLister struct {
	indexer   cache.Indexer
	namespace string
}

// List lists all RemoteShuffleServices in the indexer for a given namespace.
func (s remoteShuffleServiceNamespaceLister) List(selector labels.Selector) (ret []*v1alpha1.RemoteShuffleService, err error) {
	err = cache.ListAllByNamespace(s.indexer, s.namespace, selector, func(m interface{}) {
		ret = append(ret, m.(*v1alpha1.RemoteShuffleService))
	})
	return ret, err
}

// Get retrieves the RemoteShuffleService from the indexer for a given namespace and name.
func (s remoteShuffleServiceNamespaceLister) Get(name string) (*v1alpha1.RemoteShuffleService, error) {
	obj, exists, err := s.indexer.GetByKey(s.namespace + "/" + name)
	if err != nil {
		return nil, err
	}
	if !exists {
		return nil, errors.NewNotFound(v1alpha1.Resource("remoteshuffleservice"), name)
	}
	return obj.(*v1alpha1.RemoteShuffleService), nil
}