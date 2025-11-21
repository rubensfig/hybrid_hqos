################################################################################
#
# Copyright (C) 2024 Intel Corporation
# 
# This software and the related documents are Intel copyrighted materials, and 
# your use of them is governed by the express license under which they were 
# provided to you ("License"). Unless the License provides otherwise, you may not 
# use, modify, copy, publish, distribute, disclose or transmit this software or 
# the related documents without Intel's prior written permission.
# 
# This software and the related documents are provided as is, with no express or 
# implied warranties, other than those that are expressly stated in the License.
# 
#  version: VBNG_VAGF.L.24.03.0-00014
#
################################################################################

container=$(hostname)

/tmp/etcdctl --endpoints=etcd-client:2379 put /vnf-agent/status/$container DOWN
