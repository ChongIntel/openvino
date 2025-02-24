# Copyright (C) 2018-2022 Intel Corporation
# SPDX-License-Identifier: Apache-2.0

import numpy as np
import pytest
import tensorflow as tf
from common.tf_layer_test_class import CommonTFLayerTest


class TestFusedBatchNorm(CommonTFLayerTest):
    def _prepare_input(self, inputs_info):
        inputs_data = {}
        x_shape = inputs_info['x']
        inputs_data['x'] = np.random.randint(-10, 10, x_shape)
        scale_shape = inputs_info['scale']
        inputs_data['scale'] = np.random.randint(-10, 10, scale_shape)
        offset_shape = inputs_info['offset']
        inputs_data['offset'] = np.random.randint(-10, 10, offset_shape)
        if 'mean' in inputs_info:
            mean_shape = inputs_info['mean']
            inputs_data['mean'] = np.random.randint(-10, 10, mean_shape)
        if 'variance' in inputs_info:
            variance_shape = inputs_info['variance']
            inputs_data['variance'] = np.random.randint(0, 10, variance_shape)
        return inputs_data

    def create_fused_batch_norm_net(self, x_shape, epsilon, exponential_avg_factor, data_format, is_training,
                                    fbn_version):
        fbn_dict = {
            "v1": tf.raw_ops.FusedBatchNorm,
            "v2": tf.raw_ops.FusedBatchNormV2,
            "v3": tf.raw_ops.FusedBatchNormV3
        }
        tf.compat.v1.reset_default_graph()
        # Create the graph and model
        with tf.compat.v1.Session() as sess:
            c_dim = x_shape[-1]
            if data_format == "NCHW":
                c_dim = x_shape[1]
            x = tf.compat.v1.placeholder(tf.float32, x_shape, 'x')
            mean = tf.compat.v1.placeholder(tf.float32, [c_dim], 'mean')
            variance = tf.compat.v1.placeholder(tf.float32, [c_dim], 'variance')
            scale = tf.compat.v1.placeholder(tf.float32, [c_dim], 'scale')
            offset = tf.compat.v1.placeholder(tf.float32, [c_dim], 'offset')
            fbn_func = fbn_dict[fbn_version]
            if not is_training:
                # due to limitation in the layer test infrastructure - it finds tensor names for Parameter and Result nodes
                # by get_any_name() that cannot work if some nodes fused to Parameter or Result node have multiple tensor names
                # This issue is tracked in 97192 ticket
                # Now it is worked around by guarding Parameter Node with AddV2
                mean = tf.raw_ops.AddV2(x=mean, y=tf.constant(2.0, dtype=tf.float32))
                variance = tf.raw_ops.AddV2(x=variance, y=tf.constant(2.0, dtype=tf.float32))
            fused_batch_norm = fbn_func(x=x, scale=scale, offset=offset, epsilon=epsilon,
                                        mean=mean, variance=variance,
                                        exponential_avg_factor=exponential_avg_factor, data_format=data_format,
                                        is_training=is_training, name="FusedBatchNorm")
            tf.identity(fused_batch_norm[0], name='y')
            tf.identity(fused_batch_norm[1], name='batch_mean')
            tf.identity(fused_batch_norm[2], name='batch_variance')
            tf.compat.v1.global_variables_initializer()

            tf_net = sess.graph_def

        return tf_net, None

    test_data_basic = [
        # Currently these cases are passing on Windows, looks a problem with CPU on Linux
        pytest.param(dict(x_shape=[2, 3, 4, 5], epsilon=0.0001, exponential_avg_factor=1, data_format="NHWC",
                          is_training=True,
                          fbn_version="v1"), marks=pytest.mark.xfail(reason="97191")),
        pytest.param(dict(x_shape=[2, 3, 4, 5], epsilon=0.0005, exponential_avg_factor=0.3, data_format="NHWC",
                          is_training=True,
                          fbn_version="v2"), marks=pytest.mark.xfail(reason="97191")),
        pytest.param(dict(x_shape=[3, 2, 1, 5], epsilon=0.00003, exponential_avg_factor=0.7, data_format="NCHW",
                          is_training=True,
                          fbn_version="v3"), marks=pytest.mark.xfail(reason="97191")),
        pytest.param(dict(x_shape=[3, 4, 2, 5], epsilon=0.0003, exponential_avg_factor=0.0, data_format="NCHW",
                          is_training=True,
                          fbn_version="v3"), marks=pytest.mark.xfail(reason="97191")),
        dict(x_shape=[2, 3, 4, 5], epsilon=0.0001, exponential_avg_factor=1, data_format="NHWC",
             is_training=False,
             fbn_version="v1"),
        dict(x_shape=[3, 2, 1, 4], epsilon=0.0005, exponential_avg_factor=0.3, data_format="NCHW",
             is_training=False,
             fbn_version="v2"),
        dict(x_shape=[5, 4, 3, 2], epsilon=0.0005, exponential_avg_factor=0.0, data_format="NCHW",
             is_training=False,
             fbn_version="v3"),
    ]

    @pytest.mark.parametrize("params", test_data_basic)
    @pytest.mark.precommit_tf_fe
    def test_fused_batch_norm_basic(self, params, ie_device, precision, ir_version, temp_dir,
                                    use_new_frontend, use_old_api):
        self._test(*self.create_fused_batch_norm_net(**params),
                   ie_device, precision, ir_version, temp_dir=temp_dir,
                   use_new_frontend=use_new_frontend, use_old_api=use_old_api)
