// Copyright (C) 2022 Intel Corporation
// SPDX-License-Identifier: Apache-2.0
//

#include "snippets/add.hpp"
#include "common_test_utils/test_constants.hpp"

namespace ov {
namespace test {
namespace snippets {


namespace {

INSTANTIATE_TEST_SUITE_P(smoke_Snippets_Eltwise, Add,
        ::testing::Combine(
                ::testing::Values(ov::Shape {1, 42, 16, 64}),
                ::testing::Values(ov::Shape {1, 42, 16,  1}),
                ::testing::Values(ov::element::f32),
                ::testing::Values(1), // one node - Add
                ::testing::Values(0), // SnippetsMarkSkipped disables tokenization for eltwise chains after inputs
                ::testing::Values(CommonTestUtils::DEVICE_CPU)),
        Add::getTestCaseName);

INSTANTIATE_TEST_SUITE_P(smoke_Snippets_Eltwise, AddSinh,
        ::testing::Combine(
        ::testing::Values(ov::Shape {1, 42, 16, 64}),
        ::testing::Values(ov::Shape {1, 42, 16,  1}),
        ::testing::Values(ov::element::f32),
        ::testing::Values(3), // Add + 2 sinh after inputs
        ::testing::Values(1), // Subgraph is created, since the inputs are followed by converts
        ::testing::Values(CommonTestUtils::DEVICE_CPU)),
                         AddSinh::getTestCaseName);

INSTANTIATE_TEST_SUITE_P(smoke_Snippets_Eltwise, AddSinhConst,
        ::testing::Combine(
                ::testing::Values(ov::Shape {1, 42, 16, 64}),
                ::testing::Values(ov::element::f32),
                ::testing::Values(2), // Add + sinh after inputs
                ::testing::Values(1), // Subgraph is created, since the inputs are followed by converts
                ::testing::Values(CommonTestUtils::DEVICE_CPU)),
        AddSinhConst::getTestCaseName);

INSTANTIATE_TEST_SUITE_P(smoke_Snippets_Eltwise, AddRollConst,
        ::testing::Combine(
                ::testing::Values(ov::Shape {1, 42, 16, 64}),
                ::testing::Values(ov::element::f32),
                ::testing::Values(2), // Add + roll after inputs
                ::testing::Values(1), // Subgraph is created, since the inputs are followed by converts
                ::testing::Values(CommonTestUtils::DEVICE_CPU)),
        AddRollConst::getTestCaseName);

INSTANTIATE_TEST_SUITE_P(smoke_Snippets_Eltwise_BF16, AddRollConst,
        ::testing::Combine(
                ::testing::Values(ov::Shape {1, 42, 16, 64}),
                ::testing::Values(ov::element::bf16),
                ::testing::Values(3), // Add + reorder + roll after inputs
                ::testing::Values(1), // Subgraph is created, since the inputs are followed by converts
                ::testing::Values(CommonTestUtils::DEVICE_CPU)),
        AddRollConst::getTestCaseName);


}  // namespace
} // namespace snippets
} // namespace test
} // namespace ov