// Copyright (C) 2018-2022 Intel Corporation
// SPDX-License-Identifier: Apache-2.0
//

#pragma once

#include <memory>
#include <openvino/pass/graph_rewrite.hpp>
#include <transformations_visibility.hpp>
#include <vector>

namespace ov {
namespace pass {

class TRANSFORMATIONS_API ConvertShapeOf3;

}  // namespace pass
}  // namespace ov

class ov::pass::ConvertShapeOf3 : public ov::pass::MatcherPass {
public:
    OPENVINO_RTTI("ConvertShapeOf3", "0");
    ConvertShapeOf3();
};

namespace ngraph {
namespace pass {
using ov::pass::ConvertShapeOf3;
}  // namespace pass
}  // namespace ngraph
