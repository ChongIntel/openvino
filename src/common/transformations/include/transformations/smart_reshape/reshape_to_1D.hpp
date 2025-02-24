// Copyright (C) 2018-2022 Intel Corporation
// SPDX-License-Identifier: Apache-2.0
//

#pragma once

#include <memory>
#include <ngraph/pass/graph_rewrite.hpp>
#include <vector>

namespace ov {
namespace pass {

class NGRAPH_API ReshapeTo1D;

}  // namespace pass
}  // namespace ov

/**
 * @ingroup ie_transformation_common_api
 * @brief ReshapeTo1D transformation looks for Reshape from nD to 1D tensor and replaces its pattern to [-1]
 */

class ov::pass::ReshapeTo1D : public ngraph::pass::MatcherPass {
public:
    OPENVINO_RTTI("ReshapeTo1D", "0");
    ReshapeTo1D();
};

namespace ngraph {
namespace pass {
using ov::pass::ReshapeTo1D;
}  // namespace pass
}  // namespace ngraph
